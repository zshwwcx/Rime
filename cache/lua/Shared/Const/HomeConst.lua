-- 家园位面的状态
HOME_PLANE_STAGE = {
    NONE = 0,            -- 未创建
    CREATING = 1,        -- 创建中
    CREATED = 2,         -- 已存在
    DESTROYING = 3,      -- 销毁中
}

-- 错误码
HOME_ERRCODE = 
{
    SUCC = 0,
    NO_HOME = 1,        -- 没有家园
    CREATE_FAILED = 2,  -- 进入家园场景失败
    NOT_IN_HOMELAND = 3,-- 不在家园场景中
    BUILDING_ID_INVALID = 4,    -- 家具ID无效
    BUILDING_NOT_EXIST = 5,     -- 家具不存在 
    NOT_HOMELAND_OWNER = 6,     -- 不是家园主人
    FURNITURE_NOT_ENOUGH = 7,   -- 家具数量不足
    FURNITURE_ID_INVALID = 8,   -- 家具类型无效
    FURNITURE_ALREADY_UNLOCK = 9, -- 家具已经解锁
    MODULE_LOCKED = 10,         -- 家园功能未解锁
    FURNITURE_UNLOCK_CONDITION_NOT_MATCH = 11,  -- 家具解锁条件不满足
    HOME_MONEY_NOT_ENOUGH = 12, -- 家园货币不足
    FURNITURE_LOCKED = 13,      -- 家具未解锁
    FURNITURE_NUM_REACH_MAX = 14, -- 家具数量超过上限
    FURNITURE_NUM_REACH_TOTAL_COUNT = 15, -- 家具剩余数量超过总数量
    HOME_CONFIG_NOT_FOUND = 16, -- 没有找到家园配置
    BUILDING_LAYER_INVALID = 17,-- 建筑层数无效
    BUILDING_FRAME_VALUE_INVALID = 18,  -- 框架值无效
    BUILDING_NUM_REACH_MAX = 19, -- 场景中家具数量达到上限
    ENTER_HOME_STATE_INVALID = 20, -- 当前状态下无法进入家园场景
}

-- 家园类型
HOME_TYPE = 
{
    HOME_HOUSE = 0,     -- 住宅
    HOME_MANOR = 1,     -- 庄园
}

--- 家园场景中家具数量上限
HOMELAND_FURNITURE_MAX_SIZE = 10000
--- 场景中没有人之后销毁的延迟,1分钟
HOMELAND_DESTROY_DELAY = 60
--- 创建场景的超时时长,10秒
HOME_PLANE_WORLD_CREATE_TIMEOUT = 10 * 1000
--- 传送进场景的超时时长,10秒
HOME_PLANE_WORLD_ENTER_TIMEOUT = 10 * 1000
--- 存盘定时器间隔,5分钟
HOMELAND_SAVE_INTERVAL = 60 * 5
-- 家园货币类型
HOME_MONEY_TYPE = 2001000
-- 最大存盘失败次数
MAX_SAVE_FAIL_COUNT = 3

