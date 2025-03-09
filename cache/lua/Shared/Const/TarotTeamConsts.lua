-- 小队状态
TAROT_TEAM_STATUS = {
    RECRUITING = 1, -- 招募中
    BUILDING = 10,  -- 建队流程
    FINAL = 20,     -- 正式队伍
}

-- 队伍唯一id默认值
TAROT_TEAM_DEFAULT_ID = 0

---@alias TAROT_TEAM_RANK_TYPE number
---@type table<string, TAROT_TEAM_RANK_TYPE> 搜索排行榜
TAROT_TEAM_SEARCH_LIST_TYPE = {
    -- 招募小队
    RECRUIT_DEFAULT = 0,                  -- 默认
    RECRUIT_MEMBER_NUMBER_DESCENDING = 1, -- 成员数量，降序
    RECRUIT_MEMBER_NUMBER_ASCENDING = 2,  -- 成员数量，升序
    RECRUIT_EXPIRE_TIME_DESCENDING = 3,   -- 过期时间，降序
    RECRUIT_EXPIRE_TIME_ASCENDING = 4,    -- 过期时间，升序

    -- 正式小队
    NORMAL_DEFAULT = 20,
    NORMAL_MEMBER_NUMBER_DESCENDING = 21, -- 成员数量，降序
    NORMAL_MEMBER_NUMBER_ASCENDING = 22,  -- 成员数量，升序
    NORMAL_LEVEL_DESCENDING = 23,         -- 等级，降序
    NORMAL_LEVEL_ASCENDING = 24,          -- 等级，升序

    -- 搜索结果
    SEARCH_RESULT = 40,
}

-- 招募小队客户端排序规则
TAROT_TEAM_SORT_LIST_ROLE = {
    RECRUIT_MEMBER_NUMBER_DESCENDING = {key = "memberCount",              bDescending = true},
    RECRUIT_MEMBER_NUMBER_ASCENDING = {key = "memberCount",              bDescending = false},
    RECRUIT_EXPIRE_TIME_DESCENDING = {key = "leftTime",              bDescending = true},
    RECRUIT_EXPIRE_TIME_ASCENDING = {key = "leftTime",              bDescending = false},
    NORMAL_MEMBER_NUMBER_DESCENDING = {key = "memberCount",              bDescending = true},
    NORMAL_MEMBER_NUMBER_ASCENDING = {key = "memberCount",              bDescending = false},
    NORMAL_LEVEL_DESCENDING = {key = "lv",              bDescending = true},
    NORMAL_LEVEL_ASCENDING = {key = "lv",              bDescending = false}
}

SEARCH_LIST_ORDER_TYPE = {
    DESCENDING = 0, -- 降序
    ASCENDING = 1,  -- 升序
}

---@enum TarotTeamSortKey
SEARCH_LIST_SORT_KEY = {
    MEMBER_NUMBER = "memberCount",
    EXPIRE_TIME = "expireTime",
    LEVEL = "level",
}

DEFAULT_MAX_LEVEL = 999
DEFAULT_MAX_MEMBER_NUMBER = 999
DEFAULT_MAX_EXPIRE_TIME = 9999999999
-- 搜索排行榜配置: {{字段1tag, 字段1升降序, 字段1升降序默认值}, {字段2tag, 字段2升降序, 字段2升降序默认值}}
-- 招募小队搜索列表score配置
RECRUIT_TAROT_TEAM_SEARCH_LIST_CONFIG = {
    [TAROT_TEAM_SEARCH_LIST_TYPE.RECRUIT_DEFAULT] = {
        size = 500,
        sortKeys = {
            [1] = { SEARCH_LIST_SORT_KEY.MEMBER_NUMBER, SEARCH_LIST_ORDER_TYPE.DESCENDING, 0 },
            [2] = { SEARCH_LIST_SORT_KEY.EXPIRE_TIME, SEARCH_LIST_ORDER_TYPE.ASCENDING, 0 },
        }, -- {人数，过期时间}
    },
    [TAROT_TEAM_SEARCH_LIST_TYPE.RECRUIT_MEMBER_NUMBER_DESCENDING] = {
        size = 500,
        sortKeys = { [1] = { SEARCH_LIST_SORT_KEY.MEMBER_NUMBER, SEARCH_LIST_ORDER_TYPE.DESCENDING, 0 } }, -- {人数}
    },
    [TAROT_TEAM_SEARCH_LIST_TYPE.RECRUIT_MEMBER_NUMBER_ASCENDING] = {
        size = 500,
        sortKeys = { [1] = { SEARCH_LIST_SORT_KEY.MEMBER_NUMBER, SEARCH_LIST_ORDER_TYPE.ASCENDING, DEFAULT_MAX_MEMBER_NUMBER } }, -- {人数}
    },
    [TAROT_TEAM_SEARCH_LIST_TYPE.RECRUIT_EXPIRE_TIME_DESCENDING] = {
        size = 500,
        sortKeys = { [1] = { SEARCH_LIST_SORT_KEY.EXPIRE_TIME, SEARCH_LIST_ORDER_TYPE.DESCENDING, 0 } }, -- {过期时间}
    },
    [TAROT_TEAM_SEARCH_LIST_TYPE.RECRUIT_EXPIRE_TIME_ASCENDING] = {
        size = 500,
        sortKeys = { [1] = { SEARCH_LIST_SORT_KEY.EXPIRE_TIME, SEARCH_LIST_ORDER_TYPE.ASCENDING, DEFAULT_MAX_EXPIRE_TIME } }, -- {过期时间}
    }
}

-- 正式小队搜索列表score配置
NORMAL_TAROT_TEAM_SEARCH_LIST_CONFIG = {
    [TAROT_TEAM_SEARCH_LIST_TYPE.NORMAL_DEFAULT] = {
        size = 500,
        sortKeys = {
            [1] = { SEARCH_LIST_SORT_KEY.MEMBER_NUMBER, SEARCH_LIST_ORDER_TYPE.DESCENDING, 0 },
            [2] = { SEARCH_LIST_SORT_KEY.LEVEL, SEARCH_LIST_ORDER_TYPE.DESCENDING, 0 }
        },                                                                                -- {人数，等级}
    },
    [TAROT_TEAM_SEARCH_LIST_TYPE.NORMAL_MEMBER_NUMBER_DESCENDING] = {
        size = 500,
        sortKeys = { [1] = { SEARCH_LIST_SORT_KEY.MEMBER_NUMBER, SEARCH_LIST_ORDER_TYPE.DESCENDING, 0 } }, -- {人数}
    },
    [TAROT_TEAM_SEARCH_LIST_TYPE.NORMAL_MEMBER_NUMBER_ASCENDING] = {
        size = 500,
        sortKeys = { [1] = { SEARCH_LIST_SORT_KEY.MEMBER_NUMBER, SEARCH_LIST_ORDER_TYPE.ASCENDING, DEFAULT_MAX_MEMBER_NUMBER } }, -- {人数}
    },
    [TAROT_TEAM_SEARCH_LIST_TYPE.NORMAL_LEVEL_DESCENDING] = {
        size = 500,
        sortKeys = { [1] = { SEARCH_LIST_SORT_KEY.LEVEL, SEARCH_LIST_ORDER_TYPE.DESCENDING, 0 } }, -- {等级}
    },
    [TAROT_TEAM_SEARCH_LIST_TYPE.NORMAL_LEVEL_ASCENDING] = {
        size = 500,
        sortKeys = { [1] = { SEARCH_LIST_SORT_KEY.LEVEL, SEARCH_LIST_ORDER_TYPE.ASCENDING, DEFAULT_MAX_LEVEL } }, -- {等级}
    },
}

-- 小队类型对应多个搜索列表的score配置
TAROT_TEAM_STATUS_2_SEARCH_CONFIG = {
    [TAROT_TEAM_STATUS.RECRUITING] = RECRUIT_TAROT_TEAM_SEARCH_LIST_CONFIG,
    [TAROT_TEAM_STATUS.BUILDING] = nil,
    [TAROT_TEAM_STATUS.FINAL] = NORMAL_TAROT_TEAM_SEARCH_LIST_CONFIG,
}

-- 默认搜索列表的score配置
TAROT_TEAM_STATUS_2_DEFAULT_SEARCH_CONFIG = {
    [TAROT_TEAM_STATUS.RECRUITING] = RECRUIT_TAROT_TEAM_SEARCH_LIST_CONFIG[TAROT_TEAM_SEARCH_LIST_TYPE.RECRUIT_DEFAULT],
    [TAROT_TEAM_STATUS.BUILDING] = nil,
    [TAROT_TEAM_STATUS.FINAL] = RECRUIT_TAROT_TEAM_SEARCH_LIST_CONFIG[TAROT_TEAM_SEARCH_LIST_TYPE.NORMAL_DEFAULT],
}

TAROT_TEAM_ACTION_LOG = {
    APPLY = 1,
    CENCEL_APPLY = 2,
    APPLY_RECRUITING = 3,
    CANCEL_APPLY_RECRUITING = 4,
    REFRESH = 5,

}
