#!/usr/bin/env ruby

### TODO: add command logging

### TODO: add some design notes - esp. that we never raise on
### unexpected data, we return nil or empty arrays. Client classes
### should simply pass these values up the chain - it's up to the
### application to determine what to do on missing data (this makes
### sense, since we don't want to accidently turn the volume all the
### way up and have an exception leave the speakers to disintergrate...

### TODO: The vsx handles only one connection at time with this code, but
### the android remote control is able to connect even when this code is
### connected... how?


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

class Vsx
  include Timeout

  DEBUG = false

  CONNECTION_TIMEOUT = 2.0     # seconds
  DEFAULT_READ_TIMEOUT = 0.35  # seconds
  PORT = 23
  DEFAULT_RETRYS = 5

  # [1] means not present on VSX 1021-k

  DECODE_INPUTS = {
    '00' => 'PHONO',           # [1]
    '01' => 'CD',
    '02' => 'TUNER',
    '03' => 'CD-R/TAPE',
    '04' => 'DVD',
    '05' => 'TV/SAT',
    '10' => 'Video 1',
    '12' => 'MULTI CH IN',     # [1]
    '14' => 'Video 2',
    '15' => 'DVR/BDR',
    '17' => 'iPod/USB',
    '19' => 'HDMI 1',
    '20' => 'HDMI 2',          # [1]
    '21' => 'HDMI 3',          # [1]
    '22' => 'HDMI 4',          # [1]
    '23' => 'HDMI 5',          # [1]
    '24' => 'HDMI 6',          # [1]
    '25' => 'BD',
    '26' => 'Home Media Gallery (Internet Radio)',
    '27' => 'SIRIUS',
    '31' => 'HDMI (cyclic)',
    '33' => 'Adapter Port'
  }

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
  
  attr_reader :tuner, :volume, :hostname, :dvd

  def initialize hostname
    @hostname = hostname
    
    # For some reason the timeout wrapper doesn't return a socket name error, so let's check (caught in rescue).
    
    Socket.gethostbyname(@hostname) unless @hostname =~ %r{^\d{3}\.\d{3}\.\d{3}\.\d{3}$}
    
    timeout(CONNECTION_TIMEOUT) do
      @socket = TCPSocket::new(@hostname, PORT)
    end
    
    @buff = ''
    @responses = []
    
    raise NoResponse, "VSX at #{@hostname}:#{PORT} did not respond to status check" unless cmd('', /R/).shift
    
    @tuner  = TunerControl.new(self)
    @volume = VolumeControl.new(self)
    @dvd    = DVDControl.new(self)
    
  rescue Timeout::Error => e
    raise NoConnection, "Couldn't connect to VSX receiver at #{@hostname}:#{PORT}: #{e.message} after #{CONNECTION_TIMEOUT} seconds."
    
  rescue SocketError => e
    raise NoConnection, "Couldn't locate VSX receiver at #{@hostname}:#{PORT}: #{e.message}."
    
  rescue Errno::ECONNREFUSED => e   # The VSX only handles one connection at a time.
    raise NoConnection, "VSX receiver at #{@hostname}:#{PORT} not listening: #{e.message}."
  end
  
  def to_s
    "#<VSX:#{self.object_id} #{@hostname}:#{PORT}>"
  end
  
  
  def report

    case status_helper
      
    when :off
      puts "Powered off"
    
    when :unreachable
      puts "VSX receiver is unreachable"

    when :on
      puts 'Input: '  + get_input_name
      puts 'Volume: ' + volume.report
      puts 'Tuner: '  + tuner.report
      puts 'Listening Mode: ' + listening_profile
      puts 'Speakers: ' +  speakers
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

  # TODO: need to rethink what on/off returns; also need on? and off?

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

  # TODO: need a friendlier version of this...

  # set_input(CODE) changes the input device used by the vsx
  # receiver. CODEs indicate devices such as tuner ('02'), dvd ('04),
  # etc.  This is used primarily by controllers (TunerControl,
  # DVDControl, etc) in their Control#select method.  See the
  # DECODE_INPUTS hash for the complete list.

  def set_input code
    return code if get_input == code
    return cmd("#{code}FN", /FN(#{code})/).shift == code
  end

  def get_input
    return cmd('?F', /FN(\d+)/).shift
  end

  def get_input_name
    return DECODE_INPUTS[get_input]
  end

  # display()
  #
  # Return what's on the display of the vsx receiver, or, if unavailable, nil
  
  def display
    encoded_asterisks, encoded_text = cmd('?FL', /^FL([0-9A-F]{2})([0-9A-F]{28})$/)
    return nil unless encoded_asterisks && encoded_text
    
    str = case encoded_asterisks
          when '00': '  '
          when '01': ' *'
          when '02': '* '
          when '03': '**'
          else; ''
          end
    
    return str + encoded_text.unpack('a2' * 14).map { |c| c.to_i(16).chr }.join
  end

  def speakers
    return case cmd('?SPK', /^SPK([0-3])$/).shift
           when '0': 'Off'
           when '1': 'A'
           when '2': 'B'
           when '3': 'A+B'
           end
  end

  def listening_profile
    return DECODE_LISTENING_MODE[cmd('?S', /^SR([0-9]{4})$/).shift]
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
  # volume control.
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
      return [] if trys <= 0
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


  ##### protected

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
    while resp = self.read(0.05)
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

end
