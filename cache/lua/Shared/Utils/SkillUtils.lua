local const = kg_require("Shared.Const")

local SBR_LOCK_STATUS = const.SKILL_BALANCE_LOCK_STATUS
local SBR_PROFESSION_SKILL = const.SKILL_BALANCE_TYPE.PROFESSION_SKILL

function GetRoleSkillRowBySkillId(tableData, skillId)
    local skillId2UniqueIdMap = tableData.Get_skillId2UniqueIdMap()
    local uniqueIdRow = skillId2UniqueIdMap[skillId]
    if uniqueIdRow == nil then
        local newSkillId2UniqueIdMap = tableData.Get_newSkillId2UniqueIdMap()
        local newUniqueIdRow = newSkillId2UniqueIdMap[skillId]
        if newUniqueIdRow then
            return tableData.GetFellowSkillUnlockDataRow(newUniqueIdRow.ID)
        end
    else
        return tableData.GetRoleSkillUnlockDataRow(uniqueIdRow.ID)
    end
end

-- skillBalanceRules如果配置了技能id, 以skillBalanceRules为准
-- 如果没有配置, 以balanceRuleInfo (SkillTypeLevelLimit & SkillTypeUnlock)为准
function GetBalanceRuleOverrideSkillInfoBySkillType(tableData, skillID, bUnlocked, balanceRuleInfo)
    local srcRoleSkillRow = GetRoleSkillRowBySkillId(tableData, skillID)
    if srcRoleSkillRow == nil then
        return false
    end
    local skillType = srcRoleSkillRow.SkillType
    local overrideLevel
    local bIsOverride = false
    local skillTypeLevelLimit = balanceRuleInfo.SkillTypeLevelLimit
    if skillTypeLevelLimit then
        overrideLevel = skillTypeLevelLimit[skillType]
        bIsOverride = overrideLevel ~= nil
    end

    if not bUnlocked then
        local ruleID = balanceRuleInfo.RuleID
        local skillTypeUnlockMap = tableData.Get_SkillTypeUnlockMap()[ruleID]
        if skillTypeUnlockMap and skillTypeUnlockMap[skillType] then
            bUnlocked = true
            bIsOverride = true
        end
    end

    return bIsOverride, bUnlocked, overrideLevel or 1
end


---@return boolean, boolean, int: (bOverride, bUnlocked, overrideLevel)
function GetBalanceRuleOverrideSkillInfo(tableData, balanceRuleId, skillID, bUnlocked)
    local balanceRuleInfo = tableData.GetFightPropBalanceRuleDataRow(balanceRuleId)
    if not balanceRuleInfo then
        return false
    end

    local skillBalanceRuleID = balanceRuleInfo.SkillBalanceRuleID
    if skillBalanceRuleID == 0 then
        return false
    end

    local skillBalanceRulesTable = tableData.Get_SkillBalanceRules()
    local skillBalanceRules = skillBalanceRulesTable[skillBalanceRuleID]
    if not skillBalanceRules then
        return false
    end

    local professionSkillBR = skillBalanceRules[SBR_PROFESSION_SKILL]
    local skillBalanceRule = professionSkillBR and professionSkillBR[skillID]
    if not skillBalanceRule then
        return GetBalanceRuleOverrideSkillInfoBySkillType(tableData, skillID, bUnlocked, balanceRuleInfo)
    end

    local lockStatus = skillBalanceRule[1]
    if lockStatus == SBR_LOCK_STATUS.LOCK then
        return true, false
    elseif lockStatus == SBR_LOCK_STATUS.COMMON then
        return true, bUnlocked, skillBalanceRule[2]
    elseif lockStatus == SBR_LOCK_STATUS.UNLOCK then
        return true, true, skillBalanceRule[2]
    end

    return false
end