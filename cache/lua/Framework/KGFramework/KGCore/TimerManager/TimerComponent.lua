-- luacheck: push ignore
---@class TimerComponent @计时器接口的封装其他,需要使用计时器的类继承这个类就好了
local TimerComponent = DefineClass("TimerComponent")

function TimerComponent:ctor()
    self.timers = {}
    self.timerCount = 0
end

---StartTimer 启用一个定时器
---@param key string 定时器key
---@param func function? 定时器回调函数
---@param duration number? 定时器时间
---@param loop number 定时器循环次数 填-1一直循环
---@param isGameTime boolean? 时间是否受缩放影响 default:false
---@param immediateExecute boolean? 开始定时器后是否立即执行一次回调
---@param endCallback function? 定时器结束时回调
function TimerComponent:StartTimer(key, func, duration, loop, isGameTime, immediateExecute, endCallback, tracebackLevel)
	if self.timers[key] then
		self:StopTimer(key)
	end
	if not func then
		Log.ErrorFormat("UIFrame.TimerComponent:StartTimer 回调函数不能为空 key:%s", key)
		return
	end
	local timerId = Game.TimerManager:StartTimeBindIns(nil, func, duration, loop, isGameTime, key, immediateExecute, endCallback, tracebackLevel ~= nil and tracebackLevel or 4)
	self.timers[key] = timerId
	return timerId
end

function TimerComponent:StartTimerBindIns(key, func, duration, loop, isGameTime, immediateExecute, endCallback, tracebackLevel)
	if self.timers[key] then
		self:StopTimer(key)
	end
	if not func then
		Log.ErrorFormat("UIFrame.TimerComponent:StartTimer 回调函数不能为空 key:%s", key)
		return
	end
	local timerId = Game.TimerManager:StartTimeBindIns(self, func, duration, loop, isGameTime, key, immediateExecute, endCallback, tracebackLevel ~= nil and tracebackLevel or 4)
	self.timers[key] = timerId
	return timerId
end

---StartTickTimer 启动并创建一个帧定时器
---@param key string 定时器key
---@param func function 回调函数
---@param loop number 定时器循环次数 填-1一直循环
---@param immediateExecute boolean 是否立即执行一次
function TimerComponent:StartTickTimer(key, func, loop, immediateExecute)
    return self:StartTimer(key, func, 0, loop, true, immediateExecute, nil, 4)
end

function TimerComponent:StartTickTimerBindIns(key, func, loop, immediateExecute)
	return self:StartTimerBindIns(key, func, 0, loop, true, immediateExecute, nil, 4)
end

---StopTimer 结束一个定时器
---@param key string|number 定时器key
---@param actNow boolean 停止的时候是否触发一次callback
function TimerComponent:StopTimer(key, actNow)
    local timer = self.timers[key]
    if timer then
        Game.TimerManager:StopTimerAndKill(timer, actNow)
    elseif type(key) == "number" then
        Game.TimerManager:StopTimerAndKill(key, actNow)
    end
	self.timers[key] = nil
end

---PauseTimer 暂停一个定时器
---@param key string 定时器key
function TimerComponent:PauseTimer(key)
    if self.timers[key] then
        Game.TimerManager:PauseTimer(self.timers[key])
    end
end

---@public
function TimerComponent:StopAllTimer()
	if self.timers then
		for k, v in pairs(self.timers) do
			Game.TimerManager:StopTimerAndKill(v)
			self.timers[k] = nil
		end
	end
end

function TimerComponent:StartCoroutine(key, ...)
    local stage = 1
    local funcs = {...}
    local timerFunc = function()
        local f = funcs[stage]
        if not f then
            self:StopTimer(key)
        end
        local ok, ret = xpcall(f, debug.traceback)
        if not ok then
            Log.ErrorFormat("UIFrame.TimerComponent.StartCoroutine key:%s, %s", key, ret)
        end

        if ret then
            stage = stage + 1
            if stage > #funcs then
                self:StopTimer(key)
            end
        end
    end
    Game.TimerManager:CreateTimerAndStart(timerFunc, 0, -1, true)
end

function TimerComponent:StopCoroutime(key)
    self:StopTimer(key)
end

---延迟帧调用
---@param key string 唯一标识位
---@param count number 延迟几帧
---@param ... table 执行函数列表
function TimerComponent:StepCall(key, count, ...)
    self:StartCoroutine(key, self:WaitForFrame(count), ...)
end

---条件完成调用
---@param key string 唯一标识位
---@param request table 必须要有一个isDone 字段
---@param action function 执行函数
function TimerComponent:RequestCall(key, request, action)
    local func = function()
        if not request then
            if action then
                action()
            end
            return true
        end

        if request.isDone then
            if action then
                action()
            end
            return true
        end
        return false
    end

    self:StartCoroutine(key, func)
end

function TimerComponent:WaitForFrame(count)
    count = count or 1
    local func = function()
        count = count - 1
        return count <= 0
    end
    return func
end

function TimerComponent:IsTimerExist(key)
	local timerId = self.timers[key]
	return timerId and Game.TimerManager:IsTimerExist(timerId)
end

function TimerComponent:WaitForSeconds(second)
    second = second or 1
    local expire = 0
    local start = false
    local func = function()
        if not start then
            start = true
            expire = os.gameRealTimeMS + second
        end
        return os.gameRealTimeMS >= expire
    end
    return func
end

return TimerComponent

-- luacheck: pop