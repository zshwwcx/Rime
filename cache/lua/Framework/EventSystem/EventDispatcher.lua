local table_remove = table.remove
local table_clear = table.clear
local pairs = pairs
local ipairs = ipairs
local ULLFunc = import("LowLevelFunctions")
local EPropertyClass = import("EPropertyClass")

local EventDispatcher = DefineClass("EventDispatcher")

-- 弱引用标记，因为_eventDict第二层的key是obj
mtWeakKeyTable = mtWeakKeyTable or {
	__mode = "k",
}

-- 最大派发次数，大于该值认为死循环
MAX_DISPATCH_COUNT = 20  -- luacheck: ignore
-- 是否开启性能分析
EventDispatcher.EVENT_PERFORMANCE_ANALYSIS = false
EventDispatcher.performanceData = {}

-- 毫秒
function EventDispatcher.AddPerformanceData(funcName, t)
	if Game.GameLoopManagerV2:GetCurGameLoopStage() == Game.GameLoopManagerV2.EGameStageType.Loading then
		return
	end
	local performanceData = EventDispatcher.performanceData
	if not performanceData[funcName] then
		performanceData[funcName] = {}
	end
	table.insert(performanceData[funcName], t)
end

function EventDispatcher.SavePerformanceData()
	local dataStr = "EventCallbackFunc,CallCount,TotalTime(ms),AverageTime(ms),MaxTime(ms)\n"
	for funcName, data in pairs(EventDispatcher.performanceData) do
		local count = #data
		local totalT = 0
		local maxT = 0
		for _, t in ipairs(data) do
			totalT = totalT + t
			if t > maxT then
				maxT = t
			end
		end
		local info = string.format("%s,%s,%s,%s,%s\n", funcName, count, totalT, totalT/count, maxT)
		dataStr = dataStr .. info
	end
	local localP4Version = import("SubsystemBlueprintLibrary").GetEngineSubsystem(import("PakUpdateSubsystem")):GetLocalP4Version()	--客户端当前资源版本号
	local fileName =  string.format("event_system_profiling_%d_%s.csv", localP4Version, os.date("%Y_%m_%d_%H_%M_%S"))
	local path = import("BlueprintPathsLibrary").ProfilingDir().. fileName
	path = import("LuaFunctionLibrary").ConvertToAbsolutePathForExternalAppForRead(path)
	local file = io.open(path, "w")
	if file then
		file:write(dataStr)
		file:close()
	else
		-- 找不到文件，尝试创建目录
		local profilePath = import("BlueprintPathsLibrary").ProfilingDir()
		profilePath = import("LuaFunctionLibrary").ConvertToAbsolutePathForExternalAppForRead(profilePath)
		import("LuaFunctionLibrary").MakeDirectory(profilePath, false)
		file = io.open(path, "w")
		if file then
			file:write(dataStr)
			file:close()
		end
	end
	EventDispatcher.SendPerformanceData(dataStr, fileName)
end

function EventDispatcher.SendPerformanceData(dataStr, fileName)
	local heads = slua.Map(EPropertyClass.Str, EPropertyClass.Str)
	heads:Add("X-TOKEN", "pFC5HHxS2Fe3hbpLL8vyxYDy")
	heads:Add("X-OVERWRITE", "1")
	heads:Add("X-FILENAME", fileName)
	heads:Add("Content-Type", "text/plain")
	local callback = slua.createDelegate( function(result, content)
		Log.Debug("EventSystem performance data upload ", result and "success"  or "failed", content)
	end)
	import("C7FunctionLibrary").HttpPost("172.31.141.230:8007/engine_file_upload", heads, dataStr, callback)
end

function EventDispatcher:ctor()
	-- eventType -> target -> cbList
	self._eventDict = {}
	self._waitAddEventDict = {}
	self._waitRemoveEventDict = {}
	-- 加速搜索，缓存target -> eventType -> true or nil
	self._targetEventDict = {}
	setmetatable(self._targetEventDict, mtWeakKeyTable)
	self._lockEvent = {}
end

function EventDispatcher:dtor()
	self._eventDict = nil
	self._waitAddEventDict = nil
	self._waitRemoveEventDict = nil
	self._targetEventDict = nil
	self._lockEvent = nil
end

function EventDispatcher:AddListener(eventType, target, callback)
	if not self:checkCallback(eventType, callback, target) then
		return false
	end

	if self._lockEvent[eventType] then
		for index, eventGroup in ipairs(self._waitRemoveEventDict) do
			if eventGroup[1] == eventType and eventGroup[2] == target and eventGroup[3] == callback and eventGroup[4] == nil then
				table_remove(self._waitRemoveEventDict, index)
				return true
			end
		end

		self._waitAddEventDict[#self._waitAddEventDict + 1] = {eventType, target, callback}
		return true
	end

	-- 检查是否重复添加
	if self._eventDict[eventType] and self._eventDict[eventType][target] then
		for _, cb in ipairs(self._eventDict[eventType][target]) do
			if cb == callback then
				Log.ErrorFormat("[EventSystem] AddListener repeat add, eventType: %s", eventType)
				return false
			end
		end
	end


	if not self._eventDict[eventType] then
		local targetDict = {}
		setmetatable(targetDict, mtWeakKeyTable)
		self._eventDict[eventType] = targetDict
	end
	local targetDict = self._eventDict[eventType]
	if not targetDict[target] then
		targetDict[target] = {}
	end
	local cbList = targetDict[target]
	cbList[#cbList + 1] = callback
	if not self._targetEventDict[target] then
		self._targetEventDict[target] = {}
	end
	self._targetEventDict[target][eventType] = true
	return true
end

function EventDispatcher:RemoveListener(eventType, target, callback)
	if self._lockEvent[eventType] then
		for index, eventGroup in ipairs(self._waitAddEventDict) do
			if eventGroup[1] == eventType and eventGroup[2] == target and eventGroup[3] == callback and eventGroup[4] == nil then
				table_remove(self._waitAddEventDict, index)
				return true
			end
		end

		self._waitRemoveEventDict[#self._waitRemoveEventDict + 1] = {eventType, target, callback}
		return true
	end

	local eventDict = self._eventDict[eventType]
	if not eventDict or not eventDict[target] then
		return false
	end
	if not self:_isEventInEventGroup(eventDict[target], callback) then
		return false
	end


	for index, cb in ipairs(eventDict[target]) do
		if cb == callback then
			table_remove(eventDict[target], index)
			if #eventDict[target] == 0 then
				eventDict[target] = nil
				if not next(eventDict) then
					self._eventDict[eventType] = nil
				end
				local targetEventDict = self._targetEventDict[target]
				targetEventDict[eventType] = nil
				if not next(targetEventDict) then
					self._targetEventDict[target] = nil
				end
			end
			return true
		end
	end
	return false
end

function EventDispatcher:RemoveTargetListener(target)
	-- 遍历删除优化，O(n)算法
	local waitAddEventDict = self._waitAddEventDict
	local count = #waitAddEventDict
	if count > 0 then
		local curIndex = 1
		for i = 1, count, 1 do
			local eventGroup = waitAddEventDict[i]
			waitAddEventDict[i] = nil
			if eventGroup[2] ~= target then
				-- 不删除，往前移
				waitAddEventDict[curIndex] = eventGroup
				curIndex = curIndex + 1
			end
		end
		if not table.IsArray(waitAddEventDict) then
			Log.Error("iter remove algorithm error")
		end
	end

	local waitRemoveEventDict = self._waitRemoveEventDict
	count = #waitRemoveEventDict
	local targetEventDict = self._targetEventDict[target]
	if targetEventDict then
		local eventDict = self._eventDict
		local hasLock = false
		local lockEvent = self._lockEvent
		for eventType, _ in pairs(targetEventDict) do
			local eventGroup = eventDict[eventType]
			if lockEvent[eventType] then
				for _, cb in ipairs(eventGroup[target]) do
					waitRemoveEventDict[count + 1] = {eventType, target, cb}
					count = count + 1
				end
				hasLock = true
			else
				eventGroup[target] = nil
				targetEventDict[eventType] = nil
				if not next(eventGroup) then
					eventDict[eventType] = nil
				end
			end
		end
		if not hasLock then
			self._targetEventDict[target] = nil
		end
	end
end

function EventDispatcher:TriggerEvent(eventType, ...)
	if self._lockEvent[eventType] and self._lockEvent[eventType] > MAX_DISPATCH_COUNT then
		Log.ErrorFormat("[EventSystem] triggerEvent dead cycle, %s", eventType)
		return false
	end
	if not self._lockEvent[eventType] then
		self._lockEvent[eventType] = 0
	end
	self._lockEvent[eventType] = self._lockEvent[eventType] + 1
	local waitRemoveEventDict = self._waitRemoveEventDict
	if self._eventDict[eventType] then
		for target, cbList in pairs(self._eventDict[eventType]) do
			for _, cbName in ipairs(cbList) do
				local func = cbName
				if type(cbName) == "string" then
					func = target[cbName]
				end
				local isRemove = false
				for _, eventGroup in ipairs(waitRemoveEventDict) do
					if eventGroup[1] == eventType and eventGroup[2] == target and eventGroup[3] == cbName and eventGroup[4] == nil then
						isRemove = true
						break
					end
				end
				if not isRemove then
					if func then
						if EventDispatcher.EVENT_PERFORMANCE_ANALYSIS then
							local GetGameMicrosecond = ULLFunc.GetGameMicrosecond
							local info = debug.getinfo(func, "Sl")
							local funcName = string.format("%s:%s", info.short_src, info.linedefined)
							local t1 = GetGameMicrosecond()
							xpcall(func, _G.CallBackError, target, ...)
							local t2 = GetGameMicrosecond()
							EventDispatcher.AddPerformanceData(funcName, (t2 - t1) / 1000.0)
						else
							xpcall(func, _G.CallBackError, target, ...)
						end
					else
						Log.ErrorFormat("[EventSystem] callback func:%s not exist, %s",cbName, eventType)
					end
				end
			end
		end
	end
	self._lockEvent[eventType] = self._lockEvent[eventType] - 1
	if self._lockEvent[eventType] <= 0 then
		self._lockEvent[eventType] = nil
	end
	if next(self._lockEvent) then
		return true
	end

	for i = #waitRemoveEventDict, 1, -1 do
		local eventGroup = waitRemoveEventDict[i]
		self:RemoveListener(eventGroup[1], eventGroup[2], eventGroup[3])
		waitRemoveEventDict[i] = nil
	end

	local waitAddEventDict = self._waitAddEventDict
	for i = #waitAddEventDict, 1, -1 do
		local eventGroup = waitAddEventDict[i]
		self:AddListener(eventGroup[1], eventGroup[2], eventGroup[3], eventGroup[4])
		waitAddEventDict[i] = nil
	end
	return true
end

function EventDispatcher:checkCallback(eventType, callback, target)
	if true then
		if eventType == nil then
			Log.Error("[EventSystem] checkCallback error, eventType is nil")
			return false
		end
		local targetType = type(target)
		if targetType ~= "table" and targetType~="userdata" then
			Log.ErrorFormat("[EventSystem] targetType error, eventType:%s, target type: %s", eventType, targetType)
			return false
		end
		if type(callback) ~= "string" and type(callback) ~= "function" then
			Log.ErrorFormat("[EventSystem] callback error, eventType:%s, callback type: ", eventType, type(callback))
			return false
		end
		if type(callback) == "string" and type(target[callback]) ~= "function" then
			Log.ErrorFormat("[EventSystem] callback error, eventType:%s, callback func type: %s", eventType, type(callback))
			return false
		end
	end
	return true
end

function EventDispatcher:_isEventInEventGroup(cbItemList, callback)
	for _, cb in ipairs(cbItemList) do
		if cb == callback then
			return true
		end
	end
	return false
end

function EventDispatcher:IsEventSubscribed(EventType)
	if self._eventDict[EventType] then
		return true
	end
	return false
end

function EventDispatcher:IsEmpty()
	if next(self._eventDict) then
		return false
	end
	return true
end

function EventDispatcher:Clear()
	table_clear(self._eventDict)
	table_clear(self._waitAddEventDict)
	table_clear(self._waitRemoveEventDict)
	table_clear(self._targetEventDict)
	table_clear(self._lockEvent)
end

return EventDispatcher