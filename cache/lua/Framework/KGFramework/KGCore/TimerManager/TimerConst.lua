-- luacheck: push ignore
DebugModel = false --是否开启Debug模式，输出详细Log
PerformanceAnalysis = false --是否开启性能分析
TickThreshold = 50 --毫秒 决定Timer走时间轮还是tick计时的阈值
TickTime = 20 --毫秒   时间轮最小精度
TimeWheelConfig = {200, 60, 60, 24, 360}  --4秒，4分钟，4小时，4天，1440天 这里是配置每个时间轮的刻度不是时间 时间是刻度乘以精度
TimerDurationLimit = 124416000000
-- luacheck: pop