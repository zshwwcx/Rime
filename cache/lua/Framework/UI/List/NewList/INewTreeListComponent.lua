local BaseListItemComponent = kg_require("Framework.UI.List.NewList.BaseListItemComponent")
---@class INewTreeListComponent
local INewTreeListComponent = DefineClass("INewTreeListComponent",BaseListItemComponent)

---@public 刷新
---@param parentUI UIController 主界面
---@param bIsSelect boolean 是否选中
---@param allData table List总数据
function INewTreeListComponent:OnListRefresh(parentUI, bIsSelect, allData, ...)
end

---@public 单击
---@param parentUI UIController 主界面
---@param allData table List总数据
function INewTreeListComponent:OnClick(parentUI, allData, ...)
end

---@public 可否被选中
---@param parentUI UIController 主界面
---@param allData table List总数据
function INewTreeListComponent:CanSel(parentUI, allData, ...)
    return true
end

---@public 双击
---@param parentUI UIController 主界面
---@param allData table List总数据
function INewTreeListComponent:OnDoubleClick(parentUI, allData, ...)
end

---@public 长按
---@param parentUI UIController 主界面
---@param allData table List总数据
function INewTreeListComponent:OnLongPress(parentUI, allData, ...)
end

---@public 抬起
---@param parentUI UIController 主界面
---@param allData table List总数据
function INewTreeListComponent:OnReleased(parentUI, allData, ...)
end

---@public 右键
---@param parentUI UIController 主界面
---@param allData table List总数据
function INewTreeListComponent:OnRightClick(parentUI, allData, ...)
end

---@public 获取选中动画
---@return nil|table<string,string> @选中的动画控件路径和动画名称（例如：{"WidgetRoot" = "Fadein"}）
function INewTreeListComponent:GetSelectAni()
end

---@public 获取取消选中动画
---@return nil|table<string,string> @选中的动画控件路径和动画名称（例如：{"WidgetRoot" = "Fadeout"}）
function INewTreeListComponent:GetUnSelectAni()
end

return INewTreeListComponent