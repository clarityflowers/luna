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

return utils