local MIDI = require("midi_constants")
local riverboat = {}
local luamidi = require "luamidi"
local tools = require "miditools"

function riverboat.midi(state, info, inputs, knobs)
  if not state then
    state = {
      notes = {},
      playing = {},
      channel = 0,
      width = 8,
      convert_to = nil
    }
  end

  local now = info.clock.beat + info.clock.fraction

  local new_channel = tools.useKnob(inputs, knobs, 4, state.channel, {
    min = 0,
    max = 15
  })
  if new_channel ~= state.channel then
    tools.clear(tools.OUT_PORT, state.channel)
    state.channel = new_channel
  end

  state.width = tools.useKnob(inputs, knobs, 5, state.width, {
    min = 1,
    max = 64
  })

  

  for _, input in pairs(inputs) do
    local type = input[1]
    if type == "MIDI" then
      local _, message, v1, v2, _ = unpack(input) -- v2, channel
      if message == MIDI.NOTE_ON and v2 > 0 then
        luamidi.sendMessage(tools.OUT_PORT, MIDI.NOTE_ON, v1, 127, state.channel)
        table.insert(state.playing, {now, v1})
        
      elseif message == MIDI.NOTE_OFF or message == MIDI.NOTE_ON and v2 == 0 then
        luamidi.sendMessage(tools.OUT_PORT, MIDI.NOTE_OFF, v1, 0, state.channel)
        for i, note in pairs(state.playing) do
          local time, pitch = unpack(note)
          if pitch == v1 then
            state.playing[i] = nil
            table.insert(state.notes, {time, now, pitch})
            break
          end
        end
      end
    end
  end

  if state.convert_to == "watermill" then
    if info.clock.is_beat then
      for _, note in pairs(state.playing) do
        local time, pitch = unpack(note)
        luamidi.sendMessage(tools.OUT_PORT, MIDI.NOTE_OFF, pitch, 0, state.channel)
        table.insert(state.notes, {time, now, pitch})
      end

      local new_state = {
        recorded_notes = state.notes,
        channel = state.channel,
        start_time = info.clock.beat - state.width,
        width = state.width,
        status = "started"
      }
      return new_state, { convert_to = "watermill" }
    end
  else
    if tools.knobClicked(inputs, knobs, 7) then
      state.convert_to = "watermill"
    end
  end


  return state
end

return riverboat