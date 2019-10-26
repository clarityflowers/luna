local notes = {}

--[[
  Note:
  {
    octave (int),
    steps (mod7),
    accidental (-2..2),
  }
  Key:
  {
    sharps (-7..7),
    root (mod7)
  }
  Cleff: "treble" | "bass" | "piano"
]]



local function modulo(number, mod, base)
  if base == nil then 
    base = 0 
  end
  while number < base do
    number = number + mod
  end
  while number >= base + mod do
    number = number - mod
  end
  return number  
end

function notes.adjustmentForKey(key)
  local sharps, root = unpack(key)
  local adjustment = 4 * sharps + (root - 1)
  while adjustment >= 7 do
    adjustment = adjustment - 7
  end
  while adjustment < 0 do
    adjustment = adjustment + 7
  end
  return adjustment
end

function notes.keyAccidentalPositions(key, cleff)
  local sharps = unpack(key)
  local result = {{}}
  if cleff == "piano" then
    table.insert(result, {})
  end
  if sharps ~= 0 then
    local value = 1
    if sharps < 0 then
      value = -1
    end
    local i
    for i = value, value * math.abs(sharps), value do
      note = value * ((math.abs(i) * 4) -2) + 2
      staff_pos = notes.staffPosition({0, note}, cleff, {0, 1})
      
      local base = 1
      if cleff == "treble" then
        base = 3
      end
      staff_pos = modulo(staff_pos, 7, base)
      table.insert(result[1], {value, staff_pos})
      if cleff == "piano" then
        table.insert(result[2], {value, modulo(staff_pos, 7, 15)})
      end
    end
  elseif sharps < 0 then
    local i
    for i = -1, -7, -1 do

    end
  end
  return result
end

function notes.staffPosition(note, cleff, key)
  local pos = 0
  if key then
    pos = pos + notes.adjustmentForKey(key)
    if note then
      local octave, steps = unpack(note)
      pos = pos + octave * 7 + steps - 1
    end
  end

  if cleff == "treble" then
    pos = pos - 2
  elseif cleff == "bass" or cleff == "piano" then
    pos = pos + 10
  end

  return pos
end

function notes.isUp(position, cleff, prev_up)
  local up = true
  if position == 4 or (cleff == "piano" and (position == 10 or position == 16)) then
    up = prev_up
  else
    up = position < 4 or (cleff == "piano" and position > 10 and position < 16)
  end
  return up
end

function notes.areEqual(a, b)
  return a[1] == b[1] and a[2] == b[2] and (a[3] or 0) == (b[3] or 0)
end

return notes