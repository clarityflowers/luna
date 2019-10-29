local livereload = require "livereload2"
local tools = livereload.init("draw_tools.lua")
local constants = livereload.init("draw_constants.lua")
local notes = livereload.init("notes.lua")
local draw = livereload.init("music_draw.lua")
local utils = livereload.init('utils.lua')
local midiconst = livereload.init 'midi_constants.lua'

local rack = {}

function draw.midiRecording(state, props)
  utils.defaults(state, {
    min = nil,
    max = nil
  })
  props = utils.idefaults(props, {
    recording = {
      start_time = 0,
      current_time = 0,
      events = {}
    },
    x = 0,
    y = 0,
    width = 300,
    height = 50,
    clock = nil,
  })
  local top = props.y
  local bottom = top + props.height
  local left = props.x
  local right = left + props.width
  love.graphics.line(right, top, right, bottom)
  love.graphics.line(left, top, left, bottom)
  local on_notes = {}

  for _, record in ipairs(props.recording.events) do
    local _, event = unpack(record)
    local message, v1 = unpack(event)

    if message == midiconst.NOTE_ON then
      if state.min == nil or state.min > v1 then
        state.min = v1
      end
      if state.max == nil or state.max < v1 then
        state.max = v1
      end
    end
  end

  for _, record in ipairs(props.recording.events) do
    local time, event = unpack(record)
    local time_ago = props.recording.current_time - time
    local time_x = props.x
    local time_range = props.recording.current_time - props.recording.start_time
    if time >= props.recording.start_time then
      time_x = time_x - time_ago / time_range * props.width + props.width
    end

    local message, v1 = unpack(event)
    if message == midiconst.NOTE_ON then
      on_notes[v1] = time_x
    elseif message == midiconst.NOTE_OFF then
      local on_x = on_notes[v1]
      if on_x then
        on_notes[v1] = nil
      else
        on_x = left
      end
      local note_relative = 1.0 - (v1 - state.min) / (state.max - state.min)
      local note_y = note_relative * props.height + props.y
      love.graphics.line(on_x, note_y, time_x, note_y)
    end
  end
  for v1, on_x in pairs(on_notes) do
    local note_relative = 1.0 - (v1 - state.min) / (state.max - state.min)
    local note_y = note_relative * props.height + props.y
    love.graphics.line(on_x, note_y, right, note_y)
  end
  return x, y
end

function rack.draw(music, state, dt)
  local flow_y = 20
  local x = 20
  local width = love.graphics.getWidth() - (x * 2)
  width = 230
  love.graphics.setColor(draw.colors.black)
  local height = love.graphics.getHeight()

  flow_y = flow_y + 100

  utils.defaults(state, {
    staff = {},
    clock = {},
    midiStream = {},
    midiRecording = {}
  })

  love.graphics.setColor(draw.colors.black)
  draw.perf({
    perf = music.perf,
    x = 3,
    y = height - 3,
    attach_y = "bottom"
  })

  _, flow_y = draw.clock(state.clock, {
    clock = music.clock,
    x = x,
    y = flow_y
  })

  _, flow_y = draw.staff(state.staff, {
    x = x,
    y = flow_y,
    key = music.key,
    cleff = "treble",
    steps = music.sequence,
    width = width
  })

  local event = music.music_events[1]
  flow_y = flow_y + 10

  love.graphics.setColor(draw.colors.black)

  draw.midiRecording(state.midiRecording, {
    recording = music.midiRecording,
    x = x,
    y = flow_y
  })

end

return rack