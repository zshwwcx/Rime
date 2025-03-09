-- GlobalUnlock(_G)
-- _G.C7 = _G.C7 or {}
-- local C7 = _G.C7

-- C7.component = "client"

-- C7.cache = C7.cache or {}
-- C7.global = C7.global or {}
-- C7.global.model = C7.global.model or {}
-- C7.global.configs = C7.global.configs or {}
-- C7.global.settings = C7.global.settings or {}
-- C7.global.limitCallLogs = C7.global.limitCallLogs or {}
-- --C7.global.footstepInit = nil
-- C7.global.debug = C7.global.debug or {}
-- C7.global.effectContainer = C7.global.effectContainer or {
--     guid = 0,
--     count = 0,
--     effects = {}
-- }
-- C7.global.ufxContainer = C7.global.ufxContainer or {
--     count = 0
-- }
-- C7.global.gbId2SnapShotInfo = {}
-- C7.global.proxy = C7.global.proxy or {}
-- C7.global.bullets = C7.global.bullets or {}
-- C7.global.bulletIndex = C7.global.bulletIndex or 0
-- C7.global.dayStartTime = C7.global.dayStartTime or 0   -- 游戏每天开始的时间，从5点开始
-- C7.global.dayZeroTime = C7.global.dayZeroTime or 0    -- 正常每天开始的时间，从0点开始
-- C7.cmd = C7.cmd or {}

-- 需要开启打点， telnet之类的运行pg.setLuaFuncHook(C7.luaFuncHook)
-- 关闭打点，C7.resetLuaFuncHook()
-- C7.luaFuncHook = function(func, ...)
--     local funcInfo = debug.getinfo(func)
--     local funcDesc = string.format("%s:%s", funcInfo.short_src, funcInfo.linedefined)
--     if (SampleUtil.SampleOn()) then SampleUtil.BeginSample(funcDesc) end
--     local r1, r2, r3 ,r4, r5 = func(...)
--     if (SampleUtil.SampleOn()) then SampleUtil.EndSample() end
--     return r1, r2, r3, r4, r5
-- end

-- C7.startRecordFrame = function()
--     C7.startFrameCount = Time.frameCount
--     C7.startFrameTime = Time.time
-- end

-- C7.stopRecordFrame = function()
--     local totalFrame = Time.frameCount - C7.startFrameCount
--     local totalTime = Time.time - C7.startFrameTime
-- end

-- C7.callback = function(...)
--     local stage = 1
--     local funcs = {...}
--     local timerFunc = function(id)
--         local f = funcs[stage]
--         if not f then
--             -- print("stop timer!!!")
--             return C7.cancelTimer(id)
--         end

--         -- print("timerFunc >>", stage)
--         local ok, ret = xpcall(f, debug.traceback)
--         if not ok then
--             LOG_ERROR(ret)
--         end
--         -- print("timerFunc <<", stage, ret)

--         if not ok or not ret then
--             stage = stage + 1
--         end
--     end

--     return C7.addFrameTimer(1, 1, timerFunc)
-- end

-- C7.callbackBeat = function(...)
--     local stage = 1
--     local funcs = {...}
--     local timerFunc = function(id)
--         local f = funcs[stage]
--         if not f then
--             -- print("stop timer!!!")
--             return C7.cancelTimer(id)
--         end

--         -- print("timerFunc >>", stage)
--         local ok, ret = xpcall(f, debug.traceback)
--         if not ok then
--             LOG_ERROR(ret)
--         end
--         -- print("timerFunc <<", stage, ret)

--         if not ok or not ret then
--             stage = stage + 1
--         end
--     end

--     return C7.addTimer(1, 1, timerFunc)
-- end

-- C7.cancel = function(timerId)
--     C7.cancelTimer(timerId)
-- end

-- C7.step = function(count)
--     count = count or 1
--     local func = function()
--         count = count - 1
--         return count > 0
--     end

--     return func
-- end

-- C7.wait = function(time)
--     time = time or 1
--     local expire = 0
--     local start = false
--     local func = function()
--         if not start then
--             start = true
--             expire = Time.realtimeSinceStartup + time
--         end
--         return Time.realtimeSinceStartup < expire
--     end

--     return func
-- end

-- C7.waitRequest = function(request, action)
--     local func = function()
--         if not request then
--             if action then
--                 action()
--             end
--             return false
--         end

--         if not request.isDone then
--             return true
--         end

--         if action then
--             action()
--         end
--         return false
--     end

--     C7.callback(func)
-- end

-- C7.stepcall = function(count, ...)
--     C7.callback(C7.step(count), ...)
-- end

-- C7.waitcall = function(count, ...)
--     return C7.callback(C7.wait(count), ...)
-- end

-- return _G.C7