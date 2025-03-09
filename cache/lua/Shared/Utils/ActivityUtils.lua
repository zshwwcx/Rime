local os_date = os.date
local os_time = os.time
local tonumber = tonumber
local string_split = string.split
local math_abs = math.abs
local math_max = math.max
local math_floor = math.floor
local string_format = string.format
local timeUtils = kg_require("Shared.Utils.TimeUtils")
local TableData = Game.TableData or TableData

local pairs = pairs
local ipairs = ipairs
local next = next
local unpack = unpack
if _G.IsClient then
    pairs = ksbcpairs
    ipairs = ksbcipairs
    next = ksbcnext
    unpack = ksbcunpack
end

function GetWeekRefreshActivityNextOpenTime(ActivityID)
    local ActivityData = TableData.GetActivityDataRow(ActivityID)
    if ActivityData == nil then
        LOG_DEBUG_FMT("GetWeekRefreshActivityNextOpenTime not find ActivityData for ActivityID:%s", ActivityID)
        return nil
    end
    local OpenTimeStr = ActivityData.ActivityOpenTimeNew
    if OpenTimeStr[0] == nil then
        LOG_DEBUG_FMT("GetWeekRefreshActivityNextOpenTime  ActivityData is not week refresh for ActivityID:%s", ActivityID)
        return nil
    end
    local current_timestamp = os.time()
    local current_weekday = timeUtils.getWeekDay(current_timestamp)
    local min_diff = math.huge
    local nearest_datetime = nil
    local Year = timeUtils.getYear(current_timestamp)
    local Month = timeUtils.getMonth(current_timestamp)
    local Day = timeUtils.getDay(current_timestamp)
    for WeekIndex, TimeInfo in pairs(OpenTimeStr[0]) do
        for i = 1, #TimeInfo, 2 do
            local NextDay = Day + (WeekIndex - current_weekday) % 7
            local target_datetime = os.time({
                year = Year,
                month = Month,
                day = NextDay,
                hour = TimeInfo[i][1],
                min = TimeInfo[i][2],
                sec = TimeInfo[i][3]
            })
            local diff = target_datetime - current_timestamp
            if diff < 0 then
                diff = diff + 7 * timeUtils.SEC_IN_DAY
                target_datetime = target_datetime + 7 * timeUtils.SEC_IN_DAY
            end
            if diff < min_diff then
                min_diff = diff
                nearest_datetime = target_datetime
            end
        end
    end
    return nearest_datetime
end

function GetMonthRefreshActivityNextOpenTime(ActivityID)
	local ActivityData = TableData.GetActivityDataRow(ActivityID)
	if ActivityData == nil or ActivityData.ActivityOpenTimeNew == nil or #ActivityData.ActivityOpenTimeNew == 0 then
		return nil
	end
	local ActivityOpenTime = ActivityData.ActivityOpenTimeNew
	local timezone = TimeUtils.GetServerTimeZone()
	local currentTimestamp = math_floor(_G._now() / 1000)
	local timestampOfCalculate =  currentTimestamp
	local dateTb = timeUtils.getServerDate("*t", currentTimestamp)
	local tmpDateTb = {year = dateTb.year, month = dateTb.month, day = dateTb.day}
	while(true) do
		local openTimeList = {}
		for weekIndex, week in pairs(ActivityOpenTime) do
			for dayIndex, day in pairs(week) do
				for i = 1, #day, 2 do
					if timeUtils.getDateOfTargetWeekNumber(timestampOfCalculate, weekIndex, dayIndex, tmpDateTb) then
						tmpDateTb.hour = day[i][1]
						tmpDateTb.mine = day[i][2]
						tmpDateTb.sec = day[i][3]
						openTimeList[#openTimeList+1] = timeUtils.getServerTime(tmpDateTb, timezone)
						tmpDateTb.yday = nil
						tmpDateTb.wday = nil
					end
				end
			end
		end
		table.sort(openTimeList)
		for i, v in pairs(openTimeList) do
			if currentTimestamp < v then
				return v
			end
		end
		tmpDateTb.month = tmpDateTb.month + 1
		if tmpDateTb.month == 13 then
			tmpDateTb.year = tmpDateTb.year + 1
			tmpDateTb.month = 1
		end
		timestampOfCalculate = timeUtils.getServerTime(tmpDateTb)
	end
end

function GetRefreshActivityNextOpenTime(ActivityID)
	local ActivityData = TableData.GetActivityDataRow(ActivityID)
	if ActivityData == nil then
		return nil
	end
	if ActivityData.OpenDayType == 0 then
		return GetWeekRefreshActivityNextOpenTime(ActivityID)
	else
		return GetMonthRefreshActivityNextOpenTime(ActivityID)
	end
end

function GetWeekRefreshActivityTodayOpenTime(ActivityID, currentTimeStamp)
    local ActivityData = TableData.GetActivityDataRow(ActivityID)
    local OpenTime = {}
    if ActivityData == nil then
        LOG_DEBUG_FMT("GetWeekRefreshActivityTodayOpenTime not find ActivityData for ActivityID:%s", ActivityID)
        return OpenTime
    end
    local OpenTimeStr = ActivityData.ActivityOpenTimeNew
    if OpenTimeStr[0] == nil then
        LOG_DEBUG_FMT("GetWeekRefreshActivityTodayOpenTime  ActivityData is not week refresh for ActivityID:%s", ActivityID)
        return OpenTime
    end
    local current_timestamp = currentTimeStamp
    local current_weekday = timeUtils.getWeekDay(current_timestamp)
    local Year = timeUtils.getYear(current_timestamp)
    local Month = timeUtils.getMonth(current_timestamp)
    local Day = timeUtils.getDay(current_timestamp)
    if OpenTimeStr[0][current_weekday] == nil then
        LOG_DEBUG_FMT("GetWeekRefreshActivityTodayOpenTime  ActivityData is not open today for ActivityID:%s", ActivityID)
        return OpenTime
    end
    for i = 1, #OpenTimeStr[0][current_weekday] do
        table.insert(OpenTime, {
            year = Year,
            month = Month,
            day = Day,
            hour = OpenTimeStr[0][current_weekday][i][1],
            min = OpenTimeStr[0][current_weekday][i][2],
            sec = OpenTimeStr[0][current_weekday][i][3]
        })
    end
    return OpenTime
end

function GetWeekRefreshActivityDayOpenTime(ActivityID, WeekIndex)
    local ActivityData = TableData.GetActivityDataRow(ActivityID)
    local OpenTime = {}
    if ActivityData == nil then
        LOG_DEBUG_FMT("GetWeekRefreshActivityDayOpenTime not find ActivityData for ActivityID:%s", ActivityID)
        return OpenTime
    end
    local OpenTimeStr = ActivityData.ActivityOpenTimeNew
    if OpenTimeStr[0] == nil then
        LOG_DEBUG_FMT("GetWeekRefreshActivityDayOpenTime  ActivityData is not week refresh for ActivityID:%s", ActivityID)
        return OpenTime
    end
    if OpenTimeStr[0][WeekIndex] == nil then
        LOG_DEBUG_FMT("GetWeekRefreshActivityDayOpenTime  ActivityData is not open today for ActivityID:%s", ActivityID)
        return OpenTime
    end
    for i = 1, #OpenTimeStr[0][WeekIndex], 2 do
        local TimeStr = string.format("%s:%s:%s", OpenTimeStr[0][WeekIndex][i][1], OpenTimeStr[0][WeekIndex][i][2], OpenTimeStr[0][WeekIndex][i][3])
        table.insert(OpenTime, TimeStr)
    end
    return OpenTime
end

---GetOpenTimeOfTimeStamp 获取时间戳当天活动的所有开关时间
---@param activityID number 活动id
---@param timeStamp number 时间戳(s)
function GetOpenTimeByTimeStamp(activityID, timeStamp)
	local activityData = TableData.GetActivityDataRow(activityID)
	if activityData == nil then
		return 
	end
	local openTimeFullData = activityData.ActivityOpenTimeNew
	
	if activityData.OpenDayType == 0 then
		if openTimeFullData[0] == nil then
			return
		end
		local weekday = timeUtils.getWeekDay(timeStamp)
		return openTimeFullData[0][weekday]
	else
		local weekNumber = timeUtils.getWeekNumberOfMonth(timeStamp)
		local OpenTimeFullData = activityData.ActivityOpenTimeNew
		if OpenTimeFullData[weekNumber] == nil then
			return
		end
		local weekday = timeUtils.getWeekDay(timeStamp)
		return OpenTimeFullData[weekNumber][weekday]
	end
end

function GetMonthRefreshActivityTodayOpenTime(ActivityID, currentTimeStamp)
    local ActivityData = TableData.GetActivityDataRow(ActivityID)
    local OpenTime = {}
    if ActivityData == nil then
        LOG_DEBUG_FMT("GetWeekRefreshActivityTodayOpenTime not find ActivityData for ActivityID:%s", ActivityID)
        return OpenTime
    end
    local OpenTimeStr = ActivityData.ActivityOpenTimeNew
    if OpenTimeStr[0] then
        LOG_DEBUG_FMT("GetWeekRefreshActivityTodayOpenTime  ActivityData is not Month refresh for ActivityID:%s", ActivityID)
        return OpenTime
    end
    local current_timestamp = currentTimeStamp
    local current_weekday = timeUtils.getWeekDay(current_timestamp)
    local Year = timeUtils.getYear(current_timestamp)
    local Month = timeUtils.getMonth(current_timestamp)
    local Day = timeUtils.getDay(current_timestamp)
    local monthWeekStart
    local weekstart
    for weekIndex, timeStr in pairs(OpenTimeStr) do
        monthWeekStart = timeUtils.getMonthWeekStartTime(current_timestamp, weekIndex)
        weekstart = timeUtils.getWeekStartTime(current_timestamp)
        if monthWeekStart == weekstart then
            if not OpenTimeStr[weekIndex][current_weekday] then
                LOG_DEBUG_FMT("GetWeekRefreshActivityTodayOpenTime  ActivityData is not Month refresh for ActivityID:%s", ActivityID)
                return OpenTime
            else
                for i = 1, #OpenTimeStr[weekIndex][current_weekday] do
                    table.insert(OpenTime, {
                        year = Year,
                        month = Month,
                        day = Day,
                        hour = OpenTimeStr[weekIndex][current_weekday][i][1],
                        min = OpenTimeStr[weekIndex][current_weekday][i][2],
                        sec = OpenTimeStr[weekIndex][current_weekday][i][3]
                    })
                end
            end
            break
        end
    end
    return OpenTime
end

function isInActivityTimeByTimestamp(activityID, now)
    local dayOpenTime = GetOpenTimeByTimeStamp(activityID, now)
    if not dayOpenTime then
        return false
    end
    local secondFromDayZero = now - timeUtils.getDayZeroTime(now)
    local dayStartTime, dayEndTime = unpack(dayOpenTime)
    if dayStartTime then
        local hour, min, sec = unpack(dayStartTime)
        local dayStartSeconds = (hour or 0) * 3600 + (min or 0) * 60 + (sec or 0)
        if secondFromDayZero < dayStartSeconds then
            return false
        end
    end
    if dayEndTime then
        local hour, min, sec = unpack(dayEndTime)
        local dayEndSeconds = (hour or 0) * 3600 + (min or 0) * 60 + (sec or 0)
        if secondFromDayZero > dayEndSeconds then
            return false
        end
    end
    return true
end

-- ActivityUtils = kg_require("Shared.Utils.ActivityUtils")
-- ActivityUtils.GetWeekRefreshActivityNextOpenTime(1013)