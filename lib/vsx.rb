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

  CONNECTION_TIMEOUT = 2.0     # seconds
  DEBUG = false
  DEFAULT_READ_TIMEOUT = 0.35  # seconds
  PORT = 23
  DEFAULT_RETRYS = 5
  DECODE_INPUTS = {
    '00' => 'PHONO',           # not present on VSX 1021-k
    '01' => 'CD',
    '02' => 'TUNER',
    '03' => 'CD-R/TAPE',
    '04' => 'DVD',
    '05' => 'TV/SAT',
    '10' => 'Video 1',
    '12' => 'MULTI CH IN',     # not present on VSX 1021-k
    '14' => 'Video 2',
    '15' => 'DVR/BDR',
    '17' => 'iPod/USB',
    '19' => 'HDMI 1',
    '20' => 'HDMI 2',          # not present on VSX 1021-k
    '21' => 'HDMI 3',          # not present on VSX 1021-k
    '22' => 'HDMI 4',          # not present on VSX 1021-k
    '23' => 'HDMI 5',          # not present on VSX 1021-k
    '24' => 'HDMI 6',          # not present on VSX 1021-k
    '25' => 'BD',
    '26' => 'Home Media Gallery (Internet Radio)',
    '27' => 'SIRIUS',
    '31' => 'HDMI (cyclic)',
    '33' => 'Adapter Port'
  }


  attr_reader :tuner, :volume, :hostname, :dvd

  def initialize hostname
    @hostname = hostname

    # for some reason timeout wrapper doesn't return a socket name error, so let's check here:

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


  # returns one of :off, :on, :unreachable

  def status
    resp = cmd('?P', /PWR[01]/).shift
    return :on  if resp == 'PWR0'
    return :off if resp == 'PWR1'
    return :unreachable
  rescue => e
    return :unreachable
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
    return true if status == :on
    cmd('PO')
    return cmd('?P', /PWR[01]/, 10).shfit == 'PWR0'
  end


  # off() - turn off the vsx, return true on success power-down or if we
  # are already powered-down.

  def off
    return true if status == :off
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
    @socket.close
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

  # drain() removes any queued output
  #
  # The vsx can produce status messages at
  # anytime (e.g., someone adjusts volume), or multiple status
  # messages (on switching input, say) so we need this to clear old
  # responses before we attempt a command/response.

  def drain
    while resp = self.read(0.05)
    end
  end

end
