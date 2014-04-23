require 'vsx-exceptions'

class DVDControl

  def initialize vsx
    @vsx = vsx
  end

  # Tell the VSX to use the DVD as input; returns true if succesful

  def select
    return (@vsx.inputs.selected = 'DVD')
  end

  def selected?
    return (@vsx.inputs.selected[:device] == 'DVD')
  end

end
