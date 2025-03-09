local UIPanelFrame = kg_require("Framework.KGFramework.KGUI.Component.Panel.UIPanelFrame")
---@class UITempComFrame : NewUIComponent
---@field view ComFrameBlueprint
local UITempComFrame = DefineClass("UITempComFrame", UIPanelFrame)

function UITempComFrame:InitWidget()
    self.titleButton = self.view.WBP_ComBtnBack_lua
    self.moneyRoot = self.view.Money_lua
end

return UITempComFrame
