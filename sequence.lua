local sequence = {}
local utils = require "utils"

function errorContext(tokens, stack, mode, state)
  table.insert(stack, {mode, state})
  local result = ""
  local prev_state = nil
  for _, v in ipairs(stack) do
    if result then
      result = result .. ", "
    end
    local mode, state = unpack(v) do
      if mode == "line" then
        result = result .. "line " .. #tokens
      elseif mode == "note" then
        result = result .. "note " .. #prev_state.notes
      end
    end
    prev_state = state
  end
  return result .. ":"
end

function parse(sequence)
  sequence = utils.trim(sequence) .. "\n"
  local i
  local tokens = {}
  local stack = {}
  local mode = "line"
  local state = {}
  local i = 1

  function consume()
    if i > #sequence then
      return nil
    end
    local result = string.sub(sequence, i, i)
    i = i + 1
    return result
  end

  local c = consume()
  local lines = {}
  while c ~= nil do
    local notes = {}
    local echo = false
    while c ~= "\n" and c ~= nil do
      if c == " " or c == "\t" then
        c = consume()
      elseif c == "." then
        echo = true
        while c == "." do
          c = consume()
        end
      else
        local note = {
          step = nil,
          shift = 0,
          tie = false,
          accidental = 0
        }
        if c == "_" then
          while c == "_" do
            c = consume()
          end
        else
          if c == "~" then
            note.tie = true
            c = consume()
          end
          while c == "-" or c == "+" do
            if c == "-" then
              note.shift = note.shift - 1
            else
              note.shift = note.shift + 1
            end
            c = consume()
          end
          if c == "~" then
            note.step = "repeat"
            c = consume()
          elseif string.match(c, '%d') then
            note.step = tonumber(c)
            c = consume()
          else 
            error(string.format("line %s, note %s: Unexpected character %s. Expected a number or a '~'", #lines, #notes, c))
          end
          if c == "+" then
            while c == "+" do
              note.accidental = note.accidental + 1
              c = consume()
            end
          elseif c == "-" then
            while c == "-" do
              note.accidental = note.accidental - 1
              c = consume()
            end
          end
        end
        
        table.insert(notes, note)
      end
    end
    table.insert(lines, {
      notes = notes,
      echo = echo
    })
    if c == "\n" then
      c = consume()
    end
  end

  return lines
end

function compile(lines)
  local step_lines = {}
  for _, line in ipairs(lines) do
    local line_steps = {}
    local octave = 0
    local step = nil
    for _, note in ipairs(line.notes) do
      if note.step == nil then
        table.insert(line_steps, {})
      else
        if note.step ~= "repeat" then
          step = note.step
        end
        octave = octave + note.shift

        if note.tie and #line_steps > 0 then
          steps[#line_steps].tie = true 
        end
        
        table.insert(line_steps, {
          note = {octave, line_steps, note.accidental}
        })
      end
    end
    if line.echo then
      local i = 1
      while #line_steps < #(step_lines[#step_lines]) do
        table.insert(line_steps, 1, utils.copy(step_lines[#step_lines][i]))
        i = i + 1
      end
    end
    table.insert(step_lines, line_steps)
  end
  local steps = {}
  for _, line_steps in ipairs(step_lines) do
    for _, step in ipairs(line_steps) do
      table.insert(steps, step)
    end
  end
  return steps
end


local function prettyPrint(t, depth)
  depth = depth or 0

  local spaces = ""
  local i
  for i=1, depth do
    spaces = "  " .. spaces
  end

  for k, v in pairs(t) do
    if type(v) == "table" then
      print(spaces .. k .. ":")
      prettyPrint(v, depth + 1)
    else
      print(spaces .. string.format("%s: %s", k, tostring(v)))
    end
  end
end

local function testSequence()
  local tokens = parse([[
    1 2 3 4 5
    ...     6
  ]])
  print("Tokens")
  prettyPrint(tokens)
  local steps = compile(tokens)
  print("Steps")
  prettyPrint(steps)
end

-- testSequence()

function sequence.parse(input)
  return compile(parse(input))
end

return sequence
