local UIButton = kg_require("Framework.KGFramework.KGUI.Component.Button.UIButton")
---@class UITempComBtnBackArrow : NewUIComponent
---@field view UITempComBtnBackArrowBlueprint
local UITempComBtnBackArrow = DefineClass("UITempComBtnBackArrow", UIButton)

function UITempComBtnBackArrow:InitWidget()
    self.btn_ClickArea = self.view.Btn_Back_lua
end

return UITempComBtnBackArrow