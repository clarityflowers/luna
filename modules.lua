local livereload = require "livereload2"
local utils = livereload.init('utils.lua')

local modules = {}

--[[
  returns:
  {
    average: float,
    peak: float
  }
]]
function modules.perf(state, dt)
  utils.defaults(state, {
    times = {},
    times_i = 1
  })

  if #state.times < 10000 then
    table.insert(state.times, dt)
  else
    state.times[state.times_i] = dt
    state.times_i = state.times_i + 1
    if state.times_i > 10000 then
      state.times_i = 1
    end
  end
  local result = {
    peak = 0
  }
  local total = 0
  for _, v in ipairs(state.times) do
    total = total + v
    if v > result.peak then
      result.peak = v
    end
  end
  result.average = total / #state.times

  return result
end


--[[
  clock:
  {
    beat = integer,
    fraction = 0.0..1.0,
    prev_beat = integer,
    prev_fraction = 0.0..1.0,
  }
]]
function modules.clock(state, props)
  utils.defaults(state, {
    beat = 0,
    fraction = 0.0
  })
  props = utils.idefaults(props, {
    dt = 0,
    tempo = {
      bpm = 100,
      multiplier = {1, 1}
    }
  })
  local tempo = props.tempo
  local beats_per_s = tempo.bpm * tempo.multiplier[1] / tempo.multiplier[2] / 60
  local result = {
    click = false,
    prev_time = state.beat + state.fraction
  }
  local prev_beat = state.beat
  local prev_fraction = state.fraction
  state.fraction = state.fraction + (props.dt * beats_per_s)
  if state.fraction > 1 then
    state.beat = state.beat + 1
    state.fraction = state.fraction - 1
    result.click = true
  end

  result.beat = state.beat
  result.fraction = state.fraction
  return {
    beat = state.beat,
    fraction = state.fraction,
    prev_beat = prev_beat,
    prev_fraction = prev_fraction
  }
end

--[[
  playing_note: 
  {
    type = "note",
    note = note,
    time = float
  }
  playing_porta: 
  {
    type = "porta",
    value = 0.0..1.0,
    time = float
  }
  playing_event: playing_note | playing_porta

  returns:
  events: playing_event[],
  sequence: step[]
]]
function modules.sequencer(state, props)
  utils.defaults(state, {
    position = 1
  })
  props = utils.idefaults(props, {
    clock = {
      beat = 0,
      fraction = 0.0,
      prev_beat = 0,
      prev_fraction = 0.0,
    },
    gate_time = 0.5,
    sequence = {}
  })
  local sequence = utils.copy(props.sequence)
  if #sequence == 0 then
    return {}, sequence
  end
  local clock = props.clock
  
  local events = {}
  local click = clock.beat > clock.prev_beat
  if click then
    state.position = state.position + 1
    if state.position > #sequence then
      state.position = 1
    end
  end
  local step = utils.copy(sequence[state.position])
  sequence[state.position] = step
  if step.note then
    if clock.fraction <= props.gate_time then
      table.insert(events, {
        type = "note",
        note = step.note,
        time = clock.beat
      })
      step.playing = true
    end
  else
    step.playing = true
  end
  
  return events, sequence
end


return modules