local livereload = require "livereload"
local utils = livereload "utils"
local modules = livereload "modules"
local notes = livereload "notes"
local constants = livereload "midi_constants"
local tools = livereload "miditools"

local rack = {}

--[[
multiplier: {integer, integer}
steps: integer
accidental: integer
octave: integer
note: {octave, steps, accidental | nil}
direction: integer
pitch: integer
interval: {direction, steps, accidental}
key: integer
note_event: {note, start, end}
unlocked_sequence: {key: key, root: root, gate_time: 0.0..1.0, notes: {note | nil, length, is_tie}[]}
sequence: {key: key, root: root, steps: ({note, is_tie, playing} | nil)[]}
recording: {key: key, root: root, events: note_event[], start: integer, end: integer}
tempo:
{
  bpm: float,
  multiplier: {integer, integer}
}
step:
{
  note = note,
  tie = boolean,
  playing = boolean
}
]]

local notes = livereload "notes"

local function events_equal(a, b)
  if a.time == b.time then
    if a.type == "note" and b.type == "note" then
      return notes.areEqual(a.note, b.note)          
    end
  end
  return false
end

local function event_exists_in(event, events)
  for _, other in ipairs(events) do
    if events_equal(event, other) then
      return true
    end
  end
  return false
end

function modules.midiStream(state, props)
  utils.defaults(state, {
    active = {}
  })
  props = utils.idefaults(props, {
    events = {}
  })
  local stream = {}
  local events = props.events

  local deleted = {}

  local result = {}

  -- clear out no longer active events
  for i, event in ipairs(state.active) do
    if not event_exists_in(event, props.events) then
      table.insert(deleted, i)
      table.insert(result, {constants.NOTE_OFF, tools.toPitch(event.note), 0})
    end
  end
  local count = 0
  for _, i in ipairs(deleted) do
    table.remove(state.active, i - count)
    count = count + 1
  end

  -- insert new events
  for i, event in ipairs(props.events) do
    if not event_exists_in(event, state.active) then
      table.insert(state.active, event)
      table.insert(result, {constants.NOTE_ON, tools.toPitch(event.note), 127})
    end
  end
  return result
end

function modules.recordMidiStream(state, props)
  utils.defaults(state, {
    recording = {}
  })
  props = utils.idefaults(props, {
    stream = {},
    clock = nil,
    window = nil
  })
  local time = love.timer.getTime()
  if props.clock then
    time = props.clock.beat + props.clock.fraction
  end
  for _, message in ipairs(props.stream) do
    table.insert(state.recording, {time, message})
  end
  if props.window ~= nil then
    for i, record in ipairs(state.recording) do
      local event_time = unpack(record)
      if time - event_time > props.window then
        state.recording[i] = nil
      else
        break
      end
    end
    utils.compress(state.recording)
  end
  local start_time = 0
  if props.window then
    start_time = time - props.window
  end
  if state.recording[1] then
    local time, message = unpack(state.recording[1])
  end
  
  return {
    start_time = start_time,
    current_time = time,
    events = state.recording
  }
end


function rack.update(state, dt, inputs)
  utils.defaults(state, {
    perf = {},
    clock = {},
    sequencer = {},
    inKey = {},
    midiStream = {},
    midiRecording = {}
  })

  local OUT = 0
  local KNOBS = 1

  local render = {}
  

  for _, input in ipairs(inputs) do
    local command = unpack(input)
    if command == "quit" then
      return "quit"
    end
  end


  render.perf = modules.perf(state.perf, dt)




  -- Twister()
  -- Twister.process(state.twister, state.inputs, KNOBS)

  -- local inputs = state.inputs

  --[[
  do
    local bpm_color = 0.15
    if not state.stopped and state.clock.fraction > 0.2 then
      bpm_color = nil
    end

    if Twister.knob(inputs, 1) then
      local multiplier_knob_value = Twister.knob(state.twister, 2, fromMultiplier(state.multiplier), {
        color = "value",
      })
      state.multiplier = toMultiplier(multiplier_knob_value)
    else
      state.bpm = Twister.knob(state.twister, 1, state.bpm / 2, {
        min = 20,
        max = 100,
        color = bpm_color,
      }) * 2
    end
  end
  ]]

  
  
  -- local sequence = Sequence.create([[
    --   !1 +2 +5 !1 ~~ +2 ~+7 __
    --   ...               ~+6 __
    -- ]]) 



  local tempo = {
    bpm = 100,
    multiplier = {1, 1}
  }

  render.clock = modules.clock(state.clock, {
    tempo = tempo,
    dt = dt
  })
    

  local sequence = {
    {note = {0, 1}},
    {note = {0, 2}},
    {note = {0, 3}},
    {note = {0, 4}},
    {note = {0, 5}},
    {note = {0, 6}},
    {note = {0, 7}},
  }

  local music_events
  music_events, render.sequence = modules.sequencer(state.sequencer, {
    clock = render.clock,
    gate_time = math.random(),
    sequence = sequence
  })


  render.key = {0, 6}
  render.music_events = modules.inKey(state.inKey, {
    events = music_events,
    key = render.key
  })

  local midiStream = modules.midiStream(state.midiStream, {
    events = render.music_events
  })

  render.midiRecording = modules.recordMidiStream(state.midiRecording, {
    stream = midiStream,
    clock = render.clock,
    window = 16
  })







  
  -- local events, sequence = Sequencer.run(state.plaits_sequencer, sequence, state.key, state.clock)
  -- Out(events, OUT, 0)
  -- table.insert(re)

  -- table.insert(render, {"staff", {key = key, cleff = "treble", root = root}, {"stepped", sequence}})
  
  -- return {
  --   sequence = state.sequence,
  --   key = state.key,
  --   bass_sequence = state.bass_sequence
  -- }
  return render
end

return rack