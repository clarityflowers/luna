local result = {}
local livereload = require "livereload2"
local miditools = require "miditools"
local tools = livereload.init("draw_tools.lua")
local MIDI = require "midi_constants"
local constants = require "draw_constants"


function result.draw(state, time, fonts, selected, x, section_y, width)
  local flow_y = section_y
  local playing = state.status == "started" or state.status == "stopping"
  love.graphics.setColor(0.2, 0.2, 0.2)
  if not selected then
    love.graphics.setColor(0.6, 0.6, 0.6)
  end
  do
    local flow_x = x
    love.graphics.print("ch " .. state.channel, flow_x, flow_y)
  end
  local cleff = "piano"
  flow_y = flow_y + 30
  local staff_top = flow_y
  flow_y = tools.drawStaffLines(x, flow_y, width, cleff, 0, fonts, playing)
  local flow_x = x + 10
  local distance_per_beat = (width - flow_x) / state.width

  local function draw_note_length(note_x, y, length)
    love.graphics.rectangle("fill", note_x + 7, y - 1, length, 2)
  end
  local function draw_note_head(note, note_x, note_y, staff_position, color)
    color = color or {0, 0, 0}
    love.graphics.setColor(color)
    note_x = tools.drawAccidental(note, note_x, note_y)
    love.graphics.setColor(0.4, 0.4, 0.4)
    tools.drawLinesForNote(note_x, staff_position, cleff, staff_top, 1)
    love.graphics.setColor(color)
    local up = tools.isNoteUp(staff_position, cleff)
    tools.drawNoteHead(note_x, note_y, up)
    return note_x
  end
  local notes_started = {}
  local notes_x = x + 24

  local current_time_x = notes_x
  if state.clock ~= nil then
    current_time_x = notes_x + (state.clock * distance_per_beat)
  end
  if playing then
    love.graphics.setColor(0.8, 0.5, 0.5)
    love.graphics.line(current_time_x, staff_top - constants.BAR_HEIGHT * 3, current_time_x, flow_y + constants.BAR_HEIGHT * 3)
  end
  if state.looped_events then
    for i = 1, #state.looped_events, 1 do
      local note_time, type, v1 = unpack(state.looped_events[i])
      if type == MIDI.NOTE_ON then
        local note_x = notes_x + (note_time * distance_per_beat)
        notes_started[v1] = note_x
      elseif type == MIDI.NOTE_OFF then
        local start_x = notes_started[v1]
        
        if start_x then
          notes_started[v1] = nil
          local end_x = notes_x + (note_time * distance_per_beat)
          local note = miditools.toNote(v1)
          local staff_position = tools.noteStaffPos(note, cleff)
          local note_y = tools.noteYFromPosition(staff_position, staff_top)
          local playing = current_time_x > start_x and current_time_x < end_x
          if playing then
            love.graphics.setColor(0.8, 0.5, 0.5)
          end
          note_x = draw_note_head(note, start_x, note_y, staff_position)
          draw_note_length(start_x, note_y, end_x - start_x)
        end
      end
    end
  end
  return flow_y + 10
end

return result