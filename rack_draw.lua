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
  local recording_width = 200
  local width = love.graphics.getWidth() - (x * 2)
  local staff_width = width - recording_width - 20
  love.graphics.setColor(draw.colors.black)
  local height = love.graphics.getHeight()

  flow_y = flow_y

  utils.defaults(state, {
    staff = {},
    clock = {},
    channels = {},
    plaitsClock = {},
    midiStream = {},
    midiRecording = {}
  })


  local options_x = x
  local options_y = flow_y
  options_x, flow_y = draw.clock(state.clock, {
    clock = music.clock,
    x = x,
    y = options_y,
    ticks = 4
  })
  options_x = draw.clock(state.clock, {
    clock = music.channels[3].clock,
    x = options_x,
    y = options_y,
    ticks = 4
  })
  options_x = draw.text(music.tempo.bpm, options_x + 10, options_y)



  love.graphics.setColor(draw.colors.black)
  draw.perf({
    perf = music.perf,
    x = 3,
    y = height - 3,
    attach_y = "bottom"
  })

  if music.perf_2 then
    draw.perf({
      perf = music.perf_2,
      x = 80,
      y = height - 3,
      attach_y = "bottom"
    })
  end

  flow_y = flow_y + 10

  utils.defaults(state, { channels = {}})

  for i, channel in ipairs(music.channels) do
    utils.defaults(state.channels, { [i] = {} })
    utils.defaults(state.channels[i], {
      midiRecording = {},
      staff = {}
    })

    local line_state = state.channels[i]
    local flow_x = x

    if channel.name then
      flow_y = 5 + draw.text(channel.name, x, flow_y)
    end
    local line_y = flow_y

    if channel.sequence then
      flow_x, flow_y = draw.staff(line_state.staff, {
        x = x,
        y = flow_y,
        key = music.key,
        cleff = "treble",
        steps = channel.sequence,
        width = staff_width
      })
      flow_x = flow_x + 20
    else
      flow_y = flow_y + 50
    end
  
  
    love.graphics.setColor(draw.colors.black)
    draw.midiRecording(line_state.midiRecording, {
      recording = channel.midi_recording,
      x = flow_x,
      width = width - flow_x ,
      y = line_y
    })

    flow_y = flow_y + 20

  end


end

return rack