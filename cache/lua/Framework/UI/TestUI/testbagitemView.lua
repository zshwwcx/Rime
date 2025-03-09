---@class BagItemView : BagItem_C
---@field public WidgetRoot BagItem_C
---@field public bg UImage
---@field public selected UImage
---@field public icon UImage
---@field public num UTextBlock
---@field public Big_Button_ClickArea UButton
---@field public RequestBtn UButton
---@class testbagitemView : BagItemView
local TestBagItemView = DefineClass("TestBagItemView", UIView)

function TestBagItemView:OnCreate()
    local controller = self.controller
    controller:SetAutoBind(false)
    controller:AddUIListener(EUIEventTypes.CLICK, self.RequestBtn, "OnClick_RequestBtn")
    controller:AddUIListener(EUIEventTypes.CLICK, self.Big_Button_ClickArea, "OnClick_Big_Button_ClickArea")
end

function TestBagItemView:OnDestroy()
end

return TestBagItemView
