local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class UI_DiyText : UIComponent
---@field view UI_DiyTextBlueprint
local UI_DiyText = DefineClass("UI_DiyText", UIComponent)

---组件刷新统一入口
function UI_DiyText:Refresh(text)
    self.userWidget:SetText(text)
end

return UI_DiyText
