-- 布尔属性压缩存储 减少属性数量，增加需要存储或同步的bool属性直接在此添加即可
-- 详见文档 https://docs.corp.kuaishou.com/k/home/VYf7Ko_10lKw/fcAAHfjZakUsjidU1g2_xJx3D

-- id间隔不要过大，排列紧密压缩效果更好 上线后禁止修改
IS_AUTO_CUNSUME_LOUD_SPEAKER_MONEY = 10 -- 没有喇叭道具的情况下自动消耗货币
IS_DIALOGE_OPTION_REPORT_SERVER = 15 -- 是否上报对话选项
IS_ENTER_TEAROOM = 20 -- 是否正在进入茶壶房间
IS_CREATE_TEAROOM = 21 -- 是否正在创建茶壶房间
IS_TEAROOM_BARRAGESWITCH = 22 -- 茶壶房间的弹幕

FLAG_DEF =
{
    --[key] -> {是否变化通知客户端, 是否可以客户端改动, 是否需要持久化}
    --如果均为false 可以不添加
    [IS_AUTO_CUNSUME_LOUD_SPEAKER_MONEY] = {true, true, true},
    [IS_TEAROOM_BARRAGESWITCH] = {true, true, true},
    [IS_DIALOGE_OPTION_REPORT_SERVER] = {true,false,false},
}

-- 初始值为true的flag
-- 数组，角色上线时会遍历初始化
DEFAULT_TRUE_FLAG = {
    -- xx,
}

-- 需要同步到数据中心的设置 map
NEED_SYNC_BOOL_PROP = {
    -- xx = true,
}