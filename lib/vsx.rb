#!/usr/bin/env ruby

### TODO: add command logging 

### TODO: add some design notes - esp. that we never raise on
### unexpected data, we return nil or empty arrays. Client classes
### should simply pass these values up the chain - it's up to the
### application to determine what to do on missing data (this makes
### sense, since we don't want to accidently turn the volume all the
### way up and have an exception leave the speakers to disintergrate...

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), './lib/'))
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '../lib/'))

require 'socket'
require 'time'
require 'vsx-exceptions'
require 'vsx-utils'
require 'volume-control'
require 'tuner-control'
require 'dvd-control'

class Vsx
  DEBUG = true
  DEFAULT_TIMEOUT = 0.5
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
    @socket = TCPSocket::new(@hostname, PORT)
    @buff = ''
    @responses = []

    raise NoResponse, "VSX at #{@hostname} did not respond to status check" unless cmd('', /R/)[0]

    @tuner  = TunerControl.new(self)
    @volume = VolumeControl.new(self)
    @dvd    = DVDControl.new(self)

  rescue SocketError => e
    raise NoConnection, "Can't locate VSX receiver at #{@hostname}: #{e.message}."

  rescue Errno::ECONNREFUSED => e   # among other things, the VSX only handles one connection at a time.
    raise NoConnection, "VSX receiver at #{@hostname} not listening: #{e.message}."
  end

  def to_s
    "#<VSX:#{self.object_id} #{@hostname}:#{PORT}>"
  end

  # returns one of :off, :on, :unreachable

  def status
    resp = cmd('?P', /PWR[01]/)[0]
    STDERR.puts "response is #{resp.inspect}"
    return :on  if resp == 'PWR0'
    return :off if resp == 'PWR1'
    return :unreachable 
  rescue => e
    return :unreachable
  end

  # TODO: need to rethink what on/off returns; also need on? and off?

  # Turn on the VSX; when it's off, this takes a long time to
  # respond. The initial command PO does not get a return value.

  def on
    return true if status == :on
    cmd('PO')
    return cmd('?P', /PWR[01]/, 10)[0] == 'PWR0'
  end

  # turn off the vsx

  def off
    return true if status == :off
    return cmd('PF', /PWR[01]/)[0] == 'PWR1'
  end

  # input is a code designating the tuner ('02'), dvd ('04), etc.
  # this is used primarily by controllers (TunerControl, DVDControl, etc) in their select methods.

  def set_input value
    return value if get_input == value
    return cmd("#{value}FN", /FN(#{value})/)[0] == value
  end

  def get_input
    return cmd('?F', /FN(\d+)/)[0]
  end

  def get_input_name
    return DECODE_INPUTS[get_input]
  end


  # Given a command request and an optional regular expression to
  # match against the response, send the request to the VSX and read
  # until the expected response is recieved - since there may be many
  # irrelevant responses, we may have to check several (up to
  # DEFAULT_RETRYS, or a specified number). Regardless, we give up
  # when there's nothing left to read.
  #
  # We always return an array, empty if there's no match, or with the
  # matched data.  When using the default regular expression, the
  # entirety of the first response will be returned as the only
  # element of the array. However, there may be no response, so even
  # the default may return an empy array.

  def cmd request, expected = /.*/, trys = DEFAULT_RETRYS

    STDERR.puts "cmd: draining" if DEBUG

    self.drain

    STDERR.puts "cmd: writing #{request}" if DEBUG    

    self.write request

    STDERR.puts "cmd: #{request} =~ #{expected.inspect}" if DEBUG

    while response = self.read
      STDERR.puts "cmd: #{request} count-down #{trys}, get #{translate_response response}" if DEBUG
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

  # protected

  def write str = ""
    @socket.write str + "\r\n"
  end

  def read timeout = DEFAULT_TIMEOUT
    return @responses.shift unless @responses.empty?

    results = select([ @socket ], nil, nil, timeout)

    @buff += @socket.recv(4 * 1024) if (results and results[0].include? @socket)  # results nil on timeout

    if @buff =~ /^(.*\r\n)(.*)$/m        # check for all completed input (ends with CRLF, aka \r\n)
      @buff = $2                        # save potential partial response for later..
      @responses += $1.split(/\r\n/)    # and return all the completed responses 
    end

    @responses.shift
  end


  # remove any queued output - the vsx can produce status messages at
  # anytime (e.g., someone adjusts volume), or multiple messages (on
  # switching input, say) so we need to clear old responses before we
  # attempt a command/response.

  def drain
    while resp = self.read(0.05) 
      STDERR.puts "drain: dropping '#{translate_response resp}'" if DEBUG
    end
  end

end
