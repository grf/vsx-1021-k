#!/usr/bin/env ruby

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), './lib/'))
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '../lib/'))

require 'socket'
require 'time'
require 'vsx-exceptions'

DEBUG = true        # for info when read innocuously times out, etc
DIAGNOSTICS = false # for timing commands, etc

class VolumeControl

  def initialize vsx
    @vsx = vsx
  end


  # to do: add incr, decr, set, mute, inquire methods

  def report
    return sprintf("%3.1f Db, %s", inquire_volume, inquire_mute ? 'muted' : 'not muted')
  end

  def db
    return inquire_volume
  end

  def muted
    return inquire_mute
  end

  # TODO: methods mute, unmute, db=, incr, decr


  def inquire_volume
    regx = /^VOL(\d+)$/

    response = @vsx.command '?V', regx
    raise  NoResponse, "No response from VSX at #{@vsx.hostname} for volume inquiry" unless response

    regx =~ response
    return  ($1.to_i - 161) * 0.5
  end

  def inquire_mute
    regx = /^MUT(\d+)$/

    response = @vsx.command '?M', regx
    raise  NoResponse, "No response from VSX at #{@vsx.hostname} for mute inquiry" unless response

    regx =~ response
    case $1
    when '0' : true
    when '1' : false
    else
      raise InvalidResponse, "Invalid response from VSX at #{@vsx.hostname} for mute inquiry"
    end
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


class TunerControl

  def initialize vsx
    @vsx = vsx
  end

  # return symbol :fm or :am

  def band
    inquire[:band]
  end

  # return float as string

  def frequency
    inquire[:frequency]
  end


  def report
    inq = inquire
    if inq[:band] == :fm
      "FM " + inq[:frequency] + " " + inq[:units]
    else
      "AM " + inq[:frequency] + " " + inq[:units]
    end
  end


  # TODO: band=, frequency=   -- note: setting to band when already in that band gets no response, so check

  def band= value
  end

  def frequency= value
  end


  private
  

  # return hash { :frequency => float, :band => [ :fm | :am ], :units => [ 'MHz' | 'KHz' ] } 
  # raise VsxError on timeout or 

  def inquire
    regx = /^FR([FA])(\d+$)/

    response = @vsx.command '?FR', regx
    raise  NoResponse, "No response from VSX at #{@vsx.hostname} for tuner inquiry" unless response

    regx =~ response
    raw_band, raw_freq = $1, $2

    case raw_band
    when 'F'
      return { :band => :fm, :frequency => sprintf("%3.1f", raw_freq.to_i / 100.0), :units => 'MHz' }
    when 'A'
      return { :band => :am, :frequency => sprintf("%3.0f", raw_freq.to_i / 1.0), :units => 'KHz' }
    else
      raise InvalidResponse, "Bad response '#{response}' from VSX at #{@vsx.hostname} for tuner inquiry"
    end
  end


end




class Vsx

  attr_reader :tuner, :volume, :hostname

  def initialize hostname

    @hostname = hostname
    @socket = TCPSocket::new(@hostname, 23)
    @buff = ''
    @responses = []

    @tuner  = TunerControl.new(self)
    @volume = VolumeControl.new(self)
  end

  def write str = ""
    @socket.write str + "\r\n"
  end

  def read timeout = 0.5
    return @responses.shift unless @responses.empty?

    results = select([ @socket ], nil, nil, timeout)

    @buff += @socket.recv(4 * 1024) if (results and results[0].include? @socket)

    if @buff =~ /^(.*\r\n)(.*)$/m        # check for all completed input (ends with CRLF, aka \r\n)
       @buff = $2                        # save partial response for later
       @responses += $1.split(/\r\n/)    # get all the completed responses 
    end

    @responses.shift
  end


  # given a command request and a regular expression response, send
  # the request to the VSX and read until response is recieved; but we
  # don't wait longer than half a second. Returns nil if timed out.
  # methods calling this need to be aware of nil and throw error if
  # appropriate.

  def command request, response_pattern
    self.drain
    self.write request

    response = self.read

    return response if response.nil? or response_pattern =~ response   # nil on timeout, or the expected response
    return nil                                                         # response was unexpected
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


