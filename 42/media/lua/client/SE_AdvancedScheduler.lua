--[[
    Safehouse Expanded
    Scheduling Module

    Provides persistent hourly job schedules for
    Project Remnants safehouse residents.
]]

require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISScrollingListBox"
require "NPCFW_FactionManagementUI"

PPR_SafehouseExpanded = PPR_SafehouseExpanded or {}
PPR_SafehouseExpanded.Scheduler = PPR_SafehouseExpanded.Scheduler or {}

local s = PPR_SafehouseExpanded.Scheduler

-- Data key, keep constant for save compatibility
s.KEY = "RHS_HourlySchedules_V1"

-- keep track of last time a job was applied to the NPC
s.lastApplied = s.lastApplied or {}
s.lastHour = s.lastHour or -1
s.lastDay = s.lastDay or -1

-- get the player
local function player() return getSpecificPlayer(0) end

-- retrieves the existing scheduler data, or creates new one
local function data()
    local p = player()
    if not p then return nil end

    local md = p:getModData()
    if not md[s.KEY] then md[s.KEY] = {} end
    return md[s.KEY]
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
function s.getResidents()
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
function s.getJobOptions()
    -- non-Remnants options: Idle and Sleep
    local options = {
        {id="IDLE",label="Idle / Recreation"},
        {id="SLEEP",label="Sleep"}
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
function s.loadOrDefaultSchedule(id)
    local store = data()
    if not store then return nil end

    id = tostring(id)
    if not store[id] then
        local hours = {}
        for hour = 0, 23 do hours[hour+1] = "IDLE" end
        store[id] = hours
    end
    return store[id]
end

-- called when the hours change to set the job of the npc to a new one
local function setJob(npcId, job)
    if not npcfwSetSafehouseJob then return false end

    local success, return_val = pcall(npcfwSetSafehouseJob, npcId, job)

    if not success then
        print("[RHS] Job error for " .. npcId .. ": " .. tostring(return_val))
        return false
    end
    return return_val ~= false
end

function s.apply(npcId, desired, force)
    if not desired then return end
    if not force and s.lastApplied[npcId] == desired then return end

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

    if ok then s.lastApplied[npcId] = desired end
end

function s.tick(force)
    local p = player()
    if not p or not NPCFW or not NPCFW.ready then return end

    local time = getGameTime()
    if not time then return end

    local hour = time:getHour()
    local day = math.floor(time:getWorldAgeHours() / 24)

    if not force and s.lastHour == hour and s.lastDay == day then return end
    s.lastHour, s.lastDay = hour, day

    local active = {}
    for _, npc in ipairs(s.getResidents()) do
        active[npc.id] = true
        local schedule = s.loadOrDefaultSchedule(npc.id)
        if schedule then s.apply(npc.id, schedule[hour+1], force) end
    end

    for id in pairs(s.lastApplied) do
        if not active[id] then s.lastApplied[id] = nil end
    end
    
end

--[[
    Handles the creation of the Advanced Scheduler window
]]
s.Window = ISCollapsableWindow:derive("AdvancedSchedulerWindow")
function s.Window:new()
    local w, h = 910, 430
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local o = ISCollapsableWindow.new(self, math.max(10,math.floor((sw-w)/2)), math.max(10,math.floor((sh-h)/2)), w, h)
    
    o.resizable = false
    o.title = "Remnants - Hourly Schedule"
    o.selectedId = nil
    o.jobId = "IDLE"
    return o
end

function s.Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 12

    self.memberList = ISScrollingListBox:new(12,top+27,180,306)
    self.memberList:initialise()
    self.memberList:instantiate()
    self.memberList.itemheight = 30
    self.memberList:setOnMouseDownFunction(self, s.Window.onMemberSelected)
    self:addChild(self.memberList)

    self.jobCombo = ISComboBox:new(252,top,300,26,self, s.Window.onJobSelected)
    self.jobCombo:initialise()
    self.jobCombo:instantiate()

    for _, job in ipairs(s.getJobOptions()) do
        self.jobCombo:addOptionWithData(job.label,job.id)
    end

    self:addChild(self.jobCombo)
    self.jobCombo:setSelectedData("IDLE")
    self.hourButtons = {}

    for hour=0,23 do
        local col = hour % 12
        local row = math.floor(hour / 12)
        local btn = ISButton:new(210+col*56, top+90+row*67, 52, 52, tostring(hour), self, s.Window.onHourClicked)
        btn:initialise()
        btn:instantiate()
        btn.hour = hour
        self:addChild(btn)
        self.hourButtons[hour+1] = btn
    end

    self.copyButton = ISButton:new(210,top+260,210,30,"Copy day to all residents", self, s.Window.onCopyAll)
    self.copyButton:initialise()
    self.copyButton:instantiate()
    self:addChild(self.copyButton)

    self.applyButton = ISButton:new(650,top+260,232,30,"Apply current hour now", self, s.Window.onApplyNow)
    self.applyButton:initialise()
    self.applyButton:instantiate()
    self:addChild(self.applyButton)

    self:reloadRoster()
end

function s.Window:reloadRoster()
    local entries = s.getResidents()
    self.memberList:clear()
    for _, item in ipairs(entries) do self.memberList:addItem(item.name,item) end
    local index = 1
    for i, entry in ipairs(entries) do
        if entry.id == self.selectedId then index = i break end
    end
    if #entries > 0 then
        self.memberList.selected = index
        self.selectedId = entries[index].id
    else
        self.selectedId = nil
    end
    self:updateGrid()
end

function s.Window:onMemberSelected()
    local item = self.memberList.items[self.memberList.selected]
    if item and item.item then self.selectedId = item.item.id end
    self:updateGrid()
end

function s.Window:onJobSelected(combo)
    self.jobId = tostring(combo:getSelectedData() or "IDLE")
end

-- update grid to show current job schedule
function s.Window:updateGrid()
    local schedule = self.selectedId and s.loadOrDefaultSchedule(self.selectedId) or nil
    local current = getGameTime() and getGameTime():getHour() or -1
    for hour = 0,23 do
        local button = self.hourButtons[hour+1]
        if button then
            local task = schedule and schedule[hour+1] or "-"
            local prefix = current == hour and ">" or ""
            button:setTitle(prefix .. string.format("%02d",hour) .. "\n" .. tostring(task))
            button:setEnable(schedule ~= nil)
            if task == "SLEEP" then
                button.backgroundColor = {r=0.35,g=0.28,b=0.58,a=0.9}
            elseif task == "IDLE" then
                button.backgroundColor = {r=0.18,g=0.46,b=0.37,a=0.9}
            else
                button.backgroundColor = {r=0.25,g=0.36,b=0.60,a=0.9}
            end
        end
    end
end

-- change hour to currently selected jobID
function s.Window:onHourClicked(btn)
    if not self.selectedId then return end
    local schedule = s.loadOrDefaultSchedule(self.selectedId)
    schedule[btn.hour+1] = self.jobId
    self:updateGrid()
end

-- copy schedule to all other survivors
function s.Window:onCopyAll()
    if not self.selectedId then return end
    local src = s.loadOrDefaultSchedule(self.selectedId)
    for _, member in ipairs(s.getResidents()) do
        local dst = s.loadOrDefaultSchedule(member.id)
        for h=1,24 do dst[h] = src[h] end
    end
    self:updateGrid()
end

-- Resets last applied, so the next tick will automatically apply the jobs
function s.Window:onApplyNow()
    s.lastApplied = {}
    s.tick(true)
end

-- close the scheduler window
function s.Window:close()
    self:setVisible(false)
    self:removeFromUIManager()
    s.window = nil
end

-- open the scheduler window
function s.open()
    if s.window then
        s.window:setVisible(true)
        s.window:bringToTop()
        s.window:reloadRoster()
        return
    end
    local w = s.Window:new()
    w:initialise()
    w:instantiate()
    w:addToUIManager()
    s.window = w
end

--[[
    Install the patch of the Project Remnants mod, that actually allows my mod to work :)
]]
local function installPatch()
    if s.patched or not NPCFW_FactionManagementUI then return end
    local cls = NPCFW_FactionManagementUI
    if not cls.buildMembersContent or not cls.rebuildMemberJobCombos then return end
    -- Keep all Remnants management features, but remove its immediate job dropdowns.
    -- Because refreshMemberList calls this dynamically, an empty override prevents recreation.
    local originalBuild = cls.buildMembersContent
    cls.rebuildMemberJobCombos = function(self)
        if self.clearMemberJobCombos then self:clearMemberJobCombos() end
    end
    cls.buildMembersContent = function(self)
        originalBuild(self)
        local panel = self.contentPanel
        if not panel then return end
        -- Use the header strip above the members list rather than (0, 0),
        -- which may be occluded by the tab's existing frame/controls.
        local leftW = self.memberLeftW or math.floor(self.contentW * 0.56)
        local button = ISButton:new(8, 2, math.min(230, leftW - 16), 24,
            "Open Hourly Scheduler", self, function() s.open() end)
        button:initialise()
        button:instantiate()
        panel:addChild(button)
        self.rhsButton = button
    end
    s.patched = true
    print("[RHS] Replaced Remnants job dropdowns with scheduler button")
end

-- Hook on game start and a periodic fallback in case Remnants loads after this addon.
Events.OnGameStart.Add(function()
    installPatch()
    s.tick(true)
end)
Events.EveryHours.Add(function()
    installPatch()
    s.tick(false)
end)

-- Independent entry point: right-click anywhere on the ground to open the planner.
-- This remains available when another mod overrides Remnants' Members UI.
local function AS_WorldContext(playerIndex, context, worldObjects, test)
    if test or not context or not NPCFW or not NPCFW.ready then return end
    if not npcfwGetPlayerFactionRoster then return end
    context:addOption("Remnants: Hourly Scheduler", nil, function()
        s.open()
    end)
end
Events.OnFillWorldObjectContextMenu.Add(AS_WorldContext)

-- Immediate install attempt, with delayed retries already registered above.
installPatch()
print("[PPR_SafehouseExpanded] Advanced Scheduler loaded.")
