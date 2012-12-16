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

  def report
    inq = inquire
    if inq[:band] == :fm
      "FM " + inq[:frequency] + " " + inq[:units]
    else
      "AM " + inq[:frequency] + " " + inq[:units]
    end
  end

  # TODO: band=, frequency=   -- note: setting to band when already in that band gets no response, so check

  def band= value
    #####
  end

  def frequency= value
    #####
  end

  # Tell the VSX to use the tuner as input; returns true if succesful
  # TODO:  may want to generalize this into the @vsx class

  def select
    input = @vsx.command_matches('?F', /FN(\d+)/, 'tuner selection')[0]
    return true if input == '02'

    # this is slightly tricky - if we have to select a new input, the
    # VSX generates a lot of messages. thus we use the lower-level
    # command interface.

    @vsx.command('02FN')

    3.times do
      return true if @vsx.command('?F') =~ /FN02/
      sleep 0.5
    end

    return false
  end


  private
  
  # return hash { :frequency => float, :band => [ :fm | :am ], :units => [ 'MHz' | 'KHz' ] } 
  # raise VsxError on timeout or 

  def inquire
    regx = /^FR([FA])(\d+$)/

    #### TODO: use command_matches
    response = @vsx.command '?FR', regx
    raise  NoResponse, "No response from VSX at #{@vsx.hostname} for tuner inquiry" unless response

    regx =~ response
    raw_band, raw_freq = $1, $2

    case raw_band
    when 'F'
      return { :band => :fm, :frequency => sprintf("%3.1f", raw_freq.to_i / 100.0), :units => 'MHz' }
    when 'A'
      return { :band => :am, :frequency => sprintf("%3.0f", raw_freq.to_i / 1.0), :units => 'KHz' }
    else
      raise InvalidResponse, "Bad response '#{response}' from VSX at #{@vsx.hostname} for tuner inquiry"
    end
  end


end
