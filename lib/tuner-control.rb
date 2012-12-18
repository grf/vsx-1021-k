require 'vsx-exceptions'

class TunerControl

  def initialize vsx
    @vsx = vsx
  end

  # return symbol :fm or :am

  def band
    inquire[:band]
  end

  # return float as string

  def frequency
    inquire[:frequency]
  end

  # return descriptive info, e.g. "FM 89.0 MHz"

  def report
    inq = inquire
    if inq[:band] == :fm
      "FM " + sprintf("%3.1f", inq[:frequency]) + " " + inq[:units]
    elsif  inq[:band] == :am
      "AM " + sprintf("%3.0f", inq[:frequency]) + " " + inq[:units]
    else
      "failed request - unknown band, unknown frequency"
    end
  end

  # set band to :fm or :am

  def band= value

    rec = inquire()

    return value if value == rec[:band]

    case value
    when :fm : code = '00TN'
    when :am : code = '01TN'
    else
      return
    end

    @vsx.cmd(code)  # doesn't really return anything interesting

    return case @vsx.cmd('?FR',  /^FR([FA])(\d+)$/)[0]
           when 'F' : :fm
           when 'A' : :am
           else
             nil
           end
  end

  def frequency= value
    rec = inquire()
    return value if pretty_close?(value, rec[:frequency])

    code = case rec[:band]
           when :am :  sprintf("%04d", value.to_i)
           when :fm :  sprintf("%04d", (value * 100).to_i)
           end

    @vsx.cmd('TAC')
    code.unpack('aaaa').each { |char| @vsx.cmd("#{char}TP") }

    raw_band, raw_freq = @vsx.cmd('?FR',  /^FR([FA])(\d+)$/)

    return case raw_band
           when 'F': raw_freq.to_i / 100.0
           when 'A': raw_freq.to_i / 1.0
           else
             nil
           end
  end

  # Tell the VSX to use the tuner as input; returns true if succesful

  def select
    return @vsx.set_input('02') == '02'
  end

  # private

  def pretty_close? x, y
    return false unless [Float, Fixnum].include?(x.class) &&  [Float, Fixnum].include?(y.class)
    (x - y).abs <= 0.1  # we can set to 0.1 frequency
  end
  
  # return hash { :frequency => float, :band => [ :fm | :am ], :units => [ 'MHz' | 'KHz' ] } 
  # return empty hash on error

  def inquire

    raw_band, raw_freq = @vsx.cmd('?FR', /^FR([FA])(\d+)$/)

    case raw_band
    when 'F'
      return { :band => :fm, :frequency => raw_freq.to_i / 100.0, :units => 'MHz' }
    when 'A'
      return { :band => :am, :frequency => raw_freq.to_i / 1.0,   :units => 'KHz' }
    else
      return { }
    end
  end


end
