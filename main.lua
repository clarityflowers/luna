local livereload = require "livereload2"


local state
local midiout
local midithread
local font
local draw
local blur = love.graphics.newShader[[
  extern vec2 direction;
  extern number radius;
  vec4 effect(vec4 color, Image texture, vec2 tc, vec2 _) {
    vec4 c = vec4(0.0);

    for (float i = -radius; i <= radius; i += 1.0)
    {
      c += Texel(texture, tc + i * direction);
    }
    return c / (2.0 * radius + 1.0) * color;
  }
]]
local canvas
  

function love.load()
  love.window.setMode(666, 420, {
    borderless = true,
    centered = false,
    x = 610,
    y = 0,
    highdpi = true,
    msaa = 16
  })

  canvas = love.graphics.newCanvas(
    love.graphics.getWidth(),
    love.graphics.getHeight(),
    {
      msaa = 16
    }
  )

  state = {
    midi = nil,
    data = 0,
    inputs = {},
    midiinput = love.thread.newChannel()
  }

  midiout = love.thread.newChannel()
  midithread = love.thread.newThread("midiloader.lua")
  midithread:start(midiout, state.midiinput)

  draw = livereload.init("draw.lua")

  font = love.graphics.newFont("leaguespartan-bold.ttf", 10)
  love.graphics.setFont(font)
end

function love.quit()
  if state.midi then
    state.midiinput:push({ "quit" })
    midithread:wait()
  end
end

function love.keypressed( key, scancode, isrepeat )
  table.insert(state.inputs, {"key", true, key, scancode, isrepeat})
end

function love.keyreleased( key, scancode )
  table.insert(state.inputs, {"key", false, key, scancode})
end

function love.update_and_draw(dt)
  local error = midithread:getError()
  assert( not error, error )
  local midi = midiout:pop()
  if midi then
    state.midi = midi
  end


  
  local result = draw.run(state, dt, blur, canvas)
  if result then
    state = result
  end
end

function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0

	-- Main loop time.
	return function()
		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end

    if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())

      if love.update_and_draw then love.update_and_draw(dt) end

      love.graphics.present()
		end

		if love.timer then love.timer.sleep(0.017 - dt) end
  end
end