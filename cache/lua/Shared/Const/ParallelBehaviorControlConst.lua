if IS_SERVER then
    kg_require("logicScript.resources.excel.ExcelEnum")
else
    require "Data.Excel.ExcelEnum"
end

-- 并行行为枚举
---@class PARALLEL_BEHAVIOR_CONST
---
---注意: 这里只定义行为枚举, 下面会进行遍历进行 string-int形式的映射自动补全
PARALLEL_BEHAVIOR_CONST = {
    -- ======================== Locomotion层 =============================
    -- OnGround
    L_IDLE               = 101,     -- 站立空闲
    L_MOVE               = 102,     -- 移动, 诸如走/跑/冲刺跑
    L_MOVE_TURN          = 103,     -- 移动转身
    L_DODGE              = 104,     -- 冲刺
    L_JUMP               = 105,     -- 跳跃
    L_DROPPING           = 106,     -- 跌落
    
    
    -- ====================== Action层 ==================================
    A_LEISURE                 = 1000,     -- 无任何行为
    -- Battle Begin
    A_SKILL_GBATTLE           = 2001,     -- 地面战斗
    A_SKILL_GRCONTROL         = 2002,     -- 地面解控
    A_SKILL_INSTAGGER         = 2003,     -- 处刑表演
    A_SKILL_PARALLEL          = 2004,     -- 可并行技能
    A_SKILL_AIR               = 2005,     -- 空中可释放的技能
    A_SKILL_End               = 2099,     -- 技能行为定义结束，无实际意义
    A_HIT_RIGOR               = 4001,     -- 硬直受击
    -- Battle End
    A_DIE                     = 5001,     -- 死亡
    A_INTERACT                = 6001,     -- 交互
    
}

local PBCValueToName = {}
for bName, bValue in pairs(PARALLEL_BEHAVIOR_CONST) do
    PBCValueToName[bValue] = bName
end
for bValue, bName in pairs(PBCValueToName) do
    PARALLEL_BEHAVIOR_CONST[bValue] = bName
end

LOCO_GROUP_STATE_CONST = LOCO_GROUP_STATE_CONST or
{
    NormalWalking = 1,
    Ride = 2,
    WaterWalk = 3,
	DizzinessWalk = 4,
	RidePassenger = 5,
}

MOUNT_LOCO_GROUP_STATE_CONST = MOUNT_LOCO_GROUP_STATE_CONST or
{
    NormalWalking = 1,
}

LOCO_ANIM_STATE_CONST = LOCO_ANIM_STATE_CONST or
{
    Idle = 1,
    RunStart = 2,
    Run = 3,
    RunEnd = 4,
    MoveTurn = 5,
    JumpStart = 6,
    JumpLoop = 7,
    JumpEndLow = 8,
    JumpEndHigh = 9,
    JumpEndRestartLow = 10,
    JumpEndRestartHigh = 11,
    GlideStart = 12,
    GlideLoop = 13,
    RidingIdle = 14,
    RidingStart = 15,
    RidingLoop = 16,
    RidingEnd = 17,
    RidingMoveTurn = 18,
    MultiJumpEndRestart = 19,
    RidingDash = 20,
    WaterGetIn = 21,
    WaterGetOut = 22,
    RidingJumpStart = 23,
    RidingJumpLoop = 24,
    RidingJumpEnd = 25,
    RidingJumpEndRestart = 26,
    DizzinessStart = 27,
    DizzinessIdle = 28,
    DizzinessWalk = 29,
    DizzinessEnd = 30,
    WaterIdle = 31,
    WaterRunStart = 32,
    WaterRun = 33,
    WaterRunEnd = 34,
    WaterMoveTurn = 35,
    WaterJumpStart = 36,
    WaterJumpLoop = 37,
    WaterJumpEnd = 38,
    WaterJumpEndRestart = 39,
    WaterJumpStartSecond = 40,
    WaterJumpStartThird = 41,
    WaterJumpLoopThird = 42,
    WaterJumpEndThird = 43,
    WaterDash = 44,
    JumpStartSecond = 45,
    JumpStartThird = 46,
    JumpLoopThird = 47,
    JumpEndThird = 48,
	MountPassengerIdle = 49,
	MountPassengerDash = 50,
	MountPassengerMoveTurn = 51,
	MountPassengerJumpStart = 52,
	MountPassengerJumpEnd = 53
}

-- 小心维护这个映射吧, 逻辑使用后面的L_XXXX进行基础移动来描述的
LOCO_ANIM_STATE_TO_LOGIC_LOCO_TYPE_MAPPING = {
    [LOCO_ANIM_STATE_CONST.Idle] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.RunStart] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.Run] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.RunEnd] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.MoveTurn] = PARALLEL_BEHAVIOR_CONST.L_MOVE_TURN,
    [LOCO_ANIM_STATE_CONST.JumpStart] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.JumpLoop] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.JumpEndLow] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.JumpEndHigh] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.JumpEndRestartLow] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.JumpEndRestartHigh] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.GlideStart] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.GlideLoop] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.RidingIdle] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.RidingStart] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.RidingLoop] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.RidingEnd] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.RidingMoveTurn] = PARALLEL_BEHAVIOR_CONST.L_MOVE_TURN,
    [LOCO_ANIM_STATE_CONST.MultiJumpEndRestart] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.RidingDash] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.WaterGetIn] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.WaterGetOut] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.RidingJumpStart] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.RidingJumpLoop] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.RidingJumpEnd] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.RidingJumpEndRestart] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.DizzinessStart] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.DizzinessIdle] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.DizzinessWalk] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.DizzinessEnd] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.WaterIdle] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.WaterRunStart] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.WaterRun] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.WaterRunEnd] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.WaterMoveTurn] = PARALLEL_BEHAVIOR_CONST.L_MOVE_TURN,
    [LOCO_ANIM_STATE_CONST.WaterJumpStart] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.WaterJumpLoop] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.WaterJumpEnd] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.WaterJumpEndRestart] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.WaterJumpStartSecond] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.WaterJumpStartThird] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.WaterJumpLoopThird] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.WaterJumpEndThird] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
    [LOCO_ANIM_STATE_CONST.WaterDash] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
    [LOCO_ANIM_STATE_CONST.JumpStartSecond] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.JumpStartThird] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.JumpLoopThird] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
    [LOCO_ANIM_STATE_CONST.JumpEndThird] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
	[LOCO_ANIM_STATE_CONST.MountPassengerIdle] = PARALLEL_BEHAVIOR_CONST.L_IDLE,
	[LOCO_ANIM_STATE_CONST.MountPassengerDash] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
	[LOCO_ANIM_STATE_CONST.MountPassengerMoveTurn] = PARALLEL_BEHAVIOR_CONST.L_MOVE,
	[LOCO_ANIM_STATE_CONST.MountPassengerJumpStart] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
	[LOCO_ANIM_STATE_CONST.MountPassengerJumpEnd] = PARALLEL_BEHAVIOR_CONST.L_JUMP,
}

EMovePosture = EMovePosture or {
    Run = 0,
    Walk = 1,
    Sprint = 2,
}

PLAYER_POSTURE_TO_SPEED = PLAYER_POSTURE_TO_SPEED or {
    [LOCO_GROUP_STATE_CONST.NormalWalking] = {
        [EMovePosture.Walk] = Enum.EPlayerInitialConst.NormalWalkSpeed,
        [EMovePosture.Run] = Enum.EPlayerInitialConst.NormalRunSpeed,
        [EMovePosture.Sprint] = Enum.EPlayerInitialConst.NormalSprintSpeed,
    },
    [LOCO_GROUP_STATE_CONST.Ride] = {
        [EMovePosture.Walk] = Enum.EPlayerInitialConst.NormalRideSlowSpeed,
        [EMovePosture.Run] = Enum.EPlayerInitialConst.NormalRideFastSpeed,
        [EMovePosture.Sprint] = Enum.EPlayerInitialConst.NormalRideSprintSpeed
    },
    [LOCO_GROUP_STATE_CONST.WaterWalk] = {
        [EMovePosture.Walk] = Enum.EPlayerInitialConst.NormalWateWalkSpeed,
        [EMovePosture.Run] = Enum.EPlayerInitialConst.NormalWateWalkSpeed,
        [EMovePosture.Sprint] = Enum.EPlayerInitialConst.NormalWateWalkSpeed
    },
	[LOCO_GROUP_STATE_CONST.DizzinessWalk] = {
		[EMovePosture.Walk] = Enum.EPlayerInitialConst.NormalWalkSpeed,
		[EMovePosture.Run] = Enum.EPlayerInitialConst.NormalRunSpeed,
		[EMovePosture.Sprint] = Enum.EPlayerInitialConst.NormalSprintSpeed,
	},
	[LOCO_GROUP_STATE_CONST.RidePassenger] = {
		[EMovePosture.Walk] = Enum.EPlayerInitialConst.NormalRideSlowSpeed,
		[EMovePosture.Run] = Enum.EPlayerInitialConst.NormalRideFastSpeed,
		[EMovePosture.Sprint] = Enum.EPlayerInitialConst.NormalRideSprintSpeed
	},
}

PLAYER_POSTURE_SPEED_BOUND = PLAYER_POSTURE_SPEED_BOUND or {
    [LOCO_GROUP_STATE_CONST.NormalWalking] = {Enum.EPlayerInitialConst.NormalWalkToRunSpeedBound, Enum.EPlayerInitialConst.NormalRunToSprintSpeedBound},
    [LOCO_GROUP_STATE_CONST.Ride] = {Enum.EPlayerInitialConst.NormalRideSlowToRideFastSpeedBound, Enum.EPlayerInitialConst.NormalRideFastToRideSprintSpeedBound},
    [LOCO_GROUP_STATE_CONST.WaterWalk] = {0, 2 * Enum.EPlayerInitialConst.NormalWateWalkSpeed},
	[LOCO_GROUP_STATE_CONST.DizzinessWalk] = {Enum.EPlayerInitialConst.NormalWalkToRunSpeedBound, Enum.EPlayerInitialConst.NormalRunToSprintSpeedBound}
}


WEAK_FORCE_CONTROL_REASON_TAGS = {
    DefaultReason = "",

    ATI_PlayAnimationWithMotionWarp = "",
    ATI_BasicMoveAdjust = "",

    LocoControlComp_AttachMode = "",
    LocoControlComp_AnimStateChanged = "",
    LocoControlComp_EnterWorld = "",
    LocoControlComp_LocoSourceMode = "",
    LocoControlComp_OnGroundLocoThruster = "",
    LocoControlComp_MoveDriveMode = "",
    LocoControlComp_SwitchWaterDetect = "",

    MultiJumpComp = "",
    PathFollowComp = "",
	RotateComp = "",

    InteractiveState_AttachInteract = "",
    CommonDualSocialAction = "",
    Violent_Rotation = "",
    
    MainPlayer = "",
    LocalControllableNPC = "",
    LocalNpcBase = "",
    LocalDisplayChar = "",
    LocalSceneNpc = "",
    CrowdNpc = "",
    DialoguePerformer = "", -- 剧编演员

    LevelSequenceBinded = "",
    DialogueBinded = "",
}
for K, _ in pairs(WEAK_FORCE_CONTROL_REASON_TAGS or {}) do
    WEAK_FORCE_CONTROL_REASON_TAGS[K] = tostring(K)
end
