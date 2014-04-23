# TODO:  add channel level next for left/right settings


# maintain a table of regular expressions that we'll try to match up
# against VSX responses

DISPATCH_TABLE = []

# provide a construct to populate the dispatch table, which includes a
# proc to decode a matched response

def on regex, name, &block
  DISPATCH_TABLE.push({ :name => name, :regex => regex, :decoder => block })
end

# decode searches the dispatch table for a matching response, and
# returns a string description of the response, if possible.

def decode_response vsx_response
  DISPATCH_TABLE.each do |parser|
    text  = (parser[:regex] =~ vsx_response) && parser[:decoder].call(vsx_response)
    title = (parser[:name].class == String)  ? parser[:name] + ': ' : ''
    return title + text if text
  end
  return vsx_response
end


# like above, but always include the original response

def translate_response vsx_response
  DISPATCH_TABLE.each do |parser|
    text  = (parser[:regex] =~ vsx_response) && parser[:decoder].call(vsx_response)
    title = (parser[:name].class == String)  ? parser[:name] + ': ' : ''
    if text
      return "#{vsx_response} (#{title}#{text})"
    end
  end
  return vsx_response
end


# /^RGB..[01].*$/ -- report input name information

on /^RGB[0-9]{2}[01].*$/,  'Input Name' do |response|

  renamed = case response[5..5]
            when '0' then false
            when '1' then true
            else
              nil
            end

  device = case response[3..4]
           when '00' then 'PHONO'
           when '01' then 'CD'
           when '02' then 'TUNER'
           when '03' then 'CD-R/TAPE'
           when '04' then 'DVD'
           when '05' then 'TV/SAT'
           when '10' then 'VIDEO 1(VIDEO)'
           when '12' then 'MULTI CH IN'
           when '14' then 'VIDEO 2'
           when '15' then 'DVR/BDR'
           when '17' then 'iPod/USB'
           when '18' then 'XM RADIO'
           when '19' then 'HDMI 1'
           when '20' then 'HDMI 2'
           when '21' then 'HDMI 3'
           when '22' then 'HDMI 4'
           when '23' then 'HDMI 5'
           when '24' then 'HDMI 6'
           when '25' then 'BD'
           when '26' then 'HOME MEDIA GALLERY(Internet Radio)'
           when '27' then 'SIRIUS'
           when '33' then 'ADAPTER PORT'
           else
             'Device Code ' + response[3..4]
           end

  name = response[6..-1].strip

  #  info = { :device => device,  :name => name,  :renamed => renamed }
  name  +  (renamed ? " (#{device})" : "")

end


# /^AST[0-9]{43}$/  -- audio status request - return from command  '?AST'

on /^AST[0-9]{43}$/, 'Audio Status' do |response|

  input_signal = case response[3..4]
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
                   "signal code #{response[3..4]}"
                 end

  input_frequency = case response[5..6]
                    when '00' then '32 kHz'
                    when '01' then '44.1 kHz'
                    when '02' then '48 kHz'
                    when '03' then '88.2 kHz'
                    when '04' then '96 kHz'
                    when '05' then '176.4 kHz'
                    when '06' then '192 kHz'
                    else
                      "frequency code #{response[5..6]}"
                    end

  # report input channels (often not available)

  list = []

  list.push('L')   if response[7..7]   == '1'  # Left
  list.push('C')   if response[8..8]   == '1'  # Center
  list.push('R')   if response[9..9]   == '1'  # Right
  list.push('SL')  if response[10..10] == '1'  # Left Surround
  list.push('SR')  if response[11..11] == '1'  # Right Surround
  list.push('SBL') if response[12..12] == '1'  # Left Surround Back
  list.push('S')   if response[13..13] == '1'  # Surround (??)
  list.push('SBR') if response[14..14] == '1'  # Right Surround Back
  list.push('LFE') if response[15..15] == '1'  # (??)
  list.push('FHL') if response[16..16] == '1'  # Front High, Left
  list.push('FHR') if response[17..17] == '1'  # Front High, Right
  list.push('FWL') if response[18..18] == '1'  # Front Wide, Left
  list.push('FWR') if response[19..19] == '1'  # Front Wide, Right
  list.push('XL')  if response[20..20] == '1'  # Extra Left?
  list.push('XC')  if response[21..21] == '1'  # Extra Center?
  list.push('XR')  if response[22..22] == '1'  # Extra Right?

  # response data 23..27 are reserved

  input_channels = list.join(',')

  # Report output channels:

  list = []

  list.push('L')    if response[28..28] == '1'  # Left
  list.push('C')    if response[29..29] == '1'  # Center
  list.push('R')    if response[30..30] == '1'  # Right
  list.push('SL')   if response[31..31] == '1'  # Left Surround
  list.push('SR')   if response[32..32] == '1'  # Right Surround
  list.push('SBL')  if response[33..33] == '1'  # Left Surround Back
  list.push('SB')   if response[34..34] == '1'  # Surround Back (in lieu of SBL & SBR)
  list.push('SBR')  if response[35..35] == '1'  # Right Surround Back
  list.push('SW')   if response[36..36] == '1'  # Subwoofer
  list.push('FHL')  if response[37..37] == '1'  # Front High Left
  list.push('FHR')  if response[38..38] == '1'  # Front High Right
  list.push('FWL')  if response[39..39] == '1'  # Front Wide Left
  list.push('FWR')  if response[40..40] == '1'  # Front Wide Right

  # rest of response data are reserved

  output_channels = list.join(',')

  str = input_signal + " at " + input_frequency

  if input_channels.length > 0
    str += " with " + input_channels + " channels"
  end

  if output_channels.length > 0
    str += '; driving speaker channels ' + output_channels
  end

  str
end

# /^FR[AF](\d+)$/   -- tuner setting response (to command ?FR)

on /^FR[AF]\d+$/, 'Tuner Setting' do |params|
  case params
  when /^FRF(\d+)$/ then  sprintf("FM %3.1f MHz", $1.to_i / 100.0)
  when /^FRA(\d+)$/ then  sprintf("AM %3.0f KHz", $1.to_i / 1.0)  # Don't know if this one is correct
  else
    params
  end
end

# /^VST\d{29}$/     -- video input status response (to command ?VST)

on /^VST\d{29}$/, 'Video Status' do |response|

  input_terminal = case response[3..3]
                   when "0" then nil
                   when "1" then 'Video'
                   when "2" then 'S-Video'
                   when "3" then 'Component'
                   when "4" then 'HDMI'
                   when "5" then 'Self OSD/JPEG'
                   else
                     "terminal code " + response[3..3]
                   end

  input_resolution = case response[4..5]
                     when "00" then nil
                     when "01" then '480/60i'
                     when "02" then '576/50i'
                     when "03" then '480/60p'
                     when "04" then '576/50p'
                     when "05" then '720/60p'
                     when "06" then '720/50p'
                     when "07" then '1080/60i'
                     when "08" then '1080/50i'
                     when "09" then '1080/60p'
                     when "10" then '1080/50p'
                     when "11" then '1080/24p'
                     else
                       "resolution code " + response[4..5]
                     end

  input_aspect = case response[6..6]
                 when '0' then nil
                 when '1' then '4:3'
                 when '2' then '16:9'
                 when '3' then '14:9'
                 else
                   "aspect code " + response[6..6]
                 end

  str = input_terminal

  if input_resolution
    str += ' at ' + input_resolution
  end

  if input_aspect
    str += ' formatted ' + input_aspect
  end

  str
end





# /^FL[0-9A-F]{30}$/  Front panel display reponse (to command ?FL)

on /^FL[0-9A-F]{30}$/, 'Display' do |response|

  case response[2..3]
  when '00' then '  '
  when '01' then ' *'
  when '02' then '* '
  when '03' then '**'    # no idea what lights these refer to...need to study panel
  else
    '??'             # decode string of hex to corresponding ASCII, e.g. '53' => 'S'
  end   +  (response.unpack '@4' + 'a2' * 14).map { |c| c.to_i(16).chr }.join
end

# /^FN(\d\d)$/     -- input device response (to command ?F);  the codes can be used to set the device with the command '**FN' using reference below

on  /^FN\d\d$/, 'Input Device' do |response|

  case response[2..3]
  when '00' then 'PHONO'           # not present on VSX 1021-k
  when '01' then 'CD'
  when '02' then 'TUNER'
  when '03' then 'CD-R/TAPE'
  when '04' then 'DVD'
  when '05' then 'TV/SAT'
  when '10' then 'Video 1'
  when '12' then 'MULTI CH IN'     # not present on VSX 1021-k
  when '14' then 'Video 2'
  when '15' then 'DVR/BDR'
  when '17' then 'iPod/USB'
  when '19' then 'HDMI 1'
  when '20' then 'HDMI 2'          # not present on VSX 1021-k
  when '21' then 'HDMI 3'          # not present on VSX 1021-k
  when '22' then 'HDMI 4'          # not present on VSX 1021-k
  when '23' then 'HDMI 5'          # not present on VSX 1021-k
  when '24' then 'HDMI 6'          # not present on VSX 1021-k
  when '25' then 'BD'
  when '26' then 'Home Media Gallery (Internet Radio)'
  when '27' then 'SIRIUS'
  when '31' then 'HDMI (cyclic)'
  when '33' then 'Adapter Port'
  else
    response
  end
end

#  /^VOL(\d+)$/    -- audio level response (to command ?V)

on /^VOL\d+$/, 'Audio Level' do |response|

  vol = response.gsub('VOL', '').to_i
  "#{sprintf "%3.1f", (vol - 161) * 0.5} dB"
end


# handle /^SPK\d$/ -- speaker status response (to command ?SPK)

on /^SPK\d$/, 'Speaker Status' do |response|
  case response[3..3]
  when '0' then 'Speaker Off'
  when '1' then 'Speaker A'
  when '2' then 'Speaker B'
  when '3' then 'Speaker A+B'
  else
    response
  end
end

#
# handle /^SR\d{4}$/     -- listening mode setting in response to '?S' command
#
# These codes can be used to set the listening mode with  '****SR' command, using appropriate 4 character listening mode code


on  /^SR\d{4}$/, 'Listening Setting' do |response|

  # [1]       indicates unsupported on my model, VSX 1021-K

  case response[2..5]
  when '0001' then 'STEREO (cyclic)'
  when '0010' then 'STANDARD'
  when '0009' then 'STEREO (direct set)'
  when '0011' then '(2ch source)'                                           # [1]
  when '0013' then 'PRO LOGIC2 MOVIE'
  when '0018' then 'PRO LOGIC2x MOVIE'
  when '0014' then 'PRO LOGIC2 MUSIC'
  when '0019' then 'PRO LOGIC2x MUSIC'
  when '0015' then 'PRO LOGIC2 GAME'
  when '0020' then 'PRO LOGIC2x GAME'
  when '0031' then 'PRO LOGIC2z HEIGHT'
  when '0032' then 'WIDE SURROUND MOVIE'
  when '0033' then 'WIDE SURROUND MUSIC'
  when '0012' then 'PRO LOGIC'
  when '0016' then 'Neo:6 CINEMA'
  when '0017' then 'Neo:6 MUSIC'
  when '0028' then 'XM HD SURROUND'                                         # [1]
  when '0029' then 'NEURAL SURROUND'
  when '0037' then 'Neo:X CINEMA'                                           # [1]
  when '0038' then 'Neo:X MUSIC'                                            # [1]
  when '0039' then 'Neo:X GAME'                                             # [1]
  when '0040' then 'NEURAL SURROUND+Neo:X CINEMA'                           # [1]
  when '0041' then 'NEURAL SURROUND+Neo:X MUSIC'                            # [1]
  when '0042' then 'NEURAL SURROUND+Neo:X GAME'                             # [1]
  when '0021' then '(Multi ch source)'
  when '0022' then '(Multi ch source)+DOLBY EX'
  when '0023' then '(Multi ch source)+PRO LOGIC2x MOVIE'
  when '0024' then '(Multi ch source)+PRO LOGIC2x MUSIC'
  when '0034' then '(Multi-ch Source)+PRO LOGIC2z HEIGHT'
  when '0035' then '(Multi-ch Source)+WIDE SURROUND MOVIE'
  when '0036' then '(Multi-ch Source)+WIDE SURROUND MUSIC'
  when '0025' then '(Multi ch source)DTS-ES Neo:6'
  when '0026' then '(Multi ch source)DTS-ES matrix'
  when '0027' then '(Multi ch source)DTS-ES discrete'
  when '0030' then '(Multi ch source)DTS-ES 8ch discrete'
  when '0043' then '(Multi ch source)DTS-ES Neo:X'                          # [1]
  when '0100' then 'ADVANCED SURROUND (cyclic)'
  when '0101' then 'ACTION'
  when '0103' then 'DRAMA'
  when '0102' then 'SCI-FI'
  when '0105' then 'MONO FILM'
  when '0104' then 'ENTERTAINMENT SHOW'
  when '0106' then 'EXPANDED THEATER'
  when '0116' then 'TV SURROUND'
  when '0118' then 'ADVANCED GAME'
  when '0117' then 'SPORTS'
  when '0107' then 'CLASSICAL'
  when '0110' then 'ROCK/POP'
  when '0109' then 'UNPLUGGED'
  when '0112' then 'EXTENDED STEREO'
  when '0003' then 'Front Stage Surround Advance Focus'
  when '0004' then 'Front Stage Surround Advance Wide'
  when '0153' then 'RETRIEVER AIR'
  when '0113' then 'PHONES SURROUND'
  when '0050' then 'THX (cyclic)'                                           # [1]
  when '0051' then 'PROLOGIC + THX CINEMA'                                  # [1]
  when '0052' then 'PL2 MOVIE + THX CINEMA'                                 # [1]
  when '0053' then 'Neo:6 CINEMA + THX CINEMA'                              # [1]
  when '0054' then 'PL2x MOVIE + THX CINEMA'                                # [1]
  when '0092' then 'PL2z HEIGHT + THX CINEMA'                               # [1]
  when '0055' then 'THX SELECT2 GAMES'                                      # [1]
  when '0068' then 'THX CINEMA (for 2ch)'                                   # [1]
  when '0069' then 'THX MUSIC (for 2ch)'                                    # [1]
  when '0070' then 'THX GAMES (for 2ch)'                                    # [1]
  when '0071' then 'PL2 MUSIC + THX MUSIC'                                  # [1]
  when '0072' then 'PL2x MUSIC + THX MUSIC'                                 # [1]
  when '0093' then 'PL2z HEIGHT + THX MUSIC'                                # [1]
  when '0073' then 'Neo:6 MUSIC + THX MUSIC'                                # [1]
  when '0074' then 'PL2 GAME + THX GAMES'                                   # [1]
  when '0075' then 'PL2x GAME + THX GAMES'                                  # [1]
  when '0094' then 'PL2z HEIGHT + THX GAMES'                                # [1]
  when '0076' then 'THX ULTRA2 GAMES'                                       # [1]
  when '0077' then 'PROLOGIC + THX MUSIC'                                   # [1]
  when '0078' then 'PROLOGIC + THX GAMES'                                   # [1]
  when '0201' then 'Neo:X CINEMA + THX CINEMA'                              # [1]
  when '0202' then 'Neo:X MUSIC + THX MUSIC'                                # [1]
  when '0203' then 'Neo:X GAME + THX GAMES'                                 # [1]
  when '0056' then 'THX CINEMA (for multi ch)'                              # [1]
  when '0057' then 'THX SURROUND EX (for multi ch)'                         # [1]
  when '0058' then 'PL2x MOVIE + THX CINEMA (for multi ch)'                 # [1]
  when '0095' then 'PL2z HEIGHT + THX CINEMA (for multi ch)'                # [1]
  when '0059' then 'ES Neo:6 + THX CINEMA (for multi ch)'                   # [1]
  when '0060' then 'ES MATRIX + THX CINEMA (for multi ch)'                  # [1]
  when '0061' then 'ES DISCRETE + THX CINEMA (for multi ch)'                # [1]
  when '0067' then 'ES 8ch DISCRETE + THX CINEMA (for multi ch)'            # [1]
  when '0062' then 'THX SELECT2 CINEMA (for multi ch)'                      # [1]
  when '0063' then 'THX SELECT2 MUSIC (for multi ch)'                       # [1]
  when '0064' then 'THX SELECT2 GAMES (for multi ch)'                       # [1]
  when '0065' then 'THX ULTRA2 CINEMA (for multi ch)'                       # [1]
  when '0066' then 'THX ULTRA2 MUSIC (for multi ch)'                        # [1]
  when '0079' then 'THX ULTRA2 GAMES (for multi ch)'                        # [1]
  when '0080' then 'THX MUSIC (for multi ch)'                               # [1]
  when '0081' then 'THX GAMES (for multi ch)'                               # [1]
  when '0082' then 'PL2x MUSIC + THX MUSIC (for multi ch)'                  # [1]
  when '0096' then 'PL2z HEIGHT + THX MUSIC (for multi ch)'                 # [1]
  when '0083' then 'EX + THX GAMES (for multi ch)'                          # [1]
  when '0097' then 'PL2z HEIGHT + THX GAMES (for multi ch)'                 # [1]
  when '0084' then 'Neo:6 + THX MUSIC (for multi ch)'                       # [1]
  when '0085' then 'Neo:6 + THX GAMES (for multi ch)'                       # [1]
  when '0086' then 'ES MATRIX + THX MUSIC (for multi ch)'                   # [1]
  when '0087' then 'ES MATRIX + THX GAMES (for multi ch)'                   # [1]
  when '0088' then 'ES DISCRETE + THX MUSIC (for multi ch)'                 # [1]
  when '0089' then 'ES DISCRETE + THX GAMES (for multi ch)'                 # [1]
  when '0090' then 'ES 8CH DISCRETE + THX MUSIC (for multi ch)'             # [1]
  when '0091' then 'ES 8CH DISCRETE + THX GAMES (for multi ch)'             # [1]
  when '0204' then 'Neo:X + THX CINEMA (for multi ch)'                      # [1]
  when '0205' then 'Neo:X + THX MUSIC (for multi ch)'                       # [1]
  when '0206' then 'Neo:X + THX GAMES (for multi ch)'                       # [1]
  when '0005' then 'AUTO SURR/STREAM DIRECT (cyclic)'
  when '0006' then 'AUTO SURROUND'
  when '0151' then 'Auto Level Control (A.L.C.)'
  when '0007' then 'DIRECT'
  when '0008' then 'PURE DIRECT'
  when '0152' then 'OPTIMUM SURROUND'                                       # [1]
  else
    response
  end
end


# /^LM[0-9a-f]{4}$/   -- display listening mode (response to command '?L')
# unlike responses to the above, these codes are not used to set anything (so I believe)

on  /^LM[0-9a-f]{4}$/, 'Listening Mode' do |response|

  case response[2..5]
  when '0101' then '[)(]PLIIx MOVIE'
  when '0102' then '[)(]PLII MOVIE'
  when '0103' then '[)(]PLIIx MUSIC'
  when '0104' then '[)(]PLII MUSIC'
  when '0105' then '[)(]PLIIx GAME'
  when '0106' then '[)(]PLII GAME'
  when '0107' then '[)(]PROLOGIC'
  when '0108' then 'Neo:6 CINEMA'
  when '0109' then 'Neo:6 MUSIC'
  when '010a' then 'XM HD Surround'
  when '010b' then 'NEURAL SURR'
  when '010c' then '2ch Straight Decode'
  when '010d' then '[)(]PLIIz HEIGHT'
  when '010e' then 'WIDE SURR MOVIE'
  when '010f' then 'WIDE SURR MUSIC'
  when '0110' then 'STEREO'
  when '0111' then 'Neo:X CINEMA'
  when '0112' then 'Neo:X MUSIC'
  when '0113' then 'Neo:X GAME'
  when '0114' then 'NEURAL SURROUND+Neo:X CINEMA'
  when '0115' then 'NEURAL SURROUND+Neo:X MUSIC'
  when '0116' then 'NEURAL SURROUND+Neo:X GAMES'
  when '1101' then '[)(]PLIIx MOVIE'
  when '1102' then '[)(]PLIIx MUSIC'
  when '1103' then '[)(]DIGITAL EX'
  when '1104' then 'DTS +Neo:6 / DTS-HD +Neo:6'
  when '1105' then 'ES MATRIX'
  when '1106' then 'ES DISCRETE'
  when '1107' then 'DTS-ES 8ch'
  when '1108' then 'multi ch Straight Decode'
  when '1109' then '[)(]PLIIz HEIGHT'
  when '110a' then 'WIDE SURR MOVIE'
  when '110b' then 'WIDE SURR MUSIC'
  when '110c' then 'ES Neo:X'
  when '0201' then 'ACTION'
  when '0202' then 'DRAMA'
  when '0203' then 'SCI-FI'
  when '0204' then 'MONOFILM'
  when '0205' then 'ENT.SHOW'
  when '0206' then 'EXPANDED'
  when '0207' then 'TV SURROUND'
  when '0208' then 'ADVANCEDGAME'
  when '0209' then 'SPORTS'
  when '020a' then 'CLASSICAL'
  when '020b' then 'ROCK/POP'
  when '020c' then 'UNPLUGGED'
  when '020d' then 'EXT.STEREO'
  when '020e' then 'PHONES SURR.'
  when '020f' then 'FRONT STAGE SURROUND ADVANCE FOCUS'
  when '0210' then 'FRONT STAGE SURROUND ADVANCE WIDE'
  when '0211' then 'SOUND RETRIEVER AIR'
  when '0301' then '[)(]PLIIx MOVIE +THX'
  when '0302' then '[)(]PLII MOVIE +THX'
  when '0303' then '[)(]PL +THX CINEMA'
  when '0304' then 'Neo:6 CINEMA +THX'
  when '0305' then 'THX CINEMA'
  when '0306' then '[)(]PLIIx MUSIC +THX'
  when '0307' then '[)(]PLII MUSIC +THX'
  when '0308' then '[)(]PL +THX MUSIC'
  when '0309' then 'Neo:6 MUSIC +THX'
  when '030a' then 'THX MUSIC'
  when '030b' then '[)(]PLIIx GAME +THX'
  when '030c' then '[)(]PLII GAME +THX'
  when '030d' then '[)(]PL +THX GAMES'
  when '030e' then 'THX ULTRA2 GAMES'
  when '030f' then 'THX SELECT2 GAMES'
  when '0310' then 'THX GAMES'
  when '0311' then '[)(]PLIIz +THX CINEMA'
  when '0312' then '[)(]PLIIz +THX MUSIC'
  when '0313' then '[)(]PLIIz +THX GAMES'
  when '0314' then 'Neo:X CINEMA + THX CINEMA'
  when '0315' then 'Neo:X MUSIC + THX MUSIC'
  when '0316' then 'Neo:X GAMES + THX GAMES'
  when '1301' then 'THX Surr EX'
  when '1302' then 'Neo:6 +THX CINEMA'
  when '1303' then 'ES MTRX +THX CINEMA'
  when '1304' then 'ES DISC +THX CINEMA'
  when '1305' then 'ES 8ch +THX CINEMA'
  when '1306' then '[)(]PLIIx MOVIE +THX'
  when '1307' then 'THX ULTRA2 CINEMA'
  when '1308' then 'THX SELECT2 CINEMA'
  when '1309' then 'THX CINEMA'
  when '130a' then 'Neo:6 +THX MUSIC'
  when '130b' then 'ES MTRX +THX MUSIC'
  when '130c' then 'ES DISC +THX MUSIC'
  when '130d' then 'ES 8ch +THX MUSIC'
  when '130e' then '[)(]PLIIx MUSIC +THX'
  when '130f' then 'THX ULTRA2 MUSIC'
  when '1310' then 'THX SELECT2 MUSIC'
  when '1311' then 'THX MUSIC'
  when '1312' then 'Neo:6 +THX GAMES'
  when '1313' then 'ES MTRX +THX GAMES'
  when '1314' then 'ES DISC +THX GAMES'
  when '1315' then 'ES 8ch +THX GAMES'
  when '1316' then '[)(]EX +THX GAMES'
  when '1317' then 'THX ULTRA2 GAMES'
  when '1318' then 'THX SELECT2 GAMES'
  when '1319' then 'THX GAMES'
  when '131a' then '[)(]PLIIz +THX CINEMA'
  when '131b' then '[)(]PLIIz +THX MUSIC'
  when '131c' then '[)(]PLIIz +THX GAMES'
  when '131d' then 'Neo:X + THX CINEMA'
  when '131e' then 'Neo:X + THX MUSIC'
  when '131f' then 'Neo:X + THX GAMES'
  when '0401' then 'STEREO'
  when '0402' then '[)(]PLII MOVIE'
  when '0403' then '[)(]PLIIx MOVIE'
  when '0404' then 'Neo:6 CINEMA'
  when '0405' then 'AUTO SURROUND Straight Decode'
  when '0406' then '[)(]DIGITAL EX'
  when '0407' then '[)(]PLIIx MOVIE'
  when '0408' then 'DTS +Neo:6'
  when '0409' then 'ES MATRIX'
  when '040a' then 'ES DISCRETE'
  when '040b' then 'DTS-ES 8ch'
  when '040c' then 'XM HD Surround'
  when '040d' then 'NEURAL SURR'
  when '040e' then 'RETRIEVER AIR'
  when '040f' then 'Neo:X CINEMA'
  when '0410' then 'ES Neo:X'
  when '0501' then 'STEREO'
  when '0502' then '[)(]PLII MOVIE'
  when '0503' then '[)(]PLIIx MOVIE'
  when '0504' then 'Neo:6 CINEMA'
  when '0505' then 'ALC Straight Decode'
  when '0506' then '[)(]DIGITAL EX'
  when '0507' then '[)(]PLIIx MOVIE'
  when '0508' then 'DTS +Neo:6'
  when '0509' then 'ES MATRIX'
  when '050a' then 'ES DISCRETE'
  when '050b' then 'DTS-ES 8ch'
  when '050c' then 'XM HD Surround'
  when '050d' then 'NEURAL SURR'
  when '050e' then 'RETRIEVER AIR'
  when '050f' then 'Neo:X CINEMA'
  when '0510' then 'ES Neo:X'
  when '0601' then 'STEREO'
  when '0602' then '[)(]PLII MOVIE'
  when '0603' then '[)(]PLIIx MOVIE'
  when '0604' then 'Neo:6 CINEMA'
  when '0605' then 'STREAM DIRECT NORMAL Straight Decode'
  when '0606' then '[)(]DIGITAL EX'
  when '0607' then '[)(]PLIIx MOVIE'
  when '0608' then '(nothing)'
  when '0609' then 'ES MATRIX'
  when '060a' then 'ES DISCRETE'
  when '060b' then 'DTS-ES 8ch'
  when '060c' then 'Neo:X CINEMA'
  when '060d' then 'ES Neo:X'
  when '0701' then 'STREAM DIRECT PURE 2ch'
  when '0702' then '[)(]PLII MOVIE'
  when '0703' then '[)(]PLIIx MOVIE'
  when '0704' then 'Neo:6 CINEMA'
  when '0705' then 'STREAM DIRECT PURE Straight Decode'
  when '0706' then '[)(]DIGITAL EX'
  when '0707' then '[)(]PLIIx MOVIE'
  when '0708' then '(nothing)'
  when '0709' then 'ES MATRIX'
  when '070a' then 'ES DISCRETE'
  when '070b' then 'DTS-ES 8ch'
  when '070c' then 'Neo:X CINEMA'
  when '070d' then 'ES Neo:X'
  when '0881' then 'OPTIMUM'
  when '0e01' then 'HDMI THROUGH'
  when '0f01' then 'MULTI CH IN'
  else
    response
  end
end


on /^(B00|E04|E06|MUT0|MUT1|PWR0|PWR1|R)$/, :nada do |response|
  case response
  when "B00"                then "VSX busy - retry presently"  # error responses
  when "E04"                then "Bad command code"
  when "E06"                then "Bad command parameter"
  when "MUT0"               then "VSX is muted"                # in response to command '?M'
  when "MUT1"               then "VSX is not muted"
  when "PWR0"               then "VSX is powered up"           # in response to command '?P'
  when "PWR1"               then "VSX is not powered up"
  when "R"                  then "VSX OK"                      # response to bare CRLF
  else
    response
  end
end
