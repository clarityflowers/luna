local utils = require "utils"
local notes = require "notes"
local tools = require "miditools"
local MIDI = require "midi_constants"


local function music_equal(a, b)
  if a.time == b.time then
    if a.type == "note" and b.type == "note" then
      return notes.areEqual(a.note, b.note)          
    elseif a.type == "porta" and b.type == "porta" then
      return a.value == b.value
    end
  end
  return false
end

local function note_exists_in(playing, music)
  for _, other in ipairs(music) do
    if music_equal(playing, other) then
      return true
    end
  end
  return false
end


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

  if #state.times < 1000 then
    table.insert(state.times, dt)
  else
    state.times[state.times_i] = dt
    state.times_i = state.times_i + 1
    if state.times_i > 1000 then
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
  tempo:
  {
    bpm: float,
    multiplier: {integer, integer}
  }
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
  local prev_beat = state.beat
  local prev_fraction = state.fraction
  state.fraction = state.fraction + (props.dt * beats_per_s)
  while state.fraction > 1 do
    state.beat = state.beat + 1
    state.fraction = state.fraction - 1
  end

  return {
    beat = state.beat,
    fraction = state.fraction,
    prev_beat = prev_beat,
    prev_fraction = prev_fraction
  }
end

function modules.sampleAndHold(state, props)
  props = utils.idefaults(props, {
    clock = {
      beat = 0,
      fraction = 0.0,
      prev_beat = 0,
      prev_fraction = 0.0,
    },
    value = nil
  })
  utils.defaults(state, {
    value = props.value
  })
  if props.clock.beat > props.clock.prev_beat then
    state.value = props.value
  end
  return state.value
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
  playing: (playing_note | playing_porta)

  returns:
  music: playing[]
]]
function modules.generativeSequencer(state, props)
  props = utils.idefaults(props, {
    clock = {
      beat = 0,
      fraction = 0.0,
      prev_beat = 0,
      prev_fraction = 0.0,
    },
    gate_time = 0.5,
    sequence = {},
    generate = function() return {} end
  }),
  utils.defaults(state, {
    prev_step = {},
    step = {},
    sampleAndHold = {},
    start_time = 1
  })

  local clock = props.clock

  local gate_time = modules.sampleAndHold(state.sampleAndHold, {
    clock = props.clock,
    value = props.gate_time
  })
  
  local music = {}
  local click = clock.beat > clock.prev_beat
  if click then
    state.prev_step = state.step
    state.step = props.generate()
  end
  local step = state.step
  if step.note then
    local new_note = true
    local porta = false
    if state.prev_step.note and state.prev_step.tie then
      if notes.areEqual(state.prev_step.note, step.note) then
        new_note = false
      else
        porta = true
      end
    end
    if new_note then
      state.start_time = clock.beat
    end
    if clock.fraction <= gate_time or step.tie then
      table.insert(music, {
        type = "note",
        note = step.note,
        time = state.start_time
      })
      if porta then
        table.insert(music, {
          type = "porta",
          time = state.start_time,
          value = 7
        })
      end
      step.playing = true
    end
  else
    step.playing = true
  end

  return music
end

--[[
  returns:
  music: playing[],
  sequence: step[]
]]
function modules.sequencer(state, props)
  props = utils.idefaults(props, {
    clock = {
      beat = 0,
      fraction = 0.0,
      prev_beat = 0,
      prev_fraction = 0.0,
    },
    gate_time = 0.5,
    porta_time = 40,
    sequence = {},
  })
  utils.defaults(state, {
    position = nil,
    sequencer = {}
  })

  if #props.sequence == 0 then
    return music, {}
  end

  local sequence = utils.copy(props.sequence)

  local function generator()
    if #props.sequence == 0 then
      return {}
    end
    if state.position == nil then
      state.position = 1
    else
      state.position = state.position + 1
    end
    if state.position > #props.sequence then
      state.position = 1
    end
    
    return props.sequence[state.position]
  end

  local sequencer_props = utils.copy(props)
  sequencer_props.sequence = nil
  sequencer_props.generate = generator

  local music = modules.generativeSequencer(state.sequencer, sequencer_props)
  
  if state.position ~= nil then
    local step = utils.copy(sequence[state.position])
    sequence[state.position] = step

    if step.note then
      for _, playing in ipairs(music) do
        if playing.type == "note" then
          step.playing = true
        end
      end
    else
      step.playing = true
    end
  end

  return music, sequence
end


function modules.inKey(state, props)
  props = utils.idefaults(props, {
    music = {},
    key = {0, 1},
    octave = 0
  })
  local result = {}
  for _, playing in ipairs(props.music) do
    if playing.type ~= "note" then
      table.insert(result, playing)
    else
      table.insert(result, {
        type = "note",
        note = notes.inKey(playing.note, props.key, props.octave),
        time = playing.time
      })
    end
  end
  return result
end


function modules.musicEvents(state, props)
  utils.defaults(state, {
    active = {}
  })
  props = utils.idefaults(props, {
    music = {}
  })
  local stream = {}
  local music = props.music

  local deleted = {}

  local result = {}

  -- clear out no longer active music
  for i, playing in ipairs(state.active) do
    if not note_exists_in(playing, props.music) then
      table.insert(deleted, i)
      table.insert(result, {"off", playing})
    end
  end
  local count = 0
  for _, i in ipairs(deleted) do
    table.remove(state.active, i - count)
    count = count + 1
  end

  -- insert new music
  for i, playing in ipairs(props.music) do
    if not note_exists_in(playing, state.active) then
      table.insert(state.active, playing)
      table.insert(result, {"on", playing})
    end
  end
  return result
end

function modules.musicEventsToMidi(music_events)
  local result = {}
  for _, event in ipairs(music_events) do
    local type, playing = unpack(event)
    if playing.type == "note" then
      local command = MIDI.NOTE_ON
      local velocity = playing.velocity or 127
      if type == "off" then
        command = MIDI.NOTE_OFF
        velocity = 0
      end
      table.insert(result, {command, tools.toPitch(playing.note), velocity})
    elseif playing.type == "porta" then
      local value = playing.value
      if type == "off" then
        value = 0
      end
      table.insert(result, {MIDI.CC, MIDI.CC_PORTA_TIME, value})
    end
  end

  return result
end

function modules.midiStream(state, props)
  utils.defaults(state, {
    music_events = {}
  })
  props = utils.idefaults(props, {
    music = {}
  })
  local music_events = modules.musicEvents(state.music_events, {
    music = props.music
  })
  local midi_events = modules.musicEventsToMidi(music_events)
  return midi_events
end

function modules.recordEvents(state, props)
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
    -- print(message[1])
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

modules.recordMidiStream = modules.recordEvents

function arraysAreEqual(a, b)
  if #a ~= #b then
    return false
  end
  for i, v in ipairs(a) do
    if b[i] ~= v then
      return false
    end
  end
  return true
end

function applyMult(value, mult)
  return value * mult[1] / mult[2]
end

function modules.multiplyClock(state, props)
  props = utils.idefaults(props, {
    clock = {
      beat = -1,
      prev_beat = -1,
      fraction = 0.0,
      prev_fraction = 0.0
    },
    multiplier = {1, 1}
  })
  utils.defaults(state, {
    started = false,
    beat = props.clock.beat,
    fraction = props.clock.fraction,
    mult_count = 0,
    multiplier = props.multiplier
  })

  local prev_beat = state.beat
  local prev_fraction = state.fraction

  
  local clock = props.clock
  local parent_clicks = clock.beat - clock.prev_beat
  if not state.started and parent_clicks > 0 and clock.beat % state.multiplier[2] == 0 then
    state.started = true
    state.div_count = state.multiplier[2] - 1
  end
  if state.started then
    local click = false

    local prev_mult_count = state.mult_count
    state.mult_count = math.floor(clock.fraction * state.multiplier[1])
    for i=1, parent_clicks do
      state.div_count = state.div_count + 1
    end
    if prev_mult_count < state.mult_count then
      for i=prev_mult_count + 1, state.mult_count do
        state.div_count = state.div_count + 1
      end
    end
    while state.div_count >= state.multiplier[2] do
      state.beat = state.beat + 1
      state.div_count = state.div_count - state.multiplier[2] 
      click = true
    end

    _, state.fraction = math.modf(clock.fraction * state.multiplier[1] / state.multiplier[2])
    state.fraction = state.fraction + state.div_count / state.multiplier[2]

    if click and parent_click and not arraysAreEqual(props.multiplier, state.multiplier) then
      state.multiplier = props.multiplier
    end
  end

  return {
    beat = state.beat,
    fraction = state.fraction,
    prev_beat = prev_beat,
    prev_fraction = prev_fraction
  }

end

math.tau = math.pi * 2

function modules.lfo(props)
  props = utils.idefaults(props, {
    clock = {
      fraction = 0.0,
      prev_fraction = 0.0
    },
    min = 0,
    max = 1
  })
  local sin = math.sin(props.clock.fraction * math.tau)
  return utils.map(sin, -1, 1, props.min, props.max)
end


function modules.devices(state)
  utils.defaults(state, {
    i = {},
    o = {},
    loaded = false,
  })
  if not state.loaded then
    for port, name in pairs(luamidi.enumerateinports()) do
      state.i[name] = port
      print(string.format('"%s" input connected', name))
    end
    for port, name in pairs(luamidi.enumerateoutports()) do
      state.o[name] = port
      print(string.format('"%s" output connected', name))
    end
    state.loaded = true
  end
  return state.i, state.o
end

function modules.shiftOctave(props)
  props = utils.idefaults(props, {
    music = {},
    shift = 0
  })
  local result = {}
  for _, playing in ipairs(props.music) do
    if playing.type == "note" then
      playing = utils.copy(playing)
      local octave, step, accidental = unpack(playing.note)
      playing.note = {octave + props.shift, step, accidental}
    end
    table.insert(result, playing)
  end
  return result
end

return modules