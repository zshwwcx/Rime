-- 队伍匹配状态变更原因
TeamMatchStateChangeReasonType = {
    TMSCRT_MATCH = 0,                 -- 申请匹配
    TMSCRT_ACTOR_OPERATE = 1,         -- 玩家操作
    TMSCRT_ACTOR_SUCCESS = 2,         -- 匹配成功
    TMSCRT_TEAM_FULL = 3,             -- 队伍满员
    TMSCRT_TEAM_DISCONNECT = 4,       -- 玩家断线
    TMSCRT_TEAM_ENTER = 5,            -- 加入队伍
    TMSCRT_TEAM_RECONNECT = 6,        -- 断线重连
    TMSCRT_TEAM_DISSOLVED = 7,        -- 队伍解散
    TMSCRT_TEAM_TRANSFER_CAPTAIN = 8, -- 转移队长
    TMSCRT_TEAM_CHANGE_TARGET = 9,    -- 更换目标
    TMSCRT_TEAM_OPEN_DUNGEON = 10,    -- 开启副本
    TMSCRT_TEAM_LEAVE_TEAM = 11,      -- 退出队伍
    TMSCRT_TEAM_COMBINE = 12,         -- 队伍合并
    TMSCRT_TEAM_BREAK = 13,           -- 匹配打断
    TMSCRT_GROUP_FULL = 14,           -- 团队满员
    TMSCRT_GROUP_AUTO_MATCH = 15,     -- 自动匹配
    TMSCRT_GROUP_CHANGE_TARGET = 16,  -- 目标变更
    TMSCRT_GROUP_DISBAND = 17,        -- 团队解散
    TMSCRT_BUILD_GROUP = 18,          -- 建立团队
    TMSCRT_BREAK_ALL_MATCH = 19,      -- 打断所有匹配
}

--- team member change reason
TeamMemberChangeReason = {
    TMCR_ENTER = 0,
    TMCR_LEAVE = 1,
    TMCR_CAPTAIN_CHANGE = 2,
}

--- team member change subreason
TeamMemberChangeSubReason = {
    TMCSR_SERVER_ERR = -1,         -- 服务器ERROR
    TMCSR_DEFAULT = 0,             -- 默认情况
    TMCSR_SUPPORT = 1,             -- 支援入队
    TMCSR_GROUP_DISBAND = 2,       -- 团队解散入队
    TMCSR_KICKED = 3,              -- 被踢出离队
    TMCSR_BUILD_GROUP = 4,         -- 创建团队离队
    TMCSR_DISSOLVE = 5,            -- 队伍解散离队（全部离线、队伍合并）
    TMCSR_COMBINE = 6,             -- 队伍合并入队
    TMCSR_PVP_MATCH = 7,           -- PVP匹配
    TMCSR_PVP_MATCH_RECOVER = 8,   -- PVP匹配恢复
    TMCSR_OFFLINE = 9,             -- 离线
}

--- target队伍、团队限制
TeamTargetLimit = {
    BOTH = 0,
    TEAM_ONLY = 1,
    GROUP_ONLY = 2
}

--队伍人数
TeamMaxNum = 5

TeamPosition = {
    Attack = 0,
    Tank = 1,
    Defend = 2,
}

-- group member change type
GroupMemberChangeType = {
    ENTER_GROUP = 0,
    LEAVE_GROUP = 1,
}