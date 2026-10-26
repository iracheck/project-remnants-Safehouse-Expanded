--[[
    Safehouse Expanded
    SchedulerUI

    Handles the creation, opening, closing, updating, and logic of the scheduler UI window.
]]

-- safehouse expanded requirements
require "00_Core/SE_Core"
require "03_Scheduler/SE_AdvancedScheduler"

require "ISUI/ISLabel"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISScrollingListBox"

SafehouseExpanded.SchedulerUI = SafehouseExpanded.SchedulerUI or {}

local ui = SafehouseExpanded.SchedulerUI
local scheduler = SafehouseExpanded.Scheduler

-- jobId : color
local JOB_COLORS = {
    SLEEP = {r=0.318, g=0.251, b=0.471, a=0.9},
    IDLE = {r=0.616, g=0.514, b=0.769, a=0.9},

    GUARD = {r=0.529, g=0.243, b=0.314, a=0.9},
    COOK = {r=0.882, g=0.541, b=0.259, a=0.9},
    LUMBERJACK = {r=0.396, g=0.298, b=0.247, a=0.9},
    FARMER = {r=0.329, g=0.525, b=0.353, a=0.9},
    HAULER = {r=0.259, g=0.490, b=0.659, a=0.9},

    DEFAULT = {r=0.384, g=0.412, b=0.443, a=0.9}
}

-- =================
-- CREATING WINDOW |
-- =================

ui.Window = ISCollapsableWindow:derive("AdvancedSchedulerWindow")
function ui.Window:new()
    local w, h = 910, 430
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local window = ISCollapsableWindow.new(self, math.max(10,math.floor((sw-w)/2)), math.max(10,math.floor((sh-h)/2)), w, h)
    
    window.resizable = false
    window.title = getText("UI_Scheduler_WindowName")
    window.selectedId = nil
    window.jobId = "IDLE"
    return window
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

    self.jobLabel = ISLabel:new(
    252, top - 20, 20,
    getText("UI_Scheduler_JobToAssign"),
    1, 1, 1, 1,
    UIFont.Small, true
    )
    self.jobLabel:initialise()
    self:addChild(self.jobLabel)

    for _, job in ipairs(scheduler.getJobOptions()) do
        self.jobCombo:addOptionWithData(job.label,job.id)
    end

    self:addChild(self.jobCombo)
    self.jobCombo:setSelectedData("IDLE")

    self.memberLabel = ISLabel:new(
    210, top + 65, 20,
    getText("UI_Scheduler_EditingSchedule", ""),
    1, 1, 1, 1,
    UIFont.Small, true
    )
    self.memberLabel:initialise()
    self:addChild(self.memberLabel)

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

    self.copyButton = ISButton:new(210, top+260, 210, 30, getText("UI_Scheduler_ApplyToAll"), self, ui.Window.onCopyAll)
    self.copyButton:initialise()
    self.copyButton:instantiate()
    self:addChild(self.copyButton)

    self.applyButton = ISButton:new(650,top+260,232,30,getText("UI_Scheduler_ApplyHourNow"), self, ui.Window.onApplyNow)
    self.applyButton:initialise()
    self.applyButton:instantiate()
    self:addChild(self.applyButton)

    self:reloadRoster()
end

-- ===============
-- UPDATING INFO |
-- ===============

-- shorten text to an appropriate width
local function shortenTextToWidth(originalText, width, padding, font)
    local availableWidth = width - padding
    local newText = originalText

    if availableWidth >= getTextManager():MeasureStringX(font, originalText) then
        return originalText
    end

    repeat
        newText = string.sub(newText, 1, -2)
    until availableWidth >= getTextManager():MeasureStringX(font, newText) or #newText == 0

    return newText

end

-- update grid to show current job schedule
function ui.Window:updateGrid()
    local schedule = self.selectedId and scheduler.loadOrDefaultSchedule(self.selectedId) or nil
    local current = getGameTime() and getGameTime():getHour() or -1

    local selectedItem = self.memberList.items[self.memberList.selected]
    local residentName = selectedItem and selectedItem.item and selectedItem.item.name or ""

    self.memberLabel:setName(getText("UI_Scheduler_EditingSchedule", residentName))

    for hour = 0,23 do
        local button = self.hourButtons[hour+1]
        if button then
            local task = schedule and schedule[hour+1] or "-"
            local prefix = current == hour and ">" or ""

            local taskText = shortenTextToWidth(tostring(task), button:getWidth(), 6, UIFont.Small)

            button:setTitle(prefix .. string.format("%02d", hour) .. "\n" .. taskText)
            button:setEnable(schedule ~= nil)

            local color
            if JOB_COLORS[task] then
                color = JOB_COLORS[task]
            else
                color = JOB_COLORS.DEFAULT
            end

            button.backgroundColor = {
                r = color.r,
                g = color.g,
                b = color.b,
                a = color.a
            }
        end
    end
end


function ui.Window:reloadRoster()
    local entries = scheduler.getResidents(true)
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

-- ===================
-- UI BUTTON EFFECTS |
-- ===================

function ui.Window:onMemberSelected()
    local item = self.memberList.items[self.memberList.selected]
    if item and item.item then self.selectedId = item.item.id end
    self:updateGrid()
end

function ui.Window:onJobSelected(combo)
    self.jobId = tostring(combo:getSelectedData() or "IDLE")
end

-- change hour to currently selected jobID
function ui.Window:onHourClicked(btn)
    if not self.selectedId then return end
    local schedule = scheduler.loadOrDefaultSchedule(self.selectedId)

    schedule[btn.hour+1] = self.jobId
    self:updateGrid()

    scheduler.tick(true)
end

-- copy schedule to all other survivors
function ui.Window:onCopyAll()
    if not self.selectedId then return end
    local src = scheduler.loadOrDefaultSchedule(self.selectedId)
    for _, member in ipairs(scheduler.getResidents(true)) do
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

-- ==================
-- WINDOW LIFECYCLE |
-- ==================

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

SafehouseExpanded.log("Loading SchedulerUI...")