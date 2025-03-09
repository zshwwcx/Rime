--- 红包相关定义
--- Created by shangyuzhong.
--- DateTime: 2024/10/10 15:29
---
local Enum = Enum
local itemConst = kg_require("Shared.ItemConst")

-- 大类, 1=绑金礼金，2=道具礼金
RED_PACKET_CLASS = {
    MONEY = 1,
    ITEM = 2,
}

-- 小类, 1=拼手气礼金，2=密文礼金，3=密码礼金
RED_PACKET_TYPE = {
    RANDOM = 1,
    SECRET_WORD = 2,
    PASSWORD = 3,
}

-- 日志类型, 1=发红包，2=红包过期
RED_PACKET_LOG_TYPE = {
    SEND_LOG = 1,       -- 发红包
    EXPIRE_LOG = 2,   -- 红包过期
}

-- 记录类型, 1=发红包, 2=领取红包
RED_PACKET_RECORD_TYPE = {
    SEND = 1,
    RECEIVE = 2,
}

RED_PACKET_SOURCE_TYPE = {
    GUILD_DANCE = 1,    -- 公会舞会
}


RED_PACKET_MONEY_TYPE = itemConst.ITEM_SPECIAL_MONEY_COIN       -- 红包货币类型:金镑
RED_PACKET_MONEY_RETURN_TYPE = itemConst.ITEM_SPECIAL_MONEY_COIN_BOUND       -- 红包货币返还类型:绑定金镑
RED_PACKET_ITEM_RETURN_TYPE = itemConst.ITEM_SPECIAL_MONEY_COIN       -- 红包道具返还类型:金镑

-- 红包频道额外处理
RED_PACKET_CHANNEL_EXTRA_HANDLE = {
    [Enum.EChatChannelData.WORLD] = "redPacketHandle_World",
    [Enum.EChatChannelData.GUILD] = "redPacketHandle_Guild",
    [Enum.EChatChannelData.TEAM] = "redPacketHandle_Team",
    [Enum.EChatChannelData.GROUP] = "redPacketHandle_Group",
    [Enum.EChatChannelData.CHATROOM] = "redPacketHandle_ChatRoom",
}

-- 红包大类检查
RED_PACKET_CLASS_CHECK_FUNC_NAME = {
    [RED_PACKET_CLASS.MONEY] = "redPacketClassCheck_Money",
    [RED_PACKET_CLASS.ITEM] = "redPacketClassCheck_Item",
}

-- 红包小类检查
RED_PACKET_TYPE_CHECK_FUNC_NAME = {
    [RED_PACKET_TYPE.RANDOM] = "redPacketTypeCheck_Random",
    [RED_PACKET_TYPE.SECRET_WORD] = "redPacketTypeCheck_SecretWord",
    [RED_PACKET_TYPE.PASSWORD] = "redPacketTypeCheck_Password",
}

-- 可加入礼金的道具相关
-- NpcShop表shopid=2300007，item子表tokenid使用货币为2001003，限购次数totallimits为-1，时间在定时上架区间范围内
RED_PACKET_GOODS_SHOP_ID = 2390107
RED_PACKET_GOODS_SHOP_TOKEN_ID = 2001003
RED_PACKET_GOODS_TOTAL_LIMITS = -1

GLOBAL_CACHE_VALID_SECS = 3     -- 全局缓存有效时间

