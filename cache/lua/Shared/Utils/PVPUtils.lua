local pvp_const = kg_require("Shared.Const.PVPConst")

local TableData = TableData

local math_round = math.round
local math_random = math.random
local table_sort = table.sort

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

WORLD_DELAY_DESTROY_SEC = 20
BATTLE_NOTICE_COUNT_IDX = 1
BATTLE_NOTICE_TIME_IDX = 2

COMPARE_FUNC =
{
    [">="] = function(curCount, needCount) return curCount >= needCount end,
    [">"] = function(curCount, needCount) return curCount > needCount end,
    ["<="] = function(curCount, needCount) return curCount <= needCount end,
    ["<"] = function(curCount, needCount) return curCount < needCount end,
    ["="] = function(curCount, needCount) return curCount == needCount end,
    ["!="] = function(curCount, needCount) return curCount ~= needCount end,
}

function GenGameModeConfig(modeID)
    local rowData = TableData.GetPVPGameModeDataRow(modeID)
    assert(rowData and next(rowData.Rules))

    local rules = {}
    for i, ruleID in ipairs(rowData.Rules) do
        local ruleData = TableData.GetPVPRoundConfigDataRow(ruleID)
        -- TODO 导表后处理强制检查
        assert(ruleData)
        rules[i] = ruleData
    end

    return rules
end

function GetRandomDestroySec()
    return math_random(1, WORLD_DELAY_DESTROY_SEC * 10)/10
end

function isExcludeID(excludeList, retMap)
    if not retMap then
        return false
    end

    -- 一般来说excludeList会很少(1-2个)，因此遍历消耗更小
    for _, id in ipairs(excludeList) do
        if retMap[id] then
            return true
        end
    end

    return false
end

function UpdateBattleNoticeStat(eventType, statDict, customIDs, num, configID2Times)
    local instant = eventType >= pvp_const.INSTANT_BATTLE_NOTICE
    -- 根据event类型来记录当前值，部分类型的播报会使用，比如连斩终结
    statDict[eventType] = instant and num or ((statDict[eventType] or 0) + num)

    local ret
    -- 导表规则中约束了越靠前优先级越高
    for _, customID in ipairs(customIDs) do
        local stat = statDict[customID]
        if not stat then
            stat = {}
            statDict[customID] = stat
        end

        stat[BATTLE_NOTICE_COUNT_IDX] = instant and num or ((stat[BATTLE_NOTICE_COUNT_IDX] or 0) + num)
        stat[BATTLE_NOTICE_TIME_IDX] = math_round(_script.getNow())
        -- 检查是否有满足条件的
        local rowData = TableData.GetBattleNoticeDataRow(customID)
        assert(rowData)
        local timesLimit = rowData.TimesLimit
        if timesLimit == 0 or timesLimit > (configID2Times[customID] or 0) then
            local compareFunc = COMPARE_FUNC[rowData.ConditionOperator]
            if compareFunc(stat[BATTLE_NOTICE_COUNT_IDX], rowData.ConditionArg) then
                if not (next(rowData.Exclude) and isExcludeID(rowData.Exclude, ret)) then
                    ret = ret or {}
                    ret[customID] = rowData.HeadState or 0
                end
            end
        end
    end

    return ret
end

local function sortAndGenTopPlayer(battleStatQueue, ret, field, statsType)
    table_sort(battleStatQueue, function(a, b)
        if a[field] ~= b[field] then
            return (a[field] or 0) > (b[field] or 0) 
        end
        -- 伤害没有称号，目前称号计算在数值相同的情况下，以伤害作为判断依据
        if a.Damage ~= b.Damage then
            return (a.Damage or 0) > (b.Damage or 0) 
        end 
        -- 概率较低，均一样的情况下用index排序
        return a.Index < b.Index
    end)

    local minVal = TableData.GetPVPBattleTitleDataRow(statsType).MinValue
    for _, info in ipairs(battleStatQueue) do
        if (info[field] or 0) < minVal then
            break
        end
        local id = info.id
        if not ret[id] then
            ret[statsType] = id
            ret[id] = true
            return
        end
    end
end

function GenTeamArenaMemberBadages(battleStatQueue, gameMode)
    local ret = {}
    local list = TableData.Get_PVPBattleTitleList()[gameMode]
    -- 表里配置了徽章获取优先级
    for _, info in ipairs(list) do
        local filed, id = unpack(info)
        sortAndGenTopPlayer(battleStatQueue, ret, filed, id)
    end

    return ret
end

-- 策划目前要求结算界面每个玩家只有一个称号
-- 对局表现的称号机制上是允许多个的，此处选一个优先级最高的来展示
function chooseTeamArenaCalcTitle(titleMap)
    if not titleMap or not next(titleMap) then
        return 0
    end

    local sortArray = {}
    local GetTitleDataRow = TableData.GetTitleDataRow
    for titleID, _ in pairs(titleMap) do
        local rowData = GetTitleDataRow(titleID)
        if rowData then
            sortArray[#sortArray+1] = titleID
        end
    end
    table.sort(sortArray, function(a, b) return titleMap[a] < titleMap[b] end)
    return sortArray[1]
end