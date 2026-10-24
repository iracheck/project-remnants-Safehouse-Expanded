--[[
    Safehouse Expanded
    Scheduling Module

    Provides persistent hourly job schedules for
    Project Remnants safehouse residents.
]]

-- SafehouseExpanded dependencies
require "SE_Core"
require "SE_Logger"

SafehouseExpanded.Scheduler = SafehouseExpanded.Scheduler or {}

local scheduler = SafehouseExpanded.Scheduler

-- Data key, keep constant for save compatibility
scheduler.KEY = "SE_SchedulerData_v1"

-- keep track of last time a job was applied to the NPC
scheduler.lastApplied = scheduler.lastApplied or {}
scheduler.lastHour = scheduler.lastHour or -1
scheduler.lastDay = scheduler.lastDay or -1

-- get the player
local function player() return getSpecificPlayer(0) end

-- retrieves the existing scheduler data, or creates new one
local function data()
    local p = player()
    if not p then return nil end

    local mod_data = p:getModData()
    if not mod_data[scheduler.KEY] then mod_data[scheduler.KEY] = {} end
    return mod_data[scheduler.KEY]
end

-- converts a Java table into a Lua array
local function toRows(javaTable)
    local rows = {}

    if not javaTable then return rows end

    local i = 1
    while javaTable[i] and i <= 500 do
        rows[#rows + 1] = javaTable[i]
        i = i + 1
    end

    return rows
end

-- get all residents currently at home (does not include residents following the player)
function scheduler.getResidents()
    if not npcfwGetPlayerFactionRoster then return {} end

    local ok, result = pcall(npcfwGetPlayerFactionRoster)

    if not ok then return {} end
    local members = {}

    for _, r in ipairs(toRows(result)) do
        if r.isBaseResident == true or tostring(r.assignment or "") == "BASE_RESIDENT" then
            members[#members + 1] = {
                id = tostring(r.npcId),
                name = tostring(r.displayName or r.npcId),
            }
        end
    end

    table.sort(members, function(a,b) return a.name < b.name end)
    return members
end

-- gets all the possible jobs for the scheduler to handle
function scheduler.getJobOptions()
    -- non-Remnants options: Idle and Sleep
    local options = {
        {id="IDLE", label="Idle / Recreation"},
        {id="SLEEP", label="Sleep"}
    }

    if npcfwGetSafehouseJobDefs then
        local success, return_val = pcall(npcfwGetSafehouseJobDefs)
        if success then
            for _, j in ipairs(toRows(return_val)) do
                local id = tostring(j.id or "NONE")

                if id ~= "NONE" and id ~= "IDLE" and id ~= "SLEEP" then
                    options[#options+1] = {id=id, label=tostring(j.label or id)}
                end
            end

        end

    end
    return options
end

-- gets the schedule of an npc, or loads the default one if one does not exist
function scheduler.loadOrDefaultSchedule(id)
    local store = data()
    if not store then return nil end

    id = tostring(id)
    if not store[id] then
        local hours = {}

        -- assign a default schedule that is just the default of Project Remnants--> idle all day
        for hour = 0, 23 do
            hours[hour + 1] = "IDLE"
        end

        store[id] = hours
    end
    return store[id]
end

-- called when the hours change to set the job of the npc to a new one
local function setJob(npcId, job)
    if not npcfwSetSafehouseJob then return false end

    local success, return_val = pcall(npcfwSetSafehouseJob, npcId, job)

    if not success then
        SafehouseExpanded.warn("Failed to set a job for " .. npcId)
        return false
    end

    return return_val ~= false
end

function scheduler.apply(npcId, desired, force)
    if not desired then return end
    if not force and scheduler.lastApplied[npcId] == desired then return end

    local ok = false

    if desired == "IDLE" then
        ok = setJob(npcId, "NONE")

    elseif desired == "SLEEP" then
        local cleared = setJob(npcId, "NONE")
        local npc

        if npcfwGetNPC then
            local found, value = pcall(npcfwGetNPC, npcId)
            if found then npc = value end
        end

        if npc and npcfwOrderSafehouseSleep then
            local allowed = true
            if npcfwCanOrderSafehouseSleep then
                local success, return_val = pcall(npcfwCanOrderSafehouseSleep, npc)
                allowed = success and return_val == true
            end
            if allowed then
                local success, return_val = pcall(npcfwOrderSafehouseSleep, npc)
                ok = success and return_val ~= false
            end
        end
        if not ok then ok = false end 
    -- otherwise, they are assigned a job--> tell them to work it!
    else
        ok = setJob(npcId, desired)
    end

    if ok then scheduler.lastApplied[npcId] = desired end
end

function scheduler.tick(force)
    local p = player()
    if not p or not NPCFW or not NPCFW.ready then return end

    local time = getGameTime()
    if not time then return end

    local hour = time:getHour()
    local day = math.floor(time:getWorldAgeHours() / 24)

    if not force and scheduler.lastHour == hour and scheduler.lastDay == day then return end
    scheduler.lastHour, scheduler.lastDay = hour, day

    local active = {}
    for _, npc in ipairs(scheduler.getResidents()) do
        active[npc.id] = true
        local schedule = scheduler.loadOrDefaultSchedule(npc.id)
        if schedule then scheduler.apply(npc.id, schedule[hour+1], force) end
    end

    for id in pairs(scheduler.lastApplied) do
        if not active[id] then scheduler.lastApplied[id] = nil end
    end
    
end

-- Initial startup
function scheduler.enable()
    if scheduler.enabled then return end
    scheduler.enabled = true

    Events.OnGameStart.Add(scheduler.onGameStart)
    Events.EveryHours.Add(scheduler.onEveryHour)
end

function scheduler.onGameStart()
    scheduler.tick(true)
end

function scheduler.onEveryHour()
    scheduler.tick(false)
end