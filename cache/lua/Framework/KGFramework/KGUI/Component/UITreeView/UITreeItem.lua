
local UIListItem = kg_require("Framework.KGFramework.KGUI.Component.UIListView.UIListItem")

---@class UITreeItem : UIListItem
local UITreeItem = DefineClass("UITreeItem", UIListItem)

function UITreeItem:HasChild()
    if not self.data.children then
        return false
    end
    return #self.data.children > 0
end

---@public
---设置序号
---@param pathKey number lua下的路径key
---@param path array C++路径
function UITreeItem:SetIndex(pathKey, path)
    self.index = pathKey
    self.path = path
end

---@public
---设置数据
---@param index int 序号
function UITreeItem:RefreshInternal(data, otherInfo)
    self.data = data or {}
    self.otherInfo = otherInfo or self.otherInfo
    self:OnRefresh(data, otherInfo)
    if self:HasChild() then
        self:UpdateExpansionState(self:IsExpansion())
    else
        self:UpdateSelectionState(self:IsSelected())
    end
end

---@public
---获取节点在当前层级的下标
---@return number
function UITreeItem:GetShortIndex()
    return self.parentComponent:PackPathToShortIndex(self.path)
end

---@public
---更新展开的业务表现
---@param expanded bool
function UITreeItem:UpdateExpansionState(expanded)
end

function UITreeItem:OnClickBtnInternal()
    if self:HasChild() then
        self.parentComponent:processListExpansionInternal(self.index, self.path)
    else
        self.parentComponent:processListSelectInternal(self.index, self.path)
    end
end

--是否被选中
function UITreeItem:IsExpansion()
    return self.parentComponent:IsItemExpandedByIndex(self.index)
end
return UITreeItem