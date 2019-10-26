local tools = {}
local constants = require("livereload2").init("draw_constants.lua")

function tools.drawStaffLines(x, flow_y, width, cleff, octave, play)
  love.graphics.setLineWidth(1)
  local staff_top = flow_y
  for i = 0, 4, 1 do
    love.graphics.setColor(0.65, 0.65, 0.65)
    local bar_y = flow_y + (i * constants.BAR_HEIGHT * 2)
    love.graphics.line(x, bar_y, x + width, bar_y)
  end
  flow_y = flow_y + constants.BAR_HEIGHT * 8
  if cleff == "piano" then
    flow_y = flow_y + constants.BAR_HEIGHT * 4
    for i = 0, 4, 1 do
      local bar_y = flow_y + (i * constants.BAR_HEIGHT * 2)
      love.graphics.line(x, bar_y, x + width, bar_y)
    end
    flow_y = flow_y + constants.BAR_HEIGHT * 8
  end


  -- clef 
  love.graphics.setFont(constants.note_font)
  if play then
    love.graphics.setColor(0.8, 0.5, 0.5)
  end
  if cleff == "treble" or cleff == "piano" then
    love.graphics.print(constants.G_CLEFF, x, staff_top + constants.NOTE_OFFSET + (6 * constants.BAR_HEIGHT))
  elseif cleff == "bass" then
    love.graphics.print(constants.F_CLEFF, x, staff_top + constants.NOTE_OFFSET + (2 * constants.BAR_HEIGHT))
  end
  if cleff == "piano" then
    love.graphics.print(constants.F_CLEFF, x, staff_top + constants.NOTE_OFFSET + (14 * constants.BAR_HEIGHT))
  end

  -- octave marker

  love.graphics.setFont(constants.text_font)
  if octave > 0 then
    local octave_x = x
    local octave_y = staff_top - 14
    if cleff ~= "bass" then
      octave_y = math.min(octave_y, staff_top + (6 * constants.BAR_HEIGHT) - 45)
    else
      octave_x = octave_x - 5
      octave_y = math.min(octave_y, staff_top + (2 * constants.BAR_HEIGHT) - 20)
    end
    love.graphics.printf(1 + (octave * 7), octave_x, octave_y, 25, "center")
  end
  if octave < 0 then
    local octave_y = flow_y + 3
    local octave_x = x - 2
    if cleff ~= "treble" then
      octave_y = math.max(octave_y, flow_y - (6 * constants.BAR_HEIGHT) + 18)
    else
      octave_y = math.max(octave_y, flow_y - (2 * constants.BAR_HEIGHT) + 20)
    end
    love.graphics.printf(1 + (-octave * 7), octave_x, octave_y, 25, "center")
  end

  return flow_y
end

function tools.noteStaffPos(note, cleff)
  local note_staff_pos = 0
  if note then
    local octave, letter = unpack(note)
    note_staff_pos = (octave - 5) * 7 + letter - 1
  end

  if (cleff == "bass") then
    note_staff_pos = note_staff_pos + 12
  end
  return note_staff_pos
end

function tools.noteYFromPosition(staff_position, staff_top)
  local note_y = staff_top - (staff_position * constants.BAR_HEIGHT) + constants.BAR_HEIGHT * 10
  return note_y
end

function tools.drawAccidental(note, flow_x, note_y)
  local _, _, accidental = unpack(note)
  if accidental == 1 then
    love.graphics.setFont(constants.small_note_font)
    love.graphics.printf(constants.ACCIDENTAL_SHARP, flow_x - 10, note_y + constants.SMALL_NOTE_OFFSET, 10, "right")
    flow_x = flow_x + 5
  end
  if accidental == -1 then
    love.graphics.setFont(constants.small_note_font)
    love.graphics.printf(constants.ACCIDENTAL_FLAT, flow_x -  8, note_y + constants.SMALL_NOTE_OFFSET, 10, "right")
    flow_x = flow_x + 5
  end
  return flow_x
end

function tools.drawLine(line_x, pos, staff_top)
  local bar_y = staff_top + (pos * constants.BAR_HEIGHT * 2)
  love.graphics.line(line_x - 4, bar_y, line_x + 12, bar_y)
end

function tools.drawLinesForNote(line_x, pos, cleff, staff_top)
  if pos >= 12 then
    local bar_count = math.floor(pos / 2) - 5
    for bar_i = 1, bar_count, 1 do
      tools.drawLine(line_x, -bar_i, staff_top)
    end
  end

  if cleff == "piano" then
    if pos == 0 then
      tools.drawLine(line_x, 5, staff_top, a)
    end
    if pos <= -10 then
      local bar_count = math.floor(-pos / 2) - 5
      for bar_i = 1, bar_count, 1 do
        tools.drawLine(line_x, bar_i + 10, staff_top, a)
      end
    end
  else
    if pos <= 0 then
      local bar_count = math.floor(-pos / 2) + 1
      for bar_i = 1, bar_count, 1 do
        tools.drawLine(line_x, bar_i + 4, staff_top, a)
      end
    end
  end
end

function tools.drawNoteHead(x, y, up)
  local symbol = constants.NOTE_QUARTER_UP
  if up == false then
    symbol = constants.NOTE_QUARTER_DOWN
  end
  love.graphics.setFont(constants.note_font)
  love.graphics.print(symbol, x - 1, y + constants.NOTE_OFFSET)
end

function tools.isNoteUp(staff_pos, cleff)
  note_up = true
  if staff_pos >= 6 then
    note_up = false
  elseif cleff == "piano" and staff_pos > -6 and staff_pos < 0 then
    note_up = true
  end
  return note_up
end

return tools