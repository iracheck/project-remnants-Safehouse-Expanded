--[[
    Safehouse Expanded
    Scheduler Presets

    Handles saving, loading, deleting, and applying
    custom and built-in schedule presets.
]]

require "00_Core/SE_Core"

SafehouseExpanded.SchedulerPresets = SafehouseExpanded.SchedulerPresets or {}

local presets = SafehouseExpanded.SchedulerPresets

presets.KEY = "SE_SchedulerPresetData_v1"

-- ===================
-- UTILITY FUNCTIONS |
-- ===================

-- retrieves the existing scheduler data, or creates new one
local function data()
    local p = getSpecificPlayer(0)
    if not p then return nil end

    local mod_data = p:getModData()
    if not mod_data[presets.KEY] then mod_data[presets.KEY] = {} end
    return mod_data[presets.KEY]
end

-- ==================
-- DATA INTERACTION |
-- ==================

function presets.save(name, schedule)
    if not schedule or #schedule ~= 24 then
        SafehouseExpanded.warn("Tried to save a preset that either did not exist, or was not the correct size")
        return false
    end

    if type(name) ~= "string" then
        SafehouseExpanded.warn("Invalid preset name")
        return false
    end

    name = name:match("^%s*(.-)%s*$")

    if name == "" then
        SafehouseExpanded.warn("Cannot save a preset with an empty name")
        return false
    end

    local copy = {}
    local save = data()

    if not save then return false end

    for hour = 1, 24 do
        copy[hour] = schedule[hour]
    end

    save[name] = copy

    return true
end

function presets.get(name)
    local save = data()
    if not save then return nil end

    return save[name]
end

function presets.copy(name)
    local data = presets.get(name)
    local copy = {}

    if not data then
        return nil
    end

    for hour = 1, 24 do
        copy[hour] = data[hour]
    end

    return copy
end

function presets.delete(name)
    if presets.get(name) then
        SafehouseExpanded.log("Deleted preset \"" .. name .. "\"")
        data()[name] = nil
        return true
    end

    SafehouseExpanded.warn("Failed to delete preset \"" .. name .. "\"")

    return false
end

function presets.getAll()
    local save = data()
    if not save then return {} end

    local all = {}

    for name, schedule in pairs(save) do
        all[#all + 1] = name
    end

    table.sort(all)
    return all

end