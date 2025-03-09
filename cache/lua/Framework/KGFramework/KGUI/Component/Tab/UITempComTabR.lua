local UITabListItem = kg_require("Framework.KGFramework.KGUI.Component.Tab.UITabListItem")
---@class UITempComTabR : UIListItem
---@field view ComTabRBlueprint
local UITempComTabR = DefineClass("UITempComTabR", UITabListItem)

function UITempComTabR:InitWidget()
    self.text_Name = self.view.Text_tab_lua
end

---更新选择的业务表现
---@field selected bool
function UITempComTabR:UpdateSelectionState(selected)
    self.userWidget:StopAllAnimations()
    if selected then
        self:PlayAnimation(self.view.Ani_On)
    else
        self:PlayAnimation(self.view.Ani_Off)
    end
end

return UITempComTabR
