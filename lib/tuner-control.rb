require 'vsx-exceptions'


# TODO: manage presets somehow


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
    when :fm then code = '00TN'
    when :am then code = '01TN'
    else
      return
    end

    @vsx.cmd(code)  # doesn't really return anything interesting

    return case @vsx.cmd('?FR',  /^FR([FA])(\d+)$/).shift
           when 'F' then :fm
           when 'A' then :am
           else
             nil
           end
  end

  def frequency= value
    rec = inquire()
    return value if pretty_close?(value, rec[:frequency])

    code = case rec[:band]
           when :am then  sprintf("%04d", value.to_i)
           when :fm then  sprintf("%04d", (value * 100).to_i)
           end

    @vsx.cmd('TAC')
    code.unpack('aaaa').each { |char| @vsx.cmd("#{char}TP") }

    raw_band, raw_freq = @vsx.cmd('?FR',  /^FR([FA])(\d+)$/)

    return case raw_band
           when 'F'then raw_freq.to_i / 100.0
           when 'A'then raw_freq.to_i / 1.0
           else
             nil
           end
  end

  def select
    return (@vsx.inputs.selected = 'TUNER')
  end

  def selected?
    return (@vsx.inputs.selected[:device] == 'TUNER')
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
