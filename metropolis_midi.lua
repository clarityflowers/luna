local luamidi = require "luamidi"
local midi_utils = require "midi_utils"

local OUT_PORT = 2
local IN_PORT = 2
local PORT = 2


local letters_to_pitches = {
  0, 2, 4, 5, 7, 9, 11
}
local pitches_to_default_notes = {
  [0] = {1, 0},
  {1, 1},
  {2, 0},
  {3, -1},
  {3, 0},
  {4, 0},
  {4, 1},
  {5, 0},
  {6, -1},
  {6, 0},
  {7, -1},
  {7, 0}
}

local function toPitch(note)
  if not note then return nil end
  local octave, letter, accidental = unpack(note)
  if octave == nil then return nil end
  local pitch = octave * 12 + letters_to_pitches[letter] + accidental
  return pitch
end


local NOTE_ON = 144
local NOTE_OFF = 128
local MIDI_CC = 176
local MIDI_CC_PORTA_TIME = 5
local MIDI_CC_CLEAR = 123

local function midiClear(port, channel)
  luamidi.sendMessage(port, MIDI_CC, MIDI_CC_CLEAR, 0, channel)
end



local GATE_MODE_NONE = 1
local GATE_MODE_ONCE = 2
local GATE_MODE_REPEAT = 3
local GATE_MODE_SUS = 4




local metropolis = {}

function metropolis.midi(metro, info, inputs, knobs)
  
  local PORTA_TIME = 50
  local DEFAULT_STEP_OPTIONS = {1, GATE_MODE_SUS, false, false}
  local stop = info.pause
  local toggle_play = info.start

  local reload = metro == nil
  if reload then
    metro = {
      steps = {}, -- {{{octave, letter, accidental}, steps, gate_mode, tie, skip}, ...}
      step = 1,
      step_time = 1,
      selected_step = 0,
      prev_step = nil,
      playing = nil,
      play = false,
      channel = 0,
      octave_shift = 0,
      cleff = "treble",
      edit_mode = "insert",
      sliding = false,
      gate_time = 0.2,
      multiplier = {1, 1}
    }
  end

  if info.delete then
    stop = true
  end

  local is_beat = false
  local fraction
  local prev_fraction

  do
    local numerator, denominator = unpack(metro.multiplier)
    local moment = (info.clock.beat + info.clock.fraction) * numerator / denominator
    fraction = moment - math.floor(moment)
    local prev_beat = info.clock.beat
    if info.clock.is_beat then
      prev_beat = info.clock.beat - 1
    end
    local prev_moment = (prev_beat + info.clock.prev_fraction) * numerator / denominator
    prev_fraction = prev_moment - math.floor(prev_moment)
    if fraction < prev_fraction then
      is_beat = true
    end
  end


  

  local delete_step = false

  local step_max = #metro.steps
  local step_min = 1
  if metro.edit_mode == "edit" then
    step_max = step_max + 1
  elseif metro.edit_mode == "insert" then
    step_min = step_min - 1
  end
  for _, input in pairs(inputs) do
    local command = input[1]
    if command == "key" then
      local _, key, ctrl, shift = unpack(input)
      if key == "left" then
        if metro.selected_step <= step_min then
          metro.selected_step = step_max
        else
          metro.selected_step = metro.selected_step - 1
        end
      elseif key == "right" then
        if metro.selected_step >= step_max then
          metro.selected_step = step_min
        else
          metro.selected_step = metro.selected_step + 1
        end
      elseif key == "space" then
        toggle_play = true
      elseif shift and key == "e" then
        if metro.edit_mode == "insert" then
          metro.edit_mode = "edit"
          if metro.selected_step == step_min then
            metro.selected_step = #metro.steps + 1
          end
        else
          metro.edit_mode = "insert"
          if metro.selected_step == step_max then
            metro.selected_step = 0
          end
        end
      elseif key == "backspace" then
        delete_step = true
      elseif key == "q" then
        if metro.edit_mode == "insert" then
          local note_to_insert = {false, unpack(DEFAULT_STEP_OPTIONS)}
          table.insert(
            metro.steps,
            metro.selected_step + 1,
            note_to_insert
          )
          metro.selected_step = metro.selected_step + 1
        else
          if metro.steps[metro.selected_step] then
            metro.steps[metro.selected_step][1] = false
          end
        end
      elseif key == "w" then
        if metro.steps[metro.selected_step] then
          metro.steps[metro.selected_step][3] = GATE_MODE_ONCE
        end
      elseif key == "e" then
        if metro.steps[metro.selected_step] then
          metro.steps[metro.selected_step][3] = GATE_MODE_REPEAT
        end
      elseif key == "r" then
        if metro.steps[metro.selected_step] then
          metro.steps[metro.selected_step][3] = GATE_MODE_SUS
        end
      elseif key == "s" then
        if metro.steps[metro.selected_step] then
          local step = metro.steps[metro.selected_step]
          step[5] = not step[5]
        end
      elseif key == "t" then
        if metro.steps[metro.selected_step] then
          local step = metro.steps[metro.selected_step]
          step[4] = not step[4]
        end
      elseif key == "up" and shift then
        metro.octave_shift = metro.octave_shift + 1
      elseif key == "down" and shift then
        metro.octave_shift = metro.octave_shift - 1
      elseif shift and key == "c" then
        if metro.cleff == "treble" then
          metro.cleff = "bass"
        elseif metro.cleff == "bass" then
          metro.cleff = "piano"
        else
          metro.cleff = "treble"
        end
      else
        local match = false
        for i = 0, 9, 1 do
          if key == tostring(i) then
            if i >= 1 and i <= 8 then
              if metro.steps[metro.selected_step] then
                metro.steps[metro.selected_step][2] = i
              end
              match = true
            end
          end
        end
        if not match then
          print("Unhandled key: " .. key)
        end
      end
    elseif command == "MIDI" then
      local _, message, v1, v2 = unpack(input)
      if message == NOTE_ON and v2 > 0 then
        local pitch = v1
        local octave =  math.floor(pitch / 12)
        local note = {
          octave,
          unpack(pitches_to_default_notes[pitch % 12])
        }
        local default_step = {note, unpack(DEFAULT_STEP_OPTIONS)}
        if metro.edit_mode == "edit" then
          if not metro.steps[metro.selected_step] then
            metro.steps[metro.selected_step] = default_step
          else
            metro.steps[metro.selected_step][1] = note
          end
        elseif metro.edit_mode == "insert" then
          table.insert(metro.steps, metro.selected_step + 1, default_step)
          metro.selected_step = metro.selected_step + 1
        end
      end
    end
  end




  if info.selected then
    local channel_knob_color = nil
    if not metro.play or metro.playing then
      channel_knob_color = "value"
    end
    metro.channel = midi_utils.useKnob(inputs, knobs, 4, metro.channel, {
      min = 0,
      max = 15,
      color = channel_knob_color
    })
    if midi_utils.knobClicked(inputs, knobs, 5) then
      metro.multiplier = {1, 1}
    end
    metro.multiplier = midi_utils.toMultiplier(midi_utils.useKnob(
      inputs,
      knobs,
      5,
      midi_utils.fromMultiplier(metro.multiplier), {
        color = "value"
      }
    ))
    metro.gate_time = midi_utils.useKnob(inputs, knobs, 6, metro.gate_time, {
        min = 0,
        max = 1,
        color = "value",
        round = false
      }
    )
  end


  if info.selected and info.in_devices[IN_PORT] then
    local message_and_channel, v1, v2 = luamidi.getMessage(IN_PORT)
    if message_and_channel then
      local channel = message_and_channel % 16
      local message = message_and_channel - channel
      if message == NOTE_ON and v2 > 0 then
        local pitch = v1
        local octave =  math.floor(pitch / 12)
        local note = {
          octave,
          unpack(pitches_to_default_notes[pitch % 12])
        }
        local default_step = {note, unpack(DEFAULT_STEP_OPTIONS)}
        if metro.edit_mode == "edit" then
          if not metro.steps[metro.selected_step] then
            metro.steps[metro.selected_step] = default_step
          else
            metro.steps[metro.selected_step][1] = note
          end
        elseif metro.edit_mode == "insert" then
          table.insert(metro.steps, metro.selected_step + 1, default_step)
          metro.selected_step = metro.selected_step + 1
        end
      end
    end
  end


  if delete_step then
    local step_index = metro.selected_step
    if metro.edit_mode == "insert" then
      metro.selected_step = metro.selected_step - 1
    end
    if metro.steps[step_index] then
      table.remove(metro.steps, step_index)
      if #metro.steps == 0 then
        stop = true
      elseif metro.step >= step_index then
        metro.step = metro.step - 1
        if metro.step == 0 then
          metro.step = #metro.steps
        end
        if metro.prev_step ~= nil then
          metro.prev_step = metro.prev_step - 1
        end
        if metro.prev_step == 0 then
          metro.prev_step = #metro.steps
        end
        metro.step_time = 1000
      end
    end
  end

  if toggle_play then
    if metro.play then
      stop = true
    elseif #metro.steps > 0 then
      metro.play = true
      metro.step = #metro.steps
    end
  end

  if stop then
    midiClear(PORT, metro.channel)
    metro.step = #metro.steps
    metro.step_time = 1
    metro.prev_step = nil
    metro.playing = nil
    metro.play = false
  end


  if metro.play and is_beat and #metro.steps > 0 then
    if metro.prev_step ~= nil and metro.step_time < metro.steps[metro.step][2] then
      metro.step_time = metro.step_time + 1
    else
      local attempts = 1
      metro.prev_step = metro.step
      repeat
        attempts = attempts + 1
        metro.step = (metro.step % #metro.steps) + 1
      until (not metro.steps[metro.step][5]) or attempts > #metro.steps + 1
      if attempts > #metro.steps + 1 then
        stop = true
      end
      metro.step_time = 1
    end
  end


  if metro.play and metro.steps[metro.step] then
    local step = metro.steps[metro.step]
    local note, pulse_count, gate_mode, slide = unpack(step)
    local pitch = toPitch(note)
    if pitch ~= nil then
      pitch = pitch + metro.octave_shift * 12
    end

    local is_end = is_beat or (
      prev_fraction < metro.gate_time and
      fraction >= metro.gate_time
    )


    local prev_slide = false
    if metro.prev_step and metro.steps[metro.prev_step] then
      prev_slide = metro.steps[metro.prev_step][4] and metro.step_time == 1
    end



    if (
      metro.playing and
      is_end and (
        (gate_mode ~= GATE_MODE_SUS) or (
          is_beat and metro.step_time == 1
        ) or (
          not is_beat and metro.step_time == pulse_count
        )
      ) and not (
        (is_beat and prev_slide) or
        (not is_beat and slide and metro.step_time == pulse_count)
      )
    ) then
      luamidi.noteOff(PORT, metro.playing, metro.channel)
      metro.playing = nil
      if (not is_beat and metro.sliding and not slide) or (is_beat and metro.sliding and not prev_slide) then
        metro.sliding = false
        luamidi.sendMessage(PORT, MIDI_CC, MIDI_CC_PORTA_TIME, 0, metro.channel)
      end
    end


    if is_beat and pitch ~= nil and (
      ((
        gate_mode == GATE_MODE_ONCE or gate_mode == GATE_MODE_SUS
      ) and metro.step_time == 1) or
      gate_mode == GATE_MODE_REPEAT
    ) then
      if prev_slide and not metro.sliding then
        metro.sliding = true
        luamidi.sendMessage(PORT, MIDI_CC, MIDI_CC_PORTA_TIME, PORTA_TIME, metro.channel)
      end

      local holding = nil
      
      if prev_slide and metro.playing then
        holding = metro.playing

        metro.playing = nil
      end

      if not metro.playing then
        luamidi.sendMessage(PORT, NOTE_ON, pitch, 127, metro.channel)
        metro.playing = pitch
      end

      if holding then
        luamidi.noteOff(PORT, holding, metro.channel)
      end
    end
  end
  
  return metro
end

return metropolis