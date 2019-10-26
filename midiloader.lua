local timer = require "love.timer"
-- local lfs = require "lfs"
local livereload = require "livereload2"


-- Receive values sent via thread:start
local midiout, midiinput = ...

local state = {}

local function setChannel(channel, value)
  channel:clear()
  channel:push(value)
end

local time = nil

local module = livereload.init("rack.lua")
local running = true

while running do
  local start_time = timer.getTime()
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
  if result == "quit" then
    running = false
  else
    midiout:performAtomic(setChannel, result)
  end
  
  
  local end_time = timer.getTime()
  local loop_dt = end_time - start_time

  timer.sleep(0.001 - loop_dt)
end
