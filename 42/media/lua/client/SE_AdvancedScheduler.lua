--[[
    Safehouse Expanded
    Scheduling Module

    Provides persistent hourly job schedules for
    Project Remnants safehouse residents.
]]

-- pat's project remnants dependencies
require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISScrollingListBox"
require "NPCFW_FactionManagementUI"

-- SafehouseExpanded dependencies
require "SE_Logger"

PPR_SafehouseExpanded = PPR_SafehouseExpanded or {}
PPR_SafehouseExpanded.Scheduler = PPR_SafehouseExpanded.Scheduler or {}

local se_scheduler = PPR_SafehouseExpanded.Scheduler

-- Data key, keep constant for save compatibility
se_scheduler.KEY = "RHS_HourlySchedules_V1"

-- keep track of last time a job was applied to the NPC
se_scheduler.lastApplied = se_scheduler.lastApplied or {}
se_scheduler.lastHour = se_scheduler.lastHour or -1
se_scheduler.lastDay = se_scheduler.lastDay or -1

-- get the player
local function player() return getSpecificPlayer(0) end

-- retrieves the existing scheduler data, or creates new one
local function data()
    local p = player()
    if not p then return nil end

    local md = p:getModData()
    if not md[se_scheduler.KEY] then md[se_scheduler.KEY] = {} end
    return md[se_scheduler.KEY]
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
function se_scheduler.getResidents()
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
function se_scheduler.getJobOptions()
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
function se_scheduler.loadOrDefaultSchedule(id)
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
        SafehouseExpanded.warn("Failed to set a job for " .. npcID)
        return false
    end
    return return_val ~= false
end

function se_scheduler.apply(npcId, desired, force)
    if not desired then return end
    if not force and se_scheduler.lastApplied[npcId] == desired then return end

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

    if ok then se_scheduler.lastApplied[npcId] = desired end
end

function se_scheduler.tick(force)
    local p = player()
    if not p or not NPCFW or not NPCFW.ready then return end

    local time = getGameTime()
    if not time then return end

    local hour = time:getHour()
    local day = math.floor(time:getWorldAgeHours() / 24)

    if not force and se_scheduler.lastHour == hour and se_scheduler.lastDay == day then return end
    se_scheduler.lastHour, se_scheduler.lastDay = hour, day

    local active = {}
    for _, npc in ipairs(se_scheduler.getResidents()) do
        active[npc.id] = true
        local schedule = se_scheduler.loadOrDefaultSchedule(npc.id)
        if schedule then se_scheduler.apply(npc.id, schedule[hour+1], force) end
    end

    for id in pairs(se_scheduler.lastApplied) do
        if not active[id] then se_scheduler.lastApplied[id] = nil end
    end
    
end

--[[
    Handles the creation of the Advanced Scheduler window
]]
se_scheduler.Window = ISCollapsableWindow:derive("AdvancedSchedulerWindow")
function se_scheduler.Window:new()
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

function se_scheduler.Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 12

    self.memberList = ISScrollingListBox:new(12,top+27,180,306)
    self.memberList:initialise()
    self.memberList:instantiate()
    self.memberList.itemheight = 30
    self.memberList:setOnMouseDownFunction(self, se_scheduler.Window.onMemberSelected)
    self:addChild(self.memberList)

    self.jobCombo = ISComboBox:new(252,top,300,26,self, se_scheduler.Window.onJobSelected)
    self.jobCombo:initialise()
    self.jobCombo:instantiate()

    for _, job in ipairs(se_scheduler.getJobOptions()) do
        self.jobCombo:addOptionWithData(job.label,job.id)
    end

    self:addChild(self.jobCombo)
    self.jobCombo:setSelectedData("IDLE")
    self.hourButtons = {}

    for hour=0,23 do
        local col = hour % 12
        local row = math.floor(hour / 12)
        local btn = ISButton:new(210+col*56, top+90+row*67, 52, 52, tostring(hour), self, se_scheduler.Window.onHourClicked)
        btn:initialise()
        btn:instantiate()
        btn.hour = hour
        self:addChild(btn)
        self.hourButtons[hour+1] = btn
    end

    self.copyButton = ISButton:new(210,top+260,210,30,"Copy day to all residents", self, se_scheduler.Window.onCopyAll)
    self.copyButton:initialise()
    self.copyButton:instantiate()
    self:addChild(self.copyButton)

    self.applyButton = ISButton:new(650,top+260,232,30,"Apply current hour now", self, se_scheduler.Window.onApplyNow)
    self.applyButton:initialise()
    self.applyButton:instantiate()
    self:addChild(self.applyButton)

    self:reloadRoster()
end

function se_scheduler.Window:reloadRoster()
    local entries = se_scheduler.getResidents()
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

function se_scheduler.Window:onMemberSelected()
    local item = self.memberList.items[self.memberList.selected]
    if item and item.item then self.selectedId = item.item.id end
    self:updateGrid()
end

function se_scheduler.Window:onJobSelected(combo)
    self.jobId = tostring(combo:getSelectedData() or "IDLE")
end

-- update grid to show current job schedule
function se_scheduler.Window:updateGrid()
    local schedule = self.selectedId and se_scheduler.loadOrDefaultSchedule(self.selectedId) or nil
    local current = getGameTime() and getGameTime():getHour() or -1

    for hour = 0,23 do
        local button = self.hourButtons[hour+1]
        if button then
            local task = schedule and schedule[hour+1] or "-"
            local prefix = current == hour and ">" or ""

            button:setTitle(prefix .. string.format("%02d",hour) .. "\n" .. tostring(task))
            button:setEnable(schedule ~= nil)

            --TODO: Better colors
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
function se_scheduler.Window:onHourClicked(btn)
    if not self.selectedId then return end
    local schedule = se_scheduler.loadOrDefaultSchedule(self.selectedId)
    schedule[btn.hour+1] = self.jobId
    self:updateGrid()
end

-- copy schedule to all other survivors
function se_scheduler.Window:onCopyAll()
    if not self.selectedId then return end
    local src = se_scheduler.loadOrDefaultSchedule(self.selectedId)
    for _, member in ipairs(se_scheduler.getResidents()) do
        local dst = se_scheduler.loadOrDefaultSchedule(member.id)
        for h=1,24 do dst[h] = src[h] end
    end
    self:updateGrid()
end

-- Resets last applied, so the next tick will automatically apply the jobs
function se_scheduler.Window:onApplyNow()
    se_scheduler.lastApplied = {}
    se_scheduler.tick(true)
end

-- close the scheduler window
function se_scheduler.Window:close()
    self:setVisible(false)
    self:removeFromUIManager()

    se_scheduler.window = nil
end

-- open the scheduler window
function se_scheduler.open(selectedId)
    if se_scheduler.window then
        se_scheduler.window.selectedId = selectedId
        
        se_scheduler.window:setVisible(true)
        se_scheduler.window:bringToTop()
        se_scheduler.window:reloadRoster()
        return
    end

    local w = se_scheduler.Window:new()
    w.selectedId = selectedId 
    w:initialise()
    w:instantiate()
    w:addToUIManager()

    se_scheduler.window = w
end

--[[
    Install the patch of the Project Remnants mod, that actually allows my mod to work :)
]]
local function installPatch()
    if se_scheduler.patched or not NPCFW_FactionManagementUI then return end

    local ui = NPCFW_FactionManagementUI
    if not ui.buildMembersContent or not ui.rebuildMemberJobCombos then return end

    ui.rebuildMemberJobCombos = function(self)
        if self.clearMemberJobCombos then 
            self:clearMemberJobCombos() 
        end

        if not self.memberList then return      end

        local rowTop = 0
        for index, npc in ipairs(self.rosterEntries or {}) do
            local item = self.memberList.items[index]
            local rowHeight = item and item.height or self.memberList.itemheight

            local buttonHeight = 24
            local buttonY = rowTop + math.floor((rowHeight - buttonHeight) / 2)

            local listWidth = self.memberList:getWidth()

            local buttonX = math.floor(listWidth * 0.72) + 2
            local buttonWidth = math.floor(listWidth * 0.25)

            local npcId = npc.npcId

            local button = ISButton:new(buttonX, buttonY, buttonWidth, buttonHeight, "Edit Schedule", self, function()
                se_scheduler.open(npcId)
            end
            )

            button:initialise()
            button:instantiate()

            self.memberList:addChild(button)
            button:setScrollWithParent(true)


            -- move to the next row
            rowTop = rowTop + rowHeight
        end
    end

    se_scheduler.patched = true
    SafehouseExpanded.log("Sucessfully patched Remnants with Advanced Scheduler logic.")
end

-- Hook on game start and a periodic fallback in case Remnants loads after this addon.
Events.OnGameStart.Add(function()
    installPatch()
    se_scheduler.tick(true)
end)
Events.EveryHours.Add(function()
    installPatch()
    se_scheduler.tick(false)
end)

-- Independent entry point: right-click anywhere on the ground to open the planner.
-- This remains available when another mod overrides Remnants' Members UI.
-- local function AS_WorldContext(playerIndex, context, worldObjects, test)
--     if test or not context or not NPCFW or not NPCFW.ready then return end
--     if not npcfwGetPlayerFactionRoster then return end
--     context:addOption("Safehouse Expanded: Hourly Scheduler", nil, function()
--         s.open()
--     end)
-- end
-- Events.OnFillWorldObjectContextMenu.Add(AS_WorldContext)

-- Immediate install attempt, with delayed retries already registered above.
installPatch()
SafehouseExpanded.log("Advanced Scheduler loaded.")
