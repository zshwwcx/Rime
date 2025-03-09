local sharedUtils = kg_require("Shared.Utils")

local TableData = TableData
local pairs = pairs
local ipairs = ipairs
local next = next
local unpack = unpack

if _G.IsClient then
    TableData = Game.TableData
    pairs = ksbcpairs
    ipairs = ksbcipairs
    next = ksbcnext
    unpack = ksbcunpack
end

local math_random = math.random
local math_cos = math.cos
local math_sin = math.sin
local math_sqrt = math.sqrt


--region 生成随机点的算法
local MathConstants = {
    PI = 3.1415926535897932,
}
local PI = MathConstants.PI

---@class TVector3
---@field X number
---@field Y number
---@field Z number

--- 获取目标点整数范围内的随机坐标点(正方形)
function GetRandPositionInRange(pos, range)
    local x = pos[1] + math_random(-range, range)
    local y = pos[2] + math_random(-range, range)
    return { x, y, pos[3] }
end

--- 获取原点的圆形内的随机坐标点
---@param pos table 原点坐标
---@param radius number 半径
---@return table 一个落在圆形内的随机坐标点
function GetRandPositionInCircle(pos, radius)
    local randomTheta = 2 * PI * math_random()
    local randomRadius = radius * math_sqrt(math_random())
    local x = pos[1] + math_cos(randomTheta) * randomRadius
    local y = pos[2]
    local z = pos[3] + math_sin(randomTheta) * randomRadius
    return { x, y, z }
end

--- 获取原点的扇形内的随机坐标点
---@param pos table 坐标原点坐标
---@param directionRadians number 原点朝向(弧度)
---@param radius number 半径
---@param centralAngleRadians number 以x轴的圆心角(弧度), [-centralAngleRadians, centralAngleRadians)
---@return table 一个落在扇形内的随机坐标点
function GetRandPositionInSector(pos, directionRadians, radius, centralAngleRadians)
    local randomTheta = centralAngleRadians * math_random() - centralAngleRadians / 2 + directionRadians
    local randomRadius = radius * math_sqrt(math_random())
    local x = pos[1] + math_cos(randomTheta) * randomRadius
    local y = pos[2]
    local z = pos[3] + math_sin(randomTheta) * randomRadius
    return { x, y, z }
end

--- 获取原点的扇环内的随机坐标点
---@param PosNumber number 返回坐标数量
---@param MinRadius number  内圈半径
---@param MaxRadius number  外圈半径
---@param CentralAngleRadians number 圆心角(弧度)
---@param OriginPos TVector3 const 保证不改变内部值
---@param DirectionRadians number 朝向（弧度）
---@return TVector3[]
--- 扇环范围 [innerRadius, Radius) x [-centralAngleRadians, centralAngleRadians)
function GenRandPositionInAnnularSector(PosNumber, MinRadius, MaxRadius, CentralAngleRadians, OriginPos, DirectionRadians)
    local posResult = {}
    local radiusSquare = MaxRadius * MaxRadius
    local innerRadiusSquare = MinRadius * MinRadius
    local origionPosX, origionPosY, origionPosZ = OriginPos.X, OriginPos.Y, OriginPos.Z

    for i = 1, PosNumber do
        local randomRadius = math_sqrt(innerRadiusSquare + math_random() * (radiusSquare - innerRadiusSquare))
        local randomTheta = CentralAngleRadians * math_random() - CentralAngleRadians / 2 + DirectionRadians
        local resPos = {
            X = origionPosX + math_cos(randomTheta) * randomRadius,
            Y = origionPosY + math_sin(randomTheta) * randomRadius,
            Z = origionPosZ
        }
        posResult[i] = resPos
    end

    return posResult
end

RandPositionInAnnularSectorGenerator = {
    radiusSquare = 0,
    innerRadiusSquare = 0,
    origionPosX = 0,
    origionPosY = 0,
    origionPosZ = 0,
}
function RandPositionInAnnularSectorGenerator:Init(MinRadius, MaxRadius,
                                                   CentralAngleRadians, OriginPos,
                                                   DirectionRadians)
    self.radiusSquare = MaxRadius * MaxRadius
    self.innerRadiusSquare = MinRadius * MinRadius
    self.centralAngleRadians = CentralAngleRadians
    self.directionRadians = DirectionRadians
    self.origionPosX, self.origionPosY, self.origionPosZ = OriginPos.X, OriginPos.Y, OriginPos.Z
end

function RandPositionInAnnularSectorGenerator:GenRandPoint()
    local randomRadius = math_sqrt(self.innerRadiusSquare + math_random() * (self.radiusSquare - self.innerRadiusSquare))
    local randomTheta = self.centralAngleRadians * math_random() - self.centralAngleRadians / 2 + self.directionRadians

    return self.origionPosX + math_cos(randomTheta) * randomRadius,
        self.origionPosY + math_sin(randomTheta) * randomRadius,
        self.origionPosZ
end

--- 获取原点的扇环内按照角度均匀划分后随机坐标点
---@param PosNumber number 返回坐标数量
---@param MinRadius number  内圈半径
---@param MaxRadius number  外圈半径
---@param CentralAngleRadians number 圆心角(弧度)
---@param OriginPos TVector3 const 保证不改变内部值
---@param DirectionRadians number 朝向（弧度）
---@param AngleOffset number? 角度偏移. 若不为空, 角度不随机, 且正值左偏；负值右偏
---@return TVector3[]
function GenUniformRandPosInAnnulusSector(PosNumber, MinRadius, MaxRadius, CentralAngleRadians, OriginPos,
                                          DirectionRadians, AngleOffset)
    local posResult                             = {}
    local angleUnit                             = CentralAngleRadians / PosNumber
    local randomRotateAngle                     = AngleOffset and (angleUnit / 2 + AngleOffset) or
        (math_random() * angleUnit)
    local preAngle                              = 0
    local minRadiusSquare                       = MinRadius * MinRadius
    local maxRadiusSquare                       = MaxRadius * MaxRadius
    local offsetAngle                           = DirectionRadians - CentralAngleRadians / 2
    local origionPosX, origionPosY, origionPosZ = OriginPos.X, OriginPos.Y, OriginPos.Z

    for i = 1, PosNumber do
        local randomRadius = math_random() * (maxRadiusSquare - minRadiusSquare) + minRadiusSquare
        randomRadius = math_sqrt(randomRadius)
        local randomAngle = randomRotateAngle + preAngle
        local cartePos = {
            X = origionPosX + math_cos(randomAngle + offsetAngle) * randomRadius,
            Y = origionPosY + math_sin(randomAngle + offsetAngle) * randomRadius,
            Z = origionPosZ
        }
        posResult[i] = cartePos

        preAngle = preAngle + angleUnit
    end

    posResult = sharedUtils.ShuffleList(posResult)
    return posResult
end

UniformRandPosInAnnulusSectorGenerator = {
    angleUnit = 0,
    randomRotateAngle = 0,
    preAngle = 0,
    minRadiusSquare = 0,
    maxRadiusSquare = 0,
    offsetAngle = 0,
    origionPosX = 0,
    origionPosY = 0,
    origionPosZ = 0,
    preAngleList = {}
}

function UniformRandPosInAnnulusSectorGenerator:Init(PosNumber, MinRadius, MaxRadius, CentralAngleRadians, OriginPos,
                                                     DirectionRadians, AngleOffset)
    self.angleUnit                                       = CentralAngleRadians / PosNumber
    self.randomRotateAngle                               = AngleOffset and (self.angleUnit / 2 + AngleOffset) or
        (math_random() * self.angleUnit)
    self.minRadiusSquare                                 = MinRadius * MinRadius
    self.maxRadiusSquare                                 = MaxRadius * MaxRadius
    self.offsetAngle                                     = DirectionRadians - CentralAngleRadians / 2
    self.origionPosX, self.origionPosY, self.origionPosZ = OriginPos.X, OriginPos.Y, OriginPos.Z
    -- self.preAngle                                        = 0
    table.clear(self.preAngleList)
    self.preAngleList[1] = 0
    for i = 2, PosNumber do
        self.preAngleList[i] = self.preAngleList[i - 1] + self.angleUnit
    end
    sharedUtils.ShuffleList(self.preAngleList)
end

function UniformRandPosInAnnulusSectorGenerator:GenRandPoint()
    local randomRadius = math_random() * (self.maxRadiusSquare - self.minRadiusSquare) + self.minRadiusSquare
    randomRadius = math_sqrt(randomRadius)

    local prevAngle = table.remove(self.preAngleList)
    local randomAngle = self.randomRotateAngle + (prevAngle or 0)

    return self.origionPosX + math_cos(randomAngle + self.offsetAngle) * randomRadius,
        self.origionPosY + math_sin(randomAngle + self.offsetAngle) * randomRadius,
        self.origionPosZ
end

PoissonDiskSampling = {}
PoissonDiskSampling.DefaultAttemps = 30 -- 推荐尝试次数

--- 参考泊松采样算法适配位置筛选, 并非严格泊松采样
---@param posNumber number 返回坐标数量
---@param minRadius number  内圈半径
---@param maxRadius number  外圈半径
---@param centralAngleRadians number 圆心角(弧度)
---@param originPos TVector3 const 保证不改变内部值
---@param directionRadians number 朝向（弧度）
---@param minDistance number 限制的最小距离
---@param inGrid table 已经增加的点集合
---@param attempts number? 拒绝采样尝试次数
---@return TVector3[], table @随机点数组, 随机点索引数组
function PoissonDiskSampling.GenRandPosInAnnulusSectorBasedPoissonDisk(posNumber, minRadius, maxRadius,
                                                                       centralAngleRadians, originPos, directionRadians,
                                                                       minDistance, inGrid, attempts)
    local attempts = attempts or PoissonDiskSampling.DefaultAttemps
    local cellSize = minDistance / math_sqrt(2)

    local posResult = {}
    local grid = inGrid or {}
    local radiusSquare = maxRadius * maxRadius
    local innerRadiusSquare = minRadius * minRadius
    local minDistanceSquare = minDistance * minDistance

    local origionPosX, origionPosY, origionPosZ = originPos.X, originPos.Y, originPos.Z
    for i = 1, posNumber do
        for j = 1, attempts do
            local randomRadius = math_sqrt(innerRadiusSquare + math_random() * (radiusSquare - innerRadiusSquare))
            local randomTheta = centralAngleRadians * math_random() - centralAngleRadians / 2 + directionRadians

            local resPosX = origionPosX + math_cos(randomTheta) * randomRadius
            local resPosY = origionPosY + math_sin(randomTheta) * randomRadius

            local success = PoissonDiskSampling.isValidPoint(grid, cellSize, resPosX, resPosY, minDistanceSquare)
            if success then
                local resPos = {
                    X = resPosX,
                    Y = resPosY,
                    Z = origionPosZ
                }
                posResult[i] = resPos
                PoissonDiskSampling.insertPoint(grid, cellSize, resPos)
                break
            end

            if j == attempts then
                return posResult, grid
            end
        end
    end

    return posResult, grid
end

function PoissonDiskSampling.insertPoint(grid, cellSize, point)
    local x = math.floor(point.X / cellSize)
    local y = math.floor(point.Y / cellSize)
    -- TODO: 使用 table 池减少 GC
    if not grid[x] then grid[x] = {} end
    grid[x][y] = point
end

function PoissonDiskSampling.isValidPoint(grid, cellSize, pointX, pointY, squareRadius)
    local cellX = math.floor(pointX / cellSize)
    local cellY = math.floor(pointY / cellSize)
    for x = cellX - 2, cellX + 2 do
        if not grid[x] then goto continue end
        for y = cellY - 2, cellY + 2 do
            local point = grid[x][y]
            if point then
                local diffX = point.X - pointX
                local diffY = point.Y - pointY
                if diffX * diffX + diffY * diffY < squareRadius then
                    return false
                end
            end
        end
        ::continue::
    end
    return true
end

PoissonDiskSampling.RandPosInAnnulusSectorGenerator = {
    attempts = 0,
    cellSize = 0,
    posResult = {},
    grid = {},
    radiusSquare = 0,
    innerRadiusSquare = 0,
    radiusSquare = 0,
    minDistanceSquare = 0,
    origionPosX = 0,
    origionPosY = 0,
    origionPosZ = 0,
    centralAngleRadians = 0,
    directionRadians = 0,
}

function PoissonDiskSampling.RandPosInAnnulusSectorGenerator:Init(minRadius, maxRadius,
                                                                  centralAngleRadians, originPos, directionRadians,
                                                                  minDistance, inGrid, attempts)
    self.attempts = attempts or PoissonDiskSampling.DefaultAttemps
    self.cellSize = minDistance / math_sqrt(2)

    table.clear(self.posResult)
    self.grid = inGrid or {}
    self.radiusSquare = maxRadius * maxRadius
    self.innerRadiusSquare = minRadius * minRadius
    self.minDistanceSquare = minDistance * minDistance

    self.origionPosX, self.origionPosY, self.origionPosZ = originPos.X, originPos.Y, originPos.Z
    self.centralAngleRadians = centralAngleRadians
    self.directionRadians = directionRadians
end

function PoissonDiskSampling.RandPosInAnnulusSectorGenerator:GenRandPoint()
    for j = 1, self.attempts do
        local randomRadius = math_sqrt(self.innerRadiusSquare +
            math_random() * (self.radiusSquare - self.innerRadiusSquare))
        local randomTheta = self.centralAngleRadians * math_random() - self.centralAngleRadians / 2 +
            self.directionRadians

        local resPosX = self.origionPosX + math_cos(randomTheta) * randomRadius
        local resPosY = self.origionPosY + math_sin(randomTheta) * randomRadius

        local success = PoissonDiskSampling.isValidPoint(self.grid, self.cellSize, resPosX, resPosY,
            self.minDistanceSquare)
        if success then
            -- TODO: table池, Shared目录下暂无 table 池实现, 后续增加
            local resPos = {
                X = resPosX,
                Y = resPosY,
                Z = self.origionPosZ
            }
            PoissonDiskSampling.insertPoint(self.grid, self.cellSize, resPos)
            return resPosX, resPosY, self.origionPosZ
        end

        if j == self.attempts then
            return nil, nil, nil
        end
    end
end

--endregion
