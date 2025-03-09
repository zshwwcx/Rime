--- 组队相关定义
--- Created by shangyuzhong.
--- DateTime: 2024/10/24
---

TEAM_LOG_ACTION_TYPE = {
    REFRESH_INFO = 0,
    CREATE_TEAM = 1,
    JOIN_TEAM = 2,
    LEAVE_TEAM = 3,
    CHANGE_CAPTAIN = 4,
    KICK_MEMBER = 5,
    APPLY_CAPTAIN = 6,
    DISBAND_TEAM = 7
}

TEAM_LOG_QUIT_REASON = {
    BUILD_GROUP = 1,        -- 组团解散队伍
    DISBAND_TEAM = 2,       -- 解散队伍
    LEAVE_TEAM = 3,         -- 主动离队
    TEAM_COMBINE = 4,       -- 队伍合并
}

-- 团队成员日志类型
GROUP_PLAYER_LOG_ACTION_TYPE = {
    BUILD_GROUP = 1,    -- 创建团队
    JOIN_GROUP = 2,     -- 加入团队
    LEAVE_GROUP = 3,    -- 离开团队
    TRANSFER_LEADER = 4,    -- 转让团队队长
    KICK_MEMBER = 5,    -- 踢出团队队友
    APPLY_LEADER = 6,    -- 申请团队队长
    ASSIGN_TEAM_LEADER = 7,    -- 任命队长
    APPLY_TEAM_LEADER = 8,    -- 申请队长
}

-- 退出团队原因
QUIT_GROUP_SUB_REASON = {
    DEFAULT = 0,  -- 默认主动退出
    KICKED = 1,  -- 被踢出
    DISBAND = 2, -- 团队解散
}

-- 组团日志的状态类型
GROUP_LOG_STATE_TYPE = {
    BUILD_GROUP = 1,    -- 创建团队
    GROUP_FULL = 2,    -- 团队已满
    DISBAND_GROUP = 3,    -- 解散团队
    JOIN_LEAGUE = 4,    -- 加入联盟
}

-- 组队语音状态
VOICE_STATE = {
    [Enum.EVOICE_STATE.REFUSE] = true,
    [Enum.EVOICE_STATE.LISTEN] = true,
    [Enum.EVOICE_STATE.VOICE] = true
}

FIND_TEAM_MAX_LOOP_LIMIT = 1000

MAX_AUTO_AGREE_QUEUE_SIZE = 100	-- 组团自动同意队列最大长度

APPLIED_EXPIRE_HANDLE_INTERVAL = 5

LEAGUE_GROUP_MAX_COUNT = 5

TEAM_SEARCH_CACHE_TIME = 3

TEAM_SEARCH_CD = 0.5

TEAM_SYNC_CACHE_TIME = 30

TEAM_DETAIL_CACHE_TIME = 5