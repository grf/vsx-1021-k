#!/usr/bin/env ruby
require 'sinatra'
require 'thin'
require 'yaml'
require_relative './lib/vsx'

if File.exists?('settings.yml')
  yml_settings = YAML::load_file(File.join(File.dirname(File.expand_path(__FILE__)), 'settings.yml'))
end

$settings = {
  'hostname' => ENV['VSX_HOSTNAME'] || yml_settings['hostname'],
  'min_volume' => ENV['VSX_MIN_VOLUME'] || yml_settings['min_volume'],
  'max_volume' => ENV['VSX_MAX_VOLUME'] || yml_settings['max_volume'],
  'volume_adjust' => ENV['VSX_VOLUME_ADJUST'] || yml_settings['volume_adjust'],
  'sinatra_port' => ENV['VSX_PORT'] || yml_settings['sinatra_port']
}

if $settings['hostname'].nil? or $settings['min_volume'].nil? or $settings['max_volume'].nil? or $settings['volume_adjust'].nil?
  puts "Missing something in environment variables or in settings.yml and can not continue!"
  exit 1
end

configure do
  set :bind, '0.0.0.0'
  set :port, $settings['sinatra_port']
end

vsx = Vsx.new($settings['hostname'])

get '/' do
  body "Nothing to do or see here!"
  halt 404
end

get '/mute' do
  if ! vsx.volume.muted?
    vsx.volume.mute
    body vsx.volume.report
  else
    vsx.volume.unmute
    body vsx.volume.report
  end
end

get '/mute/:name' do |m|
  case m
    when 'on'
      vsx.volume.mute
      body vsx.volume.report
    when 'off'
      vsx.volume.unmute
      body vsx.volume.report
    else
      body "Should be /on or /off or without the trailing /"
      halt 400
  end
end

get '/power/:name' do |p|
  case p
    when 'on'
      if vsx.off?
        4.times do
          begin
            vsx.on
            body 'on'
          rescue
            body 'failed'
            halt 500
          end
        end
      else
        body 'already on'
      end
    when 'off'
      if vsx.on?
        vsx.off
        body 'off'
      else
        body 'already off'
      end
    else
      body "Should be /on or /off without the trailing /"
      halt 400
  end
end

get '/volume/:name' do |v|
  if v == "up"
    vsx.volume.incr $settings['volume_adjust'].to_f
    body vsx.volume.report
  elsif v == "down"
    vsx.volume.decr $settings['volume_adjust'].to_f
    body vsx.volume.report
  else
    # Acceptable volumes are enforced. All others should throw an error
    max_volume = $settings['max_volume'].to_f
    min_volume = $settings['min_volume'].to_f
    volume = v.to_f
    if volume > max_volume or volume < min_volume
      body "Volume should be between #{min_volume} and #{max_volume}"
      halt 400
    end
    vsx.volume.db=(volume)
    body vsx.volume.report
  end
end

get '/input/:name' do |i|
  # There are many inputs, you should run
  # vsx.inputs.find_devices
  # to find the mappings between numbers passed and desired input
  # for me:
  # 19 = HDMI1
  # 20 = HDMI2
  # 21 = HDMI3
  # 22 = HDMI4
  # 23 = HDMI5
  # 24 = HDMI6
  # 25 = BD Player
  # However, you can also use the names such as "HDMI 1" or the rename
  # such as "PS3" to switch between inputs
  input = i.to_s
  vsx.inputs.selected=(input)
  body vsx.inputs.report
end

get '/listening_mode/:name' do |l|
  # Personally, I only care about switching between auto and
  # extended stereo. This will only accept 'auto' and 'music' as params
  if l == 'auto'
    listening_mode = '0006'
  elsif l == 'music'
    listening_mode = '0112'
  else
    listening_mode = '0006'
  end
  vsx.listening_mode=(listening_mode)
  body vsx.listening_mode_name
end
