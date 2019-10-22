local result = {}
local MIDI = require("midi_constants")
local luamidi = require "luamidi"
local tools = require "miditools"

local function insert_event(events, time, ...)
  for i = 1, #events, 1 do
    local event = events[i]
    if event[1] > time then
      table.insert(events, i, {time, ...})
      return
    end
  end
  table.insert(events, {time, ...})
end

local function within(value, min, max)
  return value >= min and value < max
end


function result.midi(state, info, inputs, knobs)
  if not state.looped_events then
    print "refresh looped events"
    state.looped_events = {}
    for i = 1, #state.recorded_notes, 1 do
      local note_start, note_end, pitch = unpack(state.recorded_notes[i])
      local nstart = note_start - state.start_time
      local nend = note_end - state.start_time
      if within(nstart, 0, state.width) then
        insert_event(state.looped_events, nstart, MIDI.NOTE_ON, pitch, 127)
        if nend >= state.width then
          insert_event(state.looped_events, state.width, MIDI.NOTE_OFF, pitch, 0)
        end
      end
      if within(nend, 0, state.width) then
        insert_event(state.looped_events, nend, MIDI.NOTE_OFF, pitch, 0)
        if nstart < 0 then
          insert_event(state.looped_events, 0, MIDI.NOTE_ON, pitch, 127)
        end
      end
      if nstart < 0 and nend > state.width then
        insert_event(state.looped_events, 0, MIDI.NOTE_ON, pitch, 127)
        insert_event(state.looped_events, nend, MIDI.NOTE_OFF, pitch, 0)
      end
    end
  end

  local prev_clock = (info.clock.prev_time - state.start_time) % state.width
  local clock = (info.clock.time - state.start_time) % state.width
  state.clock = clock
  local is_loop = prev_clock > clock

  if info.pause then
    state.status = "stopping"
  elseif info.start then
    if state.status == "started" then
      state.status = "stopping"
    elseif state.status == "stopped" then
      state.status = "starting"
    end
  elseif is_loop then
    if state.status == "stopping" then
      state.status = "stopped"
      tools.clear(tools.OUT_PORT, state.channel)
    elseif state.status == "starting" then
      state.status = "started"
    end
  end

  if state.status == "started" or state.status == "stopping" then
    for _, event in pairs(state.looped_events) do
      time, message, pitch, vel = unpack(event)
      if (is_loop or time > prev_clock) and time < clock then
        luamidi.sendMessage(tools.OUT_PORT, message, pitch, vel, state.channel)
      end
    end
  end

  local new_channel = tools.useKnob(inputs, knobs, 4, state.channel, {
    min = 0,
    max = 15
  })
  if new_channel ~= state.channel then
    tools.clear(tools.OUT_PORT, state.channel)
    state.channel = new_channel
  end

  if info.delete then
    tools.clear(tools.OUT_PORT, state.channel)
  end

  return state
end

return result