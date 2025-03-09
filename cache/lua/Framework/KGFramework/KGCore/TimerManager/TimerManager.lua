local TimerWheel = kg_require("Framework.KGFramework.KGCore.TimerManager.TimerWheel")
local TimerTask = kg_require("Framework.KGFramework.KGCore.TimerManager.TimerTask")
local timerConst = kg_require("Framework.KGFramework.KGCore.TimerManager.TimerConst")
local LowLevelFunctions_GetUtcMillisecond = import("LowLevelFunctions").GetUtcMillisecond
local EPropertyClass = import("EPropertyClass")

--local PerfSightHelper_PostFrame = import("PerfSightHelper").PostFrame

---@class TimerManager
local TimerManager = DefineClass("TimerManager")

function TimerManager:ctor()
    self.lastRealTimeSeconds = 0
    self.timerIdIndex = 0
    ---@type TimerWheel
    self.gameTimeWheel = nil
    ---@type TimerWheel
    self.realTimeWheel = nil
    ---@type TimerTask[]
    self.timerFreePool = {}
    ---@type table<number, TimerTask>
    self.timerRunPool = {}
    ---@type table<number, TimerTask> 在TimerManager Tick结束后再处理的timertask，避免逻辑错误
    self.bePostProcessTimers = {}
	self.performanceAnalysis = {}
    self:init()
end

------------- 对外接口-----------------------------------

---CreateTimerAndStart 开始一个定时器
---@param func function 定时器回调函数
---@param duration number 定时器时间 单位毫秒
---@param loop number 定时器循环次数 填-1一直循环
---@param isGameTime boolean? 游戏时间true 真实时间false default:false
---@param key string? 用来标记这个定时器是谁的（方便排查问题，可以不传）
---@param immediateExecute boolean? 开始定时器后是否立即执行一次回调
---@param endCallback function? 定时器结束时回调
function TimerManager:CreateTimerAndStart(func, duration, loop, isGameTime, key, immediateExecute, endCallback, tracebackLevel)
	return self:StartTimeBindIns(nil, func, duration, loop, isGameTime, key, immediateExecute, endCallback, tracebackLevel ~= nil and tracebackLevel or 3)
end

---StartTimeBindIns 开始一个定时器
---@param instance table 回调函数所属instance
---@param func function 定时器回调函数
---@param duration number 定时器时间 单位毫秒
---@param loop number 定时器循环次数 填-1一直循环
---@param isGameTime boolean? 游戏时间true 真实时间false default:false
---@param key string? 用来标记这个定时器是谁的（方便排查问题，可以不传）
---@param immediateExecute boolean? 开始定时器后是否立即执行一次回调
---@param endCallback function? 定时器结束时回调
function TimerManager:StartTimeBindIns(instance, func, duration, loop, isGameTime, key, immediateExecute, endCallback, tracebackLevel)
	if string.isEmpty(func) or duration == nil or duration < 0 or duration >= timerConst.TimerDurationLimit or loop == nil then
		Log.Error("Start Timer error, parameter exception")
		return
	end
	local timer = self:getFreeTimer(key)
	self.timerRunPool[timer.timerId] = timer
	timer:init(instance, func, duration, loop, isGameTime, immediateExecute, endCallback, tracebackLevel ~= nil and tracebackLevel or 3)
	timer:Start()
	if timerConst.DebugModel then
		Log.InfoFormat("TimerManager:开启Timer ID:%s, Key: %s", timer.timerId, timer.key)
	end
	self.bePostProcessTimers[timer.timerId] = timer
	if timer.immediateExecute then
		timer:executeCallback(0)
		if timer.state == TimerTask.STATE.WAIT_STOP then --可能在第一次执行的时候timer就结束了
			self:StopTimerAndKill(timer.timerId)
			return
		end
	end
	return timer.timerId
end

---Tick 创建并开始一个每帧定时器
---@param func function 定时器回调函数
---@param loop number 定时器循环次数 填-1一直循环
function TimerManager:TickTimer(func, loop)
    return self:CreateTimerAndStart(func, 0, loop, true)
end

function TimerManager:TickTimerBindIns(instance, funcName, loop)
	return self:StartTimeBindIns(instance, funcName, 0, loop, true)
end

---StopTimerAndKill 停止并销毁一个定时器
---@param timerId number 定时器Id
---@param actNow boolean 停止的时候是否触发一次callback
function TimerManager:StopTimerAndKill(timerId, actNow)
	local timer = self.timerRunPool[timerId]
	if timer and timer:Stop(actNow) then
		if timerConst.DebugModel then
			Log.InfoFormat("TimerManager:停止Timer ID:%s, Key: %s", timerId, timer.key)
		end
		self:recycleTimer(timer)
	end
end

---@param timerId number 定时器Id
function TimerManager:PauseTimer(timerId)
    local timer = self.timerRunPool[timerId]
    if timer then
        if timerConst.DebugModel then
            Log.InfoFormat("TimerManager:暂停Timer ID:%s, Key: %s", timerId, timer.key)
        end
        timer:Pause()
    end
end

function TimerManager:ResumeTimer(timerId)
    local timer = self.timerRunPool[timerId]
    if not timer then
        Log.WarningFormat("TimerManager:尝试恢复一个不存在的Timer ID:%s, %s", timerId, debug.traceback())
        return
    end
    if timer:Resume() then
        if timerConst.DebugModel then
            Log.InfoFormat("TimerManager:恢复Timer ID:%s, Key: %s", timerId, timer.key)
        end
        self:pushTimerToWheel(timer)
    end
end

function TimerManager:IsTimerExist(timerId)
	local timer = self.timerRunPool[timerId]
	return timer and timer.state ~= TimerTask.STATE.WAIT_STOP and timer.state ~= TimerTask.STATE.STOP
end

--------------内部实现---------------------------------
function TimerManager:init()
    self.gameTimeWheel = self:createTimerWheel()
    self.realTimeWheel = self:createTimerWheel()
end

function TimerManager:UpdateTick(deltaTime, timeSeconds, realTimeSeconds)
    SetNow(LowLevelFunctions_GetUtcMillisecond())
    SetGameTimeSeconds(timeSeconds, realTimeSeconds)
    UIManager:GetInstance():OnIdle(deltaTime)
	 ----for PerfSight
	 --import("PerfSightHelper").PostFrame(deltaTime)
	 ----for PerfSight

    realTimeSeconds = realTimeSeconds * 1000
    self.gameTimeWheel:UpdateTick(deltaTime*1000)
    self.realTimeWheel:UpdateTick(realTimeSeconds - self.lastRealTimeSeconds)
    self.lastRealTimeSeconds = realTimeSeconds
    
    for i, timer in pairs(self.bePostProcessTimers) do
        self.bePostProcessTimers[i] = nil
        if timer.state == timer.STATE.WAIT_START then
            timer.state = timer.STATE.RUN
            self:pushTimerToWheel(timer)         
        end
    end
end

function TimerManager:executeTimer(timer)
    timer:UnbindTimerWheel()
    timer:Execute()
    self:postProcessTimer(timer)
end

function TimerManager:postProcessTimer(timer)
    if timer.state == timer.STATE.WAIT_RUN then
        self:ContinueStartTimer(timer.timerId)
    elseif timer.state == timer.STATE.WAIT_STOP then
        self:StopTimerAndKill(timer.timerId)
    end
end

--- 循环定时器重新执行下一次定时任务
---@param timerId number 定时器Id
function TimerManager:ContinueStartTimer(timerId)
    local timer = self.timerRunPool[timerId]
    if timer and timer:Run() then
        self:pushTimerToWheel(timer)
    end
end

function TimerManager:createTimerWheel()
    local config = timerConst.TimeWheelConfig
    local preTimerWheel = nil
    local timerWheel = {}
    for i, v in ipairs(config) do
        local wheel = TimerWheel.new(v)
        wheel:SetPrevWheel(preTimerWheel)
        if preTimerWheel then
            preTimerWheel:SetNextWheel(wheel)
        else
            timerWheel = wheel
        end
        preTimerWheel = wheel
    end
    return timerWheel
end

function TimerManager:pushTimerToWheel(timer)
    if timer.isGameTime then
        self.gameTimeWheel:addTimer(timer)
    else
        self.realTimeWheel:addTimer(timer)
    end
end

function TimerManager:getFreeTimer(key)
    local timerId = self:newTimerId()
    local pool = self.timerFreePool
    local freeCount = #pool
    if freeCount > 0 then
        local timer = pool[freeCount]
        table.remove(pool, freeCount)
        timer:setIdKey(timerId, key)
		return timer
    end
    return TimerTask.new(timerId, key)
end

function TimerManager:recycleTimer(timer)
    self.timerRunPool[timer.timerId] = nil
    self.timerFreePool[#self.timerFreePool + 1] = timer
end

function TimerManager:newTimerId()
    self.timerIdIndex = self.timerIdIndex + 1
    if self.timerIdIndex > 4294967296 then
        self.timerIdIndex = 1
    end
    if self.timerRunPool[self.timerIdIndex] then
        return self:newTimerId()
    end
    return self.timerIdIndex
end

function TimerManager:uninit()
    self.timerIdIndex = 0
    self.gameTimeWheel = nil
    self.realTimeWheel = nil
    self.timerFreePool = nil
    self.timerRunPool = nil
	self.performanceAnalysis = nil
end

function TimerManager:dtor()
    self:uninit()
end
-- luacheck: push ignore
function TimerManager:AppAddListener()
    if IsValid_L(self.TickableObj) then
        return
    end
    self.lastRealTimeSeconds = import("GameplayStatics").GetRealTimeSeconds(_G.GetContextObject())
	local WrapFunc = function(DeltaTime,timeSeconds,realTimeSeconds)
        self:UpdateTick(DeltaTime,timeSeconds,realTimeSeconds)
	end
	local TickableObj = import("LuaTickableObject")(Game.WorldContext)
	TickableObj.OnLuaTick:Bind(WrapFunc)
	self.TickableObj = TickableObj
end
-- luacheck: pop

--region 性能统计

function TimerManager:AddTimerCaller(timerCaller, callbackName)
	if timerConst.PerformanceAnalysis and not self.performanceAnalysis[timerCaller] then
		self.performanceAnalysis[timerCaller] = {TimerCaller = timerCaller, CallbackName = callbackName == nil and "" or callbackName, CallCount = 0, TotalTime = 0, AverageTime = 0, MaxTime = 0}
	end
end

---CollectPerformanceData 收集timer调用耗时数据
---@param timerCaller string timer调用者
---@param timeConsuming number timer调用耗时
function TimerManager:CollectPerformanceData(timerCaller, timeConsuming)
	if timerConst.PerformanceAnalysis then
		if Game.GameLoopManagerV2:GetCurGameLoopStage() == Game.GameLoopManagerV2.EGameStageType.Loading then
			return
		end
		local timerData = self.performanceAnalysis[timerCaller]
		timerData.CallCount = timerData.CallCount + 1
		timerData.TotalTime = timerData.TotalTime + timeConsuming
		timerData.AverageTime = timerData.TotalTime / timerData.CallCount
		if timeConsuming > timerData.MaxTime then
			timerData.MaxTime = timeConsuming
		end
	end
end

---ClearPerformanceData 清理timer调用耗时数据
function TimerManager:ClearPerformanceData()
	table.clear(self.performanceAnalysis)
end

---GetPerformanceData 输出timer调用耗时数据
function TimerManager:OutputPerformanceData(outputCount, bReport)
	local performanceAnalysisList = table.values(self.performanceAnalysis)
	table.sort(performanceAnalysisList, function(a, b)
		if a.AverageTime == b.AverageTime then
			if a.MaxTime == b.MaxTime then
				return a.CallCount > b.CallCount
			end
			return a.MaxTime > b.MaxTime
		end
		return a.AverageTime > b.AverageTime
	end)
	local localP4Version = import("SubsystemBlueprintLibrary").GetEngineSubsystem(import("PakUpdateSubsystem")):GetLocalP4Version()	--客户端当前资源版本号
	local fileName =  string.format("timer_profiling_%d_%s.csv", localP4Version, os.date("%Y_%m_%d_%H_%M_%S"))
	local path = import("BlueprintPathsLibrary").ProfilingDir().. fileName
	path = import("LuaFunctionLibrary").ConvertToAbsolutePathForExternalAppForRead(path)
	local dataStr = "TimerCall,CallbackName,CallCount,TotalTime(ms),AverageTime(ms),MaxTime(ms)\n"
	outputCount = (outputCount == nil or outputCount >= #performanceAnalysisList) and #performanceAnalysisList or outputCount
	for i = 1, outputCount do
		local v = performanceAnalysisList[i]
		if v.CallCount > 0 then
			dataStr = dataStr .. string.format("%s,%s,%d,%f,%f,%f\n", v.TimerCaller, v.CallbackName, v.CallCount, v.TotalTime/1000, v.AverageTime/1000, v.MaxTime/1000)
		end
	end
	if bReport then
		local heads = slua.Map(EPropertyClass.Str, EPropertyClass.Str)
		heads:Add("X-TOKEN", "vwjt9ti66TR6WZV8Vu4JHETy")
		heads:Add("X-OVERWRITE", "1")
		heads:Add("X-FILENAME", fileName)
		heads:Add("Content-Type", "text/plain")
		local callback = slua.createDelegate( function(result, content)
			Log.Debug("Timer performance data upload ", result and "success"  or "failed", content)
		end)
		import("C7FunctionLibrary").HttpPost("172.31.141.230:8006/engine_file_upload", heads, dataStr, callback)
	end
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
end

-- 定时手动gc
function TimerManager:StartManualGC()
	if self.gcTimer then
		return
	end
	collectgarbage("stop")
	self.gcTimer = self:CreateTimerAndStart(function()
		collectgarbage("collect")
	end, 15000, -1)
end
--endregion 性能统计

return TimerManager