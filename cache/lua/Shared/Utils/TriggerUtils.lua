local sharedConst = kg_require("Shared.Const")
local lume = kg_require("Shared.lualibs.lume")

local tonumber = tonumber -- luacheck: ignore
local TableData = Game.TableData or TableData
local math = math
TRIGGER_CONDITION_FUNC = {} -- 当前拥有类型的触发器,需要实现对应的取值函数,变量数据源于其他系统

-- 服务端没有 ksbc
local ksbcipairs = ksbcipairs or ipairs

local CompareFunction =
{
    [">="] = function(curCount, needCount) return curCount >= needCount end,
    [">"] = function(curCount, needCount) return curCount > needCount end,
    ["<="] = function(curCount, needCount) return curCount <= needCount end,
    ["<"] = function(curCount, needCount) return curCount < needCount end,
    ["="] = function(curCount, needCount) return curCount == needCount end,
	["=="] = function(curCount, needCount) return curCount == needCount end,
    ["!="] = function(curCount, needCount) return curCount ~= needCount end,
}

function MakeTriggerKey(systemID, key)
    return tonumber(key) * sharedConst.TRIGGER_CONDITION_SYSTEM_KEY +  tonumber(systemID)
end

function ParseTriggerKey(triggerKey)
    local system = math.floor(triggerKey % sharedConst.TRIGGER_CONDITION_SYSTEM_KEY)
    local key = math.floor(triggerKey / sharedConst.TRIGGER_CONDITION_SYSTEM_KEY)
    return system, key
end

function ParseConditionKey(ConditionKey)
    local conditionIndex = math.floor(ConditionKey % sharedConst.TRIGGER_CONDITION_KEY)
    local conditionID = math.floor(ConditionKey / sharedConst.TRIGGER_CONDITION_KEY)
    return conditionID, conditionIndex
end

function IsSingleConditionMeetRequirement(condition, curCount)
    if not condition or not condition["target"] or curCount == nil then
        return false
    end

    local needCount = condition["target"]
    local operator = condition["operate"] or ">="
    local func = CompareFunction[operator]
    if not func then
        return false
    end

    return func(curCount, needCount)
end

function MakeLifeStyleBornKey(customID, conditionIndex)
    return customID.."_"..conditionIndex
end

function IsTriggerFuncImplement(trigger)
    local func = TRIGGER_CONDITION_FUNC[trigger]
    return func and true or false
end

-- 对外暴露查询接口，conditionData可以为空
function GetTriggerCount(avatar, triggerKey, customID, condIndex, conditionData, cnt)
    if not conditionData then
        local customData = TableData.GetTriggerCustomDataRow(customID)
        if not customData then
            LOG_DEBUG_FMT("GetTriggerCount not find customData for customID:%s", customID)
            return 0
        end

        conditionData = customData.Condition[condIndex]
        if not conditionData then
            LOG_DEBUG_FMT("GetTriggerCount not find conditionData for customID:%s, condIndex:%s", customID, condIndex)
            return 0
        end
    end

    local func = TRIGGER_CONDITION_FUNC[conditionData.trigger]
    -- 当前值
    if func then
        local count = func(avatar, conditionData["args"], cnt)
        return count
    else
        -- 出生计数历史值
        if conditionData.lifeType == Enum.ETRIGGER_LIFE_STYLE.BORN then
            local triggerBornKey = MakeLifeStyleBornKey(customID, condIndex)
            if not avatar.triggerForeverCounter[triggerBornKey] then
                return 0
            end

            return avatar.triggerForeverCounter[triggerBornKey]
        else
        -- 接取计数历史值
            if not IsTempTriggerValid(avatar, triggerKey, customID, condIndex) then
                return 0
            end

            return avatar.triggerTempCounter[triggerKey][customID][condIndex]
        end
    end

    return 0
end

function IsTempTriggerValid(avatar, triggerKey, customID, condIndex)
    if not avatar.triggerTempCounter[triggerKey] or
        not avatar.triggerTempCounter[triggerKey][customID] or
        not avatar.triggerTempCounter[triggerKey][customID][condIndex] then
            return false
    end

    return true
end

function InitTempTrigger(avatar, triggerKey, customID, condIndex)
    if not avatar.triggerTempCounter[triggerKey] then
        avatar.triggerTempCounter[triggerKey] = {}
    end

    if not avatar.triggerTempCounter[triggerKey][customID] then
        avatar.triggerTempCounter[triggerKey][customID] = {}
    end

    if not avatar.triggerTempCounter[triggerKey][customID][condIndex] then
        avatar.triggerTempCounter[triggerKey][customID][condIndex]  = 0
    end
end

function SetTriggerCount(avatar, triggerKey, customID, condIndex, cnt, conditionData)
    local func = TRIGGER_CONDITION_FUNC[conditionData.trigger]
    -- 当前值
    if func then
        local count = func(avatar, conditionData["args"], cnt)
        return count
    else
        -- 出生计数历史值
        if conditionData.lifeType == Enum.ETRIGGER_LIFE_STYLE.BORN then
            local triggerBornKey = MakeLifeStyleBornKey(customID, condIndex)
            if not avatar.triggerForeverCounter[triggerBornKey] then
                avatar.triggerForeverCounter[triggerBornKey] = cnt
            end

            return avatar.triggerForeverCounter[triggerBornKey]
        else
            -- 接取计数历史值
            if not IsTempTriggerValid(avatar, triggerKey, customID, condIndex) then
                InitTempTrigger(avatar, triggerKey, customID, condIndex)
            end

            local newCount = avatar.triggerTempCounter[triggerKey][customID][condIndex]
            newCount = newCount + cnt
            avatar.triggerTempCounter[triggerKey][customID][condIndex] = newCount
            return newCount
        end
    end
end

function CanTriggerConditionCompleted(avatar, triggerKey, customData, skipIndex)
    local req = {}
    local maxFlag = 0

    for index, condData in ksbcipairs(customData.Condition) do
        local flag = customData.ConditionExpression[index]

        if index == skipIndex then req[flag] = true end
        if flag > 1 and not req[flag - 1] then return false end
        maxFlag = flag > maxFlag and flag or maxFlag

        if not req[flag] then
            local curCount = SetTriggerCount(avatar, triggerKey, customData.ID, index, 0, condData)
            if IsSingleConditionMeetRequirement(condData, curCount) then
                req[flag] = true
            end
        end
    end

    return req[maxFlag] or false
end

-- 查询接口，是否完成condition
function CanTriggerCompleted(avatar, system, key, customID)
    local triggerKey = MakeTriggerKey(system, key)
    local customData = TableData.GetTriggerCustomDataRow(customID)

	if not customData then
		LOG_DEBUG_FMT("CanTriggerCompleted not find customData for customID:%s", customID)
		return false
	end

    return CanTriggerConditionCompleted(avatar, triggerKey, customData)
end

-- 查询接口，返回一个condition内部的单个条件是否满足
---@param avatar
---@param system Enum.TriggerModuleType
---@param key number 后端注册的key
---@param customID number TriggerCustomData的ID
---@param condIndex number 内部第几个条件
---@return boolean
function CanSingleTriggerCompleted(avatar, system, key, customID, condIndex)
    local triggerKey = MakeTriggerKey(system, key)
    local customData = TableData.GetTriggerCustomDataRow(customID)
	if not customData then
		LOG_DEBUG_FMT("GetTriggerCount not find customData for customID:%s", customID)
		return false
	end

	local conditionData = customData.Condition[condIndex]
	if not conditionData then
		LOG_DEBUG_FMT("GetTriggerCount not find conditionData for customID:%s, condIndex:%s", customID, condIndex)
		return false
	end
    local count = GetTriggerCount(avatar, triggerKey, customID, condIndex, conditionData)
    return IsSingleConditionMeetRequirement(conditionData, count)
end

-- 查询接口，返回一个condition内部的所有条件的情况，注意此处不会区分ConditionExpression表达式，仅返回具体值
---@return table
function GetAllSingleTriggerInfo(avatar, system, key, customID)
    local triggerKey = MakeTriggerKey(system, key)
    local customData = TableData.GetTriggerCustomDataRow(customID)
    local answer = {}

    for index, condData in ipairs(customData.Condition) do
        local curCount = SetTriggerCount(avatar, triggerKey, customData.ID, index, 0, condData)
        answer[index] = {Completed = IsSingleConditionMeetRequirement(condData, curCount), Number = curCount}
    end

    return answer
end


-- 获取等级
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.LEVELUP] = function(actor)
    return actor.Level
end

-- 获取部位强化套装数量
-- 依赖事件传入当前值，避免重复计算
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.BODY_ENHANCE_SUIT_COUNT] = function(actor, args, count)
    return count
end

-- 获取部位强化数量
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.BODY_ENFORCE] = function(actor, args)
    local count = 0
    local minStage = args[1] and args[1]["value"] or 1
    local cmpStage = args[1] and args[1]["cmp"] or ">="
    local equipmentBodyInfo = actor.equipmentBodyInfo or Game.EquipmentSystem.model.equipmentBodyInfo
    local equipmentBodyEnhanceSlots = equipmentBodyInfo.enhanceInfo.slots
    for _, info in pairs(equipmentBodyEnhanceSlots) do
        local stage = table.getn(info.stages)
        if CompareFunction[cmpStage](stage, minStage) then
            count = count + 1
        end
    end

    return count
end

-- 获取命运点
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.DESTINY_POINTS] = function(actor, args)
    return 0
end

-- 获取是否加入公会
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.JOIN_GUILD] = function(actor, args)
    return actor:isInGuild() and 1 or 0
end

-- 获取装备品质装备数量
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.EQUIP_QUALITY_EQUIPMENT] = function(actor, args)
    local count = 0
    local minQuality = args[1] and args[1]["value"] or 1
    local cmpQuality = args[1] and args[1]["cmp"] or ">="

    local equipmentSlotInfo = actor.equipmentSlotInfo or Game.EquipmentSystem.model.equipmentSlotInfo
	if equipmentSlotInfo and equipmentSlotInfo.slots then 
		for _, equip in pairs(equipmentSlotInfo.slots) do
			if CompareFunction[cmpQuality](equip.quality, minQuality) then
				count = count + 1
			end
		end
		return count
	else 
		return 0
	end
end

-- 获取封印物共鸣度
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.SEALED_RESONANCE] = function(actor, args)
    -- local sefirotCoreInfo = actor.sefirotCoreInfo or Game.SealedSystem.model.sefirotCoreInfo
    -- return sefirotCoreInfo.sumResonance
    return 0
end

-- 获取封印物突破个数
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.BREAK_SEALED_COUNT] = function(actor, args)
    local count = 0
    -- local starLevel = args[1] and args[1]["value"] or 1

    -- local sefirotCoreInfo = actor.sefirotCoreInfo or Game.SealedSystem.model.sefirotCoreInfo
    -- for _, info in pairs(sefirotCoreInfo.sealedSlotInfo) do
    --     local sealedInfo = actor:getSealedInfo(info.itemId, info.gbId)
    --     if sealedInfo and sealedInfo.sealedPropInfo.sealedBreakthrough >= starLevel then
    --         count = count + 1
    --     end
    -- end
    return count
end

-- 获取危险封印物数量
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.EQUIPPED_DANGER_SEALED_COUNT] = function(actor, args)
    local count = 0
    -- local danger = args[1] and args[1]["value"] or 1
    -- local cmpQuality = args[1] and args[1]["cmp"] or "<="

    -- local sefirotCoreInfo = actor.sefirotCoreInfo or Game.SealedSystem.model.sefirotCoreInfo
    -- for _, info in pairs(sefirotCoreInfo.sealedSlotInfo) do
    --     local itemData = TableData.GetItemNewDataRow(info.itemId)
    --     if itemData and CompareFunction[cmpQuality](itemData.quality, danger) then
    --         count = count + 1
    --     end
    -- end

    return count
end

-- 获取已装备封印物数量
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.EQUIPPED_SEALED_COUNT] = function(actor, args)
    local count = 0
    -- local sefirotCoreInfo = actor.sefirotCoreInfo or Game.SealedSystem.model.sefirotCoreInfo
    -- for _ in pairs(sefirotCoreInfo.sealedSlotInfo) do
    --     count = count + 1
    -- end

    return count
end

-- 获取升级伙伴数量
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.PARTNER_LEVEL] = function(actor, args)
    local count = 0
    local minLevel = args[1] and args[1]["value"] or 1
    local cmpLevel = args[1] and args[1]["cmp"] or ">="
    local fellowBag = actor.fellowBag or Game.FellowSystem.model.FellowList
    for _, fellow in pairs(fellowBag) do
        if CompareFunction[cmpLevel](fellow.Level, minLevel) then
            count = count + 1
        end
    end

    return count
end

-- 获取突破伙伴数量
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.PARTNER_BREAK] = function(actor, args)
    local count = 0
    local minStar = args[1] and args[1]["value"] or 1
    local cmpStar = args[1] and args[1]["cmp"] or ">="
    local fellowBag = actor.fellowBag or Game.FellowSystem.model.FellowList
    for _, fellow in pairs(fellowBag) do
        if CompareFunction[cmpStar](fellow.FirstStarUpLevel, minStar) then
            count = count + 1
        end
    end

    return count
end

-- 获得伙伴数量
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.PARTNER_COUNT] = function(actor, args)
    local count = 0
    local fellowBag = actor.fellowBag or Game.FellowSystem.model.FellowList
    for _ in pairs(fellowBag) do
        count = count + 1
    end

    return count
end

-- 查询任务是否完成
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.COMPLETE_TASK] = function(actor, args)
    local taskID = args[1] and args[1]["value"] or 0
    if actor.IsTaskAccomplished then
        return actor:IsQuestFinished(taskID) and 1 or 0
    else
        -- return Game.QuestSystem:IsQuestFinished(taskID) and 1 or 0
        return 0
    end
end


-- 查询任务是否激活
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.ACTIVE_TASK] = function(actor, args)
    local taskID = args[1] and args[1]["value"] or 0
    if actor.IsQuestActive  then
        return actor:IsQuestActive(taskID) and 1 or 0
    else
		-- todo: 11/22 客户端还没有此接口
        return Game.QuestSystem:IsQuestAccepted(taskID) and 1 or 0
    end
end

-- 查询任务RING是否领取
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.IS_RING_ACCEPTED] = function(actor, args)
    local ringID = args[1] and args[1]["value"] or 0
    if actor.HasQuest  then
        return actor:HasQuest(ringID) and 1 or 0
    else
		return Game.QuestSystem:IsRingAccepted(ringID) and 1 or 0
    end
end

-- 查询任务RING是否完成
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.IS_RING_FINISHED] = function(actor, args)
    local ringID = args[1] and args[1]["value"] or 0
    if actor.IsRingFinished  then
        return actor:IsRingFinished(ringID) and 1 or 0
    else
		return Game.QuestSystem:IsRingFinished(ringID) and 1 or 0
    end
end

-- 查询成就是否完成
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.ACHIEVEMENT_FINISHED] = function(actor, args)
    local achievementNo = args[1] and args[1]["value"] or 0
    if actor.finishedAchievements then
        return actor.finishedAchievements[achievementNo] and 1 or 0
    end

    return 0
end

-- 查询超过等级的技能数量
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.SKILL_LEVEL_COUNT] = function(actor, args)
    local count = 0
    local minLevel = args[1] and args[1]["value"] or 1
    local cmpLevel = args[1] and args[1]["cmp"] or ">="

    for _, skillInfo in pairs(actor.unlockedSkillList) do
        if CompareFunction[cmpLevel](skillInfo.SkillLvl, minLevel) then
            count = count + 1
        end
    end

    return count
end

-- 查询相应扮演玩法的等级
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.ROLEPLAY_LEVEL] = function(actor, args)
    local targetRolePlay = args[1] and args[1]["value"] or 0
    LOG_DEBUG_FMT("triggerGetRoleplayLevel debug: roleplayID:%s",targetRolePlay)
    if not actor.roleplayProp then
        return 0
    end
    local roleplayProp = actor.roleplayProp[targetRolePlay]
    if roleplayProp then
        return roleplayProp.level
    else
        return 1
    end
end

-- 查询扮演玩法相应属性值
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.ROLEPLAY_COMMON_PROPERTY] = function(actor,args)
    local targetProperty = args[1] and args[1]["value"] or 0
    LOG_DEBUG_FMT("triggerGetRoleplayCommonProperty debug: targetProperty:%s",targetProperty)
    if not actor.roleplayCommonProp then
        return 0
    end
    local commomProperty = actor.roleplayCommonProp[targetProperty]
    if commomProperty then
        return commomProperty
    else
        return 0
    end
end

-- 查询扮演玩法技能书的技能是否解锁
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.ROLEPLAY_TREESKILL_UNLOCK] = function(actor, args)
    local targetSkillID = args[1] and args[1]["value"] or 0
    if not actor.roleplayProp then
        return 0
    end
    for _, content in pairs(actor.roleplayProp) do
        if content.skillTree then
            if content.skillTree[targetSkillID] then
                return 1
            end
        end
    end
    return 0
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.CLASS] = function(actor, args)
   return actor.Profession
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.EXPLORE_STELE_UNLOCK] = function(actor, args)
    local steleID = args[1] and args[1]["value"]
    return actor.ExploreSteleMap[steleID] and 1 or 0
 end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.EXPLORE_STELE_LEVEL] = function(actor, args)
    local SoulID = args[1] and args[1]["value"]
    return actor.ExploreSoulMap[SoulID] and actor.ExploreSoulMap[SoulID].Stage or 0
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.EXPLORE_BOX_COUNT] = function(actor, args)
    local firstAreaID = args[1] and args[1]["value"] or 0
    local count = 0

    if not actor.ExploreAreaMap[firstAreaID] then
        return 0
    end

    for _, areaInfo in pairs(actor.ExploreAreaMap[firstAreaID].SecondLevelAreaMap) do
        if areaInfo.GameplayProgress[Enum.EExploreTypeData.BOX] then
            count = count + areaInfo.GameplayProgress[Enum.EExploreTypeData.BOX].FinishedNum
        end
    end

    return count
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.EXPLORE_SOUL_COUNT] = function(actor, args)
    local firstAreaID = args[1] and args[1]["value"] or 0
    local count = 0

    if not actor.ExploreAreaMap[firstAreaID] then
        return 0
    end

    for _, areaInfo in pairs(actor.ExploreAreaMap[firstAreaID].SecondLevelAreaMap) do
        for exploreType, _ in pairs(Enum.EExploreType2SoulData) do
            if areaInfo.GameplayProgress[exploreType] then
                count = count + areaInfo.GameplayProgress[exploreType].FinishedNum
            end
        end
    end

    return count
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.REENFORCE_SEALED_COUNT] = function(actor, args)
    return 0
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.SHOP_SOLDOUT] = function(actor, args)
    local goodID = args[1] and args[1]["value"] or 0
    local limitGoodsBuyInfo = actor.LimitGoodsBuyInfo or Game.DepartmentStoreSystem.TotalBuyCountDict
    return limitGoodsBuyInfo[goodID] and limitGoodsBuyInfo[goodID].BuyCount or 0
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.GUILD_SHOP_LEVEL] = function(actor, args)
    local privateGuildInfo = actor.privateGuildInfo or Game.GuildSystem.model.guildPlayer
    return privateGuildInfo.guildShopLv or 0
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.FRIEND_COUNT] = function(actor, args, friendCount)
    if friendCount then return friendCount end

    local count = 0
    local bothwayFriends = actor.bothwayFriends or Game.FriendSystem.model.relationBothWayMap
    for _ in pairs(bothwayFriends) do
        count = count + 1
    end

    return count
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.UNLOCK_ROLEPLAY] = function(actor, args)
    local identity = args[1]["value"] or 0
    for identityID, _ in pairs(actor.rolePlayUnlockIdentity) do
        if identityID == identity then
            return 1
        end
    end

    return 0
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.REENFORCE_EQUIP_COUNT] = function(actor, args)
    return 0
end

-- 依赖事件传入当前值，避免重复计算
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.SEALED_UPGRADE] = function(actor, args, count)
    return count or 0
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.STATISTIC] = function(actor, args, count)
    return count or 0
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.SEQUENCE_STAGE] = function(actor, args, count)
    local seqData = TableData.GetSequenceDataRow(actor.curSeqId)
    local sequence = args[1]["value"] or 0
    if seqData then
        return seqData.SequenceStage <= sequence and 1 or 0
    end

    return 0
end

-- 交互物是否处于任务激活状态中
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.INTERACTOR_TASK_ACTIVE] = function(actor, args)
    local TemplateID = args[1] and args[1]["value"] or 0
    if actor.CheckIsCollectActive then
        return actor:CheckIsCollectActive(TemplateID) and 1 or 0
    end
	
	return Game.QuestSystem:CheckInteractorCondition(TemplateID, false) and 1 or 0
end

-- 大世界玩法是否完成
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.PERSISTENT_GAMEPLAY_MAP] = function(actor, args)
    local MapID = args[1] and args[1]["value"] or 0
    local GamePlayID = args[2] and tostring(args[2]["value"]) or ""  
    if actor.PersistentGameplayMap and actor.PersistentGameplayMap[MapID] then
        return actor.PersistentGameplayMap[MapID][GamePlayID] or 0 
    end
	
	return 0
end

-- 背包物品查询
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.ITEM_GET] = function(actor, args)
    local ItemID = args[1] and args[1]["value"] or 0
    if actor.getInvValidItemCount then
        return actor:getInvValidItemCount(ItemID, sharedConst.INV_BOUND_TYPE_INSENSITIVE)
    end
	
	return 0
end

-- NPC问价比例
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.NPC_CUT_PRICE_EXCEED] = function(actor, args, count)
    local targetRatio = args[1] and args[1]["value"] or 0
	return count and count > targetRatio and 1 or 0
end

-- NPC问价比例
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.NPC_CUT_PRICE_INSUFFICIENT] = function(actor, args, count)
    local targetRatio = args[1] and args[1]["value"] or 0
	return count and count < targetRatio and 1 or 0
end

-- 灵视状态
TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.SPIRITUAL_VISION] = function(actor, args, count)
    if not actor.IsInSpiritualVision then
        return -1
    end

    if actor:IsInSpiritualVision() then
        return 1
    else
        return 0
    end
end

TRIGGER_CONDITION_FUNC[Enum.ETriggerTypeData.HAS_BUFF] = function(actor, args, count)
    local buffID = args[1] and args[1]["value"] or 0
    return actor:HasBuff(buffID) and 1 or 0
end


-------------------------------------------------------前置条件 Premise-----------------
-- 队伍人数
function CheckTeamMemberCount(actor, args, count)
    if actor.teamID == 0 then return false end
    return lume.count(actor.teamInfoList) >= count
end

-- -- 塔罗小队人数
function CheckTarotteamMemberCount(actor, args, count)
    return actor:CheckTarotTeamMemberCountInGroup(count, false)
end

-- 塔罗小队人数且顺位最高
function CheckTarotteamMemberCountEx(actor, args, count)
    return actor:CheckTarotTeamMemberCountInGroup(count, true)
end

-- 检查玩家在场景中获得的buff数量(伴随触发器)
function CheckDungeonBuff(actor, args, count)
    if not actor:IsInDungeon() then return false end
    local key = "CHECK_DUNGEON_BUFF"        
    local buffCount = actor:GetCurrentDungeon():GetTriggerStatisticsByKey(key, args, actor)
    return buffCount >= count
end

local PremiseFunction = 
{
    ["TEAM_MEMBER_COUNT"] = CheckTeamMemberCount,
    ["TAROTTEAM_MEMBER_COUNT"] = CheckTarotteamMemberCount,
    ["TAROTTEAM_MEMBER_COUNT_EX"] = CheckTarotteamMemberCountEx,
    ["CHECK_DUNGEON_BUFF"] = CheckDungeonBuff, 
}

function CanTriggerPremiseCompleted(avatar, customData)
    for _, condData in ksbcipairs(customData.Premise) do
        if not PremiseFunction[condData.type] then
            LOG_ERROR_FMT("fail to find premise function by type: %s", condData.type)
        end

        if not PremiseFunction[condData.type](avatar, condData.args, tonumber(condData.target)) then
            return false
        end
    end

    return true
end