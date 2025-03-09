local TableData = Game.TableData or TableData

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
local lume = kg_require("Shared.lualibs.lume")
-- local LOG_DEBUG = LOG_DEBUG
-- local LOG_INFO = LOG_INFO

STATUS = {
    BASEID_INVALID = 1,
    HERBID_INVALID = 2,
    POISON_EXTREME = 3,
    MEDICINE_PROPERTY_EXTREME = 4,
    IN_INVALIDATION = 5,
    ON_PATH = 6,
    SUCCESS = 7,
}

function rotationTransformation(x, y, radian)
    local ret_x = math.cos(radian) * x - math.sin(radian) * y
    local ret_y = math.sin(radian) * x + math.cos(radian) * y
    return ret_x, ret_y
end

-- 获取多边形的顶点坐标
function getScreenPropertyNormalizedVector2DMap(baseId)
    local makeMedicineBaseData = TableData.GetMakeMedicineBaseDataRow(baseId)

    if not makeMedicineBaseData then
        return
    end

    local medPropVectorMap = getPropertyNormalizedVector2DMap(makeMedicineBaseData.IncludeMedProp)
    local initialMedPropAngle = makeMedicineBaseData.InitialMedPropAngle
    local radian = math.rad(initialMedPropAngle)

    for _, medPropVector2D in pairs(medPropVectorMap) do
        medPropVector2D[1], medPropVector2D[2] = rotationTransformation(medPropVector2D[1], medPropVector2D[2], radian)
    end

    return medPropVectorMap
end

-- 获取药品的圆心和半径
function getScreenMedicineNormalizedCircle(baseId)
    local makeMedicineBaseData = TableData.GetMakeMedicineBaseDataRow(baseId)

    if not makeMedicineBaseData then
        return
    end

    local circleInfo = {}
    local propMax = makeMedicineBaseData.PropMax
    local medicineInfoByBase = TableData.Get_MakeMedicineBaseIdToMedicineInfo()[baseId] or {}
    local initialMedPropAngle = makeMedicineBaseData.InitialMedPropAngle
    local radian = math.rad(initialMedPropAngle)
    for medicineId, info in pairs(medicineInfoByBase) do
        local x, y = unpack(info.Position)
        x = x / propMax
        y = y / propMax
        x, y = rotationTransformation(x, y, radian)
        local radius = info.Radius / propMax
        circleInfo[medicineId] = {position={x, y}, radius=radius}
    end

    return circleInfo
end

-- 获取herbItemIdList序列到达的状态和额外参数（坐标等）
-- status:BASEID_INVALID, ret:{baseId}
-- status:HERBID_INVALID, ret:{herbItemId}
-- status:POISON_EXTREME, ret:{index, position}
-- status:MEDICINE_PROPERTY_EXTREME, ret:{index, position}
-- status:IN_INVALIDATION, ret:{position}
-- status:ON_PATH, ret:{index, position}
-- status:SUCCESS, ret:{index, position, medicineID}
function getScreenEndPointNormalizedPosition(baseId, herbItemIdList)
    local status, ret = getEndPoint2DPosition(baseId, herbItemIdList)

    if not ret.position then
        return status, ret
    end

    local pos_x, pos_y = unpack(ret.position)
    local makeMedicineBaseData = TableData.GetMakeMedicineBaseDataRow(baseId)

    local propMax = makeMedicineBaseData.PropMax
    local normalized_x = pos_x / propMax
    local normalized_y = pos_y / propMax

    local initialMedPropAngle = makeMedicineBaseData.InitialMedPropAngle
    local radian = math.rad(initialMedPropAngle)
    normalized_x, normalized_y = rotationTransformation(normalized_x, normalized_y, radian)
    ret.position = {normalized_x, normalized_y}
    -- LOG_DEBUG("getScreenEndPointNormalizedPosition", normalized_x, normalized_y)
    return status, ret
end

function getEndPoint2DPosition(baseId, herbItemIdList)
    local baseData = TableData.GetMakeMedicineBaseDataRow(baseId)

    if not baseData then
        return STATUS.BASEID_INVALID, {baseID=baseId}
    end

    local medPropVectorMap = getPropertyNormalizedVector2DMap(baseData.IncludeMedProp)
    local propMax = baseData.PropMax

    local curentMedPropMap = {}
    for _, propId in pairs(baseData.IncludeMedProp) do
        curentMedPropMap[propId] = 0
    end

    local makeMedicineHerbItemIdToRow = TableData.Get_MakeMedicineHerbItemIdToRow()
    local curentPoisonProperty = 0
    local medicineInfoByBase = TableData.Get_MakeMedicineBaseIdToMedicineInfo()[baseId]

    local pos_x = 0
    local pos_y = 0
    for i, herbItemId in pairs(herbItemIdList) do
        local makeMedicineHerbData = makeMedicineHerbItemIdToRow[herbItemId]
        if not makeMedicineHerbData then
            return STATUS.HERBID_INVALID, {herbItemID=herbItemId}
        end
        for propId, value in pairs(makeMedicineHerbData.MedicineProperty) do
            curentMedPropMap[propId] = curentMedPropMap[propId] + value
        end

        pos_x, pos_y = unpack(getMedPropMapVector2D(curentMedPropMap, medPropVectorMap))
        -- LOG_DEBUG("getEndPoint2DPosition", i, pos_x, pos_y, curentPoisonProperty, propMax)

        if checkIsPoisonExtreme(pos_x, pos_y, curentPoisonProperty) then
            -- LOG_INFO("getEndPoint2DPosition checkIsPoisonExtreme true")
            return STATUS.POISON_EXTREME, {index=i, position={pos_x, pos_y}}
        end

        if checkIsMedicinePropertyExtreme(pos_x, pos_y, propMax) then
            -- LOG_INFO("getEndPoint2DPosition checkIsMedicinePropertyExtreme true")
            return STATUS.MEDICINE_PROPERTY_EXTREME, {index=i, position={pos_x, pos_y}}
        end

        curentPoisonProperty = curentPoisonProperty + makeMedicineHerbData.PoisonProperty
    end

    if checkIsInInvalidation(pos_x, pos_y, baseData.Invalidation) then
        -- LOG_INFO("getEndPoint2DPosition checkIsInInvalidation true")
        return STATUS.IN_INVALIDATION, {position={pos_x, pos_y}}
    end

    for medicineID, info in pairs(medicineInfoByBase) do
        if checkIsInMedicineCircle(pos_x, pos_y, info) then
            return STATUS.SUCCESS, {position={pos_x, pos_y}, medicineID=medicineID}
        end
    end
    return STATUS.ON_PATH, {position={pos_x, pos_y}}
end

function getPropertyNormalizedVector2DMap(medPropList)
    local medPropVectorMap = {}
    local n = #medPropList
    for i, medPropId in pairs(medPropList) do
        local radian = (i - 1) / n * 2 * math.pi
        local x = math.cos(radian)
        local y = math.sin(radian)
        medPropVectorMap[medPropId] = {x, y}
    end
    return medPropVectorMap
end

function getMedicineVector2DMap(medicineInfoByBase)
    local medicineVectorMap = {}
    for medicineId, info in pairs(medicineInfoByBase) do
        medicineVectorMap[medicineId] = info.Position
    end
    return medicineVectorMap
end

function getMedPropMapVector2D(medPropMap, medPropVectorMap)
    local pos_x = 0
    local pos_y = 0
    for medPropId, value in pairs(medPropMap) do
        local x, y = unpack(medPropVectorMap[medPropId])
        pos_x = pos_x + x * value
        pos_y = pos_y + y * value
    end
    return {pos_x, pos_y}
end

function checkIsPoisonExtreme(pos_x, pos_y, poisonProperty)
    if pos_x * pos_x + pos_y * pos_y < poisonProperty * poisonProperty then
        return true
    end
    return false
end

function checkIsMedicinePropertyExtreme(pos_x, pos_y, propMax)
    if pos_x * pos_x + pos_y * pos_y > propMax * propMax then
        return true
    end
    return false
end

function checkIsInMedicineCircle(pos_x, pos_y, medicineInfo)
    local medicine_x = medicineInfo.Position[1]
    local medicine_y = medicineInfo.Position[2]
    local radius = medicineInfo.Radius
    if (pos_x - medicine_x) * (pos_x - medicine_x) + (pos_y - medicine_y) * (pos_y - medicine_y) < radius * radius then
        return true
    end
    return false
end

function isPrescriptionSame(prescriptionA, prescriptionB)
    local prescriptionDictA = transformListToDict(prescriptionA)
    local prescriptionDictB = transformListToDict(prescriptionB)
    if lume.count(prescriptionDictA) ~= lume.count(prescriptionDictB) then
        return false
    end
    for id, _ in pairs(prescriptionDictA) do
        if prescriptionDictA[id] ~= prescriptionDictB[id] then
            return false
        end
    end
    return true
end

function checkIsInInvalidation(pos_x, pos_y, radius)
    if pos_x * pos_x + pos_y * pos_y < radius * radius then
        return true
    end
    return false
end

function transformListToDict(list)
    local ret = {}
    for _, id in pairs(list) do
        ret[id] = ret[id] and ret[id] + 1 or 1
    end
    return ret
end


---@public
function CheckMakeMedicine(startPoint, allEndPoints, medPointList, mysteryPoint, herbIdList, xWidth, yWidth)
    local curX = startPoint[1]
    local curY = startPoint[2]
    local preX
    local preY
    local reachHerbCount = 0
    local reachMystery = false
    local reachEnd = false
    local herbId2Info = {}
    local pathMedPointDict = {}
    local ret = Enum.EErrCodeData.NO_ERR
    for idx, herbId in pairs(herbIdList) do
        if not herbId2Info[herbId] then
            local herbInfo = TableData.GetMakeMedicineHerbNewDataRow(herbId)
            if not herbInfo then
                ret = Enum.EErrCodeData.PARAM_ERR
                LOG_ERROR_FMT("checkMakeMedicine: herbId[%s] is not valid!", herbId)
                break
            end
            herbId2Info[herbId] = herbInfo
        end
        local info = herbId2Info[herbId]
        local medProperty = info.MedicineProperty
        for _, direct in pairs(medProperty) do
            preX = curX
            preY = curY
            curX = curX + direct[1]
            curY = curY + direct[2]
            if not checkPointValid(curX, curY, xWidth, yWidth) then
                ret = Enum.EErrCodeData.PARAM_ERR
                LOG_ERROR_FMT("checkMakeMedicine: the [%]st herb[%s] is out of bound! Total:[%v]", idx, herbId, herbIdList)
                break 
            end
            if medPointList and next(medPointList) then
                if not checkPassMedPoint(preX, preY, curX, curY, medPointList, pathMedPointDict) then
                    ret = Enum.EErrCodeData.PARAM_ERR
                    break
                end
            end
            if not reachMystery and mysteryPoint and next(mysteryPoint) then
                reachMystery = checkPassMysteryPoint(preX, preY, curX, curY, mysteryPoint)
                if reachMystery == nil then
                    ret = Enum.EErrCodeData.PARAM_ERR
                    break
                end
            end
        end
    end
    reachHerbCount = lume.count(pathMedPointDict)
    reachEnd = checkReachEndPoint(curX, curY, allEndPoints)
    return ret, reachEnd, reachMystery, reachHerbCount
end

function checkPassMedPoint(preX, preY, curX, curY, medPointList, pathHerbPointDict)
    for index, point in pairs(medPointList) do
        local pX = point[1]
        local pY = point[2]
        local smallV
        local bigV
        if preX == curX then
            if preY <= curY then
                smallV = preY
                bigV = curY
            else
                smallV = curY
                bigV = preY
            end
            if pX == preX and (pY >= smallV and pY <= bigV) then
                pathHerbPointDict[index] = true
            end
        elseif preY == curY then
            if preX <= curX then
                smallV = preX
                bigV = curX
            else
                smallV = curX
                bigV = preX
            end
            if pY == preY and (pX >= smallV and pX <= bigV) then
                pathHerbPointDict[index] = true
            end
        else
            LOG_ERROR_FMT("change x and y at same time, pre_x[%s], pre_y[%s], cur_x[%s], cur_y[%s]",
                preX, preY, curX, curY)
            return false
        end
    end
    return true
end

function checkPassMysteryPoint(preX, preY, curX, curY, mysteryPoint)
    if not mysteryPoint then
        return false
    end
    if not next(mysteryPoint) then
        return false
    end
    local pX = mysteryPoint[1]
    local pY = mysteryPoint[2]
    local smallV
    local bigV
    if preX == curX then
        if preY <= curY then
            smallV = preY
            bigV = curY
        else
            smallV = curY
            bigV = preY
        end
        if pX == preX and (pY >= smallV and pY <= bigV) then
            return true
        end
    elseif preY == curY then
        if preX <= curX then
            smallV = preX
            bigV = curX
        else
            smallV = curX
            bigV = preX
        end
        if pY == preY and (pX >= smallV and pX <= bigV) then
            return true
        end
    else
        LOG_ERROR_FMT("change x and y at same time, pre_x[%s], pre_y[%s], cur_x[%s], cur_y[%s]",
            preX, preY, curX, curY)
        return nil
    end
    return false
end

function checkReachEndPoint(curX, curY, allEndPoints)
    for _, points in pairs(allEndPoints) do
        if curX == points[1] and curY == points[2] then
            return true
        end
    end
    return false
end

function checkPointValid(curX, curY, xWidth, yWidth)
    if curX <= 0 or curX >= xWidth - 1 or curY <= 0 or curY >= yWidth -1 then
        return false
    end
    return true
end