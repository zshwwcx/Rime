local WorldViewBudgetConst = kg_require("Gameplay.CommonDefines.WorldViewBudgetConst")

local const = kg_require("Shared.Const")
local NIAGARA_HIDDEN_REASON = const.NIAGARA_HIDDEN_REASON
---@class UEActorManager
UEActorManager = DefineClass("UEActorManager")

--API BEGIN------------------------------------------------------------------


Enum.EUEActorType = {
    None = 0, -- 不需要返回
    MainPlayer = 1, --主角
    AoiPlayer = 2, --第三方玩家
    NPC = 3,
    BriefPlayer_2 = 2001, --AOI 2级精简玩家
    Npc_Monster = 301, -- 怪物
    Npc_LevelB = 311, -- B级NPC
    IceField = 4,  -- 冰块
    TraceNavigator = 6,  -- 任务追踪小龙
    ChasedMonster = 7, -- 被追的蝴蝶
    AttachItem = 8, --挂接物品
    LocalDisplayChar = 9, --挂接物品
    SceneActor = 10, --场景物体
    DialogueNPC = 11, --剧情对话中的NPC
    TraceLine = 16,  -- 追踪引导线
    CutSceneActor = 17, -- CutScene中的替换Actor
    LocalControllableNPC = 18, --无形之手
    LocalControllableNPCRegion = 19 ,--移动限制范围
    LargeMarineLife = 20,--大型海洋生物
    SimpleNPC = 21, --简单NPC(小龙)
    TrackTrail = 23, --追踪轨迹
    LocalDisplayNpc = 25, --测试展示场景的Npc
    LocalMountEntity = 26, -- 本地坐骑
	GraveWolf = 27, --寂静墓地狼灵
	CommonInteractor = 28, -- 通用交互物
}

VIEW_DOWNGRADING_BUDGET_CARED = {
    [Enum.EUEActorType.MainPlayer] = 1,
    [Enum.EUEActorType.AoiPlayer] = 1,
    [Enum.EUEActorType.NPC] = 1,
    [Enum.EUEActorType.Npc_Monster] = 1,
    [Enum.EUEActorType.Npc_LevelB] = 1,
    [Enum.EUEActorType.DialogueNPC] = 1,
    [Enum.EUEActorType.CutSceneActor] = 1,
    [Enum.EUEActorType.LocalDisplayNpc] = 1,
	[Enum.EUEActorType.LocalDisplayChar] = 1,
}

-- 使用新的Actor框架创建Actor, 迁移过程中支持新老两种写法混用
-- value为是否完成迁移，完成后某一类Entity将不再支持老的方式
USE_NEW_UE_ACTOR_MAP = {
    -- [Enum.EUEActorType.TraceLine] = false
}
-- ==============================复杂角色表现能力定义 END=============================================

function UEActorManager:CreateUEActorNew(UEActorType, X,Y,Z, Pitch,Roll,Yaw, EntityID, CustomClassStr, CompositeParam, SceneInstanceID)
    local Entity = Game.EntityManager:getEntityWithBrief(EntityID)
    if not Entity then 
        return
    end
    local actorType = "Entity"
    local classPath = self.ActorClass[UEActorType]
    local ueActor = self.cppMgr:CreateActorNew(Entity, EntityID, actorType, classPath, X, Y, Z, Pitch,Roll,Yaw)
    if not ueActor then
        Log.ErrorFormat("CreateUEActor failed, entityID -> %s", EntityID)
        return
    end
    Entity.cppActor = ueActor
    self.NewUEActor[EntityID] = UEActorType
end

function UEActorManager:IsNewUEActor(EntityID)
    local ActorType = self.NewUEActor[EntityID]
    if ActorType == nil then 
        return false
    end
    return USE_NEW_UE_ACTOR_MAP[ActorType] == true
end

function UEActorManager:CreateUEActor(UEActorType, X,Y,Z, Pitch,Roll,Yaw, EntityID, CustomClassStr, CompositeParam, SceneInstanceID)
       
    if USE_NEW_UE_ACTOR_MAP[UEActorType] ~= nil then
        return self:CreateUEActorNew(UEActorType, X,Y,Z, Pitch,Roll,Yaw, EntityID, CustomClassStr, CompositeParam, SceneInstanceID)
    end

    --待EngineDev合并之后 移除
    local Entity = Game.EntityManager:getEntityWithBrief(EntityID)
    if not Entity then
		Log.DebugFormat("[LogicUnit-LifeTimeStage]UEActorManager:CreateUEActor EntityID:%s  UEActorType:%s  CustomClassStr:%s, Is Brief Entity  or Not Exist", EntityID, UEActorType, CustomClassStr)
		return
	end

    -- 主玩家因为会跨图是保留actor的, 主玩家侧注意是在WorldManager中处理
    if Entity ~= Game.me then
        local viewRoleImportance = Entity.ViewRoleImportance
        if viewRoleImportance ~= nil and VIEW_DOWNGRADING_BUDGET_CARED[UEActorType] ~= nil then
            local downgradingBudgetPreset = WorldViewBudgetConst.DOWNGRADING_PRESET_FROM_IMPORTANCE[viewRoleImportance]
            Entity:TryRequestViewDownGradingBudgetTokenBatch(downgradingBudgetPreset[1], downgradingBudgetPreset[2])
            if CompositeParam ~= nil then
                CompositeParam.ViewDownGradingBudgetFlags = Entity.ViewDowngradingFlags
            end
        end
    end

	Log.DebugFormat("[LogicUnit-LifeTimeStage]UEActorManager:CreateUEActor EntityID:%s  UID:%s UEActorType:%s  SceneInstanceID:%s  CustomClassStr:%s", EntityID, Entity:uid(), UEActorType, SceneInstanceID, CustomClassStr)
	
    EntityID = Entity:uid()

    if UEActorType == Enum.EUEActorType.MainPlayer then
        ---临时兼容现在的逻辑, 后续Entity完善后移除

        if self.bEnableMainPlayerCrossMap == false then
            -- 清理主角Character
            local PlayerController = import("GameplayStatics").GetPlayerController(slua.getWorld(), 0)
            if PlayerController ~= nil then

                --开启控制器更新
                import("KGUEActorManager").SetActorTickEnable(PlayerController, true)

                local OldPawn = PlayerController:K2_GetPawn()
                if OldPawn then
                    local entity = Game.EntityManager:getEntityWithBrief(OldPawn:GetEntityUID())
                    PlayerController:UnPossess()
                    -- 断掉和Entity之间引用，防止Character 非法报错
                    if entity then
                        -- 临时写法，否则切换角色后进游戏，此时老的RpcEntity引用已经销毁会报错
                        if Game.me == entity then
                            entity.CharacterID = 0
                        end
                    end

                    if OldPawn.KillActor and entity then
                        OldPawn:KillActor()
                    else
                        OldPawn:K2_DestroyActor()
                    end
                end
            end
        end
    end

    local ActorCreateParamsCache = import("UEActorCreateParams")()
    ActorCreateParamsCache.EntityID = EntityID
    
    
    --类加载 TODO
    --自定义的先兼容
    if CustomClassStr ~= nil then
        ActorCreateParamsCache.ClassPath = CustomClassStr
    else
        ActorCreateParamsCache.ClassPath = self.ActorClass[UEActorType]
    end
    
    --坐标相关 后续封装
    if self.Translation ~= nil then
        self.Translation.X = X
        self.Translation.Y = Y
        self.Translation.Z = Z
    end

    if self.Rotation ~= nil then
        self.Rotation.Pitch = Pitch
        self.Rotation.Roll = Roll
        self.Rotation.Yaw = Yaw
    end

    self.TransformParamsCache:SetRotation(self.Rotation:ToQuat())
    self.TransformParamsCache:SetTranslation(self.Translation)

    ActorCreateParamsCache.Transform = self.TransformParamsCache
    ActorCreateParamsCache.bPreLoad = false

    --兼容目前的逻辑,后期主角需要预加载
    --ActorCreateParamsCache.bSyncLoad = (UEActorType == Enum.EUEActorType.MainPlayer) 

    if UEActorType == Enum.EUEActorType.DialogueNPC then --对话编辑器状态下同步加载
        ActorCreateParamsCache.bSyncLoad = true
    end
    if CompositeParam then
        if CompositeParam.UID then
            self.UEActorCompositeMap[CompositeParam.UID] = CompositeParam
        else
            self.UEActorCompositeMap[CompositeParam.EntityUID] = CompositeParam
        end

        -- todo 为了区分P1/P3进行临时处理 @sunya 20240810
        CompositeParam.UEActorType = UEActorType
    end

    self.UEActor_CreateActorMap[EntityID] = true

    Game.WorldManager:SpawnUEActor(ActorCreateParamsCache, SceneInstanceID, UEActorType)
end

function UEActorManager:PostCreateUEActor(ActorCreateParams)
    Log.DebugFormat("[LogicUnit-LifeTimeStage]UEActorManager:PostCreateUEActor:%s", ActorCreateParams.EntityID)

    if self.bEnableMainPlayerCrossMap and Game.me and ActorCreateParams.EntityID == Game.me:uid() then
        local PlayerController = import("GameplayStatics").GetPlayerController(slua.getWorld(), 0)
        if PlayerController ~= nil then
            local OldPawn = PlayerController:K2_GetPawn()
            if OldPawn then
                self:OnCreateActor(OldPawn, ActorCreateParams.EntityID)
            end
        end
    else
        --请求创建UEActor
        self.cppMgr:CreateActor(ActorCreateParams)
    end
end


function UEActorManager:DestroyUEActor(EntityID)
    --待EngineDev合并之后 移除
    local Entity = Game.EntityManager:getEntityWithBrief(EntityID)
    if Entity then 
        Log.DebugFormat("[LogicUnit-LifeTimeStage]UEActorManager DestroyUEActor:%s, EntityUid:%s EntityType: %s", Entity.eid, Entity:uid(), Entity.__cname)

        Game.WorldManager:OnDestroyActor(EntityID)

        if Game.ActorAppearanceManager and Game.ActorAppearanceManager.EnableFun then
            Game.ActorAppearanceManager:OnDestoryActor(Entity:uid())
        end

        self.UEActorCompositeMap[Entity:uid()] = nil
        self.UEActor_CreateActorMap[Entity:uid()] = nil

        self:InnerDestoryActor(Entity:uid())
    end
end

--重新附加主角
function UEActorManager:AttachMainUEActor()
	Log.DebugFormat("[LogicUnit-LifeTimeStage] UEActorManager:AttachMainUEActor   Game.me:%s", Game.me )
    if Game.me == nil then
        Log.Error("AttachMainUEActor: Game.me == nil !")
        return 
    end
	
    if self.bEnableMainPlayerCrossMap then
        local PlayerController = import("GameplayStatics").GetPlayerController(slua.getWorld(), 0)
        if PlayerController ~= nil then
    
            --开启控制器更新
            import("KGUEActorManager").SetActorTickEnable(PlayerController, true)
    
            --开启Main Pawn 更新
            local Pawn = PlayerController:K2_GetPawn()
            if Pawn then
    
                import("KGUEActorManager").SetActorTickEnable(Pawn, true)
                
                --临时处理下移动
                if Pawn:GetCharacterMoveComp() then
                    Pawn:GetCharacterMoveComp():EnableMoveTick(true)
                end
                
                --显示
                Pawn:SetActorHiddenInGame(false)
                --碰撞
                Pawn:SetActorEnableCollision(true)
				
            end
        end
    end
end

--分离主角
function UEActorManager:DetachMainUEActor()

	Log.DebugFormat("[LogicUnit-LifeTimeStage] UEActorManager:DetachMainUEActor   Game.me:%s", Game.me )
    if Game.ActorAppearanceManager and Game.ActorAppearanceManager.EnableFun then
        if Game.me then
            Game.ActorAppearanceManager:OnDestoryActor(Game.me:uid())
        end
    end

    --停止主角的一切更新

    local PlayerController = import("GameplayStatics").GetPlayerController(slua.getWorld(), 0)
    if PlayerController ~= nil then

        --暂停控制器更新
        import("KGUEActorManager").SetActorTickEnable(PlayerController, false)

        --暂停Main Pawn 更新
        local Pawn = PlayerController:K2_GetPawn()
        if Pawn then

            import("KGUEActorManager").SetActorTickEnable(Pawn, false)

            --临时处理下移动
            if Pawn:GetCharacterMoveComp() then
                Pawn:GetCharacterMoveComp():EnableMoveTick(false)
            end
             

            Pawn:SetActorHiddenInGame(true)
            --碰撞
            Pawn:SetActorEnableCollision(false)
			
            if self.bEnableMainPlayerCrossMap then
                --清理组件

            end
        end
    end
end

--清理所有的UEActor(地图切换前一步)
function UEActorManager:ClearAllUEActor()
	Log.DebugFormat("[LogicUnit-LifeTimeStage] UEActorManager:ClearAllUEActor   Game.me:%s", Game.me )
    for _EntityUID, _ in pairs(self.UEActor_CreateActorMap) do
        --理论上被销毁的Entity都已被销毁
        local _Entity = Game.EntityManager:getEntityWithBrief(_EntityUID)
        if _Entity then
            --主角不清理
            if _Entity == Game.me then
                goto Continue
            else
                Log.Warning("UEActorManager:ClearAllUEActor Entity Exist !!! " .. tostring(_EntityUID))
            end
        end

        self:InnerDestoryActor(_EntityUID)

        ::Continue::
    end

    self.UEActor_CreateActorMap = {}

    --清理Actor类缓存
    if self.cppMgr then
        self.cppMgr.ClassMap:Clear()
    end

end

--API END------------------------------------------------------------------

function UEActorManager:ctor()
    self.ActorClass = {}
    self.UEActorCompositeMap = {}
    self.ABaseCharacterUEClass = nil
    self.UEActor_CreateActorMap = {} --{EntityUID:true}

    self.bEnableMainPlayerCrossMap = false
    self.NewUEActor = {}
end

function UEActorManager:dtor()
    
end

function UEActorManager:Init()

    self.cppMgr = import("KGUEActorManager")(Game.WorldContext)
    Game.GameInstance:CacheManager(self.cppMgr)
    self.cppMgr:NativeInit()

    self.cppMgr.OnCreateActorCB:Bind(function (NewActor, EntityID)
        self:OnCreateActor(NewActor, EntityID)
    end)
    self.cppMgr.OnActorDestoryCB:Bind(function (DestroyedActor, EntityID)
        self:OnActorDestory(DestroyedActor, EntityID)
    end)

    self.cppMgr.GameInstance = import("GameplayStatics").GetGameInstance(Game.GameInstance or _G.GetContextObject())
    self.cppMgr.FrameCreateActorMaxNum = 5

    --类加载 TODO
    self.ActorClass = {}
    self.ActorClass[Enum.EUEActorType.MainPlayer] = "/Game/Blueprint/3C/BP_PlayerCharacter.BP_PlayerCharacter_C"
    self.ActorClass[Enum.EUEActorType.AoiPlayer] = "/Game/Blueprint/3C/Actor/BP_AOI_PlayerCharacter.BP_AOI_PlayerCharacter_C"
    self.ActorClass[Enum.EUEActorType.NPC] = "/Game/Blueprint/AI/TestCharacter/BP_TestAICharacter.BP_TestAICharacter_C"
    self.ActorClass[Enum.EUEActorType.BriefPlayer_2] = "/Game/Blueprint/3C/Actor/BP_BriefActor.BP_BriefActor_C"
    self.ActorClass[Enum.EUEActorType.Npc_Monster] = "/Game/Blueprint/3C/Actor/BP_Npc_Monster.BP_Npc_Monster_C"
    self.ActorClass[Enum.EUEActorType.Npc_LevelB] = "/Game/Blueprint/3C/Actor/BP_Npc_LevelB.BP_Npc_LevelB_C"
    self.ActorClass[Enum.EUEActorType.IceField] = "/Game/Blueprint/LogicActor/BP_IceField.BP_IceField_C"
    self.ActorClass[Enum.EUEActorType.LargeMarineLife] = "/Game/Blueprint/AI/TestCharacter/BP_TestAICharacter.BP_TestAICharacter_C"
    self.ActorClass[Enum.EUEActorType.ChasedMonster] = "/Game/Blueprint/LogicActor/BP_ChasedMonster.BP_ChasedMonster_C"
   	self.ActorClass[Enum.EUEActorType.AttachItem] = "/Game/Blueprint/3C/Equipment/BP_AttachItemBase.BP_AttachItemBase_C"
    self.ActorClass[Enum.EUEActorType.LocalDisplayChar] = "/Game/Blueprint/3C/Actor/BP_LocalDisplayCharacter.BP_LocalDisplayCharacter_C"
    self.ActorClass[Enum.EUEActorType.DialogueNPC] = "/Game/Blueprint/3C/Actor/BP_DialogueActor.BP_DialogueActor_C"
    self.ActorClass[Enum.EUEActorType.TraceLine] = "/Game/Blueprint/3C/Core/BP_TaskTrackLineActor.BP_TaskTrackLineActor_C"
    self.ActorClass[Enum.EUEActorType.CutSceneActor] = "/Game/Blueprint/3C/Actor/BP_CutSceneDynamicActor.BP_CutSceneDynamicActor_C"
    self.ActorClass[Enum.EUEActorType.LocalControllableNPC] = "/Game/Blueprint/AI/TestCharacter/BP_TestAICharacter.BP_TestAICharacter_C"
    self.ActorClass[Enum.EUEActorType.LocalControllableNPCRegion] = "/Game/Blueprint/InvisibleHand/BP_ControlRegionTemplate.BP_ControlRegionTemplate_C"
    self.ActorClass[Enum.EUEActorType.SimpleNPC] = "/Game/Blueprint/AI/TestCharacter/BP_SimpleAICharacter.BP_SimpleAICharacter_C"
    self.ActorClass[Enum.EUEActorType.TrackTrail] = "/Game/Blueprint/SceneActor/BP_NiagaraCarrierV2.BP_NiagaraCarrierV2_C"
    self.ActorClass[Enum.EUEActorType.LocalDisplayNpc] = "/Game/Blueprint/AI/TestCharacter/BP_TestAICharacter.BP_TestAICharacter_C"
    self.ActorClass[Enum.EUEActorType.LocalMountEntity] = "/Game/Blueprint/3C/Actor/BP_LocalMount.BP_LocalMount_C"
	self.ActorClass[Enum.EUEActorType.GraveWolf] = "/Game/Blueprint/3C/Actor/BP_GraveWolfMonster.BP_GraveWolfMonster_C"

    self.TransformParamsCache = FTransform()
    self.Rotation = FRotator(0, 0, 0)
    self.Translation = FVector(0, 0, 0)

    --self.ActorCreateParamsCache = import("UEActorCreateParams")()

    self.UEActorCompositeMap = {}

    self.ABaseCharacterUEClass = import("BaseCharacter")

    self.UEActor_CreateActorMap = {} --{EntityUID:true}
end

function UEActorManager:UnInit()
    --退出清理主角
    self:ClearMainUEActor()

    if self.cppMgr then
        self.cppMgr:NativeUninit()
        self.cppMgr = nil
    end
end

--角色创建通知
--AActor* NewActor
--const FString& EntityID
function UEActorManager:OnCreateActor(NewActor, EntityID)

	local Entity = Game.EntityManager:getEntityWithBrief(EntityID)
	Log.DebugFormat("[LogicUnit-LifeTimeStage] [UEActorManager:OnCreateActor]  Eid:%s UID:%s cname:%s ", Entity and Entity.eid, EntityID, Entity and Entity.__cname)

    if Entity then

        if NewActor and NewActor.SetEntityUID then
            NewActor:SetEntityUID(EntityID)
        end

        local CompositeParam = self.UEActorCompositeMap[Entity:uid()]
        if CompositeParam then

            if CompositeParam.FacadeScaleValue then
                NewActor:SetActorScale3D(FVector(CompositeParam.FacadeScaleValue, CompositeParam.FacadeScaleValue, CompositeParam.FacadeScaleValue))
            end

            if CompositeParam.CompositeType == Enum.EUECompositeType.AttachItem then
                CompositeParam.CompositeCallFunc = UEActorManager_OnCompositeActorV2
                Game.RoleCompositeMgr:RefreshAttachItem(NewActor, Entity.eid, CompositeParam)

            else
                if Game.me and EntityID == Game.me:uid() then
                    NewActor.bMainPlayer = true

                    Log.DebugFormat("[UEActorManager] OnCreateActor MainPlayer %s: ", Entity.eid)
                end

                self:setActorVisible(NewActor, false)
                    
                CompositeParam.CompositeCallFunc = UEActorManager_OnCompositeActorV2
				Game.ActorAppearanceManager:Refresh_Avatar(NewActor, CompositeParam)
            end
        else
            Log.DebugFormat("[UEActorManager] OnCreateActor S OnLoadActorFinish %s: ", EntityID)
            Game.WorldManager:OnLoadActorFinish(NewActor, Entity:uid())
        end
    end
end

function UEActorManager:OnCompositeActor(NewActor, EntityUID, PreLoadData)
    Log.DebugFormat("[LogicUnit-LifeTimeStage][UEActorManager:OnCompositeActor]  UID:%s ", EntityUID)

    local Entity = Game.EntityManager:getEntityWithBrief(EntityUID)
    if Entity then
        if NewActor:IsA(self.ABaseCharacterUEClass) then
            Game.WorldManager:RegisterCharacter(Entity:uid(), NewActor)
            if Game.NetSyncManager then
                Game.NetSyncManager:RegisterCharacter(Entity:uid(), NewActor)
            end
        end

        self:setActorVisible(NewActor, true)

        if Entity.ENTITY_TYPE == "MainPlayer" then
            Log.DebugFormat("[UEActorManager] OnCompositeActor MainPlayer %s: ", Entity.eid)

            --仅主角初始化WP组件
            local WPCom = NewActor:RegisterComponentByClass(import("WorldPartitionStreamingSourceComponent"),"WP_1")
            if WPCom then

            end

            --屏蔽
            import("LuaHelper").SetActorComponentTickEnabled(NewActor, import("FaceAnimComponent"), false)

            local PlayerController = import("GameplayStatics").GetPlayerController(slua.getWorld(), 0)
            if PlayerController ~= nil then
                PlayerController:Possess(NewActor)
            end
        end
        
        local CompositeParam = self.UEActorCompositeMap[Entity:uid()]
        if CompositeParam then
            self.UEActorCompositeMap[Entity:uid()] = nil
            
            Log.DebugFormat("[UEActorManager] OnCompositeActor NotifyLoadActor %s: ", EntityUID)
            Game.WorldManager:OnLoadActorFinish(NewActor, Entity:uid(), PreLoadData)

            if Entity.ENTITY_TYPE == "MainPlayer" then
                local Result = {}
                local Characters = slua.Array(import("EPropertyClass").Object, import("BaseCharacter"))
                import("GameplayStatics").GetAllActorsOfClass(GetContextObject(), import("BaseCharacter"), Characters)
                for i = 0, Characters:Length() - 1 do
                    local Character = Characters:Get(i)
                    if Character then
                        local Comps = Character:K2_GetComponentsByClass(import("WorldPartitionStreamingSourceComponent"))
                        for j = 0, Comps:Num()-1 do
                            local Comp = Comps:Get(j)
                            table.insert(Result, Comp)
                        end
                    end
                end
    
                for k, v in pairs(Result) do
                    if IsValid_L(v) and IsValid_L(v:GetOwner()) and v:GetOwner() ~= GetMainPlayerCharacter() then
                        Log.InfoFormat("WorldPartition Destroy: %s", tostring(v:GetOwner():GetName()))
                        v:GetOwner():K2_DestroyActor()
                    end
                end
            end
        end
    end
end

function UEActorManager_OnCompositeActorV2(NewActor, EntityUID, PreLoadData)
	Log.DebugFormat("[LogicUnit-LifeTimeStage] [UEActorManager_OnCompositeActorV2] OnCompositeActor %s: ", EntityUID)
    Game.UEActorManager:OnCompositeActor(NewActor, EntityUID, PreLoadData)
end

--内部销毁UEActor
function UEActorManager:InnerDestoryActor(UID)
    --中断外观组装流程
    xpcall(Game.UECompositeManager.CancelComposite, _G.CallBackError, Game.UECompositeManager, UID)

    if self.NewUEActor[UID] ~= nil then
        self.NewUEActor[UID] = nil
        self.cppMgr:DestroyActorNew(UID)
    else
        --销毁Actor
        self.cppMgr:DestoryActor(UID)
    end
end

--角色销毁通知
--AActor* DestroyedActor
--const FString& EntityID
function UEActorManager:OnActorDestory(DestroyedActor, EntityID)
    Log.DebugFormat("[LogicUnit-LifeTimeStage] UEActorManager:OnActorDestory %s", EntityID)
    local Entity = Game.EntityManager:getEntity(EntityID)
    if Entity and not Entity.isBriefAvatar and Entity.isAvatar then
        Game.WorldManager:UnRegisterLODSignActor(DestroyedActor)
    end
end

--主动清理主角
function UEActorManager:ClearMainUEActor()
	Log.DebugFormat("[LogicUnit-LifeTimeStage] UEActorManager:ClearMainUEActor ")
    local PlayerController = import("GameplayStatics").GetPlayerController(slua.getWorld(), 0)
    if PlayerController ~= nil then
        local OldPawn = PlayerController:K2_GetPawn()
        if OldPawn then
            OldPawn:K2_DestroyActor()
        end
    end
end

function UEActorManager:setActorVisible(Actor, bVisible)
	Log.DebugFormat("[LogicUnit-LifeTimeStage] UEActorManager:setActorVisible  Visible:%s   Actor:%s", bVisible, Actor)
    --
    Actor:SetActorHiddenInGame(not bVisible)
    -- --Mesh更新
    -- import("LuaHelper").SetActorComponentTickEnabled(Actor, import("MeshComponent"), not bHidden)

    -- Actor:SetActorTickEnabled(not bHidden)
    --碰撞
    Actor:SetActorEnableCollision(bVisible)

	if Game.EffectManager then
		Game.EffectManager:OnUpdateSpawnerVisibility(Game.ObjectActorManager:GetIDByObject(Actor),bVisible,NIAGARA_HIDDEN_REASON.OWNER_SET_HIDDEN)
	end
end

return UEActorManager