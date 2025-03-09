local timerConst = kg_require("Framework.KGFramework.KGCore.TimerManager.TimerConst")
---@class TimerTask
local TimerTask = DefineClass("TimerTask")

local GetGameMicrosecond = import("LowLevelFunctions").GetGameMicrosecond

--定时器任务状态
TimerTask.STATE =
{
    WAIT_START = 1,
    RUN = 2,
    PAUSE = 3,
    WAIT_RUN = 4,
    WAIT_STOP = 5,
    STOP = 6,
}

function TimerTask:ctor(id, key)
    self.duration = 0 --timer调用间隔时间
    self.accumulatedTime = 0  --special类型计时器tick过程中累积时间
    self.callBack = nil	--回调函数
	self.instanceOfCallback = setmetatable({}, {__mode = "v"}) --回调函数所属对象
	self.endCallback = nil --timer结束时回调函数
    self.totalTick = 0 --总共执行时间轮tick次数
    self.loop = 0	--timer执行次数
    self.gameTimeWheel = nil --所属时间轮
    self.state = TimerTask.STATE.STOP --timer当前状态
    self.remainTick = 0		--时间轮剩余tick次数
    self.wheelsRemainTick = {} --每级时间轮tick次数
    self.tickPos = 0 	--当前所在时间轮的刻度位置
    self.bCalculateDebt = false --当前需要在后续补回欠下的时间
    self.debtTotalTime = 0		--当前欠下的时间
    self.tickDebtTime = 0   --每次放置在时间轮后欠下的时间
	self.tickTypeRemainTime = 0 --tick类型的timer 上次执行完后剩余的时间
	self.timerCaller = nil --调用者堆栈信息
    self:setIdKey(id, key)
end

function TimerTask:setIdKey(id, key)
    self.timerId = id
    self.key = key
end

function TimerTask:init(instance, func, duration, loop, isGameTime, immediateExecute, endCallback, tracebackLevel)
	self.accumulatedTime = 0
	self.debtTotalTime = 0
	self.tickPos = 0
	self.tickTypeRemainTime = 0
	
    self.isGameTime = isGameTime
    self.duration = duration
    self.callBack = func
	if instance then
		self.instanceOfCallback[1] = instance
	end
    self.totalTick = math.floor(duration / timerConst.TickTime)
    table.clear(self.wheelsRemainTick)
    self.remainTick = self.totalTick
    self.loop = loop
    self.state = TimerTask.STATE.STOP
	self.immediateExecute = immediateExecute
    self.endCallback = endCallback
    self.tickDebtTime = duration % timerConst.TickTime
    self.bCalculateDebt = self.tickDebtTime ~= 0

	if timerConst.DebugModel or timerConst.PerformanceAnalysis then
		local info = debug.getinfo(tracebackLevel, "Sl")
		self.timerCaller = info.source ..":" .. tostring(info.currentline)
		Game.TimerManager:AddTimerCaller(self.timerCaller, instance ~= nil and self.callBack or "")
	else
		self.timerCaller = nil
	end
end

function TimerTask:Start()
    if self.state == TimerTask.STATE.STOP then
        self.state = TimerTask.STATE.WAIT_START
		return true
    end
    return false
end

function TimerTask:Run()
    if self.state == TimerTask.STATE.WAIT_RUN then
        self.state = TimerTask.STATE.RUN
		return true
    end
    return false
end

function TimerTask:Stop(actNow)
    if self.state == TimerTask.STATE.STOP then
        return false
    end
    if self.state == TimerTask.STATE.RUN then
        self.gameTimeWheel:removeTimer(self)
    end

	self.state = TimerTask.STATE.STOP
	if actNow and self.callBack then
        xpcall(self.callBack, _G.CallBackError, 0)
    end
    if self.endCallback then
        xpcall(self.endCallback, _G.CallBackError)
    end
    if timerConst.DebugModel then
        Log.InfoFormat("TimerManager:停止Timer ID:%s, Key: %s", self.timerId, self.key)
    end
	
	self.callBack = nil
	self.instanceOfCallback[1] = nil
	self.gameTimeWheel = nil
	table.clear(self.wheelsRemainTick)
	return true
end

function TimerTask:Pause()
    if self.state == TimerTask.STATE.RUN then
        self.gameTimeWheel:removeTimer(self)
    end
    self.state = TimerTask.STATE.PAUSE
end

function TimerTask:Resume()
    if self.state == TimerTask.STATE.PAUSE then
        self.state = TimerTask.STATE.RUN
		return true
    end
    return false
end

function TimerTask:Execute()
    if self:isAlwaysLoop() then
        self.state = TimerTask.STATE.WAIT_RUN
	else
        self.loop = self.loop - 1
        self.state = self.loop == 0 and TimerTask.STATE.WAIT_STOP or TimerTask.STATE.WAIT_RUN
    end

    local tmpRemainTick = self.totalTick
    if self.bCalculateDebt then
       self.debtTotalTime = self.debtTotalTime + self.tickDebtTime
        if self.debtTotalTime >= timerConst.TickTime then
            self.debtTotalTime = self.debtTotalTime - timerConst.TickTime
            tmpRemainTick = math.floor((self.duration + timerConst.TickTime) / timerConst.TickTime)
        end
    end
    
    self.remainTick = tmpRemainTick
    self:executeCallback(self.duration)
end

function TimerTask:UpdateTick(deltaTime)
    self.accumulatedTime = self.accumulatedTime + deltaTime
    if self.accumulatedTime > self.duration then
        local spanTime = self.accumulatedTime - self.tickTypeRemainTime
        self.accumulatedTime = self.accumulatedTime - self.duration
        self.tickTypeRemainTime = self.accumulatedTime
        if not self:isAlwaysLoop() then
            self.loop = self.loop - 1
            if self.loop == 0 then
                self.state = TimerTask.STATE.WAIT_STOP
				self.gameTimeWheel:removeTimer(self)
            end
        end
        self:executeCallback(spanTime) 
    end
end

function TimerTask:executeCallback(spanTime)
	if self.callBack then
		local isSuccess, info = nil
		if timerConst.PerformanceAnalysis and self.timerCaller then
			local startTime = GetGameMicrosecond()
			local instance = self.instanceOfCallback[1]
			if instance then
				isSuccess, info = xpcall(instance[self.callBack], _G.CallBackError, instance, spanTime, self.key)
			else
				isSuccess, info = xpcall(self.callBack, _G.CallBackError, spanTime)
			end
			Game.TimerManager:CollectPerformanceData(self.timerCaller, GetGameMicrosecond() - startTime)
		else
			local instance = self.instanceOfCallback[1]
			if instance then
				isSuccess, info = xpcall(instance[self.callBack], _G.CallBackError, instance, spanTime, self.key)
			else
				isSuccess, info = xpcall(self.callBack, _G.CallBackError, spanTime)
			end
		end
		local needStop = not isSuccess or info
		if needStop and self.state ~= TimerTask.STATE.WAIT_STOP then
			self.state = TimerTask.STATE.WAIT_STOP
			if self.gameTimeWheel then
				self.gameTimeWheel:removeTimer(self)
			end
		end
		return not needStop
	end
end

function TimerTask:isAlwaysLoop()
    return self.loop == -1
end

--是否使用特殊方式计算时间
function TimerTask:checkIsSpecialTimer()
    return self.duration < timerConst.TickThreshold --持续时间太短
end

function TimerTask:BindTimerWheel(wheel, pos)
    self.gameTimeWheel = wheel
    self.tickPos = pos
end

function TimerTask:UnbindTimerWheel()
    self.gameTimeWheel = nil
    self.tickPos = 0
end

return TimerTask