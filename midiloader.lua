local timer = require "love.timer"
-- local lfs = require "lfs"
local livereload = require "livereload"
local modules = livereload "modules"


-- Receive values sent via thread:start
local midiout, midiinput = ...

local state = {}

local function setChannel(channel, value)
  channel:clear()
  channel:push(value)
end

local time = nil

local module = livereload "rack"
local running = true

local perf_state = {}

local last_update_time = timer.getTime()

while running do
  local inputs = {}
  while true do
    local input = midiinput:pop()
    if input then
      table.insert(inputs, input)
    else
      break
    end
  end

  local newtime = timer.getTime()
  local dt = newtime - (time or newtime)
  time = newtime


  
  local result = module.update(state, dt, inputs)


  local start_time = timer.getTime()
  if result == "quit" then
    running = false
  else
    if time - last_update_time > 0.01 then
      last_update_time = time
      midiout:performAtomic(setChannel, result)
    end
  end
  local perf = modules.perf(perf_state, timer.getTime() - start_time)
  -- print(string.format("%06.3f", perf.average * 1000))


  
  
  timer.sleep(0.002)
end
