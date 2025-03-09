local UStaticMeshComponent = import("StaticMeshComponent")
local USkeletalMeshComponent = import("SkeletalMeshComponent")
local UPoseableMeshComponent = import("PoseableMeshComponent")
--local UGFurComponent = import("GFurComponent")
local UMeshComponent = import("MeshComponent")
local ActorUtil = import("KGActorUtil")
local UKGMaterialInstanceDynamic = import("KGMaterialInstanceDynamic")
local UMaterialInstanceDynamic = import("MaterialInstanceDynamic")
local EPropertyClass = import("EPropertyClass")
local ViewResourceConst = kg_require("Gameplay.CommonDefines.ViewResourceConst")

local MaterialEffectParamTemplate = kg_require("Gameplay.Effect.MaterialEffectParamTemplate")
local SEARCH_MESH_TYPE = MaterialEffectParamTemplate.SEARCH_MESH_TYPE
local MATERIAL_PARAM_ASSET_TYPE = MaterialEffectParamTemplate.MATERIAL_PARAM_ASSET_TYPE
local MaterialEffectParamsPool = MaterialEffectParamTemplate.MaterialEffectParamsPool
local MaterialCacheSetTemplate = MaterialEffectParamTemplate.MaterialCacheSetTemplate
local MaterialParamPriorityQueueItem = MaterialEffectParamTemplate.MaterialParamPriorityQueueItem
local MaterialParamPriorityQueue = MaterialEffectParamTemplate.MaterialParamPriorityQueue
local MaterialCacheItemTemplate = MaterialEffectParamTemplate.MaterialCacheItemTemplate
local MaterialCacheStackTemplate = MaterialEffectParamTemplate.MaterialCacheStackTemplate
local MaterialParamPriorityQueueSet = MaterialEffectParamTemplate.MaterialParamPriorityQueueSet
local ChangeMaterialRequestTemplate = MaterialEffectParamTemplate.ChangeMaterialRequestTemplate
local ChangeMaterialParamRequestTemplate = MaterialEffectParamTemplate.ChangeMaterialParamRequestTemplate

--[[
材质管理器提供了材质栈和材质参数缓存的机制，以及相关联的优先级控制等功能

1，关于材质栈
	不同的业务可能会在不同的场景下去替换角色Mesh上的材质，一方面我们需要一个统一的结构去处理材质替换任务的优先级，另一方面，当一个业务不再需要替换材质时，相应材质栈中次高优先级的
材质替换任务就会生效，在MaterialManager中，这里使用了一个优先队列来处理相应的逻辑
	关于材质栈，可以分为4个层级
	1, 每个Actor包含多个MeshComponent
	2, 每个MeshComponent对应一个MaterialCacheSet, 每个MaterialCacheSet中包含多个 MaterialCacheStack
	3, 每个MaterialCacheStack中包含多个 MaterialCacheItem
	4, 每个MaterialCacheItem中对应一个材质实例（MaterialInstance而非DynamicMaterialInstance）

2，关于材质参数设置
	对于大多数场景下，业务希望通过修改材质参数来播放相应的材质表现，但是并不想替换材质，当材质栈变化的时候，这些材质参数需要能够保留，因此需要一个相对独立的材质参数的缓存，
在材质栈变化的时候能继承相应的材质参数。
	材质参数同样存在优先级，部分材质效果由于修改了相同的材质参数可能存在冲突，而对于修改不同材质参数的使用方来说，这些材质效果通常可以共存不存在冲突
	从目前的使用case来看，绝大部分修改材质表现效果仅需要按照曲线或者固定斜率的线性函数在一定时间内修改一组材质参数即可达成，因此在材质参数设置上，支持外部传入材质参数配置集合的方式
来实现自身需要的材质表现效果，同样可以通过传入EffectType的方式来确认是否需要引入优先级控制（部分简单交互物的材质表现无需引入优先级）。对于小部分特殊逻辑的材质表现来说，后续可以支持
预制好对应的MaterialEffectTask，来实现较为复杂的材质表现控制效果
	关于材质参数优先队列，可以分为2个层级
	1, 每个Actor按照EffectType不同，包含多个材质参数优先队列;
	2, 每个优先队列中保存了修改材质参数的RequestId, 优先级以及SequenceId
	
]]--

-- 32bit material cache key, 第一位是 bOverlayMaterial, 第二位是 bSeparateOverlapMaterial, 后8位是MaterialIndex，其余暂未启用
OVERLAY_MATERIAL_BIT_OFFSET = OVERLAY_MATERIAL_BIT_OFFSET or 31
OVERLAY_MATERIAL_MASK = OVERLAY_MATERIAL_MASK or (1 << OVERLAY_MATERIAL_BIT_OFFSET)
SEPARATE_OVERLAY_MATERIAL_BIT_OFFSET = SEPARATE_OVERLAY_MATERIAL_BIT_OFFSET or 30
SEPARATE_OVERLAY_MATERIAL_MASK = SEPARATE_OVERLAY_MATERIAL_MASK or (1 << SEPARATE_OVERLAY_MATERIAL_BIT_OFFSET)
MATERIAL_INDEX_MASK = MATERIAL_INDEX_MASK or 0x000000FF

MaterialCacheKeyUtils = MaterialCacheKeyUtils or {}
function MaterialCacheKeyUtils.GetMaterialCacheKey(MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
	return MaterialIndex & MATERIAL_INDEX_MASK |
		(bOverlayMaterial and OVERLAY_MATERIAL_MASK or 0) |
		(bSeparateOverlapMaterial and SEPARATE_OVERLAY_MATERIAL_MASK or 0)
end

function MaterialCacheKeyUtils.GetMaterialIndexInfoByCacheKey(MaterialCacheKey)
	local MaterialIndex = MaterialCacheKey & MATERIAL_INDEX_MASK
	local bOverlayMaterial = (MaterialCacheKey & OVERLAY_MATERIAL_MASK) ~= 0
	local bSeparateOverlapMaterial = (MaterialCacheKey & SEPARATE_OVERLAY_MATERIAL_MASK) ~= 0
	return MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial
end


TempVal_MaterialParamAssetsToLoad = TempVal_MaterialParamAssetsToLoad or {}
TempVal_MaterialInstanceArray = slua.Array(EPropertyClass.Object, UKGMaterialInstanceDynamic)
TempVal_AffectedMaterialCacheKeys = TempVal_AffectedMaterialCacheKeys or {}

---@class MaterialManager
---@field ChangeMaterialRequests table<number, ChangeMaterialRequestTemplate>
---@field ChangeMaterialParamRequests table<number, ChangeMaterialParamRequestTemplate>
---@field MaterialCaches table<number, MaterialCacheSetTemplate>
---@field OwnerActorIdToPriorityQueueSet table<number, MaterialParamPriorityQueueSet>
---@field OwnerActorIdToMeshCompIds table<number, table<number, boolean>>
MaterialManager = DefineClass("MaterialManager")

--MaterialManager.ValidMeshCompClasses = {UStaticMeshComponent, USkeletalMeshComponent, UPoseableMeshComponent, UGFurComponent}
MaterialManager.ValidMeshCompClasses = { UStaticMeshComponent, USkeletalMeshComponent, UPoseableMeshComponent }
-- 材质管理器中很多日志要调用cpp函数去或者mesh或者material名称, 因此先加个开关, 等后面功能稳定以后日志可以全部注释掉
MaterialManager.bEnableLogging = false

function MaterialManager:Init()
	self.cppMgr = import("KGMaterialManager")(Game.WorldContext)
	Game.GameInstance:CacheManager(self.cppMgr)
	self.cppMgr:NativeInit()

	-- key: mesh cache id(MeshComponentObjectId), val: MaterialCacheSetTemplate
	self.MaterialCaches = {}
	self.CurChangeMaterialSeqId = 0

	-- key: change material req id(AssetLoadId), val: ChangeMaterialRequestTemplate
	self.ChangeMaterialRequests = {}
	self.LoadIdToChangeMaterialSeqId = {}
	self.OwnerActorIdToChangeMaterialReqIds = {}
	-- key: actor id, val: table<number, boolean>
	-- 由于change material和change material param都可能初始化材质栈, 因此需要一个角色直接关联的所有材质栈id, 避免额外的运行时开销
	self.OwnerActorIdToMeshCompIds = {}
	-- key: actor id, val: table<number, boolean>
	-- 角色会动态创建部分mesh, 一些mesh不希望会受到全身材质表现影响, 这里可以加上黑名单
	self.OwnerActorIdToExcludedMeshCompIds = {}
	
	-- 通常来说使用者都是直接修改角色身上所有mesh上非指定slot、非overlay、非separate overlay材质, 为了避免多次冗余的去判定每个slot上材质是否为空判定
	-- 这里做了个缓存
	self.OwnerActorIdToBodyMaterialCacheKeys = {}
	self.OwnerActorIdToBodyMaterialInstanceSetId = {}

	-- key: change material param req id(AssetLoadId), val: ChangeMaterialParamRequestTemplate
	self.ChangeMaterialParamRequests = {}
	self.LoadIdToChangeMaterialParamSeqId = {}
	self.OwnerActorIdToChangeMaterialParamReqIds = {}
	self.OwnerActorIdToPriorityQueueSet = {}
	
	self:SetCameraDitherMaterialInfo()
end


function MaterialManager:UnInit()
	self.cppMgr:NativeUninit()
end


--region Material

---@public
---@param ChangeMaterialReq ChangeMaterialRequestTemplate
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
---部分逻辑需要在切换材质以后同时开启材质表现, 但是材质和材质参数在开启前都需要异步加载资源, 实际上材质的应用和材质参数的设置可能存在几帧的偏差, 从而导致表现问题
---例如黑化溶解和普通溶解效果, 为此本接口提供了同时设置材质和开启材质参数的功能
function MaterialManager:ChangeMaterialAndMaterialParam(ChangeMaterialReq, ChangeMaterialParamReq)
	if ChangeMaterialReq.MaterialPath == nil or ChangeMaterialReq.MaterialPath == "" then
		Log.Warning("MaterialManager:ChangeMaterialAndMaterialParam, invalid material path")
		MaterialEffectParamsPool.RecycleToPool(ChangeMaterialReq)
		MaterialEffectParamsPool.RecycleToPool(ChangeMaterialParamReq)
		return
	end

	if ChangeMaterialReq.OwnerActorId ~= ChangeMaterialParamReq.OwnerActorId then
		Log.Error("MaterialManager:ChangeMaterialAndMaterialParam, invalid owner actor id")
		return
	end
	
	local OwnerActorId = ChangeMaterialReq.OwnerActorId
	
	local ReqId
	if ChangeMaterialReq.CustomChangeMaterialReqId == nil and ChangeMaterialParamReq.CustomChangeMaterialParamReqId == nil then
		ReqId = self:GenerateChangeMaterialSeqId()
	elseif ChangeMaterialReq.CustomChangeMaterialReqId == ChangeMaterialParamReq.CustomChangeMaterialParamReqId then
		-- 两者此时必定相等
		ReqId = ChangeMaterialReq.CustomChangeMaterialReqId
	else
		Log.Error("MaterialManager:ChangeMaterialAndMaterialParam, invalid custom request id")
		return
	end

	ChangeMaterialReq.ChangeMaterialSeqId = ReqId
	ChangeMaterialParamReq.ChangeMaterialParamSeqId = ReqId
	
	local MaterialUnionAssets = self:AssembleMaterialParamsAssets(ChangeMaterialParamReq)
	table.insert(MaterialUnionAssets, ChangeMaterialReq.MaterialPath)

	if #MaterialUnionAssets == 1 then
		-- 此时只有material加载
		ChangeMaterialParamReq.bNeedLoadAsset = false
		local LoadId, LoadAsset = Game.AssetManager:AsyncLoadAssetKeepReference(MaterialUnionAssets[1], self, "OnMaterialUnionAssetLoad")
		if LoadAsset == nil then
			ChangeMaterialReq.AssetLoadId = LoadId
			ChangeMaterialParamReq.bWaitingUnionMaterialAsset = true
		else
			ChangeMaterialReq.MaterialAssetId = Game.ObjectActorManager:GetIDByObject(LoadAsset)
		end
	else
		local LoadId, LoadAssets = Game.AssetManager:AsyncLoadAssetListKeepReference(MaterialUnionAssets, self, "OnMaterialUnionAssetListLoad")
		local AssetNum = LoadAssets:Num()
		if AssetNum == 0 then
			ChangeMaterialParamReq.AssetLoadId = LoadId
			ChangeMaterialParamReq.bNeedLoadAsset = true
			ChangeMaterialReq.AssetLoadId = LoadId
		else
			ChangeMaterialParamReq.IsAssetLoaded = true
			
			if AssetNum == 1 or AssetNum ~= #MaterialUnionAssets then
				Log.Error("invalid load num")
				return
			end

			local AssetLoadedResults = ChangeMaterialParamReq.AssetLoadedResults
			local Index = 0
			while Index < AssetNum - 1 do
				local LoadAsset = LoadAssets:Get(Index)
				Index = Index + 1
				AssetLoadedResults[Index].AssetId = Game.ObjectActorManager:GetIDByObject(LoadAsset)
			end

			ChangeMaterialReq.MaterialAssetId = Game.ObjectActorManager:GetIDByObject(LoadAssets:Get(AssetNum - 1))
		end
	end

	self.ChangeMaterialRequests[ReqId] = ChangeMaterialReq
	if self.OwnerActorIdToChangeMaterialReqIds[OwnerActorId] == nil then
		self.OwnerActorIdToChangeMaterialReqIds[OwnerActorId] = {}
	end
	local ActorChangeMaterialReqIds = self.OwnerActorIdToChangeMaterialReqIds[OwnerActorId]
	ActorChangeMaterialReqIds[ReqId] = true

	self.ChangeMaterialParamRequests[ReqId] = ChangeMaterialParamReq
	if self.OwnerActorIdToChangeMaterialParamReqIds[OwnerActorId] == nil then
		self.OwnerActorIdToChangeMaterialParamReqIds[OwnerActorId] = {}
	end
	local ActorChangeMaterialParamReqIds = self.OwnerActorIdToChangeMaterialParamReqIds[OwnerActorId]
	ActorChangeMaterialParamReqIds[ReqId] = true
	
	if not ChangeMaterialParamReq.bNeedLoadAsset and ChangeMaterialReq.MaterialAssetId ~= 0 then
		self:InternalChangeMaterial(ChangeMaterialReq)
		self:ApplyMaterialParams(ChangeMaterialParamReq)
	else
		self.LoadIdToChangeMaterialSeqId[ChangeMaterialReq.AssetLoadId] = ReqId
		self.LoadIdToChangeMaterialParamSeqId[ChangeMaterialParamReq.AssetLoadId] = ReqId
	end
	
	return ReqId
end


---@public
function MaterialManager:RevertMaterialAndMaterialParam(ReqId)
	self:RevertMaterial(ReqId)
	self:RevertMaterialParam(ReqId)
end


function MaterialManager:AddExcludedMeshComponentId(ActorId, MeshCompId)
	if self.OwnerActorIdToExcludedMeshCompIds[ActorId] == nil then
		self.OwnerActorIdToExcludedMeshCompIds[ActorId] = {}
	end
	
	local ExcludedMeshCompIds = self.OwnerActorIdToExcludedMeshCompIds[ActorId]
	ExcludedMeshCompIds[MeshCompId] = true
end

function MaterialManager:RemoveExcludedMeshComponentId(ActorId, MeshCompId)
	if self.OwnerActorIdToExcludedMeshCompIds[ActorId] == nil then
		return
	end

	local ExcludedMeshCompIds = self.OwnerActorIdToExcludedMeshCompIds[ActorId]
	ExcludedMeshCompIds[MeshCompId] = nil
end

---@param ChangeMaterialReq ChangeMaterialRequestTemplate
function MaterialManager:ChangeMaterial(ChangeMaterialReq)
	if ChangeMaterialReq.MaterialPath == nil or ChangeMaterialReq.MaterialPath == "" then
		Log.Warning("MaterialManager:ChangeMaterial, invalid material path")
		MaterialEffectParamsPool.RecycleToPool(ChangeMaterialReq)
		return
	end

	local OwnerActorId = ChangeMaterialReq.OwnerActorId
	local OwnerActor = Game.ObjectActorManager:GetObjectByID(OwnerActorId)
	if OwnerActor == nil then
		Log.Warning("MaterialManager:ChangeMaterial, invalid owner actor")
		MaterialEffectParamsPool.RecycleToPool(ChangeMaterialReq)
		return
	end

    if ChangeMaterialReq.ChangeMaterialSeqId ~= 0 and self.ChangeMaterialRequests[ChangeMaterialReq.ChangeMaterialSeqId] ~= nil then
        Log.Warning("MaterialManager:ChangeMaterial, ChangeMaterialReq in use")
        return
    end

	local ChangeMaterialSeqId
	if ChangeMaterialReq.CustomChangeMaterialReqId ~= nil then
		ChangeMaterialSeqId = ChangeMaterialReq.CustomChangeMaterialReqId
	else
		ChangeMaterialSeqId = self:GenerateChangeMaterialSeqId()
	end
	ChangeMaterialReq.ChangeMaterialSeqId = ChangeMaterialSeqId
	
	local LoadId, MaterialAsset = Game.AssetManager:AsyncLoadAssetKeepReference(ChangeMaterialReq.MaterialPath, self, "OnMaterialLoaded")
	if MaterialAsset == nil then
		ChangeMaterialReq.AssetLoadId = LoadId
		self.LoadIdToChangeMaterialSeqId[LoadId] = ChangeMaterialSeqId
	else
		ChangeMaterialReq.MaterialAssetId = Game.ObjectActorManager:GetIDByObject(MaterialAsset)
	end
	
	self.ChangeMaterialRequests[ChangeMaterialSeqId] = ChangeMaterialReq
	if self.OwnerActorIdToChangeMaterialReqIds[OwnerActorId] == nil then
		self.OwnerActorIdToChangeMaterialReqIds[OwnerActorId] = {}
	end
	local ActorChangeMaterialReqIds = self.OwnerActorIdToChangeMaterialReqIds[OwnerActorId]
	ActorChangeMaterialReqIds[ChangeMaterialSeqId] = true

	if MaterialAsset ~= nil then
		self:InternalChangeMaterial(ChangeMaterialReq)
	end
	
	return ChangeMaterialSeqId
end


---@public
function MaterialManager:RevertMaterial(ChangeMaterialReqId)
	if ChangeMaterialReqId == nil then
		return
	end

	local ChangeMaterialReq = self.ChangeMaterialRequests[ChangeMaterialReqId]
	if ChangeMaterialReq == nil then
		return
	end

	if ChangeMaterialReq.MaterialAssetId == 0 then
		-- 资源还未加载完, 直接cancel加载任务即可
		Game.AssetManager:CancelLoadAsset(ChangeMaterialReq.AssetLoadId)
	else
		Game.AssetManager:RemoveAssetReferenceByLoadID(ChangeMaterialReq.AssetLoadId)
		self:RemoveMaterialCacheStackItems(ChangeMaterialReq)

		for _, ReqId in pairs(ChangeMaterialReq.AttachEntityChangeMaterialReqIds) do
			self:RevertMaterial(ReqId)
		end
	end

	if ChangeMaterialReq.LifeTimerId ~= nil then
		Game.TimerManager:StopTimerAndKill(ChangeMaterialReq.LifeTimerId)
	end
	
	local ActorChangeMaterialReqIds = self.OwnerActorIdToChangeMaterialReqIds[ChangeMaterialReq.OwnerActorId]
	ActorChangeMaterialReqIds[ChangeMaterialReqId] = nil
	self.ChangeMaterialRequests[ChangeMaterialReqId] = nil
	MaterialEffectParamsPool.RecycleToPool(ChangeMaterialReq)
end


---@public
function MaterialManager:RevertAllMaterialsByOwnerActorId(ActorId)
	if ActorId == nil then
		return
	end

	local ActorChangeMaterialReqIds = self.OwnerActorIdToChangeMaterialReqIds[ActorId]
	if ActorChangeMaterialReqIds then
		for ChangeMaterialReqId, _ in pairs(ActorChangeMaterialReqIds) do
			local ChangeMaterialReq = self.ChangeMaterialRequests[ChangeMaterialReqId]

			if ChangeMaterialReq.MaterialAssetId == 0 then
				-- 资源还未加载完, 直接cancel加载任务即可
				Game.AssetManager:CancelLoadAsset(ChangeMaterialReq.AssetLoadId)
			else
				Game.AssetManager:RemoveAssetReferenceByLoadID(ChangeMaterialReq.AssetLoadId)
				--for MeshComponentId, _ in pairs(ChangeMaterialReq.AffectedMaterialCacheKeys) do
				--	self:ClearMaterialCacheSet(ActorId, MeshComponentId, true)
				--end

				for _, ReqId in pairs(ChangeMaterialReq.AttachEntityChangeMaterialReqIds) do
					self:RevertMaterial(ReqId)
				end

				if ChangeMaterialReq.LifeTimerId ~= nil then
					Game.TimerManager:StopTimerAndKill(ChangeMaterialReq.LifeTimerId)
				end
			end

			self.ChangeMaterialRequests[ChangeMaterialReqId] = nil
			MaterialEffectParamsPool.RecycleToPool(ChangeMaterialReq)
		end
	end

	local MeshCompIds = self.OwnerActorIdToMeshCompIds[ActorId]
	if MeshCompIds ~= nil then
		for MeshCompId, _ in pairs(MeshCompIds) do
			self:ClearMaterialCacheSet(ActorId, MeshCompId, true)
		end
	end
	
	self.OwnerActorIdToMeshCompIds[ActorId] = nil
	self.OwnerActorIdToExcludedMeshCompIds[ActorId] = nil
	self.OwnerActorIdToChangeMaterialReqIds[ActorId] = nil
	self.OwnerActorIdToBodyMaterialCacheKeys[ActorId] = nil
end
--endregion Material


--region MaterialParam

---@public
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:ChangeMaterialParam(ChangeMaterialParamReq)
	local OwnerActorId = ChangeMaterialParamReq.OwnerActorId
	local OwnerActor = Game.ObjectActorManager:GetObjectByID(OwnerActorId)
	if OwnerActor == nil then
		Log.Warning("MaterialManager:SetMaterialParam, invalid owner actor")
		MaterialEffectParamsPool.RecycleToPool(ChangeMaterialParamReq)
		return
	end

    if ChangeMaterialParamReq.ChangeMaterialParamSeqId ~= 0 and self.ChangeMaterialParamRequests[ChangeMaterialParamReq.ChangeMaterialParamSeqId] ~= nil then
        Log.Warning("MaterialManager:ChangeMaterialParam, ChangeMaterialReq in use")
        return
    end

	local MaterialParamAssets = self:AssembleMaterialParamsAssets(ChangeMaterialParamReq)
	local ChangeMaterialParamSeqId
	if ChangeMaterialParamReq.CustomChangeMaterialParamReqId ~= nil then
		ChangeMaterialParamSeqId = ChangeMaterialParamReq.CustomChangeMaterialParamReqId
	else
		ChangeMaterialParamSeqId = self:GenerateChangeMaterialSeqId()
	end
	ChangeMaterialParamReq.ChangeMaterialParamSeqId = ChangeMaterialParamSeqId

	if #MaterialParamAssets == 0 then
		ChangeMaterialParamReq.bNeedLoadAsset = false
	elseif #MaterialParamAssets == 1 then
		local LoadId, LoadAsset = Game.AssetManager:AsyncLoadAssetKeepReference(MaterialParamAssets[1], self, "OnMaterialParamAssetLoad")
		if LoadAsset == nil then
			ChangeMaterialParamReq.AssetLoadId = LoadId
			ChangeMaterialParamReq.bNeedLoadAsset = true
		else
			ChangeMaterialParamReq.IsAssetLoaded = true
			ChangeMaterialParamReq.AssetLoadedResults[1].AssetId = Game.ObjectActorManager:GetIDByObject(LoadAsset)
		end
	else
		local LoadId, LoadAssets = Game.AssetManager:AsyncLoadAssetListKeepReference(MaterialParamAssets, self, "OnMaterialParamAssetListLoad")
		local AssetNum = LoadAssets:Num()
		if AssetNum == 0 then
			ChangeMaterialParamReq.AssetLoadId = LoadId
			ChangeMaterialParamReq.bNeedLoadAsset = true
		else
			ChangeMaterialParamReq.IsAssetLoaded = true

			local AssetLoadedResults = ChangeMaterialParamReq.AssetLoadedResults
			if AssetNum ~= #AssetLoadedResults then
				Log.Error("invalid load num")
				return
			end
	
			local Index = 0
			while Index < AssetNum do
				local LoadAsset = LoadAssets:Get(Index)
				Index = Index + 1
				AssetLoadedResults[Index].AssetId = Game.ObjectActorManager:GetIDByObject(LoadAsset)
			end
		end
	end

	self.ChangeMaterialParamRequests[ChangeMaterialParamSeqId] = ChangeMaterialParamReq
	if self.OwnerActorIdToChangeMaterialParamReqIds[OwnerActorId] == nil then
		self.OwnerActorIdToChangeMaterialParamReqIds[OwnerActorId] = {}
	end
	local ActorChangeMaterialParamReqIds = self.OwnerActorIdToChangeMaterialParamReqIds[OwnerActorId]
	ActorChangeMaterialParamReqIds[ChangeMaterialParamSeqId] = true

	if ChangeMaterialParamReq.bNeedLoadAsset then
		self.LoadIdToChangeMaterialParamSeqId[ChangeMaterialParamReq.AssetLoadId] = ChangeMaterialParamSeqId
	else
		self:ApplyMaterialParams(ChangeMaterialParamReq)
	end

	return ChangeMaterialParamSeqId
end


---@public
function MaterialManager:RevertMaterialParam(ChangeMaterialParamReqId)
	if ChangeMaterialParamReqId == nil then
		return
	end

	local ChangeMaterialParamReq = self.ChangeMaterialParamRequests[ChangeMaterialParamReqId]
	if ChangeMaterialParamReq == nil then
		return
	end

	if not ChangeMaterialParamReq.bWaitingUnionMaterialAsset then
		if ChangeMaterialParamReq.bNeedLoadAsset then
			if ChangeMaterialParamReq.IsAssetLoaded == false then
				-- 资源还未加载完, 直接cancel加载任务即可
				Game.AssetManager:CancelLoadAsset(ChangeMaterialParamReq.AssetLoadId)
			else
				Game.AssetManager:RemoveAssetReferenceByLoadID(ChangeMaterialParamReq.AssetLoadId)
				self:RemoveMaterialParams(ChangeMaterialParamReq)
			end
		else
			self:RemoveMaterialParams(ChangeMaterialParamReq)
		end

		for _, ReqId in pairs(ChangeMaterialParamReq.AttachEntityChangeMaterialParamReqIds) do
			self:RevertMaterialParam(ReqId)
		end

		if ChangeMaterialParamReq.LifeTimerId ~= nil then
			Game.TimerManager:StopTimerAndKill(ChangeMaterialParamReq.LifeTimerId)
		end
	end
	
	local ActorChangeMaterialParamReqIds = self.OwnerActorIdToChangeMaterialParamReqIds[ChangeMaterialParamReq.OwnerActorId]
	ActorChangeMaterialParamReqIds[ChangeMaterialParamReqId] = nil
	self.ChangeMaterialParamRequests[ChangeMaterialParamReqId] = nil
	MaterialEffectParamsPool.RecycleToPool(ChangeMaterialParamReq)
end


---@public
function MaterialManager:RevertActorAllMaterialParams(ActorId)
	if ActorId == nil then
		return
	end

	local ActorChangeMaterialParamReqIds = self.OwnerActorIdToChangeMaterialParamReqIds[ActorId]
	if ActorChangeMaterialParamReqIds ~= nil then
		for ChangeMaterialParamReqId, _ in pairs(ActorChangeMaterialParamReqIds) do
			local ChangeMaterialParamReq = self.ChangeMaterialParamRequests[ChangeMaterialParamReqId]

            if not ChangeMaterialParamReq.bWaitingUnionMaterialAsset then
                if ChangeMaterialParamReq.bNeedLoadAsset then
                    if ChangeMaterialParamReq.IsAssetLoaded == false then
                        -- 资源还未加载完, 直接cancel加载任务即可
                        Game.AssetManager:CancelLoadAsset(ChangeMaterialParamReq.AssetLoadId)
                    else
                        Game.AssetManager:RemoveAssetReferenceByLoadID(ChangeMaterialParamReq.AssetLoadId)
                        self:InternalRevertMaterialParams(ChangeMaterialParamReq)
                    end
                else
                    self:InternalRevertMaterialParams(ChangeMaterialParamReq)
                end

                for _, ReqId in pairs(ChangeMaterialParamReq.AttachEntityChangeMaterialParamReqIds) do
                    self:RevertMaterialParam(ReqId)
                end

                if ChangeMaterialParamReq.LifeTimerId ~= nil then
                    Game.TimerManager:StopTimerAndKill(ChangeMaterialParamReq.LifeTimerId)
                end
            end

			MaterialEffectParamsPool.RecycleToPool(ChangeMaterialParamReq)
			self.ChangeMaterialParamRequests[ChangeMaterialParamReqId] = nil
		end
	end

	local PriorityQueueSet = self.OwnerActorIdToPriorityQueueSet[ActorId]
	if PriorityQueueSet ~= nil then
		for _, PriorityQueue in pairs(PriorityQueueSet.PriorityQueues) do
			for _, Param in ipairs(PriorityQueue.PriorityQueueItems) do
				MaterialEffectParamsPool.RecycleToPool(Param)
			end
			MaterialEffectParamsPool.RecycleToPool(PriorityQueue)
		end
		
		MaterialEffectParamsPool.RecycleToPool(PriorityQueueSet)
		self.OwnerActorIdToPriorityQueueSet[ActorId] = nil
	end

	self.cppMgr:RemoveTransientTasksByActorId(ActorId)
	self.OwnerActorIdToChangeMaterialParamReqIds[ActorId] = nil
	self:RemoveBodyMaterialInstanceSetCache(ActorId)
	self.OwnerActorIdToBodyMaterialCacheKeys[ActorId] = nil
end


---@public
---@param MaterialInstance any 这里不能给DynamicMaterial 
function MaterialManager:ChangeDefaultMaterial(InMeshCompId, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial, MaterialInstance)
	-- 如果说对应的material cache stack已经构建过了, 则需要替换材质栈中的缓存material, 否则直接替换mesh对应的material即可
	local MeshComp = Game.ObjectActorManager:GetObjectByID(InMeshCompId)
	if MeshComp == nil then
		Log.Error("invalid mesh component")
		return
	end
	
	self.cppMgr:ChangeDefaultMaterialInstance(MeshComp, MaterialInstance, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
end


---@public
function MaterialManager:GetDefaultMaterial(InMeshCompId, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
	-- 如果说对应的material cache stack已经构建过了, 则需要替换材质栈中的缓存material, 否则直接替换mesh对应的material即可
	local MeshComp = Game.ObjectActorManager:GetObjectByID(InMeshCompId)
	if MeshComp == nil then
		Log.Error("invalid mesh component")
		return
	end
	
	return self.cppMgr:GetDefaultMaterialInstance(MeshComp, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
end

---@public
---通过这个接口可以获取到当前材质栈中生效的dynamic material instance, 外部获取到对应材质实例以后可以设置相应的材质参数
---需要注意的是，这些材质参数一旦切换了MeshAsset或者MeshComponent, 所有的参数都会丢失，当前只有角色组装会用这部分逻辑
function MaterialManager:GetMaterialInstance(InActorId, InMeshCompId, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
	local MeshComp = Game.ObjectActorManager:GetObjectByID(InMeshCompId)
	if MeshComp == nil then
		Log.Error("invalid mesh component")
		return
	end

	return self.cppMgr:GetDynamicMaterialInstance(MeshComp, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
end

--- 对于受击闪白类似的材质表现，由于触发频率比较高, 为了尽可能降低这些材质表现的开销
---	1，相应材质参数任务不纳入优先队列管理;
---	2, 相同EffectType的材质更新任务，默认非Transient任务优先级高于Transient任务
---	3, 当发生mesh切换以后，所有transient task都会被直接清理
---@public
function MaterialManager:AddBodyTransientMaterialParamUpdateTask(OwnerActorId, InEffectType, LifeTimeSeconds)
	local OwnerActor = Game.ObjectActorManager:GetObjectByID(OwnerActorId)
	if OwnerActor == nil then
		Log.Error("invalid owner actor")
		return
	end

	if InEffectType ~= nil then
		local PriorityQueueSet = self.OwnerActorIdToPriorityQueueSet[OwnerActorId]
		if PriorityQueueSet ~= nil then
			local PriorityQueue = PriorityQueueSet[InEffectType]
			if PriorityQueue ~= nil then
				return
			end
		end
	end
	
	local AffectedMaterialCacheKeys = self.OwnerActorIdToBodyMaterialCacheKeys[OwnerActorId]
	if AffectedMaterialCacheKeys == nil then
		self:TryCacheBodyMaterialCacheKeys(OwnerActor, OwnerActorId)
		AffectedMaterialCacheKeys = self.OwnerActorIdToBodyMaterialCacheKeys[OwnerActorId]
		self:TryInitMaterialCacheStacks(OwnerActorId, AffectedMaterialCacheKeys)
	end
	self:TryCacheBodyMaterialInstanceSet(OwnerActor, OwnerActorId)
	local MaterialInstanceSetId = self.OwnerActorIdToBodyMaterialInstanceSetId[OwnerActorId]
	local bHasValidEffectType = InEffectType ~= nil
	return self.cppMgr:AddTransientUpdateTask(OwnerActorId, MaterialInstanceSetId, LifeTimeSeconds, bHasValidEffectType, InEffectType or 0)
end

---@public
function MaterialManager:SetScalarParameterByTransientTaskId(TaskId, ParamName, ParamVal)
	self.cppMgr:SetScalarParameterByTransientTaskId(TaskId, ParamName, ParamVal)
end

function MaterialManager:RemoveTransientTaskById(TaskId)
	self.cppMgr:RemoveTransientTaskById(TaskId)
end

---@public
---对单个材质基于线性插值tick更新材质参数, 角色不要用，简单物件或者UI可以用
function MaterialManager:AddLinearSampleParamSingleMaterialInst(ParamName, MaterialInst, StartVal, EndVal, Duration)
	return self.cppMgr:AddLinearSampleParamSingleMaterialInst(ParamName, MaterialInst, StartVal, EndVal, Duration)
end

function MaterialManager:AddLinearSampleParam(ParamName, MaterialInstArray, StartVal, EndVal, Duration)
	return self.cppMgr:AddLinearSampleParam(ParamName, MaterialInstArray, StartVal, EndVal, Duration)
end

function MaterialManager:AddVectorLinearSampleParam(ParamName, MaterialInstArray, StartR, StartG, StartB, StartA, EndR, EndG, EndB, EndA, Duration)
	return self.cppMgr:AddVectorLinearSampleParam(ParamName, MaterialInstArray, StartR, StartG, StartB, StartA, EndR, EndG, EndB, EndA, Duration)
end

function MaterialManager:RemoveMaterialParamUpdateTask(TaskID)
	return self.cppMgr:RemoveMaterialParamUpdateTask(TaskID)
end

function MaterialManager:SetEnableForceOverlay(bEnable)
	self.cppMgr:SetEnableForceOverlay(bEnable)
end

--endregion MaterialParam


--region RefreshMaterialAndParamCache
---@public
---如果说某个MeshComponent重新设置了MeshAsset, 此时需要更新对应MeshComponent的所有材质栈, 这是由于新Mesh对应的材质slot数量, slot name等信息都会变化，
---ChangeMaterialReq中对应的修改的MaterialCacheKey可能都会变化, 因此这里做一次整体的刷新流程
---某个MeshComponent对应的Asset变化以后调用这里的材质栈刷新逻辑
function MaterialManager:RefreshMaterialCacheOnMeshAssetChanged(InActorId, InMeshComponentId)
	local MeshComponentIds = self.OwnerActorIdToMeshCompIds[InActorId]
	if MeshComponentIds == nil or MeshComponentIds[InMeshComponentId] == nil then
		-- 没有逻辑处理过InMeshComponentId, 无需处理
		return
	end

	local MeshComp = Game.ObjectActorManager:GetObjectByID(InMeshComponentId)
	if MeshComp == nil then
		Log.Error("invalid mesh component", InMeshComponentId)
		return
	end

	if MaterialManager.bEnableLogging then
		Log.Debug("MaterialManager:RefreshMaterialCacheOnMeshAssetChanged, MeshComponent:", MeshComp:GetName())
	end

	self.cppMgr:RemoveTransientTasksByActorId(InActorId)
	self:ClearMaterialCacheSet(InActorId, InMeshComponentId, false)
	self.OwnerActorIdToBodyMaterialCacheKeys[InActorId] = nil
	self:RemoveBodyMaterialInstanceSetCache(InActorId)

	local ActorChangeMaterialReqIds = self.OwnerActorIdToChangeMaterialReqIds[InActorId]
	if ActorChangeMaterialReqIds ~= nil then
		for ChangeMaterialReqId, _ in pairs(ActorChangeMaterialReqIds) do
			local ChangeMaterialReq = self.ChangeMaterialRequests[ChangeMaterialReqId]
			if ChangeMaterialReq.AffectedMaterialCacheKeys == nil then
				goto continue
			end
			
			local MaterialCacheKeys = ChangeMaterialReq.AffectedMaterialCacheKeys[InMeshComponentId]
			if MaterialCacheKeys == nil then
				goto continue
			end

			table.clear(MaterialCacheKeys)
			self:GetAffectedMaterialCacheKeysInComponent(
				InActorId, MeshComp, ChangeMaterialReq.MaterialSlotNames, ChangeMaterialReq.bChangeOverlayMaterial,
				ChangeMaterialReq.bChangeSeparateOverlayMaterial, ChangeMaterialReq.AffectedMaterialCacheKeys)

			self:InitMeshMaterialCacheStacks(InActorId, InMeshComponentId, MaterialCacheKeys)
			self:AddPerMeshMaterialCacheStackItems(
				InMeshComponentId, MaterialCacheKeys, ChangeMaterialReq.Priority, ChangeMaterialReq.MaterialAssetId, ChangeMaterialReq.ChangeMaterialSeqId)

			::continue::
		end
	end

	local ActorChangeMaterialParamReqIds = self.OwnerActorIdToChangeMaterialParamReqIds[InActorId]
	if ActorChangeMaterialParamReqIds ~= nil then
		for ChangeMaterialParamReqId, _ in pairs(ActorChangeMaterialParamReqIds) do
			local ChangeMaterialParamReq = self.ChangeMaterialParamRequests[ChangeMaterialParamReqId]
			if ChangeMaterialParamReq.AffectedMaterialCacheKeys == nil then
				goto continue
			end
			
			local MaterialCacheKeys = ChangeMaterialParamReq.AffectedMaterialCacheKeys[InMeshComponentId]
			if MaterialCacheKeys == nil then
				goto continue
			end

			-- 此时肯定加载好了且此时这个mesh的变化会影响到当前change material param request
			table.clear(MaterialCacheKeys)
			self:GetAffectedMaterialCacheKeysInComponent(
				InActorId, MeshComp, ChangeMaterialParamReq.MaterialSlotNames, ChangeMaterialParamReq.bChangeOverlayMaterial,
				ChangeMaterialParamReq.bChangeSeparateOverlayMaterial, ChangeMaterialParamReq.AffectedMaterialCacheKeys)
			self:InitMeshMaterialCacheStacks(InActorId, InMeshComponentId, MaterialCacheKeys)

			if self:IsChangeMaterialParamActive(ChangeMaterialParamReq) then
				self:InitConstMaterialParams(ChangeMaterialParamReq)
			end
			
			self:GetAffectedMaterialInstances(ChangeMaterialParamReq.AffectedMaterialCacheKeys, TempVal_MaterialInstanceArray)
			ChangeMaterialParamReq.MaterialInstanceSetId = self.cppMgr:AddMaterialInstanceSet(TempVal_MaterialInstanceArray)
			ChangeMaterialParamReq.bUseSharedMaterialInstanceSetId = false
			
			if #ChangeMaterialParamReq.MaterialParamUpdateTaskIds > 0 then
				for _, TaskId in ipairs(ChangeMaterialParamReq.MaterialParamUpdateTaskIds) do
					self.cppMgr:UpdateMaterialInstance(TaskId, TempVal_MaterialInstanceArray)
				end
			end
			TempVal_MaterialInstanceArray:Clear()

			::continue::
		end
	end
end

-- luacheck: push ignore
---@public
---如果新增了mesh component, 需要在新增mesh component后更新对应的mesh component材质以及材质参数缓存
function MaterialManager:RefreshMaterialCacheOnAddMeshComponent(InActorId, InMeshComponentId)
	local MeshComponentIds = self.OwnerActorIdToMeshCompIds[InActorId]
	if MeshComponentIds ~= nil and MeshComponentIds[InMeshComponentId] ~= nil then
		Log.Warning("mesh already found in material cache")
		return
	end

	local OwnerActor = Game.ObjectActorManager:GetObjectByID(InActorId)
	if OwnerActor == nil then
		return
	end

	self.cppMgr:RemoveTransientTasksByActorId(InActorId)
	self.OwnerActorIdToBodyMaterialCacheKeys[InActorId] = nil
	self:RemoveBodyMaterialInstanceSetCache(InActorId)

	if MaterialManager.bEnableLogging then
		Log.Debug("MaterialManager:RefreshMaterialCacheOnAddMeshComponent, MeshComponent:", Game.ObjectActorManager:GetObjectByID(InMeshComponentId):GetName())
	end
	
	local ActorChangeMaterialReqIds = self.OwnerActorIdToChangeMaterialReqIds[InActorId]
	if ActorChangeMaterialReqIds ~= nil then
		for ChangeMaterialReqId, _ in pairs(ActorChangeMaterialReqIds) do
			local ChangeMaterialReq = self.ChangeMaterialRequests[ChangeMaterialReqId]
			if ChangeMaterialReq.MaterialAssetId == 0 then
				-- 还没加载好
				goto continue
			end

			local CurAffectedMaterialCacheKeys = ChangeMaterialReq.AffectedMaterialCacheKeys
			if CurAffectedMaterialCacheKeys == nil then
				goto continue
			end
			
			if CurAffectedMaterialCacheKeys[InMeshComponentId] ~= nil then
				if MaterialManager.bEnableLogging then
					Log.Debug("MaterialManager:RefreshMaterialCacheOnAddMeshComponent, already found mesh comp in affected material cache keys", InMeshComponentId)
				end
				goto continue
			end
			
			-- 当前正在生效的才需要重新构建
			local NewAffectedMaterialCacheKeys = {}
			self:GetAffectedMaterialCacheKeys(
				InActorId, OwnerActor, ChangeMaterialReq.SearchMeshType, ChangeMaterialReq.SearchMeshName,
				ChangeMaterialReq.CustomMeshComponentIds, ChangeMaterialReq.MaterialSlotNames,
				ChangeMaterialReq.bChangeOverlayMaterial, ChangeMaterialReq.bChangeSeparateOverlayMaterial, NewAffectedMaterialCacheKeys)
			
			local MaterialCacheKeys = NewAffectedMaterialCacheKeys[InMeshComponentId]
			if MaterialCacheKeys ~= nil then
				ChangeMaterialReq.AffectedMaterialCacheKeys[InMeshComponentId] = MaterialCacheKeys
				self:InitMeshMaterialCacheStacks(InActorId, InMeshComponentId, MaterialCacheKeys)
				self:AddPerMeshMaterialCacheStackItems(
					InMeshComponentId, MaterialCacheKeys, ChangeMaterialReq.Priority, ChangeMaterialReq.MaterialAssetId,
					ChangeMaterialReq.ChangeMaterialSeqId)
			end

			::continue::
		end
	end

	local ActorChangeMaterialParamReqIds = self.OwnerActorIdToChangeMaterialParamReqIds[InActorId]
	if ActorChangeMaterialParamReqIds ~= nil then
		for ChangeMaterialParamReqId, _ in pairs(ActorChangeMaterialParamReqIds) do
			local ChangeMaterialParamReq = self.ChangeMaterialParamRequests[ChangeMaterialParamReqId]
			--if ChangeMaterialParamReq.bWaitingUnionMaterialAsset or (ChangeMaterialParamReq.bNeedLoadAsset and ChangeMaterialParamReq.IsAssetLoaded == false) then
			--	goto continue
			--end
			
			local AffectedMaterialCacheKeys = ChangeMaterialParamReq.AffectedMaterialCacheKeys
			if AffectedMaterialCacheKeys == nil then
				goto continue
			end
			
			if AffectedMaterialCacheKeys[InMeshComponentId] ~= nil then
				if MaterialManager.bEnableLogging then
					Log.Debug("MaterialManager:RefreshMaterialCacheOnAddMeshComponent, already found mesh comp in affected material cache keys", InMeshComponentId)
				end
				goto continue
			end
			
			local bNoAffectedKeys = next(AffectedMaterialCacheKeys) == nil

			if MaterialManager.bEnableLogging then
				Log.Debug("MaterialManager:RefreshMaterialCacheOnAddMeshComponent, OldAffectedMaterialCacheKeys")
				self:DumpAffectedMaterialCacheKeyInfos(AffectedMaterialCacheKeys)
			end
			
			local NewAffectedMaterialCacheKeys = {}
			self:GetAffectedMaterialCacheKeys(
				InActorId, OwnerActor, ChangeMaterialParamReq.SearchMeshType, ChangeMaterialParamReq.SearchMeshName,
				ChangeMaterialParamReq.CustomMeshComponentIds, ChangeMaterialParamReq.MaterialSlotNames,
				ChangeMaterialParamReq.bChangeOverlayMaterial, ChangeMaterialParamReq.bChangeSeparateOverlayMaterial,
				NewAffectedMaterialCacheKeys)

			if MaterialManager.bEnableLogging then
				Log.Debug("MaterialManager:RefreshMaterialCacheOnAddMeshComponent, NewAffectedMaterialCacheKeys")
				self:DumpAffectedMaterialCacheKeyInfos(NewAffectedMaterialCacheKeys)
			end

			local MaterialCacheKeys = NewAffectedMaterialCacheKeys[InMeshComponentId]
			if MaterialCacheKeys == nil then
				goto continue
			end

			AffectedMaterialCacheKeys[InMeshComponentId] = MaterialCacheKeys
			self:InitMeshMaterialCacheStacks(InActorId, InMeshComponentId, MaterialCacheKeys)

			self:GetAffectedMaterialInstances(ChangeMaterialParamReq.AffectedMaterialCacheKeys, TempVal_MaterialInstanceArray)
			ChangeMaterialParamReq.MaterialInstanceSetId = self.cppMgr:AddMaterialInstanceSet(TempVal_MaterialInstanceArray)
			ChangeMaterialParamReq.bUseSharedMaterialInstanceSetId = false

			local bIsActive = self:IsChangeMaterialParamActive(ChangeMaterialParamReq)
			if bIsActive then
				self:InitConstMaterialParams(ChangeMaterialParamReq)
			end
			
			if bNoAffectedKeys then
				self:AddMaterialParamUpdateTasks(ChangeMaterialParamReq)
				
				if not bIsActive then
					for _, TaskId in ipairs(ChangeMaterialParamReq.MaterialParamUpdateTaskIds) do
						self.cppMgr:PauseMaterialParamUpdateTask(TaskId)
					end
				end
			else
				if #ChangeMaterialParamReq.MaterialParamUpdateTaskIds > 0 then
					for _, TaskId in ipairs(ChangeMaterialParamReq.MaterialParamUpdateTaskIds) do
						self.cppMgr:UpdateMaterialInstance(TaskId, TempVal_MaterialInstanceArray)
					end
				end
			end
			TempVal_MaterialInstanceArray:Clear()
			
			::continue::
		end
	end
end
-- luacheck: pop

---@public
---如果remove了mesh component，需要在remove component前清理掉对应的材质以及材质参数缓存
function MaterialManager:RefreshMaterialCacheOnRemoveMeshComponent(InActorId, InMeshComponentId)
	local MeshComponentIds = self.OwnerActorIdToMeshCompIds[InActorId]
	if MeshComponentIds == nil or MeshComponentIds[InMeshComponentId] == nil then
		-- 没有逻辑处理过InMeshComponentId, 无需处理
		return
	end

	if MaterialManager.bEnableLogging then
		Log.Debug("MaterialManager:RefreshMaterialCacheOnRemoveMeshComponent, MeshComponent:", Game.ObjectActorManager:GetObjectByID(InMeshComponentId):GetName())
	end

	self.cppMgr:RemoveTransientTasksByActorId(InActorId)
	self:ClearMaterialCacheSet(InActorId, InMeshComponentId, true)
	self.OwnerActorIdToBodyMaterialCacheKeys[InActorId] = nil
	self:RemoveBodyMaterialInstanceSetCache(InActorId)
	
	local ActorChangeMaterialReqIds = self.OwnerActorIdToChangeMaterialReqIds[InActorId]
	if ActorChangeMaterialReqIds ~= nil then
		for ChangeMaterialReqId, _ in pairs(ActorChangeMaterialReqIds) do
			local ChangeMaterialReq = self.ChangeMaterialRequests[ChangeMaterialReqId]
			local AffectedMaterialCacheKeys = ChangeMaterialReq.AffectedMaterialCacheKeys
			if AffectedMaterialCacheKeys and AffectedMaterialCacheKeys[InMeshComponentId] ~= nil then
				AffectedMaterialCacheKeys[InMeshComponentId] = nil
			end
		end
	end

	local ActorChangeMaterialParamReqIds = self.OwnerActorIdToChangeMaterialParamReqIds[InActorId]
	if ActorChangeMaterialParamReqIds ~= nil then
		for ChangeMaterialParamReqId, _ in pairs(ActorChangeMaterialParamReqIds) do
			local ChangeMaterialParamReq = self.ChangeMaterialParamRequests[ChangeMaterialParamReqId]
			local AffectedMaterialCacheKeys = ChangeMaterialParamReq.AffectedMaterialCacheKeys
			if AffectedMaterialCacheKeys == nil then
				goto continue
			end
			
			local MaterialCacheKeys = AffectedMaterialCacheKeys[InMeshComponentId]
			if MaterialCacheKeys == nil and not ChangeMaterialParamReq.bUseSharedMaterialInstanceSetId then
				goto continue
			end

			if MaterialCacheKeys ~= nil then
				AffectedMaterialCacheKeys[InMeshComponentId] = nil
			end

			self:GetAffectedMaterialInstances(ChangeMaterialParamReq.AffectedMaterialCacheKeys, TempVal_MaterialInstanceArray)
			ChangeMaterialParamReq.MaterialInstanceSetId = self.cppMgr:AddMaterialInstanceSet(TempVal_MaterialInstanceArray)
			ChangeMaterialParamReq.bUseSharedMaterialInstanceSetId = false

			if #ChangeMaterialParamReq.MaterialParamUpdateTaskIds > 0 then
				for _, TaskId in ipairs(ChangeMaterialParamReq.MaterialParamUpdateTaskIds) do
					self.cppMgr:UpdateMaterialInstance(TaskId, TempVal_MaterialInstanceArray)
				end
			end
			TempVal_MaterialInstanceArray:Clear()

			::continue::
		end
	end
end

---@public 
function MaterialManager:RefreshMaterialOnAttachEntityCreate(InActorId, AttachEntityId, EntityType)
	local ActorChangeMaterialReqIds = self.OwnerActorIdToChangeMaterialReqIds[InActorId]
	if ActorChangeMaterialReqIds ~= nil then
		for ChangeMaterialReqId, _ in pairs(ActorChangeMaterialReqIds) do
			local ChangeMaterialReq = self.ChangeMaterialRequests[ChangeMaterialReqId]
			if ChangeMaterialReq.AffectedAttachEntityTypes ~= nil and table.contains(ChangeMaterialReq.AffectedAttachEntityTypes, EntityType) then
				self:ChangeAttachEntityMaterial(ChangeMaterialReq, AttachEntityId)
			end
		end
	end

	local ActorChangeMaterialParamReqIds = self.OwnerActorIdToChangeMaterialParamReqIds[InActorId]
	if ActorChangeMaterialParamReqIds ~= nil then
		for ChangeMaterialParamReqId, _ in pairs(ActorChangeMaterialParamReqIds) do
			local ChangeMaterialParamReq = self.ChangeMaterialParamRequests[ChangeMaterialParamReqId]
			if ChangeMaterialParamReq.AffectedAttachEntityTypes ~= nil and table.contains(ChangeMaterialParamReq.AffectedAttachEntityTypes, EntityType) then
				self:ChangeAttachEntityMaterialParam(ChangeMaterialParamReq, AttachEntityId)
			end
		end
	end
end


---@public 
function MaterialManager:RemoveAllInheritMaterial(InActorId)
	if InActorId == nil then
		return
	end

	local ActorChangeMaterialReqIds = self.OwnerActorIdToChangeMaterialReqIds[InActorId]
	if ActorChangeMaterialReqIds ~= nil then
		for ChangeMaterialReqId, _ in pairs(ActorChangeMaterialReqIds) do
			local ChangeMaterialReq = self.ChangeMaterialRequests[ChangeMaterialReqId]
			if ChangeMaterialReq.bIsInherited then
				self:RevertMaterial(ChangeMaterialReqId)
			end
		end
	end

	local ActorChangeMaterialParamReqIds = self.OwnerActorIdToChangeMaterialParamReqIds[InActorId]
	if ActorChangeMaterialParamReqIds then
		for ChangeMaterialParamReqId, _ in pairs(ActorChangeMaterialParamReqIds) do
			local ChangeMaterialParamReq = self.ChangeMaterialParamRequests[ChangeMaterialParamReqId]
			if ChangeMaterialParamReq.bIsInherited then
				self:RevertMaterialParam(ChangeMaterialParamReqId)
			end
		end
	end
end

--endregion RefreshMaterialAndParamCache


--region Debug
---@public
---@param OutMaterialCacheInfos table<string>
---debug调试用 暂不考虑性能
function MaterialManager:GetMaterialCacheDebugInfosByActorId(InActorId, OutMaterialCacheInfos)
	local OwnerActor = Game.ObjectActorManager:GetObjectByID(InActorId)
	local MeshCompIds = self.OwnerActorIdToMeshCompIds[InActorId]
	if MeshCompIds == nil then
		return
	end

	for MeshCompId, _ in pairs(MeshCompIds) do
		local MeshComp = Game.ObjectActorManager:GetObjectByID(MeshCompId)

		local MaterialCacheStacks = self.MaterialCaches[MeshCompId].MaterialCacheStacks
		for MaterialCacheKey, MaterialCacheStack in pairs(MaterialCacheStacks) do
			local MaterialIndex, bChangeOverlayMaterial, bChangeSeparateOverlayMaterial = MaterialCacheKeyUtils.GetMaterialIndexInfoByCacheKey(MaterialCacheKey)
			for _, MaterialCacheItem in ipairs(MaterialCacheStack.MaterialCacheItems) do
				local MaterialInstance
				if MaterialCacheItem.bIsDefaultMaterial then
					MaterialInstance = self.cppMgr:GetDefaultMaterialInstance(MeshComp, MaterialIndex, bChangeOverlayMaterial, bChangeSeparateOverlayMaterial)
				else
					MaterialInstance = Game.ObjectActorManager:GetObjectByID(MaterialCacheItem.MaterialId)
				end
				
				table.insert(OutMaterialCacheInfos,
					string.format("%s|%s, %d|%s|%s, %s(%d|%d)", OwnerActor:GetName(), MeshComp:GetName(), MaterialIndex,
						tostring(bChangeOverlayMaterial), tostring(bChangeSeparateOverlayMaterial),
						MaterialInstance and MaterialInstance:GetName() or "nil", MaterialCacheItem.Priority, MaterialCacheItem.SequenceId
					))
			end
		end
	end
end


---@public
---@param OutMaterialParamsInfos table<string>
---debug调试用 暂不考虑性能
function MaterialManager:GetMaterialParamDebugInfosByActorId(InActorId, OutMaterialParamsInfos)
	local ChangeMaterialParamReqIds = self.OwnerActorIdToChangeMaterialParamReqIds[InActorId]
	if ChangeMaterialParamReqIds == nil then
		return
	end

	for ChangeMaterialParamReqId, _ in pairs(ChangeMaterialParamReqIds) do
		local ChangeMaterialParamReq = self.ChangeMaterialParamRequests[ChangeMaterialParamReqId]
		if ChangeMaterialParamReq.AffectedMaterialCacheKeys then
			for MeshCompId, MaterialCacheKeys in pairs(ChangeMaterialParamReq.AffectedMaterialCacheKeys) do
				local MeshComp = Game.ObjectActorManager:GetObjectByID(MeshCompId)

				for _, MaterialCacheKey in ipairs(MaterialCacheKeys) do
					local DynamicMaterialInst = self:GetMaterialByMaterialCacheKey(MeshComp, MaterialCacheKey)
					if DynamicMaterialInst == nil then
						Log.Error("invalid mesh material")
						goto continue
					end

					local ParamInfo = ""
					if ChangeMaterialParamReq.ScalarParams then
						for ParamName, _ in pairs(ChangeMaterialParamReq.ScalarParams) do
							local ParamVal = DynamicMaterialInst:K2_GetScalarParameterValue(ParamName)
							ParamInfo = ParamInfo .. string.format("%s: %.2f, ", ParamName, ParamVal)
						end
					end

					if ChangeMaterialParamReq.VectorParams then
						for ParamName, _ in pairs(ChangeMaterialParamReq.VectorParams) do
							local ParamVal = DynamicMaterialInst:K2_GetVectorParameterValue(ParamName)
							ParamInfo = ParamInfo .. string.format("%s: (%.2f,%.2f,%.2f,%.2f), ", ParamName, ParamVal.R, ParamVal.G, ParamVal.B, ParamVal.A)
						end
					end

					if ChangeMaterialParamReq.TextureParams then
						for ParamName, _ in pairs(ChangeMaterialParamReq.TextureParams) do
							local ParamVal = DynamicMaterialInst:K2_GetTextureParameterValue(ParamName)
							if ParamVal ~= nil then
								ParamInfo = ParamInfo .. string.format("%s: %s, ", ParamName, ParamVal:GetName())
							end
						end
					end

					if ChangeMaterialParamReq.FloatCurveParams then
						for ParamName, _ in pairs(ChangeMaterialParamReq.FloatCurveParams) do
							local ParamVal = DynamicMaterialInst:K2_GetScalarParameterValue(ParamName)
							ParamInfo = ParamInfo .. string.format("%s: %.2f, ", ParamName, ParamVal)
						end
					end

					if ChangeMaterialParamReq.VectorCurveParams then
						for ParamName, _ in pairs(ChangeMaterialParamReq.VectorCurveParams) do
							local ParamVal = DynamicMaterialInst:K2_GetVectorParameterValue(ParamName)
							ParamInfo = ParamInfo .. string.format("%s: (%.2f,%.2f,%.2f,%.2f), ", ParamName, ParamVal.R, ParamVal.G, ParamVal.B, ParamVal.A)
						end
					end

					if ChangeMaterialParamReq.ScalarLinearSampleParams then
						for ParamName, _ in pairs(ChangeMaterialParamReq.ScalarLinearSampleParams) do
							local ParamVal = DynamicMaterialInst:K2_GetScalarParameterValue(ParamName)
							ParamInfo = ParamInfo .. string.format("%s: %.2f, ", ParamName, ParamVal)
						end
					end

					if ChangeMaterialParamReq.VectorLinearSampleParams then
						for ParamName, _ in pairs(ChangeMaterialParamReq.VectorLinearSampleParams) do
							local ParamVal = DynamicMaterialInst:K2_GetVectorParameterValue(ParamName)
							ParamInfo = ParamInfo .. string.format("%s: (%.2f,%.2f,%.2f,%.2f), ", ParamName, ParamVal.R, ParamVal.G, ParamVal.B, ParamVal.A)
						end
					end

					if ChangeMaterialParamReq.ActorLocationParams then
						for ParamName, _ in pairs(ChangeMaterialParamReq.ActorLocationParams) do
							local ParamVal = DynamicMaterialInst:K2_GetVectorParameterValue(ParamName)
							ParamInfo = ParamInfo .. string.format("%s: (%.2f,%.2f,%.2f,%.2f), ", ParamName, ParamVal.R, ParamVal.G, ParamVal.B, ParamVal.A)
						end
					end
					
					local MaterialIndex, bChangeOverlayMaterial, bChangeSeparateOverlayMaterial = MaterialCacheKeyUtils.GetMaterialIndexInfoByCacheKey(MaterialCacheKey)
					table.insert(OutMaterialParamsInfos,
						string.format("%s, %d|%s|%s, [%s]", MeshComp:GetName(), MaterialIndex, tostring(bChangeOverlayMaterial),
							tostring(bChangeSeparateOverlayMaterial), ParamInfo
						))

					::continue::
				end
			end
		end
	end
end

---@private
function MaterialManager:GetMeshAssetName(MeshComp)
	if MeshComp == nil then
		return "invalid"
	end
	
	local MeshAssetName
	if MeshComp:IsA(UStaticMeshComponent) then
		MeshAssetName = MeshComp.StaticMesh and MeshComp.StaticMesh:GetName() or ""
	elseif MeshComp:IsA(USkeletalMeshComponent) then
		MeshAssetName = MeshComp:GetSkeletalMeshAsset() and MeshComp:GetSkeletalMeshAsset():GetName() or ""
	end
	
	return MeshAssetName
end

--- 临时debug用, 材质管理器功能稳定后清理
function MaterialManager:DumpInvalidMaterialCacheKeyInfo(Reason, MaterialCacheKey, MeshComp, InActorId)
	local MeshAssetName = self:GetMeshAssetName(MeshComp)

	local ActorName = ""
	if InActorId then
		local Actor = Game.ObjectActorManager:GetObjectByID(InActorId)
		ActorName = Actor and Actor:GetName() or ""
	end
	
	local MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial = MaterialCacheKeyUtils.GetMaterialIndexInfoByCacheKey(MaterialCacheKey)
	Log.Error(Reason, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial, MeshAssetName, ActorName)
end

function MaterialManager:DumpAffectedMaterialCacheKeyInfos(AffectedMaterialCacheKeys)
	local MeshComps = ""
	for MeshCompId, MaterialCacheKeys in pairs(AffectedMaterialCacheKeys) do
		local MeshComp = Game.ObjectActorManager:GetObjectByID(MeshCompId)
		MeshComps = string.format("%s, %d, %s", MeshComps, MeshCompId, MeshComp and MeshComp:GetName() or "invalid")
	end
	Log.Debug("DumpAffectedMaterialCacheKeyInfos: ", MeshComps)
end

--endregion Debug


--region Private
--------------------------------------------------internal functions------------------------------------------------
---@private
function MaterialManager:GenerateChangeMaterialSeqId()
	self.CurChangeMaterialSeqId = self.CurChangeMaterialSeqId + 1
	if self.CurChangeMaterialSeqId >= 0x7fffffff then
		self.CurChangeMaterialSeqId = 1
	end

	return self.CurChangeMaterialSeqId
end


---@private
function MaterialManager:GetMaterialByMaterialCacheKey(MeshComp, MaterialCacheKey)
	local MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial = MaterialCacheKeyUtils.GetMaterialIndexInfoByCacheKey(MaterialCacheKey)
	if bOverlayMaterial then
		return MeshComp:GetOverlayMaterial()
	end

	if bSeparateOverlapMaterial then
		return MeshComp:GetSeperateOverlayMaterial(MaterialIndex)
	end

	return MeshComp:GetMaterial(MaterialIndex)
end


---@private
function MaterialManager:SetMaterialByMaterialCacheKey(MeshComp, MaterialInst, MaterialCacheKey)
	local MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial = MaterialCacheKeyUtils.GetMaterialIndexInfoByCacheKey(MaterialCacheKey)
	if bOverlayMaterial then
		--return MeshComp:SetOverlayMaterial(MaterialInst)
		self.cppMgr:SetOverlayMaterial(MeshComp, MaterialInst)
		return
	end

	if bSeparateOverlapMaterial then
		MeshComp:SetSeperateOverlayMaterial(MaterialIndex, MaterialInst)
		return
	end

	MeshComp:SetMaterial(MaterialIndex, MaterialInst)
end


---@private
function MaterialManager:OnMaterialLoaded(InLoadId, LoadAsset)
	local ChangeMaterialSeqId = self.LoadIdToChangeMaterialSeqId[InLoadId]
	if ChangeMaterialSeqId == nil then
		return
	end

	self.LoadIdToChangeMaterialSeqId[InLoadId] = nil
	
	local ChangeMaterialReq = self.ChangeMaterialRequests[ChangeMaterialSeqId]
	if ChangeMaterialReq == nil then
		Log.Error("MaterialManager:OnMaterialLoaded, invalid change material req", ChangeMaterialSeqId)
		return
	end
	
	if LoadAsset == nil then
		Log.Error("MaterialManager:OnMaterialLoaded, invalid material asset loaded", InLoadId, ChangeMaterialReq.MaterialPath)
		return
	end
	
	ChangeMaterialReq.MaterialAssetId = Game.ObjectActorManager:GetIDByObject(LoadAsset)
	self:InternalChangeMaterial(ChangeMaterialReq)
end


---@private
---@param ChangeMaterialReq ChangeMaterialRequestTemplate
function MaterialManager:InternalChangeMaterial(ChangeMaterialReq)
	local OwnerActorId = ChangeMaterialReq.OwnerActorId
	local OwnerActor = Game.ObjectActorManager:GetObjectByID(OwnerActorId)
	if OwnerActor == nil then
		Log.Error("MaterialManager:ChangeMaterial, invalid owner actor", ChangeMaterialReq.MaterialPath)
		return
	end
	
	local bUseBodyMaterial = ChangeMaterialReq:UseBodyMaterial()
	if bUseBodyMaterial then
		local bHasBodyMaterialCacheStackInit = self.OwnerActorIdToBodyMaterialCacheKeys[OwnerActorId] ~= nil
		self:TryCacheBodyMaterialCacheKeys(OwnerActor, OwnerActorId)
		ChangeMaterialReq.AffectedMaterialCacheKeys = self.OwnerActorIdToBodyMaterialCacheKeys[OwnerActorId]
		if not bHasBodyMaterialCacheStackInit then
			self:TryInitMaterialCacheStacks(ChangeMaterialReq.OwnerActorId, ChangeMaterialReq.AffectedMaterialCacheKeys)
		end
	else
		ChangeMaterialReq.AffectedMaterialCacheKeys = self:GetAffectedMaterialCacheKeys(
			OwnerActorId, OwnerActor, ChangeMaterialReq.SearchMeshType, ChangeMaterialReq.SearchMeshName,
			ChangeMaterialReq.CustomMeshComponentIds, ChangeMaterialReq.MaterialSlotNames,
			ChangeMaterialReq.bChangeOverlayMaterial, ChangeMaterialReq.bChangeSeparateOverlayMaterial, ChangeMaterialReq.AffectedMaterialCacheKeys)

		self:TryInitMaterialCacheStacks(ChangeMaterialReq.OwnerActorId, ChangeMaterialReq.AffectedMaterialCacheKeys)
	end
	
	self:AddMaterialCacheStackItems(ChangeMaterialReq)
	
	-- 如果材质表现需要作用于attach entity，在owner的材质表现真正启动后再做, 这个是为了attach entity材质表现能够跟owner同一帧启动(仅在attach entity还未加载好时会有些错帧)
	-- 对于错帧的情况可以后续考虑加时间补偿
	if ChangeMaterialReq.AffectedAttachEntityTypes ~= nil then
		local OwnerEntity = Game.EntityManager:getEntity(ChangeMaterialReq.OwnerEntityId)
		for _, AttachEntityType in ipairs(ChangeMaterialReq.AffectedAttachEntityTypes) do
			local AttachEntityIds = OwnerEntity:GetSyncMaterialAttachEntitiesByType(AttachEntityType)
			for _, AttachEntityId in ipairs(AttachEntityIds) do
				self:ChangeAttachEntityMaterial(ChangeMaterialReq, AttachEntityId)
			end
		end
	end

	if ChangeMaterialReq.TotalLifeMs > 0 then
		ChangeMaterialReq.LifeTimerId = Game.TimerManager:CreateTimerAndStart(function()
			self:RevertMaterial(ChangeMaterialReq.ChangeMaterialSeqId)
		end, ChangeMaterialReq.TotalLifeMs, 1)
	end
end


---@private
---@param ChangeMaterialReq ChangeMaterialRequestTemplate
function MaterialManager:ChangeAttachEntityMaterial(ChangeMaterialReq, AttachEntityId)
	-- 1, 暂不支持嵌套形式的挂接物材质表现继承
	-- 2, 挂接物总是改全部材质
	local NewChangeMaterialReq = MaterialEffectParamsPool.AllocFromPool(ChangeMaterialRequestTemplate)
	NewChangeMaterialReq.Priority = ChangeMaterialReq.Priority
	NewChangeMaterialReq.MaterialPath = ChangeMaterialReq.MaterialPath
	NewChangeMaterialReq.bChangeOverlayMaterial = ChangeMaterialReq.bChangeOverlayMaterial
	NewChangeMaterialReq.bChangeSeparateOverlayMaterial = ChangeMaterialReq.bChangeSeparateOverlayMaterial

	NewChangeMaterialReq.bIsInherited = true

	local AttachEntity = Game.EntityManager:getEntity(AttachEntityId)
	local ReqId = AttachEntity:ChangeMaterial(NewChangeMaterialReq)
	ChangeMaterialReq.AttachEntityChangeMaterialReqIds[AttachEntityId] = ReqId
end


---@private
---@param ChangeMaterialReq ChangeMaterialRequestTemplate
function MaterialManager:AddMaterialCacheStackItems(ChangeMaterialReq)
	for MeshCompId, MaterialCacheKeys in pairs(ChangeMaterialReq.AffectedMaterialCacheKeys) do
		self:AddPerMeshMaterialCacheStackItems(
			MeshCompId, MaterialCacheKeys, ChangeMaterialReq.Priority, ChangeMaterialReq.MaterialAssetId, ChangeMaterialReq.ChangeMaterialSeqId)
	end
end


---@private
function MaterialManager:AddPerMeshMaterialCacheStackItems(MeshCompId, MaterialCacheKeys, Priority, MaterialAssetId, ChangeMaterialSeqId)
	local MaterialCacheStacks = self.MaterialCaches[MeshCompId].MaterialCacheStacks
	local bIsOldDefaultMaterial
	local OldEffectiveMaterialId
	
	for _, MaterialCacheKey in ipairs(MaterialCacheKeys) do
		local MaterialCacheStack = MaterialCacheStacks[MaterialCacheKey]
		local MaterialCacheItems = MaterialCacheStack.MaterialCacheItems

		OldEffectiveMaterialId = nil
		bIsOldDefaultMaterial = false
		if #MaterialCacheItems > 0 then
			OldEffectiveMaterialId = MaterialCacheItems[1].MaterialId
			bIsOldDefaultMaterial = MaterialCacheItems[1].bIsDefaultMaterial
		end

		local MaterialCacheItem = MaterialEffectParamsPool.AllocFromPool(MaterialCacheItemTemplate)
		MaterialCacheItem.Priority = Priority
		MaterialCacheItem.MaterialId = MaterialAssetId
		MaterialCacheItem.SequenceId = ChangeMaterialSeqId
		table.insert(MaterialCacheItems, MaterialCacheItem)

		if MaterialManager.bEnableLogging then
			Log.Debug("MaterialManager:AddPerMeshMaterialCacheStackItems, MeshComponent:",
				Game.ObjectActorManager:GetObjectByID(MeshCompId):GetName(), "Material:", Game.ObjectActorManager:GetObjectByID(MaterialAssetId):GetName(),
				"MaterialCacheKey:", MaterialCacheKey)
		end
		
		-- 目前材质表现一般不会分新材质，这里数量不多，直接用table sort
		if #MaterialCacheItems > 1 then
			table.sort(MaterialCacheItems, function(a, b)
				if a.Priority == b.Priority then
					return a.SequenceId > b.SequenceId
				end
				return a.Priority > b.Priority
			end)
		end

		local NewEffectiveMaterialId = MaterialCacheItems[1].MaterialId
		if OldEffectiveMaterialId ~= NewEffectiveMaterialId then
			-- 生效材质发生了变化
			local MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial = MaterialCacheKeyUtils.GetMaterialIndexInfoByCacheKey(MaterialCacheKey)
			if bIsOldDefaultMaterial then
				-- 原始材质为default material, 且 default material为空 这个只有一个overlay材质才会走到这里 就不单独放进cpp了
				local MeshComponent = Game.ObjectActorManager:GetObjectByID(MeshCompId)
				local DefaultMaterial = self.cppMgr:GetDefaultMaterialInstance(MeshComponent, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
				if DefaultMaterial == nil then
					local MaterialInst = Game.ObjectActorManager:GetObjectByID(MaterialAssetId)
					-- 为了避免每次材质栈变化都需要新建一个DynamicMaterialInstance
					local DynamicMaterialInst = UKGMaterialInstanceDynamic.CreateNew(MaterialInst, nil)
					if DynamicMaterialInst == nil then
						self:DumpInvalidMaterialCacheKeyInfo("failed to create dynamic material inst", MaterialCacheKey, MeshComponent)
						goto continue
					end

					self:SetMaterialByMaterialCacheKey(MeshComponent, DynamicMaterialInst, MaterialCacheKey)
				else
					self.cppMgr:ChangeMaterialParentById(MeshCompId, NewEffectiveMaterialId, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
				end
			else
				self.cppMgr:ChangeMaterialParentById(MeshCompId, NewEffectiveMaterialId, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
			end
		end
		
		::continue::
	end
end


---@private
---@param ChangeMaterialReq ChangeMaterialRequestTemplate
function MaterialManager:RemoveMaterialCacheStackItems(ChangeMaterialReq)
	for MeshCompId, MaterialCacheKeys in pairs(ChangeMaterialReq.AffectedMaterialCacheKeys) do
		local MaterialCacheStacks = self.MaterialCaches[MeshCompId].MaterialCacheStacks

		for _, MaterialCacheKey in ipairs(MaterialCacheKeys) do
			local MaterialCacheItems = MaterialCacheStacks[MaterialCacheKey].MaterialCacheItems

			local OldEffectiveMaterialId = MaterialCacheItems[1].MaterialId

			for Index, MaterialCacheItem in ipairs(MaterialCacheItems) do
				if MaterialCacheItem.SequenceId == ChangeMaterialReq.ChangeMaterialSeqId then
					MaterialEffectParamsPool.RecycleToPool(MaterialCacheItem)
					table.remove(MaterialCacheItems, Index)
					break
				end
			end

			-- 目前材质表现一般不会分新材质，这里数量不多，直接用table sort
			if #MaterialCacheItems > 1 then
				table.sort(MaterialCacheItems, function(a, b)
					if a.Priority == b.Priority then
						return a.SequenceId > b.SequenceId
					end
					return a.Priority > b.Priority
				end)
			end

			-- 栈中至少要保留一个default材质，不可能为空
			local NewEffectiveMaterialId = MaterialCacheItems[1].MaterialId
			if OldEffectiveMaterialId ~= NewEffectiveMaterialId then
				-- 生效材质发生了变化
				local bFallbackToDefaultMaterial = MaterialCacheItems[1].bIsDefaultMaterial
				local MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial = MaterialCacheKeyUtils.GetMaterialIndexInfoByCacheKey(MaterialCacheKey)
				if bFallbackToDefaultMaterial then
					local MeshComp = Game.ObjectActorManager:GetObjectByID(MeshCompId)

					if MaterialManager.bEnableLogging then
						local DefaultMaterial = self.cppMgr:GetDefaultMaterialInstance(MeshComp, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
						Log.Debug("MaterialManager:RemoveMaterialCacheStackItems, fallback to default material, MeshComponent:",
							MeshComp:GetName(), "MaterialCacheKey:", MaterialCacheKey, "DefaultMaterial:", DefaultMaterial and DefaultMaterial:GetName() or "invalid")
					end

					self.cppMgr:FallbackToDefaultMaterialInstance(MeshComp, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
				else

					if MaterialManager.bEnableLogging then
						local NewMaterial = Game.ObjectActorManager:GetObjectByID(NewEffectiveMaterialId)
						Log.Debug("MaterialManager:RemoveMaterialCacheStackItems, change parent to new material, MeshComponent:",
							MeshComp:GetName(), "MaterialCacheKey:", MaterialCacheKey, "DefaultMaterial:", NewMaterial and NewMaterial:GetName() or "invalid")
					end
					
					self.cppMgr:ChangeMaterialParentById(MeshCompId, NewEffectiveMaterialId, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
				end
			end
		end
	end
end


--- 初始情况下材质栈为空，需要将default材质置入材质栈的底部, 以便所有材质效果都结束的情况下能恢复到default材质
---@private
---@param MaterialCacheKeys table<number, table<number>>
function MaterialManager:TryInitMaterialCacheStacks(InActorId, InMaterialCacheKeys)
	for MeshCompId, MaterialCacheKeys in pairs(InMaterialCacheKeys) do
		self:InitMeshMaterialCacheStacks(InActorId, MeshCompId, MaterialCacheKeys)
	end
end


---@private
function MaterialManager:InitMeshMaterialCacheStacks(InActorId, MeshCompId, MaterialCacheKeys)
	local MaterialCacheSet = self.MaterialCaches[MeshCompId]
	if MaterialCacheSet == nil then
		MaterialCacheSet = MaterialEffectParamsPool.AllocFromPool(MaterialCacheSetTemplate)
		MaterialCacheSet.MeshComponentId = MeshCompId
		self.MaterialCaches[MeshCompId] = MaterialCacheSet
	end

	local MeshComponentIds = self.OwnerActorIdToMeshCompIds[InActorId]
	if MeshComponentIds == nil then
		self.OwnerActorIdToMeshCompIds[InActorId] = {}
		MeshComponentIds = self.OwnerActorIdToMeshCompIds[InActorId]
	end
	MeshComponentIds[MeshCompId] = true

	local MaterialCacheStacks = MaterialCacheSet.MaterialCacheStacks
	local MeshComponent = nil
	for _, MaterialCacheKey in ipairs(MaterialCacheKeys) do
		local MaterialCacheStack = MaterialCacheStacks[MaterialCacheKey]
		if MaterialCacheStack ~= nil then
			-- 对应material slot已经初始化过
			goto iter_material_continue
		end

		if MeshComponent == nil then
			MeshComponent = Game.ObjectActorManager:GetObjectByID(MeshCompId)
			if MeshComponent == nil then
				Log.Error("invalid mesh component")
				return
			end
		end

		local MaterialInst = self:GetMaterialByMaterialCacheKey(MeshComponent, MaterialCacheKey)

		if MaterialManager.bEnableLogging then
			local MeshAssetName = self:GetMeshAssetName(MeshComponent)
			local MaterialInstName = MaterialInst and MaterialInst:GetName() or "invalid"
			local ParentMaterialInstName = "invalid"
			if MaterialInst and MaterialInst.GetMaterialParent then
				ParentMaterialInstName = MaterialInst:GetMaterialParent():GetName()
			end
			Log.Debug("MaterialManager:InitMeshMaterialCacheStacks, MeshComponent:", MeshCompId, MeshComponent:GetName(), MeshAssetName,
				"Material:", MaterialInstName, "MaterialParent:", ParentMaterialInstName,
				"MaterialCacheKey:", MaterialCacheKey)
		end
		
		MaterialCacheStack = MaterialEffectParamsPool.AllocFromPool(MaterialCacheStackTemplate)
		MaterialCacheStacks[MaterialCacheKey] = MaterialCacheStack

		local MaterialCacheItem = MaterialEffectParamsPool.AllocFromPool(MaterialCacheItemTemplate)
		-- default材质优先级默认为-1
		MaterialCacheItem.Priority = -1
		MaterialCacheItem.bIsDefaultMaterial = true
		if MaterialInst ~= nil then
            if not MaterialInst:IsA(UKGMaterialInstanceDynamic) then
                ---------------------------------------------------------------------------------------------
                -- todo 后续这里无需这么处理, 不再使用ChangeMaterialParent的方案
                local bIsDefaultMaterialInstDynamic = false
                local NonDynamicMaterialInstance = MaterialInst
                if MaterialInst:IsA(UMaterialInstanceDynamic) then
                    bIsDefaultMaterialInstDynamic = true
                    NonDynamicMaterialInstance = MaterialInst.Parent
                    if NonDynamicMaterialInstance == nil then
                        local MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial = MaterialCacheKeyUtils.GetMaterialIndexInfoByCacheKey(MaterialCacheKey)
                        Log.Error("invalid parent material instance by material cache key", MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
                        goto iter_material_continue
                    end
                end
                ---------------------------------------------------------------------------------------------

                local MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial = MaterialCacheKeyUtils.GetMaterialIndexInfoByCacheKey(MaterialCacheKey)
                self.cppMgr:SetDefaultMaterialInstance(MeshComponent, NonDynamicMaterialInstance, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)

                -- 为了避免每次材质栈变化都需要新建一个DynamicMaterialInstance, 初始创建材质栈时, 直接创建dynamic material instance, 并在后续材质栈变化时
                -- 总是通过dynamic material instance ChangeMaterialParent的方式替换当前材质实例
                -- 同时也能截住dynamic material instance实现材质缓存的机制
                local DynamicMaterialInst = UKGMaterialInstanceDynamic.CreateNew(NonDynamicMaterialInstance, nil)
                if DynamicMaterialInst == nil then
                    self:DumpInvalidMaterialCacheKeyInfo("failed to create dynamic material inst", MaterialCacheKey, MeshComponent, InActorId)
                    goto iter_material_continue
                end

                ---------------------------------------------------------------------------------------------
                if bIsDefaultMaterialInstDynamic then
                    DynamicMaterialInst:CopyParameterOverrides(MaterialInst)
                end
                ---------------------------------------------------------------------------------------------

                self:SetMaterialByMaterialCacheKey(MeshComponent, DynamicMaterialInst, MaterialCacheKey)
            else
                local MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial = MaterialCacheKeyUtils.GetMaterialIndexInfoByCacheKey(MaterialCacheKey)
                self.cppMgr:SetDefaultMaterialInstance(MeshComponent, MaterialInst:GetMaterialParent(), MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
            end
        end
		table.insert(MaterialCacheStack.MaterialCacheItems, MaterialCacheItem)

		::iter_material_continue::
	end
end


---@private
---清理stack的过程与remove不一样，不需要去做材质fallback, 出于性能考虑，单独分离一个clear流程
function MaterialManager:ClearMaterialCacheSet(InActorId, MeshComponentId, bFallbackToDefaultMaterial)
	local MaterialCacheSet = self.MaterialCaches[MeshComponentId]
	if MaterialCacheSet ~= nil then
		local MeshComponent = Game.ObjectActorManager:GetObjectByID(MeshComponentId)
		if MaterialManager.bEnableLogging then
			Log.Debug("MaterialManager:ClearMaterialCacheSet, MeshComponent:", MeshComponentId, MeshComponent and MeshComponent:GetName() or "invalid")
		end
		
		for MaterialCacheKey, _ in pairs(MaterialCacheSet.MaterialCacheStacks) do
			local MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial = MaterialCacheKeyUtils.GetMaterialIndexInfoByCacheKey(MaterialCacheKey)
			local DefaultMaterial = self.cppMgr:GetDefaultMaterialInstance(MeshComponent, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
			if MaterialManager.bEnableLogging then
				Log.Debug("MaterialManager:ClearMaterialCacheSet, remove and fallback to default material, MeshComponent:", MeshComponent:GetName(), 
					DefaultMaterial and DefaultMaterial:GetName() or "invalid")
			end
			if DefaultMaterial ~= nil then
				self.cppMgr:RemoveDefaultMaterialInstance(MeshComponent, MaterialIndex, bOverlayMaterial, bSeparateOverlapMaterial)
			end

			-- 对于替换mesh中的asset来说, 这里不能fallback到default material, 因为目前都是在替换完asset后才执行的refresh操作, 如果此时fallback了，会导致material被覆盖掉
			if bFallbackToDefaultMaterial then
				self:SetMaterialByMaterialCacheKey(MeshComponent, DefaultMaterial, MaterialCacheKey)
			end
		end

		for _, MaterialCacheStack in pairs(MaterialCacheSet.MaterialCacheStacks) do
			for _, MaterialCacheItem in ipairs(MaterialCacheStack.MaterialCacheItems) do
				MaterialEffectParamsPool.RecycleToPool(MaterialCacheItem)
			end
			MaterialEffectParamsPool.RecycleToPool(MaterialCacheStack)
		end
		MaterialEffectParamsPool.RecycleToPool(MaterialCacheSet)
		self.MaterialCaches[MeshComponentId] = nil
	end

	local MeshComponentIds = self.OwnerActorIdToMeshCompIds[InActorId]
	if MeshComponentIds ~= nil then
		MeshComponentIds[MeshComponentId] = nil
	end
end


---@private
function MaterialManager:OnMaterialUnionAssetLoad(InLoadId, LoadAsset)
	local ReqId = self.LoadIdToChangeMaterialSeqId[InLoadId]
	if ReqId == nil then
		return
	end

	self.LoadIdToChangeMaterialSeqId[InLoadId] = nil

	local ChangeMaterialReq = self.ChangeMaterialRequests[ReqId]
	if ChangeMaterialReq == nil then
		Log.Error("MaterialManager:OnMaterialUnionAssetLoad, invalid change material req", ReqId)
		return
	end

	local ChangeMaterialParamReq = self.ChangeMaterialParamRequests[ReqId]
	if ChangeMaterialParamReq == nil then
		Log.Error("MaterialManager:OnMaterialUnionAssetLoad, invalid change material param req", ReqId)
		return
	end
	
	if LoadAsset == nil then
		Log.Error("MaterialManager:OnMaterialUnionAssetLoad, invalid material asset loaded", InLoadId, ChangeMaterialReq.MaterialPath)
		return
	end
	
	ChangeMaterialParamReq.bWaitingUnionMaterialAsset = false
	ChangeMaterialReq.MaterialAssetId = Game.ObjectActorManager:GetIDByObject(LoadAsset)
	self:InternalChangeMaterial(ChangeMaterialReq)
	self:ApplyMaterialParams(ChangeMaterialParamReq)
end


---@private
function MaterialManager:OnMaterialUnionAssetListLoad(InLoadId, LoadAssets)
	if LoadAssets == nil then
		Log.Error("invalid asset loaded")
		return
	end

	local ReqId = self.LoadIdToChangeMaterialParamSeqId[InLoadId]
	if ReqId == nil then
		return
	end

	self.LoadIdToChangeMaterialSeqId[InLoadId] = nil
	self.LoadIdToChangeMaterialParamSeqId[InLoadId] = nil

	local ChangeMaterialReq = self.ChangeMaterialRequests[ReqId]
	if ChangeMaterialReq == nil then
		Log.Error("invalid req id", ReqId)
		return
	end
	
	local ChangeMaterialParamReq = self.ChangeMaterialParamRequests[ReqId]
	if ChangeMaterialParamReq == nil then
		Log.Error("invalid req id", ReqId)
		return
	end

	ChangeMaterialParamReq.IsAssetLoaded = true

	local AssetLoadedResults = ChangeMaterialParamReq.AssetLoadedResults
	local AssetNum = LoadAssets:Num()
	if AssetNum == 1 or AssetNum ~= #AssetLoadedResults + 1 then
		Log.Error("invalid load num", InLoadId)
		return
	end
	
	local Index = 0
	while Index < AssetNum - 1 do
		local LoadAsset = LoadAssets:Get(Index)
		Index = Index + 1
		if LoadAsset == nil then
			Log.Error("invalid asset loaded", AssetLoadedResults[Index].AssetPath)
			return
		end
		
		AssetLoadedResults[Index].AssetId = Game.ObjectActorManager:GetIDByObject(LoadAsset)
	end

	ChangeMaterialReq.MaterialAssetId = Game.ObjectActorManager:GetIDByObject(LoadAssets:Get(AssetNum - 1))
	self:InternalChangeMaterial(ChangeMaterialReq)
	self:ApplyMaterialParams(ChangeMaterialParamReq)
end


---@private
function MaterialManager:OnMaterialParamAssetLoad(InLoadId, LoadAsset)
	local ChangeMaterialParamReqId = self.LoadIdToChangeMaterialParamSeqId[InLoadId]
	if ChangeMaterialParamReqId == nil then
		return
	end

	self.LoadIdToChangeMaterialParamSeqId[InLoadId] = nil

	local ChangeMaterialParamReq = self.ChangeMaterialParamRequests[ChangeMaterialParamReqId]
	if ChangeMaterialParamReq == nil then
		Log.Error("invalid load id", InLoadId)
		return
	end

	if LoadAsset == nil then
		Log.Error("invalid asset loaded", ChangeMaterialParamReq.AssetLoadedResults[1].AssetPath)
		return
	end
	
	ChangeMaterialParamReq.IsAssetLoaded = true

	ChangeMaterialParamReq.AssetLoadedResults[1].AssetId = Game.ObjectActorManager:GetIDByObject(LoadAsset)
	self:ApplyMaterialParams(ChangeMaterialParamReq)
end


---@private
function MaterialManager:OnMaterialParamAssetListLoad(InLoadId, LoadAssets)
	if LoadAssets == nil then
		Log.Error("invalid asset loaded")
		return
	end

	local ChangeMaterialParamReqId = self.LoadIdToChangeMaterialParamSeqId[InLoadId]
	if ChangeMaterialParamReqId == nil then
		return
	end

	self.LoadIdToChangeMaterialParamSeqId[InLoadId] = nil

	local ChangeMaterialParamReq = self.ChangeMaterialParamRequests[ChangeMaterialParamReqId]
	if ChangeMaterialParamReq == nil then
		Log.Error("invalid load id", InLoadId)
		return
	end

	ChangeMaterialParamReq.IsAssetLoaded = true

	local AssetLoadedResults = ChangeMaterialParamReq.AssetLoadedResults
	local AssetNum = LoadAssets:Num()
	if AssetNum ~= #AssetLoadedResults then
		Log.Error("invalid load num", InLoadId)
		return
	end

	local Index = 0
	while Index < AssetNum do
		local LoadAsset = LoadAssets:Get(Index)
		Index = Index + 1
		
		if LoadAsset == nil then
			Log.Error("invalid asset loaded", AssetLoadedResults[Index].AssetPath)
			return
		end
		AssetLoadedResults[Index].AssetId = Game.ObjectActorManager:GetIDByObject(LoadAsset)
	end

	self:ApplyMaterialParams(ChangeMaterialParamReq)
end


---@private
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:ChangeAttachEntityMaterialParam(ChangeMaterialParamReq, AttachEntityId)
	-- 1, 暂不支持嵌套形式的挂接物材质表现继承
	-- 2, 挂接物总是改全部材质
	local NewChangeMaterialParamReq = MaterialEffectParamsPool.AllocFromPool(ChangeMaterialParamRequestTemplate)
	NewChangeMaterialParamReq.EffectType = ChangeMaterialParamReq.EffectType
	NewChangeMaterialParamReq.Priority = ChangeMaterialParamReq.Priority
	NewChangeMaterialParamReq.bChangeOverlayMaterial = ChangeMaterialParamReq.bChangeOverlayMaterial
	NewChangeMaterialParamReq.bChangeSeparateOverlayMaterial = ChangeMaterialParamReq.bChangeSeparateOverlayMaterial

	NewChangeMaterialParamReq.ScalarParams = ChangeMaterialParamReq.ScalarParams
	NewChangeMaterialParamReq.VectorParams = ChangeMaterialParamReq.VectorParams
	NewChangeMaterialParamReq.TextureParams = ChangeMaterialParamReq.TextureParams
	NewChangeMaterialParamReq.FloatCurveParams = ChangeMaterialParamReq.FloatCurveParams
	NewChangeMaterialParamReq.VectorCurveParams = ChangeMaterialParamReq.VectorCurveParams
	NewChangeMaterialParamReq.ScalarLinearSampleParams = ChangeMaterialParamReq.ScalarLinearSampleParams
	NewChangeMaterialParamReq.VectorLinearSampleParams = ChangeMaterialParamReq.VectorLinearSampleParams
	NewChangeMaterialParamReq.ActorLocationParams = ChangeMaterialParamReq.ActorLocationParams

	NewChangeMaterialParamReq.bIsInherited = true

	local AttachEntity = Game.EntityManager:getEntity(AttachEntityId)
	local ReqId = AttachEntity:ChangeMaterialParam(NewChangeMaterialParamReq)
	ChangeMaterialParamReq.AttachEntityChangeMaterialParamReqIds[AttachEntityId] = ReqId
end


---@private
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:AddNewItemToPriorityQueue(ChangeMaterialParamReq)
	local OwnerActorId = ChangeMaterialParamReq.OwnerActorId
	local EffectType = ChangeMaterialParamReq.EffectType
	local PriorityQueueSet = self.OwnerActorIdToPriorityQueueSet[OwnerActorId]
	if PriorityQueueSet == nil then
		PriorityQueueSet = MaterialEffectParamsPool.AllocFromPool(MaterialParamPriorityQueueSet)
		self.OwnerActorIdToPriorityQueueSet[OwnerActorId] = PriorityQueueSet
	end

	local PriorityQueues = PriorityQueueSet.PriorityQueues
	local PriorityQueue = PriorityQueues[EffectType]
	if PriorityQueue == nil then
		PriorityQueue = MaterialEffectParamsPool.AllocFromPool(MaterialParamPriorityQueue)
		PriorityQueues[EffectType] = PriorityQueue
	end

	local PriorityQueueItem = MaterialEffectParamsPool.AllocFromPool(MaterialParamPriorityQueueItem)
	PriorityQueueItem.ChangeMaterialParamReqId = ChangeMaterialParamReq.ChangeMaterialParamSeqId
	PriorityQueueItem.Priority = ChangeMaterialParamReq.Priority
	PriorityQueueItem.SequenceId = ChangeMaterialParamReq.ChangeMaterialParamSeqId

	local PriorityQueueItems = PriorityQueue.PriorityQueueItems
	local OldEffectiveReqId
	if #PriorityQueueItems > 0 then
		OldEffectiveReqId = PriorityQueueItems[1].ChangeMaterialParamReqId
	end

	table.insert(PriorityQueueItems, PriorityQueueItem)

	-- 现在材质表现用的比较少, 这里数量不多
	if #PriorityQueueItems > 1 then
		table.sort(PriorityQueueItems, function(a, b)
			if a.Priority == b.Priority then
				return a.SequenceId > b.SequenceId
			end
			return a.Priority > b.Priority
		end)
	end

	local NewEffectiveReqId = PriorityQueueItems[1].ChangeMaterialParamReqId
	if OldEffectiveReqId ~= NewEffectiveReqId then
		if OldEffectiveReqId ~= nil then
			local OldChangeMaterialParamReq = self.ChangeMaterialParamRequests[OldEffectiveReqId]
			self:DeactivateMaterialParams(OldChangeMaterialParamReq)
		end

		local NewChangeMaterialParamReq = self.ChangeMaterialParamRequests[NewEffectiveReqId]
		self:ActivateOrSetMaterialParams(NewChangeMaterialParamReq)
	end
end


---@private
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:ApplyMaterialParams(ChangeMaterialParamReq)
	local OwnerActorId = ChangeMaterialParamReq.OwnerActorId
	local OwnerActor = Game.ObjectActorManager:GetObjectByID(OwnerActorId)
	if OwnerActor == nil then
		Log.Error("invalid owner actor")
		return
	end
	
	local bUseBodyMaterial = ChangeMaterialParamReq:UseBodyMaterial()
	if bUseBodyMaterial then
		local bHasBodyMaterialCacheStackInit = self.OwnerActorIdToBodyMaterialCacheKeys[OwnerActorId] ~= nil
		self:TryCacheBodyMaterialCacheKeys(OwnerActor, OwnerActorId)
		ChangeMaterialParamReq.AffectedMaterialCacheKeys = self.OwnerActorIdToBodyMaterialCacheKeys[OwnerActorId]

		if not bHasBodyMaterialCacheStackInit then
			self:TryInitMaterialCacheStacks(OwnerActorId, ChangeMaterialParamReq.AffectedMaterialCacheKeys)
		end
		
		self:TryCacheBodyMaterialInstanceSet(OwnerActor, OwnerActorId)
		ChangeMaterialParamReq.MaterialInstanceSetId = self.OwnerActorIdToBodyMaterialInstanceSetId[OwnerActorId]
		ChangeMaterialParamReq.bUseSharedMaterialInstanceSetId = true
	else
		ChangeMaterialParamReq.AffectedMaterialCacheKeys = self:GetAffectedMaterialCacheKeys(
			OwnerActorId, OwnerActor, ChangeMaterialParamReq.SearchMeshType, ChangeMaterialParamReq.SearchMeshName, ChangeMaterialParamReq.CustomMeshComponentIds, 
			ChangeMaterialParamReq.MaterialSlotNames, ChangeMaterialParamReq.bChangeOverlayMaterial, ChangeMaterialParamReq.bChangeSeparateOverlayMaterial,
			ChangeMaterialParamReq.AffectedMaterialCacheKeys)

		self:TryInitMaterialCacheStacks(OwnerActorId, ChangeMaterialParamReq.AffectedMaterialCacheKeys)

		self:GetAffectedMaterialInstances(ChangeMaterialParamReq.AffectedMaterialCacheKeys, TempVal_MaterialInstanceArray)
		ChangeMaterialParamReq.MaterialInstanceSetId = self.cppMgr:AddMaterialInstanceSet(TempVal_MaterialInstanceArray)
		TempVal_MaterialInstanceArray:Clear()
	end

	local EffectType = ChangeMaterialParamReq.EffectType
	if EffectType == nil then
		-- 不走优先级控制, 对于简单物件来说没必要用优先级控制
		self:InternalSetMaterialParams(ChangeMaterialParamReq)
	else
		self.cppMgr:RemoveTransientTaskByEffectType(OwnerActorId, EffectType)
		self:AddNewItemToPriorityQueue(ChangeMaterialParamReq)
	end

	if ChangeMaterialParamReq.AffectedAttachEntityTypes ~= nil then
		local OwnerEntity = Game.EntityManager:getEntity(ChangeMaterialParamReq.OwnerEntityId)
		for _, AttachEntityType in ipairs(ChangeMaterialParamReq.AffectedAttachEntityTypes) do
			local AttachEntityIds = OwnerEntity:GetSyncMaterialAttachEntitiesByType(AttachEntityType)
			for _, AttachEntityId in ipairs(AttachEntityIds) do
				self:ChangeAttachEntityMaterialParam(ChangeMaterialParamReq, AttachEntityId)
			end
		end
	end

	if ChangeMaterialParamReq.TotalLifeMs > 0 then
		ChangeMaterialParamReq.LifeTimerId = Game.TimerManager:CreateTimerAndStart(function()
			self:RevertMaterialParam(ChangeMaterialParamReq.ChangeMaterialParamSeqId)
		end, ChangeMaterialParamReq.TotalLifeMs, 1)
	end
end


---@private
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:RemoveMaterialParams(ChangeMaterialParamReq)
	local EffectType = ChangeMaterialParamReq.EffectType
	if EffectType == nil then
		-- 不走优先级控制, 对于简单物件来说没必要用优先级控制
		self:InternalRevertMaterialParams(ChangeMaterialParamReq)
	else
		local OwnerActorId = ChangeMaterialParamReq.OwnerActorId
		local PriorityQueueSet = self.OwnerActorIdToPriorityQueueSet[OwnerActorId]
		local PriorityQueue = PriorityQueueSet.PriorityQueues[EffectType]
		local PriorityQueueItems = PriorityQueue.PriorityQueueItems

		local OldEffectiveReqId = PriorityQueueItems[1].ChangeMaterialParamReqId

		for Index, PriorityQueueItem in ipairs(PriorityQueueItems) do
			if PriorityQueueItem.SequenceId == ChangeMaterialParamReq.ChangeMaterialParamSeqId then
				MaterialEffectParamsPool.RecycleToPool(PriorityQueueItem)
				table.remove(PriorityQueueItems, Index)
				break
			end
		end

		-- 现在材质表现用的比较少, 这里数量不多
		if #PriorityQueueItems > 1 then
			table.sort(PriorityQueueItems, function(a, b)
				if a.Priority == b.Priority then
					return a.SequenceId > b.SequenceId
				end
				return a.Priority > b.Priority
			end)
		end

		local NewEffectiveReqId
		if #PriorityQueueItems > 0 then
			NewEffectiveReqId = PriorityQueueItems[1].ChangeMaterialParamReqId
		end

		if OldEffectiveReqId == ChangeMaterialParamReq.ChangeMaterialParamSeqId then
			self:SetAllMaterialParamsToDefault(ChangeMaterialParamReq)
		end
		
		if not ChangeMaterialParamReq.bUseSharedMaterialInstanceSetId then
			self.cppMgr:RemoveMaterialInstanceSet(ChangeMaterialParamReq.MaterialInstanceSetId)
		end

		for _, TaskId in ipairs(ChangeMaterialParamReq.MaterialParamUpdateTaskIds) do
			self.cppMgr:RemoveMaterialParamUpdateTask(TaskId)
		end

		if OldEffectiveReqId ~= NewEffectiveReqId and NewEffectiveReqId ~= nil then
			local NewChangeMaterialParamReq = self.ChangeMaterialParamRequests[NewEffectiveReqId]
			self:ActivateOrSetMaterialParams(NewChangeMaterialParamReq)
		end
	end
end


---@private
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:IsChangeMaterialParamActive(ChangeMaterialParamReq)
	if ChangeMaterialParamReq.EffectType == nil then
		return true
	end

	if ChangeMaterialParamReq.bWaitingUnionMaterialAsset or (ChangeMaterialParamReq.bNeedLoadAsset and ChangeMaterialParamReq.IsAssetLoaded == false) then
		return false
	end

	local OwnerActorId = ChangeMaterialParamReq.OwnerActorId
	local PriorityQueueSet = self.OwnerActorIdToPriorityQueueSet[OwnerActorId]
	local PriorityQueue = PriorityQueueSet.PriorityQueues[ChangeMaterialParamReq.EffectType]
	local PriorityQueueItems = PriorityQueue.PriorityQueueItems
	return PriorityQueueItems[1].ChangeMaterialParamReqId == ChangeMaterialParamReq.ChangeMaterialParamSeqId
end


---@private
function MaterialManager:GetRemapInfo(CurveObj, RemapTime)
	if RemapTime == nil or RemapTime <= 1e-4 then
		Log.ErrorFormat("invalid remap time %f", RemapTime)
		return false, 0.0
	end

	local MinTime, MaxTime = 0.0, 0.0
	MinTime, MaxTime = CurveObj:GetTimeRange(MinTime, MaxTime)
	local CurveTimeRange = MaxTime - MinTime
	if CurveTimeRange <= 1e-4 then
		Log.ErrorFormat("invalid curve time range %f", CurveTimeRange)
		return false, 0.0
	end

	return true, CurveTimeRange / RemapTime
end


---@private
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:SetAllMaterialParamsToDefault(ChangeMaterialParamReq)
	if ChangeMaterialParamReq.ScalarParams then
		for ParamName, _ in pairs(ChangeMaterialParamReq.ScalarParams) do
			self.cppMgr:SetScalarParameterToDefaultBySetId(ChangeMaterialParamReq.MaterialInstanceSetId, ParamName)
		end
	end

	if ChangeMaterialParamReq.VectorParams then
		for ParamName, _ in pairs(ChangeMaterialParamReq.VectorParams) do
			self.cppMgr:SetVectorParameterToDefaultBySetId(ChangeMaterialParamReq.MaterialInstanceSetId, ParamName)
		end
	end

	if ChangeMaterialParamReq.TextureParams then
		for ParamName, _ in pairs(ChangeMaterialParamReq.TextureParams) do
			self.cppMgr:SetTextureParameterToDefaultBySetId(ChangeMaterialParamReq.MaterialInstanceSetId, ParamName)
		end
	end

	if ChangeMaterialParamReq.FloatCurveParams then
		for ParamName, _ in pairs(ChangeMaterialParamReq.FloatCurveParams) do
			self.cppMgr:SetScalarParameterToDefaultBySetId(ChangeMaterialParamReq.MaterialInstanceSetId, ParamName)
		end
	end

	if ChangeMaterialParamReq.VectorCurveParams then
		for ParamName, _ in pairs(ChangeMaterialParamReq.VectorCurveParams) do
			self.cppMgr:SetVectorParameterToDefaultBySetId(ChangeMaterialParamReq.MaterialInstanceSetId, ParamName)
		end
	end

	if ChangeMaterialParamReq.VectorLinearSampleParams then
		for ParamName, _ in pairs(ChangeMaterialParamReq.VectorLinearSampleParams) do
			self.cppMgr:SetVectorParameterToDefaultBySetId(ChangeMaterialParamReq.MaterialInstanceSetId, ParamName)
		end
	end

	if ChangeMaterialParamReq.ScalarLinearSampleParams then
		for ParamName, _ in pairs(ChangeMaterialParamReq.ScalarLinearSampleParams) do
			self.cppMgr:SetScalarParameterToDefaultBySetId(ChangeMaterialParamReq.MaterialInstanceSetId, ParamName)
		end
	end

	if ChangeMaterialParamReq.ActorLocationParams then
		for ParamName, _ in pairs(ChangeMaterialParamReq.ActorLocationParams) do
			self.cppMgr:SetVectorParameterToDefaultBySetId(ChangeMaterialParamReq.MaterialInstanceSetId, ParamName)
		end
	end
end

---@private
function MaterialManager:GetAffectedMaterialInstances(AffectedMaterialCacheKeys, OutMaterialInstances)
	for MeshCompId, MaterialCacheKeys in pairs(AffectedMaterialCacheKeys) do
		local MeshComp = Game.ObjectActorManager:GetObjectByID(MeshCompId)
		if MeshComp == nil then
			Log.Error("invalid mesh component", MeshCompId)
			return
		end

		for _, MaterialCacheKey in ipairs(MaterialCacheKeys) do
			local DynamicMaterialInst = self:GetMaterialByMaterialCacheKey(MeshComp, MaterialCacheKey)
			if DynamicMaterialInst ~= nil then
				OutMaterialInstances:Add(DynamicMaterialInst)
			end
		end
	end
end


---@private
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:InitConstMaterialParams(ChangeMaterialParamReq)
	-- 目前绝大部分修改材质表现的任务 单次基本都只会修改几个参数, 数量很少, 所以这里写法上先保留for循环然后设置参数的形式
	if ChangeMaterialParamReq.ScalarParams then
		for ParamName, ParamVal in pairs(ChangeMaterialParamReq.ScalarParams) do
			self.cppMgr:SetScalarParameterBySetId(ChangeMaterialParamReq.MaterialInstanceSetId, ParamName, ParamVal)
		end
	end

	if ChangeMaterialParamReq.VectorParams then
		for ParamName, ParamVal in pairs(ChangeMaterialParamReq.VectorParams) do
			self.cppMgr:SetVectorParameterBySetId(ChangeMaterialParamReq.MaterialInstanceSetId, ParamName, ParamVal.R, ParamVal.G, ParamVal.B, ParamVal.A)
		end
	end

	for _, LoadResult in ipairs(ChangeMaterialParamReq.AssetLoadedResults) do
		if LoadResult.AssetType == MATERIAL_PARAM_ASSET_TYPE.Texture then
			local ParamName = LoadResult.ParamName
			local AssetObj = Game.ObjectActorManager:GetObjectByID(LoadResult.AssetId)
			if AssetObj == nil then
				Log.Error("invalid material param asset")
				return
			end

			self.cppMgr:SetTextureParameterBySetId(ChangeMaterialParamReq.MaterialInstanceSetId, ParamName, AssetObj)
		end
	end
end


---@private
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:InternalSetMaterialParams(ChangeMaterialParamReq)
	ChangeMaterialParamReq.bHasInit = true

	self:InitConstMaterialParams(ChangeMaterialParamReq)
	self:AddMaterialParamUpdateTasks(ChangeMaterialParamReq)
end

---@private
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:AddMaterialParamUpdateTasks(ChangeMaterialParamReq)
	for _, LoadResult in ipairs(ChangeMaterialParamReq.AssetLoadedResults) do
		local ParamName = LoadResult.ParamName
		local AssetObj = Game.ObjectActorManager:GetObjectByID(LoadResult.AssetId)
		if AssetObj == nil then
			Log.Error("invalid material param asset")
			goto continue
		end

		if LoadResult.AssetType == MATERIAL_PARAM_ASSET_TYPE.FloatCurve then
			local MaterialCurveParam = ChangeMaterialParamReq.FloatCurveParams[ParamName]
			local bRemap, RemapScale = self:GetRemapInfo(AssetObj, MaterialCurveParam.RemapTime)
			local TaskId = self.cppMgr:AddFloatCurveParamBySetId(
				ParamName, ChangeMaterialParamReq.MaterialInstanceSetId, AssetObj, bRemap, RemapScale, MaterialCurveParam.bEnableLoop)

			if TaskId ~= 0 then
				table.insert(ChangeMaterialParamReq.MaterialParamUpdateTaskIds, TaskId)
			end

		elseif LoadResult.AssetType == MATERIAL_PARAM_ASSET_TYPE.VectorCurve then
			local MaterialCurveParam = ChangeMaterialParamReq.VectorCurveParams[ParamName]
			local bRemap, RemapScale = self:GetRemapInfo(AssetObj, MaterialCurveParam.RemapTime)
			local TaskId = self.cppMgr:AddVectorCurveParamBySetId(
				ParamName, ChangeMaterialParamReq.MaterialInstanceSetId, AssetObj, bRemap, RemapScale, MaterialCurveParam.bEnableLoop)

			if TaskId ~= 0 then
				table.insert(ChangeMaterialParamReq.MaterialParamUpdateTaskIds, TaskId)
			end
		end

		::continue::
	end

	if ChangeMaterialParamReq.VectorLinearSampleParams then
		for ParamName, ParamVal in pairs(ChangeMaterialParamReq.VectorLinearSampleParams) do
			local TaskId = self.cppMgr:AddVectorLinearSampleParamBySetId(
				ParamName, ChangeMaterialParamReq.MaterialInstanceSetId,
				ParamVal.StartR, ParamVal.StartG, ParamVal.StartB, ParamVal.StartA, ParamVal.EndR, ParamVal.EndG, ParamVal.EndB, ParamVal.EndA, ParamVal.Duration
			)

			if TaskId ~= 0 then
				table.insert(ChangeMaterialParamReq.MaterialParamUpdateTaskIds, TaskId)
			end
		end
	end

	if ChangeMaterialParamReq.ScalarLinearSampleParams then
		for ParamName, ParamVal in pairs(ChangeMaterialParamReq.ScalarLinearSampleParams) do
			local TaskId = self.cppMgr:AddLinearSampleParamBySetId(
				ParamName, ChangeMaterialParamReq.MaterialInstanceSetId, ParamVal.StartVal, ParamVal.EndVal, ParamVal.Duration
			)

			if TaskId ~= 0 then
				table.insert(ChangeMaterialParamReq.MaterialParamUpdateTaskIds, TaskId)
			end
		end
	end

	if ChangeMaterialParamReq.ActorLocationParams then
		for ParamName, ParamVal in pairs(ChangeMaterialParamReq.ActorLocationParams) do
			local Actor = Game.ObjectActorManager:GetObjectByID(ParamVal)
			local TaskId = self.cppMgr:AddActorLocationParamBySetId(ParamName, ChangeMaterialParamReq.MaterialInstanceSetId, Actor)
			if TaskId ~= 0 then
				table.insert(ChangeMaterialParamReq.MaterialParamUpdateTaskIds, TaskId)
			end
		end
	end
end


---@private
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:InternalRevertMaterialParams(ChangeMaterialParamReq)
	self:SetAllMaterialParamsToDefault(ChangeMaterialParamReq)

	if not ChangeMaterialParamReq.bUseSharedMaterialInstanceSetId then
		self.cppMgr:RemoveMaterialInstanceSet(ChangeMaterialParamReq.MaterialInstanceSetId)
	end
	
	for _, TaskId in ipairs(ChangeMaterialParamReq.MaterialParamUpdateTaskIds) do
		self.cppMgr:RemoveMaterialParamUpdateTask(TaskId)
	end
end

-- 这块逻辑后续按需新增
-----@private
-----@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:ActivateOrSetMaterialParams(ChangeMaterialParamReq)
	if not ChangeMaterialParamReq.bHasInit then
		self:InternalSetMaterialParams(ChangeMaterialParamReq)
		return
	end

	self:InitConstMaterialParams(ChangeMaterialParamReq)

	for _, TaskId in ipairs(ChangeMaterialParamReq.MaterialParamUpdateTaskIds) do
		self.cppMgr:ResumeMaterialParamUpdateTask(TaskId)
	end
end


-----@private
-----@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:DeactivateMaterialParams(ChangeMaterialParamReq)
	self:SetAllMaterialParamsToDefault(ChangeMaterialParamReq)

	for _, TaskId in ipairs(ChangeMaterialParamReq.MaterialParamUpdateTaskIds) do
		self.cppMgr:PauseMaterialParamUpdateTask(TaskId)
	end
end


---@private
---@param ChangeMaterialParamReq ChangeMaterialParamRequestTemplate
function MaterialManager:AssembleMaterialParamsAssets(ChangeMaterialParamReq)
	table.clear(TempVal_MaterialParamAssetsToLoad)

	if ChangeMaterialParamReq.TextureParams then
		for ParamName, TexturePath in pairs(ChangeMaterialParamReq.TextureParams) do
			if TexturePath == nil or TexturePath == "" then
				Log.Error("invalid asset path", ParamName)
			end
			
			table.insert(TempVal_MaterialParamAssetsToLoad, TexturePath)

			local LoadParam = {
				ParamName = ParamName,
				AssetType = MATERIAL_PARAM_ASSET_TYPE.Texture,
				AssetPath = TexturePath
			}
			table.insert(ChangeMaterialParamReq.AssetLoadedResults, LoadParam)
		end
	end

	if ChangeMaterialParamReq.FloatCurveParams then
		for ParamName, CurveParam in pairs(ChangeMaterialParamReq.FloatCurveParams) do
			if CurveParam.AssetPath == nil or CurveParam.AssetPath == "" then
				Log.Error("invalid asset path", ParamName)
			end
			
			table.insert(TempVal_MaterialParamAssetsToLoad, CurveParam.AssetPath)

			local LoadParam = {
				ParamName = ParamName,
				AssetType = MATERIAL_PARAM_ASSET_TYPE.FloatCurve,
				AssetPath = CurveParam.AssetPath
			}
			table.insert(ChangeMaterialParamReq.AssetLoadedResults, LoadParam)
		end
	end

	if ChangeMaterialParamReq.VectorCurveParams then
		for ParamName, CurveParam in pairs(ChangeMaterialParamReq.VectorCurveParams) do
			if CurveParam.AssetPath == nil or CurveParam.AssetPath == "" then
				Log.Error("invalid asset path", ParamName)
			end
			
			table.insert(TempVal_MaterialParamAssetsToLoad, CurveParam.AssetPath)

			local LoadParam = {
				ParamName = ParamName,
				AssetType = MATERIAL_PARAM_ASSET_TYPE.VectorCurve,
				AssetPath = CurveParam.AssetPath
			}
			table.insert(ChangeMaterialParamReq.AssetLoadedResults, LoadParam)
		end
	end

	return TempVal_MaterialParamAssetsToLoad
end


function MaterialManager:TryCacheBodyMaterialCacheKeys(InActor, ActorId)
	local MaterialCacheKeys = self.OwnerActorIdToBodyMaterialCacheKeys[ActorId]
	if MaterialCacheKeys ~= nil then
		return
	end

	self.OwnerActorIdToBodyMaterialCacheKeys[ActorId] = {}
	MaterialCacheKeys = self.OwnerActorIdToBodyMaterialCacheKeys[ActorId]
	
	local Comps = ActorUtil.GetComponentsByClasses(InActor, MaterialManager.ValidMeshCompClasses, false)
	for _, Comp in pairs(Comps:ToTable()) do
		local CompId = Game.ObjectActorManager:GetIDByObject(Comp)
		
		if self.OwnerActorIdToExcludedMeshCompIds[ActorId] ~= nil then
			local ExcludedMeshCompIds = self.OwnerActorIdToExcludedMeshCompIds[ActorId]
			if ExcludedMeshCompIds[CompId] ~= nil then
				goto continue
			end
		end
		
		MaterialCacheKeys[CompId] = {}
		local CompAffectedMaterialCacheKeys = MaterialCacheKeys[CompId]
		
		local Materials = Comp:GetMaterials()
		local Index = 0
		local MaterialNum = Materials:Num()
		while Index < MaterialNum do
			local Material = Materials:Get(Index)
			if Material ~= nil then
				local MaterialCacheKey = MaterialCacheKeyUtils.GetMaterialCacheKey(Index, false, false)
				table.insert(CompAffectedMaterialCacheKeys, MaterialCacheKey)
			end
			Index = Index + 1
		end
		
		::continue::
	end
end


---@private
function MaterialManager:TryCacheBodyMaterialInstanceSet(InActor, ActorId)
	local SetId = self.OwnerActorIdToBodyMaterialInstanceSetId[ActorId]
	if SetId ~= nil then
		return
	end

	local MaterialCacheKeys = self.OwnerActorIdToBodyMaterialCacheKeys[ActorId]
	if MaterialCacheKeys == nil then
		return
	end

	self:GetAffectedMaterialInstances(MaterialCacheKeys, TempVal_MaterialInstanceArray)
	self.OwnerActorIdToBodyMaterialInstanceSetId[ActorId] = self.cppMgr:AddMaterialInstanceSet(TempVal_MaterialInstanceArray)
	TempVal_MaterialInstanceArray:Clear()
end


---@private
function MaterialManager:RemoveBodyMaterialInstanceSetCache(ActorId)
	local SetId = self.OwnerActorIdToBodyMaterialInstanceSetId[ActorId]
	if SetId ~= nil then
		self.cppMgr:RemoveMaterialInstanceSet(SetId)
		self.OwnerActorIdToBodyMaterialInstanceSetId[ActorId] = nil
	end
end

---@private
function MaterialManager:SetCameraDitherMaterialInfo()
	local CharacterCameraDitherMaterialInstance = Game.AssetManager:SyncLoadAsset(ViewResourceConst.CHARACTER_CAMERA_DITHER_MATERIAL_PATH)
	if not CharacterCameraDitherMaterialInstance then
		Log.Error("invalid character camera dither material instance", ViewResourceConst.CHARACTER_CAMERA_DITHER_MATERIAL_PATH)
	else
		self.cppMgr:SetCharacterCameraDitherOverlayMaterialInstance(CharacterCameraDitherMaterialInstance)
	end

	local EnvCameraDitherMaterialInstance = Game.AssetManager:SyncLoadAsset(ViewResourceConst.ENV_CAMERA_DITHER_MATERIAL_PATH)
	if not EnvCameraDitherMaterialInstance then
		Log.Error("invalid env camera dither material instance", ViewResourceConst.CHARACTER_CAMERA_DITHER_MATERIAL_PATH)
	else
		self.cppMgr:SetEnvCameraDitherOverlayMaterialInstance(EnvCameraDitherMaterialInstance)
	end
	
	self.cppMgr:SetCharacterTypeActorTag(ViewResourceConst.CAMERA_DITHER_CHARACTER_TYPE_TAG)
	self.cppMgr:SetValidMeshComponentTypes(MaterialManager.ValidMeshCompClasses)
	-- 临时屏蔽camera dither, 需要时通过GM指令打开验证
	self.cppMgr:SetEnableForceOverlay(false)
end

function MaterialManager:OnWorldMapLoadComplete(_)
	self.cppMgr:ClearAllForceOverlayRecords()
end

---@private 
function MaterialManager:GetAffectedMaterialCacheKeysInComponent(
		ActorId, MeshComp, MaterialSlotNames, bChangeOverlayMaterial, bChangeSeparateOverlayMaterial, OutAffectedMaterialCacheKeys)
	local MeshCompId = Game.ObjectActorManager:GetIDByObject(MeshComp)

	if self.OwnerActorIdToExcludedMeshCompIds[ActorId] ~= nil then
		local ExcludedMeshCompIds = self.OwnerActorIdToExcludedMeshCompIds[ActorId]
		if ExcludedMeshCompIds[MeshCompId] ~= nil then
			return
		end
	end
	
	if OutAffectedMaterialCacheKeys[MeshCompId] == nil then
		-- todo 这里需要的话后续也可以补一下对象池
		OutAffectedMaterialCacheKeys[MeshCompId] = {}
	end

	local CompAffectedMaterialCacheKeys = OutAffectedMaterialCacheKeys[MeshCompId]
	if bChangeOverlayMaterial then
		local MaterialCacheKey = MaterialCacheKeyUtils.GetMaterialCacheKey(0, true, false)
		table.insert(CompAffectedMaterialCacheKeys, MaterialCacheKey)
		return
	end

	if MaterialSlotNames == nil then
		local Materials = MeshComp:GetMaterials()
		local Index = 0
		local MaterialNum = Materials:Num()
		while Index < MaterialNum do
			local Material = Materials:Get(Index)
			if Material ~= nil then
				local MaterialCacheKey = MaterialCacheKeyUtils.GetMaterialCacheKey(Index, false, false)
				table.insert(CompAffectedMaterialCacheKeys, MaterialCacheKey)
			end
			Index = Index + 1
		end

		if bChangeSeparateOverlayMaterial then
			local SeparateMaterials = MeshComp:GetSeperateOverlayMaterials()
			Index = 0
			MaterialNum = SeparateMaterials:Num()
			while Index < MaterialNum do
				local Material = SeparateMaterials:Get(Index)
				if Material ~= nil then
					local MaterialCacheKey = MaterialCacheKeyUtils.GetMaterialCacheKey(Index, false, true)
					table.insert(CompAffectedMaterialCacheKeys, MaterialCacheKey)
				end
				Index = Index + 1
			end
		end
	else
		for _, MaterialSlotName in ipairs(MaterialSlotNames) do
			local MaterialIndex = MeshComp:GetMaterialIndex(MaterialSlotName)
			local Material = MeshComp:GetMaterial(MaterialIndex)
			if Material ~= nil then
				local MaterialCacheKey = MaterialCacheKeyUtils.GetMaterialCacheKey(MaterialIndex, false, false)
				table.insert(CompAffectedMaterialCacheKeys, MaterialCacheKey)
			end

			if bChangeSeparateOverlayMaterial then
				local SeparateMaterialIndex = MeshComp:GetSeperateOverlayMaterialIndex(MaterialSlotName)
				local SeparateMaterial = MeshComp:GetSeperateOverlayMaterial(MaterialIndex)
				if SeparateMaterial ~= nil then
					local MaterialCacheKey = MaterialCacheKeyUtils.GetMaterialCacheKey(SeparateMaterialIndex, false, true)
					table.insert(CompAffectedMaterialCacheKeys, MaterialCacheKey)
				end
			end
		end
	end
end


---@param SearchMeshType SEARCH_MESH_TYPE
---@private
function MaterialManager:GetAffectedMaterialCacheKeys(InActorId, InActor, SearchMeshType, MeshName, CustomMeshCompIds, MaterialSlotNames, bChangeOverlayMaterial,
													  bChangeSeparateOverlayMaterial, OutAffectedMaterialCacheKeys)
	if OutAffectedMaterialCacheKeys == nil then
		OutAffectedMaterialCacheKeys = {}
	end
	
	if SearchMeshType == SEARCH_MESH_TYPE.SearchAllMesh then
		local Comps = ActorUtil.GetComponentsByClasses(InActor, MaterialManager.ValidMeshCompClasses, true)
		for _, Comp in pairs(Comps:ToTable()) do
			self:GetAffectedMaterialCacheKeysInComponent(
				InActorId, Comp, MaterialSlotNames, bChangeOverlayMaterial, bChangeSeparateOverlayMaterial, OutAffectedMaterialCacheKeys)
		end

	elseif SearchMeshType == SEARCH_MESH_TYPE.SearchSelfMeshes then
		local Comps = ActorUtil.GetComponentsByClasses(InActor, MaterialManager.ValidMeshCompClasses, false)
		for _, Comp in pairs(Comps:ToTable()) do
			self:GetAffectedMaterialCacheKeysInComponent(
				InActorId, Comp, MaterialSlotNames, bChangeOverlayMaterial, bChangeSeparateOverlayMaterial, OutAffectedMaterialCacheKeys)
		end

	elseif SearchMeshType == SEARCH_MESH_TYPE.SearchMeshByName then
		-- 目前技能模块用的比较多 先维持这块逻辑
		local Comp = ActorUtil.GetComponentByNameAndClass(InActor, MeshName, UMeshComponent, false)
		if Comp ~= nil then
			self:GetAffectedMaterialCacheKeysInComponent(
				InActorId, Comp, MaterialSlotNames, bChangeOverlayMaterial, bChangeSeparateOverlayMaterial, OutAffectedMaterialCacheKeys)
		end

	elseif SearchMeshType == SEARCH_MESH_TYPE.UseCustomMeshComps and CustomMeshCompIds ~= nil then
		for _, CompId in ipairs(CustomMeshCompIds) do
			local Comp = Game.ObjectActorManager:GetObjectByID(CompId)
			if Comp ~= nil then
				self:GetAffectedMaterialCacheKeysInComponent(
					InActorId, Comp, MaterialSlotNames, bChangeOverlayMaterial, bChangeSeparateOverlayMaterial, OutAffectedMaterialCacheKeys)
			end
		end
	end
	
	return OutAffectedMaterialCacheKeys
end
--endregion Private

return MaterialManager
