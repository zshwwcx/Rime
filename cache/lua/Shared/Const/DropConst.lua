local itemConstSource = kg_require("Shared.ItemConstSource")

local Enum = Enum

DROP_ACTION_MAX_KEY = 10000000000   -- 发放奖励的配置表的主键的最大值, 100亿

DROP_LIMIT_FOREVER_ONE = 10001  -- 永久1次的限次规则编号, 如每个成就/任务的奖励只能领取1次

-- showStyle, 获得物品展示类型
DROP_SHOW_GROUND = Enum.EConstIntData.DROP_FALL_GROUND          -- 掉落地上
DROP_SHOW_TIP = Enum.EConstIntData.DROP_UI_COM_TIP              -- 左下角UI展示, 直接进包
DROP_SHOW_DIALOG = Enum.EConstIntData.DROP_UI_COM_DIALOG        -- 奖励弹窗, 直接进包
DROP_SHOW_SPECIAL = Enum.EConstIntData.DROP_UI_SPECIAL_DISPLAY  -- 特殊展示, 直接进包


-- belong, 掉落归属
BELONG_ONE = Enum.EConstIntData.DROP_PRIORITY_ONLY_SELF             -- 独立掉落，仅掉一份 第一个有权限的
BELONG_ALL = Enum.EConstIntData.DROP_PRIORITY_ALL                   -- 所有拥有奖励分配权限的玩家，一起掉落一份，共同分配(展示方式仅支持0)
BELONG_TEAM = Enum.EConstIntData.DROP_PRIORITY_TEAM                 -- 队伍共享，不同队伍之间互不影响(展示方式仅支持0)
BELONG_INDEPENDENT = Enum.EConstIntData.DROP_PRIORITY_INDEPENDENT   -- 独立掉落(有权限的人都单独掉)

-- key为使用途径(source), value为功能类型（actionType）, 相同lua导表文件的同一个字段是指一种功能
-- 主要是一个功能可能有多种途径去领取奖励
-- 如可以单独领取某个成就的奖励, 也可以一键领取所有成就的奖励
-- 虽然像成就奖励有2种途径领取, 但对应的功能都是同一个（即sheet + fieldName）是相同的
ITEM_SOURCE_2_ACTION_TYPE = {
    [itemConstSource.ITEM_SOURCE_OPEN_BOX] = Enum.EDropActionType.DROP_ACTION_USE_ITEM,
    [itemConstSource.ITEM_SOURCE_GAME_DROP_REWARD] = Enum.EDropActionType.DROP_ACTION_GAME_DROP,
}

--{
--  actionType(功能类型): {
--          funcName（TableData的读配置的函数名）, 
--          fieldName（奖励的字段名）, 
--          isCustomRule（是否自定义规则生成的物品列表), 
--          limitRuleID（限次规则的编号）,
--          showStyle (获得物品的展示类型, 分为掉落地上, tip或dialog展示, 其中nil为获得不用提示）, 或者配置表的展示类型的字段名,
--          belong (掉落归属, 参考上面的枚举, 0为当前玩家发奖励）, 或者配置表的掉落归属的字段名,
--      }
--}

-- 限次的主键 = actionType * DROP_ACTION_MAX_KEY + key (发放奖励的配置表的主键)
-- 重要：一键领取和单独领取奖励的actionType必须相同, 否则限次会有出错!!!

DROP_ACTION_CONFIG = {
    [Enum.EDropActionType.DROP_ACTION_USE_ITEM] = { "GetItemNewDataRow", "DropSystemAction", true, 0, DROP_SHOW_DIALOG, 0 },
    [Enum.EDropActionType.DROP_ACTION_GAME_DROP] = { "GetGameDropDataRow", "Reward", false, 0, "ShowType", Enum.EConstIntData.DROP_PRIORITY_ONLY_SELF }
}