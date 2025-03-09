EWActorType = {
    None = 0,
    PLAYER = 1, --玩家
    NPC = 2, --NPC

    MONSTER_MIN = 10001, --怪物初始-------
    MONSTER_NORMAL = 10002, --普通怪
    MONSTER_BOSS = 10003, --Boss

    MONSTER_MAX = 20000, --怪物结束-------

    NPC_MIN = 20001, --NPC开始-------
    NPC_TASK = 20002, --任务NPC
    NPC_PASSERBY = 20002, --路人NPC
    NPC_DIALOGUE = 20003, --剧情展示NPC
    NPC_MINDRAGON = 20004, -- 空想家小龙
	NPC_CROWD = 20005, -- 氛围Npc
	NPC_CROWD_INTERESTING = 20006, -- 氛围Npc感兴趣的Npc, 如马车
    NPC_MAX = 30000, --NPC结束-------

    SCENEACTOR_MIN = 30001, --场景物体开始---------
    DECAL_ACTOR = 30002,

    INTERACTIVE_CHAIR = 40001, --可交互的椅子
    SCENE_TEXT = 40002, --文字板
    SEQUENCE_LADDER = 40003, --序列晋升
    TIENGEN_LAKE_FLOWER = 40004, -- 廷根湖大红花
    ALCHEMY_TABLE = 40005, --盗火学派，炼药台
    CONSECRATION_MONUMENT = 40006, --七天神像
    INTERACTIVE_SWING = 40007, --秋千
    NON_INTERACT_MESH = 40008, --不可交互带状态mesh
    FRACTURE_TABLE = 40009, --破碎物体
    SPIRIT_REALM_PORTAL = 40010, --灵界传送交互物
    INTERACTIVE_DOOR = 40011, --可交互门
    ROLE_PLAY_CARDSPAWNER = 40012, --UI角色扮演卡牌
    PHARMACY_SPOON = 40013, --UI药师勺子,
    CONSECRATION_SPIRIT = 40014, --奉献之灵
    TREASURE_BOX_UNLOCK = 40015, --已解锁宝箱
    FOG_TRIGGER = 40016, -- 迷雾驱散触发器
    CLOCK_LAMP = 40017, --挂钟
    MIRROR = 40018, -- 镜子
    TREASURE_BOX_LOCK = 40019, --锁定宝箱
    FATE_CONTRACT = 40020, -- 一笔画
    CAGE_MONKEY = 40021, -- 笼子里的狒狒
    PUT_BREAD = 40022, --摆放面包仪式
    HEIGHT_FOG_MODIFIER = 40023, --接触时修改体积雾
    MOVABLE_BREAD = 40024, --摆放面包仪式的面包
    SPIRIT_ANIMAL = 40025, --只能被无形之手抚摸的喵乌贼
    TIME_CHESS = 40026, --岁月棋局
    POTIONS_TABLE = 40027, --魔药台
    TOWER_CLIMB_PORTAL = 40028, --爬塔通关后出现的传送门
    SPLINE_FOOT_PRINT = 40029, --脚印样条线
    PLANE_PORTAL = 40030, --位面传送门
    INTERACTIVE_PORTAL = 40031, --大世界传送门
    NIAGARA_CARRIER_V2 = 40032, --特效载体(新版)
    SCENE_NPC = 40033, -- Npc外观的场景物体
    SCENEACTOR_WINDMILL = 40034, --风车, flowchart控制转速
    COLLECTION = 40035, --新采集物
    ICE_FIELD_NPC = 40036, --冰面NPC
    CAMERA_CONTROL_VOLUME = 40037, --摄像机控制Volume
    MONSTER_CHASE = 40038, --追蝴蝶
    LARGE_CREATURE = 40039, --大型生物
    SPIRITUAL_ICON = 40040, --摆放的灵视标记点
    INTERACTIVE_STREETLIGHT = 40041, --可交互灯
    STREET_LIGHT = 40042, --TOD路灯
    TREASURE_BOX_EYE = 40043, --眼睛宝箱
    STAR_GRAPH_TREASURE = 40044, --星空解密
    POSTER_TREASURE = 40045, --报纸解密(填字游戏)
    MAGIC_WALL = 40046, --魔法墙
    GUILD_BLESS = 40047, --公会祈福
    BATTLE_ZONE = 40048, --战斗区域
    BUFF_TRIGGER = 40049, --加buff的trigger
    LOAD_SEQUENCE = 40050, --加载Sequence
    TRIGGER_LIGHT = 40051, --目标标识
    SPIRITUALITY_WALL = 40052, -- 灵性之墙
    MESH_CARRIER = 40053,
    FOUNTAIN = 40054, --喷泉
    TREASURE_BOX_ELEM = 40055, --元素宝箱
    JUMP_POINT = 40056, --跳跃点
    SHADOW_MONSTER = 40057, --暗影怪
    FIREWORK = 40058, --烟花
    DROP_MONSTER = 40059, --怪物宝箱
    POWDER_KEG = 40060, --火药桶
    GROW_DECAY_PLANT = 40061, --生长衰减植物
    BASE_ELEM_TRIGGER = 40062, --元素反应trigger
    FURNACE = 40063, --盗火学院火炉
    MACHINE = 40064, --盗火学院齿轮
    BUFF_CAGE = 40065, --带有某个Buff时可以通行的笼子
    GUILD_ANSWER_AREA = 40066, --公会答题区域
    PLANT_SIHOUETTE = 40067, --植物剪影
    PREPARE_ZONE = 40068, --准备区域
    TEAM_MARK = 40069, --组队标记
    DROP_ITEM = 40070, --掉落道具
    SPIDER_WEB = 40071, -- 蜘蛛网(带阻挡)
    PAINTING_VIDEO = 40072, -- 挂画视频
    PAINTING_SCRATCH = 40073, -- 挂画刮刮乐
    DROP_ITEM_GROUP = 40074, --掉落道具打包盒
    ESTATE_PORTAL = 40075, --五月庄园传送门
    MOVABLE_PLATFORM_WAY_PATH = 40076, --移动平台(电梯)平台层
    MOVABLE_PLATFORM = 40077, --移动平台(电梯)轿厢
    KG_SPOT_LIGHT_V2 = 40078, --聚光灯
    WATERPIPE_PUZZLE_TRIGGER = 40079, --水管解谜玩法区域
    WATERPIPE_PUZZLE_ITEM = 40080, --水管解谜玩法场景物
	DIALOGUE_TRIGGER = 40081, --加载对话
    SOUND_TRACE = 40082, -- 寻声玩法
	CORRUPT_TREE = 40083, --腐败果树
    TURNTABLE_PUZZLE_TRIGGER = 40084, --转盘解谜玩法区域
	BROKEN_STEPS = 40085, --五月庄园破碎楼梯
    TURNTABLE_PUZZLE_TURNTABLE = 40086, --转盘解谜玩法 转盘
    TURNTABLE_CROSS_AREA = 40087, --转盘解谜玩法 转盘交叉区域
    TURNTABLE_BARRIER = 40088, --转盘解谜玩法 标记物
    TURNTABLE_RESET_DEVICE = 40089, --转盘解谜玩法 重置装置
    MAP_UI_FREEZE_VOLUME = 40090, --在场景物Trigger内地图UI不发生变化
    PHYSICAL_EFFECT = 40091, --实时破碎物
    CUTTABLE_TREE = 40092, --可以被砍的树
    SHOW_MESH = 40093,--把静态网格体挪到相机前
    DECAL_CARRIER = 40094,--场景摆放的Decal
    CHASED_MONSTER = 40095,--被追的动物
	TASK_PLANE_PORTAL = 40096,--任务专用本地传送门
	SPIRIT_EFFECT_LINE = 40097, --灵性特效线
	BOOK_CORRIDOR = 40098, --书籍通道
	SIMULATE_PHYSICAL_MESH = 40099, --开启物理模拟的Mesh
	POINT_LIGHT = 40100, --点光源
	BOOK_CORRIDOR_DOOR = 40101, --书籍通道出入口
	ESTATE_PAINT = 40102, --庄园挂画二合一
	EAT_SNACK = 40103, --品尝茶点
	DRINK_WINE = 40104, --品酒
	WONDER = 40105, --奇观
	RAVINGSFLOWER = 40106, --位面中呓语之花本体
	ASSCENE_TEXT = 40107, --A/S级别效果的文字板
	BOOK_FLOOR = 40108, --书籍地面
	EXTRAORDINARY_PORTAL = 40109, --非凡事件入口
	GODDESS = 40110, -- 女神像
	SPEED_BALL = 40111, -- 加速球
	PUZZLE_RITUAL = 40112, -- 呓语之花解谜仪式
	GODDESSLEAD = 40113, -- 主女神像
	PILLAR = 40114, -- 神像柱子
	PLACE_ITEM = 40115, -- 放置道具
	CAN_FIRED = 40116, -- 可以被火元素触发状态改变，播放特效

	CUSTOM_SHAPE_WALL = 40150, --自定义边界
    BIND_VIEW_CONTROLLER = 40151, --绑定美术场景物

    AUNIVERSAL_INTERACTOR = 59998, --通用交互物
    GROUP_ACTOR = 59999, --Group

    SCENEACTOR_MAX = 60000, --场景物体结束---------

    SCENEACTOR_DATA_MIN = 60001, --场景数据开始---------

    GAME_CONTROL_VOLUME = 60002, -- 游戏控制相机数据
    MANOR_CAMERA = 60003, -- MANOR相机数据
    NPC_SPAWNER = 60004, -- NpcSpawner
    NPC_SINGLE_SPAWNER = 60005, -- NpcSingleSpawner
    RESPAWN_POINT = 60006, -- 出生点
    SQAURE_TRIGGER = 60007, --方形触发器
    TELEPORT_POINT = 60008, --传送点
    WAY_POINT_PATH = 60009, --路径
    WAY_SINGLE_POINT = 60010, --单路点
    OCCUPY_DETECT_AREA = 60011, --公会抢点数据
    SHAPE_TRIGGER = 60012, --方或圆形触发器
	MASS_NPC_TRIGGER_POINT = 60013, -- 氛围NPC触发点
    PRELOAD_STREAMINGSOURCE = 60014, --WP预加载地块范围
    COMMON_INTERACTOR = 60015, -- 通用交互物
    CUSTOMIZED_GAMEPLAY = 60016, -- 定制玩法

    SCENEACTOR_DATA_MAX = 70000, --场景数据结束---------



    ABILITY_MIN = 70001, --技能生成物开始-------


    ABILITY_MAX = 80000, --技能生成物结束-------

	POS_TRIGGER_POINT = 80001, -- 场景pos触发器
}

SceneActorTypeEnum = {
    EWActorType.INTERACTIVE_CHAIR,
    EWActorType.INTERACTIVE_SWING,
    EWActorType.INTERACTIVE_DOOR
}