-- 可赋值的黑板值(与 STATIC_BLACK_BOARD_KEY_TYPE 对应)
ESetBBVType = {
    instigatorID = 0,
    triggerID    = 1,
    rootSkillID  = 2,
    rootBuffID   = 3,
    level        = 4,
    buffID       = 5,
    layer        = 6,
    skillID      = 7,
    speed        = 8,
    lockTarget   = 9,
    isAttackMiss = 10,
}

-- 可赋值的黑板值(与 STATIC_BLACK_BOARD_KEY_TYPE 对应)
EClearBBVType = {
    searchTargetList = 0,
    searchTargetListLength    = 1,
    searchPosList  = 2,
}

-- 可赋值的黑板值(与 STATIC_BLACK_BOARD_KEY_TYPE 对应)
ECheckBBVType = {
    searchTargetListLength = 0,
}

-- 基准坐标点类型
EBaseCoordinatePointType = {
    Self = 0,           -- self: 自身位置点
    SelfOffset = 1,     -- selfoffset,dist,x: 自身位置往前dist距离、再往右x（x缺省为0）的点
    Target = 2,         -- tar: 目标位置点
    TargetOffset = 3,   -- taroffset,dist,x: 目标位置往前dist距离、再往右x（x缺省为0）的点
    TargetToSelf = 4,   -- tartoself,dist,x: 目标往自身连线方向往前dist距离、再往右x（x缺省为0）的点
    SelfToTarget = 5,   -- selftotar,dist,x: 自身往目标连线方向往前dist距离、再往右x（x缺省为0）的点
}

-- 筛选集合运算类型
ESelectionSetOperateType = {
    None = 0,           -- 无运算
    Union = 1,          -- 并集: union(fan;selfoffset,4;4,120;2,2;0;|fan;self;4,120;2,2;90;)
    Intersect = 2,      -- 交集: intersect
    Except = 3,         -- 差集: except
}

-- 目标存活类型
ETargetAliveType = {
    None = 0,           -- 不考虑存活状态(死亡或者活着都行)
    Alive = 1,          -- 要求目标是活着的
    Dead = 2,           -- 要求目标是死亡的
}

-- 筛选器形状类型
ESelectorShapeType = {
    None = 0,        -- 无范围
    Cuboid = 1,        -- 长方体(原点为底面中心）
    Cylinder = 2,    -- 圆柱（原点为底面圆心）
    Fan3d = 3,      -- 扇柱（原点为底面圆心）
    Sphere = 4,        -- 球形（原点为球心）
    Annular3d  = 5, -- 环形体（原点为底面圆心)
}

ESelectResultSortType = {
	None = 0,            -- 不排序
	DistanceSort = 1,    -- 预选中距离排序类型
	AngleSort = 2,       -- 预选中角度排序
}

-- 敌我阵营关系
EFactionType = {
    None = 0,        -- 全体（不筛选)
    Self = 1,        -- 自己
    TeamMate = 2,    -- 小队队友（友方阵营）
    GroupMate = 4,  -- 团队队友（友方阵营）
    Allies = 8,        -- 联盟盟友（友方阵营）
    Neutral = 16,    -- 中立
    Enemy = 32,        -- 敌对
}

-- 位置筛选形状类型
EPositionSelectShapeType = {
    none = 0,       -- 取默认点位置
    circle = 1,     -- 圆形
    fan = 2,        -- 扇形
    ringcut = 3,    -- 扇环
}

EFactionAll = 0
for _, v in pairs(EFactionType) do
    EFactionAll = EFactionAll + v
end

-- 目标单位类型
ETargetActorType = {
    None = 0,            -- 全体（不筛选)
    Player = 1,            -- 玩家
    CreateMonster = 2,    -- 创生怪物
    NormalMonster = 4,    -- 普通怪物
    EliteMonster = 8,    -- 精英怪物
    Boss = 16,            -- boss
    TaskNpc = 32,        -- 任务npc
    Interactor = 64,    -- 交互物
    SpellField = 128,    -- 法术场(entity实现的法术场)
    Aura = 256,         -- 光环(entity实现的光环)
    Trap = 512,         -- 陷阱(entity实现的陷阱)
    Vehicle = 1024,      -- 载具
}

-- 目标排序策略
ETargetSortStrategy = {
    None = 0,            -- 不排序
    ByProp = 1,            -- 通过属性排序
    ByDistance = 2,        -- 通过到调用者的距离排序
    Random = 3,            -- 随机
    EnterOrder = 4,        -- 进出顺序(用于光环)
    CreateTime = 5,     -- 创建时间(用于光环、陷阱、法术场等unit单位)
    ByHpRate = 6,       -- 血量百分比
    ByDistanceDivide = 7, -- 距离划分
    
    -- 内部使用， 不开放给策划(ByHpRate会转换成BySortMethod)
    BySortMethod = 100, --
}

-- 排序顺序类型
ESortOrderType = {
    Ascending = 0,        -- 升序
    Descending = 1,        -- 降序
}

-- 位置筛选器范围类型
EPositionSelectorRangeType = {
    Circle = 1,        -- 圆形
    Sector = 2,        -- 扇形
    AnnularSector = 3, -- 扇环
}

-- 位置筛选器坐标系
EPositionSelectorCoordinateSystem = {
    SelfToTarget = 1, -- 自身-连线坐标系(方向：自身到目标；原点：自身)
    TargetToSelf = 2, -- 目标-连线坐标系(方向：自身到目标；原点：目标)
    Target = 3,       -- 目标坐标系
    Self = 4,         -- 自身坐标系
    World = 5,        -- 世界坐标系
}

-- 位置筛选器原点获取方法
EPositionSelectorPosType = {
    SearchTargetList = 1, -- 读取 SearchTargetList
    LockTarget = 2,       -- 读取 lockTarget, 若怪物则使用仇恨列表筛选出的目标
    TargetSelection = 3,  -- 目标筛选后获取
    Self = 4,             -- 获取自身施法者位置
}

-- 位置筛选器随机方法
EPositionSelectorRandomType = {
    Random = 0,          -- 真随机
    UniformRandom = 1,   -- 按角度分配均匀随机
    DistanceConstrainedRandom = 2,   -- 限制最小距离的真随机
}

-- 技能目标类型
ESkillTargetType = {
    None = 0,                   -- 无效选项
    Owner = 1,                  -- 技能/buff的持有者
    Instigator = 2,             -- 技能/buff的始作俑者
    Trigger = 3,                -- 技能/buff的触发者
    LockTarget = 4,             -- 技能/buff的锁定目标
    Blackboard = 5,             -- 黑板里面的单位
    TaskTarget = 6,             -- 创建法术代理Task的目标
}

-- 放置位置模式(法术场、陷阱、光环之类的放置模式)
EPositionMode = {
    SelfRoot = 0,               -- 自身Root位置
    TargetRoot = 1,             -- 默认目标Root位置
    PositionSelect = 2,         -- 位置筛选获取位置
    PositionInBlackboard = 3,   -- 位置黑板值里的已有位置
    RightRockerInput = 4,       -- 右摇杆拖拽传入
    BlackboardSearchTargetPos = 5,  -- 获取黑板目标的位置
}

-- 子弹位置偏移选取类型
EBulletOffsetType = {
    SelfRoot = 0,               -- 自身Root位置
    TargetRoot = 1,             -- 默认目标Root位置
}

-- 偏移方向模式
EOffsetDirectionMode = {
    None = 0,                   -- 无效选项
    Self = 1,                   -- 自己方向(或者位置，连线模式）
    Target = 2,                 -- 目标方向(或者位置，连线模式）
    TargetInBlackBoard = 3,     -- 黑板里面单位方向（或者位置，连线模式）
    InputDir = 4,               -- 输入方向(左摇杆输入)
    WorldDir = 5,               -- 世界坐标系方向(暂未支持）
}


EBulletDirType = {
    SpawnerDir = 1,  -- 发射者朝向
    ToTargetDir = 2, -- 发射者到目标连线
}

-- 法术场方向模式（task用)
EUnitDirectionMode = {
    UseDirectionByConfig = 0,   -- 使用表格里面计算的方向
    Direction2Self = 1,         -- 指向施法者
    Direction2Target = 2,       -- 指向task的目标
    Direction2BlackboardPos = 3,-- 指向黑板里面的位置
    Direction2LockTarget = 4,   -- 指向技能锁定目标
}

-- 拋射物目標位置模式
ETrajectilePositionMode = {
    UsePositionInConfig = 0,    -- 表格里面定义的位置（通过Trajectile表计算）
    PositionSelect = 1,         -- 位置筛选获取位置
    PositionInBlackboard = 2,   -- 位置黑板值里的已有位置
    RightRockerInput = 3,       -- 右摇杆拖拽传入
}

-- 召唤物目标位置模式
ESummonPositionMode = {
    PositionSelect = 0,       -- 位置筛选获取位置
    PositionInBlackboard = 1, -- 位置黑板值里的已有位置
    RightRockerInput = 2,     -- 右摇杆拖拽传入
    SelfRoot = 3,             -- 技能持有者位置
}

-- 召唤物初始朝向模式
ESummonOrientationMode = {
    Creator = 0,         -- 创建者朝向
    CreatorToSummon = 1, -- 创建者→召唤物连线朝向
    SummonToCreator = 2, -- 召唤物→创建者连线朝向
    Random = 3,          -- 随机朝向
}

-- 子弹方向模式
EBulletDirectionMode = {
    Root1ToRoot2 = 0,               -- 默认第一偏移点到到第二偏移点为起始方向
    UseDirectionByConfig = 1,       -- 使用配置计算出来的偏移(表格内+task的两次偏移和转向）
    Direction2Target = 2,           -- 指向目标
    UseDirectionByTask = 3,         -- 子弹朝向仅取决于 Task 设置
}

EBulletOffsetMode = {
    Spawner = 0,
    Target = 1,
}

-- 执行转向/面向旋转的模式
ERotateDirectionMode = {
    Target = 0,                         -- 目标方向
    InputDir = 1,                       -- 输入方向
    CounterClockwise = 2,               -- 固定逆时针方向
    Clockwise = 3,                      -- 固定顺时针方向
    DirectionInBlackboard = 4,          -- 位置隐含黑板值所在方向
    FollowTarget = 5                    -- 跟随目标旋转
}

-- 激光射线的旋转模式
ELaserRotateDirection = {
    NoRotate = 0,                    -- 不旋转
    Self = 1,                        -- 跟随技能释放者朝向
    Clockwise = 2,                   -- 固定顺时针方向
    CounterClockwise = 3,            -- 固定逆时针方向
    FollowTarget = 4                 -- 跟随技能目标旋转
}

-- 技能目标设置类型
ESkillTargetSettingType = {
    NoTarget = 0, -- 不需要目标，不需要辅选
    NoTargetOrAssist = 1, -- 不需要目标，但需要辅选
    NeedTargetAndLock = 2, -- 需要目标，通过点选，不需要辅选
    NeedTarget = 3, -- 需要目标，点选or辅选
}

-- 右摇杆模式, 1、2、3模式下大圈半径为释放最大距离
EJoyStickMode = {
    NoJoyStick = 0, -- 无右遥感模式
    BigTrapSmall = 1, -- 大圈套小圈
    SelfRectangle = 2, -- 自身瞄准矩形：以自身为圆心旋转矩形瞄准指示器
    SelfSector = 3, -- 自身瞄准扇形：以自身为圆心旋转扇形瞄准指示器
    SelfRectangleReturnActor = 4, -- 自身瞄准矩形：以自身为圆心旋转矩形瞄准指示器,退化为目标
    BigTrapSmallReturnActor = 5, -- 大圈套小圈,退化为目标
    BigCircleSkillRange = 6, -- 大圈模式,释放技能类型,非瞄准,仅显示技能范围
    SelfCircle = 7, -- 自身瞄准圆形：以自身为圆心旋转圆形瞄准指示器
}

EJoyStickWarningType = {
    None = 0,
    Circle = 1, -- 圆形
    Rectangle = 2, --
    Sector = 3,
}

-- ability 类型
EAbilityType = {
    Skill = 0,      -- 技能
    Buff = 1,       -- buff
}

-- 目标筛选来源类型
ERuleSourceType = {
    Shape = 0,      -- 通过形状范围筛选
    Team = 1,       -- 通过队伍（队伍成员)
    Param = 2,       -- 来源为外部参数传入
}

-- 目标筛选退化模式（通过退化规则来补充不足的数量)
ETargetSelectBackupMode = {
    UseNewSelectRule = 0,   -- 完全使用新的目标筛选规则
    UseNewShape = 1,        -- 仅使用新的范围
    UseNewFilter = 2,       -- 仅使用新的过滤规则
}

ESkillLockTargetAliveType = {
    Alive = 0, -- 目标存活时才锁定目标
    Dead = 1, -- 目标死亡时才锁定目标
}

ESkillCastDirectionModeType = {
    None = 0,       -- 无方向
    TargetFirst = 1, -- 优先目标方向
    JoyStickFirst = 2, -- 优先摇杆方向
}

-- 技能禁用通用ID
EDisableSkillRequestID = {
    ParallelBehavior = 100,          -- 并行行为
    SocialAction = 101,              -- 社交行为
    PlayerTask = 102,                -- 玩家任务
}

-- CheckTargetNum mode
ECheckTargetNumMode = {
    CheckByRule = 0,   -- 用RuleID获取目标数量的逻辑
    CurrentAttackTargetNum = 1,  -- 表示直接获取当前结算流程目标的数量（前提当然是当前检查的时候处于已经获取到数量的结算流程状态，不然获取的数量只会是0）
    LockTargetNum = 2,      -- 当前锁定目标数量（0或1）
}

-- 目标位置类型（用于Attack）
ETargetPositionType = {
    SelfPos = 0,
    LockTargetPos = 1,
    BlackBoardPos = 2,
    InputPos      = 3,
}


-- 目标朝向类型（用于Attack）
EYawType = {
    SelfYaw = 0,
    LockTargetYaw = 1,
    BlackBoardAsTargetYaw = 2,
    InputPosAsTargetYaw = 3,
    WorldCoordinate = 4
}


-- 锁定目标类型(用于LockAttack)
ELockAttackTargetType = {
    LockTarget   = 0,
    SelectTarget = 1,
}

ESkillBehaviorType = {
    GROUND_SKILL = 1,
    AIR_SKILL = 2,
    PARALLEL_SKILL = 3,
    GR_CONTROL = 4,
}


ESkillQTEResult = {
    Success = 0,
    End     = 1,
    Failed  = 2,
}

EAsideTalkTargetType = {
    AllPlayer = 0,
    Owner = 1,
    LockTarget = 2,
    SearchTarget = 3,
}

-- 给 flowchart 发送消息的目标选项
ESenFlowchartTargetMode = {
    SkillOrBuff = 0,     --技能/buff对象目标(持有者/始作俑者)
    Level = 1,           -- 关卡/场景为目标
    Nearby = 2,          -- 范围内对象为目标
    TargetSelection = 3, -- 目标筛选为目标
}

-- buff层数的来源
EBuffLayerSourceType = {
    TaskLayer = 0,      -- task配置的层数
    SearchNum = 1,      -- 黑板中searchTargetList
    AttackNum = 2,      -- 黑板中的attackTargetsNum 或 attackTargetsList
    Formula = 3,        -- 公式计算
}

-- Buff改变监听事件类型
EBuffChangeType = {
    AddBuff = 0, -- 添加BUFF
    RemoveBuff = 1, -- 移除BUFF
    AddLayer = 2, -- 叠加BUFF层级
    RemoveLayer = 3, -- 移除BUFF层级
    AddLevel = 4, -- BUFF增加等级
    RemoveLevel = 5, -- BUFF减少等级
    ResetTime = 6, -- 重置时间
    ResetMaxLayer = 7, -- 重置最大层数
    ResetInstigatorID = 8, -- 刷新始作俑者
}

-- 阵营检查类型
EDynamicCampType = {
    RedNameRule = 1,    -- 红名阵营判断规则
}


-- buff类型
EBuffType = {
    Neutral = 0,         -- 中性buff
    Positive = 1,        -- 增益buff
    Negative = 2,        -- 减益buff
}

-- buffTags
EBuffTags = {
    None         = 0,                 -- 无效值
    -- buff性质大类（1~20）
    Control      = 1,                 -- 控制

    -- 具体状态标签(21~50)
    SlowDown     = 21,                -- 减速
    Imprisoned   = 22,                -- 禁锢
    Stealth      = 23,                -- 隐身
    Dizziness    = 24,                -- 眩晕
    Ridicule     = 25,                -- 嘲讽
    Fear         = 26,                -- 恐惧
    Silent       = 27,                -- 沉默
    Hypnotize    = 28,                -- 催眠
    Endure       = 29,                -- 霸体
    Chaos        = 30,                -- 混乱

    -- 特殊概念(51~256)
    GuildBuff    = 51,                -- 公会祈福buff组
    SpinWheelColor = 52,              -- 小丑转盘buff组
    Dance        = 53,                -- 小丑尬舞buff组
}

-- 技能类型(禁用等逻辑判断)
ESkillType = {
    NormalSkill = 1,     -- 普通技能
    NormalAttack = 2,    -- 普攻
    DodgeSkill = 4,      -- 闪避
    UltimateSkill = 8,   -- 绝技
    DeControlSkill = 16, -- 解控
    JumpSkill = 32,      -- 跳跃
}

-- 技能Tags
ESkillTags = {
    None         = 0,                 -- 无效值
    -- 技能大类标签（1~20）
    Professional = 1,                 -- 职业技能
    Sealed       = 2,                 -- 封印物技能

    -- 特殊功能标签（21~50）
    Displacement = 21,                -- 位移
    Revive       = 22,                -- 复活
    CounterAttack= 23,                -- 反击

    -- 各细化标签
    -- 太阳（51~60）
    -- 空想家（61~70)
    NightMare 	 = 61,                -- 噩梦形态连招
    Vis_Heal     = 62,                -- 观众治疗技能
    Vis_Damage   = 63,                -- 观众伤害技能
    -- 愚者（71~80）
    -- 仲裁人（81~90）
    ArbSkill     = 81,                -- 精神穿刺连招
    -- 学徒（91~100）
    -- 战士（101~110）
    War_xuanfeng = 101,               -- 旋风
    War_flyatk   = 102,               -- 浮空连斩连招
    -- 非职业（111~256）
    AlgerSpec    = 111,               -- 阿尔杰冲浪
}

EAddBuffResult = {
    Sucess = 0, -- 检查成功
    DelaySucess = 1, -- 检查成功但延迟释放
    ErrorLayer = 2, -- 错误的层级数据
    CompDeactive = 3, -- Buff组件未激活
    NoBuffData = 4, -- 无效Buff资源
    NoBuffInstance = 5, -- 无效Buff实例
    Immuned = 6, -- 已被免疫
    DataInValid = 7, -- 部分数据不合法
    Unfortunately = 8, -- 添加概率检测失败
    ReplicatedTargetError = 9, -- 广播目标不允许
    TargetInValid = 10, -- 添加buff对象不合法
    NotInSpace = 11, -- 不在space上
}

EReleaseSkillResult = {
    Sucess = 0, -- 检查成功
    DelaySucess = 1, -- 检查成功但延迟释放
    CompDeactive = 2, -- 技能组件未激活
    NoSkillData = 3, -- 无效技能资源
    NoSkillInstance = 4, -- 无效技能实例
    InCoolDown = 5, -- 还在冷却中
    InValidTarget = 6, -- 无效目标
    ConditionFail = 7, -- 条件检查失败
    DisabledType = 8, -- 该类型被禁用
    DisabledTag = 9, -- 该标签被禁用
    NotEnoughMP = 10, -- 魔法值不够
    NotEnoughPower = 11, -- 耐力值不够
    NotEnoughProp = 12, -- 其他属性值不够
    GameLogicForbidden = 13, -- 玩法逻辑禁止技能释放
    DataInValid = 14, -- 部分数据不合法
    MoveModeFail = 15, -- 移动模式不合法
    ForbiddenPBRule = 16, -- 被行为组件禁用
    NotEnoughSkillPower = 17, -- 绝技点不够
    ComboCastInvalid = 18, -- 连招释放不合法
    SkillIsLocked = 30,  -- 技能未解锁
    SkillNoEquipped = 31, -- 技能未装备上
    SkillIsPassiveOrBeaten = 32, -- 不能主动释放被动或者受击技能
    InstigatorInvalid = 33, -- 始作俑者Id非法
    TriggerInvalid = 34, -- 触发者Id非法
    ExtraDataInvalid = 35, -- ExtraData非法
    InvalidRoleSkill = 36, -- 不是该职业的职业技能
    NotEnoughFightRes = 37, -- 释放所需战斗资源不足
    NotInSpace = 38, -- 不在space上
}

EBSAFinishReason = {
    FR_EndOfLife = 0, -- 寿终正寝
    FR_Interrupt = 1, -- 被中断
    FR_PredictionFailure = 2, -- 预测失败
    FR_TMax = 3, -- FR TMax
}


EValueCalcType = {
    ConfigValue = 0,    -- 配置的值
    Formula = 1,        -- 公式计算
}

-- 攻击盒移动方式
EAttackBoxMoveType = {
    None = 0,           -- 不移动
    Rotate = 1,         -- 仅旋转
    Move = 2,           -- 位移(暂未支持)
}

-- 攻击盒旋转方向
EAttackBoxRotateDir = {
    Clockwise = 0,          -- 顺时针
    Counterclockwise = 1,   -- 逆时针
}

-- 可移动攻击盒偏移模式
EMovableAttackOffsetMode = {
    OffsetRealTime = 0,     -- 中心点即时偏移（移动更新之后，每次攻击的时候，攻击盒中心点基于当前位置的偏移）
    OffsetInitPos = 1,      -- 初始点偏移（仅用于计算初始点的偏移）
}

-- buff line linked 模式
EBuffLineLinkMode = {
    One2Multi = 1,          -- 1连多
    PairWise = 2,           -- 两两连接（目标总人数需要是偶数)
}

EBattleButtonInteractRes = {
    Success = 0,            -- 交互成功
    ClickNumMax = 1,        -- 点击次数超上限
    ButtonInCD = 2,         -- 按钮CD中
    InvalidDist = 3,        -- 未达可交互距离
    InvalidButton = 3,      -- 非法按钮
    SelfInteract = 4,       -- 不允许持有者交互
}

-- 战斗行为限制类型
EFightLimitType = {
    HitLimit = 0,           -- 无法被攻击(IsHitLimit)
    LockLimit = 1,          -- 无法被锁定(IsLockLimit)
    HealLimit = 2,          -- 无法被治疗(IsHealLimit)
    PBlockLimit = 3,        -- 物理（现实）攻击无法被阻挡(pBlockLimit)
    MBlockLimit = 4,        -- 法术（神秘）攻击无法被阻挡(mBlockLimit)
}

-- 参数类型
EParamType = {
    Bool = 0,               -- Bool类型
    Int = 1,                -- Int类型
    String = 2,             -- String类型
    Nil = 3,                -- Nil类型
}

-- 伤害衰减类型
EDamageAttenuationType = {
    None = 0,               -- 不开启伤害数值衰减
    AOE = 1,                -- 启用泛用AOE衰减
    Bullet = 2,             -- 启用泛用子弹衰减
}


-- 子弹运动类型
EBulletMotionType = {
    Linear = 0,             -- 直线运动
    Curvilinear = 1,        -- 曲线运动
    Parabolic = 2,          -- 抛物线运动
    Surrounding = 3,        -- 环绕运动（暂只支持圆形环绕)
}

-- 子弹发射模式
EBulletLaunchMode = {
    Parallel = 0,           -- 并行发射
    FanShape = 1,           -- 扇形发射
    StarShape = 2,          -- 星形发射
}

-- 单次AOE攻击最大目标数量(PVE或者非pvp)
AOE_MAX_NUM = 30

-- 单次AOE攻击最大目标数量(PVP)
AOE_MAX_NUM_PVP = 12

-- 扫描碰撞子弹最大命中次数(PVE或者非pvp)
BULLET_MAX_HIT_COUNT = 30

-- 扫描碰撞子弹最大命中次数（PVP)
BULLET_MAX_HIT_COUNT_PVP = 12

-- buffattack的受击者类型
EBuffAttackDefenderType = {
    TargetSelection = 0,   -- 目标筛选结果
    EffectTargetType = 1,  -- effectTemplate中选配的目标
}

-- 玩家行为状态检查类型
EActionStateType = {
    Move = 0,       -- 移动
    Jump = 1,       -- 跳跃
    CastSkill = 2,  -- 释放技能
}

-- 客户端GID范围起始点
CLIENT_COMBAT_INS_ID_BEGIN = 1000000
-- 服务器GID范围起始点
SERVER_COMBAT_INS_ID_BEGIN = 2000000
SERVER_COMBAT_INS_ID_END = 3000000