local ESelectionMode = import("ESelectionMode")

---@alias integer number

---@class IrregularListView : BaseList
---@field protected _s UKGIrregularListView
local IrregularListView = DefineClass("IrregularListView", BaseList)

---@protected
---@param _ ...
---@param itemComponentClass LuaClass Item组件类型
function IrregularListView:OnCreate(itemComponentClass)  -- luacheck: ignore
    self._itemComponentClass = itemComponentClass
    self._listData = nil  ---@type table
    self._itemComponents = {}  ---@type table<integer, ListItemBase>

    --region 子节点选中态管理
    self._selectedIndices = {}
    -- 仅使用Lua层逻辑控制选中态
    self._selectionMode = self:GetViewRoot():GetSelectionMode()
    --self:GetViewRoot():SetSelectionMode(import("ESelectionMode").None)
    --endregion

    --region 各种基础事件注册
    self:GetViewRoot().OnEntryInitialized:Add(function(item, entry)--- ... 这种格式不能接收userdata
        self:OnEntryInitialized(item, entry)
    end)
    self:GetViewRoot().OnEntryReleased:Add(function(item, entry)
        self:OnEntryReleased(item, entry)
    end)
    self:GetViewRoot().OnItemSnapped:Add(function(item)         self:OnItemSnapped(item)
     end)
    --endregion
end

---@protected
---@param item UListObject
---@param entry UUserWidget
function IrregularListView:OnEntryInitialized(item, entry)
    local index = item.Index
    --Log.Debug("[IrregularListView] on entry initialized " .. tostring(index) .. " " .. tostring(entry))
    local itemComponent = self:BindListComponent("KGIrregularListView", entry, self._itemComponentClass or ListItemBase, self.GetCellIndex, self, false, item)
    itemComponent:SetItem(item)
    self:addClickListener(itemComponent)
    --self._itemComponentClass.new(entry, false, self) ---@type ListItemBase
    itemComponent:SetIndex(index)
    self._itemComponents[index] = itemComponent
    self:RefreshItem(index)
    self:OnItemSelectionChanged(index, self:IsItemSelected(index))
end

---@protected
---@param item UListObject
---@param entry UUserWidget
function IrregularListView:OnEntryReleased(item, entry)
    local index = item.Index
    --Log.Debug("[IrregularListView] on entry released " .. tostring(index) .. " " .. tostring(entry))
    local itemComponent = self._itemComponents[index]
    if itemComponent.Item == item then
        -- NOTE: 这里index即使存在于_itemComponents里面，也可能已经不是对应的Item，因为IrregularListView:Refresh(listData)
        --       传入的listData可能已经变了，当前的流程里面可能存在多个Object对应相同Index的情况
        itemComponent:SetIndex(nil)
        self._itemComponents[index] = nil
    end
end

---@protected
---@param item UListObject
function IrregularListView:OnItemSnapped(item)
    local index = item.Index
    --Log.Debug("[IrregularListView] on item snapped " .. tostring(index))
    self:SetItemSelectionDryly(index, true)
end

---@public
---刷新列表数据
---@param listData table 数组数据
function IrregularListView:Refresh(listData)
    local oldListData = self._listData
    self._listData = listData
    local oldCount = oldListData == nil and 0 or #oldListData
    local newCount = listData == nil and 0 or #listData
    if oldCount ~= newCount or true then
        local placeholderItems = import("UIFunctionLibrary").GetListObject(self:GetViewRoot(), newCount)
        self:GetViewRoot():SetListItems(placeholderItems)
        placeholderItems:Clear()
    else
        self:GetViewRoot():RequestRefresh()
    end
end

---@protected
---@param index integer 数据序号
function IrregularListView:RefreshItem(index)
    local itemComponent = self._itemComponents[index]  ---@type ListItemBase
    if itemComponent == nil then
        return
    end
    if self._listData and self._listData[index] then
        itemComponent:Refresh(self._listData[index])
    end
end

function IrregularListView:GetItemByIndex(index)
	return self._itemComponents[index]  ---@type ListItemBase
end

---@public
---判断`index`序号对应的子项是否被选中
---@param index integer
function IrregularListView:IsItemSelected(index)
    return self._selectedIndices[index] and true or false
end

---@public
---滚动到序号`index`处
---@param index integer
function IrregularListView:ScrollTo(index)
    self:GetViewRoot():ScrollToIndex(index - 1)
end

---@public
---选中序号为`index`的子项
---@param index integer
---@param selected boolean
function IrregularListView:SetItemSelection(index, selected)
    if self._selectionMode == ESelectionMode.Single then
        self:ScrollTo(index)
    else
        self:SetItemSelectionDryly(index, selected)
    end
end

---@private
---@param index integer
---@param selected boolean
function IrregularListView:SetItemSelectionDryly(index, selected)
    assert(self._selectionMode ~= ESelectionMode.None)
    local oldSelected = self:IsItemSelected(index)
    if oldSelected == selected then
        return
    end

    if self._selectionMode == ESelectionMode.None then
        return
    elseif self._selectionMode == ESelectionMode.Single then
        local oldIndex = next(self._selectedIndices)  ---@type int | nil
        if oldIndex ~= nil then
            self._selectedIndices[oldIndex] = nil
            local oldItemComponent = self._itemComponents[oldIndex]
            if oldItemComponent ~= nil then
                oldItemComponent:OnSelectionChanged(false)
            end
        end
    else
        assert(false, "not implemented error!")
    end

    self._selectedIndices[index] = selected and true or nil
    self:OnItemSelectionChanged(index, selected)
end

---@protected
---@param index integer
---@param selected boolean
function IrregularListView:OnItemSelectionChanged(index, selected)
    local itemComponent = self._itemComponents[index]
    if itemComponent ~= nil then
        itemComponent:OnSelectionChanged(selected)
    end
end

function IrregularListView:OnDestroy()
    self:GetViewRoot().OnEntryInitialized:Clear()
    self:GetViewRoot().OnEntryReleased:Clear()
    self:GetViewRoot().OnItemSnapped:Clear()
    self._itemComponents = nil
    self._selectedIndices = nil
    UIBase.OnDestroy(self)
end


---reg 点击绑定
function IrregularListView:addClickListener(itemComponent)
    local btn = itemComponent.View.Btn_ClickArea
    if not btn then return end
	self:RemoveUIListener(EUIEventTypes.CLICK, btn)
    self:AddUIListener(EUIEventTypes.CLICK, btn, self.HandleItemClicked, itemComponent)
end

function IrregularListView:HandleItemClicked(itemComponent)
    self:GetViewRoot():SetItemSelection(itemComponent.Item, true)
end

return IrregularListView