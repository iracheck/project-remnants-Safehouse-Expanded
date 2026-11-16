--[[
    Safehouse Expanded
    PRQP Integration

    Prevents the scheduler from interrupting NPCs
    currently controlled by PRQP.
]]

require "00_Core/SE_Core"

SafehouseExpanded.PRQP = SafehouseExpanded.PRQP or {}

local prqp_patch = SafehouseExpanded.PRQP

function prqp_patch.isBusy(npcId)
    local prqp = PRQP_VehicleUnload

    if not prqp or not prqp.IsWorker then
        return false
    end

    if not npcfwGetNPC then return false end

    local ok, npc = pcall(npcfwGetNPC, npcId)
    if not ok or not npc then return false end

    local success, busy = pcall(prqp.IsWorker, npc)
    return success and busy == true
end

function prqp_patch.countBusy()
    local count = 0

    for _, npc in ipairs(SafehouseExpanded.Scheduler.getResidents(false)) do
        if prqp_patch.isBusy(npc.id) then
            count = count + 1
        end
    end

    return count
end
