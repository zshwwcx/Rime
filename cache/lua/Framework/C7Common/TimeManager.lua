---@class TimeManager
---@field private cppMgr KGTime
TimeManager = DefineClass("TimeManager")
local HOURMILLISECOND = 3600000
function TimeManager:Init()
    self.osTime = os.time
    self.cppMgr = import("KGTime")(Game.WorldContext)
    Game.GameInstance:CacheManager(self.cppMgr)
    self.cppMgr:NativeInit()

    ----------------------------------------------------------------------------
    --- 覆写全局设定
    --- 只在运行时生效

    --- Q: 为什么不直接修改time.lua的实现？
    --- A: 因为技能编辑器、剧情编辑器等编辑器以来time.lua
    --- 的实现，这些编辑器需要自由控制时间，不能使用TimeManager这种无法回退的时间，所以
    --- 只会在游戏运行时覆写全局设定，保证游戏运行时的时间是正确的。

    if _G.GAME_RUNTIME then
        function SetNow(t, force)
        end

        ---返回当前时间（设备本地时间，不可信，可以通过调整设备时间修改），ms值
        ---@public
        ---@param number unit 0:微秒，1：秒，nil：毫秒
        ---@return integer 向上取整
        _G._NOW0 = function(unit)
            return Game.TimeManager:Now(unit)
        end

        ---返回当前时间(服务器时间)，ms值
        ---@public
        ---@param unit number|nil 0:微秒，1：秒，nil：毫秒
        ---@return integer
        _G._now = function(unit)
            local timeMgr = Game.TimeManager
            if timeMgr and timeMgr:IsValid() then
                return timeMgr:Now(unit)
            end
            return os.TIME0()
        end
    end
    ----------------------------------------------------------------------------
end

function TimeManager:UnInit()
    self.cppMgr:NativeUninit()
    self.cppMgr = nil
end

function TimeManager:IsValid()
    return self.cppMgr ~= nil
end

---@param unit number @ 时间单位， 0：微妙， 1：秒，nil：毫秒
---@return number
function TimeManager:GetFactor(unit)
    if not unit then
        unit = 0.001
    end

    if unit <= 0 then
        unit = 0.000001
    end

    return unit
end

--- 获取unix时间戳
---@param unit number @ 时间单位， 0：微妙， 1：秒，nil：毫秒
---@return number @ 返回当前时间(unix时间戳)
function TimeManager:Now(unit)
    local cppMgr = self.cppMgr
    local milliseconds = cppMgr and cppMgr:UtcNow() or self.osTime() * 1000
    unit = self:GetFactor(unit)
    return math.floor(milliseconds * (0.001 / unit))
end

--- 同步CS服务端时间 毫秒级
---@param serverTime number @ 服务端时间，毫秒数
---@param rtt number @ RTT，毫秒数
---@param serverTimeZone number @ 服务端时区，单位：小时
function TimeManager:AdjustClientTimeWithServer(serverTime, rtt, serverTimeZone)
    assert(serverTime, "serverTime is nil")

    serverTime = serverTime + rtt or 0

    if not serverTimeZone then
        serverTimeZone = self.serverTimeZone
    end

    Log.DebugFormat("[LogKGTime]Lua AdjustClientTimeWithServer timestamp:%d, timeZone:%d", serverTime, serverTimeZone)

    local cppMgr = self.cppMgr
    if cppMgr then
        cppMgr:AdjustClientTimeWithServer(serverTime, serverTimeZone)
        -- cppMgr:Dump()
    end
end

function TimeManager:SetServerTimeZone(serverTimeZone)
    self.serverTimeZone = serverTimeZone

    local cppMgr = self.cppMgr
    if cppMgr then
        cppMgr:SetServerTimeZone(serverTimeZone)
    end

    Log.DebugFormat("[KGTime]Server time zone: %d", serverTimeZone)
end

function TimeManager:GetServerDateStr()
    return self.cppMgr:GetServerTimeString()
end

function TimeManager:GetClientDateStr()
    return self.cppMgr:GetClientTimeString()
end

function TimeManager:GetLocalDateStr()
    return self.cppMgr:GetLocalTimeString()
end

return TimeManager