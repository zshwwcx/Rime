local parallel_behavior_control_const = kg_require("Shared.Const.ParallelBehaviorControlConst")
local LOCO_ANIM_STATE_CONST = parallel_behavior_control_const.LOCO_ANIM_STATE_CONST

--- 输入枚举
---
LOCO_ANIM_STATE_CONST = kg_require("Shared.Const.ParallelBehaviorControlConst").LOCO_ANIM_STATE_CONST

local EMountType = import("EMountType")

ROLE_MOVEMENT_DISABLE_TAG = {
    LOCO_MOVE = 1000
}


--================================动画控制==================================================
COMMON_ANIM_CROSSFADE_TIME = 0.1


-- ===============================基础移动==============================================
INVALID_MOTION_WARP_TOKEN = -1

FOOT_CURVE_NAME = "FootCurve"  -- 值小于0为左脚区间

LOCOMOTION_SM_NAME = 'Locomotion'
LocoStateTypeToAnimStateNameMap = LocoStateTypeToAnimStateNameMap or
        {
            [LOCO_ANIM_STATE_CONST.Idle] = "Idle",
            [LOCO_ANIM_STATE_CONST.RunStart] = "RunStart",
            [LOCO_ANIM_STATE_CONST.Run] = "Run",
            [LOCO_ANIM_STATE_CONST.RunEnd] = "RunEnd",
            [LOCO_ANIM_STATE_CONST.MoveTurn] = "MoveTurn",
            [LOCO_ANIM_STATE_CONST.JumpStart] = "JumpStart",
            [LOCO_ANIM_STATE_CONST.JumpLoop] = "JumpLoop",
            [LOCO_ANIM_STATE_CONST.JumpEndLow] = "JumpEndLow",
            [LOCO_ANIM_STATE_CONST.JumpEndHigh] = "JumpEndHigh",
            [LOCO_ANIM_STATE_CONST.JumpEndRestartLow] = "JumpEndRestartLow",
            [LOCO_ANIM_STATE_CONST.JumpEndRestartHigh] = "JumpEndRestartHigh",
            [LOCO_ANIM_STATE_CONST.GlideStart] = "GlideStart",
            [LOCO_ANIM_STATE_CONST.GlideLoop] = "GlideLoop",
            [LOCO_ANIM_STATE_CONST.RidingIdle] = "RidingIdle",
            [LOCO_ANIM_STATE_CONST.RidingStart] = "RidingStart",
            [LOCO_ANIM_STATE_CONST.RidingLoop] = "RidingLoop",
            [LOCO_ANIM_STATE_CONST.RidingEnd] = "RidingEnd",
            [LOCO_ANIM_STATE_CONST.RidingMoveTurn] = "RidingMoveTurn",
            [LOCO_ANIM_STATE_CONST.MultiJumpEndRestart]  = "MultiJumpEndRestart",
            [LOCO_ANIM_STATE_CONST.RidingDash] = "RidingDash",
            [LOCO_ANIM_STATE_CONST.WaterGetIn] = "WaterGetIn",
            [LOCO_ANIM_STATE_CONST.WaterGetOut] = "WaterGetOut",
            [LOCO_ANIM_STATE_CONST.RidingJumpStart]  = "RidingJumpStart",
            [LOCO_ANIM_STATE_CONST.RidingJumpLoop] = "RidingJumpLoop",
            [LOCO_ANIM_STATE_CONST.RidingJumpEnd] = "RidingJumpEnd",
            [LOCO_ANIM_STATE_CONST.RidingJumpEndRestart] = "RidingJumpEndRestart",
            [LOCO_ANIM_STATE_CONST.DizzinessStart] = "DizzinessStart",
            [LOCO_ANIM_STATE_CONST.DizzinessIdle] = "DizzinessIdle",
            [LOCO_ANIM_STATE_CONST.DizzinessEnd] = "DizzinessEnd",
            [LOCO_ANIM_STATE_CONST.DizzinessWalk] = "DizzinessWalk",
            [LOCO_ANIM_STATE_CONST.WaterIdle] = "WaterIdle",
            [LOCO_ANIM_STATE_CONST.WaterRunStart] = "WaterRunStart",
            [LOCO_ANIM_STATE_CONST.WaterRun] = "WaterRun",
            [LOCO_ANIM_STATE_CONST.WaterRunEnd] = "WaterRunEnd",
            [LOCO_ANIM_STATE_CONST.WaterMoveTurn] = "WaterMoveTurn",
            [LOCO_ANIM_STATE_CONST.WaterJumpStart] = "WaterJumpStart",
            [LOCO_ANIM_STATE_CONST.WaterJumpLoop] = "WaterJumpLoop",
            [LOCO_ANIM_STATE_CONST.WaterJumpEnd] = "WaterJumpEnd",
            [LOCO_ANIM_STATE_CONST.WaterJumpEndRestart] = "WaterJumpEndRestart",
            [LOCO_ANIM_STATE_CONST.WaterJumpStartSecond] = "WaterJumpStartSecond",
            [LOCO_ANIM_STATE_CONST.WaterJumpStartThird] = "WaterJumpStartThird",
            [LOCO_ANIM_STATE_CONST.WaterJumpLoopThird] = "WaterJumpLoopThird",
            [LOCO_ANIM_STATE_CONST.WaterJumpEndThird] = "WaterJumpEndThird",
            [LOCO_ANIM_STATE_CONST.WaterDash] = "WaterDash",
            [LOCO_ANIM_STATE_CONST.JumpStartSecond] = "JumpStartSecond",
            [LOCO_ANIM_STATE_CONST.JumpStartThird] = "JumpStartThird",
            [LOCO_ANIM_STATE_CONST.JumpLoopThird] = "JumpLoopThird",
            [LOCO_ANIM_STATE_CONST.JumpEndThird] = "JumpEndThird",
			[LOCO_ANIM_STATE_CONST.MountPassengerIdle] = "MountPassengerIdle",
			[LOCO_ANIM_STATE_CONST.MountPassengerDash] = "MountPassengerDash",
			[LOCO_ANIM_STATE_CONST.MountPassengerMoveTurn] = "MountPassengerMoveTurn",
			[LOCO_ANIM_STATE_CONST.MountPassengerJumpStart] = "MountPassengerJumpStart",
			[LOCO_ANIM_STATE_CONST.MountPassengerJumpEnd] = "MountPassengerJumpEnd",
        }

LocoAnimStateNameToStateTypeMap = LocoAnimStateNameToStateTypeMap or
        {
            ["Idle"] = LOCO_ANIM_STATE_CONST.Idle,
            ["RunStart"] = LOCO_ANIM_STATE_CONST.RunStart,
            ["Run"] = LOCO_ANIM_STATE_CONST.Run,
            ["RunEnd"] = LOCO_ANIM_STATE_CONST.RunEnd,
            ["MoveTurn"] = LOCO_ANIM_STATE_CONST.MoveTurn,
            ["JumpStart"] = LOCO_ANIM_STATE_CONST.JumpStart,
            ["JumpLoop"] = LOCO_ANIM_STATE_CONST.JumpLoop,
            ["JumpEndLow"] = LOCO_ANIM_STATE_CONST.JumpEndLow,
            ["JumpEndHigh"] = LOCO_ANIM_STATE_CONST.JumpEndHigh,
            ["JumpEndRestartLow"] = LOCO_ANIM_STATE_CONST.JumpEndRestartLow,
            ["JumpEndRestartHigh"] = LOCO_ANIM_STATE_CONST.JumpEndRestartHigh,
            ["GlideStart"] = LOCO_ANIM_STATE_CONST.GlideStart,
            ["GlideLoop"] = LOCO_ANIM_STATE_CONST.GlideLoop,
            ["RidingIdle"] = LOCO_ANIM_STATE_CONST.RidingIdle,
            ["RidingStart"] = LOCO_ANIM_STATE_CONST.RidingStart,
            ["RidingLoop"] = LOCO_ANIM_STATE_CONST.RidingLoop,
            ["RidingEnd"] = LOCO_ANIM_STATE_CONST.RidingEnd,
            ["RidingMoveTurn"] = LOCO_ANIM_STATE_CONST.RidingMoveTurn,
            ["MultiJumpEndRestart"] = LOCO_ANIM_STATE_CONST.MultiJumpEndRestart,
            ["RidingDash"] = LOCO_ANIM_STATE_CONST.RidingDash,
            ["WaterGetIn"] = LOCO_ANIM_STATE_CONST.WaterGetIn,
            ["WaterGetOut"] = LOCO_ANIM_STATE_CONST.WaterGetOut,
            ["RidingJumpStart"] = LOCO_ANIM_STATE_CONST.RidingJumpStart,
            ["RidingJumpLoop"] = LOCO_ANIM_STATE_CONST.RidingJumpLoop,
            ["RidingJumpEnd"] = LOCO_ANIM_STATE_CONST.RidingJumpEnd,
            ["RidingJumpEndRestart"] = LOCO_ANIM_STATE_CONST.RidingJumpEndRestart,
            ["DizzinessStart"] = LOCO_ANIM_STATE_CONST.DizzinessStart,
            ["DizzinessIdle"] = LOCO_ANIM_STATE_CONST.DizzinessIdle,
            ["DizzinessEnd"] = LOCO_ANIM_STATE_CONST.DizzinessEnd,
            ["DizzinessWalk"] = LOCO_ANIM_STATE_CONST.DizzinessWalk,
            ["WaterIdle"] = LOCO_ANIM_STATE_CONST.WaterIdle,
            ["WaterRunStart"] = LOCO_ANIM_STATE_CONST.WaterRunStart,
            ["WaterRun"] = LOCO_ANIM_STATE_CONST.WaterRun,
            ["WaterRunEnd"] = LOCO_ANIM_STATE_CONST.WaterRunEnd,
            ["WaterMoveTurn"] = LOCO_ANIM_STATE_CONST.WaterMoveTurn,
            ["WaterJumpStart"] = LOCO_ANIM_STATE_CONST.WaterJumpStart,
            ["WaterJumpLoop"] = LOCO_ANIM_STATE_CONST.WaterJumpLoop,
            ["WaterJumpEnd"] = LOCO_ANIM_STATE_CONST.WaterJumpEnd,
            ["WaterJumpEndRestart"] = LOCO_ANIM_STATE_CONST.WaterJumpEndRestart,
            ["WaterJumpStartSecond"] = LOCO_ANIM_STATE_CONST.WaterJumpStartSecond,
            ["WaterJumpStartThird"] = LOCO_ANIM_STATE_CONST.WaterJumpStartThird,
            ["WaterJumpLoopThird"] = LOCO_ANIM_STATE_CONST.WaterJumpLoopThird,
            ["WaterJumpEndThird"] = LOCO_ANIM_STATE_CONST.WaterJumpEndThird,
            ["WaterDash"] = LOCO_ANIM_STATE_CONST.WaterDash,
            ["JumpStartSecond"] = LOCO_ANIM_STATE_CONST.JumpStartSecond,
            ["JumpStartThird"] = LOCO_ANIM_STATE_CONST.JumpStartThird,
            ["JumpLoopThird"] = LOCO_ANIM_STATE_CONST.JumpLoopThird,
            ["JumpEndThird"] = LOCO_ANIM_STATE_CONST.JumpEndThird,
			["MountPassengerIdle"] = LOCO_ANIM_STATE_CONST.MountPassengerIdle,
			["MountPassengerDash"] = LOCO_ANIM_STATE_CONST.MountPassengerDash,
			["MountPassengerMoveTurn"] = LOCO_ANIM_STATE_CONST.MountPassengerMoveTurn,
			["MountPassengerJumpStart"] = LOCO_ANIM_STATE_CONST.MountPassengerJumpStart,
			["MountPassengerJumpEnd"] = LOCO_ANIM_STATE_CONST.MountPassengerJumpEnd,
        }


-- -------------------------------感知部分-----------------------------------------------
IN_WATER_DEPTH_CM = 5
WATER_DETECT_DISTANCE_CM = 300
PERCEPTION_DETECT_Z_OFFSET_CM = 300
PERCEPTION_DETECT_DISTANCE_TOLERATE_CM = 5

DYNAMIC_WATER_WAVE_TIME_GAP_FOR_LOCO = 0.1

LOCAL_WIND_FIELD_TIME_GAP_LOCO = 0.1

LOCO_JUMP_Z = 1170
LOCO_GRAVITY_SCALE = 3.25
LOCO_HIGH_JUMP_END_Z_VELOCITY = -2000

MAX_PLAY_RATIO_BY_SPEED = 3.0
MIN_PLAY_RATIO_BY_SPEED = 0.1

LOCO_MAX_ACCELERATION_MAP = LOCO_MAX_ACCELERATION_MAP or {
    [LOCO_ANIM_STATE_CONST.Idle] = 3000,
    [LOCO_ANIM_STATE_CONST.RunStart] = 3000,
    [LOCO_ANIM_STATE_CONST.Run] = 3000,
    [LOCO_ANIM_STATE_CONST.RunEnd] = 3000,
    [LOCO_ANIM_STATE_CONST.MoveTurn] = 3000,
    [LOCO_ANIM_STATE_CONST.JumpStart] = 3000,
    [LOCO_ANIM_STATE_CONST.JumpLoop] = 3000,
    [LOCO_ANIM_STATE_CONST.JumpEndLow] = 3000,
    [LOCO_ANIM_STATE_CONST.JumpEndHigh] = 3000,
    [LOCO_ANIM_STATE_CONST.JumpEndRestartLow] = 3000,
    [LOCO_ANIM_STATE_CONST.JumpEndRestartHigh] = 3000,
    [LOCO_ANIM_STATE_CONST.GlideStart] = 3000,
    [LOCO_ANIM_STATE_CONST.GlideLoop] = 3000,
    [LOCO_ANIM_STATE_CONST.RidingIdle] = 3000,
    [LOCO_ANIM_STATE_CONST.RidingStart] = 3000,
    [LOCO_ANIM_STATE_CONST.RidingLoop] = 3000,
    [LOCO_ANIM_STATE_CONST.RidingEnd] = 3000,
    [LOCO_ANIM_STATE_CONST.RidingMoveTurn] = 3000,
    [LOCO_ANIM_STATE_CONST.MultiJumpEndRestart] = 3000,
    [LOCO_ANIM_STATE_CONST.RidingDash] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterGetIn] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterGetOut] = 3000,
    [LOCO_ANIM_STATE_CONST.RidingJumpStart]  = 3000,
    [LOCO_ANIM_STATE_CONST.RidingJumpLoop] = 3000,
    [LOCO_ANIM_STATE_CONST.RidingJumpEnd] = 3000,
    [LOCO_ANIM_STATE_CONST.RidingJumpEndRestart] = 3000,
    [LOCO_ANIM_STATE_CONST.DizzinessStart] = 3000,
    [LOCO_ANIM_STATE_CONST.DizzinessIdle] = 3000,
    [LOCO_ANIM_STATE_CONST.DizzinessEnd] = 3000,
    [LOCO_ANIM_STATE_CONST.DizzinessWalk] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterIdle] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterRunStart] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterRun] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterRunEnd] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterMoveTurn] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterJumpStart] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterJumpLoop] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterJumpEnd] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterJumpEndRestart] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterJumpStartSecond] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterJumpStartThird] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterJumpLoopThird] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterJumpEndThird] = 3000,
    [LOCO_ANIM_STATE_CONST.WaterDash] = 3000,
    [LOCO_ANIM_STATE_CONST.JumpStartSecond] = 3000,
    [LOCO_ANIM_STATE_CONST.JumpStartThird] = 3000,
    [LOCO_ANIM_STATE_CONST.JumpLoopThird] = 3000,
    [LOCO_ANIM_STATE_CONST.JumpEndThird] = 3000,
	[LOCO_ANIM_STATE_CONST.MountPassengerIdle] = 3000,
	[LOCO_ANIM_STATE_CONST.MountPassengerDash] = 3000,
	[LOCO_ANIM_STATE_CONST.MountPassengerMoveTurn] = 3000,
	[LOCO_ANIM_STATE_CONST.MountPassengerJumpStart] = 3000,
	[LOCO_ANIM_STATE_CONST.MountPassengerJumpEnd] = 3000,
}

LOCO_MAX_BRAKING_DECELERATION_MAP = LOCO_MAX_BRAKING_DECELERATION_MAP or {
    [LOCO_ANIM_STATE_CONST.Idle] = 2048,
    [LOCO_ANIM_STATE_CONST.RunStart] = 2048,
    [LOCO_ANIM_STATE_CONST.Run] = 2048,
    [LOCO_ANIM_STATE_CONST.RunEnd] = 2048,
    [LOCO_ANIM_STATE_CONST.MoveTurn] = 2048,
    [LOCO_ANIM_STATE_CONST.JumpStart] = 0,
    [LOCO_ANIM_STATE_CONST.JumpLoop] = 0,
    [LOCO_ANIM_STATE_CONST.JumpEndLow] = 1048576,
    [LOCO_ANIM_STATE_CONST.JumpEndHigh] = 1048576,
    [LOCO_ANIM_STATE_CONST.JumpEndRestartLow] = 2048,
    [LOCO_ANIM_STATE_CONST.JumpEndRestartHigh] = 2048,
    [LOCO_ANIM_STATE_CONST.GlideStart] = 600,
    [LOCO_ANIM_STATE_CONST.GlideLoop] = 600,
    [LOCO_ANIM_STATE_CONST.RidingIdle] = 2048,
    [LOCO_ANIM_STATE_CONST.RidingStart] = 2048,
    [LOCO_ANIM_STATE_CONST.RidingLoop] = 2048,
    [LOCO_ANIM_STATE_CONST.RidingEnd] = 2048,
    [LOCO_ANIM_STATE_CONST.RidingMoveTurn] = 2048,
    [LOCO_ANIM_STATE_CONST.MultiJumpEndRestart] = 1048576,
    [LOCO_ANIM_STATE_CONST.RidingDash] = 2048,
    [LOCO_ANIM_STATE_CONST.WaterGetIn] = 0,
    [LOCO_ANIM_STATE_CONST.WaterGetOut] = 0,
    [LOCO_ANIM_STATE_CONST.RidingJumpStart]  = 2048,
    [LOCO_ANIM_STATE_CONST.RidingJumpLoop] = 2048,
    [LOCO_ANIM_STATE_CONST.RidingJumpEnd] = 2048,
    [LOCO_ANIM_STATE_CONST.RidingJumpEndRestart] = 2048,
    [LOCO_ANIM_STATE_CONST.DizzinessStart] = 2048,
    [LOCO_ANIM_STATE_CONST.DizzinessIdle] = 2048,
    [LOCO_ANIM_STATE_CONST.DizzinessEnd] = 2048,
    [LOCO_ANIM_STATE_CONST.DizzinessWalk] = 2048,
    [LOCO_ANIM_STATE_CONST.WaterIdle] = 2048,
    [LOCO_ANIM_STATE_CONST.WaterRunStart] = 2048,
    [LOCO_ANIM_STATE_CONST.WaterRun] = 2048,
    [LOCO_ANIM_STATE_CONST.WaterRunEnd] = 2048,
    [LOCO_ANIM_STATE_CONST.WaterMoveTurn] = 2048,
    [LOCO_ANIM_STATE_CONST.WaterJumpStart] = 0,
    [LOCO_ANIM_STATE_CONST.WaterJumpLoop] = 0,
    [LOCO_ANIM_STATE_CONST.WaterJumpEnd] = 1048576,
    [LOCO_ANIM_STATE_CONST.WaterJumpEndRestart] = 2048,
    [LOCO_ANIM_STATE_CONST.WaterJumpStartSecond] = 0,
    [LOCO_ANIM_STATE_CONST.WaterJumpStartThird] = 0,
    [LOCO_ANIM_STATE_CONST.WaterJumpLoopThird] = 0,
    [LOCO_ANIM_STATE_CONST.WaterJumpEndThird] = 1048576,
    [LOCO_ANIM_STATE_CONST.WaterDash] = 2048,
    [LOCO_ANIM_STATE_CONST.JumpStartSecond] = 0,
    [LOCO_ANIM_STATE_CONST.JumpStartThird] = 0,
    [LOCO_ANIM_STATE_CONST.JumpLoopThird] = 0,
    [LOCO_ANIM_STATE_CONST.JumpEndThird] = 1048576,
	[LOCO_ANIM_STATE_CONST.MountPassengerIdle] = 2048,
	[LOCO_ANIM_STATE_CONST.MountPassengerDash] = 2048,
	[LOCO_ANIM_STATE_CONST.MountPassengerMoveTurn] = 2048,
	[LOCO_ANIM_STATE_CONST.MountPassengerJumpStart] = 2048,
	[LOCO_ANIM_STATE_CONST.MountPassengerJumpEnd] = 2048,
}

LOCO_DRIVE_ROLE_MESH_Z_OFFSET = -2.0 -- 用于匹配本地角色移动时，胶囊体的保底离地距离
LOCO_DRIVE_ROLE_CAPSULE_Z_OFFSET = 2.0 -- 用于本地角色贴地时, RootComponent的偏移高度
GRAVITY_VELOCITYZ_MAX = 2000.0  -- 重力速度上限
ENTER_FALLING_VELOCITYZ = 100.0 -- 允许从地面进入Falling的Z轴速度大小

-- 标记跳跃和滑翔状态，会传递到C++
JUMP_LOCOSTATES = JUMP_LOCOSTATES or {
    LOCO_ANIM_STATE_CONST.JumpStart,
    LOCO_ANIM_STATE_CONST.JumpLoop,
    LOCO_ANIM_STATE_CONST.JumpStartSecond,
    LOCO_ANIM_STATE_CONST.JumpStartThird
}
GLIDE_LOCOSTATES = GLIDE_LOCOSTATES or {
    LOCO_ANIM_STATE_CONST.GlideStart,
    LOCO_ANIM_STATE_CONST.GlideLoop
}
WATERWAVE_LOCOSTATES = WATERWAVE_LOCOSTATES or {
    LOCO_ANIM_STATE_CONST.Idle,
    LOCO_ANIM_STATE_CONST.RunStart,
    LOCO_ANIM_STATE_CONST.Run,
    LOCO_ANIM_STATE_CONST.RunEnd,
    LOCO_ANIM_STATE_CONST.MoveTurn,
    LOCO_ANIM_STATE_CONST.RidingIdle,
    LOCO_ANIM_STATE_CONST.RidingStart,
    LOCO_ANIM_STATE_CONST.RidingLoop,
    LOCO_ANIM_STATE_CONST.RidingEnd,
    LOCO_ANIM_STATE_CONST.RidingMoveTurn,
}

BODYLEAN_LOCOSTATES = BODYLEAN_LOCOSTATES or {
    LOCO_ANIM_STATE_CONST.RunStart,
    LOCO_ANIM_STATE_CONST.Run,
    LOCO_ANIM_STATE_CONST.RunEnd
}

RIDEMOUNT_PASSENGER_LOCOSTATE_REPLACE = RIDEMOUNT_PASSENGER_LOCOSTATE_REPLACE or {
	["RidingIdle"] = "MountPassengerIdle",
	["RidingDash"] = "MountPassengerDash",
	["RidingMoveTurn"] = "MountPassengerMoveTurn",
	["RidingJumpStart"] = "MountPassengerJumpStart",
	["RidingJumpEnd"] = "MountPassengerJumpEnd",
	
	["RidingStart"] = "MountPassengerIdle",
	["RidingLoop"] = "MountPassengerIdle",
	["RidingEnd"] = "MountPassengerIdle",
	["RidingJumpLoop"] = "MountPassengerIdle",
	["RidingJumpEndRestart"] = "MountPassengerIdle",
}

DELAYED_ANIMMOVEPOSTURE_CACHETIME = 0.4
CLIENT_LOCAL_SPEED_INFO = {
    ["PredictSpeedByMovePosture"] = {
        Priority = 1000,
        Tag = "PredictSpeedByMovePosture"
    },

    ["PathFollow"] = {
        Priority = 2000,
        Tag = "PathFollow"
    },
}

DISABLE_GRAVITY_TAG = {
    PARABOLA_ROOT_MOTION = 1000,
    LEVEL_SEQUENCE = 1001,
    DIRECTOR_STATE = 1002,
    LOCAL_NPC = 1003,
    ABILITY_SKILL = 1004,
    CHARACTER = 1005,
	MOUNT = 1006,
    MOTIONWARP = 1007,
    HIT_FORCE_MOVE = 1008,
	SPLINE_MOVE = 1009,
    LOCO_CONTROL = 1010,
}

ENavJumpType = ENavJumpType or {
    NoJump = 0,
    JumpOnce = 1,
    JumpTwice = 2,
    TryJump = 3,
}

ENavJumpStage = ENavJumpStage or {
    FirstStage = 1,
    SecondStage = 2
}


LOCOMOTION_CONTROL_OVERRIDE_BY_MOUNT = LOCOMOTION_CONTROL_OVERRIDE_BY_MOUNT or {
	[LOCO_ANIM_STATE_CONST.RidingIdle] = true,
	[LOCO_ANIM_STATE_CONST.RidingStart] = true,
	[LOCO_ANIM_STATE_CONST.RidingLoop] = true,
	[LOCO_ANIM_STATE_CONST.RidingEnd] = true,
	[LOCO_ANIM_STATE_CONST.RidingMoveTurn] = true,
	[LOCO_ANIM_STATE_CONST.RidingDash] = true,
	[LOCO_ANIM_STATE_CONST.RidingJumpStart] = true,
	[LOCO_ANIM_STATE_CONST.RidingJumpLoop] = true,
	[LOCO_ANIM_STATE_CONST.RidingJumpEnd] = true,
	[LOCO_ANIM_STATE_CONST.RidingJumpEndRestart] = true
}


-- ===============================捏脸、妆容========================================================
MAKEUP_DATA_KEY = MAKEUP_DATA_KEY or {
	MAKEUP_PARAM_DATA = 'MakeUpParamData',
	MAKEUP_RES_DATA = 'MakeUpResData',
}

-- 详见C++ EAvatarCaptureMaterialSlotTypeIndex
FACE_CAPTURE_MAT_COUNT = 5