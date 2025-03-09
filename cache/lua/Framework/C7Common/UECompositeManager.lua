local URoleCompositeFunc = import("RoleCompositeFunc")
local UBoxComponent = import("BoxComponent")
local EPropertyClass = import("EPropertyClass")
local EAttachmentRule = import("EAttachmentRule")
local EAnimationMode = import("EAnimationMode")
local EVisibilityBasedAnimTickOption = import("EVisibilityBasedAnimTickOption")
local KGActorUtil = import("KGActorUtil")
local UKGComponentUtil = import("KGComponentUtil")
local KGUECompositeOperateLibrary = import("KGUECompositeOperateLib")
local const = kg_require("Shared.Const")
local NIAGARA_SOURCE_TYPE = const.NIAGARA_SOURCE_TYPE
local ViewAnimConst = kg_require("Gameplay.CommonDefines.ViewAnimConst")
local NIAGARA_EFFECT_TAG = const.NIAGARA_EFFECT_TAG
local AnimLibHelper = kg_require("GamePlay.3C.RoleComposite.AnimLibHelper")

--UE的异步组件组装
local UBaseAnimInstance = import("BaseAnimInstance")
local UECompositeManager = DefineClass("UECompositeManager")
local UPropClass = import("EPropertyClass")

local MaterialEffectParamTemplate = kg_require("Gameplay.Effect.MaterialEffectParamTemplate")
local MaterialEffectParamsPool = MaterialEffectParamTemplate.MaterialEffectParamsPool
local ChangeMaterialRequestTemplate = MaterialEffectParamTemplate.ChangeMaterialRequestTemplate
local ChangeMaterialParamRequestTemplate = MaterialEffectParamTemplate.ChangeMaterialParamRequestTemplate
local SEARCH_MESH_TYPE = MaterialEffectParamTemplate.SEARCH_MESH_TYPE
local MATERIAL_EFFECT_TYPE = MaterialEffectParamTemplate.MATERIAL_EFFECT_TYPE

Enum.UECompositeState = {
    None = 0, --未初始
    Pending = 1, --正在处理
    Resolve = 2, --完成
    Rejected = 3, --错误中断, 消息记录在Error
} 

Enum.UECompositeType = {
    Base = -1,
    Group = 0,
    LoadAsset = 1,
    SkeletalMeshCom = 2,
    StaticMeshCom = 3,
    HitBox = 4,
    Capsule = 5,
    Material = 6,
    Anim = 7,
    MergeMesh = 8,
    BodyShape = 9,
    MaterialModify = 10,
    Effect = 11,
    AnimLoad = 12,
    MeshClone = 13,
}

Enum.UECompositeComTag = {
    Mesh = "BodyUpper", --主Mesh
    Hair = "Hair", --头发
    Head = "Head" --头
}

Enum.UECompositeGroupType = {
    Base = "Base",
    Appearance = "Appearance", --通用外观
    Suit = "Suit", --套装
    AttachItem = "AttachItem" --挂接物
}

Enum.UECompositeDissolveType = { --溶解类型
    None = -1, --不启用
    Noise = 0, --局内
    Direction = 1, --系统展示
    Noise_Out = 2, --局内溶出
    Scene_Direction = 3, --场景方向融入
    Scene_Direction_Out = 4, --场景方向融出
    Scene_Noise_Out = 5, --场景溶出
    Direction_Out = 6, --系统溶出
}

Enum.UEActorMeshCBType = 
{
	MeshComCreate = 1 << 1, --Mesh组件新建(实例创角, 并未加载资源)
	MeshChanged = 1 << 2, --Mesh资源替换
	MeshComDestroy = 1 << 3, --Mesh组件销毁(销毁前调用)
	ShadowPhysics = 1 << 4, --物理资源修改
}

UECompositeManager.CompositeEffectTag = "CompositeEffectTag"
UECompositeManager.AnimClassChangedTag = "AnimClassChangedTag"
UECompositeManager.SkeletalChangedTag = "SkeletalChangedTag"

UECompositeManager.CloneMesh_Suffix = "CloneMesh"
UECompositeManager.GFurTag_Suffix = "GFur"
UECompositeManager.GFurTagCloneMesh_Suffix = "GFurCloneMesh"

UECompositeManager.EyeLashSlotName = "EyeLash"

CompositeOperateBase = DefineClass("CompositeOperateBase")
function CompositeOperateBase:ctor()
    self.OperateType = Enum.UECompositeType.Base
    self.DependencyToken = {}
    self:Reset()
end

function CompositeOperateBase:Reset()
    self.ID = 0
    self.State = Enum.UECompositeState.None
    self.TargetID = 0 --目前的Object UID
    self.ErrorResult = nil

    self.DependencyToken.IDs = nil
    self.DependencyToken.RemainIDs = nil

    self.Data = {}
end

function CompositeOperateBase:Init()
    self:ChangeState(Enum.UECompositeState.Pending)
end

function CompositeOperateBase:Execute()

end

function CompositeOperateBase:DoExecute()
    self:Execute()

    self:ChangeState(Enum.UECompositeState.Resolve)
end

function CompositeOperateBase:ProgressCancel()
    if self.DependencyToken.IDs then
        for k, ID in pairs(self.DependencyToken.IDs) do
            local Operate = self:GetOperateFromID(ID)
            if Operate and Operate.State == Enum.UECompositeState.Pending then
                Operate:ProgressCancel()
            end
        end
    end
end

function CompositeOperateBase:OnAssetLoaded(ID, Asset)

end

function CompositeOperateBase:Notify()

end

function CompositeOperateBase:ChangeState(NewState)
    if self.State ~= NewState then
        self.State = NewState
        if NewState > Enum.UECompositeState.Pending then
            if self.State == Enum.UECompositeState.Rejected then
                if self.ErrorResult then
                    Log.WarningFormat("CompositeOperateBase:ChangeState %s", self.ErrorResult)
                end
            end

            local RegisterIDs = Game.UECompositeManager.DependencyObserverMap[self.ID]
            if RegisterIDs then
                for RID, _ in pairs(RegisterIDs) do
                    Game.UECompositeManager:DependencyRejected(self, RID)
                end
            end
        end
    end
end

function CompositeOperateBase:RequestComposite(OperateType, DependencyIDs, TargetID, Data)
    return Game.UECompositeManager:RequestComposite(OperateType, DependencyIDs, TargetID, Data)
end

function CompositeOperateBase:AddLoadAssetDependency(AssetPath)
    local Operate = Game.UECompositeManager:beginRequestComposite(Enum.UECompositeType.LoadAsset, nil, 0)
    if Operate == nil then
        return 0
    end

    Operate.Data.AssetPath = AssetPath

    local AssetOpID = Game.UECompositeManager:endRequestComposite(Operate)
    if AssetOpID == 0 then
        return 0
    end

    if self.DependencyToken.IDs == nil then
        self.DependencyToken.IDs = {}
    end

    table.insert(self.DependencyToken.IDs, AssetOpID)

    return AssetOpID
end

local function StringValid(Str)
    return Str and type(Str) == "string" and string.len(Str) > 0
end

--忽略大小写
local function IsStringEquals(StrA, StrB)
    return string.lower(StrA) == string.lower(StrB)
end

function CompositeOperateBase:GetOperateFromID(OperateID)
    return Game.UECompositeManager.CompositeOperateMap[OperateID]
end

LoadAsset_C = DefineClass("LoadAsset_C", CompositeOperateBase)
function LoadAsset_C:ctor()
    self.OperateType = Enum.UECompositeType.LoadAsset
end

function LoadAsset_C:Reset()
    self.super.Reset(self)

    self.Data.AssetPath = nil

    self.Asset = nil
    self.AssetLoadID = nil
end

function LoadAsset_C:DoExecute()
    self.AssetLoadID = Game.UECompositeManager:PushAsyncLoadAsset(self.Data.AssetPath, Game.UECompositeManager.OnAssetLoad, self.ID)
end

function LoadAsset_C:ProgressCancel()
    if self.AssetLoadID then
        Game.UECompositeManager:CancelAsyncLoadAsset(self.AssetLoadID)
    end
end

function LoadAsset_C:OnAssetLoaded(Asset)
    if Asset then
        self.Asset = Asset
        self:ChangeState(Enum.UECompositeState.Resolve)
    else
        self.ErrorResult = "Asset Load Error: " .. self.Data.AssetPath
        self:ChangeState(Enum.UECompositeState.Rejected)
    end
end

local function LocalGetUEActorComFromTag(Actor, Tag)
    local ActorComs = Actor:GetComponentsByTag(import("ActorComponent"), Tag)
    if ActorComs:Length() > 0 then
        return ActorComs:Get(0)
    else
        return nil
    end
end

local ImportC7FunctionLibrary = import("C7FunctionLibrary")

SkeletalMeshCom_C = DefineClass("SkeletalMeshCom_C", CompositeOperateBase)

SkeletalMeshCom_C.BodyMeshOffset = FTransform(FQuat(0.000000,0.000000,0.000000,0.000000),FVector(0, 0, -2), FVector(0, 0, 0)) --身体Mesh默认偏移

function SkeletalMeshCom_C:ctor()
    self.OperateType = Enum.UECompositeType.SkeletalMeshCom
end

function SkeletalMeshCom_C:Reset()
    self.super.Reset(self)

    self.Data.SkeletalMesh = nil
    self.Data.Offset = nil
    
    self.Data.OwnerActorID = nil
    self.Data.Tag = nil --如果TargetID没指定, 通过Tag来找,默认没有Tag的新创建
    self.Data.AttachTargetTag = nil --挂到对应Tag目标, 没有就挂到Root
    self.Data.SocketName = nil --对象是MeshCom的, 插槽名称
    self.Data.BodyMeshSocketName = nil --对象是MeshCom的, 插槽名称 主Mesh下的
    self.Data.LeaderPoseComTag = nil --跟随的MeshTag名

    self.Data.bReceivesDecals = nil --是否接受贴花
    self.Data.bRenderCustomDepthPass = nil --是否开启自定义深度
    self.Data.CollisionProfileName = nil --碰撞配置名称
    self.Data.bActive = nil --是否激活
    self.Data.bVisibility = nil --初始是否显示
	self.Data.PhysicsAsset = nil --是否配置物理资产
    
    --OP
    self.Data.bEnableMeshOptimization = nil --是否开启SK优化
    self.Data.bUseAttachParentBound = nil --使用父类Bound(优化用, 一般false)

    --Move
    self.Data.bEnableMoveFix = nil

    --TA
    self.Data.bCastInsetShadow = nil --阴影
    self.Data.bSingleSampleShadowFromStationaryLights = nil --物体中心位置去算一个固态阴影的遮蔽值
    self.Data.CapsuleShadow_AssetID = nil


    self.AssetOpID = 0
    self.DecorationComponentsIDs = nil

    self.MaterialOverlayAsset = nil
    self.MaterialOverlayLoadID = nil
	self.PhysicsAssetLoadID = nil
end

function SkeletalMeshCom_C:Init()
    self.super.Init(self)

    if StringValid(self.Data.SkeletalMesh) then
        self.AssetOpID = self:AddLoadAssetDependency(self.Data.SkeletalMesh)
    end

	if StringValid(self.Data.PhysicsAsset) then
		self.PhysicsAssetLoadID = self:AddLoadAssetDependency(self.Data.PhysicsAsset)
	end

    if self.Data.DecorationComponents then
        for k, _Path in pairs(self.Data.DecorationComponents) do
            if StringValid(_Path) then
                local LoadID = self:AddLoadAssetDependency(_Path)
                if LoadID then
                    if self.DecorationComponentsIDs == nil then
                        self.DecorationComponentsIDs = {}
                    end

                    table.insert(self.DecorationComponentsIDs, LoadID)
                end
            end
        end
    end


    if self.Data.SocketName == nil then
        self.Data.SocketName = ""
    end

    if self.Data.MaterialOverlay and self.Data.MaterialOverlay ~= "" then
        self.MaterialOverlayLoadID = self:AddLoadAssetDependency(self.Data.MaterialOverlay)
    end
	
	self.loadedOverrideMaterials = {}
	if self.Data.OverrideMaterials then
		for slotName, materialPath in pairs(self.Data.OverrideMaterials) do
			self.loadedOverrideMaterials[slotName] = self:AddLoadAssetDependency(materialPath)
		end
	end
end

--开启Mesh优化
function EnableSKMeshOptimization(Mesh, bEnable)

    if Game.WorldManager.EnableCustomOP == false then
        return 
    end

    if not IsValid_L(Mesh) then
        return 0
    end

    Mesh.bSkipKinematicUpdateWhenInterpolating = bEnable
    Mesh.bSkipBoundsUpdateWhenInterpolating = bEnable
    if bEnable then
        UKGComponentUtil.SetMeshVisibilityBasedAnimTickOption(Mesh,EVisibilityBasedAnimTickOption.OnlyTickPoseWhenRendered)
    else
        UKGComponentUtil.SetMeshVisibilityBasedAnimTickOption(Mesh,EVisibilityBasedAnimTickOption.AlwaysTickPoseAndRefreshBones)
    end
    
    -- 关闭URO功能， 解决动画引起的部件运动闪烁问题 ； URO的正式投放要走后期的单位lod的变化控制，而不是现在统一无条件开启 @sunya 20241024
    --Mesh.bEnableUpdateRateOptimizations = bEnable

    if Game.WorldManager.EnableCustomMeshBoundOP then
        Mesh.KinematicBonesUpdateType = 1
        Mesh.bComponentUseFixedSkelBounds = bEnable
    end



    if Game.WorldManager.EnableCustomMeshBoundOP and bEnable then
        local MeshAsset
        if Mesh:IsA(import("SkeletalMeshComponent")) then
            MeshAsset = Mesh:GetSkeletalMeshAsset()
        end


        if MeshAsset and MeshAsset.ExtendedBounds and MeshAsset.PositiveBoundsExtension then
            if not import("KismetMathLibrary").EqualEqual_VectorVector(MeshAsset.PositiveBoundsExtension, MeshAsset.ExtendedBounds.BoxExtent, 1e-4) then
                local OriginBound = MeshAsset:GetImportedBounds()
                local NewExtent = FVector()
                NewExtent.X = OriginBound.BoxExtent.X * 0.4 + 150
                NewExtent.Y = OriginBound.BoxExtent.Y * 0.4 + 150
                NewExtent.Z = OriginBound.BoxExtent.Z * 0.4 + 150


                import("LuaHelper").SetMeshPositiveBoundsExtension(MeshAsset, NewExtent)
                import("LuaHelper").SetMeshNegativeBoundsExtension(MeshAsset, NewExtent)
            end
        end
    end
end

function SkeletalMeshCom_C:Execute()

    local AssetOp = self:GetOperateFromID(self.AssetOpID)
    
    local MeshCom = nil
    if self.TargetID then
        MeshCom = Game.ObjectActorManager:GetObjectByID(self.TargetID)

        if MeshCom and self.Data.Tag then
            MeshCom.ComponentTags:AddUnique(self.Data.Tag)
        end
    end

    if MeshCom == nil and self.Data.OwnerActorID then
        local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.Data.OwnerActorID)
        if OwnerActor then
            if self.Data.Tag then
                local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), self.Data.Tag)
                --临时兼容
                if self.Data.Tag == Enum.UECompositeComTag.Mesh then
                    if ActorComs:Length() == 0 and OwnerActor:GetMainMesh() ~= nil then
                        ActorComs:Add(OwnerActor:GetMainMesh())
                    end
                end

                if ActorComs:Length() > 0 then
                    MeshCom = ActorComs:Get(0)
                else
                    MeshCom = URoleCompositeFunc.RegisterActorComponent(OwnerActor, import("SkeletalMeshComponent"))
                    MeshCom.ComponentTags:AddUnique(self.Data.Tag)

                    Game.UECompositeManager:OnMeshComChanged(self.Data.OwnerActorID, MeshCom, Enum.UEActorMeshCBType.MeshComCreate)

                    local ParentCom = OwnerActor:K2_GetRootComponent()
                    if self.Data.AttachTargetTag ~= nil then
                        local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), self.Data.AttachTargetTag)
                        if ActorComs:Length() > 0 then
                            ParentCom = ActorComs:Get(0)
                        end
                    end

                    if ParentCom == nil then
                        ParentCom = OwnerActor:K2_GetRootComponent()
                    end

                    MeshCom:K2_AttachToComponent(ParentCom, self.Data.SocketName, EAttachmentRule.KeepRelative,
                    EAttachmentRule.KeepRelative, EAttachmentRule.KeepRelative, true)

                    if _G.UE_EDITOR then
                        KGActorUtil.AddInstanceComponent(OwnerActor, MeshCom)
                    end
                end
            end

            if MeshCom and self.Data.LeaderPoseComTag ~= nil then
                local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), self.Data.LeaderPoseComTag)
                if ActorComs:Length() > 0 then
                    local LeaderMeshCom = ActorComs:Get(0)
                    if LeaderMeshCom then
                        MeshCom:SetLeaderPoseComponent(LeaderMeshCom, false, false)
                    end
                end
            end
        end
    end

    if MeshCom then
        -- 直接关闭动画更新引起的overlap, 是否要overlap统一走运动处理的流程
        MeshCom.bUpdateOverlapsOnAnimationFinalize = false
        -- 不使用generate overlap
        MeshCom:SetGenerateOverlapEvents(false)
        if (Game.WorkProxyManager ~= nil) then
            local Signs = Game.BSManager.Int32s
            pcall(Game.WorkProxyManager.DestroyOperateStack_P, Game.WorkProxyManager, MeshCom, Signs, false)
        end

        --TODO 后续调整
        local _Tags = MeshCom.ComponentTags:ToTable()
        for _, _Tag in pairs(_Tags) do
            local SI, EI = string.find(_Tag, "_ModifyMaID_")
            if SI then
                local OPIDStr = string.sub(_Tag, EI + 1)
                if OPIDStr then
                    local OPID = tonumber(OPIDStr)
                    if OPID then
                        Game.WorkProxyManager:CancelWorkProxy(OPID)
                    end
                end

                for j = 0 , MeshCom.ComponentTags:Num() - 1 do
                    local tag = MeshCom.ComponentTags:Get(j)
                    if IsStringEquals(tag, _Tag) then
                        MeshCom.ComponentTags:Remove(j)
                        break
                    end
                end 
            end
        end

        if self.Data.LightChannels then
            MeshCom:SetLightingChannels(self.Data.LightChannels [0] or false ,self.Data.LightChannels [1] or false, self.Data.LightChannels [2] or false)
        end

        ImportC7FunctionLibrary.EmptyMeshOverrideMaterials(MeshCom)

        local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.Data.OwnerActorID)

        if AssetOp and AssetOp.Asset then
            --资源类型检查
            if not IsValid_L(AssetOp.Asset) or not AssetOp.Asset.IsA or not AssetOp.Asset:IsA(import("SkeletalMesh")) then
                Log.Warning("[UECompositeManager:SkeletalMeshCom] SkeletalMesh Type Error: ", self.Data.SkeletalMesh)
            else
                if self.Data.Tag == Enum.UECompositeComTag.Mesh then
                    for j = 0 , MeshCom.ComponentTags:Num()-1 do
                        local tag = MeshCom.ComponentTags:Get(j)
                        if IsStringEquals(tag, UECompositeManager.SkeletalChangedTag) then
                            MeshCom.ComponentTags:Remove(j)
                            break
                        end
                    end 

                    local NewSkeleton = AssetOp.Asset:GetSkeleton()

                    local OldSK = MeshCom:GetSkeletalMeshAsset()
                    if OldSK then
                        local OldSkeleton = OldSK:GetSkeleton()
                        if OldSkeleton ~= NewSkeleton then
                            MeshCom.ComponentTags:AddUnique(UECompositeManager.SkeletalChangedTag)
                        end
                    end

                    --Capsule Shadow
                    --根据通用骨架来确定及类型来确定挂载资源
                    if NewSkeleton and self.Data.CapsuleShadow_AssetID then
                        if Game.UECompositeManager.SKEL_3CSKID == Game.ObjectActorManager:GetIDByObject(NewSkeleton) then
                            local _Asset = Game.ObjectActorManager:GetObjectByID(self.Data.CapsuleShadow_AssetID)
                            if _Asset and import("C7FunctionLibrary").SetShadowPhysicsAssetForSkeletalMesh then
                                import("C7FunctionLibrary").SetShadowPhysicsAssetForSkeletalMesh(AssetOp.Asset, _Asset)

                                MeshCom:SetCastCapsuleIndirectShadow(true)
                                MeshCom:SetCapsuleIndirectShadowMinVisibility(0.5)
        
                                if self.Data.LightChannels then
                                    MeshCom:SetLightingChannels(self.Data.LightChannels [0] or false ,self.Data.LightChannels [1] or false, true)
                                end
                            end
                        end
                    end
                end

                MeshCom:SetSkeletalMeshAsset(AssetOp.Asset)

                Game.UECompositeManager:OnMeshComChanged(self.Data.OwnerActorID, MeshCom, Enum.UEActorMeshCBType.MeshChanged)

                -- 过场动画中的主角需要挂上物理，才能在播放动画时刷新动态包围盒，避免被渲染剔除
                --if OwnerActor and OwnerActor:ActorHasTag("CutscenePlayer") then
                --    local OriginSkeletalMeshAsset = MeshCom:GetSkeletalMeshAsset()
                --    if OriginSkeletalMeshAsset then
                --        local PhysicAsset = OriginSkeletalMeshAsset:GetPhysicsAsset()
                --        if PhysicAsset then
                --            import("C7FunctionLibrary").SetPhysicsAssetForSkeletalMesh(AssetOp.Asset, PhysicAsset)
                --        end
                --    end
                --end
            end
        end
        

        if OwnerActor and self.Data.Tag and self.DecorationComponentsIDs then

            local _DecorationTag = self.Data.Tag .. UECompositeManager.GFurTag_Suffix
            local DecorationComponents = OwnerActor:GetComponentsByTag(import("MeshComponent"), _DecorationTag)
            if DecorationComponents:Length() > 0 then
                for i = 0, DecorationComponents:Length() - 1, 1 do
                    local DecorationComponent = DecorationComponents:Get(i)
                    if DecorationComponent then
                        local OwnerActorID = Game.ObjectActorManager:GetIDByObject(OwnerActor)
                        if OwnerActorID then
                            Game.UECompositeManager:OnMeshComChanged(OwnerActorID, DecorationComponent, Enum.UEActorMeshCBType.MeshComDestroy)
                        end
                        DecorationComponent:K2_DestroyComponent(DecorationComponent)
                    end
                end
            end

            for k, DecorationComponentID in pairs(self.DecorationComponentsIDs) do
                local DecorationComponentOp = self:GetOperateFromID(DecorationComponentID)

                if DecorationComponentOp and IsValid_L(DecorationComponentOp.Asset) then
                    local DecorationComponent = URoleCompositeFunc.RegisterActorComponent(OwnerActor, DecorationComponentOp.Asset)
                    if _G.UE_EDITOR then
                        KGActorUtil.AddInstanceComponent(OwnerActor, DecorationComponent)
                    end
                    DecorationComponent.ComponentTags:AddUnique(_DecorationTag)
                    DecorationComponent:K2_AttachToComponent(MeshCom, "", EAttachmentRule.SnapToTarget,
                        EAttachmentRule.SnapToTarget, EAttachmentRule.SnapToTarget, true)
    
                    if self.Data.bVisibility ~= nil then
                        DecorationComponent:SetHiddenInGame(not self.Data.bVisibility, false)
                    end
                end
            end
        end


        if self.Data.bActiveTick ~= nil then
            MeshCom:SetComponentTickEnabled(true)
        end
        
        if self.Data.bReceivesDecals ~= nil then
            MeshCom:SetReceivesDecals(self.Data.bReceivesDecals)
        end

        if self.Data.bRenderCustomDepthPass ~= nil then
            MeshCom:SetRenderCustomDepth(self.Data.bRenderCustomDepthPass)
        end

        if self.Data.bActive ~= nil then
            MeshCom:SetActive(self.Data.bActive, false)
        end

        if self.Data.bVisibility ~= nil then
            --MeshCom:SetVisibility(self.Data.bVisibility, false)
            MeshCom:SetHiddenInGame(not self.Data.bVisibility, false)
        end

        if self.Data.bCastInsetShadow ~= nil then
            MeshCom:SetCastInsetShadow(self.Data.bCastInsetShadow)
        end

        if self.Data.bSingleSampleShadowFromStationaryLights ~= nil then
            MeshCom:SetSingleSampleShadowFromStationaryLights(self.Data.bSingleSampleShadowFromStationaryLights)
        end

        if self.Data.bEnableMeshOptimization ~= nil  then
            EnableSKMeshOptimization(MeshCom, self.Data.bEnableMeshOptimization)
        end

        if self.Data.bUseAttachParentBound ~= nil then
            MeshCom.bUseAttachParentBound = self.Data.bUseAttachParentBound
        end

        if self.Data.bOverrideLighting then
            MeshCom:SetOverwriteLighting(self.Data.bOverrideLighting)
        end

		if self.Data.ForcedLOD then
			MeshCom:SetForcedLOD(self.Data.ForcedLOD)
		end

		if self.PhysicsAssetLoadID then
			local LoadOp = self:GetOperateFromID(self.PhysicsAssetLoadID)
			if LoadOp and (LoadOp.Asset) then
				MeshCom:SetPhysicsAsset(LoadOp.Asset)
			end
		end
		
        if self.MaterialOverlayLoadID then
            local LoadOp = self:GetOperateFromID(self.MaterialOverlayLoadID)
            if LoadOp and (LoadOp.Asset) then
                MeshCom:SetOverlayMaterial(LoadOp.Asset)
            end
        end

		-- override materials
		for slotName, materialLoadID in pairs(self.loadedOverrideMaterials) do
			local LoadOp = self:GetOperateFromID(materialLoadID)
			local slotIndex = MeshCom:GetMaterialIndex(slotName)
			if LoadOp and LoadOp.Asset and slotIndex >= 0 then
				MeshCom:SetMaterial(slotIndex, LoadOp.Asset)
			end
		end

		-- material follow, 对于丝袜黑丝白丝之类的材质, 脚和鞋子需要跟随下半身的材质. 
		if OwnerActor then
			local UseLowerBodySkinTag = "UseLowerBodySkin"
			if OwnerActor:ActorHasTag(UseLowerBodySkinTag) then
				-- 移除, 如果有旧的Tag, 需要移除.
				if MeshCom:ComponentHasTag(UseLowerBodySkinTag) then
					SkeletalMeshCom_C.RemoveTag(MeshCom.ComponentTags, UseLowerBodySkinTag)
					SkeletalMeshCom_C.RemoveTag(OwnerActor.Tags, UseLowerBodySkinTag)
					local data = G_RoleCompositeMgr.AvatarProfileLib.MaterialFollowers[UseLowerBodySkinTag]
					for i = 1, #data.FollowerParts do
						local followerMeshCom = KGUECompositeOperateLibrary.GetSkeletalMeshComByTag(OwnerActor, data.FollowerParts[i])
						if followerMeshCom then
							local slotIndex = MeshCom:GetMaterialIndex(data.SlotNames[i])
							if slotIndex >= 0 then
								local objID = Game.ObjectActorManager:GetIDByObject(followerMeshCom)
								Game.MaterialManager:ChangeDefaultMaterial(objID, slotIndex, false, false, nil)
							end
						end
					end
				else
					-- 跟随, 如果Actor上有Tag, 判断是否需要跟随设置材质.
					local data = G_RoleCompositeMgr.AvatarProfileLib.MaterialFollowers[UseLowerBodySkinTag]
					local leaderMeshCom = nil
					for i = 1, #data.FollowerParts do
						if data.FollowerParts[i] == self.Data.Tag then
							if not leaderMeshCom then
								leaderMeshCom = KGUECompositeOperateLibrary.GetSkeletalMeshComByTag(OwnerActor, data.LeaderPart)
								if not leaderMeshCom then
									break
								end
							end
							local leaderSlotIndex = leaderMeshCom:GetMaterialIndex(data.SlotNames[i])
							if leaderSlotIndex == -1 then
								break
							end
							local slotIndex = MeshCom:GetMaterialIndex(data.SlotNames[i])
							if slotIndex ~= -1 then
								local objID = Game.ObjectActorManager:GetIDByObject(MeshCom)
								local leaderObjID = Game.ObjectActorManager:GetIDByObject(leaderMeshCom)
								local materialInstance = Game.MaterialManager:GetDefaultMaterial(leaderObjID, leaderSlotIndex, false, false)
								materialInstance = materialInstance or leaderMeshCom:GetMaterial(leaderSlotIndex)
								Game.MaterialManager:ChangeDefaultMaterial(objID, slotIndex, false, false, materialInstance)
							end
						end
					end
				end
			end
			-- 添加, 当前这个Mesh需要其他Part的材质跟随. 目前只有一种Tag, 使用量很少.
			if self.Data.MaterialFollowerTags then
				MeshCom.ComponentTags:AddUnique(UseLowerBodySkinTag)
				OwnerActor.Tags:AddUnique(UseLowerBodySkinTag)
				local data = G_RoleCompositeMgr.AvatarProfileLib.MaterialFollowers[UseLowerBodySkinTag]
				for i = 1, #data.FollowerParts do
					local followerMeshCom = KGUECompositeOperateLibrary.GetSkeletalMeshComByTag(OwnerActor, data.FollowerParts[i])
					if followerMeshCom then
						local slotIndex = MeshCom:GetMaterialIndex(data.SlotNames[i])
						local followerSlotIndex = followerMeshCom:GetMaterialIndex(data.SlotNames[i])
						if slotIndex ~= -1 and followerSlotIndex ~= -1 then
							local objID = Game.ObjectActorManager:GetIDByObject(followerMeshCom)
							local leaderObjID = Game.ObjectActorManager:GetIDByObject(MeshCom)
							local materialInstance = Game.MaterialManager:GetDefaultMaterial(leaderObjID, slotIndex, false, false)
							Game.MaterialManager:ChangeDefaultMaterial(objID, followerSlotIndex, false, false, materialInstance)
						end
					end
				end
			end
		end

        if self.Data.BodyMeshSocketName then
            local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.Data.OwnerActorID)
            if OwnerActor then
                local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), Enum.UECompositeComTag.Mesh)

                local ParentCom = nil

                if ActorComs:Length() == 0 and OwnerActor:GetMainMesh() ~= nil then
                    ParentCom = OwnerActor:GetMainMesh()
                else
                    ParentCom = ActorComs:Get(0)
                end
                
                if ParentCom then
                    MeshCom:K2_AttachToComponent(ParentCom, self.Data.BodyMeshSocketName, EAttachmentRule.KeepRelative,
                    EAttachmentRule.KeepRelative, EAttachmentRule.KeepRelative, true)
                end
            end
        end

        if self.Data.Offset then
            --主Mesh默认偏移
            if self.Data.Tag == Enum.UECompositeComTag.Mesh and self.Data.bEnableMoveFix then
                MeshCom:K2_SetRelativeTransform(self.Data.Offset + SkeletalMeshCom_C.BodyMeshOffset, false, nil, false)
            else
                MeshCom:K2_SetRelativeTransform(self.Data.Offset, false, nil, false)
            end
        end
    end
end

function SkeletalMeshCom_C:Notify()

end

function SkeletalMeshCom_C.RemoveTag(Tags, ToRemovedTag)
	for j = 0, Tags:Num() - 1 do
		if Tags:Get(j) == ToRemovedTag then
			Tags:Remove(j)
			return
		end
	end
end

StaticMeshCom_C = DefineClass("StaticMeshCom_C", CompositeOperateBase)
function StaticMeshCom_C:ctor()
    self.OperateType = Enum.UECompositeType.StaticMeshCom
end

function StaticMeshCom_C:Reset()
    self.super.Reset(self)

    self.Data.StaticMesh = nil
    self.Data.Offset = nil

    self.Data.OwnerActorID = nil
    self.Data.Tag = nil --如果TargetID没指定, 通过Tag来找, 默认没有Tag的新创建,挂到Root
	self.Data.AttachTargetTag = nil
	self.Data.SocketName = nil
	
    self.Data.bReceivesDecals = nil
	self.Data.bRenderCustomDepthPass = nil--是否开启自定义深度
    self.Data.CollisionProfileName = nil
	self.Data.bActive = nil --是否激活
	self.Data.bVisibility = nil--初始是否显示

	self.Data.bUseAttachParentBoundnit = nil --使用父类Bound（优化用，一般false)

	self.Data.bCastInsetShadow = nil--阴影
	self.Data.bSingleSampleShadowFromStationaryLights = nil--物体中心位置去算一个固态阴影的遮蔽值

	self.MaterialOverlayLoadID = nil
	
    self.AssetOpID = 0
end

function StaticMeshCom_C:Init()
    self.super.Init(self)

	if self.Data.SocketName == nil then
		self.Data.SocketName = ""
	end
	
    if self.Data.StaticMesh then
        self.AssetOpID = self:AddLoadAssetDependency(self.Data.StaticMesh)
    end

	if self.Data.MaterialOverlay and self.Data.MaterialOverlay ~= "" then
		self.MaterialOverlayLoadID = self:AddLoadAssetDependency(self.Data.MaterialOverlay)
	end
end

function StaticMeshCom_C:Execute()

    local AssetOp = self:GetOperateFromID(self.AssetOpID)

    local MeshCom = Game.ObjectActorManager:GetObjectByID(self.TargetID)

    if MeshCom and self.Data.Tag then
        MeshCom.ComponentTags:AddUnique(self.Data.Tag)
    end

    if MeshCom == nil and self.Data.OwnerActorID then
        local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.Data.OwnerActorID)
        if OwnerActor then
            if self.Data.Tag then
                local ActorComs = OwnerActor:GetComponentsByTag(import("StaticMeshComponent"), self.Data.Tag)
                if ActorComs:Length() > 0 then
                    MeshCom = ActorComs:Get(0)
                else
                    MeshCom = URoleCompositeFunc.RegisterActorComponent(OwnerActor, import("StaticMeshComponent"))
                    MeshCom.ComponentTags:AddUnique(self.Data.Tag)

					local ParentCom = OwnerActor:K2_GetRootComponent()
					if self.Data.AttachTargetTag ~= nil then
						ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), self.Data.AttachTargetTag)
						if ActorComs:Length() > 0 then
							ParentCom = ActorComs:Get(0)
						end
					end

					if ParentCom == nil then
						ParentCom = OwnerActor:K2_GetRootComponent()
					end

					MeshCom:K2_AttachToComponent(ParentCom, self.Data.SocketName, EAttachmentRule.KeepRelative,
						EAttachmentRule.KeepRelative, EAttachmentRule.KeepRelative, true)

                    if _G.UE_EDITOR then
                        KGActorUtil.AddInstanceComponent(OwnerActor, MeshCom)
                    end
                end
            end
        end
    end
    if MeshCom then
		ImportC7FunctionLibrary.EmptyMeshOverrideMaterials(MeshCom)
		
        if AssetOp and AssetOp.Asset then
            if not IsValid_L(AssetOp.Asset) or not AssetOp.Asset:IsA(import("StaticMesh")) then
                Log.Warning("[UECompositeManager:StaticMeshCom] StaticMesh Type Error: ", self.Data.StaticMesh)
            else
                MeshCom:SetStaticMesh(AssetOp.Asset)
            end
        end
        
        if self.Data.bReceivesDecals ~= nil  then
            MeshCom:SetReceivesDecals(self.Data.bReceivesDecals)
        end
		
		if self.Data.bRenderCustomDepthPass ~= nil then
			MeshCom:SetRenderCustomDepth(self.Data.bRenderCustomDepthPass)
		end

		if self.Data.bActive ~= nil then
			MeshCom:SetActive(self.Data.bActive, false)
		end

		if self.Data.bVisibility ~= nil then
			MeshCom:SetHiddenInGame(not self.Data.bVisibility, false)
		end

		if self.Data.bUseAttachParentBound ~= nil then
			MeshCom.bUseAttachParentBound = self.Data.bUseAttachParentBound
		end

		if self.Data.bCastInsetShadow ~= nil then
			MeshCom:SetCastInsetShadow(self.Data.bCastInsetShadow)
		end

		if self.Data.bSingleSampleShadowFromStationaryLights ~= nil then
			MeshCom:SetSingleSampleShadowFromStationaryLights(self.Data.bSingleSampleShadowFromStationaryLights)
		end

		if self.Data.LightChannels then
            MeshCom:SetLightingChannels(self.Data.LightChannels [0] or false ,self.Data.LightChannels [1] or false, self.Data.LightChannels [2] or false)
        end

        if self.Data.bOverrideLighting then
            MeshCom:SetOverwriteLighting(self.Data.bOverrideLighting)
        end

		if self.MaterialOverlayLoadID then
			local LoadOp = self:GetOperateFromID(self.MaterialOverlayLoadID)
			if LoadOp and (LoadOp.Asset) then
				MeshCom:SetOverlayMaterial(LoadOp.Asset)
			end
		end
		
        MeshCom:K2_SetRelativeTransform(self.Data.Offset, false, nil, false)
    end
end

function StaticMeshCom_C:Notify()

end


local __Hit_Result = import("HitResult")() -- luacheck: ignore


HitBox_C = DefineClass("HitBox_C", CompositeOperateBase)
function HitBox_C:ctor()
    self.OperateType = Enum.UECompositeType.HitBox
end

function HitBox_C:Reset()
    self.super.Reset(self)

    self.Data.BoxExtent = nil
    self.Data.Offset = nil
    self.Data.ParentSocket = nil
end

function HitBox_C:Execute()
	if not self.Data.bUseHitBox then
		return
	end

    local meshCom = Game.ObjectActorManager:GetObjectByID(self.TargetID)
    if meshCom then
        local hitBox = URoleCompositeFunc.RegisterActorComponent(meshCom:GetOwner(), UBoxComponent)
		if hitBox then
			hitBox:K2_AttachToComponent(meshCom, self.Data.ParentSocket, EAttachmentRule.SnapToTarget, EAttachmentRule.SnapToTarget, EAttachmentRule.SnapToTarget, true)
			hitBox:K2_SetRelativeTransform(self.Data.Offset, false, __Hit_Result, false)
			hitBox:SetBoxExtent(self.Data.BoxExtent, true)
		end
    end
end

Capsule_C = DefineClass("Capsule_C", CompositeOperateBase)
function Capsule_C:ctor()
    self.OperateType = Enum.UECompositeType.Capsule
end

function Capsule_C:Reset()
    self.super.Reset(self)

    self.Data.CapsuleHalfHeight = nil
    self.Data.CapsuleRadius = nil
    self.Data.Collision = nil
end

function Capsule_C:Execute()

    local CapsuleCom = Game.ObjectActorManager:GetObjectByID(self.TargetID)
    if CapsuleCom then
        CapsuleCom:SetCapsuleSize(self.Data.CapsuleRadius, self.Data.CapsuleHalfHeight, true)
    end
end

local Import_MaterialInstanceDynamic = import("MaterialInstanceDynamic")

--之后再处理这个接口
local FindAddDynamicMaterial = function(InActor, Mesh, MaterialSlotName)

    if not IsValid_L(InActor) or not IsValid_L(Mesh) then
        return nil
    end

    --print("FindAddDynamicMaterial", MaterialSlotName)

    local ActorId = Game.ObjectActorManager:GetIDByObject(InActor)
    local MeshCompId = Game.ObjectActorManager:GetIDByObject(Mesh)

    --Material
    local SlotIndex = Mesh:GetMaterialIndex(MaterialSlotName)
    
    --print("FindAddDynamicMaterial SlotIndex", tostring(SlotIndex))
    --local Material = Mesh:GetMaterial(SlotIndex)
    local Material = nil
    if SlotIndex >= 0 then
        Material = Game.MaterialManager:GetMaterialInstance(ActorId, MeshCompId, SlotIndex, false, false)
    end

    -- if Material and not Material:IsA(Import_MaterialInstanceDynamic) then

    --     Material = Mesh:CreateDynamicMaterialInstance(SlotIndex, Material, "")
    --     Mesh:SetMaterial(SlotIndex, Material)
    -- end

    --SeperateOverlayMaterial, 主要是希望妆容应用到头发的 SeperateOverlayMaterial 上
    local SeperateOverlayMaterial = nil
    local SlotIndexOverlay = Mesh:GetSeperateOverlayMaterialIndex(MaterialSlotName)
    if SlotIndexOverlay >= 0 then
        SeperateOverlayMaterial = Game.MaterialManager:GetMaterialInstance(ActorId, MeshCompId, SlotIndexOverlay, false, true)
    end
    -- local SeperateOverlayMaterial = Mesh:GetSeperateOverlayMaterial(SlotIndexOverlay)

    -- if SeperateOverlayMaterial and not SeperateOverlayMaterial:IsA(Import_MaterialInstanceDynamic) then
    --     SeperateOverlayMaterial = Mesh:CreateDynamicSeperateOverlayMaterialInstance(SlotIndexOverlay, SeperateOverlayMaterial, "")
    --     Mesh:SetSeperateOverlayMaterial(SlotIndexOverlay, SeperateOverlayMaterial)
    -- end

    return Material, SeperateOverlayMaterial
end

Material_C = DefineClass("Material_C", CompositeOperateBase)
function Material_C:ctor()
    self.OperateType = Enum.UECompositeType.Material
end

function Material_C:Reset()
    self.super.Reset(self)

    self.Data.Tag = nil
    --self.Data.MaterialSlotName = nil

    -- self.Data.NumberValues = nil
    -- self.Data.VectorParameters = nil
    self.Data.TextureParameter = nil --{TexturePath}

    self.Data.MakeupCaptureMaterials = nil --RT
    self.Data.MakeupProfileName = nil --预制名
    self.Data.MakeupDataLibRef = nil --妆容数据库
    self.Data.MakeupProfileLibRef = nil --预制库
    self.Data.MakeupDataKeys = nil --妆容数据库Keys

    self.Data.ExtendMakeupData = nil --扩展数据
    
    self.Data.InitModelMaterialID = nil -- 出生材质

    self.TextureAssetOpMap = nil
    self.TextureAssetMap = nil
    
    self.InitMaterialAssetOpMap = nil
    self.InitMaterialAssetMap = nil
end

function Material_C:Init()
    self.super.Init(self)

    self.TextureAssetMap = {}
    if self.Data.TextureParameter then
        self.TextureAssetOpMap = {}
        for _Name, AssetPath in pairs(self.Data.TextureParameter) do
            local AssetOpID = self:AddLoadAssetDependency(AssetPath)

            self.TextureAssetOpMap[AssetOpID] = AssetPath
        end
    end

    if self.Data.InitModelMaterialID then
        self.InitMaterialAssetMap = {}
        local MaterialData = Game.TableData.GetModelMaterialDataRow(self.Data.InitModelMaterialID)
        if MaterialData then
            self.InitMaterialAssetOpMap = {}
            if StringValid(MaterialData.MainMaterial) then
                local AssetOpID = self:AddLoadAssetDependency(MaterialData.MainMaterial)
                self.InitMaterialAssetOpMap[AssetOpID] = "MainMaterial"
            end
            if StringValid(MaterialData.EyeLashMaterial) then
                local AssetOpID = self:AddLoadAssetDependency(MaterialData.EyeLashMaterial)
                self.InitMaterialAssetOpMap[AssetOpID] = "EyeLashMaterial"
            end
        end
    end
end

function Material_C:OnAssetLoaded(ID, Asset)
    if self.InitMaterialAssetOpMap then
        if self.InitMaterialAssetOpMap[ID] then
            local Part = self.InitMaterialAssetOpMap[ID]
            self.InitMaterialAssetMap[Part] = Asset
        end
        return
    end
    
    local AssetPath = self.TextureAssetOpMap[ID]
    if AssetPath == nil then
        return
    end

    if self.TextureAssetMap == nil then
        self.TextureAssetMap = {}
    end

    self.TextureAssetMap[AssetPath] = Asset
end

--- 绑定其他部位的材质槽位的同名材质变量,主要用于保持脸和身体的肤色一致. 数量很少
function Material_C:MakeupDataModifyOtherPart(InActor, Keys, LibRef)
    local Profiles = self.Data.MakeupProfileLibRef
    for _, Key in pairs(Keys) do
        if Profiles[Key] and Profiles[Key].OtherPartAndSlots then
            local Value = LibRef[Key]
            if not Value then
                -- TODO: 临时修复，妆容属性可能来自 profile 中有 OtherPartAndSlots 字段的，他可能不在当前人物部件的妆容属性里
                Log.Warning("Not Exist Makeup Key in Current LibRef: ", Key)
                goto continue
            end
            local Profile = Profiles[Key]
            for _, PartAndSlot in ipairs(Profile.OtherPartAndSlots) do
                local Components = InActor:GetComponentsByTag(import("SkeletalMeshComponent"), Enum.EAvatarBodyPartTypeName[PartAndSlot.BodyPartType])
                if Components:Length() > 0 then
                    local Material, SeperateOverlayMaterial = FindAddDynamicMaterial(InActor, Components:Get(0), PartAndSlot.SlotName)
                    --Material
                    if Material then
                        local DataType = Profile.Type
                        if DataType == Enum.EMakeupPropertyType.Float then
                            local realValue = (Profile.MaxValue - Profile.MinValue) * Value + Profile.MinValue
                            Material:SetScalarParameterValue(Profile.MaterialPropertyName, realValue)
                        elseif DataType == Enum.EMakeupPropertyType.Color then
                            Material:SetVectorParameterValue(Profile.MaterialPropertyName, Value)
                        else
                            Log.Warning("MakeupDataModifyOtherPart Not Supported:", Key)
                        end
                    end
                    --SeperateOverlayMaterial
                    if SeperateOverlayMaterial then
                        local DataType = Profile.Type
                        if DataType == Enum.EMakeupPropertyType.Float then
                            local realValue = (Profile.MaxValue - Profile.MinValue) * Value + Profile.MinValue
                            SeperateOverlayMaterial:SetScalarParameterValue(Profile.MaterialPropertyName, realValue)
                        elseif DataType == Enum.EMakeupPropertyType.Color then
                            SeperateOverlayMaterial:SetVectorParameterValue(Profile.MaterialPropertyName, Value)
                        else
                            Log.Warning("MakeupDataModifyOtherPart Not Supported:", Key)
                        end
                    end
                end
            end
        end

        ::continue::
    end
end

function Material_C:MakeupDataModify(MeshCom, Key, Makeup_Value)
	--[[
    if self.Data.MakeupProfileLibRef == nil or not IsValid_L(MeshCom) then
        return
    end

    local MakeupProfileData = self.Data.MakeupProfileLibRef[Key]
    if MakeupProfileData then
        local Material, SeperateOverlayMaterial = FindAddDynamicMaterial(MeshCom:GetOwner(), MeshCom, MakeupProfileData.SlotName)
        --Material
        if Material then
            local DataType = MakeupProfileData.Type
            if DataType == Enum.EMakeupPropertyType.Float then
                local realValue = (MakeupProfileData.MaxValue - MakeupProfileData.MinValue) * Makeup_Value + MakeupProfileData.MinValue
                Material:SetScalarParameterValue(MakeupProfileData.MaterialPropertyName, realValue)
            elseif DataType == Enum.EMakeupPropertyType.Curve then
                local realValue = math.round(Makeup_Value)
                Material:SetScalarParameterValue(MakeupProfileData.MaterialPropertyName, realValue)
            elseif DataType == Enum.EMakeupPropertyType.Color then
                Material:SetVectorParameterValue(MakeupProfileData.MaterialPropertyName, Makeup_Value)
            elseif DataType == Enum.EMakeupPropertyType.Texture then
                local _Texture = self.TextureAssetMap[Makeup_Value]
                if _Texture and IsValid_L(_Texture) and _Texture.IsA and _Texture:IsA(import("Texture2D")) then
                    Material:SetTextureParameterValue(MakeupProfileData.MaterialPropertyName, _Texture)
                end
            end
        end
        --SeperateOverlayMaterial
        if SeperateOverlayMaterial then
            local DataType = MakeupProfileData.Type
            if DataType == Enum.EMakeupPropertyType.Float then
                local realValue = (MakeupProfileData.MaxValue - MakeupProfileData.MinValue) * Makeup_Value + MakeupProfileData.MinValue
                SeperateOverlayMaterial:SetScalarParameterValue(MakeupProfileData.MaterialPropertyName, realValue)
            elseif DataType == Enum.EMakeupPropertyType.Curve then
                local realValue = math.round(Makeup_Value)
                SeperateOverlayMaterial:SetScalarParameterValue(MakeupProfileData.MaterialPropertyName, realValue)
            elseif DataType == Enum.EMakeupPropertyType.Color then
                SeperateOverlayMaterial:SetVectorParameterValue(MakeupProfileData.MaterialPropertyName, Makeup_Value)
            elseif DataType == Enum.EMakeupPropertyType.Texture then
                local _Texture = self.TextureAssetMap[Makeup_Value]
                if _Texture and _Texture.IsA and IsValid_L(_Texture) and _Texture:IsA(import("Texture2D")) then
                    SeperateOverlayMaterial:SetTextureParameterValue(MakeupProfileData.MaterialPropertyName, _Texture)
                end
            end
        end
    end
    ]]--
end

function Material_C:ModifyInitModelMaterial(MeshComp)
	--[[
    local _Actor = MeshComp:GetOwner()
    if not IsValid_L(_Actor) then
        return
    end
    local ActorId = Game.ObjectActorManager:GetIDByObject(_Actor)
    local MeshCompId = Game.ObjectActorManager:GetIDByObject(MeshComp)

    if self.InitMaterialAssetMap.MainMaterial then
        for SlotIndexOverlay=0, MeshComp:GetNumSeperateOverlayMaterials()-1 do
            Game.MaterialManager:ChangeDefaultMaterial(MeshCompId, SlotIndexOverlay, false, true, self.InitMaterialAssetMap.MainMaterial)
        end
        for Index=0, MeshComp:GetNumMaterials()-1 do
			
            Game.MaterialManager:ChangeDefaultMaterial(MeshCompId, Index, false, false, self.InitMaterialAssetMap.MainMaterial)
        end
    end
    if self.InitMaterialAssetMap.EyeLashMaterial then
        local MaterialIdxID = MeshComp:GetMaterialIndex(UECompositeManager.EyeLashSlotName)
        if MaterialIdxID>0 then
            Game.MaterialManager:ChangeDefaultMaterial(MeshCompId, MaterialIdxID, false, false, self.InitMaterialAssetMap.EyeLashMaterial)

            --MeshComp:SetMaterial(MaterialIdxID, self.InitMaterialAssetMap.EyeLashMaterial)
        end
    end]]--
end

function Material_C:Execute()
    local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.TargetID)
    if OwnerActor then
        local MeshCom = nil
        local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), self.Data.Tag)
		
		if ActorComs:Length() <= 0 then
			ActorComs = OwnerActor:GetComponentsByTag(import("StaticMeshComponent"), self.Data.Tag)
		end
		
        if ActorComs:Length() > 0 then
            MeshCom = ActorComs:Get(0)
            if MeshCom then
                if self.Data.MakeupCaptureMaterials and self.Data.MakeupProfileName then
                    local FaceControlComponent = OwnerActor:GetComponentByClass(import("FaceControlComponent"))
                    if FaceControlComponent then
                        local MakeupCaptureMaterialsNum = -1
                        local _MaterialPaths = slua.Array(EPropertyClass.Str)
                        for _, v in ipairs(self.Data.MakeupCaptureMaterials) do
                            _MaterialPaths:Add(v);
                            MakeupCaptureMaterialsNum = MakeupCaptureMaterialsNum + 1
                        end

                        FaceControlComponent:InitHeadMakeupRuntimeMaterial(self.Data.MakeupProfileName, _MaterialPaths, MeshCom)

                        if self.Data.MakeupDataKeys and self.Data.MakeupDataLibRef and MakeupCaptureMaterialsNum > 0 then
                            for _, _Key in pairs(self.Data.MakeupDataKeys) do
                                local Makeup_Value = self.Data.MakeupDataLibRef[_Key]
                                local MakeupProfileData = self.Data.MakeupProfileLibRef[_Key]
                                if Makeup_Value and MakeupProfileData and MakeupProfileData.CaptureMaterialIndex > 0 then
                                    for i = 0, MakeupCaptureMaterialsNum do
                                        if  MakeupProfileData.CaptureMaterialIndex & (1 << i) > 0 then
                                            local DataType = MakeupProfileData.Type
                                            if DataType == Enum.EMakeupPropertyType.Float then
                                                local realValue = (MakeupProfileData.MaxValue - MakeupProfileData.MinValue) * Makeup_Value + MakeupProfileData.MinValue
                                                --FaceControlComponent:SetScalarParameterValue(i, MakeupProfileData.MaterialPropertyName, realValue)
                                            elseif DataType == Enum.EMakeupPropertyType.Curve then
                                                local realValue = math.round(Makeup_Value)
                                                --FaceControlComponent:SetScalarParameterValue(i, MakeupProfileData.MaterialPropertyName, realValue)
                                            elseif DataType == Enum.EMakeupPropertyType.Color then
                                                --FaceControlComponent:SetVectorParameterValue(i, MakeupProfileData.MaterialPropertyName, Makeup_Value)
                                            elseif DataType == Enum.EMakeupPropertyType.Texture then
                                                local _Texture = self.TextureAssetMap[Makeup_Value]
                                                if _Texture and IsValid_L(_Texture) and _Texture.IsA and _Texture:IsA(import("Texture2D")) then
                                                    FaceControlComponent:SetTextureParameterValue(i, MakeupProfileData.MaterialPropertyName, _Texture)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        FaceControlComponent:ApplyHeadMakeupData()
                    else
                        Log.Warning("FaceControlComponent Missing in Actor Bp", OwnerActor)
                    end
                end
                --[[
                if self.Data.MakeupDataLibRef then
                    if self.Data.MakeupDataKeys then
                        for _, _Key in pairs(self.Data.MakeupDataKeys) do
                            local Makeup_Value = self.Data.MakeupDataLibRef[_Key]
                            if Makeup_Value then
                                self:MakeupDataModify(MeshCom, _Key, Makeup_Value)
                            else
                                -- TODO: 临时修复，妆容属性可能来自 profile 中有 OtherPartAndSlots 字段的，他可能不在当前人物部件的妆容属性里
                                Log.Warning("Not Exist Makeup Key in Current DataLib: ", _Key)
                            end
                        end
                        self:MakeupDataModifyOtherPart(OwnerActor, self.Data.MakeupDataKeys, self.Data.MakeupDataLibRef)
                    end
                end]]--
			--[[
                if self.Data.ExtendMakeupData then
                    for _Key, Makeup_Value in pairs(self.Data.ExtendMakeupData) do
                        self:MakeupDataModify(MeshCom, _Key, Makeup_Value)
                    end
                end

                if self.Data.InitModelMaterialID then
                    self:ModifyInitModelMaterial(MeshCom)
                end]]--
            end
        end
    end
end

Anim_C = DefineClass("Anim_C", CompositeOperateBase)
function Anim_C:ctor()
    self.OperateType = Enum.UECompositeType.Anim
end

function Anim_C:Reset()
    self.super.Reset(self)

    self.Data.OwnerActorID = nil
    self.Data.Tag = nil --未指定TargetID下, 通过Tag查找

    self.Data.AnimLibID = nil

    self.Data.AnimClass = nil
    self.Data.AnimLayers = nil
    self.Data.AnimAssetOverride = nil

    self.AnimClass = nil
    self.AnimClassOpID = nil

    self.AnimLayers = nil
    self.AnimLayerOpIDs = nil
end

function Anim_C:Init()
    self.super.Init(self)
    
    if StringValid(self.Data.AnimClass) then
        self.AnimClassOpID = self:AddLoadAssetDependency(self.Data.AnimClass)
    end

    if self.Data.AnimLayers then
        self.AnimLayerOpIDs = {}
        for _, AssetPath in pairs(self.Data.AnimLayers) do
            if StringValid(AssetPath) then
                local AssetOpID = self:AddLoadAssetDependency(AssetPath)

                self.AnimLayerOpIDs[AssetOpID] = AssetPath
            end
        end
    end
end

function Anim_C:OnAssetLoaded(ID, Asset)
    if self.AnimClassOpID == ID then
        self.AnimClass = Asset
    else
        if self.AnimLayers == nil then
            self.AnimLayers = {}
        end

        local _Path = self.AnimLayerOpIDs[ID]
        if _Path then
            self.AnimLayers[_Path] = Asset
        end
    end
end

function Anim_C:Execute()

    local MeshCom = Game.ObjectActorManager:GetObjectByID(self.TargetID)

    if MeshCom == nil and self.Data.OwnerActorID and self.Data.Tag then
        local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.Data.OwnerActorID)
        if OwnerActor then
            local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), self.Data.Tag)
            if ActorComs:Length() > 0 then
                MeshCom = ActorComs:Get(0)
            end

            --TEMP 兼容现有逻辑
            OwnerActor.Tags:AddUnique("MeshReady")
        end
    end

    if MeshCom then
        if self.AnimClass and slua.isValid(self.AnimClass) then

            if MeshCom:GetAnimClass() ~= self.AnimClass then
                MeshCom:SetAnimationMode(EAnimationMode.AnimationBlueprint, false)
                if import("KismetSystemLibrary").IsValidClass(self.AnimClass) then
                    MeshCom:SetAnimClass(self.AnimClass)

                    import("RoleCompositeMgr").RefreshBoneTransforms(MeshCom, true)

                    MeshCom.ComponentTags:AddUnique(UECompositeManager.AnimClassChangedTag)
                else
                    Log.Warning("[UECompositeManager:Anim] AnimClass Error: ", self.Data.AnimClass)
                end
            else
                if self.Data.Tag == Enum.UECompositeComTag.Mesh then
                    for j = 0 , MeshCom.ComponentTags:Num()-1 do
                        local tag = MeshCom.ComponentTags:Get(j)
                        if IsStringEquals(tag, UECompositeManager.AnimClassChangedTag) then
                            MeshCom.ComponentTags:Remove(j)
                            break
                        end
                    end 
                end
            end
        end

        -- if self.AnimLayers then
        --     for _, _Layer in pairs(self.AnimLayers) do
        --         if _Layer and slua.isValid(_Layer) then
        --             MeshCom:UnlinkAnimClassLayers(_Layer)
        --             MeshCom:LinkAnimClassLayers(_Layer)
        --         end
        --     end
        -- end

    end
end



AnimLoad_C = DefineClass("AnimLoad_C", CompositeOperateBase)
function AnimLoad_C:ctor()
    self.OperateType = Enum.UECompositeType.AnimLoad
end

function AnimLoad_C:Reset()
    self.super.Reset(self)

    self.Data.OwnerActorID = nil
    self.Data.AnimLibID = nil
	self.Data.UID = nil

    self.AnimAssetLoadMap = {}
    self.AnimOverrideLoadMap = {}

    self.AnimAssetMap = self.AnimAssetMap or  slua.Map(EPropertyClass.Name, EPropertyClass.Object,nil,import("AnimSequenceBase"))
    self.AnimOverrideMap = self.AnimOverrideMap or  slua.Map(EPropertyClass.Name, EPropertyClass.Object,nil,import("AnimSequenceBase"))

    self.AnimAssetMap:Clear()
    self.AnimOverrideMap:Clear()

    self.AnimInsID = nil
end

function AnimLoad_C:Init()
    local AnimConfigID = self.Data.AnimLibID
    local PreLoadIDs, PreLoadAssets = AnimLibHelper.GetAnimPreLoadDataForLocomotion(AnimConfigID)
    if PreLoadIDs and PreLoadAssets then
        for Index, AnimPath in pairs(PreLoadAssets) do
			local AssetOpID = self:AddLoadAssetDependency(AnimPath)
			self.AnimAssetLoadMap[AssetOpID] = PreLoadIDs[Index]
        end
    end

    if self.Data.AnimAssetOverride then
        for AssetID, AnimPath in pairs(self.Data.AnimAssetOverride) do
            if StringValid(AnimPath) then
                local AssetOpID = self:AddLoadAssetDependency(AnimPath)
                self.AnimOverrideLoadMap[AssetOpID] = AssetID
            elseif AnimPath and AnimPath.IsA and AnimPath:IsA(import("AnimSequenceBase"))  then --临时处理bug
                self.AnimOverrideMap:Add(AssetID, AnimPath)
            end
        end
    end
end

function AnimLoad_C:OnAssetLoaded(ID, Asset)

    local AssetID = self.AnimAssetLoadMap[ID]
    if AssetID then
        if not Asset or not IsValid_L(Asset) or not type(Asset) == "userdata" or  not Asset.IsA or not Asset:IsA(import("AnimSequenceBase"))  then
            local AnimConfigID = self.Data.AnimLibID
            local AnimData = AnimLibHelper.GetAnimFeatureData(AnimConfigID, AssetID)
            Log.WarningFormat("[AnimLoad_C:OnAssetLoaded]Failed To Load Asset: %s   AssetID:%s      AnimConfigID:%s        Path:%s", Asset and tostring(Asset) or nil, AssetID, AnimConfigID, AnimData and AnimLibHelper.GetAnimAssetPathFromAnimID(AnimData.Anim) or "AnimData Not Found")
			if Asset and  not type(Asset) == "userdata" then
				Log.WarningFormat("[AnimLoad_C:OnAssetLoaded]Loaded Asset Is Not a UserData")
			end
			
			return
        end

        self.AnimAssetMap:Add(AssetID,Asset)
        return
    end

    AssetID = self.AnimOverrideLoadMap[ID]
    if AssetID then
        if not Asset or not IsValid_L(Asset) or not type(Asset) == "userdata" or not Asset.IsA or not Asset:IsA(import("AnimSequenceBase"))  then
            Log.WarningFormat("[AnimLoad_C:OnAssetLoaded]Failed To Load Asset: %s       AssetID:%s      Path:%s", tostring(Asset), AssetID, self.Data.AnimAssetOverride[AssetID])
			if Asset and  not type(Asset) == "userdata" then
				Log.WarningFormat("[AnimLoad_C:OnAssetLoaded]Loaded Asset Is Not a UserData")
			end
			
			return
        end

        self.AnimOverrideMap:Add(AssetID, Asset)

        return
    end
end

function AnimLoad_C:Execute()
    local MeshCom = Game.ObjectActorManager:GetObjectByID(self.TargetID)

    if MeshCom == nil and self.Data.OwnerActorID and self.Data.Tag then
        local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.Data.OwnerActorID)
        if OwnerActor then
            local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), self.Data.Tag)
            if ActorComs:Length() > 0 then
                MeshCom = ActorComs:Get(0)
            end
        end
    end

    if not MeshCom then
        return
    end

    local AnimIns = MeshCom:GetAnimInstance()
    if IsValid_L(AnimIns) and AnimIns:IsA(UBaseAnimInstance) then
        --AnimIns:SetAnimConfig("0", self.AnimOverrideMap, self.AnimAssetMap)
		-- todo 这个流程最好还是往AfterLoadActor之后的entity流程放, 这里暂时先这里初始化临时处理
		local AnimLibName = self.Data.AnimLibID
		if AnimLibName == nil then
			AnimLibName = "None"
		end
		AnimIns:InitLocoSequenceContainerSize(ViewAnimConst.ANIM_LOCO_CONTAINER.CONTAINER_SIZE, AnimLibName)
		-- todo 下面先裸操作, 等巍巍迭代完, 资源LoadID、资源asset map 通过参数带出去, 然后entity处理的过程中, 再AfterLoadActor中调用对应接口进行处理 
		AnimIns:ObtainLocoSequenceMappingWithPriorityIndex(ViewAnimConst.ANIM_LOCO_CONTAINER.BASIC_LOCO_PRIORITY, ViewAnimConst.ANIM_LOCO_CONTAINER.BASIC_LOCO_SEMANTIC, self.AnimAssetMap)
		-- todo 下面这个是临时的, 等戴唯处理完后, 需要干掉 @戴唯
		AnimIns:ObtainLocoSequenceMappingWithPriorityIndex(ViewAnimConst.ANIM_LOCO_CONTAINER.MEDIUM_LOCO_PRIORITY, ViewAnimConst.ANIM_LOCO_CONTAINER.TEMP_LOCO_OVERRIDE_SEMANTIC, self.AnimOverrideMap)
		-- todo 迭代后, 变成下面的逻辑 @孙亚 @巍巍
		--[[
		local logicEntity = Game.EntityManager:GetEntityByIntID(self.Data.UID)
		if logicEntity ~= nil then
			-- 这里临时处理, 后续要批量加载后的ID
			-- AnimLoadAssets 要根据动作库导出的语义进行分类的
			logicEntity:SetRetainedAnimLoadID(animLoadID, AnimIns, AnimLoadAssets)
		end
		]]--
    end
end


MeshClone_C = DefineClass("MeshClone_C", CompositeOperateBase)
function MeshClone_C:ctor()
    self.OperateType = Enum.UECompositeType.MeshClone
end

function MeshClone_C:Reset()
    self.super.Reset(self)

    self.Data.Tag = nil
    self.Data.CloneTag = nil
    self.Data.MorphCloneAnimPath = nil
    self.Data.MigrateTag = nil
    self.Data.MigrateMeshTags = nil
    self.Data.MorphCloneOffset = nil

    self.MorphCloneAnimID = nil
    self.MorphCloneAnim = nil
end

function MeshClone_C:Init()
    self.super.Init(self)

    if StringValid(self.Data.MorphCloneAnimPath) then
        self.MorphCloneAnimID = self:AddLoadAssetDependency(self.Data.MorphCloneAnimPath)
    end
end

function MeshClone_C.GetMeshFromTag(OwnerActor, Tag)
    local ActorComs = OwnerActor:GetComponentsByTag(import("MeshComponent"), Tag)
    if ActorComs:Length() > 0 then
        return ActorComs:Get(0)
    elseif Tag == Enum.UECompositeComTag.Mesh then --临时兼容
        if OwnerActor:GetMainMesh() ~= nil then
            return OwnerActor:GetMainMesh()
        end
    end
    
    return nil
end

function MeshClone_C:Execute()
    if self.MorphCloneAnimID then
        local MorphCloneAnim_LoadRef = self:GetOperateFromID(self.MorphCloneAnimID)
        if MorphCloneAnim_LoadRef then
            self.MorphCloneAnim = MorphCloneAnim_LoadRef.Asset
        end
    end

    local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.TargetID)
    if OwnerActor then

        if self.Data.CloneTag and self.Data.Tag then
            local MeshCom = MeshClone_C.GetMeshFromTag(OwnerActor, self.Data.Tag)
            if MeshCom then
                local CloneMeshAsset = MeshCom.GetSkeletalMeshAsset and MeshCom:GetSkeletalMeshAsset()
                if CloneMeshAsset then
                    local _NewTag = self.Data.Tag .. self.Data.CloneTag
                    local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), _NewTag)
                    local CloneMeshCom = nil
                    if ActorComs:Length() > 0 then
                        CloneMeshCom = ActorComs:Get(0)
                    end

                    if CloneMeshCom == nil then
                        CloneMeshCom = URoleCompositeFunc.RegisterActorComponent(OwnerActor, import("SkeletalMeshComponent"))
                    
                        CloneMeshCom.ComponentTags:AddUnique(_NewTag)
                    end
                    CloneMeshCom:K2_AttachToComponent(MeshCom, "", EAttachmentRule.KeepRelative,
                    EAttachmentRule.KeepRelative, EAttachmentRule.KeepRelative, true)

                    local RelativeTransform = FTransform(FRotator(0, 0, 0):ToQuat(), FVector(0, 0, 0))
                    CloneMeshCom:K2_SetRelativeTransform(RelativeTransform, false, import("HitResult")(), false)

                    CloneMeshCom:SetSkeletalMeshAsset(MeshCom:GetSkeletalMeshAsset())

                    if self.Data.MorphCloneOffset then
                        CloneMeshCom:K2_SetRelativeLocation(self.Data.MorphCloneOffset, true, nil, true)
                    end
                    
                    local Materials = MeshCom:GetMaterials()
                    for i = 0, Materials:Num()-1 do
                        local Material = Materials:Get(i)
                        if Material then
                            CloneMeshCom:SetMaterial(i, Material)
                        end
                    end

                    -- 拷贝材质信息
                    CloneMeshCom:SetLightingChannels(MeshCom.LightingChannels.bChannel0, MeshCom.LightingChannels.bChannel1, MeshCom.LightingChannels.bChannel2)
                    CloneMeshCom:SetOverwriteLighting(MeshCom.bOverwriteLighting or true)
                    CloneMeshCom:SetCastCapsuleIndirectShadow(MeshCom.bCastCapsuleIndirectShadow or true)
                    CloneMeshCom:SetCapsuleIndirectShadowMinVisibility(MeshCom.CapsuleIndirectShadowMinVisibility or 0.5)
                    CloneMeshCom:SetSingleSampleShadowFromStationaryLights(MeshCom.bSingleSampleShadowFromStationaryLights or true)

                    if _G.UE_EDITOR then
                        KGActorUtil.AddInstanceComponent(OwnerActor, CloneMeshCom)
                    end

                    CloneMeshCom.bAbsoluteScale = true
                    
                    if IsValid_L(self.MorphCloneAnim) and self.MorphCloneAnim.IsA then
                        CloneMeshCom:SetAnimationMode(EAnimationMode.AnimationSingleNode)
                        CloneMeshCom:PlayAnimation(self.MorphCloneAnim, false)
                    else
                        CloneMeshCom:SetLeaderPoseComponent(MeshCom, false, false)
                    end
                end
            end
        end

        if self.Data.MigrateTag and self.Data.MigrateMeshTags then
            local MigrateMeshCom = MeshClone_C.GetMeshFromTag(OwnerActor, self.Data.MigrateTag)
            if MigrateMeshCom then
                for _, _Tag in pairs(self.Data.MigrateMeshTags) do
                    if _Tag ~= self.Data.MigrateTag then

                        local OR_MeshComs = nil

                        if _Tag == Enum.UECompositeComTag.Mesh then
                            local _DecorationTag = _Tag .. UECompositeManager.GFurTag_Suffix
                            local DecorationComponents = OwnerActor:GetComponentsByTag(import("MeshComponent"), _DecorationTag)
                            if DecorationComponents:Length() > 0 then
                                for i = 0, DecorationComponents:Length() - 1, 1 do
                                    local DecorationComponent = DecorationComponents:Get(i)
                                    if DecorationComponent then
                                        local ParentCom = DecorationComponent:GetAttachParent()
                                        if ParentCom and ParentCom:ComponentHasTag(_Tag) then
                                            
                                            local Class = import("GameplayStatics").GetObjectClass(DecorationComponent)

                                            local OwnerActorID = Game.ObjectActorManager:GetIDByObject(OwnerActor)
                                            if OwnerActorID then
                                                Game.UECompositeManager:OnMeshComChanged(OwnerActorID, DecorationComponent, Enum.UEActorMeshCBType.MeshComDestroy)
                                            end

                                            DecorationComponent:K2_DestroyComponent(DecorationComponent)
                                
                                            if IsValid_L(Class) then
                                                local _NewDecorationComponent= URoleCompositeFunc.RegisterActorComponent(OwnerActor, Class)
                                                local _NewTag = _DecorationTag .. self.Data.CloneTag
                                                _NewDecorationComponent.ComponentTags:AddUnique(_NewTag)
                                                if OR_MeshComs == nil then
                                                    OR_MeshComs = {}
                                                end
                                                table.insert(OR_MeshComs, _NewDecorationComponent)
                                                if _G.UE_EDITOR then
                                                    KGActorUtil.AddInstanceComponent(OwnerActor, _NewDecorationComponent)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            local OR_MeshCom = MeshClone_C.GetMeshFromTag(OwnerActor, _Tag)
                            if OR_MeshCom then
                                if OR_MeshComs == nil then
                                    OR_MeshComs = {}
                                end
                                table.insert(OR_MeshComs, OR_MeshCom)
                            end
                        end

                        if OR_MeshComs then
                            for i, OR_MeshCom in ipairs(OR_MeshComs) do
                                if OR_MeshCom then
                                    OR_MeshCom:K2_AttachToComponent(MigrateMeshCom, "", EAttachmentRule.KeepRelative,
                                    EAttachmentRule.KeepRelative, EAttachmentRule.KeepRelative, true)
            
                                    OR_MeshCom.bAbsoluteScale = true
                                    
                                    if OR_MeshCom.SetLeaderPoseComponent then
                                        OR_MeshCom:SetLeaderPoseComponent(MigrateMeshCom, false, false)
        
                                        local _NewTag = _Tag .. self.Data.CloneTag
                                        OR_MeshCom.ComponentTags:AddUnique(_NewTag)
                                    end
            
                                    for j = 0 , OR_MeshCom.ComponentTags:Num() - 1 do
                                        local tag = OR_MeshCom.ComponentTags:Get(j)
                                        if IsStringEquals(tag, _Tag) then
                                            OR_MeshCom.ComponentTags:Remove(j)
                                            break
                                        end
                                    end 
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

MergeMesh_C = DefineClass("MergeMesh_C", CompositeOperateBase)
function MergeMesh_C:ctor()
    self.OperateType = Enum.UECompositeType.MergeMesh
end

function MergeMesh_C:Reset()
    self.super.Reset(self)

    self.Data.MeargeMeshTags = {}
end

function MergeMesh_C:Execute()

    local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.TargetID)
    if OwnerActor then
        local Params = import("SkeletalMeshMergeParams")()
        if Params == nil then
            return
        end

        local _DestoryMeshComs = {}
        local _BodyMesh = nil
        for _Index, _Tag in ipairs(self.Data.MeargeMeshTags) do
            if _Tag == Enum.UECompositeComTag.Mesh then
                local _Mesh = LocalGetUEActorComFromTag(OwnerActor, _Tag)
                if _Mesh then
                    local SkeletonMesh = _Mesh:GetSkeletalMeshAsset()
                    if SkeletonMesh then
                        Params.MeshesToMerge:Add(SkeletonMesh)
                        local Skeleton = SkeletonMesh:GetSkeleton()
                        if Skeleton then
                            Params.bSkeletonBefore= true
                            Params.Skeleton = Skeleton
                        end
                    end

                    _BodyMesh = _Mesh
                end
            else
                local _Mesh = LocalGetUEActorComFromTag(OwnerActor, _Tag)
                if _Mesh then
                    local SkeletonMesh = _Mesh:GetSkeletalMeshAsset()
                    if SkeletonMesh then
                        Params.MeshesToMerge:Add(SkeletonMesh)
                    end

                    table.insert(_DestoryMeshComs, _Mesh)
                end
            end
        end
    
        local MeshAsset = import("SkeletalMergingLibrary").MergeMeshes(Params)
        if MeshAsset and _BodyMesh then
    
            -- 过场动画中的主角需要挂上物理，才能在播放动画时刷新动态包围盒，避免被渲染剔除
            --if OwnerActor:ActorHasTag("CutscenePlayer") then
            --    local OriginSkeletalMeshAsset = _BodyMesh:GetSkeletalMeshAsset()
            --    if OriginSkeletalMeshAsset then
            --        local PhysicAsset = OriginSkeletalMeshAsset:GetPhysicsAsset()
            --        if PhysicAsset then
            --            import("C7FunctionLibrary").SetPhysicsAssetForSkeletalMesh(MeshAsset, PhysicAsset)
            --        end
            --    end
            --end

            local OldMeshAsset = _BodyMesh:GetSkeletalMeshAsset()

            import("LuaHelper").SetMeshPositiveBoundsExtension(MeshAsset, OldMeshAsset.PositiveBoundsExtension)
            import("LuaHelper").SetMeshNegativeBoundsExtension(MeshAsset, OldMeshAsset.NegativeBoundsExtension)

            _BodyMesh:SetSkeletalMeshAsset(MeshAsset)
    
            for _, _Mesh in ipairs(_DestoryMeshComs) do
                _Mesh:K2_DestroyComponent(_Mesh)
            end
        end
    end
end

local ImportAvatarCreatorFunctionLibrary = import("AvatarCreatorFunctionLibrary")

BodyShape_C = DefineClass("BodyShape_C", CompositeOperateBase)
function BodyShape_C:ctor()
    self.OperateType = Enum.UECompositeType.BodyShape
end

function BodyShape_C:Reset()
    self.super.Reset(self)

    self.Data.ProfileName = nil --预设体型
    self.Data.FaceCompactData = nil --骨骼自定义形变参数
end

function BodyShape_C:Execute()

    local Owner = Game.ObjectActorManager:GetObjectByID(self.TargetID)
    if Owner then

        if not self.Data.ProfileName or not self.Data.FaceCompactData then
            return
        end
        --先适配, 后续这个组件要干掉
        local FaceControlComponent = Owner:GetComponentByClass(import("FaceControlComponent"))
        if FaceControlComponent then
            FaceControlComponent:SetFaceDataRuntimeDiff(self.Data.ProfileName, self.Data.FaceCompactData)
        else
            ImportAvatarCreatorFunctionLibrary.SetFaceDataRuntimeDiff(Owner:GetMainMesh(), self.Data.ProfileName, self.Data.FaceCompactData)
        end
    end
end

MaterialModify_C = DefineClass("MaterialModify_C", CompositeOperateBase)

MaterialModify_C.Timer = {}


function MaterialModify_C:ctor()
    self.OperateType = Enum.UECompositeType.MaterialModify
end

function MaterialModify_C:ModifyMaterialWithUpdation(OwnerActorId, InComp, InSlotIDs, InTotalLife, InMaterialPath, InScalarMap, InVectorMap, InTextureMap, InUpdateDuration, InPriority, DelayTime)
     --if InMaterialPath then
     --    local ChangeMaterialReq = MaterialEffectParamsPool.AllocFromPool(ChangeMaterialRequestTemplate)
     --    ChangeMaterialReq.OwnerActorId = OwnerActorId
     --    ChangeMaterialReq.MaterialPath = InMaterialPath
     --    ChangeMaterialReq.SearchMeshType = SEARCH_MESH_TYPE.SearchSelfMeshes
     --    --ChangeMaterialReq.AffectedAttachEntityTypes = { Enum.EAttachReason.Weapon }
		-- if InTotalLife and InTotalLife > 0 then
		--	 ChangeMaterialReq.TotalLifeMs = InTotalLife * 1000
		-- end
	 --
     --    Game.MaterialManager:ChangeMaterial(ChangeMaterialReq)
     --end

     local ChangeMaterialParamReq = MaterialEffectParamsPool.AllocFromPool(ChangeMaterialParamRequestTemplate)
     ChangeMaterialParamReq.OwnerActorId = OwnerActorId
     ChangeMaterialParamReq.EffectType = MATERIAL_EFFECT_TYPE.Dissolve
     ChangeMaterialParamReq.SearchMeshType = SEARCH_MESH_TYPE.SearchSelfMeshes
     ChangeMaterialParamReq.ScalarParams = InScalarMap.ScalarParams
     ChangeMaterialParamReq.ScalarLinearSampleParams = InScalarMap.ScalarLinearSampleParams
     for k, v in pairs(ChangeMaterialParamReq.ScalarLinearSampleParams) do
         v.Duration = InUpdateDuration
     end

	if InTotalLife and InTotalLife > 0 then
		ChangeMaterialParamReq.TotalLifeMs = InTotalLife * 1000
	end
	
     ChangeMaterialParamReq.FloatCurveParams = InScalarMap.FloatCurveParams
     ChangeMaterialParamReq.VectorParams = InVectorMap
     --ChangeMaterialParamReq.AffectedAttachEntityTypes = { Enum.EAttachReason.Weapon }
    
     Game.MaterialManager:ChangeMaterialParam(ChangeMaterialParamReq)
    
    return nil
end

function MaterialModify_C:Reset()
    self.super.Reset(self)

    self.Data.Tags = nil
    self.Data.bVisibility = nil
    self.Data.bDelayDeleteCloneMesh = nil --TODO临时
    self.Data.CloneTag = nil
    self.Data.DissolveType = Enum.UECompositeDissolveType.Noise
    self.Data.DissolveTime = 1.6
    self.Data.DissolveEdgeColor = nil --溶解颜色
    self.Data.DissolveDelayTime = nil
    self.Data.DissolveCurvePath = nil

    --TODO 暂时内部 以下数据后续都走配置
    --self.DeathDissolvePath = "/Game/Arts/MaterialLibrary/Utility/MF/MF_DeathDissolve.MF_DeathDissolve"

    self.InVectorMap = nil

    self.InVectorMap_Noise = {DissolveDirection={R=0,G=0,B=1,A=0}, DissolveEdgeColor={R=1.3,G=1.2,B=10,A=0}} --Noise
    self.InVectorMap_Direction = {DissolveDirection={R=0,G=0,B=1,A=1}, DissolveEdgeColor={R=26,G=62,B=100,A=0}} --Direction
    self.InVectorMap_Scene_Noise_Out = {DissolveDirection={R=0,G=0,B=1,A=0}} --场景溶出
    self.InVectorMap_Scene_Direction = {DissolveDirection={R=0,G=0,B=1,A=1}} --场景方向溶出
    self.InVectorMap_Scene_Direction_Out = {DissolveDirection={R=0,G=0,B=1,A=1}} --场景方向溶出

    self.InTextureMap = nil

    self._DissolveAlpha_1_0 = nil
    self._DissolveAlpha_0_1 = nil

    self._DissolveAlpha_1_0_Noise = {}

    self._DissolveAlpha_1_0_Noise.ScalarParams = { InvertMask = 1, DissolveNoiseTiling=0.15, DissolveEdgeWidth=0.15, CharacterHeight=0}
    self._DissolveAlpha_1_0_Noise.ScalarLinearSampleParams = { _DissolveAlpha = { StartVal = 1, EndVal = 0, Duration = 2}}

    self._DissolveAlpha_0_1_Noise = {}
    self._DissolveAlpha_0_1_Noise.ScalarParams = { InvertMask = 0, DissolveNoiseTiling=0.15, DissolveEdgeWidth=0.15, CharacterHeight=0}
    self._DissolveAlpha_0_1_Noise.ScalarLinearSampleParams = { _DissolveAlpha = { StartVal = 0, EndVal = 1, Duration = 2}}

    self._DissolveAlpha_1_0_Direction = {}
    self._DissolveAlpha_1_0_Direction.ScalarParams = { InvertMask = 1, DissolveNoiseTiling=0.3, DissolveEdgeWidth=0.003, CharacterHeight=200, DissolveNoiseIntensity=0.1}
    self._DissolveAlpha_1_0_Direction.ScalarLinearSampleParams = { _DissolveAlpha = { StartVal = 1, EndVal = 0, Duration = 2}}

    self._DissolveAlpha_0_1_Direction = {}
    self._DissolveAlpha_0_1_Direction.ScalarParams = { InvertMask = 0, DissolveNoiseTiling=0.3, DissolveEdgeWidth=0.003, CharacterHeight=200, DissolveNoiseIntensity=0.1}
    self._DissolveAlpha_0_1_Direction.ScalarLinearSampleParams = { _DissolveAlpha = { StartVal = 0, EndVal = 1, Duration = 2}}

    self._DissolveAlpha_1_0_Scene_Noise_Out = {}
    self._DissolveAlpha_1_0_Scene_Noise_Out.ScalarParams = { InvertMask = 0}
    self._DissolveAlpha_1_0_Scene_Noise_Out.ScalarLinearSampleParams = { _DissolveAlpha = { StartVal = 1, EndVal = 0, Duration = 2}}

    self._DissolveAlpha_0_1_Scene_Noise_Out = {}
    self._DissolveAlpha_0_1_Scene_Noise_Out.ScalarParams = { InvertMask = 1}
    self._DissolveAlpha_0_1_Scene_Noise_Out.ScalarLinearSampleParams = { _DissolveAlpha = { StartVal = 0, EndVal = 1, Duration = 2}}

    self._DissolveAlpha_1_0_Scene_Direction = {}
    self._DissolveAlpha_1_0_Scene_Direction.ScalarParams = { InvertMask = 0}
    self._DissolveAlpha_1_0_Scene_Direction.ScalarLinearSampleParams = { _DissolveAlpha = { StartVal = 1, EndVal = 0, Duration = 2}}

    self._DissolveAlpha_0_1_Scene_Direction_Out = {}
    self._DissolveAlpha_0_1_Scene_Direction_Out.ScalarParams = { InvertMask = 0}
    self._DissolveAlpha_0_1_Scene_Direction_Out.ScalarLinearSampleParams = { _DissolveAlpha = { StartVal = 0, EndVal = 1, Duration = 2}}

    self.DissolveCurveID = nil
end

function MaterialModify_C:Init()
    self.super.Init(self)

    if self.Data.DissolveType == nil then
        self.Data.DissolveType = Enum.UECompositeDissolveType.Noise
    end

    --TODO 后续改成Map
    if self.Data.DissolveType == Enum.UECompositeDissolveType.Noise 
    or self.Data.DissolveType == Enum.UECompositeDissolveType.Noise_Out then
        self.InVectorMap = self.InVectorMap_Noise
        self._DissolveAlpha_1_0 = self._DissolveAlpha_1_0_Noise
        self._DissolveAlpha_0_1 = self._DissolveAlpha_0_1_Noise
    elseif self.Data.DissolveType == Enum.UECompositeDissolveType.Scene_Noise_Out then
        self.InVectorMap = self.InVectorMap_Scene_Noise_Out
        self._DissolveAlpha_1_0 = self._DissolveAlpha_1_0_Scene_Noise_Out
        self._DissolveAlpha_0_1 = self._DissolveAlpha_0_1_Scene_Noise_Out
    elseif self.Data.DissolveType == Enum.UECompositeDissolveType.Scene_Direction then
        self.InVectorMap = self.InVectorMap_Scene_Direction
        self._DissolveAlpha_1_0 = self._DissolveAlpha_1_0_Scene_Direction
    elseif self.Data.DissolveType == Enum.UECompositeDissolveType.Scene_Direction_Out then
        self.InVectorMap = self.InVectorMap_Scene_Direction_Out
        self._DissolveAlpha_0_1 = self._DissolveAlpha_0_1_Scene_Direction_Out
    else
        self.InVectorMap = self.InVectorMap_Direction
        self._DissolveAlpha_1_0 = self._DissolveAlpha_1_0_Direction
        self._DissolveAlpha_0_1 = self._DissolveAlpha_0_1_Direction
    end

    if self.Data.DissolveEdgeColor then
        if self.InVectorMap then
            self.InVectorMap.DissolveEdgeColor = self.Data.DissolveEdgeColor
        end
    end

    if StringValid(self.Data.DissolveCurvePath) then
        self.DissolveCurveID = self:AddLoadAssetDependency(self.Data.DissolveCurvePath)
    end
end

function MaterialModify_C:Execute()

    local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.TargetID)
    if OwnerActor then
        local MeshCom = nil

        if self.Data.Tags then
            for _, _Tag in pairs(self.Data.Tags) do
                local ActorComs = OwnerActor:GetComponentsByTag(import("MeshComponent"), _Tag)
                --临时兼容
                if _Tag == Enum.UECompositeComTag.Mesh then
                    if ActorComs:Length() == 0 and OwnerActor:GetMainMesh() ~= nil then
                        ActorComs:Add(OwnerActor:GetMainMesh())
                    end
                end

                if ActorComs:Length() > 0 then
                    
                    --临时 TODO
                    local _GFurTag = _Tag
                    local SI, EI = string.find(_GFurTag, UECompositeManager.CloneMesh_Suffix)
                    if SI then
                        local _SubStr = string.sub(_GFurTag, 1, SI - 1)
                        if _SubStr then
                            _GFurTag = _SubStr .. UECompositeManager.GFurTagCloneMesh_Suffix
                        end
                    else
                        _GFurTag = _GFurTag .. UECompositeManager.GFurTag_Suffix
                    end

                    local DecorationComponents = OwnerActor:GetComponentsByTag(import("MeshComponent"), _GFurTag)
                    if DecorationComponents:Length() > 0 then
                        for i = 0, DecorationComponents:Length() - 1, 1 do
                            local DecorationComponent = DecorationComponents:Get(i)
                            if DecorationComponent then
                                local ParentCom = DecorationComponent:GetAttachParent()
                                if ParentCom and ParentCom:ComponentHasTag(_Tag) then
                                    ActorComs:Add(DecorationComponent)
                                end
                            end
                        end
                    end

                    for index = 0, ActorComs:Length() - 1 do

                        MeshCom = ActorComs:Get(index)
                        if MeshCom then
                            if self.Data.bVisibility ~= nil then
                                MeshCom:SetHiddenInGame(not self.Data.bVisibility, false)
                            end
    
                            --TODO 后续调整
                            local _Tags = MeshCom.ComponentTags:ToTable()
                            for _, _Tag in pairs(_Tags) do
                                local SI, EI = string.find(_Tag, "_ModifyMaID_")
                                if SI then
                                    local OPIDStr = string.sub(_Tag, EI + 1)
                                    if OPIDStr then
                                        local OPID = tonumber(OPIDStr)
                                        if OPID then
                                            Game.WorkProxyManager:CancelWorkProxy(OPID)
                                        end
                                    end
    
                                    for j = 0 , MeshCom.ComponentTags:Num() - 1 do
                                        local tag = MeshCom.ComponentTags:Get(j)
                                        if IsStringEquals(tag, _Tag) then
                                            MeshCom.ComponentTags:Remove(j)
                                            break
                                        end
                                    end 
                                end
                            end
            
                            local bSkeletalChanged = nil
                            if _Tag == Enum.UECompositeComTag.Mesh then
                                for j = 0 , MeshCom.ComponentTags:Num()-1 do
                                    local tag = MeshCom.ComponentTags:Get(j)
                                    if IsStringEquals(tag, UECompositeManager.SkeletalChangedTag) then
                                        MeshCom.ComponentTags:Remove(j)
                                        bSkeletalChanged = true
                                        break
                                    end
                                end 
                            end
    
                            if bSkeletalChanged then
                                self:DelayDestroyCloneMesh()
                            end
    
                            local ModifyOPID = nil
                            if self.Data.DissolveType == Enum.UECompositeDissolveType.Noise
                                or self.Data.DissolveType == Enum.UECompositeDissolveType.Direction
                                or self.Data.DissolveType == Enum.UECompositeDissolveType.Scene_Direction then
                                
                                if self.DissolveCurveID then
                                    self._DissolveAlpha_1_0.FloatCurveParams._DissolveAlpha = {
                                        AssetPath = self.Data.DissolveCurvePath,
                                        bEnableLoop = false,
                                        RemapTime = self.Data.DissolveTime,
                                    }
                                end
    
                                ModifyOPID = self:ModifyMaterialWithUpdation(self.TargetID, MeshCom, nil, self.Data.DissolveTime + 1, self.DeathDissolvePath, self._DissolveAlpha_1_0, self.InVectorMap, self.InTextureMap, self.Data.DissolveTime, nil, self.Data.DissolveDelayTime)
    
                            elseif self.Data.DissolveType == Enum.UECompositeDissolveType.Noise_Out 
                                or self.Data.DissolveType == Enum.UECompositeDissolveType.Direction_Out
                                or self.Data.DissolveType == Enum.UECompositeDissolveType.Scene_Noise_Out
                                or self.Data.DissolveType == Enum.UECompositeDissolveType.Scene_Direction_Out then
                                
                                if self.DissolveCurveID then
                                    self._DissolveAlpha_0_1.FloatCurveParams._DissolveAlpha = {
                                        AssetPath = self.Data.DissolveCurvePath,
                                        bEnableLoop = false,
                                        RemapTime = self.Data.DissolveTime,
                                    }
                                end
    
                                ModifyOPID = self:ModifyMaterialWithUpdation(self.TargetID, MeshCom, nil, self.Data.DissolveTime + 1, self.DeathDissolvePath, self._DissolveAlpha_0_1, self.InVectorMap, self.InTextureMap, self.Data.DissolveTime, nil, self.Data.DissolveDelayTime)
                            end
    
                            if ModifyOPID then
                                --TODO ID存储需要优化
                                local ModifyOPIDTag = "_ModifyMaID_" .. tostring(ModifyOPID)
                                MeshCom.ComponentTags:AddUnique(ModifyOPIDTag)
                            end
                        end
                    end
                end
            end
        end

        local DelayDestroyCloneMeshTimeHander = MaterialModify_C.Timer[self.TargetID]
        if DelayDestroyCloneMeshTimeHander then
            Game.TimerManager:StopTimerAndKill(DelayDestroyCloneMeshTimeHander)
            MaterialModify_C.Timer[self.TargetID] = nil
        end

        if self.Data.bDelayDeleteCloneMesh then

            local DeleteTime = self.Data.DissolveTime
            if self.Data.DissolveDelayTime then
                DeleteTime = -self.Data.DissolveDelayTime + DeleteTime
            end

            MaterialModify_C.Timer[self.TargetID] = Game.TimerManager:CreateTimerAndStart(function()
                self:DelayDestroyCloneMesh()
                MaterialModify_C.Timer[self.TargetID] = nil
            end, DeleteTime * 1000, 1)
        end
    end
end

function MaterialModify_C:DelayDestroyCloneMesh()
    local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.TargetID)
    if OwnerActor then
        for k, _Tag in pairs(Enum.EAvatarBodyPartTypeName) do
            local _CloneTag = _Tag .. "CloneMesh"
            local ActorComs = OwnerActor:GetComponentsByTag(import("MeshComponent"), _CloneTag)
            if ActorComs:Length() > 0 then
                local MeshCom = ActorComs:Get(0)
                if MeshCom then
                    Game.UECompositeManager:OnMeshComChanged(self.TargetID, MeshCom, Enum.UEActorMeshCBType.MeshComDestroy)
                    MeshCom:K2_DestroyComponent(MeshCom)
                end
            end

            --TODO 临时
            local _GFurTag = _Tag .. UECompositeManager.GFurTagCloneMesh_Suffix
            local DecorationComponents = OwnerActor:GetComponentsByTag(import("MeshComponent"), _GFurTag)
            if DecorationComponents:Length() > 0 then
                for i = 0, DecorationComponents:Length() - 1, 1 do
                    local DecorationComponent = DecorationComponents:Get(i)
                    if DecorationComponent then
                        Game.UECompositeManager:OnMeshComChanged(self.TargetID, DecorationComponent, Enum.UEActorMeshCBType.MeshComDestroy)
                        DecorationComponent:K2_DestroyComponent(DecorationComponent)
                    end
                end
            end
        end
    end
end

Effect_C = DefineClass("Effect_C", CompositeOperateBase)
function Effect_C:ctor()
    self.OperateType = Enum.UECompositeType.Effect
end

function Effect_C:Reset()
    self.super.Reset(self)


    self.Data.NS_Effect = nil --特效路径
    self.Data.Tag = nil --目标SceneCom的Tag
    self.Data.Offset = nil --偏移
    self.Data.Socket = nil --目标插槽
    self.Data.EffectTag = nil --特效标记
    self.Data.FilteredBones = nil --骨骼过滤

    self.AssetOpID = 0
end

function Effect_C:Init()
    self.super.Init(self)

    if StringValid(self.Data.NS_Effect) then
        self.AssetOpID = self:AddLoadAssetDependency(self.Data.NS_Effect)
    end
end

function Effect_C:Execute()
    local AssetOp = self:GetOperateFromID(self.AssetOpID)
    if AssetOp and IsValid_L(AssetOp.Asset) and AssetOp.Asset.IsA and AssetOp.Asset:IsA(import("NiagaraSystem")) and self.Data.Tag then
        local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.TargetID)
        if OwnerActor then
            local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), self.Data.Tag)
            if ActorComs:Length() <= 0 then
                return
            end

            local TargetCom = ActorComs:Get(0)
            if TargetCom == nil then
                return
            end

            local MeshCompId = Game.ObjectActorManager:GetIDByObject(TargetCom)
            if MeshCompId == 0 then
                return
            end

            if self.Data.Offset == nil then
                return
            end

			-- 组装流程不一定都有entity, 没有的不用走culling流程
			local NiagaraBudgetToken
			local EffectPriority = self.Data.Priority and self.Data.Priority or 2
			if OwnerActor.GetEntityUID then
				local EntityId = OwnerActor:GetEntityUID()
				local Entity = Game.EntityManager:getEntity(EntityId)
				if Entity then
					local CharacterTypeForViewBudget = Entity:GetCharacterTypeForViewBudget()
					-- 外观特效优先级默认按medium来
					local bCanPlayNiagara, BudgetToken = Game.EffectManager:TryObtainNiagaraBudget(
						CharacterTypeForViewBudget, NIAGARA_EFFECT_TYPE_FOR_PRIORITY_CULLING.APPEARANCE, OwnerActor, EffectPriority)
					if not bCanPlayNiagara then
						return
					end
					NiagaraBudgetToken = BudgetToken
				end
			end
			
            -- todo 这里没有entity id 使用连线特效可能会出问题
            local NiagaraEffectParam = NiagaraEffectParamTemplate.AllocFromPool()
            NiagaraEffectParam.NiagaraAssetId = Game.ObjectActorManager:GetIDByObject(AssetOp.Asset)
            NiagaraEffectParam.AttachPointName = self.Data.Socket
            NiagaraEffectParam.bNeedAttach = true
            NiagaraEffectParam.SpawnerId = Game.ObjectActorManager:GetIDByObject(OwnerActor)
            NiagaraEffectParam.AttachComponentId = MeshCompId
            NiagaraEffectParam.bActivateImmediately = true
            NiagaraEffectParam.NiagaraBudgetToken = NiagaraBudgetToken
			NiagaraEffectParam.NiagaraEffectType = NIAGARA_EFFECT_TYPE_FOR_PRIORITY_CULLING.APPEARANCE
			NiagaraEffectParam.CustomNiagaraPriority = EffectPriority
			table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.APPEARANCE)
			NiagaraEffectParam.ComponentTags = {}
            table.insert(NiagaraEffectParam.ComponentTags, self.Data.EffectTag)
            table.insert(NiagaraEffectParam.ComponentTags, Game.UECompositeManager.CompositeEffectTag)

            -- 确认下是否组装特效要用battle
            NiagaraEffectParam.SourceType = NIAGARA_SOURCE_TYPE.BATTLE

            M3D.ToTransform(self.Data.Offset, NiagaraEffectParam.SpawnTrans)

            if self.Data.FilteredBones and next(self.Data.FilteredBones) ~= nil then
				NiagaraEffectParam.UserVals_SkeletalMeshCompIds = {}
				NiagaraEffectParam.UserVals_SkeletalMeshCompFilterBones = {}
                NiagaraEffectParam.UserVals_SkeletalMeshCompIds["SKMesh"] = MeshCompId
                local Bones = {}
                for _, BoneName in ipairs(self.Data.FilteredBones) do
                    table.insert(Bones, BoneName)
                end
                NiagaraEffectParam.UserVals_SkeletalMeshCompFilterBones["SKMesh"] = Bones
            end

            Game.EffectManager:CreateNiagaraSystem(NiagaraEffectParam)
        end
    end
end

Group_C = DefineClass("Group_C", CompositeOperateBase)
function Group_C:ctor()
    self.OperateType = Enum.UECompositeType.Group
end

function Group_C:Reset()
    self.super.Reset(self)

    self.Data.UID = 0   --唯一ID 标记回传 再次刷新中断判定依据
    self.Data.OwnerActorID = nil --UEActorID
    self.Data.CompositeCallFunc = nil --完成函数回调 用全局函数
    
    self.Data.GroupType = Enum.UECompositeGroupType.Base
end

function Group_C:AddOperateID(ID)
    local Operate = self:GetOperateFromID(ID)
    if Operate and Operate.State == Enum.UECompositeState.Pending then
        if self.DependencyToken.IDs == nil then
            self.DependencyToken.IDs = {}
        end

        --加个保护
        if table.ikey(self.DependencyToken.IDs, ID) then
            return 
        end

        table.insert(self.DependencyToken.IDs, ID)
    end
end

function Group_C:Init()
    if self.Data.GroupType ~= Enum.UECompositeGroupType.Base and self.Data.UID and self.Data.UID ~= 0 then
        local GroupOperateIDs = Game.UECompositeManager.CompositeGroupMap[self.Data.UID]
        if GroupOperateIDs then
            local GroupOperateID = GroupOperateIDs[self.Data.GroupType]
            if GroupOperateID then
                local GroupOperate = self:GetOperateFromID(GroupOperateID)
                if GroupOperate and GroupOperate.State == Enum.UECompositeState.Pending then
                    GroupOperate:ProgressCancel()
                end
            end
        else
            GroupOperateIDs = {}
            Game.UECompositeManager.CompositeGroupMap[self.Data.UID] = GroupOperateIDs
        end

        GroupOperateIDs[self.Data.GroupType] = self.ID
    end

    self.super.Init(self)
end

function Group_C:DoExecute()
    self.super.DoExecute(self)

    if self.Data.CompositeCallFunc then
        local OwnerActor = Game.ObjectActorManager:GetObjectByID(self.Data.OwnerActorID)
        if OwnerActor then
            --self.Data.CompositeCallFunc(OwnerActor, self.Data.UID)
            local CompositeCallFunc = self.Data.CompositeCallFunc
            local UID = self.Data.UID
			local CallBackData = self.Data.CallBackData
			
            --清理
            Game.UECompositeManager:DeleteGroup(self.Data.UID)

            if CompositeCallFunc and UID then
                xpcall(CompositeCallFunc, _G.CallBackError, OwnerActor, UID, CallBackData)
            end
            

        end
    end
end

function Group_C:ProgressCancel()
    if self.DependencyToken.IDs then
        for k, ID in pairs(self.DependencyToken.IDs) do
            local Operate = self:GetOperateFromID(ID)
            if Operate then
                Operate:ProgressCancel()
            end
        end
    end
end

function UECompositeManager:ctor()

    self.CompositeOperateClassMap = {}
    self.CompositeOperateClassMap[Enum.UECompositeType.Group] = Group_C
    self.CompositeOperateClassMap[Enum.UECompositeType.LoadAsset] = LoadAsset_C
    self.CompositeOperateClassMap[Enum.UECompositeType.SkeletalMeshCom] = SkeletalMeshCom_C
    self.CompositeOperateClassMap[Enum.UECompositeType.StaticMeshCom] = StaticMeshCom_C
    self.CompositeOperateClassMap[Enum.UECompositeType.HitBox] = HitBox_C
    self.CompositeOperateClassMap[Enum.UECompositeType.Capsule] = Capsule_C
    self.CompositeOperateClassMap[Enum.UECompositeType.Material] = Material_C
    self.CompositeOperateClassMap[Enum.UECompositeType.Anim] = Anim_C
    self.CompositeOperateClassMap[Enum.UECompositeType.MergeMesh] = MergeMesh_C
    self.CompositeOperateClassMap[Enum.UECompositeType.BodyShape] = BodyShape_C
    self.CompositeOperateClassMap[Enum.UECompositeType.MaterialModify] = MaterialModify_C
    self.CompositeOperateClassMap[Enum.UECompositeType.Effect] = Effect_C
    self.CompositeOperateClassMap[Enum.UECompositeType.AnimLoad] = AnimLoad_C
    self.CompositeOperateClassMap[Enum.UECompositeType.MeshClone] = MeshClone_C
    
    self:Reset()
end

function UECompositeManager:dtor()

end

function UECompositeManager:Reset()
    self.CompositeGroupQueue = {}
    self.CompositeGroupMap = {}


    self.CompositeOperateMap = {}
    self.DependencyObserverMap = {}

    self.CompositeOperatePool = {}

    self.IDGenerate_last_timestamp = 0
    self.IDGenerate_Counter = 0

    self.AsyncLoadMap = {}

    self.SKEL_3CSKID = nil
end

function UECompositeManager:Init()
    self:Reset()
end

function UECompositeManager:UnInit()
    self:Reset()
end

--请求 异步创建
--OperateType Enum.UECompositeType
--DependencyIDs 依赖项ID 没有填 nil
--TargetID  Object UID
--Data 目前直接使用编辑器导出数据
function UECompositeManager:RequestComposite(OperateType, DependencyIDs, TargetID, Data)

    local Operate = self:beginRequestComposite(OperateType, DependencyIDs, TargetID, Data)
    if Operate == nil then
        return 0
    end

    return self:endRequestComposite(Operate)
end

function UECompositeManager:beginRequestComposite(OperateType, DependencyIDs, TargetID, Data)
    local FreeOp = self:GetFreeOperate(OperateType)
    if FreeOp == nil then
        Log.Error("[UECompositeManager:RequestComposite] OperateType Error: ", OperateType)
        return nil
    end

    FreeOp.ID = self:GetNewID()
    FreeOp.TargetID = TargetID
    FreeOp.State = Enum.UECompositeState.Pending
    FreeOp.DependencyToken.IDs = DependencyIDs

    if Data then
        --暂时测试用 目前新的Data都是 nil 后续废弃
        FreeOp.Data = table.cloneconf(Data)
    end

    return FreeOp
end

function UECompositeManager:endRequestComposite(Operate)

    Operate:Init()

    if Operate.DependencyToken.IDs == nil or next(Operate.DependencyToken.IDs) == nil then
        Operate:DoExecute()
    else
        self:RegisterDependency(Operate)
    end

    self.CompositeOperateMap[Operate.ID] = Operate

    return Operate.ID
end

--TODO 回收
function UECompositeManager:DeleteGroup(UID)
    local GroupOperateIDs = self.CompositeGroupMap[UID]
    if GroupOperateIDs then
        for k, GroupOperateID in pairs(GroupOperateIDs) do
            self:InnerDeleteOperate(GroupOperateID, true)
        end
    end

    self.CompositeGroupMap[UID] = nil
end

--TODO 回收
function UECompositeManager:InnerDeleteOperate(InOperateID, bCancel)
    local Operate = self.CompositeOperateMap[InOperateID]
    if Operate then
        if bCancel then
            Operate:ProgressCancel()
        end

        if Operate.DependencyToken and Operate.DependencyToken.IDs then
            for _, _DependencyOperateID in pairs(Operate.DependencyToken.IDs) do
                self:InnerDeleteOperate(_DependencyOperateID)
            end
        end

        Operate:Reset()
    end

    self.CompositeOperateMap[InOperateID] = nil
end

function UECompositeManager:CancelComposite(UID)
    Log.DebugFormat("UECompositeManager:CancelComposite %s: ", UID)
    self:DeleteGroup(UID)
end


--Operate Pool Begin
function UECompositeManager:GetFreeOperate(OperateType)
    local FreeOpPool = self.CompositeOperatePool[OperateType]
    if FreeOpPool ~= nil then
        local Size = #FreeOpPool
        if #Size > 0 then
            return table.remove(FreeOpPool, Size)
        end
    end

    local OpClass = self.CompositeOperateClassMap[OperateType]
    if OpClass then
        return OpClass.new()
    else
        return nil
    end
end

function UECompositeManager:ReleaseOperate(Operate)
    if Operate then
        Operate:Reset()

        local FreeOpPool = self.CompositeOperateClassMap[Operate.OperateType]
        if FreeOpPool == nil then
            FreeOpPool = {}
        end
    
        table.insert(FreeOpPool, Operate)
    
        self.AoiPlayerActorPool[Operate.OperateType] = FreeOpPool
    end
end
--Operate Pool End

function UECompositeManager:RegisterDependency(Operate)
    if Operate.DependencyToken == nil 
        or Operate.DependencyToken.IDs == nil then
        return 
    end

    Operate.DependencyToken.RemainIDs = {}

    for _, _ID in ipairs(Operate.DependencyToken.IDs) do
        local RegisterIDs = self.DependencyObserverMap[_ID]
        if RegisterIDs == nil then
            RegisterIDs = {}
        end

        RegisterIDs[Operate.ID] = true

        self.DependencyObserverMap[_ID] = RegisterIDs

        Operate.DependencyToken.RemainIDs[_ID] = true
    end
end

function UECompositeManager:UnRegisterDependency(Operate)
    if Operate.DependencyToken == nil 
        or Operate.DependencyToken.IDs == nil then
        return 
    end

    for _, _ID in ipairs(Operate.DependencyToken.IDs) do
        local RegisterIDs = self.DependencyObserverMap[_ID]
        if RegisterIDs then
            RegisterIDs[Operate.ID] = nil
        end
    end
end

function UECompositeManager:DependencyRejected(DOperate, RID)
    local RgOperate = self.CompositeOperateMap[RID]
    if RgOperate then
        if RgOperate.DependencyToken.RemainIDs then
            RgOperate.DependencyToken.RemainIDs[DOperate.ID] = nil
        end
        
        if DOperate.OperateType == Enum.UECompositeType.LoadAsset then
            RgOperate:OnAssetLoaded(DOperate.ID, DOperate.Asset)
        end
    
        if RgOperate.DependencyToken.RemainIDs == nil 
            or next(RgOperate.DependencyToken.RemainIDs) == nil then
    
            RgOperate:DoExecute()
        end
    end
end

function UECompositeManager:GetNewID()

    local timestamp = os.time()
    if timestamp == self.IDGenerate_last_timestamp then
        self.IDGenerate_Counter = self.IDGenerate_Counter + 1
    else
        self.IDGenerate_Counter = 0
    end
    self.IDGenerate_last_timestamp = timestamp
    
    return timestamp * 100000 + self.IDGenerate_Counter
end

function UECompositeManager.OnAssetLoad(Asset, CID)
    local CP = Game.UECompositeManager.CompositeOperateMap[CID]
    if CP then
        CP:OnAssetLoaded(Asset)
    end
end

function UECompositeManager:PushAsyncLoadAsset(Path, CallBackFunc, ...)
    --Log.WarningFormat("PushAsyncLoadAsset %s %s", Path, CallBackFunc)
    if Path and StringValid(Path) then
        local loadID, obj = Game.AssetManager:AsyncLoadAssetKeepReference(Path, self, "OnAssetAsyncLoaded")

        local CallBackData = {ID = loadID, Path=Path,CallBackFunc = CallBackFunc, Params={...}}

        self.AsyncLoadMap[loadID] = CallBackData

        return loadID
    end
    return nil
end

function UECompositeManager:CancelAsyncLoadAsset(AssetLoadID)
    if AssetLoadID then
        Game.AssetManager:CancelLoadAsset(AssetLoadID)

        self.AsyncLoadMap[AssetLoadID] = nil
    end
end

function UECompositeManager:OnAssetAsyncLoaded(loadID, obj)
    local CallBackData = self.AsyncLoadMap[loadID]
    if CallBackData and CallBackData.CallBackFunc then
        xpcall(CallBackData.CallBackFunc, _G.CallBackError, obj, unpack(CallBackData.Params))
    end

    self.AsyncLoadMap[loadID] = nil

    Game.AssetManager:RemoveAssetReferenceByLoadID(loadID)
end

function UECompositeManager:OnMeshComChanged(OwnerActorID, MeshCom, UEActorMeshCBType)
    --临时测试接口
    if Game.EntityManager then
        local Actor = Game.ObjectActorManager:GetObjectByID(OwnerActorID)
        if Actor and Actor.GetEntityUID then
            local UID = Actor:GetEntityUID()
            if UID > 0 then
                local Entity = Game.EntityManager:getEntity(UID)
                if Entity and Entity.OnMeshComChanged then
                    xpcall(Entity.OnMeshComChanged, _G.CallBackError, Entity, MeshCom, UEActorMeshCBType)
                end
            end
        end
    end
end

return UECompositeManager

