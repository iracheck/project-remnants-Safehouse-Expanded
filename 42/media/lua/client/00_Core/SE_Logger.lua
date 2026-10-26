--[[
    Safehouse Expanded
    Logger

    System for creating a coherent and consistent logging structure.
]]

require "00_Core/SE_Core"

function SafehouseExpanded.log(message)
    print("[SafehouseExpanded] " .. tostring(message))
end

function SafehouseExpanded.warn(message)
    print("[WARNING] [SafehouseExpanded] " .. tostring(message))
end