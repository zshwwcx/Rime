ProfilerInstrumentationConfig = {
    UIEvent = {
        name = 'UIEvent',
        description = 'ui事件',
        Threshold = {17,17,16,16,15}
    },
    UIShow = {
        name = 'UIShow',
        description = 'ui 打开',
        Threshold = {17,17,16,16,15}
    },
    UITick = {
        name = 'UITick',
        description = 'ui tick',
        Threshold = {17,17,16,16,15}
    },
    MainTick = {
        name = 'MainTick',
        description = '',
        Threshold = {20,20,19,19,18}
    },
    PropertySync = {
        name = 'PropertySync',
        description = '属性同步',
        Threshold = {17,17,16,16,15}
    },
    BattleBuffUpdate = {
        name = 'BattleBuffUpdate',
        description = '战斗buff更新',
        Threshold = {17,17,16,16,15}
    },
    BattleSkillUpdate = {
        name = 'BattleSkillUpdate',
        description = '战斗技能更新',
        Threshold = {17,17,16,16,15}
    },
    BattleTick = {
        name = 'BattleTick',
        description = '战斗tick',
        Threshold = {17,17,16,16,15}
    },
    HeadInfoDistanceCheck = {
        name = 'HeadInfoDistanceCheck',
        description = '头顶信息距离检测' ,
        Threshold = {17,17,16,16,15}
    },
    HeadInfoBuffStart = {
        name = 'HeadInfoBuffStart',
        description = '头顶信息buff开始',
        Threshold = {17,17,16,16,15}
    },
    HeadInfoBuffEnd = {
        name = 'HeadInfoBuffEnd',
        description = '头顶信息buff结束',
        Threshold = {17,17,16,16,15}
    },
    STATS_MISC = {
        name = 'STATS_MISC',
        description = 'STATS_MISC',
        Threshold = {17,17,16,16,15}
    },
    STATS_MESSAGE = {
        name = 'STATS_MESSAGE',
        description = 'STATS_MESSAGE',
        Threshold = {17,17,16,16,15}
    },
    STATS_PROPERTY = {
        name = 'STATS_PROPERTY',
        description = 'STATS_PROPERTY',
        Threshold = {17,17,16,16,15}
    },
    STATS_VOLATILE_UPDATE = {
        name = 'STATS_VOLATILE_UPDATE',
        description = 'STATS_VOLATILE_UPDATE',
        Threshold = {17,17,16,16,15}
    },
    STATS_VOLATILE_CONTROLLED_BY = {
        name = 'STATS_VOLATILE_CONTROLLED_BY',
        description = 'STATS_VOLATILE_CONTROLLED_BY',
        Threshold = {17,17,16,16,15}
    },
    STATS_ENTER_SPACE = {
        name = 'STATS_ENTER_SPACE',
        description = 'STATS_ENTER_SPACE',
        Threshold = {17,17,16,16,15}
    },
    STATS_LEAVE_SPACE = {
        name = 'STATS_LEAVE_SPACE',
        description = 'STATS_LEAVE_SPACE',
        Threshold = {17,17,16,16,15}
    },
    STATS_CLIENT_HOTFIX = {
        name = 'STATS_CLIENT_HOTFIX',
        description = 'STATS_CLIENT_HOTFIX',
        Threshold = {17,17,16,16,15}
    },
    STATS_SCENE_MESSAGE = {
        name = 'STATS_SCENE_MESSAGE',
        description = 'STATS_SCENE_MESSAGE',
        Threshold = {17,17,16,16,15}
    },
    STATS_DESTROY_ENTITY = {
        name = 'STATS_DESTROY_ENTITY',
        description = 'STATS_DESTROY_ENTITY',
        Threshold = {17,17,16,16,15}
    },
    STATS_CREATE_ENTITY = {
        name = 'STATS_CREATE_ENTITY',
        description = 'STATS_CREATE_ENTITY',
        Threshold = {17,17,16,16,15}
    },
    STATS_CALLBACK_MESSAGE = {
        name = 'STATS_CALLBACK_MESSAGE',
        description = 'STATS_CALLBACK_MESSAGE',
        Threshold = {17,17,16,16,15}
    },
    STATS_CREATE_ENTITY_BRIEF = {
        name = 'STATS_CREATE_ENTITY_BRIEF',
        description = 'STATS_CREATE_ENTITY_BRIEF',
        Threshold = {17,17,16,16,15}
    },
    STATS_ENTITY_TO_BRIEF = {
        name = 'STATS_ENTITY_TO_BRIEF',
        description = 'STATS_ENTITY_TO_BRIEF',
        Threshold = {17,17,16,16,15}
    },
    STATS_BRIEF_TO_ENTITY = {
        name = 'STATS_BRIEF_TO_ENTITY',
        description = 'STATS_BRIEF_TO_ENTITY',
        Threshold = {17,17,16,16,15}
    },
    STATS_TRACEROUTE = {
        name = 'STATS_TRACEROUTE',
        description = 'STATS_TRACEROUTE',
        Threshold = {17,17,16,16,15}
    },
    MainProfileItem = {
        -- 总体耗时计算
        'UIEvent', 'MainTick', 'PropertySync', 'BattleTick'
    },
    MaxRecordNum = 100
}

return ProfilerInstrumentationConfig