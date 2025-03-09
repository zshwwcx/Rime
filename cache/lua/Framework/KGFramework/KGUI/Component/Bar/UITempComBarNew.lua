local UITitleButton = kg_require("Framework.KGFramework.KGUI.Component.Button.UITitleButton")
---@class UITempComBarNew : NewUIComponent
---@field view UIProgressBarBlueprint
local UITempComBarNew = DefineClass("UITempComBarNew", UITitleButton)

function UITempComBarNew:InitWidget()
    self.bar_Perspective = self.view.PB_HPMain_lua
    self.bar_Backgroud = self.view.PB_HPMainContrast_lua
    self.vxBar = self.view.img_Bar_lua
end

return UITempComBarNew