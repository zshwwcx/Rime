---@class EventBase
---@field events table<string,string|function|table<string|function,string>>
local EventBase = DefineClass("EventBase")

function EventBase:ctor()
    self.events = nil
end

---@public BatchAddListener 批量注册事件监听
function EventBase:BatchAddListener()
    local eventDict = self.eventBindMap
    if not eventDict then
        return
    end
    for eventType, value in pairs(eventDict) do
        if type(value) == "table" then
            if type(value[2]) == "function" then
                local result, behavior = xpcall(value[2], _G.CallBackError)
                if result then
                    self:AddListener(eventType, value[1], behavior)
                end
            else
                self:AddListener(eventType, value[1], value[2])
            end
        else
            self:AddListener(eventType, value)
        end
    end
end

---@public RemoveAllListener 批量移除事件监听
---@param forceRemove boolean 是否强制强制移除（防止移除过程中收到事件）
function EventBase:RemoveAllListener(forceRemove)
    Game.EventSystem:RemoveObjListeners(self, forceRemove)
    if self.events then
        table.clear(self.events)
    end
end

---@public AddListener 注册事件监听
---@param eventType string 事件类型
---@param callBackFunc string|function  事件回调函数（或回调函数名称）
---@param behavior string entityId
function EventBase:AddListener(eventType, callBackFunc, behavior)
    if (eventType == nil or (type(callBackFunc) == "string" and self[callBackFunc] == nil or callBackFunc == nil)) then
        Log.Warning("EventSystem AddListener Invalid Params ", eventType ~= nil and eventType or "EventType is nil")
        return
    end

    self.events = self.events or {}
    if behavior then
        self.events[eventType] = self.events[eventType] or {}
        if self.events[eventType][behavior] then
            --Log.Error("AddListener Error: already register this eventType. ClassName:", self.__cname, " EventType:", eventType)
            return
        end
    elseif self.events[eventType] then
        --Log.Error("AddListener Error: already register this eventType. ClassName:", self.__cname, " EventType:", eventType)
        return
    end
    Game.EventSystem:AddListener(eventType, self, callBackFunc, behavior)
    if behavior then
        self.events[eventType][behavior] = callBackFunc
    else
        self.events[eventType] = callBackFunc
    end
end

---@public RemoveListener 移除事件监听
---@param eventType string 事件类型
---@param behavior string entityId
function EventBase:RemoveListener(eventType, behavior)
    if self.events and self.events[eventType] then
        local eventValue = self.events[eventType]
        if behavior and eventValue then
            eventValue = self.events[eventType][behavior]
        end
        Game.EventSystem:RemoveListenerFromType(eventType, self, eventValue, behavior)
        if eventValue then
            if behavior then
                self.events[eventType][behavior] = nil
            else
                self.events[eventType] = nil
            end
        end
    end
end

---@public OnDestroy
function EventBase:OnDestroy()
    self:RemoveAllListener(true)
end

return EventBase