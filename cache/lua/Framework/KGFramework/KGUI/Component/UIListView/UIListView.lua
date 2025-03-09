local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
local LuaDelegate = kg_require("Framework.KGFramework.KGCore.Delegates.LuaDelegate")
local ESelectionMode = import("ESelectionMode")

---@class UIListView : NewUIComponent
---@field widget UKGListView
local UIListView = DefineClass("UIListView", UIComponent)

---获取列表原始数据
---@return table
function UIListView:GetData()
    return self._datas 
end

--region Public
---@public
---通过序号获取Item的UI组件
---@param index int 序号
---@return UIListItem
function UIListView:GetItemByIndex(index)
    local item = self._itemShowIndexMap[index]
    return item
end

---@public
---通过key获取Item的UI组件，遍历当前存在的所有UI组件，返回第一个数据的key字段值为value的UI组件。
---
---例如：列表数据为 {{id=1001,name="apple"},{id=1002,name="banana"},{id=1005,name="orange"}}。那么key可以为"id"，此时value可以是1001、1002、1005。
---@param key string 字段名
---@param value any 值
---@return UIListItem
function UIListView:GetItemByKey(key, value)
    for k, v in pairs(self._itemShowIndexMap) do
        if v.data[key] == value then
            return v
        end
    end
    return nil
end

---@public
---使用新的数据刷新列表
---@param _datas table 列表原始数据
---@param index? int 从列表第几个下标开始刷新（默认值：1。注意Lua数组起始位是1）
---@param otherInfo? table | nil 列表里每个Item的补充数据，解决列表数据不全的问题（默认值：nil）
function UIListView:Refresh(datas, index, otherInfo)
    table.clear(self._curSelectIndexs)
    index = index or 1
    self._datas = datas
    local count = self._datas and #self._datas or 0
    self._otherInfo = otherInfo
    self.listView:BP_SetListItems(count)
    self.listView:BP_ScrollItemIntoView(index - 1, 0)
end

---@public
---使用旧的数据刷新列表
function UIListView:RefreshItems()
    local count = self._datas and #self._datas or 0
    self.listView:BP_SetListItems(count)
end

---@public
---新增数据数量（只能是在数组后面追加）
function UIListView:NotifyAddData(count)
    for index = 1, count do
        self.listView:AddItem()
    end
end

---@public
---@param index int 序号（lua数组起始为1）
---插入数据（每次一个数据）
function UIListView:NotifyInsertData(index)
    self.listView:InsertItem(index-1)
end

---@public
---@param index int 序号（lua数组起始为1）
---删除数据（每次一个数据）
function UIListView:NotifyRemoveData(index)
    self.listView:RemoveItem(index-1)
end

---@public
---通过序号触发Item的刷新
---@param index int 序号
function UIListView:RefreshItemByIndex(index)
    local item = self:GetItemByIndex(index)
    local data = self:GetChildData(index)
    if item and data then
        item:RefreshInternal(data, self._otherInfo)
    end
end

---@public
---通过Item的字段名和值匹配触发Item的刷新（匹配方式参考`GetItemByKey`的描述）
---@param key string 字段名
---@param value any 值
---@param data any 数据
function UIListView:RefreshItemByKey(key, value, data)
    local item = self:GetItemByKey(key, value)
    if item and data then
        item:RefreshInternal(data, self._otherInfo)
    end
end

---@public
---获取选中的序号
---@return int
function UIListView:GetChildData(index)
    return self._datas[index]
end

---@public
---清空列表数据
function UIListView:Clear()
    self._datas = nil
    self._otherInfo = nil
    self.listView:BP_SetListItems(0)
end

---@public
---跳转到指定序号
---@param index int 指定序号（注意Lua数组起始位是1）
---@param alignment float 对齐方式，表示跳转后序号为index的Item应该处于列表视口的哪个位置，例如垂直布局的列表0表示“滚动到顶端”，0.5表示”滚动到中间“，1.0表示”滚动到底部“（默认值：0，范围：0~1.0）
function UIListView:ScrollToItemByIndex(index, alignment)
    index = index or 1
    alignment = alignment or 0
    self.listView:BP_ScrollItemIntoView(index - 1, alignment)
end

---@public
---通过序号触发Item选中
---@param index int 指定序号
---@param selected boolean 是否选择
function UIListView:SetSelectedItemByIndex(index, selected)
    self.listView:BP_SetItemSelection(index - 1, selected)
end

---@public
---设置选择模式
---@param mode ESelectionMode
function UIListView:SetSelectionMode(mode)
    self.listView:SetSelectionMode(mode)
end

---@public
---获取当前选择模式
function UIListView:GetSelectionMode()
    return self.listView:GetSelectionMode()
end

---@public
---清空全部选中
function UIListView:ClearSelection()
    table.clear(self._curSelectIndexs)
    self.listView:BP_ClearSelection()
end

---@public
---获取单选的当前序号
---@return int
function UIListView:GetSelectedItemIndex()
    local _, value = next(self._curSelectIndexs)
    return value
end

---@public
---获取选中的序号集合
---@return table<int, bool> 其中Key为序号，Value恒定为true
function UIListView:GetSelectedItemIndexes()
    return self._curSelectIndexs
end

---@public
---判断指定序号的Item是否被选中
---@param index int 序号
---@return bool
function UIListView:IsSelectedByIndex(index)
    return table.contains(self._curSelectIndexs, index)
end

function UIListView:NodeIsLastChild(index)
    return index == #self._datas
end
--endregion Public

--region Private


---@private
function UIListView:OnCreate()
    self:ReDefineWidget()
    self:InitUIData()
    self:InitUIEvent()
    self:InitUIView()
end

function UIListView:ReDefineWidget()
    self.listView = self.widget
end

---@private
function UIListView:InitUIData()
    ---@private
    ---@type table<int, UIListItem>
    self._itemShowIndexMap = {}

    ---@private
    ---@type table<UWidget, UIListItem>
    self._itemShowWidgetMap = {}

    ---@private
    ---@type table<UWidget, UIListItem>
    self.itemHideList = {}

    ---@private
    ---@type any
    self._datas = nil

    ---@private
    ---@type table<int>
    self._curSelectIndexs = {}
    self:InitExtraEvent()
end

function UIListView:InitExtraEvent()
    ---@public
    ---监听Item选中状态变化回调
    ---@type LuaMulticastDelegate<fun(index:number, selected:bool)>
    self.onItemSelectionChanged = LuaMulticastDelegate.new()

    ---@public
    ---监听Item选中
    ---@type LuaMulticastDelegate<fun(index:number, data:table)>
    self.onItemSelected = LuaMulticastDelegate.new()

    ---@public
    ---监听Item点击事件
    ---@type LuaMulticastDelegate<fun(index:number, data:table)>
    self.onItemClicked = LuaMulticastDelegate.new()

    ---@public
    ---请求多样式UserWidget Lua类的回调
    ---@type LuaDelegate<fun(index:number):UIComponent>
    self.onGetEntryLuaClass = LuaDelegate.new()
    ---@public
    ---请求多样式UserWidget序号的回调
    ---@type LuaDelegate<fun(index:number):number>
    self.onGetEntryClassIndexForItem = self.listView.OnGetEntryClassIndexForItem
end

---@private
function UIListView:dtor()
    self.onItemSelectionChanged = nil
    self.onGetEntryClassIndexForItem = nil
    UIComponent.dtor(self)
end

---@private
function UIListView:InitUIEvent()
    self:AddUIEvent(self.listView.EntryWidgetPool.OnGetEntryWidgetForPool, "onGetEntryWidgetForPool")
    self:AddUIEvent(self.listView.BP_OnItemSelectionChanged, "onItemSelectionChangedInternal")
    self:AddUIEvent(self.listView.BP_OnEntryInitialized, "onEntryInitialized")
    self:AddUIEvent(self.listView.BP_OnEntryReleased, "onEntryReleased")
end

---@private
function UIListView:onItemSelectionChangedInternal(index, bSelect)
    index = index + 1
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
        self.onItemSelected:Broadcast(index, self._datas[index])
    end
end

---@private
function UIListView:onEntryInitialized(index, userWidget)
    index = index + 1
    local item = self:addItem(index, userWidget)
    if item and self._datas[index] then
        item:SetIndex(index)
        item:RefreshInternal(self._datas[index], self._otherInfo)
    end
end

---@private
function UIListView:onEntryReleased(userWidget)
    self:releasedItem(userWidget)
end

function UIListView:onGetEntryWidgetForPool(widgetType)
    local component = self:loadFormCache(widgetType)
    if component then
        return component.userWidget
    end
    return nil
end

function UIListView:loadFormCache(widgetType)
    local component = Game.NewUIManager:PopComponentByWidgetType(widgetType)
    if component then
        self:initComponent(component)
        component.parentComponent = self
        self.itemHideList[component.userWidget] = component
    end
    return component
end

---@private
function UIListView:addItem(index, userWidget)
    local class
    if self.onGetEntryLuaClass:IsBind() then
        class = self.onGetEntryLuaClass:Execute()
    end
    local item = self:getItemFromPool(userWidget, class)
    self._itemShowIndexMap[index] = item
    self._itemShowWidgetMap[userWidget] = item
    return item
end

---@private
function UIListView:releasedItem(userWidget)
    if self._itemShowWidgetMap[userWidget] then
        local item = self._itemShowWidgetMap[userWidget]
        item:OnReleased()
        self.itemHideList[userWidget] = item
        self._itemShowWidgetMap[userWidget] = nil
        if self._itemShowIndexMap[item.index] and self._itemShowIndexMap[item.index].userWidget == userWidget then 
            self._itemShowIndexMap[item.index] = nil
        end
    end
end

---@private
function UIListView:getItemFromPool(userWidget, class)
    local item = self.itemHideList[userWidget]
    if item then
        self.itemHideList[userWidget] = nil
    else
        item = self:CreateComponent(userWidget, class)
        if item then
            item:InitDefaultClickEvent()
            item:UpdateObjectNum(userWidget.UObjectNum)
        end
    end
    return item
end

function UIListView:processListSelectInternal(index)
    local selected = self:IsSelectedByIndex(index)
    local curMode = self:GetSelectionMode()
    if curMode == ESelectionMode.Single then
        if not selected then
            self:SetSelectedItemByIndex(index, not selected)
        end
    elseif curMode == ESelectionMode.SingleToggle or curMode == ESelectionMode.Multi then
        self:SetSelectedItemByIndex(index, not selected)
    end
end

---@private
function UIListView:processListClickInternal(index, data)
    self.onItemClicked:Broadcast(index, data)
end
return UIListView
--endregion
