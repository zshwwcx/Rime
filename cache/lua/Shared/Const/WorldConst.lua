-- ---@class WorldConst
-- local worldConst = {}
--------------------------------------
---在添加新的类型的时候需要通知@wanglei43处理特效优先级裁剪 不能随意添加场景类型定义枚举。
---前后端共用，不要随意删除！！！！
---@class WORLD_TYPE
WORLD_TYPE =
{
    BIGWORLD = 1,
    DUNGEON = 2,
    TEAM_ARENA_33 = 3,  -- 3v3
    GUILD_STATION = 4,
    MULTI_PVP = 5, -- 50v50战场
    PLANE = 6, -- 位面
    TEST_MAP = 7, -- 测试场景
    TOWER_CLIMB = 8, -- 爬塔场景
    TEAM_ARENA_55 = 9, -- 5v5
    GUILD_LEAGUE = 10,  -- 公会联赛
    HOME_HOUSE = 11, -- 家园住房
    HOME_MANOR = 12, -- 家园庄园
    SCHOOL_TOP = 13, -- 门派首席场景
    GROUP_OCCUPY = 14, -- 12V12
    ELIMINATION_ARENA = 15, -- 淘汰赛场景
}
-- 最大分线数量
MAX_LINE_NUM = 100000

-- return worldConst
