
local const = kg_require("Shared.Const")
local itemConst = kg_require("Shared.ItemConst")
-- local timeUtils = kg_require("Shared.Utils.TimeUtils")
local TableData = Game.TableData or TableData

-- local activityData = kg_require("data.activity_data")
-- local gameplayConfigData = kg_require("data.gameplay_config_data")
-- local guildChallengeDiffucultiesData = kg_require("data.guild_challenge_difficulties_data")
-- local guildTalentShowGameplayConfigData = kg_require("data.guild_talent_show_gameplay_config_data")

function getGuildBuildingTopLv(buildingType)
    if buildingType == const.GUILD_BUILDING_TYPE.MAIN then
        return Enum.EConstIntData.GUILD_LEVEL_TOPLIMIT
    elseif buildingType == const.GUILD_BUILDING_TYPE.PUB then
        return Enum.EConstIntData.GUILD_PUB_LEVEL_TOPLIMIT
    elseif buildingType == const.GUILD_BUILDING_TYPE.VAULT then
        return Enum.EConstIntData.GUILD_VAULT_LEVEL_TOPLIMIT
    elseif buildingType == const.GUILD_BUILDING_TYPE.SCHOOL then
        return Enum.EConstIntData.GUILD_TRAINING_GROUND_LEVEL_TOPLIMIT
    elseif buildingType == const.GUILD_BUILDING_TYPE.SHOP then
        return Enum.EConstIntData.GUILD_TRAINING_GROUND_LEVEL_TOPLIMIT
    end
    return 0
end

--- 获取公会建筑等级
-- @param buildings
-- @param bType
-- @return buildingLv
function getGuildBuildingLv(buildings, bType)
    local building = (buildings or {})[bType]
    if bType == const.GUILD_BUILDING_TYPE.MAIN then
        return building and building.lv or 1
    else
        return building and building.lv or 1
    end
end

--- 获取某个公会建筑维护费用
-- @param lv
-- @param bType
-- @return gmdd.buildingLevelCost[bType] or 0
function getGuildBuildingMaintCost(lv, bType)
    local gmdd = TableData.GetGuildMaintenanceDataRow(lv)
    return gmdd and gmdd.BuildingLevelCost[bType] or 0
end

--- 获取公会维护费用
-- @param buildings
-- @return cost
function getGuildMaintCost(buildings)
    local cost = 0
    for _, bType in pairs(const.GUILD_BUILDING_TYPE) do
        local lv = getGuildBuildingLv(buildings, bType)
        cost = cost + getGuildBuildingMaintCost(lv, bType)
    end
    return cost
end

function getGuildDinnerTotalAwardCnt()
    return math.floor(gameplayConfigData.data.GUILD_DINNER_AWARD_TIME / gameplayConfigData.data.GUILD_DINNER_AWARD_INTERVAL)
end

--- 获取公会创建类型对应的货币消耗
---- TODO 对应配置读取！！！
-- return moneyType, moneyNum
function getCreateGuildCost(createType)
    if createType == const.GUILD_CREATE_TYPE.COMMON then
        return Enum.EConstIntData.CREATE_GUILD_MONEY_TYPE_COMMON, Enum.EConstIntData.CREATE_GUILD_MONEY_COMMON
    elseif createType == const.GUILD_CREATE_TYPE.ADVANCED then
        return Enum.EConstIntData.CREATE_GUILD_MONEY_TYPE_ADVANCE, Enum.EConstIntData.CREATE_GUILD_MONEY_ADVANCE
    end
end

--- 获取公会创建失败时对应的货币返还
-- return moneyType, moneyNum
function getCreateGuildRetrun(createType)
    if createType == const.GUILD_CREATE_TYPE.COMMON then
        return Enum.EConstIntData.CREATE_GUILD_MONEY_TYPE_COMMON, Enum.EConstIntData.CREATE_GUILD_MONEY_COMMON
    elseif createType == const.GUILD_CREATE_TYPE.ADVANCED then
        return Enum.EConstIntData.CREATE_GUILD_MONEY_TYPE_ADVANCE, Enum.EConstIntData.CREATE_GUILD_MONEY_ADVANCE
    end
end

--- 获取公会创建需要的玩家数
function getCreateGuildNeedPlayerNum(createType)
    if createType == const.GUILD_CREATE_TYPE.COMMON then
        return Enum.EConstIntData.GUILD_RESPONDS_MAX_NUM_COMMON
    elseif createType == const.GUILD_CREATE_TYPE.ADVANCED then
        return Enum.EConstIntData.GUILD_RESPONDS_MAX_NUM_ADVANCE
    end
end