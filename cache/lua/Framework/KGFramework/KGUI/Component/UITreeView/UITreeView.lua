local UIListView = kg_require("Framework.KGFramework.KGUI.Component.UIListView.UIListView")
local LuaDelegate = kg_require("Framework.KGFramework.KGCore.Delegates.LuaDelegate")
local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
local ESelectionMode = import("ESelectionMode")
local EPropertyClass = import("EPropertyClass")
local UITreeViewData = kg_require("Framework.KGFramework.KGUI.Component.UITreeView.UITreeViewData")

---@class UITreeView : NewUIComponent
---@field widget UKGTreeView
local UITreeView = DefineClass("UITreeView", UIListView)
UITreeView.CHILD_MAX_NUM = 1000
--region Public 外部功能接口

---获取列表数据原型
---@return UITreeViewData
function UITreeView.NewTreeViewData()
    local data = UITreeViewData.new()
    return data
end

---@public
---刷新树状列表
---@param data UITreeViewData
---@param otherInfo? table
function UITreeView:Refresh(data, otherInfo)
    table.clear(self._curSelectIndexs)
    table.clear(self._curExpansionIndexs)
    self._datas  = data
    local count = data and #data.children or 0
    self._otherInfo = otherInfo
    self.treeView:BP_SetListItems(count)
end

---@public
---新增数据数量 待实现
function UITreeView:NotifyAddData()
  
end

---@public
---插入数据 待实现
function UITreeView:NotifyInsertData()

end

---@public
---删除数据 待实现
function UITreeView:NotifyRemoveData()

end

---@public
---@param index number 节点唯一的key
function UITreeView:RefreshItemByIndex(index)
    local item = self:GetItemByIndex(index)
    local data = self:getDataByIndex(index)
    if item then
        item:SetData(data, self._otherInfo)
    end
end

---@public
---@param data table 数据
---@param ... number 节点路径
function UITreeView:RefreshItemByPath(...)
    local index = self:PackPathToIndex(...)
    self:RefreshItemByIndex(index)
end

---@public
---@param index number  节点唯一的key
---@return UITreeItem
function UITreeView:GetItemByIndex(index)
    local item = self._itemShowIndexMap[index]
    return item
end

---@public
---@param ... number 节点路径
---@return UITreeItem
function UITreeView:GetItemByPath(...)
    local index = self:PackPathToIndex(...)
    return self:GetItemByIndex(index)
end

---@public
---获取当前选择模式
function UITreeView:GetSelectionMode()
    return self.treeView:GetSelectionMode()
end

---@public
---获取Item组件展开或折叠状态
---@param index number 节点唯一的key
---@param item UITreeItem
---@return bool
function UITreeView:IsItemExpandedByIndex(index)
    return table.contains(self._curExpansionIndexs, index)
end

---@public
---获取Item组件展开或折叠状态
---@param ... number 节点路径
---@return bool
function UITreeView:IsItemExpandedByPath(...)
    local index = self:PackPathToIndex(...)
    return self:IsItemExpandedByIndex(index)
end

---@public
---跳转到指定序号
---@param ... number 节点路径
---@param alignment number 对齐方式，表示跳转后序号为index的Item应该处于列表视口的哪个位置，例如垂直布局的列表0表示“滚动到顶端”，0.5表示”滚动到中间“，1.0表示”滚动到底部“（默认值：0，范围：0~1.0）
function UITreeView:ScrollToItemByPath(alignment, ...)
    local path = self:PackPathToArray(...)
    self.treeView:BP_ScrollTreeItemIntoView(path, alignment)
end

---@public
---通过序号触发Item选中
---@param ... number 下标路径 序号
function UITreeView:SetSelectedItemByPath(selected, ...)
    local path = self:PackPathToArray(...)
    self.treeView:BP_SetTreeItemSelection(path, selected)
end

---@public
---通过序号触发Item折叠
---@param ... number 下标路径 序号
function UITreeView:SetExpansionItemByPath(expansion, ...)
    local path = self:PackPathToArray(...)
    self.treeView:SetItemExpansion(path, expansion)
end

---@public
---清空全部选中
function UITreeView:ClearSelection()
    table.clear(self._curSelectIndexs)
    self.treeView:BP_ClearSelection()
end

---@public
---打开全部
function UITreeView:ExpandAll()
    return self.treeView:ExpandAll()
end

---@public
---折叠全部
function UITreeView:CollapseAll()
    table.clear(self._curExpansionIndexs)
    return self.treeView:CollapseAll()
end

function UITreeView:GetTreeView()
    return self.treeView
end

--endregion

--region Private 内部实现

---@private
function UITreeView:OnCreate()
    self:ReDefineWidget()
    self:InitUIData()
    self:InitUIEvent()
end

function UITreeView:dtor()
    self.onGetEntryClassIndexForItem = nil
    UIComponent.dtor(self)
end

function UITreeView:ReDefineWidget()
    ---@type UKGTreeView
    self.treeView = self.widget
end

---@private
function UITreeView:InitUIData()
    UIListView.InitUIData(self)
    self._curExpansionIndexs = {}   
end

function UITreeView:InitExtraEvent()
 ---@public
    ---监听Item选中状态变化回调
    ---@type LuaMulticastDelegate<fun(index:number, data:UITreeViewChildData,  bSelect:bool)>
    self.onItemSelectionChanged = LuaMulticastDelegate.new()

    ---@public
    ---监听节点选中事件
    ---@type LuaMulticastDelegate<fun(index:number, data:UITreeViewChildData, selected:bool)>
    self.onItemSelected = LuaMulticastDelegate.new()

    ---@public
    ---监听节点折叠事件
    ---@type LuaMulticastDelegate<fun(index:number, data:UITreeViewChildData, expanded:bool)>
    self.onItemExpansionChanged = LuaMulticastDelegate.new()

        ---@public
    ---请求多样式UserWidget序号的回调
    ---@type LuaDelegate<fun(path:array):number>
    self.onGetEntryClassIndexForItem = self.treeView.OnGetTreeEntryClassIndexForItem

    ---@public
    ---请求多样式UserWidget Lua类的回调
    ---@type LuaDelegate<fun(index:number):UIComponent>
    self.onGetEntryLuaClass = LuaDelegate.new()
end

function UITreeView:InitUIEvent()
    self:AddUIEvent(self.treeView.BP_OnGetItemChildren, "onGetItemChildren")
    self:AddUIEvent(self.treeView.BP_OnTreeEntryInitialized, "onEntryInitialized")
    self:AddUIEvent(self.treeView.BP_OnEntryReleased, "onEntryReleased")
    self:AddUIEvent(self.treeView.BP_OnItemExpansionChanged, "onItemExpansionChangedInternal")
    self:AddUIEvent(self.treeView.BP_OnTreeItemSelectionChanged, "onItemSelectionChangedInternal")
    self:AddUIEvent(self.treeView.OnGetTreeEntryClassIndexForItem, "onGetTreeEntryClassIndexForItem")
end

---@private
---@param path Array
---@return number
function UITreeView:onGetItemChildren(path)
    local data = self:getDataByPath(path)
    if data == nil then
        return 0
    end
    if data.children == nil then
        return 0
    end
    return #data.children
end

---@private
---@param path Array
---@param userWidget UUserWidget
function UITreeView:onEntryInitialized(path, userWidget)
    local index = self:PackArrayToIndex(path)
    local data = self:getDataByPath(path)
    local item = self:addItem(index, userWidget)
    if item and data then
        item:SetIndex(index, path)
        item:RefreshInternal(data, self._otherInfo)
    end
end

---@private
---@param path Array
---@param expanded bool
function UITreeView:onItemExpansionChangedInternal(path, expanded)
    local index = self:PackArrayToIndex(path)
    local item = self:GetItemByIndex(index)
    if item ~= nil then
        item:UpdateExpansionState(expanded)
    end
    self:updateExpansionIndexs(expanded, index)
    self.onItemExpansionChanged:Broadcast(self:PackArrayToIndex(path), self:getDataByPath(path), expanded)
end

function UITreeView:updateExpansionIndexs(expanded, index)
    if expanded then
        self._curExpansionIndexs[#self._curExpansionIndexs + 1] = index
    else
        table.removeItem(self._curExpansionIndexs, index)
    end
end

---@private
---@param path Array
---@param expanded bool
function UITreeView:onItemSelectionChangedInternal(path, bSelect)
    local index = self:PackArrayToIndex(path)
    local item = self:GetItemByIndex(index)
    if item then
        item:UpdateSelectionState(bSelect)
    end
    if bSelect then
        self._curSelectIndexs[#self._curSelectIndexs + 1] = index
    else
        table.removeItem(self._curSelectIndexs, index)
    end
    self.onItemSelectionChanged:Broadcast(index, bSelect)
    if bSelect then
        self.onItemSelected:Broadcast(index, self:getDataByPath(path), bSelect)
    end
end

function UITreeView:onGetTreeEntryClassIndexForItem(path)
    return path:Num() - 1
end

---@public
---通过C++数组路径获取某个节点数据
---@param index number
---@return table
function UITreeView:getDataByPath(path)
    local current = self._datas 
    for i = 0, path:Num() - 1 do
        current = current.children[path:Get(i) + 1]
        if current == nil then
            return nil
        end
    end
    return current
end

---@public
---@param index number
---@return table
function UITreeView:getDataByIndex(index)
    local current = self._datas
    local cur = index%UITreeView.CHILD_MAX_NUM
    current = current.children[cur]
    index = index/UITreeView.CHILD_MAX_NUM

    while index > 1 do
        cur = index%UITreeView.CHILD_MAX_NUM
        current = current.children[cur]
        index = index/UITreeView.CHILD_MAX_NUM
    end  
    return current
end

function UITreeView:NodeHasChild(index)
    local data = self:getDataByIndex(index)
    if data and data.children and #data.children>0 then
        return true
    end 
    return false
end

function UITreeView:NodeIsLastChild(index)
    local current = self._datas
    local cur = index%UITreeView.CHILD_MAX_NUM
    current = current.children[cur]
    index = index/UITreeView.CHILD_MAX_NUM
    local isLast = false
    while index > 1 do
        cur = math.floor(index%UITreeView.CHILD_MAX_NUM)
        isLast = cur == #current.children
        current = current.children[cur]
        index = index/UITreeView.CHILD_MAX_NUM
    end  
    return isLast
end

---@param path Array C++TreeList 返回的节点路径
---@return number
function UITreeView:PackArrayToIndex(path)
    local index = 0
    for i = 1, path:Num() do
        local num = path:Get(i-1) + 1
        index = UITreeView.CHILD_MAX_NUM ^(i-1) * num + index
    end
    return index
end

---@param firstIndex number 一级列表下标
---@param secondIndex number 二级列表下标
---@param threeIndex number 三级列表下标
---@return number
function UITreeView:PackPathToIndex(firstIndex, secondIndex, threeIndex)
    secondIndex = secondIndex or 0
    threeIndex = threeIndex or 0
    local index = firstIndex + secondIndex*UITreeView.CHILD_MAX_NUM + threeIndex*UITreeView.CHILD_MAX_NUM^2
    return index
end

---@param firstIndex number 一级列表下标
---@param secondIndex number 二级列表下标
---@param threeIndex number 三级列表下标
---@return number
function UITreeView:PackPathToArray(firstIndex, secondIndex, threeIndex)
    local paths = slua.Array(EPropertyClass.Int)
    if firstIndex then
        paths:Add(firstIndex-1)
    end
    if firstIndex and secondIndex then
        paths:Add(secondIndex-1)
    end
    if firstIndex and secondIndex and threeIndex then
        paths:Add(threeIndex-1)
    end
    return paths
end

---@param index number
---@return array
function UITreeView:PackIndexToArray(index)
    local paths = slua.Array(EPropertyClass.Int)
    local cur = index%UITreeView.CHILD_MAX_NUM
    paths:Add(cur-1)
    index = index/UITreeView.CHILD_MAX_NUM

    while index > 1 do
        cur = index%UITreeView.CHILD_MAX_NUM
        paths:Add(cur-1)
        index = index/UITreeView.CHILD_MAX_NUM
    end  
    return paths
end

---@public
---获取节点在当前层级的下标
---@param path Array
---@return number
function UITreeView:PackPathToShortIndex(path)
    return path:Get(path:Num()-1) + 1
end

function UITreeView:processListExpansionInternal(index, path)
    local expansion = not self:IsItemExpandedByIndex(index)
    self.treeView:SetItemExpansion(path, expansion)
end

function UITreeView:processListSelectInternal(index, path)
    local selected = self:IsSelectedByIndex(index)
    local curMode = self:GetSelectionMode()
    if curMode == ESelectionMode.Single then
        if not selected then
            self.treeView:BP_SetTreeItemSelection(path, not selected)
        end
    elseif curMode == ESelectionMode.SingleToggle or curMode == ESelectionMode.Multi then
        self.treeView:BP_SetTreeItemSelection(path, not selected)
    end
end
--endregion
return UITreeView