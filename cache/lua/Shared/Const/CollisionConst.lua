local bit = require("Framework.Utils.bit")
local EPropertyClass = import("EPropertyClass")
local C7FunctionLibrary = import("C7FunctionLibrary")

-- ==============碰撞使用, 规则详见https://docs.corp.kuaishou.com/k/home/VQrrEYoJZoNM/fcAC-_fa3yA1q919YIFz7Uenj========

COLLISION_PRESET_NAMES = {
    NO_COLLISION_COMPONENT_PRESET = 'NoCollisionComponentPreset', --默认无碰撞
    MAIN_PLAYER_PRESET = "MainPlayerPreset", -- 玩家专用
    AOI_PLAYER_PRESET = "AOIPlayerPreset", -- P3玩家使用
    MOVABLE_UNIT_WITH_NET_DRIVE_PRESET = "MovableUnitWithNetDrivePreset", -- 具有RoleMovementComponent的可移动单位, 网络权威模式下的驱动时候使用; 例如 怪物、公有NPC
    MOVABLE_UNIT_WITH_LOCAL_DRIVE_PRESET = "MovableUnitWithLocalDrivePreset", -- 具有RolveMovementComponent的可移动单位, 本地驱动模式使用; 例如  非ISM的本地氛围NPC
    SCENE_ACTOR_PRESET = "SceneActorPreset", -- 静止不动的场景物件, 例如: 采集物、玩法触发物件、可交互椅子、可破碎物等
    INVISIBLE_WALL_DYNAMIC = "InvisibleWallDynamic",
    SCENE_ACTOR_BLOCK_MAIN_PLAYER = "SceneActorBlockMainPlayer",
    SCENE_ACTOR_BLOCK_ALL = "SceneActorBlockAll",
    INTERACTABLE_DETECT_PRESET = "InteractableDetectPreset",
    INTERACTABLE_PRESET = "InteractablePreset",
	PHYSICS_ACTOR_PRESET = "PhysicsActor", -- 开启物理模拟的物体
}

local ECollisionChannel = import("ECollisionChannel")

-- 注意: 这里每次进行channel/object type变动设计的时候, 都需要维护确认一下, 具体映射关系可以看DefaultEngine.ini
-- 外部就只允许使用COLLISION_OBJECT_TYPE_BY_NAME来做引用
COLLISION_OBJECT_TYPE_BY_NAME = {
    -- Engine内置
    WorldStatic = ECollisionChannel.ECC_WorldStatic,
    WorldDynamic = ECollisionChannel.ECC_WorldDynamic,
    Visibility = ECollisionChannel.ECC_Visibility, --  是trace Channel 对应的 "ObjectType", 但是不能在Preset中作为ObjectType被使用
    Camera = ECollisionChannel.ECC_Camera, -- 是trace Channel 对应的 "ObjectType", 但是不能在Preset中作为ObjectType被使用
    Pawn = ECollisionChannel.ECC_Pawn,

    -- User defined
    Interactable = ECollisionChannel.ECC_GameTraceChannel4, -- Interactable
    Water = ECollisionChannel.ECC_GameTraceChannel5,
    ScenePerception = ECollisionChannel.ECC_GameTraceChannel6, --  是trace Channel 对应的 "ObjectType", 但是不能在Preset中作为ObjectType被使用
    FluidTrace = ECollisionChannel.ECC_GameTraceChannel7, --  是trace Channel 对应的 "ObjectType", 但是不能在Preset中作为ObjectType被使用
    MainPlayer = ECollisionChannel.ECC_GameTraceChannel8,
    AOIPlayer = ECollisionChannel.ECC_GameTraceChannel9,
    MovableUnit = ECollisionChannel.ECC_GameTraceChannel10,
    SceneActor = ECollisionChannel.ECC_GameTraceChannel11,
    SceneActorBlockMainPlayer = ECollisionChannel.ECC_GameTraceChannel12, -- 场景物阻挡玩家
    SceneActorBlockAll = ECollisionChannel.ECC_GameTraceChannel13, -- 场景物阻挡玩家和相机
	SceneIndoorField = ECollisionChannel.ECC_GameTraceChannel14, -- 场景物阻挡玩家和相机
}

COLLISION_TRACE_TYPE_BY_NAME = {
    Visibility = C7FunctionLibrary.ConvertToTraceType(COLLISION_OBJECT_TYPE_BY_NAME.Visibility),
    Camera = C7FunctionLibrary.ConvertToTraceType(COLLISION_OBJECT_TYPE_BY_NAME.Camera)
}


-- todo 这里按需进行扩展使用
QUERY_BY_OBJECTTYPES = {
    COMMON_WORLD_STATIC = slua.Array(EPropertyClass.Int), -- 通用的查询静态WorldStatic
    COMMON_PAWN = slua.Array(EPropertyClass.Int),
    COMMON_WORLD_DYNAMIC = slua.Array(EPropertyClass.Int),
    PICK_BY_SCREEN_CLICK = slua.Array(EPropertyClass.Int), -- 点击屏幕进行角色选中,
    INTERACTABLE_FOR_INTERACT_HUD = slua.Array(EPropertyClass.Int), -- 交互hud显示查询 
    INTERACTABLE_FOR_LINE_TRACE = slua.Array(EPropertyClass.Int), -- 是否能交互的连线检测
    SCENE_ACTOR = slua.Array(EPropertyClass.Int), -- 场景物
	ABILITY_DEFAULT = slua.Array(EPropertyClass.Int), -- 技能查询(仅战斗)
	ABILITY_WITH_SCENE_ACTOR = slua.Array(EPropertyClass.Int), -- 技能查询(战斗加探索元素反应)
	CAMERA_DITHER_FADE = slua.Array(EPropertyClass.Int) -- 相机检测 场景/角色虚化 
}

QUERY_BY_OBJECTTYPES.COMMON_WORLD_STATIC:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.WorldStatic))

QUERY_BY_OBJECTTYPES.COMMON_PAWN:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.Pawn))

QUERY_BY_OBJECTTYPES.COMMON_WORLD_DYNAMIC:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.WorldDynamic))

QUERY_BY_OBJECTTYPES.PICK_BY_SCREEN_CLICK:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.MainPlayer))
QUERY_BY_OBJECTTYPES.PICK_BY_SCREEN_CLICK:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.AOIPlayer))
QUERY_BY_OBJECTTYPES.PICK_BY_SCREEN_CLICK:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.MovableUnit))

QUERY_BY_OBJECTTYPES.INTERACTABLE_FOR_INTERACT_HUD:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.Interactable))

QUERY_BY_OBJECTTYPES.INTERACTABLE_FOR_LINE_TRACE:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.WorldDynamic))
QUERY_BY_OBJECTTYPES.INTERACTABLE_FOR_LINE_TRACE:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.WorldStatic))

QUERY_BY_OBJECTTYPES.SCENE_ACTOR:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.SceneActor))
QUERY_BY_OBJECTTYPES.SCENE_ACTOR:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.SceneActorBlockMainPlayer))
QUERY_BY_OBJECTTYPES.SCENE_ACTOR:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.SceneActorBlockAll))

QUERY_BY_OBJECTTYPES.ABILITY_DEFAULT:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.MainPlayer))
QUERY_BY_OBJECTTYPES.ABILITY_DEFAULT:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.AOIPlayer))
QUERY_BY_OBJECTTYPES.ABILITY_DEFAULT:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.MovableUnit))

QUERY_BY_OBJECTTYPES.ABILITY_WITH_SCENE_ACTOR:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.MainPlayer))
QUERY_BY_OBJECTTYPES.ABILITY_WITH_SCENE_ACTOR:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.AOIPlayer))
QUERY_BY_OBJECTTYPES.ABILITY_WITH_SCENE_ACTOR:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.MovableUnit))
QUERY_BY_OBJECTTYPES.ABILITY_WITH_SCENE_ACTOR:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.SceneActor))
QUERY_BY_OBJECTTYPES.ABILITY_WITH_SCENE_ACTOR:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.SceneActorBlockMainPlayer))
QUERY_BY_OBJECTTYPES.ABILITY_WITH_SCENE_ACTOR:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.SceneActorBlockAll))

QUERY_BY_OBJECTTYPES.CAMERA_DITHER_FADE:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.MainPlayer))
QUERY_BY_OBJECTTYPES.CAMERA_DITHER_FADE:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.AOIPlayer))
QUERY_BY_OBJECTTYPES.CAMERA_DITHER_FADE:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.MovableUnit))
QUERY_BY_OBJECTTYPES.CAMERA_DITHER_FADE:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.SceneActor))
QUERY_BY_OBJECTTYPES.CAMERA_DITHER_FADE:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.SceneActorBlockMainPlayer))
QUERY_BY_OBJECTTYPES.CAMERA_DITHER_FADE:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.WorldStatic))
QUERY_BY_OBJECTTYPES.CAMERA_DITHER_FADE:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.WorldDynamic))
QUERY_BY_OBJECTTYPES.CAMERA_DITHER_FADE:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.Visibility))
QUERY_BY_OBJECTTYPES.CAMERA_DITHER_FADE:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.Pawn))
QUERY_BY_OBJECTTYPES.CAMERA_DITHER_FADE:Add(C7FunctionLibrary.ConvertToObjectType(COLLISION_OBJECT_TYPE_BY_NAME.Interactable))

-- ===========================================业务按需封装内容===============================================
-- 与SetCollisionPresetForRootAndMeshComponents中的mask参数有关的封装
-- 0b111 掩码  高2位(Overlap操作) | 低1位(Preset操作)

local NO_NEED_SET_PRIM_PRESET = 0
local NEED_SET_PRIM_PRESET = 1
local OVERLAP_EVENT_BIT_OFFSET = 1
local IGNORE_OVERLAP_GENERATE = bit.lshift(0, OVERLAP_EVENT_BIT_OFFSET)
local DISABLE_OVERLAP_GENERATE = bit.lshift(1, OVERLAP_EVENT_BIT_OFFSET)
local ENABLE_OVERLAP_GENERATE = bit.lshift(2, OVERLAP_EVENT_BIT_OFFSET)

-- 下列不完整, 按需加
ONLY_SET_PRESET = bit.bor(NEED_SET_PRIM_PRESET, IGNORE_OVERLAP_GENERATE)
ONLY_DISABLE_OVERLAP = bit.bor(NO_NEED_SET_PRIM_PRESET, DISABLE_OVERLAP_GENERATE)
ONLY_ENABLE_OVERLAP = bit.bor(NO_NEED_SET_PRIM_PRESET, ENABLE_OVERLAP_GENERATE)
SET_PRESET_AND_IGNORE_OVERLAP = bit.bor(NEED_SET_PRIM_PRESET, IGNORE_OVERLAP_GENERATE)
SET_PRESET_AND_DISABLE_OVERLAP = bit.bor(NEED_SET_PRIM_PRESET, DISABLE_OVERLAP_GENERATE)
