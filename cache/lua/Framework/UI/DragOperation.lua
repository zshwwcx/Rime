---@class DragOperation
local DragOperation = DefineClass("DragOperation", UIComponent)

local UIFunctionLibrary = import("UIFunctionLibrary")

---@param Source UIController/UIComponent   必须  使用拖拽组件的界面self
---@param SetUIFunc function                可选  对拖拽目标设置显示逻辑的方法，参数为UIView
---@param OnDragFunc function               可选  拖拽事件开始时调用的方法，主要用来对拖拽目标原控件进行隐藏设置等
---@param OnCancelFunc function             可选  拖拽事件结束时调用的方法，与前者对应
---@param OnDropFunc function               可选  拖拽结束产生Drop时调用的方法
---@param CanDragFunc function              可选  是否触发拖拽
function DragOperation:BindDrag(Source, SetUIFunc, OnDragFunc, OnCancelFunc, OnDropFunc, CanDragFunc)
    self._view = self.View
    self._visualFunc = SetUIFunc
    self._onDrag = OnDragFunc
    self._onCancel = OnCancelFunc
    self._onDrop = OnDropFunc
    self._canDrag = CanDragFunc
    self._sourceUI = Source

    self._dragOperation = nil
    self._viewInst = nil

    if self:IsValid() then
        -- add event
        Source:AddUIListener(EUIEventTypes.DragDetected, self._view.WidgetRoot, function(ui,MyGeometry,InMouseEvent)
            return self:OnDragDetected(MyGeometry,InMouseEvent) 
        end)
        Source:AddUIListener(EUIEventTypes.DragCancelled, self._view.WidgetRoot, function(ui,InMouseEvent,InDragDropOperation)
            self:OnDragCancelled(InMouseEvent,InDragDropOperation)
        end)
        Source:AddUIListener(EUIEventTypes.Drop, self._view.WidgetRoot, function(ui, _, __, dragOper)
            self:OnDrop(_, __, dragOper)
        end)
    end
end

function DragOperation:dtor()
    self._view = nil
    self._visualFunc = nil
    self._onCancel = nil
    self._onDrag = nil
    self._viewInst = nil
    self._dragOperation = nil
end

function DragOperation:IsValid()
    if not self._view then
		Log.Debug("no targetVisualWidget passed")
		return false
	end
	if not self._view.WidgetRoot or not self._view.WidgetRoot:IsA(import("UserWidget")) then
		Log.Warning("Drag TargetVisual should be UserWidget WBP")
		return false
	end
    return true
end

function DragOperation:getDragOperation()
	if not self._dragOperation then
		self._viewInst = UIFunctionLibrary.InstanceBP(self._view.WidgetRoot)
        UIFunctionLibrary.SetZOrder(self._viewInst,0)
		self._dragOperation = UIFunctionLibrary.CreateDrag(self._viewInst, nil)
	end
    local wrapView = setmetatable({ WidgetRoot = self._viewInst }, UIView._rootMeta)
    if self._visualFunc then
        self._visualFunc(wrapView)
    end
    wrapView = nil
	return self._dragOperation
end

function DragOperation:OnDragDetected(MyGeometry,InMouseEvent)
    if self._canDrag and (not self._canDrag()) then
        return
    end
    local dragOperation = self:getDragOperation()
    if self._onDrag then
        self._onDrag(self._sourceUI,MyGeometry,InMouseEvent)
    end
    return dragOperation
end

function DragOperation:OnDragCancelled(InMouseEvent,InDragDropOperation)
    if self._onCancel then
        self._onCancel(self._sourceUI,InMouseEvent,InDragDropOperation)
    end
end

function DragOperation:OnDrop(_, __, dragOper)
    if self._onDrop then
        return self._onDrop(self._sourceUI,_, __, dragOper)
    end
    return nil
end

function DragOperation:OnDestroy()
    UIBase.OnDestroy(self)
    self._view = nil
    self._visualFunc = nil
    self._onDrag = nil
    self._onCancel = nil

    self._dragOperation = nil
    self._viewInst = nil
end

return DragOperation