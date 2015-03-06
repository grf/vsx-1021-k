require 'vsx-exceptions'

class BDControl

  def initialize vsx
    @vsx = vsx
  end

  # Tell the VSX to use the BD as input; returns true if succesful

  def select
    return (@vsx.inputs.selected = 'BD')
  end

  def selected?
    return (@vsx.inputs.selected[:device] == 'BD')
  end

end
