require 'vsx-exceptions'

class Video1Control

  def initialize vsx
    @vsx = vsx
  end

  # Tell the VSX to use the DVD as input; returns true if succesful

  def select
    return (@vsx.inputs.selected = 'VIDEO 1')
  end

  def selected?
    return (@vsx.inputs.selected[:device] == 'VIDEO 1')
  end

end
