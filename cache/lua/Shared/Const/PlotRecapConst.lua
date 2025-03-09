-- 剧情回顾的状态
PLOT_RECAP_STATE = {
    LOCK = 0,             -- 未解锁
    WAIT_SUBMIT = 1,      -- 可提交
    UNLOCK = 2,           -- 已解锁
}



-- 剧情回顾的类型
PLOT_RECAP_TYPE = {
    FACT_MAIN_RECAP = "FactMainRecap",    -- 现实主线
    MIST_MAIN_RECAP = "MistMainRecap",    -- 迷雾主线
    FACT_SIDE_RECAP = "FactSideRecap",    -- 现实支线
    MIST_SIDE_RECAP = "MistSideRecap",    -- 迷雾支线
    SIDE_QUEST_RECAP = "SideQuestRecap",  -- 普通支线 
}


-- 支线剧情回顾类型
SIDE_PLOT_RECAP_TYPE = {
    [PLOT_RECAP_TYPE.FACT_SIDE_RECAP] = 1,
    [PLOT_RECAP_TYPE.MIST_SIDE_RECAP] = 1,
    [PLOT_RECAP_TYPE.SIDE_QUEST_RECAP] = 1,
}
