local table_clear = table.clear
local pairs = pairs

require "Framework.EventSystem.EventTypes"

USE_OLD_EVENT_SYSTEM = false   -- luacheck: ignore
if USE_OLD_EVENT_SYSTEM then
	local EventSystem = require "Framework.EventSystem.EventSystemOld"
	return EventSystem
end
local EventDispatcher = require("Framework.EventSystem.EventDispatcher")

---@class EventSystem
local EventSystem = DefineSingletonClass("EventSystem")

-- 弱引用标记，因为_eventDict第二层的key是obj
mtWeakKeyTable = mtWeakKeyTable or {
    __mode = "k",
}

function EventSystem:ctor()
	self.globalEventDispatcher = EventDispatcher.new()
	self.behaviorEventDispatcherDict = {}
	-- 加速查找
	self.targetBehaviorEventDict = {}
	setmetatable(self.targetBehaviorEventDict, mtWeakKeyTable)
	
	-- 简单缓存池
	self.cacheEventDispatcher = {}
	self.cacheMaxCount = 100
end

function EventSystem:dtor()
	self.globalEventDispatcher:Clear()
	self.globalEventDispatcher = nil
	for _, eventDispatcher in pairs(self.behaviorEventDispatcherDict) do
		eventDispatcher:clear()
	end
	self.behaviorEventDispatcherDict = nil
	self.targetBehaviorEventDict = nil
end

function EventSystem:GetEventDispatcher()
	if #self.cacheEventDispatcher > 0 then
		return table.remove(self.cacheEventDispatcher)
	end
	return EventDispatcher.new()
end

function EventSystem:CacheEventDispatcher(eventDispatcher)
	if #self.cacheEventDispatcher >= self.cacheMaxCount then
		return
	end
	eventDispatcher:Clear()
	self.cacheEventDispatcher[#self.cacheEventDispatcher + 1] = eventDispatcher
end

function EventSystem:AddListener(EventType, Obj, CallBackFunc, Behavior)
	if Behavior then
		if not self.behaviorEventDispatcherDict[Behavior] then
			self.behaviorEventDispatcherDict[Behavior] = self:GetEventDispatcher()
		end
		if self.behaviorEventDispatcherDict[Behavior]:AddListener(EventType, Obj, CallBackFunc) then
			self.targetBehaviorEventDict[Obj] = self.targetBehaviorEventDict[Obj] or {}
			local behaviorEventDict = self.targetBehaviorEventDict[Obj]
			behaviorEventDict[Behavior] = behaviorEventDict[Behavior] or {}
			behaviorEventDict[Behavior][EventType] = behaviorEventDict[Behavior][EventType] or 0
			behaviorEventDict[Behavior][EventType] = behaviorEventDict[Behavior][EventType] + 1
		end
	else
		self.globalEventDispatcher:AddListener(EventType, Obj, CallBackFunc)
	end
end

function EventSystem:AddListenerForUniqueID(EventType, Obj, CallBackFunc, UniqueID)
	if (UniqueID == nil) then
		Log.ErrorFormat("[EventSystem:AddListenerForUniqueID] UniqueID is nil ,EventType: %s", EventType)
		return
	end
	self:AddListener(EventType, Obj, CallBackFunc, UniqueID)
end

function EventSystem:RemoveListenerForUniqueID(EventType, Obj, CallBackFunc, UniqueID)
	if (UniqueID == nil) then
		Log.ErrorFormat("[EventSystem:RemoveListenerForUniqueID] UniqueID is nil ,EventType:%s", EventType)
		return
	end
	self:RemoveListenerFromType(EventType, Obj, CallBackFunc, UniqueID)
end

function EventSystem:RemoveListenerFromType(EventType, Obj, func, Behavior)
	if Behavior then
		local eventDispatcher = self.behaviorEventDispatcherDict[Behavior]
		if not eventDispatcher then
			Log.WarningFormat("[EventSystem:RemoveListenerFromType] listener is not exist, EventType:%s", EventType)
			return
		end
		eventDispatcher:RemoveListener(EventType, Obj, func)
		if eventDispatcher:IsEmpty() then
			self.behaviorEventDispatcherDict[Behavior] = nil
			self:CacheEventDispatcher(eventDispatcher)
		end
		local behaviorEventDict = self.targetBehaviorEventDict[Obj]
		-- 注意add 和 remove的次数一定要匹配
		if not behaviorEventDict or not behaviorEventDict[Behavior] or not behaviorEventDict[Behavior][EventType] then
			--Log.ErrorFormat("[EventSystem:RemoveListenerFromType] remove count more than add, EventType:%s", EventType)
			return
		else
			behaviorEventDict[Behavior][EventType] = behaviorEventDict[Behavior][EventType] - 1
			if behaviorEventDict[Behavior][EventType] <= 0 then
				behaviorEventDict[Behavior][EventType] = nil
				if not next(behaviorEventDict[Behavior]) then
					behaviorEventDict[Behavior] = nil
					if not next(behaviorEventDict) then
						self.targetBehaviorEventDict[Obj] = nil
					end
				end
			end
		end
	else
		self.globalEventDispatcher:RemoveListener(EventType, Obj, func)
	end
end

function EventSystem:RemoveObjListeners(Obj)
	self.globalEventDispatcher:RemoveTargetListener(Obj)
	--for Behavior, eventDispatcher in pairs(self.behaviorEventDispatcherDict) do
	--	eventDispatcher:RemoveTargetListener(Obj)
	--	if eventDispatcher:IsEmpty() then
	--		self.behaviorEventDispatcherDict[Behavior] = nil
	--		self:CacheEventDispatcher(eventDispatcher) 
	--	end
	--end
	if self.targetBehaviorEventDict[Obj] then
		for Behavior, _ in pairs(self.targetBehaviorEventDict[Obj]) do
			local eventDispatcher = self.behaviorEventDispatcherDict[Behavior]
			eventDispatcher:RemoveTargetListener(Obj)
			if eventDispatcher:IsEmpty() then
				self.behaviorEventDispatcherDict[Behavior] = nil
				self:CacheEventDispatcher(eventDispatcher)
			end
		end
		self.targetBehaviorEventDict[Obj] = nil
	end
end

function EventSystem:Publish(EventType, ...)
	if EventType == nil then
		Log.ErrorFormat("[EventSystem:Publish] EventType is nil")
		return
	end
	self.globalEventDispatcher:TriggerEvent(EventType, ...)
end

function EventSystem:PublishBehavior(EventType, Behavior, ...)
	if Behavior == nil then
		Log.ErrorFormat("[EventSystem:PublishBehavior] Behavior is nil, EventType:%s", EventType)
		return
	end
	if EventType == nil then
		Log.ErrorFormat("[EventSystem:PublishBehavior] EventType is nil, Behavior: %s", Behavior)
		return
	end
	if not self.behaviorEventDispatcherDict[Behavior] then
		return
	end
	self.behaviorEventDispatcherDict[Behavior]:TriggerEvent(EventType, ...)
end

function EventSystem:PublishForUniqueID(EventType, UniqueID, ...)
	self:PublishBehavior(EventType, UniqueID, ...)
end

function EventSystem:ReplaceBehavior(OldBehavior, NewBehavior)
	if OldBehavior == NewBehavior then return end
	self.behaviorEventDispatcherDict[NewBehavior] = self.behaviorEventDispatcherDict[OldBehavior]
	self.behaviorEventDispatcherDict[OldBehavior] = nil
	for _, behaviorEventDict in pairs(self.targetBehaviorEventDict) do
		behaviorEventDict[NewBehavior] = behaviorEventDict[OldBehavior]
		behaviorEventDict[OldBehavior] = nil
	end
end

function EventSystem:IsEventBehaviorSubscribed(EventType, Behavior)
	if self.behaviorEventDispatcherDict[Behavior] and self.behaviorEventDispatcherDict[Behavior]:IsEventSubscribed(EventType) then
		return true
	end
	return false
end

function EventSystem:Clear()
	self.globalEventDispatcher:Clear()
	table_clear(self.behaviorEventDispatcherDict)
	table_clear(self.targetBehaviorEventDict)
end

function EventSystem:UnInit()
end

function EventSystem:GetListenCount()
	local count = 0
	for _, eventGroup in pairs(self.globalEventDispatcher._eventDict) do
		for _, cbList in pairs(eventGroup) do
			for _, _ in ipairs(cbList) do
				count = count + 1
			end
		end
	end
	for _, eventDispatcher in pairs(self.behaviorEventDispatcherDict) do
		for _, eventGroup in pairs(eventDispatcher._eventDict) do
			for _, cbList in pairs(eventGroup) do
				for _, _ in ipairs(cbList) do
					count = count + 1
				end
			end
		end
	end
	return count
end

return EventSystem