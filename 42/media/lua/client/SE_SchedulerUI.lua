--[[
    Safehouse Expanded
    SchedulerUI

    Handles the creation, opening, closing, updating, and logic of the scheduler UI window.
]]

require "SE_Core"
require "SE_AdvancedScheduler"

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISScrollingListBox"

SafehouseExpanded.SchedulerUI = SafehouseExpanded.SchedulerUI or {}

local ui = SafehouseExpanded.SchedulerUI
local scheduler = SafehouseExpanded.Scheduler

ui.Window = ISCollapsableWindow:derive("AdvancedSchedulerWindow")
function ui.Window:new()
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

function ui.Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 12

    self.memberList = ISScrollingListBox:new(12,top+27,180,306)
    self.memberList:initialise()
    self.memberList:instantiate()
    self.memberList.itemheight = 30
    self.memberList:setOnMouseDownFunction(self, ui.Window.onMemberSelected)
    self:addChild(self.memberList)

    self.jobCombo = ISComboBox:new(252,top,300,26,self, ui.Window.onJobSelected)
    self.jobCombo:initialise()
    self.jobCombo:instantiate()

    for _, job in ipairs(scheduler.getJobOptions()) do
        self.jobCombo:addOptionWithData(job.label,job.id)
    end

    self:addChild(self.jobCombo)
    self.jobCombo:setSelectedData("IDLE")
    self.hourButtons = {}

    for hour=0,23 do
        local col = hour % 12
        local row = math.floor(hour / 12)
        local btn = ISButton:new(210+col*56, top+90+row*67, 52, 52, tostring(hour), self, ui.Window.onHourClicked)
        btn:initialise()
        btn:instantiate()
        btn.hour = hour
        self:addChild(btn)
        self.hourButtons[hour+1] = btn
    end

    self.copyButton = ISButton:new(210,top+260,210,30,"Copy day to all residents", self, ui.Window.onCopyAll)
    self.copyButton:initialise()
    self.copyButton:instantiate()
    self:addChild(self.copyButton)

    self.applyButton = ISButton:new(650,top+260,232,30,"Apply current hour now", self, ui.Window.onApplyNow)
    self.applyButton:initialise()
    self.applyButton:instantiate()
    self:addChild(self.applyButton)

    self:reloadRoster()
end

function ui.Window:reloadRoster()
    local entries = scheduler.getResidents()
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

function ui.Window:onMemberSelected()
    local item = self.memberList.items[self.memberList.selected]
    if item and item.item then self.selectedId = item.item.id end
    self:updateGrid()
end

function ui.Window:onJobSelected(combo)
    self.jobId = tostring(combo:getSelectedData() or "IDLE")
end

-- update grid to show current job schedule
function ui.Window:updateGrid()
    local schedule = self.selectedId and scheduler.loadOrDefaultSchedule(self.selectedId) or nil
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
function ui.Window:onHourClicked(btn)
    if not self.selectedId then return end
    local schedule = scheduler.loadOrDefaultSchedule(self.selectedId)

    schedule[btn.hour+1] = self.jobId
    self:updateGrid()
end

-- copy schedule to all other survivors
function ui.Window:onCopyAll()
    if not self.selectedId then return end
    local src = scheduler.loadOrDefaultSchedule(self.selectedId)
    for _, member in ipairs(scheduler.getResidents()) do
        local dst = scheduler.loadOrDefaultSchedule(member.id)
        for h=1,24 do dst[h] = src[h] end
    end
    self:updateGrid()
end

-- Resets last applied, so the next tick will automatically apply the jobs
function ui.Window:onApplyNow()
    scheduler.lastApplied = {}
    scheduler.tick(true)
end

-- close the scheduler window
function ui.Window:close()
    self:setVisible(false)
    self:removeFromUIManager()

    ui.window = nil
end

-- open the scheduler window
function ui.open(selectedId)
    if ui.window then
        ui.window.selectedId = selectedId
        
        ui.window:setVisible(true)
        ui.window:bringToTop()
        ui.window:reloadRoster()
        return
    end

    local w = ui.Window:new()
    w.selectedId = selectedId 
    w:initialise()
    w:instantiate()
    w:addToUIManager()

    ui.window = w
end