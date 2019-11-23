local utils = {}

function utils.copy(item)
  local result = {}
  for key, value in pairs(item) do
    result[key] = value
  end
  return result
end

function utils.defaults(state, defaults)
  for key, value in pairs(defaults) do
    if state[key] == nil then
      state[key] = value
    end
  end
end

function utils.idefaults(state, props)
  local result = utils.copy(state)
  utils.defaults(result, props)
  return result
end


function utils.compress(array)
  local x = 0
  local i
  for i=1, #array, 1 do
    local v = array[i]
    if v ~= nil then
      x = x + 1
      if i ~= x then
        array[x] = v
        array[i] = nil
      end
    end
  end
end

function utils.round(value)
  if value - math.floor(value) < 0.5 then
    return math.floor(value)
  else
    return math.ceil(value)
  end
end

function isInt(number)
  local _, fraction = math.modf(number)
  return fraction == 0
end

function utils.toRange(value, min, max)
  return (value - min) / (max - min)
end

function utils.rangeToFloat(range, min, max)
  return range * (max - min) + min
end

function utils.rangeToInt(range, min, max)
  return utils.round(utils.rangeToFloat(range, min, max))
end

local inputs = {}

function utils.map(value, inMin, inMax, outMin, outMax)
  local range = utils.toRange(value, inMin, inMax)
  local result = utils.rangeToFloat(range, outMin, outMax)
  if inputs[value] == nil then
    inputs[value] = true
  end
    
  return result
end

function utils.mapInt(value, inMin, inMax, outMin, outMax)
  return utils.round(utils.map(value, inMin, inMax, outMin, outMax))
end

function utils.trim(string)
  return (string:gsub("^%s*(.-)%s*$", "%1"))
end

return utils