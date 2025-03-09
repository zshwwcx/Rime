local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")

---@class UIDragOperation:NewUIComponent
local UIDragOperation = DefineClass("UIDragOperation", UIComponent)

local UIFunctionLibrary = import("UIFunctionLibrary")

---@param Source UIController/UIComponent   必须  使用拖拽组件的界面self
---@param SetUIFunc function                可选  对拖拽目标设置显示逻辑的方法，参数为UIView
---@param OnDragFunc function               可选  拖拽事件开始时调用的方法，主要用来对拖拽目标原控件进行隐藏设置等
---@param OnCancelFunc function             可选  拖拽事件结束时调用的方法，与前者对应
---@param OnDropFunc function               可选  拖拽结束产生Drop时调用的方法
---@param CanDragFunc function              可选  是否触发拖拽
function UIDragOperation:BindDrag(Source, SetUIFunc, OnDragFunc, OnCancelFunc, OnDropFunc, CanDragFunc)
    self._visualFunc = SetUIFunc
    self._onDrag = OnDragFunc
    self._onCancel = OnCancelFunc
    self._onDrop = OnDropFunc
    self._canDrag = CanDragFunc
    self._sourceUI = Source

    self._dragOperation = nil
    self._viewInst = nil
    Source:AddUIEvent(self.userWidget, "OnDragDetected") 
    Source:AddUIEvent(self.userWidget, "OnDragDetected") 
    Source:AddUIEvent(self.userWidget, "OnDrop") 
end

function UIDragOperation:dtor()
    self._view = nil
    self._visualFunc = nil
    self._onCancel = nil
    self._onDrag = nil
    self._viewInst = nil
    self._dragOperation = nil
end

function UIDragOperation:getDragOperation()
	if not self._dragOperation then
		self._viewInst = UIFunctionLibrary.InstanceBP(self.userWidget)
        UIFunctionLibrary.SetZOrder(self._viewInst,0)
		self._dragOperation = UIFunctionLibrary.CreateDrag(self._viewInst, nil)
	end
    if self._visualFunc then
        self._visualFunc(self._viewInst)
    end
	return self._dragOperation
end

function UIDragOperation:OnDragDetected(MyGeometry,InMouseEvent)
    if self._canDrag and (not self._canDrag()) then
        return
    end
    local dragOperation = self:getDragOperation()
    if self._onDrag then
        self._onDrag(self._sourceUI,MyGeometry,InMouseEvent)
    end
    return dragOperation
end

function UIDragOperation:OnDragCancelled(InMouseEvent,InDragDropOperation)
    if self._onCancel then
        self._onCancel(self._sourceUI,InMouseEvent,InDragDropOperation)
    end
end

function UIDragOperation:OnDrop(_, __, dragOper)
    if self._onDrop then
        return self._onDrop(self._sourceUI,_, __, dragOper)
    end
    return nil
end

function UIDragOperation:OnDestroy()
    UIComponent.OnDestroy(self)
    self._visualFunc = nil
    self._onDrag = nil
    self._onCancel = nil

    self._dragOperation = nil
    self._viewInst = nil
end

return UIDragOperation