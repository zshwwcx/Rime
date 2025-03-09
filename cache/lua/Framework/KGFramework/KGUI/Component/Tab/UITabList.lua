local UIListView = kg_require("Framework.KGFramework.KGUI.Component.UIListView.UIListView")
---@class UITabList : UIListView
---@field view UITabListBlueprint
local UITabList = DefineClass("UITabList", UIListView)

---获取tab数据原型
---@param name string
---@param iconPath string
---@return UITabData
function UITabList.NewTabData(name, iconPath)
    local data = {name = name, iconPath = iconPath}
    return data
end

function UITabList:ReDefineWidget()
    self.listView = self.view.KGListView
end

---@param list UITabData[]
function UITabList:Refresh(list)
    UIListView.Refresh(self, list)
end

return UITabList
