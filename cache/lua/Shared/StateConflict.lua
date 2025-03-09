
StateConflict = DefineClass("StateConflict")

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

StateConflict.ActionConfig = {}

-- 状态冲突注册
---@param actionName string 状态名称
---@param stopFunc string 需要被打断时要执行的函数, 注意，打断成功要要回true，打断失败的话返回false
---@param stateFunc string 通過其他函數獲取狀態
---@param noExecTime boolean 是否是瞬发. 可能的情况下会打断其他的状态, 但是自己的状态不会保存
function StateConflict.Register(actionName, stopFunc, stateFunc, noExecTime)
    if Enum.EStateConflictAction[actionName] == nil then
        LOG_ERROR_FMT("StateConflictRegister actionName not defined %s", actionName)
        return false
    end
    StateConflict.ActionConfig[Enum.EStateConflictAction[actionName]] = {
        Name = actionName,
        ID = Enum.EStateConflictAction[actionName],
        stateFunc = stateFunc,
        stopFunc = stopFunc,
        noExecTime = noExecTime,
    }
end
function StateConflict.getConfigMap()
    --兼容客户端和服务器
    local tableData = Game.TableData or TableData
    return tableData.Get_StateConflictMap()
end


-- 遍历当前已有的所有状态, 判断能否迁移到新的状态, 返回所有状态中最坏的条件
---@param toActionID integer 目标状态类型
---@return integer 冲突类型 Enum.EStateConflictType
---@return table replace table
---@return integer fromActionID 冲突时,block 的fromActionID
function StateConflict.checkState(player, toActionID)
    local configMap = StateConflict.getConfigMap()
    if configMap[toActionID] == nil then
        return Enum.EStateConflictType.NO, {}, 0
    end

    local worstType = Enum.EStateConflictType.NO
    local replaceList = {}
    -- 遍历所有迁移到目标状态会冲突的前置状态
    for fromID, csState in pairs(configMap[toActionID]) do
        -- state from self.SCState
        local currentState = StateConflict.GetState(player, fromID)
        if currentState then
            if csState == Enum.EStateConflictType.NO then
                goto continue
            end
            if csState == Enum.EStateConflictType.BLOCK then
                LOG_DEBUG_FMT("StateConflict.checkState blocked fromState[%d] toAction[%d]", fromID, toActionID)
                return Enum.EStateConflictType.BLOCK, {}, fromID
            end
            worstType = csState
            table.insert(replaceList, fromID)
        end
        ::continue::
    end
    return worstType, replaceList, 0
end

function StateConflict.GetState(player, fromID)
    -- state from self.SCState
    local currentState = player:getCurrentConflictState(fromID)
    if currentState == nil then
        -- check if stateFunc is defined and check state from stateFunc
        local fromAction = StateConflict.ActionConfig[fromID]
        if fromAction and fromAction.stateFunc and player[fromAction.stateFunc] then
            currentState = player[fromAction.stateFunc](player)
        end
    end
    return currentState
end

---@return integer 冲突类型 Enum.EStateConflictType
---@return table replace table
---@return integer fromActionID 冲突时,block 的fromActionID
function StateConflict.CanExec(player, toActionID)
    return StateConflict.checkState(player, toActionID)
end


---@return integer 冲突类型 Enum.EStateConflictType
---@return integer reminderID
---@return boolean 是否成功执行
---@return integer blockedID
function StateConflict.Exec(player, toActionID, checkResult, doNotSaveState)
    local resultState, replaceList, blockedID
    if checkResult ~= nil then
        resultState, replaceList, blockedID = table.unpack(checkResult)
    else
        resultState, replaceList, blockedID = StateConflict.checkState(player, toActionID)
    end

    local reminderID = 0
    local action = StateConflict.ActionConfig[toActionID]
    if action == nil then
        player:logWarnFmt("StateConflict Action not defined: %s", toActionID)
        return Enum.EStateConflictType.NO, reminderID, false, 0
    end

    -- 1. 无冲突
    if resultState == Enum.EStateConflictType.NO then
        -- 如果目标action不是瞬发, 设置状态
        if not action.noExecTime and not doNotSaveState then
            player:SCSet(toActionID)
        end
        return Enum.EStateConflictType.NO, reminderID, true, 0
    end

    -- 2. 有冲突
    if resultState == Enum.EStateConflictType.BLOCK then
        reminderID = StateConflict.GetReminderID(blockedID, toActionID)
        LOG_DEBUG_FMT("StateConflict.Exec blocked fromState[%d] toAction[%d]", blockedID, toActionID)
        return Enum.EStateConflictType.BLOCK, reminderID, true, blockedID
    end


    -- 3. 有接续
    local isOk = true
    for _, fromID in ipairs(replaceList) do
        local fromAction = StateConflict.ActionConfig[fromID]
        if fromAction == nil then
            player:logWarnFmt("StateConflict Action not defined: %s", fromID)
            goto continue
        end
        -- if stop function is defined, run stop function
        -- 暂时不考虑异步的执行
        -- 注意, stopFunction 返回false时标示stop失败, 按block处理
        if fromAction.stopFunc and fromAction.stopFunc ~= "" and not player[fromAction.stopFunc](player) then
            -- mark failed if stop failed
            isOk = false
            blockedID = fromID
            break
        end

        -- if state need stop by client
        if StateConflict.IsStopByClient(fromID) then
            player:stopConflictStateByClient(fromID)
        end

        -- if stop success, remove old state
        player:SCRemove(fromID, true)
        ::continue::
    end

    -- return blocked if any failed
    if not isOk then
        reminderID = StateConflict.GetReminderID(blockedID, toActionID)
        LOG_DEBUG_FMT("StateConflict.Exec stopFailed blocked fromState[%d] toAction[%d]", blockedID, toActionID)
        return Enum.EStateConflictType.BLOCK, reminderID, false, blockedID
    end

    -- set new status
    if not action.noExecTime and not doNotSaveState then
        player:SCSet(toActionID)
    end
    return Enum.EStateConflictType.NO, reminderID, true, 0
end

-- 执行action的stopfunction
function StateConflict.doStopByActionID(player, actionID)
    local action = StateConflict.ActionConfig[actionID]
    if action and action.stopFunc ~= "" and player[action.stopFunc] ~= nil then
        player[action.stopFunc](player)
    end
end


function StateConflict.GetReminderID(fromID, toID)
    --兼容客户端和服务器
    local tableData = Game.TableData or TableData
    local popupConfig = tableData.Get_StateConflictPopupData()
    local isShowPopup = false
    local reminderID = 0
    if popupConfig[fromID] ~= nil and popupConfig[fromID][toID] ~= nil then
        isShowPopup = popupConfig[fromID][toID]
    end

    if isShowPopup then
        reminderID = Enum.EReminderTextData.STATECONFLICT_COMMON
        local reminderConfig = tableData.Get_StateConflictReminderData()
        if reminderConfig[toID] ~= nil and reminderConfig[toID][fromID] ~= nil then
            reminderID = reminderConfig[toID][fromID]
        end
    end

    return reminderID
end


function StateConflict:IsStopByClient(actionID)
    local tableData = Game.TableData or TableData
    local config = tableData.GetStateTypeDefineDataRow(actionID)
    if not config then
        return false
    end
    return config.StopByClient
end