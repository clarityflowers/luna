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

local time = timer.getTime()

local module = livereload.init("midi.lua")
local running = true

while running do
  local newtime = timer.getTime()
  local dt = newtime - time
  time = newtime

  local inputs = {}
  while true do
    local input = midiinput:pop()
    if input then
      table.insert(inputs, input)
    else
      break
    end
  end
  local result = module.run(state, dt, inputs)
  if result == "quit" then
    running = false
  else
    state = result
  end

  midiout:performAtomic(setChannel, state)

  timer.sleep(0.008 - dt)
end
