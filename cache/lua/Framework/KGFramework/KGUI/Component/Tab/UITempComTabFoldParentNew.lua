local UIAccordionListTab = kg_require("Framework.KGFramework.KGUI.Component.Tab.UIAccordionListTab")
---@class UITempComTabFoldParentNew : UIAccordionListTab
---@field view UITempComTabFoldParentNewBlueprint
local UITempComTabFoldParentNew = DefineClass("UITempComTabFoldParentNew", UIAccordionListTab)
function UITempComTabFoldParentNew:InitWidget()
    self.text_Name = self.view.Text_Name_lua
    self.text_ExtraDesc = self.view.Text_Sub_lua
end

---@public
---更新展开的业务表现
---@param expanded bool
function UITempComTabFoldParentNew:UpdateExpansionState(expanded)
    self.userWidget:SetSelected(expanded)
    self.userWidget:SetArrow(true)
end

---更新选择的业务表现
---@field selected bool
function UITempComTabFoldParentNew:UpdateSelectionState(selected)
    self.userWidget:SetSelected(selected)
    self.userWidget:SetArrow(false)
end
return UITempComTabFoldParentNew
