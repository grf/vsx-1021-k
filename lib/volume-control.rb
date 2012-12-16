require 'vsx-exceptions'

class VolumeControl

  def initialize vsx
    @vsx = vsx
  end

  # to do: add incr, decr, set, mute, inquire methods

  def report
    return sprintf("%3.1f Db, %s", inquire_volume, inquire_mute ? 'muted' : 'not muted')
  end

  def muted?
    return inquire_mute
  end

  def db
    return inquire_volume
  end

  def db= value
    #####
  end

  def mute
    return if muted?
    #####
  end

  def unmute
    return unless muted?
    #####
  end

  def incr
    #####
  end

  def decr
    #####
  end

  private


  def inquire_volume
    vol = @vsx.command_matches('?V', /^VOL(\d+)$/, 'volume inquiry')[0]
    return (vol.to_i - 161) * 0.5
  end

  def inquire_mute
    bool = @vsx.command_matches('?M', /^MUT([01])$/, 'mute inquiry')[0]
    return bool == '0' ? true : false
  end


  ##### FIXME

  # increment up or down by increment, +1 = +0.5 dB

  def volume_delta increment
    increment = increment.to_i
    return nil if increment == 0  # treat nil as no-op
    increment < 0 ? ([ 'VD' ] * increment.abs).join("\r\n") : ([ 'VU' ] * increment).join("\r\n") 
  end

  ##### FIXME

  # goes from -80.0 db to +12.db

  def volume_set db
    return '185VL' if db >  12.0
    return '000VL' if db < -80.0  
    return sprintf("%03dVL", (db/0.5 + 161).to_int)
  end

end
