local livereload = require "livereload"
local tools = require "draw_tools"
local constants = livereload "draw_constants"
local notes = livereload "notes"
local utils = livereload "utils"
local midiconst = livereload "midi_constants"

local idefaults = utils.idefaults

local draw = {}

draw.colors = {
  highlight = {0.9, 0.3, 0.7},
  black = {0, 0, 0}
}

local colors = draw.colors

function draw.font(string, font, x, y)
  local prev_font = love.graphics.getFont()
  love.graphics.setFont(constants[font .. "_font"])
  love.graphics.print(string, x, y)
  love.graphics.setFont(prev_font)
end

function draw.text(string, x, y)
  draw.font(string, "text", x, y)
  return y + constants.FONT_SIZE
end

function draw.monotext(string, x, y)
  draw.font(string, "mono", x, y)
  return y + constants.FONT_SIZE
end

function draw.music(character, x, y, pos, small)
  y = draw.getStaffY(y, pos)
  local font = "note"
  if small then
    font = "small_note"
  end
  local offset = constants.NOTE_OFFSET
  if small then
    offset = constants.SMALL_NOTE_OFFSET
  end
  draw.font(constants.SYMBOLS[character], font, x, y + offset)
end

function draw.noteLines(x, y, pos, cleff)
  local prev_color = {love.graphics.getColor()}
  love.graphics.setColor(0.65, 0.65, 0.65)
  x = x + constants.NOTE_FONT_SIZE * 0.13
  for i = -2, pos, -2 do
    local line_y = draw.getStaffY(y, i)
    local radius = constants.NOTE_FONT_SIZE * 0.35
    love.graphics.line(x - radius, line_y, x + radius, line_y)
  end
  for i = 8, pos, 2 do
    if cleff ~= "piano" or pos == 10 or i >= 22 then
      local line_y = y - i * constants.BAR_HEIGHT
      local radius = constants.NOTE_FONT_SIZE * 0.3
      love.graphics.line(x - radius, line_y, x + radius, line_y)
    end
  end
  love.graphics.setColor(prev_color)
end

function draw.getStaffY(y, position)
  return y - position * constants.BAR_HEIGHT
end

function draw.note(props)
  props = idefaults(props, {
    note = nil,
    cleff = "treble",
    symbol = "quarter",
    key = {0, 1},
    length = nil,
    end_note = nil,
    x = 0,
    y = 0
  })
  local x = props.x
  local y = props.y

  local position = 4

  local pad_length = false

  if props.note then
    position = notes.staffPosition(props.note, props.cleff, props.key)
  end

  if props.note then
    draw.noteLines(x, y, position, props.cleff)
    local up = notes.isUp(position, props.cleff, prev_up)
    prev_up = up
    local symbol = "note " .. props.symbol .. " down"
    if up then
      symbol = "note " .. props.symbol .. " up"
    end
    draw.music(symbol, x, y, position)
  else
    draw.music("quarter rest", x, y, 4)
    if props.cleff == "piano" then
      draw.music("quarter rest", x, y, 16)
    end
  end
  x = x + constants.NOTE_FONT_SIZE * 0.5
  if pad_length then
    x = x + constants.NOTE_FONT_SIZE * 0.4
  end
  return x
end

function draw.staff(state, props)
  props = idefaults(props, {
    y = 0,
    x = 0,
    width = love.graphics.getWidth(),
    cleff = "treble",
    key = {0, 1},
    steps = {}
  })
  local padding = constants.BAR_HEIGHT * 5
  local y = props.y + padding
  y = tools.drawStaffLines(props.x, y, props.width, props.cleff, 0, false)
  local x = props.x + constants.NOTE_FONT_SIZE

  local sharps = unpack(props.key)
  love.graphics.setFont(constants.note_font)
  local start_x = x
  love.graphics.setColor(0.4, 0.4, 0.4)
  for i, accidentals in ipairs(notes.keyAccidentalPositions(props.key, props.cleff)) do
    x = start_x
    for _, accidental in ipairs(accidentals) do
      local value, pos = unpack(accidental)
      local character = constants.ACCIDENTALS[value]
      draw.music(character, x, y, pos)
      x = x + constants.NOTE_FONT_SIZE * 0.3
    end
  end

  x = x + constants.NOTE_FONT_SIZE * 0.5
  
  local prev_up = true
  local prev_extend = false
  for i, step in ipairs(props.steps) do
    local length = nil
    local end_note = nil
    
    local prev_step = props.steps[i - 1]
    local tied_to = prev_step and prev_step.tie
    local position = notes.staffPosition(step.note, props.cleff, props.key)
    local line_y = draw.getStaffY(y, position)
    local extend = tied_to and notes.areEqual(step.note, prev_step.note)

    if tied_to and not (extend and prev_extend) then
      local prev_width = love.graphics.getLineWidth()
      love.graphics.setLineWidth(1.5)
      local line_x = x - constants.NOTE_FONT_SIZE * 0.55
      local line_y1 = line_y
      local line_y2 = line_y
      if not extend then
        line_x = line_x + constants.NOTE_FONT_SIZE * 0.1
        local prev_pos = 4
        if prev_step.note then
          prev_pos = notes.staffPosition(prev_step.note, props.cleff, props.key)
        end
        line_y1 = draw.getStaffY(y, prev_pos)
        x = x + constants.NOTE_FONT_SIZE * 0.1
      end
      local line_x2 = line_x + constants.NOTE_FONT_SIZE * 0.4
      love.graphics.line(line_x, line_y1, line_x2, line_y2)
      love.graphics.setLineWidth(prev_width)
    end

    love.graphics.setColor(colors.black)
    if step.playing then
      love.graphics.setColor(colors.highlight)
    end

    if not extend then
      if step.tie then
        length = constants.NOTE_FONT_SIZE * 0.4
        local next_i = i + 1
        if next_i > #props.steps then
          next_i = 1
        end
        local next_step = props.steps[next_i]
        if step.note and next_step.note and not notes.areEqual(step.note, next_step.note) then
          end_note = next_step.note
        end
      end
      x = draw.note({
        note = step.note, 
        cleff = props.cleff, 
        key = props.key,
        length = length,
        end_note = end_note,
        x = x,
        y = y
      })
    else 
      local prev_width = love.graphics.getLineWidth()
      love.graphics.setLineWidth(1.5)
      local line_x = x 
      local line_y1 = line_y
      local line_y2 = line_y
      local line_x2 = line_x + constants.NOTE_FONT_SIZE * 0.7
      love.graphics.line(line_x, line_y1, line_x2, line_y2)
      love.graphics.setLineWidth(prev_width)
      x = x + constants.NOTE_FONT_SIZE * 0.5
    end

    prev_extend = extend

    x = x + constants.NOTE_FONT_SIZE * 0.4
  end

  return props.x + props.width, y + padding
end

function draw.perf(props)
  props = utils.idefaults(props, {
    perf = {
      average = 0.0,
      peak = 0.0
    },
    x = 0,
    y = 0,
    attach_y = "top"
  })

  local x, y = props.x, props.y

  local size = constants.FONT_SIZE
  local top_y = y

  if props.attach_y == "bottom" then
    y = y - size * 2
  end

  local return_x = x + size * 6.5

  draw.monotext(string.format("%6.3f avg", props.perf.average * 1000), x, y)
  draw.monotext(string.format("%6.3f peak", props.perf.peak * 1000), x, y + size)

  local return_y = y
  if props.attach_y == "bottom" then
    return_y = top_y
  end

  return return_x, return_y
end

function draw.clock(state, props)
  utils.defaults(state, {
    tick_left = true,
    beat = -1
  })
  props = utils.idefaults(props, {
    clock = nil,
    x = 0,
    y = 0,
  })
  local x, y = props.x, props.y
  if not props.clock then
    return x, y
  end
  local clock = props.clock

  local click = clock.beat > state.beat
  state.beat = clock.beat
  if click then
    state.tick_left = not state.tick_left
  end
  local height = constants.FONT_SIZE
  local radius = height * 0.4
  local diameter = radius * 2
  local circle_x = x + radius
  if not state.tick_left then
    circle_x = circle_x + diameter
  end
  love.graphics.circle('fill', circle_x, y + radius + 0.1, radius)
  return x + diameter * 2, y + height
end

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

return draw