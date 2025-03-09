---@class WidgetEmptyComponent:UIComponent 空的Component，用于绑定逻辑很简单的组件
local WidgetEmptyComponent = DefineClass("WidgetEmptyComponent", UIComponent)

---OnCreate
---@param name string 控件名(由框架传入)
function WidgetEmptyComponent:OnCreate(name, ...)
    self.super.OnCreate(self, ...)
    local parent = self:GetParent()
    local methodName = "OnRefresh_" .. name
    local callback = parent[methodName]
    if callback then
        xpcall(callback, _G.CallBackError, parent, self, ...)
    end
end

return WidgetEmptyComponent