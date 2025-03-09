---@class ITreeListComponent
local ITreeListComponent = DefineClass("ITreeListComponent")

---@public 刷新
---@param parentUI UIController 主界面
---@param bIsSelect boolean 是否选中
---@param allData table List总数据
function ITreeListComponent:OnListRefresh(parentUI, bIsSelect, allData, ...)
end

---@public 单击
---@param parentUI UIController 主界面
---@param allData table List总数据
function ITreeListComponent:OnClick(parentUI, allData, ...)
end

---@public 可否被选中
---@param parentUI UIController 主界面
---@param allData table List总数据
function ITreeListComponent:CanSel(parentUI, allData, ...)
    return true
end

---@public 双击
---@param parentUI UIController 主界面
---@param allData table List总数据
function ITreeListComponent:OnDoubleClick(parentUI, allData, ...)
end

---@public 长按
---@param parentUI UIController 主界面
---@param allData table List总数据
function ITreeListComponent:OnLongPress(parentUI, allData, ...)
end

---@public 抬起
---@param parentUI UIController 主界面
---@param allData table List总数据
function ITreeListComponent:OnReleased(parentUI, allData, ...)
end

---@public 右键
---@param parentUI UIController 主界面
---@param allData table List总数据
function ITreeListComponent:OnRightClick(parentUI, allData, ...)
end

---@public 获取选中动画
---@return nil|table<string,string> @选中的动画控件路径和动画名称（例如：{"WidgetRoot" = "Fadein"}）
function ITreeListComponent:GetSelectAni()
end

---@public 获取取消选中动画
---@return nil|table<string,string> @选中的动画控件路径和动画名称（例如：{"WidgetRoot" = "Fadeout"}）
function ITreeListComponent:GetUnSelectAni()
end

return ITreeListComponent