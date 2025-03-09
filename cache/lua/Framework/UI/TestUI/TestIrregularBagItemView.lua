---@class TestIrregularBagItemView : TestIrregularBagItem_C
---@field public WidgetRoot TestIrregularBagItem_C
---@field public bg Image
---@field public selected Image
---@field public icon Image
---@field public num TextBlock
---@field public Btn_ClickArea Button
---@field public RequestBtn Button
---@field public anim1 WidgetAnimation
---@field public anim2 WidgetAnimation
---@field public anim3 WidgetAnimation

---@class TestIrregularBagItemView : TestIrregularBagItemView
---@field public controller TestIrregularBagItem
local TestIrregularBagItemView = DefineClass("TestIrregularBagItemView", UIView)

function TestIrregularBagItemView:OnCreate()
    local controller = self.controller
    controller:SetAutoBind(false)

    controller:AddUIListener(EUIEventTypes.CLICK, self.RequestBtn, "OnClick_RequestBtn")
    controller:AddUIListener(EUIEventTypes.CLICK, self.Btn_ClickArea, "OnClick_Btn_ClickArea")
end

function TestIrregularBagItemView:OnDestroy()
    -- local controller = self.controller
---DeletePlaceHolder
end

return TestIrregularBagItemView
