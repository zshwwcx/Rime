local TableData = TableData
local pairs = pairs
local ipairs = ipairs
local next = next
local unpack = unpack

if _G.IsClient then
    TableData = Game.TableData
    pairs = ksbcpairs
    ipairs = ksbcipairs
    next = ksbcnext
    unpack = ksbcunpack
    getNow = _G._now
end

SceneUtils        = {}
SceneUtils.GetNow = _G.IsClient and _G._now or function() return Game.TimeInMilliSecCache end

ESceneFieldType = {
    Default = "Default", 
    Map = "Map",
}

--获取场景分区 区域类型
--Pos当前位置Vector
--return Type Int32
function GetSceneFieldType(Pos, FieldData, Config)
    if FieldData.RootPos and FieldData.RowCellExportDatas
        and Config.CellSize_X and Config.CellSize_Y then
        local Index_X = (Pos.X - FieldData.RootPos.X) / Config.CellSize_X
        local Index_Y = (Pos.Y - FieldData.RootPos.Y) / Config.CellSize_Y

        if Index_X and Index_Y then
            local ColData = FieldData.RowCellExportDatas[tostring(math.floor(Index_X))]
            if ColData and ColData.ColCellDatas then
                local CellData = ColData.ColCellDatas[tostring(math.floor(Index_Y))]
                if CellData and CellData.Type then
                    return CellData.Type
                end
            end
        end
    end

    return -1
end

--region 场景时间
-- TODO: 待重构, 双端应统一场景时间的计算方式
-- TODO: 目前仅作为 Utils 函数传入, 需要把状态信息 gameStartTime, realTimePerDay, timePeriods 传入, 后续考虑封装为类

SceneUtils.SECONDS_IN_DAY = 24 * 60 * 60

---@param outTimePeriods table
function SceneUtils.InitTimePeriods(inTimeFlowSpeed, outTimePeriods)
    local realTimePerDay = 0
    for id, data in pairs(TableData.GetTimeSettingDataTable() or {}) do
        local h, m, s = data.StartTime:match("(%d+):(%d+):(%d+)")
        local startTime = tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
        h, m, s = data.EndTime:match("(%d+):(%d+):(%d+)")
        local endTime = tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
        table.insert(outTimePeriods, {
            id = id,
            startSeconds = startTime,
            endSeconds = endTime,
            realTime = data.RealTime / inTimeFlowSpeed
        })
        realTimePerDay = realTimePerDay + data.RealTime / inTimeFlowSpeed
    end
    table.sort(outTimePeriods, function(a, b)
        return a.endSeconds < b.endSeconds
    end)
    for i = 1, #outTimePeriods do
        if i == 1 then --第一段特殊处理
            local totalTime = outTimePeriods[i].endSeconds + SceneUtils.SECONDS_IN_DAY - outTimePeriods[i].startSeconds
            outTimePeriods[i].flowSpeed = totalTime / outTimePeriods[i].realTime
            outTimePeriods[i].realEndTime = outTimePeriods[i].endSeconds / outTimePeriods[i].flowSpeed
        else
            local totalTime = outTimePeriods[i].endSeconds - outTimePeriods[i].startSeconds
            outTimePeriods[i].flowSpeed = totalTime / outTimePeriods[i].realTime
            outTimePeriods[i].realEndTime = outTimePeriods[i - 1].realEndTime + outTimePeriods[i].realTime
        end
    end

    return realTimePerDay, outTimePeriods
end

-- 根据场景的时间设置计算当前的时间
---@param inLastJumpTime integer? 时间偏移 s
---@param inElapsedStopTime integer? 时间暂停的时间 ms
function SceneUtils.CalCurrentGameTime(inLastJumpTime, inElapsedStopTime, gameStartTime, realTimePerDay, timePeriods)
    local calCurrentTime
    if inElapsedStopTime and inElapsedStopTime > 0 then
        calCurrentTime = inElapsedStopTime
    else
        calCurrentTime = SceneUtils.GetNow()
    end
    local elapsedRealTime = math.fmod(calCurrentTime / 1000 + (inLastJumpTime or 0) - gameStartTime + realTimePerDay,
        realTimePerDay)


    local index = 1
    for i = 1, #timePeriods do
        if elapsedRealTime < timePeriods[i].realEndTime then
            index = i
            break
        end
    end

    local gameTime
    if index == 1 and timePeriods[#timePeriods].realEndTime < elapsedRealTime then
        gameTime = (timePeriods[index].endSeconds + SceneUtils.SECONDS_IN_DAY - (timePeriods[index].realEndTime + realTimePerDay - elapsedRealTime) * timePeriods[index].flowSpeed)
    else
        gameTime = timePeriods[index].endSeconds -
            (timePeriods[index].realEndTime - elapsedRealTime) * timePeriods[index].flowSpeed
    end
    return gameTime, index
end

---@return number hour, number min, number sec
function SceneUtils.ConvertGameTime(inGameTime)
    return math.floor(inGameTime / 3600), math.floor((inGameTime % 3600) / 60), math.floor(inGameTime % 60)
end

function SceneUtils.CalGameTimeToRealTime(inGameTime, timePeriods, realTimePerDay)
    local index = 1
    for i = 1, #timePeriods do
        if inGameTime < timePeriods[i].endSeconds then
            index = i
            break
        end
    end

    local realTime
    local flowSpeed = timePeriods[index].flowSpeed
    if index == 1 and timePeriods[#timePeriods].endSeconds < inGameTime then
        realTime = (timePeriods[index].realEndTime + realTimePerDay - (timePeriods[index].endSeconds + SceneUtils.SECONDS_IN_DAY - inGameTime) / flowSpeed)
    else
        realTime = timePeriods[index].realEndTime - (timePeriods[index].endSeconds - inGameTime) / flowSpeed
    end

    return realTime % realTimePerDay
end

--endregion
