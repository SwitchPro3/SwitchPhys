-- Developed by SwitchPro and Ustahl --
-- Switch Throttle Model © 2024 by SwitchPro and Ustahl is licensed under CC BY-NC-ND 4.0. --
-- To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-nd/4.0/--

--Normalized sigmoid function for new_throttle function by JPG_18
--Thanks to JPG_18 for helping optimize and write some of the script

-- [THROTTLE_LUA]
-- THROTTLE_GAMMA=1.1 ; Defaults to 1.1 if not specified.
-- THROTTLE_SLOPE=2.5 ; Defaults to 2.5 if not specified.
---------------------------------------------------------------------------------------------------

-- Get the redline RPM for calculations and coast torque for mode 1 --
local data = ac.accessCarPhysics()
local engine_ini = ac.INIConfig.carData(0, "engine.ini")
local redline = engine_ini:get("ENGINE_DATA", "LIMITER", 10000)
----------------------------------------------------------------------

-- Custom parameters --
local gamma = engine_ini:get("THROTTLE_LUA", "THROTTLE_GAMMA", 1.1) -- Throttle gamma
local slope = engine_ini:get("THROTTLE_LUA", "THROTTLE_SLOPE", 2.5) -- Torque mode
-------------------------------------------------

-- Generated torque --
--local user_throttle
local modeled_throttle
----------------------

local function calculateTorque(throttle, rpm)
    local new_throttle = ((2/(1+(math.exp(-((redline/rpm)^gamma)*slope*throttle)))-1))/((2/(1+(math.exp(-((redline/rpm)^gamma)*slope*1)))-1))

return new_throttle

end


local switch_throttle_model = {}

function switch_throttle_model.runThrottleModel()
    modeled_throttle = calculateTorque(data.gas,data.rpm)
    ac.overrideGasInput(modeled_throttle)

    --ac.debug("input t: ", data.gas)
    --ac.debug("output t: ", modeled_throttle)
    --ac.debug("rpm: ", data.rpm)
end


return switch_throttle_model