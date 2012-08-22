#!/usr/bin/env ruby


#
# mute
# unmute
# off
# on
#
# volume +, ++, +++, -, --, ---
# fm
# fm station
# am station
# computer, xbmc, xbox

# parse_command_line str
          


$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), './lib/'))
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '../lib/'))


def xprompt
  STDOUT.write 'cmd> '
  STDOUT.flush
end

def xread
  line = STDIN.gets
  if line.nil?
    print '', 'goodbye'
    exit -1
  end
  return line.chomp
end

def xeval str 
  @parser.complete str
end

def xprint *texts
  STDOUT.write texts.join("\n") + "\n"
  STDOUT.flush
end


class CommandParser
  
  def initialize
    @command_set = {}
    [ 'mute', 'unmute', 'off', 'on', 'volume', 'fm', 'am', 'xbmc', 'xbox' ].each do |cmd|
      @command_set[cmd.downcase] =  true # lambda { |args| dispatch cmd.to_sym, args }
    end
  end

  def complete str
    str.downcase!
    candidates = []
    @command_set.keys.sort.each do |cmd_name|
      return [ str ] if str == cmd_name
      # candidates.push cmd_name if cmd_name =~ /^\\#{str.unpack('a1' * str.length).join('\\')}/
      candidates.push cmd_name if cmd_name =~ /^#{str}/
    end
    return candidates
  rescue => e
    STDERR.puts e
    return candidates
  end
end



@parser = CommandParser.new

while true  
  xprompt
  xprint(xeval(xread()))
end
