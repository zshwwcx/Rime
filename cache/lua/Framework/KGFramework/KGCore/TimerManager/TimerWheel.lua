local timerConst = kg_require("Framework.KGFramework.KGCore.TimerManager.TimerConst")
local LinkedList = require("Framework.Library.LinkedList")

---@class TimerWheel
local TimerWheel = DefineClass("TimerWheel")

function TimerWheel:ctor(capTick)
	---@type table<number, LinkedList>
    self.tickTimers = {}          -- 定时器列表
    self.specialTimers = LinkedList.new()       -- 时间太短，不适用于时间轮的定时器
    self.nextWheel = nil          -- 下一个维度的时间轮
    self.prevWheel = nil          -- 上一个维度的时间轮
    self.curTick = 0              -- 当前时间轮Tick进度
    self.capTick = capTick        -- 时间轮Tick容量
    self.timeSpan = 0
end

function TimerWheel:SetNextWheel(wheel)
    self.nextWheel = wheel
end

function TimerWheel:SetPrevWheel(wheel)
    self.prevWheel = wheel
end

---@param deltaTime number
function TimerWheel:UpdateTick(deltaTime)
    self.timeSpan = self.timeSpan + deltaTime
    while(self.timeSpan >= timerConst.TickTime) do
        self.timeSpan = self.timeSpan - timerConst.TickTime
        self:Tick()
    end
    self:UpdateSpecialTimer(deltaTime)
end

function TimerWheel:UpdateSpecialTimer(deltaTime)
	local specialTimers = self.specialTimers
	specialTimers.iteratorNode = specialTimers.headNode
	
	while(specialTimers.iteratorNode ~= nil) do
		local timer = specialTimers.iteratorNode.Value
		specialTimers.iteratorNode = specialTimers.iteratorNode.Next
		timer:UpdateTick(deltaTime)
		if timer.state == timer.STATE.WAIT_STOP then
			timer:UnbindTimerWheel()
			Game.TimerManager:StopTimerAndKill(timer.timerId)
		end
	end
end

function TimerWheel:Tick()
    self:tickUpdate()
    self:tickNextWheel()
    self:checkTimers()
end

function TimerWheel:tickUpdate()
    self.curTick = self.curTick + 1
end

function TimerWheel:tickNextWheel()
    if self.curTick >= self.capTick then
        if self.nextWheel then
            self.nextWheel:Tick()
        end
        self:resetCurTick()
    end
end

function TimerWheel:resetCurTick()
    self.curTick = 0
end

function TimerWheel:checkTimers()
    local timers = self.tickTimers[self.curTick]
    if timers and timers:GetLength() > 0 then
		timers.iteratorNode = timers.headNode
		while(timers.iteratorNode ~= nil) do
			local timer = timers.iteratorNode.Value
			timers.iteratorNode = timers.iteratorNode.Next
			timers:RemoveNodeByKey(timer.timerId)
			if self.prevWheel then
				self.prevWheel:switchWheel(timer)
			else
				Game.TimerManager:executeTimer(timer)
			end
		end
    end
end

function TimerWheel:removeTimer(timer)
	local list = self.tickTimers[timer.tickPos]
    if list and list:GetLength() > 0 and list:Contains(timer.timerId) then
		list:RemoveNodeByKey(timer.timerId)
		return
    end

	if self.specialTimers:Contains(timer.timerId) then
		self.specialTimers:RemoveNodeByKey(timer.timerId)
	end
end

-- 定时器切换到前一级时间轮
function TimerWheel:switchWheel(timer)
    timer.remainTick = timer.wheelsRemainTick[#timer.wheelsRemainTick]
    table.remove(timer.wheelsRemainTick)
    self:addTimer(timer)
end

-- 新加定时器
function TimerWheel:addTimer(timer)
	if timer:checkIsSpecialTimer() then
		self.specialTimers:InsertNode(timer.timerId, timer)
        timer:BindTimerWheel(self, 0)
        return
    end
	if not self:isBelongTimerWheel(timer) then
        local nextExecTick = timer.remainTick + self.curTick
        timer.remainTick = math.floor(nextExecTick / self.capTick)
        timer.wheelsRemainTick[#timer.wheelsRemainTick + 1] = nextExecTick % self.capTick
        self.nextWheel:addTimer(timer)
    else
        local pos = (self.curTick + timer.remainTick) % self.capTick
        local list = self.tickTimers[pos]
		if not list then
			list = LinkedList.new()
			self.tickTimers[pos] = list
		end
		list:InsertNode(timer.timerId, timer)
        timer:BindTimerWheel(self, pos)
    end
end

-- 定时器是否属于当前时间轮
function TimerWheel:isBelongTimerWheel(timer)
    return timer.remainTick < self.capTick
end

-- 是否是最外层时间轮
function TimerWheel:isFirstTimerWheel()
    return self.prevWheel == nil
end

-- 是否是最里层时间轮
function TimerWheel:isEndTimerWheel()
    return self.nextWheel == nil
end

return TimerWheel