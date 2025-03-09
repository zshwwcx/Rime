--TODO 放入表格
-- local InvalidDefaultValue = 100000000

local FormulaMgr = {}
FormulaMgr.funcDict = {}
local TableData = (Game and Game.TableData) or TableData
local Pow = function(x, y) return x ^ y end
local pow = Pow
local max = math.max
local Max = math.max
local min = math.min
local Min = math.min
local ceil = math.ceil
local Ceil = math.ceil
local floor = math.floor
local Floor = math.floor
local round = function(num) return math.floor(num + 0.5) end
local Round = round
local abs = math.abs
local Abs = math.abs
local random = math.random
local Random = math.random
local Ln = math.log
local Cos = math.cos

local formulaEnv = {
    Pow = function(x, y) return x ^ y end,
    pow = Pow,
    max = math.max,
    Max = math.max,
    min = math.min,
    Min = math.min,
    ceil = math.ceil,
    Ceil = math.ceil,
    floor = math.floor,
    Floor = math.floor,
    round = function(num) return math.floor(num + 0.5) end,
    Round = round,
    abs = math.abs,
    Abs = math.abs,
    random = math.random,
    Random = math.random,
    Ln = math.log,
    Cos = math.cos,
}

function FormulaMgr.CallFormulaFunc(FuncName, ...)
    local formulaFunc = FormulaMgr.funcDict[FuncName]
    if not formulaFunc then
        formulaFunc = FormulaMgr.loadFormulaFunc(FuncName)
        if not formulaFunc then
            --print("[CallFormulaFunc]loadFormulaFunc failed:" .. FuncName)
            return false, 0
        end
        --setfenv(formulaFunc,formulaEnv)
        --setmetatable(formulaFunc ,{ __index = formulaEnv})
        FormulaMgr.funcDict[FuncName] = formulaFunc
    end
    --print("[CallFormulaFunc]FuncName:" .. FuncName)
    --print("POW:",Pow(2,2))
    --debug.setupvalue(formulaFunc, 1, Pow)
    return true, formulaFunc(...)
end

function FormulaMgr.loadFormulaFunc(FuncName)
    local configID = Enum.EFormulaData[FuncName]
    if not configID then
        return nil
    end

    local formulaData = TableData.GetFormulaDataRow(configID)
    if not formulaData then
        --print("[ERROR] not get formulaData:" .. tostring(configID))
        return nil
    end
    local strFormula = formulaData.Formula
    local strFunc = string.gsub(strFormula, "%$(%d+)", function(w)
        local idx = tonumber(w)
        return string.format("args[%d]", idx)
    end)

    local funcPrefix = [[
        local args = {...}
    ]]
    strFunc = funcPrefix .. "\n" .. strFunc

    --print("[loadFormulaFunc]:" .. FuncName .. "\n " .. strFunc)
    local func = load(strFunc, nil, nil, formulaEnv)
    return func
end

FightPropInfo = {}

function FightPropInfo.doSetAttr(targetInfo, k, v)
    targetInfo[k] = v
    targetInfo.logInfoFmtHandle("[doSetAttr], k:%s, v:%s", k, v)
    ---MISS CallBack
end

function FightPropInfo.doSetAttrByMode(targetInfo, k, v)
    targetInfo[k] = (targetInfo[k] or 0) + v
    targetInfo.logInfoFmtHandle("[doSetAttrByMode], k:%s, v:%s", k, v)
    ---MISS CallBack
end

function FightPropInfo.checkIncrFightPropSetByMode(targetInfo, propMode, propModeValue)
    local fightPropModeSetMap = TableData.Get_fightPropModeSetMap()
    local propModeSetId = fightPropModeSetMap[propMode]
    if propModeSetId == nil then
        return false
    end

    ---@type FightPropModeSetData
    local propSetRow = TableData.GetFightPropModeSetDataRow(propModeSetId)
    if propSetRow == nil then
        targetInfo.logErrorFmtHandle(
            "[checkIncrFightPropSetByMode]can't find fightPropModeSet Row of propModeSetId: %s, propName: %s",
            propModeSetId, propMode)
        return true
    end

    for _, subPropModeId in ipairs(propSetRow.PropSet) do
        ---@type FightPropModeData
        local subPropModeRow = TableData.GetFightPropModeDataRow(subPropModeId)
        if subPropModeRow ~= nil then
            local propName = subPropModeRow.PropMode
            FightPropInfo.doChangeFightPropByMode(targetInfo, propName, propModeValue)
        else
            targetInfo.logErrorFmtHandle(
                "[checkIncrFightPropSetByMode], can't find propRow of subPropId: %s, set propId: %s, propMode: %s",
                subPropModeId, propModeSetId, propMode)
        end
    end

    return true
end

function FightPropInfo.doChangeFightPropByMode(targetInfo, propMode, propModeValue)
    local len = string.len(propMode)
    if len <= 2 then
        targetInfo.logErrorFmtHandle("[doChangeFightPropByMode], invalid FightProp ChangeMode: %s", propMode)
        return
    end

    -- 1. try get prop name and mode
    local propName = string.sub(propMode, 1, len - 2)
    local mode = string.sub(propMode, len)

    -- rawset the mode value
    FightPropInfo.doSetAttrByMode(targetInfo, propMode, propModeValue)

    targetInfo.logInfoFmtHandle("[doChangeFightPropByMode], propName: %s, mode: %s, v: %s", propName, mode, propModeValue)

    -- modify the final prop value
    if mode == "N" or mode == "P" or mode == "F" then
        -- if has XXX_C value, first use this value as XXX's value
        -- local propNameC = propName .. "_C"
        -- local propValueC = targetInfo[propNameC]
        -- if propValueC ~= nil and propValueC > InvalidDefaultValue then
        --     return
        -- end

        local propNameN = propName .. "_N"
        local propNameP = propName .. "_P"
        local propNameF = propName .. "_F"
        local propValueN = targetInfo[propNameN] or 0
        local propValueP = targetInfo[propNameP] or 0
        local propValueF = targetInfo[propNameF] or 0
        local propValue = propValueN * (1 + propValueP) + propValueF
        --FightPropInfo.setFightProp(targetInfo, propName, propValue)
        FightPropInfo.doSetAttr(targetInfo, propName, propValue)

        targetInfo.logInfoFmtHandle("[doChangeFightPropByMode][NPF], propName: %s, mode: %s, finalValue: %s", propName,
            mode, propValue)
        return
    end

    if mode == "C" or mode == "B" then
        local propValue = propModeValue
        FightPropInfo.doSetAttr(targetInfo, propName, propValue)

        targetInfo.logInfoFmtHandle("[doChangeFightPropByMode][CB], propName: %s, mode: %s, finalValue: %s", propName,
            mode, propValue)
        return
    end

    targetInfo.logErrorFmtHandle("[doChangeFightPropByMode]error mode, propName: %s, mode: %s, v: %s", propName, mode,
        propModeValue)
end

function FightPropInfo.changeFightPropByMode(targetInfo, propId, propMode, propValue)
    ---@type FightPropModeData
    local propRow = TableData.GetFightPropModeDataRow(propId)
    if propRow == nil then
        targetInfo.logErrorFmtHandle("[changeFightPropByMode], can't find propRow of propId: %s, propMode: %s", propId,
            propMode)
        return
    end

    if FightPropInfo.checkIncrFightPropSetByMode(targetInfo, propMode, propValue) then
        return
    end
    FightPropInfo.doChangeFightPropByMode(targetInfo, propMode, propValue)
end

function FightPropInfo:setAttr(k, v)
    self.logInfoFmtHandle("[setAttr]%s,%s", k, v)
    local metaTable = getmetatable(self)
    setmetatable(self, {})
    -- 1. check change fight prop by mode
    local propId = Enum.EFightPropModeData[k]
    if propId ~= nil then
        FightPropInfo.changeFightPropByMode(self, propId, k, v)
    end

    setmetatable(self, metaTable)
end

-- function FightPropInfo:getAttr(k)
--     self.logInfoFmtHandle("[getAttr]k:%s,v:%s", k, self[k])
--     return self[k]
-- end

function FightPropInfo:new(LogHandle)
    local obj = {
        logInfoFmtHandle = LogHandle.logInfoFmtHandle,
        logErrorFmtHandle = LogHandle.logErrorFmtHandle
    }
    --setmetatable(obj, {__index = self.getAttr, __newindex = self.setAttr})
    local meta = {__index = function(_,k) return self[k] end}
    setmetatable(obj, meta)
   -- setmetatable(obj, { __newindex = self.setAttr})
    return obj
end

function FightPropInfo.calculateFellowLevelProp(FellowData, PropConfigID, FellowLvel, TotalPropInfo, LogHandle)
    local configID = FellowData.Id
    local lvPropData = TableData.GetFellowPropTemplateDataRow(PropConfigID)
    if not lvPropData then
        LogHandle.logErrorFmtHandle("[GetFellowFightProp] no FellowPropTemplateData, configID[%s] propTemplateID[%s]",
            configID, PropConfigID)
        return
    end

    for k, _ in pairs(Enum.EFellowPropConstData) do
        local baseValue = FellowData[k]
        if baseValue and baseValue > 0 then
            local formulaData = TableData.GetFormulaDataRow(lvPropData[k])
            if not formulaData then
                LogHandle.logErrorFmtHandle(
                    "[GetFellowFightProp] GetFormulaDataRow failed. configID[%s] propTemplateID[%s] propName[%s]",
                    configID, PropConfigID, k)
                return
            end

            local formulaName = formulaData.Name
            if not formulaName then
                LogHandle.logErrorFmtHandle(
                    "[GetFellowFightProp] formulaName nil. configID[%s] propTemplateID[%s] propName[%s]",
                    configID, PropConfigID, k)
                return
            end

            local callRet, result, num = xpcall(FormulaMgr.CallFormulaFunc,
                function(msg)
                    LogHandle.logErrorFmtHandle("[GetFellowFightProp],xpcall error:{%s},traceback:%s", msg,
                        debug.traceback())
                end
                , formulaName, baseValue, FellowLvel)
            --local ret , num = FormulaMgr.CallFormulaFunc(formulaName, baseValue,FellowLvel)
            if not result or not callRet then
                LogHandle.logErrorFmtHandle(
                    "[GetFellowFightProp]CallFormulaFunc failed. configID[%s] propTemplateID[%s] propName[%s] FuncName[%s]",
                    configID, PropConfigID, k, formulaName)
                return
            end
            TotalPropInfo[k] = (TotalPropInfo[k] or 0) + num
            LogHandle.logInfoFmtHandle(
                "[GetFellowFightProp] add new Level prop[%s,%s,%s] FuncName[%s] configID[%s] FellowLvel[%s,%s]",
                k, num, TotalPropInfo[k], formulaName, configID, baseValue, FellowLvel)
        end
    end
end

---@class LogHandleInfo
---@field logInfoFmtHandle function
---@field logErrorFmtHandle function

---重新获得一个伙伴的战斗属性信息
---@param FellowInfo FellowInfo @see alias.xml
---@param LogHandle LogHandleInfo @see above
---@return FightPropInfo
function FightPropInfo.GetFellowFightProp(FellowInfo, LogHandle)
    local configID = FellowInfo.ConfigID
    local fellowData = TableData.GetFellowDataRow(configID)
    if not fellowData then
        LogHandle.logErrorFmtHandle("[GetFellowFightProp] no fellowData,configID[%s]", configID)
        return nil
    end
    local preStarUpID = fellowData.StarUpTemplateID * Enum.EFellowConstIntData.STAR_UP_CONFIG_ID_FACTOR
    local fellowPropInfo = FightPropInfo:new(LogHandle)
    local totalPropInfo = {}
    local firstStarUpLevel = FellowInfo.FirstStarUpLevel
    local preStarProp = Enum.EFellowConstStrData.STAR_UP_PROP_PREFIX

    --caculate Star Level fight prop
    for firstStarLevel = Enum.EFellowConstIntData.FIRST_STAR_UP_LEVEL_INIT, firstStarUpLevel do
        local secondStarLevel = Enum.EFellowConstIntData.MAX_STAR_UP_LEVEL
        if firstStarLevel == firstStarUpLevel then
            secondStarLevel = FellowInfo.SecondStarUpLevel
            fellowPropInfo.logInfoFmtHandle(
                "[GetFellowFightProp] up first star level,firstStarLevel[%s],secondStarLevel[%s]",
                firstStarLevel, secondStarLevel)
        end
        local starUpConfigID = preStarUpID + firstStarLevel
        if firstStarLevel == 6 then
            break
        end
        local starUpData = TableData.GetFellowStarUpDataRow(starUpConfigID)
        if not starUpData then
            fellowPropInfo.logErrorFmtHandle(
                "[GetFellowFightProp] no starUpData, starUpConfigID[%s] firstStarLevel[%s] configID[%s]",
                starUpConfigID, firstStarLevel, configID)
            return nil
        end

        for secondCount = 1, secondStarLevel do
            local propKey = preStarProp .. tostring(secondCount)
            local propDict = starUpData[propKey]
            if not propDict then
                fellowPropInfo.logErrorFmtHandle(
                    "[GetFellowFightProp] no propDict, starUpConfigID[%s] propKey[%s] configID[%s]",
                    starUpConfigID, propKey, configID)
                return nil
            end

            for k, v in pairs(propDict) do
                totalPropInfo[k] = (totalPropInfo[k] or 0) + v
                fellowPropInfo.logInfoFmtHandle("[GetFellowFightProp] add new starup prop[%s,%s,%s] configID[%s]",
                    k, v, totalPropInfo[k], configID)
            end
        end
    end

    local propTemplateID = fellowData.PropTemplateID
    FightPropInfo.calculateFellowLevelProp(fellowData, propTemplateID, FellowInfo.Level, totalPropInfo, LogHandle)
    for k, v in pairs(totalPropInfo) do
        fellowPropInfo:setAttr(k, v)
    end

    return fellowPropInfo
end

---重新获得一个伙伴的战斗属性信息
---@param FellowInfo FellowInfo @see alias.xml
---@param LogHandle LogHandleInfo @see above
---@return table
function FightPropInfo.GetFellowBaseFightProp(FellowInfo, LogHandle)
    local configID = FellowInfo.ConfigID
    local fellowData = TableData.GetFellowDataRow(configID)
    if not fellowData then
        LogHandle.logErrorFmtHandle("[GetFellowFightProp] no fellowData,configID[%s]", configID)
        return nil
    end
    local preStarUpID = fellowData.StarUpTemplateID * Enum.EFellowConstIntData.STAR_UP_CONFIG_ID_FACTOR
    local fellowPropInfo = FightPropInfo:new(LogHandle)

    local totalPropInfo = {}
    local firstStarUpLevel = FellowInfo.FirstStarUpLevel
    local preStarProp = Enum.EFellowConstStrData.STAR_UP_PROP_PREFIX

    --caculate Star Level fight prop
    for firstStarLevel = Enum.EFellowConstIntData.FIRST_STAR_UP_LEVEL_INIT, firstStarUpLevel do
        local secondStarLevel = Enum.EFellowConstIntData.MAX_STAR_UP_LEVEL
        if firstStarLevel == firstStarUpLevel then
            secondStarLevel = FellowInfo.SecondStarUpLevel
            fellowPropInfo.logInfoFmtHandle(
                "[GetFellowFightProp] up first star level,firstStarLevel[%s],secondStarLevel[%s]",
                firstStarLevel, secondStarLevel)
        end
        local starUpConfigID = preStarUpID + firstStarLevel
        if firstStarLevel == 6 then
            break
        end
        local starUpData = TableData.GetFellowStarUpDataRow(starUpConfigID)
        if not starUpData then
            fellowPropInfo.logErrorFmtHandle(
                "[GetFellowFightProp] no starUpData, starUpConfigID[%s] firstStarLevel[%s] configID[%s]",
                starUpConfigID, firstStarLevel, configID)
            return nil
        end

        for secondCount = 1, secondStarLevel do
            local propKey = preStarProp .. tostring(secondCount)
            local propDict = starUpData[propKey]
            if not propDict then
                fellowPropInfo.logErrorFmtHandle(
                    "[GetFellowFightProp] no propDict, starUpConfigID[%s] propKey[%s] configID[%s]",
                    starUpConfigID, propKey, configID)
                return nil
            end

            for k, v in pairs(propDict) do
                totalPropInfo[k] = (totalPropInfo[k] or 0) + v
                fellowPropInfo.logInfoFmtHandle("[GetFellowFightProp] add new starup prop[%s,%s,%s] configID[%s]",
                    k, v, totalPropInfo[k], configID)
            end
        end
    end

    local propTemplateID = fellowData.PropTemplateID
    FightPropInfo.calculateFellowLevelProp(fellowData, propTemplateID, FellowInfo.Level, totalPropInfo, LogHandle)

    return totalPropInfo
end


---获得伙伴等级的战斗属性信息
---@param ConfigID int @伙伴的配置ID
---@param LogHandle LogHandleInfo @see above
---@return table
function FightPropInfo.GetFellowLevelFightProp(ConfigID, Level, LogHandle)
    local retProp = FightPropInfo:new(LogHandle)
    local fellowData = TableData.GetFellowDataRow(ConfigID)
    if not fellowData then
        LogHandle.logErrorFmtHandle("[GetFellowFightProp] no fellowData,configID[%s]", ConfigID)
        return retProp
    end
    local propTemplateID = fellowData.PropTemplateID
    FightPropInfo.calculateFellowLevelProp(fellowData, propTemplateID, Level, retProp, LogHandle)
    return retProp
end

---重新获得一个伙伴的战斗属性信息
---@param FellowInfo FellowInfo @see alias.xml
---@param LogHandle LogHandleInfo @see above
---@return FightPropInfo
function FightPropInfo.GetFellowLevelUpFightProp(FellowInfo, Level, LogHandle)
    local configID = FellowInfo.ConfigID
    local fellowData = TableData.GetFellowDataRow(configID)
    if not fellowData then
        LogHandle.logErrorFmtHandle("[GetFellowFightProp] no fellowData,configID[%s]", configID)
        return nil
    end
    local preStarUpID = fellowData.StarUpTemplateID * Enum.EFellowConstIntData.STAR_UP_CONFIG_ID_FACTOR
    local fellowPropInfo = FightPropInfo:new(LogHandle)
    local totalPropInfo = {}
    local firstStarUpLevel = FellowInfo.FirstStarUpLevel
    local preStarProp = Enum.EFellowConstStrData.STAR_UP_PROP_PREFIX

    --caculate Star Level fight prop
    for firstStarLevel = Enum.EFellowConstIntData.FIRST_STAR_UP_LEVEL_INIT, firstStarUpLevel do
        local secondStarLevel = Enum.EFellowConstIntData.MAX_STAR_UP_LEVEL
        if firstStarLevel == firstStarUpLevel then
            secondStarLevel = FellowInfo.SecondStarUpLevel
            fellowPropInfo.logInfoFmtHandle(
                "[GetFellowFightProp] up first star level,firstStarLevel[%s],secondStarLevel[%s]",
                firstStarLevel, secondStarLevel)
        end
        local starUpConfigID = preStarUpID + firstStarLevel
        if firstStarLevel == 6 then
            break
        end
        local starUpData = TableData.GetFellowStarUpDataRow(starUpConfigID)
        if not starUpData then
            fellowPropInfo.logErrorFmtHandle(
                "[GetFellowFightProp] no starUpData, starUpConfigID[%s] firstStarLevel[%s] configID[%s]",
                starUpConfigID, firstStarLevel, configID)
            return nil
        end

        for secondCount = 1, secondStarLevel do
            local propKey = preStarProp .. tostring(secondCount)
            local propDict = starUpData[propKey]
            if not propDict then
                fellowPropInfo.logErrorFmtHandle(
                    "[GetFellowFightProp] no propDict, starUpConfigID[%s] propKey[%s] configID[%s]",
                    starUpConfigID, propKey, configID)
                return nil
            end

            for k, v in pairs(propDict) do
                totalPropInfo[k] = (totalPropInfo[k] or 0) + v
                fellowPropInfo.logInfoFmtHandle("[GetFellowFightProp] add new starup prop[%s,%s,%s] configID[%s]",
                    k, v, totalPropInfo[k], configID)
            end
        end
    end

    local propTemplateID = fellowData.PropTemplateID
    FightPropInfo.calculateFellowLevelProp(fellowData, propTemplateID, Level, totalPropInfo, LogHandle)
    for k, v in pairs(totalPropInfo) do
        fellowPropInfo:setAttr(k, v)
    end

    return fellowPropInfo
end

---重新获得一个伙伴的战力值
---@param FellowInfo FellowInfo @see alias.xml
---@param LogHandle LogHandleInfo @see above
---@return bool,int @bSuccess, CombatEffectiveness
function FightPropInfo.GetFellowCombatEffectiveness(FellowInfo, LogHandle)
    local configID = FellowInfo.ConfigID
    local fellowData = TableData.GetFellowDataRow(configID)
    if not fellowData then
        LogHandle.logErrorFmtHandle("[GetFellowCombatEffectiveness] no fellowData,configID[%s]", configID)
        return false, 0
    end


    local preStarUpID = fellowData.StarUpTemplateID * Enum.EFellowConstIntData.STAR_UP_CONFIG_ID_FACTOR
    local fellowfirstStarUpLevel = FellowInfo.FirstStarUpLevel
    local totalCE = fellowData.Initial_CE
    --Star up
    for firstStarLevel = Enum.EFellowConstIntData.FIRST_STAR_UP_LEVEL_INIT, fellowfirstStarUpLevel do
        local starUpConfigID = preStarUpID + firstStarLevel
        if firstStarLevel == 6 then
            break
        end
        local starUpData = TableData.GetFellowStarUpDataRow(starUpConfigID)
        local ceList = starUpData and starUpData.StarUpCe
        if (not starUpData) or (not ceList) then
            LogHandle.logErrorFmtHandle(
                "[GetFellowCombatEffectiveness] no starUpData[%s] or ceList[%s], starUpConfigID[%s] firstStarLevel[%s] configID[%s]",
                starUpData, ceList, starUpConfigID, firstStarLevel, configID)

            return false, 0
        end

        local secondStarLevel = Enum.EFellowConstIntData.MAX_STAR_UP_LEVEL
        if firstStarLevel == fellowfirstStarUpLevel then
            secondStarLevel = FellowInfo.SecondStarUpLevel
            LogHandle.logInfoFmtHandle(
                "[GetFellowCombatEffectiveness] up first star level,firstStarLevel[%s],secondStarLevel[%s]",
                firstStarLevel, secondStarLevel)
        else
            local firstCE = starUpData.GradeUpCE
            if type(firstCE) ~= "number" then
                LogHandle.logErrorFmtHandle(
                    "[GetFellowCombatEffectiveness]firstCE type is error[%s], starUpConfigID[%s] firstStarLevel[%s] configID[%s]",
                    type(firstCE), starUpConfigID, firstStarLevel, configID)
                return false, 0
            end
            totalCE = totalCE + firstCE
            LogHandle.logInfoFmtHandle(
                "[GetFellowCombatEffectiveness] add first star up CE totalCE[%s,%s], starUpConfigID[%s] StarLevel[%s] configID[%s]",
                totalCE, firstCE, starUpConfigID, firstStarLevel, configID)
        end

        for secondCount = 1, secondStarLevel do
            local ceValue = ceList[secondCount]
            if type(ceValue) ~= "number" then
                LogHandle.logErrorFmtHandle(
                    "[GetFellowCombatEffectiveness]ceValue type is error[%s], starUpConfigID[%s] StarLevel[%s,%s] configID[%s]",
                    type(ceValue), starUpConfigID, firstStarLevel, secondCount, configID)

                return false, 0
            end
            totalCE = totalCE + ceValue
            LogHandle.logInfoFmtHandle(
                "[GetFellowCombatEffectiveness] add star up CE totalCE[%s,%s], starUpConfigID[%s] StarLevel[%s,%s] configID[%s]",
                totalCE, ceValue, starUpConfigID, firstStarLevel, secondCount, configID)
        end
    end

    --level
    local rarityData = TableData.GetFellowRarityDataRow(fellowData.RarityId)
    local ceColName = rarityData and rarityData.LvUpCE
    if not ceColName then
        LogHandle.logErrorFmtHandle("[GetFellowCombatEffectiveness] ceColName[%s,%s] is error,configID[%s]", rarityData,
            ceColName, configID)
        return false, 0
    end
    local fellowLv = FellowInfo.Level
    if fellowLv < Enum.EFellowConstIntData.LEVEL_INIT then
        LogHandle.logErrorFmtHandle("[GetFellowCombatEffectiveness] Level[%s] is error,configID[%s]", fellowLv, configID)
        return false, 0
    end
    local targetLevel = fellowLv - 1
    for curLv = Enum.EFellowConstIntData.LEVEL_INIT, targetLevel do
        local fellowLvData = TableData.GetFellowLVDataRow(curLv)
        local lvCE = fellowLvData and fellowLvData[ceColName]
        if type(lvCE) ~= "number" then
            LogHandle.logErrorFmtHandle(
                "[GetFellowCombatEffectiveness] lvCE[%s,%s,%s] is error,configID[%s] Level[%s,%s]", ceColName,
                fellowLvData,
                lvCE
                , configID, curLv, fellowLv)
            return false, 0
        end

        totalCE = totalCE + lvCE
        LogHandle.logInfoFmtHandle(
            "[GetFellowCombatEffectiveness] add level CE totalCE[%s,%s],configID[%s] level[%s,%s]",
            totalCE, lvCE, configID, curLv, fellowLv)
    end

    LogHandle.logInfoFmtHandle(
        "[GetFellowCombatEffectiveness]get total CE totalCE[%s],configID[%s] level[%s] StarUpLevel[%s, %s]",
        totalCE, configID, fellowLv, fellowfirstStarUpLevel, FellowInfo.SecondStarUpLevel)
    return true, totalCE
end
