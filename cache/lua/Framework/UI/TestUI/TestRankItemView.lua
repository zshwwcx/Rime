---@class TestRankItemView : TestRankItem_C
---@field public WidgetRoot TestRankItem_C
---@field public icon C7Image
---@field public num TextBlock
---@field public Btn_ClickArea Button
---@field public GoBtn Button

---@class TestRankItemView : TestRankItemView
---@field public controller TestRankItem
local TestRankItemView = DefineClass("TestRankItemView", UIView)

function TestRankItemView:OnCreate()
    local controller = self.controller
    controller:SetAutoBind(false)
    controller:AddUIListener(EUIEventTypes.CLICK, self.Btn_ClickArea, "OnClick_Btn_ClickArea")
    controller:AddUIListener(EUIEventTypes.CLICK, self.GoBtn, "OnClick_GoBtn")

end

function TestRankItemView:OnDestroy()
    -- local controller = self.controller
---DeletePlaceHolder
end

return TestRankItemView
