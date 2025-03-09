
local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class UIListItem:NewUIComponent
---@field index int
---@field data any

local UIListItem = DefineClass("UIListItem", UIComponent)

function UIListItem:InitDefaultClickEvent()
    if self.view.Btn_ClickArea then
        self:AddUIEvent(self.view.Btn_ClickArea.OnClicked, "OnClickBtnInternal")
    end
end

---@public
---设置序号
---@param index int 序号
function UIListItem:SetIndex(index)
    self.index = index
end

---@public
---设置数据
---@param index int 序号
function UIListItem:RefreshInternal(data, otherInfo)
    self.data = data or {}
    self.otherInfo = otherInfo or self.otherInfo
    self:OnRefresh(data, otherInfo)
    self:UpdateSelectionState(self:IsSelected())
end

---数据更新
---@field data any
function UIListItem:OnRefresh(data)
end

---更新选择的业务表现
---@field selected bool
function UIListItem:UpdateSelectionState(selected)
    if self.userWidget.SetSelected then
        self.userWidget:SetSelected(selected)
    end
end

---对象释放回调
function UIListItem:OnReleased()
end

function UIListItem:OnClickBtnInternal()
    self.parentComponent:processListClickInternal(self.index, self.data)
    self.parentComponent:processListSelectInternal(self.index)
end

--是否被选中
function UIListItem:IsSelected()
    return self.parentComponent:IsSelectedByIndex(self.index)
end

function UIListItem:IsLastChild()
    return self.parentComponent:NodeIsLastChild(self.index)
end
return UIListItem