local UITreeView = kg_require("Framework.KGFramework.KGUI.Component.UITreeView.UITreeView")
---@class UIAccordionList : UITreeView
---@field view UIAccordionListBlueprint
local UIAccordionList = DefineClass("UIAccordionList", UITreeView)

---获取tab数据原型
---@param name string
---@param iconPath string
---@return UITabData
function UIAccordionList.NewTabData(name, iconPath)
    local data = {name = name, iconPath = iconPath}
    return data
end

function UIAccordionList:ReDefineWidget()
    self.treeView = self.view.KGTreeView
end

function UIAccordionList:InitUIData()
    UITreeView.InitUIData(self)
    ---一级菜单展开的时候是否自动选择改目录下的第一个二级菜单
    ---@private
    self._autoSelectFirst = false

    ---一级菜单展开是否互斥
    ---@private
    self._exclusive = true
end

---@param autoSelectFirst boolean
function UIAccordionList:SetAutoSelectFirst(autoSelectFirst)
    self._autoSelectFirst = autoSelectFirst
end

---@param exclusive boolean
function UIAccordionList:SetExclusive(exclusive)
    self._exclusive = exclusive
end

---折叠打开是否自动选择第一个子节点
function UIAccordionList:IsAutoSelectFirst()
    return self._autoSelectFirst
end

---一级菜单是否互斥折叠
function UIAccordionList:IsExclusive()
    return self._exclusive
end

---打开一级菜单
---@param pathIndex number 第几个一级菜单
function UIAccordionList:ExpansionMainTab(pathIndex)
    local index = self:PackPathToIndex(pathIndex)
    local path = self:PackIndexToArray(index)
    if self:NodeHasChild(index) then
        self:processListExpansionInternal(index, path)
    else
        self:processListSelectInternal(index, path)
    end
end

---@private
---@param path Array
---@param expanded bool
function UIAccordionList:onItemExpansionChangedInternal(path, expanded)
    local index = self:PackArrayToIndex(path)
    local item = self:GetItemByIndex(index)
    if item ~= nil then
        item:UpdateExpansionState(expanded)
    end
    self:updateExpansionIndexs(expanded, index)
    self.onItemExpansionChanged:Broadcast(self:PackArrayToIndex(path), self:getDataByPath(path), expanded)
end

function UIAccordionList:collapseLastItem()
    local index = self._curExpansionIndexs[1]
    if index then
        self.treeView:SetItemExpansion(self:PackIndexToArray(index), false)
    end
end

function UIAccordionList:processListExpansionInternal(index, path)
    local expansion = not self:IsItemExpandedByIndex(index)
    if self._exclusive and expansion then
        self:collapseLastItem()
    end
    self.treeView:SetItemExpansion(path, expansion)
    local firstIndex = self:PackPathToShortIndex(path)
    local childIndex = self:PackPathToIndex(firstIndex, 1)
    if self._autoSelectFirst and expansion and self:NodeHasChild(index) and not self:IsSelectedByIndex(childIndex) then
        self:SetSelectedItemByPath(true, firstIndex, 1)
    end
end
return UIAccordionList
