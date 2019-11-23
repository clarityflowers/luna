local livereload = require "livereload"
local utils = livereload "utils"
local MIDI = livereload "midi_constants"
local luamidi = require "luamidi"


local devices = {
  midifighter = {
    twister = {}
  },
  midi = {}
}

local twister = devices.midifighter.twister
local midi = devices.midi

function midi.receive(port)
  if port == nil then
    return {}
  end
  local messages = {}
  repeat
    local message_and_channel, v1, v2 = luamidi.getMessage(port)
    if message_and_channel then
      local channel = message_and_channel % 16 + 1
      local message = message_and_channel - channel + 1
      table.insert(messages, {message, v1, v2, channel})
    end
  until not message_and_channel
  return messages
end

function midi.channel(messages, channel)
  local result = {}
  for _, message in ipairs(messages) do
    local type, v1, v2, message_channel = unpack(message)
    if message_channel == channel then
      table.insert(result, {type, v1, v2})
    end
  end
  return result
end

function midi.send(port, messages, channel)
  if port == nil then
    return
  end
  for _, message in pairs(messages) do
    local type, v1, v2 = unpack(message)
    -- print(port, type, v1, v2, channel - 1)
    luamidi.sendMessage(port, type, v1, v2, channel - 1)
  end
end

twister.name = "Midi Fighter Twister"

function twister.init(inDevices, outDevices)
  local result = {}
  local knobs = {}
  local inPort = inDevices[twister.name]
  local outPort = outDevices[twister.name]

  local i
  for i=1, 16, 1 do
    knobs[i] = {
      value = 0,
      out_value = 0,
      color = 0,
      changed = false,
      pressed = false,
      clicked = false,
      released = false
    }
  end

  result.version = 1

  function result:receive()
    local messages = midi.receive(inPort)
    for _, knob in ipairs(knobs) do
      knob.changed = false
      knob.clicked = false
      knob.released = false
    end
    for _, message in ipairs(midi.channel(messages, 1)) do
      local type, knob_i, value = unpack(message)
      local knob = knobs[knob_i + 1]
      if type == MIDI.CC and value ~= knob.value then
        knob.changed = true
        knob.value = value
      end
    end
    for _, message in ipairs(midi.channel(messages, 2)) do
      local type, knob_i, value = unpack(message)
      local knob = knobs[knob_i + 1]
      if type == MIDI.CC then
        if value == 0 then
          knob.pressed = false
          knob.released = true
        else
          knob.pressed = true
          knob.clicked = true
        end
      end
    end
  end

  function result:knob(knob_i, value, props)
    props = utils.idefaults(props, {
      min = 0,
      max = 1,
      ccMin = 0,
      ccMax = 127,
      int = false
    })
    local knob = knobs[knob_i]

    if knob.changed then
      knob.out_value = utils.map(knob.value, props.ccMin, props.ccMax, props.min, props.max)
      if props.int then
        knob.out_value = utils.round(knob.out_value)
      end
    else
      local new_midi_value = utils.mapInt(value, props.min, props.max, props.ccMin, props.ccMax)
      if (knob.value ~= new_midi_value) then
        knob.out_value = value
        knob.value = new_midi_value
        midi.send(outPort, {{MIDI.CC, knob_i - 1, new_midi_value}}, 1)
      end
    end

    return knob.out_value
  end

  function result:color(knob_i, value)
    local knob = knobs[knob_i]
    if knob.color ~= value then
      midi.send(outPort, {{MIDI.CC, knob_i - 1, value}}, 2)
      knob.color = value
    end
  end

  return result
end

return devices