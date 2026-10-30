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
presets.INITIALIZED_KEY = "SE_Presets_Initialized_v1"

local BUILTIN_PRESETS = {
        ["Default"] = {
        -- 00:00 - 07:00
        "SLEEP", "SLEEP", "SLEEP", "SLEEP",
        "SLEEP", "SLEEP", "SLEEP", "SLEEP",

        -- 08:00 - 15:00
        "IDLE", "IDLE", "IDLE", "IDLE",
        "IDLE", "IDLE", "IDLE", "IDLE",

        -- 16:00 - 23:00
        "IDLE", "IDLE", "IDLE", "IDLE",
        "IDLE", "IDLE", "IDLE", "IDLE"
    },

    ["Farmer"] = {
        -- 00:00 - 07:00
        "SLEEP", "SLEEP", "SLEEP", "SLEEP",
        "SLEEP", "IDLE", "FARMER", "FARMER",

        -- 08:00 - 15:00
        "FARMER", "FARMER", "FARMER", "FARMER",
        "IDLE", "FARMER", "FARMER", "FARMER",

        -- 16:00 - 23:00
        "FARMER", "FARMER", "FARMER", "IDLE",
        "IDLE", "SLEEP", "SLEEP", "SLEEP"
    },

    ["Lumberjack"] = {
        -- 00:00 - 07:00
        "SLEEP", "SLEEP", "SLEEP", "SLEEP",
        "SLEEP", "SLEEP", "SLEEP", "SLEEP",

        -- 08:00 - 15:00
        "IDLE", "LUMBERJACK", "LUMBERJACK", "LUMBERJACK",
        "IDLE", "LUMBERJACK", "LUMBERJACK", "LUMBERJACK",

        -- 16:00 - 23:00
        "LUMBERJACK", "LUMBERJACK", "LUMBERJACK", "LUMBERJACK",
        "HAULER", "HAULER", "IDLE", "IDLE"
    },

    ["Hauler"] = {
        -- 00:00 - 07:00
        "SLEEP", "SLEEP", "SLEEP", "SLEEP",
        "SLEEP", "SLEEP", "SLEEP", "SLEEP",

        -- 08:00 - 15:00
        "IDLE", "HAULER", "HAULER", "HAULER",
        "IDLE", "HAULER", "HAULER", "HAULER",

        -- 16:00 - 23:00
        "HAULER", "HAULER", "HAULER", "HAULER",
        "HAULER", "HAULER", "IDLE", "IDLE"
    },

    ["Cook"] = {
        -- 00:00 - 07:00
        "SLEEP", "SLEEP", "SLEEP", "SLEEP",
        "SLEEP", "SLEEP", "COOK", "COOK",

        -- 08:00 - 15:00
        "COOK", "COOK", "COOK", "COOK",
        "IDLE", "IDLE", "COOK", "COOK",

        -- 16:00 - 23:00
        "COOK", "COOK", "HAULER", "HAULER",
        "IDLE", "IDLE", "SLEEP", "SLEEP"
    },

    ["Day Guard"] = {
        -- 00:00 - 07:00
        "SLEEP", "SLEEP", "SLEEP", "SLEEP",
        "SLEEP", "SLEEP", "SLEEP", "SLEEP",

        -- 08:00 - 15:00
        "IDLE", "IDLE", "GUARD", "GUARD",
        "GUARD", "GUARD", "GUARD", "GUARD",

        -- 16:00 - 23:00
        "GUARD", "GUARD", "GUARD", "GUARD",
        "GUARD", "GUARD", "IDLE", "IDLE"
    },

    ["Night Guard"] = {
        -- 00:00 - 07:00
        "GUARD", "GUARD", "GUARD", "GUARD",
        "GUARD", "GUARD", "GUARD", "GUARD",

        -- 08:00 - 15:00
        "GUARD", "GUARD", "IDLE", "IDLE",
        "SLEEP", "SLEEP", "SLEEP", "SLEEP",

        -- 16:00 - 23:00
        "SLEEP", "SLEEP", "SLEEP", "SLEEP",
        "IDLE", "IDLE", "GUARD", "GUARD"
    },
}

-- ===================
-- UTILITY FUNCTIONS |
-- ===================

local function data()
    local p = getSpecificPlayer(0)
    if not p then return nil end

    local mod_data = p:getModData()

    if not mod_data[presets.KEY] then
        mod_data[presets.KEY] = {}
    end

    local save = mod_data[presets.KEY]

    if not mod_data[presets.INITIALIZED_KEY] then
        for name, schedule in pairs(BUILTIN_PRESETS) do
            if not save[name] then
                local copy = {}

                for hour = 1, 24 do
                    copy[hour] = schedule[hour]
                end

                save[name] = copy
            end
        end

        mod_data[presets.INITIALIZED_KEY] = true
    end

    return save
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

-- Finds a preset that matches a given schedule
function presets.findMatch(schedule)
    if not schedule or #schedule ~= 24 then return nil end

    for _, name in ipairs(presets.getAll()) do
        local preset = presets.get(name)

        if preset then
            local matches = true

            for hour = 1, 24 do
                if preset[hour] ~= schedule[hour] then
                    matches = false
                    break
                end
            end

            if matches then
                return name
            end
        end
    end

    return nil
end