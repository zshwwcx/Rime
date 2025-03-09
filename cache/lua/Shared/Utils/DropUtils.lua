local const = kg_require("Shared.Const")
local itemConst = kg_require("Shared.ItemConst")
local lume = kg_require("Shared.lualibs.lume")
local utils = kg_require("Shared.Utils")
local itemUtils = kg_require("Shared.Utils.ItemUtils")

local assert = assert
local ipairs, pairs = ipairs, pairs
local math_max = math.max
local unpack = unpack
local math_random = math.random
local table_insert = table.insert

local DROP_TYPE = {
    NOT_DROP = 0,
    FIX_DROP = 1,
    RATE_DROP = 2,
}

local INV_BOUND_TYPE_BOUND_MIN = 4
local INV_BOUND_TYPE_UNBOUND_MIN = 5

local function solveBoundDict(idNumBoundDict, forceBound)
    local result = utils.deepCopyTable(idNumBoundDict)
    local INV_BOUND_TYPE_INSENSITIVE = const.INV_BOUND_TYPE_INSENSITIVE
    local INV_BOUND_TYPE_BOUND = const.INV_BOUND_TYPE_BOUND
    local INV_BOUND_TYPE_UNBOUND = const.INV_BOUND_TYPE_UNBOUND
    local itemDataData = TableData.GetItemNewDataTable()

    for itemId, numberInfo in pairs(result) do
        local idd = itemDataData[itemId]
        if numberInfo[INV_BOUND_TYPE_INSENSITIVE] and numberInfo[INV_BOUND_TYPE_INSENSITIVE] > 0 then
            if idd.bindType == itemConst.BIND_TYPE_GET then
                numberInfo[INV_BOUND_TYPE_BOUND]
                    = (numberInfo[INV_BOUND_TYPE_BOUND] or 0)
                    + numberInfo[INV_BOUND_TYPE_INSENSITIVE]
            else
                numberInfo[INV_BOUND_TYPE_UNBOUND]
                    = (numberInfo[INV_BOUND_TYPE_UNBOUND] or 0)
                    + numberInfo[INV_BOUND_TYPE_INSENSITIVE]
            end

            numberInfo[INV_BOUND_TYPE_INSENSITIVE] = nil
        end

        if idd.canUnbind ~= 1 or forceBound then
            local unboundNumber = numberInfo[INV_BOUND_TYPE_UNBOUND] or 0
            numberInfo[INV_BOUND_TYPE_UNBOUND] = 0
            numberInfo[INV_BOUND_TYPE_BOUND] = (numberInfo[INV_BOUND_TYPE_BOUND] or 0) + unboundNumber

            local unboundMinNumber = numberInfo[INV_BOUND_TYPE_UNBOUND_MIN] or 0
            numberInfo[INV_BOUND_TYPE_UNBOUND_MIN] = 0
            numberInfo[INV_BOUND_TYPE_BOUND_MIN] = (numberInfo[INV_BOUND_TYPE_BOUND_MIN] or 0) + unboundMinNumber
        end
    end
    return result
end

function getItemBindType(typeData)
    if not typeData then
        return const.INV_BOUND_TYPE_INSENSITIVE
    else
        if typeData == itemConst.BIND_TYPE_GET then
            return const.INV_BOUND_TYPE_BOUND
        else
            return const.INV_BOUND_TYPE_UNBOUND
        end
    end
end

function _addItemInfoToRet(ret, itemId, number, bindType)
    if not number or number <= 0 then
        return ret
    end
    local itemInfo = ret[itemId]
    if not itemInfo then
        itemInfo = itemUtils.genItemNumInfo(0, 0, 0)
        ret[itemId] = itemInfo
    end
    itemInfo[bindType] = (itemInfo[bindType] or 0) + number
    return ret
end

function _addItemInfoForDisplay(fixRet, rateRet, itemId, number, minNumber, bindType, dropType)
    if dropType == DROP_TYPE.FIX_DROP then
        _addItemInfoToRet(fixRet, itemId, number, bindType)
    elseif dropType == DROP_TYPE.RATE_DROP then
        _addItemInfoToRet(rateRet, itemId, number, bindType)
    end

    if number and number > 0 and minNumber and minNumber > 0 then
        local singleFixRet = fixRet[itemId]
        local singleRateRet = rateRet[itemId]
        local minBindType = INV_BOUND_TYPE_BOUND_MIN
        if bindType == const.INV_BOUND_TYPE_INSENSITIVE then
            local idd = TableData.GetItemNewDataRow(itemId)
            if idd.canUnbind == 1 and idd.bindType ~= itemConst.BIND_TYPE_GET then
                minBindType = INV_BOUND_TYPE_UNBOUND_MIN
            end
        elseif bindType == const.INV_BOUND_TYPE_UNBOUND then
            minBindType = INV_BOUND_TYPE_UNBOUND_MIN
        end

        if dropType == DROP_TYPE.FIX_DROP then
            singleFixRet[minBindType] = singleFixRet[minBindType] or 0
            singleFixRet[minBindType] = singleFixRet[minBindType] + minNumber
        elseif dropType == DROP_TYPE.RATE_DROP then
            local oldNumber = singleRateRet[minBindType] or 0
            if oldNumber <= 0 or number < oldNumber then
                singleRateRet[minBindType] = minNumber
            end
        end
    end
end

function getPlayerLimitNumMap(idNumDict)
    local idldd = playerItemDropLimitData.data
    local limitNumMap= {}
    for itemId, numInfo in pairs(idNumDict) do
        local limitId = idldd[itemId]
        if limitId then
            local sumNum = 0
            for _, v in pairs(numInfo) do
                sumNum = sumNum + v
            end
            limitNumMap[limitId] = sumNum
        end
    end
    return limitNumMap
end

function getConditionDropResult(conditionFunc, conditionArgs)
    local conditionPackages = {conditionFunc(unpack(conditionArgs))}
    local length = #conditionPackages
    assert(length % 2 == 0 and length > 0)

    local result = {}
    for i = 1, length, 2 do
        result[conditionPackages[i]] = conditionPackages[i + 1]
    end
    return result
end

function _mergeDropResult(targetResult, result, multiples)
    multiples = multiples or 1
    local bindTypeList = {
        const.INV_BOUND_TYPE_INSENSITIVE,
        const.INV_BOUND_TYPE_BOUND,
        const.INV_BOUND_TYPE_UNBOUND
    }
    for itemId, numberInfo in pairs(result) do
        for _, bindType in ipairs(bindTypeList) do
            if numberInfo[bindType] then
                _addItemInfoToRet(targetResult, itemId, numberInfo[bindType] * multiples, bindType)
            end
        end
    end
end

function _mergeDropResultWithMinNum(targetResult, result, multiples)
    multiples = multiples or 1
    local bindTypeList = {
        const.INV_BOUND_TYPE_INSENSITIVE,
        const.INV_BOUND_TYPE_BOUND,
        const.INV_BOUND_TYPE_UNBOUND,
        INV_BOUND_TYPE_BOUND_MIN,
        INV_BOUND_TYPE_UNBOUND_MIN
    }
    for itemId, numberInfo in pairs(result) do
        for _, bindType in ipairs(bindTypeList) do
            if numberInfo[bindType] then
                _addItemInfoToRet(targetResult, itemId, numberInfo[bindType] * multiples, bindType)
            end
        end
    end
end

function _mergeRateDropResultWithMinNum(targetResult, result, multiples)
    multiples = multiples or 1
    local bindTypeList = {
        const.INV_BOUND_TYPE_INSENSITIVE,
        const.INV_BOUND_TYPE_BOUND,
        const.INV_BOUND_TYPE_UNBOUND,
    }
    for itemId, numberInfo in pairs(result) do
        for _, bindType in ipairs(bindTypeList) do
            local targetResultNumber = targetResult[itemId] and targetResult[itemId][bindType]
            targetResultNumber = targetResultNumber or 0
            local newResultNumber = numberInfo[bindType]
            if newResultNumber then
                _addItemInfoToRet(targetResult, itemId, newResultNumber * multiples, bindType)
            end
        end

        local minTyeList = {
            INV_BOUND_TYPE_BOUND_MIN,
            INV_BOUND_TYPE_UNBOUND_MIN,
        }
        for _, bindType in ipairs(minTyeList) do
            local targetResultNumber = targetResult[itemId] and targetResult[itemId][bindType]
            targetResultNumber = targetResultNumber or 0
            local newResultNumber = numberInfo[bindType]
            if newResultNumber and (targetResultNumber <= 0 or newResultNumber < targetResultNumber) then
                _addItemInfoToRet(targetResult, itemId, newResultNumber * multiples, bindType)
            end
        end
    end
end

function _mergeDropForDisplay(fixRet, rateRet, resultFixRet, resultRateRet, dropType)
    if dropType == DROP_TYPE.FIX_DROP then
        _mergeDropResultWithMinNum(fixRet, resultFixRet)
        _mergeRateDropResultWithMinNum(rateRet, resultRateRet)
    elseif dropType == DROP_TYPE.RATE_DROP then
        _mergeRateDropResultWithMinNum(rateRet, resultFixRet)
        _mergeRateDropResultWithMinNum(rateRet, resultRateRet)
    end
end

function _subIndexDropType(index, dataList, extractMode, getRatioFunc)
    local ratio = getRatioFunc(dataList[index])
    if ratio <= 0 then
        return DROP_TYPE.NOT_DROP
    end
    if extractMode == const.EXTRACT_MODE_PROBABILITY then
        if ratio >= 1 then
            return DROP_TYPE.FIX_DROP
        end
        return DROP_TYPE.RATE_DROP
    elseif extractMode == const.EXTRACT_MODE_PROPORTION then
        for i, v in ipairs(dataList) do
            if i ~= index and getRatioFunc(v) > 0 then
                return DROP_TYPE.RATE_DROP
            end
        end
        return DROP_TYPE.FIX_DROP
    elseif extractMode == const.EXTRACT_MODE_PROPORTION_OVERFLOW then
        local frontRatio = 0
        for i = 1, index - 1 do
            frontRatio = frontRatio + getRatioFunc(dataList[i])
        end
        if frontRatio <= 0 then
            if ratio < 1 then
                return DROP_TYPE.RATE_DROP
            else
                return DROP_TYPE.FIX_DROP
            end
        elseif frontRatio < 1 then
            return DROP_TYPE.RATE_DROP
        else
            return DROP_TYPE.NOT_DROP
        end
    else
        return DROP_TYPE.NOT_DROP
    end
end

function _genSingleGroupDrop(groupId, needSplitResult, dropNumArgs)
    local groupData = dropGroupData.data[groupId] or {}

    local ret = {}
    local fixRet = {}
    local rateRet = {}
    for index, v in ipairs(groupData) do
        local itemId = v.itemId
        local ratio = v.dropRatio
        if ratio == nil or ratio > 0 then
            local bound = getItemBindType(v.fixBindType)
            local upperBound = v.dropMaxNum
            if upperBound == nil then
                local factor = v.dropMaxFunction[1]
                local funcId = v.dropMaxFunction[2]
                local funcRet = formulaData.data[funcId].formula(dropNumArgs)
                upperBound = math.floor(funcRet * factor)
            end
            local lowerBound = v.dropMinNum
            if lowerBound == nil then
                local factor = v.dropMinFunction[1]
                local funcId = v.dropMinFunction[2]
                local funcRet = formulaData.data[funcId].formula(dropNumArgs)
                lowerBound = math.floor(funcRet * factor)
            end

            local number = upperBound
            local nestedGroupId = v.nestedGroupId
            local dropType = _subIndexDropType(index, groupData, groupData[1].extractMode, function (data) return data.dropRatio or 1 end)
            if nestedGroupId then
                for i = 1, number do
                    local nestedRet, nestedFixRet, nestedRateRet = _genSingleGroupDrop(nestedGroupId, needSplitResult, dropNumArgs)
                    if needSplitResult then
                        lume.push(ret, unpack(nestedRet))
                    else
                        _mergeDropResult(ret, nestedRet)
                    end

                    _mergeDropForDisplay(fixRet, rateRet, nestedFixRet, nestedRateRet, dropType)
                end
            else
                if needSplitResult then
                    local temp = {}
                    _addItemInfoToRet(temp, itemId, number, bound)
                    lume.push(ret, temp)
                else
                    _addItemInfoToRet(ret, itemId, number, bound)
                end

                _addItemInfoForDisplay(fixRet, rateRet, itemId, number, lowerBound, bound, dropType)
            end
        end -- if ratio > 0
    end
    return ret, fixRet, rateRet
end

function _genSinglePackageDrop(dropBagId, needSplitResult, lv, school, dropNumArgs)
    local subPackageData = _selectSubPackage(dropBagId, lv, school)
    if subPackageData then
        return _genSubPackageDrop(subPackageData, needSplitResult, dropNumArgs)
    else
        return {}, {}, {}
    end
end

function _selectSubPackage(dropBagId, lv, school)
    -- 公共奖励包根据职业、等级选择对应的子掉落包
    assert(dropPackageData.data[dropBagId] ~= nil)
    for _, subPackageData in ipairs(dropPackageData.data[dropBagId]) do
        if lv >= subPackageData.lvLowLimit and lv <= subPackageData.lvHighLimit
            and (lume.find(subPackageData.schoolLimit, const.SCHOOL_ALL)
            or lume.find(subPackageData.schoolLimit, school)) then
            return subPackageData
        end
    end
    return nil
end

function _genSubPackageDrop(subPackageData, needSplitResult, dropNumArgs)
    local groupRatioList = subPackageData.groups or subPackageData.cgroups

    local ret = {}
    local fixRet = {}
    local rateRet = {}
    for index, v in ipairs(groupRatioList) do
        local groupId
        local ratio
        if type(v) == "table" or type(v) == 'userdata' then
            groupId, ratio = unpack(v)
        else
            groupId = v
        end

        local dropType = _subIndexDropType(index, groupRatioList, subPackageData.extractMode, function (data)
            if type(data) == "table" or type(data) == 'userdata' then
                local _, r = unpack(data)
                return r
            else
                return data
            end
        end)
        if ratio == nil or ratio > 0 then
            local singleGroupRet, singleFixRet, singleRateRet = _genSingleGroupDrop(groupId, needSplitResult, dropNumArgs)
            if needSplitResult then
                lume.push(ret, unpack(singleGroupRet))
            else
                _mergeDropResult(ret, singleGroupRet)
            end

            _mergeDropForDisplay(fixRet, rateRet, singleFixRet, singleRateRet, dropType)
        end
    end
    return ret, fixRet, rateRet
end

function _genFixedDrop(dropId, needSplitResult, _, _)
    local ret = {}
    local fixRet = {}
    local rateRet = {}
    for _, v in ipairs(dropData.data[dropId].fixedDrop) do
        local itemId = v[2]
        local number = v[3]
        local bound = getItemBindType(v[4])

        if needSplitResult then
            local temp = {}
            _addItemInfoToRet(temp, itemId, number, bound)
            lume.push(ret, temp)
        else
            _addItemInfoToRet(ret, itemId, number, bound)
        end
        _addItemInfoForDisplay(fixRet, rateRet, itemId, number, number, bound, DROP_TYPE.FIX_DROP)
    end
    return ret, fixRet, rateRet
end

function _genGroupDrop(dropId, needSplitResult, _, dropNumArgs)
    local groupIds = dropData.data[dropId].dropParam
    local ret = {}
    local fixRet = {}
    local rateRet = {}
    for _, groupId in ipairs(groupIds) do
        local singleGroupRet, singleFixRet, singleRateRet = _genSingleGroupDrop(groupId, needSplitResult, dropNumArgs)
        if needSplitResult then
            lume.push(ret, unpack(singleGroupRet))
        else
            _mergeDropResult(ret, singleGroupRet)
        end

        _mergeDropForDisplay(fixRet, rateRet, singleFixRet, singleRateRet, DROP_TYPE.FIX_DROP)
    end
    return ret, fixRet, rateRet
end

function _genPackageDrop(dropId, needSplitResult, conditionArgs, dropNumArgs)
    local lv, school = unpack(conditionArgs)
    local dropBagIds = dropData.data[dropId].dropParam
    local ret = {}
    local fixRet = {}
    local rateRet = {}
    for _, dropBagId in ipairs(dropBagIds) do
        local singlePackageRet, singleFixRet, singleRateRet = _genSinglePackageDrop(dropBagId, needSplitResult, lv, school, dropNumArgs)
        if needSplitResult then
            lume.push(ret, unpack(singlePackageRet))
        else
            _mergeDropResult(ret, singlePackageRet)
        end

        _mergeDropForDisplay(fixRet, rateRet, singleFixRet, singleRateRet, DROP_TYPE.FIX_DROP)
    end
    return ret, fixRet, rateRet
end

function _genRatioDrop(dropId, needSplitResult, _, _)
    local ret = {}
    local fixRet = {}
    local rateRet = {}
    for _, v in ipairs(dropData.data[dropId].ratioDrop) do
        local itemId = v[2]
        local ratio = v[3]
        if ratio > 0 then
            local lowerBound = v[4]
            local upperBound = v[5]
            local bound = getItemBindType(v[6])
            local number = upperBound

            if needSplitResult then
                local temp = {}
                _addItemInfoToRet(temp, itemId, number, bound)
                lume.push(ret, temp)
            else
                _addItemInfoToRet(ret, itemId, number, bound)
            end

            if ratio >= 1 then
                _addItemInfoForDisplay(fixRet, rateRet, itemId, number, lowerBound, bound, DROP_TYPE.FIX_DROP)
            else
                _addItemInfoForDisplay(fixRet, rateRet, itemId, number, lowerBound, bound, DROP_TYPE.RATE_DROP)
            end
        end -- ratio > 0
    end
    return ret, fixRet, rateRet
end

function _selectSubConditionPackage(dropBagId, lv)
    -- 条件公式奖励包根据等级选择对应的子掉落包
    assert(dropConditionPackageData.data[dropBagId] ~= nil)
    for _, subPackageData in ipairs(dropConditionPackageData.data[dropBagId]) do
        if lv >= subPackageData.lvLowLimit and lv <= subPackageData.lvHighLimit then
            return subPackageData
        end
    end
    return nil
end

function _genConditionDrop(dropId, needSplitResult, conditionArgs, dropNumArgs)
    local conditionFunc = dropData.data[dropId].conditionalDrop
    local result = getConditionDropResult(conditionFunc, conditionArgs)

    local ret = {}
    local fixRet = {}
    local rateRet = {}
    local lv = conditionArgs[1]
    for conditionPackageId, multiples in pairs(result) do
        local dcpdd = _selectSubConditionPackage(conditionPackageId, lv)
        if dcpdd then
            local singlePackageRet, singleFixRet, singleRateRet = _genSubPackageDrop(dcpdd, needSplitResult, dropNumArgs)
            if needSplitResult then
                for i = 1, multiples do
                    lume.push(ret, singlePackageRet)
                    lume.push(fixRet, singleFixRet)
                    lume.push(rateRet, singleRateRet)
                end
            else
                _mergeDropResult(ret, singlePackageRet, multiples)
                _mergeDropForDisplay(fixRet, rateRet, singleFixRet, singleRateRet, DROP_TYPE.FIX_DROP)
            end
        end
    end
    return ret, fixRet, rateRet
end

---------- function tables ----------
_genDropItemsNumberInfoFunctions = {
    [itemConst.DROP_TYPE_FIXED] = _genFixedDrop,
    [itemConst.DROP_TYPE_GROUP] = _genGroupDrop,
    [itemConst.DROP_TYPE_PACKAGE] = _genPackageDrop,
    [itemConst.DROP_TYPE_RATIO] = _genRatioDrop,
    [itemConst.DROP_TYPE_CONDITION] = _genConditionDrop
}

--------------------

function _callDropFunction(dropId, functionTable, ...)
    local ddd = dropData.data[dropId]
    if ddd == nil then
        return {}, {}, {}
    end
    local dropType = ddd.dropType
    if dropType == nil or functionTable[dropType] == nil then
        return {}, {}, {}
    end
    return functionTable[dropType](dropId, ...)
end

function _genDropItemsNumberInfo(dropId, needSplitResult, conditionArgs, dropNumArgs, player)
    dropNumArgs = _getDefaultDropNumArgs(dropNumArgs)
    return _callDropFunction(dropId, _genDropItemsNumberInfoFunctions, needSplitResult, conditionArgs, dropNumArgs)
end

function _getDefaultConditionArgs(dropId, player)
    local ddd = dropData.data[dropId]
    if ddd == nil then
        return {}
    end
    if ddd.dropType == itemConst.DROP_TYPE_PACKAGE then
        return {player and player.lv or 1, player and player.school or 3}
    else
        return {}
    end
end

function _getDefaultDropNumArgs(dropNumArgs, player)
    local pet = player and player:getCurPet()
    --[[
    itemConst 加字段定义
    --lv 人物等级，获得掉落玩家的人物等级(DROP_INDEX_PLAYER_LV)；
    --mlv 怪物等级，如果掉落配置在怪物身上，则取此怪物的等级；否则取默认值1。
    --recLv 任务推荐等级，如果掉落配置在任务上，则取《任务表》中 “任务_内容表” recLv 字段的值；否则取默认值1。
    --hard 任务难度，如果掉落配置在任务上，则取《任务表》中 “任务_内容表” hard字段的值；否则取默认值1。
    --grpCount 组队人数，玩家队伍中的人数；如果玩家没有组队取1。
    --plv 出战英灵等级。如果玩家当前没有出战的英灵，则取默认值为1。
    --srcId 掉落来源
    --teamGuildMember 队伍中同公会人数(包括自己)
    --]]
    local defaultArgs = {
        lv = player and player.lv or 1,
        mlv = 1,
        recLv = 1,
        hard = 1,
        grpCount = player and math_max(#player.teamInfo.members, 1) or 1,
        plv = pet and pet.lv or 1,
        srcId = itemConst.DROP_SRC_ID_DEFAULT,
        teamGuildMember = 0,
    }
    table.merge(defaultArgs, dropNumArgs or {})
    return defaultArgs
end

--------------------------public interface----------------------
-- 根据dropId获取物品
function genDropItems(dropId, needSplitResult, conditionArgs, player, dropNumArgs, forceBound)
    dropNumArgs = _getDefaultDropNumArgs(dropNumArgs, player)
    conditionArgs = conditionArgs or _getDefaultConditionArgs(dropId, player)
    local idNumDict, fixIdNumDict, rateIdNumDict = _genDropItemsNumberInfo(dropId, needSplitResult, conditionArgs, dropNumArgs)
    return idNumDict, solveBoundDict(fixIdNumDict, forceBound), solveBoundDict(rateIdNumDict, forceBound)
end



--------------------------各种自定义的掉落规则----------------------

-- 固定掉落的drop task, 里面不会有随机的规则
FIX_DROP_FUNC_NAMES = {
    DropBox = true,
    DropSex = true,
    DropProfession = true,
    DropProfessionSex = true,
    DropLevel = true,
}

function DropBox(ent, args)
    -- 固定掉落（物品列表），每个物品按照指定的数量和绑定情况掉落
    -- 参考格式：DropBox(item=1001,1002,1003; num=1,1,2; bind=1,,0)
    return args
end

function DropRandom(ent, args)
    -- 纯概率掉落：
    -- 参考格式：DropRandom(item=1001,1002,1003; num=1,1,2; prob=0.01,0.1,0.9;bind=1,,0)
    -- 具体说明：每个物品的掉落概率独立判断1次，判断成功则掉落对应数量的物品。
    local items = {}
    for _, arg in pairs(args) do
        local prob = arg.prob
        if prob == 1 or math_random() <= prob then
            table_insert(items, arg)
        end
    end

    return items
end

function DropRandomWithFix(ent, args)
    -- 含保底的概率掉落：
    -- 参考格式：DropRandomWithFix(fixitem=1000; fixnum=2; fixbind=1 ! item=1001,1002,1003; num=1,1,2; prob=0.01,0.1,0.9; bind=1,,0)
    -- 具体说明：从第2个物品开始进行概率判断。每个物品的掉落概率独立判断1次，判断成功则掉落对应数量的物品。如果什么都没掉，就掉落第1个物品。
    local items = DropRandom(ent, args[2])
    if next(items) then
        return items
    else
        local itemInfo = args[1]
        return { item = itemInfo.fixitem, num = itemInfo.fixnum, bind = itemInfo.fixbind }
    end
end

function DropWeight(ent, args)
    -- 权重掉落
    -- 参考格式：DropWeight(times=2 ! item=1001,1002,1003; num=1,1,2; weight=10,20,30; bind=1,,0)
    -- 具体说明：次数填几就表示按这一套权重随机掉落几次，每次掉1个物品
    local times = args[1].times
    -- @todo 后期可以迭代导表后处理计算好总权重
    local totalWeight = 0
    for _, itemInfo in pairs(args[2]) do
        totalWeight = totalWeight + itemInfo.weight
    end

    local items = {}
    for _ = 1, times do
        local curWeight = math_random(1, totalWeight)
        for _, itemInfo in pairs(args[2]) do
            curWeight = curWeight - itemInfo.weight
            if curWeight < 1 then
                table_insert(items, itemInfo)
                break
            end
        end
    end

    return items
end

function DropSex(ent, args)
    -- 按性别掉落
    -- 参考格式：DropSex(sex=0,1; item=1001,1002; num=1,,2; bind=1,0)
    -- sex的枚举为0和1，其中0是男，1是女, 参考EAVATAR_SEX枚举
    -- 具体说明：使使用该task时，必须完整枚举所有性别
    local sex = ent.Sex
    for _, arg in pairs(args) do
        if arg.sex == sex then
            return arg
        end
    end
end

function DropProfession(ent, args)
    -- 按职业掉落
    -- 参考格式：DropProfession(profession=11,12; item=1001,1002; num=1,2; bind=1,0)
    -- 具体说明：使用该task时，必须完整枚举所有职业
    local profession = ent.Profession
    for _, arg in pairs(args) do
        if arg.profession == profession then
            return arg
        end
    end
end

function DropProfessionSex(ent, args)
    -- 按性别职业掉落
    -- 参考格式：DropProfessionSex(profession=11,11,12,12; sex=0,1,0,1; item=1001,1002,1003,1004; num=1,2,3,4; bind=1,0,,1)
    -- sex的枚举为0和1，其中0是男，1是女, 参考EAVATAR_SEX枚举
    -- 具体说明：这里实际上是对drop4中职业ID的细化，比如观众ID是1，那么ID-10表示职业-女观众，ID-11表示男观众，根据尾号的0和1来判断。拓展到其他职业，也是这个规则。
    -- 使用该task时，必须完整枚举所有职业和性别（如果存在单性别职业，那么这个职业只需要列举对应性别即可，不要求两种性别都包含）
    local profession = ent.Profession
    local sex = ent.Sex
    for _, arg in pairs(args) do
        if arg.profession == profession and arg.sex == sex then
            return arg
        end
    end
end

function DropLevel(ent, args)
    -- 按等级掉落
    -- 参考格式：DropLevel(lv=10,30,60; item=1001,1002,1003; num=1,2,3; bind=1,0,)
    -- 具体说明：
    --    0  < 角色等级 ≤ Lv1 时，获得物品ID1（个数为数量1）；
    --    Lv1  < 角色等级 ≤ Lv2 时，获得物品ID2（个数为数量2）；
    --    ……
    --    Lvn-1  < 角色等级 ≤ Lvn 时，获得对应数量物品IDn（个数为数量n）；
    --    角色等级>Lvn时，也获得对应数量物品IDn（个数为数量n）；
    local level = ent.Level
    for _, arg in ipairs(args) do
        if level <= arg.lv then
            return arg
        end
    end

    return args[#args]
end
