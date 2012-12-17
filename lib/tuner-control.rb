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
    else
      "AM " + sprintf("%3.0f", inq[:frequency]) + " " + inq[:units]
    end
  end

  # set band to :fm or :am

  def band= value

    rec = inquire()
    return nil unless rec  # TODO: not necessary now, but I've plans for inquire() not to throw an error but return nil

    return value if value == rec[:band]

    case value
    when :fm : code = '00TN'
    when :am : code = '01TN'
    else
      return nil
    end

    @vsx.command(code)
    resp = @vsx.persistent_command('?FR',  /^FR([FA])(\d+)$/)
    return nil unless resp
    return case resp[0]
           when 'F' : :fm
           when 'A' : :am
           else
             nil
           end
  end

  def frequency= value
    rec = inquire()
    return nil unless rec
    return value if pretty_close(value, rec[:frequency])

    code = case rec[:band]
           when :am :  sprintf("%04d", value.to_i)
           when :fm :  sprintf("%04d", (value * 100).to_i)
           end

    @vsx.command('TAC')
    code.unpack('aaaa').each { |char| @vsx.command("#{char}TP") }
      
    response = @vsx.persistent_command('?FR',  /^FR([FA])(\d+)$/)
    return nil unless response

    raw_band, raw_freq = response

    return case raw_freq
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


  private

  def pretty_close x, y
    (x - y).abs < 0.001
  end
  
  # return hash { :frequency => float, :band => [ :fm | :am ], :units => [ 'MHz' | 'KHz' ] } 
  # raise VsxError on timeout or 

  def inquire

    raw_band, raw_freq = @vsx.command_matches('?FR', /^FR([FA])(\d+)$/, 'tuner inquiry')

    case raw_band
    when 'F'
      return { :band => :fm, :frequency => raw_freq.to_i / 100.0, :units => 'MHz' }
    when 'A'
      return { :band => :am, :frequency => raw_freq.to_i / 1.0,   :units => 'KHz' }
    else
      raise InvalidResponse, "Bad response ('#{raw_band}', '#{raw_freq}') from VSX at #{@vsx.hostname} for tuner inquiry"
    end
  end


end
