local livereload = require "livereload"
local utils = livereload "utils"
local modules = livereload "modules"
local notes = livereload "notes"
local MIDI = livereload "midi_constants"
local tools = livereload "miditools"
local luamidi = require "luamidi"
local devices = livereload "devices"
local seq = livereload "sequence"

local rack = {}

local DEVICE = "Port 1"

function simpleGenerativeSequencer(state, props)
  props = utils.idefaults(props, {
    clock = {
      beat = 0,
      fraction = 0,
      prev_beat = 0,
      prev_fraction = 0
    },
    generator = function() return {} end,
    key = {0, 1},
    out_devices = {},
    out_device = "",
    channel = 1,
    gate_time = 0.5,
    porta_time = 127,
    multiplier = {1, 1},
    window = 16,
    name = nil
  })



  utils.defaults(state, {
    clock = {},
    sequencer = {},
    inKey = {},
    music_events = {},
    music_recording = {},
    midi_recording = {}
  })

  local result = {}
  result.name = props.name

  result.clock = modules.multiplyClock(state.clock, {
    clock = props.clock,
    multiplier = props.multiplier
  })
  local music = modules.generativeSequencer(state.sequencer, {
    clock = result.clock,
    gate_time = props.gate_time,
    porta_time = props.porta_time,
    generate = props.generator
  })
  
  music = modules.inKey(state.inKey, {
    music = music,
    key = props.key
  })
  
  
  local music_events = modules.musicEvents(state.music_events, {
    music = music
  })
  
  result.music_recording = modules.recordEvents(state.music_recording, {
    stream = music_events,
    clock = result.clock,
    window = props.window
  })
  
  local midi_events = modules.musicEventsToMidi(music_events)

  -- if #midi_events > 0 then
  --   print(#midi_events)
  -- end

  result.midi_recording = modules.recordEvents(state.midi_recording, {
    stream = midi_events,
    clock = result.clock,
    window = props.window
  })

  devices.midi.send(props.out_devices[DEVICE], midi_events, props.channel)

  return result
end

function simpleSequencer(state, props)
  props = utils.idefaults(props, {
    clock = {
      beat = 0,
      fraction = 0,
      prev_beat = 0,
      prev_fraction = 0
    },
    sequence = {},
    key = {0, 1},
    out_devices = {},
    out_device = "",
    channel = 1,
    gate_time = 0.5,
    porta_time = 127,
    multiplier = {1, 1},
    octave_shift = 0,
    name = nil
  })
  utils.defaults(state, {
    clock = {},
    sequencer = {},
    inKey = {},
    midiStream = {},
    midiRecording = {},
  })

  local result = {}

  result.name = props.name

  result.clock = modules.multiplyClock(state.clock, {
    clock = props.clock,
    multiplier = props.multiplier
  })


  local music
  music, result.sequence = modules.sequencer(state.sequencer, {
    clock = result.clock,
    gate_time = props.gate_time,
    sequence = props.sequence,
    porta_time = props.porta_time,
    generate = generator
  })

  music = modules.inKey(state.inKey, {
    music = music,
    key = props.key
  })

  music = modules.shiftOctave({
    music = music,
    shift = props.octave_shift
  })

  local midiStream = modules.midiStream(state.midiStream, {
    music = music
  })

  result.midi_recording = modules.recordMidiStream(state.midiRecording, {
    stream = midiStream,
    clock = result.clock,
    window = #props.sequence * 2
  })

  devices.midi.send(props.out_devices[DEVICE], midiStream, props.channel)

  return result
end

local channels = {}

function modules.midiSync(props)
  props = utils.idefaults(props, {
    clock = {
      beat = 0,
      fraction = 0,
      prev_beat = 0,
      prev_fraction = 0
    }
  })
  local clock = props.clock
  local time = clock.beat + clock.fraction
  local prev_time = clock.prev_beat + clock.prev_fraction
  local sync_count = math.floor(time * 24) - math.floor(prev_time * 24)
  local events = {}
  local i
  for i=1, sync_count do
    table.insert(events, {MIDI.SYNC, 0, 0})
  end
  return events
end

function rack.update(state, dt, inputs)
  local perf_start = love.timer.getTime()

  utils.defaults(state, {
    init = false,
    phase = 0,
    advance_phase = false,
    perf = {},
    perf_2 = {},
    clock = {},
    looper_clock = {},
    devices = {},
    twister = nil,
    plaits = {},
    channels = {}
  })


  local OUT = 0
  local KNOBS = 1

  local render = {}

  local in_devices, out_devices = modules.devices(state.devices)

  if state.twister == nil or state.twister.version < 1 then
    state.twister = devices.midifighter.twister.init(in_devices, out_devices)
  end

  local tempo = {
    bpm = 120,
    multiplier = {1, 1}
  }

  for _, input in ipairs(inputs) do
    local command = unpack(input)
    if command == "quit" then
      print ("quit!")
      for _, port in pairs(out_devices) do
        local channel = 0
        for channel = 0, 15 do
          luamidi.sendMessage(port, MIDI.CC, MIDI.CC_CLEAR, 0, channel)
        end
      end
      return "quit"
    elseif command == "key" then
      local key = input[2]
      if key == "space" then
        state.advance_phase = true
      end
    end
  end


  state.twister:receive()

  render.perf = modules.perf(state.perf, dt)
  -- state.tempo.bpm = 2 * state.twister:knob(1, state.tempo.bpm / 2, {
  --   min = 20,
  --   max = 100,
  --   int = true
  -- })


  render.tempo = tempo
  
  local clock = modules.clock(state.clock, {
    tempo = tempo,
    dt = dt
  })
  render.clock = clock


  if state.init == false and render.clock.beat > 0 then
    state.init = true
    devices.midi.send(out_devices[DEVICE], {{MIDI.START, 0, 0}}, 1)
  end


  if state.advance_phase and clock.prev_beat ~= clock.beat and clock.beat % 4 == 0 then
    state.advance_phase = false
    state.phase = state.phase + 1
  end



  local sync_events = modules.midiSync({
    clock = render.clock
  })
  devices.midi.send(out_devices[DEVICE], sync_events, 1) 




  local bpmColor = 0
  if render.clock.fraction >= 0.5 then
    bpmColor = 95
  end
  state.twister:color(1, bpmColor)

  render.key = {1, 6}

  local channel_i = 1


  render.channels = {}  


  -- plaits (generative)
  
  channel_i = 1
  if state.phase >= 1 then
    utils.defaults(state.channels, { [channel_i] = {} })

    local channel = state.channels[channel_i]
    utils.defaults(channel, {
      sequencer = {},
      pattern = {
        {0, 5}, {0, 4}, {0, 1},
        {0, 5}, {0, 2}, {-1, 5},
        {0, 1}, {0, 7}
      },
      position = 0,
      trigger = 0,
    })

    local function generator()
      local prev_length = #channel.pattern
      if channel.position >= 0 then
        channel.position = channel.position + 1
        if channel.position > #channel.pattern then
          channel.position = -1

          if #channel.pattern >= 8 and #channel.pattern < 32 and math.random() > 0.99 then
            local length = #channel.pattern
            local i
            for i=1, length do
              table.insert(channel.pattern, channel.pattern[i])
            end
          end 

          if math.random() > 0.5 then
            local between = math.floor(math.random(#channel.pattern - 1))
            local new = nil
            local after_note =  channel.pattern[between + 1]

            if #channel.pattern >= 8 then
              local removed_note = channel.pattern[between]
              new = removed_note[1] * 7 + removed_note[2]
              table.remove(channel.pattern, between)
            end
            local before_note = channel.pattern[between]
            local after = after_note[1] * 7 + after_note[2]
            local before = before_note[1] * 7 + before_note[2]
            local random = math.random()
            local options = {}
            table.insert(options, "octave")
            if #channel.pattern > 2 and between > 1 and #channel.pattern < 7 then
              table.insert(options, "delete")
            end
            if math.abs(after - before) == 2 then
              table.insert(options, "passing")
            end
            table.insert(options, "neighbor")
            if (before_note[2] ~= 1 and after_note[2] ~= 1) then
              table.insert(options, "root")
            end
            if (before_note[2] ~= 5 and after_note[2] ~= 5) then
              table.insert(options, "fifth")
            end



            local operation = options[math.random(#options)]

            if operation == "delete" then
              table.remove(channel.pattern, between)
            elseif operation == "passing" then
              if after > before then
                new = after - 1
              else
                new = after + 1
              end
            elseif operation == "neighbor" then
              local neighbor_opts = {}
              if after - before ~= 1 then
                table.insert(neighbor_opts, after - 1)
                table.insert(neighbor_opts, before + 1)
              end
              if before - after ~= 1 then
                table.insert(neighbor_opts, after + 1)
                table.insert(neighbor_opts, before - 1)
              end
              new = neighbor_opts[math.random(#neighbor_opts)]
            elseif operation == "octave" then
              local shift = 1
              if before_note[1] >= 2 then
                shift = -1
              elseif before_note[1] <= 0 then
                shift = 1
              elseif math.random() < 0.3 then
                shift = -1
              end
              channel.pattern[between] = notes.normalize({shift, before})
            elseif operation == "root" then
              new = 1
            elseif operation == "fifth" then
              new = -2
              if math.random() > 0.7 then
                new = new + 7
              end
            end
            if new == "rest" then
              table.insert(channel.pattern, between + 1, nil)
            elseif new then
              local new_note = {0, new}
              table.insert(channel.pattern, between + 1, notes.normalize(new_note))
            end
          end
        end
      end


      if channel.position == -1 then
        if #channel.pattern >= 8 then
          channel.position = 1
        else
          channel.trigger = channel.trigger + 0.05
          if math.random() < channel.trigger then
            channel.trigger = 0
            channel.position = 1
          end
        end
      end
      
      -- if math.random() > 0.9 then
      --   return {}
      if channel.position <= 0 then
        return {}
      else
        return {note = channel.pattern[channel.position]}
      end
    end


    render.channels[channel_i] = simpleGenerativeSequencer(channel.sequencer, {
      name = "Mother-32 (Generative Melody)",
      clock = render.clock,
      key = render.key,
      generator = generator,
      channel = channel_i,
      gate_time = 0.1,
      multiplier = {4, 1},
      out_devices = out_devices,
      window = 64
    })

    channel_i = channel_i + 1
  else
    render.channels[channel_i] = {}
  end
  

  -- 0-coast (rhythm)
  channel_i = 2
  if state.phase >= 2 then
    utils.defaults(state.channels, { [channel_i] = {} })
    render.channels[channel_i] = simpleGenerativeSequencer(state.channels[channel_i], {
      name = "Plaits > Optomix (Drums)",
      clock = render.clock,
      key = render.key,
      sequence = {
        {note = {0, 1}},
        {note = {0, 2}},
        {note = {0, 3}},
        {},
      },
      generator = function()
        if math.random() > 0.5 then
          if math.random() > 0.8 then
            return {note = {3, 1}}
          else
            return {note = {-2, 1}}
          end
        else
          return {}
        end
      end,
      channel = channel_i,
      multiplier = {2, 1},
      out_devices = out_devices
    })
  else
    render.channels[channel_i] = {}
  end
  


  -- drone
  channel_i = 3
  if state.phase >= 3 then
    utils.defaults(state.channels, { [channel_i] = {} })
    local channel
    render.channels[channel_i] = simpleSequencer(state.channels[channel_i], {
      name = "0-Coast (Drone)",
      clock = render.clock,
      key = render.key,
      generator = function()
        if math.random() > 0.5 then
          return {note = {math.random(2) - 3, 1}}
        else
          return {}
        end
      end,
      sequence = {
        {note = {-1, 3}},
        {note = {-1, 1}},
        {note = {-1, 6}},
        {note = {-1, 5}},
      },
      octave_shift = -1,
      porta_time = 3,
      channel = channel_i,
      gate_time = 0.5,
      multiplier = {1, 4},
      out_devices = out_devices
    })
  else
    render.channels[channel_i] = {}
  end


  -- clock
  
  channel_i = 4
  if true then 
    utils.defaults(state.channels, { [channel_i] = {} })
    simpleSequencer(state.channels[channel_i], {
      name = "Clock",
      clock = render.clock,
      key = render.key,
      sequence = {
        {note = {0, 1}}
      },
      channel = channel_i,
      porta_time = 7,
      multiplier = {4, 1},
      out_devices = out_devices
    })
    channel_i = channel_i + 1
  end


  -- do 
  --   utils.defaults(state.channels, { [channel_i] = {} })
  --   render.channels[channel_i] = simpleSequencer(state.channels[channel_i], {
  --     name = "Hat",
  --     clock = render.clock,
  --     key = render.key,
  --     sequence = {
  --       {note = {0, 1}},
  --       {},
  --       {},
  --       {note = {0, 1}},
  --       {},
  --       {},
  --       {note = {0, 1}},
  --       {note = {0, 1}},
  --       {},
  --       {},
  --       {},
  --       {note = {0, 1}},
  --       {},
  --       {},
  --       {},
  --       {},
  --     },
  --     channel = channel_i,
  --     gate_time = 0.5,
  --     multiplier = {4, 1},
  --     out_devices = out_devices
  --   })
  --   channel_i = channel_i + 1
  -- end



  render.perf_2 = modules.perf(state.perf_2, love.timer.getTime() - perf_start)
  return render
end


return rack