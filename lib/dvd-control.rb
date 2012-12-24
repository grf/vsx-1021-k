require 'vsx-exceptions'

class DVDControl

  def initialize vsx
    @vsx = vsx
  end

  # Tell the VSX to use the DVD as input; returns true if succesful

  def select
    return (@vsx.input = '04') == '04'
  end

end
