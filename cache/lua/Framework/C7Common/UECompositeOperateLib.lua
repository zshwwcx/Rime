local URoleCompositeFunc = import("RoleCompositeFunc")
local EAttachmentRule = import("EAttachmentRule")

local UECompositeOperateLib = DefineClass("UECompositeOperateLib")
local MeshComponentClass = import("MeshComponent")
local BoxComponentClass = import("BoxComponent")
local HitResultClass = import("HitResult")

local ViewAnimConst = kg_require("Gameplay.CommonDefines.ViewAnimConst")
local ViewControlConst = kg_require("Shared.Const.ViewControlConst")

local KGUECompositeOperateLibrary = import("KGUECompositeOperateLib")

local const = kg_require("Shared.Const")
local NIAGARA_SOURCE_TYPE = const.NIAGARA_SOURCE_TYPE
local NIAGARA_EFFECT_TAG = const.NIAGARA_EFFECT_TAG

Enum.UECompositeTypeV2 = {
    Base = 0,
    SkeletalMeshCom = 1,
    Anim = 2,
    Material = 3,
    Capsule = 4,
    HitBox = 5,
    BodyShape = 6,
    Effect = 7,

}

Enum.UECompositeComTagV2 = {
    Mesh = "BodyUpper", --主Mesh
}

--忽略大小写
local function IsStringEquals(StrA, StrB)
    return string.lower(StrA) == string.lower(StrB)
end

local function IsStringValid(Str)
    return Str and type(Str) == "string" and string.len(Str) > 0
end

UEOperateDataBase = DefineClass("UEOperateDataBase")
function UEOperateDataBase:ctor()
    self.Priority = 0

    --c++结构体数据
    --Lua覆盖数据
end

function UEOperateDataBase:id()
end

function UEOperateDataBase:GetFreeData()
    if self.class ~= nil then
        Log.ErrorFormat("UEOperateDataBase class %s", self.__cname)
        return nil
    end
    return UEOperateDataBase.MemoryAlloc:GetFreeData(self)
end

function UEOperateDataBase:ReleaseData()
    return UEOperateDataBase.MemoryAlloc:ReleaseData(self)
end

function UEOperateDataBase:GetUECompositeType()
    return self.class.UECompositeType
end

CompositeOperateBaseV2 = DefineClass("CompositeOperateBaseV2")
CompositeOperateBaseV2.OperateType = Enum.UECompositeTypeV2.Base
CompositeOperateBaseV2.UEOperateDataCls = nil
function CompositeOperateBaseV2:ctor()
    self.UECompositeOperateLib = nil
end

--模型编辑器数据未优化完毕, 需要转换
--数据转换
function CompositeOperateBaseV2:GetData(OldData)
    
end
--收集资源
function CompositeOperateBaseV2:CollectAssetPath(OutPaths)
    
end
--执行修改
function CompositeOperateBaseV2:Execute(InData)

end


function CompositeOperateBaseV2:GetComponentByID(InObjectID)
    return Game.ObjectActorManager:GetObjectByID(InObjectID)
end

function CompositeOperateBaseV2:GetActorByID(InObjectID)
    return Game.ObjectActorManager:GetObjectByID(InObjectID)
end

function CompositeOperateBaseV2:GetAssetFromPath(InPath)
    --暂时先用
    return Game.AssetManager:SyncLoadAsset(InPath)
end

---SK Begin---------------------------

--模型身体数据
SkeletalMeshComV2_Data = DefineClass("SkeletalMeshComV2_Data", UEOperateDataBase)
SkeletalMeshComV2_Data.UECompositeType = Enum.UECompositeTypeV2.SkeletalMeshCom
SkeletalMeshComV2_Data.EmptyTable = {}
function SkeletalMeshComV2_Data:ctor()
    self.UID = nil
    self.SkeletalMesh = nil
    self.Offset = nil
    
    self.OwnerActorID = nil
    self.Tag = nil --如果TargetID没指定, 通过Tag来找,默认没有Tag的新创建
    self.AttachTargetTag = nil --挂到对应Tag目标, 没有就挂到Root
    self.SocketName = "" --对象是MeshCom的, 插槽名称
    self.BodyMeshSocketName = nil --对象是MeshCom的, 插槽名称 主Mesh下的
    self.LeaderPoseComTag = nil --跟随的MeshTag名
	self.OverrideMaterials = nil -- 覆盖材质, 配置复用Mesh
	self.MaterialFollowerTags = nil -- 材质跟随, 丝袜等内容要求不同Part之间用同一个某某材质

    self.bReceivesDecals = nil --是否接受贴花
    self.bRenderCustomDepthPass = nil --是否开启自定义深度
    self.bActive = nil --是否激活
    self.bVisibility = nil --初始是否显示
    
    --OP
    self.bEnableMeshOptimization = nil --是否开启SK优化
    self.bUseAttachParentBound = nil --使用父类Bound(优化用, 一般false)
    self.bActiveTick = nil --是否允许更新

    --TA
    self.bCastInsetShadow = nil --阴影
    self.bSingleSampleShadowFromStationaryLights = nil --物体中心位置去算一个固态阴影的遮蔽值
    self.CapsuleShadow_AssetID = nil
    self.LightChannels = nil
    self.MaterialOverlay = nil
    self.bOverrideLighting = true

    --C++OP
    self.BoolParamNames={}
    self.BoolValues={}
    self.StringParamNames={}
    self.StringValues={}
    self.IntParamNames ={}
    self.IntValues={}
end

SkeletalMeshComV2_C = DefineClass("SkeletalMeshComV2_C", CompositeOperateBaseV2)
SkeletalMeshComV2_C.OperateType = Enum.UECompositeTypeV2.SkeletalMeshCom
SkeletalMeshComV2_C.UEOperateDataCls = SkeletalMeshComV2_Data

function SkeletalMeshComV2_C:ctor()
    --公用优化配置

    --公用TA设置
end

function SkeletalMeshComV2_C:GetData(SKData)
    if SKData == nil then
        SKData = SkeletalMeshComV2_C.UEOperateDataCls:GetFreeData()
    end
    
    --公用优化配置
    SKData.bActive = true --是否激活
    
    --OP
    SKData.bUseAttachParentBound = false --使用父类Bound(优化用, 一般false)

    --TA
    SKData.bCastInsetShadow = false --阴影
    SKData.bSingleSampleShadowFromStationaryLights = true --物体中心位置去算一个固态阴影的遮蔽值
    SKData.bOverrideLighting = true

    return SKData
end

function SkeletalMeshComV2_C:CollectAssetPath(InSKData, OutPaths)
    if IsStringValid(InSKData.SkeletalMesh) then
        table.insert(OutPaths, InSKData.SkeletalMesh)
    end

    if IsStringValid(InSKData.MaterialOverlay) then
        table.insert(OutPaths, InSKData.MaterialOverlay)
    end

	if InSKData.OverrideMaterials then
		for _, materialPath in pairs(InSKData.OverrideMaterials) do
			table.insert(OutPaths, materialPath)
		end
	end
end

SkeletalMeshComV2_C.SkComFuncType =
{
	--Bool
	["AddInstanceComponent"] = "AddInstanceComponent",
    ["bUpdateOverlapsOnAnimationFinalize"] = "bUpdateOverlapsOnAnimationFinalize",
    ["SetGenerateOverlapEvents"] = "SetGenerateOverlapEvents",
    ["SetComponentTickEnabled"] = "SetComponentTickEnabled",
    ["SetReceivesDecals"] = "SetReceivesDecals",
    ["SetRenderCustomDepth"] = "SetRenderCustomDepth",
    ["SetActive"] = "SetActive",
    ["SetHiddenInGame"] = "SetHiddenInGame",
    ["SetCastInsetShadow"] = "SetCastInsetShadow",
    ["SetSingleSampleShadowFromStationaryLights"] = "SetSingleSampleShadowFromStationaryLights",
    ["EnableSKMeshOptimization"] = "EnableSKMeshOptimization",
    ["bUseAttachParentBound"] = "bUseAttachParentBound",
    ["SetOverwriteLighting"] = "SetOverwriteLighting",

	--FString
    ["K2_AttachToComponent"] = "K2_AttachToComponent",
    ["SetLeaderPoseComponent"] = "SetLeaderPoseComponent",
    ["SetSkeletalMeshAsset"] = "SetSkeletalMeshAsset",
    ["SetOverlayMaterial"] = "SetOverlayMaterial",
	["SetOverrideMaterial"] = "SetOverrideMaterial",

	--Int32
    ["SetShadowPhysicsAssetForSkeletalMesh"] = "SetShadowPhysicsAssetForSkeletalMesh",
    ["SetForcedLOD"] = "SetForcedLOD",
};

function SkeletalMeshComV2_C:Execute(InSKData)

    -- local OwnerActor = self:GetActorByID(InSKData.OwnerActorID)
    -- if OwnerActor == nil then
    --     return
    -- end

    if InSKData.LightChannels == nil then
        InSKData.LightChannels = SkeletalMeshComV2_Data.EmptyTable
    end

    if InSKData.SocketName then
        table.insert(InSKData.StringParamNames, SkeletalMeshComV2_C.SkComFuncType.K2_AttachToComponent)
        table.insert(InSKData.StringValues, InSKData.SocketName)
    end

    if _G.UE_EDITOR then
        table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.AddInstanceComponent)
        table.insert(InSKData.BoolValues, true)
    end

    if InSKData.LeaderPoseComTag then
        table.insert(InSKData.StringParamNames, SkeletalMeshComV2_C.SkComFuncType.SetLeaderPoseComponent)
        table.insert(InSKData.StringValues, InSKData.LeaderPoseComTag)
    end

    table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.bUpdateOverlapsOnAnimationFinalize)
    table.insert(InSKData.BoolValues, false)

    table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.SetGenerateOverlapEvents)
    table.insert(InSKData.BoolValues, false)

    if InSKData.Tag == Enum.UECompositeComTagV2.Mesh and InSKData.CapsuleShadow_AssetID then
        table.insert(InSKData.IntParamNames, SkeletalMeshComV2_C.SkComFuncType.SetShadowPhysicsAssetForSkeletalMesh)
        table.insert(InSKData.IntValues, InSKData.CapsuleShadow_AssetID)
    end

    if InSKData.SkeletalMesh then
        table.insert(InSKData.StringParamNames, SkeletalMeshComV2_C.SkComFuncType.SetSkeletalMeshAsset)
        table.insert(InSKData.StringValues, InSKData.SkeletalMesh)
    end

    if InSKData.MaterialOverlay then
        table.insert(InSKData.StringParamNames, SkeletalMeshComV2_C.SkComFuncType.SetOverlayMaterial)
        table.insert(InSKData.StringValues, InSKData.MaterialOverlay)
    end

    if InSKData.bActiveTick ~= nil then
        table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.SetComponentTickEnabled)
        table.insert(InSKData.BoolValues, InSKData.bActiveTick)
    end
    
    if InSKData.bReceivesDecals ~= nil then
        table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.SetReceivesDecals)
        table.insert(InSKData.BoolValues, InSKData.bReceivesDecals)
    end

    if InSKData.bRenderCustomDepthPass ~= nil then
        table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.SetRenderCustomDepth)
        table.insert(InSKData.BoolValues, InSKData.bRenderCustomDepthPass)
    end

    if InSKData.bActive ~= nil then
        table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.SetActive)
        table.insert(InSKData.BoolValues, InSKData.bActive)
    end

    if InSKData.bVisibility ~= nil then
        table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.SetHiddenInGame)
        table.insert(InSKData.BoolValues, not InSKData.bVisibility)
    end

    if InSKData.bCastInsetShadow ~= nil then
        table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.SetCastInsetShadow)
        table.insert(InSKData.BoolValues, InSKData.bCastInsetShadow)
    end

    if InSKData.bSingleSampleShadowFromStationaryLights ~= nil then
        table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.SetSingleSampleShadowFromStationaryLights)
        table.insert(InSKData.BoolValues, InSKData.bSingleSampleShadowFromStationaryLights)
    end

    if InSKData.bEnableMeshOptimization ~= nil  then
        table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.EnableSKMeshOptimization)
        table.insert(InSKData.BoolValues, InSKData.bEnableMeshOptimization)
    end

    if InSKData.bUseAttachParentBound ~= nil then
        table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.bUseAttachParentBound)
        table.insert(InSKData.BoolValues, InSKData.bUseAttachParentBound)
    end

    if InSKData.bOverrideLighting then
        table.insert(InSKData.BoolParamNames, SkeletalMeshComV2_C.SkComFuncType.SetOverwriteLighting)
        table.insert(InSKData.BoolValues, InSKData.bOverrideLighting)
    end

    if InSKData.ForcedLOD then
        table.insert(InSKData.IntParamNames, SkeletalMeshComV2_C.SkComFuncType.SetForcedLOD)
        table.insert(InSKData.IntValues, InSKData.ForcedLOD)
    end

	if InSKData.OverrideMaterials then
		for slotName, materialPath in pairs(InSKData.OverrideMaterials) do
			table.insert(InSKData.StringParamNames, SkeletalMeshComV2_C.SkComFuncType.SetOverrideMaterial)
			table.insert(InSKData.StringValues, slotName .. ";" .. materialPath)
		end
	end

    -- end1 = os.clock()
    -- print("AAOG_AvatarTest2 MeshSK",tostring(end1 - start), tostring(InSKData.Tag))

    -- start = os.clock()

    local MeshCom, OutMeshModifyEvents = KGUECompositeOperateLibrary.SetSkeletalMeshComParams(InSKData.UID, _G.GetContextObject(), InSKData.OwnerActorID, InSKData.Tag, 
                                                                Game.UECompositeManager.SKEL_3CSKID, InSKData.LightChannels,
                                                                InSKData.BoolParamNames, InSKData.BoolValues,
                                                                InSKData.StringParamNames, InSKData.StringValues,
                                                                InSKData.IntParamNames, InSKData.IntValues)

    -- end1 = os.clock()
    -- print("AAOG_AvatarTest3 MeshSK",tostring(end1 - start), tostring(InSKData.Tag))
	
    if MeshCom then
        if InSKData.Offset then
            MeshCom:K2_SetRelativeTransform(InSKData.Offset, false, nil, false)
        end

        if Game.ActorAppearanceManager.EnableRenderSkeletonInstance then
            MeshCom:SetRenderSkeletonInstance(true)
        end

        if OutMeshModifyEvents then
            
            if Enum.UEActorMeshCBType.MeshChanged & OutMeshModifyEvents == Enum.UEActorMeshCBType.MeshChanged then
                --2次合并成一个
                if Enum.UEActorMeshCBType.MeshComCreate & OutMeshModifyEvents == Enum.UEActorMeshCBType.MeshComCreate then
                    self.UECompositeOperateLib:OnMeshComChanged(InSKData.OwnerActorID, MeshCom, Enum.UEActorMeshCBType.MeshComCreate)
                else
                    self.UECompositeOperateLib:OnMeshComChanged(InSKData.OwnerActorID, MeshCom, Enum.UEActorMeshCBType.MeshChanged)
                end
            else
                if Enum.UEActorMeshCBType.MeshComCreate & OutMeshModifyEvents == Enum.UEActorMeshCBType.MeshComCreate then
                    self.UECompositeOperateLib:OnMeshComChanged(InSKData.OwnerActorID, MeshCom, Enum.UEActorMeshCBType.MeshComCreate)
                end
            end
        end
		
		-- material follow, 对于丝袜黑丝白丝之类的材质, 脚和鞋子需要跟随下半身的材质. 
		local OwnerActor = Game.ObjectActorManager:GetObjectByID(InSKData.OwnerActorID)
		if OwnerActor then
			local UseLowerBodySkinTag = "UseLowerBodySkin"
			if OwnerActor:ActorHasTag(UseLowerBodySkinTag) then
				-- 移除, 如果有旧的Tag, 需要移除.
				if MeshCom:ComponentHasTag(UseLowerBodySkinTag) then
					SkeletalMeshComV2_C.RemoveTag(MeshCom.ComponentTags, UseLowerBodySkinTag)
					SkeletalMeshComV2_C.RemoveTag(OwnerActor.Tags, UseLowerBodySkinTag)
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
						if data.FollowerParts[i] == InSKData.Tag then
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
			if InSKData.MaterialFollowerTags then
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
	end

    -- if MeshCom == nil and InSKData.OwnerActorID then
    --     local OwnerActor = self:GetActorByID(InSKData.OwnerActorID)
    --     if OwnerActor then
    --         if InSKData.Tag then
    --             local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), InSKData.Tag)

    --             --做C++接口
    --             if InSKData.Tag == Enum.UECompositeComTag.Mesh then
    --                 if ActorComs:Length() == 0 and OwnerActor.GetMainMesh then
    --                     local MeshCom = OwnerActor:GetMainMesh()
    --                     if MeshCom then
    --                         MeshCom.ComponentTags:AddUnique(Enum.UECompositeComTag.Mesh)
    --                     end
    --                     ActorComs:Add(MeshCom)
    --                 end
    --             end

    --             if ActorComs:Length() > 0 then
    --                 MeshCom = ActorComs:Get(0)
    --             else
    --                 MeshCom = URoleCompositeFunc.RegisterActorComponent(OwnerActor, import("SkeletalMeshComponent"))
    --                 MeshCom.ComponentTags:AddUnique(InSKData.Tag)

    --                 self.UECompositeOperateLib:OnMeshComChanged(InSKData.OwnerActorID, MeshCom, Enum.UEActorMeshCBType.MeshComCreate)

    --                 local ParentCom = OwnerActor:K2_GetRootComponent()
    --                 if InSKData.AttachTargetTag ~= nil then
    --                     local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), InSKData.AttachTargetTag)
    --                     if ActorComs:Length() > 0 then
    --                         ParentCom = ActorComs:Get(0)
    --                     else
    --                         if InSKData.AttachTargetTag == Enum.UECompositeComTag.Mesh then
    --                             if ActorComs:Length() == 0 and OwnerActor.GetMainMesh then
    --                                 ParentCom = OwnerActor:GetMainMesh()
    --                             end
    --                         end
    --                     end
    --                 end

    --                 if ParentCom then
    --                     MeshCom:K2_AttachToComponent(ParentCom, InSKData.SocketName, EAttachmentRule.KeepRelative,
    --                     EAttachmentRule.KeepRelative, EAttachmentRule.KeepRelative, true)

    --                     if _G.UE_EDITOR then
    --                         --KGActorUtil.AddInstanceComponent(OwnerActor, MeshCom)

    --                         local TableBoolName = {}
    --                         local TableBoolValue = {}

    --                         table.insert(TableBoolName, "AddInstanceComponent")
    --                         table.insert(TableBoolValue, true)

    --                         KGUECompositeOperateLibrary.SetSkeletalMeshComParams(0, OwnerActor, InSKData.Tag, TableBoolName, TableBoolValue)
    --                     end
    --                 end
    --             end
    --         end

    --         if MeshCom and InSKData.LeaderPoseComTag ~= nil then
    --             local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), InSKData.LeaderPoseComTag)
    --             local LeaderMeshCom = nil
    --             if ActorComs:Length() > 0 then
    --                 LeaderMeshCom = ActorComs:Get(0)
    --             else
    --                 if InSKData.LeaderPoseComTag == Enum.UECompositeComTag.Mesh then
    --                     if OwnerActor.GetMainMesh then
    --                         LeaderMeshCom = OwnerActor:GetMainMesh()
    --                     end
    --                 end
    --             end

    --             if LeaderMeshCom then
    --                 MeshCom:SetLeaderPoseComponent(LeaderMeshCom, false, false)
    --             end
    --         end
    --     end
    -- end

    -- if MeshCom then
    --     -- 直接关闭动画更新引起的overlap, 是否要overlap统一走运动处理的流程
    --     MeshCom.bUpdateOverlapsOnAnimationFinalize = false
    --     -- 不使用generate overlap
    --     MeshCom:SetGenerateOverlapEvents(false)

    --     if InSKData.LightChannels then
    --         MeshCom:SetLightingChannels(InSKData.LightChannels [0] or false ,InSKData.LightChannels [1] or false, InSKData.LightChannels [2] or false)
    --     end

    --     ImportC7FunctionLibrary.EmptyMeshOverrideMaterials(MeshCom)

    --     local OwnerActor = Game.ObjectActorManager:GetObjectByID(InSKData.OwnerActorID)

    --     if IsStringValid(InSKData.SkeletalMesh) then
    --         local SKMeshAsset = self:GetAssetFromPath(InSKData.SkeletalMesh)
    --         if SKMeshAsset then
    --             if InSKData.Tag == Enum.UECompositeComTagV2.Mesh then
    --                 local NewSkeleton = SKMeshAsset:GetSkeleton()

    --                 --Capsule Shadow
    --                 --根据通用骨架来确定及类型来确定挂载资源
    --                 if NewSkeleton and InSKData.CapsuleShadow_AssetID then
    --                     if Game.UECompositeManager.SKEL_3CSKID == Game.ObjectActorManager:GetIDByObject(NewSkeleton) then
    --                         local _Asset = Game.ObjectActorManager:GetObjectByID(InSKData.CapsuleShadow_AssetID)
    --                         if _Asset and import("C7FunctionLibrary").SetShadowPhysicsAssetForSkeletalMesh then
    --                             import("C7FunctionLibrary").SetShadowPhysicsAssetForSkeletalMesh(SKMeshAsset, _Asset)

    --                             MeshCom:SetCastCapsuleIndirectShadow(true)
    --                             MeshCom:SetCapsuleIndirectShadowMinVisibility(0.5)
        
    --                             if InSKData.LightChannels then
    --                                 MeshCom:SetLightingChannels(InSKData.LightChannels [0] or false ,InSKData.LightChannels [1] or false, true)
    --                             end
    --                         end
    --                     end
    --                 end
    --             end

    --             MeshCom:SetSkeletalMeshAsset(SKMeshAsset)

    --             self.UECompositeOperateLib:OnMeshComChanged(InSKData.OwnerActorID, MeshCom, Enum.UEActorMeshCBType.MeshChanged)
    --         end
    --     end
        
    --     if InSKData.bActiveTick ~= nil then
    --         MeshCom:SetComponentTickEnabled(InSKData.bActiveTick)
    --     end
        
    --     if InSKData.bReceivesDecals ~= nil then
    --         MeshCom:SetReceivesDecals(InSKData.bReceivesDecals)
    --     end

    --     if InSKData.bRenderCustomDepthPass ~= nil then
    --         MeshCom:SetRenderCustomDepth(InSKData.bRenderCustomDepthPass)
    --     end

    --     if InSKData.bActive ~= nil then
    --         MeshCom:SetActive(InSKData.bActive, false)
    --     end

    --     if InSKData.bVisibility ~= nil then
    --         MeshCom:SetHiddenInGame(not InSKData.bVisibility, false)
    --     end

    --     if InSKData.bCastInsetShadow ~= nil then
    --         MeshCom:SetCastInsetShadow(InSKData.bCastInsetShadow)
    --     end

    --     if InSKData.bSingleSampleShadowFromStationaryLights ~= nil then
    --         MeshCom:SetSingleSampleShadowFromStationaryLights(InSKData.bSingleSampleShadowFromStationaryLights)
    --     end

    --     if InSKData.bEnableMeshOptimization ~= nil  then
    --         self:EnableSKMeshOptimizationV2(MeshCom, InSKData.bEnableMeshOptimization)
    --     end

    --     if InSKData.bUseAttachParentBound ~= nil then
    --         MeshCom.bUseAttachParentBound = InSKData.bUseAttachParentBound
    --     end

    --     if InSKData.bOverrideLighting then
    --         MeshCom:SetOverwriteLighting(InSKData.bOverrideLighting)
    --     end

    --     if InSKData.ForcedLOD then
	-- 		MeshCom:SetForcedLOD(InSKData.ForcedLOD)
	-- 	end

    --     if IsStringValid(InSKData.MaterialOverlay) then
    --         local MaterialOverlayAsset = self:GetAssetFromPath(InSKData.MaterialOverlay)
    --         if MaterialOverlayAsset then
    --             MeshCom:SetOverlayMaterial(MaterialOverlayAsset)
    --         end
    --     end

    --     if InSKData.BodyMeshSocketName then
    --         local OwnerActor = Game.ObjectActorManager:GetObjectByID(InSKData.OwnerActorID)
    --         if OwnerActor then
    --             local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), Enum.UECompositeComTagV2.Mesh)

    --             local ParentCom = nil

    --             if ActorComs:Length() == 0 and OwnerActor:GetMainMesh() ~= nil then
    --                 ParentCom = OwnerActor:GetMainMesh()
    --             else
    --                 ParentCom = ActorComs:Get(0)
    --             end
                
    --             if ParentCom then
    --                 MeshCom:K2_AttachToComponent(ParentCom, InSKData.BodyMeshSocketName, EAttachmentRule.KeepRelative,
    --                 EAttachmentRule.KeepRelative, EAttachmentRule.KeepRelative, true)
    --             end
    --         end
    --     end

    --     if InSKData.Offset then
    --         MeshCom:K2_SetRelativeTransform(InSKData.Offset, false, nil, false)
    --     end
    -- end

end

-- --开启Mesh优化
-- function SkeletalMeshComV2_C:EnableSKMeshOptimizationV2(Mesh, bEnable)

--     Mesh.bSkipKinematicUpdateWhenInterpolating = bEnable
--     Mesh.bSkipBoundsUpdateWhenInterpolating = bEnable
--     if bEnable then
--         UKGComponentUtil.SetMeshVisibilityBasedAnimTickOption(Mesh,EVisibilityBasedAnimTickOption.OnlyTickPoseWhenRendered)
--     else
--         UKGComponentUtil.SetMeshVisibilityBasedAnimTickOption(Mesh,EVisibilityBasedAnimTickOption.AlwaysTickPoseAndRefreshBones)
--     end

--     Mesh.KinematicBonesUpdateType = 1
--     Mesh.bComponentUseFixedSkelBounds = bEnable

--     if bEnable then
--         local MeshAsset
--         if Mesh:IsA(import("SkeletalMeshComponent")) then
--             MeshAsset = Mesh:GetSkeletalMeshAsset()
--         end

--         if MeshAsset and MeshAsset.ExtendedBounds and MeshAsset.PositiveBoundsExtension then
--             if not import("KismetMathLibrary").EqualEqual_VectorVector(MeshAsset.PositiveBoundsExtension, MeshAsset.ExtendedBounds.BoxExtent, 1e-4) then
--                 local OriginBound = MeshAsset:GetImportedBounds()
--                 local NewExtent = FVector()
--                 NewExtent.X = OriginBound.BoxExtent.X * 0.4 + 150
--                 NewExtent.Y = OriginBound.BoxExtent.Y * 0.4 + 150
--                 NewExtent.Z = OriginBound.BoxExtent.Z * 0.4 + 150


--                 import("LuaHelper").SetMeshPositiveBoundsExtension(MeshAsset, NewExtent)
--                 import("LuaHelper").SetMeshNegativeBoundsExtension(MeshAsset, NewExtent)
--             end
--         end
--     end
-- end

--SK归滚删除
function SkeletalMeshComV2_C:Rollback(InData, isNeedDelete)
    local OwnerActor = Game.ObjectActorManager:GetObjectByID(InData.OwnerActorID)
    if OwnerActor and InData.Tag ~= Enum.UECompositeComTagV2.Mesh then
        local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), InData.Tag)
        if ActorComs:Length() > 0 then
            local SKCom = ActorComs:Get(0)
            if SKCom then
                Game.UECompositeManager:OnMeshComChanged(InData.OwnerActorID, SKCom, Enum.UEActorMeshCBType.MeshComDestroy)
				if isNeedDelete == true then
					SKCom:K2_DestroyComponent(SKCom)
				end
            end
        end
    end
end

function SkeletalMeshComV2_C.RemoveTag(Tags, ToRemovedTag)
	for j = 0, Tags:Num() - 1 do
		if Tags:Get(j) == ToRemovedTag then
			Tags:Remove(j)
			return
		end
	end
end

---SK End---------------------------

---动画 Begin---------------------------

--模型身体数据
AnimV2_Data = DefineClass("AnimV2_Data", UEOperateDataBase)
AnimV2_Data.UECompositeType = Enum.UECompositeTypeV2.Anim
AnimV2_Data.AnimLibNameNone = "None"
function AnimV2_Data:ctor()

    self.UID = nil
    self.OwnerActorID = nil
    self.Tag = nil
    self.AnimConfigID = nil
    self.AnimClassPath = nil
    self.AnimAssetOverridePathMap = nil


    self.AnimAssetPathNames = {}
    self.AnimAssetPathValues={}
    self.AnimAssetOverridePathNames={}
    self.AnimAssetOverridePathValues={}

    -- if self.AnimAssetMap then
    --     self.AnimAssetMap:Clear()
    -- else
    --     self.AnimAssetMap = slua.Map(EPropertyClass.Name, EPropertyClass.Object,nil, AnimSequenceBaseClass)
    -- end

    -- if self.Override_AnimAssetMap then
    --     self.Override_AnimAssetMap:Clear()
    -- else
    --     self.Override_AnimAssetMap = slua.Map(EPropertyClass.Name, EPropertyClass.Object,nil, AnimSequenceBaseClass)
    -- end
end

AnimV2_C = DefineClass("AnimV2_C", CompositeOperateBaseV2)
AnimV2_C.OperateType = Enum.UECompositeTypeV2.Anim
AnimV2_C.UEOperateDataCls = AnimV2_Data

function AnimV2_C:ctor()
    --公用优化配置

    --公用TA设置
end

function AnimV2_C:GetData(AnimData)
    if AnimData == nil then
        AnimData = AnimV2_C.UEOperateDataCls:GetFreeData()
    end

    --公用设置


    return AnimData
end

function AnimV2_C:CollectAssetPath(InData, OutPaths)
    if IsStringValid(InData.AnimClassPath) then
        table.insert(OutPaths, InData.AnimClassPath)
    end

    --TODO 戴唯 动画路径仍需要遍历

    if IsStringValid(InData.AnimConfigID) then
		local PreLoadIDs, PreLoadAssets = AnimLibHelper.GetAnimPreLoadDataForLocomotion(InData.AnimConfigID)
        if PreLoadIDs and PreLoadAssets then
			table.move(PreLoadIDs, 1, #PreLoadIDs, #InData.AnimAssetPathNames + 1, InData.AnimAssetPathNames)
			table.move(PreLoadAssets, 1, #PreLoadAssets, #InData.AnimAssetPathValues + 1, InData.AnimAssetPathValues)
            table.move(PreLoadAssets, 1, #PreLoadAssets, #OutPaths + 1, OutPaths)
        end
    end

    if InData.AnimAssetOverridePathMap then
        for AssetID, _Path in pairs(InData.AnimAssetOverridePathMap) do
            if StringValid(_Path) then
                table.insert(InData.AnimAssetOverridePathNames, AssetID)
                table.insert(InData.AnimAssetOverridePathValues, _Path)
            end
        end

        table.move(InData.AnimAssetOverridePathValues, 1, #InData.AnimAssetOverridePathValues, #OutPaths + 1, OutPaths)
    end
end

function AnimV2_C:Execute(InData)

    local AnimLibName = InData.AnimConfigID
    if AnimLibName == nil then
        AnimLibName = AnimV2_Data.AnimLibNameNone
    end

    KGUECompositeOperateLibrary.SetAnimParams(InData.UID, _G.GetContextObject(), InData.OwnerActorID, InData.Tag, InData.AnimClassPath, AnimLibName, ViewAnimConst.ANIM_LOCO_CONTAINER.CONTAINER_SIZE,
        ViewAnimConst.ANIM_LOCO_CONTAINER.BASIC_LOCO_PRIORITY, ViewAnimConst.ANIM_LOCO_CONTAINER.BASIC_LOCO_SEMANTIC,
        ViewAnimConst.ANIM_LOCO_CONTAINER.MEDIUM_LOCO_PRIORITY, ViewAnimConst.ANIM_LOCO_CONTAINER.TEMP_LOCO_OVERRIDE_SEMANTIC,
        InData.AnimAssetPathNames, InData.AnimAssetPathValues,
        InData.AnimAssetOverridePathNames, InData.AnimAssetOverridePathValues)
    

    -- local MeshCom = nil
    -- local OwnerActor = Game.ObjectActorManager:GetObjectByID(InData.OwnerActorID)
    -- if OwnerActor then
    --     local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), InData.Tag)
    --     if ActorComs:Length() > 0 then
    --         MeshCom = ActorComs:Get(0)
    --     end
    -- end

    -- if MeshCom == nil then
    --     return
    -- end

    -- local _AnimClassAsset = self:GetAssetFromPath(InData.AnimClassPath)
    -- if _AnimClassAsset then
    --     if MeshCom:GetAnimClass() ~= _AnimClassAsset then
    --         MeshCom:SetAnimationMode(EAnimationMode.AnimationBlueprint, false)
    --         MeshCom:SetAnimClass(_AnimClassAsset)
    --         import("RoleCompositeMgr").RefreshBoneTransforms(MeshCom, true)
    --     end
    -- end

    -- InData.Override_AnimAssetMap:Clear()
    -- if InData.AnimAssetOverridePathMap then
    --     for AssetID, AnimPath in pairs(InData.AnimAssetOverridePathMap) do
    --         if StringValid(AnimPath) then
    --             local _AnimAsset = self:GetAssetFromPath(AnimPath)
    --             if _AnimAsset then
    --                 InData.Override_AnimAssetMap:Add(AssetID, _AnimAsset)
    --             end
    --         end
    --     end
    -- end

    -- InData.AnimAssetMap:Clear()
    -- if InData.AnimAssetPathMap then
    --     for AssetID, AnimPath in pairs(InData.AnimAssetPathMap) do
    --         if StringValid(AnimPath) then
    --             local _AnimAsset = self:GetAssetFromPath(AnimPath)
    --             if _AnimAsset then
    --                 InData.AnimAssetMap:Add(AssetID, _AnimAsset)
    --             end
    --         end
    --     end

        
    -- end

    -- local AnimIns = MeshCom:GetAnimInstance()
    -- if IsValid_L(AnimIns) then
    --     --AnimIns:SetAnimConfig("0", InData.Override_AnimAssetMap, InData.AnimAssetMap)

    --     --AnimIns:SetAnimConfig("0", self.AnimOverrideMap, self.AnimAssetMap)
	-- 	-- todo 这个流程最好还是往AfterLoadActor之后的entity流程放, 这里暂时先这里初始化临时处理
	-- 	local AnimLibName = InData.AnimConfigID
	-- 	if AnimLibName == nil then
	-- 		AnimLibName = "None"
	-- 	end
	-- 	AnimIns:InitLocoSequenceContainerSize(ViewAnimConst.ANIM_LOCO_CONTAINER.CONTAINER_SIZE, AnimLibName)
	-- 	-- todo 下面先裸操作, 等巍巍迭代完, 资源LoadID、资源asset map 通过参数带出去, 然后entity处理的过程中, 再AfterLoadActor中调用对应接口进行处理 
	-- 	AnimIns:ObtainLocoSequenceMappingWithPriorityIndex(ViewAnimConst.ANIM_LOCO_CONTAINER.BASIC_LOCO_PRIORITY, ViewAnimConst.ANIM_LOCO_CONTAINER.BASIC_LOCO_SEMANTIC, InData.AnimAssetMap)
	-- 	-- todo 下面这个是临时的, 等戴唯处理完后, 需要干掉 @戴唯
	-- 	AnimIns:ObtainLocoSequenceMappingWithPriorityIndex(ViewAnimConst.ANIM_LOCO_CONTAINER.MEDIUM_LOCO_PRIORITY, ViewAnimConst.ANIM_LOCO_CONTAINER.TEMP_LOCO_OVERRIDE_SEMANTIC, InData.Override_AnimAssetMap)
	-- 	-- todo 迭代后, 变成下面的逻辑 @孙亚 @巍巍
	-- 	--[[
	-- 	local logicEntity = Game.EntityManager:GetEntityByIntID(self.Data.UID)
	-- 	if logicEntity ~= nil then
	-- 		-- 这里临时处理, 后续要批量加载后的ID
	-- 		-- AnimLoadAssets 要根据动作库导出的语义进行分类的
	-- 		logicEntity:SetRetainedAnimLoadID(animLoadID, AnimIns, AnimLoadAssets)
	-- 	end
	-- 	]]--
    -- end



end


---动画 End---------------------------

--材质 Begin---------------------------
MaterialV2_Data = DefineClass("MaterialV2_Data", UEOperateDataBase)
MaterialV2_Data.UECompositeType = Enum.UECompositeTypeV2.Material

MaterialV2_Data.EyeLashSlotName = "EyeLash"

function MaterialV2_Data:ctor()
    self.OwnerActorID = nil
    self.UID = nil
    self.Tag = nil

    self.MeshMaterialData = nil
    self.MakeupProfileName = nil
    self.MakeupCaptureMaterials = nil
    self.CaptureMaterialData = nil

    self.MainMaterialPath = nil
    self.EyeLashMaterialPath = nil
	
	-- Head和其他部件执行逻辑是不一样的,这里就分开
	self.OverrideBodyPartMakeupData = nil
	
	-- =======进行直接刷新材质效果的流程===========
	-- todo 这里差释放的逻辑  @孙亚
	self.OverrideAssetLoadID = nil -- 如果单位的整体数据被释放了, 这里回池的时候
	self.RemovedOverrideAssetPaths = nil
	self.AddedOverrideAssetPaths = nil
	self.ExecuteCallbackObj = nil
	self.ExecuteCallbackName = nil
end

local TEMP_PATH_MAPPING = {}
local TEMP_OLD_ASSET_PATHS = {}
local TEMP_NEW_ASSET_PATHS = {}
function MaterialV2_Data:ExecuteOverrideHeadMakeUpData(OverrideMakeUpData, CallbackObj, CallbackName)
	if self.OverrideAssetLoadID ~= nil then
		Log.ErrorFormat("[ExecuteOverrideHeadMakeUpData] Already has Waiting LoadID:%s", self.OverrideAssetLoadID)
		return false
	end
	
	self.CallbackObj = CallbackObj
	self.CallbackName = CallbackName

	if self.OverrideBodyPartMakeupData ~= nil and self.OverrideBodyPartMakeupData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_RES_DATA] then
		table.clear(TEMP_OLD_ASSET_PATHS)
		for k, v in pairs(self.OverrideBodyPartMakeupData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_RES_DATA]) do
			TEMP_OLD_ASSET_PATHS[k] = v
		end
	end
	if not NoNeedCopy then
		if OverrideMakeUpData ~= nil then
			if self.OverrideBodyPartMakeupData == nil then
				self.OverrideBodyPartMakeupData = {
					[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_PARAM_DATA] =  {},
					[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_RES_DATA] =  {},
				}
			end

			local resData = self.OverrideBodyPartMakeupData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_RES_DATA]
			table.clear(resData)
			for k, v in pairs(OverrideMakeUpData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_RES_DATA]) do
				resData[k] = v
			end

			local paramData = self.OverrideBodyPartMakeupData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_PARAM_DATA]
			table.clear(paramData)
			for k, v in pairs(OverrideMakeUpData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_PARAM_DATA]) do
				paramData[k] = v
			end
		end

	else
		self.OverrideBodyPartMakeupData = OverrideMakeUpData
	end
	
	if self.OverrideBodyPartMakeupData ~= nil and self.OverrideBodyPartMakeupData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_RES_DATA] then
		table.clear(TEMP_NEW_ASSET_PATHS)
		for k, v in pairs(self.OverrideBodyPartMakeupData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_RES_DATA]) do
			TEMP_NEW_ASSET_PATHS[k] = v
		end
	end

	table.clear(TEMP_PATH_MAPPING)
	if self.RemovedOverrideAssetPaths ~= nil then
		table.clear(self.RemovedOverrideAssetPaths)
	end

	if self.AddedOverrideAssetPaths ~= nil then
		table.clear(self.AddedOverrideAssetPaths)
	end

	if TEMP_NEW_ASSET_PATHS ~= nil then
		for paramKey, texturePath in pairs(TEMP_NEW_ASSET_PATHS) do
			TEMP_PATH_MAPPING[texturePath] = 1
		end
	end

	if TEMP_OLD_ASSET_PATHS ~= nil then
		for paramKey, texturePath in pairs(TEMP_OLD_ASSET_PATHS) do
			if TEMP_PATH_MAPPING[texturePath] ~= 1 then
				if self.RemovedOverrideAssetPaths == nil then
					self.RemovedOverrideAssetPaths = {}
				end
				-- new数据中不在, 就要移除
				table.insert(self.RemovedOverrideAssetPaths, texturePath)
			else
				-- new数据存在, 直接复用
				TEMP_PATH_MAPPING[texturePath] = nil
			end
		end
	end

	for texturePath, _ in pairs(TEMP_PATH_MAPPING) do
		if self.AddedOverrideAssetPaths == nil then
			self.AddedOverrideAssetPaths = {}
		end
		table.insert(self.AddedOverrideAssetPaths, texturePath)
	end
	
	self.OverrideAssetLoadID = nil
	
	if self.AddedOverrideAssetPaths ~= nil and #self.AddedOverrideAssetPaths > 0 then
		self.OverrideAssetLoadID = Game.AssetManager:AsyncLoadAssetListKeepReference(self.AddedOverrideAssetPaths, self, "LoadAssetCallbackForOverrideHeadMakeUpData")
		return true
	end

	if self.RemovedOverrideAssetPaths ~= nil and #self.RemovedOverrideAssetPaths > 0 then
		Game.RoleCompositeMgr:RemoveActorAppearanceAssetRefByPaths(self.UID, self.RemovedOverrideAssetPaths)
		table.clear(self.RemovedOverrideAssetPaths)
	end

	MaterialV2_C.Execute(nil, self)

	if self.CallbackObj ~= nil then
		self.CallbackObj[self.CallbackName](self.CallbackObj, true, self.UID)
		self.CallbackObj = nil
		self.CallbackName = nil
	end

	return true
end

local TEMP_SINGLE_ASSET_TABLE = {[1]=nil}
function MaterialV2_Data:LoadAssetCallbackForOverrideHeadMakeUpData(LoadID, Assets)
	-- 异步流程, 对不上, 放弃后续流程
	if self.OverrideAssetLoadID ~= LoadID then
		Game.AssetManager:RemoveAssetReferenceByLoadID(LoadID)
		return false
	end
	
	if self.RemovedOverrideAssetPaths ~= nil and #self.RemovedOverrideAssetPaths > 0 then
		Game.RoleCompositeMgr:RemoveActorAppearanceAssetRefByPaths(self.UID, self.RemovedOverrideAssetPaths)
		table.clear(self.RemovedOverrideAssetPaths)
	end

	if #self.AddedOverrideAssetPaths == 1 then
		TEMP_SINGLE_ASSET_TABLE[1] = Assets
		Game.RoleCompositeMgr:AddActorAppearanceAssetRef(self.UID, self.AddedOverrideAssetPaths, TEMP_SINGLE_ASSET_TABLE, false)
		TEMP_SINGLE_ASSET_TABLE[1] = nil
	else
		Game.RoleCompositeMgr:AddActorAppearanceAssetRef(self.UID, self.AddedOverrideAssetPaths, Assets, false)
	end

	Game.AssetManager:RemoveAssetReferenceByLoadID(self.OverrideAssetLoadID)
	self.OverrideAssetLoadID = nil

	MaterialV2_C.Execute(nil, self)

	if self.CallbackObj ~= nil then
		self.CallbackObj[self.CallbackName](self.CallbackObj, true, self.UID)
		self.CallbackObj = nil
		self.CallbackName = nil
	end
	
end



MaterialV2_C = DefineClass("MaterialV2_C", CompositeOperateBaseV2)
MaterialV2_C.OperateType = Enum.UECompositeTypeV2.Material
MaterialV2_C.UEOperateDataCls = MaterialV2_Data

function MaterialV2_C:ctor()
    --公用优化配置
	
    --公用TA设置
end

function MaterialV2_C:GetData(InData)
    if InData == nil then
        InData = MaterialV2_C.UEOperateDataCls:GetFreeData()
    end
    
	
    return InData
end

function MaterialV2_C:CollectAssetPath(InData, OutPaths)
    if InData.MeshMaterialData and InData.MeshMaterialData.CompositeMeshMaterialDataMap then
        for k, MaterialData in pairs(InData.MeshMaterialData.CompositeMeshMaterialDataMap:ToTable()) do
            if MaterialData.TexturePaths then
                local TexturePaths = MaterialData.TexturePaths:ToTable()
                table.move(TexturePaths, 1, #TexturePaths, #OutPaths + 1, OutPaths)
            end
        end
    end


    if InData.MakeupCaptureMaterials then
        table.move(InData.MakeupCaptureMaterials, 1, #InData.MakeupCaptureMaterials, #OutPaths + 1, OutPaths)
    end
	
	-- todo 这里totable其实可以工具导出直接生成需要的, 这里每次totable都是有GC问题的 @刘瑞林
    if InData.CaptureMaterialData and InData.CaptureMaterialData.CompositeCaptureMaterialDataMap then
        for k, MaterialData in pairs(InData.CaptureMaterialData.CompositeCaptureMaterialDataMap:ToTable()) do
            if MaterialData.TexturePaths then
                local TexturePaths = MaterialData.TexturePaths:ToTable()
                table.move(TexturePaths, 1, #TexturePaths, #OutPaths + 1, OutPaths)
            end
        end
    end
	if InData.OverrideBodyPartMakeupData ~= nil and InData.OverrideBodyPartMakeupData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_RES_DATA] then
		local TexturePaths = InData.OverrideBodyPartMakeupData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_RES_DATA]
		if TexturePaths ~= nil then
			for _, texturePath in pairs(TexturePaths) do
				table.insert(OutPaths,  texturePath)
			end
		end
	end
	
    if IsStringValid(InData.MainMaterialPath) then
        table.insert(OutPaths, #OutPaths + 1, InData.MainMaterialPath)
    end

    if IsStringValid(InData.EyeLashMaterialPath) then
        table.insert(OutPaths, #OutPaths + 1, InData.EyeLashMaterialPath)
    end
end

local TEMP_HEAD_MAT_MAPPING = {}
local TEMP_PARTS_MAT_MAPPING = {}

function MaterialV2_C:Execute(InData)
    local MeshCom = nil
    local OwnerActor = Game.ObjectActorManager:GetObjectByID(InData.OwnerActorID)
    if OwnerActor then
        local ActorComs = OwnerActor:GetComponentsByTag(MeshComponentClass, InData.Tag)
        if ActorComs:Length() > 0 then
            MeshCom = ActorComs:Get(0)
        end
    end

    if MeshCom == nil or InData.UID == nil then
        return
    end


    if InData.MeshMaterialData then
		-- todo 这里有一个坑, 没有刷part
        KGUECompositeOperateLibrary.SetMeshMaterialParameter(InData.UID,_G.ContextObject, MeshCom, InData.MeshMaterialData)--  profile 預設數據--->漂染數據--->膚色同步(哪些參數要做膚色同步?  在c+ 接口的地方直接按照poart 受擊)
    end
	
    if InData.MainMaterialPath and InData.EyeLashMaterialPath then
        KGUECompositeOperateLibrary.ChangeModelDefaultMaterial(InData.UID, _G.ContextObject, MeshCom, InData.MainMaterialPath, MaterialV2_Data.EyeLashSlotName, InData.EyeLashMaterialPath)
    end

	if Enum.EAvatarBodyPartTypeName[Enum.EAvatarBodyPartType.Head] == InData.Tag then
		if InData.MakeupCaptureMaterials and InData.MakeupProfileName then
			local FaceControlComponent = OwnerActor:GetComponentByClass(import("FaceControlComponent"))
			if FaceControlComponent then
				-- 先做基础预设数据
				--KGUECompositeOperateLibrary.InitHeadMakeupRuntimeMaterial(InData.UID, _G.ContextObject, FaceControlComponent, InData.MakeupProfileName, InData.MakeupCaptureMaterials, MeshCom);

				FaceControlComponent:InitHeadMakeupRuntimeMaterial(InData.MakeupProfileName, InData.MakeupCaptureMaterials, MeshCom)
				if InData.CaptureMaterialData then
					KGUECompositeOperateLibrary.FaceSetMeshMaterialParameter(InData.UID, _G.ContextObject, FaceControlComponent, InData.CaptureMaterialData)
				end

				-- 再做头部的override数据设置
				if InData.OverrideBodyPartMakeupData ~= nil then
					-- todo C++版本的设置函数 @刘瑞林; 做完后使用字符串数据
					--KGUECompositeOperateLibrary.SeteMaterialParameterFromMakeupSerializedData(InData.UID, _G.ContextObject, MeshCom, InData.MakeupProfileName, InData.OverrideBodyPartMakeupData)
					local makeupParamData = InData.OverrideBodyPartMakeupData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_PARAM_DATA]
					if makeupParamData ~= nil then
						MaterialV2_C.ApplyHeadMakeupParams(InData, OwnerActor, MeshCom, makeupParamData)
					end

					local makeupResData = InData.OverrideBodyPartMakeupData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_RES_DATA]
					if makeupResData ~= nil  then
						MaterialV2_C.ApplyHeadMakeupParams(InData, OwnerActor, MeshCom, makeupResData)
					end
				end

				FaceControlComponent:ApplyHeadMakeupData()
			end
		end
		
	else
		if InData.OverrideBodyPartMakeupData ~= nil then
			-- todo C++版本的设置函数 @刘瑞林; 做完后使用字符串数据
			--KGUECompositeOperateLibrary.SeteMaterialParameterFromMakeupSerializedData(InData.UID, _G.ContextObject, MeshCom, InData.MakeupProfileName, InData.OverrideBodyPartMakeupData)
			local makeupParamData = InData.OverrideBodyPartMakeupData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_PARAM_DATA]
			if makeupParamData ~= nil then
				MaterialV2_C.ApplyNonHeadMakeupParams(InData, OwnerActor, MeshCom, makeupParamData)
			end

			local makeupResData = InData.OverrideBodyPartMakeupData[ViewControlConst.MAKEUP_DATA_KEY.MAKEUP_RES_DATA]
			if makeupResData ~= nil  then
				MaterialV2_C.ApplyNonHeadMakeupParams(InData, OwnerActor, MeshCom, makeupResData)
			end
		end
	end

end

-- 留的脚本接口, 后面如果C++版本线上问题修复不了, 用这个接口进行处理
function MaterialV2_C.ApplyNonHeadMakeupParams(InData, OwnerActor, MeshCom, OverrideHeadMakeupParams )
	local MeshCompId = Game.ObjectActorManager:GetIDByObject(MeshCom)
	local Profiles = G_RoleCompositeMgr.AvatarProfileLib[InData.MakeupProfileName].MakeupProfile
	local matManager = Game.MaterialManager
	-- todo 临时使用分开设置
	for paramKey, paramValue in pairs(OverrideHeadMakeupParams) do
		local ProfileTemplateData = Profiles[paramKey]
		local Material = TEMP_HEAD_MAT_MAPPING[ProfileTemplateData.SlotName]
		if Material == nil then
			local SlotIndex = MeshCom:GetMaterialIndex(ProfileTemplateData.SlotName)
			Material = matManager:GetMaterialInstance(InData.OwnerActorID, MeshCompId, SlotIndex, false, false)
			TEMP_HEAD_MAT_MAPPING[ProfileTemplateData.SlotName] = Material
		end

		local DataType = ProfileTemplateData.Type
		local realValue = nil
		if DataType == Enum.EMakeupPropertyType.Float then
			realValue = (ProfileTemplateData.MaxValue - ProfileTemplateData.MinValue) * paramValue + ProfileTemplateData.MinValue
			Material:SetScalarParameterValue(ProfileTemplateData.MaterialPropertyName, realValue)
		elseif DataType == Enum.EMakeupPropertyType.Color then
			realValue = paramValue
			Material:SetVectorParameterValue(ProfileTemplateData.MaterialPropertyName, realValue)
		elseif DataType == Enum.EMakeupPropertyType.Texture then
			realValue = Game.RoleCompositeMgr:GetActorAppearanceAsset(InData.UID, paramValue)
			Material:SetTextureParameterValue(ProfileTemplateData.MaterialPropertyName, realValue)
		else
			-- todo 补全贴图
			Log.ErrorFormat("[ApplyNonHeadMakeupParams] MakeupDataModify Not Supported, type:%s  param name:%s  value:%s", DataType, paramKey, paramValue)
		end

	end
end

-- 留的脚本接口, 后面如果C++版本线上问题修复不了, 用这个接口进行处理
function MaterialV2_C.ApplyHeadMakeupParams(InData, OwnerActor, MeshCom, OverrideHeadMakeupParams )
	table.clear(TEMP_HEAD_MAT_MAPPING)
	table.clear(TEMP_PARTS_MAT_MAPPING)
	
	local Profiles = G_RoleCompositeMgr.AvatarProfileLib[InData.MakeupProfileName].MakeupProfile
	local matManager = Game.MaterialManager
	local FaceControlComponent = OwnerActor:GetComponentByClass(import("FaceControlComponent"))
	for paramKey, paramValue in pairs(OverrideHeadMakeupParams) do
		local ProfileTemplateData = Profiles[paramKey]
		local DataType = ProfileTemplateData.Type
		local realValue = nil
		if DataType == Enum.EMakeupPropertyType.Float then
			realValue = (ProfileTemplateData.MaxValue - ProfileTemplateData.MinValue) * paramValue + ProfileTemplateData.MinValue
			FaceControlComponent:SetScalarParameterValueByCompositeIndex(ProfileTemplateData.CaptureMaterialIndex, ProfileTemplateData.MaterialPropertyName, realValue)
		elseif DataType == Enum.EMakeupPropertyType.Color then
			realValue = paramValue
			FaceControlComponent:SetVectorParameterValueByCompositeIndex(ProfileTemplateData.CaptureMaterialIndex, ProfileTemplateData.MaterialPropertyName, realValue)
		elseif DataType == Enum.EMakeupPropertyType.Texture then
			realValue = Game.RoleCompositeMgr:GetActorAppearanceAsset(InData.UID, paramValue)
			FaceControlComponent:SetTextureParameterValueByCompositeIndex(ProfileTemplateData.CaptureMaterialIndex, ProfileTemplateData.MaterialPropertyName, realValue)
			--FaceControlComponent:SetTextureParameterValue(0, ProfileTemplateData.MaterialPropertyName, realValue)
		else
			-- todo 补全贴图
			Log.ErrorFormat("[ApplyHeadMakeupParams] MakeupDataModify Not Supported, type:%s  param name:%s  value:%s", DataType, paramKey, paramValue)
		end
		
		-- 头部材质参数, 会需要进行肤色同步的逻辑, 看ProfileTemplateData数据中的OtherPartAndSlots部分
		if ProfileTemplateData.OtherPartAndSlots and #ProfileTemplateData.OtherPartAndSlots > 0 then
			for _, PartAndSlotData in pairs(ProfileTemplateData.OtherPartAndSlots) do

				local partMeshMatMapping = TEMP_PARTS_MAT_MAPPING[PartAndSlotData.BodyPartType]
				if partMeshMatMapping == nil then
					partMeshMatMapping = {}
					TEMP_PARTS_MAT_MAPPING[PartAndSlotData.BodyPartType] = partMeshMatMapping
				end

				local partMeshMat = partMeshMatMapping[PartAndSlotData.SlotName]
				if partMeshMat == nil then
					local Components = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), Enum.EAvatarBodyPartTypeName[PartAndSlotData.BodyPartType])
					local partMeshCom = Components:Get(0)
					local SlotIndex = MeshCom:GetMaterialIndex(PartAndSlotData.SlotName)
					local PartMeshCompId = Game.ObjectActorManager:GetIDByObject(partMeshCom)
					partMeshMat = matManager:GetMaterialInstance(InData.OwnerActorID, PartMeshCompId, SlotIndex, false, false)
					partMeshMatMapping[ProfileTemplateData.SlotName] = partMeshMat
				end

				if DataType == Enum.EMakeupPropertyType.Float then
					partMeshMat:SetScalarParameterValue(ProfileTemplateData.MaterialPropertyName, realValue)
				elseif DataType == Enum.EMakeupPropertyType.Color then
					partMeshMat:SetVectorParameterValue(ProfileTemplateData.MaterialPropertyName, realValue)
				elseif DataType == Enum.EMakeupPropertyType.Texture then
					partMeshMat:SetTextureParameterValue(ProfileTemplateData.MaterialPropertyName, realValue)
				else
					Log.ErrorFormat("MakeupDataModifyOtherPart Not Supported, type:%s   param name:%s", DataType, (ProfileTemplateData.MaterialPropertyName))
				end
			end
		end

	end

	table.clear(TEMP_HEAD_MAT_MAPPING)
	table.clear(TEMP_PARTS_MAT_MAPPING)
end


--材质 End---------------------------

CapsuleV2_Data = DefineClass("CapsuleV2_Data", UEOperateDataBase)
CapsuleV2_Data.UECompositeType = Enum.UECompositeTypeV2.Capsule
function CapsuleV2_Data:ctor()
    self.OwnerActorID = nil

    self.CapsuleHalfHeight = nil
    self.CapsuleRadius = nil
end

CapsuleV2_C = DefineClass("CapsuleV2_C", CompositeOperateBaseV2)
CapsuleV2_C.OperateType = Enum.UECompositeTypeV2.Capsule
CapsuleV2_C.UEOperateDataCls = CapsuleV2_Data


function CapsuleV2_C:GetData(InData)
    if InData == nil then
        InData = CapsuleV2_C.UEOperateDataCls:GetFreeData()
    end
    
    return InData
end

function CapsuleV2_C:Execute(InData)

    if InData.CapsuleHalfHeight and InData.CapsuleRadius then
        local OwnerActor = Game.ObjectActorManager:GetObjectByID(InData.OwnerActorID)
        if OwnerActor then
			local CapsuleCom
			if OwnerActor.GetCapsule then
				CapsuleCom = OwnerActor:GetCapsule()
			else
				-- NOTE 仅场编下用，场编预览的Actor继承链不一样
				CapsuleCom = OwnerActor:GetComponentByClass(import("CapsuleComponent"))
			end
			if CapsuleCom then
				CapsuleCom:SetCapsuleSize(InData.CapsuleRadius, InData.CapsuleHalfHeight, true)
			end
        end
    end
end

--受击盒
HitBoxV2_Data = DefineClass("HitBoxV2_Data", UEOperateDataBase)
HitBoxV2_Data.UECompositeType = Enum.UECompositeTypeV2.HitBox
HitBoxV2_Data.HitBoxTag = "HitBoxTag"
HitBoxV2_Data.Empty_Hit_Result = HitResultClass()
function HitBoxV2_Data:ctor()
    self.OwnerActorID = nil

    self.BoxExtent = nil
    self.Offset = nil
    self.ParentSocket = ""
end

HitBoxV2_C = DefineClass("HitBoxV2_C", CompositeOperateBaseV2)
HitBoxV2_C.OperateType = Enum.UECompositeTypeV2.HitBox
HitBoxV2_C.UEOperateDataCls = HitBoxV2_Data

function HitBoxV2_C:GetData(InData)
    if InData == nil then
        InData = HitBoxV2_C.UEOperateDataCls:GetFreeData()
    end
    
    return InData
end

function HitBoxV2_C:Execute(InData)

    if InData.BoxExtent and InData.Offset and InData.ParentSocket then
        local OwnerActor = Game.ObjectActorManager:GetObjectByID(InData.OwnerActorID)
        if OwnerActor then
            local HitBoxCom = nil
            local ActorComs = OwnerActor:GetComponentsByTag(BoxComponentClass, HitBoxV2_Data.HitBoxTag)
            if ActorComs:Length() > 0 then
                HitBoxCom = ActorComs:Get(0)
            else
                HitBoxCom = URoleCompositeFunc.RegisterActorComponent(OwnerActor, BoxComponentClass)
            end

            if HitBoxCom and OwnerActor.GetMainMesh then
                local MainMeh = OwnerActor:GetMainMesh()
                if MainMeh then
                    HitBoxCom:K2_AttachToComponent(MainMeh, InData.ParentSocket, EAttachmentRule.SnapToTarget, EAttachmentRule.SnapToTarget, EAttachmentRule.SnapToTarget, true)
                    HitBoxCom:K2_SetRelativeTransform(InData.Offset, false, HitBoxV2_Data.Empty_Hit_Result, false)
                    HitBoxCom:SetBoxExtent(InData.BoxExtent, true)
                end
            end
        end
    end
end

--预设体型
BodyShapeV2_Data = DefineClass("BodyShapeV2_Data", UEOperateDataBase)
BodyShapeV2_Data.UECompositeType = Enum.UECompositeTypeV2.BodyShape
function BodyShapeV2_Data:ctor()
    self.OwnerActorID = nil

    self.ProfileName = nil --预设体型
    self.FaceCompactData = nil --骨骼自定义形变参数, 预设
	self.BodyCompactData = nil --骨骼自定义形变参数, 预设
	self.OverrideAllBodyShapeData = nil  -- 捏脸、捏骨都是放在一起的
end

function BodyShapeV2_Data:ExecuteOverrideBodyShape(OverrideBodyShapeData)
	self.OverrideAllBodyShapeData = OverrideBodyShapeData

	BodyShapeV2_C.Execute(nil, self)
	return true
end

BodyShapeV2_C = DefineClass("BodyShapeV2_C", CompositeOperateBaseV2)
BodyShapeV2_C.OperateType = Enum.UECompositeTypeV2.BodyShape
BodyShapeV2_C.UEOperateDataCls = BodyShapeV2_Data

function BodyShapeV2_C:GetData(InData)
    if InData == nil then
        InData = BodyShapeV2_C.UEOperateDataCls:GetFreeData()
    end
    
    return InData
end

FaceControlComponentCls = import("FaceControlComponent")
function BodyShapeV2_C:Execute(InData)
    local OwnerActor = Game.ObjectActorManager:GetObjectByID(InData.OwnerActorID)
    if OwnerActor then

		local FaceControlComponent = OwnerActor:GetComponentByClass(FaceControlComponentCls)
		
		-- 需要保障按需挂脸部component @胡江龙
		if FaceControlComponent == nil then
			return false
		end
		
		if InData.FaceCompactData ~= nil then
			FaceControlComponent:SetFaceDataRuntimeDiff(InData.ProfileName, InData.FaceCompactData)
		end

		if InData.BodyCompactData ~= nil then
			FaceControlComponent:SetFaceDataRuntimeDiff(InData.ProfileName, InData.BodyCompactData)
		end

		if InData.OverrideAllBodyShapeData ~= nil then
			FaceControlComponent:SetFaceDataRuntimeDiff(InData.ProfileName, InData.OverrideAllBodyShapeData)
		end
    end
end

--特效
EffectV2_Data = DefineClass("EffectV2_Data", UEOperateDataBase)
EffectV2_Data.UECompositeType = Enum.UECompositeTypeV2.Effect
EffectV2_Data.CompositeEffectTag = "CompositeEffectTag"
function EffectV2_Data:ctor()
    self.OwnerActorID = nil
    self.UID = nil

    self.EffectDatas = nil
    self.Tag = Enum.UECompositeComTagV2.Mesh
end

EffectV2_C = DefineClass("EffectV2_C", CompositeOperateBaseV2)
EffectV2_C.OperateType = Enum.UECompositeTypeV2.Effect
EffectV2_C.UEOperateDataCls = EffectV2_Data

function EffectV2_C:GetData(InData)
    if InData == nil then
        InData = EffectV2_C.UEOperateDataCls:GetFreeData()
    end
    
    return InData
end

function EffectV2_C:CollectAssetPath(InData, OutPaths)
    for key, EffectData in pairs(InData.EffectDatas) do
        if IsStringValid(EffectData.NS_Effect) then
            table.insert(OutPaths, #OutPaths + 1, EffectData.NS_Effect)
        end
    end
end

function EffectV2_C:Execute(InData)
    local OwnerActor = Game.ObjectActorManager:GetObjectByID(InData.OwnerActorID)
    if OwnerActor then
        local ActorComs = OwnerActor:GetComponentsByTag(import("SkeletalMeshComponent"), InData.Tag)
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

        --c++ 后续考虑固化
        for key, EffectData in pairs(InData.EffectDatas) do
            if IsStringValid(EffectData.NS_Effect) then
                local EffectAsset = self:GetAssetFromPath(EffectData.NS_Effect)
                if EffectAsset then

					-- 组装流程不一定都有entity, 没有的不用走culling流程
					local NiagaraBudgetToken
					local EffectPriority = EffectData.Priority and EffectData.Priority or 2
					if InData.UID then
						local Entity = Game.EntityManager:getEntity(InData.UID)
						if Entity then
							local CharacterTypeForViewBudget = Entity:GetCharacterTypeForViewBudget()
							-- 外观特效优先级默认按medium来
							local bCanPlayNiagara, BudgetToken = Game.EffectManager:TryObtainNiagaraBudget(
								CharacterTypeForViewBudget, NIAGARA_EFFECT_TYPE_FOR_PRIORITY_CULLING.APPEARANCE, OwnerActor, EffectPriority)
							if not bCanPlayNiagara then
								goto continue
							end
							NiagaraBudgetToken = BudgetToken
						end
					end
					
                    -- todo 这里没有entity id 使用连线特效可能会出问题
                    local NiagaraEffectParam = NiagaraEffectParamTemplate.AllocFromPool()
                    NiagaraEffectParam.NiagaraAssetId = Game.ObjectActorManager:GetIDByObject(EffectAsset)
                    NiagaraEffectParam.AttachPointName = EffectData.Socket
                    NiagaraEffectParam.bNeedAttach = true
                    NiagaraEffectParam.SpawnerId = Game.ObjectActorManager:GetIDByObject(OwnerActor)
                    NiagaraEffectParam.AttachComponentId = MeshCompId
                    NiagaraEffectParam.bActivateImmediately = true
					NiagaraEffectParam.NiagaraBudgetToken = NiagaraBudgetToken
					NiagaraEffectParam.NiagaraEffectType = NIAGARA_EFFECT_TYPE_FOR_PRIORITY_CULLING.APPEARANCE
					NiagaraEffectParam.CustomNiagaraPriority = EffectPriority
                    NiagaraEffectParam.ComponentTags = {EffectV2_Data.CompositeEffectTag}
                    table.insert(NiagaraEffectParam.ComponentTags, Enum.UECompositeComTag.Mesh)
					table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.APPEARANCE)

                    -- 确认下是否组装特效要用battle
                    NiagaraEffectParam.SourceType = NIAGARA_SOURCE_TYPE.BATTLE

                    if EffectData.Offset then
                        M3D.ToTransform(EffectData.Offset, NiagaraEffectParam.SpawnTrans)
                    end

                    if EffectData.FilteredBones and next(EffectData.FilteredBones) ~= nil then
                        NiagaraEffectParam.UserVals_SkeletalMeshCompIds = {}
                        NiagaraEffectParam.UserVals_SkeletalMeshCompFilterBones = {}
                        NiagaraEffectParam.UserVals_SkeletalMeshCompIds["SKMesh"] = MeshCompId
                        NiagaraEffectParam.UserVals_SkeletalMeshCompFilterBones["SKMesh"] = EffectData.FilteredBones
                    end

                    Game.EffectManager:CreateNiagaraSystem(NiagaraEffectParam)
					
					::continue::
                end
            end
        end
    end
end


function UECompositeOperateLib:ctor()
    self.CompositeOperateClassMap = {}
end

function UECompositeOperateLib:dtor()

end

function UECompositeOperateLib:RegisterOperate(OperateCls, OperateDataPoolSize)
    OperateCls.UEOperateDataCls.MemoryAlloc:AssignPoolSize(OperateCls.UEOperateDataCls, OperateDataPoolSize)

    self.CompositeOperateClassMap[OperateCls.OperateType] = OperateCls
end

function UECompositeOperateLib:Init(MemoryAlloc)
    UEOperateDataBase.MemoryAlloc = MemoryAlloc

    self:RegisterOperate(SkeletalMeshComV2_C, 600)
    self:RegisterOperate(AnimV2_C, 100)
    self:RegisterOperate(MaterialV2_C, 1000)
    self:RegisterOperate(CapsuleV2_C, 100)
    self:RegisterOperate(HitBoxV2_C, 10)
    self:RegisterOperate(BodyShapeV2_C, 30)
    self:RegisterOperate(EffectV2_C, 30)
end



function UECompositeOperateLib:GetOperateByType(OperateType)
    local OpClass = self.CompositeOperateClassMap[OperateType]
    if OpClass then
        local NewOp = OpClass.new()
        NewOp.UECompositeOperateLib = self
        return NewOp
    end
end

function UECompositeOperateLib:OnMeshComChanged(OwnerActorID, MeshCom, UEActorMeshCBType)
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

return UECompositeOperateLib
