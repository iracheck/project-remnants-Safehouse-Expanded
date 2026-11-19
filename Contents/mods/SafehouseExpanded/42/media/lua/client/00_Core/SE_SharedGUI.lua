--[[
    Safehouse Expanded
    Shared GUI Elements

    Shared functions for generating UI elements that are shared between GUIs.
]]


function SafehouseExpanded.getBranding(self, width, height)
    local branding = "Safehouse Expanded"
    local brandWidth = getTextManager():MeasureStringX(UIFont.Small, branding)

    self.brandLabel = ISLabel:new(
        self.width - brandWidth - 14,
        self.height - 26,
        18,
        branding,
        0.55, 0.55, 0.55, 1,
        UIFont.Small,
        true
    )
    self.brandLabel:initialise()
    self:addChild(self.brandLabel)
end