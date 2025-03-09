--[[
    [底层:第一部分->底层生命周期] -> {ctor, Init, UnInit, Destroy} 底层管理. 上层不要复写, 可以调用.
    [上层:第二部分->上层生命周期] -> {onCtor, onInit, onUnInit, onDestroy} 上层System的生命周期处理.
    [上层:第三部分->常用调用时机] -> {OnBackToLogin, ...} 上层视情况实现, 来驱动自身生命周期的切换
--]]

local EventBase = kg_require("Framework.EventSystem.EventBase")
local TimerComponent = kg_require("Framework.KGFramework.KGCore.TimerManager.TimerComponent")
---@class SystemBase:EventBase,TimerComponent System基类
SystemBase = DefineClass("SystemBase", EventBase, TimerComponent)

--------------------------------对外的生命周期函数, 上层逻辑不要复写, 可以调用--------------------------------

--上层使用onCtor
function SystemBase:ctor(config)
    self.config = config
    self:onCtor()
end

function SystemBase:GetConfig()
    return self.config
end

--配置Tick参数. 上层使用onTick
function SystemBase:tick(deltaTime)
    self:onTick(deltaTime)
end

--上层使用onInit
function SystemBase:Init()
    self:onInit()
    self:BatchAddListener()
end

--上层使用onUnInit
function SystemBase:UnInit()
    self:onUnInit()
    self:RemoveAllListener()
    self:StopAllTimer()
end

--上层使用onDestroy
function SystemBase:Destroy()
    self:onDestroy()
    EventBase.OnDestroy(self)
    self:StopAllTimer()
end

--------------------------------生命周期响应函数, 底层只定义, 由上层具体实现--------------------------------

--第一个生命周期, 仅用来定义成员,处理默认值, 不要对外依赖.
function SystemBase:onCtor()
end

--第二个生命周期, 在所有System.onCtor之后, 初始化成员, 可以用来处理对外依赖
function SystemBase:onInit()
end

--清理函数, 非destroy, 用于回收资源, 恢复到init状态
function SystemBase:onUnInit()
end

--最后一个生命周期, 执行完成后将注销Game.GameplayManagers.xxx, 实现关闭前存盘等操作
function SystemBase:onDestroy()
end

--用于执行Tick逻辑
function SystemBase:onTick()
end

--------------------------------其他外部状态调用, 由上层具体实现--------------------------------
--[[
--登录
function SystemBase:OnLogin()
end

--返回登录
function SystemBase:OnBackToLogin()
end

--返回选角
function SystemBase:OnBackToSelectRole()
end

--断线重连重登成功（RetLogin之后）
function SystemBase:OnReLogin()
end

--网络连接
function SystemBase:OnNetConnected()
end

--网络断开
function SystemBase:OnNetDisconnected()
end

--内存警告
function SystemBase:OnMemoryWarning()
end

--UObject数量超警告
function SystemBase:OnObjectCountNearlyExceed(currentObjectCount)
end

--me构造完成
function SystemBase:AfterPlayerInit()
end

--场景loading完成
function SystemBase:OnWorldMapLoadComplete(levelId)
end

--场景销毁
function SystemBase:OnWorldMapDestroy(levelId)
end

--OnMainPlayerCreate MainPlayer创建|销毁
function ManagerBase:OnMainPlayerCreate()
end

--OnMainPlayerDestroy MainPlayer销毁
function ManagerBase:OnMainPlayerDestroy()
end

--主角进入世界
function ManagerBase:OnMainPlayerEnterWorld()
end

--主角离开世界
function ManagerBase:OnMainPlayerExitWorld()
end

--]]