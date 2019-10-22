local lfs = require "lfs"

local livereload = {}

function livereload.init(file, reload_clock_time, module_args)
  reload_clock_time = reload_clock_time or 0.05
  local last_modified = 0
  local reload_clock = reload_clock_time
  local module = nil
  local past_modules = {}
  local last_state = nil

  local live_module = {}

  function live_module.run(state, dt, run_args)
    reload_clock = reload_clock + dt
    if reload_clock > reload_clock_time then
      reload_clock = reload_clock - reload_clock_time
      local modified = lfs.attributes(file, "modification")
      if modified > last_modified then
        local loaded_module, error = loadfile(file)
        if error then
          last_modified = modified
          print("\nFailed when compiling " .. file, error)
        end
        if loaded_module then
          local function fn() return loaded_module(module_args) end
          local success, result = xpcall(fn, debug.traceback)
          if success then
            if result then
              print "reloaded!"
              table.insert(past_modules, {module, last_state})
              module = result
              last_modified = modified
            end
          else
            print("\nFailed initing " .. file, result)
            last_modified = modified
          end
        end
      end
    end

    if module then
      local function fn() return module.run(state, dt, run_args) end
      local success, result = xpcall(fn, debug.traceback)
      if success then
        last_state = result
        return result
      else
        print("\nFailed when running " ..file, result)
        if #past_modules then
          module, last_state = unpack(table.remove(past_modules))
        end
        return last_state
      end
    end
  end

  return live_module
end

return livereload