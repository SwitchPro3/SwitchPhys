--- This work © 2024 by Ustahl is licensed under CC BY-SA 4.0.
--- To view a copy of this license, visit
--- https://creativecommons.org/licenses/by-sa/4.0/

local engine_file = ac.INIConfig.carData(0, "engine.ini")
local drivetrain_file = ac.INIConfig.carData(0, "drivetrain.ini")
local _turbo_ref_gear_initialized = false

local _isInMenu = false
local _wasInMenu = false

local last_gear
local current_gear
local gear_changed = false

local detected_turbo_count = ac.getCar(0).turboCount
local turbos = {}
local gear_ratios = {}
local gear_ratio_closest_to_1
local ref_rpm_by_gear = {}
local final_drive_ratio

local interval

local function detectTurbos()
    for i = 0, detected_turbo_count - 1, 1 do
        table.insert(turbos, {
            max_boost = engine_file:get('TURBO_' .. i, 'MAX_BOOST', 0),
            ref_rpm = engine_file:get('TURBO_' .. i, 'REFERENCE_RPM', 3000),
            lag_up = engine_file:get('TURBO_' .. i, 'LAG_UP', 0.99),
            lag_dn = engine_file:get('TURBO_' .. i, 'LAG_DN', 0.99),
            gamma = engine_file:get('TURBO_' .. i, 'GAMMA', 1.5),
        })
    end
end

local function findRatioClosestTo1()
    local closest = gear_ratios[1]
    local closest_diff = math.abs(1 - closest)
    local diff
    for i = 2, #gear_ratios, 1 do
        diff = math.abs(1 - gear_ratios[i])
        if diff < closest_diff then
            closest = gear_ratios[i]
            closest_diff = diff
        end
    end
    gear_ratio_closest_to_1 = closest
end

local function updateGearRatiosAndFinalDrive()
    local ratios = ac.getCarPhysics(0).gearRatios
    gear_ratios = {[0] = math.round(math.abs(ratios[0]), 3)}
    for i = 3, #ratios, 1 do
        table.insert(gear_ratios, math.round(ratios[i - 1], 3))
    end
    local default_final_drive = drivetrain_file:get('GEARS', 'FINAL', 3)
    local final_drive = math.round(ac.getCarPhysics(0).finalRatio, 3)
    final_drive_ratio = math.round(default_final_drive / final_drive, 3)
end

local function _calcBoostExponent(gear_ratio, max_boost)
    return (0.07625 * max_boost ^ 2 + 0.07126 * max_boost + 1.052) ^ (gear_ratio * final_drive_ratio)
end

local function adjustBaseRefRPM()
    for i = 1, detected_turbo_count, 1 do
        turbos[i].ref_rpm = math.round(turbos[i].ref_rpm / _calcBoostExponent(gear_ratio_closest_to_1 * final_drive_ratio, turbos[i].max_boost))
    end
end

local function calculateRefRPMByGear()
    local final_ref_rpm, max_boost, ref_rpm

    for i = 1, detected_turbo_count, 1 do
        max_boost = turbos[i].max_boost
        ref_rpm = turbos[i].ref_rpm
        ref_rpm_by_gear[i] = {}
        -- iterate though gears and build tables for each turbo
        for index, ratio in pairs(gear_ratios) do
            final_ref_rpm = math.round(ref_rpm * _calcBoostExponent(ratio, max_boost))
            table.insert(ref_rpm_by_gear[i], index, final_ref_rpm)
        end
    end
end

local function initializeTurboRefGear()
    --cleanup
    turbos = {}
    gear_ratios = {}
    ref_rpm_by_gear = {}
    gear_ratio_closest_to_1 = nil
    final_drive_ratio = nil

    updateGearRatiosAndFinalDrive()
    findRatioClosestTo1()
    detectTurbos()
    adjustBaseRefRPM()
    calculateRefRPMByGear()
    last_gear = 1
    current_gear = 1

    _turbo_ref_gear_initialized = true
end

local function adjustTurboRefRPMByGear(gear)
    local ref_rpm, lag_up, lag_dn, gamma
    for i = 1, detected_turbo_count, 1 do
        lag_up = turbos[i].lag_up
        lag_dn = turbos[i].lag_dn
        gamma = turbos[i].gamma

        if gear == -1 then
            ref_rpm = ref_rpm_by_gear[i][0]
        elseif gear > 0 then
            ref_rpm = ref_rpm_by_gear[i][gear]
        else
            ref_rpm = ref_rpm_by_gear[i][1] * 2
        end

        if gear == 1 and gamma > 1 then gamma = 1 end -- idk if this is needed?

        ac.setTurboExtras(i - 1, lag_up, lag_dn, ref_rpm, gamma)
    end
    gear_changed = false
end

function script.update(dt)
    if ac.getSim().isInMainMenu then
        _isInMenu = true
    else
        if _isInMenu then
            _isInMenu = false
            _wasInMenu = true
        end
        if _wasInMenu and _turbo_ref_gear_initialized then
            _turbo_ref_gear_initialized = false
            _wasInMenu = false
        end
    end
    if not _turbo_ref_gear_initialized then
        if interval then
            clearInterval(interval)
        end
        initializeTurboRefGear()
    else
        interval = setInterval(function ()
            current_gear = ac.getCar(0).gear

            if last_gear ~= current_gear then
                gear_changed = true
                last_gear = current_gear
            end

            if gear_changed then
                adjustTurboRefRPMByGear(current_gear)
            end

        end, 0.016 ,"Turbo Ref RPM update loop")
    end
end