
-- 前后端公用的基础宏定义，业务模块相关的不要加到这里，加到自己模块对应的XXConst文件

PLAYER_STATUS_NORMAL = 1             --正常在线
PLAYER_STATUS_CLIENT_LOST = 2        --客户端离线

--Teleport 保留的通用类型
--后续可能会有策划基于基础信息配置不同的传送ID
--目前两种类型，只是为了兼容现有的传送表现
TELEPORT_COMMON_TYPE = {
    TELEPORT_NONOE = 0,
    TELEPORT_NEAR  = 1, --近距离传送
    TELEPORT_FAR   = 2, --远距离传送
    TELEPORT_FOLLOW = 3, --跟随传送
    TELEPORT_ESTATEPORTAL = 4
}


--传送的来源
TELEPORT_SOURCE = {
    SKILL = 0,      -- 技能作用的传送
    NORMAL = 1      -- 非技能作用的传送
}

--祭坛占领状态
OCCUPY_DETECT_AREA_STATUS = {
    NOT_ACTIVATE = 0, --未激活
    IN_OCCUPY = 1, --占领中
    IN_BATTLE = 2, --争夺中
    OCCUPIED = 3, --已占领
}

-- 公会联赛相关配置
GUILD_LEAGUE_PREPARE_STAGE = 1 -- 公会联赛准备阶段
GUILD_LEAGUE_BATTLE_STAGE = 2 -- 公会联赛战斗阶段
GUILD_LEAGUE_OVER_STAGE = 3 -- 公会联赛结束阶段

-- 公会活跃度类型
GUILD_TIME_LIVE_TYPE = {
    NONE = 0, -- 还没计算出来，或者没人活跃
    DAY = 1, -- 白天活跃
    NIGHT = 2 -- 晚上活跃
}

---- 先放在这里，后面改到表格里
GUILD_LEAGUE_CAN_KEEP_TIME = 180 -- 公会战结束之后场景保留时间
----

-- 任务事件状态
QUEST_ACTION_STATUS = {
    NONE = 0,
    RUNNING = 1,
    FINISH = 2,
}

-- 时间
MILLISECOND_ONE_SECOND = 1000
SECONDS_ONE_MINUTE = 60
SECONDS_HALF_HOUR = 30 * 60
SECONDS_ONE_HOUR = 60 * 60
SECONDS_FIVE_HOUR = 5 * 60 * 60
SECONDS_ONE_DAY = 60 * 60 * 24
MAX_SECONDS_ONE_MONTH = 60 * 60 * 24 * 31
MONTH_ONE_YEAR = 12
DAYS_ONE_WEEK = 7

--凌晨5点是一天的开始
SECONDS_DAY_START = SECONDS_FIVE_HOUR

MSEC_ONE_MINUTE = 60 * 1000
MSEC_ONE_DAY = 60 * 60 * 24 * 1000
SECONDS_ONE_WEEK = 7 * 24 * 60 * 60
MINUTES_ONE_DAY = 24 * 60
MINUTES_ONE_HOUR = 60
HOURS_ONE_DAY = 24
SECONDS_HALF_DAY = 12 * 60 * 60

FRIEND_SERVER_FRIEND_GROUP_ID               = 0
FRIEND_SERVER_BLACK_GROUP_ID                = 1000
FRIEND_SERVER_STRANGER_GROUP_ID             = 1001
FRIEND_SERVER_NPC_GROUP_ID                  = 1003
FRIEND_SERVER_FOE_GROUP_ID                  = 1004
FRIEND_SERVER_HEREDITARY_GROUP_ID           = 1005
FRIEND_SERVER_CUSTOM_GROUP_ID_START         = 1

-- 属性结算类别
PROP_CALCTYPE_INT = 0
PROP_CALCTYPE_PERCENT = 1

--角色展示相关
VIEW_ROLE_FACE_DATA_SOURCE = {
    TEAM = 0,
    INDIVIDUAL = 1,
}

------------------- 公会 start -----------------
GUILD_STATUS =
{
    INIT = 0,   --创建中
    COMMON = 1, -- 正常状态
    DELETE = 2, -- 删除状态
    MERGE = 3   -- 合并中
}

GUILD_BUILDING_TYPE =
{
    MAIN = 1,    --主城
    PUB = 2,     --酒馆
    VAULT = 3,   --金库
    SCHOOL = 4,   --修炼场
    SHOP = 5,     -- 商店
}

GUILD_QUESTION_TYPE = {
    FIX_ANSWER = 1, -- Option1为固定答案
    ROLE = 2, -- 跟职位有关的问题
    TOTAL_CONTRIB = 3, -- 跟总贡献有关的问题
    ALL_ANSWER = 4 -- 所有都是固定答案
}

GUILD_ROLE_TYPE = {
    COMMON_ROLE = 1, -- 普通职位类型
    HONOR_ROLE = 2, -- 荣誉职位
    GROUP_ROLE = 3 -- 分组职位
}

-- 新增类型，记得处理GuildSimpleInfo:update这个方法
GUILD_LIST_SORT_TYPE = {
    LEVEL_DESC = 100, -- 等级从大到小
    LEVEL_ASC = 101, -- 等级从小到大
    MEMBER_DESC = 102, -- 正式会员从多到少
    MEMBER_ASC = 103, -- 正式会员从少到多
    APPRENTICE_DESC = 104, -- 候补会员从多到少
    APPRENTICE_ASC = 105, -- 候补会员从少到多
}

GUILD_LIST_SORT_TYPE_REVERSE = {}

for k, v in pairs(GUILD_LIST_SORT_TYPE) do
    GUILD_LIST_SORT_TYPE_REVERSE[v] = k
end

-- 新增类型，记得处理GuildSimpleInfo:update这个方法
PRE_GUILD_LIST_SORT_TYPE = {
    RESPONSER_DESC = 200, -- 响应人数从多到少
    RESPONSER_ASC = 201, -- 响应人数从少到多
    RESPONSE_LEFT_TIME_DESC = 202, -- 剩余响应时间从多到少
    RESPONSE_LEFT_TIME_ASC = 203, -- 剩余响应时间从少到多
}

PRE_GUILD_LIST_SORT_TYPE_REVERSE = {}

for k, v in pairs(PRE_GUILD_LIST_SORT_TYPE) do
    PRE_GUILD_LIST_SORT_TYPE_REVERSE[v] = k
end


GUILD_ROLE_TYPE_REVERSE = {}

for k, v in pairs(GUILD_ROLE_TYPE) do
    GUILD_ROLE_TYPE_REVERSE[v] = k
end

GUILD_LIST_PAGE_COUNT = 30

GUILD_ROLE =   --公会职位
{
    FOUNDER = 0,        --领袖
    PRESIDENT = 1,      --会长
    VICE_PRESIDENT = 2, --副会长
    BABY = 3,           --宝贝
    DIRECTOR = 4,       --理事
    EMISSARY = 5,       --使者
    ELITE = 6,          --精锐
    MEMBER = 7,         --会员
    APPRENTICE = 8,     --学徒
    BOSS = 10,          --领袖/会长
    GROUP_LEADER = 11,  --组长
    GROUP_MEMBER = 12,  --组员
}

GUILD_LEAGUE_GROUP_TYPE = {
    FIX = 1, -- 固定组
    SPECIAL = 2, -- 特殊组
    MATCH = 3 -- 匹配组
}

GUILD_LEAGUE_SEASON_STATUS = {
    NONE = 0, -- 未开始
    PREVIEW = 10, -- 开始前的准备
    START = 20, -- 开始
    END = 30 -- 结束
}

GUILD_LEAGUE_ROUND_STATUS = {
    NONE = 0, -- 未开始
    PREPARE = 5, -- 场景创建中
    START = 10, -- 开始
    END = 20, -- 结束
    REWARDED = 30 -- 已发奖
}


GUILD_LEAGUE_GAME_RESULT = {
    NO_RESULT = 0, -- 还未结束
    LEFT_WIN = 1, -- 胜利公会的Index
    RIGHT_WIN = 2 -- 胜利公会的Index
}

GUILD_ROLE_REVERSE = {}

for k, v in pairs(GUILD_ROLE) do
    GUILD_ROLE_REVERSE[v] = k
end

GUILD_SUB_BUILDINGS = {GUILD_BUILDING_TYPE.PUB, GUILD_BUILDING_TYPE.VAULT, GUILD_BUILDING_TYPE.SCHOOL}

GUILD_ANSWER_ACTIVITY_ID = 100
GUILD_NIGHT_ACTIVITY_ID = 101
GUILD_DANCE_ACTIVITY_ID = 102
GUILD_LEAGUE_ACTIVITY_ID = 1

SKILL_BALANCE_LOCK_STATUS = {
    LOCK = -1,
    COMMON = 0,
    UNLOCK = 1,
}

SKILL_BALANCE_TYPE = {
    PROFESSION_SKILL = 1,
    FELLOW_SKILL = 2
}

GUILD_CAMP_ID_NONE = 0
GUILD_ID_NONE = ""

GUILD_SYSTEM_ACTIVITIES = {
    [GUILD_ANSWER_ACTIVITY_ID] = true,
    [GUILD_NIGHT_ACTIVITY_ID] = true,
    [GUILD_DANCE_ACTIVITY_ID] = true
}

GUILD_TYPE = {
    BATTLE = 1,
    FRIEND = 2,
    BUDDHA = 3
}

GUILD_TYPE_REVERSE = {}
for k, v in pairs(GUILD_TYPE) do
    GUILD_TYPE_REVERSE[v] = k
end

GUILD_CREATE_TYPE =
{
    COMMON = 1,   -- 普通
    ADVANCED = 2,  -- 高级
    SYSTEM = 3, -- 系统
}

-- 远航任务状态
VOYAGE_TASK_STATUS = {
    PROCESSING = 1, -- 进行中
    TO_AWARD = 2, -- 完成未领取
    AWARDED = 3 -- 奖励已领取
}

GUILD_RIGHT_TRUE = 1           --默认权限
GUILD_RIGHT_VARIABLE_TRUE = 2  --可变更权限(默认勾选)
GUILD_RIGHT_VARIABLE_FALSE = 3 --可变更权限(默认不勾选)
GUILD_RIGHT_FALSE = 4          --禁止权限

LIMIT_DEL_GUILD_ROLE = -- 禁止删角的公会职位
{
    [GUILD_ROLE.FOUNDER] = true,
    [GUILD_ROLE.PRESIDENT] = true,
    [GUILD_ROLE.BOSS] = true
}

GUILD_BATCH_APPLY_LIMIT = 20

GUILD_ANSWER_STAGE = {
    COUNTDOWN = 1,
    ANSWERING = 2,
    INTERVAL = 3,
    OVER = 4
}

GUILD_INVITE_RESULT = {
    AGREE = 1,
    REFUSE = 2,
    TIMEOUT = 3
}

GUILD_TITLE_ID = 11

GUILD_FUNDS_SOURCE =
{
    USE_ITEM = 1,
    GUILD_ROBBER = 2,
}

GUILD_RIGHT =   --公会权限
{
    PRESIDENT = 1,   --会长任免
    BABY = 2,        --任免宝贝
    POSITION_SET = 3,--设置职位
    INFO_SET = 4,    --设置公会的一些内容
    CONSTRUCTION = 5,--公会建设
    ACTIVITY = 6,    --开启活动
    MEMBER = 7,      --管理入会
    MERGE = 8,       --合并处理
    APPRENTICE = 9,  --学徒转正
    KICKOUT = 10,    --请离公会
    MODIFY_NAME = 11,--修改公会名称
    GROUP_MESSAGE = 12,--群发消息
    RESIGN = 13,      --辞职
    AUTO_RECEIVE = 14,--设置自动接受学徒
    SKILL = 15,       --设置可修炼技能
    SET_COMMAND = 16,  --设置指挥权限
    SET_LOGO = 17,      --设置logo
    MODIFY_PRESIDENT_STATUE = 18,   --设置会长雕像
    SET_BADGE_FRAME = 19,   --设置徽章框
    SET_ELITE = 20,   --设置精英
    BAN_ROOKIE_BID = 21,--设置禁止新人参与拍卖
    SET_GUILD_LEAGUE_ELITE = 22, -- 设置公会联赛成员
    CHANGE_GUILD_BABY_NAME = 23, -- 修改吉祥物名称
    SEND_GUILD_MAIL = 24, -- 群发公会邮件
    CHANGE_GUILD_BACKGROUND = 25, -- 修改公会背景
    SET_GUILD_TYPE = 26, -- 修改公会类型
    GROUP_NAME = 27, -- 修改公会组的名字
    GROUP_CONTROL = 28, -- 修改公会组的成员
}

GUILD_QUIT_REASON =
{
    CANCEL_RESPOSE = 0, -- 取消响应
    MANAGER_KICK = 1,   -- 管理员踢人
    QUIT_SELF = 2,      -- 自己退出
    SYSTEM_KICK = 3,    -- 系统踢人
    GUILD_DISBAND = 4,  -- 公会解散
    CREATE_FAIL = 5,    -- 创建失败
    REMOVE_ROLE = 6,    -- 删角
}
------------------- 公会 end -----------------

------------------- 道具 start -----------------
-- 道具分组抽取方式（概率和圆桌）
EXTRACT_MODE_PROBABILITY = 0            -- 单独随机
EXTRACT_MODE_PROPORTION = 1             -- 权重
EXTRACT_MODE_PROPORTION_OVERFLOW = 2    -- 圆桌

INV_BOUND_TYPE_INSENSITIVE = 1
INV_BOUND_TYPE_BOUND = 2
INV_BOUND_TYPE_UNBOUND = 3

--道具提交类型
ITEM_SUBMIT_TYPE = {
    NORMAL_SUBMIT        = 0,   --直接提交
    SAME_TYPE_SUBMIT     = 1,   --选择提交：同类道具，固定数量
    SPECIAL_SUBMIT       = 2,   --选择提交：特殊道具，固定数量
    FREE_SUBMIT          = 3,   --选择提交: 自选道具、自选数量
}

ITEM_LOOP_USE_ONE_FRAME_NUM = 10  -- 道具批量使用单帧数量

CONSUME_INV_SOURCE = {
    INV = 1,
    WAREHOUSE = 2,
}

-- 刷新方式
DAY_REFRESH_TYPE      = 1     -- 每天刷新
WEEK_REFRESH_TYPE     = 2     -- 每周刷新
MONTH_REFRESH_TYPE    = 3     -- 每月刷新
QUARTER_REFRESH_TYPE  = 4     -- 每季度刷新
NOT_REFRESH_TYPE      = 5     -- 终身限次
------------------- 道具 end -----------------

--消息数据刷新类型
MSG_DATA_TYPE=
{
    RESETALL    = 1,
    ADD         = 2,
    RMV         = 3,
    UPDATE      = 4,
}

STALL_RECORD_STATE = {
    CENSORING = 1,
    SUCCESS = 2,
    FAILED = 3,
    EXTRACTED = 4,
}

--摆摊出售状态
STALL_SELL_STATUS = {
    SELLING         = 1,    --在售中
    PUBLIC          = 2,    --公示期
    OVERTIME_TYPE   = 3,    --过期
}

--战斗数据统计的技能类型
BATTLE_STATISTIC_SKILL_TYPE = {
    NORMAL_SKILL = 0,      --普通技能
    ELEMENT_EFFECT = 1,    --元素伤害
    PASSIVE_SKILL = 2,     --被动技能
    SPECIAL_BUFF = 3,      --指定buff
}

------------------- 邮件系统 start -----------------
MAIL_ID_FROM_NULL = 0
MAIL_ID_FROM_GM_DELETE = 1  -- 运营预留的邮件模板，1为提取附件后删除
MAIL_ID_FROM_GM_SAVE = 2    -- 运营预留的邮件模板，2为提取附件后不删除

MAIL_TYPE_TEXT       = 1  -- 纯文本邮件
MAIL_TYPE_ATTACHMENT = 2  -- 有附件邮件
MAIL_TYPE_FIND_NPC   = 3  -- 寻路到NPC邮件
MAIL_TYPE_GIVE_GIFT  = 4  -- 送礼邮件

MAIL_CATEGORY_SYSTEM      = 1 -- 系统邮件
MAIL_CATEGORY_GUILD = 2  -- 俱乐部邮件
MAIL_CATEGORY_NPC         = 3 -- NPC邮件
MAIL_CATEGORY_ARBITRATOR_TRIAL = 4 -- 仲裁人惩戒邮件


MAIL_SAVE_TIME_WHEN_READ = 7 * 24 * 60 * 60 -- 邮件读取以后的保存时间(s)
------------------- 邮件系统 end -----------------


-- 私聊
WHISPER_CHAT = 0

-- 聊天称号状态
CHAT_TITLE_STATUS = {
    NONE_USE_TITLE = 0,  -- 没有可以使用的称号
    BAN_USE_TITLE = -1   -- 禁止使用称号
}

CHAT_CUSTOM_IMG_STATUS = {
    APPROVED = 1, -- 审核通过
    REJECTED = 2, -- 审核拒绝
	MACHINE = 3, -- 机器审核
	MANUAL = 4 	--人工审核
}

--好友系统相关
FRIEND_SYSTEM_PLAYER_STATE = {
    DEL = 0,        -- 删角，涉及到角色列表服务，不可轻易改动值
    ONLINE = 1,     -- 在线
    AFK = 2,        -- 暂离
    OFFLINE = 3     -- 离线
}

FRIEND_SYSTEM_PLAYER_HIDE_STATUS = {
    SHOW_ALL = 0,
    PART_SHOW = 1,
    PART_HIDE = 2,
    HIDE_ALL = 3,
}

-- 商会类型
COMMERCE_SHOP_TYPE_BOUND = 1

-- 组队
TEAM_NO_TEAM                    = 0    -- 没有队伍
TEAM_MEMBER_MAX_NUMBER          = 5    -- 最大数量队员
TEAM_RECRUIT_LIMIT_TIME         = 15    -- 组队喊话限制时间

-- 组团
GROUP_NO_GROUP = 0 -- 没有团队
GROUP_PAGE_COUNT = 5 -- 5个分页
GROUP_TEAM_COUNT = 6 -- 每个分页6个队伍
GROUP_MEMBER_MAX_COUNT = GROUP_PAGE_COUNT * GROUP_TEAM_COUNT * TEAM_MEMBER_MAX_NUMBER
GROUP_DEFAULT_PAGE_INDEX = 1
GROUP_DEFAULT_TEAM_INDEX = 1
GROUP_MANAGER_MAX_COUNT = 5 -- 团队最大管理数量
GROUP_TOPLOGO_MAX_COUNT = 3 -- 团队最大标记数量

DEFAULT_ALL_TARGET_ID = 5300001
DEFAULT_NO_TARGET_ID = 5300002
WORLD_BOSS_TARGET_ID = 5300011      -- 世界Boss组队索引

GIFT_RANK_SHOW_COUNT = 10

ADD_NPC_FRIEND_CHANNEL_ID = 19

GM_PARAM_TYPE = {
    NONE = 0, -- 无可选值
    NUMBER = 1, -- 给出个取值范围
    TABLE_DATA = 2, -- 从配置表里面读取
    ENUM = 3, -- 枚举
    BOOL = 4, -- bool类型
}

CHAT_BLOCK_MAX_NUM = 20 -- 聊天屏蔽用户最大数量

GM_CUSTOMER_SERVICE_GBID = 520

NULL_GBID = ""

CLIMB_TOWER_FRIEND_HELP_TYPE = {
    ONLINE_FRIEND = 1,  --在线好友
    GUILD_MEMBER = 2,   --公会成员
    PASSERBY = 3,       --随机路人
}

WARE_HOUSE_UNLOCK_TYPE = {
    LOCKED = 0,
    CAN_UNLOCK = 1,
    UNLOCKED = 2,
}

--玩家对战模式类型
FIGHT_MODE_TYPE = {
    PEACE_MODE = 1,      --理智模式
    TRIAL_MODE = 2,      --狩猎模式
    FIGHT_MODE = 3,      --疯狂模式
}

--地图安全区类型
MAP_FREE_ZONE_TYPE = {
    FREE_WITH_RED_NAME = 1,      --自由区
    SAFE_WITH_RED_NAME = 2,      --显示红名的安全区
    SAFE = 3,      --不显示红名的安全区
}

HREF_TTPE =
{
    STOP_WHISPER = "stopWhisper",
}

-- 副本相关
DUNGEON_TYPE = {
    NONE = 0,
    SINGLE = 1,
    TEAM = 2,
}

DUNGEON_BUFF_CONDITION = {
    DUNGEON_OPEN = 1, -- 副本开放后x天
    FIRST_COMPLETE = 2, -- 首通后x天
    DIFFERENT_CLASS = 3 --  队伍中有x个不同职业
}

DUNGEON_MODE = {
    ROBOT = 1, -- 人机模式
    NO_ROBOT = 2 -- 非人机模式
}

DUNGEON_MODE_REVERSE = {}
for k, v in pairs(DUNGEON_MODE) do
    DUNGEON_MODE_REVERSE[v] = k
end

QUALITY_WHITE = 1

-- 职业
SCHOOL_ALL = 0

HOST_ID_OFFSET = 100000

SILENT_GRAVE_DETECT_RANGE = -1

-- 性别
AVATAR_GENDER_NONE = 0
AVATAR_GENDER_MALE = 1
AVATAR_GENDER_FEMALE = 2
AVATAR_GENDER_SECRET = 3

--敌对关系类型
FIGHT_RELATION = {
    BE_ATTACK = 1,        --受击
    ACTIVE_ATTACK = 2,    --主动攻击
}

--拍卖类型
BID_TYPE = {
    WORLD_BID            = 1,   --世界拍卖
    GUILD_BID            = 2,   --公会拍卖
}

--世界/公会拍卖状态
BID_STATUS = {
    BID_STATUS_NONE      = 0,   --未开启
    BID_STATUS_PREPARE   = 1,   --准备阶段
    BID_STATUS_STARTING  = 2,   --拍卖阶段
    BID_STATUS_END       = 3,   --拍卖结束
}

--世界/公会道具拍卖状态
ITEM_BID_STATUS = {
    BID_STATUS_NONE      = 0,   --待拍    (没有玩家参与举牌竞价的在拍商品)
    BID_STATUS_BIDING    = 1,   --在拍
    BID_STATUS_PURCHASE  = 2,   --购得
    BID_STATUS_FAIL      = 3,   --流拍
    BID_STATUS_SELL      = 4,   --售出
}

RECEIVE_TASK_TYPE = {
    NULL = 0,
    SEQUENCE_TASK = 1,   -- 手动接取序列晋升类型任务
    ABANDON_QUEST = 2,
}

-- 扮演手册 命运启示刷新概率分母
SCHEDULE_FATE_REVELATION_APPEAR_PROBABILITY_DENOMINATOR = 10000

-- san值改变来源
BOUNTY_CHANGE_SOURCE = {
    RP_ARBITRATOR = 2,
    RP_SHERIFF = 3,
}

-- 仲裁人身份审判类型
ARBITRATOR_TRIAL_TYPE = {
    NO_TRAIL = 0, -- 未审判
    TRIAL = 1, -- 主动审判
    TRIALLED = 2 -- 被审判
}

-- 检定结果类型
DICE_RESULT = {
    NONE = 0,           -- 非法状态
    HUGE_FAILURE = 1,   -- 大失败
    FAILURE = 2,        -- 失败
    SUCCESS = 3,        -- 成功
    HUGE_SUCCESS = 4    -- 大成功
}

ROLEPLAY_REWARDNPC_TASK_LEVEL = {
    REWARDLEVEL_A = 1,   -- A级别
    REWARDLEVEL_B = 2,   -- B级别
    REWARDLEVEL_C = 3,   -- C级别
}

--目标追踪类型
TARGET_TRACK_TYPE = {
    NONE = 0,
    TASK = 1,
    MAP = 2,
    DUNGEON_TASK = 3,
}

-- 对战模式override关系优先级
FIGHT_MODE_PRIORITY = {
    FIGHT_MODE = 3000,           -- 对战模式 & 绿名保护
    LEVEL_PROTECT = 3001,        -- 等级保护
    GUILD_PROTECT = 3002,        -- 公会保护
    FIGHT_RELATION = 3010,       -- 私有敌对关系
    TEAM = 3020,                 -- 队伍关系 & 团队关系
    SAFE_ZONE = 3030,            -- 安全区玩家关系
}

ROLEPLAY_SHERIFF_SKILL_TYPE = {
    ATTACK_SKILL = 1, --伤害加成技能
    DEFENSE_SKILL = 2, --防御加成技能
    REWARD_SKILL = 3, --奖励加成技能
    ATTACK_SKILL_ID = 4, --进攻skill的ID
    ATTACK_SKILL_LEVEL = 5, --进攻skill的level
    DEFEND_SKILL_ID = 6, --防御skill的ID
    DEFEND_SKILL_LEVEL = 7, --防御skill的level
}

CALL_ENTITY_COMPONENT_STAGE = {
    PropInit = 'PropInit',              -- 用于local entity做属性的初始化，防止local entity没有属性数据报错
    
    -- 客户端组件阶段添加
    LoadActor = 'LoadActor',                -- Entity通知加载UEActor(外观参数收集,预算投放,预加载资源)
    EnterWorld='EnterWorld',                -- entity进入场景创建Character之后调用，用于一些依赖于场景或者模型表现的逻辑初始化
    AfterEnterWorld = 'AfterEnterWorld',    -- 用于有时序依赖逻辑，只放一些必须在EnterWorld之后执行的逻辑
    ExitWorld='ExitWorld',                  -- 一般entity在ExitWorld的时候就销毁了，主要用于MainPlayer的场景退出逻辑，其他类型Entity可直接在dtor中编写
    AfterExitWorld = 'AfterExitWorld',      -- 用于有时序依赖逻辑，只放一些必须在ExitWorld之后执行的逻辑
    
    RebuildAttr = 'RebuildAttr',            -- 断线重连恢复
    AfterLoadActor = "AfterLoadActor",
    
    ActorViewLodChanged = 'ActorViewLodChanged',

    BeforeStartMorph = 'BeforeStartMorph',
    AfterLoadActorForStartMorph = 'AfterLoadActorForStartMorph',
    AfterStartMorph = 'AfterStartMorph',

    BeforeEndMorph = 'BeforeEndMorph',
    AfterLoadActorForEndMorph = 'AfterLoadActorForEndMorph',
    AfterEndMorph = 'AfterEndMorph',

    BeginMorphPlay = 'BeginMorphPlay', -- 变身结束后的表演阶段开始
    EndMorphPlay = 'EndMorphPlay', -- 变身结束后的表演阶段结束

	AppendGamePlayDebugInfo = 'AppendGamePlayDebugInfo',
}

-- entity 的当前阶段
SCENE_ENTITY_STAGE = {
    INIT = 'INIT',                              -- 初始化阶段
    LOADING_CHARACTER = 'LOADING_CHARACTER',    -- 加载阶段
    SPAWN = "SPAWN",                            -- 加载完成
    AFTER_ENTER_WORLD = 'AFTER_ENTER_WORLD',    -- 进入场景后阶段，所有组件已经EnterWorld
    AFTER_EXIT_WORLD = 'AFTER_EXIT_WORLD',      -- 退出场景后阶段，所有组件已经ExitWorld
    DESTROY = 'DESTROY',                        -- 销毁阶段
}
              
ROLEPLAY_SEQUENCE_IDENTITY_TYPE = {
    PASSIVE_TYPE = 1,
    NEGATIVE_TYPE = 2,
}

--场景节点类型
MAP_NODE_DATA_TYPE = {
    INTERACTOR    = "1",      --交互物
    ACTOR         = "2",
    PREFAB        = "3",
}

--祭坛占领状态
OCCUPY_DETECT_AREA_STATUS = {
    NOT_ACTIVATE = 0, --未激活
    IN_OCCUPY = 1, --占领中
    IN_BATTLE = 2, --争夺中
    OCCUPIED = 3, --已占领
    FINAL_COMPLETE = 4, --完全激活
}

-- 战斗Effect类型
COMBAT_EFFECT_TYPE = {
    TRIGGER_KEEP = 1,		-- 直接生效，在effect添加开始执行action，effect移除执行action end，这里只能配置持续性action
    TRIGGER_REPEAT = 2,			-- 时间间隔生效，有最大生效次数，这里只能触发非持续性action
    TRIGGER_BY_EVENT = 3,		-- 事件触发，事件触发后执行action，只能触发非持续性action，如果未配置事件，只配置了条件，则只能配置持续性action，条件满足后触发action，条件不满足或移除执行action end
}

-- 战斗触发条件目标类型
COMBAT_EFFECT_CONDITION_TARGET_TYPE = {
    OWNER = 0, -- 持有者
    INSTIGATOR = 1, -- 始作俑者
    TRIGGER = 2, -- 触发者
    TARGET = 3, -- 锁定目标
    COMMON_ATTACKER = 4, -- 伤害结算流程中 OnAfterReceiveDamage/OnAfterApplyDamage 事件的攻击者
    COMMON_DEFENDER = 5, --  伤害结算流程中 OnAfterReceiveDamage/OnAfterApplyDamage 事件的受击者
    BBV_SEARCH_TARGETS = 6, -- 隐式黑板中的SearchTargetList
    BUFF_LINKED_TARGET = 7, -- Buff连线目标
    BUTTON_INTERACT_TRIGGER = 11, -- 战斗按钮交互的触发者
    ALL_TARGET = 12, -- switch effect 使用，表示传入的所有目标生效
    ANY_TARGET = 13, -- switch effect 使用，表示传入的任意目标生效
}


SWITCH_FRAME_COMBAT_EFFECT_TASK_TARGET_TYPE = {
    Target = -1,  -- 对单个目标
    Self = -2,  -- 对自己
    AttackTargetList = -3,  -- 对结算目标
}

-- 战斗触发条件关系类型
CONDITION_RELATION_TYPE = {
    AND_ALL = 0,        -- 所有条件and结果
    OR_ALL = 1,         -- 所有条件or结果
    NOT_AND_ALL = 2,    -- 所有条件and结果，再取反
    NOT_OR_ALL = 3,     -- 所有条件or结果，再取反
    SINGLE = 4,
    NOT = 5,
}

-- 战斗效果Task目标类型
COMBAT_EFFECT_TASK_TARGET_TYPE = {
    OWNER = 0, -- 持有者
    INSTIGATOR = 1, -- 始作俑者
    TRIGGER = 2, -- 触发者
    TARGET = 3, -- 锁定目标
    COMMON_ATTACKER = 4, -- 伤害结算流程中 OnAfterReceiveDamage/OnAfterApplyDamage 事件的攻击者
    COMMON_DEFENDER = 5, --  伤害结算流程中 OnAfterReceiveDamage/OnAfterApplyDamage 事件的受击者
    BBV_SEARCH_TARGETS = 6, -- 隐式黑板中的SearchTargetList
    BUFF_LINKED_TARGET = 7, -- Buff连线目标

    PRIORITY_LOCK_TARGET = 10, -- OnAfterApplyDamage/OnApplyHeal 海之言被动技能的优先级目标
    BUTTON_INTERACT_TRIGGER = 11, -- 战斗按钮交互的触发者
}

TASK_INTERRUPT_TYPE = {
    BIND_STATE = 0,     -- 跟随state结束
    BIND_SKILL = 1,     -- 跟随技能结束
    NOT_INTERRUPT = 2,  -- 不结束
    ONLY_BIND_SKILL = 3, -- 只跟随技能结束
}

TASK_STATE_DATA_TYPE = {
    NONE = 0,            -- 无状态
    WITH_STATE = 1,      -- 有状态
}

STATIC_BLACK_BOARD_KEY_TYPE = {
    -- 技能和buff公用
    instigatorID = 'instigatorID',
    triggerID = 'triggerID',
    rootSkillID = 'rootSkillID',
    rootBuffID = 'rootBuffID',
    insID = 'insID',    -- 技能或者buff的实例唯一id
    level = 'level',

    attackTargetsNum = 'attackTargetsNum', -- 存的是当前attack流程结算目标的数量，不存在时为nil
    attackTargetsList = 'attackTargetsList', -- 存的是当前attack流程结算目标list
    attackBoxCenter = 'attackBoxCenter',  -- 当前 attack 的攻击盒中心位置
    attackBoxYaw = 'attackBoxYaw',  -- 当前 attack 的攻击盒朝向

    commonAttackerID = 'commonAttackerID',
    commonTargetID = 'commonTargetID', 
    
    -- buff effect专用，需在prop中定义
    buffID = 'buffID',
    buffInstID = 'buffInstID',
    layer = 'layer',
    buffTotalLife = 'buffTotalLife',
    buffStartTimeStamp = 'buffStartTimeStamp',
    linkedTargetId = 'linkedTargetId',  -- buff连线目标
    bFromPassive = 'bFromPassive',  -- 是否来自被动技能
    
    -- 技能 ability专用
    skillID = 'skillID',
    speed = 'speed',
    lockTarget = 'lockTarget',
    inputPos = 'inputPos',
    inputDir = 'inputDir',
    isAttackMiss = 'isAttackMiss', -- 是否是Attack task miss，true表示是miss，false表示不是miss，默认是nil
    
    -- 被动技能 effect专用

    -- 技能隐式黑板专用
    searchTargetList = 'searchTargetList',  -- 存的是entity int id，不存在时为nil
    searchTargetListLength = 'searchTargetListLength', -- 存的是searchTargetList数量，不存在时为nil
    searchTargetNotEntity = 'searchTargetNotEntity',   -- 存的searchTargetList是否是非entity(自己的创生物可能是非entity)
    searchPosList = 'searchPosList',

    -- 伤害结算(修正)
    hurtOutCtx = 'hurtOutCtx',  -- 伤害上下文，对应伤害结算里面的FDOut, 主要修正hurtOutCtx.OutHurt值（修正前的值hurtOutCtx.InTotalHurt)
    overflowHeal = 'overflowHeal',  -- 溢出治疗值

    rotateID = 'rotateID',      -- 存储的是该技能Instance最近一次持续性rotate所对应的id，避免RotateStop的时候错误打断

    -- Condition 专用
    eventCD = 'eventCD',        -- 用于在 Condition 限制 Event 成功触发的频率
	
    -- 连线特效专用
    LinkTarget = "LinkTarget", -- 连线特效目标
}

TASK_DYNAMIC_KEY_TYPE = {
    propModifyList = "propModifyList",
    coverSetPropModeCMList = "coverSetPropModeCMList",
    fStatePropModifyList = "fStatePropModifyList",
    coverSetFStatePropMList = "coverSetFStatePropMList",
    limitFightActionOperateId = "limitFightActionOperateId",
    setFightActionLimitRecord = "setFightActionLimitRecord",
    extraHurtMultiOperateId = "extraHurtMultiOperateId",
    resourceAddRangeTimer = "resourceAddRangeTimer",
    resourceConsumeRangeTimer = "resourceConsumeRangeTimer",
    resourceAdjustSpeed = "resourceAdjustSpeed", -- 用于对战斗资源改变速率调整的恢复
    oldWeaponValueList = "oldWeaponValueList",

    -- 用于持续攻击
    attackRangeTrapId = "attackRangeTrapId",
    attackRangeInstID = "attackRangeInstID", -- 用于带有偏移的持续攻击

    buffStateSetSuc = "buffStateSetSuc",

    delayCreateBulletTimerList = "delayCreateBulletTimerList",

    delayCreateBuffLayerBulletTimerList = "delayCreateBuffLayerBulletTimerList",

    attackInstID = 'attackInstID', -- 攻击实例Id(用于标识一次攻击，单次攻击可能是个aoe，有时候单次攻击的某些效果有人数上限)

    rotateFixedDirectionTimer = "rotateFixedDirectionTimer", -- 暂时用于 Rotate, 固定方向(顺/逆时针)旋转的 timer, 后续下沉到插件
    oldTimeStamp = "oldTimeStamp",                           -- 暂时用于 Rotate, 记录执行上次 timer 的时间

    keepBuffTargetIdList = "keepBuffTargetIdList",

    -- 客户端Task使用
    HandleID = "HandleID",
    ASTPlayNiagaraViewBudgetToken = 'ASTPlayNiagaraVBT',
    
    MeshFollowBoneCompGID = "MeshFollowBoneCompGID",
    OriginMoveDriveMode = "OriginMoveDriveMode",--原本的mode
    ViolentRotation_LR_Finishs = "ViolentRotation_LR_Finishs",--目标旋转，最后做矫正用
    ViolentRotation_ProxyIDs = "ViolentRotation_ProxyIDs",--代理ID，之后删除


    -- 资源加载句柄ID
    ResourceHandle = "ReSourceHandle",

    oldCurSpeed = "oldCurSpeed",
    CreateRandomSpellFieldsTimers = "CreateRandomSpellFieldsTimers", -- CreateRandomSpellFieldsTimers 的times => {eid1:tid1, eid2:tid2, ...}

    -- rootmotion使用
    rmEntityIID = "rmEntityIID", -- 执行rootMotion的int_id
    rmID = "rmID",   -- RootMotionID

    MultiMovementTimersKey = "MultiMovementTimersKey",

    -- movable attack 使用
    movableAttackTimer = "movableAttackTimer",
    curAttackCount = "curAttackCount",
    targetHitCDCtx = "targetHitCDCtx",

    -- ExploreElementRange 使用
    exploreElementTimer = "exploreElementTimer",
    exploreElementID = "exploreElementID",
    elementDuration = "elementDuration",
    selectionRuleID = "selectionRuleID",

    -- 判断持续性task是否因为到了结束帧而执行End
    bTaskEndFrameReached = "bTaskEndFrameReached",

    -- material effect使用
    ChangeMaterialReqId = "ChangeMaterialReqId",
    ChangeMaterialParamReqId = "ChangeMaterialParamReqId",
	
    rotateID = 'rotateID',      -- 存储的是持续性rotateTask所对应的rotateID，避免RotateStop的时候错误打断

    execTimeStamp = 'execTimeStamp',
    AttackSoundToken = "AttackSoundToken", -- 播放音效Task的Token

    AttackNiagaraToken = "AttackNiagaraToken", 
    AttackRandomNiagaraToken = "AttackRandomNiagaraToken",
    AttackRandomTableNiagaraToken = "AttackRandomTableNiagaraToken",

    MaterialToken = "MaterialToken",
    GhostToken = "GhostToken",
    GhostTimer = "GhostTimer",
    GhostMaterialReqId = "GhostMaterialReqId",
    GhostActorIds = "GhostActorIds",

    -- 子弹发射timer
    spawnBulletTimer = "spawnBulletTimer",

    NotUpdateBoundsSKComps = "NotUpdateBoundsSKComps",
}

SKILL_PRESS_TYPE = {
    DOWN = 0,
    UP = 1
}

USE_ITEM_POS_TYPE = {
    ENTER_TRAP = 1,
    LEAVE_TRAP = 2,
}
-- 占卜的类型
FORTUNE_TYPE = {
    NORMAL_FORTUNE = 1, --普通占卜
    SWITCH_FORTUNE = 2, --转运占卜
}

BATTLE_ZONE_SHAPE = {
    CIRCLE = 0,
    SQUARE = 1,
}

QTE_RESULT_TYPE = {
    Succ = 1,
    Failed = 2,
    Break = 3,
}

HEADINFO_TYPE = {
    HP = 0,
    Title = 1,
    Name = 2,
    Guild = 3,
    Icons = 4,
    Buffs = 5,
    Bubble = 6,
    PVPHonor =7,
    TeamSig = 8,
    GM_EntityID = 9,
}

LINK_NIAGARA_AGENT_TYPE = {
	TARGET = 0,  -- 对象entity
	GHOST = 1, -- 残影
	SPELL_FIELD_MESH = 2, -- 法术场中mesh
}

WITCH_REPLY = {
    NO_REPLY = 0, --到点没有回复
    NOT_AVAILABLE = 1, --直接拒绝
    BE_SLAVE = 2,  --直接开舔
    DICE_CHECK_SLAVE = 3,  --骰子比拼
}

FORTUNE_REPLY = {
    NO_REPLY = 0, --到点没有回复
    AGREE_FORTUNE = 1,  --直接同意
    DISAGREE_FORTUNE = 2, --直接拒绝
}

GIVE_REWARD_TYPE = {
    CONSUME_ITEM = 1,
    FLOWER = 2,
    EGG = 3,
}

WITCH_INTERACT_ACTION = {
    HUG = 1,    --拥抱
}

ROLEPLAY_INTERACT_ANIMATION = {
    STAND_UP = 1,
    SIT_ON_FORTUNE_CHAIR = 2,
    SLEEP_ON_WITCH_CHAIR = 3,    
}

ROLEPLAY_ANIMATION_STATUS = {
    NONE_STATUS = 1, --无任何状态
    SPAWN_FORTUNE_DESK = 2, --召唤占卜摊子并且坐下
    SPAWN_WITCH_CHAIR = 3, --召唤魔女躺椅并且躺下
    DOUBLE_PEOPLE_WITCH_CHAIR_POSITIVE = 4, --魔女双人交互动作床上那个
    JOKER_BALL_PLAY = 5, -- 小丑抛球
    JOKER_CYCLE_PLAY = 6, -- 小丑踩车
    JOKER_HAT_PLAY = 7, -- 小丑玩帽子
    JOKER_BALL_PLAY_SUCCESS = 8, --小丑抛球成功
    JOKER_BALL_PLAY_FAIL = 9, --小丑抛球失败
    JOKER_CYCLE_PLAY_SUCCESS = 10, --小丑独轮车成功
    JOKER_CYCLE_PLAY_FAIL = 11, --小丑独轮车失败
    JOKER_HAT_PLAY_SUCCESS = 12, --小丑帽子成功
    JOKER_HAT_PLAY_FAIL = 13, --小丑帽子失败
    DOUBLE_PEOPLE_WITCH_CHAIR_NEGATIVE = 14, --魔女双人交互动作床下那个
}

ROLEPLAY_ANIMATION_STATUS_REVERSE_DICT = {
    1, --无任何状态
    2, --召唤占卜摊子并且坐下
    3, --召唤魔女躺椅并且躺下
    4, --魔女双人交互动作床上那个
    5, -- 小丑抛球
    6, -- 小丑踩车
    7, -- 小丑玩帽子
    8, --小丑抛球成功
    9, --小丑抛球失败
    10, --小丑独轮车成功
    11, --小丑独轮车失败
    12, --小丑帽子成功
    13, --小丑帽子失败
    14, --魔女双人交互动作床下那个
}

USERLINE_TYPE = {
    TEAM_USER_LINE = 1,
    ROLEPLAY_WITCH_USER_LINE = 2,    
}


SceneActorBelongType = {
    Public = 0,    -- 公有
    Private = 1,   -- 私有
}

SceneActorInsType = {
    Default = 0,    -- 直接出生 
    SystemCall = 1, -- 外部系统刷出
}

FOLLOW_TRAP_STATUS = {
    DONT_CARE = 0,
    OUT_FOLLOW_TRAP = 1,
    IN_FOLLOW_TRAP = 2,
}

--从1开始
FASHION_STAIN_MAX_SLOT_NUM = 4

--代表不选择
FASHION_STAIN_SLOT_NOT_SELECT = 0

--普通染色判断
FASHION_STAIN_TYPE_NORMAL = "0"

--高级染色判断
FASHION_STAIN_TYPE_ADVANCED = "1"

NPC_WARNING_VALID = {
    DONT_CARE = 0,
    WARNING_INVALID = 1,
    WARNING_VALID = 2,
}

SKILL_ROUTTLE_STATE = {
    Battle = 0,
    RolePlay = 1,
    Action = 2,
    InvisibleHand = 3
}

GUILD_DANCE_LOTTERY_TYPE = {
    NOTHING = 1,
    COMMON = 2,
    MEDIUM = 3,
    RARE = 4
}

ULTIMATEPOINT_UPDATE_FREQUENCY = 5
-- 追踪目标类型
TRACING_INFO_TYPE = {
    NONE = 0,
    TASK = 1,
    MAP = 2,
    DUNGEON_TASK = 3,
    ACTIVITY_HUD = 4,
    ACTIVITY_POPUP = 5,
    CHAT = 6,
    MAP_TAG = 7,
    NEWBIETASK = 8,
    AXIS = 9,       --坐标点追踪
    SCENE_MARK = 10, --公会联赛场景标记
    MAX_VALUE = 11, -- 用于判断最大值,增加的时候后移
}

--追踪类型
TRACING_TYPE = {
    TASK = 1,
    MAP_TAG = 2,
    OTHER = 3, -- 暂时不用了，只分1任务和2地图追踪
    SECOND_TASK = 4,
    MAX_VALUE = 5, -- 用于判断最大值,增加的时候后移
}

ENBALE_INTERACT_VALUE = {
    ALL = 0, --可以随便交互，任意交互
    ONLY_WITH_PLAYER = 1, ---只可以与玩家交互
    ONLY_WITH_INTERACTOR = 2, ---只可以与交互物交互
    NONE = 3, ---不可以进行任何交互
}

DANCE_ACTIVITY_TYPE = {
    INVALID = 0,
    SINGLE_CHALLENGE = 1,       -- 单人挑战
    DOUBLE_CHALLENGE = 2,       -- 双人挑战
    SINGLE_PERFORM = 3,         -- 单人表演
    DOUBLE_PERFORM = 4,         -- 双人表演
    MULTI = 5,                  -- 群舞
    PARADE = 6,                 -- 游行
    MAX = 7
}

-- 舞会交互记录类型
DANCE_ACT_TYPE = {
    INVALID = 0,
    TEA = 1,            -- 茶点
    WINE = 2,           -- 品酒
    DANCE_SCORE = 3,    -- 舞蹈等级到达良好
}

DANCER_INFO_STATE = {
    PREPARE = 1,        -- 准备阶段
    READY = 2,          -- 已就绪
    GAMING = 3,         -- 进行中
    LEAVE = 4,          -- 已离开
    FINISHED = 5,       -- 已完成
    SETTLED = 6,        -- 已结算
    DISCONNECT = 7,     -- 断线
}

-- 玩家之间关系定义(不要随意改，有修改同步到 @fuzuotao)
PLAYER_RELATION_TYPE = {
    NONE = 0,           -- 没啥关系
    TEAM_MATE = 1,      -- 小队队友
    GROUP_MATE = 2,     -- 团队队友
    LOVER = 3,          -- 情缘关系
    SWORN_BROTHERS = 4, -- 结义关系
    ENEMY = 5,          -- 敌对关系
}

-- 特效初始朝向定义
EFFECT_INIT_ORIENT = {
    TARGET = 0, -- 目标轴向
    SELF = 1,   -- 自身轴向
    CONNECT_LINE = 2, -- 连线轴向
}

-- OpenUI对象类型
OPEN_UI_OBJECT = {
    SELF = 0, -- 自身
    TARGET = 1,   -- 锁定目标
    ALL_PLAYER = 2, -- 所有玩家
}

-- moveCast 运动模式
MOVE_CAST_MODE = {
    WINDMILLS = 0, 			-- 大风车
    ROLLER = 1, 			-- 滚轮
    LOCO_MOVE = 2,			-- 正常移动施法			
}

-- 收藏品系统中全部大类的type索引
COLLECTIBLES_ALL_TYPE_INDEX = 0

ROLE_PLAY_KEY_BOARD = {
    GENERAL_POS = -1 ---通用键位
}

ATTACH_LOCATION_TYPE = {
    KEEP_RELATIVE_OFFSET = 0,
    KEEP_WORLD_POSITION = 1,
    SNAP_TO_TARGET = 2,
    SNAP_TO_TARGET_INCLUDING_SCALE = 3,
}

-- 最多32个
---@class NIAGARA_HIDDEN_REASON
NIAGARA_HIDDEN_REASON = {
    OWNER_SET_HIDDEN = 0,
	COMBAT_SETTINGS = 1,
	CUTSCENE = 2,
    TASK_SWITCH = 3,
}

---@class NIAGARA_SOURCE_TYPE
NIAGARA_SOURCE_TYPE = {
    DEFAULT = 1,
    BATTLE = 2,
    ANIM_NOTIFY = 3,
}

---@class NIAGARA_EFFECT_TAG
NIAGARA_EFFECT_TAG = {
	TEAMMATE = 0,
	ENEMY = 1,
	TEAMMATE_POSITIVE = 2,
	TEAMMATE_INDICATOR = 3,
	ENEMY_INDICATOR = 4,
	HATRED_INDICATOR = 5,
	BATTLE = 6,
	NEUTRAL = 7,
	APPEARANCE = 8,
}

MOUNT_STATE = {
    OFF_MOUNT = 0,
    ON_SELF_MOUNT = 1,      -- 在自己的坐骑上
    ON_OTHER_MOUNT = 2,     -- 在别人的坐骑上
}

ACCSLOT_POS = {
    [1] = true,
    [2] = true,
    [3] = true,
}

ACCSLOT_NONE = 0

FASHION_FLOAT_TO_INT = 100

LINE_BONE_NAME = "spine_03"

PRE_SELECT_SWITCH = false

ONLY_ANGLE = true

SORT_DEBUG_SWITCH = false

IS_LOCK_LIMIT_SWITCH = true

CAMERA_POV_SORT_SWITCH = false

LOCK_SELECT_EFFECT_SWITCH = true

SELECT_EFFECT_REFRESH_SWITCH = false

DEFAULT_SELECT_SORT_SWITCH = true

------------------- 茶壶系统 start -----------------
-- 房间类型
TEAROOM_TYPE = {
    CHAT = 1, -- 闲聊唠嗑
    SING_LISTEN_SONG = 2, -- 听歌唱歌
    EMOTIONAL_STORY = 3, -- 情感故事
    STRATEGY_DISCUSSION = 4, -- 攻略讨论
    OTHER = 5, -- 其他类型
}

-- todo fuyu10
TEAROOM_TYPE_TO_NAME = {
    [TEAROOM_TYPE.CHAT] = "闲聊唠嗑",
    [TEAROOM_TYPE.SING_LISTEN_SONG] = "听歌唱歌",
    [TEAROOM_TYPE.EMOTIONAL_STORY] = "情感故事",
    [TEAROOM_TYPE.STRATEGY_DISCUSSION] = "攻略讨论",
    [TEAROOM_TYPE.OTHER] = "其他类型",
}

-- 房间标签
TEAROOM_TAG = {
    OFFICIAL = 0, -- 官方
    FIERY = 1 , -- 火爆
    BELOW_LINE = 2, --线下
    NONE = 3, -- 没有
}

-- todo fuyu10
TEAROOM_TAG_TO_NAME = {
    [TEAROOM_TAG.OFFICIAL] = "官方",
    [TEAROOM_TAG.FIERY] = "火爆",
    [TEAROOM_TAG.BELOW_LINE] = "线下",
    [TEAROOM_TAG.NONE] = "",
}

-- 房间开麦权限类型
TEAROOM_OPEM_MIC_PERMISSION = {
    SPEAK_FREE = 1, --全体自由发言
    SPEAK_RIGHT = 2, -- 房主设置发言权限
    SPEAK_ORDER = 3 --房主设置发言顺序
}

TEAROOM_OPEM_MIC_PERMISSION_TO_NAME = {
    [TEAROOM_OPEM_MIC_PERMISSION.SPEAK_FREE] = "全体自由发言",
    [TEAROOM_OPEM_MIC_PERMISSION.SPEAK_RIGHT] = "房主设置发言权限",
    [TEAROOM_OPEM_MIC_PERMISSION.SPEAK_ORDER] = "房主设置发言顺序",
}

TEA_ROOM_ID_EMPTY = 0 -- 玩家默认不在茶壶房间内teaRoomID为0
TEA_ROOM_ID_ENTER = 1 -- 玩家进房的时候teaRoomID的标记
TEA_ROOM_ID_CREATE = 2 -- 玩家创建房间的时候teaRoomID的标记

------------------- 茶壶系统 end -----------------

-- 解迷玩法类型
PUZZLE_PLAY_TYPE = {
    WATER_PIPE_TYPE = 0, -- 水管解迷玩法
    ROTARY_DISK_TYPE = 1, -- 转盘解迷玩法
}

EFFECT_SETTING_CONST = {
    EFFECT_QUALITY = 1,             -- 主机特效质量
    OTHER_EFFECT_QUALITY = 2,       -- 他人特效质量
    OTHER_EFFECT_STRENGTH = 3,      -- 他人特效强度
}

SPACE_REVIVE_LIMIT_TYPE = {
    NONE = 0, -- 不做限制；
    SKILL = 1, -- 限制技能复活；
    SYSTEM = 2, -- 限制自身功能复活；
    ALL = 3, -- 禁止复活
}

HIT_PARAM_TYPE = {
    NORMAL = 0,
    ROOT_MOTION = 1,
    PHYSICAL_FALL = 2,
    HOVER = 3,
    -- 上面为c/s沟通大类，下面是客户端细分表现
    LIE_DOWN = 4,
    PHYSICAL_FALL_LOOP = 5
}

PROFESSION_TYPE = {
    SUN = 1200001,
    UTOPIAN = 1200002,
    FOOL = 1200003,
    ARBITER = 1200004,
    APPRENTICE = 1200005,
    WARRIOR = 1200006
}

UTOPIAN_CUSTOMDATA =  {
    WHITE_FEATHER_SKILL_ID = 8000220,        -- 观众白羽毛技能ID
    WHITE_WING_BUFF_ID = 8103001,            -- 白翅膀BUFFID
    WHITE_WING_ITEM_ID = "Prop_4000031",     -- 白翅膀道具ID
    BLACK_WING_BUFF_ID = 8103002,            -- 黑翅膀BUFFID
    BLACK_WING_ITEM_ID = "Prop_4000032",     -- 黑翅膀道具ID
}

BUFF_NOT_CHECK_SOURCE_INSTIGATOR_ID = 1

ARRODES_DIALOGUE_ASSET_ID = 10070059


CHAT_MULTI_SEND_TYPE = {
    CHANNEL = 1,    -- 频道
    WHISPER = 2,    -- 私聊
    CLUB = 3,       -- 群聊
}

TITLE_TYPE = {
    TITLE = 1,      --称号
    HONORIFIC = 2,  --头衔
}

TRIGGER_CONDITION_SYSTEM_KEY = 1000         -- Condition 系统System预留数量
TRIGGER_CONDITION_KEY = 10                  -- Condition Index预留数量

------------------- 呓语之花 start -----------------
RAVING_FLOWER_SUBSTATE = {
    None = 0,   -- 初始状态
	Factory = 1, -- 工厂区
	Sewer = 2, -- 下水道
	Sycamore = 4, -- 梧桐区
}

PUZZLE_RITUAL_SUBSTATE = {
    InActive = 0,	-- 未激活，不显示
    Active = 1,		-- 已激活，交互点位未完成
    Finished = 2,	-- 交互点位全部完成
}
------------------- 呓语之花 end -----------------

------------------- 神像探索 start -----------------
IDOL_EXPLORE_FINISH_TRIGGER_SOURCE = {
    RPC = 1,
    COLLECT_INTERACTION_SUCCEED = 2,
    ITEM_NUMBER_CHANGE = 3,
    INTERACTION_SUCCEED = 4,
    FLOWCHART_METHOD = 5
}

IDOL_EXPLORE_STATUS = {
    LOCKED = 1,
    EXPLORING = 2,
    EXPLORING_INTERACTED = 3,
    FINISHED = 4
}

IDOL_3_STATUS = {
    UNCREATED = 1,
    CREATED = 2,
    OPENED = 3
}
------------------- 神像探索 end -----------------


PATH_MOVE_STATE = {
    ["Idle"] = 1,
    ["Waiting"] = 2,
    ["Moving"] = 3,
    ["Paused"] = 4,
}