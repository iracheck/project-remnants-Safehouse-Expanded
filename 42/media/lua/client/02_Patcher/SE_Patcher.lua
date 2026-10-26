--[[
    Safehouse Expanded
    Patcher

    Patches the existing Project Remnants files to make this addon work as expected. Everything that overrides Project Remnants behavior/ui/code is located here.
]]

-- safehouse expanded dependencies
require "00_Core/SE_Core"
require "00_Core/SE_Logger"
require "03_Scheduler/SE_AdvancedScheduler"
require "03_Scheduler/SE_SchedulerUI"

-- other
require "NPCFW_FactionManagementUI"
require "ISUI/ISButton"

SafehouseExpanded.Patcher = SafehouseExpanded.Patcher or {}

local core = SafehouseExpanded
local patcher = SafehouseExpanded.Patcher

local scheduler = SafehouseExpanded.Scheduler
local schedulerUI = SafehouseExpanded.SchedulerUI

function patcher.installPatches()
    if core.isSchedulerEnabled() then
        patcher.installSchedulerPatch()

        if not patcher.schedulerPatched then
            SafehouseExpanded.warn("Failed to install scheduler patch.")
        end

        scheduler.enable()
    end
end

function patcher.installSchedulerPatch()
    SafehouseExpanded.log("Loading Advanced Scheduler module.")
    if patcher.schedulerPatched or not NPCFW_FactionManagementUI then return end

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
                schedulerUI.open(npcId)
            end
            )

            button:initialise()
            button:instantiate()

            self.memberList:addChild(button)
            button:setScrollWithParent(true)

            -- cleanup
            self.memberJobCombos = self.memberJobCombos or {}
            self.memberJobCombos[index] = button

            -- move to the next row
            rowTop = rowTop + rowHeight
        end
    end

    patcher.schedulerPatched = true
    SafehouseExpanded.log("Sucessfully patched Remnants with Advanced Scheduler logic.")
end

patcher.installPatches()    

SafehouseExpanded.log("Loading Patcher...")