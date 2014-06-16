### TODO: implement CHANNEL LEVEL CL* commands (command sheet 1 line 418)

### TODO: implement TONE CONTROL B*/T* commands (command sheet 1 line 346)

### TODO: timeout gracefully.  Unsupported commands can hang connection (why isn't existing timeout mechanism not working in that case?)

### TODO: add command logging

### TODO: add some design notes - esp. that we never raise on
### unexpected data, we return nil or empty arrays. Client classes
### should simply pass these values up the chain - it's up to the
### application to determine what to do on missing data (this makes
### sense, since we don't want to accidently turn the volume all the
### way up and have an exception leave the speakers disintergrating...

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), './lib/'))
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '../lib/'))

require 'socket'
require 'time'
require 'timeout'
require 'vsx-exceptions'
require 'vsx-utils'
require 'volume-control'
require 'tuner-control'
require 'dvd-control'
require 'input-control'

class Vsx
  include Timeout

  DEBUG = false

  CONNECTION_TIMEOUT = 5.0     # seconds
  DEFAULT_READ_TIMEOUT = 0.35  # seconds
  PORT_A = 8102
  PORT_B = 23
  DEFAULT_RETRYS = 5

  ### TODO: listening modes should get moved to an appropriate class....

  # The listening mode codes can be used to set listening mode; we can
  # instead  get listening mode responses more suitable for display (see
  # DECODE_LISTENING_DISPLAY)

  DECODE_LISTENING_MODE = {
    '0001' => 'STEREO (cyclic)',
    '0010' => 'STANDARD',
    '0009' => 'STEREO (direct set)',
    '0011' => '(2ch source)',                                          # [1]
    '0013' => 'PRO LOGIC2 MOVIE',
    '0018' => 'PRO LOGIC2x MOVIE',
    '0014' => 'PRO LOGIC2 MUSIC',
    '0019' => 'PRO LOGIC2x MUSIC',
    '0015' => 'PRO LOGIC2 GAME',
    '0020' => 'PRO LOGIC2x GAME',
    '0031' => 'PRO LOGIC2z HEIGHT',
    '0032' => 'WIDE SURROUND MOVIE',
    '0033' => 'WIDE SURROUND MUSIC',
    '0012' => 'PRO LOGIC',
    '0016' => 'Neo:6 CINEMA',
    '0017' => 'Neo:6 MUSIC',
    '0028' => 'XM HD SURROUND',                                        # [1]
    '0029' => 'NEURAL SURROUND',
    '0037' => 'Neo:X CINEMA',                                          # [1]
    '0038' => 'Neo:X MUSIC',                                           # [1]
    '0039' => 'Neo:X GAME',                                            # [1]
    '0040' => 'NEURAL SURROUND+Neo:X CINEMA',                          # [1]
    '0041' => 'NEURAL SURROUND+Neo:X MUSIC',                           # [1]
    '0042' => 'NEURAL SURROUND+Neo:X GAME',                            # [1]
    '0021' => '(Multi ch source)',
    '0022' => '(Multi ch source)+DOLBY EX',
    '0023' => '(Multi ch source)+PRO LOGIC2x MOVIE',
    '0024' => '(Multi ch source)+PRO LOGIC2x MUSIC',
    '0034' => '(Multi-ch Source)+PRO LOGIC2z HEIGHT',
    '0035' => '(Multi-ch Source)+WIDE SURROUND MOVIE',
    '0036' => '(Multi-ch Source)+WIDE SURROUND MUSIC',
    '0025' => '(Multi ch source)DTS-ES Neo:6',
    '0026' => '(Multi ch source)DTS-ES matrix',
    '0027' => '(Multi ch source)DTS-ES discrete',
    '0030' => '(Multi ch source)DTS-ES 8ch discrete',
    '0043' => '(Multi ch source)DTS-ES Neo:X',                         # [1]
    '0100' => 'ADVANCED SURROUND (cyclic)',
    '0101' => 'ACTION',
    '0103' => 'DRAMA',
    '0102' => 'SCI-FI',
    '0105' => 'MONO FILM',
    '0104' => 'ENTERTAINMENT SHOW',
    '0106' => 'EXPANDED THEATER',
    '0116' => 'TV SURROUND',
    '0118' => 'ADVANCED GAME',
    '0117' => 'SPORTS',
    '0107' => 'CLASSICAL',
    '0110' => 'ROCK/POP',
    '0109' => 'UNPLUGGED',
    '0112' => 'EXTENDED STEREO',
    '0003' => 'Front Stage Surround Advance Focus',
    '0004' => 'Front Stage Surround Advance Wide',
    '0153' => 'RETRIEVER AIR',
    '0113' => 'PHONES SURROUND',
    '0050' => 'THX (cyclic)',                                          # [1]
    '0051' => 'PROLOGIC + THX CINEMA',                                 # [1]
    '0052' => 'PL2 MOVIE + THX CINEMA',                                # [1]
    '0053' => 'Neo:6 CINEMA + THX CINEMA',                             # [1]
    '0054' => 'PL2x MOVIE + THX CINEMA',                               # [1]
    '0092' => 'PL2z HEIGHT + THX CINEMA',                              # [1]
    '0055' => 'THX SELECT2 GAMES',                                     # [1]
    '0068' => 'THX CINEMA (for 2ch)',                                  # [1]
    '0069' => 'THX MUSIC (for 2ch)',                                   # [1]
    '0070' => 'THX GAMES (for 2ch)',                                   # [1]
    '0071' => 'PL2 MUSIC + THX MUSIC',                                 # [1]
    '0072' => 'PL2x MUSIC + THX MUSIC',                                # [1]
    '0093' => 'PL2z HEIGHT + THX MUSIC',                               # [1]
    '0073' => 'Neo:6 MUSIC + THX MUSIC',                               # [1]
    '0074' => 'PL2 GAME + THX GAMES',                                  # [1]
    '0075' => 'PL2x GAME + THX GAMES',                                 # [1]
    '0094' => 'PL2z HEIGHT + THX GAMES',                               # [1]
    '0076' => 'THX ULTRA2 GAMES',                                      # [1]
    '0077' => 'PROLOGIC + THX MUSIC',                                  # [1]
    '0078' => 'PROLOGIC + THX GAMES',                                  # [1]
    '0201' => 'Neo:X CINEMA + THX CINEMA',                             # [1]
    '0202' => 'Neo:X MUSIC + THX MUSIC',                               # [1]
    '0203' => 'Neo:X GAME + THX GAMES',                                # [1]
    '0056' => 'THX CINEMA (for multi ch)',                             # [1]
    '0057' => 'THX SURROUND EX (for multi ch)',                        # [1]
    '0058' => 'PL2x MOVIE + THX CINEMA (for multi ch)',                # [1]
    '0095' => 'PL2z HEIGHT + THX CINEMA (for multi ch)',               # [1]
    '0059' => 'ES Neo:6 + THX CINEMA (for multi ch)',                  # [1]
    '0060' => 'ES MATRIX + THX CINEMA (for multi ch)',                 # [1]
    '0061' => 'ES DISCRETE + THX CINEMA (for multi ch)',               # [1]
    '0067' => 'ES 8ch DISCRETE + THX CINEMA (for multi ch)',           # [1]
    '0062' => 'THX SELECT2 CINEMA (for multi ch)',                     # [1]
    '0063' => 'THX SELECT2 MUSIC (for multi ch)',                      # [1]
    '0064' => 'THX SELECT2 GAMES (for multi ch)',                      # [1]
    '0065' => 'THX ULTRA2 CINEMA (for multi ch)',                      # [1]
    '0066' => 'THX ULTRA2 MUSIC (for multi ch)',                       # [1]
    '0079' => 'THX ULTRA2 GAMES (for multi ch)',                       # [1]
    '0080' => 'THX MUSIC (for multi ch)',                              # [1]
    '0081' => 'THX GAMES (for multi ch)',                              # [1]
    '0082' => 'PL2x MUSIC + THX MUSIC (for multi ch)',                 # [1]
    '0096' => 'PL2z HEIGHT + THX MUSIC (for multi ch)',                # [1]
    '0083' => 'EX + THX GAMES (for multi ch)',                         # [1]
    '0097' => 'PL2z HEIGHT + THX GAMES (for multi ch)',                # [1]
    '0084' => 'Neo:6 + THX MUSIC (for multi ch)',                      # [1]
    '0085' => 'Neo:6 + THX GAMES (for multi ch)',                      # [1]
    '0086' => 'ES MATRIX + THX MUSIC (for multi ch)',                  # [1]
    '0087' => 'ES MATRIX + THX GAMES (for multi ch)',                  # [1]
    '0088' => 'ES DISCRETE + THX MUSIC (for multi ch)',                # [1]
    '0089' => 'ES DISCRETE + THX GAMES (for multi ch)',                # [1]
    '0090' => 'ES 8CH DISCRETE + THX MUSIC (for multi ch)',            # [1]
    '0091' => 'ES 8CH DISCRETE + THX GAMES (for multi ch)',            # [1]
    '0204' => 'Neo:X + THX CINEMA (for multi ch)',                     # [1]
    '0205' => 'Neo:X + THX MUSIC (for multi ch)',                      # [1]
    '0206' => 'Neo:X + THX GAMES (for multi ch)',                      # [1]
    '0005' => 'AUTO SURR/STREAM DIRECT (cyclic)',
    '0006' => 'AUTO SURROUND',
    '0151' => 'Auto Level Control (A.L.C.)',
    '0007' => 'DIRECT',
    '0008' => 'PURE DIRECT',
    '0152' => 'OPTIMUM SURROUND',                                     # [1]
  }

  # listening display codes are not usable as paramters to the vsx device

  DECODE_LISTENING_DISPLAY = {
    '0101' => '[)(]PLIIx MOVIE',
    '0102' => '[)(]PLII MOVIE',
    '0103' => '[)(]PLIIx MUSIC',
    '0104' => '[)(]PLII MUSIC',
    '0105' => '[)(]PLIIx GAME',
    '0106' => '[)(]PLII GAME',
    '0107' => '[)(]PROLOGIC',
    '0108' => 'Neo:6 CINEMA',
    '0109' => 'Neo:6 MUSIC',
    '010a' => 'XM HD Surround',
    '010b' => 'NEURAL SURR',
    '010c' => '2ch Straight Decode',
    '010d' => '[)(]PLIIz HEIGHT',
    '010e' => 'WIDE SURR MOVIE',
    '010f' => 'WIDE SURR MUSIC',
    '0110' => 'STEREO',
    '0111' => 'Neo:X CINEMA',
    '0112' => 'Neo:X MUSIC',
    '0113' => 'Neo:X GAME',
    '0114' => 'NEURAL SURROUND+Neo:X CINEMA',
    '0115' => 'NEURAL SURROUND+Neo:X MUSIC',
    '0116' => 'NEURAL SURROUND+Neo:X GAMES',
    '1101' => '[)(]PLIIx MOVIE',
    '1102' => '[)(]PLIIx MUSIC',
    '1103' => '[)(]DIGITAL EX',
    '1104' => 'DTS +Neo:6 / DTS-HD +Neo:6',
    '1105' => 'ES MATRIX',
    '1106' => 'ES DISCRETE',
    '1107' => 'DTS-ES 8ch',
    '1108' => 'multi ch Straight Decode',
    '1109' => '[)(]PLIIz HEIGHT',
    '110a' => 'WIDE SURR MOVIE',
    '110b' => 'WIDE SURR MUSIC',
    '110c' => 'ES Neo:X',
    '0201' => 'ACTION',
    '0202' => 'DRAMA',
    '0203' => 'SCI-FI',
    '0204' => 'MONOFILM',
    '0205' => 'ENT.SHOW',
    '0206' => 'EXPANDED',
    '0207' => 'TV SURROUND',
    '0208' => 'ADVANCEDGAME',
    '0209' => 'SPORTS',
    '020a' => 'CLASSICAL',
    '020b' => 'ROCK/POP',
    '020c' => 'UNPLUGGED',
    '020d' => 'EXT.STEREO',
    '020e' => 'PHONES SURR.',
    '020f' => 'FRONT STAGE SURROUND ADVANCE FOCUS',
    '0210' => 'FRONT STAGE SURROUND ADVANCE WIDE',
    '0211' => 'SOUND RETRIEVER AIR',
    '0301' => '[)(]PLIIx MOVIE +THX',
    '0302' => '[)(]PLII MOVIE +THX',
    '0303' => '[)(]PL +THX CINEMA',
    '0304' => 'Neo:6 CINEMA +THX',
    '0305' => 'THX CINEMA',
    '0306' => '[)(]PLIIx MUSIC +THX',
    '0307' => '[)(]PLII MUSIC +THX',
    '0308' => '[)(]PL +THX MUSIC',
    '0309' => 'Neo:6 MUSIC +THX',
    '030a' => 'THX MUSIC',
    '030b' => '[)(]PLIIx GAME +THX',
    '030c' => '[)(]PLII GAME +THX',
    '030d' => '[)(]PL +THX GAMES',
    '030e' => 'THX ULTRA2 GAMES',
    '030f' => 'THX SELECT2 GAMES',
    '0310' => 'THX GAMES',
    '0311' => '[)(]PLIIz +THX CINEMA',
    '0312' => '[)(]PLIIz +THX MUSIC',
    '0313' => '[)(]PLIIz +THX GAMES',
    '0314' => 'Neo:X CINEMA + THX CINEMA',
    '0315' => 'Neo:X MUSIC + THX MUSIC',
    '0316' => 'Neo:X GAMES + THX GAMES',
    '1301' => 'THX Surr EX',
    '1302' => 'Neo:6 +THX CINEMA',
    '1303' => 'ES MTRX +THX CINEMA',
    '1304' => 'ES DISC +THX CINEMA',
    '1305' => 'ES 8ch +THX CINEMA',
    '1306' => '[)(]PLIIx MOVIE +THX',
    '1307' => 'THX ULTRA2 CINEMA',
    '1308' => 'THX SELECT2 CINEMA',
    '1309' => 'THX CINEMA',
    '130a' => 'Neo:6 +THX MUSIC',
    '130b' => 'ES MTRX +THX MUSIC',
    '130c' => 'ES DISC +THX MUSIC',
    '130d' => 'ES 8ch +THX MUSIC',
    '130e' => '[)(]PLIIx MUSIC +THX',
    '130f' => 'THX ULTRA2 MUSIC',
    '1310' => 'THX SELECT2 MUSIC',
    '1311' => 'THX MUSIC',
    '1312' => 'Neo:6 +THX GAMES',
    '1313' => 'ES MTRX +THX GAMES',
    '1314' => 'ES DISC +THX GAMES',
    '1315' => 'ES 8ch +THX GAMES',
    '1316' => '[)(]EX +THX GAMES',
    '1317' => 'THX ULTRA2 GAMES',
    '1318' => 'THX SELECT2 GAMES',
    '1319' => 'THX GAMES',
    '131a' => '[)(]PLIIz +THX CINEMA',
    '131b' => '[)(]PLIIz +THX MUSIC',
    '131c' => '[)(]PLIIz +THX GAMES',
    '131d' => 'Neo:X + THX CINEMA',
    '131e' => 'Neo:X + THX MUSIC',
    '131f' => 'Neo:X + THX GAMES',
    '0401' => 'STEREO',
    '0402' => '[)(]PLII MOVIE',
    '0403' => '[)(]PLIIx MOVIE',
    '0404' => 'Neo:6 CINEMA',
    '0405' => 'AUTO SURROUND Straight Decode',
    '0406' => '[)(]DIGITAL EX',
    '0407' => '[)(]PLIIx MOVIE',
    '0408' => 'DTS +Neo:6',
    '0409' => 'ES MATRIX',
    '040a' => 'ES DISCRETE',
    '040b' => 'DTS-ES 8ch',
    '040c' => 'XM HD Surround',
    '040d' => 'NEURAL SURR',
    '040e' => 'RETRIEVER AIR',
    '040f' => 'Neo:X CINEMA',
    '0410' => 'ES Neo:X',
    '0501' => 'STEREO',
    '0502' => '[)(]PLII MOVIE',
    '0503' => '[)(]PLIIx MOVIE',
    '0504' => 'Neo:6 CINEMA',
    '0505' => 'ALC Straight Decode',
    '0506' => '[)(]DIGITAL EX',
    '0507' => '[)(]PLIIx MOVIE',
    '0508' => 'DTS +Neo:6',
    '0509' => 'ES MATRIX',
    '050a' => 'ES DISCRETE',
    '050b' => 'DTS-ES 8ch',
    '050c' => 'XM HD Surround',
    '050d' => 'NEURAL SURR',
    '050e' => 'RETRIEVER AIR',
    '050f' => 'Neo:X CINEMA',
    '0510' => 'ES Neo:X',
    '0601' => 'STEREO',
    '0602' => '[)(]PLII MOVIE',
    '0603' => '[)(]PLIIx MOVIE',
    '0604' => 'Neo:6 CINEMA',
    '0605' => 'STREAM DIRECT NORMAL Straight Decode',
    '0606' => '[)(]DIGITAL EX',
    '0607' => '[)(]PLIIx MOVIE',
    '0608' => '(nothing)',
    '0609' => 'ES MATRIX',
    '060a' => 'ES DISCRETE',
    '060b' => 'DTS-ES 8ch',
    '060c' => 'Neo:X CINEMA',
    '060d' => 'ES Neo:X',
    '0701' => 'STREAM DIRECT PURE 2ch',
    '0702' => '[)(]PLII MOVIE',
    '0703' => '[)(]PLIIx MOVIE',
    '0704' => 'Neo:6 CINEMA',
    '0705' => 'STREAM DIRECT PURE Straight Decode',
    '0706' => '[)(]DIGITAL EX',
    '0707' => '[)(]PLIIx MOVIE',
    '0708' => '(nothing)',
    '0709' => 'ES MATRIX',
    '070a' => 'ES DISCRETE',
    '070b' => 'DTS-ES 8ch',
    '070c' => 'Neo:X CINEMA',
    '070d' => 'ES Neo:X',
    '0881' => 'OPTIMUM',
    '0e01' => 'HDMI THROUGH',
    '0f01' => 'MULTI CH IN'
  }

  attr_reader :tuner, :volume, :hostname, :dvd, :inputs

  def initialize hostname
    @hostname = hostname
    @port ||= PORT_A

    # For some reason the timeout wrapper doesn't return a socket name error, so let's provoke an exception explicitly

    Socket.gethostbyname(@hostname) unless @hostname =~ %r{^\d{3}\.\d{3}\.\d{3}\.\d{3}$}

    timeout(CONNECTION_TIMEOUT) do
      @socket = TCPSocket::new(@hostname, @port)
    end

    @buff = ''
    @responses = []

    raise NoResponse, "VSX at #{@hostname}:#{@port} did not respond to status check" unless cmd('', /R/).shift

    @tuner   = TunerControl.new(self)
    @volume  = VolumeControl.new(self)
    @dvd     = DVDControl.new(self)
    @inputs  = InputControl.new(self)

  rescue Timeout::Error => e
    raise NoConnection, "Couldn't connect to VSX receiver at #{@hostname}:#{@port}: #{e.message} after #{CONNECTION_TIMEOUT} seconds."

  rescue SocketError => e
    raise NoConnection, "Couldn't locate VSX receiver at #{@hostname}:#{@port}: #{e.message}."

  rescue Errno::ECONNREFUSED => e   # The VSX only handles one connection at a time.
    if @port == PORT_A
       @port  = PORT_B
       retry
    else
       raise NoConnection, "Couldn't connect to VSX receiver at #{@hostname}:#{@port}: #{e.message}."
    end
  end

  def to_s
    "#<VSX:#{self.object_id.to_s(16)} #{@hostname}:#{@port}>"
  end

  def report
    case status_helper
    when :off
      puts "Powered off"

    when :unreachable
      puts "VSX receiver is unreachable"

    when :on
      puts 'Input Devices: ' + inputs.devices.map { |rec| rec[:name] }.join(',  ')
      puts 'Selected Input: '  + inputs.report
      puts 'Volume: ' + volume.report
      puts 'Tuner: '  + tuner.report
      puts 'Listening Mode: ' + listening_mode_display + ',  more exactly ' + listening_mode_name
      puts 'Speakers: ' +  speakers
      puts 'Audio: ' + audio_status_report
    end
  end

  # returns one of :off, :on, :unreachable

  def on?
    status_helper == :on
  end

  def off?
    status_helper == :off
  end

  def unreachable?
    status_helper == :unreachable
  end

  # Several commands will hang if called inappropriately, e.g. turning
  # the vsx receiver on when it's already on.  We don't want to waste
  # time on timeouts for these cases, so in general we check first (we
  # usually get round-trip responses for a status query in around 100
  # ms, while read timeouts take three times that (check the current
  # value with DEFAULT_READ_TIMEOUT).

  # on() - returns true if we successfully power up or already are
  # powered up, nil otherwise.
  #
  # When the vsx is initialy off, it takes a long time for VSX to warm
  # up (up to five seconds), though the command completes
  # quickly. When we actually are powering up the vsx, the command PO
  # does not get a return message.

  def on
    return true if on?
    cmd('PO')
    return cmd('?P', /PWR[01]/, 10).shift == 'PWR0'
  end

  # off() - turn off the vsx, return true on success power-down or if we
  # are already powered-down.

  def off
    return true if off?
    return cmd('PF', /PWR[01]/).shift == 'PWR1'
  end

  # display()
  #
  # Return what's on the display of the vsx receiver, or, if unavailable, nil

  def display
    encoded_asterisks, encoded_text = cmd('?FL', /^FL([0-9A-F]{2})([0-9A-F]{28})$/)
    return nil unless encoded_asterisks && encoded_text

    str = case encoded_asterisks
          when '00' then '  '
          when '01' then ' *'
          when '02' then '* '
          when '03' then '**'
          else; ''
          end

    return str + encoded_text.unpack('a2' * 14).map { |c| c.to_i(16).chr }.join
  end

  def speakers
    return case cmd('?SPK', /^SPK([0-3])$/).shift
           when '0' then 'Off'
           when '1' then 'A'
           when '2' then 'B'
           when '3' then 'A+B'
           end
  end

  # gets listening_mode

  def listening_mode
    return cmd('?S', /^SR([0-9]{4})$/).shift
  end

  # listening_mode = CODE
  #
  # Some of the codes are not sticky, so '0001' initially sets to
  # '0001' => 'STEREO (cyclic)' but quickly resets to '0009' =>
  # 'STEREO (direct set)'.  '0010' => 'STANDARD' works similarly.

  def listening_mode= value
    cmd("#{value}SR", /^SR([0-9]{4})$/).shift
  end

  def listening_mode_name
    return DECODE_LISTENING_MODE[listening_mode]
  end

  # Since the codes from display listening mode commands aren't usable
  # for setting, we only have a decode method.

  def listening_mode_display
    return DECODE_LISTENING_DISPLAY[cmd('?L', /^LM(\d{4})$/).shift]
  end

  def audio_status

    input_signal_code, input_frequency_code, input_channels_code, output_channels_code \
       = cmd('?AST', /^AST(..)(..)(.{16}).....(.{13}).....$/)

    input_signal = case input_signal_code
                   when '00' then 'analog'
                   when '01' then 'analog'
                   when '02' then 'analog'
                   when '03' then 'PCM'
                   when '04' then 'PCM'
                   when '05' then 'DOLBY DIGITAL'
                   when '06' then 'DTS'
                   when '07' then 'DTS-ES Matrix'
                   when '08' then 'DTS-ES Discrete'
                   when '09' then 'DTS 96/24'
                   when '10' then 'DTS 96/24 ES Matrix'
                   when '11' then 'DTS 96/24 ES Discrete'
                   when '12' then 'MPEG-2 AAC'
                   when '13' then 'WMA9 Pro'
                   when '14' then 'DSD->PCM'
                   when '15' then 'HDMI pass-through'
                   when '16' then 'DOLBY DIGITAL PLUS'
                   when '17' then 'DOLBY TrueHD'
                   when '18' then 'DTS EXPRESS'
                   when '19' then 'DTS-HD Master Audio'
                   when '20' then 'DTS-HD High Resolution'
                   when '21' then 'DTS-HD High Resolution'
                   when '22' then 'DTS-HD High Resolution'
                   when '23' then 'DTS-HD High Resolution'
                   when '24' then 'DTS-HD High Resolution'
                   when '25' then 'DTS-HD High Resolution'
                   when '26' then 'DTS-HD High Resolution'
                   when '27' then 'DTS-HD Master Audio'
                   else
                     "signal code #{input_signal_code}"
                   end

    input_frequency = case input_frequency_code
                      when '00' then '32 kHz'
                      when '01' then '44.1 kHz'
                      when '02' then '48 kHz'
                      when '03' then '88.2 kHz'
                      when '04' then '96 kHz'
                      when '05' then '176.4 kHz'
                      when '06' then '192 kHz'
                      else
                        "frequency code #{input_frequency_code}"
                      end

    # Set up arrays of strings describing the channels, e.g.
    # [ 'L', 'R', 'SW' ] is common for the output_channels_driven variable,
    # where L == left, C == center, SW == subwoofer, SL == left surround,
    # SBR == right surround back, etc.

    input_channel_names  = [ 'L', 'C', 'R', 'SL', 'SR', 'SBL', 'S', 'SBR', 'LFE', 'FHL', 'FHR', 'FWL', 'FWR', 'XL', 'XC', 'XR' ]
    input_channels_supplied = decode_status_string(input_channels_code, input_channel_names)

    output_channel_names = [ 'L', 'C', 'R', 'SL', 'SR', 'SBL', 'SB', 'SBR', 'SW', 'FHL', 'FHR', 'FWL', 'FWR' ]
    output_channels_driven = decode_status_string(output_channels_code, output_channel_names)

    return {
      :input_channels  => input_channels_supplied,
      :input_frequency => input_frequency,
      :input_signal    => input_signal,
      :output_channels => output_channels_driven
    }

  end

  def audio_status_report

    data = audio_status

    report = data[:input_signal] + " input signal at " + data[:input_frequency]

    if data[:input_channels].length > 0
      report += " with " + data[:input_channels].join(',') + " channels"
    end

    if data[:output_channels].length > 0
      report += '; driving speaker channels ' + data[:output_channels].join(',')
    end

    report
  end

  # cmd(REQUEST, [ EXPECTED ], [ TRYS ]) sends a command to the VSX
  # receiver.
  #
  # Given the command REQUEST and an optional regular expression
  # EXPECTED to match against the response, send the REQUEST to the
  # VSX and read the queued responses until either the EXPECTED
  # response is recieved or until there's nothing left to read.  We do
  # this because there may be many irrelevant responses to our
  # REQUEST; in fact, we may get arbitrary responses caused by
  # external changes to the receiver, as when someone is adjusting the
  # volume control dial.
  #
  # Our reads will wait up to DEFAULT_READ_TIMEOUT (350 milliseconds
  # at the time of this writing). A timeout rarely occurs, however.
  #
  # We always return an array, empty if there's no match against
  # EXPECTED, or with one or more matched strings (e.g., the tuner
  # status command, /^FR([FA])(\d+)$/, when matched returns the band
  # and frequency as an array of strings).  When using the default
  # regular expression /.*/, the entirety of the first response will
  # be returned as the only element of the array. However, there may
  # be no response (the power-up command, PO, is one such), so even
  # the default regular expression may return an empy array.

  def cmd request, expected = /.*/, trys = DEFAULT_RETRYS

    # clear any old queued responses before we issue our request:

    self.drain
    self.write request

    while response = self.read
      trys -= 1
      return [] if trys <= 0                # could be thowing away a real response, but too bad, too late...
      matches = expected.match(response)
      next if matches.nil?
      return  matches.to_a if matches.length == 1
      return  matches.captures
    end
    return []
  end

  def close
    @socket.close unless @socket.closed?
  end

  protected

  # write(STR)
  #
  # Send the command STR to the vsx receiver.

  def write str = ""
    @socket.write str + "\r\n"
  end

  # read([ TIMEOUT ])  attempt to read a response from the vsx receiver
  # with optionally specified TIMEOUT.
  #
  # We maintain a queue @RESPONSES (an array) of completed messages from
  # the vsx receiver, as well as the string @BUFFER of partial
  # responses. Wait up to TIMEOUT seconds if specified, or use
  # DEFAULT_READ_TIMEOUT.  Round-trip request/response times are
  # typically 100 milliseconds.

  def read timeout = DEFAULT_READ_TIMEOUT
    return @responses.shift unless @responses.empty?

    results = select([ @socket ], nil, nil, timeout)

    @buff += @socket.recv(4 * 1024) if (results and results[0].include? @socket)  # results nil on timeout

    if @buff =~ /^(.*\r\n)(.*)$/m       # network responses can split at odd boundries; check for completed messages ending with \r\n.
      @buff = $2                        # save potential partial response for later..
      @responses += $1.split(/\r\n/)    # and sock away all of the completed responses
    end

    @responses.shift  # return next queued message or nil if we've timed out
  end

  # drain() removes any queued output.
  #
  # The vsx can produce status messages at any time (e.g., someone
  # adjusts volume), or multiple status messages (on switching input,
  # say) so we need this to clear old responses before we attempt a
  # command/response.

  def drain
    # while resp = self.read(0.05)

    while resp = self.read(0.005)    # not sure how low I can go here,  this really speeds things up.
    end
  end

  def status_helper
    resp = cmd('?P', /PWR[01]/).shift
    return :on  if resp == 'PWR0'
    return :off if resp == 'PWR1'
    return :unreachable
  rescue => e
    return :unreachable
  end

  # code_unwrapper STR
  #
  # Helper for unpacking codes, used in decode_status_string()
  #
  # Take a string, e.g. '0110', and return an array of booleans, true
  # wherever a character is '1', here [ false, true, true, false ]

  def code_unwrapper str
    str.unpack('a' * str.length).map { |code| code == '1' }
  end

  # decode_status_string CODE_STRING, DOC_ARRAY
  #
  # Help for unpacking ASCII status codes in a string, and returning
  # associated doc strings, for example:
  #
  #   CODE_STRING = '101', DOC_ARRAY = [ 'one', 'two', 'three' ], returns [ 'one', 'three' ]
  #
  # That is, return the elements from DOC_ARRAY that correspond to
  # positions in CODE_STRING with characters of '1'.

  def decode_status_string code_string, doc_array
    results = []
    code_unwrapper(code_string).each do |bool|
      doco = doc_array.shift
      results.push doco if bool
    end
    return results
  end

end # of class Vsx
