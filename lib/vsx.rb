#!/usr/bin/env ruby

### TODO: add command logging

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), './lib/'))
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '../lib/'))

require 'socket'
require 'time'
require 'vsx-exceptions'
require 'volume-control'
require 'tuner-control'

class Vsx
  DEBUG = false
  DIAGNOSTICS = false # for timing commands, etc

  DEFAULT_TIMEOUT = 0.5

  attr_reader :tuner, :volume, :hostname

  def initialize hostname

    @hostname = hostname
    @socket = TCPSocket::new(@hostname, 23)
    @buff = ''
    @responses = []

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

  # TODO: need to rethink what on/off returns; also need on? and off?

  # turn on the VSX

  def on
    return true if status == :on
    command('PO')
    return true if persistent_command('?P', /PWR0/)
    raise NoResponse, "Can't power up VSX receiver at #{@hostname}"
  end

  # turn off the vsx

  def off
    return true if status == :off
    command('PF')
    return true if persistent_command('?P', /PWR1/)
    raise NoResponse, "Can't power down VSX receiver at #{@hostname}"
  end

  # used primarily by input controls in their select methods - e.g.,
  # we use '02' for the TunerControl#select method. value should be a string.
  # returns the input code we end up with, or nil in case of and error

  def set_input value
    input = command_matches('?F', /FN(\d+)/, 'tuner selection')[0]
    return '02' if input == value

    command("#{value}FN")
    response = persistent_command('?F', /FN(#{value})/, 4)
    return nil unless response
    return response[0]
  end

  # given a command request and optionally a regular expression to
  # match against the response, send the request to the VSX and read
  # until response is recieved; but we don't wait longer than about half a
  # second. Returns nil if timed out or if response did not match a
  # supplied regular expression.  Methods calling this need to be
  # aware of nil condirtion and throw error if appropriate.

  def command request, response_pattern = /.*/
    self.drain
    self.write request

    response = self.read
    STDERR.puts "command: got '#{response}' for command '#{request}' (matcher '#{response_pattern}')" if DEBUG

    return response if response.nil? or response_pattern =~ response   # nil on timeout or return the matched response
    return nil                                                         # nil on unmatched response
  end


  # try a command multiple times - usually this a followup status
  # command of some kind, for cases where some previously submitted
  # command might have made the VSX return multiple responses.  We're
  # really only interested in the current state, and may have to flush
  # several VSX responses.  Returns true on success, false otherwise.

  def persistent_command cmd, regex, tries = 4

    tries.times do
      resp = command(cmd, regex)
      STDERR.puts "persistent_command: got '#{resp}' for command '#{cmd}'" if DEBUG
      return regex.match(resp).captures if resp
      sleep DEFAULT_TIMEOUT
    end
    return nil
  end

  # like command() above, but stricter and expects the required
  # regular expression to have match patterns e.g. /^foobar ([09]+)$/.
  # Returns an array of the matched patterns.  Throws a# VsxError on
  # any kind of failure.
  #
  # Note that there is a race condition on certain requests that
  # return multiple responses, e.g., selection of a new input or
  # power-up, so it's unsuitable for those commands. See
  # persistent_command.

  def command_matches cmd, regex, error_type
    response = self.command cmd, regex
    STDERR.puts  "command_matches: got '#{response}' for command '#{cmd}', regex '#{regex}'" if DEBUG
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
  # anytime (e.g., someone adjusts volume), so we need to clear stuff
  # out before we attempt a command/response.

  def drain
    while resp = self.read(0.05) do
      STDERR.puts "drain: dropping '#{resp}'" if DEBUG
    end
  end

end
