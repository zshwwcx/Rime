local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class UIProgressBar : NewUIComponent
---@field view UIProgressBarBlueprint
local UIProgressBar = DefineClass("UIProgressBar", UIComponent)

UIProgressBar.eventBindMap = {
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function UIProgressBar:OnCreate()
    self:InitWidget()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

---初始化数据
function UIProgressBar:InitUIData()
    self.oriPos = self.vxBar.Slot:GetPosition()      -- 光标初始位置
end

function UIProgressBar:InitWidget()
    self.bar_Perspective = self.view.Bar_Perspective
    self.bar_Backgroud = self.view.Bar_Backgroud
    self.vxBar = self.view.VX_Bar
end

---组件刷新统一入口
function UIProgressBar:Refresh(progress)
    self:SetProgressBarValue(progress)
end

---@public
---@param progress number 进度条的百分比 [0,1]
function UIProgressBar:SetProgressBarValue(progress)
    local legalValue = math.min(1, math.max(0, progress))
    self.progressBarValue = legalValue
    self.bar_Perspective:SetPercent(legalValue)
    local NewAnchors = import("Anchors")()
    NewAnchors.Minimum = FVector2D(legalValue, 0.5)
    NewAnchors.Maximum = FVector2D(legalValue, 0.5)
    self.vxBar.Slot:SetAnchors(NewAnchors)
    self.vxBar.Slot:SetPosition(self.oriPos)
    self:SetWidgetVisible(self.vxBar, legalValue == 0, true, true)
end
return UIProgressBar
