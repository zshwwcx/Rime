GlobalUnlock(_G)
require("Shared.WorldActorDefine")
require("Shared.Const")
GlobalLock(_G)

local bit = Game and Game.bit or require("bit")

PublicSceneActorBigWorldEntity = true
PublicSceneActorPlaneEntity = true
SceneActorLazyLoad = false

local pairs = pairs
local ipairs = ipairs
local next = next
local unpack = unpack
local table_insert = table.insert
local table_clear = table.clear
local math_floor = math.floor

if _G.IsClient then
    pairs = ksbcpairs
    ipairs = ksbcipairs
    next = ksbcnext
    unpack = ksbcunpack
end

ActionRuntimeFlag = {
    SERVER = 0,
    CLIENT = 1,
    BOTH_SIDE = 2
}

EInteractorInnerEvent = {
    ON_BORN = "ON_BORN",
    ON_INTERACT_START = "ON_INTERACT_START",
    ON_INTERACT_SUCCESS = "ON_INTERACT_SUCCESS",
    ON_INTERACT_FAILED = "ON_INTERACT_FAILED",
    ON_CUSTOMIZE_MSG_ = "ON_CUSTOMIZE_MSG_",
    ON_STATE_SWITCH_ = "ON_STATE_SWITCH_",
    ON_INTERACTIVE_MAIN_CHAR_MOVING_IN_RANGE = "ON_INTERACTIVE_MAIN_CHAR_MOVING_IN_RANGE"
}

EventSourceType = {
    BUTTON = 1,
    STEP_ON = 2,
    ELEM_ATTACH = 3,
    ELEM_LOSE = 4,
    ATTACK = 5,
    ENTER_TRAP = 6,
}

SceneActorFixedStateEnum = {
    SA_INACTIVE = 0,
    SA_ACTIVE = 1,
    SA_FINISH = 2,
    SA_CLOSED = 3,
}

SceneActorFixedStateData = {
    [0] = "SA_INACTIVE",
    [1] = "SA_ACTIVE",
    [2] = "SA_FINISH",
    [3] = "SA_CLOSED",
}

SceneActorForceBelongType = {
    [EWActorType.INTERACTIVE_CHAIR] = Enum.EInteractorBelongType.ALL_CLIENT,
    [EWActorType.INTERACTIVE_SWING] = Enum.EInteractorBelongType.ALL_CLIENT,
    [EWActorType.TREASURE_BOX_UNLOCK] = Enum.EInteractorBelongType.OWN_CLIENT,
    [EWActorType.TREASURE_BOX_LOCK] = Enum.EInteractorBelongType.OWN_CLIENT,
	[EWActorType.SIMULATE_PHYSICAL_MESH] = Enum.EInteractorBelongType.OWN_CLIENT
}

SceneActorGenRewardWhiteList = {
    [EWActorType.TREASURE_BOX_UNLOCK] = true,
    [EWActorType.TREASURE_BOX_LOCK] = true,
    [EWActorType.CONSECRATION_SPIRIT] = true,
    [EWActorType.CAGE_MONKEY] = true,
    [EWActorType.PUT_BREAD] = true,
    [EWActorType.SPIRIT_ANIMAL] = true,
    [EWActorType.ICE_FIELD_NPC] = true,
    [EWActorType.MONSTER_CHASE] = true,
    [EWActorType.POSTER_TREASURE] = true,
    [EWActorType.STAR_GRAPH_TREASURE] = true,
    [EWActorType.TREASURE_BOX_EYE] = true,
    [EWActorType.TREASURE_BOX_ELEM] = true,
    [EWActorType.FIREWORK] = true,
}

SceneActorExploreWhiteList = {
    [EWActorType.CONSECRATION_MONUMENT] = true,
}

SceneActorChangeStateWhiteList = {
    [EWActorType.FATE_CONTRACT] = true,
    [EWActorType.PLANT_SIHOUETTE] = true,
    [EWActorType.SOUND_TRACE] = true,
	[EWActorType.ESTATE_PAINT] = true,
	[EWActorType.BOOK_CORRIDOR] = true,
}

SceneActorChangeSubStateWhiteList = {
    [EWActorType.FURNACE] = true,
    [EWActorType.PLANT_SIHOUETTE] = true,
	[EWActorType.ESTATE_PAINT] = true,
	[EWActorType.PUZZLE_RITUAL] = true,
}

SceneActorGenRewardType = {
    GEN_DROP = 0,
    GEN_TREASURE_BOX = 1,
}

SceneActorTemplateRecord = {
    [EWActorType.COLLECTION] = true,
}

SceneActorPersistType = {
    [EWActorType.COLLECTION] = true,
    [EWActorType.CONSECRATION_MONUMENT] = true,
}

EConsecrationStateEnum = {
    TaskRequired = 0,
    Locked = 1,
    UnLocked = 2
}

GetSceneActorRowBehaviorIDFunc = {
    [EWActorType.INTERACTIVE_DOOR] = function(TemplateID, TableData)
        local ContinuousInteractiveDoorData = TableData.GetContinuousInteractiveDoorDataRow(TemplateID)
        return ContinuousInteractiveDoorData and ContinuousInteractiveDoorData.DoorBehavior
    end,
    [EWActorType.TREASURE_BOX_UNLOCK] = function(TemplateID, TableData)
        local SceneActorTreasureBoxData = TableData.GetSceneActorTreasureBoxDataRow(TemplateID)
        return SceneActorTreasureBoxData and SceneActorTreasureBoxData.Behavior
    end,
    [EWActorType.TREASURE_BOX_LOCK] = function(TemplateID, TableData)
        local SceneActorTreasureBoxData = TableData.GetSceneActorTreasureBoxDataRow(TemplateID)
        return SceneActorTreasureBoxData and SceneActorTreasureBoxData.Behavior
    end,
    [EWActorType.TREASURE_BOX_EYE] = function(TemplateID, TableData)
        local SceneActorTreasureBoxData = TableData.GetSceneActorTreasureBoxDataRow(TemplateID)
        return SceneActorTreasureBoxData and SceneActorTreasureBoxData.Behavior
    end,
    [EWActorType.TREASURE_BOX_ELEM] = function(TemplateID, TableData)
        local SceneActorTreasureBoxData = TableData.GetSceneActorTreasureBoxDataRow(TemplateID)
        return SceneActorTreasureBoxData and SceneActorTreasureBoxData.Behavior
    end,
    [EWActorType.FOG_TRIGGER] = function(TemplateID, TableData)
        local FogTriggerData = TableData.GetFogTriggerDataRow(TemplateID)
        return FogTriggerData and FogTriggerData.Behavior
    end,
    [EWActorType.FATE_CONTRACT] = function(templateID, tableData)
        local fateContractEntryData = tableData.GetFateContractEntryDataRow(templateID)
        return fateContractEntryData and fateContractEntryData.Behavior
    end,
    [EWActorType.BASE_ELEM_TRIGGER] = function(templateID, tableData)
        local elementTriggerData = tableData.GetSceneActorElementTriggerDataRow(templateID)
        return elementTriggerData and elementTriggerData.Behavior
    end,
    [EWActorType.FOUNTAIN] = function(templateID, tableData)
        local SceneActorFountainData = tableData.GetSceneActorFountainDataRow(templateID)
        return SceneActorFountainData and SceneActorFountainData.Behavior
    end,
}

SceneActorTypeToDefaultBehaviorID = {
    [EWActorType.INTERACTIVE_DOOR] = Enum.ESceneActorBehaviorType.Block,
    [EWActorType.COLLECTION] = Enum.ESceneActorBehaviorType.InteractiveCollection,
    [EWActorType.INTERACTIVE_STREETLIGHT] = Enum.ESceneActorBehaviorType.InteractiveStreetlight,
    [EWActorType.PLANE_PORTAL] = Enum.ESceneActorBehaviorType.PlanePortal,
    [EWActorType.INTERACTIVE_PORTAL] = Enum.ESceneActorBehaviorType.WorldPortal,
    [EWActorType.BUFF_TRIGGER] = Enum.ESceneActorBehaviorType.BuffTriggerClick,
    [EWActorType.TREASURE_BOX_ELEM] = Enum.ESceneActorBehaviorType.DropSpider,
    [EWActorType.FIREWORK] = Enum.ESceneActorBehaviorType.Firework,
    [EWActorType.POWDER_KEG] = Enum.ESceneActorBehaviorType.PowderKeg,
    [EWActorType.FURNACE] = Enum.ESceneActorBehaviorType.Furnace,
    [EWActorType.GUILD_BLESS] = Enum.ESceneActorBehaviorType.GuilBless,
    [EWActorType.DROP_ITEM] = Enum.ESceneActorBehaviorType.DropItem,
    [EWActorType.ESTATE_PORTAL] = Enum.ESceneActorBehaviorType.EstatePortal,
	[EWActorType.BROKEN_STEPS] = Enum.ESceneActorBehaviorType.BrokenSteps,
	[EWActorType.CORRUPT_TREE] = Enum.ESceneActorBehaviorType.CorruptTree,
	[EWActorType.BOOK_CORRIDOR] = Enum.ESceneActorBehaviorType.BookCorridor,
}

function GetSceneActorBehaviorID(TemplateData)
    if not TemplateData then
        return nil
    end
    if TemplateData.SceneActorBehavior then
        return TemplateData.SceneActorBehavior
    end
    local TableData = Game.TableData or TableData
    local func = GetSceneActorRowBehaviorIDFunc[TemplateData.ActorType]
    if func then
        local ret = func(TemplateData.TemplateID, TableData)
        if ret then
            return ret
        end
    end

    return SceneActorTypeToDefaultBehaviorID[TemplateData.ActorType] or
        Enum.ESceneActorBehaviorType.EmptyBehaviorTemplate
end

GetSceneActorRowInitialSubStateFunc = {
    [EWActorType.INTERACTIVE_DOOR] = function(TemplateData, TableData)
        local TemplateID = TemplateData.TemplateID
        local ContinuousInteractiveDoorData = TableData.GetContinuousInteractiveDoorDataRow(TemplateID)
        return ContinuousInteractiveDoorData and ContinuousInteractiveDoorData.InitialSubState
    end,
    [EWActorType.COLLECTION] = function(TemplateData, TableData)
        local TemplateID = TemplateData.TemplateID
        local SceneActorTaskCollectData = TableData.GetSceneActorTaskCollectDataRow(TemplateID)
        return SceneActorTaskCollectData and SceneActorTaskCollectData.InteractMaxTimes
    end,
    [EWActorType.INTERACTIVE_STREETLIGHT] = function(TemplateData, TableData)
        local TemplateID = TemplateData.TemplateID
        local InteractiveStreetLightData = TableData.GetInteractiveStreetLightDataRow(TemplateID)
        return InteractiveStreetLightData and InteractiveStreetLightData.InitialSubState
    end,
    [EWActorType.FURNACE] = function(TemplateData, TableData)
        return 1
    end,
    [EWActorType.CONSECRATION_MONUMENT] = function(TemplateData, TableData)
        local SteleID = TemplateData.MapRegionID
        local ExploreSteleData = TableData.GetExploreSteleDataRow(SteleID)
        if not ExploreSteleData then
            return
        end
        if ExploreSteleData.TaskRingID ~= 0 then
            return EConsecrationStateEnum.TaskRequired
        else
            return EConsecrationStateEnum.Locked
        end
    end,
	[EWActorType.ESTATE_PAINT] = function(TemplateData, TableData)
		return 0
	end,
	[EWActorType.RAVINGSFLOWER] = function(TemplateData, TableData)
		return RAVING_FLOWER_SUBSTATE.None
	end,
	[EWActorType.PUZZLE_RITUAL] = function(TemplateData, TableData)
		return PUZZLE_RITUAL_SUBSTATE.InActive
	end,
}

function GetSceneActorInitialSubState(TemplateData, PlaneID)
    if not TemplateData then
        return nil
    end
    if PlaneID then
        local PlaneData = Game.TableData.GetPlaneDataRow(PlaneID)
        if PlaneData then
            local InitialSubState = PlaneData.SceneActorSubState[TemplateData.InsID]
            if InitialSubState then
                return InitialSubState
            end
        end
    end
    if TemplateData.SceneActorSubState then
        return TemplateData.SceneActorSubState
    end
    local TableData = Game.TableData or TableData
    local func = GetSceneActorRowInitialSubStateFunc[TemplateData.ActorType]
    if func then
        local ret = func(TemplateData, TableData)
        if ret then
            return ret
        end
    end
end

GetSceneActorRowInitialStateFunc = {
    [EWActorType.INTERACTIVE_DOOR] = function(TemplateID, TableData)
        local ContinuousInteractiveDoorData = TableData.GetContinuousInteractiveDoorDataRow(TemplateID)
        return ContinuousInteractiveDoorData and ContinuousInteractiveDoorData.InitialState
    end,
}

function GetSceneActorInitialState(TemplateData, PlaneID)
    if not TemplateData then
        return nil
    end

    local TableData = Game.TableData or TableData

    if PlaneID then
        local PlaneData = TableData.GetPlaneDataRow(PlaneID)
        if PlaneData then
            for _, idx in pairs(PlaneData.DisableSceneActor) do
                if SceneActorTypeEnum[idx] == TemplateData.ActorType then
                    return SceneActorFixedStateEnum.SA_INACTIVE
                end
            end
        end
    end

    if TemplateData.InitialState then
        return TemplateData.InitialState
    end

    local func = GetSceneActorRowInitialStateFunc[TemplateData.ActorType]
    if func then
        local ret = func(TemplateData.TemplateID, TableData)
        if ret then
            return ret
        end
    end

    local SceneActorBehaviorID = GetSceneActorBehaviorID(TemplateData)
    if SceneActorBehaviorID then
        local sceneActorBehaviorData = TableData.GetSceneActorBehaviorDataRow(SceneActorBehaviorID)
        if sceneActorBehaviorData then
            return sceneActorBehaviorData.IinitialState
        end
    end

    return SceneActorFixedStateEnum.SA_ACTIVE
end

GetSceneActorRowTemplateBelongTypeFunc = {
    [EWActorType.INTERACTIVE_DOOR] = function(TemplateID, TableData)
        local ContinuousInteractiveDoorData = TableData.GetContinuousInteractiveDoorDataRow(TemplateID)
        return ContinuousInteractiveDoorData and ContinuousInteractiveDoorData.BelongType
    end,
}

function GetSceneActorTemplateBelongType(TemplateData)
    if not TemplateData then
        return nil
    end

    local TableData = Game.TableData or TableData

    local func = GetSceneActorRowTemplateBelongTypeFunc[TemplateData.ActorType]
    if func then
        local ret = func(TemplateData.TemplateID, TableData)
        if ret then
            return ret
        end
    end
end

GetSceneActorRowInteractPeriodFunc = {
    [EWActorType.COLLECTION] = function(TemplateID, TableData)
        local SceneActorTaskCollectData = TableData.GetSceneActorTaskCollectDataRow(TemplateID)
        return SceneActorTaskCollectData and SceneActorTaskCollectData.InteractPeriod
    end,
    [EWActorType.INTERACTIVE_STREETLIGHT] = function(TemplateID, TableData)
        local InteractiveStreetLightData = TableData.GetInteractiveStreetLightDataRow(TemplateID)
        return InteractiveStreetLightData and InteractiveStreetLightData.InteractPeriod
    end,
}

function GetSceneActorInteractPeriod(TemplateData)
    if not TemplateData then
        return nil
    end
    local TableData = Game.TableData or TableData
    local func = GetSceneActorRowInteractPeriodFunc[TemplateData.ActorType]
    if func then
        local ret = func(TemplateData.TemplateID, TableData)
        if ret then
            return ret
        end
    end
end

GetSceneActorRowInteractCDFunc = {
    [EWActorType.COLLECTION] = function(TemplateID, TableData)
        local SceneActorTaskCollectData = TableData.GetSceneActorTaskCollectDataRow(TemplateID)
        return SceneActorTaskCollectData and SceneActorTaskCollectData.InteractCD
    end,
}

function GetSceneActorInteractCD(TemplateData)
    if not TemplateData then
        return nil
    end
    local TableData = Game.TableData or TableData
    local func = GetSceneActorRowInteractCDFunc[TemplateData.ActorType]
    if func then
        local ret = func(TemplateData.TemplateID, TableData)
        if ret then
            return ret
        end
    end
end

SceneActorEntityType = {
    [EWActorType.BATTLE_ZONE] = "BattleZoneV2",
    [EWActorType.SPIRITUALITY_WALL] = "BattleZoneV2",
    [EWActorType.PREPARE_ZONE] = "PrepareZone",
    [EWActorType.MOVABLE_PLATFORM] = "MobilePlatform",
    [EWActorType.MAGIC_WALL] = "MagicWall",
}

ClientLocalSceneActorType = {
    [EWActorType.MOVABLE_PLATFORM_WAY_PATH] = true,
	[EWActorType.TASK_PLANE_PORTAL] = true
}

function CheckSceneActorDefaultSpawn(TemplateData, PersistentPIAInfo)
    local GroupID = TemplateData.GroupID
    if GroupID and GroupID ~= "" then
        return false
    end
    local ActorType = TemplateData.ActorType
    if not ActorType or ActorType <= EWActorType.SCENEACTOR_MIN or ActorType >= EWActorType.SCENEACTOR_MAX then
        return false
    end

	if TemplateData.SceneActorCommon and TemplateData.SceneActorCommon.LoadDiceCheck and TemplateData.SceneActorCommon.LoadDiceCheck > 0 then
		return false
	end
	
    local InsType = TemplateData.SceneActorCommon and TemplateData.SceneActorCommon.InsType.EnumValue
	if not InsType then
		if TemplateData.LoadFromMap then
			InsType = Enum.InteractorInsType.CONST
		end
	end
    if not InsType or InsType ~= Enum.InteractorInsType.CONST then
        return false
    end
    local BelongType = TemplateData.SceneActorCommon and TemplateData.SceneActorCommon.BelongType.EnumValue
	if not BelongType then
		BelongType = SceneActorForceBelongType[ActorType]
		if not BelongType then
			BelongType = GetSceneActorTemplateBelongType(TemplateData)
		end
	end
    if not BelongType or BelongType ~= Enum.EInteractorBelongType.OWN_CLIENT then
        return false
    end
    if PersistentPIAInfo[TemplateData.ID] then
        return false
    end
    return true
end

function GetDiceCheckTriggerRadius(DiceID)
    local TableData = Game.TableData or TableData
    local DiceData = TableData.GetDiceDataRow(DiceID)
    if not DiceData then
        return
    end
    local TriggerRadiusLevel = DiceData.TriggerRadiusLevel
    return Enum.EConstListData.DICE_CHECK_TRIGGER_RADIUS_LEVELS[TriggerRadiusLevel]
end


TO_LIMIT_HUD_BTN_COUNT_ACTOR_TYPES = {
	[EWActorType.INTERACTIVE_CHAIR] = true, --可交互的椅子
	[EWActorType.INTERACTIVE_SWING] = true, --秋千
	[EWActorType.INTERACTIVE_STREETLIGHT] = true, --秋千
	[EWActorType.TREASURE_BOX_UNLOCK] = true, --已解锁宝箱
	[EWActorType.TREASURE_BOX_LOCK] = true, --锁定宝箱
	[EWActorType.TREASURE_BOX_EYE] = true, --锁定宝箱
	[EWActorType.TREASURE_BOX_ELEM] = true, --元素宝箱
}

--region 九宫格
BIT_PER_AXIS = 26
OFFSET = bit.lshift(1, BIT_PER_AXIS - 1)
MAX_AXIS_VALUE = bit.lshift(1, BIT_PER_AXIS) - 1
BIT_PER_AXIS_NUMBER = 2 ^ BIT_PER_AXIS
GRID_LENGTH = 3000  -- 对应x轴的划分刻度
GRID_WIDTH = 3000   -- 对应y轴的划分刻度
GRID_EXTEND = 50    -- 走出格子多远才会收到回调
GRID_SYNC_RANGE = 3 -- 格子的同步范围

GRID_STATE_KEY = -1 -- 对应格子的交互物是否已经默认创建

PROP_POSITION = "position"
PROP_ROT = "rotation"

-- region grid
---@param x number
---@param z number
---@return number
function genGridIndexByPos(x, z)
    x = math_floor(x / GRID_LENGTH)
    x = x + OFFSET
    z = math_floor(z / GRID_WIDTH)
    z = z + OFFSET
    return (x * (BIT_PER_AXIS_NUMBER)) + z
end

function genGridIndexByCoordinate(x, z)
    x = x + OFFSET
    z = z + OFFSET
    return (x * (BIT_PER_AXIS_NUMBER)) + z
end

function getGridCoordinate(gridIndex)
    local z = gridIndex % BIT_PER_AXIS_NUMBER - OFFSET
    local x = math_floor(gridIndex / BIT_PER_AXIS_NUMBER) - OFFSET
    return x, z
end

function getGridCoordinateByPos(pos)
    return math_floor(pos[1] / GRID_LENGTH), math_floor(pos[2] / GRID_WIDTH)
end

-- cur向对于pre可能存在8个方向
--  ---------------------
-- |  NW  |  N   |  NE  |
--  ---------------------
-- |  W   |  C   |  E   |
--  ---------------------
-- |  SW  |  S   |  SE  |
--  ---------------------
GRID_ID_TABLE = {}
function getActiveGridIndex(curGridIndex, preGridIndex)
    local curX, curZ = getGridCoordinate(curGridIndex)
    local preX, preZ = getGridCoordinate(preGridIndex)
    table_clear(GRID_ID_TABLE)

    if curX > preX then -- E
        --  先把E方向的三个格子补齐
        table_insert(GRID_ID_TABLE,
            genGridIndexByCoordinate(curX + 1, curZ + 1))
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX + 1, curZ))
        table_insert(GRID_ID_TABLE,
            genGridIndexByCoordinate(curX + 1, curZ - 1))
        if curZ > preZ then -- NE
            table_insert(GRID_ID_TABLE,
                genGridIndexByCoordinate(curX - 1, curZ + 1))
            table_insert(GRID_ID_TABLE,
                genGridIndexByCoordinate(curX, curZ + 1))
        elseif curZ < preZ then -- SE
            table_insert(GRID_ID_TABLE,
                genGridIndexByCoordinate(curX - 1, curZ - 1))
            table_insert(GRID_ID_TABLE,
                genGridIndexByCoordinate(curX, curZ - 1))
        end
    elseif curX < preX then -- W
        --  先把W方向的三个格子补齐
        table_insert(GRID_ID_TABLE,
            genGridIndexByCoordinate(curX - 1, curZ + 1))
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX - 1, curZ))
        table_insert(GRID_ID_TABLE,
            genGridIndexByCoordinate(curX - 1, curZ - 1))
        if curZ > preZ then -- NW
            table_insert(GRID_ID_TABLE,
                genGridIndexByCoordinate(curX, curZ + 1))
            table_insert(GRID_ID_TABLE,
                genGridIndexByCoordinate(curX + 1, curZ + 1))
        elseif curZ < preZ then -- SW
            table_insert(GRID_ID_TABLE,
                genGridIndexByCoordinate(curX, curZ - 1))
            table_insert(GRID_ID_TABLE,
                genGridIndexByCoordinate(curX + 1, curZ - 1))
        end
    elseif curZ > preZ then -- N
        table_insert(GRID_ID_TABLE,
            genGridIndexByCoordinate(curX - 1, curZ + 1))
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX, curZ + 1))
        table_insert(GRID_ID_TABLE,
            genGridIndexByCoordinate(curX + 1, curZ + 1))
    else -- S
        table_insert(GRID_ID_TABLE,
            genGridIndexByCoordinate(curX - 1, curZ - 1))
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX, curZ - 1))
        table_insert(GRID_ID_TABLE,
            genGridIndexByCoordinate(curX + 1, curZ - 1))
    end
    return GRID_ID_TABLE
end

function getDeActiveGridIndex(curGridIndex, preGridIndex)
    local curX, curZ = getGridCoordinate(curGridIndex)
    local preX, preZ = getGridCoordinate(preGridIndex)
    table_clear(GRID_ID_TABLE)

    if curX > preX then -- E
        --  先把E方向的三个格子补齐
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX - 1, preZ + 1))
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX - 1, preZ))
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX - 1, preZ - 1))
        if curZ > preZ then -- NE
            table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX, preZ - 1))
            table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX + 1, preZ - 1))
        elseif curZ < preZ then -- SE
            table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX, preZ + 1))
            table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX + 1, preZ + 1))
        end
    elseif curX < preX then -- W
        --  先把W方向的三个格子补齐
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX + 1, preZ + 1))
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX + 1, preZ))
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX + 1, preZ - 1))
        if curZ > preZ then -- NW
            table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX, preZ - 1))
            table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX - 1, preZ - 1))
        elseif curZ < preZ then -- SW
            table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX - 1, preZ + 1))
            table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX, preZ + 1))
        end
    elseif curZ > preZ then -- N
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX - 1, preZ - 1))
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX, preZ - 1))
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX + 1, preZ - 1))
    else -- S
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX - 1, preZ + 1))
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX, preZ + 1))
        table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(preX + 1, preZ + 1))
    end
    return GRID_ID_TABLE
end

--- 返回某个位置周边的9个格子
--- @param x any
--- @param z any
--- @return table
function getNearByGridIndex(x, z)
    local curX = math_floor(x / GRID_LENGTH)
    local curZ = math_floor(z / GRID_WIDTH)
    table_clear(GRID_ID_TABLE)

    -- E方向
    table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX + 1, curZ + 1))
    table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX + 1, curZ))
    table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX + 1, curZ - 1))

    -- W方向
    table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX - 1, curZ + 1))
    table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX - 1, curZ))
    table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX - 1, curZ - 1))

    -- N方向
    table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX, curZ + 1))

    -- S方向
    table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX, curZ - 1))

    -- C方向
    table_insert(GRID_ID_TABLE, genGridIndexByCoordinate(curX, curZ))
    return GRID_ID_TABLE
end
--endregion 九宫格
