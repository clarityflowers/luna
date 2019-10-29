local luamidi = require("luamidi")
local MIDI = require("midi_constants")
local miditools = {}

local KNOB_PORT = 1

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

miditools.OUT_PORT = 2
miditools.KNOB_PORT = KNOB_PORT

function miditools.toPitch(note)
  if not note then return nil end
  local octave, letter, accidental = unpack(note)
  if octave == nil then return nil end
  local pitch = (octave + 5) * 12 + letters_to_pitches[letter] + accidental
  return pitch
end

function miditools.toNote(pitch)
  local octave =  math.floor(pitch / 12)
  local note = {
    octave,
    unpack(pitches_to_default_notes[pitch % 12])
  }
  return note
end

function miditools.round(value)
  if value - math.floor(value) < 0.5 then
    return math.floor(value)
  else
    return math.ceil(value)
  end
end

function miditools.toRange(ccv, min, max, ccmax, fractional)
  ccmax = ccmax or 128
  if fractional then
    return ccv * (max - min) / (ccmax - 1) + min
  end
  local value = ccv * (max - min + 1) / (ccmax) + min
  if max - min > ccmax then
    return miditools.round(value)
  else
    return math.floor(value)
  end
end

function miditools.fromRange(v, min, max, ccmax)
  ccmax = ccmax or 128
  local ccv = (v - min) * (ccmax - 1) / (max - min)
  local result = math.min(math.max(miditools.round(ccv), 0), ccmax)
  return result
end


function miditools.useKnob(inputs, knobs, knob_i, value, options)
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
      not input.handled and
      command == "KNOBS" and
      message == MIDI.CC and
      v1 == knob_i and
      channel == 0
    )  then
      input.handled = true
      result = miditools.toRange(v2, min, max, nil, fractional)
    end
  end
  local knob = knobs[knob_i + 1]
  local value_changed = false
  if knob.value ~= value then
    value_changed = true
    luamidi.sendMessage(KNOB_PORT, MIDI.CC, knob_i, miditools.fromRange(value, min, max))
    knob.value = value
  end
  if knob.color ~= color or (color == "value" and value_changed) then
    local color_cc = 0
    local color_value = color
    if color == "value" then
      color_value = ((value - min) / (max - min)) * 0.7 + 0.05
    end
    if color_value ~= nil then
      color_cc = miditools.fromRange(color_value, 0, 1)
    end
    luamidi.sendMessage(KNOB_PORT, MIDI.CC, knob_i, color_cc, 1)
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
    luamidi.sendMessage(KNOB_PORT, MIDI.CC, knob_i, anim_v, 2)
    knob.animation = animation
    knob.speed = speed
  end
  return result
end

local function knobPressed(inputs, knobs, i)
  if knobs == nil then return false, false, false end
  local knob = knobs[i + 1]
  if not knob then
    print("bad knob?", i)
    return false, false, false
  end
  local clicked = false
  local released = false
  for _, input in pairs(inputs) do
    if not input.handled then
      local command, message, v1, v2, channel = unpack(input)
      if (
        command == "KNOBS" and
        message == MIDI.CC and
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
        input.handled = true
      end
    end
  end
  return knob.pressed, clicked, released
end

function miditools.knobClicked(inputs, knobs, i)
  local _, clicked = knobPressed(inputs, knobs, i)
  return clicked
end

function miditools.clear(port, channel)
  luamidi.sendMessage(port, MIDI.CC, MIDI.CC_CLEAR, 0, channel)
end

return miditools