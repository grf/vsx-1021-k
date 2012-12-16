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
    title = (parser[:name].class == String)  ? "#{parser[:name]}: " : ""
    return title + text if text
  end
  return vsx_response
end


# /^AST[0-9]{43}$/  -- audio status request - return from command  '?AST'

on /^AST[0-9]{43}$/, 'Audio Status' do |response|

  input_signal = case response[3..4]
                 when '00': 'analog'
                 when '01': 'analog'
                 when '02': 'analog'
                 when '03': 'PCM'
                 when '04': 'PCM'
                 when '05': 'DOLBY DIGITAL'
                 when '06': 'DTS'
                 when '07': 'DTS-ES Matrix'
                 when '08': 'DTS-ES Discrete'
                 when '09': 'DTS 96/24'
                 when '10': 'DTS 96/24 ES Matrix'
                 when '11': 'DTS 96/24 ES Discrete'
                 when '12': 'MPEG-2 AAC'
                 when '13': 'WMA9 Pro'
                 when '14': 'DSD->PCM'
                 when '15': 'HDMI pass-through'
                 when '16': 'DOLBY DIGITAL PLUS'
                 when '17': 'DOLBY TrueHD'
                 when '18': 'DTS EXPRESS'
                 when '19': 'DTS-HD Master Audio'
                 when '20': 'DTS-HD High Resolution'
                 when '21': 'DTS-HD High Resolution'
                 when '22': 'DTS-HD High Resolution'
                 when '23': 'DTS-HD High Resolution'
                 when '24': 'DTS-HD High Resolution'
                 when '25': 'DTS-HD High Resolution'
                 when '26': 'DTS-HD High Resolution'
                 when '27': 'DTS-HD Master Audio'
                 else
                   "signal code #{response[3..4]}"
                 end

  input_frequency = case response[5..6]
                    when '00': '32 kHz'
                    when '01': '44.1 kHz'
                    when '02': '48 kHz'
                    when '03': '88.2 kHz'
                    when '04': '96 kHz'
                    when '05': '176.4 kHz'
                    when '06': '192 kHz'
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

  str + ' (' + response + ')'
end

# /^FR[AF](\d+)$/   -- tuner setting response (to command ?FR)

on /^FR[AF]\d+$/, 'Tuner Setting' do |params|
  case params
  when /^FRF(\d+)$/:  sprintf("FM %3.1f MHz", $1.to_i / 100.0)
  when /^FRA(\d+)$/:  sprintf("AM %3.0f KHz", $1.to_i / 1.0)  # Don't know if this one is correct
  else
    params
  end
end

# /^VST\d{29}$/     -- video input status response (to command ?VST)

on /^VST\d{29}$/, 'Video Status' do |response|
  
  input_terminal = case response[3..3]
                   when "0": nil
                   when "1": 'Video'
                   when "2": 'S-Video'
                   when "3": 'Component'
                   when "4": 'HDMI'
                   when "5": 'Self OSD/JPEG'
                   else
                     "terminal code " + response[3..3]
                   end

  input_resolution = case response[4..5]
                     when "00": nil
                     when "01": '480/60i' 
                     when "02": '576/50i' 
                     when "03": '480/60p' 
                     when "04": '576/50p' 
                     when "05": '720/60p' 
                     when "06": '720/50p' 
                     when "07": '1080/60i'
                     when "08": '1080/50i'
                     when "09": '1080/60p'
                     when "10": '1080/50p'
                     when "11": '1080/24p'
                     else
                       "resolution code " + response[4..5]
                     end
  
  input_aspect = case response[6..6]
                 when '0': nil
                 when '1': '4:3'
                 when '2': '16:9'
                 when '3': '14:9'
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

  str + ",  (#{response})"
end





# /^FL[0-9A-F]{30}$/  Front panel display reponse (to command ?FL)

on /^FL[0-9A-F]{30}$/, 'Display' do |response|
  
  case response[2..3]
  when '00': '  '
  when '01': ' *'
  when '02': '* '
  when '03': '**'    # no idea what lights these refer to...need to study panel
  else 
    '??'             # decode string of hex to corresponding ASCII, e.g. '53' => 'S'
  end   +  (response.unpack '@4' + 'a2' * 14).map { |c| c.to_i(16).chr }.join
end

# /^FN(\d\d)$/     -- input device response (to command ?F);  the codes can be used to set the device with the command '**FN' using reference below 

on  /^FN\d\d$/, 'Input Device' do |response|

  case response[2..3]
  when '00': 'PHONO'           # not present on VSX 1021-k
  when '01': 'CD'
  when '02': 'TUNER'
  when '03': 'CD-R/TAPE'
  when '04': 'DVD'
  when '05': 'TV/SAT'
  when '10': 'Video 1'
  when '12': 'MULTI CH IN'     # not present on VSX 1021-k
  when '14': 'Video 2'
  when '15': 'DVR/BDR'
  when '17': 'iPod/USB'
  when '19': 'HDMI 1'
  when '20': 'HDMI 2'          # not present on VSX 1021-k
  when '21': 'HDMI 3'          # not present on VSX 1021-k
  when '22': 'HDMI 4'          # not present on VSX 1021-k
  when '23': 'HDMI 5'          # not present on VSX 1021-k
  when '24': 'HDMI 6'          # not present on VSX 1021-k
  when '25': 'BD'
  when '26': 'Home Media Gallery (Internet Radio)'
  when '27': 'SIRIUS'
  when '31': 'HDMI (cyclic)'
  when '33': 'Adapter Port'
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
  when '0': 'Speaker Off'
  when '1': 'Speaker A'
  when '2': 'Speaker B'
  when '3': 'Speaker A+B'
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
  when '0001': 'STEREO (cyclic)'
  when '0010': 'STANDARD'
  when '0009': 'STEREO (direct set)'
  when '0011': '(2ch source)'                                           # [1]
  when '0013': 'PRO LOGIC2 MOVIE'
  when '0018': 'PRO LOGIC2x MOVIE'
  when '0014': 'PRO LOGIC2 MUSIC'
  when '0019': 'PRO LOGIC2x MUSIC'
  when '0015': 'PRO LOGIC2 GAME'
  when '0020': 'PRO LOGIC2x GAME'
  when '0031': 'PRO LOGIC2z HEIGHT'
  when '0032': 'WIDE SURROUND MOVIE'
  when '0033': 'WIDE SURROUND MUSIC'
  when '0012': 'PRO LOGIC'
  when '0016': 'Neo:6 CINEMA'
  when '0017': 'Neo:6 MUSIC'
  when '0028': 'XM HD SURROUND'                                         # [1]
  when '0029': 'NEURAL SURROUND'
  when '0037': 'Neo:X CINEMA'                                           # [1]
  when '0038': 'Neo:X MUSIC'                                            # [1]
  when '0039': 'Neo:X GAME'                                             # [1]
  when '0040': 'NEURAL SURROUND+Neo:X CINEMA'                           # [1]
  when '0041': 'NEURAL SURROUND+Neo:X MUSIC'                            # [1]
  when '0042': 'NEURAL SURROUND+Neo:X GAME'                             # [1]
  when '0021': '(Multi ch source)'
  when '0022': '(Multi ch source)+DOLBY EX'
  when '0023': '(Multi ch source)+PRO LOGIC2x MOVIE'
  when '0024': '(Multi ch source)+PRO LOGIC2x MUSIC'
  when '0034': '(Multi-ch Source)+PRO LOGIC2z HEIGHT'
  when '0035': '(Multi-ch Source)+WIDE SURROUND MOVIE'
  when '0036': '(Multi-ch Source)+WIDE SURROUND MUSIC'
  when '0025': '(Multi ch source)DTS-ES Neo:6'
  when '0026': '(Multi ch source)DTS-ES matrix'
  when '0027': '(Multi ch source)DTS-ES discrete'
  when '0030': '(Multi ch source)DTS-ES 8ch discrete'
  when '0043': '(Multi ch source)DTS-ES Neo:X'                          # [1]
  when '0100': 'ADVANCED SURROUND (cyclic)'
  when '0101': 'ACTION'
  when '0103': 'DRAMA'
  when '0102': 'SCI-FI'
  when '0105': 'MONO FILM'
  when '0104': 'ENTERTAINMENT SHOW'
  when '0106': 'EXPANDED THEATER'
  when '0116': 'TV SURROUND'
  when '0118': 'ADVANCED GAME'
  when '0117': 'SPORTS'
  when '0107': 'CLASSICAL'
  when '0110': 'ROCK/POP'
  when '0109': 'UNPLUGGED'
  when '0112': 'EXTENDED STEREO'
  when '0003': 'Front Stage Surround Advance Focus'
  when '0004': 'Front Stage Surround Advance Wide'
  when '0153': 'RETRIEVER AIR'
  when '0113': 'PHONES SURROUND'
  when '0050': 'THX (cyclic)'                                           # [1]
  when '0051': 'PROLOGIC + THX CINEMA'                                  # [1]
  when '0052': 'PL2 MOVIE + THX CINEMA'                                 # [1]
  when '0053': 'Neo:6 CINEMA + THX CINEMA'                              # [1]
  when '0054': 'PL2x MOVIE + THX CINEMA'                                # [1]
  when '0092': 'PL2z HEIGHT + THX CINEMA'                               # [1]
  when '0055': 'THX SELECT2 GAMES'                                      # [1]
  when '0068': 'THX CINEMA (for 2ch)'                                   # [1]
  when '0069': 'THX MUSIC (for 2ch)'                                    # [1]
  when '0070': 'THX GAMES (for 2ch)'                                    # [1]
  when '0071': 'PL2 MUSIC + THX MUSIC'                                  # [1]
  when '0072': 'PL2x MUSIC + THX MUSIC'                                 # [1]
  when '0093': 'PL2z HEIGHT + THX MUSIC'                                # [1]
  when '0073': 'Neo:6 MUSIC + THX MUSIC'                                # [1]
  when '0074': 'PL2 GAME + THX GAMES'                                   # [1]
  when '0075': 'PL2x GAME + THX GAMES'                                  # [1]
  when '0094': 'PL2z HEIGHT + THX GAMES'                                # [1]
  when '0076': 'THX ULTRA2 GAMES'                                       # [1]
  when '0077': 'PROLOGIC + THX MUSIC'                                   # [1]
  when '0078': 'PROLOGIC + THX GAMES'                                   # [1]
  when '0201': 'Neo:X CINEMA + THX CINEMA'                              # [1]
  when '0202': 'Neo:X MUSIC + THX MUSIC'                                # [1]
  when '0203': 'Neo:X GAME + THX GAMES'                                 # [1]
  when '0056': 'THX CINEMA (for multi ch)'                              # [1]
  when '0057': 'THX SURROUND EX (for multi ch)'                         # [1]
  when '0058': 'PL2x MOVIE + THX CINEMA (for multi ch)'                 # [1]
  when '0095': 'PL2z HEIGHT + THX CINEMA (for multi ch)'                # [1]
  when '0059': 'ES Neo:6 + THX CINEMA (for multi ch)'                   # [1]
  when '0060': 'ES MATRIX + THX CINEMA (for multi ch)'                  # [1]
  when '0061': 'ES DISCRETE + THX CINEMA (for multi ch)'                # [1]
  when '0067': 'ES 8ch DISCRETE + THX CINEMA (for multi ch)'            # [1]
  when '0062': 'THX SELECT2 CINEMA (for multi ch)'                      # [1]
  when '0063': 'THX SELECT2 MUSIC (for multi ch)'                       # [1]
  when '0064': 'THX SELECT2 GAMES (for multi ch)'                       # [1]
  when '0065': 'THX ULTRA2 CINEMA (for multi ch)'                       # [1]
  when '0066': 'THX ULTRA2 MUSIC (for multi ch)'                        # [1]
  when '0079': 'THX ULTRA2 GAMES (for multi ch)'                        # [1]
  when '0080': 'THX MUSIC (for multi ch)'                               # [1]
  when '0081': 'THX GAMES (for multi ch)'                               # [1]
  when '0082': 'PL2x MUSIC + THX MUSIC (for multi ch)'                  # [1]
  when '0096': 'PL2z HEIGHT + THX MUSIC (for multi ch)'                 # [1]
  when '0083': 'EX + THX GAMES (for multi ch)'                          # [1]
  when '0097': 'PL2z HEIGHT + THX GAMES (for multi ch)'                 # [1]
  when '0084': 'Neo:6 + THX MUSIC (for multi ch)'                       # [1]
  when '0085': 'Neo:6 + THX GAMES (for multi ch)'                       # [1]
  when '0086': 'ES MATRIX + THX MUSIC (for multi ch)'                   # [1]
  when '0087': 'ES MATRIX + THX GAMES (for multi ch)'                   # [1]
  when '0088': 'ES DISCRETE + THX MUSIC (for multi ch)'                 # [1]
  when '0089': 'ES DISCRETE + THX GAMES (for multi ch)'                 # [1]
  when '0090': 'ES 8CH DISCRETE + THX MUSIC (for multi ch)'             # [1]
  when '0091': 'ES 8CH DISCRETE + THX GAMES (for multi ch)'             # [1]
  when '0204': 'Neo:X + THX CINEMA (for multi ch)'                      # [1]
  when '0205': 'Neo:X + THX MUSIC (for multi ch)'                       # [1]
  when '0206': 'Neo:X + THX GAMES (for multi ch)'                       # [1]
  when '0005': 'AUTO SURR/STREAM DIRECT (cyclic)'
  when '0006': 'AUTO SURROUND'
  when '0151': 'Auto Level Control (A.L.C.)'
  when '0007': 'DIRECT'
  when '0008': 'PURE DIRECT'
  when '0152': 'OPTIMUM SURROUND'                                       # [1]
  else
    response
  end
end


# /^LM[0-9a-f]{4}$/   -- display listening mode (response to command '?L')
# unlike responses to the above, these codes are not used to set anything (so I believe)

on  /^LM[0-9a-f]{4}$/, 'Listening Mode' do |response|

  case response[2..5]
  when '0101': '[)(]PLIIx MOVIE'
  when '0102': '[)(]PLII MOVIE'
  when '0103': '[)(]PLIIx MUSIC'
  when '0104': '[)(]PLII MUSIC'
  when '0105': '[)(]PLIIx GAME'
  when '0106': '[)(]PLII GAME'
  when '0107': '[)(]PROLOGIC'
  when '0108': 'Neo:6 CINEMA'
  when '0109': 'Neo:6 MUSIC'
  when '010a': 'XM HD Surround'
  when '010b': 'NEURAL SURR'
  when '010c': '2ch Straight Decode'
  when '010d': '[)(]PLIIz HEIGHT'
  when '010e': 'WIDE SURR MOVIE'
  when '010f': 'WIDE SURR MUSIC'
  when '0110': 'STEREO'
  when '0111': 'Neo:X CINEMA'
  when '0112': 'Neo:X MUSIC'
  when '0113': 'Neo:X GAME'
  when '0114': 'NEURAL SURROUND+Neo:X CINEMA'
  when '0115': 'NEURAL SURROUND+Neo:X MUSIC'
  when '0116': 'NEURAL SURROUND+Neo:X GAMES'
  when '1101': '[)(]PLIIx MOVIE'
  when '1102': '[)(]PLIIx MUSIC'
  when '1103': '[)(]DIGITAL EX'
  when '1104': 'DTS +Neo:6 / DTS-HD +Neo:6'
  when '1105': 'ES MATRIX'
  when '1106': 'ES DISCRETE'
  when '1107': 'DTS-ES 8ch'
  when '1108': 'multi ch Straight Decode'
  when '1109': '[)(]PLIIz HEIGHT'
  when '110a': 'WIDE SURR MOVIE'
  when '110b': 'WIDE SURR MUSIC'
  when '110c': 'ES Neo:X'
  when '0201': 'ACTION'
  when '0202': 'DRAMA'
  when '0203': 'SCI-FI'
  when '0204': 'MONOFILM'
  when '0205': 'ENT.SHOW'
  when '0206': 'EXPANDED'
  when '0207': 'TV SURROUND'
  when '0208': 'ADVANCEDGAME'
  when '0209': 'SPORTS'
  when '020a': 'CLASSICAL'
  when '020b': 'ROCK/POP'
  when '020c': 'UNPLUGGED'
  when '020d': 'EXT.STEREO'
  when '020e': 'PHONES SURR.'
  when '020f': 'FRONT STAGE SURROUND ADVANCE FOCUS'
  when '0210': 'FRONT STAGE SURROUND ADVANCE WIDE'
  when '0211': 'SOUND RETRIEVER AIR'
  when '0301': '[)(]PLIIx MOVIE +THX'
  when '0302': '[)(]PLII MOVIE +THX'
  when '0303': '[)(]PL +THX CINEMA'
  when '0304': 'Neo:6 CINEMA +THX'
  when '0305': 'THX CINEMA'
  when '0306': '[)(]PLIIx MUSIC +THX'
  when '0307': '[)(]PLII MUSIC +THX'
  when '0308': '[)(]PL +THX MUSIC'
  when '0309': 'Neo:6 MUSIC +THX'
  when '030a': 'THX MUSIC'
  when '030b': '[)(]PLIIx GAME +THX'
  when '030c': '[)(]PLII GAME +THX'
  when '030d': '[)(]PL +THX GAMES'
  when '030e': 'THX ULTRA2 GAMES'
  when '030f': 'THX SELECT2 GAMES'
  when '0310': 'THX GAMES'
  when '0311': '[)(]PLIIz +THX CINEMA'
  when '0312': '[)(]PLIIz +THX MUSIC'
  when '0313': '[)(]PLIIz +THX GAMES'
  when '0314': 'Neo:X CINEMA + THX CINEMA'
  when '0315': 'Neo:X MUSIC + THX MUSIC'
  when '0316': 'Neo:X GAMES + THX GAMES'
  when '1301': 'THX Surr EX'
  when '1302': 'Neo:6 +THX CINEMA'
  when '1303': 'ES MTRX +THX CINEMA'
  when '1304': 'ES DISC +THX CINEMA'
  when '1305': 'ES 8ch +THX CINEMA'
  when '1306': '[)(]PLIIx MOVIE +THX'
  when '1307': 'THX ULTRA2 CINEMA'
  when '1308': 'THX SELECT2 CINEMA'
  when '1309': 'THX CINEMA'
  when '130a': 'Neo:6 +THX MUSIC'
  when '130b': 'ES MTRX +THX MUSIC'
  when '130c': 'ES DISC +THX MUSIC'
  when '130d': 'ES 8ch +THX MUSIC'
  when '130e': '[)(]PLIIx MUSIC +THX'
  when '130f': 'THX ULTRA2 MUSIC'
  when '1310': 'THX SELECT2 MUSIC'
  when '1311': 'THX MUSIC'
  when '1312': 'Neo:6 +THX GAMES'
  when '1313': 'ES MTRX +THX GAMES'
  when '1314': 'ES DISC +THX GAMES'
  when '1315': 'ES 8ch +THX GAMES'
  when '1316': '[)(]EX +THX GAMES'
  when '1317': 'THX ULTRA2 GAMES'
  when '1318': 'THX SELECT2 GAMES'
  when '1319': 'THX GAMES'
  when '131a': '[)(]PLIIz +THX CINEMA'
  when '131b': '[)(]PLIIz +THX MUSIC'
  when '131c': '[)(]PLIIz +THX GAMES'
  when '131d': 'Neo:X + THX CINEMA'
  when '131e': 'Neo:X + THX MUSIC'
  when '131f': 'Neo:X + THX GAMES'
  when '0401': 'STEREO'
  when '0402': '[)(]PLII MOVIE'
  when '0403': '[)(]PLIIx MOVIE'
  when '0404': 'Neo:6 CINEMA'
  when '0405': 'AUTO SURROUND Straight Decode'
  when '0406': '[)(]DIGITAL EX'
  when '0407': '[)(]PLIIx MOVIE'
  when '0408': 'DTS +Neo:6'
  when '0409': 'ES MATRIX'
  when '040a': 'ES DISCRETE'
  when '040b': 'DTS-ES 8ch'
  when '040c': 'XM HD Surround'
  when '040d': 'NEURAL SURR'
  when '040e': 'RETRIEVER AIR'
  when '040f': 'Neo:X CINEMA'
  when '0410': 'ES Neo:X'
  when '0501': 'STEREO'
  when '0502': '[)(]PLII MOVIE'
  when '0503': '[)(]PLIIx MOVIE'
  when '0504': 'Neo:6 CINEMA'
  when '0505': 'ALC Straight Decode'
  when '0506': '[)(]DIGITAL EX'
  when '0507': '[)(]PLIIx MOVIE'
  when '0508': 'DTS +Neo:6'
  when '0509': 'ES MATRIX'
  when '050a': 'ES DISCRETE'
  when '050b': 'DTS-ES 8ch'
  when '050c': 'XM HD Surround'
  when '050d': 'NEURAL SURR'
  when '050e': 'RETRIEVER AIR'
  when '050f': 'Neo:X CINEMA'
  when '0510': 'ES Neo:X'
  when '0601': 'STEREO'
  when '0602': '[)(]PLII MOVIE'
  when '0603': '[)(]PLIIx MOVIE'
  when '0604': 'Neo:6 CINEMA'
  when '0605': 'STREAM DIRECT NORMAL Straight Decode'
  when '0606': '[)(]DIGITAL EX'
  when '0607': '[)(]PLIIx MOVIE'
  when '0608': '(nothing)'
  when '0609': 'ES MATRIX'
  when '060a': 'ES DISCRETE'
  when '060b': 'DTS-ES 8ch'
  when '060c': 'Neo:X CINEMA'
  when '060d': 'ES Neo:X'
  when '0701': 'STREAM DIRECT PURE 2ch'
  when '0702': '[)(]PLII MOVIE'
  when '0703': '[)(]PLIIx MOVIE'
  when '0704': 'Neo:6 CINEMA'
  when '0705': 'STREAM DIRECT PURE Straight Decode'
  when '0706': '[)(]DIGITAL EX'
  when '0707': '[)(]PLIIx MOVIE'
  when '0708': '(nothing)'
  when '0709': 'ES MATRIX'
  when '070a': 'ES DISCRETE'
  when '070b': 'DTS-ES 8ch'
  when '070c': 'Neo:X CINEMA'
  when '070d': 'ES Neo:X'
  when '0881': 'OPTIMUM'
  when '0e01': 'HDMI THROUGH'
  when '0f01': 'MULTI CH IN'
  else
    response
  end
end


on /^(B00|E04|E06|MUT0|MUT1|PWR0|PWR1|R)$/, :miscellaneous do |response|
  case response
  when "B00"               : "VSX busy - retry presently"  # error responses
  when "E04"               : "Bad command code"
  when "E06"               : "Bad command parameter"
  when "MUT0"              : "VSX is muted"                # in response to command '?M'
  when "MUT1"              : "VSX is not muted"
  when "PWR0"              : "VSX is powered up"           # in response to command '?P'
  when "PWR1"              : "VSX is not powered up"
  when "R"                 : "VSX OK"                      # response to bare CRLF
  else
    response
  end
end

