require 'vsx-exceptions'

class VolumeControl

  def initialize vsx
    @vsx = vsx
  end

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
    code = if value >  12.0
             '185VL' 
           elsif value < -80.0
             '000VL'
           else
             sprintf("%03dVL", (value/0.5 + 161).to_int)
           end

    @vsx.command(code)
    resp = @vsx.persistent_command('?V', /^VOL(\d+)$/)
    return nil unless resp
    db =  decode_volume(resp[0])
    return nil unless pretty_close(value, db)
    return db
  end

  def mute
    return true if muted?
    @vsx.command('MO')
    return @vsx.persistent_command('?M', /^(MUT0)$/) == nil ? false : true
  end

  def unmute
    return true unless muted?
    @vsx.command('MF')
    return @vsx.persistent_command('?M', /^(MUT1)$/) == nil ? false : true
  end

  def incr
    @vsx.command('VU')
    resp = @vsx.persistent_command('?V', /^VOL(\d+)$/)
    return decode_volume(resp[0]) if resp
    return nil
  end

  def decr
    @vsx.command('VD')
    resp = @vsx.persistent_command('?V', /^VOL(\d+)$/)
    return decode_volume(resp[0]) if resp
    return nil
  end

  private

  def pretty_close x, y
    (x - y).abs < 0.001
  end
  
  def decode_volume code
    return (code.to_i - 161) * 0.5
  end

  def inquire_volume
    vol = @vsx.command_matches('?V', /^VOL(\d+)$/, 'volume inquiry')[0]
    return decode_volume(vol)
  end

  def inquire_mute
    bool = @vsx.command_matches('?M', /^MUT([01])$/, 'mute inquiry')[0]
    return bool == '0' ? true : false
  end

end
