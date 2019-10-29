local livereload = require "livereload"
local tools = livereload "draw_tools"
local constants = livereload "draw_constants"
local notes = livereload "notes"
local draw = livereload "music_draw"
local utils = livereload "utils"
local midiconst = livereload "midi_constants"

local rack = {}

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