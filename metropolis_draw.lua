local livereload = require "livereload"
local constants = require("draw_constants")
local tools = livereload "draw_tools"

local metropolis = {}

function metropolis.draw(state, fonts, selected, x, y, max_width)
  local cleff = state.cleff
  local flow_x = x
  local flow_y = y
  local width = max_width


  local function printMultiplier(multiplier, x, y)
    local string
    if multiplier[2] == 1 then
      string = "x" .. multiplier[1]
    elseif multiplier[2] > 1 and multiplier[1] == 1 then
      string = "/" .. multiplier[2]
    else
      string = multiplier[1] .. "/" .. multiplier[2]
    end
    love.graphics.setFont(constants.text_font)
    love.graphics.print(string, x, y)
    return 25
  end

  local function drawSelectedInsert(x, y, y2, i)
    local selected_line_x = x + 16
    love.graphics.setColor(0, 0.4, 0.8)
    love.graphics.setFont(constants.text_font)
    love.graphics.printf(i, selected_line_x - 10, y - 20, 20, "center")
    love.graphics.line(selected_line_x, y - constants.BAR_HEIGHT, selected_line_x, y2 + constants.BAR_HEIGHT)
  end

  local function drawSelectedEdit(x, x2, y)
    love.graphics.setColor(0, 0.4, 0.8, 0.2)
    local rect_top = y - constants.BAR_HEIGHT * 4
    local rect_bottom = y + constants.BAR_HEIGHT * 4
    love.graphics.rectangle("fill", x - 8, rect_top, x2 - x + 23, rect_bottom - rect_top)
  end

  
  -- configs
  do
    local cx = x
    if selected then
      love.graphics.setColor(.2, .2, .2)
    else
      love.graphics.setColor(.7, .7, .7)
    end
    love.graphics.setFont(constants.text_font)
    love.graphics.print("ch " .. state.channel, cx, flow_y)
    cx = cx + 40
    cx = cx + printMultiplier(state.multiplier, cx, flow_y)
    local GATE_WIDTH = 20
    love.graphics.rectangle("line", cx, flow_y, GATE_WIDTH, 10)
    love.graphics.rectangle("fill", cx, flow_y, GATE_WIDTH * state.gate_time, 10)
    cx = cx + GATE_WIDTH + 10
    love.graphics.circle("line", cx + 5, flow_y + 5, 5)
    local TAU = math.pi * 2
    love.graphics.arc("fill", cx + 5, flow_y + 5, 5, - TAU * .25, TAU * (state.gate_time - .25))
  end
  
  flow_y = flow_y + 34
  
  -- staff lines, cleff, octave marker
  local staff_top = flow_y
  flow_y =  tools.drawStaffLines(flow_x, flow_y, width, cleff, state.octave_shift, fonts, state.play)

  flow_x = flow_x + 40
  local notes_start_x = flow_x

  local BEAT_SPACE = constants.BAR_HEIGHT * 5

  local highest_note_pos = 100000

  local function drawLinesForNote(line_x, pos, a)
    love.graphics.setColor(0.4, 0.4, 0.4, a)
    tools.drawLinesForNote(line_x, pos, cleff, staff_top, a)
  end
  
  for i = 1, #state.steps, 1 do
    local step = state.steps[i]
    local note, pulse_count, gate_mode, slide, skip = unpack(step)
    
    love.graphics.setColor(.5, .5, .5)
    local a = 1
    if skip then
      a = 0.1
    end


    
    -- note position
    local note_x = flow_x
    local note_staff_pos = tools.noteStaffPos(note, cleff)
    local note_y = tools.noteYFromPosition(note_staff_pos, staff_top)
    if note_y < highest_note_pos then
      highest_note_pos = note_y
    end
    
    if note then
      love.graphics.setColor(0, 0, 0, a)
      flow_x = tools.drawAccidental(note, flow_x, note_y)

      drawLinesForNote(flow_x, note_staff_pos, a)

      -- note head
      if (
        state.step == i and
        state.playing and
        (state.step_time == 1 or (gate_mode ~= 3 and gate_mode ~= 4))
      ) then
        love.graphics.setColor(1, 0, 0, a)
      else
        love.graphics.setColor(0, 0, 0, a)
      end
      tools.drawNoteHead(flow_x, note_y, note_staff_pos < 5)
      love.graphics.setFont(constants.text_font)

      -- slide
      if slide then
        love.graphics.setColor(0, 0, 0, a)
        local slide_y = math.min(staff_top + constants.BAR_HEIGHT * 2, note_y) - constants.BAR_HEIGHT * 2 + 1
        love.graphics.line(flow_x - 2, slide_y, flow_x + 10, slide_y)
      end
    else
      -- rest
      if state.play and state.step == i and state.step_time == 1 then
        love.graphics.setColor(1, 0, 0, a)
      else
        love.graphics.setColor(0, 0, 0, a)
      end
      love.graphics.setFont(constants.note_font)
      love.graphics.printf(constants.QUARTER_REST, flow_x, staff_top + constants.BAR_HEIGHT * 4 + constants.NOTE_OFFSET, 10, "center")
      if cleff == "piano" then
        love.graphics.printf(constants.QUARTER_REST, flow_x, flow_y - constants.BAR_HEIGHT * 4 + constants.NOTE_OFFSET, 10, "center")
      end
      -- love.graphics.rectangle("fill", flow_x, staff_top + 81 - (2 * constants.BAR_HEIGHT), 10, constants.BAR_HEIGHT)
      -- love.graphics.line(flow_x - 2, staff_top + constants.BAR_HEIGHT * 6, flow_x + 12, staff_top + constants.BAR_HEIGHT * 6)
    end

    -- extra_beats
    local pulses = pulse_count - 1
    if note and gate_mode == 4 and pulses > 0 then
      if state.playing and state.step == i and state.step_time == 1 then
        love.graphics.setColor(1, 0, 0, a)
      else
        love.graphics.setColor(0, 0, 0, a)
      end
      love.graphics.rectangle("fill", flow_x + 7, note_y - 1, 8, 2)
    end
    for s = 1, pulses, 1 do
      flow_x = flow_x + BEAT_SPACE
      if note and gate_mode == 3 then
        drawLinesForNote(flow_x, note_staff_pos, a)
      end
      if ((state.play and (not note or gate_mode == 2)) or state.playing) and state.step == i and state.step_time == s + 1 then
        love.graphics.setColor(1, 0, 0, a)
      else
        love.graphics.setColor(0, 0, 0, a)
      end
      if note then
        if gate_mode == 3 then
          love.graphics.setFont(constants.note_font)
          love.graphics.print(constants.NOTE_HEAD_BLACK, flow_x, note_y + constants.NOTE_OFFSET)
        end
        if gate_mode == 4 then
          local pulse_width = BEAT_SPACE - 3
          if s == pulses then
            pulse_width = BEAT_SPACE - 10
          end
          love.graphics.rectangle("fill", flow_x - 7, note_y - 1, pulse_width, 2)
        end
      end
      if not note or gate_mode == 2 then
        love.graphics.setFont(constants.small_note_font)
        love.graphics.print(constants.QUARTER_REST, flow_x, staff_top + constants.BAR_HEIGHT * 4 + constants.SMALL_NOTE_OFFSET)
        if cleff == "piano" then
          love.graphics.print(constants.QUARTER_REST, flow_x, flow_y - constants.BAR_HEIGHT * 4 + constants.SMALL_NOTE_OFFSET)
        end
      end
    end

    -- selected step
    local selected_x = note_x
    local selected_x_2 = flow_x
    local selected_y = note_y
    local step_selected = selected and state.selected_step == i

    if step_selected then
      if state.edit_mode == "insert" then
        drawSelectedInsert(selected_x_2, staff_top, flow_y, state.selected_step)
      elseif state.edit_mode == "edit" then
        drawSelectedEdit(selected_x, selected_x_2, selected_y)
      end
    end

    flow_x = flow_x + BEAT_SPACE
  end

  -- selected step (if for new step)
  if selected then
    if state.edit_mode == "insert" then
      if state.selected_step == 0 then
        drawSelectedInsert(notes_start_x - 25, staff_top, flow_y, state.selected_step)
      end
    elseif state.edit_mode == "edit" then
      if state.selected_step == #state.steps + 1 then
        drawSelectedEdit(flow_x, flow_x, staff_top + constants.BAR_HEIGHT * 4)
      end
    end
  end

  flow_y = flow_y + constants.BAR_HEIGHT * 6

  return flow_y
end

return metropolis