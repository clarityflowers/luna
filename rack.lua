local livereload = require "livereload2"
local utils = livereload.init('utils.lua')
local modules = livereload.init('modules.lua')

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

local notes = livereload.init("notes.lua")

-- function modules.inKey(state, props)


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

  -- clear out no longer active events
  for i, event in ipairs(state.active) do
    local exists = false
    for _, in_event in ipairs(props.events) do
      if event.time == in_event.time then
        if event.type == "note" and in_event.type == "note" and notes.areEqual(event.note, in_event.note) then
          exists = true          
        end
      end
    end
    if not exists then
      table.insert(deleted, i)
      -- if event.type == 
    end
  end
end


function rack.update(state, dt, inputs)
  utils.defaults(state, {
    perf = {},
    clock = {},
    sequencer = {}
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


  local tempo = {
    bpm = 100,
    multiplier = {1, 1}
  }

  render.clock = modules.clock(state.clock, {
    tempo = tempo,
    dt = dt
  })



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
   
    
  render.key = {-1, 1}

  local sequence = {
    {note = {0, 1}},
    {note = {0, 2}},
    {note = {0, 5}, tie = true},
    {note = {0, 5}},
    {note = {0, 1}, tie = true},
    {note = {0, 1}, tie = true},
    {note = {0, 1}},
    {note = {0, 2}, tie = true},
    {note = {0, 7}},
    {},
  }

  render.music_events, render.sequence = modules.sequencer(state.sequencer, {
    clock = render.clock,
    gate_time = 0.5,
    sequence = sequence
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