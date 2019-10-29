local luamidi = require "luamidi"
local metropolis = require "metropolis_midi"
local riverboat = require "riverboat"
local watermill = require "watermill_midi"
local tools = require "miditools"
local modes = require "modes"

local result = {}
local MIDI = require("midi_constants")


local function midiClear(port, channel)
  luamidi.sendMessage(port, MIDI.CC, MIDI.CC_CLEAR, 0, channel)
end

local KNOBS_PORT = 1
local OUT_PORT = 2
local IN_PORT = 2

local function toMultiplier(cc)
  if cc > 63 then
    return {tools.toRange(cc - 64, 1, 16, 64), 1}
  else
    return {1, tools.toRange(63 - cc, 1, 16, 64)}
  end
end

local function fromMultiplier(mult)
  if mult[2] == 1 then
    return tools.fromRange(mult[1], 1, 16, 64) + 64
  else
    return tools.fromRange(17 - mult[2], 1, 16, 64)
  end
end

function result.run(state, dt, inputs)
  if state == nil then
    state = {
      fraction = 0.0,
      beat = 0,
      bpm = 100,
      multiplier = {1, 1},
      tracks = {},
      code = {
        lines = {}
      },
      selected_track = 0,
      pause = false,
      in_devices = nil,
      out_devices = nil,
      knobs = nil
    }
  end
  local beats_per_s = state.bpm * state.multiplier[1] / state.multiplier[2] / 60
  local code = state.code
  local do_pause = false

  local is_global_beat = false
  local prev_global_fraction = state.fraction

  if state.in_devices == nil then
    print "Load MIDI in"
    state.in_devices = luamidi.enumerateinports()
    for port, device in pairs(state.in_devices) do
      print(port, device)
    end
    print "Load MIDI in success"
  end
  if state.out_devices == nil then
    print "Load MIDI out"
    state.out_devices = luamidi.enumerateoutports()
    for port, device in pairs(state.out_devices) do
      print(port, device)
    end
    print "Load MIDI out Success"
  end

  if state.knobs == nil and state.out_devices[KNOBS_PORT] then
    state.knobs = {}
    for _ = 1, 16, 1 do
      table.insert(state.knobs, {
        value = 0,
        color = nil,
        animation = nil,
        speed = nil,
        pressed = false
      })
    end
  end

  inputs = {unpack(inputs)}

  if state.in_devices[IN_PORT] then
    repeat
      local message_and_channel, v1, v2 = luamidi.getMessage(IN_PORT)
      if message_and_channel then
        local channel = message_and_channel % 16
        local message = message_and_channel - channel
        table.insert(inputs, {"MIDI", message, v1, v2, channel})
      end
    until not message_and_channel
  end
  if state.in_devices[KNOBS_PORT] and state.out_devices[KNOBS_PORT] then
    repeat
      local message_and_channel, v1, v2 = luamidi.getMessage(KNOBS_PORT)
      if message_and_channel then
        local channel = message_and_channel % 16
        local message = message_and_channel - channel
        table.insert(inputs, {"KNOBS", message, v1, v2, channel})
      end
    until not message_and_channel
  end

  local deleted_track = nil

  for _, input in pairs(inputs) do
    local command = input[1]
    if command == "quit" then
      if (state.out_devices[OUT_PORT]) then
        midiClear(OUT_PORT)
      end
      return "quit"
    elseif command == "key" then
      local _, key, ctrl, shift = unpack(input)
      if not ctrl and not shift then
        if key == "-" then
          input.handled = true
          print "hey"
          deleted_track = state.selected_track
        elseif key == "up" then
          input.handled = true
          if state.selected_track <= 1 then
            state.selected_track = #state.tracks
          else
            state.selected_track = state.selected_track - 1
          end
        elseif key == "down" then
          input.handled = true
          if state.selected_track >= #state.tracks then
            state.selected_track = 1
          else
            state.selected_track = state.selected_track + 1
          end
        end
      end
    end
  end

  if #state.tracks > 1 then
    state.selected_track = tools.useKnob(inputs, state.knobs, 0, state.selected_track, {
      min = 1,
      max = #state.tracks,
      color = "value"
    })
  end

  -- global pause
  if tools.knobClicked(inputs, state.knobs, 0) then
    do_pause = true
    if state.pause then
      luamidi.sendMessage(OUT_PORT, 250, 0, 0)
      state.pause = false
    else
      state.pause = true
    end
  end

  -- insert track
  if tools.knobClicked(inputs, state.knobs, 1) then
    table.insert(
      state.tracks,
      state.selected_track + 1,
      {"?", 1}
    )
    state.selected_track = state.selected_track + 1
  end

  local toggle_sequence_play = false

  -- start sequence
  if tools.knobClicked(inputs, state.knobs, 4) then
    toggle_sequence_play = true
    if state.pause then
      state.pause = false
      luamidi.sendMessage(OUT_PORT, 250, 0, 0)
    end
  end


  local bpm_color = 0.15
  if not state.pause and state.fraction > 0.2 then
    bpm_color = nil
  end
  state.bpm = tools.useKnob(inputs, state.knobs, 1, state.bpm / 2, {
    min = 20,
    max = 100,
    color = bpm_color,
  }) * 2
  if tools.knobClicked(inputs, state.knobs, 2) then
    state.multiplier = {1, 1}
  end
  state.multiplier = toMultiplier(tools.useKnob(inputs, state.knobs, 2, fromMultiplier(state.multiplier), {
    color = "value",
  }))

  -- clock
  local prev_beat = state.beat
  if not state.pause then
    state.fraction = state.fraction + (dt * beats_per_s)
    if state.fraction > 1 then
      state.beat = state.beat + 1
      state.fraction = state.fraction - 1
      is_global_beat = true
    end
    if (
      (
        math.floor(prev_global_fraction * 24) <
        math.floor(state.fraction * 24)
      ) or
      is_global_beat
    ) then
      -- luamidi.sendMessage(OUT_PORT, 248, 0, 0)
      -- if state.out_devices[KNOBS_PORT] then
        -- luamidi.sendMessage(KNOBS_PORT, 248, 0, 0)
      -- end
    end
  end

  local clock = {
    beat = state.beat,
    fraction = state.fraction,
    is_beat = is_global_beat,
    prev_fraction = prev_global_fraction,
    time = state.beat + state.fraction,
    prev_time = prev_beat + prev_global_fraction
  }

  for track_index, track in pairs(state.tracks) do
    local selected = state.selected_track == track_index
    local track_inputs = {}
    local track_knobs = nil
    if selected then
      track_inputs = inputs
      track_knobs = state.knobs
    end
    local info = {
      selected = selected,
      start = selected and toggle_sequence_play,
      delete = deleted_track == track_index,
      pause = do_pause,
      in_devices = state.in_devices,
      clock = clock
    }
    local options = nil
    if track[1] == "metropolis" then
      track[2] = metropolis.midi(track[2], info, track_inputs, track_knobs)
    elseif track[1] == "riverboat" then
      track[2], options = riverboat.midi(track[2], info, track_inputs, track_knobs)
    elseif track[1] == "watermill" then
      track[2], options = watermill.midi(track[2], info, track_inputs, track_knobs)
    else
      if selected then
        track[2] = tools.useKnob(track_inputs, track_knobs, 4, track[2], {
          min = 1,
          max = #modes
        })
        if toggle_sequence_play then
          print("select mode", modes[track[2]])
          track[1] = modes[track[2]]
          track[2] = nil
        end
      end
    end
    if options then
      if options.convert_to then
        track[1] = options.convert_to
        print("convert " .. track_index .. " to " .. options.convert_to)
      end
    end
  end

  if deleted_track then
    print "hi"
    table.remove(state.tracks, deleted_track)
    if state.selected_track == 1 and #state.tracks > 1 then
      state.selected_track = state.selected_track + 1
    else
      state.selected_track = state.selected_track - 1
    end
  end

  return state
end

return result