local Enum = Enum
local EDynamicCampType = kg_require("Shared.Const.AbilityConst").EDynamicCampType
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

-------------------- Camp Public Function Begin ------------------------
-- 判断和目标的关系
function GetTargetRealCampRelation(Owner, Target)
    local relation
    -- 1 判断动态玩法关系(暂时只有红名，预留后续拓展)
    local ownerDynamicCamp = Owner.DynamicCampRule
    local targetDynamicCamp = Target.DynamicCampRule
    if ownerDynamicCamp == EDynamicCampType.RedNameRule and targetDynamicCamp == EDynamicCampType.RedNameRule then
        -- 红名判断规则
        relation = checkRedNameRelation(Owner, Target)
        return relation
    end

    -- 2 判断动态阵营/基础阵营关系
    local ownerCamp = Owner.Camp
    local targetCamp = Target.Camp
    relation = GetCampRelation(ownerCamp, targetCamp)

    return relation
end

-- 读取camp表配置基础阵营关系
function GetCampRelation(CampA, CampB)
    local CampRelation = -1
    local CRData = TableData.GetCampRelationDataRow(CampA)

    if (CRData ~= nil) and (CRData.Relation ~= nil) and (CRData.Relation[CampB] ~= nil) then
        CampRelation = CRData.Relation[CampB]
    end

    return CampRelation
end
-------------------- Camp Public Function End ------------------------


-------------------- Camp Private Function Begin ------------------------

function checkRedNameRelation(Owner, Target)
    local ownerTID = Owner.ITeamID or Owner.teamID
    local ownerGID = Owner.IgroupID or Owner.groupID
    local targetTID = Target.ITeamID or Target.teamID
    local targetGID = Target.IgroupID or Target.groupID

    -- 1.同团队/队伍强制友好
    if ownerTID and ownerTID ~= 0 and ownerTID == targetTID then
        return Enum.ECampEnumData.Friendly
    end
    if ownerGID and ownerGID ~= 0 and ownerGID == targetGID then
        return Enum.ECampEnumData.Friendly
    end

    -- 2.私有红名列表内玩家敌对
    local fightRelationship = Owner.FightRelationship
    local targetID = Target.int_id or Target.eid
    if fightRelationship and fightRelationship[targetID] then
        return Enum.ECampEnumData.Enemy
    end

    -- 3.对战模式和保护设置检查
    if Owner.FightModeType == Enum.EBattleModeData.PEACE_MODE then
        -- 3.1 理智模式强制和平
        return Enum.ECampEnumData.Friendly
    end

    local protectionSetting = getSettingValue(Owner, Enum.ESettingDataEnum.OpenProtection, Enum.ESettingConfigData.OPEN_PROTECTION)
    if protectionSetting == 1 then
        -- 3.2检查保护设置
        -- 等级保护
        local levelLimit = getSettingValue(Owner, Enum.ESettingDataEnum.LevelProtection, Enum.ESettingConfigData.LEVEL_PROTECTION)
        if Target.Level < levelLimit then
            return Enum.ECampEnumData.Friendly
        end

        -- 非敌对公会保护 策划预留功能 TODO
        -- 绿名保护
        local greenSetting = getSettingValue(Owner, Enum.ESettingDataEnum.GreenProtection, Enum.ESettingConfigData.GREEN_PROTECTION)
        if greenSetting and GetNameColor(Target) == "GREEN" then
            return Enum.ECampEnumData.Friendly
        end

        -- 公会保护
        local guildSetting = getSettingValue(Owner, Enum.ESettingDataEnum.GuildProtection, Enum.ESettingConfigData.GUILD_PROTECTION)
        if guildSetting and Owner.guildId and Owner.guildId ~= "" and Owner.guildId == Target.guildId then
            return Enum.ECampEnumData.Friendly
        end
    end

    if Owner.FightModeType == Enum.EBattleModeData.TRIAL_MODE then
        -- 3.3 狩猎模式不攻击非红名玩家
        local bounty = Target.Bounty or 0
        if bounty < Enum.ERedNameConstIntData.MIN_RED_BOUNTY then
            return Enum.ECampEnumData.Friendly
        end
    end

    -- 3.4 疯狂模式均可攻击
    return Enum.ECampEnumData.Enemy
end

function getSettingValue(Actor, ClientSettingName, ServerSettingName)
    if Actor.GetSettingValueByID then
        return Actor:GetSettingValueByID(ServerSettingName)
    else
        local settingManager = Game.SettingsManager
        return settingManager:GetIniData(ClientSettingName)
    end
end
-------------------- Camp Private Function End ------------------------


-------------------- RedName Public Function Begin --------------------
-- 查询玩家红名颜色
function GetNameColor(Actor)
    local colorData = TableData.GetRedNameStageDataTable()
    if colorData == nil then
       LOG_ERROR_FMT("[FightModeComponent:GetNameColor] GetRedNameStageDataTable Failed!")
        return
    end

    local bounty = Actor.Bounty or 0
    local yellowNameTime = Actor.yellowNameTime or 0
    for _, stage in pairs(colorData) do
        if bounty >= stage.NumericalDuration[1] and bounty <= stage.NumericalDuration[2] then
            if stage.ColorName == "YELLOW" then
                if yellowNameTime > 0 then
                    return stage.ColorName
                end
            elseif stage.ColorName == "GREEN" then
                if yellowNameTime <= 0 then
                    return stage.ColorName
                end
            else
                return stage.ColorName
            end
        end
    end
end



-------------------- RedName Public Function End --------------------