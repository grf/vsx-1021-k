require 'vsx-exceptions'

class DVRBDRControl

  def initialize vsx
    @vsx = vsx
  end

  # Tell the VSX to use the BD/DVD as input; returns true if succesful

  def select
    return (@vsx.inputs.selected = 'DVR/BDR')
  end

  def selected?
    return (@vsx.inputs.selected[:device] == 'DVR/BDR')
  end

end
