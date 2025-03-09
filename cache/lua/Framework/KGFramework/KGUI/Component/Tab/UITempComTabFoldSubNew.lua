local UIAccordionListTab = kg_require("Framework.KGFramework.KGUI.Component.Tab.UIAccordionListTab")
---@class UITempComTabFoldSubNew : UIAccordionListTab
---@field view UITempComTabFoldSubNewBlueprint
local UITempComTabFoldSubNew = DefineClass("UITempComTabFoldSubNew", UIAccordionListTab)
function UITempComTabFoldSubNew:InitWidget()
    self.text_Name = self.view.Text_Name_lua
end

--- UI组件初始化，此处为自动生成
---@param data UITreeViewChildData
function UITempComTabFoldSubNew:OnRefresh(data, otherInfo)
    UIAccordionListTab.OnRefresh(self, data, otherInfo)
    local lineType = self.parentComponent:NodeIsLastChild(self.index) and 2 or 1
    self.userWidget:SetLine(lineType)
end

---更新选择的业务表现
---@field selected bool
function UITempComTabFoldSubNew:UpdateSelectionState(selected)
    self.userWidget:SetSelected(selected)
end
return UITempComTabFoldSubNew