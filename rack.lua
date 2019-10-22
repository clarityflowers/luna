local rack = {}

function rack.update(dt, state)
  local render = {}

  state.inputs = processInputs(state.inputs)
  local inputs = state.inputs

  do
    local bpm_color = 0.15
    if not state.stopped and state.fraction > 0.2 then
      bpm_color = nil
    end

    if state.bpm == nil then
      state.bpm = 100
    end
    if state.multiplier == nil then
      state.multiplier = {1, 1}
    end

    if knobPressed(inputs, 1) then
      local multiplier_knob_value = useKnob(inputs, 2, fromMultiplier(state.multiplier), {
        color = "value",
      })
      state.multiplier = toMultiplier(multiplier_knob_value)
    else
      state.bpm = useKnob(inputs, 1, state.bpm / 2, {
        min = 20,
        max = 100,
        color = bpm_color,
      }) * 2
    end

  end

  
  state.clock = clock(state.clock, state.bpm, state.multiplier, dt)
  table.insert(render, {"clock", { bpm = state.bpm, multiplier = state.multiplier, clock = state.clock }})
  
  state.
  
  
end