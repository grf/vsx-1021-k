require 'vsx-exceptions'

class VolumeControl

  def initialize vsx
    @vsx = vsx
  end

  def report
    return sprintf("%3.1f Db, %s", db || -999, muted? ? 'muted' : 'not muted')
  end

  def bass
    return decode_tone(@vsx.cmd('?BA', /^BA(\d+)$/).shift)
  end

  def treble
    return decode_tone(@vsx.cmd('?TA', /^BA(\d+)$/).shift)
  end





  # TODO:

  def left

  end

  def right
  end






  def db
    return decode_volume(@vsx.cmd('?V', /^VOL(\d+)$/).shift)
  end

  # We're careful about top sound, refuse to turn it up too high for our particular
  # system. -80 to +12 db.

  def db= value
    code = if value >  12.0
             '185VL'
           elsif value < -80.0
             '000VL'
           else
             sprintf("%03dVL", (value/0.5 + 161).to_int)
           end

    return decode_volume(@vsx.cmd(code, /^VOL(\d+)$/).shift)
  end

  def muted?
    return @vsx.cmd('?M', /^MUT([01])$/).shift == '0' ? true : false
  end

  def mute
    return true if muted?
    return @vsx.cmd('MO', /^MUT([01])$/).shift == '0'
  end

  def unmute
    return true unless muted?
    return @vsx.cmd('MF', /^MUT([01])$/).shift == '1'
  end

  def incr db_increment=nil
    return decode_volume(@vsx.cmd('VU', /^VOL(\d+)$/).shift) unless db_increment  # 0.5 db by default
    db_increment = db_increment.to_f.abs

    raise sprintf("Won't raise volume more than 5dB at a time - you asked for %4.2f", db_increment) if db_increment > 5

    self.db += db_increment
  end

  def decr db_increment=nil
    return decode_volume(@vsx.cmd('VD', /^VOL(\d+)$/).shift) unless db_increment
    return self.db -= db_increment.to_f.abs
  end

  def fade_in target_volume, pause = 0.2
    initial_volume = self.db
    return if target_volume <= initial_volume

    self.unmute
    fade_values(initial_volume, target_volume).each do |vol|
      self.db = vol
      sleep pause
    end
  end

  def fade_out target_volume, pause = 0.2
    initial_volume = self.db
    return if initial_volume >= target_volume

    self.unmute
    fade_values(initial_volume, target_volume).reverse.each do |vol|
      self.db vol
      sleep pause
    end
  end

  def fade_values lower_volume, upper_volume, db_increment  = 2.5
    intervals = ((upper_volume - lower_volume)/db_increment).to_int + 1
    values = []
    intervals.times { |i| values.push lower_volume + db_increment * i }
    return values
  end

  # private

  def pretty_close? x, y
    return false unless [Float, Fixnum].include?(x.class) &&  [Float, Fixnum].include?(y.class)
    return (x - y).abs <= 0.5  # we can set in 0.5 dB steps
  end

  def decode_volume code
    return nil unless code.class == String
    return nil unless code =~ /^\d+$/
    return (code.to_i - 161) * 0.5
  end

  def decode_tone code
    return nil unless code.class == String
    return nil unless code =~ /^\d+$/
    return (code.to_i - 06) * 6
  end





end
