require 'vsx-exceptions'

class InputControl


  INPUT_CODES = {
    '00' => 'PHONO',           # [1]
    '01' => 'CD',
    '02' => 'TUNER',
    '03' => 'CD-R/TAPE',
    '04' => 'DVD',
    '05' => 'TV/SAT',
    '10' => 'VIDEO 1',
    '12' => 'MULTI CH IN',     # [1]
    '14' => 'VIDEO 2',
    '15' => 'DVR/BDR',
    '17' => 'iPod/USB',
    '19' => 'HDMI 1',
    '20' => 'HDMI 2',          # [2]   but the vsx-1021 does respond using HDMI 2-5. Probably mapped to others.
    '21' => 'HDMI 3',          # [2]
    '22' => 'HDMI 4',          # [2]
    '23' => 'HDMI 5',          # [2]
    '24' => 'HDMI 6',          # [1]
    '25' => 'BD',
    '26' => 'Home Media Gallery (Internet Radio)',
    '27' => 'SIRIUS',
    '33' => 'Adapter Port'
  }

  # [1] - my vsx-1021 doesn't support these devices; get bad command
  # [2} - these return in spite of the docs saying no;  mapped to other device?


  attr_reader :devices

  def initialize vsx
    @vsx = vsx
    @devices = find_devices()
  end

  # TODO:  we'd like to blast a set of queries all at once to the VSX,  but our primitive read doesn't work with multiple responses - but see scripts/repl.

  def find_devices
    devs = []
    INPUT_CODES.keys.each do |code|
      matches = @vsx.cmd("?RGB#{code}", /^RGB([0-9]{2})([01])(.*)$/)
      next if matches.empty?
      devs.push( { :code => matches[0],  :device => INPUT_CODES[matches[0]],   :renamed => matches[1] == '1',  :name => matches[2].strip  } )
    end
    return devs
  end

  def report
    info = selected
    case
    when info[:device].nil? then nil
    when info[:renamed]     then "#{info[:name]} (#{info[:device]})"
    else
      info[:device]
    end
  end

  def selected
    code = @vsx.cmd('?F', /FN(\d+)/).shift
    @devices.each do |rec|
      return rec if rec[:code] == code
    end
    return {}
  end

  def selected= value
    code = nil
    record = nil
    @devices.each do |rec|
      if (value == rec[:code] or value == rec[:device] or value == rec[:name])
        code = rec[:code]
        record = rec
      end
    end
    return nil unless record
    @vsx.cmd("#{code}FN", /FN(#{code})/)
    return selected
  end


end
