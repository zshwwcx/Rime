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
	table.getn = function(t) return #t  end
end

-- 初始化单个slot模板概率库
function GetRandomGroupStockSlotTemplateInfo(slot, class)
    local equipmentWordRandomGroupTable = TableData.GetEquipmentWordRandomGroupDataTable()
    local groupRateTable = {}

    for groupID, equipmentWordRandomGroupData in pairs(equipmentWordRandomGroupTable) do
        local slotKey = string.format("%s;%s", slot, class)
        local slotClassToRow = TableData.Get_EquipmentWordGroupTypeNameSlotClassToRow()[slotKey]
        local rate = equipmentWordRandomGroupData[slotClassToRow.RandomGroup]
        if rate > 0 then
            groupRateTable[groupID] = {}
            groupRateTable[groupID].baseValue = rate
            groupRateTable[groupID].value = groupRateTable[groupID].baseValue
            groupRateTable[groupID].adjustCount = 0
        end
    end

    return groupRateTable
end

-- 重建概率组
function CalcEquipRandomGroupStockSlotInfo(slot, profession, randomGroupStockSlotsInfo)
    local randomGroupStockSlotTable = {}
    randomGroupStockSlotTable.stockInfo = GetRandomGroupStockSlotTemplateInfo(slot, profession)

    if randomGroupStockSlotsInfo[slot] then
        randomGroupStockSlotTable.adjustTotalUpCount = randomGroupStockSlotsInfo[slot].adjustTotalUpCount or 0
        randomGroupStockSlotTable.adjustTotalDownCount = randomGroupStockSlotsInfo[slot].adjustTotalDownCount or 0
    else
        randomGroupStockSlotTable.adjustTotalUpCount = 0
        randomGroupStockSlotTable.adjustTotalDownCount = 0
    end
    
    if randomGroupStockSlotsInfo[slot] and randomGroupStockSlotsInfo[slot].stockInfo then
        for groupId, info in pairs(randomGroupStockSlotsInfo[slot].stockInfo) do
            randomGroupStockSlotTable.stockInfo[groupId] = {
                adjustCount = info.adjustCount,
                value = info.value
            }
        end
    end

    return randomGroupStockSlotTable
end

-- 方案名称特殊字符检测
---@return boolean true if name is valid, false otherwise
function CheckPlanNameValid(name)
	local LegalTextTable = TableData.GetLegalTextDataTable()
	for P, C in utf8.codes(name) do
		local bFound = false
		for _, Config in pairs(LegalTextTable) do
			local StartPosition = tonumber(Config.StartPosition, 16)
			local EndPosition = tonumber(Config.EndPosition, 16)
			if C >= StartPosition and C <= EndPosition then
				bFound = true
				break
			end
		end
		if not bFound then
			return false
		end
	end
	return true
end

-- 装备评分计算
function GetEquipScoreByInfo(Profession, EquipInfo, overrideRandom, overrideFixed)
	if not EquipInfo or not Profession then
		return 0
	end
	local EquipData = TableData.GetItemNewDataRow(EquipInfo.itemId)
	if not EquipData then
		return 0
	end
	local optionalClassData = TableData.GetPlayerBattleDataRow(Profession)
	if not optionalClassData then
		return 0
	end
	optionalClassData = optionalClassData[0]
	local randomProps = (overrideRandom or EquipInfo.equipmentPropInfo.randomPropInfo.randomProps) or {}
	local fixedProps = (overrideFixed or EquipInfo.equipmentPropInfo.fixedPropInfo.fixedProps) or {}

	-- 基础属性
	local randomRate = (100 + table.getn(randomProps) * Enum.EEquipmentConstData.EQUIP_RANDOMWORDTOBASE) / 100
	local basePropsMark = math.floor(EquipData.Mark * randomRate)

	-- 随机属性
	local randomPropsMark = 0
	for _, propId in pairs(randomProps) do
		local atkWordData = TableData.GetEquipmentWordRandomWordDataRow(propId)
		if not atkWordData then
			return -1
		end
		if optionalClassData.ClassPropType == 1 then
			randomPropsMark = randomPropsMark + math.floor(atkWordData.Mark * atkWordData.PMarkAj)
		elseif optionalClassData.ClassPropType == 2 then
			randomPropsMark = randomPropsMark + math.floor(atkWordData.Mark * atkWordData.MMarkAj)
		end
	end

	-- 固定属性
	local fixedPropsMark = 0
	for _, fixedProp in pairs(fixedProps) do
		local atkWordData = TableData.GetEquipmentWordFixedWordDataRow(fixedProp)
		if not atkWordData then
			return -1
		end
		if optionalClassData.ClassPropType == 1 then
			fixedPropsMark = fixedPropsMark + math.floor(atkWordData.Mark * atkWordData.PMarkAj)
		elseif optionalClassData.ClassPropType == 2 then
			fixedPropsMark = fixedPropsMark + math.floor(atkWordData.Mark * atkWordData.MMarkAj)
		end
	end

	return basePropsMark + randomPropsMark + fixedPropsMark
end

-- 更好槽位
---@param SlotInfo equipmentSlotInfo.slots
function GetBetterSlotByInfo(Profession, SlotInfo, equipInfo, addOnScoreTable)
	if not SlotInfo or not equipInfo or not equipInfo.itemId then
		return nil
	end

	local equipScore = GetEquipScoreByInfo(Profession,equipInfo)
	local min = equipScore
	local result
	local equipData = TableData.GetItemNewDataRow(equipInfo.itemId)
	if not equipData then
		return nil
	end
	local slotList = TableData.GetEquipmentTypeDataRow(equipData.subType).Slot
	for _, slotIdx in pairs(slotList) do
		if SlotInfo[slotIdx] == nil then
			return slotIdx
		end

		local compareScore
		if addOnScoreTable then
			compareScore = addOnScoreTable[slotIdx]
		else
			compareScore = GetEquipScoreByInfo(Profession, SlotInfo[slotIdx])
		end
		if compareScore < equipScore then
			if compareScore < min then
				min = compareScore
				result = slotIdx
			end
		end
	end
	return result
end