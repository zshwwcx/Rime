local LRUCache = kg_require("Shared.Container.LRUCache")

local KGActorUtil = import("KGActorUtil")
local AGS = import("AkGameplayStatics")
local KSL = import("KismetSystemLibrary")
local EPropertyClass = import("EPropertyClass")
local EAkCallbackType = import("EAkCallbackType")
local UAkComponent = import("AkComponent")
local BlendTypeLinear = import("EAkCurveInterpolation").Linear
local EAkResult = import("EAkResult")

local UNDER_LINE = "_" -- luacheck: ignore
local AK_INVALID_PLAYING_ID = 0 -- luacheck: ignore
local FOOT_STEP_DEFAULT = "Default" -- luacheck: ignore
local TERRAIN_NAME_DEFAULT = "Default" -- luacheck: ignore
local TERRAIN_NAME_WATER = "Water" -- luacheck: ignore
local DEFAULT_PHYSICAL_MATERIAL_NAME = "DefaultPhysicalMaterial" -- luacheck: ignore
local NAME_NONE = "None" -- luacheck: ignore
local MAIN_PLAYER_SUFFIX = "_1P" -- luacheck: ignore
local __Playing_ID_Array = slua.Array(EPropertyClass.Int) -- luacheck: ignore


--region UEClassDefine


---@class FKGGroupState
---@field Group string
---@field State string


--endregion UEClassDefine


--region LRU


---@class AudioLRUCache : LRUCache
local AudioLRUCache = DefineClass("AudioLRUCache", LRUCache)

---@overload
function AudioLRUCache:_popTail()
    if self.count > 0 then
        local node = self.tail.prev
        self:_removeNode(node)
        self.cache[node.key] = nil
        Game.AkAudioManager:onLruPopBank(node.data)
    end
end

---@return string[]
function AudioLRUCache:emptyAll()
    local datas = {}
    for _, node in pairs(self.cache) do
        table.insert(datas, node.data)
    end
    self:clear()
    return datas
end


--endregion LRU


---@class AsyncLoadBankTask
AsyncLoadBankTask = DefineClass("AsyncLoadBankTask")

-- 异步加载Task缓存池大小
AsyncLoadBankTask.__PoolSize = 16
-- 对象池数量预警
AsyncLoadBankTask.__PoolSizeWarningThreshold = 64

function AsyncLoadBankTask:ctor()
    self:on_recycle_to_pool()
end

function AsyncLoadBankTask:on_recycle_to_pool()
    self.taskID = 0
    self.eventName = ""
    self.akCompID = 0
    self.location = nil -- FVector()
    self.postType = 0
end


---@class AkAudioManager
AkAudioManager = DefineClass("AkAudioManager")

-- 战斗音效数量限制
AkAudioManager.BattleLimit = tonumber(Enum.EAudioConstData.BATTLE_MAX_PLAYBACK_LIMIT)

-- 脚步&动作音效数量限制
AkAudioManager.NotifyEventLimit = tonumber(Enum.EAudioConstData.FOOTSTEP_N_ACTION_LIMIT)

-- 音频播放类型
AkAudioManager.Event_Post_Type = {
    ON_LOCATION = 1, -- 固定位置播放
    ON_ACTOR = 2, -- 跟随Actor播放
}

-- lru支持的最大bank内存,暂定20(mb)
AkAudioManager.Lru_Memory_Limit = 15

-- 玩家位次后缀
AkAudioManager.EPlayerSlotSuffix = {
    P1 = "_1P",
    P2 = "_2P",
    P3 = "", -- 占位用
}

-- 性别后缀
AkAudioManager.EGenderSuffix = {
    INVALID = "", -- 占位用
    MALE = "_M",
    FEMALE = "_F",
}


--region Core


---@private
function AkAudioManager:initMembers()
    ---@type table<number, string> UI事件对应的event类型
    self.UIEventMap = {}

    ---@type boolean PC端下游戏窗口是否是当前聚焦
    self.bLostFocus = true

    ---@type table<string, number> 手动加载的bank,只能被手动卸载
    self.staticBanks = {}

    ---@type table<number, number> 同步播放时是playingID->playingID,异步播放时是taskID->playingID
    self.playingIDRef = {}

    ---@type table<number, AsyncLoadBankTask> 异步加载中的task缓存
    self.inLoadingTask = {}

    ---@type table<number, string> 局内播放的音频ID列表,此列表内所有音频会在单局生命周期结束后调用Stop
    self.autoStopIDList = {}

    ---@type table<string, string> 局内group和rtpc
    self.groupStates = {}

    ---@type table<string, number>
    self.rtpcs = {}

    ---@type table SrcEventKey->FootStep->TerrainName->NP->RealEventName
    self.footStepEventCache = {}

    ---@type table<string, string> SrcEventName->MaterialName->RealEventName
    self.actionEventCache = {}

    ---@type table SrcEventKey->VoiceType->NP->RealEventName
    self.voiceEventCache = {}

    ---@type table<string, string[]>
    self.uiBankCache = {}

    -- 三层Table,event->gender->playerSlot
    self.skillEventCache = {}

    ---@type table<string, number>
    self.serverPostEvents = {}

    ---@type table<string, string>
    self.serverSetGroupState = {}

    ---@type table<string, number>
    self.serverSetRtpcValue = {}

    -- 当前被锁定的敌方目标
    self.lockTargetUID = 0

    -- 输出地面材质和脚步事件的debug开关
    self.bEnableTerrainDebug = false

    -- 带优先级的GroupState队列
    self.priorityVolumeQueue = {}

    -- 当前生效的Volume
    self.curVolumeUniqueID = ""

    -- 当前生效的Volume对应的GroupState
    self.curVolumeGroupStates = nil

    -- 阶段切换的标记
    self.bNeedUnloadStageBank = false

    -- 区域标记
    self.sceneFieldType = 0

    -- 处于战斗状态的Actor的数量
    self.inBattleActorNum = 0

    -- 记录Actor的战斗状态
    self.inBattleActorMap = {}
end

-- lru能容纳的节点数量,但实际上淘汰是依据size来的,所以这里只是个默认值
local __Default_Lru_Limit = 100 -- luacheck: ignore

function AkAudioManager:Init()
    -- 初始化大部分成员变量
    self:initMembers()

    -- lru相关
    self.lruMemorySize = 0
    self.lru = AudioLRUCache.new(__Default_Lru_Limit)

    -- 初始化C++管理器
    self.cppMgr = import("KGAkAudioManager")(Game.WorldContext)
    Game.GameInstance:CacheManager(self.cppMgr)
    self.cppMgr:NativeInit()
    self:bindCppDelegate()

    if EUIEventTypes then
        self.UIEventMap[EUIEventTypes.CLICK] = "OnClicked"
        self.UIEventMap[EUIEventTypes.CheckStateChanged] = "OnCheckStateChange"
    end

    self.cppMgr:SetBattleEventLimitInfo(Enum.EAudioConstData.Skill_Battle_Playback_RTPC, self.BattleLimit)

    -- 加载AutoLoad的Bank
    self:loadAutoLoadBanks()

    -- 事件监听
    Game.EventSystem:AddListener(EEventTypes.LEVEL_ON_LEVEL_LOAD_START, self, self.Receive_LEVEL_ON_LEVEL_LOAD_START)
    Game.EventSystem:AddListener(EEventTypes.LEVEL_ON_LEVEL_LOADED, self, self.Receive_LEVEL_ON_LEVEL_LOADED)
    Game.EventSystem:AddListener(EEventTypes.LEVEL_ON_ROLE_LOAD_COMPLETED, self, self.Receive_LEVEL_ON_ROLE_LOAD_COMPLETED)
    --Game.EventSystem:AddListener(EEventTypes.ROLE_ON_DESTROY, self, self.Receive_ROLE_ON_DESTORY)

    -- 初始化地图音频相关
    self:initMapAudioTagParam()
end

function AkAudioManager:UnInit()
    local staticBankList = {}
    for bankName, _ in pairs(self.staticBanks) do
        table.insert(staticBankList, bankName)
    end
    self:SyncUnloadBankList(staticBankList, self, true)
    self.staticBanks = {}

    self.lruMemorySize = 0
    local lruBanks = self.lru:emptyAll()
    self:SyncUnloadBankList(lruBanks, self)

    if self.eventExpireProcessTimer then
        Game.TimerManager:StopTimerAndKill(self.eventExpireProcessTimer)
        self.eventExpireProcessTimer = nil
    end

    self:uninitMapAudioTagParam()
    self:unbindCppDelegate()
    Game.EventSystem:RemoveObjListeners(self)

    self.cppMgr:NativeUninit()
end

---@private
---@param nextLevelMapData LevelMapData
function AkAudioManager:Receive_LEVEL_ON_LEVEL_LOAD_START(nextLevelMapData)
    self.inBattleActorNum = 0
    self.inBattleActorMap = {}
    self:ResetGroupState(Enum.EAudioConstData.OTHER_BATTLE_STATE_GROUP)

    self:ResetRtpcValue(Enum.EAudioConstData.Skill_Battle_Playback_RTPC)
    self:mapAudioTag_onLevelLoadStart(nextLevelMapData)
    self:resetServerAudio()
    self:OnSceneFieldTypeChanged(0)
end

-- 回收局内产生的音频事件,设置的GroupState,Rtpc等
---@private
function AkAudioManager:Receive_LEVEL_ON_LEVEL_LOADED(levelMapData)
    self:mapAudioTag_onLevelLoadEnd(levelMapData)

    -- 回收所有被标记为需要清理的声音
    __Playing_ID_Array:Clear()
    for playingID, _ in pairs(self.autoStopIDList) do
        __Playing_ID_Array:Add(playingID)
    end

    self.cppMgr:StopAllByPlayingIDs(__Playing_ID_Array)
end

-- 获取调用方的信息,知道是哪个模块调用的即可
---@private
---@return string
function AkAudioManager:getOwnerName(owner)
    if not owner then
        return ""
    elseif (owner.GetName ~= nil) and (type(owner.GetName) == "function") then
        return owner:GetName()
    else
        return owner.__cname or ""
    end
end

---@public
---@param eventName string
---@return number 返回小于0为没有对应数据
function AkAudioManager:GetEventDuration(eventName)
    local AED = Game.TableData.GetAkAudioEventDataRow(eventName)
    return AED and AED.Duration or -1
end

---@public
---@param eventName string
---@return string
function AkAudioManager:GetEventRequiredBank(eventName)
    local AED = Game.TableData.GetAkAudioEventDataRow(eventName)
    return AED and AED.RequiredBank or ""
end

---@private
function AkAudioManager:bindCppDelegate()
    if not IsValid_L(self.cppMgr) then
        return
    end

    self.cppMgr.OnAnimNotify_ActionAkEventDelegate:Bind(function(skComp, akEvent, bMainPlayerOnly)
        self:OnAnimNotify_ActionAkEvent(skComp, akEvent, bMainPlayerOnly)
    end)

    self.cppMgr.OnAnimNotify_FootStepAkEventDelegate:Bind(function(skComp, akEvent, bNeedSplice)
        self:OnAnimNotify_FootStepAkEvent(skComp, akEvent, bNeedSplice)
    end)

    self.cppMgr.OnAnimNotify_VoiceAkEventDelegate:Bind(function(skComp, akEvent)
        self:OnAnimNotify_VoiceAkEvent(skComp, akEvent)
    end)

    self.cppMgr.OnAnimNotifyStateBegin_AkEvent:Bind(function(skComp, akEvent)
        self:OnAnimNotifyStateBegin_AkEvent(skComp, akEvent)
    end)

    self.cppMgr.OnAnimNotifyStateEnd_AkEvent:Bind(function(skComp, akEvent)
        self:OnAnimNotifyStateEnd_AkEvent(skComp, akEvent)
    end)

    self.cppMgr.OnBankLoadedDelegate:Bind(function(loadID, bankName)
        self:OnBankLoaded(loadID, bankName)
    end)

    self.cppMgr.OnSetGroupStateWithPriorityDelegate:Bind(function(uniqueID, groupState, priority)
        self:OnSetGroupStateWithPriority(uniqueID, groupState, priority)
    end)

    self.cppMgr.OnResetGroupStateWithPriorityDelegate:Bind(function(uniqueID, groupState, priority)
        self:OnResetGroupStateWithPriority(uniqueID, groupState, priority)
    end)

    self.cppMgr.OnPostTrackEventDelegate:Bind(function(akEvent, bEnableSync)
        self:OnPostTrackEvent(akEvent, bEnableSync)
    end)
end

function AkAudioManager:unbindCppDelegate()
    if not IsValid_L(self.cppMgr) then
        return
    end

    self.cppMgr.OnAnimNotify_ActionAkEventDelegate:Clear()

    self.cppMgr.OnAnimNotify_FootStepAkEventDelegate:Clear()

    self.cppMgr.OnAnimNotify_VoiceAkEventDelegate:Clear()

    self.cppMgr.OnAnimNotifyStateBegin_AkEvent:Clear()

    self.cppMgr.OnAnimNotifyStateEnd_AkEvent:Clear()

    self.cppMgr.OnBankLoadedDelegate:Clear()

    self.cppMgr.OnSetGroupStateWithPriorityDelegate:Clear()

    self.cppMgr.OnResetGroupStateWithPriorityDelegate:Clear()

    self.cppMgr.OnPostTrackEventDelegate:Clear()
end


--endregion Core


--region BattleSystem

-- 获取技能实际要播放的eventName并缓存
---@public
---@param srcEventName string
---@param playerSlotSuffix string
---@param genderSuffix string
function AkAudioManager:GetRealSkillEventName(srcEventName, playerSlotSuffix, genderSuffix)
    -- 建立空映射,方便查找
    genderSuffix = genderSuffix or self.EGenderSuffix.INVALID

    local realEventName = srcEventName

    local eventAsKey = self.skillEventCache[srcEventName]
    if not eventAsKey then
        self.skillEventCache[srcEventName] = {}
        eventAsKey = self.skillEventCache[srcEventName]
    end

    local genderAsKey = eventAsKey[genderSuffix]
    if not genderAsKey then
        eventAsKey[genderSuffix] = {}
        genderAsKey = eventAsKey[genderSuffix]
    end

    local slotAsKey = genderAsKey[playerSlotSuffix]
    if not slotAsKey then
        realEventName = srcEventName .. genderSuffix .. playerSlotSuffix
        genderAsKey[playerSlotSuffix] = realEventName
    else
        realEventName = genderAsKey[playerSlotSuffix]
    end

    return realEventName
end

-- 锁定目标更新时,记录ID并触发音效
---@public
---@param newTarget table UEActor
function AkAudioManager:OnLockTargetChanged(newTarget)
    if newTarget then
        self.lockTargetUID = newTarget:GetEntityUID()
        local lockTargetEnt = Game.EntityManager:GetEntityByIntID(self.lockTargetUID)
        if lockTargetEnt then
            self:PostEvent3D(Enum.EUIAudioEvent.Play_UI_Battle_Lock, lockTargetEnt:GetViewPosition())
        end
    else
        self.lockTargetUID = 0
    end
end

-- 判断一个localEntity是否是音频系统关注的主要目标
---@private
---@param instigator
function AkAudioManager:isMajorUnit(instigator)
    if not instigator then
        return false
    end

    local bIsMainPlayer = instigator == Game.me
    local bIsBoss = instigator.BossType == Enum.EBossType.BOSS
    local bIsLockTarget = instigator:uid() == self.lockTargetUID

    return (bIsMainPlayer == true) or (bIsBoss == true) or (bIsLockTarget == true)
end

-- 战斗侧播放音频时,根据当前声音总共的数量和播放者类型决定是否可以播放
---@public
---@param instigator table
---@return boolean
function AkAudioManager:CanBattleSystemPostEvent(instigator)
    if not self:isMajorUnit(instigator) then
        -- 非主角,boos,锁定目标尝试播放,根据当前数量进行限制
        local battleEventNum = self.cppMgr:GetBattleEventNum()
        return battleEventNum < self.BattleLimit
    else
        -- 其他情况都允许播放
        return true
    end
end

-- 战斗侧播放出来的声音,记录结束时间
---@public
---@param eventName string
---@param playingID number
function AkAudioManager:RecordBattleAudioEndTime(eventName, playingID)
    if playingID == AK_INVALID_PLAYING_ID then
        return
    end

    local eventDuration = self:GetEventDuration(eventName)
    if eventDuration <= 0 then
        return
    end

    self.cppMgr:AddBattleEventRecord(playingID, eventDuration)
end

-- 战斗侧主动减少计数
---@public
---@param playingID number
function AkAudioManager:RemoveBattleAudioEndTime(playingID)
    self.cppMgr:DelBattleEventRecord(playingID)
end

-- 出生时必然会调用set_InBattle,所以不监听出生事件
---@public
---@param entity ActorBase
---@param bInBattle boolean
function AkAudioManager:OnActorBattleStateChange(entity, bInBattle)
    if (entity == nil) or (entity == Game.me) then
        return
    end

    local entityUID = entity:uid()
    if not self.inBattleActorMap[entityUID] then
        self.inBattleActorMap[entityUID] = 1
        if bInBattle then
            self.inBattleActorNum = self.inBattleActorNum + 1
        end
    else
        if bInBattle then
            self.inBattleActorNum = self.inBattleActorNum + 1
        else
            self.inBattleActorNum = self.inBattleActorNum - 1
        end
    end

    self:processOtherBattleState()
end

---@private
function AkAudioManager:Receive_ROLE_ON_DESTROY(_, entityUID)
    local entity = Game.EntityManager:GetEntityByIntID(entityUID)
    if (entity == nil) or (entity == Game.me) then
        return
    end

    -- 销毁时,如果在战斗状态中,则认为需要-1,否则认为已经减过了
    if (self.inBattleActorMap[entityUID] ~= nil) and (entity.InBattle == true) then
        self.inBattleActorNum = self.inBattleActorNum - 1
    end

    self.inBattleActorMap[entityUID] = nil
    self:processOtherBattleState()
end

---@private
function AkAudioManager:processOtherBattleState()
    if self.inBattleActorNum < 0 then
        Log.WarningFormat("[processOtherBattleState] unexpected inBattleActorNum %s", self.inBattleActorNum)
    end

    if self.inBattleActorNum > 0 then
        self:SetGroupState(Enum.EAudioConstData.OTHER_BATTLE_STATE_GROUP, Enum.EAudioConstData.IN_OTHER_BATTLE_STATE)
    else
        self:ResetGroupState(Enum.EAudioConstData.OTHER_BATTLE_STATE_GROUP)
    end
end


--endregion BattleSystem


--region PostEvent

local __Zero__Vector = FVector() -- luacheck: ignore

-- 播放一个2D音频
---@public
---@param eventName string
---@param bNoNeedAutoStop boolean 默认不传该参数,则该音频会在切换地图时自动Stop,如果传了true,则需要手动Stop
---@return number, string
function AkAudioManager:PostEvent2D(eventName, bNoNeedAutoStop)
    return self:PostEvent3D(eventName, __Zero__Vector, bNoNeedAutoStop)
end

-- 在指定位置播放一个3D音频
---@public
---@param eventName string
---@param location PVector3
---@param bNoNeedAutoStop boolean 默认不传该参数,则该音频会在切换地图时自动Stop,如果传了true,则需要手动Stop
---@return number
function AkAudioManager:PostEvent3D(eventName, location, bNoNeedAutoStop)
    local requiredBank = self:GetEventRequiredBank(eventName)
    if requiredBank == "" then
        Log.WarningFormat("[PostEvent3D] %s has no bank", eventName)
        return AK_INVALID_PLAYING_ID
    end

    -- 尝试从lru中获取bank,如果获取成功,则同时也更新lru,如果bank已加载,则直接播放
    if (self.lru:get(requiredBank) ~= nil) or (self.staticBanks[requiredBank] ~= nil) then
        local playingID = self.cppMgr:InnerPostEvent3D(eventName, location)
        if playingID == AK_INVALID_PLAYING_ID then
            Log.WarningFormat("[PostEvent3D] eventName=%s post failed", eventName)
        end

        if not bNoNeedAutoStop then
            self.autoStopIDList[playingID] = 1
        end

        self.playingIDRef[playingID] = playingID
        return playingID
    end

    -- bank未加载,走异步加载流程
    local taskID = self.cppMgr:InnerAsyncLoadBank(requiredBank)
    local task = Game.ObjectActorManager:AllocateObject(AsyncLoadBankTask)
    task.eventName = eventName
    task.location = location
    task.taskID = taskID
    task.postType = self.Event_Post_Type.ON_LOCATION

    if not bNoNeedAutoStop then
        self.autoStopIDList[taskID] = 1
    end

    Log.DebugFormat("[PostEvent3D] async load bank %s with taskID %s", requiredBank, taskID)
    self.inLoadingTask[taskID] = task
    return taskID * -1
end

-- 在Actor上播放一个跟随Actor位置的音频
---@public
---@param eventName string
---@param actor table UEActor
function AkAudioManager:PostEventOnActor(eventName, actor)
    if not IsValid_L(actor) then
        Log.WarningFormat("[PostEventOnActor] actor invalid to post %s", eventName)
        return AK_INVALID_PLAYING_ID
    end

    -- 获取AkComp,如果没有就创建一个
    local akComp = actor:GetComponentByClass(UAkComponent)
    if not akComp then
        Log.DebugFormat("[PostEventOnActor] %s create new akComp", actor)
        akComp = AGS.GetAkComponent(actor:K2_GetRootComponent(), nil)
    end

    -- 总之是没拿到,认为播放失败
    if not akComp then
        Log.WarningFormat("[PostEventOnActor] %s create akComp failed", actor)
        return AK_INVALID_PLAYING_ID
    end

    return self:realPostEventOnAkComp(eventName, akComp)
end

---@public
---@param eventName string
---@param akCompID number
function AkAudioManager:PostEventOnAkComp(eventName, akCompID)
    local akComp = Game.ObjectActorManager:GetObjectByID(akCompID)
    if not akComp then
        Log.WarningFormat("[PostEventOnAkComp] akComp %s invalid, eventName=%s", akCompID, eventName)
        return AK_INVALID_PLAYING_ID
    end

    return self:realPostEventOnAkComp(eventName, akComp)
end

---@private
---@param eventName string
---@param akComp
function AkAudioManager:realPostEventOnAkComp(eventName, akComp)
    local requiredBank = self:GetEventRequiredBank(eventName)
    if requiredBank == "" then
        Log.WarningFormat("[realPostEventOnAkComp] %s has no bank", eventName)
        return AK_INVALID_PLAYING_ID
    end

    -- 尝试从lru中获取bank,如果获取成功,则同时也更新了,如果bank已加载,则直接播放
    if (self.lru:get(requiredBank) ~= nil) or (self.staticBanks[requiredBank] ~= nil) then
        local playingID = self.cppMgr:InnerPostEventOnAkComp(eventName, akComp)
        if playingID == AK_INVALID_PLAYING_ID then
            Log.WarningFormat("[PostEventOnActor] eventName=%s post failed", eventName)
        end

        self.playingIDRef[playingID] = playingID
        return playingID
    end

    -- bank未加载,走异步加载流程
    local taskID = self.cppMgr:InnerAsyncLoadBank(requiredBank)
    local task = Game.ObjectActorManager:AllocateObject(AsyncLoadBankTask)
    task.eventName = eventName
    task.akCompID = Game.ObjectActorManager:GetIDByObject(akComp)
    task.taskID = taskID
    task.postType = self.Event_Post_Type.ON_ACTOR

    Log.DebugFormat("[realPostEventOnAkComp] async load bank %s with taskID %s", requiredBank, taskID)
    self.inLoadingTask[taskID] = task
    return taskID * -1
end

-- 通过ID停止播放
---@public
---@param playingID number
---@param blendTime number
---@param blendType number
function AkAudioManager:StopEvent(playingID, blendTime, blendType)
    local realPlayingID = self.playingIDRef[playingID] or AK_INVALID_PLAYING_ID
    if realPlayingID == AK_INVALID_PLAYING_ID then
        Log.WarningFormat("[StopEvent] try to stop non-exist playingID %s", playingID)
    end

    -- @shijingzhe:如果同一帧内Play+Stop,需要保证异步的Play无法播出来
    self.playingIDRef[playingID] = -1

    if realPlayingID ~= AK_INVALID_PLAYING_ID then
        blendTime = blendTime or 0
        blendType = blendType or BlendTypeLinear
        self.cppMgr:InnerStopEventByPlayingID(realPlayingID, blendTime, blendType)
    end
end

---@public
---@param playingID number
---@param blendTime number
---@param blendType number
function AkAudioManager:PauseEvent(playingID, blendTime, blendType)
    local realPlayingID = self.playingIDRef[playingID]
    if not realPlayingID then
        Log.WarningFormat("[PauseEvent] try to stop non-exist playingID %s", playingID)
        return
    end

    blendTime = blendTime or 0
    blendType = blendType or BlendTypeLinear
    self.cppMgr:InnerPauseEventByPlayingID(playingID, blendTime, blendType)
end

---@public
---@param playingID number
---@param blendTime number
---@param blendType number
function AkAudioManager:ResumeEvent(playingID, blendTime, blendType)
    local realPlayingID = self.playingIDRef[playingID]
    if not realPlayingID then
        Log.WarningFormat("[ResumeEvent] try to stop non-exist playingID %s", playingID)
        return
    end

    blendTime = blendTime or 0
    blendType = blendType or BlendTypeLinear
    self.cppMgr:InnerResumeEventByPlayingID(playingID, blendTime, blendType)
end


--endregion PostEvent


--region AUDIO_PARAM


local NoneState = "None" -- luacheck: ignore

---@public
---@param groupName string
---@param state string
function AkAudioManager:SetGroupState(groupName, state)
    --local oldState = self.groupStates[groupName] or NoneState
    --Log.DebugFormat("[SetGroupState] groupName=%s, oldState=%s, newState=%s", groupName, oldState, state)

    -- 值相同,不重复调用
    if self.groupStates[groupName] == state then
        return
    end

    self.groupStates[groupName] = state
    self.cppMgr:InnerSetGroupState(groupName, state)
end

---@public
---@param groupName string
function AkAudioManager:ResetGroupState(groupName)
    --local oldState = self.groupStates[groupName] or NoneState
    --Log.DebugFormat("[ResetGroupState] groupName=%s, oldState=%s", groupName, oldState)

    -- 不重复调用
    if self.groupStates[groupName] == NoneState then
        return
    end

    self.groupStates[groupName] = NoneState
    self.cppMgr:InnerResetGroupState(groupName, NoneState)
end

---@public
---@param rtpcName string
---@param rtpcValue number
function AkAudioManager:SetRtpcValue(rtpcName, rtpcValue)
    --local oldValue = self.rtpcs[rtpcName]
    --Log.DebugFormat("[SetRtpcValue] rtpcName=%s, oldValue=%s, newValue=%s", rtpcName, oldValue, rtpcValue)

    -- 值相同,不重复调用
    if self.rtpcs[rtpcName] == rtpcValue then
        return
    end

    self.rtpcs[rtpcName] = rtpcValue
    self.cppMgr:InnerSetRtpcValue(rtpcName, rtpcValue)
end

---@public
---@param rtpcName string
function AkAudioManager:ResetRtpcValue(rtpcName)
    --Log.DebugFormat("[ResetRtpcValue] rtpcName=%s", rtpcName)

    self.rtpcs[rtpcName] = nil
    self.cppMgr:InnerResetRtpcValue(rtpcName)
end

---@public
---@param akCompID number
---@param rtpcName string
---@param rtpcValue number
function AkAudioManager:SetRtpcValueOnAkComp(akCompID, rtpcName, rtpcValue)
    local akComp = Game.ObjectActorManager:GetObjectByID(akCompID)
    if not akComp then
        Log.WarningFormat("[SetRtpcValueOnAkComp] akComp %s invalid, rtpcName=%s, rtpcValue=%s", akCompID, rtpcName, rtpcValue)
        return
    end

    --Log.DebugFormat("[SetRtpcValueOnAkComp] actor=%s, rtpcName=%s, rtpcValue=%s", actor:GetName(), rtpcName, rtpcValue)
    self.cppMgr:InnerSetRtpcValueOnAkComp(akComp, rtpcName, rtpcValue)
end

---@public
---@param akCompID number
---@param rtpcName string
function AkAudioManager:ResetRtpcValueOnAkComp(akCompID, rtpcName)
    local akComp = Game.ObjectActorManager:GetObjectByID(akCompID)
    if not akComp then
        Log.WarningFormat("[ResetRtpcValueOnAkComp] akComp %s invalid, rtpcName=%s", akCompID, rtpcName)
        return
    end

    --Log.DebugFormat("[SetRtpcValueOnAkComp] actor=%s, rtpcName=%s, rtpcValue=%s", actor:GetName(), rtpcName, rtpcValue)
    self.cppMgr:InnerResetRtpcValueOnAkComp(akComp, rtpcName)
end

-- 在一个AkComponent上设置Switch
---@public
---@param akCompID number
---@param switchGroup string
---@param switchState string
function AkAudioManager:SetSwitchOnAkComp(akCompID, switchGroup, switchState)
    local akComp = Game.ObjectActorManager:GetObjectByID(akCompID)
    if not akComp then
        Log.WarningFormat("[SetSwitchOnAkComp] akComp %s invalid, switchGroup=%s, switchState=%s", akCompID, switchGroup, switchState)
        return
    end

    --Log.DebugFormat("[SetSwitchOnAkComp] %s switch group:%s to state:%s", akCompID, switchGroup, switchState)
    akComp:SetSwitch(nil, switchGroup, switchState)
end

-- 排序方法
---@private
function AkAudioManager.priorityCompare(a, b)
    return a[3] > b[3]
end

---@private
---@param uniqueID string
---@param groupStates FKGGroupState[]
---@param priority number
function AkAudioManager:OnSetGroupStateWithPriority(uniqueID, groupStates, priority)
    -- -1直接设置
    if priority < 0 then
        for _, groupState in pairs(groupStates) do
            self:SetGroupState(groupState.Group, groupState.State)
        end
        return
    end

    local _, topGroupStates, topPriority = self:getTopVolumeInfo()

    -- 如果优先级更高,则reset当前top, 并设置新的
    if priority >= topPriority then
        for _, topGroupState in pairs(topGroupStates) do
            self:ResetGroupState(topGroupState.Group)
        end

        for _, groupState in pairs(groupStates) do
            self:SetGroupState(groupState.Group, groupState.State)
        end

        -- 记录当前生效的
        self.curVolumeUniqueID = uniqueID
        self.curVolumeGroupStates = groupStates
    end

    -- 无论如何都入队并排序
    table.insert(self.priorityVolumeQueue, { uniqueID, groupStates, priority })
    table.sort(self.priorityVolumeQueue, self.priorityCompare)
end

---@private
---@param uniqueID string
---@param groupStates FKGGroupState[]
---@param priority number
function AkAudioManager:OnResetGroupStateWithPriority(uniqueID, groupStates, priority)
    -- -1直接设置
    if priority < 0 then
        for _, groupState in pairs(groupStates) do
            self:ResetGroupState(groupState.Group)
        end
        return
    end

    -- 无论如何都出队
    self:removeVolumeInfo(uniqueID)

    -- 如果被reset的是cur, 则将cur重置后, 再把Top设置新的
    if uniqueID == self.curVolumeUniqueID then
        for _, curGroupState in pairs(self.curVolumeGroupStates) do
            self:ResetGroupState(curGroupState.Group)
        end

        self.curVolumeUniqueID = ""
        self.curVolumeGroupStates = nil

        local newTopUniqueID, newTopGroupStates = self:getTopVolumeInfo()
        if newTopUniqueID ~= "" then
            for _, newTopGroupState in pairs(newTopGroupStates) do
                self:SetGroupState(newTopGroupState.Group, newTopGroupState.State)
            end

            -- 记录当前生效的
            self.curVolumeUniqueID = newTopUniqueID
            self.curVolumeGroupStates = newTopGroupStates
        end
    end
end

-- uniqueID, groupStates, priority
AkAudioManager.EMPTY_QUEUE_ITEM = { 0, {}, -1 }

---@private
---@return string, FKGGroupState, number
function AkAudioManager:getTopVolumeInfo()
    local topItem = self.priorityVolumeQueue[1] or self.EMPTY_QUEUE_ITEM
    return topItem[1], topItem[2], topItem[3]
end

---@private
---@param uniqueID string
function AkAudioManager:removeVolumeInfo(uniqueID)
    for idx = #self.priorityVolumeQueue, 1, -1 do
        if self.priorityVolumeQueue[idx][1] == uniqueID then
            table.remove(self.priorityVolumeQueue, idx)
            return
        end
    end
end

---@public
---@param akCompID number
---@param newScalingFactor number
function AkAudioManager:SetAttenuationScalingFactor(akCompID, newScalingFactor)
    local akComp = Game.ObjectActorManager:GetObjectByID(akCompID)
    if not akComp then
        Log.WarningFormat("[SetAttenuationScalingFactor] akComp %s invalid", akCompID)
        return
    end

    self.cppMgr:InnerSetAttenuationScalingFactor(akComp, newScalingFactor)
end


--endregion AUDIO_PARAM


--region Bank


local __Bank_Name_List = {} -- luacheck: ignore

-- 同步加载所有需要自动加载的bank,允许在初始化时同步加载,其他case都必须异步加载
-- 此函数生命周期内只调用一次
---@private
function AkAudioManager:loadAutoLoadBanks()
    table.clear(__Bank_Name_List)
    local autoLoadBankData = Game.TableData.GetAutoLoadBankDataTable()
    for bankName, _ in ksbcpairs(autoLoadBankData) do
        table.insert(__Bank_Name_List, bankName)
    end

    self:SyncLoadBankList(__Bank_Name_List, self)
end

-- 同步加载一个Bank
---@public
---@param bankName string
---@param owner table
function AkAudioManager:SyncLoadBank(bankName, owner)
    table.clear(__Bank_Name_List)
    table.insert(__Bank_Name_List, bankName)
    self:SyncLoadBankList(__Bank_Name_List, owner)
end

local __Bank_Name_Array = slua.Array(EPropertyClass.Str) -- luacheck: ignore

-- 同步加载多个Bank
---@public
---@param bankNameList string[]
---@param owner table
function AkAudioManager:SyncLoadBankList(bankNameList, owner)
    local ownerName = self:getOwnerName(owner)
    if ownerName == "" then
        Log.Error("[SyncLoadBankList] invalid owner")
        return
    end

    if #bankNameList == 0 then
        Log.DebugFormat("[SyncLoadBankList] empty bankNameList, ownerName=%s", ownerName)
        return
    end

    __Bank_Name_Array:Clear()
    for _, bankName in ksbcipairs(bankNameList) do
        if self.lru:get(bankName) then
            -- 在lru内的bank理论上不能被动态加载,如果出现这种情况,则表示音频划分有问题
            -- 但如果已经在lru中,则需要把记录从lru中移动到static中,防止被动态卸载
            Log.WarningFormat("[SyncLoadBankList] %s mismatch static and dynamic bank %s, move to static", ownerName, bankName)
            self.lru:remove(bankName)
            self:onLruPopBank(bankName, true)
            self.staticBanks[bankName] = 1
            goto continue
        end

        if self.staticBanks[bankName] then
            goto continue
        end

        __Bank_Name_Array:Add(bankName)
        self.staticBanks[bankName] = 1
        :: continue ::
    end

    if __Bank_Name_Array:Num() == 0 then
        return
    end

    self.cppMgr:InnerSyncLoadBankList(__Bank_Name_Array)
end

-- 同步卸载一个Bank
---@public
---@param bankName string
---@param owner table
function AkAudioManager:SyncUnloadBank(bankName, owner)
    table.clear(__Bank_Name_List)
    table.insert(__Bank_Name_List, bankName)
    self:SyncUnloadBankList(__Bank_Name_List, owner)
end

-- 同步卸载多个Bank
---@public
---@param bankNameList string[]
---@param owner table
---@param bForce boolean 不关心是否在static中,强制卸载
function AkAudioManager:SyncUnloadBankList(bankNameList, owner, bForce)
    local ownerName = self:getOwnerName(owner)
    if ownerName == "" then
        Log.Error("[SyncUnloadBankList] invalid owner")
        return
    end

    if #bankNameList == 0 then
        Log.DebugFormat("[SyncUnloadBankList] empty bankNameList, ownerName=%s", ownerName)
        return
    end

    local autoLoadBankData = Game.TableData.GetAutoLoadBankDataTable()

    __Bank_Name_Array:Clear()
    for _, bankName in ipairs(bankNameList) do
        if (autoLoadBankData[bankName] ~= nil) and (bForce ~= true) then
            goto continue
        end

        __Bank_Name_Array:Add(bankName)
        self.staticBanks[bankName] = nil
        :: continue ::
    end

    if __Bank_Name_Array:Num() == 0 then
        return
    end

    self.cppMgr:InnerSyncUnloadBankList(__Bank_Name_Array)
end

-- 获取Bank内存占用(实际上是磁盘文件占用,所以这里拿到的是个大概值)
---@private
---@param bankName
---@return number
function AkAudioManager:getBankSize(bankName)
    local ABD = Game.TableData.GetAkAudioBankDataRow(bankName)
    if not ABD then
        Log.WarningFormat("[getBankSize] %s not exist", bankName)
        return 0
    end

    return ABD.Size
end

-- bank异步加载完成时的回调
---@private
---@param loadID number
---@param bankName string
function AkAudioManager:OnBankLoaded(loadID, bankName)
    local task = self.inLoadingTask[loadID]
    if not task then
        Log.ErrorFormat("[OnBankLoaded] task %s not found", loadID)
        return
    end

    Log.DebugFormat("[OnBankLoaded] %s loaded in %s", bankName, loadID)
    self.inLoadingTask[loadID] = nil
    loadID = loadID * -1

    if self.playingIDRef[loadID] == nil then
        local playingID = AK_INVALID_PLAYING_ID
        if task.postType == self.Event_Post_Type.ON_LOCATION then
            playingID = self.cppMgr:InnerPostEvent3D(task.eventName, task.location)
        elseif task.postType == self.Event_Post_Type.ON_ACTOR then
            local akComp = Game.ObjectActorManager:GetObjectByID(task.akCompID)
            if not akComp then
                Log.WarningFormat("[OnBankLoaded] akComp invalid during %s async", loadID)
            else
                playingID = self.cppMgr:InnerPostEventOnAkComp(task.eventName, akComp)
            end
        end

        if playingID == AK_INVALID_PLAYING_ID then
            Log.WarningFormat("[OnBankLoaded] task %s post event %s failed", loadID, task.eventName)
        end

        -- playingID记录
        self.playingIDRef[loadID] = playingID
    else
        -- playingID清空
        self.playingIDRef[loadID] = nil
    end

    -- 不管播放成功与否,更新lru,如果Bank超限,则popTail,每次pop一个
    if not self.lru:get(bankName) then
        self.lruMemorySize = self.lruMemorySize + self:getBankSize(bankName)
    end

    self.lru:set(bankName, bankName)
    if self.lruMemorySize > self.Lru_Memory_Limit then
        self.lru:_popTail()
    end

    Log.DebugFormat("[OnBankLoaded] current lru bank memory is %s", self.lruMemorySize)

    -- task回收
    Game.ObjectActorManager:ReleaseObject(task)
end

---@private
---@param bankName string
---@param bKeep boolean 控制是否卸载
function AkAudioManager:onLruPopBank(bankName, bKeep)
    Log.DebugFormat("[onLruPopBank] unload %s, bKeep=%s", bankName, bKeep)
    local bankSize = self:getBankSize(bankName)
    self.lruMemorySize = self.lruMemorySize - bankSize

    if not bKeep then
        self.cppMgr:InnerAsyncUnloadBank(bankName)
    end
end


--endregion Bank


--region Notify


-- 动作Notify
---@private
---@param skComp table
---@param akEvent table
---@param bMainPlayerOnly boolean
function AkAudioManager:OnAnimNotify_ActionAkEvent(skComp, akEvent, bMainPlayerOnly)
    local owner = IsValid_L(skComp) and skComp:GetOwner() or nil
    if not IsValid_L(owner) then
        return
    end

    -- 隐藏中的单位不播Notify
    if KGActorUtil.IsActorHidden(owner) then
        return
    end

    local eventName = IsValid_L(akEvent) and akEvent:GetName() or nil
    if not eventName then
        return
    end

    ---@type ViewControlAudioComponent
    local entity = Game.EntityManager:getEntity(owner.GetEntityUID and owner:GetEntityUID() or 0)
    if (entity ~= Game.me) and (bMainPlayerOnly == true) then
        -- 仅1P播放的音频,3P玩家不播
        return
    end

    local notifyEventNum = self.cppMgr:GetNotifyEventNum()
    if (notifyEventNum > self.NotifyEventLimit) and (self:isMajorUnit(entity) == false) then
        return
    end

    if (entity ~= nil) and (Game.WorldManager.ViewBudgetMgr:TryConsumeViewFrequency_LOCO_SOUND(entity) == false) then
        return
    end

    -- 时装逻辑,如果是仅1P的情况,不进行拼接
    local materialSuffix = ""
    if (bMainPlayerOnly == false) and (entity ~= nil) and (entity.GetUpperWearSoundMaterialName ~= nil) then
        local upperWearMaterialName = entity:GetUpperWearSoundMaterialName()
        if not string.isEmpty(upperWearMaterialName) then
            materialSuffix = UNDER_LINE .. upperWearMaterialName
        end
    end

    if not self.actionEventCache[eventName] then
        self.actionEventCache[eventName] = {}
    end

    if not self.actionEventCache[eventName][materialSuffix] then
        self.actionEventCache[eventName][materialSuffix] = {}
    end

    local bMainPlayer = entity == Game.me
    local slotSuffix =  (bMainPlayer == true and bMainPlayerOnly == false) and MAIN_PLAYER_SUFFIX or ""
    local realEventName = self.actionEventCache[eventName][materialSuffix][bMainPlayer]
    if not realEventName then
        realEventName = eventName .. materialSuffix .. slotSuffix
        self.actionEventCache[eventName][materialSuffix][bMainPlayer] = realEventName
    end

    local playingID = AK_INVALID_PLAYING_ID

    if entity then
        -- 通过owner找到entity
        playingID = entity:AkPostEventOnActor(realEventName)
    else
        -- 找不到的认为是普通actor,直接播
        playingID = self:PostEventOnActor(realEventName, owner)
    end

    if playingID ~= AK_INVALID_PLAYING_ID then
        local eventDuration = self:GetEventDuration(realEventName)
        if eventDuration > 0 then
            self.cppMgr:AddNotifyEventRecord(playingID, eventDuration)
        end
    end
end

---@private
---@return string
function AkAudioManager:getTerrainName(entity)
    if not entity then
        return TERRAIN_NAME_DEFAULT
    end

    -- 在水中就直接返回
    if type(entity.GetIsInWater) == "function" then
        --Log.DebugFormat("[getTerrainName] is in water %s", entity:GetIsInWater())
        if entity:GetIsInWater() then
            return TERRAIN_NAME_WATER
        end
    end

    local terrainName = TERRAIN_NAME_DEFAULT

    local character = Game.ObjectActorManager:GetObjectByID(entity.CharacterID)
    if character then
        local pName = self.cppMgr:GetCurrentFloorPhysicalMaterialName(character, Game.me == entity)
        if (pName ~= DEFAULT_PHYSICAL_MATERIAL_NAME) and (pName ~= NAME_NONE) and (pName ~= "") then
            local physicalMaterialData = Game.TableData.GetTerrainPhysicalMaterialDataRow(pName)
            if physicalMaterialData then
                terrainName = physicalMaterialData.Name
            end
        end

        if self.bEnableTerrainDebug then
            KSL.PrintString(Game.WorldContext, "PhysicalMaterialName: " .. pName, true, true, FLinearColor(1, 0, 0), 5)
        end
    end

    return terrainName
end

-- 脚步Notify,需要计算鞋子+地面的材质
---@private
---@param skComp table
---@param akEvent table
---@param bNeedSplice boolean
function AkAudioManager:OnAnimNotify_FootStepAkEvent(skComp, akEvent, bNeedSplice)
    local owner = IsValid_L(skComp) and skComp:GetOwner() or nil
    if not IsValid_L(owner) then
        return
    end

    -- 隐藏中的单位不播Notify
    if KGActorUtil.IsActorHidden(owner) then
        return
    end

    local eventName = IsValid_L(akEvent) and akEvent:GetName() or nil
    if not eventName then
        return
    end

    ---@type ViewControlAudioComponent
    local entity = Game.EntityManager:getEntity(owner.GetEntityUID and owner:GetEntityUID() or 0)

    local bInRidding = false
    if (entity ~= nil) and (entity.GetDriverEntity ~= nil) then
        entity = entity:GetDriverEntity()
        bInRidding = true
    end

    local notifyEventNum = self.cppMgr:GetNotifyEventNum()
    if (notifyEventNum > self.NotifyEventLimit) and (self:isMajorUnit(entity) == false) then
        return
    end

    if (entity ~= nil) and (Game.WorldManager.ViewBudgetMgr:TryConsumeViewFrequency_LOCO_SOUND(entity) == false) then
        return
    end

    local playingID = AK_INVALID_PLAYING_ID
    if not bNeedSplice then
        --Log.DebugFormat("[OnAnimNotify_FootStepAkEvent] %s post %s", owner, eventName)
        playingID = self:PostEventOnActor(eventName, owner)
    else
        -- 获取鞋子材质,骑乘状态下没有鞋子
        local footStep
        if (entity ~= nil) and (entity.GetShoesSoundMaterialName ~= nil) and (bInRidding == false) then
            footStep = entity:GetShoesSoundMaterialName()
        end

        if string.isEmpty(footStep) then
            footStep = FOOT_STEP_DEFAULT
        end

        -- 获取地面材质
        local terrainName = self:getTerrainName(entity)

        -- 尝试从已有缓存中取出实际需要播放的eventName
        if not self.footStepEventCache[eventName] then
            self.footStepEventCache[eventName] = {}
        end

        if not self.footStepEventCache[eventName][footStep] then
            self.footStepEventCache[eventName][footStep] = {}
        end

        if not self.footStepEventCache[eventName][footStep][terrainName] then
            self.footStepEventCache[eventName][footStep][terrainName] = {}
        end

        local bIsMainPlayer = entity == Game.me
        local realEventName = self.footStepEventCache[eventName][footStep][terrainName][bIsMainPlayer]

        if not realEventName then
            realEventName = self:concatRealEventName(eventName, footStep, terrainName, bIsMainPlayer)
            self.footStepEventCache[eventName][footStep][terrainName][bIsMainPlayer] = realEventName
        end

        if self.bEnableTerrainDebug then
            KSL.PrintString(Game.WorldContext, "AkAudioEventName: " .. realEventName, true, true, FLinearColor(0, 0, 1), 5)
        end

        --Log.DebugFormat("[OnAnimNotify_FootStepAkEvent] %s post %s", owner, realEventName)
        playingID = self:PostEventOnActor(realEventName, owner)
    end

    if playingID ~= AK_INVALID_PLAYING_ID then
        local eventDuration = self:GetEventDuration(eventName)
        if eventDuration > 0 then
            self.cppMgr:AddNotifyEventRecord(playingID, eventDuration)
        end
    end
end

-- 拼接最终脚步路径
---@private
---@param eventName string
---@param footStep string
---@param terrainName string
---@param bIsMainPlayer boolean
function AkAudioManager:concatRealEventName(eventName, footStep, terrainName, bIsMainPlayer)
    if footStep ~= FOOT_STEP_DEFAULT then
        eventName = eventName .. UNDER_LINE .. footStep
    end

    if terrainName ~= TERRAIN_NAME_DEFAULT then
        eventName = eventName .. UNDER_LINE .. terrainName
    end

    if bIsMainPlayer then
        eventName = eventName .. MAIN_PLAYER_SUFFIX
    end

    return eventName
end

local __Player_Suffix = "_Player" -- luacheck: ignore
local __Monster_Suffix = "_Monster" -- luacheck: ignore

-- 语音Notify,区分玩家/怪物/NP
---@private
---@param skComp table
---@param akEvent table
function AkAudioManager:OnAnimNotify_VoiceAkEvent(skComp, akEvent)
    local owner = IsValid_L(skComp) and skComp:GetOwner() or nil
    if not IsValid_L(owner) then
        return
    end

    -- 隐藏中的单位不播Notify
    if KGActorUtil.IsActorHidden(owner) then
        return
    end

    local eventName = IsValid_L(akEvent) and akEvent:GetName() or nil
    if not eventName then
        return
    end

    local entity = Game.EntityManager:getEntity(owner.GetEntityUID and owner:GetEntityUID() or 0)

    local notifyEventNum = self.cppMgr:GetNotifyEventNum()
    if (notifyEventNum > self.NotifyEventLimit) and (self:isMajorUnit(entity) == false) then
        return
    end

    if (entity ~= nil) and (Game.WorldManager.ViewBudgetMgr:TryConsumeViewFrequency_LOCO_SOUND(entity) == false) then
        return
    end

    if not self.voiceEventCache[eventName] then
        self.voiceEventCache[eventName] = {}
    end

    -- 类型后缀获取
    local voiceType
    if entity.GetEntityConfigData then
        local configData = entity:GetEntityConfigData()
        if configData then
            local facadeControlData = Game.TableData.GetFacadeControlDataRow(configData.FacadeControlID)
            if facadeControlData then
                voiceType = facadeControlData.VoiceType
            end
        end
    end

    -- 如果为空,说明没配置,走默认值
    local typeSuffix
    if string.isEmpty(voiceType) then
        typeSuffix = (owner.ActorType == EWActorType.PLAYER) and __Player_Suffix or __Monster_Suffix
    else
        typeSuffix = UNDER_LINE .. voiceType
    end

    if not self.voiceEventCache[eventName][typeSuffix] then
        self.voiceEventCache[eventName][typeSuffix] = {}
    end

    local bMainPlayer = entity == Game.me
    local slotSuffix = bMainPlayer and MAIN_PLAYER_SUFFIX or ""
    local realEventName = self.voiceEventCache[eventName][typeSuffix][bMainPlayer]
    if not realEventName then
        realEventName = eventName .. typeSuffix .. slotSuffix
        self.voiceEventCache[eventName][typeSuffix][bMainPlayer] = realEventName
    end

    local playingID = self:PostEventOnActor(realEventName, owner)
    if playingID ~= AK_INVALID_PLAYING_ID then
        local eventDuration = self:GetEventDuration(eventName)
        if eventDuration > 0 then
            self.cppMgr:AddNotifyEventRecord(playingID, eventDuration)
        end
    end
end

---@private
---@param skComp
---@param akEvent
function AkAudioManager:OnAnimNotifyStateBegin_AkEvent(skComp, akEvent)
    local owner = IsValid_L(skComp) and skComp:GetOwner() or nil
    if not IsValid_L(owner) then
        return
    end

    local eventName = IsValid_L(akEvent) and akEvent:GetName() or nil
    if not eventName then
        return
    end

    Log.DebugFormat("[OnAnimNotifyStateBegin_AkEvent] %s %s", skComp, eventName)
    self:PostEventOnActor(eventName, owner)
end

---@private
---@param skComp
---@param akEvent
function AkAudioManager:OnAnimNotifyStateEnd_AkEvent(skComp, akEvent)
    local owner = IsValid_L(skComp) and skComp:GetOwner() or nil
    if not IsValid_L(owner) then
        return
    end

    local eventName = IsValid_L(akEvent) and akEvent:GetName() or nil
    if not eventName then
        return
    end

    Log.DebugFormat("[OnAnimNotifyStateEnd_AkEvent] %s %s", skComp, eventName)
    self:PostEventOnActor(eventName, owner)
end

--endregion Notify


--region Track

---@param akEvent
---@param bEnableSync boolean
function AkAudioManager:OnPostTrackEvent(akEvent, bEnableSync)
    local eventName = IsValid_L(akEvent) and akEvent:GetName() or nil
    if not eventName then
        return
    end

    self:PostEvent2D(eventName)
end


--endregion Track


--region Map


---@private
function AkAudioManager:initMapAudioTagParam()
    self.curMapAudioTag = ""

    ---@type number[]
    self.mapAudioPlayingIDs = {}

    ---@type table<string, string>
    self.mapAudioGroupStates = {}

    ---@type table<string, number>
    self.mapAudioRtpcs = {}
end

---@private
function AkAudioManager:uninitMapAudioTagParam()
    self.curMapAudioTag = ""
    self.mapAudioPlayingIDs = {}
    self.mapAudioGroupStates = {}
    self.mapAudioRtpcs = {}
end

---@private
---@param tag string
function AkAudioManager:getMapRequiredBanks(tag)
    local bankList = {}
    local mapAudioData = Game.TableData.GetLevelMapAudioDataRow(tag)
    if not mapAudioData then
        return bankList
    end

    local bankMap = {}
    for _, event in ksbcipairs(mapAudioData.EnterAkEvents) do
        local requiredBank = self:GetEventRequiredBank(event)
        if requiredBank ~= "" then
            bankMap[requiredBank] = 1
        end
    end
    for _, event in ksbcipairs(mapAudioData.LeaveAkEvents) do
        local requiredBank = self:GetEventRequiredBank(event)
        if requiredBank ~= "" then
            bankMap[requiredBank] = 1
        end
    end

    for bank, _ in pairs(bankMap) do
        table.insert(bankList, bank)
    end

    return bankList
end

---@private
-- @param nextLevelMapData LevelMapData
function AkAudioManager:mapAudioTag_onLevelLoadStart(nextLevelMapData)
    if Game.GameLoopManagerV2:GetCurGameLoopStage() == Game.GameLoopManagerV2.EGameStageType.Login then
        return
    end

    local nextMapAudioTag = self:getNextMapAudioTag(nextLevelMapData)
    if nextMapAudioTag == self.curMapAudioTag then
        -- 同tag不做任何处理
        return
    end

    local nextRequiredBanks = self:getMapRequiredBanks(nextMapAudioTag)
    if #nextRequiredBanks > 0 then
        self:SyncLoadBankList(nextRequiredBanks, self)
    end

    self:leaveMapAudioTag(self.curMapAudioTag)
end

---@private
function AkAudioManager:mapAudioTag_onLevelLoadEnd(nextLevelMapData)
    local nextMapAudioTag = self:getNextMapAudioTag(nextLevelMapData)
    if nextMapAudioTag == self.curMapAudioTag then
        -- 同tag不做任何处理
        return
    end

    -- 下个Map的Bank
    local banksToCulling = {}
    local nextRequiredBanks = self:getMapRequiredBanks(nextMapAudioTag)
    for _, bankName in ipairs(nextRequiredBanks) do
        banksToCulling[bankName] = 1
    end

    -- 当前Map的Bank
    local banksToUnload = {}
    local curRequiredBanks = self:getMapRequiredBanks(self.curMapAudioTag)
    for _, bankName in ipairs(curRequiredBanks) do
        if banksToCulling[bankName] == nil then
            table.insert(banksToUnload, bankName)
        end
    end

    if #banksToUnload > 0 then
        self:SyncUnloadBankList(banksToUnload, self)
    end

    self:enterMapAudioTag(nextMapAudioTag)
end

-- 离开一个AudioTag,只播放Stop事件
---@private
---@param tag string
function AkAudioManager:leaveMapAudioTag(tag)
    local mapAudioData = Game.TableData.GetLevelMapAudioDataRow(tag)
    if not mapAudioData then
        return
    end

    for _, eventName in ksbcipairs(mapAudioData.LeaveAkEvents) do
        self:PostEvent2D(eventName, true)
    end
end

-- 进入一个AudioTag
---@private
---@param tag string
function AkAudioManager:enterMapAudioTag(tag)
    self:ResetCurMapAudioTag()
    self.curMapAudioTag = tag

    local mapAudioData = Game.TableData.GetLevelMapAudioDataRow(tag)
    if not mapAudioData then
        return
    end

    for _, eventName in ksbcipairs(mapAudioData.EnterAkEvents) do
        local playingID = self:PostEvent2D(eventName, true)
        table.insert(self.mapAudioPlayingIDs, playingID)
    end

    for groupName, state in ksbcpairs(mapAudioData.StateGroups) do
        self:SetGroupState(groupName, state)
        self.mapAudioGroupStates[groupName] = state
    end

    for rtpcName, rtpcValue in ksbcpairs(mapAudioData.RtpcValue) do
        self:SetRtpcValue(rtpcName, rtpcValue)
        self.mapAudioRtpcs[rtpcName] = rtpcValue
    end
end

-- 重置当前tag下的所有数据
---@public
function AkAudioManager:ResetCurMapAudioTag()
    -- 停止playing event
    __Playing_ID_Array:Clear()
    for _, playingID in pairs(self.mapAudioPlayingIDs) do
        __Playing_ID_Array:Add(playingID)
    end
    self.cppMgr:StopAllByPlayingIDs(__Playing_ID_Array)
    self.mapAudioPlayingIDs = {}

    -- 重置GroupState
    for groupName, _ in pairs(self.mapAudioGroupStates) do
        self:ResetGroupState(groupName)
    end
    self.mapAudioGroupStates = {}

    -- 重置Rtpc
    for rtpcName, _ in pairs(self.mapAudioRtpcs) do
        self:ResetRtpcValue(rtpcName)
    end
    self.mapAudioRtpcs = {}

    self.curMapAudioTag = ""
end

-- 脱离MapTag控制
---@public
function AkAudioManager:OutMapAudioTagControl()
    local curMapAudioTag = self.curMapAudioTag
    self:ResetCurMapAudioTag()

    local curRequiredBanks = self:getMapRequiredBanks(curMapAudioTag)
    if #curRequiredBanks > 0 then
        self:SyncUnloadBankList(curRequiredBanks, self)
    end
end

-- 获取新的MapAudioTag,基于当前map和位面ID
---@private
-- @param nextLevelMapData LevelMapData
function AkAudioManager:getNextMapAudioTag(nextLevelMapData)
    local nextMapAudioTag = ""

    ---@type Space
    local space = Game.NetworkManager.GetLocalSpace()
    if not space then
        return ""
    end

    if space.planeID > 0 then
        local planeData = Game.TableData.GetPlaneDataRow(space.planeID)
        if planeData then
            if planeData.MapAudioTag ~= "" then
                nextMapAudioTag = planeData.MapAudioTag
            else
                -- 位面配置,不填默认用位面对应的World所使用的MapID
                local levelId = planeData.WorldID
                if levelId then
                    local srcLevelMapData = Game.TableData.GetLevelMapDataRow(levelId)
                    if srcLevelMapData then
                        nextMapAudioTag = srcLevelMapData.MapAudioTag
                    end
                end
            end
        end
    else
        nextMapAudioTag = nextLevelMapData.MapAudioTag
    end

    return nextMapAudioTag
end

---@public
---@param newType number
function AkAudioManager:OnSceneFieldTypeChanged(newType)
    Log.DebugFormat("[OnSceneFieldTypeChanged] newType=%s", newType)

    -- 停止上个type的
    local lastSceneFiledAudioData = Game.TableData.GetSceneFieldAudioDataRow(self.sceneFieldType)
    if lastSceneFiledAudioData then
        for _, eventName in ksbcipairs(lastSceneFiledAudioData.LeaveAkEvents) do
            self:PostEvent2D(eventName)
        end
    end

    -- 执行新type的
    self.sceneFieldType = newType
    local newSceneFiledAudioData = Game.TableData.GetSceneFieldAudioDataRow(self.sceneFieldType)
    if newSceneFiledAudioData then
        for _, eventName in ksbcipairs(newSceneFiledAudioData.EnterAkEvents) do
            self:PostEvent2D(eventName, true)
        end

        for groupName, state in ksbcpairs(newSceneFiledAudioData.StateGroups) do
            self:SetGroupState(groupName, state)
        end

        for rtpcName, rtpcValue in ksbcpairs(newSceneFiledAudioData.RtpcValue) do
            self:SetRtpcValue(rtpcName, rtpcValue)
        end
    end
end

--endregion Map


--region UI


-- 触发一个UI音频事件(根据UI事件自动触发的,不要手动调用)
---@public
---@param wbp table
---@param uiEventType number
---@return number
function AkAudioManager:OnUIPostEvent(wbp, uiEventType)
    local playingID = AK_INVALID_PLAYING_ID

    local uiAudioEventType = self.UIEventMap[uiEventType]
    if uiAudioEventType == nil then
        return playingID
    end

    if (IsValid_L(wbp) == false) or (wbp.Audio == nil) then
        return playingID
    end

    local uiAudioConfig = Game.TableData.GetUIAudioDataRow(wbp.Audio)
    if uiAudioConfig == nil then
        return playingID
    end

    local eventName = uiAudioConfig.Audios[uiAudioEventType]
    if (eventName == nil) or (eventName == "") then
        return playingID
    end

    return self:PostEvent2D(eventName)
end


--endregion UI


--region Server


---@private
function AkAudioManager:resetServerAudio()
    for eventName, playingID in pairs(self.serverPostEvents) do
        self:StopEvent(playingID)
        self.serverPostEvents[eventName] = nil
    end

    for group, _ in pairs(self.serverSetGroupState) do
        self:ResetGroupState(group)
        self.serverSetGroupState[group] = nil
    end

    for name, _ in pairs(self.serverSetRtpcValue) do
        self:ResetRtpcValue(name)
        self.serverSetRtpcValue[name] = nil
    end
end

-- 角色加载完成时根据服务器属性刷新音频相关表现
---@private
function AkAudioManager:Receive_LEVEL_ON_ROLE_LOAD_COMPLETED()
    self:RefreshServerPostedEvent()
    self:RefreshServerSetGroupState()
    self:RefreshServerSetRtpcValue()
end

local __Server_Audio_Blend = 500 -- luacheck: ignore

-- 服务器控制播放音频,局内清除,要求服务器有记录
---@public
---@param eventNameList string[]
function AkAudioManager:OnServerPostEvent(eventNameList)
    if not Game.me.mapLoaded then
        return
    end

    for _, eventName in ipairs(eventNameList) do
        local inPlayingID = self.serverPostEvents[eventName]
        if inPlayingID then
            self:StopEvent(inPlayingID, __Server_Audio_Blend)
            Log.DebugFormat("[OnServerPostEvent] inPlayingID=%s stopped", inPlayingID)
        end

        local playingID = self:PostEvent2D(eventName)
        self.serverPostEvents[eventName] = playingID
        Log.DebugFormat("[OnServerPostEvent] eventName=%s", eventName)
    end
end

-- 重连时根据服务器属性刷新播放
function AkAudioManager:RefreshServerPostedEvent()
    for eventName, playingID in pairs(self.serverPostEvents) do
        self:StopEvent(playingID)
        self.serverPostEvents[eventName] = nil
    end

    local space = Game.NetworkManager.GetLocalSpace()
    if not space then
        Log.Warning("[RefreshServerPostedEvent] get space entity failed")
        return
    end

    self:OnServerPostEvent(space.AkEventList or {})
end

-- 服务器设置GroupState,要求服务器记录属性
---@public
---@param groupState table<string, string>
function AkAudioManager:OnServerSetGroupState(groupState)
    if not Game.me.mapLoaded then
        return
    end

    for group, state in pairs(groupState) do
        self:SetGroupState(group, state)
        self.serverSetGroupState[group] = state
    end
end

-- 重连时根据服务器属性处理
function AkAudioManager:RefreshServerSetGroupState()
    for group, _ in pairs(self.serverSetGroupState) do
        self:ResetGroupState(group)
        self.serverSetGroupState[group] = nil
    end

    local space = Game.NetworkManager.GetLocalSpace()
    if not space then
        Log.Warning("[RefreshServerSetGroupState] get space entity failed")
        return
    end

    self:OnServerSetGroupState(space.AkGroupState or {})
end

-- 服务器设置Rtpc,要求服务器记录属性
---@public
---@param rtpcValue table<string, number>
function AkAudioManager:OnServerSetRtpcValue(rtpcValue)
    if not Game.me.mapLoaded then
        return
    end

    for name, Value in pairs(rtpcValue) do
        self:SetRtpcValue(name, Value)
        self.serverSetRtpcValue[name] = Value
    end
end

-- 重连时根据服务器属性处理
function AkAudioManager:RefreshServerSetRtpcValue()
    for name, _ in pairs(self.serverSetRtpcValue) do
        self:ResetRtpcValue(name)
        self.serverSetRtpcValue[name] = nil
    end

    local space = Game.NetworkManager.GetLocalSpace()
    if not space then
        Log.Warning("[RefreshServerSetRtpcValue] get space entity failed")
        return
    end

    self:OnServerSetRtpcValue(space.AkRtpcValue or {})
end


--endregion Server


--region Setting


-- Windows下窗口失去焦点时,根据设置控制音频播放
---@public
---@param bLostFocus boolean
function AkAudioManager:OnWindowFocusChanged(bLostFocus)
    if self.bLostFocus == bLostFocus then
        return
    end

    self.bLostFocus = bLostFocus
    local bPlayBackGroundAudio = Game.SettingsManager:GetIniData(Enum.ESettingDataEnum.PlayBackGroundSFX)
    if (self.bLostFocus == true) and (bPlayBackGroundAudio == 0) then
        Game.SettingsManager:SetStopBackEndSoundEffect()
    else
        Game.SettingsManager:SetPlayFontEndSoundEffect()
    end
end


--endregion Setting


--region Stage


-- 阶段切换时加卸载Bank
---@public
---@param lastStage number
---@param newStage number
function AkAudioManager:SwitchStageAudio(lastStage, newStage)
    -- 过滤游戏启动时的情况
    if lastStage == newStage then
        return
    end

    local EGameStageType = Game.GameLoopManagerV2.EGameStageType

    if lastStage == EGameStageType.Platform then
        -- 从平台阶段切走的,加载LoginBank
        self:SyncLoadBank(Enum.EAudioConstData.LOGIN_STAGE_BANK, self)
    elseif (lastStage == EGameStageType.InGame) or (lastStage == EGameStageType.Loading) then
        -- 从游戏阶段回到登录/创角/选角阶段的
        if (newStage == EGameStageType.Login)
                or (newStage == EGameStageType.CreateRole)
                or (newStage == EGameStageType.SelectRole)
                or (newStage == EGameStageType.Platform) then
            self:OutMapAudioTagControl()
            self:SyncLoadBank(Enum.EAudioConstData.LOGIN_STAGE_BANK, self)
        end
    elseif newStage == EGameStageType.Loading then
        -- 从登录/创角/选角阶段进Loading的,标记一下,等InGame阶段时再卸载,执行当前Tag的清理
        if (lastStage == EGameStageType.Login)
                or (lastStage == EGameStageType.CreateRole)
                or (lastStage == EGameStageType.SelectRole)
                or (lastStage == EGameStageType.Platform) then
            self:ResetCurMapAudioTag()
            self.bNeedUnloadStageBank = true
        end
    elseif (newStage == EGameStageType.InGame) and (self.bNeedUnloadStageBank == true) then
        -- 进入到InGame阶段且有标记,进行卸载
        self:SyncUnloadBank(Enum.EAudioConstData.LOGIN_STAGE_BANK, self)
        self.bNeedUnloadStageBank = false
    end
end


--endregion Stage


--region Dance


local __External_Sources = slua.Array(EPropertyClass.Struct, import("AkExternalSourceInfo")) -- luacheck: ignore

-- 舞会玩法的专用接口
---@public
---@param eventName string
---@param callback function 按beat执行的回调
---@return number
function AkAudioManager:PostDanceEvent(eventName, callback)
    if not IsValid_L(Game.ObjectActorManager:GetObjectByID(Game.me.CharacterID)) then
        Log.Error("[PostDanceEvent] main player invalid")
        return
    end

    local playingID = AGS.PostEvent(nil, Game.ObjectActorManager:GetObjectByID(Game.me.CharacterID), 1 << EAkCallbackType.MusicSyncBeat, callback, __External_Sources, true, eventName)
    if playingID == AK_INVALID_PLAYING_ID then
        Log.WarningFormat("[PostDanceEvent] %s post failed", eventName)
        return AK_INVALID_PLAYING_ID
    end

    Log.DebugFormat("[PostDanceEvent] eventName=%s, playingID=%s", eventName, playingID)

    self.autoStopIDList[playingID] = 1
    return playingID
end

-- 舞会玩法专用,跳到指定的百分比位置
---@public
---@param eventName string
---@param percent number
function AkAudioManager:SeekOnDanceEvent(eventName, percent)
    if not IsValid_L(Game.ObjectActorManager:GetObjectByID(Game.me.CharacterID)) then
        Log.Error("[SeekOnDanceEvent] main player invalid")
        return
    end

    local akComp = Game.ObjectActorManager:GetObjectByID(Game.me.CharacterID):GetComponentByClass(UAkComponent)
    if not akComp then
        Log.Error("[SeekOnDanceEvent] main player no akComp")
        return
    end

    local result = self.cppMgr:InnerSeekOnDanceEvent(eventName, akComp, percent)
    if result ~= EAkResult.Success then
        Log.WarningFormat("[SeekOnDanceEvent] seek %s to %s failed with %s", eventName, percent, result)
    end
end


--endregion Dance


--region Profile


-- 打印当前的bank信息
---@public
function AkAudioManager:PrintCurrentBankInfo()
    Log.Debug("[PrintCurrentBankInfo] ==============================")
    for bankName, _ in pairs(self.staticBanks) do
        Log.DebugFormat("[PrintCurrentBankInfo] staticBank: %s", bankName)
    end

    for _, bankName in ipairs(self.lru.cache) do
        Log.DebugFormat("[PrintCurrentBankInfo] lru: %s", bankName)
    end
    Log.Debug("[PrintCurrentBankInfo] ==============================")
end

-- 开始Ak性能分析
---@public
---@param fileName string
function AkAudioManager:StartAkProfilerCapture(fileName)
    fileName = fileName or tostring(os.time())
    Log.DebugFormat("[StartAkProfilerCapture] fileName=%s", fileName)
    AGS.StartProfilerCapture(fileName)
end

-- 停止Ak性能分析
---@public
function AkAudioManager:StopAkProfilerCapture()
    Log.Debug("[StopAkProfilerCapture]")
    AGS.StopProfilerCapture()
end


--endregion Profile


return AkAudioManager
