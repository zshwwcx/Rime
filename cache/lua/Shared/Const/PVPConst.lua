
-- PVP玩法局内阶段
---@class PVP_INNER_STATUS
PVP_INNER_STATUS = {
    INIT = 0,      -- 初始
    PREPARE = 1,   -- 准备
    BATTLE = 2,    -- 战斗中
    WAIT_NEXT = 3, -- 等待下一局
    CALC = 4,      -- 结算中
    END = 5,       -- 结束
}
---@class PVP_INNER_MEMBER_STATUS
-- PVP玩法玩家状态
PVP_INNER_MEMBER_STATUS =
{
    INIT = 0,  -- 还没有入场
    NORMAL = 1,   -- 已入场
    DEAD = 2,   -- 败北
    QUIT = 3,   -- 退出 已结算
    ESAPE = 4,   -- 逃跑(未结算时 下线或者强行退出)
}

-- TODO: 此处修改为ExcelEnum
-- PVP玩法玩家状态
PVP_ID =
{
    FIVE_VS_FIVE = 5500001,
    THREE_VS_THREE = 5500002
}

-- PVP阵营类型
PVP_CAMP_TYPE =
{
    BLUE = 1,  -- 红方
    RED = 2    -- 蓝方
}

PVP_BATTLE_START_TIMER = 6  -- 战斗前开始多少秒显示大的倒计时

DEFAULT_BORN_RANGE = 300

COMBAT_ASSIST_FIX_RANGE = 800 -- 8米
COMBAT_ASSIST_EFFECTIVE_RANGE = 2500 -- 25米
HEAL_ASSIST_TIME = 15 * 1000 -- 默认治疗助攻有效时间 15秒

-------------------------------------- 战斗播报 start --------------------------------------
INSTANT_BATTLE_NOTICE = 100
-- 战斗播报需要统计的类型
-- 不要超过1000，每个类型会有计数存储，和配置的播报共用一个table
BATTLE_NOTICE_EVENT = {
    -- 累计事件
    KILL = 1,  -- 击杀
    ASSIST = 2,  -- 助攻
    CONTROL_TIME = 3,  -- 控制时长

    -- 瞬间事件
    DAMAGE_PERCENT = 101,  -- 敌方玩家死亡时伤害占比
    KILL_SELF_HP = 102,  -- 击杀敌方时自己的血量
    HEAL_TAGERT_HP = 103,  -- 治疗时对方玩家血量
    KILL_TARGET_KILL_CNT = 104,  -- 击杀对方时对方的连续击杀数量
}

BATTLE_NOTICE_EVENT_REVERSE = {}
for k, v in pairs(BATTLE_NOTICE_EVENT) do
    BATTLE_NOTICE_EVENT_REVERSE[v] = k
end

-------------------------------------- 战斗播报 end --------------------------------------

-------------------------------------- 1V1切磋 start ------------------------------------
-- 默认配置,防止配置缺失
INDIVIDUAL_PVP_DEFAULT_PREPARE_TIME = 5             -- 准备时长
INDIVIDUAL_PVP_DEFAULT_FIGHT_TIME = 300             -- 战斗时长
INDIVIDUAL_PVP_DEFAULT_RANGE = 5                    -- 切磋范围
INDIVIDUAL_PVP_DEFAULT_REJECT_CD = 5                -- 重复邀请cd
INDIVIDUAL_PVP_DEFAULT_RECV_NUM = 10                -- 接收邀请的最大数量
INDIVIDUAL_PVP_DEFAULT_SEND_NUM = 10                -- 发送邀请的最大数量
INDIVIDUAL_PVP_DEFAULT_AUTO_REJECT_TIME = 20        -- 自动拒绝邀请的时长
INDIVIDUAL_PVP_DEFAULT_LEAVE_RANGE_TIME = 3         -- 离开范围的超时时长
INDIVIDUAL_PVP_BROADCAST_RESULT_RANGE = 50          -- 广播切磋结果的范围

-- 死亡时,复活回血比例
INDIVIDUAL_PVP_REVIVE_HP_PERCENT = 0.1

-- pvp entity的异步销毁延迟
INDIVIDUAL_PVP_ENTITY_DESTROY_DELAY = 1

-- 切磋阶段
INDIVIDUAL_PVP_STAGE = {
    STAGE_INIT = 1,         -- 初始化
    STAGE_PREPARE = 2,      -- 准备
    STAGE_BATTLE = 3,       -- 战斗
    STAGE_CALC = 4,         -- 结算
    STAGE_END = 5,          -- 结束
    STAGE_AFTER_END = 6,    -- 清理
}

-- 切磋类型
INDIVIDUAL_PVP_TYPE = {
    INDIVIDUAL_PVP = 1,         -- 1V1切磋
    TRIAL_PVP = 2               -- 审判
}

-- 角色切磋状态
INDIVIDUAL_PVP_ACTOR_STATE = {
    STATE_NONE = 1,         -- 非切磋状态
    STATE_FIGHT = 2         -- 切磋状态
}

-- 角色切磋结果
INDIVIDUAL_PVP_ACTOR_RESULT = {
    RESULT_WIN = 1,         -- 胜
    RESULT_LOSE = 2,        -- 负
    RESULT_DRAW = 3,        -- 平
}

-- 离开场景原因
INDIVIDUAL_PVP_LEAVE_REASON = {
    REASON_LEAVE_RANGE = 1,     -- 离开切磋范围
    REASON_REENTER_RANGE = 2,   -- 重新进入切磋范围
    REASON_LEAVE_SAFE_PLACE = 3,-- 离开安全区
}

-- 错误码
INDIVIDUAL_PVP_ERRCODE = 
{
    PVP_SEND_SUCC = 0,                  -- 邀请发送成功
    PVP_TARGET_OFFLINE = 1,             -- 目标不在线
    PVP_SEND_LIST_FULL = 2,             -- 发送数量达到上限
    PVP_TARGET_RECV_LIST_FULL = 3,      -- 目标的接收数量达到上限
    PVP_TARGET_IN_CD = 4,               -- 目标在邀请cd中
    PVP_DISTANCE_TOO_FAR = 5,           -- 目标距离过远
    PVP_TARGET_IN_FIGHT = 6,            -- 目标在切磋中
    PVP_INVITER_OFFLINE = 7,            -- 邀请者不在线
    PVP_INVITER_NOT_EXIST = 8,          -- 邀请无效
    PVP_INVITER_TOO_FAR = 9,            -- 邀请者距离过远
    PVP_INVITER_IN_FIGHT = 10,          -- 邀请者在切磋中
    PVP_AGREE_SUCC = 11,                -- 同意邀请成功
    PVP_INVITER_NOT_IN_SAFE = 12,       -- 邀请者不在安全区
    PVP_TARGET_NO_IN_SAFE = 13,         -- 目标不在安全区
    PVP_BAN = 14,                       -- 禁止1V1切磋
    PVP_ALREADY_SEND = 15,              -- 不能重复发送邀请
    PVP_INVITE_INVITER_DEAD = 16,       -- 邀请者死亡,发送邀请失败
    PVP_INVITE_TARGET_DEAD = 17,        -- 目标死亡,发送邀请失败
    PVP_ACCEPT_INVITER_DEAD = 18,       -- 邀请者死亡,接收邀请失败
    PVP_FAILED = 19,                    -- 邀请失败,自己在切磋中
    PVP_FAILED_TARGET_IN_FIGHT = 20,    -- 被邀请者在切磋中,接受邀请失败
    PVP_ACCEPT_TARGET_DEAD = 21,        -- 被邀请者死亡,接受邀请失败
    PVP_CANNOT_BATTLE_WITH_SELF = 22,   -- 不能对自己发起切磋
    PVP_TARGET_IS_REDNAME = 23,         -- 对方处于红名状态
    PVP_SELF_IS_REDNAME = 24,           -- 自己处于红名状态
}

-------------------------------------- 1V1切磋 end --------------------------------------