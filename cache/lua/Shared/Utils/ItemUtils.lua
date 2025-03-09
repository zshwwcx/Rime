local math = math
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
local TableData = Game.TableData or TableData
local table_sort = table.sort
local getn = table.getn

local const = kg_require("Shared.Const")
local itemConst = kg_require("Shared.ItemConst")
local lume = kg_require("Shared.lualibs.lume")



function meetLevelLimit(player, itemId, lvReq)
    local idd = TableData.GetItemNewDataRow(itemId)
    if not idd then
        return
    end

    lvReq = (lvReq and math.floor(lvReq)) or idd.lvReq or 1
    return (idd.lvTop == nil or player.Level <= idd.lvTop) and player.Level >= lvReq
end

function meetLevelBottom(player, itemId, lvReq)
    local idd = TableData.GetItemNewDataRow(itemId)    
    if not idd then
        return
    end

    lvReq = (lvReq and math.floor(lvReq)) or idd.lvReq or 1
    return player.Level >= lvReq
end

function meetLevelTop(player, itemId, lvReq)
    local idd = TableData.GetItemNewDataRow(itemId)    
    if not idd then
        return
    end

    lvReq = (lvReq and math.floor(lvReq)) or idd.lvReq or 1
    return idd.lvTop == nil or player.Level <= idd.lvTop
end

function isSchoolMeetItem(itemId, school)
    -- 检查职业限制
    local idd = TableData.GetItemNewDataRow(itemId)    
    if not idd then
        return false
    end

    local schoolLimit = idd.classlimit
    if schoolLimit == nil then
        return true
    end
    for _, v in ipairs(schoolLimit) do
        if v == const.SCHOOL_ALL then
            return true
        else
            if v == school then
                return true
            end
        end
    end
    return false
end

function meetSchoolLimit(itemId, player)
    return isSchoolMeetItem(itemId, player.Profession)
end

itemOperation = setmetatable({}, {
    __index = function(_, key)
        return function(itemId)
            local iodd = TableData.GetItemOperationTypeDataRow(itemId)
            return iodd and iodd[key] == 1
        end
    end
})


function getItemQuality(itemInfo)
    local idd = TableData.GetItemNewDataRow(itemInfo.itemId) or {}
    local quality
    if idd.isEquip then
        quality = itemInfo.quality or idd.quality
    else
        quality = idd.quality
    end

    return quality or const.QUALITY_WHITE
end

function getItemLvReq(itemInfo)
    local idd = TableData.GetItemNewDataRow(itemInfo.itemId) or {}    
    return idd.lvReq
end

function genItemNumInfo(insensitive, bound, unbound)
    return {
        [const.INV_BOUND_TYPE_INSENSITIVE] = insensitive,
        [const.INV_BOUND_TYPE_BOUND] = bound,
        [const.INV_BOUND_TYPE_UNBOUND] = unbound,
    }
end

-- function formatIdNumBoundDict(idNumDict, isFixBind, rate)
--     local ret = {}
--     rate = rate or 1
--     local INV_BOUND_TYPE_INSENSITIVE = const.INV_BOUND_TYPE_INSENSITIVE
--     local INV_BOUND_TYPE_BOUND = const.INV_BOUND_TYPE_BOUND
--     local INV_BOUND_TYPE_UNBOUND = const.INV_BOUND_TYPE_UNBOUND
--     for k, v in pairs(idNumDict) do
--         if type(v) == "number" then
--             if isFixBind then -- 强制绑定
--                 ret[k] = genItemNumInfo(0, v*rate, 0)
--             else
--                 ret[k] = genItemNumInfo(v*rate, 0, 0)
--             end
--         else
--             if rate == 1 then
--                 ret[k] = v
--             else
--                 ret[k] = {
--                     [INV_BOUND_TYPE_INSENSITIVE] = v[INV_BOUND_TYPE_INSENSITIVE]*rate,
--                     [INV_BOUND_TYPE_BOUND] = v[INV_BOUND_TYPE_BOUND]*rate,
--                     [INV_BOUND_TYPE_UNBOUND] = v[INV_BOUND_TYPE_UNBOUND]*rate,
--                 }
--             end
--         end
--     end
--     return ret
-- end

function isValInTable(val, table)
    for _, value in pairs(table) do
        if val == value then
            return true
        end
    end
    return false
end


function formatIdNumBoundDict(idNumDict, isFixBind, rate, randomRewardItemIds)
    local ret = {}
    rate = rate or 1
    local INV_BOUND_TYPE_INSENSITIVE = const.INV_BOUND_TYPE_INSENSITIVE
    local INV_BOUND_TYPE_BOUND = const.INV_BOUND_TYPE_BOUND
    local INV_BOUND_TYPE_UNBOUND = const.INV_BOUND_TYPE_UNBOUND
    for k, v in pairs(idNumDict) do
        if not randomRewardItemIds or not isValInTable(k, randomRewardItemIds)then
            if type(v) == "number" then
                if isFixBind then -- 强制绑定
                    ret[k] = genItemNumInfo(0, v*rate, 0)
                else
                    ret[k] = genItemNumInfo(v*rate, 0, 0)
                end
            else
                if rate == 1 then
                    ret[k] = v
                else
                    ret[k] = {
                        [INV_BOUND_TYPE_INSENSITIVE] = v[INV_BOUND_TYPE_INSENSITIVE]*rate,
                        [INV_BOUND_TYPE_BOUND] = v[INV_BOUND_TYPE_BOUND]*rate,
                        [INV_BOUND_TYPE_UNBOUND] = v[INV_BOUND_TYPE_UNBOUND]*rate,
                    }
                end
            end
        else
            if type(v) == "number" then
                if isFixBind then -- 强制绑定
                    ret[k] = genItemNumInfo(0, -1, 0)
                else
                    ret[k] = genItemNumInfo(-1, 0, 0)
                end
            else
                ret[k] = {
                    [INV_BOUND_TYPE_INSENSITIVE] = v[INV_BOUND_TYPE_INSENSITIVE] ~= 0 and -1 or v[INV_BOUND_TYPE_INSENSITIVE],
                    [INV_BOUND_TYPE_BOUND] = v[INV_BOUND_TYPE_BOUND] ~= 0 and -1 or v[INV_BOUND_TYPE_BOUND],
                    [INV_BOUND_TYPE_UNBOUND] = v[INV_BOUND_TYPE_UNBOUND] ~= 0 and -1 or v[INV_BOUND_TYPE_UNBOUND],
                }
            end
        end
    end
    return ret
end

--- return：2：绑定；3：非绑
function getDecomposeItemInfo(slotInfo, number, isServer, dropUtils, entID)
    local INV_BOUND_TYPE_INSENSITIVE = const.INV_BOUND_TYPE_INSENSITIVE
    local INV_BOUND_TYPE_BOUND = const.INV_BOUND_TYPE_BOUND
    local INV_BOUND_TYPE_UNBOUND = const.INV_BOUND_TYPE_UNBOUND
	if not slotInfo then return end
    local itemId = slotInfo.itemId

    -- 封印物
    local idd = TableData.GetItemNewDataRow(itemId)
    if idd.type == itemConst.ITEM_TYPE_SEALED then
        local rewards
        local boundType = INV_BOUND_TYPE_INSENSITIVE
        if idd.bindType == itemConst.BIND_TYPE_NONE then
            boundType = INV_BOUND_TYPE_UNBOUND
        elseif idd.bindType == itemConst.BIND_TYPE_GET then
            boundType = INV_BOUND_TYPE_BOUND
        elseif idd.bindType == itemConst.BIND_TYPE_OWN then
            boundType = idd.bound and INV_BOUND_TYPE_BOUND or INV_BOUND_TYPE_UNBOUND
        end
        local sealedPropInfo = itemId and slotInfo.sealedPropInfo
        local upgradeMaterialList = ReturnUpgradeMaterials(itemId, sealedPropInfo.sealedRandomPropInfo)
        local refineMaterialList = GetRetSealedRandomMaterial(itemId, sealedPropInfo.refineTimes)
        local breakMaterialList = GetDecomposeRetMaterial(itemId, sealedPropInfo.sealedBreakthrough)
        rewards = MergeMaterialListByBindType({upgradeMaterialList, refineMaterialList, breakMaterialList}, boundType)
        return rewards
    -- 装备
    elseif idd.isEquip then
        local equipmentInfo = slotInfo
        local quality = equipmentInfo.quality
        local lv = idd.lvReq
        local subType = idd.subType
        local equipTypeData = TableData.GetEquipmentTypeDataRow(subType)
        local key = subType..";"..quality..";"..lv
        local id = TableData.Get_DecomposeEquipKeyToID()[key]
        if not id then
            -- Log.Error("[getDecomposeItemInfo], cant find equip decompose info, key: ", key)
            return {}
        end
        local decomposeEquipData = TableData.GetDecomposeEquipDataRow(id)
        if not decomposeEquipData then
            -- Log.Error("[getDecomposeItemInfo], cant find equip decompose info, id: ", id)
            return {}
        end
        local boundType = INV_BOUND_TYPE_INSENSITIVE
        if decomposeEquipData.bindType == itemConst.BIND_TYPE_NONE then
            boundType = INV_BOUND_TYPE_UNBOUND
        elseif decomposeEquipData.bindType == itemConst.BIND_TYPE_GET then
            boundType = INV_BOUND_TYPE_BOUND
        elseif decomposeEquipData.bindType == itemConst.BIND_TYPE_OWN then
            boundType = equipmentInfo.bound and INV_BOUND_TYPE_BOUND or INV_BOUND_TYPE_UNBOUND
        end
        local rewards = {}
        local specialRewards = {}

        for id, count in pairs(decomposeEquipData.fixedReward) do
            if not rewards[id] then
                rewards[id] = { 0, 0, 0 }
            end
            local rewardsInfo = rewards[id]
            rewardsInfo[boundType] = rewardsInfo[boundType] + count
        end

        for id, formulaId in pairs(decomposeEquipData.randomReward) do
            local count
            local formularData = TableData.GetFormulaDataRow(formulaId)
            if not formularData then 
                count = 0 
            else
                local formulaFunc = FormulaManager.FormulaStr2FuncSimple(formularData.Formula)
                count = formulaFunc(lv)
            end
            if count > 0 then
                if not rewards[id] then
                    rewards[id] = { 0, 0, 0 }
                end
                local rewardsInfo = rewards[id]
                rewardsInfo[boundType] = rewardsInfo[boundType] + count
            end
        end

        for id, returnRate in pairs(decomposeEquipData.ReturnItem) do
            local count = 0
            local quality = getItemQuality(equipmentInfo)
            local subType = idd.subType
            local equipTypeData = TableData.GetEquipmentTypeDataRow(subType)
            local Slot = equipTypeData.Slot[1]
            local ConfigData = TableData.GetEquipmentGrowPropConfigDataTable()
            local finalKey
            for key, v in pairs(ConfigData) do
                local TCMin = v.TC[1]
                local TCMax = v.TC[2]
                if idd.TC >= TCMin and idd.TC <= TCMax then
                    for _, t in pairs(v.Slot) do
                        if t == Slot then
                            for _,q in pairs(v.Quality) do
                                if q == quality then
                                    finalKey = key
                                    break
                                end
                            end
                        end
                    end
                end
            end

            if finalKey then
                local equipGrowAtkRandomData = TableData.GetEquipmentGrowRandomDataRow(finalKey)
                if equipGrowAtkRandomData then
                    local singleConsumeCount = equipGrowAtkRandomData.SingleConsume[Enum.EEquipmentGrowConstData.ITEM_RANDOM_ID]
                    local randomEnhanceCount = equipmentInfo.equipmentPropInfo.randomPropInfo.randomEnhanceCount or 0
                    count = math.floor(randomEnhanceCount * singleConsumeCount * returnRate)
                end
            end
        
            if count > 0 then
                if not rewards[id] then
                    rewards[id] = { 0, 0, 0 }
                end
                local rewardsInfo = rewards[id]
                rewardsInfo[boundType] = rewardsInfo[boundType] + count
            end
        end

        return formatIdNumBoundDict(rewards, nil, number)
    end

    local didd = TableData.GetDecomposeItemDataRow(itemId)
    local decomposeItem
    local rewards = {}
    if didd then
        if not isServer then
            return getRandomDecomposeItemInfoClient(itemId, number)
        else
            return getRandomDecomposeItemInfoServer(itemId, number, dropUtils, entID)
        end
    else
        decomposeItem = idd.decomposeItem
        if decomposeItem then
            for itemId, itemInfo in pairs(decomposeItem) do
                local rewardsInfo = rewards[itemId]
                for count, isBound in pairs(itemInfo) do
                    if rewardsInfo then
                        if isBound == 1 then
                            rewardsInfo[INV_BOUND_TYPE_BOUND] = rewardsInfo[INV_BOUND_TYPE_BOUND] + count
                        elseif isBound == 0 then
                            rewardsInfo[INV_BOUND_TYPE_UNBOUND] = rewardsInfo[INV_BOUND_TYPE_UNBOUND] + count
                        end
                    else
                        if isBound == 1 then
                            rewards[itemId] = {
                                0,
                                count,
                                0
                            }
                        elseif isBound == 0 then
                            rewards[itemId] = {
                                0,
                                0,
                                count
                            }
                        end
                    end
                end
            end
        end
        if next(rewards) then
            return formatIdNumBoundDict(rewards, nil, number)
        else
            return {}
        end
    end
end

function getRandomDecomposeItemInfoClient(itemId, number)
    local INV_BOUND_TYPE_INSENSITIVE = const.INV_BOUND_TYPE_INSENSITIVE
    local INV_BOUND_TYPE_BOUND = const.INV_BOUND_TYPE_BOUND
    local INV_BOUND_TYPE_UNBOUND = const.INV_BOUND_TYPE_UNBOUND
    
    local didd = TableData.GetDecomposeItemDataRow(itemId)
    local dropGroupSetId
    local decomposeItem
    local rewards = {}
    local randomRewardItemIds = {}
    if didd then
        decomposeItem = didd.decomposeItem
        if decomposeItem then
            for rewardId, itemInfo in pairs(decomposeItem) do
                local rewardsInfo = rewards[rewardId]
                for count, isBound in pairs(itemInfo) do
                    if rewardsInfo then
                        if isBound == 1 then
                            rewardsInfo[INV_BOUND_TYPE_BOUND] = rewardsInfo[INV_BOUND_TYPE_BOUND] + count
                        elseif isBound == 0 then
                            rewardsInfo[INV_BOUND_TYPE_UNBOUND] = rewardsInfo[INV_BOUND_TYPE_UNBOUND] + count
                        end
                    else
                        if isBound == 1 then
                            rewards[rewardId] = {
                                0,
                                count,
                                0
                            }
                        elseif isBound == 0 then
                            rewards[rewardId] = {
                                0,
                                0,
                                count
                            }
                        end
                    end
                end
            end
        end

        dropGroupSetId = didd.dropId
        if dropGroupSetId ~= 0 then
            local dgsdd = TableData.GetDropGroupSetDataRow(dropGroupSetId)
            for rewardId, numberInfo in pairs(dgsdd.FixedRewards) do
                if numberInfo[INV_BOUND_TYPE_INSENSITIVE] == -1 or numberInfo[INV_BOUND_TYPE_BOUND] == -1 or numberInfo[INV_BOUND_TYPE_UNBOUND] == -1 then
                    table.insert(randomRewardItemIds, rewardId)
                end
                local rewardsInfo = rewards[rewardId]
                if rewardsInfo then
                    rewardsInfo[INV_BOUND_TYPE_INSENSITIVE] = rewardsInfo[INV_BOUND_TYPE_INSENSITIVE] + numberInfo[INV_BOUND_TYPE_INSENSITIVE]
                    rewardsInfo[INV_BOUND_TYPE_BOUND] = rewardsInfo[INV_BOUND_TYPE_BOUND] + numberInfo[INV_BOUND_TYPE_BOUND]
                    rewardsInfo[INV_BOUND_TYPE_UNBOUND] = rewardsInfo[INV_BOUND_TYPE_UNBOUND] + numberInfo[INV_BOUND_TYPE_UNBOUND]
                else
                    rewards[rewardId] = {
                        numberInfo[INV_BOUND_TYPE_INSENSITIVE],
                        numberInfo[INV_BOUND_TYPE_BOUND],
                        numberInfo[INV_BOUND_TYPE_UNBOUND]
                    }
                end
            end
        end

        if next(rewards) then
            return formatIdNumBoundDict(rewards, nil, number, randomRewardItemIds)
        else
            return nil
        end
    end
end

function getRandomDecomposeItemInfoServer(itemId, number, dropUtils, entID)
    local INV_BOUND_TYPE_INSENSITIVE = const.INV_BOUND_TYPE_INSENSITIVE
    local INV_BOUND_TYPE_BOUND = const.INV_BOUND_TYPE_BOUND
    local INV_BOUND_TYPE_UNBOUND = const.INV_BOUND_TYPE_UNBOUND
    local didd = TableData.GetDecomposeItemDataRow(itemId)
    local dropGroupSetId
    local decomposeItem
    local rewards = {}
    if didd then
        decomposeItem = didd.decomposeItem
        if decomposeItem then
            for rewardId, itemInfo in pairs(decomposeItem) do
                local rewardsInfo = rewards[rewardId]
                for count, isBound in pairs(itemInfo) do
                    if rewardsInfo then
                        if isBound == 1 then
                            rewardsInfo[INV_BOUND_TYPE_BOUND] = rewardsInfo[INV_BOUND_TYPE_BOUND] + count
                        elseif isBound == 0 then
                            rewardsInfo[INV_BOUND_TYPE_UNBOUND] = rewardsInfo[INV_BOUND_TYPE_UNBOUND] + count
                        end
                    else
                        if isBound == 1 then
                            rewards[rewardId] = {
                                0,
                                count,
                                0
                            }
                        elseif isBound == 0 then
                            rewards[rewardId] = {
                                0,
                                0,
                                count
                            }
                        end
                    end
                end
            end
        end
        if next(rewards) then
            rewards = formatIdNumBoundDict(rewards, nil, number)
        end
        dropGroupSetId = didd.dropId
        if dropGroupSetId ~= 0 then
            for i = 1, number do
                local randomRewards = dropUtils.CalcDropLib({entID=entID}, dropGroupSetId, 1)
                for Uid, Reward in pairs(randomRewards) do
                    local rewardId = Reward.tid
                    local isBind = Reward.isBind
                    local count = Reward.count
                    local rewardsInfo = rewards[rewardId]
                    if rewardsInfo then
                        rewardsInfo[INV_BOUND_TYPE_INSENSITIVE] = rewardsInfo[INV_BOUND_TYPE_INSENSITIVE]
                        rewardsInfo[INV_BOUND_TYPE_BOUND] = isBind == 1 and rewardsInfo[INV_BOUND_TYPE_BOUND] + count or rewardsInfo[INV_BOUND_TYPE_BOUND]
                        rewardsInfo[INV_BOUND_TYPE_UNBOUND] = isBind == 0 and rewardsInfo[INV_BOUND_TYPE_UNBOUND] + count or rewardsInfo[INV_BOUND_TYPE_UNBOUND]
                    else
                        rewards[rewardId] = {
                            0,
                            isBind == 1 and count or 0,
                            isBind == 0 and count or 0,
                        }
                    end
                end
            end  
        end
    end
    if next(rewards) then
        return rewards
    else
        return nil
    end
end

function checkItemAttributeIntegrity(itemInfo)
    if itemInfo.expired == nil or itemInfo.gbId == nil or itemInfo.purchaseInfo == nil or
        itemInfo.bound == nil or itemInfo.useTimes == nil or itemInfo.index == nil or itemInfo.itemId == nil or
        itemInfo.count == nil or (itemInfo.equipmentPropInfo == nil and itemInfo.petEquipPropInfo == nil) or
        itemInfo.expiryTime == nil or itemInfo.quality == nil then

        return false
    end

    return true
end

function getConfigForbiddenProps(key, itemId)
    return true
end


-- 检查装备是否是绝世装备
function checkEquipmentIsPeerless(equipmentInfo)
    equipmentInfo = equipmentInfo or {}
    local idd = TableData.GetItemNewDataRow(equipmentInfo.itemId)
    if not idd or not idd.isEquip then
        return false
    end

    local edd = TableData.GetItemNewDataRow(equipmentInfo.itemId)
    if not edd or edd.isPeerless ~= 1 then
        return false
    end

    return true
end


function getItemName(itemId)
    local idd = TableData.GetItemNewDataRow(itemId)
    return idd and idd.itemName
end

function hasUsed(item)
    local idd = TableData.GetItemNewDataRow(item.itemId) or {}
    if not idd.reuseTimes or item.useTimes == 0 then
        return false
    end
    return true
end

function isBooty(item)
    return item.customData and item.customData.isBooty
end

function clearBooty(item)
    if item.customData then
        item.customData.isBooty = nil
    end
end

-- 指定绑定性的道具结构转化为id:number格式的简单结构
-----param idNumDict(指定绑定性)->  {[itemId1] = {不敏感数量1, 绑定数量1, 非绑数量1}, [itemId2] = {不敏感数量2, 绑定数量2, 非绑数量2}})
-----return (不指定绑定性) ->{[itemId1] = num1, [itemId2] = num2})
function idNumDict2SimpleIdNumMap(idNumDict)
    local r = {}
    for id, info in pairs(idNumDict) do
        r[id] = (info[const.INV_BOUND_TYPE_INSENSITIVE] or 0) + (info[const.INV_BOUND_TYPE_BOUND] or 0) + (info[const.INV_BOUND_TYPE_UNBOUND] or 0)
    end
    return r
end

function idNumDict2boundDict(idNumDict)
    local r = {}
    for id, number in pairs(idNumDict2SimpleIdNumMap(idNumDict)) do
        r[id] = {
            [const.INV_BOUND_TYPE_INSENSITIVE] = 0,
            [const.INV_BOUND_TYPE_BOUND] = number,
            [const.INV_BOUND_TYPE_UNBOUND] = 0,
        }
    end
    return r
end

--tempIdNumDict 合并到 srcIdNumDict
function mergeIdNumDict(srcIdNumDict, tempIdNumDict)
    if not tempIdNumDict or not srcIdNumDict then
        return
    end

    for id, num in pairs(tempIdNumDict) do
        srcIdNumDict[id] = (srcIdNumDict[id] or 0) + num
    end
    return srcIdNumDict
end

function getEquipmentOriginalCE(equipment)
    local equipmentEquipProp = equipment and equipment.equipmentPropInfo
    local equipmentCE = 0
    if equipmentEquipProp then
        equipmentCE = math.floor(equipmentEquipProp.equipCE - equipmentEquipProp.enhanceCE - equipmentEquipProp.gemPropCE)
    end

    return equipmentCE
end

function isEquipmentCanBatch(item, equipItem, quality, school, vipLv, serverOpenDay)
    if not quality or not school then
        return false
    end

    local itemId = item.itemId
    local idd = TableData.GetItemNewDataRow(itemId)
    if idd.isEquip then
        if getItemQuality(item) > quality then
            return false
        end
    end
    return true
end


function getShareUseItemMaxUseTimes(itemId, lv)
    local idd = TableData.GetItemNewDataRow(itemId)
    if not idd.sharingUseGroupTag then
        return math.huge
    end
    local isudd = TableData.GetSharingUseGroupDataRow(idd.sharingUseGroupTag)
    if not isudd then
        return 0
    end

    -- if isudd.limitType == 1 then
    --     local limitTimesFunc = formulaData.data[isudd.sharingUseTimes]
    --     if not limitTimesFunc then
    --         return 0
    --     end
    --     return limitTimesFunc.formula(lv) or 0
    -- else
    return isudd.sharingUseTimes or 0
    -- end
end


function getSealedIDHash(first, second)
    return first * Enum.ESealedConstIntData.HASH_VALUE + second
end

--计算需返还封印物升级材料数量
function ReturnUpgradeMaterials(itemId, randomAttrs)
    local sealedData = TableData.GetItemNewDataRow(itemId)
    if sealedData == nil then
        LOG_ERROR_FMT("[ReturnUpgradeMaterials]failed to find sealedData by itemId:%s", itemId)
        return {}
    end
    local rarity = sealedData.quality
    local rarityData = TableData.GetSealedRarityDataRow(rarity)
    local materialCnt = 0
    local moneyCnt = 0
    
    for _, info in pairs(randomAttrs) do

        repeat
            if info.attrLevel == 0 then
                break
            end
            local sealedLvId = getSealedIDHash(rarity, info.attrLevel - 1)
            local upgradeData = TableData.GetSealedLVDataRow(sealedLvId)
            if not upgradeData then
                LOG_ERROR_FMT("[ReturnUpgradeMaterials]failed to find upgradeData by itemId:%s, sealedLvId:%s", itemId, sealedLvId)
                break
            end

            materialCnt = materialCnt + upgradeData.LvUpItemIncrease
            moneyCnt = moneyCnt + upgradeData.LvUpMoneyIncrease
        until 0
        
    end

    materialCnt = math.floor(materialCnt * rarityData.RankUpItemReturn)
    moneyCnt = math.floor(moneyCnt * rarityData.RankUpMoneyReturn)
    return {[ Enum.ESealedConstIntData.ITEM_ID] = materialCnt, [Enum.ESealedConstIntData.MONEY_ID] = moneyCnt}
end

--返还洗练材料
function GetRetSealedRandomMaterial(itemId, refineTimes)
    local sealedData = TableData.GetItemNewDataRow(itemId)
    if sealedData == nil then
        LOG_ERROR_FMT("[GetRetSealedRandomMaterial]failed to find sealedData by itemId:%s", itemId)
        return {}
    end
    local rarity = sealedData.quality
    local rarityData = TableData.GetSealedRarityDataRow(rarity)
    if rarityData == nil then
        LOG_ERROR_FMT("[GetRetSealedRandomMaterial]failed to find rarityData by rarity:%s", rarity)
        return {}
    end
    local materialCnt = math.floor(rarityData.RandomItem * refineTimes * rarityData.RandomItemReturn)

    return {[Enum.ESealedConstIntData.RANDOM_ITEM_ID] = materialCnt}
end

--返还分解时材料
function GetDecomposeRetMaterial(itemId, breakLv)
    local sealedData = TableData.GetItemNewDataRow(itemId)
    if sealedData == nil then
        LOG_ERROR_FMT("[GetDecomposeRetMaterial]failed to find sealedData by itemId:%s", itemId)
        return {}
    end
    local rarity = sealedData.quality
    local rarityData = TableData.GetSealedRarityDataRow(rarity)
    if rarityData == nil then
        LOG_ERROR_FMT("[GetDecomposeRetMaterial]failed to find rarityData by rarity:%s", rarity)
        return {}
    end
    local breakMaterialList = {}

    for id, count in pairs(rarityData.DecomposeReward) do
        breakMaterialList[id] = count * breakLv
    end
    
    return breakMaterialList
end

--合并需要返还的材料列表
function MergeMaterialListByBindType(allList, boundType)
    local returnMaterialList = {}
    for _, materialList in pairs(allList) do
        for itemId, itemCnt in pairs(materialList) do
            if returnMaterialList[itemId] then
                returnMaterialList[itemId][boundType] = returnMaterialList[itemId][boundType] + itemCnt
            elseif itemCnt > 0 then
                returnMaterialList[itemId] = {0,0,0}
                returnMaterialList[itemId][boundType] = itemCnt
            end
        end
    end

    return returnMaterialList
end

--是否为公示期商品
function isPublicItem(itemInfo)
    local sdd = TableData.GetStallDataRow(itemInfo.itemId)
    if not sdd then
        return false
    end

    local isBoard = sdd.isBoard
    if isBoard == nil then
        return false
    end

    return isBoard == 1
end

function checkIsFreePrice(itemInfo)
    local sdd = TableData.GetStallDataRow(itemInfo.itemId)
    if not sdd then
        return false
    end
    --[[
    --自由定价 的方式有功能迭代(改成珍品判断条件)
    local instanceType = sdd.instanceType
    if instanceType == nil or instanceType == const.COMMON_FREE_PRICE_TYPE then
        return sdd.isFreePrice == 1
    elseif instanceType == const.TREASURE_FREE_PRICE_TYPE then
        return checkIsTreasure(itemInfo)
    end--]]

    return sdd.isFreePrice == 1
end

-- 是否展示用自由定价道具（类型可能自由定价则都算作自由定价）
function checkIsFreePriceToDisplay(itemId)
    local sdd = TableData.GetStallDataRow(itemId)
    if not sdd then
        return false
    end

    local instanceType = sdd.instanceType
    if instanceType == nil or instanceType == const.COMMON_FREE_PRICE_TYPE then
        return sdd.isFreePrice == 1
    elseif instanceType == const.TREASURE_FREE_PRICE_TYPE then
        local idd = itemData.data[itemId]
        if not idd then
            return false
        end

        local preciousInstanceCriterion = idd.preciousInstanceCriterion
        if preciousInstanceCriterion == nil or preciousInstanceCriterion == const.NONE_TREASURE_TYPE then
            return false
        elseif preciousInstanceCriterion == const.ALL_TREASURE_TYPE then
            return true
        else
            return true
        end
    end
    return false
end

function getCurrentWeekLimit(lastWeekLimit, configData)
    if lastWeekLimit == nil then
        lastWeekLimit = 0
    end
    return math.min(lastWeekLimit + configData.weekMaxNum, configData.upperLimit)
end

-- 是否是货币
function isMoney(itemId)
	local idd = TableData.GetItemNewDataRow(itemId)
	if not idd then
		return false
	end
	return idd.type == itemConst.ITEM_TYPE_SPECIAL and idd.subType == itemConst.ITEM_SUBTYPE_MONEY
end

function getItemHoldMaxByCfg(idd)
	local holdMax = 0
	if not idd then
		return holdMax
	end
	holdMax = idd.holdMax or itemConst.ITEM_DEFAULT_HOLD_MAX
	return holdMax
end

function _isSameArtistOutputInCustomData(infoA, infoB)
	if infoA ~= nil and infoB ~= nil then
		if infoA.type ~= infoB.type then
			return false
		end

		if infoA.name ~= infoB.name or infoA.path ~= infoB.path  then
			return false
		end

		if infoA.workId ~= infoB.workId then
			return false
		end

		if infoA.skillLvs ~= nil and infoB.skillLvs ~= nil then
			if lume.count(infoA.skillLvs) ~= lume.count(infoB.skillLvs) then
				return false
			end

			local infoB_skillLvs = infoB.skillLvs
			for skillId, skillLv in pairs(infoA.skillLvs) do
				if skillLv ~= infoB_skillLvs[skillId] then
					return false
				end
			end
		elseif infoA.skillLvs ~= infoB.skillLvs then
			return false
		end
	elseif infoA ~= infoB then
		return false
	end
	return true
end

function tableIsEmptyOrNil(t)
	if t == nil or next(t) == nil then
		return true
	end
	return false
end

function _isSameCustomData(customDataA, customDataB)
	local emptyOrNilA = tableIsEmptyOrNil(customDataA)
	local emptyOrNilB = tableIsEmptyOrNil(customDataB)
	if emptyOrNilA and emptyOrNilB then
		return true
	end

	if emptyOrNilA or emptyOrNilB then
		return false
	end

	local isBootyA = customDataA.isBooty
	local isBootyB = customDataB.isBooty
	if isBootyA ~= isBootyB then
		return false
	end

	local bigTreasureDataA = customDataA.bigTreasureData
	local bigTreasureDataB = customDataB.bigTreasureData
	if bigTreasureDataA ~= nil or bigTreasureDataB ~= nil then
		return false
	end

	if customDataA.musicInfo or customDataB.musicInfo or customDataA.notationInfo or customDataB.notationInfo then
		if _isSameArtistOutputInCustomData(customDataA.musicInfo, customDataB.musicInfo) and
			_isSameArtistOutputInCustomData(customDataA.notationInfo, customDataB.notationInfo) then
			return true
		end
	end
	if customDataA.stylistDesignInfo or customDataB.stylistDesignInfo then
		local infoA = customDataA.stylistDesignInfo
		local infoB = customDataB.stylistDesignInfo
		if infoA and infoB and infoA.md5 and infoB.md5 and infoA.md5 == infoB.md5 and infoA.name == infoB.name then
			return true
		end
	end

	return false
end

function _isItemCanMerge(targetItem, item)
	if not targetItem or not item then
		return false
	end

	if targetItem.itemId ~= item.itemId then
		return false
	end

	if targetItem.bound ~= item.bound then
		return false
	end

	-- 是装备不可堆叠
	local edd = TableData.GetItemNewDataRow(item.itemId)
	if edd.equipType then
		return false
	end

	if item.purchaseInfo.moneyType ~= targetItem.purchaseInfo.moneyType then
		-- 策划保证相同item，moneyType不为0的话，一定是相同的
		weakAssert(item.purchaseInfo.moneyType == 0 or
			targetItem.purchaseInfo.moneyType == 0, "same itemId, moneyType must be same or 0")
		return false
	end

	if targetItem.purchaseInfo.freezeTime ~= 0 and targetItem.purchaseInfo.freezeTime < Game.TimeInSecCache then
		targetItem.purchaseInfo.freezeTime = 0
	end
	if item.purchaseInfo.freezeTime ~= 0 and item.purchaseInfo.freezeTime < Game.TimeInSecCache then
		item.purchaseInfo.freezeTime = 0
	end
	if targetItem.purchaseInfo.freezeTime ~= item.purchaseInfo.freezeTime then
		return false
	end

	local idd= TableData.GetItemNewDataRow(item.itemId)
	if item.useTimes > 0 or targetItem.useTimes > 0 or idd.reuseTimes == 0 then
		return false
	end

	return _isSameCustomData(item.customData, targetItem.customData)
end

function weakAssert(judge, msg)
	if not judge then
		msg = msg or "weak assertion failed"
		LOG_ERROR_FMT(msg)
	end
end

--- 堆叠两个物品
function _mergeItem(invId, targetItem, item, needLog, player, opNUID, logSrc)
	assert(targetItem.bound == item.bound)

	local idd= TableData.GetItemNewDataRow(item.itemId)
	assert(idd ~= nil)
	local maxWrap = idd.mwrap

	local ttlType = idd.ttlType
	if ttlType and ttlType[1] == itemConst.ITEM_EXPIRY_TIME_TYPE_RELATIVE then
		weakAssert(maxWrap == 1)
	end

	if targetItem.count >= maxWrap then
		return
	end

	if not _isItemCanMerge(targetItem, item) then
		return
	end

	local delta
	if targetItem.count + item.count < maxWrap then
		delta = item.count
	else
		delta = maxWrap - targetItem.count
	end

	if needLog then
		player:logInfoFmt("mergeSourceItem invId:%s item:%v number:%s opNUID:%s logSrc:%s", invId, item, -delta, opNUID, logSrc)
	end
	item.count = item.count - delta
	if needLog then
		player:logInfoFmt("mergeTargetItem invId:%s item:%v number:%s opNUID:%s logSrc:%s", invId, targetItem, -delta, opNUID, logSrc)
	end
	if targetItem.purchaseInfo.moneyType ~= 0 then
		local oldTargetItemTotalPrice = targetItem.count * targetItem.purchaseInfo.price
		targetItem.purchaseInfo.price = math.round(         -- luacheck: ignore
			(oldTargetItemTotalPrice + delta * item.purchaseInfo.price) / (targetItem.count + delta))
	end
	targetItem.count = targetItem.count + delta
end

function _canWrap(itemId)
	local idd = TableData.GetItemNewDataRow(itemId)
	assert(idd ~= nil)
	return idd.mwrap > 1
end

function _addItemToList(invId, list, item, needLog, player, opNUID, logSrc)
	if _canWrap(item.itemId) then
		local lastItem = list[getn(list)]
		if lastItem ~= nil then
			_mergeItem(invId, lastItem, item, needLog, player, opNUID, logSrc)
		end
		if item.count == 0 then
			return
		end
	end
	list[getn(list) + 1] = item
end

function addItemToRet(ret, items)
	for _, v in ipairs(items) do
		ret[getn(ret) + 1] = v
	end
end

function sortItemsFunction(a, b)
	local idda = TableData.GetItemNewDataRow(a.itemId)
	local iddb = TableData.GetItemNewDataRow(b.itemId)
	local invdda = TableData.GetInventoryDataRow(idda.invId)
	local invddb = TableData.GetInventoryDataRow(iddb.invId)
	local isBootyA = isBooty(a)
	local isBootyB = isBooty(b)
	local qualityA = getItemQuality(a)
	local qualityB = getItemQuality(b)

	if idda.invId ~= iddb.invId then
		return (invdda and invdda.sort or 0) < (invddb and invddb.sort or 0)
	elseif idda.subType ~= iddb.subType then
		return idda.subType < iddb.subType
	elseif qualityA ~= qualityB then
		return qualityA > qualityB
	elseif a.itemId ~= b.itemId then
		return a.itemId > b.itemId
	elseif isBootyA ~= isBootyB then
		return isBootyA == true
	elseif a.bound ~= b.bound then
		return a.bound == true
	elseif a.purchaseInfo.moneyType ~= b.purchaseInfo.moneyType then
		return a.purchaseInfo.moneyType > b.purchaseInfo.moneyType
	elseif a.purchaseInfo.price ~= b.purchaseInfo.price then
		return a.purchaseInfo.price > b.purchaseInfo.price
	elseif a.purchaseInfo.freezeTime ~= b.purchaseInfo.freezeTime then
		if a.purchaseInfo.freezeTime > 0 and b.purchaseInfo.freezeTime > 0 then
			return a.purchaseInfo.freezeTime < b.purchaseInfo.freezeTime
		else
			return a.purchaseInfo.freezeTime > b.purchaseInfo.freezeTime
		end
	elseif a.count ~= b.count then
		return a.count > b.count
	elseif a.expiryTime ~= 0 and a.expiryTime ~= b.expiryTime then
		return a.expiryTime < b.expiryTime
	else
		if not idda.reuseTimes then
			return a.index < b.index
		end
		if a.useTimes <= 0 or b.useTimes <= 0 then
			return a.index < b.index
		end
		return a.useTimes > b.useTimes
	end
end

function sortItems(invId, items, needLog, player, opNUID, logSrc)
	local idTable = {}
	local resetKeys = {}

	for k, v in pairs(items) do
		local itemId = v.itemId
		if idTable[itemId] == nil then
			idTable[itemId] = {
				itemId = itemId,
				hasExpiryTime = {
					bound = {purchased = {}, unpurchased = {}, booty = {}, forbiddenMerge = {}},
					unbound = {purchased = {}, unpurchased = {}, booty = {}, forbiddenMerge = {}}
				},
				noExpiryTime = {
					bound = {purchased = {}, unpurchased = {}, booty = {}, forbiddenMerge = {}},
					unbound = {purchased = {}, unpurchased = {}, booty = {}, forbiddenMerge = {}}
				}
			}
		end
		local subIdTable = v.expiryTime ~= 0 and idTable[itemId].hasExpiryTime or idTable[itemId].noExpiryTime
		local itemList = v.bound and subIdTable.bound or subIdTable.unbound
		if v.useTimes > 0 then -- 使用过的道具单独组成一组队列
			itemList = itemList.forbiddenMerge
		elseif isBooty(v) then
			itemList = itemList.booty
		elseif v.purchaseInfo.moneyType ~= 0 or v.purchaseInfo.freezeTime ~= 0 then
			itemList = itemList.purchased
		else
			itemList = itemList.unpurchased
		end
		_addItemToList(invId, itemList, v, needLog, player, opNUID, logSrc)
		table.insert(resetKeys, k)
	end

	local ret = {}

	for _, v in pairs(idTable) do
		addItemToRet(ret, v.hasExpiryTime.bound.purchased)
		addItemToRet(ret, v.hasExpiryTime.bound.unpurchased)
		addItemToRet(ret, v.hasExpiryTime.bound.booty)
		addItemToRet(ret, v.hasExpiryTime.bound.forbiddenMerge)
		addItemToRet(ret, v.hasExpiryTime.unbound.purchased)
		addItemToRet(ret, v.hasExpiryTime.unbound.unpurchased)
		addItemToRet(ret, v.hasExpiryTime.unbound.booty)
		addItemToRet(ret, v.hasExpiryTime.unbound.forbiddenMerge)
		addItemToRet(ret, v.noExpiryTime.bound.purchased)
		addItemToRet(ret, v.noExpiryTime.bound.unpurchased)
		addItemToRet(ret, v.noExpiryTime.bound.booty)
		addItemToRet(ret, v.noExpiryTime.bound.forbiddenMerge)
		addItemToRet(ret, v.noExpiryTime.unbound.purchased)
		addItemToRet(ret, v.noExpiryTime.unbound.unpurchased)
		addItemToRet(ret, v.noExpiryTime.unbound.booty)
		addItemToRet(ret, v.noExpiryTime.unbound.forbiddenMerge)
	end

	table_sort(ret, sortItemsFunction)

	for i, v in ipairs(ret) do
		v.index = i
	end

	return ret, resetKeys
end
