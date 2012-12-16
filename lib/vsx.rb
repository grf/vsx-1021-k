#!/usr/bin/env ruby

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), './lib/'))
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '../lib/'))

require 'socket'
require 'time'
require 'vsx-exceptions'
require 'volume-control'
require 'tuner-control'

DEBUG = true        # for info when read innocuously times out, etc
DIAGNOSTICS = false # for timing commands, etc




class Vsx
  DEFAULT_TIMEOUT = 0.5

  attr_reader :tuner, :volume, :hostname

  def initialize hostname

    @hostname = hostname
    @socket = TCPSocket::new(@hostname, 23)
    @buff = ''
    @responses = []

    ### Check to see if it's powered on -- just do status...
    raise NoResponse, "VSX at #{@hostname} did not respond to status check" unless command('', /R/)

    @tuner  = TunerControl.new(self)
    @volume = VolumeControl.new(self)

  rescue SocketError => e
    raise NoConnection, "Can't locate VSX receiver at #{@hostname}: #{e.message}."

  rescue Errno::ECONNREFUSED => e   # among other things, the VSX only handles one connection at a time.
    raise NoConnection, "VSX receiver at #{@hostname} not listening: #{e.message}."

  end

  # returns one of :off, :on, :unreachable

  def status
    resp = command('?P', /PWR[01]/)
    return :on  if resp == 'PWR0'
    return :off if resp == 'PWR1'
    return :unreachable 
  rescue => e
    return :unreachable
  end


  def on
    return if status == :on
    raise NoResponse, "Can't power up VSX receiver at #{@hostname}" unless command('PO', /PWR0/, 1.5)  == 'PWR0'
  end

  def off
    return if status == :off
    raise NoResponse, "Can't power down VSX receiver at #{@hostname}" unless command('PF', /PWR1/, 1.5)  == 'PWR1'
  end

  # given a command request and a regular expression response, send
  # the request to the VSX and read until response is recieved; but we
  # don't wait longer than half a second. Returns nil if timed out.
  # methods calling this need to be aware of nil and throw error if
  # appropriate.

  def command request, response_pattern = /.*/
    self.drain
    self.write request

    response = self.read

    return response if response.nil? or response_pattern =~ response   # nil on timeout, or the expected response
    return nil                                                         # response was unexpected
  end

  # like above, but stricter and expects the regx has match patterns
  # e.g. /^foobar ([09]+)$/.  Returns an array of matched patterns.
  # Throws a# VsxError on any kind of failure.

  def command_matches cmd, regex, error_type

    response = self.command cmd, regex
    raise NoResponse, "No response from VSX receiver at #{@hostname} for #{error_type}" unless response
    matches = regex.match(response).captures
    raise InvalidResponse, "Invalid response from VSX receiver at #{@hostname} for #{error_type}" unless matches
    return matches

  end


  protected

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

  def close
    @socket.close
  end

  # remove any queued output - the vsx can produce status messages at
  # anytime (e.g., someone adjusts volume, so we need to clear stuff
  # before command/response)

  def drain
    while resp = self.read(0.05) do
      STDERR.puts "draining" if DEBUG
    end
  end

end
