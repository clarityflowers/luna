local riverboat = {}
local livereload = require "livereload2"
local constants = require "draw_constants"
local miditools = livereload.init("miditools.lua")
local tools = livereload.init("draw_tools.lua")


function riverboat.draw(state, time, fonts, selected, x, section_y, width)
  local flow_y = section_y
  love.graphics.setColor(0.2, 0.2, 0.2)
  if not selected then
    love.graphics.setColor(0.6, 0.6, 0.6)
  end
  do
    local flow_x = x
    love.graphics.print("ch " .. state.channel, flow_x, flow_y)
    flow_x = flow_x + 40
    love.graphics.print("sz " .. state.width, flow_x, flow_y)
  end
  local cleff = "piano"
  flow_y = flow_y + 30
  local staff_top = flow_y
  flow_y = tools.drawStaffLines(x, flow_y, width, cleff, 0, fonts, false)
  local flow_x = x + 10
  local distance_per_beat = (width - flow_x) / state.width

  local function draw_note_length(note_x, y, length)
    love.graphics.rectangle("fill", note_x + 3, y - 1, length, 2)
  end
  local function draw_note_head(note, note_x, note_y, staff_position, color)
    color = color or {0, 0, 0}
    up = tools.isNoteUp(staff_position, cleff)
    love.graphics.setColor(color)
    note_x = tools.drawAccidental(note, note_x, note_y)
    love.graphics.setColor(0.4, 0.4, 0.4)
    tools.drawLinesForNote(note_x, staff_position, cleff, staff_top, 1)
    love.graphics.setColor(color)
    tools.drawNoteHead(note_x, note_y, up)
    return note_x
  end
  for _, playing_note in pairs(state.playing) do
    local start, pitch = unpack(playing_note)
    local note_time = time - start
    local note_length = distance_per_beat * note_time
    local note_x = x + width - 7 - note_length
    
    local note = miditools.toNote(pitch)
    local staff_position = tools.noteStaffPos(note, cleff)

  
    local note_y = tools.noteYFromPosition(staff_position, staff_top)
    note_x = draw_note_head(note, note_x, note_y, staff_position, {1, 0, 0})
    love.graphics.setColor(1, 0, 0)
    draw_note_length(note_x, note_y, note_length)
  end
  for _, played_note in pairs(state.notes) do
    local start, off, pitch = unpack(played_note)
    if time - off < state.width then
      local note_length = distance_per_beat * (time - start)
      local note_x = x + width - 7 - note_length
      local note = miditools.toNote(pitch)
      local staff_position = tools.noteStaffPos(note, cleff)
      local note_y = tools.noteYFromPosition(staff_position, staff_top)

      if time - start < state.width then
        note_x = draw_note_head(note, note_x, note_y, staff_position)
      else
        start = time - state.width
        note_x = x + width - 7 - distance_per_beat * state.width
      end
      draw_note_length(note_x, note_y, (off - start) * distance_per_beat)
    end
  end
  return flow_y + 10
end

return riverboat