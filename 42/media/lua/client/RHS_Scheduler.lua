-- Remnants Hourly Scheduler: standalone Lua-only addon.
-- The first successful Remnants UI load installs the Members-tab patch.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISScrollingListBox"
require "NPCFW_FactionManagementUI"

RHS = RHS or {}
RHS.KEY = "RHS_HourlySchedules_V1"
RHS.lastApplied = RHS.lastApplied or {}
RHS.lastHour = RHS.lastHour or -1
RHS.lastDay = RHS.lastDay or -1

local function player() return getSpecificPlayer(0) end
local function data()
    local p = player()
    if not p then return nil end
    local md = p:getModData()
    if not md[RHS.KEY] then md[RHS.KEY] = {} end
    return md[RHS.KEY]
end

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

function RHS.roster()
    if not npcfwGetPlayerFactionRoster then return {} end
    local ok, result = pcall(npcfwGetPlayerFactionRoster)
    if not ok then return {} end
    local members = {}
    for _, r in ipairs(toRows(result)) do
        if r.isBaseResident == true or tostring(r.assignment or "") == "BASE_RESIDENT" then
            members[#members + 1] = {
                id = tostring(r.npcId),
                name = tostring(r.displayName or r.npcId),
                job = tostring(r.safehouseJob or "NONE"),
            }
        end
    end
    table.sort(members, function(a,b) return a.name < b.name end)
    return members
end

function RHS.jobOptions()
    local result = {{id="IDLE",label="Idle"},{id="SLEEP",label="Sleep"}}
    if npcfwGetSafehouseJobDefs then
        local ok, raw = pcall(npcfwGetSafehouseJobDefs)
        if ok then
            for _, j in ipairs(toRows(raw)) do
                local id = tostring(j.id or "NONE")
                if id ~= "NONE" and id ~= "IDLE" and id ~= "SLEEP" then
                    result[#result+1] = {id=id, label=tostring(j.label or id)}
                end
            end
        end
    end
    return result
end

function RHS.ensureSchedule(id)
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

local function setJob(npcId, job)
    if not npcfwSetSafehouseJob then return false end
    local ok, result = pcall(npcfwSetSafehouseJob, npcId, job)
    if not ok then
        print("[RHS] Job error for " .. npcId .. ": " .. tostring(result))
        return false
    end
    return result ~= false
end

function RHS.apply(npcId, desired, force)
    if not desired then return end
    if not force and RHS.lastApplied[npcId] == desired then return end
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
                local success, result = pcall(npcfwCanOrderSafehouseSleep, npc)
                allowed = success and result == true
            end
            if allowed then
                local success, result = pcall(npcfwOrderSafehouseSleep, npc)
                ok = success and result ~= false
            end
        end
        if not ok then ok = false end -- retry at next hourly boundary if unavailable
    else
        ok = setJob(npcId, desired)
    end
    if ok then RHS.lastApplied[npcId] = desired end
end

function RHS.tick(force)
    local p = player()
    if not p or not NPCFW or not NPCFW.ready then return end
    local time = getGameTime()
    if not time then return end
    local hour = time:getHour()
    local day = math.floor(time:getWorldAgeHours() / 24)
    if not force and RHS.lastHour == hour and RHS.lastDay == day then return end
    RHS.lastHour, RHS.lastDay = hour, day
    local active = {}
    for _, npc in ipairs(RHS.roster()) do
        active[npc.id] = true
        local schedule = RHS.ensureSchedule(npc.id)
        if schedule then RHS.apply(npc.id, schedule[hour+1], force) end
    end
    for id in pairs(RHS.lastApplied) do
        if not active[id] then RHS.lastApplied[id] = nil end
    end
end

RHS.Window = ISCollapsableWindow:derive("RHS_Window")
function RHS.Window:new()
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

function RHS.Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 12
    self.memberList = ISScrollingListBox:new(12,top+27,180,306)
    self.memberList:initialise()
    self.memberList:instantiate()
    self.memberList.itemheight = 30
    self.memberList:setOnMouseDownFunction(self, RHS.Window.onMemberSelected)
    self:addChild(self.memberList)
    self.jobCombo = ISComboBox:new(252,top,300,26,self,RHS.Window.onJobSelected)
    self.jobCombo:initialise()
    self.jobCombo:instantiate()
    for _, job in ipairs(RHS.jobOptions()) do
        self.jobCombo:addOptionWithData(job.label,job.id)
    end
    self:addChild(self.jobCombo)
    self.jobCombo:setSelectedData("IDLE")
    self.hourButtons = {}
    for hour=0,23 do
        local col = hour % 12
        local row = math.floor(hour / 12)
        local btn = ISButton:new(210+col*56, top+90+row*67, 52, 52, tostring(hour), self, RHS.Window.onHourClicked)
        btn:initialise()
        btn:instantiate()
        btn.hour = hour
        self:addChild(btn)
        self.hourButtons[hour+1] = btn
    end
    self.copyButton = ISButton:new(210,top+260,210,30,"Copy day to all residents",self,RHS.Window.onCopyAll)
    self.copyButton:initialise()
    self.copyButton:instantiate()
    self:addChild(self.copyButton)
    self.applyButton = ISButton:new(650,top+260,232,30,"Apply current hour now",self,RHS.Window.onApplyNow)
    self.applyButton:initialise()
    self.applyButton:instantiate()
    self:addChild(self.applyButton)
    self:reloadRoster()
end

function RHS.Window:reloadRoster()
    local entries = RHS.roster()
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

function RHS.Window:onMemberSelected()
    local item = self.memberList.items[self.memberList.selected]
    if item and item.item then self.selectedId = item.item.id end
    self:updateGrid()
end

function RHS.Window:onJobSelected(combo)
    self.jobId = tostring(combo:getSelectedData() or "IDLE")
end

function RHS.Window:updateGrid()
    local schedule = self.selectedId and RHS.ensureSchedule(self.selectedId) or nil
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

function RHS.Window:onHourClicked(btn)
    if not self.selectedId then return end
    local schedule = RHS.ensureSchedule(self.selectedId)
    schedule[btn.hour+1] = self.jobId
    self:updateGrid()
end

function RHS.Window:onCopyAll()
    if not self.selectedId then return end
    local src = RHS.ensureSchedule(self.selectedId)
    for _, member in ipairs(RHS.roster()) do
        local dst = RHS.ensureSchedule(member.id)
        for h=1,24 do dst[h] = src[h] end
    end
    self:updateGrid()
end

function RHS.Window:onApplyNow()
    RHS.lastApplied = {}
    RHS.tick(true)
end

function RHS.Window:close()
    self:setVisible(false)
    self:removeFromUIManager()
    RHS.window = nil
end

function RHS.open()
    if RHS.window then
        RHS.window:setVisible(true)
        RHS.window:bringToTop()
        RHS.window:reloadRoster()
        return
    end
    local w = RHS.Window:new()
    w:initialise()
    w:instantiate()
    w:addToUIManager()
    RHS.window = w
end

local function installPatch()
    if RHS.patched or not NPCFW_FactionManagementUI then return end
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
            "Open Hourly Scheduler", self, function() RHS.open() end)
        button:initialise()
        button:instantiate()
        panel:addChild(button)
        self.rhsButton = button
    end
    RHS.patched = true
    print("[RHS] Replaced Remnants job dropdowns with scheduler button")
end

-- Hook on game start and a periodic fallback in case Remnants loads after this addon.
Events.OnGameStart.Add(function()
    installPatch()
    RHS.tick(true)
end)
Events.EveryHours.Add(function()
    installPatch()
    RHS.tick(false)
end)

-- Independent entry point: right-click anywhere on the ground to open the planner.
-- This remains available when another mod overrides Remnants' Members UI.
local function rhsWorldContext(playerIndex, context, worldObjects, test)
    if test or not context or not NPCFW or not NPCFW.ready then return end
    if not npcfwGetPlayerFactionRoster then return end
    context:addOption("Remnants: Hourly Scheduler", nil, function()
        RHS.open()
    end)
end
Events.OnFillWorldObjectContextMenu.Add(rhsWorldContext)

-- Immediate install attempt, with delayed retries already registered above.
installPatch()
print("[RHS] Scheduler Lua loaded; right-click ground for Remnants: Hourly Scheduler")
