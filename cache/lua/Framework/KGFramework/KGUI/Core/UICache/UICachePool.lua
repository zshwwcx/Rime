local UICache = kg_require("Framework.KGFramework.KGUI.Core.UICache.UICache")
---@class UICachePool
local UICachePool = DefineClass("UICachePool")

function UICachePool:ctor()
    local config = UIConst.UICacheConfig[self:GetCacheLevel()]
	self._dynamicCachePanel = UICache.new(config.dynamicPanel)
    self._staticCachePanel = UICache.new(config.staticPanel)
    self._componentCachePanel = UICache.new(config.component)
    self._listCachePanel = UICache.new(config.item)
end

function UICachePool:dtor()
end

function UICachePool:GetCacheLevel()
    return UIConst.UICacheLevel.PCHigh
end

function UICachePool:PopPanel(uid)
    local uiconfig = Game.NewUIManager:GetUIConfig(uid)
    if uiconfig.cache then
        return self._staticCachePanel:Pop(uid)
    else
        return self._dynamicCachePanel:Pop(uid)
    end
end

function UICachePool:PushPanel(panel)
    local uiconfig = Game.NewUIManager:GetUIConfig(panel.uid)
    if uiconfig.cache then
        self._staticCachePanel:Push(panel.uid, panel)
    else
        self._dynamicCachePanel:Push(panel.uid, panel)
    end
end

function UICachePool:ClearPanel()
    self._staticCachePanel:Clear()
    self._dynamicCachePanel:Clear()
end

function UICachePool:PopComponent(cellId)
    return self._componentCachePanel:Pop(cellId)
end

function UICachePool:PushComponent(component)
    self._componentCachePanel:Push(component.cellId, component)
end

function UICachePool:PopListComponent(widgetType)
    local component = self._listCachePanel:Pop(widgetType)
    if component and IsValid_L(component.userWidget) then
        slua.removeRef(component.userWidget)
    end
    return component
end

function UICachePool:PushListComponent(widgetType, component)
    slua.addRef(component.userWidget)
    self._listCachePanel:Push(widgetType, component)
end

function UICachePool:GetObjectNum()
    local num = 0
    num = num + self._staticCachePanel:GetCacheCount()
    num = num + self._dynamicCachePanel:GetCacheCount()
    num = num + self._componentCachePanel:GetCacheCount()
    num = num + self._listCachePanel:GetCacheCount()
    return num
end

function UICachePool:DebugInfo()
    local logStr = string.format("Cache UObject Total:  %s\n\n", self:GetObjectNum())
    logStr = string.format("%s \n **********Staic Panel************\n %s", logStr, self._staticCachePanel:DebugInfo())
    logStr = string.format("%s \n **********Dynamic Panel************\n %s", logStr, self._dynamicCachePanel:DebugInfo())
    logStr = string.format("%s \n **********Component************\n %s", logStr, self._componentCachePanel:DebugInfo())
    logStr = string.format("%s \n **********List************\n %s", logStr, self._listCachePanel:DebugInfo())
    Log.InfoFormat("Cache UI Info：%s", logStr)
    return logStr
end

return UICachePool