local lfs = require "lfs"

local RELOAD_CLOCK_TIME = 0.05

local function load_module(file, module_args, name)
  local loaded_module, error = love.filesystem.load(file)
  if error then
    print("\nFailed when compiling " .. file, error)
    return nil
  end
  if loaded_module then
    local function fn() return loaded_module(module_args) end
    local success, result = xpcall(fn, debug.traceback)
    if success then
      if result then
        if name then
          print("reloaded " .. file .. " (" .. name .. ")!")
        else
          print("loaded " .. file .. "!")
        end
        return result
      end
    else
      print("\nFailed initing " .. file, result)
      return nil
    end
  else
    print("\nModule didn't load but had no error")
    return nil
  end
end

local function livereload(file, module_args)
  file = file .. ".lua"
  local last_modified = lfs.attributes(file, "modification")
  
  local module = load_module(file, module_args)
  local last_load = love.timer.getTime()
  if module == nil then error("The module needs to exist!") end
  local prev_module = nil
  local broken = false

  local live_module = {}

  for name, value in pairs(module) do
    if type(value) == "function" then
      local function fn(...)
        local args = {...}
        local time = love.timer.getTime()
        local modified = lfs.attributes(file, "modification")
        if modified > last_modified and time - last_load >= RELOAD_CLOCK_TIME then
          local result = load_module(file, module_args, name)
          if result ~= nil then
            prev_module = module
            module = result
            last_modified = modified
            last_load = time
            broken = false
          elseif prev_modules ~= nil then
            module = prev_module
            prev_module = nil
          else
            print("The module didn't load idk")
          end
        end
        if module == nil then error("No module") end
        while module and not broken do
          local function fn2() return module[name](unpack(args)) end
          local xpcall_result = {xpcall(fn2, debug.traceback)}
          if not xpcall_result[1] then
            print("\nFailed when running " .. file)
            print(xpcall_result[2])
            if prev_module then
              module = prev_module
              prev_module = nil
            else
              broken = true
              print("No fallbacks for broken module")
            end
          else
            return unpack(xpcall_result, 2, #xpcall_result)
          end
        end
        return nil
      end
      live_module[name] = fn
    else
      live_module[name] = value
    end
  end

  return live_module
end

return livereload