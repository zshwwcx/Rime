local SwitchEnum = kg_require("Shared.ModuleSwitch.SwitchEnum")

--local const = kg_require("Common.Const")
-- 用于控制本服某些功能是否打开
-- 1. 每新增一个开关均需要在SwitchEnum中增加枚举值
-- 2. 默认的开关和实际的开关值可能不一样，修改过的开关会存储落库，每个开关是一条数据
-- 3. 开关值可以是bool/string/int，表示开关/状态/屏蔽值等，如果想存列表，可以用"a|b|c"带分割符的str表示，需要同步给客户端的开关值不宜过大  (存盘统一为string，然后用utils里面的转换函数转换)
-- 4. 已经上线且修改过的开关(落库)，不能再修改开关的ID，或者将ID用于另一个开关，否则会有问题
-- 5. 定义格式: 开关名  ->  { 开关ID(用于存储和同步), 开关默认值, 是否需要同步给客户端, 负责人的快手邮箱前缀, 描述说明, string类型开关的具体类型(可选)}

-- Dev环境开关,IS_PUBLISH 环境下在Game.Switches.EditorMode取值会是nil,也无法修改
-- 最后一个变量标记是否存盘，默认是存盘的
DebugSwitchDef = {
    EditorMode = { SwitchEnum.EDITOR_MODE, false, true, "wangbin22", "策划编辑器模式", false },
    DisableDebugInfo = { SwitchEnum.DISABLE_DEBUG_INFO, false, true, "hedongchang", "是否显示客户端ui debug信息" },
    DisableGMAttackBoxView = { SwitchEnum.ENABLE_GM_ATTACK_BOX_DISPLAY, true, true, "zengzhiwen", "是否禁止攻击盒可视化" },
    TeamSkipApply = { SwitchEnum.TEAM_SKIP_APPLY, false, false, "wangbin22", "跳过队伍申请,直接加入队伍" },
    DisableClientGM = { SwitchEnum.DISABLE_CLIENT_GM, false, false, "wangbin22", "是否禁止客户端发送GM" },
    NotLoadSpawnData = { SwitchEnum.NOT_LOAD_SPAWN_DATA, false, false, "wangbin22", "不加载布怪数据" },
}

-- string类型开关的具体类型: 1.字符串列表(默认), 如"a|b|c" 2.数字列表, 如"123|456|789"
STRING_SWITCH_VALUE_TYPE = {
	STRING_LIST = 1,
	NUMBER_LIST = 2,
}

-- 生产环境下会用到的开关,比如各个系统功能的开关
-- 下列开关的修改会全部存盘,否则重启后重置容易出问题
-- string为存盘的开关必须在SwitchUtils里面写转换后处理，不然会assert报错，阻塞起服。
SwitchDef = {
    DisableLogin = { SwitchEnum.DISABLE_LOGIN, false, false, "hedongchang", "是否禁止登录" },
    DisableDebugLogin = { SwitchEnum.DISABLE_DEBUG_LOGIN, not IS_GAME_DEBUG, false, "shangyuzhong", "是否禁止测试登录(DEBUG_LOGIN)" },
    DisableLoginDefsCompare = { SwitchEnum.DISABLE_LOGIN_DEFS_COMPARE, false, false, "hedongchang", "登录时是否禁止服务端和客户端defs version"},
    DisableChat = { SwitchEnum.DISABLE_CHAT, false, true, "wangbin22", "是否禁止聊天功能" },
    DisableChatCustomImg = { SwitchEnum.DISABLE_CHAT_CUSTOM_IMG, false, true, "tianjia", "是否禁止聊天自定义图片功能" },
    DisableGMAuthCheck = { SwitchEnum.DISABLE_GM_AUTH_CHECK, false, false, "wangbin22", "是否禁止GM权限校验" },
    DisableLoginWhiteList = { SwitchEnum.LOGIN_LOGIN_WHITELIST, true, false, "wangbin22", "是否禁止登录白名单" }, -----特别注意，平时开发默认禁止。
    DisableMail = { SwitchEnum.DISABLE_MAIL, false, true, "wangbin22", "是否禁止邮件系统" },
    DisableBasicShop = { SwitchEnum.DISABLE_BASIC_SHOP, false, true, "wangbin22", "是否禁止系统商店" },
	BasicShopBlackList = { SwitchEnum.BASIC_SHOP_BLOCK_LIST, "", true, "shangyuzhong", "禁止的系统商店列表", STRING_SWITCH_VALUE_TYPE.NUMBER_LIST },
    DisableRoleNameCheck = { SwitchEnum.DISABLE_ROLE_NAME_CHECK, false, false, "hedongchang", "是否禁止验证角色名字的长度以及是否重复" },
    DisableLookUpPlayer = { SwitchEnum.DISABLE_LOOK_UP_PLAYER, false, false, "tangxuexue", "是否禁止查找玩家" },
    DisableHotfix = { SwitchEnum.DISABLE_HOTFIX, false, false, "shenyue08", "是否禁止Hotfix" },
    DisableIndividualPVP = { SwitchEnum.ENABLE_INDIVIDUAL_PVP, false, false, "zhaoran06", "是否禁止1V1切磋" },
    DisableSkillSchemeCheckNameDirty = {SwitchEnum.DISABLE_SKILL_SCHEME_CHECK_DIRTY, false, false, "sanghaoyuan", "是否禁止技能方案敏感词校验"},
    DisableChatCheckDirty = {SwitchEnum.DISABLE_CHAT_CHECK_DIRTY, false, false, "sanghaoyuan", "是否禁止聊天敏感词校验"},
    DisableCreateGuildCheckInfoDirty = {SwitchEnum.DISABLE_CREATE_GUILD_CHECK_INFO_DIRTY, false, false, "sanghaoyuan", "是否禁止创建公会敏感词校验"},
    DisableEditGuildCheckNameDirty = {SwitchEnum.DISABLE_EDIT_GUILD_CHECK_NAME_DIRTY, false, false, "sanghaoyuan", "是否禁止编辑公会名敏感词校验"},
    DisableEditGuildCheckDeclarationDirty = {SwitchEnum.DISABLE_EDIT_GUILD_CHECK_DECLARATION_DIRTY, false, false, "sanghaoyuan", "是否禁止编辑公会宣言敏感词校验"},
    DisableEditGuildCheckSignatureDirty = {SwitchEnum.DISABLE_EDIT_GUILD_CHECK_SIGNATURE_DIRTY, false, false, "sanghaoyuan", "是否禁止编辑公会签到敏感词校验"},
    DisableChatToAllGuildCheckTextDirty = {SwitchEnum.DISABLE_CHAT_TO_ALL_GUILD_CHECK_TEXT_DIRTY, false, false, "sanghaoyuan", "是否禁止公会群发消息敏感词校验"},
    DisableFriendCheckLookupPlayerRequestDirty = {SwitchEnum.DISABLE_FRIEND_CHECK_LOOKUP_PLAYER_REQUEST_DIRTY, false, false, "sanghaoyuan", "是否禁止搜索添加好友敏感词校验"},
    DisableFriendCheckRemarkDirty = {SwitchEnum.DISABLE_FRIEND_CHECK_REMARK_DIRTY, false, false, "sanghaoyuan", "是否禁止修改好友备注敏感词校验"}, 
    DisableFriendCheckGroupNameDirty = {SwitchEnum.DISABLE_FRIEND_CHECK_GROUP_NAME_DIRTY, false, false, "sanghaoyuan", "是否禁止好友分组名称敏感词校验"},
    DisableFriendCheckClubNameNoticeDirty = {SwitchEnum.DISABLE_FRIEND_CHECK_CLUB_NAME_NOTICE_DIRTY, false, false, "sanghaoyuan", "是否禁止群聊名称和群聊公告敏感词校验"},
    DisableFriendCheckClubChatDirty = {SwitchEnum.DISABLE_FRIEND_CHECK_CLUB_CHAT_DIRTY, false, false, "sanghaoyuan", "是否禁止群聊敏感词校验"}, 
    DisableFriendCheckSendWhisperDirty = {SwitchEnum.DISABLE_FRIEND_CHECK_SEND_WHISPER_DIRTY, false, false, "sanghaoyuan", "是否禁止好友私聊敏感词校验"},
    DisableTeamCheckDirty = {SwitchEnum.DISABLE_TEAM_CHECK_DIRTY, false, false, "sanghaoyuan", "是否禁止组队敏感词校验"},
    DisableCreateRoleCheckNameDirty = {SwitchEnum.DISABLE_CREATE_ROLE_CHECK_NAME_DIRTY, false, false, "sanghaoyuan", "是否禁止创角名字敏感词校验"},
    DisableServerGM = {SwitchEnum.DISABLE_SERVER_GM, false, false, "sanghaoyuan", "是否禁止服务器gm"},
    DisableCheckProtocolMd5 = {SwitchEnum.DISABLE_CHECK_PROTOCOL_MD5, false, false, "sanghaoyuan", "是否禁止开启MD5"},
    DisableWorldBoss = {SwitchEnum.DISABLE_WORLD_BOSS, false, false, "hedongchang", "是否禁止开启世界boss功能"},
    DisableTeamPVP = {SwitchEnum.DISABLE_TEAM_PVP, false, true, "shenxudong05", "是否禁止组队pvp功能"},
    DisableTeamPVPOvertimeRobotOppo = {SwitchEnum.DISABLE_TEAM_PVP_OVERTIME_ROBOT_OPPO, false, false, "shangyuzhong", "是否禁止组队pvp玩家队匹配机器人队(为true时, 超时玩家队也不匹配机器人队)"},
    DisableTeamPVPBotMember = {SwitchEnum.DISABLE_TEAM_PVP_BOT_MEMBER, false, false, "shangyuzhong", "是否禁止组队pvp玩家队匹配机器人队员"},
    DisableTeamPVPBotOpponent = {SwitchEnum.DISABLE_TEAM_PVP_BOT_OPPONENT, false, false, "shangyuzhong", "是否禁止组队pvp匹配机器人对手(不包括福利局)"},
    DisableRedPacket = { SwitchEnum.DISABLE_RED_PACKET, false, true, "shangyuzhong", "是否禁止礼金功能" },
    ForbiddenMoney = { SwitchEnum.FORBIDDEN_MONEY, "", false, "xietieyong", "禁用的货币编号列表"},
    DisableLoginQueue = { SwitchEnum.DISABLE_LOGIN_QUEUE, false, true, "yechengyin", "是否禁止登录排队功能"},
    DisableLoginQueueUpload = { SwitchEnum.DISABLE_LOGIN_QUEUE_UPLOAD, true, false, "yechengyin", "是否禁止登录排队信息上报中台"},
    DisableRedPacketSend = { SwitchEnum.DISABLE_RED_PACKET_SEND, false, true, "shangyuzhong", "是否禁止礼金发送功能(EnableRedPacket子开关)" },
    DisableRedPacketReceive = { SwitchEnum.DISABLE_RED_PACKET_RECEIVE, false, true, "shangyuzhong", "是否禁止礼金接收功能(EnableRedPacket子开关)" },
    DisableAllDirtyCheck = { SwitchEnum.DISABLE_ALL_DIRTY_CHECK, false, false, "leyiwei", "是否禁止所有敏感词的总开关"},
    DisableTeamPveMatch = {SwitchEnum.DISABLE_TEAM_PVE_MATCH, false, true, "zhangmiao07", "是否开启PVE匹配"},
	DisableEquipChange = { SwitchEnum.DISABLE_EQUIP_CHANGE, false, true, "yechengyin", "是否禁止切换装备（包括穿和脱）" },
	DisableMoneySaleSystem = {SwitchEnum.DISABLE_MONEY_SALE_SYSTEM_INTERVENTION, false, false, "liaohaiqiang", "是否禁止货币寄售系统干预(系统出售购买)"},
    DisableMoneySaleBuy = {SwitchEnum.DISABLE_MONEY_SALE_BUY, false, false, "liaohaiqiang", "是否禁止货币寄售购买货币"},
    DisableMoneySaleSell = {SwitchEnum.DISABLE_MONEY_SALE_SELL, false, false, "liaohaiqiang", "是否禁止货币寄售出售货币"},
    DisableMoneySaleCancel = {SwitchEnum.DISABLE_MONEY_SALE_CANCEL, false, false, "liaohaiqiang", "是否禁止货币寄售下架货币"},
    DisableMoneySaleDayRefresh = {SwitchEnum.DISABLE_MONEY_SALE_DAY_REFRESH, false, false, "liaohaiqiang", "是否禁止货币寄售每日刷新(如重新计算汇率)"},
    DisableMoneySaleDBRetry = {SwitchEnum.DISABLE_MONEY_SALE_DB_RETRY, false, false, "liaohaiqiang", "是否禁止货币寄售DB操作重试"},
	DisableEquipEnhance = { SwitchEnum.DISABLE_EQUIP_ENHANCE, false, true, "yechengyin", "是否禁止装备强化" },
    DisableCreateRoleName = { SwitchEnum.DISABLE_CREATE_ROLE_NAME, false, true, "yechengyin", "是否禁止创号时取名（新流程下创号时玩家不起名）" },
    SaveDBLevelMin = { SwitchEnum.SAVE_DB_LEVEL_MIN, 10, false, "shangyuzhong", "升级实时存盘最小等级" },
    FlowchartAvatarTick = { SwitchEnum.SWITCH_FLOWCHART_AVATAR_TICK, 100, false, "shangyuzhong", "流程图中玩家tick间隔" },
    FlowchartCreepTick = { SwitchEnum.SWITCH_FLOWCHART_CREEP_TICK, 100, false, "shangyuzhong", "流程图中小怪tick间隔" },
    FlowchartCreateTick = { SwitchEnum.SWITCH_FLOWCHART_CREATE_TICK, 100, false, "shangyuzhong", "流程图中创生物tick间隔" },
    FlowchartEliteTick = { SwitchEnum.SWITCH_FLOWCHART_ELITE_TICK, 100, false, "shangyuzhong", "流程图中精英tick间隔" },
    FlowchartBossTick = { SwitchEnum.SWITCH_FLOWCHART_BOSS_TICK, 100, false, "shangyuzhong", "流程图中Boss tick间隔" },
    FlowchartNpcTick = { SwitchEnum.SWITCH_FLOWCHART_NPC_TICK, 100, false, "shangyuzhong", "流程图中npc tick间隔" },
    AOIPrimaryLevelMaxPlayer = { SwitchEnum.SWITCH_AOI_PRIMARY_LEVEL_MAX_PLAYER, 100, false, "shangyuzhong", "AOI Primary层最大玩家数" },
    BatchChangeAOILevelMaxCount = { SwitchEnum.SWITCH_BATCH_CHANGE_AOI_LVL_MAX_COUNT, 100, false, "shangyuzhong", "批量修改AOI层级最大玩家数" },
    DisableWorldEnterQueue = { SwitchEnum.DISABLE_USE_WORLD_ENTER_QUEUE, false, false, "shangyuzhong", "是否禁止大世界队列" },
    EnterNumPerProcessPerSec = { SwitchEnum.SWITCH_ENTER_NUM_PER_PROCESS_PER_SEC, 30, false, "shangyuzhong", "每秒进入大世界的人数" },
    DisableTeaRoom = { SwitchEnum.DISABLE_TEAROOM, false, true, "fuyu10", "是否禁用茶壶" },
}