local ULowLevelFunctions = import("LowLevelFunctions")
--时间/日期相关
_G.TimeUtils = {}

local DAYMILLISECOND = 86400000
local HOURMILLISECOND = 3600000
local MINUTEMILLISECOND = 60000
local WEEKMILLISECOND = 604800000
TimeUtils.DROP_LIMIT_TYPE = {
    DAY = 1,
    WEEK = 2
}

local now
function SetNow(t, bForce)
    if bForce or now == nil or now < t then
        now = t
    end
end

SetNow(ULowLevelFunctions.GetUtcMillisecond())

function SetGameTimeSeconds(timeSeconds, realTimeSeconds)
    os.gameTimeMS = timeSeconds * 1000
    os.gameRealTimeMS = realTimeSeconds * 1000
end

---返回当前时间（设备本地时间，不可信，可以通过调整设备时间修改），ms值
---@public
---@param number unit 0:微秒，1：秒，nil：毫秒
---@return integer 向上取整
_G._NOW0 = function(unit)
    if not unit then unit = 0.001 end
    if unit <= 0 then unit = 0.000001 end
    return math.floor((now or 0) * (0.001 / unit))
end
os.NOW0 = os.now
os.UTC0 = os.utc
os.TIME0 = os.time
os.gameTimeMS = 0
os.gameRealTimeMS = 0
local CS_TIME_DELTA = 0 --与CS时间差
local GS_TIME_DELTA = 0 --与GS时间差

local toint = math.floor

---将一个utc时间ms转换为客户端本地时间
---@param t number utc时间 (毫秒)
---@param d table 接受转化后的时间数据结构
_G._time = function(d, t)
    t = toint(t / 1000)
    local d1 = os.date("*t", t)
    table.append(d, d1)
end

---返回当前时间(服务器时间)，ms值
---@public
---@param unit number|nil 0:微秒，1：秒，nil：毫秒
---@return integer
_G._now = function(unit)
    if not unit then unit = 0.001 end
    if unit <= 0 then unit = 0.000001 end
    local t0 = _NOW0(unit)
    local t1 = t0 + CS_TIME_DELTA * (0.001 / unit)
    return toint(t1)
end

--返回当前或特定时间的时间戳
---@param t table|nil table格式为_G._time(d,t)获取的格式 {year = 2023,month = 8,day = 8,hour = 14,min = 0,sec = 0,isdst = fasle}，nil返回当前时间（无时区）
---@param timezone number 指定时区(默认utc时区)
---@return utc时间戳（秒）
os.time = function(t, timezone)
    if type(t) == "table" then
        timezone = timezone ~= nil and timezone or 0
        local os_time = os.TIME0()
        local localTimeZone = toint((os_time - os.TIME0(os.date("!*t", os_time))) // 3600)
        return os.TIME0(t) + (localTimeZone - timezone) * HOURMILLISECOND // 1000
    end
    return _G._now(1)
end

os.now = function(unit)
    if not unit then unit = 0.001 end
    if unit <= 0 then unit = 0.000001 end
    local t0 = os.NOW0(unit)
    local t1 = t0 + CS_TIME_DELTA * (0.001 / unit)
    return toint(t1)
end

os.utc = function(unit)
    if not unit then unit = 0.001 end
    if unit <= 0 then unit = 0.000001 end
    local t0 = os.UTC0(unit)
    local t1 = t0 + CS_TIME_DELTA * (0.001 / unit)
    return toint(t1)
end
-- --同步GS时间
-- _G._nowGS = function( unit )
-- 	if not unit then unit = 0.001 end
-- 	if unit <= 0 then unit = 0.000001 end
-- 	local t0 = _NOW0( unit )
-- 	local t1 = t0 + GS_TIME_DELTA * ( 0.001 / unit )
-- 	return toint( t1 )
-- end
-- --同步GS时间
-- os.nowGS = function( unit )
-- 	if not unit then unit = 0.001 end
-- 	if unit <= 0 then unit = 0.000001 end
-- 	local t0 = os.NOW0( unit )
-- 	local t1 = t0 + GS_TIME_DELTA * ( 0.001 / unit )
-- 	return toint( t1 )
-- end

--同步CS服务端时间 毫秒级
function _G.AdjustTimeCS(servertime)        --同步CS服务端时间 毫秒级
    SetNow(ULowLevelFunctions.GetUtcMillisecond(), true)
    CS_TIME_DELTA = servertime - _G._NOW0() -- 800 --考虑延迟比服务端差1点吧
end

-- function _G.AdjustTimeGS( servertime ) --同步GS服务端时间 毫秒级
-- 	GS_TIME_DELTA = servertime - os.NOW0() -- 800 --考虑延迟比服务端差1点吧
-- end

-- function _G.Cd(e,k,t) --自定义cd中
-- 	local now = os.now()--毫秒
-- 	if not e.___cooldown then e.___cooldown = {} end
-- 	if e.___cooldown[k] and now-e.___cooldown[k]<t then
-- 		return true, t-now+e.___cooldown[k]
-- 	end
-- 	e.___cooldown[k] = now
-- end
-- function _G.CdDo( k, t, func )
-- 	if not me.___cddotimer then me.___cddotimer = {} end
-- 	if me.___cddotimer[k] then return end
-- 	me.___cddotimer[k] = Game.TimerManager:CreateTimerAndStart(function()
-- 		if func then func() end
-- 		me.___cddotimer[k] = nil
-- 	end, t, 1)
-- end

---@param t1 number utc时间（ms）
---@param t2 number utc时间（ms）
---@return boolean
function TimeUtils.SameDay(t1, t2) --两个ms时间是否同日
    local d1, d2 = {}, {}
    _G._time(d1, t1)
    _G._time(d2, t2)
    return d1.year == d2.year and d1.month == d2.month and d1.day == d2.day
end

--两个ms时间是否同周
---@param t1 number utc时间（ms）
---@param t2 number utc时间（ms）
---@return boolean
function TimeUtils.SameWeek(t1, t2)
    local diffTime = math.abs(t1 - t2)
    if diffTime > 7 * DAYMILLISECOND then
        return false
    end
    local d1, d2 = {}, {}
    _G._time(d1, t1)
    _G._time(d2, t2)
    local w1 = d1.wday
    local w2 = d2.wday
    if w1 == 0 then w1 = 7 end
    if w2 == 0 then w2 = 7 end
    local bigDay
    local smallDay
    if t1 > t2 then
        bigDay = w1
        smallDay = w2
    else
        bigDay = w2
        smallDay = w1
    end
    if bigDay < smallDay then
        return false
    end
    if bigDay == smallDay and diffTime > DAYMILLISECOND then
        return false
    end
    return true
end

--两个ms时间是否同月
---@param t1 number utc时间（ms）
---@return boolean
function TimeUtils.SameMonth(t1, t2)
    local d1, d2 = {}, {}
    _G._time(d1, t1)
    _G._time(d2, t2)
    return d1.year == d2.year and d1.month == d2.month
end

--取得当指定时间的0点时间
---@param t number utc时间（毫秒）
---@return number 当日0点的utc时间
function TimeUtils.Day0time(t)
    local d = {}
    _G._time(d, t)
    return t - d.hour * HOURMILLISECOND - d.min * MINUTEMILLISECOND - d.sec * 1000 --今日0点
end

--取得当指定时间的24点时间
---@param t number utc时间（毫秒）
---@return number 当日24点的utc时间
function TimeUtils.Day24time(t)
    local d = {}
    _G._time(d, t)
    return t - d.hour * HOURMILLISECOND - d.min * MINUTEMILLISECOND - d.sec * 1000 + DAYMILLISECOND --今日24点
end

-- function Time.getDayKeyNum(t)--return toint(yymmdd)
-- 	local now = t or _G._now()
-- 	local d = _G._time({},now)
-- 	local dk = d.year*10000+d.month*100+d.day
-- 	return dk
-- end

--获得当前时间到一个特定时间的时间差（秒）
---@param t table|number|nil table格式为_G._time(d,t)获取的格式 {year = 2023,month = 8,day = 8,hour = 14,min = 0,sec = 0,isdst = fasle}， nil返回0
---@return number 时间差秒数
function TimeUtils.GetdiffSecFromNow(t)
    if t then
        if type(t) == "table" then
            return _G._now(1) - os.time(t)
            -- elseif type(t) == "number" then
            -- 	return (_G._now() - t) // 1000
        end
    else
        return 0
    end
    return 0
end

local tmpd = {}

---@param mss number utc时间（毫秒）
---@param s string 显示精确度“day”“hour”“min”“min”“sec”
function TimeUtils.TimeToDate(mss, s) --毫秒级
    local d = {}
    _G._time(d, mss)
    if not s then
        return string.format('%04d-%02d-%02d %02d:%02d:%06.3f', d.year, d.month, d.day, d.hour, d.min, d.sec +
        d.msec / 1000)
    elseif s == 'day' then
        return string.format('%04d-%02d-%02d', d.year, d.month, d.day)
    elseif s == 'hour' then
        return string.format('%04d-%02d-%02d %02d', d.year, d.month, d.day, d.hour)
    elseif s == 'min' then
        return string.format('%04d-%02d-%02d %02d:%02d', d.year, d.month, d.day, d.hour, d.min)
    elseif s == 'sec' then
        return string.format('%04d-%02d-%02d %02d:%02d:%02d', d.year, d.month, d.day, d.hour, d.min, d.sec)
    end
end

-- 获得时区差
function TimeUtils.GetServerTimeZone()
    local os_time = os.TIME0()
    return toint((os_time - os.TIME0(os.date("!*t", os_time))) // 3600)
end

----------------------------------------------------------------------------------------------------------
-- local time1970 = _time( 0, { year = 1970, month = 1, day = 1 } )
-- local nowutc = os.utc( 0 ) - os.now( 0 )
-- _G.unixNow0 = function( )
-- 	return _now( 0 ) - time1970 + nowutc
-- end

-- _G.unixToGame = function( t )
-- 	return t - nowutc + time1970
-- end
-- _G.gameToUnix = function( t )
-- 	return t - time1970 + nowutc
-- end

-- function Time.inDayTime(range,now)
-- 	local t0 = Time.day0time(now)/60000
-- 	local s = t0 + range[1]*600 + range[2]
-- 	local e = t0 + range[3]*600 + range[4]
-- 	return s <= t0 and t0 <= e
-- end

-- function Time.toMinutes(microseconds) -- 微秒转分钟 eg:1200000000  ->     20:00
-- 	local minutes = (microseconds / 60000000) - (microseconds / 60000000) % 1
-- 	local seconds = (microseconds / 60000000 % 1 * 60) - (microseconds / 60000000 % 1 * 60) % 1 -- （分钟小数部分 * 60 ） 再精确到秒钟整数部分
-- 	if seconds <= 9 then
-- 		seconds = "0" .. seconds
-- 	end
-- 	if minutes <= 9 then
-- 		minutes = "0" .. minutes
-- 	end
-- 	return minutes .. ":" .. seconds
-- end

-- function Time.toDay(microseconds) -- 微秒转化成天
-- 	local day = (microseconds / 86400000000) - (microseconds / 86400000000) % 1
-- 	local hour =  microseconds / 86400000000 % 1 * 60 * 24 * 1000000

-- 	return day .. "天" .. toHour(hour)
-- end
-- function Time.toTiming( microseconds )
-- 	if microseconds > 86400000000 then
-- 		return Time.toDay(microseconds)
-- 	elseif microseconds > 3600000000 then
-- 		return Time.toHour(microseconds)
-- 	elseif microseconds > 60000000 then
-- 		return Time.toMinutes(microseconds)
-- 	else
-- 		local seconds = (microseconds/1000000) - (microseconds/1000000) % 1
-- 		return '' .. seconds
-- 	end
-- end

-- function Time.toTimingFormat2( microseconds )  --格式：x时x分x秒；x分x秒；x秒
-- 	if microseconds > 3600000000 then
-- 		local format
-- 		local hour = microseconds/3600000000 - (microseconds/3600000000) % 1
-- 		local min =  microseconds / 3600000000 % 1 * 60 * 60 * 1000000
-- 		local minutes = (min / 60000000) - (min / 60000000) % 1
-- 		local seconds = (min / 60000000 % 1 * 60) - (min / 60000000 % 1 * 60) % 1
-- 		format = hour .. '时'.. minutes .. '分'.. seconds .. '秒'
-- 		return format
-- 	elseif microseconds > 60000000 then
-- 		local format
-- 		local minutes = (microseconds / 60000000) - (microseconds / 60000000) % 1
-- 		local seconds = (microseconds / 60000000 % 1 * 60) - (microseconds / 60000000 % 1 * 60) % 1
-- 		 format = minutes .. '分'.. seconds .. '秒'
-- 		return format
-- 	else
-- 		local format
-- 		local seconds = (microseconds/1000000) - (microseconds/1000000) % 1
-- 		 format = seconds .. '秒'
-- 		return format
-- 	end
-- end

-- function Time.toTimingFormat( microseconds )  --格式：00:00:00 / 00:00
-- 	if microseconds > 3600000000 then
-- 		local format
-- 		local hour = microseconds/3600000000 - (microseconds/3600000000) % 1
-- 		local min =  microseconds / 3600000000 % 1 * 60 * 60 * 1000000
-- 		if math.floor(hour/10) == 0 then
-- 			format = '0' .. hour .. ':'
-- 		else
-- 			format = hour .. ':'
-- 		end
-- 		local minutes = (min / 60000000) - (min / 60000000) % 1
-- 		local seconds = (min / 60000000 % 1 * 60) - (min / 60000000 % 1 * 60) % 1
-- 		if math.floor(minutes/10) == 0 then
-- 			format = format .. '0' .. minutes .. ':'
-- 		else
-- 			format = format .. minutes .. ':'
-- 		end
-- 		if math.floor(seconds/10) == 0 then
-- 			format = format .. '0' .. seconds
-- 		else
-- 			format = format .. seconds
-- 		end
-- 		return format
-- 	elseif microseconds > 60000000 then
-- 		local format
-- 		local minutes = (microseconds / 60000000) - (microseconds / 60000000) % 1
-- 		local seconds = (microseconds / 60000000 % 1 * 60) - (microseconds / 60000000 % 1 * 60) % 1
-- 		if math.floor(minutes/10) == 0 then
-- 			format = '0' .. minutes .. ':'
-- 		else
-- 			format = minutes .. ':'
-- 		end
-- 		if math.floor(seconds/10) == 0 then
-- 			format = format .. '0' .. seconds
-- 		else
-- 			format = format .. seconds
-- 		end
-- 		return format
-- 	else
-- 		local format
-- 		local seconds = (microseconds/1000000) - (microseconds/1000000) % 1
-- 		if math.floor(seconds/10) == 0 then
-- 			format = '0' .. seconds
-- 		else
-- 			format = seconds
-- 		end
-- 		return '00:' .. format
-- 	end
-- end

-- function Time.toTimingFormat3( microseconds )  --格式：00:00:00 前面的00会保留
-- 	if microseconds > 3600000000 then
-- 		local format
-- 		local hour = microseconds/3600000000 - (microseconds/3600000000) % 1
-- 		local min =  microseconds / 3600000000 % 1 * 60 * 60 * 1000000
-- 		if math.floor(hour/10) == 0 then
-- 			format = '0' .. hour .. ':'
-- 		else
-- 			format = hour .. ':'
-- 		end
-- 		local minutes = (min / 60000000) - (min / 60000000) % 1
-- 		local seconds = (min / 60000000 % 1 * 60) - (min / 60000000 % 1 * 60) % 1
-- 		if math.floor(minutes/10) == 0 then
-- 			format = format .. '0' .. minutes .. ':'
-- 		else
-- 			format = format .. minutes .. ':'
-- 		end
-- 		if math.floor(seconds/10) == 0 then
-- 			format = format .. '0' .. seconds
-- 		else
-- 			format = format .. seconds
-- 		end
-- 		return format
-- 	elseif microseconds > 60000000 then
-- 		local format
-- 		local minutes = (microseconds / 60000000) - (microseconds / 60000000) % 1
-- 		local seconds = (microseconds / 60000000 % 1 * 60) - (microseconds / 60000000 % 1 * 60) % 1
-- 		if math.floor(minutes/10) == 0 then
-- 			format = '00:0' .. minutes .. ':'
-- 		else
-- 			format = '00:' .. minutes .. ':'
-- 		end
-- 		if math.floor(seconds/10) == 0 then
-- 			format = format .. '0' .. seconds
-- 		else
-- 			format = format .. seconds
-- 		end
-- 		return format
-- 	else
-- 		local format
-- 		local seconds = (microseconds/1000000) - (microseconds/1000000) % 1
-- 		if math.floor(seconds/10) == 0 then
-- 			format = '0' .. seconds
-- 		else
-- 			format = seconds
-- 		end
-- 		return '00:00:' .. format
-- 	end
-- end
-- function Time.toHour( microseconds ) -- 微秒转化成小时 eg: 4206000000 --> 01:10:06
-- 	local hour = microseconds/3600000000 - (microseconds/3600000000) % 1
-- 	local min =  microseconds / 3600000000 % 1 * 60 * 60 * 1000000
-- 	return hour..":"..Time.toMinutes(min)
-- end
----------------------------------------------------------------------------------------------------------

---@param t1 number utc时间（ms）
---@param t2 number utc时间（ms）
---@return number 两个时间点相隔天数
function TimeUtils.DaysBetweenTwoDate(t1, t2)  --t2-t1
    local oldtime = _G._time({}, t1 / 1000)
    local newtime = _G._time({}, t2 / 1000)
    if oldtime.year == newtime.year then
        return newtime.yday - oldtime.yday
    elseif oldtime.year > newtime.year then
        return -TimeUtils.DaysBetweenTwoDate(t2, t1)
    else
        local day = 0
        for i = oldtime.year, newtime.year do
            local isLeap = (i % 4 == 0 and i % 100 ~= 0) and i % 400 == 0 --判断是否是闰年
            if i == oldtime.year then
                day = day + (isLeap and 365 or 366) - oldtime.yday
            elseif i ~= newtime.year then
                day = day + (isLeap and 365 or 366)
            else
                day = day + newtime.yday
            end
        end
        return day
    end
end

-- function Time.daysInclude(t1,t2,hour)
-- 	return Time.sameDay(t1-hour*60*60*1000000,t2-hour*60*60*1000000)
-- end
-- ---@param mss utc时间戳（ms）
-- function Time.timeToDateNoY(mss)  -- 没有年的日期格式
-- 	local d = {}
-- 	_G._time(d,mss)
-- 	return string.format('%02d-%02d %02d:%02d',d.month,d.day,d.hour,d.min)
-- end

-----------------------------------------------------------------------------------------------------------


function TimeUtils.CompareHourMinSec(date, hour, min, sec)
    if date.hour > hour then
        return true
    elseif date.hour == hour then
        if date.min > min then
            return true
        elseif date.min == min then
            if date.sec >= sec then
                return true
            else
                return false
            end
        else
            return false
        end
    else
        return false
    end
end

--获取下个utc每日刷新时间戳(ms)
---@param ts number utc时间戳（ms）
---@param RefreshTimePerDay table|nil {Hour = 区间[0-24), Min = 区间[0-60), Sec = 区间[0-60) } 每日刷新时间点，默认0
---@return number 下一次刷新时间utc时间戳（ms）
function TimeUtils.GetNextRefreshUTCPerDay(ts, RefreshTimePerDay)
    local date = {}
    _G._time(date, ts)
    if RefreshTimePerDay == nil then
        RefreshTimePerDay = { Hour = 0, Minute = 0, Second = 0 }
    end
    if RefreshTimePerDay.Sec == nil or RefreshTimePerDay.Sec >= 60 then
        RefreshTimePerDay.Sec = 0
    end
    if RefreshTimePerDay.Min == nil or RefreshTimePerDay.Min >= 60 then
        RefreshTimePerDay.Min = 0
    end
    if RefreshTimePerDay.Hour == nil or RefreshTimePerDay.Hour >= 24 then
        RefreshTimePerDay.Hour = 0
    end
    --已过当日刷新时间
    if (date.hour > RefreshTimePerDay.Hour) or
        (date.hour == RefreshTimePerDay.Hour and date.min > RefreshTimePerDay.Min) or
        (date.hour == RefreshTimePerDay.Hour and date.min == RefreshTimePerDay.Min and
            date.sec >= RefreshTimePerDay.Sec) then
        return TimeUtils.Day24time(ts) + RefreshTimePerDay.Hour * HOURMILLISECOND +
            RefreshTimePerDay.Min * MINUTEMILLISECOND + RefreshTimePerDay.Sec * 1000
    else
        return TimeUtils.Day0time(ts) + RefreshTimePerDay.Hour * HOURMILLISECOND +
            RefreshTimePerDay.Min * MINUTEMILLISECOND + RefreshTimePerDay.Sec * 1000
    end
end

function TimeUtils.GetLastClearUTC(utc, clearRule)
    local clearType = clearRule[1]
    if clearType == TimeUtils.DROP_LIMIT_TYPE.DAY then
        return TimeUtils.GetNextRefreshUTCPerDay(utc, { Hour = clearRule[2], Min = clearRule[3], Sec = clearRule[4] }) -
        86400000
    elseif clearType == TimeUtils.DROP_LIMIT_TYPE.WEEK then
        return TimeUtils.GetNextRefreshUTCPerWeek(utc, clearRule[2],
            { Hour = clearRule[3], Min = clearRule[4], Sec = clearRule[5] }) - 604800000
    end
end

--获取下个utc每周刷新时间戳（ms)
---@param ts number utc时间戳（ms）
---@param RefreshTimePerDay table|nil {Hour = 区间[0-24), Min = 区间[0-60), Sec = 区间[0-60) } 每日刷新时间点，默认0
---@param RefreshDayPerWeek number|nil 星期几刷新（1-7）默认1
function TimeUtils.GetNextRefreshUTCPerWeek(ts, RefreshDayPerWeek, RefreshTimePerDay)
    local date = {}
    _G._time(date, ts)
    if RefreshTimePerDay == nil then
        RefreshTimePerDay = { Hour = 0, Minute = 0, Second = 0 }
    end
    if (RefreshDayPerWeek == nil) then
        RefreshDayPerWeek = 1
    end
    if RefreshTimePerDay.Sec == nil or RefreshTimePerDay.Sec >= 60 then
        RefreshTimePerDay.Sec = 0
    end
    if RefreshTimePerDay.Min == nil or RefreshTimePerDay.Min >= 60 then
        RefreshTimePerDay.Min = 0
    end
    if RefreshTimePerDay.Hour == nil or RefreshTimePerDay.Hour >= 24 then
        RefreshTimePerDay.Hour = 0
    end
    local weekDay = TimeUtils.GetCurWeekDay(date.wday)
    --已过当周刷新时间
    if (weekDay > RefreshDayPerWeek) or
        ((weekDay == RefreshDayPerWeek) and ((date.hour > RefreshTimePerDay.Hour) or
            (date.hour == RefreshTimePerDay.Hour and date.min > RefreshTimePerDay.Min) or
            (date.hour == RefreshTimePerDay.Hour and date.min == RefreshTimePerDay.Min and
                date.sec >= RefreshTimePerDay.Sec)))
    then
        return TimeUtils.Day0time(ts) + (7 - weekDay + RefreshDayPerWeek) * DAYMILLISECOND +
            RefreshTimePerDay.Hour * HOURMILLISECOND + RefreshTimePerDay.Min * MINUTEMILLISECOND +
            RefreshTimePerDay.Sec * 1000
    else
        return TimeUtils.Day0time(ts) + (RefreshDayPerWeek - weekDay) * DAYMILLISECOND +
            RefreshTimePerDay.Hour * HOURMILLISECOND + RefreshTimePerDay.Min * MINUTEMILLISECOND +
            RefreshTimePerDay.Sec * 1000
    end
end

--获得周内天数
---@param wyday number 星期转化
function TimeUtils.GetCurWeekDay(wday)
    local weekDay = wday - 1
    if weekDay > 6 then
        weekDay = 6
    elseif weekDay < 0 then
        weekDay = 0
    end
    if weekDay == 0 then
        weekDay = 7
    end
    return weekDay
end

--获得距上次刷新点的累计刷新天数
---@param lastTS number 上一次刷新时间的utc时间戳(ms)
---@param utc number 当前时间的utc时间戳
---@param addRule array (addRule[1]:TimeUtils.DROP_LIMIT_TYPE addRule[2]:小时，addRule[3]:分钟，addRule[2]:秒钟
---@param clearRule array (addRule[1]:TimeUtils.DROP_LIMIT_TYPE addRule[2]:小时，addRule[3]:分钟，addRule[2]:秒钟
---@return number 间隔天数
function TimeUtils.GetCumulativeRefreshDayCount(lastTS, utc, addRule, clearRule)
    local needClear = false
    if clearRule then
        local lastClearUTC = TimeUtils.GetLastClearUTC(utc, clearRule)
        if lastTS < lastClearUTC then
            needClear = true
            lastTS = lastClearUTC
        end
    end

    local nextRefreshDayTS = TimeUtils.GetNextRefreshUTCPerDay(lastTS,
        { Hour = addRule[2], Min = addRule[3], Sec = addRule[4] })
    if nextRefreshDayTS > utc then
        return needClear, 0
    end
    return needClear, math.max(math.floor((utc - nextRefreshDayTS) / 86400000) + 1, 1)
end

--获得距上次刷新点的累计刷新周数
---@param lastTS number 上一次刷新时间的utc时间戳(ms)
---@param RefreshTimePerDay table|nil {Hour = 区间[0-24), Min = 区间[0-60), Sec = 区间[0-60) } 每日刷新时间点，默认0
---@param RefreshDayPerWeek number|nil 星期几刷新（1-7）默认1
---@return boolean 是否清除
---@return number 间隔周数
function TimeUtils.GetCumulativeRefreshWeekCount(lastTS, utc, addRule, clearRule)
    local needClear = false
    if clearRule then
        local lastClearUTC = TimeUtils.GetLastClearUTC(utc, clearRule)
        if lastTS < lastClearUTC then
            needClear = true
            lastTS = lastClearUTC
        end
    end

    local nextRefreshWeekTS = TimeUtils.GetNextRefreshUTCPerWeek(lastTS, addRule[2],
        { Hour = addRule[3], Min = addRule[4], Sec = addRule[5] })
    if nextRefreshWeekTS > utc then
        return needClear, 0
    end
    return needClear, math.max(math.floor((utc - nextRefreshWeekTS) / 604800000) + 1, 1)
end

---@return number utc时间戳（秒）
-- 获取当前服务器时间的秒数
function TimeUtils.GetCurTime()
    return math.floor(_G._now(1))
end

--- 将毫秒转化成秒数
function TimeUtils.Millisecond2Second(msec)
    return msec // 1000
end

--------------------------------------------------------------------------------------------------
--格式化输出（临时）
local StringConst = require "Framework.StringConst.StringConst"
local TimeEnglishString = {
    Day = "d",
    Hour = "h",
    Minute = "m",
    Second = "s"
}

-- local TimeChineseString = {
--     Day = StringConst.Get("DAY"),
--     Hour = StringConst.Get("HOUR"),
--     Minute = StringConst.Get("MINUTE"),
--     Second = StringConst.Get("SECOND"),
-- }

TimeUtils.UnitType = {
    EN = 1,  --- 英文
    CHS = 2, --- 中文
}

function TimeUtils.GetWeekString()
    if TimeUtils.WeekString == nil then
        TimeUtils.WeekString = {
            [0] = StringConst.Get("SUNDAY"),
            [1] = StringConst.Get("MONDAY"),
            [2] = StringConst.Get("TUESDAY"),
            [3] = StringConst.Get("WEDNESDAY"),
            [4] = StringConst.Get("THURSDAY"),
            [5] = StringConst.Get("FRIDAY"),
            [6] = StringConst.Get("SATURDAY")
        }
    end
    return TimeUtils.WeekString
end

function TimeUtils.GetYesterDayString()
    if TimeUtils.yesterDayString == nil then
        TimeUtils.yesterDayString = StringConst.Get("YESTERDAY")
    end
    return TimeUtils.yesterDayString
end

---@param time table {Day,Hour,Minute,Second}
---@param day boolean 是否显示天
---@param hour boolean 是否显示小时
---@param min boolean 是否显示分钟
---@param sec boolean 是否显示秒
---@param showType TimeUtils.UnitType 语言类型
function TimeUtils.CatTimeString(time, day, hour, min, sec, showType)
    -- local languageString = TimeEnglishString
    -- if showType then
    -- 	if showType == TimeUtils.UnitType.CHS then
    -- 		languageString = TimeChineseString
    -- 	end
    -- end
    local timeString = ""
    if showType then
        if time.Day ~= nil and time.Day ~= 0 and day then
            timeString = string.format("%d%s", time.Day, StringConst.Get("DAY"))
        end
        if time.Hour ~= nil and time.Hour ~= 0 and hour then
            if timeString ~= "" then
                timeString = string.format("%s%d%s", timeString, time.Hour, StringConst.Get("HOUR"))
            else
                timeString = string.format("%d%s", time.Hour, StringConst.Get("HOUR"))
            end
        end
        if time.Minute ~= nil and time.Minute ~= 0 and min then
            if timeString ~= "" then
                timeString = string.format("%s%d%s", timeString, time.Minute, StringConst.Get("MINUTE"))
            else
                timeString = string.format("%d%s", time.Minute, StringConst.Get("MINUTE"))
            end
        end
        if time.Second ~= nil and sec then
            if timeString ~= "" then
                timeString = string.format("%s%d%s", timeString, time.Second, StringConst.Get("SECOND"))
            else
                timeString = string.format("%d%s", time.Second, StringConst.Get("SECOND"))
            end
        end
    else
        if time.Hour ~= nil then
            if time.Minute ~= nil or time.Second ~= nil then
                timeString = string.format("%02d", time.Hour)
            else
                timeString = tostring(time.Hour)
            end
        end
        if time.Minute ~= nil then
            if timeString ~= "" then
                timeString = string.format("%s:%02d", timeString, time.Minute)
            else
                timeString = tostring(time.Minute)
            end
        end
        if time.Second ~= nil and sec then
            if timeString ~= "" then
                timeString = string.format("%s:%02d", timeString, time.Second)
            else
                timeString = tostring(time.Second)
            end
        end
    end
    return timeString
end

--获得倒计时时间的格式化输出
---@param milliseconds number 时长（毫秒）
---@param showContent table|nil 显示内容 {Day = false,Hour = false,Minute = false,Second = true} 除second外其他默认不显示
---@param unitType number|nil 单位类型 中文： Time.UnitType.CHS, 英文:Time.UnitType.EN, nil为xx:xx:xx格式
---@return string 格式化的时间字符串
function TimeUtils.GetCountDownTimeFormatString(milliseconds, showContent, unitType)
    local timeString = ""
    local time = {}
    time.Second = toint(milliseconds)
    if showContent ~= nil then
        if showContent.Day and unitType then
            time.Day = time.Second // DAYMILLISECOND
            time.Second = time.Second % DAYMILLISECOND
        end
        if showContent.Hour then
            time.Hour = time.Second // HOURMILLISECOND
            time.Second = time.Second % HOURMILLISECOND
        end
        if showContent.Minute then
            time.Minute = time.Second // MINUTEMILLISECOND
            time.Second = time.Second % MINUTEMILLISECOND
        end
    end
    time.Second = time.Second // 1000
    if unitType == TimeUtils.UnitType.CHS then
        --local languageString = timeLanguageString
        if time.Day ~= nil and time.Day ~= 0 then
            timeString = string.format("%d%s", time.Day, StringConst.Get("DAY"))
        end
        if time.Hour ~= nil and time.Hour ~= 0 then
            if timeString ~= "" then
                timeString = string.format("%s%d%s", timeString, time.Hour, StringConst.Get("HOUR"))
            else
                timeString = string.format("%d%s", time.Hour, StringConst.Get("HOUR"))
            end
        end
        if time.Minute ~= nil and time.Minute ~= 0 then
            if timeString ~= "" then
                timeString = string.format("%s%d%s", timeString, time.Minute, StringConst.Get("MINUTE"))
            else
                timeString = string.format("%d%s", time.Minute, StringConst.Get("MINUTE"))
            end
        end
        if time.Second ~= nil and ((showContent ~= nil and showContent.Second) or showContent == nil) then
            if timeString ~= "" then
                timeString = string.format("%s%d%s", timeString, time.Second, StringConst.Get("SECOND"))
            else
                timeString = string.format("%d%s", time.Second, StringConst.Get("SECOND"))
            end
        end
    else
        if time.Hour ~= nil then
            if time.Minute ~= nil or time.Second ~= nil then
                timeString = string.format("%02d", time.Hour)
            else
                timeString = tostring(time.Hour)
            end
            --timeString = tostring(time.Hour)
        end
        if time.Minute ~= nil then
            if timeString ~= "" then
                timeString = string.format("%s:%02d", timeString, time.Minute)
            else
                --timeString = tostring(time.Minute)
                timeString = string.format("%02d", time.Minute)
            end
        end
        if time.Second ~= nil and ((showContent ~= nil and showContent.Second) or showContent == nil) then
            if timeString ~= "" then
                timeString = string.format("%s:%02d", timeString, time.Second)
            else
                --timeString = tostring(time.Second)
                timeString = string.format("%02d", time.Second)
            end
        end
    end
    return timeString
end

--计算两天中间相隔的天数
---@param year1 number 第一个日期的年份
---@param year2 number 第二个日期的年份
---@param yday1 number 第一个日期在一年中的第几天
---@param yday1 number 第二个日期在一年中的第几天
---@return number 间隔天数
function TimeUtils.GetDiffDay(year1, year2, yday1, yday2)
    local difDay = 0
    if year1 ~= year2 then
        local yearday = 0
        for i = year1, year2 - 1, 1 do
            if i % 400 == 0 or (i % 100 ~= 0 and i % 4 == 0) then
                yearday = yearday + 366
            else
                yearday = yearday + 365
            end
        end
        difDay = yday2 + yearday - yday1
        -- if year2 == year1 + 1 then
        -- 	local yearday = 365
        -- 	if year1 % 400 == 0 or (year1 % 100 ~= 0 and year1 % 4 == 0) then
        -- 		yearday = 366
        -- 	end
        -- 	difDay = yday2 + yearday - yday1
        -- end
    else
        difDay = yday2 - yday1
    end
    return difDay
end

--计算指定月份的天数
---@param year number 年份
---@param month month 月份
---@return number 天数
function TimeUtils.GetMonthDay(year, month)
    if month == 1 or month == 3 or month == 5 or month == 7 or month == 8 or month == 10 or month == 12 then
        return 31
    elseif month == 2 then
        if year % 400 == 0 or (year % 100 ~= 0 and year % 4 == 0) then
            return 29
        else
            return 28
        end
    else
        return 30
    end
end

---获取过去时间点的格式化输出
---@param ts number utc时间（毫秒）
---@param showType number 0|nil 显示时间点，1显示距当前时间的间隔
---@return string 格式化的字符串
function TimeUtils.GetPastTimeString(ts, showType)
    local ts1 = ts
    local ts2 = _G._now()
    local date1 = {}
    local date2 = {}
	if ts1 == nil or ts1 < 0 or ts1 > 2147483647 * 1000 then
		Log.Error("Timestamp out of range")
		print(ts1)
		return ""
	end
	if ts2 == nil or ts2 < 0 or ts2 > 2147483647 * 1000 then
		Log.Error("Timestamp out of range")
		print(ts2)
		return ""
	end
    _G._time(date1, ts1)
    _G._time(date2, ts2)
    if showType == nil or showType == 0 then
        if date1.year == date2.year and date1.yday == date2.yday then
            return string.format("%02d:%02d", date1.hour, date1.min)
        else
            local difDay = TimeUtils.GetDiffDay(date1.year, date2.year, date1.yday, date2.yday)
            if difDay > 1 then
                return string.format("%d/%02d/%02d", date1.year, date1.month, date1.day)
            else
                return TimeUtils.GetYesterDayString() .. string.format(" %02d:%02d", date1.hour, date1.min)
            end
        end
    else
        local difDay = TimeUtils.GetDiffDay(date1.year, date2.year, date1.yday, date2.yday)
        local yearday = 365
        if date1.year % 400 == 0 or (date1.year % 100 ~= 0 and date1.year % 4 == 0) then
            yearday = 366
        end
        if date2.year - date1.year >= 1 and difDay >= yearday then
            return string.format(StringConst.Get("YEARPAST"), 1)
        elseif date2.year == date1.year + 1 then
            if difDay >= 31 then
                return string.format(StringConst.Get("MONTHPAST"), 12 - date1.month + date2.month - 1)
            end
        else
            if difDay >= TimeUtils.GetMonthDay(date1.year, date1.month) then
                return string.format(StringConst.Get("MONTHPAST"), date2.month - date1.month)
            elseif difDay < TimeUtils.GetMonthDay(date1.year, date1.month) and ts2 - ts1 >= WEEKMILLISECOND then
                return string.format(StringConst.Get("WEEKPAST"), difDay // 7)
            elseif difDay >= 1 and ts2 - ts1 >= DAYMILLISECOND then
                return string.format(StringConst.Get("DAYPAST"), difDay == 7 and 6 or difDay)
            elseif ts2 - ts1 < DAYMILLISECOND and ts2 - ts1 >= HOURMILLISECOND then
                return string.format(StringConst.Get("HOURPAST"), (ts2 - ts1) // HOURMILLISECOND)
            else
                if ts2 - ts1 < MINUTEMILLISECOND then
                    return string.format(StringConst.Get("MINUTEPAST"), 1)
                else
                    return string.format(StringConst.Get("MINUTEPAST"), (ts2 - ts1) // MINUTEMILLISECOND)
                end
            end
        end
    end
end

--毫秒拆分为时分秒类型
function TimeUtils.GetTimeTable(milliseconds, day, hour, min, sec)
    local time = {}

    time.Second = toint(milliseconds)
    if day then
        time.Day = time.Second // DAYMILLISECOND
        time.Second = time.Second % DAYMILLISECOND
    end
    if hour then
        time.Hour = time.Second // HOURMILLISECOND
        time.Second = time.Second % HOURMILLISECOND
    end
    if min then
        time.Minute = time.Second // MINUTEMILLISECOND
        time.Second = time.Second % MINUTEMILLISECOND
    end
    if sec or sec == nil then
        time.Second = time.Second // 1000
    end

    return time
end

--获得背包限时道具提示时间格式化输出（背包物品系统时间提示规则）
-- 剩余时间≥1天：天+时+分（例：2天56时28分）
-- 1分钟≤剩余时间＜1天：时+分（例：03:24）
-- 剩余时间＜1分钟：＜1分钟
---@param milliseconds number 时长（毫秒）
---@param showType enum TimeUtils.UnitType，默认为中文
---@return string 格式化字符串
function TimeUtils.GetCountDownTimeString_1(milliseconds, unitType)
    local timeString = ""
    local time = TimeUtils.GetTimeTable(milliseconds, true, true, true, true)
    if unitType == nil then
        unitType = TimeUtils.UnitType.CHS
    end
    if time.Day > 0 then
        timeString = TimeUtils.CatTimeString(time, true, true, true, false, unitType)
    elseif time.Day <= 0 and milliseconds >= MINUTEMILLISECOND then
        timeString = TimeUtils.CatTimeString(time, false, true, true, false)
    else
        timeString = string.format(StringConst.Get("ONEMINUTE"))
    end
    return timeString
end

--获得交易行、商城物品倒计时格式化输出（交易行、商城系统时间提示规则）
-- 剩余时间＞1天：天（例：99天）
-- 剩余时间≤1天：时+分+秒（例：23:01:59）
---@param milliseconds number 时长（毫秒）
---@param showType enum TimeUtils.UnitType，默认为中文
---@return string 格式化字符串
function TimeUtils.GetCountDownTimeString_2(milliseconds, unitType)
    local timeString = ""
    local time = TimeUtils.GetTimeTable(milliseconds, true, true, true, true)
    if unitType == nil then
        unitType = TimeUtils.UnitType.CHS
    end
    if time.Day > 0 then
        timeString = TimeUtils.CatTimeString(time, true, false, false, false, unitType)
    else
        timeString = TimeUtils.CatTimeString(time, false, true, true, true)
    end
    return timeString
end

--获得副本和任务退出倒计时格式化输出（副本系统时间提示规则）
-- 分+秒（例：126:05）
---@param milliseconds number 时长（毫秒）
---@return string 格式化字符串
function TimeUtils.GetCountDownTimeString_3(milliseconds)
    local timeString = ""
    local time = TimeUtils.GetTimeTable(milliseconds, false, false, true, true)

    timeString = TimeUtils.CatTimeString(time, false, false, true, true)
    return timeString
end

--获得抽卡倒计时格式化输出（抽卡系统时间提示规则）
--天+时+分（例：99天9时3分）
---@param milliseconds number 时长（毫秒）
---@param showType enum TimeUtils.UnitType，默认为中文
---@return string 格式化字符串
function TimeUtils.GetCountDownTimeString_4(milliseconds, unitType)
    local timeString = ""
    local time = TimeUtils.GetTimeTable(milliseconds, true, true, true, true)

    if unitType == nil then
        unitType = TimeUtils.UnitType.CHS
    end

    timeString = TimeUtils.CatTimeString(time, true, true, true, false, unitType)
    return timeString
end

--获取上次登录时间的格式化输出
-- 时间≥1年：1年前
-- 1个月≤时间＜1年：mm月前（例：11月前）
-- 1周≤时间＜1个月：ww周前（例：3周前）
-- 1天≤时间＜1周：dd天前（例：6天前）
-- 1小时≤时间＜1天：hh小时前（例：12小时前）
-- 1分钟≤时间＜1小时，向下取整：mm分钟前（例：59分钟前）
-- 时间＜1分钟，向上取整：1分钟前
---@param milliseconds number 时长（毫秒）
---@return string 格式化字符串
function TimeUtils.GetRecordTimeString_1(milliseconds)
    return TimeUtils.GetPastTimeString(milliseconds, 1)
end

--获取聊天记录时间的格式化输出
-- 昨天之前：日期（例：2023/02/01）
-- 昨天之内：“昨天”+时+分（例：昨天 07:01）
-- 今天之内：时+分（例：09:56）
---@param milliseconds number 时长（毫秒）
---@return string 格式化字符串
function TimeUtils.GetRecordTimeString_2(milliseconds)
    return TimeUtils.GetPastTimeString(milliseconds, 0)
end

--获取邮件接收日期的格式化输出
---@param s number utc时间戳（秒）
---@return string 格式化时间字符串 2023-8-14
function TimeUtils.GetMailDate(s)
    local Date = {}
    _G._time(Date, s * 1000)
    return string.format(StringConst.Get("MAIL_YMDHM_FORMAT"), Date.year, Date.month, Date.day, Date.hour, Date.min)
end

--获取邮件剩余时间的格式化输出
---@param isReceived boolean 附件是否收取
---@param LeftTime number 剩余时间（秒）
---@return string 格式化的剩余时间显示字符串
function TimeUtils.GetMailLeftTimeString(isReceived, LeftTime)
    if isReceived then
        return string.format(StringConst.Get("MAIL_RECEIVED_DESC"))
    end
    if LeftTime >= 86400 then
        return string.format(StringConst.Get("MAIL_DAY_EXPIRE"), math.modf(LeftTime / 86400))
    elseif LeftTime >= 3600 then
        return string.format(StringConst.Get("MAIL_HOUR_EXPIRE"), math.modf(LeftTime / 3600))
    elseif LeftTime >= 60 then
        return string.format(StringConst.Get("MAIL_MIN_EXPIRE"), math.modf(LeftTime / 60))
    elseif LeftTime > 0 then
        return string.format(StringConst.Get("MAIL_ONE_MIN_EXPIRE"))
    else
        return string.format(StringConst.Get("MAIL_EXPIRE"))
    end
end

---GetCountDownTimeFormatStringBySeconds 获取倒计时的字符串(秒)
---@param seconds number 时长（秒）
---@param showContent table|nil 显示内容 {Day = false,Hour = false,Minute = false,Second = true} 除second外其他默认不显示
---@param unitType enum 单位类型 中文： Time.UnitType.CHS, 英文:Time.UnitType.EN
---@return string 格式化的时间字符串
function TimeUtils.GetCountDownTimeFormatStringBySeconds(seconds, showContent, unitType)
    return TimeUtils.GetCountDownTimeFormatString(seconds * 1000, showContent, unitType)
end

function TimeUtils.GetTimeTableByStr(str)
    local timeTable = string.split(str, ":")
    return timeTable
end

--- 判断是否在当天的某段时间内
---@param timestamp number		待检测时戳
---@param startTable string	开始时间 hh:mm:ss
---@param endTable string		结束时间 hh:mm:ss
---@return boolean
function TimeUtils.CheckTimeInDeterminedInterval(timestamp, startTable, endTable)
    local curDay0Timestamp = TimeUtils.Day0time(_G._now())
    local startTimestamp = curDay0Timestamp + toint(startTable[1]) * HOURMILLISECOND +
        toint(startTable[2]) * MINUTEMILLISECOND + toint(startTable[2]) * 1000
    local endTimestamp = curDay0Timestamp + toint(endTable[1]) * HOURMILLISECOND +
        toint(endTable[2]) * MINUTEMILLISECOND + toint(endTable[2]) * 1000
    return timestamp >= startTimestamp and timestamp <= endTimestamp
end

---@param startTimeStr string
---@param EndTimeStr string
---@return string,int 得到的最近时间字符串，0为开始，1为结束 nil为已结束，
function TimeUtils.GetLatestActivityTime(startTimeStr, EndTimeStr)
    local startTable = TimeUtils.GetTimeTableByStr(startTimeStr)
    local endTable = TimeUtils.GetTimeTableByStr(EndTimeStr)
    local nowTable = {}
    _G._time(nowTable, _G._now())
    if nowTable.hour > toint(startTable[1]) then   --大于开始时，可能进行，对比结束时
        if nowTable.hour > toint(endTable[1]) then --如果大于结束时间，已结束
            return nil, nil
        elseif nowTable.hour == toint(endTable[1]) then --等于结束时，对比结束分
            if nowTable.min > toint(endTable[2]) then --大于结束分，已结束
                return nil, nil
            elseif nowTable.min == toint(endTable[2]) then --等于结束分，对比秒
                if nowTable.sec >= toint(endTable[3]) then --大于结束秒，已结束
                    return nil, nil
                else                               --小于结束秒，未结束
                    return EndTimeStr, 1           --未结束
                end
            else                                   --小于结束分，未结束
                return EndTimeStr, 1               --未结束
            end
        else                                       -- 小于结束时，未结束
            return EndTimeStr, 1                   --未结束
        end
    elseif nowTable.hour == toint(startTable[1]) then --时间相等，可能开始活动，对比开始分秒
        if nowTable.min > toint(startTable[2]) then --大于开始分，可能正在进行,对比结束分
            if nowTable.min > toint(endTable[2]) then --大于结束分，已结束
                return nil, nil
            elseif nowTable.min == toint(endTable[2]) then --等于结束分，对比结束秒
                if nowTable.sec >= toint(endTable[3]) then --大于等于结束秒，已结束
                    return nil, nil                --已结束
                else
                    return EndTimeStr, 1           --未结束
                end
            end
        elseif nowTable.min == toint(startTable[2]) then --等于开始分，可能开始，对比开始秒
            if nowTable.sec >= toint(startTable[3]) then --大于开始秒，可能进行，对比结束秒
                if nowTable.sec >= toint(endTable[3]) then --大于等于结束秒，已结束
                    return nil, nil                --已结束
                else
                    return EndTimeStr, 1           --未结束
                end
            else                                   --小于开始秒，未开始
                return startTimeStr, 0             --未开始
            end
        else                                       --小于开始分，未开始
            return startTimeStr, 0
        end
    else -- 小于开始时，未开始
        return startTimeStr, 0
    end

    return nil, nil
end

--获得塔罗小队限时工资提示时间格式化输出（塔罗小队系统工资时间提示规则）
-- 剩余时间≥1天：天+时（例：2天16时）
-- 剩余时间＜1天：时+分（例：03时24分）
---@param milliseconds number 时长（毫秒）
---@param showType enum TimeUtils.UnitType，默认为中文
---@return string 格式化字符串
function TimeUtils.GetTarotTeamWageCountDownTimeString(milliseconds, unitType)
    local timeString = ""
    local time = TimeUtils.GetTimeTable(milliseconds, true, true, true, true)
    if unitType == nil then
        unitType = TimeUtils.UnitType.CHS
    end
    if time.Day > 0 then
        timeString = TimeUtils.CatTimeString(time, true, true, false, false, unitType)
    else
        timeString = TimeUtils.CatTimeString(time, false, true, true, false, unitType)
    end
    return timeString
end

function TimeUtils.CheckActivityDay(day)
    if day == 0 then
        return true
    end
    local date = {}
    _G._time(date, _G._now())
    local weekDay = TimeUtils.GetCurWeekDay(date.wday)
    if weekDay == day then
        return true
    else
        return false
    end
end
