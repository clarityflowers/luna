local draw = {}
local livereload = require "livereload2"
local metropolis = livereload.init("metropolis_draw.lua")
local riverboat = livereload.init("riverboat_draw.lua")
local watermill = livereload.init("watermill_draw.lua")
local modes = require "modes"

local note_font = love.graphics.newFont("Bravura.otf", 30)
local small_note_font = love.graphics.newFont("Bravura.otf", 20)
local text_font = love.graphics.newFont("leaguespartan-bold.ttf", 10)
local fonts = {
  note_font = note_font,
  small_note_font = small_note_font,
  text_font = text_font
}

local function printMultiplier(multiplier, x, y)
  local string
  if multiplier[2] == 1 then
    string = "x" .. multiplier[1]
  elseif multiplier[2] > 1 and multiplier[1] == 1 then
    string = "/" .. multiplier[2]
  else
    string = multiplier[1] .. "/" .. multiplier[2]
  end
  love.graphics.setFont(text_font)
  love.graphics.print(string, x, y)
  return 25
end


function draw.run(state, dt, blur, canvas)
  love.graphics.setShader()

  if not state then return end
  for _, input in pairs(state.inputs) do
    local event = input[1]
    if event == "key" then
      _, down, scancode = unpack(input)
      if scancode == "lctrl" or scancode == "rctrl" then
        state.ctrl = down
      elseif scancode == "lshift" or scancode == "rshift" then
        state.shift = down
      elseif down then
        if scancode == "escape" then
          love.event.quit()
        elseif state.ctrl and scancode == "return" then
          if state.fullscreen then
            love.window.setMode(666, 420, {
              borderless = true,
              centered = false,
              x = 610,
              y = 0,
              highdpi = true,
              msaa = 16
            })
            state.fullscreen = false
          else
            love.window.setMode(1280, 776, {
              borderless = true,
              highdpi = true,
              msaa = 16
            })
            state.fullscreen = true
          end
        else
          state.midiinput:push({ "key", scancode, state.ctrl, state.shift})
        end
      end
    end
  end
  state.inputs = {}


  local flow_y = 10
  love.graphics.clear(0.8, 0.8, 0.8)

  
  

  local midi = state.midi

  if not midi then
    return
  end
  
  if not midi.tracks then
    return
  end

  local x = 10

  -- settings
  do
    local sx = 10
    
    love.graphics.setColor(.2, .2, .2)
    love.graphics.setFont(text_font)
    if midi.pause then
      love.graphics.print("pause", sx, flow_y)
      sx = sx + 50
    end
    love.graphics.print(midi.bpm, sx, flow_y)
    sx = sx + 25
    printMultiplier(midi.multiplier, sx, flow_y)
  end

  flow_y = flow_y + 10
  local width = love.graphics.getWidth()

  local time = midi.beat + midi.fraction

  for i = 1, #midi.tracks, 1 do
    local type, data = unpack(midi.tracks[i])
    local selected = midi.selected_track == i
    local top = flow_y
    if type == "?" then
      flow_y = flow_y + 10
      for mode_i, mode in pairs(modes) do
        love.graphics.setFont(fonts.text_font)
        if selected and data == mode_i then
          love.graphics.setColor(0.9, 0.2, 0.4)
        else
          love.graphics.setColor(0, 0, 0)
        end

        love.graphics.printf(mode, width * (mode_i * 2 - 1) / (#modes * 2 + 1), flow_y, 200, "center")
      end
      flow_y = flow_y + 20
    elseif type == "metropolis" and data then
      flow_y = metropolis.draw(data, fonts, selected, x + 10, flow_y + 10, width - 30 - x) + 10
    elseif type == "riverboat" and data then
      flow_y = riverboat.draw(data, time, fonts, selected, x + 10, flow_y + 10, width - 30 - x) + 10
    elseif type == "watermill" and data then
      flow_y = watermill.draw(data, time, fonts, selected, x + 10, flow_y + 10, width - 30 - x) + 10
    end
    love.graphics.setColor(.7, .7, .7)
    if selected then
      love.graphics.setColor(.2, .2, .2)
    end
    love.graphics.line(x, top + 10, 10, flow_y - 10)
  end

  return state
end

return draw