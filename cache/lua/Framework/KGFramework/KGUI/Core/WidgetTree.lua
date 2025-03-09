local WidgetTree = DefineClass("WidgetTree")
function WidgetTree:ctor(userWidget)
    self._userWidget = userWidget
    self._widgetCache = {}
    local mt = getmetatable(self)
    mt.__index = function(tb, key)
        local v = WidgetTree.getProperty(tb, key)
		-- if not v then
        --     v = WidgetTree.getProperty(tb, key .. "_lua") -- todo 兼容旧的命名格式等迭代完成可以修改蓝名节点名
        -- end
        return v
    end
    setmetatable(self, mt)
end

function WidgetTree.getProperty(self, key)
    if self._widgetCache[key] then
        return self._widgetCache[key]
    end
    local widget = self._userWidget[key]
    if widget == nil then
        return
    end
    self._widgetCache[key] = widget
    return widget
end

return WidgetTree