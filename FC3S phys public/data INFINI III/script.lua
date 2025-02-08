local function safe_require(module_name)
    local ok, value = pcall(require, module_name)
    if not ok then
        ac.log(module_name .. " was not found!")
        return nil, value
    end
    return value
  end

local switch_throttle_model = safe_require("script_switch_throttle_model")
local ustahl_turbo_ref_model = safe_require("script_ustahl_turbo_ref_model")

function script.update(dt)
    if switch_throttle_model then
        switch_throttle_model.runThrottleModel()
    end
    if ustahl_turbo_ref_model then
        ustahl_turbo_ref_model.runTurboRefModel()
    end
end