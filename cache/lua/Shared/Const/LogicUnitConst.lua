-- logic unit type
LOGIC_UNIT_TYPE = {
    Trap = 1,               -- 陷阱
    Aura = 2,               -- 光环
    SpellField = 3,         -- 法术场
    SpellAgent = 4,         -- 施法代理(用于脱手技能)
    SummonMonster = 5,      -- 创生怪物
    VelocityField = 6,      -- 引力场(一种特殊的光环)
    Interactor = 7,         -- 交互物
}


-- 法术场阶段
SPELL_FIELD_STAGE = {
    INIT = 0,               -- 初始化
    DEPLOY = 1,             -- 部署阶段
    DELAY_RUNNING = 2,      -- 延迟触发阶段
    RUNNING = 3,            -- 运行生效阶段
    PENDING_DESTROY = 4,    -- 等待销毁阶段
}

-- 施法代理单位阶段
SPELL_AGENT_STAGE = {
    INIT = 0,               -- 初始化
    DEPLOY = 1,             -- 部署阶段(延迟)
    RUNNING = 2,            -- 运行中
    PENDING_DESTROY = 3,    -- 等待销毁结算
}

-- 光环阶段
AURA_STAGE = {
    INIT = 0,               -- 初始化
    DEPLOY = 1,             -- 部署阶段
    RUNNING = 2,            -- 运行生效阶段
    PENDING_DESTROY = 3,    -- 等待销毁阶段
}

-- 陷阱阶段
TRAP_STAGE = {
    INIT = 0,               -- 初始化
    DEPLOY = 1,             -- 部署阶段
    WAIT_FOR_TRIGGER = 2,   -- 等待触发阶段
    DELAY_TAKE_EFFECT = 3,  -- 等待生效阶段(已经触发、等待生效)
    TAKE_EFFECT = 4,        -- 触发效果阶段(瞬间)
    CHARGING = 5,           -- 触发之后重新充能阶段
    PENDING_DESTROY = 6,    -- 等待销毁阶段
}

-- 交互物代理阶段
INTERACTOR_AGENT_STAGE = {
    INIT = 0,               -- 初始化
    DEPLOY = 1,             -- 部署阶段(延迟)
    RUNNING = 2,            -- 运行中
    PENDING_DESTROY = 3,    -- 等待销毁结算
}

-- 陷阱触发方式
TRAP_TRIGGER_TYPE = {
    BY_TRIGGER = 0,         -- 引爆(外部触发)
    BY_TIME = 1,            -- 生命周期到了
    BY_TRIGGER_OR_TIME = 2, -- 引爆或者生命周期到了
}

-- 陷阱销毁方式
TRAP_DESTROY_TYPE = {
    LIFE_EXPIRED = 0,       -- 生命周期到了
    TRIGGERED = 1,          -- 有单位进入触发
}

-- LogicUnit删除原因
LOGIC_UNIT_DESTROY_REASON = {
    END_OF_LIFE = 0,            -- 生命周期到了
    INTERRUPT = 1,              -- 中断
    INSTIGATOR_DEAD = 2,        -- 始作俑者死亡
    INSTIGATOR_LEAVE_SPACE = 3, -- 始作俑者离开场景
    INSTIGATOR_DESTROY = 4,     -- 始作俑者销毁(死亡)
    EXCEED_MAX_DEPLOY_NUM = 5,  -- 超过最多部署数量(陷阱专用)
    REACH_MAX_TRIGGER_NUM = 6,  -- 达到最大触发次数(陷阱专用)
    TRAP_TRIGGERED = 7,         -- 有单位触发了trap(陷阱专用)
    TASK_INTERRUPT = 8,         -- task调用导致的中断
}

-- 初始方向
ORIGINAL_DIRECTION_TYPE = {
    LAUNCHER = 1,           -- 直属父单位面向：（比如抛射物落地触发法术场，那么直属父单位就是抛射物）
    INSTIGATOR = 2,         -- 始作俑者: Owner面向（Owner是指角色、怪物这一层级）
    TARGET = 3,             -- 目标方向：筛选出来的目标所处方向（XOY平面投影）；如果没有筛选，则选默认目标；如果没有默认目标，则角色面向方向
    INSTIGATOR_CONNECTION = 4, -- Owner连线方向：从角色到创建位置的连线在XOY平面上的投影方向
    SPECIFIC_DIRECTION = 5, -- 指定方向：手动指定创造者坐标系下的方向矢量（右摇杆、调用Pos等，后续扩展）
}

-- 浮点数精度
FLOAT_TOLERANCE = 0.0001

-- 子弹销毁原因
BULLET_DESTROY_REASON = {
    END_OF_LIFE = 0,            -- 生命周期到了
    HIT_TARGET = 1,             -- 命中目标
    REACH_MAX_HIT_TIMES = 2,    -- 到达命中次数上线
    REACH_TARGET_POS = 3,       -- 到达了目标位置
    INSTIGATOR_DEAD = 4,        -- 始作俑者死亡
    INSTIGATOR_LEAVE_SPACE = 5, -- 始作俑者离开场景
    INSTIGATOR_DESTROY = 6,     -- 始作俑者销毁(死亡)
    TARGET_DESTROY = 7,         -- 目标销毁了
    INTERRUPT = 8,              -- 中断(外部主动销毁)
}

-- 子弹类型
BULLET_TYPE = {
    MUST_HIT_TARGET = 0,        -- 必中目标单位子弹（目标单位确定，延迟必中结算）
    FOLLOW = 1,                 -- 追踪子弹（不停的追踪目标单位，不一定追的上）
    SWEEP = 2,                  -- 扫描子弹（目标位置确定）
    MUST_HIT_POS = 3,           -- 必中目标位置子弹(目标位置确定，延迟必中结算）
}

-- 子弹初始方向类型
BULLET_INIT_DIRECTION_TYPE = {
    LAUNCHER = 1,           -- 发射者方向(直属父单位面向)
    LAUNCHER_TO_TARGET = 2, -- 发射者到目标连线方向
}

-- 子弹销毁条件
BULLET_DESTROY_CONDITION = {
    NONE = 0,               -- 不特殊销毁
    INSTIGATOR_DEAD = 1,    -- 创建者死亡销毁
}

-- 子弹碰撞形状
BULLET_COLLISION_SHAPE = {
    NONE = 0,                   -- 无碰撞
    SPHERE = 1,                 -- 球形
}

-- 子弹额外效果触发类型
BULLET_EXTRA_TRIGGER_TYPE = {
    HIT_TARGET = 0,             -- 命中目标(对于子弹类型0和1而言, 命中目标单位触发；对于子弹类型2，过程中碰到其他单位)
    REACH_DEST_POS = 1,         -- 到达目标点(字子弹类型2和3有效）
    HIT_TARGET_OR_DEST = 2,     -- 命中目标或者到达目标点(HIT_TARGET or REACH_DEST_POS)
    DESTROY = 3,                -- 销毁触发(命中单位销毁、到达目标点销毁、命中次数到达上限销毁、到时间销毁）
}

-- 抛射物路径类型
TRAJECTILE_PATH_TYPE = {
    PARABOLA = 0,               -- 抛物线
    LINE = 1,                   -- 直线
}

-- 抛射物销毁原因
TRAJECTILE_DESTROY_REASON = {
    END_OF_LIFE = 0,            -- 生命周期到了
    HIT_TARGET = 1,             -- 命中目标
    REACH_TARGET_POS = 2,       -- 到达终点
    INSTIGATOR_DEAD = 3,        -- 始作俑者死亡
    INSTIGATOR_LEAVE_SPACE = 4, -- 始作俑者离开场景
    INSTIGATOR_DESTROY = 5,     -- 始作俑者销毁(死亡)
    INTERRUPT = 6,              -- 中断(外部主动销毁)
}

-- 抛射物额外效果触发类型
TRAJECTILE_EXTRA_TRIGGER_TYPE = {
    REACH_TARGET_POS = 0,       -- 落点（到达终点）额外触发
    HIT_TARGET = 1,             -- 命中（碰到单位）额外触发
    DESTROY = 2,                -- 销毁（落点和命中单位）都会额外触发
}

-- 终点坐标系类型
TRAGET_COORDINATE_TYPE = {
    INVALID = 0,                -- 非法坐标系
    CREATEOR = 1,               -- 创建者坐标系
    ORIGINAL_BY_TARGET_AND_DIR_CONN = 2,    -- 目标为原点，然后创建者到目标连线为x方向坐标系
}
