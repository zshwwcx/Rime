--
-- Lua EventSytem
---

require "Framework.EventSystem.EventTypes"
---@class EventSystem lua事件系统
local EventSystem = DefineSingletonClass("EventSystem")

-------------------------------------------------------
-- Private Functions
-------------------------------------------------------

EventSystem.PendingBehaviorTypes = {
    InnerAddListener = 1,
    InnerRemoveListener = 2,
    InnerReplaceBehavior = 3
}

---@private innerAddListener
function EventSystem:innerAddListener(EventType, Obj, CallBackFunc, Behavior)
    if Behavior == nil then
        self.ObjBindFuncs[Obj] = self.ObjBindFuncs[Obj] or {}

        if self.ObjBindFuncs[Obj][EventType] == nil then
            self.ObjBindFuncs[Obj][EventType] = CallBackFunc
            self.DeliverTable[EventType] = self.DeliverTable[EventType] or {}
            self.DeliverTable[EventType][Obj] = type(CallBackFunc) == "function"
        else
            Log.Warning("Add ListenerError: Obj already bind to this event Obj:", tostring(Obj), --todo Log.Error先临时改成Waring,等UI框架重构完后改回来
                " EventType:", EventType)
            return
        end
    else
        self.ObjBindBehvFuncs[Obj] = self.ObjBindBehvFuncs[Obj] or {}
        self.ObjBindBehvFuncs[Obj][EventType] = self.ObjBindBehvFuncs[Obj][EventType] or {}
        if self.ObjBindBehvFuncs[Obj][EventType][Behavior] == nil then
            self.ObjBindBehvFuncs[Obj][EventType][Behavior] = CallBackFunc
            self.BehaviorDeliverTable[EventType] = self.BehaviorDeliverTable[EventType] or {}
            if self.BehaviorDeliverTable[EventType][Obj] == nil then
                self.BehaviorDeliverTable[EventType][Obj] = { 0, type(CallBackFunc) == "function" }
            end
            self.BehaviorDeliverTable[EventType][Obj][1] = self.BehaviorDeliverTable[EventType][Obj][1] + 1
        else
            Log.Error("Add ListenerError: Obj already bind to this event Obj:", tostring(Obj),
                " EventType:", EventType,
                " Behavior:", tostring(Behavior))
            return
        end
    end
end


---@private innerRemoveListener
function EventSystem:innerRemoveListener(EventType, Obj, Func, Behavior)
    if (EventType == nil or Obj == nil) then
        Log.Debug("Event System InnerRemoveListener invalid Param")
        return
    end

    if Behavior == nil then
        if self.DeliverTable[EventType] and self.DeliverTable[EventType][Obj] ~= nil and self.ObjBindFuncs[Obj][EventType] == Func then
            self.DeliverTable[EventType][Obj] = nil
            self.ObjBindFuncs[Obj][EventType] = nil

            if next(self.ObjBindFuncs[Obj]) == nil then
                self.ObjBindFuncs[Obj] = nil
            end

            if next(self.DeliverTable[EventType]) == nil then
                self.DeliverTable[EventType] = nil
            end
        else
            -- Log.ErrorFormat("Remove Listener Error : Cannot Find Listener:%s ,%s, %s, %s",EventType, Obj.__cname or Obj,Func, Behavior)
        end
    else
        if self.BehaviorDeliverTable[EventType]
            and self.BehaviorDeliverTable[EventType][Obj]
            and self.ObjBindBehvFuncs[Obj][EventType][Behavior] == Func
        then
            self.ObjBindBehvFuncs[Obj][EventType][Behavior] = nil

            if next(self.ObjBindBehvFuncs[Obj][EventType]) == nil then
                self.ObjBindBehvFuncs[Obj][EventType] = nil
            end

            if next(self.ObjBindBehvFuncs[Obj]) == nil then
                self.ObjBindBehvFuncs[Obj] = nil
            end

            self.BehaviorDeliverTable[EventType][Obj][1] = self.BehaviorDeliverTable[EventType][Obj][1] - 1
            if self.BehaviorDeliverTable[EventType][Obj][1] <= 0 then
                self.BehaviorDeliverTable[EventType][Obj] = nil
            end

            if next(self.BehaviorDeliverTable[EventType]) == nil then
                self.BehaviorDeliverTable[EventType] = nil
            end
        else
            --Log.ErrorFormat("Remove Behavior Listener Error: Cannot Find Behavior Listener:%s ,%s, %s, %s", EventType,
            -- Obj.__cname or Obj, Func, Behavior)
        end
    end
end

---@private innerReplaceBehavior
function EventSystem:innerReplaceBehavior(OldBehavior, NewBehavior)
    if OldBehavior == NewBehavior then
        return
    end

    --替换Behavior
    for _, EventTypeBehvaiorMap in pairs(self.ObjBindBehvFuncs) do
        for _, BehaviorFuncMap in pairs(EventTypeBehvaiorMap) do
            if BehaviorFuncMap[OldBehavior] then
                BehaviorFuncMap[NewBehavior] = BehaviorFuncMap[OldBehavior]
                BehaviorFuncMap[OldBehavior] = nil
            end
        end
    end

    --PendingList 也需要替换
    for K, V in ipairs(self.PendingList) do
        if V.Params and V.Params.Behavior and V.Params.Behavior == OldBehavior then
            V.Params.Behavior = NewBehavior
        end
    end
end

---@private innerSend
function EventSystem:innerSend(EventType, Behavior, ...)
    self.LockedEvents[EventType] = true

    if Behavior == nil then
        local Objs = self.DeliverTable[EventType]
        for Obj, isFunc in pairs(Objs) do
            if isFunc then
                xpcall(self.ObjBindFuncs[Obj][EventType], _G.CallBackError, Obj, ...)
            else
                xpcall(Obj[self.ObjBindFuncs[Obj][EventType]], _G.CallBackError, Obj, ...)
            end
        end
    else
        local Objs = self.BehaviorDeliverTable[EventType]
        if (Objs ~= nil) then
            for Obj, detail in pairs(Objs) do
                if self.ObjBindBehvFuncs[Obj][EventType][Behavior] then
                    if detail[2] then
                        xpcall(self.ObjBindBehvFuncs[Obj][EventType][Behavior], _G.CallBackError, Obj, ...)
                    else
                        xpcall(Obj[self.ObjBindBehvFuncs[Obj][EventType][Behavior]], _G.CallBackError, Obj, ...)
                    end
                end
            end
        end
    end

    self.LockedEvents[EventType] = nil
    self:DealPendingList()
end


-------------------------------------------------------
-- Public Functions
-------------------------------------------------------

function EventSystem:ctor()
    self.DeliverTable = {}
    self.ObjBindFuncs = {}
    self.BehaviorDeliverTable = {}
    self.ObjBindBehvFuncs = {}
    self.PendingList = {}
    self.LockedEvents = {}
    self.BehaviorsToRemove = {}
end

--- @brief SubScrible to an Event, One Function per Object
--- @param EventType string EventType To Subscribe
--- @param Obj any Obj to Subscrible,Can be Any data type
--- @param CallBackFunc function|string The function called when this event published
--- @param Behavior any CustCustome Behavior
function EventSystem:AddListener(EventType, Obj, CallBackFunc, Behavior)
    if (EventType == nil or Obj == nil or (type(CallBackFunc) == "string" and Obj[CallBackFunc] == nil or CallBackFunc == nil)) then
        Log.Debug("EventSystem AddListener Invalid Params ", EventType ~= nil and EventType or "EventType is nil")
        return
    end

    if self.LockedEvents[EventType] then
        table.insert(self.PendingList, {
            Operation = EventSystem.PendingBehaviorTypes.InnerAddListener,
            Params = {
                EventType = EventType,
                Obj = Obj,
                CallBackFunc = CallBackFunc,
                Behavior = Behavior,
            }
        })
    else
        self:innerAddListener(EventType, Obj, CallBackFunc, Behavior)
    end
end

-- 用于指定对象的“一对一”模式订阅-派发,单起一个接口名称, 便于后期统一排查
function EventSystem:AddListenerForUniqueID(EventType, Obj, CallBackFunc, UniqueID)
    if (UniqueID == nil) then
        Log.Error("[EventSystem:AddListenerForUniqueID] UniqueID is nil ,EventType:", EventType)
        return
    end

    self:AddListener(EventType, Obj, CallBackFunc, UniqueID)
end

-- 用于指定对象的“一对一”模式订阅-派发,单起一个接口名称, 便于后期统一排查
function EventSystem:RemoveListenerForUniqueID(EventType, Obj, CallBackFunc, UniqueID)
    if (UniqueID == nil) then
        Log.Error("[EventSystem:RemoveListenerForUniqueID] UniqueID is nil ,EventType:", EventType)
        return
    end

    self:RemoveListenerFromType(EventType, Obj, CallBackFunc, UniqueID)
end

--- @brief Unsubscribe An Event
--- @param EventType string EventType To Unsubscribe
--- @param Obj any Obj to Remove listener
function EventSystem:RemoveListenerFromType(EventType, Obj, func, Behavior, force)
    if (EventType == nil or Obj == nil) then
        Log.Debug("EventSystem RemoveListenerFromType Invalid Params")
        return
    end

    if self.LockedEvents[EventType] and not force then
        table.insert(self.PendingList, {
            Operation = EventSystem.PendingBehaviorTypes.InnerRemoveListener,
            Params = {
                EventType = EventType,
                Obj = Obj,
                CallBackFunc = func,
                Behavior = Behavior,
            }

        })
    else
        self:innerRemoveListener(EventType, Obj, func, Behavior)
    end
end

--- @brief Remove all listners attatched to this object. Use Cautiously, This function is Slow,it Searches Each Eventtype to unsubscribe
--- @param Obj any The Object to Remove Listener
---@param forceRemove boolean 是否强制移除
function EventSystem:RemoveObjListeners(Obj, forceRemove)
    --PendingList 中待订阅清除
    for i = #self.PendingList, 1, -1 do
        if self.PendingList[i].Operation == EventSystem.PendingBehaviorTypes.InnerAddListener and
            self.PendingList[i].Params.Obj and self.PendingList[i].Params.Obj == Obj then
            table.remove(self.PendingList, i)
        end
    end

    local EventTypesToRemove = {}
    if self.ObjBindFuncs[Obj] then
        for EventType, Func in pairs(self.ObjBindFuncs[Obj]) do
            table.insert(EventTypesToRemove, { EventType, Func })
        end
    end

    for _, EventTypeData in ipairs(EventTypesToRemove) do
        self:RemoveListenerFromType(EventTypeData[1], Obj, EventTypeData[2], nil, forceRemove)
    end
    
    local BehaviorsToRemove = self.BehaviorsToRemove
    if self.ObjBindBehvFuncs[Obj] then
        for EventType, Behaviors in pairs(self.ObjBindBehvFuncs[Obj]) do
            for Behavior, Func in pairs(Behaviors) do
                local index = #BehaviorsToRemove
                BehaviorsToRemove[index + 1] = EventType
                BehaviorsToRemove[index + 2] = Func
                BehaviorsToRemove[index + 3] = Behavior
            end
        end
    end
    for i = 1, #BehaviorsToRemove, 3 do
        self:RemoveListenerFromType(BehaviorsToRemove[i], Obj, BehaviorsToRemove[i + 1], BehaviorsToRemove[i + 2], forceRemove)
    end
    table.clear(BehaviorsToRemove)
end

-- --- @brief Send to a specified target's Listeners Subscribed to this event type
-- --- @param EventType string The EventType to send
-- --- @param Target table The target obj to send to
-- --- @param ... any Additional Params to CallBack Function
-- function EventSystem:Send(EventType,Target, ...)
--     if (EventType == nil or self.DeliverTable[EventType] ==nil or Target == nil or self.DeliverTable[EventType][Target] ==nil) then
--         return
--     end

--     self:innerSend(EventType,Target, ...)
-- end

--- @brief Publish to all Listeners Subscribed to this event type
--- @param EventType string The EventType to Publish
--- @param ... any Additional Params to CallBack Function
function EventSystem:Publish(EventType, ...)
    if (EventType == nil or self.DeliverTable[EventType] == nil) then
        return
    end

    self:innerSend(EventType, nil, ...)
end

--- @brief Publish to all Listeners Subscribed to this event Behavior type
--- @param EventType string The EventType to Publish
--- @param Behavior any UserCustome Behavior
--- @param ... any Additional Params to CallBack Function
function EventSystem:PublishBehavior(EventType, Behavior, ...)
    if (EventType == nil or self.BehaviorDeliverTable[EventType] == nil) then
        return
    end
    if Behavior == nil then
        Log.Error("Behavior is nil ,EventType:",EventType)
        return
    end
    self:innerSend(EventType, Behavior, ...)
end

-- 用于指定对象的“一对一”模式订阅-派发,单起一个接口名称, 便于后期统一排查
function EventSystem:PublishForUniqueID(EventType, UniqueID, ...)
    if UniqueID == nil then
        Log.Error("[EventSystem:PublishForUniqueID] UniqueID is nil ,EventType:", EventType)
        return
    end
    self:innerSend(EventType, UniqueID, ...)
end

--- @brief Replace a Behavior With a NewBehavior
----- @param OldBehavior any The Behavior to replace
----- @param NewBehavior any new Behavior
---Caution: Use this function cautiously !!The Behavior name need to be Globally Unique !!
function EventSystem:ReplaceBehavior(OldBehavior, NewBehavior)
    --订阅消息替换
    local bNeedPending = false
    --检查是否有锁
    for Obj, EventTypeBehvaiorMap in pairs(self.ObjBindBehvFuncs) do
        for EventType, BehaviorFuncMap in pairs(EventTypeBehvaiorMap) do
            if self.LockedEvents[EventType] then
                bNeedPending = true
            end
        end
    end

    if bNeedPending then
        table.insert(self.PendingList, {
            Operation = EventSystem.PendingBehaviorTypes.InnerReplaceBehavior,
            Params = {
                OldBehavior = OldBehavior,
                NewBehavior = NewBehavior,
            }
        })
    else
        self:innerReplaceBehavior(OldBehavior, NewBehavior)
    end
end

function EventSystem:DealPendingList()
    if next(self.LockedEvents) == nil and next(self.PendingList) ~= nil then
        for _, Changes in ipairs(self.PendingList) do
            if Changes.Operation == EventSystem.PendingBehaviorTypes.InnerAddListener then
                xpcall(self.innerAddListener, _G.CallBackError, self,
                        Changes.Params.EventType,
                        Changes.Params.Obj,
                        Changes.Params.CallBackFunc,
                        Changes.Params.Behavior)
            elseif Changes.Operation == EventSystem.PendingBehaviorTypes.InnerRemoveListener then
                xpcall(self.innerRemoveListener, _G.CallBackError, self,
                        Changes.Params.EventType,
                        Changes.Params.Obj,
                        Changes.Params.CallBackFunc,
                        Changes.Params.Behavior)
            elseif Changes.Operation == EventSystem.PendingBehaviorTypes.InnerReplaceBehavior then
                xpcall(self.innerReplaceBehavior, _G.CallBackError, self,
                        Changes.Params.OldBehavior,
                        Changes.Params.NewBehavior)
            end
        end
        table.clear(self.PendingList)
    end
end

function EventSystem:IsEventBehaviorSubscribed(EventType, Behavior)
    if self.BehaviorDeliverTable[EventType] then
        local Objs = self.BehaviorDeliverTable[EventType]
        if (Objs ~= nil) then
            for Obj, _ in pairs(Objs) do
                if self.ObjBindBehvFuncs[Obj][EventType][Behavior] then
                    return true
                end
            end
        end
    end
    return false
end

function EventSystem:UnInit()
end

return EventSystem
