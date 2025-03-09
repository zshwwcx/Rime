-- 通用交互物状态
COMMON_INTERACTOR_STATE = {
    INIT = 0,           -- 初始化
    FINI = 1,           -- 完成交互
    DESTROY = -1,       -- 销毁
}

-- 通用交互物销毁原因
COMMON_INTERACTOR_DESTROY_REASON = {
    INIT_FAILED = 1,        -- 初始化失败
    INTERACT_COUNT_REACH_MAX = 2,   -- 达到最大交互次数
    SPACE_DESTROY = 3,      -- 场景销毁
    GM = 4,                 -- GM
}

-- 通用交互物对于玩家的交互次数限制
COMMON_INTERACTOR_ACTOR_INTERACT_COUNT = {
    NO_LIMIT = 0,               -- 不限制
    ONLY_ONCE = 1,              -- 仅一次      
}

-- 通用交互物交互开始类型
COMMON_INTERACTOR_START_TYPE = {
    BUTTON_CLICK = 1,           -- 按键开始
    ELEMENT = 2,                -- 元素扩展
    ENTER_RANGE = 3             -- 进入范围
}

-- 通用交互物交互结果
COMMON_INTERACTOR_RESULT = {
    SUCC = 1,              -- 成功
    FAIL = 2,              -- 失败
}

-- 通用交互物检查结果
COMMON_INTERACTOR_CHECK_RESULT = {
    NO_ERROR = 0,                       -- 
    INTERACTOR_NOT_FOUND = 1,           -- 交互物没有找到
    INTERACTOR_STATE_INVALID = 2,       -- 交互物状态异常
    INTERACTOR_IN_INTERACTING = 3,      -- 交互物正在交互中
    INTERACT_COUNT_REACH_MAX = 4,       -- 交互次数达到上限
    INTERACTOR_IN_CD = 5,               -- 交互物处于cd中
    INTERACT_ACTOR_NOT_FOUND = 6,       -- 交互玩家未找到
    INTERACT_ACTOR_STATE_CONFLICT = 7,  -- 交互玩家状态冲突
}

-- 通用交互物行为恢复类型
COMMON_INTERACTOR_ACTION_RECOVER_TYPE = {
    RECOVER_NONE = 1,                   -- 不执行
    RECOVER_EXEC = 2,                   -- 直接执行
    RECOVER_EXEC_WITH_CONDITION = 3,    -- 条件满足时执行
}

-- 通用交互物状态冲突类型
COMMON_INTERACTOR_STATE_CONFLICT_TYPE = {
    INTERACT = 1,                       -- 瞬时交互
    INTERACT_SPELL = 2,                 -- 读条交互
    CONTINUOUS_INTERACT = 3,            -- 持续交互
}

-- 条件检查CD
COMMON_INTERACTOR_CONDITION_CHECK_CD = 2

-- 交互CD误差,毫秒
COMMON_INTERACTOR_CD_TOLERANCE = 200

-- 交互物进出范围条件结果
COMMON_INTERACTOR_CHECK_IN_RANGE_RESULT = {
    ENTER_RANGE = 1,
    LEAVE_RANGE = 2
}
