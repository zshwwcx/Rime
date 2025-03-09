local lang = kg_require("Shared.language_zhs")
local const = kg_require("Shared.Const")
local lume = kg_require("Shared.lualibs.lume")

local os_date = os.date
local os_time = os.time
local tonumber = tonumber
local string_split = string.split
local math_abs = math.abs
local math_max = math.max
local math_floor = math.floor
local math_ceil = math.ceil
local string_format = string.format

SEC_IN_DAY = 86400
SEC_IN_HOUR = 3600
SEC_IN_MINUTE = 60

local START_WEEK_POS = 2
local START_SIGN_UP_POS = 3

-- -- temp code for server start
-- if not C7 then
--     C7 = {component = "server"}
-- end

-- if C7.component == "client" then
--     function updateTimeZoneDiff()
--         C7.timeZoneDiff = 0
--         local now = os_time()
--         local serverTimeZone = 8--clientUtils.getServerTimeZone() or 0
--         C7.timeZoneDiff = os_time(os_date("!*t", now)) - now + (serverTimeZone - (os_date("*t", now).isdst and 1 or 0)) * const.SECONDS_ONE_HOUR
--     end

--     function updateServerTime()
--         local serverTimeDiff = clientUtils.getServerTimeDiff() or 0
--         if serverTimeDiff ~= 0 then
--             C7.setServerTime((os_time() + serverTimeDiff) * 1000)
--         end
--     end

--     function getOsTime2GameTime()
--         return _G._now() - getOsTime()
--     end
-- else
--     if C7.component == "bot" then
--         function updateTimeZoneDiff()
--             local now = os_time()
--             C7.timeZoneDiff = 0
--             local botUtils = kg_require("bot_common.bot_utils")
--             local serverTimeZone = botUtils.getServerTimeZone() or 0
--             C7.timeZoneDiff = os_time(os_date("!*t", now)) - now + (serverTimeZone - (os_date("*t", now).isdst and 1 or 0)) * const.SECONDS_ONE_HOUR
--         end
--     else
--         function updateTimeZoneDiff()
--             local now = os_time()
--             C7.timeZoneDiff = 0
--             local serverTimeZone = 8 -- TODO gameconfig.getConfig("timeZone")
--             C7.timeZoneDiff = os_time(os_date("!*t", now)) - now + (serverTimeZone - (os_date("*t", now).isdst and 1 or 0)) * const.SECONDS_ONE_HOUR
--         end
--     end

--     function getOsTime2GameTime()
--         return 0
--     end
-- end

function getServerDate(fmt, t)
    if FREE_WALK then
        return os_date(fmt, 10000000)
    end

    if not t then
        t = os_time() + getOsTime2GameTime()
    end
    -- if not C7.timeZoneDiff then
    --     updateTimeZoneDiff()
    -- end
    return os_date(fmt, t)
end

function getServerTime(fmt, timezone)
    local ret = os_time(fmt, timezone)
    if not fmt then
        ret = ret + getOsTime2GameTime()
    end
    -- if not C7.timeZoneDiff then
    --     updateTimeZoneDiff()
    -- end
    ret = ret
    return ret
end

function getOsDate(...)
    return os_date(...)
end

function getOsTime(...)
    return os_time(...)
end

-- 到每日5点的日更新剩余时间
function getRemainingSecondsUntilRefreshTime(time)
    return getRemainingSecondsByDay(time - const.SECONDS_DAY_START)
end

-- 到每周5点的周更新剩余时间
function getWeekRemainingSeconds(time)
    return getRemainingSecondsByWeek(time - const.SECONDS_DAY_START)
end

-- @param time
-- @return 今天剩余的秒数
function getRemainingSecondsByDay(time)
    local nowFormat = getServerDate("*t", time)
    local timeDiff = getServerTime{year=1970, month=1, day=2, hour=nowFormat.hour, min=nowFormat.min, sec=nowFormat.sec}
    return (getServerTime({year=1970, month=1, day=3, hour=0, min=0, sec=0}) - timeDiff)
end

-- @param time
-- @return 本周剩余的秒数
function getRemainingSecondsByWeek(time)
    local nowFormat = getServerDate("*t", time)
    local timeDiff = getServerTime{year=1970, month=1, day=((nowFormat.wday + 5) % 7 + 2), hour=nowFormat.hour, min=nowFormat.min, sec=nowFormat.sec}
    return (getServerTime({year=1970, month=1, day=9, hour=0, min=0, sec=0}) - timeDiff)
end

-- @param time
-- @return 本月剩余的秒数
function getRemainingSecondsByMonth(time)
    local nowFormat = getServerDate("*t", time)
    local nextMonth = nowFormat.month + 1
    local nextYear = nowFormat.year
    if nowFormat.month == 12 then
        nextMonth = 1
        nextYear = nowFormat.year + 1
    end
    local nextMonthStartTime = getServerTime({year=nextYear, month=nextMonth, day=1, hour = 0, min = 0, sec = 0})
    return (nextMonthStartTime - time)
end

-- @param time
-- @return 获取下N月开始的时间戳(按5点开始)
function getLatterMonthStartTime(time, n)
    local nowFormat = getServerDate("*t", time)
    local nextMonth = ((nowFormat.month + n - 1) % 12) + 1
    local nextYear = nowFormat.year + math.modf((nowFormat.month + n - 1) / 12)
    local nextMonthStartTime = getServerTime({year=nextYear, month=nextMonth, day=1, hour = 5, min = 0, sec = 0})
    return getDayStartTime(nextMonthStartTime)
end

-- @param time
-- @return 获取上N月开始的时间戳(按5点开始)
function getLastMonthStartTime(time, n)
    local nowFormat = getServerDate("*t", time)
    local lastMonth = nowFormat.month - n
    local lastYear = nowFormat.year
    if lastMonth <= 0 then
        lastYear = lastYear - math.modf((-lastMonth) / 12) - 1
        lastMonth = 12 - (-lastMonth) % 12
    end

    -- Unix时间戳的起始时间为1970年
    assert(lastYear > 1970)

    local lastMonthStartTime = getServerTime({year=lastYear, month=lastMonth, day=1, hour = 5, min = 0, sec = 0})
    return getDayStartTime(lastMonthStartTime)
end

-- @param time
-- @return 今天剩余的毫秒数
function getRemainingTimeByDay(time)
    return getRemainingSecondsByDay(time) * 1000
end

-- @param time
-- @return 本周剩余的毫秒数
function getRemainingTimeByWeek(time)
    return getRemainingSecondsByWeek(time) * 1000
end

-- @param time
-- @return 本月剩余的毫秒数
function getRemainingTimeByMonth(time)
    return getRemainingSecondsByMonth(time) * 1000
end

-- @param time
-- @return 今天开始的秒时间戳(默认是5点是每日的起点)
function getDayStartTime(time)
    return getDayZeroTime(time - const.SECONDS_DAY_START) + const.SECONDS_DAY_START
end

-- @param time
-- @param {hour, min, sec}
-- @return 今天对应时间的时间戳
function getDayTime(time, args)
    args = args or {}
    local hour = args[1] or 0
    local min = args[2] or 0
    local sec = args[3] or 0
    local nowFormat = getServerDate("*t", time)
    if nowFormat == nil then
        return getServerTime{year=2019, month=2, day=2, hour=0, min=0, sec=0}
    end
    return getServerTime{year=nowFormat.year, month=nowFormat.month, day=nowFormat.day, hour=hour, min=min, sec=sec}
end

-- @param time
-- @return 今天的0点时间戳
function getDayZeroTime(time)
    return getDayTime(time)
end

-- @param time
-- @return 本周开始的秒时间戳
function getWeekStartTime(time)
    local dayStartTime = getDayStartTime(time)
    local weekDay = getWeekDay(dayStartTime)
    return dayStartTime - (weekDay - 1) * const.SECONDS_ONE_DAY
end

-- @param time
-- @return 本周的0点时间戳
function getWeekZeroTime(time)
    local dayZeroTime = getDayZeroTime(time)
    local weekDay = getWeekDay(dayZeroTime)
    return dayZeroTime - (weekDay - 1) * const.SECONDS_ONE_DAY
end

-- @param time
-- @return 是否是月末最后一天
function isMonthLastDay(time)
    local nowMonth = getMonth(time)
    local nextMonth = getMonth(time + const.SECONDS_ONE_DAY)
    return nowMonth ~= nextMonth
end

-- @param time1, time2
-- @return 获取相差的服务器天数
function getServerDayDiff(time1, time2)
    if not time1 or not time2 then
        return math.huge
    end
    local dayStartTime1 = getDayStartTime(time1)
    local dayStartTime2 = getDayStartTime(time2)
    return math_abs(dayStartTime2 - dayStartTime1) / const.SECONDS_ONE_DAY
end

-- @param time
-- @return 本月开始的秒时间戳
function getMonthStartTime(time)
    local nowFormat = getServerDate("*t", time)
    return getServerTime({year=nowFormat.year, month=nowFormat.month, day=1, hour = 5, min = 0, sec = 0})
end

-- @param time 时间戳
-- @param n 第n周
-- @return 本月第n周开始的秒时间戳
function getMonthWeekStartTime(time, n)
    if not n or n <= 0 then
        n = 1
    end

    local monthStartTime = getMonthStartTime(time)
    local weekDay = getWeekDay(monthStartTime)
    local lastMonthWeekDay = 0
    if weekDay ~= 1 then
        lastMonthWeekDay = const.DAYS_ONE_WEEK - weekDay + 1
    end

    return lastMonthWeekDay * const.SECONDS_ONE_DAY + (n - 1) * const.SECONDS_ONE_WEEK + monthStartTime
end

function getWeekStartTimeByDayStartTime(dayStartTime)
    local weekDay = getWeekDay(dayStartTime)
    return dayStartTime - (weekDay - 1) * const.SECONDS_ONE_DAY
end

function getYear(time)
    local y = getServerDate("%Y", time)
    return tonumber(y)
end

function getQuarter(month)
    return math.ceil(month / 3)
end

function getMonth(time)
    local m = getServerDate("%m", time)
    return tonumber(m)
end

function getDay(time)
    local d = getServerDate("%d", time)
    return tonumber(d)
end

function getMinute(time)
    local m = getServerDate("%M", time)
    return tonumber(m)
end

function getHour(time)
    local h = getServerDate("%H", time)
    return tonumber(h)
end

function getWeekDay(time)
    local w = getServerDate("%w", time)
    w = tonumber(w)
    if w == 0 then
        w = 7
    end
    return w
end

function getWeekDayByDayStartTime(time)
    local dayStartTime = getDayStartTime(time)
    return getWeekDay(dayStartTime)
end

function getDate(time)
    local all = lume.split(getServerDate("%Y/%m/%d", time), "/")
    local year, month, day = unpack(all)
    return tonumber(year), tonumber(month), tonumber(day)
end

--- 返回年月日拼成的整数(比如2020年1月1日=>20200101),按5点刷新算
function getServerDateInteger(time)
    time = getDayStartTime(time)
    local year, month, day = getDate(time)
    return year * 10000 + month * 100 + day
end

--- 返回年月日拼成的整数(比如2020年1月1日=>20200101),按0点算
function getDateInteger(time)
    local year, month, day = getDate(time)
    return year * 10000 + month * 100 + day
end

--- 返回年月拼成的整数(比如2020年1月=>202001)
function getYearMonthInteger(time)
    local year, month = getDate(time)
    return year * 100 + month
end

--- 通过年月日拼成的整数返回年月日(比如20200101=>2020,01,01)
function getDateFromInteger(dataInteger)
    local day = dataInteger % 100
    local month = ((dataInteger - day) / 100) % 100
    local year = math_floor(dataInteger / 10000)
    return year, month, day
end

--- 通过年月日拼成的整数返回当日5点的时间戳(比如20200101=>当日5点的时间戳)
function getDayStartTimeFromInteger(dataInteger)
    local day = dataInteger % 100
    local month = ((dataInteger - day) / 100) % 100
    local year = math_floor(dataInteger / 10000)
    return getServerTime{year=year, month=month, day=day, hour=5, min=0, sec=0}
end

function getDateYMDHM(time)
    local t = getServerDate("%Y%m%d%H%M",time)
    local year = t:sub(1, 4)
    local month = t:sub(5, 6)
    local day = t:sub(7, 8)
    local hour = t:sub(9, 10)
    local minute = t:sub(11, 12)
    return year, month, day, hour, minute
end

function getDateTimeFormat(time)
    return getServerDate("*t", time)
end

function getDateTimeFormatValue(time, key)
    local nowFormat = getServerDate("*t", time)
    return nowFormat and nowFormat[key]
end

function getDataTimeToYMDHMS(time)
    local t = getServerDate("%Y%m%d%H%M%S", time)
    return t
end

function isSameDay(time1, time2)
    return getDayStartTime(time1) == getDayStartTime(time2)
end

function isSameNatureDay(time1, time2)
    return getDayZeroTime(time1) == getDayZeroTime(time2)
end

function isSameWeek(time1, time2)
    return getWeekStartTime(time1) == getWeekStartTime(time2)
end

function isSameNatureWeek(time1, time2)
    return getWeekZeroTime(time1) == getWeekZeroTime(time2)
end

function isSameMonth(time1, time2)
    local year1, month1 = getDate(time1)
    local year2, month2 = getDate(time2)
    return year1 == year2 and month1 == month2
end

-- @param time 毫秒时间戳
-- @return 到下个整分钟剩余的毫秒数
function getIntegralMinuteLeftMsec(mtime)
    return 60000 - mtime % 60000
end

function second2millisecond(second)
    return 1000 * second
end

function millisecond2second(msec)
    return msec / 1000
end

-- 解析格式为YYYY.MM.DD.hh.mm.ss格式的时间
function parseTime(timeString)
    local timeInfo = string_split(timeString, ".")
    return getServerTime({
        year = timeInfo[1],
        month = timeInfo[2],
        day = timeInfo[3],
        hour = timeInfo[4],
        min = timeInfo[5],
        sec = timeInfo[6]
    })
end

-- 获取两个时间的时间差
-- @param time1 time2 两个时间戳，无所谓谁大谁小，最后返回两者的时间差
function getTimeDiff(time1, time2)
    if time1 < time2 then
        return getTimeDiff(time2, time1)
    end

    local diff = os.difftime(time1, time2)
    local days = math_floor(diff / SEC_IN_DAY)
    diff = diff % SEC_IN_DAY
    local hours = math_floor(diff / SEC_IN_HOUR)
    diff = diff % SEC_IN_HOUR
    local minutes = math_floor(diff / SEC_IN_MINUTE)
    local seconds = diff % SEC_IN_MINUTE
    return days, hours, minutes, seconds
end

function formatTimeDiff(day, hour, minute, second)
    local timeStr
    if day ~= 0 then
        timeStr = string_format(lang.UTILS_TIME_FORMAT_DAY_STR, day)
    elseif hour ~= 0 then
        timeStr = string_format(lang.UTILS_TIME_FORMAT_HOUR_STR, hour)
    elseif minute ~= 0 then
        timeStr = string_format(lang.UTILS_TIME_FORMAT_MINUTE_STR, minute)
    else
        timeStr = string_format(lang.UTILS_TIME_FORMAT_SECOND_STR, second)
    end
    return timeStr
end

-- 解析与开服相关的时间
-- D:hh.mm.ss 代表开服第D天的hh时mm分ss秒
function parseServerTime(timeString, serverOpenTime)
    local dayStr, timeStr = unpack(string_split(timeString, ":"))
    local timeInfo = string_split(timeStr, ".")
    local dayTime = serverOpenTime + (tonumber(dayStr) - 1) * 3600 * 24
    local year, month, day = getDate(dayTime)
    return getServerTime({
        year = year,
        month = month,
        day = day,
        hour = timeInfo[1],
        min = timeInfo[2],
        sec = timeInfo[3]
    })
end

-- 获取当月的天数
function getDayCountOfMonth(year, month)
    local monthLastDayDate = getServerDate("*t", getServerTime({year = year, month = month + 1, day=0}))
    return monthLastDayDate.day
end

-- if C7.component == "client" then
--     function getCurDayStartTime()
--         return C7.global.dayStartTime
--     end

--     function getCurDayZeroTime()
--         return C7.global.dayZeroTime
--     end

--     function getCurWeekDay()
--         return C7.global.weekDay
--     end
-- end

function notValidActivity(now)
    return nil
end

function championArenaRemainTime(now)
    -- 策划没有配置，容错
    local CHAMPION_ARENA_OPEN_TIME = gameplayConfigData.data.CHAMPION_ARENA_OPEN_TIME
    if not CHAMPION_ARENA_OPEN_TIME then
        return
    end

    local startWeek = CHAMPION_ARENA_OPEN_TIME[START_WEEK_POS]
    local startWeekDay = CHAMPION_ARENA_OPEN_TIME[START_SIGN_UP_POS]
    local startTime = getMonthWeekStartTime(now, startWeek) + (startWeekDay - 1) * const.SECONDS_ONE_DAY
    if now < startTime then
        return startTime - now
    end
    local nextMonthStartTime = getLatterMonthStartTime(now, 1)
    startTime = getMonthWeekStartTime(nextMonthStartTime, startWeek) + (startWeekDay - 1) * const.SECONDS_ONE_DAY

    return startTime - now
end

-- 获取下次活动开始日的剩余时间
function getNextActivityOpenDayRefreshRemainTime(activityId, now)
    local add = activityData.data[activityId]
    if not add then
        return
    end

    local specialFunc = SPECIAL_ACTIVITY_TIME_CALC_FUNC[activityId]
    if specialFunc then
        return specialFunc(now)
    end

    local weekly = add.weekly
    if not weekly or not weekly[1] then
        return
    end
    local currentWeekDay = getWeekDay(now)
    local currentWeekActivityDay
    for i, v in ipairs(weekly) do
        if currentWeekDay < v then
            currentWeekActivityDay = v
            break
        end
    end

    if not currentWeekActivityDay then
        local firstWeekDay = weekly[1]
        local timeToWeekStart = (firstWeekDay - 1) * const.SECONDS_ONE_DAY
        local currentWeekRemainSec = getWeekRemainingSeconds(now)
        return timeToWeekStart + currentWeekRemainSec
    else
        local days = currentWeekActivityDay - currentWeekDay - 1
        return getRemainingSecondsUntilRefreshTime(now) + days * const.SECONDS_ONE_DAY
    end
end

-- 是否本周开启，是否下周开启
function checkNowChampionArenaWeek(now)
    local CHAMPION_ARENA_OPEN_TIME = gameplayConfigData.data.CHAMPION_ARENA_OPEN_TIME
    if not CHAMPION_ARENA_OPEN_TIME then
        return false, false
    end

    local startWeek = CHAMPION_ARENA_OPEN_TIME[START_WEEK_POS]
    local startTime = getMonthWeekStartTime(now, startWeek)
    local endTime = startTime + const.SECONDS_ONE_WEEK
    if now >= startTime and now <= endTime then
        return true, false
    end

    if now < startTime and now >= startTime - const.SECONDS_ONE_WEEK then
        return false, true
    end

    return false, false
end

-- 给2个时间戳，算经过了几个5点
function getDayIntervalByStart(startTime, endTime)
    local dayEndTime = getDayStartTime(endTime)       -- 截止时间上一个5点
    local dayStartTime = startTime + getRemainingSecondsUntilRefreshTime(startTime)   -- 开始时间下一个5点
    local interval = math_floor((dayEndTime - dayStartTime) / const.SECONDS_ONE_DAY)
    return math_max(interval + 1, 0)
end

---GetWeekNumberOfMonth 获取指定时间戳是当月的第几次周几
---@param timestamp number
function getWeekNumberOfMonth(timestamp)
	local dateTable = getServerDate("*t", timestamp)

	local monthFirstDayTimestamp = getServerTime({year = dateTable.year, month = dateTable.month, day = 1})
	-- 获取月份的第一天
	
	-- 计算指定日期是该月的第几周
	local dayOfMonth = math_floor((timestamp - monthFirstDayTimestamp) / (24 * 3600)) + 1
	local weekNumberOfMonth = math_ceil(dayOfMonth / 7)

	return weekNumberOfMonth
end


function getDateOfTargetWeekNumber(timestamp, weekNumber, wday, outDateTable)
	local timezone = TimeUtils.GetServerTimeZone()
	local dateTable = getServerDate("*t", timestamp)
	local monthFirstDayTimestamp = getServerTime({year = dateTable.year, month = dateTable.month, day = 1}, timezone)
	local dayCountOfMonth = getServerDate("*t", getServerTime({year = dateTable.year, month = dateTable.month + 1, day = 0}, timezone)).day
	local firstDayOfWeek = getServerDate("*t", monthFirstDayTimestamp).wday - 1
	if firstDayOfWeek == 0 then
		firstDayOfWeek = 7
	end
	local targetWDay = wday - firstDayOfWeek + 1
	if targetWDay <= 0 then
		targetWDay = targetWDay + 7
	end
	targetWDay = targetWDay + (weekNumber - 1) * 7
	if targetWDay > dayCountOfMonth then
		return
	end
	if outDateTable then
		outDateTable.day = targetWDay
		return outDateTable
	else
		return {year = dateTable.year, month = dateTable.month, day = targetWDay}
	end
end