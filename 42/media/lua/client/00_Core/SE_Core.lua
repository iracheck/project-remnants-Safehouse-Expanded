--[[
    Safehouse Expanded
    Core

    This is the core module which handles unified behavior between the different modules for Safehouse Expanded.
]]

SafehouseExpanded = SafehouseExpanded or {}

local core = SafehouseExpanded

function core.isEnabled(moduleName)
    local settings = SandboxVars and SandboxVars.SafehouseExpanded

    if not settings then return true end

    return settings[moduleName] ~= false
end

function core.isSchedulerEnabled()
    return core.isEnabled("EnableScheduler")
end

print("[Safehouse Expanded] Loading Core Module...")