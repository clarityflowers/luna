local draw = {}
local livereload = require "livereload"
-- local metropolis = livereload "metropolis_draw"
-- local riverboat = livereload "riverboat_draw"
-- local watermill = livereload "watermill_draw"
local rack = livereload "rack_draw"
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


function draw.run(state, dt, midiinput, blur, canvas)
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
          midiinput:push({ "key", scancode, state.ctrl, state.shift})
        end
      end
    end
  end
  state.inputs = {}


  local flow_y = 10
  love.graphics.clear(0.8, 0.8, 0.8)

  
  

  if not state.rack then
    state.rack = {}
  end

  if not state.midi then
    return
  end

  rack.draw(state.midi, state.rack, dt)
end

return draw