local ETE
if IS_SERVER then
    ETE = kg_require("logicScript.ability.AbEnumExport")
else
    ETE = kg_require("Data.Config.BattleSystem.ExportedEnum").ETE
    LOG_ERROR_FMT = Log.ErrorFormat
    LOG_DEBUG_FMT = Log.DebugFormat
end

local table_clear = table.clear
local table_insert = table.insert

function GetTableData()
    if IS_SERVER then
        return TableData
    else
        return Game.TableData
    end
end

function checkSkillValidForAutoCastTree(Avatar, InSkillID, InSkillSlot)
    -- 检查技能是否解锁
    local ParentID = Avatar:GetParentSkillIDNew(InSkillID)
    if Avatar.skillList[ParentID] == nil or Avatar.skillList[ParentID].SkillUnlocked ~= 1 then
        return false
    end

    local tSkillDataRow = GetTableData().GetSkillDataNewRow(ParentID)
    -- 未装配的技能，或NoAutoCast的技能，不允许加入连招树
    if InSkillSlot == ETE.EBSSkillSlot.SS_TMax or tSkillDataRow == nil or tSkillDataRow.NoAutoCast == true then
        return false
    end

    return true
end

function canCastSkill(Avatar, InExpectedSkillID, InSkillSlot, bDoNotCheck, TargetID)
    local SkillID = Avatar:GetSkillIDBySlotNew(InSkillSlot)
    -- InExpectedSkillID不为空时，检查技能ID
    if InExpectedSkillID ~= nil and SkillID ~= InExpectedSkillID then
        -- 当前槽位待释放技能与预期技能不符
        if not IS_SERVER and AutoSkillComponent.AutoSkillCustomData.bDebugMode then
            print("[AutoSkillCastMsg]TryReleaseAutoSkill Failed, ExpectedSkillID:", InExpectedSkillID, "SkillSlot:", InSkillSlot, "CurrentSlotSkillID:", SkillID)
        end
        return false, SkillID
    end

    local tSkillDT = Avatar:GetAutoSkillDT(SkillID)
    if not tSkillDT then
        LOG_DEBUG_FMT("[AutoSkillCastMsg]CheckCanCastSkill error:SkillID:%s, SkillSlot:%s  not exist", SkillID, InSkillSlot)
        return false, nil
    end
    if bDoNotCheck == true or Avatar:CanAutoReleaseSkill(tSkillDT, InSkillSlot, TargetID) then
        return true, SkillID
    end

    return false, SkillID
end

---@param Avatar AvatarActor
---@param TargetID string
---@return number 返回SkillID
---@return number 返回SkillSlot
---@return boolean 是连招树里的行节点
---@return boolean 连招树的index
function tryGetReleaseASTreeSkill(Avatar, TargetID)
    if Avatar.OrderedAutoSkillTreeMsg[Avatar.CurASTreeIndex] ~= nil and Avatar.OrderedAutoSkillTreeMsg[Avatar.CurASTreeIndex].SkillSlots[Avatar.CurASTreeSkillIndex] then
        -- 继续尝试执行未完成的一键连招树逻辑
        local slot = Avatar.OrderedAutoSkillTreeMsg[Avatar.CurASTreeIndex].SkillSlots[Avatar.CurASTreeSkillIndex]
        local skillID = Avatar.OrderedAutoSkillTreeMsg[Avatar.CurASTreeIndex].SkillIDs[Avatar.CurASTreeSkillIndex]
        local suc = canCastSkill(Avatar, skillID, slot, nil, TargetID)
        if suc == true then
            return skillID, slot, false, nil
        else
            -- 已有一键连招树逻辑执行失败
            Avatar.CurASTreeIndex = -1
            Avatar.CurASTreeSkillIndex = -1
            return nil, nil, false, nil
        end
    end

    -- 无正在执行的一键连招树逻辑，开始查找
    Avatar.CurASTreeIndex = -1
    Avatar.CurASTreeSkillIndex = -1

    for AutoSkillTreeMsgIndex, AutoSkillTreeMsg in ipairs(Avatar.OrderedAutoSkillTreeMsg) do
        if Avatar:CheckAutoSkillCondition(AutoSkillTreeMsg.Conditions, TargetID) then
            local bAllSkillAllow = true
            for index, AutoSkillID in ipairs(AutoSkillTreeMsg.SkillIDs) do
                local tSkillDT = Avatar:GetAutoSkillDT(AutoSkillID)
                if Avatar:CanAutoReleaseSkill(tSkillDT, AutoSkillTreeMsg.SkillSlots[index]) == false then
                    bAllSkillAllow = false
                    break
                end
            end

            if bAllSkillAllow == true then
                local skillID = AutoSkillTreeMsg.SkillIDs[1]
                local skillSlot = AutoSkillTreeMsg.SkillSlots[1]
                if canCastSkill(Avatar, skillID, skillSlot, true, TargetID) then
                    return skillID, skillSlot, true, AutoSkillTreeMsgIndex
                end
            end
        end
    end

    return nil, nil, nil, nil
end

-- 检查技能是否允许在通用优先级里配置一键连招（只检查配置数据，不检查是否装配）
function CheckSkillValidForCommonAutoCast(Avatar, InSkillID, InSkillSlot)
    if InSkillSlot ~= ETE.EBSSkillSlot.SS_ReviveSlot then
        -- 检查技能是否解锁
        local ParentID = Avatar:GetParentSkillIDNew(InSkillID)
        if Avatar.skillList[ParentID] == nil or Avatar.skillList[ParentID].SkillUnlocked ~= 1 then
            return false
        end

        local tSkillDataRow = GetTableData().GetSkillDataNewRow(Avatar:GetParentSkillIDNew(InSkillID))
        -- 普攻槽位不受NoAutoCast影响一定会加入
        if tSkillDataRow ~= nil and ((tSkillDataRow.NoAutoCast ~= true and tSkillDataRow.AutoCastTreeOnly ~= true) or InSkillSlot == ETE.EBSSkillSlot.SS_Attack) then
            return true
        end
    end

    return false
end

function InitAutoTreeMsg(Avatar, ASTD)
    if not Avatar.OrderedAutoSkillTreeMsg then
        Avatar.OrderedAutoSkillTreeMsg = {}
    end
    table_clear(Avatar.OrderedAutoSkillTreeMsg)
    local OrderedAutoSkillTreeMsg = Avatar.OrderedAutoSkillTreeMsg

    if ASTD == nil or ASTD.Nodes == nil or ASTD.Edges == nil then
        return false
    end

    local StartNodeID = ASTD.RootNodes[1]
    local CurNode = ASTD.Nodes[StartNodeID]
    if (CurNode == nil) then
        return false
    end

    local count = 0
    while (CurNode ~= nil and CurNode.OutEdges ~= nil and CurNode.OutEdges[1] ~= nil) do
        count = count + 1
        -- 防止死循环
        if count > 100 then
            return false
        end
        local CurEdge = ASTD.Edges[CurNode.OutEdges[1]]
        if CurEdge == nil then
            break
        end

        CurNode = ASTD.Nodes[CurEdge.EndNode] -- 下一个节点
        if CurNode.SkillIDs ~= nil and CurNode.SkillIDs[1] ~= nil then
            local Conditions = CurEdge.Conditions
            -- 检查一键连招树配置的技能是否装配
            local bCurNodeValid = true
            local SlotOrder = {}
            for index, SkillID in ipairs(CurNode.SkillIDs) do
                local tSkillSlot = Avatar:FindSkillSlot(SkillID)
                -- 未装配的技能，或NoAutoCast的技能，不允许加入连招树
                if not checkSkillValidForAutoCastTree(Avatar, SkillID, tSkillSlot) then
                    bCurNodeValid = false
                    break
                else
                    SlotOrder[index] = tSkillSlot
                end
            end
            if bCurNodeValid == true then
                table.insert(OrderedAutoSkillTreeMsg, {
                    Conditions = Conditions,
                    SkillSlots = SlotOrder,
                    SkillIDs = CurNode.SkillIDs
                })
            end
        end
    end
    return true
end

function InitSkillMsg(Avatar)
    -- 服务端会用到
    if not Avatar.CurAutoSkillSlots then
        Avatar.CurAutoSkillSlots = {}
    end
    if not Avatar.HighOrderedAutoSkillMsg then
        Avatar.HighOrderedAutoSkillMsg = {}
    end
    if not Avatar.LowOrderedAutoSkillMsg then
        Avatar.LowOrderedAutoSkillMsg = {}
    end

    table_clear(Avatar.CurAutoSkillSlots)
    table_clear(Avatar.HighOrderedAutoSkillMsg)
    table_clear(Avatar.LowOrderedAutoSkillMsg)
    -- 临时测试逻辑 Start
    for _, AutoSkillSlot in ipairs(Avatar.AutoSkillSlots) do
        --检查该角色本地储存的技能连招开启状态是否有冲突，如果有的话以本地为准
        local SkillID = -1
        local ProTableData = GetTableData().GetProfessionSkillDataRow(Avatar.Profession)
        if ProTableData and ProTableData.SkillList[1] then
            SkillID = ProTableData.SkillList[1]
        end
        if Avatar:CheckSkillEnabledForAutoSkill(SkillID) and AutoSkillSlot ~= -1 then
            table_insert(Avatar.CurAutoSkillSlots, AutoSkillSlot)
        end
    end
    -- --普通攻击槽位
    -- table_insert(Avatar.CurAutoSkillSlots, ETE.EBSSkillSlot.SS_Attack)

    for _, AutoSkillSlot in ipairs(Avatar.CurAutoSkillSlots) do
        local SkillID = Avatar:GetSkillIDBySlotNew(AutoSkillSlot)
        if CheckSkillValidForCommonAutoCast(Avatar, SkillID, AutoSkillSlot) then
            local tSkillDataRow = GetTableData().GetSkillDataNewRow(Avatar:GetParentSkillIDNew(SkillID))
            -- 普攻使用最低优先级
            local tMsg = {
                ParentID = tSkillDataRow.ID,
                Priority = AutoSkillSlot == ETE.EBSSkillSlot.SS_Attack and -1 or tSkillDataRow.AutoCastPriority or 0,
                SkillSlot = AutoSkillSlot,
                bInCoolDown = false,
            }
            if tMsg.Priority >= 6 then
                table_insert(Avatar.HighOrderedAutoSkillMsg, tMsg)
            else
                table_insert(Avatar.LowOrderedAutoSkillMsg, tMsg)
            end
        end
    end

    table.sort(Avatar.HighOrderedAutoSkillMsg, function(a, b)
        return a.Priority > b.Priority
    end)
    table.sort(Avatar.LowOrderedAutoSkillMsg, function(a, b)
        return a.Priority > b.Priority
    end)
end

---@param Avatar AvatarActor
---@param TargetID string|nil
---@return number 技能ID
---@return number 技能槽位
---@return boolean 是否是连招树技能
---@return boolean 是否是连招树新的节点
---@return boolean 连招树的index
function TryGetAutoReleaseSkill(Avatar, TargetID)
    -- 用于服务端初始化
    if not Avatar.CurASTreeIndex then
        Avatar.CurASTreeIndex = -1
        Avatar.CurASTreeSkillIndex = -1
    end

    local bHasASTreeNode = true -- 当前是否有连招树节点正在执行
    if Avatar.CurASTreeIndex < 0 and Avatar.CurASTreeSkillIndex < 0 then
        for _, Msg in ipairs(Avatar.HighOrderedAutoSkillMsg) do
            if Msg.bInCoolDown ~= true then
                local Suc, SkillID = canCastSkill(Avatar, nil, Msg.SkillSlot, false, TargetID)
                if Suc then
                    return SkillID, Msg.SkillSlot, false, false, nil
                end
            end
        end

        bHasASTreeNode = false
    end

    local SkillID, SkillSlot, IsNew, AutoSkillIndex = tryGetReleaseASTreeSkill(Avatar, TargetID)
    if SkillID then
        return SkillID, SkillSlot, true, IsNew, AutoSkillIndex
    end

    -- 如果bHasASTreeNode为true并且运行到这里，说明一定是原有连招树节点执行失败，需要重新查找
    if bHasASTreeNode == true then
        for _, Msg in ipairs(Avatar.HighOrderedAutoSkillMsg) do
            if Msg.bInCoolDown ~= true then
                local Suc, SkillID = canCastSkill(Avatar, nil, Msg.SkillSlot, nil, TargetID)
                if Suc then
                    return SkillID, Msg.SkillSlot, false, false, nil
                end
            end
        end

        local SkillID, SkillSlot, IsNew, AutoSkillIndex = tryGetReleaseASTreeSkill(Avatar, TargetID)
        if SkillID then
            return SkillID, SkillSlot, true, IsNew, AutoSkillIndex
        end
    end

    -- 最后尝试激活低优先级普通单技能逻辑
    for _, Msg in ipairs(Avatar.LowOrderedAutoSkillMsg) do
        if Msg.bInCoolDown ~= true then
            local Suc, SkillID = canCastSkill(Avatar, nil, Msg.SkillSlot, nil, TargetID)
            if Suc then
                return SkillID, Msg.SkillSlot, false, false, nil
            end
        end
    end

    return nil, nil, nil, nil, nil
end

function UpdateAutoSkillTree(Avatar, IsNew, ReleaseSkillIndex)
    if not IsNew then
        Avatar.CurASTreeSkillIndex = Avatar.CurASTreeSkillIndex + 1

        if Avatar.OrderedAutoSkillTreeMsg[Avatar.CurASTreeIndex].SkillSlots[Avatar.CurASTreeSkillIndex] == nil then
            -- 所有键连招树节点执行完了
            Avatar.CurASTreeIndex = -1
            Avatar.CurASTreeSkillIndex = -1
        end
    else
        Avatar.CurASTreeIndex = ReleaseSkillIndex
        Avatar.CurASTreeSkillIndex = 2

        local AutoSkillTreeMsg = Avatar.OrderedAutoSkillTreeMsg[ReleaseSkillIndex]
        if AutoSkillTreeMsg.SkillSlots[Avatar.CurASTreeSkillIndex] == nil then
            -- 连招树节点就配了一个技能，结束
            Avatar.CurASTreeIndex = -1
            Avatar.CurASTreeSkillIndex = -1
        end 
    end
end
