
-- 前后端共用的枚举放到这里 

-- noticeDef迁移
Enum.ERetCode = {
    SUCCESS = 0,
    FAIL = 1,
}

Enum.EACTIVITY_STATUS = {
    PREPARE = 1,    --活动暂未开启/预告
    PREVIEW = 2,    --活动预告
    OPEN = 3,       --活动开启
    CLOSE = 4,      --活动结束
    ERROR = 5,      --状态异常
}

----用来区分消息的UI样式
Enum.ECHAT_MESSAGE_TYPE = {
    TEXT = 1,               -- 文本
    VOICE = 2,              -- 语音
    IMAGE = 3,              -- 图片
    TEAM_RECRUIT = 5,       -- 队伍招募
    FUTURE = 6,             -- 运势
    RED_PACKET = 7,         -- 红包
    SYSTEM_TEXT = 8,        -- 系统文本
    ONE_TIME_ANNOUNCE = 9,  -- 一次性公告
    SYSTEM_INTERFACE = 17,
    FRIEND_CIRCLE_MESSAGE = 18,
    GUILD_TALENT_SHOW_RECRUIT = 19,
    GUILD_RESPONSE = 20,
    GUILD_JOIN = 21,
    GUILD_TASK_HELP = 22,
}

-- 用于区分消息的文本要去哪个配置表读取
Enum.ECHAT_CONTENT_TYPE = {
    GUILD_DANCE_RED_PACKET = 1,     -- 公会舞会红包, 消息的文本要到舞会的配置表常量去读取
}

----不屏蔽的消息样式
Enum.EUNBLOCK_CHAT_MESSAGE_TYPE = {
    Enum.ECHAT_MESSAGE_TYPE.SYSTEM_TEXT,
    Enum.ECHAT_MESSAGE_TYPE.ONE_TIME_ANNOUNCE,
}

-- 用来区分聊天消息的功能
Enum.ECHAT_FUNCTION_TYPE = {
    COMMON = 1,             -- 通用
    TEAM_RECRUIT = 2,       -- 队伍招募
    QUESTION_HELP = 3,      -- 答题求助
    RED_PACKET = 4,         -- 红包
    TEAM_GROUP_RECRUIT = 5, -- 团队招募
    NPC_CHOICE = 6,         -- npc分支选择
    PLAYER_NOTICE = 7,     -- 玩家系统反馈
    FUTURE = 8,             -- 运势
    EXPLORE_COURSE_HELP = 9,
    LOUD_SPEAKER = 10,       -- 喇叭
    SYSTEM_INTERFACE = 11,-- 功能分享接口
    FRIEND_CIRCLE_MESSAGE = 12, --朋友圈消息
    CUSTOM_STICKER = 13,     -- 自定义表情
    ANIM_STICKER = 14,       -- 会动的表情（猜手指、骰子）
    BUBBLE_EMOJI = 15,       -- 气泡表情
    ORIGINAL_EMOJI = 16,     --官方表情
    SHARED_LINK = 17,        -- 分享的超链接
    GUILD_TALENT_SHOW_RECRUIT = 18,
    SHURA_HELP = 21,
    GUILD_RESPONSE = 22, -- 公会响应招募
    GUILD_JOIN = 23  -- 公会加入招募
}

----不屏蔽的消息样式
Enum.EUNBLOCK_CHAT_FUNCTION_TYPE = {
    Enum.ECHAT_FUNCTION_TYPE.LOUD_SPEAKER,
}

Enum.EGROUP_ROLE = {
    NONE = 0,
    LEADER = 1,
    MANAGER = 2,
    MEMBER = 3,
}


Enum.EGROUP_CONFIRM_RESULT = {
    CONFIRM = 1,
    CANCEL = 2,
}

Enum.EVOICE_STATE = {
    REFUSE = 0,
    LISTEN = 1,
    VOICE = 2
}

Enum.EVOICE_CHANNEL = {
	WORLD = 0,              --通用玩法组队语音
	DANCE = 1,             --公会舞会语音
	UNION = 2,				--联盟语音
	CHATROOM = 3,			--茶壶语音
}

Enum.EPLAYER_STATUS = {
    NORMAL = 1,             --正常在线
    CLIENT_LOST = 2        --客户端离线
}

Enum.EDROP_LIMIT_TYPE = {
    DAY = 1,
    WEEK = 2
}

-- 好友动态提醒的类型
Enum.EFRIEND_STATE_REMIND_TYPE = {
    FRIENDCIRCLE = 1,       -- 朋友圈社交通知
    SOCIAL_RELATION_CHANGE = 2,    -- 社交关系变化通知
    BIRTHDAY = 3,           -- 开启生日提醒
    BULLET_WHISPER = 4,      -- 开启消息弹幕
    RETURN_PLAYER = 5   -- 玩家回归
}

Enum.EFRIEND_CLUB_TYPE = {
    COMMON = 0,            -- 普通群聊
    TAROTTEAM = 1,             -- 塔罗小队系统群聊
}

Enum.ECHAT_AFFIX_TYPE = {
    TITLE = 1,
    GUILD = 2,
}

Enum.ECHAT_ITEM_TYPE = {
    SYSTEM = 1,
    OTHER = 2,
    MY = 3,
    ANNOUNCE = 4,
    TIME = 5,
    HISTORY = 6,
    FRIEND_CIRCLE_MESSAGE = 7,
}

Enum.EITEM_ADD_PRIMARY_PROP_TYPE =
{
    ALL = 1,
    FIXED = 2,
    RANDOM = 3
}

-- 好友最近结识的来源
Enum.EFRIEND_RECENT_MEET_SOURCE = {
    DUNGEON = 1, -- 副本
}

Enum.EWARE_HOUSE_SLOT_UNLOCK_TYPE = {
    MONEY = 1,
    CONDITION = 2,
    VIP = 3,
}


Enum.EWARE_HOUSE_PAGE_UNLOCK_TYPE = {
    DEFAULT = 0,
    CONDITION = 1,
    VIP = 2,
}

-- 好友信息（单向、申请）状态
Enum.EFRIEND_INFO_STATE = {
    APPLYING = 1,       -- 申请中/单向
    BOTHWAY = 2         -- 双向
}

-- 成就状态
Enum.ACHIEVEMENT_STATUS = {
    ACHIEVEMENT_STATUS_NORMAL = 1, -- 进行中
    ACHIEVEMENT_STATUS_FINISH = 2, -- 已完成但未领取奖励
    ACHIEVEMENT_STATUS_REWARD = 3, -- 已领取奖励
}

-- 成就阶段奖励状态
Enum.ACHIEVEMENT_LEVEL_STATE = {
    CAN_GET_REWARD = 1, -- 已完成但未领取奖励
    GOT_REWARD = 2, -- 已领取奖励
    NOT_REACH = 3, -- 未达到
}

-- 成就筛选
Enum.ACHIEVEMENT_FILTER_TYPE = {
    ALL = 1, -- 全部
    NOT_FINISH = 2,  -- 未完成
    FINISHED = 3,  -- 已完成
}

Enum.ESTALL_SORT_TYPE = {
    DEFAULT = 0,    --默认(价格最低到高, 相同价格再按时间先后顺序)
    POWER = 1,      --功能未实现
    SKILLNUM = 2,   --功能未实现
    HISPOP = 3,     --功能未实现
    CURPOP = 4,     --功能未实现
    NAME = 5,       --功能未实现
    TIME = 6,   --按过期时间排序(大->小)
    PRICE = 7,  --按价格从低到高排序(目前等价DEFAULT)
}

Enum.EPLAYER_TYPE = {
    RealPlayer = 1, --真实玩家
    Fellow = 2,     --助战伙伴
}

Enum.ESEQUENCE_STATUS = {
    LOCKED = 0,     -- 未解锁
    UNLOCKED = 1,   -- 已解锁
    PICKED = 2,     -- 任务进行中
    READY = 3,      -- 可晋升
    DONE = 4,       -- 完成晋升
}

Enum.ESEQUENCE_CLICK_TYPE = {
    START = 1,
    FINISH = 2,
    TASK_FINISH = 3,
}

-- 击杀者类型
Enum.EKILLER_TYPE = {
    PLAYER = 0,
    NPC = 1
}

-- Trigger 计数方式
Enum.ETRIGGER_LIFE_STYLE = {
    ACCEPT = 1, -- 接取计数
    BORN = 2,   -- 出生计数
}

--HUD 侧边栏
Enum.SIDE_BAR = {
    EWorldBoss = 1,
    EClimbTower = 2,
    EQuest = 3,
    ETeamOrGroup = 4,
    EVoice = 5,
    EFollow = 6,
    EConvene = 7,
    EMark = 8,
    EQuitTeamGroup = 9,
    EQuickTeamUp = 10
}

--标记UI
Enum.EMARK = {
    None = 0,
    TeamGroup = 1,
    Scene = 2,
}

-- 状态冲突类型
---@class Enum.EStateConflictType
Enum.EStateConflictType = {
    ["NO"] = 0,      -- 共存
    ["BLOCK"] = 1,   -- 互斥
    ["REPLACE"] = 2, -- 互斥接续
}

-- 组队跟随方式
Enum.EFollowForm = {
    ["NONE"] = 0,
    ["TRANS_TELEPORT"] = 1,      -- 传送点  
    ["TRANS_INTERACTOR"] = 2,   -- 传送门
    ["TRANS_LINE"] = 3, --切分线
    ["TRANS_DUNGEON"] = 4, --切副本
    ["PATH_FOLLOW"] = 5, -- 寻路 
}

-- 团队申请
Enum.EGroupApplyDataType = {
    ["Reset"] = 1,  --重置
    ["Add"] = 2,      -- 增加  
    ["Del"] = 3,   -- 删除
}

-- 团长 队长
Enum.ETeamGroupRole = {
    ["GroupLeader"] = 1,  --团长
    ["Captain"] = 2,      -- 队长 
    ["None"] = 3,   -- 普通成员
}

-- 角色性别
Enum.EAVATAR_SEX = {
    [0] = "MALE",
    [1] = "FEMALE"
}

--HUD底部tips类型
Enum.EHUD_BOTTOM_TIPS = {
    ["None"] = 0,
    ["ObserverPVP"] = 1,
    ["ObserverPVE"] = 2,
    ["AutoSkill"] = 3,
    ["Follow"] = 4,
	["AutoBattle"] = 5,
}

---鉴定类型，前后端共用，不要改动已有的，要改动已有的要通知前后端，前端：@zhouyuye 后端：@leyiwei
Enum.DiceCheckType = {
    PrivateSceneActor = 0,
    PublicSceneActor = 1,
    PharmacistMystery = 2,
    PharmacistExtraMed = 3,
    PharmacistExtraReturn = 4,
}

--职业形态枚举
Enum.PROFESSION_STATE = {
    MAIN    = 1,        --主形态(默认形态)
    SECOND  = 2,        --副形态
}

Enum.CHAT_EXPRESSION_SHOW_STYLE = {
    ["ALL"] = 0,
    ["All_EMOJ"] = 1,
    ["SYSTEM_EMOJ"] = 2,
}

Enum.MAKEMEDICINE_MYSTERY_EFFECT = {
    EXTRA_MAKE_SELF = 1,
    ADD_BUFF = 2,
    ADD_MORE_EXP = 3,
    DICE_MORE_MED = 4,
    DICE_MORE_RETURN = 5,
}

Enum.SHOP_GOODS_PRICE_TYPE = {
    ["OriginalPrice"] = 0,
    ["Discount"] = 1,
    ["Free"] = 2
}

Enum.CURRENCY_EXCAHNGE_TYPE = {
    SHOP = 0,
    OTHER = 1
}

-- 奖励的行为（功能）的类型
Enum.EDropActionType = {
    DROP_ACTION_USE_ITEM = 1,           -- 使用物品
    DROP_ACTION_GAME_DROP = 2,          -- 探索
}

-- 自动挂机战斗状态
Enum.EAutoFarmingState = {
    STOP_AUTOFARMING = 0,
    ON_AUTOFARMING = 1,
    PAUSE_AUTOFARMING = 2,
}

Enum.BOT_MODE = {
    DEFAULT = 0,        -- 默认
    LEAD = 1,           -- 引领
    FOLLOW = 2,         -- 跟随
    FOCUS_FIRE = 3,     -- 集火
}

-- 不可以动态修改
Enum.ELineType = {
    SAFE = 0, -- 安全分线，默认分线
    FIGHT = 1, -- 战斗分线
}

-- 技能伤害用到标志位枚举
Enum.EDamageFlagType = {
    bHeal      = 1,
    bSteal     = 2,
    bActionHit = 4,
    bActionBlocked = 8,
    bActionCrit = 16,
    bDead       = 32,
    bShallowGrave = 64,
    bImmune = 128,
    bNoType = 256
}


---LoginQueueStateEnum 登录排队状态
Enum.LoginQueueStateEnum = {
    UNKNOWN = {value = -10000, name = "UNKNOWN_LOGIN_QUEUE_STATE"},
    IN_QUEUE = {value = 0, name = "IN_QUEUE"},
    PASS_QUEUE = {value = 1, name = "PASS_QUEUE"},
}
