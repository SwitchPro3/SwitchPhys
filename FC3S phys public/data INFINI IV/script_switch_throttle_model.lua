-- Developed by SwitchPro and Ustahl --
-- Switch Throttle Model © 2024 by SwitchPro and Ustahl is licensed under CC BY-NC-ND 4.0. --
-- To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-nd/4.0/--

--normalized sigmoid function for new_throttle function by JPG_18

-- [THROTTLE_LUA]
-- THROTTLE_GAMMA=1.0 ; Defaults to 1.0 if not specified.
-- THROTTLE_SLOPE=1.5 ; Defaults to 1.5 if not specified.
-- IDLE_RPM=1000 ; Defaults to 1000 if not specified.
-- THROTTLE_TYPE=0 ; 0=Cable Throttle, 1=Drive by Wire. Defaults to 0 if not specified.
---------------------------------------------------------------------------------------------------

-- Get the redline RPM for calculations and coast torque for mode 1 --
local data = ac.accessCarPhysics()
local engine_ini = ac.INIConfig.carData(0, "engine.ini")
local redline = engine_ini:get("ENGINE_DATA", "LIMITER", 10000)
----------------------------------------------------------------------

-- Get coast values for idle model --
local idle_RPM = engine_ini:get("ENGINE_DATA", "MINIMUM", 1000)
local coast_RPM = engine_ini:get("COAST_REF", "RPM", 10000)
local coast_torque_ref = engine_ini:get("COAST_REF", "TORQUE", 80)
-----------------------------------

-- Load the power.lut (for idle model) --
local power_lut = engine_ini:get("HEADER", "POWER_CURVE", "")
local WOT_TORQUE = ac.DataLUT11.carData(0, power_lut)
-----------------------------------------

-- Custom parameters --
local gamma = engine_ini:get("THROTTLE_LUA", "THROTTLE_GAMMA", 1.0) -- Throttle gamma
local slope = engine_ini:get("THROTTLE_LUA", "THROTTLE_SLOPE", 1.5) -- Torque mode
local throttle_type = engine_ini:get("THROTTLE_LUA", "THROTTLE_TYPE", 0) -- Throttle type (0 = cable, 1 = dbw)
local new_idle = engine_ini:get("THROTTLE_LUA", "IDLE_RPM", idle_RPM) -- New idle RPM
-------------------------------------------------

-- Variables or something --
local isIdleInitialized = false
local coast_torque
local idle_torque
local idle_throttle_ref
local idle_model_throttle

local modelled_throttle

local final_throttle
----------------------

local function _idleModelSetup()
    coast_torque = -(coast_torque_ref/(coast_RPM - idle_RPM)) * (new_idle - idle_RPM)
    idle_torque = WOT_TORQUE:get(new_idle)
    idle_throttle_ref = (0 - coast_torque)/(idle_torque - coast_torque)
    isIdleInitialized = true
end

local function calculateIdleTorque(rpm) 
	if data.rpm > 0 then
		return math.saturate(math.min(idle_throttle_ref * new_idle / rpm, idle_throttle_ref * (1 + idle_throttle_ref)))
	else
		return idle_throttle_ref * (1 + idle_throttle_ref)
	end
end

local function calculateTorque(throttle, rpm)
    local new_throttle = ((2/(1+(math.exp(-((redline/rpm)^gamma)*slope*throttle)))-1))/((2/(1+(math.exp(-((redline/rpm)^gamma)*slope*1)))-1))
    return new_throttle
end


local switch_throttle_model = {}

function switch_throttle_model.runThrottleModel()
    if not isIdleInitialized then _idleModelSetup() end

    idle_model_throttle = calculateIdleTorque(data.rpm)
    modelled_throttle = calculateTorque(data.gas, data.rpm)

    if modelled_throttle > idle_model_throttle then
        final_throttle = modelled_throttle
    else
        if throttle_type == 1 then
            final_throttle = data.rpm > new_idle and 0 or idle_model_throttle
        else
            final_throttle = idle_model_throttle
        end
    end

    ac.overrideGasInput(final_throttle)

    -- ac.debug("input t: ", data.gas)
    -- ac.debug("idle throttle should be in use: ", modelled_throttle < idle_model_throttle)
    -- ac.debug("idle throttle: ", idle_model_throttle)
    -- ac.debug("output t: ", final_throttle)
    -- ac.debug("rpm: ", data.rpm)
end

return switch_throttle_model