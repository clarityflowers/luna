
local midi_utils = {}
local luamidi = require "luamidi"

local MIDI_CC = 176
local KNOB_PORT = 1


function midi_utils.round(value)
  if value - math.floor(value) < 0.5 then
    return math.floor(value)
  else
    return math.ceil(value)
  end
end

function midi_utils.toRange(ccv, min, max, ccmax, fractional)
  ccmax = ccmax or 128
  if fractional then
    return ccv * (max - min) / (ccmax - 1) + min
  end
  local value = ccv * (max - min + 1) / (ccmax) + min
  if max - min > ccmax then
    return midi_utils.round(value)
  else
    return math.floor(value)
  end
end

function midi_utils.fromRange(v, min, max, ccmax)
  ccmax = ccmax or 128
  local ccv = (v - min) * (ccmax - 1) / (max - min)
  local result = math.min(math.max(midi_utils.round(ccv), 0), ccmax)
  return result
end

function midi_utils.toMultiplier(cc)
  if cc > 63 then
    return {midi_utils.toRange(cc - 64, 1, 16, 64), 1}
  else
    return {1, midi_utils.toRange(63 - cc, 1, 16, 64)}
  end
end

function midi_utils.fromMultiplier(mult)
  if mult[2] == 1 then
    return midi_utils.fromRange(mult[1], 1, 16, 64) + 64
  else
    return midi_utils.fromRange(17 - mult[2], 1, 16, 64)
  end
end

function midi_utils.useKnob(inputs, knobs, knob_i, value, options)
  if knobs == nil then return value end

  options = options or {}
  local min = options.min or 0
  local max = options.max or 127
  local color = options.color or nil
  local animation = options.animation or nil
  local speed = options.speed or 5
  local fractional = options.round == false
  local result = value
  for _, input in pairs(inputs) do
    local command, message, v1, v2, channel = unpack(input)
    if (
      command == "KNOBS" and
      message == MIDI_CC and
      v1 == knob_i and
      channel == 0
    )  then
      result = midi_utils.toRange(v2, min, max, nil, fractional)
    end
  end
  local knob = knobs[knob_i + 1]
  local value_changed = false
  if knob.value ~= value then
    value_changed = true
    luamidi.sendMessage(KNOB_PORT, MIDI_CC, knob_i, midi_utils.fromRange(value, min, max))
    knob.value = value
  end
  if knob.color ~= color or (color == "value" and value_changed) then
    local color_cc = 0
    local color_value = color
    if color == "value" then
      color_value = ((value - min) / (max - min)) * 0.7 + 0.05
    end
    if color_value ~= nil then
      color_cc = midi_utils.fromRange(color_value, 0, 1)
    end
    luamidi.sendMessage(KNOB_PORT, MIDI_CC, knob_i, color_cc, 1)
    knob.color = color
  end
  if knob.animation ~= animation or knob.speed ~= speed then
    local anim_v = 0
    if animation == "strobe" then
      anim_v = 1 + speed
    elseif animation == "pulse" then
      anim_v = 9 + speed
    elseif animation == "rainbow" then
      anim_v = 127
    end
    luamidi.sendMessage(KNOB_PORT, MIDI_CC, knob_i, anim_v, 2)
    knob.animation = animation
    knob.speed = speed
  end
  return result
end

function midi_utils.knobPressed(inputs, knobs, i)
  if knobs == nil then return false, false, false end
  local knob = knobs[i + 1]
  if not knob then
    print("bad knob?", i)
    return false, false, false
  end
  local clicked = false
  local released = false
  for _, input in pairs(inputs) do
    local command, message, v1, v2, channel = unpack(input)
    if (
      command == "KNOBS" and
      message == MIDI_CC and
      v1 == i and
      channel == 1
    )  then
      if v2 == 0 then
        knob.pressed = false
        released = true
      else
        knob.pressed = true
        clicked = true
      end
    end
  end
  return knob.pressed, clicked, released
end

function midi_utils.knobClicked(inputs, knobs, i)
  local _, clicked = midi_utils.knobPressed(inputs, knobs, i)
  return clicked
end

return midi_utils