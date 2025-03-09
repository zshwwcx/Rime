local UIListView = kg_require("Framework.KGFramework.KGUI.Component.UIListView.UIListView")
---@class UISimpleList : UIListView
local UISimpleList = DefineClass("UISimpleList", UIListView)

function UISimpleList:InitUIView()
    self:InitWidgetEntryItem()
end

function UISimpleList:InitUIEvent()
end

function UISimpleList:InitWidgetEntryItem()
    local num = self.widget:GetChildrenCount()
    for i = 1, num do
        local child = self.widget:GetChildAt(i - 1)
        child:SetVisibility(UE.ESlateVisibility.Collapsed)
        self:addItem(i, child)
        self:releasedItem(child)
        if not self.widgetEntry then
            self.widgetEntry = child
        end
    end
end

---@public
---使用新的数据刷新列表
---@param _datas table 列表原始数据
---@param otherInfo? table | nil 列表里每个Item的补充数据，解决列表数据不全的问题（默认值：nil）
function UISimpleList:Refresh(datas, otherInfo)
    table.clear(self._curSelectIndexs)
    self._datas = datas
    self._otherInfo = otherInfo
    self:releaseAllChild()
    self:generateList()
end

function UISimpleList:releaseAllChild()
    for _,v in ipairs(self._itemShowIndexMap) do
        self:releasedItem(v.userWidget)
    end
end

function UISimpleList:generateList()
    local count = #self._datas
    for i = 0, count - 1 do
        local userwidget = self:onGetEntryWidgetForPool(self.widgetEntry:GetClass())
        if userwidget then
            self:onEntryInitialized(i, userwidget)
        else
            userwidget = self.widget:GetChildAt(i)
            if not userwidget then
                userwidget = import("UIFunctionLibrary").C7CreateWidget(self.userWidget, self.widget, self.widgetEntry)
                self:CopySlot(userwidget.Slot)
            end
            self:onEntryInitialized(i, userwidget)
        end
    end
end

---@public
---通过序号触发Item选中
---@param index int 指定序号
function UISimpleList:SetSelectedItemByIndex(index, selected)
    local lastSelectIndex = self:GetSelectedItemIndex()
    if lastSelectIndex then
        self:onItemSelectionChangedInternal(lastSelectIndex - 1, false)
    end
    self:onItemSelectionChangedInternal(index - 1, true)
end

---@public
---获取当前选择模式
function UISimpleList:GetSelectionMode()
    return UE.ESelectionMode.Single
end

--设置slot参数
function UISimpleList:CopySlot(Slot)
    if Slot:IsA(import("VerticalBoxSlot")) or Slot:IsA(import("HorizontalBoxSlot")) then
        local sSlot = self.widgetEntry.Slot
        Slot:SetPadding(sSlot.Padding)
        Slot:SetSize(sSlot.Size)
        Slot:SetHorizontalAlignment(sSlot.HorizontalAlignment)
        Slot:SetVerticalAlignment(sSlot.VerticalAlignment)
    end
end
return UISimpleList