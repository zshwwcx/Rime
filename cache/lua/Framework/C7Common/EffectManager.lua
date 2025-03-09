local ActorUtil = import("KGActorUtil")
local ComponentUtil = import("KGComponentUtil")
local NiagaraFunctionLibrary = import("NiagaraFunctionLibrary")
local EPropertyClass = import("EPropertyClass")
local UNiagaraSystem = import("NiagaraSystem")
local EKGNiagaraTimeoutState = import("EKGNiagaraTimeoutState")
local ERelativeTransformSpace = import("ERelativeTransformSpace")

local const = kg_require("Shared.Const")
local AbilityConst = kg_require("Shared.Const.AbilityConst")
local UBSFunc = import("BSFunctionLibrary")
local NIAGARA_HIDDEN_REASON = const.NIAGARA_HIDDEN_REASON
local NIAGARA_EFFECT_TAG = const.NIAGARA_EFFECT_TAG
local NIAGARA_SOURCE_TYPE = const.NIAGARA_SOURCE_TYPE

local worldConst = kg_require("Shared.Const.WorldConst")

NIAGARA_EFFECT_TYPE_FOR_PRIORITY_CULLING = NIAGARA_EFFECT_TYPE_FOR_PRIORITY_CULLING or {
	SKILL = 1, -- 技能、buff、子弹、法术场(当前所有通过timeline播放的特效都算作技能类特效)
	LOCOMOTION = 2, -- locomotion, 主要来源是动作中配置的AnimNotify
	HIT = 3, -- 受击特效
	ATTACHMENT = 4, -- 挂接物、武器等特效
	APPEARANCE = 5, -- 外观相关, ModelLib中配置
}

EffectManager = DefineClass("EffectManager")

-- 出于性能考虑定义临时变量
TempVal_Vec3 = FVector()
TempVal_Vec2 = FVector2D()
TempVal_LinearColor = FLinearColor()
TempVal_CompTagsArray = slua.Array(EPropertyClass.Name)
TempVal_BoneNamesArray = slua.Array(EPropertyClass.Name)
TempVal_NiagaraAssetsNeedsToLoad = TempVal_NiagaraAssetsNeedsToLoad or {}

EffectManager.TempVal_EmptyVector = FVector(0, 0, 0) 
EffectManager.TempVal_EmptyRotator = FRotator(0, 0, 0) 
EffectManager.TempVal_IdentityTransform = FTransform() 
EffectManager.TempVal_Transform = M3D.Transform()

-- 所有需要EffectManager中设置的通用EffectTag列在这里
EffectManager.CommonEffectTags = {
	[NIAGARA_EFFECT_TAG.ENEMY] = true,
	[NIAGARA_EFFECT_TAG.TEAMMATE] = true,
	[NIAGARA_EFFECT_TAG.BATTLE] = true,
}

-- 用于特效裁剪的关卡类型
EffectManager.LevelTypeForPriorityCulling = {
	SMALL_SCALE_BATTLE = 0,
	MEDIUM_SCALE_BATTLE = 1,
	LARGE_SCALE_BATTLE = 2
}

-- level type到特效裁剪关卡类型映射
EffectManager.LevelTypeToBattleLevel = {}
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.BIGWORLD] = EffectManager.LevelTypeForPriorityCulling.LARGE_SCALE_BATTLE
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.DUNGEON] = EffectManager.LevelTypeForPriorityCulling.SMALL_SCALE_BATTLE
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.TEAM_ARENA_33] = EffectManager.LevelTypeForPriorityCulling.SMALL_SCALE_BATTLE
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.GUILD_STATION] = EffectManager.LevelTypeForPriorityCulling.MEDIUM_SCALE_BATTLE
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.MULTI_PVP] = EffectManager.LevelTypeForPriorityCulling.LARGE_SCALE_BATTLE
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.PLANE] = EffectManager.LevelTypeForPriorityCulling.SMALL_SCALE_BATTLE
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.TEST_MAP] = EffectManager.LevelTypeForPriorityCulling.SMALL_SCALE_BATTLE
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.TOWER_CLIMB] = EffectManager.LevelTypeForPriorityCulling.SMALL_SCALE_BATTLE
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.TEAM_ARENA_55] = EffectManager.LevelTypeForPriorityCulling.SMALL_SCALE_BATTLE
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.GUILD_LEAGUE] = EffectManager.LevelTypeForPriorityCulling.LARGE_SCALE_BATTLE
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.HOME_HOUSE] = EffectManager.LevelTypeForPriorityCulling.SMALL_SCALE_BATTLE
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.HOME_MANOR] = EffectManager.LevelTypeForPriorityCulling.SMALL_SCALE_BATTLE
EffectManager.LevelTypeToBattleLevel[worldConst.WORLD_TYPE.GROUP_OCCUPY] = EffectManager.LevelTypeForPriorityCulling.MEDIUM_SCALE_BATTLE

-- internal usage
-- BP类型的asset从16开始
NIAGARA_EXTRA_ASSET_TYPE = NIAGARA_EXTRA_ASSET_TYPE or {
    CurveFloat = 0,
	BlendOutCurveFloat = 1,
    SplineBP = 16
}

-- 参与检查的NiagaraEffectTypes, 特效质量等级从低到高
EffectManager.NiagaraEffectTypes = {
	NET_Monster = 1,
	NET_Attack = 2,
	NET_Player = 3,
	NET_PlayerUltra = 4,
	NET_Boss = 5
}

-- 可以通过niagara effect type反向查找niagara effect type对应的名称
EffectManager.NiagaraEffectTypeNames = {}
for k,v in pairs(EffectManager.NiagaraEffectTypes) do
	EffectManager.NiagaraEffectTypeNames[v] = k
end

EffectManager.NiagaraEffectTypeMissingMsgFormat = "[NiagaraEffectTypeCheck] %s NiagaraSystem %s have no NiagaraEffectType"
EffectManager.NiagaraEffectTypeInvalidUsageMsgFormat = "[NiagaraEffectTypeCheck] %s NiagaraSystem %s use NiagaraEffectType[%s] but expected %s or lower" 

-- 创建开关
EffectManager.DisableNiagaraCreate = false
EffectManager.bDisableEngineCulling = true
EffectManager.bEnableLogging = false

function IsUClassNiagaraAsset(AssetType)
    return AssetType >= NIAGARA_EXTRA_ASSET_TYPE.SplineBP
end

function EffectManager:ctor(bInEnablePriorityCulling)
	-- 默认只有游戏运行时开启culling, 其他各类编辑器中都不开
	self.bEnablePriorityCulling = bInEnablePriorityCulling == true
end

--region Core
---@field NiagaraEffectParams table<number, NiagaraEffectParamTemplate>
function EffectManager:Init()
    self.cppMgr = import("KGEffectManager")(Game.WorldContext)
    Game.GameInstance:CacheManager(self.cppMgr)
    self.cppMgr:NativeInit()

    ------------------------------------------- niagara --------------------------------------
    self.onNiagaraSystemActivateNotify = self.cppMgr.OnNiagaraSystemActivate:Add(function(NiagaraSystemId)
        self:OnNiagaraSystemActivate(NiagaraSystemId)
    end)

    self.onNiagaraSystemFinishedNotify = self.cppMgr.OnNiagaraSystemFinished:Add(function(NiagaraSystemId)
        self:OnNiagaraSystemFinished(NiagaraSystemId)
    end)

	self.onNiagaraBudgetSqueezedNotify = self.cppMgr.OnNiagaraBudgetSqueezed:Add(function(BudgetToken)
		self:OnNiagaraBudgetSqueezed(BudgetToken)
	end)
	
    self.onAnimNotify_C7TimedNiagaraEffect = self.cppMgr.OnAnimNotify_C7TimedNiagaraEffect:Bind(
        function(NotifyType, AttachComponentId, NiagaraAssetPath, AttachPointName, OwnerEntityUID, OwnerActorId, TotalLifeSeconds, bAllFlags, InTransform)
            return self:OnAnimNotifyNiagaraEffect(NotifyType, AttachComponentId, NiagaraAssetPath, AttachPointName, OwnerEntityUID, OwnerActorId, TotalLifeSeconds, bAllFlags, InTransform)
    end)

    self.onAnimNotify_C7TimedNiagaraEffectFixed = self.cppMgr.OnAnimNotify_C7TimedNiagaraEffectSimple:Bind(
        function(NotifyType, AttachComponentId, NiagaraAssetPath, AttachPointName, OwnerEntityUID, OwnerActorId, TotalLifeSeconds, bAllFlags)
            return self:OnAnimNotifyNiagaraEffect(NotifyType, AttachComponentId, NiagaraAssetPath, AttachPointName, OwnerEntityUID, OwnerActorId, TotalLifeSeconds, bAllFlags)
    end)

    self.onAnimNotify_C7TimedNiagaraEffectEnd = self.cppMgr.OnAnimNotify_C7TimedNiagaraEffectEnd:Bind(
        function(NiagaraSystemID)
            self:OnAnimNotifyNiagaraEffectEnd(NiagaraSystemID)
    end)

    -- niagara effect id to niagara effect param
    self.NiagaraEffectParams = {}
    self.NiagaraSystemIdToEffectId = {}
    self.NiagaraLoadIdToEffectId = {}
    self.SpawnerIdToEffectIds = {}
	self.EffectTagToEffectIds = {}
	self.EffectTagHiddenState = {}

    self.CurEffectId = 1
	
    -- 不重要特效质量等级偏移
    self.UnimportantNiagaraQualityLevelOffset = 2
    -- 不重要特效的透明系数
    self.UnimportantNiagaraAlphaLevel = 2
	
	self.NiagaraBudgetTokenToEffectId = {}

	self.SmallBattleNiagaraPriorityConfig = Game.TableData.GetNiagaraPrioritySmallScaleBattleTable()
	self.MediumBattleNiagaraPriorityConfig = Game.TableData.GetNiagaraPriorityMediumScaleBattleTable()
	self.LargeBattleNiagaraPriorityConfig = Game.TableData.GetNiagaraPriorityLargeScaleBattleTable()
	self.CurrentNiagaraPriorityConfig = self.SmallBattleNiagaraPriorityConfig
	
	local NiagaraNumLimit = Game.WorldManager.ViewBudgetMgr:GetCurrentFxValueLimit()
	Log.Debug("Use niagara limit ", NiagaraNumLimit)
	self.cppMgr:SetNiagaraNumLimit(NiagaraNumLimit)
	
	-- 用于运行时反向检查特效NiagaraEffectType设置是否正常, 默认关闭, 可以用GM开启
	self.bDebugCheckNiagaraEffectType = false
end

function EffectManager:UnInit()
    self.cppMgr.OnNiagaraSystemActivate:Remove(self.onNiagaraSystemActivateNotify)
    self.cppMgr.OnNiagaraSystemFinished:Remove(self.onNiagaraSystemFinishedNotify)
    self.cppMgr.OnNiagaraBudgetSqueezed:Remove(self.onNiagaraBudgetSqueezedNotify)
    self.cppMgr.OnAnimNotify_C7TimedNiagaraEffect:Clear()
    self.cppMgr.OnAnimNotify_C7TimedNiagaraEffectSimple:Clear()
    self.cppMgr.OnAnimNotify_C7TimedNiagaraEffectEnd:Clear()
    self:DestroyAllNiagaras()

    self.cppMgr:NativeUninit()
end

--endregion Core


--region Niagara

----------------------------------------------------------------------------------------------------
-- 外部接口
-- NiagaraEffectParams 通过 NiagaraEffectParam.AllocFromPool 获取
function EffectManager:CreateNiagaraSystem(NiagaraEffectParam)
    if (NiagaraEffectParam.NiagaraEffectPath == nil or NiagaraEffectParam.NiagaraEffectPath == "") and (
            NiagaraEffectParam.NiagaraAssetId == nil or NiagaraEffectParam.NiagaraAssetId == 0) then
        Log.Warning("EffectManager:CreateNiagaraSystem, cannot find valid NiagaraAssetId or NiagaraEffectPath")
        NiagaraEffectParamTemplate.RecycleToPool(NiagaraEffectParam)
        return
    end

	if EffectManager.DisableNiagaraCreate then
		NiagaraEffectParamTemplate.RecycleToPool(NiagaraEffectParam)
		return
	end

    if (NiagaraEffectParam.bNeedAttach or NiagaraEffectParam.bEnableStabilizeAttach) and NiagaraEffectParam.AttachComponentId == 0 then
        Log.Warning("EffectManager:CreateNiagaraSystem, need valid attach component when bNeedAttach is true")
        NiagaraEffectParamTemplate.RecycleToPool(NiagaraEffectParam)
        return
    end

    local AssetsNeedToLoad = self:AssembleLoadAssets(NiagaraEffectParam)

    local EffectId = 0
    if NiagaraEffectParam.CustomEffectID ~= 0  then
        EffectId = NiagaraEffectParam.CustomEffectID
    else
        EffectId = self:GenerateEffectId()
    end

	if NiagaraEffectParam.NiagaraBudgetToken ~= nil then
		self.NiagaraBudgetTokenToEffectId[NiagaraEffectParam.NiagaraBudgetToken] = EffectId
	end
	
    -- 先异步加载资源
    local LoadAsset
    if NiagaraEffectParam.NiagaraAssetId and NiagaraEffectParam.NiagaraAssetId > 0 and #AssetsNeedToLoad == 0 then
        LoadAsset = Game.ObjectActorManager:GetObjectByID(NiagaraEffectParam.NiagaraAssetId)
        if LoadAsset == nil then
            Log.Error("EffectManager:CreateNiagaraSystem, invalid niagara asset ref by NiagaraAssetId")
            NiagaraEffectParamTemplate.RecycleToPool(NiagaraEffectParam)
        end

        NiagaraEffectParam.bLoadComplete = true
        NiagaraEffectParam.bActivateImmediately = true
    elseif #AssetsNeedToLoad == 1 then
        local LoadId, TempLoadAsset = Game.AssetManager:AsyncLoadAssetKeepReference(
                NiagaraEffectParam.NiagaraEffectPath, self, "OnNiagaraSystemLoaded")

        LoadAsset = TempLoadAsset
        NiagaraEffectParam.AssetLoadId = LoadId
        if LoadAsset == nil then
            self.NiagaraLoadIdToEffectId[LoadId] = EffectId
        else
            NiagaraEffectParam.bLoadComplete = true
        end
    else
        -- 对于存在多个加载参数的特效, 总是等回调
        local LoadId, _ = Game.AssetManager:AsyncLoadAssetListKeepReference(
                AssetsNeedToLoad, self, "OnNiagaraAssetsLoaded")

        NiagaraEffectParam.AssetLoadId = LoadId
        self.NiagaraLoadIdToEffectId[LoadId] = EffectId
    end

	if EffectManager.bEnableLogging then
		Log.DebugFormat("EffectManager:CreateNiagaraSystem, EffectId: %d, NiagaraAssetPath: %s", EffectId, NiagaraEffectParam.NiagaraEffectPath)
	end

    self.NiagaraEffectParams[EffectId] = NiagaraEffectParam

    local SpawnerId = NiagaraEffectParam.SpawnerId
    self:AddSpawnerEffectId(SpawnerId, EffectId)

    -- 对于连线类型的特效来说, 生命周期除了跟spawner绑定以外, 还会跟linked actor绑定, 任意一方生命周期结束时都要清理特效
    -- 这里有一个限制, 因为目前特效生命周期跟随spawner的逻辑是基于entity的（在ViewControlFxComponent ExitWorld时清理自身所有特效）
    -- 如果这里Linked actor不是一个entity, 那么这里就不会清理, 后续连线特效这块Link target必须要有一个entity, 目前看应该是没问题的
	if NiagaraEffectParam.UserVals_SkeletalMeshCompIds ~= nil then
		for _, ParamVal in pairs(NiagaraEffectParam.UserVals_SkeletalMeshCompIds) do
			self:AddSpawnerEffectIdByCompId(EffectId, ParamVal)
		end
	end

    if NiagaraEffectParam.SplineLinkTargetCompId ~= nil then
        self:AddSpawnerEffectIdByCompId(EffectId, NiagaraEffectParam.SplineLinkTargetCompId)
    end
	
	self:UpdateCommonEffectTags(EffectId, NiagaraEffectParam)

    if LoadAsset ~= nil then
        self:InternalCreateNiagaraSystem(EffectId, LoadAsset)
    end

    return EffectId
end

-- 外部接口 这里只是deactivate niagara，等待粒子自动finish或者超时finish
function EffectManager:DeactivateNiagaraSystem(NiagaraEffectId)
    if NiagaraEffectId == nil then
        Log.Warning("EffectManager:DeactivateNiagaraSystem, invalid niagara effect id")
        return
    end

    local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraEffectId]
    if NiagaraEffectParam == nil then
		if EffectManager.bEnableLogging then
			Log.DebugFormat("EffectManager:DeactivateNiagaraSystem, cannot find niagara effect params, NiagaraEffectId: %d", NiagaraEffectId)
		end
        return
    end

	if EffectManager.bEnableLogging then
		Log.DebugFormat("EffectManager:DeactivateNiagaraSystem, EffectId: %d", NiagaraEffectId)
	end

    -- 如果 niagara还在加载过程中, 那么直接停止加载
    if not NiagaraEffectParam.bLoadComplete then
        Game.AssetManager:CancelLoadAsset(NiagaraEffectParam.AssetLoadId)
        self:ClearEffectIdRecord(NiagaraEffectId)
        return
    end

    if NiagaraEffectParam.AssetLoadId ~= 0 then
        Game.AssetManager:RemoveAssetReferenceByLoadID(NiagaraEffectParam.AssetLoadId)
    end

    -- 不是 auto create, 且外部还未激活
    if NiagaraEffectParam.NiagaraSystemId == nil then
        self:ClearEffectIdRecord(NiagaraEffectId)
        return
    end

    local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
    -- 还处于pending activate状态 或者由于退游戏导致niagara component已经出于pending kill的状态
    if NiagaraComponent == nil or not IsValid_L(NiagaraComponent) then
        self.NiagaraSystemIdToEffectId[NiagaraEffectParam.NiagaraSystemId] = nil
        self.cppMgr:DestroyNiagaraSystem(NiagaraEffectParam.NiagaraSystemId)
        self:ClearEffectIdRecord(NiagaraEffectId)
        return
    end

    -- 已经创建了niagara component, 走正常的deactivate流程
    NiagaraComponent:Deactivate()

    -- 支持外部提前打断特效
	-- deactivate 以后可能对应特效实例立刻内部结束了, 这里还需要判个空
	if self.NiagaraEffectParams[NiagaraEffectId] ~= nil then
		local DelayDestroyMs = NiagaraEffectParam.DelayDestroyMs
		if DelayDestroyMs > 0 then
			self.cppMgr:SetNiagaraTimeoutInfo(NiagaraEffectParam.NiagaraSystemId, EKGNiagaraTimeoutState.Destroy, DelayDestroyMs / 1000)
		end
	end
end

-- 外部接口 强制销毁粒子, 立刻执行release to pool
function EffectManager:DestroyNiagaraSystem(NiagaraEffectId)
    if NiagaraEffectId == nil then
        Log.Warning("EffectManager:DestroyNiagaraSystem, invalid niagara effect id")
        return
    end

    local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraEffectId]
    if NiagaraEffectParam == nil then
        Log.WarningFormat("EffectManager:DestroyNiagaraSystem, cannot find niagara effect params, NiagaraEffectId: %d", NiagaraEffectId)
        return
    end

	if EffectManager.bEnableLogging then
		Log.DebugFormat("EffectManager:DestroyNiagaraSystem, EffectId: %d", NiagaraEffectId)
	end

    -- 如果 niagara还在加载过程中, 那么直接停止加载
    if not NiagaraEffectParam.bLoadComplete then
        Game.AssetManager:CancelLoadAsset(NiagaraEffectParam.AssetLoadId)
        self:ClearEffectIdRecord(NiagaraEffectId)
        return
    end

    if NiagaraEffectParam.AssetLoadId ~= 0 then
        Game.AssetManager:RemoveAssetReferenceByLoadID(NiagaraEffectParam.AssetLoadId)
    end

    if NiagaraEffectParam.NiagaraSystemId ~= nil then
        self.NiagaraSystemIdToEffectId[NiagaraEffectParam.NiagaraSystemId] = nil
        self.cppMgr:DestroyNiagaraSystem(NiagaraEffectParam.NiagaraSystemId)
    end

	self:ClearEffectStates(NiagaraEffectParam)

    self:ClearEffectIdRecord(NiagaraEffectId)
end

function EffectManager:DestroyAllNiagaras()
    for EffectId, _ in pairs(self.NiagaraEffectParams) do
        self:DestroyNiagaraSystem(EffectId)
    end
end

-- 外部接口 更新Vec3 niagara 参数
function EffectManager:UpdateNiagaraVec3Param(NiagaraEffectId, ParamName, ValX, ValY, ValZ)
    if NiagaraEffectId == nil then
        Log.Warning("EffectManager:UpdateNiagaraVec3Param, invalid niagara effect id")
        return
    end

    local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraEffectId]
    if NiagaraEffectParam == nil then
        Log.WarningFormat("EffectManager:UpdateNiagaraVec3Param, cannot find niagara effect params, NiagaraEffectId: %d", NiagaraEffectId)
        return
    end

    if NiagaraEffectParam.NiagaraSystemId ~= nil then
        local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
        -- 有可能出于pending activate状态, 因此这里有可能为nil
        if NiagaraComponent ~= nil then
            TempVal_Vec3.X = ValX
            TempVal_Vec3.Y = ValY
            TempVal_Vec3.Z = ValZ
            NiagaraComponent:SetVariableVec3(ParamName, TempVal_Vec3)
            return
        end
    end

	if NiagaraEffectParam.UserVals_Vec3 == nil then
		NiagaraEffectParam.UserVals_Vec3 = {}
	end
    NiagaraEffectParam.UserVals_Vec3[ParamName] = M3D.Vec3(ValX, ValY, ValZ)
end

-- 外部接口 跟新linearColor niagara 参数
function EffectManager:UpdateNiagaraLinearColorParam(NiagaraEffectId, ParamName, ValR, ValG, ValB, ValA)
	if NiagaraEffectId == nil then
		Log.Warning("EffectManager:UpdateNiagaraLinearColorParam, invalid niagara effect id")
		return
	end

	local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraEffectId]
	if NiagaraEffectParam == nil then
		Log.WarningFormat("EffectManager:UpdateNiagaraLinearColorParam, cannot find niagara effect params, NiagaraEffectId: %d", NiagaraEffectId)
		return
	end

	if NiagaraEffectParam.NiagaraSystemId ~= nil then
		local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
		-- 有可能出于pending activate状态, 因此这里有可能为nil
		if NiagaraComponent ~= nil then
			TempVal_LinearColor.R = ValR
			TempVal_LinearColor.G = ValG
			TempVal_LinearColor.B = ValB
			TempVal_LinearColor.A = ValA
			NiagaraComponent:SetVariableLinearColor(ParamName, TempVal_LinearColor)
			return
		end
	end

	if NiagaraEffectParam.UserVals_LinearColor == nil then
		NiagaraEffectParam.UserVals_LinearColor = {}
	end
	NiagaraEffectParam.UserVals_LinearColor[ParamName] = {R = ValR, G = ValG, B = ValB, A = ValA}
end

function EffectManager:UpdateNiagaraFollowActor(NiagaraEffectId, ParamName, InActorId, bAbsoluteNiagaraRotationInFollow)
	if NiagaraEffectId == nil then
		Log.Warning("EffectManager:UpdateNiagaraFollowActor, invalid niagara effect id")
		return
	end

	local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraEffectId]
	if NiagaraEffectParam == nil then
		Log.WarningFormat("EffectManager:UpdateNiagaraFollowActor, cannot find niagara effect params, NiagaraEffectId: %d", NiagaraEffectId)
		return
	end

	self:AddSpawnerEffectId(InActorId, NiagaraEffectId, true)
	
	if NiagaraEffectParam.NiagaraSystemId ~= nil then
		local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
		-- 有可能出于pending activate状态, 因此这里有可能为nil
		if NiagaraComponent ~= nil then
			local Actor = Game.ObjectActorManager:GetObjectByID(InActorId)
			self.cppMgr:SetNiagaraFollowActorParams(NiagaraEffectParam.NiagaraSystemId, ParamName, Actor, bAbsoluteNiagaraRotationInFollow)
			return
		end
	end

	NiagaraEffectParam.FollowActorUserValName = ParamName
	NiagaraEffectParam.FollowActorId = InActorId
	NiagaraEffectParam.bAbsoluteNiagaraRotationInFollow = bAbsoluteNiagaraRotationInFollow
end

function EffectManager:UpdateNiagaraCameraArmLengthParam(NiagaraEffectId, ParamName)
	if NiagaraEffectId == nil then
		Log.Warning("EffectManager:UpdateNiagaraCameraArmLengthParam, invalid niagara effect id")
		return
	end

	local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraEffectId]
	if NiagaraEffectParam == nil then
		Log.WarningFormat("EffectManager:UpdateNiagaraCameraArmLengthParam, cannot find niagara effect params, NiagaraEffectId: %d", NiagaraEffectId)
		return
	end

	if NiagaraEffectParam.NiagaraSystemId ~= nil then
		local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
		-- 有可能出于pending activate状态, 因此这里有可能为nil
		if NiagaraComponent ~= nil then
			self.cppMgr:SetNiagaraUseCameraArmLengthParams(NiagaraEffectParam.NiagaraSystemId, ParamName)
			return
		end
	end

	NiagaraEffectParam.CameraArmLengthUserValName = ParamName
end

-- 外部接口 更新Vec2 niagara 参数
function EffectManager:UpdateNiagaraVec2Param(NiagaraEffectId, ParamName, ValX, ValY)
    if NiagaraEffectId == nil then
        Log.Warning("EffectManager:UpdateNiagaraVec2Param, invalid niagara effect id")
        return
    end

    local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraEffectId]
    if NiagaraEffectParam == nil then
        Log.WarningFormat("EffectManager:UpdateNiagaraVec2Param, cannot find niagara effect params, NiagaraEffectId: %d", NiagaraEffectId)
        return
    end

    if NiagaraEffectParam.NiagaraSystemId ~= nil then
        local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
        -- 有可能出于pending activate状态, 因此这里有可能为nil
        if NiagaraComponent ~= nil then
            TempVal_Vec2.X = ValX
            TempVal_Vec2.Y = ValY
            NiagaraComponent:SetVariableVec2(ParamName, TempVal_Vec2)
            return
        end
    end

	if NiagaraEffectParam.UserVals_Vec2 == nil then
		NiagaraEffectParam.UserVals_Vec2 = {}
	end
    NiagaraEffectParam.UserVals_Vec2[ParamName] = M3D.Vec2(ValX, ValY)
end

-- 外部接口 更新Float niagara 参数
function EffectManager:UpdateNiagaraFloatParam(NiagaraEffectId, ParamName, Val)
    if NiagaraEffectId == nil then
        Log.Warning("EffectManager:UpdateNiagaraFloatParam, invalid niagara effect id")
        return
    end

    local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraEffectId]
    if NiagaraEffectParam == nil then
        Log.WarningFormat("EffectManager:UpdateNiagaraFloatParam, cannot find niagara effect params, NiagaraEffectId: %d", NiagaraEffectId)
        return
    end

    if NiagaraEffectParam.NiagaraSystemId ~= nil then
        local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
        -- 有可能出于pending activate状态, 因此这里有可能为nil
        if NiagaraComponent ~= nil then
            NiagaraComponent:SetVariableFloat(ParamName, Val)
            return
        end
    end

    if NiagaraEffectParam.UserVals_Float == nil then
        NiagaraEffectParam.UserVals_Float = {}
    end

    NiagaraEffectParam.UserVals_Float[ParamName] = Val
end

---@param StartRelativeYaw number 这里是特效自身component space相对的起始朝向
---@param RotateAngle number 一共需要转动的角度, 顺时针为正 逆时针未负
function EffectManager:UpdatePositionWithArcParams(NiagaraEffectId, ParamName, Radius, StartRelativeYaw, RotateAngle, Duration)
	if NiagaraEffectId == nil then
		Log.Warning("EffectManager:UpdatePositionWithArcParams, invalid niagara effect id")
		return
	end

	local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraEffectId]
	if NiagaraEffectParam == nil then
		Log.WarningFormat("EffectManager:UpdatePositionWithArcParams, cannot find niagara effect params, NiagaraEffectId: %d", NiagaraEffectId)
		return
	end

	if NiagaraEffectParam.NiagaraSystemId ~= nil then
		local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
		-- 有可能出于pending activate状态, 因此这里有可能为nil
		if NiagaraComponent ~= nil then
			self.cppMgr:SetNiagaraUpdatePositionWithArcParams(NiagaraEffectParam.NiagaraSystemId, ParamName, Radius, StartRelativeYaw, RotateAngle, Duration)
			return
		end
	end
	
	NiagaraEffectParam.CachedArcPositionParamName = ParamName
	NiagaraEffectParam.CachedArcPositionParamRadius = Radius
	NiagaraEffectParam.CachedArcPositionParamStartRelativeYaw = StartRelativeYaw
	NiagaraEffectParam.CachedArcPositionParamRotateAngle = RotateAngle
	NiagaraEffectParam.CachedArcPositionParamDuration = Duration
end

-- 外部接口
--- @param HiddenReason NIAGARA_HIDDEN_REASON
function EffectManager:UpdateNiagaraHiddenState(NiagaraEffectId, bHidden, HiddenReason, bForceUpdate)
    if NiagaraEffectId == nil then
        Log.Warning("EffectManager:UpdateNiagaraHiddenState, invalid niagara effect id")
        return
    end

    local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraEffectId]
    if NiagaraEffectParam == nil then
        Log.WarningFormat("EffectManager:UpdateNiagaraHiddenState, cannot find niagara effect params, NiagaraEffectId: %d", NiagaraEffectId)
        return
    end

    local bOldNiagaraHidden = NiagaraEffectParam.HiddenMask ~= 0
    local HiddenVal = 1 << HiddenReason
    if bHidden then
        NiagaraEffectParam.HiddenMask = NiagaraEffectParam.HiddenMask | HiddenVal
    else
        NiagaraEffectParam.HiddenMask = (~HiddenVal) & NiagaraEffectParam.HiddenMask
    end
    local bNewNiagaraHidden = NiagaraEffectParam.HiddenMask ~= 0

    if bOldNiagaraHidden == bNewNiagaraHidden and bForceUpdate ~= true then
        return
    end

    if NiagaraEffectParam.NiagaraSystemId == nil then
        return
    end

    local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
    if NiagaraComponent ~= nil then
        self:InternalUpdateNiagaraHiddenState(NiagaraComponent, bNewNiagaraHidden)
    end
end

function EffectManager:DestroyNiagarasBySpawnerId(SpawnerId)
    if SpawnerId == nil then
        return
    end

    local EffectIds = self.SpawnerIdToEffectIds[SpawnerId]
    if EffectIds == nil then
        return
    end

    for EffectId, _ in pairs(EffectIds) do
        self:DestroyNiagaraSystem(EffectId)
    end

    self.SpawnerIdToEffectIds[SpawnerId] = nil
end

function EffectManager:DestroyNiagaraBySpawnerIdAndEffectTag(SpawnerId, EffectTag)
	if SpawnerId == nil then
		return
	end

	local EffectIds = self.SpawnerIdToEffectIds[SpawnerId]
	if EffectIds == nil then
		return
	end

	for EffectId, _ in pairs(EffectIds) do
		local NiagaraEffectParam = self.NiagaraEffectParams[EffectId]
		if NiagaraEffectParam and table.contains(NiagaraEffectParam.EffectTags, EffectTag) then
			self:DestroyNiagaraSystem(EffectId)
		end
	end
end

function EffectManager:GetNiagaraComponentByEffectId(EffectId)
    if EffectId == nil then
        Log.Warning("EffectManager:GetNiagaraComponentByEffectId, invalid niagara effect id")
        return
    end

    local NiagaraEffectParam = self.NiagaraEffectParams[EffectId]
    if NiagaraEffectParam == nil then
        Log.WarningFormat("EffectManager:GetNiagaraComponentByEffectId, cannot find niagara effect params, NiagaraEffectId: %d", EffectId)
        return
    end

    if NiagaraEffectParam.NiagaraSystemId == nil then
        Log.WarningFormat("EffectManager:GetNiagaraComponentByEffectId, invalid niagara system id, NiagaraEffectId: %d", EffectId)
        return
    end

    return self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
end

function EffectManager:IsValidNiagaraEffectId(EffectId)
    return self.NiagaraEffectParams[EffectId] ~= nil
end

function EffectManager:GetNiagaraEffectParam(EffectId)
	return self.NiagaraEffectParams[EffectId]
end

-- 外部传入了 blend out curve的情况下，通过该接口可以开启blend out curve
function EffectManager:BlendOutNiagara(EffectId, NewBlendOutStartVal)
	if EffectId == nil then
		Log.Warning("EffectManager:BlendOutNiagara, invalid niagara effect id")
		return
	end

	local NiagaraEffectParam = self.NiagaraEffectParams[EffectId]
	if NiagaraEffectParam == nil then
		Log.WarningFormat("EffectManager:BlendOutNiagara, cannot find niagara effect params, NiagaraEffectId: %d", EffectId)
		return
	end

    -- 如果额外传入淡出初始值,则进行覆盖
    if NewBlendOutStartVal then
        NiagaraEffectParam.BlendOutStartVal = NewBlendOutStartVal
    end

	if NiagaraEffectParam.NiagaraSystemId == nil then
		NiagaraEffectParam.bCachedBlendOutEnabled = true
		return
	end
	
	self:StartBlendOutNiagara(EffectId)
end

--- 由于本身特效资源的加载是异步的, 且特效创建也会在cpp中分帧执行, 当外部在特效挂接组件存在时播放了特效, 并在特效真正创建之前销毁了挂接组件, 此时特效播放就会失败
--- 对于不存在异步加载和分帧创建的情况下, 挂接组件destroy会让特效detach, 并重新attach到挂接组件的parent（挂接组件是非root component的情况）
--- 相应地，为了屏蔽特效管理器内部的异步处理细节, 这里需要外部挂接组件销毁时通知到特效管理器, 在特效未创建之前，先更新特效创建的参数（改为在attach component最后一帧位置处的世界空间位置播放）
--- 为了简化逻辑, 这里不去处理destroy component时对应的promote children逻辑, 目前业务上本身也没有类似的用法
function EffectManager:NotifyRemoveComponent(InActorId, InComponentId)
	if InActorId == nil or InComponentId == nil then
		return
	end
	
	local EffectIDs = self.SpawnerIdToEffectIds[InActorId]
	if EffectIDs == nil then 
		return 
	end
	
	for EffectId, _ in pairs(EffectIDs) do
		local NiagaraEffectParam = self.NiagaraEffectParams[EffectId]
		if NiagaraEffectParam.AttachComponentId == InComponentId and (NiagaraEffectParam.bNeedAttach or NiagaraEffectParam.bEnableStabilizeAttach) then
		
			if NiagaraEffectParam.bLoadComplete == false then
				local Comp = Game.ObjectActorManager:GetObjectByID(InComponentId)
				local SocketTransform = Comp:GetSocketTransform(NiagaraEffectParam.AttachPointName)
				M3D.ToTransform(SocketTransform, EffectManager.TempVal_Transform)
				NiagaraEffectParam.SpawnTrans:Mul(EffectManager.TempVal_Transform, NiagaraEffectParam.SpawnTrans)
				-- 未加载好之前只需要直接设置不attach即可
				NiagaraEffectParam.bNeedAttach = false
				NiagaraEffectParam.bEnableStabilizeAttach = false
				
			elseif NiagaraEffectParam.NiagaraSystemId ~= nil then
				local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
				if NiagaraComponent == nil then
					-- 此时出于pending activate状态
					self.cppMgr:SetPendingActivateNiagaraDetached(NiagaraEffectParam.NiagaraSystemId)
				end
			end
		end
	end
end

-- 针对高频创建的特效, 最好在创建之前就尝试去做Budget申请, 避免到特效创建时再去做额度申请导致本身特效参数计算产生冗余开销
-- 申请到budget后, 需要拿着budget去播放特效, 特效结束时budget会自动回收
-- 如果budget申请到以后, 由于各种异常逻辑导致最终没有真正创建特效, budget会在申请后的5s内自动回收(保底), 避免异常逻辑导致budget被占满最后导致所有特效无法创建
-- SpawnerCharacter可以为空, 此时以创建者不可见的条件进行创建
-- 返回值包含两个 分别为是否允许播放特效以及相应budget token
function EffectManager:TryObtainNiagaraBudget(SpawnerType, EffectType, SpawnerCharacter, InCustomEffectPriority)
	if self.bEnablePriorityCulling == false then
		return true, nil
	end
	
	if SpawnerType == nil then
		return true, nil
	end

	local CustomEffectPriority = InCustomEffectPriority and InCustomEffectPriority or 0
	local RowConfig = self.CurrentNiagaraPriorityConfig[SpawnerType]
	if RowConfig == nil then
		return false, nil
	end
	
	local NiagaraPriority
	if EffectType == NIAGARA_EFFECT_TYPE_FOR_PRIORITY_CULLING.SKILL then
		NiagaraPriority = CustomEffectPriority + RowConfig.Skill
	elseif EffectType == NIAGARA_EFFECT_TYPE_FOR_PRIORITY_CULLING.ATTACHMENT then
		NiagaraPriority = RowConfig.Attachment
	elseif EffectType == NIAGARA_EFFECT_TYPE_FOR_PRIORITY_CULLING.LOCOMOTION then
		NiagaraPriority = RowConfig.Locomotion
	elseif EffectType == NIAGARA_EFFECT_TYPE_FOR_PRIORITY_CULLING.HIT then
		NiagaraPriority = RowConfig.Hit
	elseif EffectType == NIAGARA_EFFECT_TYPE_FOR_PRIORITY_CULLING.APPEARANCE then
		NiagaraPriority = CustomEffectPriority + RowConfig.Appearance
	end

	NiagaraPriority = math.clamp(NiagaraPriority, 0, 4)

	local BudgetToken = self.cppMgr:TryObtainNiagaraBudget(SpawnerCharacter, NiagaraPriority)
	return BudgetToken ~= 0, BudgetToken
end

function EffectManager:SetEnablePriorityCulling(bInEnablePriorityCulling)
	self.bEnablePriorityCulling = bInEnablePriorityCulling
end

function EffectManager:SetNiagaraNumLimit(InNiagaraNumLimit)
	self.cppMgr:SetNiagaraNumLimit(InNiagaraNumLimit)
end

-- 对于技能编辑器来说, 总是希望特效播放不要有任何QualityLevelOffset以及TransparencyScale(默认不会, 因为正常情况下特效始作俑者都是技能播放者, 即技能编辑器中的主角)
-- 连线特效做了特殊处理, 会有问题, 这里加个开关, 允许技能编辑器中直接屏蔽QualityLevelOffset以及TransparencyScale设置逻辑
function EffectManager:DisableQualityLevelOffsetAndTransparencyScale()
	self.bDisableQualityLevelOffsetAndTransparencyScale = true
end

function EffectManager:OnWorldMapLoadComplete(LevelId)
	local MapConf = Game.TableData.GetLevelMapDataRow(LevelId)
	if MapConf and MapConf.Type then
		local LevelTypeForPriorityCulling = EffectManager.LevelTypeToBattleLevel[MapConf.Type]
		if LevelTypeForPriorityCulling == nil then
			-- 目前确实存在一些level没有配置Type, 例如登录场景
			Log.Debug("Cannot LevelTypeForPriorityCulling by level id", LevelId, MapConf.Type)
			return
		end
		
		Log.Debug("EffectManager:OnWorldMapLoadComplete, change level type to ", LevelTypeForPriorityCulling, LevelId)
		if LevelTypeForPriorityCulling == EffectManager.LevelTypeForPriorityCulling.SMALL_SCALE_BATTLE then
			self.CurrentNiagaraPriorityConfig = self.SmallBattleNiagaraPriorityConfig
		elseif LevelTypeForPriorityCulling == EffectManager.LevelTypeForPriorityCulling.MEDIUM_SCALE_BATTLE then
			self.CurrentNiagaraPriorityConfig = self.MediumBattleNiagaraPriorityConfig
		elseif LevelTypeForPriorityCulling == EffectManager.LevelTypeForPriorityCulling.LARGE_SCALE_BATTLE then
			self.CurrentNiagaraPriorityConfig = self.LargeBattleNiagaraPriorityConfig
		end
	end
end

----------------------------------------------------------------------------------------------------

function EffectManager:GenerateEffectId()
    self.CurEffectId = self.CurEffectId + 1
    if self.CurEffectId >= 0x7fffffff then
        self.CurEffectId = 1
    end

    return self.CurEffectId
end

function EffectManager:AddSpawnerEffectIdByCompId(EffectId, CompId)
    local Comp = Game.ObjectActorManager:GetObjectByID(CompId)
    if Comp ~= nil then
        local Owner = Comp:GetOwner()
        local OwnerId = Game.ObjectActorManager:GetIDByObject(Owner)
        self:AddSpawnerEffectId(OwnerId, EffectId, true)
    end
end

function EffectManager:AddSpawnerEffectId(SpawnerId, EffectId, bLinkedTarget)
    if SpawnerId ~= nil and SpawnerId ~= 0 then
        if self.SpawnerIdToEffectIds[SpawnerId] == nil then
            self.SpawnerIdToEffectIds[SpawnerId] = {}
        end
        local SpawnerEffectIds = self.SpawnerIdToEffectIds[SpawnerId]
        SpawnerEffectIds[EffectId] = true

		if bLinkedTarget then
			local NiagaraEffectParam = self.NiagaraEffectParams[EffectId]
			if NiagaraEffectParam.ExtraSpawnerIds == nil then
				NiagaraEffectParam.ExtraSpawnerIds = {}
			end
			
			table.insert(NiagaraEffectParam.ExtraSpawnerIds, SpawnerId)
		end
    end
end

function EffectManager:OnNiagaraSystemLoaded(InLoadId, LoadAsset)
	if EffectManager.bEnableLogging then
		Log.DebugFormat("EffectManager:OnNiagaraSystemLoaded, LoadId: %d", InLoadId)
	end

    local EffectId = self.NiagaraLoadIdToEffectId[InLoadId]
    if EffectId == nil then
        -- 此时已经async load发现资源已经在内存中，直接走播放逻辑了
		if EffectManager.bEnableLogging then
			Log.DebugFormat("EffectManager:OnNiagaraSystemLoaded, niagara should have been created, LoadId: %d", InLoadId)
		end
        return
    end

    local NiagaraEffectParam = self.NiagaraEffectParams[EffectId]
    if NiagaraEffectParam == nil then
        Log.ErrorFormat("EffectManager:OnNiagaraSystemLoaded, cannot find niagara effect params, LoadId: %d, EffectId: %d", InLoadId, EffectId)
        return
    end

    if LoadAsset == nil then
        Log.ErrorFormat("EffectManager:OnNiagaraSystemLoaded, invalid niagara asset loaded, LoadId: %d, EffectId: %d, EffectPath: %s",
                InLoadId, EffectId, NiagaraEffectParam.NiagaraEffectPath)
        return
    end

    NiagaraEffectParam.bLoadComplete = true

    self:InternalCreateNiagaraSystem(EffectId, LoadAsset)
end

function EffectManager:OnNiagaraAssetsLoaded(InLoadId, LoadAssets)
	if EffectManager.bEnableLogging then
		Log.DebugFormat("EffectManager:OnNiagaraSystemLoaded, LoadId: %d", InLoadId)
	end

    local EffectId = self.NiagaraLoadIdToEffectId[InLoadId]
    if EffectId == nil then
        Log.ErrorFormat("EffectManager:OnNiagaraAssetsLoaded, invalid load id, LoadId: %d", InLoadId)
        return
    end

    local NiagaraEffectParam = self.NiagaraEffectParams[EffectId]
    if NiagaraEffectParam == nil then
        Log.ErrorFormat("EffectManager:OnNiagaraAssetsLoaded, cannot find niagara effect params, LoadId: %d, EffectId: %d", InLoadId, EffectId)
        return
    end

    local AssetNum = LoadAssets:Num()
    if AssetNum ~= #NiagaraEffectParam.NiagaraAssetsLoadResults + 1 then
        Log.ErrorFormat("EffectManager:OnNiagaraAssetsLoaded, loaded assets number invalid, Loaded: %d, Expected",
                AssetNum, #NiagaraEffectParam.NiagaraAssetsLoadResults + 1)
        return
    end

    local NiagaraAsset
    local Index = 0
    while Index < AssetNum do
        local LoadAsset = LoadAssets:Get(Index)
        if LoadAsset == nil then
            Log.ErrorFormat("EffectManager:OnNiagaraAssetsLoaded, invalid niagara asset, LoadId: %d, EffectId: %d, EffectPath: %s", 
				InLoadId, EffectId, 
				Index == 0 and NiagaraEffectParam.NiagaraEffectPath or NiagaraEffectParam.NiagaraAssetsLoadResults[Index].AssetPath)
            return
        end

        if Index == 0 then
            NiagaraAsset = LoadAsset
        else
            local LoadResult = NiagaraEffectParam.NiagaraAssetsLoadResults[Index]
            if IsUClassNiagaraAsset(LoadResult.ExtraAssetType) then
                LoadResult.ExtraAssetId = Game.ObjectActorManager:GetIDByClass(LoadAsset)
            else
                LoadResult.ExtraAssetId = Game.ObjectActorManager:GetIDByObject(LoadAsset)
            end
        end

        Index = Index + 1
    end

    if NiagaraAsset == nil then
        Log.ErrorFormat("EffectManager:OnNiagaraAssetsLoaded, invalid niagara system, LoadId: %d, EffectId: %d, EffectPath: %s",
			InLoadId, EffectId, NiagaraEffectParam.NiagaraEffectPath)
        return
    end

    NiagaraEffectParam.bLoadComplete = true

    self:InternalCreateNiagaraSystem(EffectId, NiagaraAsset)
end

function EffectManager:GetNiagaraAsset(NiagaraEffectParam, InNiagaraAsset)
    if InNiagaraAsset ~= nil then
        return InNiagaraAsset
    end

    if NiagaraEffectParam.NiagaraAssetId ~= nil then
        -- 从缓存中去niagara asset
        return Game.ObjectActorManager:GetObjectByID(NiagaraEffectParam.NiagaraAssetId)
    end
end

function EffectManager:SetFloatCurveParams(NiagaraEffectParam, NiagaraSystemId)
    if #NiagaraEffectParam.NiagaraAssetsLoadResults == 0 then
        return
    end

    for _, LoadResult in ipairs(NiagaraEffectParam.NiagaraAssetsLoadResults) do
        if LoadResult.ExtraAssetType == NIAGARA_EXTRA_ASSET_TYPE.CurveFloat then
            local AssetObj = Game.ObjectActorManager:GetObjectByID(LoadResult.ExtraAssetId)
            if AssetObj == nil then
                Log.Error("invalid curve float asset")
                goto continue
            end

            local ParamName = LoadResult.ParamName
            local RemapTime
			if NiagaraEffectParam.UserVals_FloatCurveRemapTime ~= nil then
				RemapTime = NiagaraEffectParam.UserVals_FloatCurveRemapTime[ParamName]
			end
            local bNeedRemap = false
            local RemapScale = 1.0
            if RemapTime ~= nil then
                if RemapTime <= 1e-4 then
                    Log.ErrorFormat("invalid remap time %f", RemapTime)
                    goto continue
                end

                bNeedRemap = true

                local MinTime, MaxTime = 0.0, 0.0
                MinTime, MaxTime = AssetObj:GetTimeRange(MinTime, MaxTime)
                local CurveTimeRange = MaxTime - MinTime
                if CurveTimeRange <= 1e-4 then
                    Log.ErrorFormat("invalid curve time range %f", CurveTimeRange)
                    goto continue
                end

                RemapScale = CurveTimeRange / RemapTime
            end

            self.cppMgr:AddFloatCurveParams(NiagaraSystemId, ParamName, AssetObj, bNeedRemap, RemapScale, true)

            ::continue::
        end
    end
end

function EffectManager:StartBlendOutNiagara(NiagaraEffectId)
	local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraEffectId]
	if NiagaraEffectParam == nil then
		Log.ErrorFormat("EffectManager:StartBlendOutNiagara, cannot find niagara effect params, NiagaraEffectPath: %s", NiagaraEffectParam.NiagaraEffectPath)
		return
	end

	if NiagaraEffectParam.NiagaraSystemId == nil then
		Log.ErrorFormat("EffectManager:StartBlendOutNiagara, niagara system not created, NiagaraEffectPath: %s", NiagaraEffectParam.NiagaraEffectPath)
		return
	end

	local ParamName = NiagaraEffectParam.BlendOutParamName
	if ParamName == nil then
		Log.ErrorFormat("EffectManager:StartBlendOutNiagara, invalid blend out param name, NiagaraEffectPath: %s", NiagaraEffectParam.NiagaraEffectPath)
		return
	end
	
	local bBlendOutByCurve = NiagaraEffectParam.BlendOutFloatCurvePath ~= nil
	local DelayDeactivateMs
	if bBlendOutByCurve then
		local CurveAsset = nil
		for _, LoadResult in ipairs(NiagaraEffectParam.NiagaraAssetsLoadResults) do
			if LoadResult.ExtraAssetType == NIAGARA_EXTRA_ASSET_TYPE.BlendOutCurveFloat then
				CurveAsset = Game.ObjectActorManager:GetObjectByID(LoadResult.ExtraAssetId)
				break
			end
		end

		if CurveAsset == nil then
			Log.ErrorFormat("EffectManager:StartBlendOutNiagara, cannot find valid blend out curve asset, NiagaraEffectPath: %s", NiagaraEffectParam.NiagaraEffectPath)
			return
		end

		local MinTime, MaxTime = 0.0, 0.0
		MinTime, MaxTime = CurveAsset:GetTimeRange(MinTime, MaxTime)
		local CurveTimeRange = MaxTime - MinTime
		if CurveTimeRange <= 1e-4 then
			Log.ErrorFormat("EffectManager:StartBlendOutNiagara, invalid curve time range %f", CurveTimeRange)
			return
		end

		self.cppMgr:AddFloatCurveParams(NiagaraEffectParam.NiagaraSystemId, ParamName, CurveAsset, false, 1.0, false)

		DelayDeactivateMs = CurveTimeRange * 1000
	else
		local StartVal = NiagaraEffectParam.BlendOutStartVal
		local EndVal = NiagaraEffectParam.BlendOutEndVal
		local Duration = NiagaraEffectParam.BlendOutDuration
		if StartVal == nil or EndVal == nil or Duration == nil then
			Log.ErrorFormat("EffectManager:StartBlendOutNiagara, invalid linear sample params, NiagaraEffectPath: %s", NiagaraEffectParam.NiagaraEffectPath)
			return
		end

		self.cppMgr:AddLinearSampleFloatParams(NiagaraEffectParam.NiagaraSystemId, ParamName, StartVal, EndVal, Duration, false)

		DelayDeactivateMs = Duration * 1000
	end
	
	if NiagaraEffectParam.EffectPlayRate > 1e-4 then
		DelayDeactivateMs = DelayDeactivateMs / NiagaraEffectParam.EffectPlayRate
	end

	-- blend out curve用的比较少 暂时维持这个结构
	NiagaraEffectParam.BlendOutDeactivateTimerId = Game.TimerManager:CreateTimerAndStart(function()
		if EffectManager.bEnableLogging then
			Log.Debug("EffectManager:DeactivateNiagaraSystem, destroy niagara on blend out timer timeout", NiagaraEffectId)
		end
		self:DeactivateNiagaraSystem(NiagaraEffectId)
	end, DelayDeactivateMs, 1)
end

function EffectManager:InternalCreateNiagaraSystem(NiagaraEffectId, InNiagaraAsset)
    local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraEffectId]
    if NiagaraEffectParam == nil then
        Log.ErrorFormat("EffectManager:InternalCreateNiagaraSystem, cannot find niagara effect params, NiagaraEffectId: %d", NiagaraEffectId)
        return
    end

    local NiagaraAsset = self:GetNiagaraAsset(NiagaraEffectParam, InNiagaraAsset)
    if NiagaraAsset == nil or not NiagaraAsset:IsA(UNiagaraSystem) then
        Log.ErrorFormat("EffectManager:InternalCreateNiagaraSystem, invalid NiagaraAsset, NiagaraEffectId: %d", NiagaraEffectId)
        return
    end

    local Spawner = Game.ObjectActorManager:GetObjectByID(NiagaraEffectParam.SpawnerId)
    local SpawnTrans = NiagaraEffectParam.SpawnTrans
    local Loc = SpawnTrans.Translation
    local Rot = SpawnTrans.Rotation
    local S3D = SpawnTrans.Scale3D
	
    -- 主角特效都是立刻播放
    local bActivateImmediately = NiagaraEffectParam.bActivateImmediately
    local QualityLevelOffset = 0
	
    if NiagaraEffectParam.SourceType == const.NIAGARA_SOURCE_TYPE.BATTLE and not self.bDisableQualityLevelOffsetAndTransparencyScale then
		local spawnerEntityId = NiagaraEffectParam.InstigatorEntityId ~= 0 and NiagaraEffectParam.InstigatorEntityId or NiagaraEffectParam.SpawnerEntityId
		local SpawnerEntity = Game.EntityManager:getEntity(spawnerEntityId)
        if SpawnerEntity and SpawnerEntity.FinalOwnerID ~= nil and Game.me ~= nil then
            -- 3p玩家战斗特效降级，怪物不变
            local OwnerEntity = Game.EntityManager:getEntity(SpawnerEntity.FinalOwnerID)
            if OwnerEntity and OwnerEntity ~= Game.me and OwnerEntity.isAvatar then
                QualityLevelOffset = self.UnimportantNiagaraQualityLevelOffset
				NiagaraEffectParam.TransparencyScale = (self.UnimportantNiagaraAlphaLevel + 1.0) / 4.0 * (NiagaraEffectParam.TransparencyScale or 1.0)
            end
        end
    end
	if Game.BSManager.bIsInEditor == true then
		QualityLevelOffset = 0
	end

	-- todo 这里后续全部要在资源侧处理, 有问题的资源梳理完成之前, 暂时还是用 SetForceLocalPlayer
	local bIsPlayerEffect = NiagaraEffectParam.bEngineCulling == false
    local NiagaraSystemId = 0
	local bEnablePriorityCulling = NiagaraEffectParam.NiagaraBudgetToken ~= nil
	local NiagaraBudgetToken = NiagaraEffectParam.NiagaraBudgetToken and NiagaraEffectParam.NiagaraBudgetToken or 0
    if NiagaraEffectParam.bNeedAttach and not NiagaraEffectParam.bEnableStabilizeAttach then
		local AttachComp = Game.ObjectActorManager:GetObjectByID(NiagaraEffectParam.AttachComponentId)
		if AttachComp == nil then
			Log.ErrorFormat("EffectManager:InternalCreateNiagaraSystem, invalid attach component, NiagaraEffectId: %d, NiagaraEffectPath: %s",
				NiagaraEffectId, NiagaraEffectParam.NiagaraEffectPath)
			return
		end
		
        NiagaraSystemId = self.cppMgr:CreateNiagaraSystemAttached(
                NiagaraAsset, NiagaraEffectParam.LocationType, NiagaraEffectParam.AttachPointName, AttachComp, Spawner,
                NiagaraEffectParam.EffectPlayRate, bActivateImmediately,
                Loc.X, Loc.Y, Loc.Z,
                Rot.X, Rot.Y, Rot.Z, Rot.W,
                S3D.X, S3D.Y, S3D.Z,
				bEnablePriorityCulling, NiagaraBudgetToken, bIsPlayerEffect, QualityLevelOffset
        )
    else
        NiagaraSystemId = self.cppMgr:CreateNiagaraSystemAtLocation(
                NiagaraAsset, Spawner, NiagaraEffectParam.EffectPlayRate,
                bActivateImmediately,
                Loc.X, Loc.Y, Loc.Z,
                Rot.X, Rot.Y, Rot.Z, Rot.W,
                S3D.X, S3D.Y, S3D.Z,
				bEnablePriorityCulling, NiagaraBudgetToken, bIsPlayerEffect, QualityLevelOffset
        )
    end

    if NiagaraSystemId == 0 then
        -- failed to create niagara system
        Log.ErrorFormat("EffectManager:InternalCreateNiagaraSystem, create niagara component failed, NiagaraEffectId: %d, EffectPath: %s",
			NiagaraEffectId, NiagaraEffectParam.NiagaraEffectPath)
        return
    end

	if NiagaraEffectParam.NiagaraBudgetToken then
		self.NiagaraBudgetTokenToEffectId[NiagaraEffectParam.NiagaraBudgetToken] = nil
	end
    self:SetFloatCurveParams(NiagaraEffectParam, NiagaraSystemId)

    NiagaraEffectParam.NiagaraSystemId = NiagaraSystemId
    self.NiagaraSystemIdToEffectId[NiagaraSystemId] = NiagaraEffectId

    local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraSystemId)
    if NiagaraComponent ~= nil then
        -- activate immediately
        self:RefreshNiagaraStateOnActivate(NiagaraEffectId)
    end
end

function EffectManager:UnpackFlags(NiagaraEffectParam, bFlags)
    NiagaraEffectParam.bNeedAttach = (bFlags & (1 << Enum.NiagaraTransformFlagOffset.bNeedAttach)) ~= 0
    NiagaraEffectParam.bAbsoluteRotation = (bFlags & (1 << Enum.NiagaraTransformFlagOffset.bAbsoluteRotation)) ~= 0
    NiagaraEffectParam.bAbsoluteScale = (bFlags & (1 << Enum.NiagaraTransformFlagOffset.bAbsoluteScale)) ~= 0
    NiagaraEffectParam.bNeedCheckGround = (bFlags & (1 << Enum.NiagaraTransformFlagOffset.bNeedCheckGround)) ~= 0
    NiagaraEffectParam.bIsRightSide = (bFlags & (1 << Enum.NiagaraTransformFlagOffset.bIsRightSide)) ~= 0
end

-- internal usage
function EffectManager:UpdateParamByNotifyType(NiagaraEffectParam, NotifyType)
	if NotifyType == Enum.EAnimState.FootPrint then
		-- 脚印特殊定制：读身上的饰品数据
		local Spawner = Game.EntityManager:getEntity(NiagaraEffectParam.SpawnerEntityId)
		if Spawner then
			if not Spawner.GetCurrentFootPrintPath then
				Log.Warning("[FootPrint triggered by wrong entity type]", Spawner.ENTITY_TYPE)
				return
			end
			NiagaraEffectParam.NiagaraEffectPath = Spawner:GetCurrentFootPrintPath(NiagaraEffectParam.bIsRightSide)
		end
	end

end

function EffectManager:InternalGenerateAnimNotifyParam(NotifyType, AttachComponentId, NiagaraAssetPath, AttachPointName, SpawnerEntityId, SpawnerId, TotalLifeSeconds, bFlags, InTransform)
    local NiagaraEffectParam = NiagaraEffectParamTemplate.AllocFromPool()
    NiagaraEffectParam.NiagaraEffectPath = NiagaraAssetPath
    self:UnpackFlags(NiagaraEffectParam, bFlags)
    if NiagaraEffectParam.bNeedAttach then
        NiagaraEffectParam.AttachPointName = AttachPointName
        NiagaraEffectParam.AttachComponentId = AttachComponentId
    else
        NiagaraEffectParam.AttachPointName = ""
    end
    NiagaraEffectParam.SpawnerEntityId = SpawnerEntityId
    NiagaraEffectParam.SpawnerId = SpawnerId
    NiagaraEffectParam.SourceType = NIAGARA_SOURCE_TYPE.ANIM_NOTIFY
    NiagaraEffectParam.bEngineCulling = true
    if TotalLifeSeconds == nil or TotalLifeSeconds <= 0 then
        NiagaraEffectParam.TotalLifeMs = -1
    else
        NiagaraEffectParam.TotalLifeMs = math.min(TotalLifeSeconds, 20) * 1000   -- 给一个上限，防止无限制播放，按惯例与策划沟通后写死20s
    end
    if InTransform ~= nil then
        M3D.ToTransform(InTransform, NiagaraEffectParam.SpawnTrans)
    end
    -- 使用默认参数检测表面
	if (NiagaraEffectParam.bNeedAttach == false and NiagaraEffectParam.bNeedCheckGround == true) then
		local Offset = M3D.Vec3(-300, 300, 0.2)
		local ObjectTypes = BSFunc.EnumsToBitMask({ 0 })
		local WLocation = NiagaraEffectParam.SpawnTrans.Translation

		local Result, X, Y, Z = UBSFunc.FindGroundLocation_P(
				Game.WorldContext, nil, WLocation.X, WLocation.Y, WLocation.Z, ObjectTypes, Offset.X, Offset.Y, Offset.Z, M3D.Fill3())
        
        -- 如果在水中：上修到水面
        -- TODO [lx] 目前GetWaterDepth仅支持p1，后续需要扩展
        local Spawner = Game.EntityManager:getEntity(NiagaraEffectParam.SpawnerEntityId)
        if Spawner and Spawner.GetCurWaterDepth then
            Offset_Z = Spawner:GetCurWaterDepth()
            if Offset_Z > 0 then
                Z = Z + Offset_Z + Enum.EConstIntData.INWATER_EFFECT_OFFSET
            end
        end

		if (Result == true) then
			WLocation.X = X
			WLocation.Y = Y
			WLocation.Z = Z
		end
	end

	self:UpdateParamByNotifyType(NiagaraEffectParam, NotifyType)
    return NiagaraEffectParam
end

-- 水中移动相关

-- 水中移动相关 end

function EffectManager:NiagaraSetRelativeLoc(EffectID, LocalTransform)
	-- 注意：调整之前要确认自己操作的什么特效，知道自己在干什么
	-- EffectID: CreateNiagaraSystem的返回值

	local NiagaraEffectParam = self.NiagaraEffectParams[EffectID]
	if not NiagaraEffectParam then return end
	
	local NiagaraSystemID = NiagaraEffectParam.NiagaraSystemId
	if not NiagaraSystemID then return end

	local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraSystemID)
	if not NiagaraComponent then return end

	NiagaraComponent:K2_SetRelativeTransform(LocalTransform, false, nil, false)
end

function EffectManager:OnAnimNotifyNiagaraEffect(NotifyType, AttachComponentId, NiagaraAssetPath, AttachPointName, OwnerEntityUID, OwnerActorId, TotalLifeSeconds, bAllFlags, InTransform)
	local OwnerEntity = Game.EntityManager:getEntity(OwnerEntityUID)
	if NotifyType ~= Enum.EAnimState.FootPrint and OwnerEntity.CheckNiagaraPlayCD and OwnerEntity:CheckNiagaraPlayCD(NiagaraAssetPath, true) == false then
		-- 短时间连续播放去重
		return 0
	end
	
	return self:CreateNiagaraSystem(self:InternalGenerateAnimNotifyParam(
		NotifyType,
        AttachComponentId,
        NiagaraAssetPath,
        AttachPointName,
        OwnerEntityUID,
        OwnerActorId, 
        TotalLifeSeconds,
        bAllFlags,
        InTransform
    ))
end

function EffectManager:OnAnimNotifyNiagaraEffectEnd(NiagaraSystemID)
    if NiagaraSystemID ~= nil then
        local NiagaraEffectParam = self.NiagaraEffectParams[NiagaraSystemID]
        if NiagaraEffectParam == nil then return end
        if NiagaraEffectParam.TotalLifeMs > 0 then
            -- 持续时长合法的，允许不受结束事件控制
            return
        end
        self:DestroyNiagaraSystem(NiagaraSystemID)
    end
end

function EffectManager:OnNiagaraSystemActivate(NiagaraSystemId)
    local EffectId = self.NiagaraSystemIdToEffectId[NiagaraSystemId]
    -- 如果特效是立即创建的 那么本身会在特效创建完就处理特效参数缓存/显隐状态等逻辑, 因此这里有可能为nil
    if EffectId == nil then
        return
    end

	if EffectManager.bEnableLogging then
		Log.DebugFormat(
		        "EffectManager:OnNiagaraSystemActivate, refresh niagara state, EffectId: %d, NiagaraSystemId: %d",
		        EffectId, NiagaraSystemId)
	end

    self:RefreshNiagaraStateOnActivate(EffectId)
end

-- 仅内部打断才会调用到这里
function EffectManager:OnNiagaraSystemFinished(NiagaraSystemId)
    -- 内部粒子生命周期结束, 通知清理状态
    local EffectId = self.NiagaraSystemIdToEffectId[NiagaraSystemId]
    if EffectId == nil then
        -- external interrupt
        return
    end

	if EffectManager.bEnableLogging then
		Log.DebugFormat("EffectManager:OnNiagaraSystemFinished, EffectId: %d, NiagaraSystemId: %d", EffectId, NiagaraSystemId)
	end

    local NiagaraEffectParam = self.NiagaraEffectParams[EffectId]
    if NiagaraEffectParam == nil then
        Log.ErrorFormat("EffectManager:OnNiagaraSystemFinished, cannot find niagara effect params, NiagaraEffectId: %d", EffectId)
        return
    end

    if NiagaraEffectParam.AssetLoadId ~= 0 then
        Game.AssetManager:RemoveAssetReferenceByLoadID(NiagaraEffectParam.AssetLoadId)
    end

    if NiagaraEffectParam.NiagaraSystemId == nil then
        Log.ErrorFormat("EffectManager:OnNiagaraSystemFinished, invalid NiagaraSystemId on internal system finish, NiagaraEffectId: %d", EffectId)
    end

	self:ClearEffectStates(NiagaraEffectParam)

    self.NiagaraSystemIdToEffectId[NiagaraEffectParam.NiagaraSystemId] = nil
    self:ClearEffectIdRecord(EffectId)
end

function EffectManager:OnNiagaraBudgetSqueezed(BudgetToken)
	-- 如果一个特效在异步加载过程中被预算被抢占了, 通过这里回调到lua层做相关特效状态的清理逻辑
	-- 还有一种可行的方式是等这个特效逻辑一直走到真正创建那一步发现token失效再返回, 但是这样也可以导致很多无意义的逻辑执行
	local EffectId = self.NiagaraBudgetTokenToEffectId[BudgetToken]
	if EffectId == nil then
		return
	end

	if EffectManager.bEnableLogging then
		Log.Debug("EffectManager:OnNiagaraBudgetSqueezed", BudgetToken, EffectId)
	end
	self:DestroyNiagaraSystem(EffectId)
end

function EffectManager:OnEffectSettingChanged(ChangeType, EffectQualityLevel, OtherEffectQualityLevel, OtherEffectTransparencyLevel)
    -- 目前的特效规则：
    -- 1. 重置玩家自身【特效质量】设置时，会默认调整【其他玩家特效强度】和【其他玩家特效质量】，【其他玩家特效质量】默认比主机低一档，【其他玩家特效强度】默认比主机低两档
    -- 2. 重置【其他玩家特效强度】，【其他玩家特效质量】时，不能高于当前p1自己的【特效质量】（在特效设置时拦截）

    if ChangeType == const.EFFECT_SETTING_CONST.EFFECT_QUALITY then
        -- 1. 重置玩家自身【特效质量】设置时，会默认调整【其他玩家特效强度】和【其他玩家特效质量】，【其他玩家特效质量】默认比主机低一档，【其他玩家特效强度】默认比主机低两档
        if OtherEffectQualityLevel ~= nil then
            self.UnimportantNiagaraQualityLevelOffset = OtherEffectQualityLevel - EffectQualityLevel
        else
            self.UnimportantNiagaraQualityLevelOffset = math.min(-1, self.UnimportantNiagaraQualityLevelOffset)
        end

        if OtherEffectTransparencyLevel ~= nil then
            self.UnimportantNiagaraAlphaLevel = OtherEffectTransparencyLevel
        else
            self.UnimportantNiagaraAlphaLevel = math.min(math.max(0, EffectQualityLevel - 2), self.UnimportantNiagaraAlphaLevel)
        end
    elseif ChangeType == const.EFFECT_SETTING_CONST.OTHER_EFFECT_QUALITY then
        self.UnimportantNiagaraQualityLevelOffset = OtherEffectQualityLevel - EffectQualityLevel
    elseif ChangeType == const.EFFECT_SETTING_CONST.OTHER_EFFECT_STRENGTH then
        self.UnimportantNiagaraAlphaLevel = OtherEffectTransparencyLevel
    end
end

function EffectManager:SetNiagaraComponentUserParameters(NiagaraEffectParam, NiagaraComponent)

    -- flush cached user params
	if NiagaraEffectParam.UserVals_Vec3 ~= nil then
		for ParamName, ParamVal in pairs(NiagaraEffectParam.UserVals_Vec3) do
			TempVal_Vec3.X = ParamVal.X
			TempVal_Vec3.Y = ParamVal.Y
			TempVal_Vec3.Z = ParamVal.Z
			NiagaraComponent:SetVariableVec3(ParamName, TempVal_Vec3)
		end
	end
	if NiagaraEffectParam.UserVals_LinearColor ~= nil then
		for ParamName, ParamVal in pairs(NiagaraEffectParam.UserVals_LinearColor) do
			TempVal_LinearColor.R = ParamVal.R
			TempVal_LinearColor.G = ParamVal.G
			TempVal_LinearColor.B = ParamVal.B
			TempVal_LinearColor.A = ParamVal.A
			NiagaraComponent:SetVariableLinearColor(ParamName, TempVal_LinearColor)
		end
	end
	if NiagaraEffectParam.UserVals_Vec2 ~= nil then
		for ParamName, ParamVal in pairs(NiagaraEffectParam.UserVals_Vec2) do
			TempVal_Vec2.X = ParamVal.X
			TempVal_Vec2.Y = ParamVal.Y
			NiagaraComponent:SetVariableVec2(ParamName, TempVal_Vec2)
		end
	end

	if NiagaraEffectParam.UserVals_Float ~= nil then
		for ParamName, ParamVal in pairs(NiagaraEffectParam.UserVals_Float) do
			NiagaraComponent:SetVariableFloat(ParamName, ParamVal)
		end
	end

	if NiagaraEffectParam.UserVals_SkeletalMeshCompIds ~= nil then
		for ParamName, ParamVal in pairs(NiagaraEffectParam.UserVals_SkeletalMeshCompIds) do
			local SkeletalMeshComp = Game.ObjectActorManager:GetObjectByID(ParamVal)
			if SkeletalMeshComp ~= nil then
				NiagaraFunctionLibrary.OverrideSystemUserVariableSkeletalMeshComponent(NiagaraComponent, ParamName, SkeletalMeshComp)
			end
		end
	end

	if NiagaraEffectParam.UserVals_SkeletalMeshCompFilterBones ~= nil then
		for ParamName, ParamVal in pairs(NiagaraEffectParam.UserVals_SkeletalMeshCompFilterBones) do
			TempVal_BoneNamesArray:Clear()
			for _, BoneName in ipairs(ParamVal) do
				TempVal_BoneNamesArray:Add(BoneName)
			end
			NiagaraFunctionLibrary.SetSkeletalMeshDataInterfaceFilteredBones(NiagaraComponent, ParamName, TempVal_BoneNamesArray)
		end
	end

	if NiagaraEffectParam.SplineLinkTargetCompId ~= nil and  NiagaraEffectParam.SplineLinkTargetCompId ~= 0 and NiagaraEffectParam.SplineUserVarName ~= nil then
		self:SetSplineUserVar(NiagaraEffectParam)
	end

	if NiagaraEffectParam.FollowActorUserValName ~= nil and NiagaraEffectParam.FollowActorId ~= nil then
		local Actor = Game.ObjectActorManager:GetObjectByID(NiagaraEffectParam.FollowActorId)
		self.cppMgr:SetNiagaraFollowActorParams(NiagaraEffectParam.NiagaraSystemId, NiagaraEffectParam.FollowActorUserValName, Actor, NiagaraEffectParam.bAbsoluteNiagaraRotationInFollow)
	end

	if NiagaraEffectParam.CameraArmLengthUserValName ~= nil then
		self.cppMgr:SetNiagaraUseCameraArmLengthParams(NiagaraEffectParam.NiagaraSystemId, NiagaraEffectParam.CameraArmLengthUserValName)
	end

	if NiagaraEffectParam.CachedArcPositionParamName ~= nil then
		self.cppMgr:SetNiagaraUpdatePositionWithArcParams(
			NiagaraEffectParam.NiagaraSystemId, NiagaraEffectParam.CachedArcPositionParamName, NiagaraEffectParam.CachedArcPositionParamRadius,
			NiagaraEffectParam.CachedArcPositionParamStartRelativeYaw, NiagaraEffectParam.CachedArcPositionParamRotateAngle,
			NiagaraEffectParam.CachedArcPositionParamDuration)
	end
end

function EffectManager:SetFaceToTargetLocation(NiagaraEffectParam, EffectId)
	if NiagaraEffectParam.bNeedAttach == false and not NiagaraEffectParam.bEnableStabilizeAttach then
		Log.ErrorFormat("EffectManager:SetFaceToTargetLocation, niagara is not attached, %d", EffectId)
		return
	end

	NiagaraEffectParam.bAbsoluteRotation = true
	local Loc = NiagaraEffectParam.FacingTargetLocation
	self.cppMgr:SetNiagaraFaceToLocation(NiagaraEffectParam.NiagaraSystemId, Loc.X, Loc.Y)
end

function EffectManager:SetFaceToTargetActor(NiagaraEffectParam)
	local FacingActor = Game.ObjectActorManager:GetObjectByID(NiagaraEffectParam.FacingTargetActorId)
	if FacingActor then
		self.cppMgr:SetNiagaraFaceToActor(NiagaraEffectParam.NiagaraSystemId, FacingActor)
	end
end

function EffectManager:RefreshNiagaraStateOnActivate(EffectId)
    local NiagaraEffectParam = self.NiagaraEffectParams[EffectId]
    if NiagaraEffectParam == nil then
        Log.ErrorFormat("EffectManager:RefreshNiagaraStateOnActivate, cannot find niagara effect params, NiagaraEffectId: %d", EffectId)
        return
    end

    if NiagaraEffectParam.NiagaraSystemId == nil then
        Log.ErrorFormat("EffectManager:RefreshNiagaraStateOnActivate, NiagaraSystemId should not be nil %d", EffectId)
        return
    end

    local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
    if NiagaraComponent == nil then
        Log.ErrorFormat("EffectManager:RefreshNiagaraStateOnActivate, NiagaraComponent should not be nil %d", EffectId)
        return
    end

	if self.bDebugCheckNiagaraEffectType then
		self:CheckNiagaraEffectType(NiagaraEffectParam, NiagaraComponent)
	end
	
	self:SetNiagaraComponentUserParameters(NiagaraEffectParam, NiagaraComponent)

    self:UpdateHiddenStateOnActivate(EffectId)

	if NiagaraEffectParam.bEnableStabilizeAttach then
		self:EnableStabilizeAttach(NiagaraEffectParam, NiagaraComponent)
	end

	if NiagaraEffectParam.bForceFaceToLocation then
		self:SetFaceToTargetLocation(NiagaraEffectParam, EffectId)
	end

	if NiagaraEffectParam.bForceFaceToTargetActor then
		self:SetFaceToTargetActor(NiagaraEffectParam)
	end
	
	if NiagaraEffectParam.bFollowSlomo then
		self.cppMgr:SetNiagaraFollowSlomo(NiagaraEffectParam.NiagaraSystemId)
	end

	if NiagaraEffectParam.bFollowCameraFOV then
		self.cppMgr:SetNiagaraFollowCameraFOV(NiagaraEffectParam.NiagaraSystemId)
	end
	
    -- 设置niagara其他参数
    NiagaraComponent:SetAbsolute(false, NiagaraEffectParam.bAbsoluteRotation, NiagaraEffectParam.bAbsoluteScale)
    NiagaraComponent:SetParticleColorScale(NiagaraEffectParam.TransparencyScale)

    -- 设置life timer
    local TotalLifeMs = NiagaraEffectParam.TotalLifeMs
    if TotalLifeMs > 0 then
		self.cppMgr:SetNiagaraTimeoutInfo(NiagaraEffectParam.NiagaraSystemId, EKGNiagaraTimeoutState.Deactivate, TotalLifeMs / 1000)

		local DelayDestroyMs = NiagaraEffectParam.DelayDestroyMs
		if DelayDestroyMs > 0 then
			self.cppMgr:SetNiagaraTimeoutInfo(NiagaraEffectParam.NiagaraSystemId, EKGNiagaraTimeoutState.Destroy, (TotalLifeMs + DelayDestroyMs) / 1000)
		end
    end

    -- 设置component tag
	if NiagaraEffectParam.ComponentTags ~= nil and #NiagaraEffectParam.ComponentTags > 0 then
		TempVal_CompTagsArray:Clear()
		for _, ComponentTag in ipairs(NiagaraEffectParam.ComponentTags) do
			TempVal_CompTagsArray:Add(ComponentTag)
		end
		ComponentUtil.SetComponentTags(NiagaraComponent, TempVal_CompTagsArray)
		table.clear(NiagaraEffectParam.ComponentTags)
	end

	if NiagaraEffectParam.bCachedBlendOutEnabled then
		self:StartBlendOutNiagara(EffectId)
	end
	
	-- 是否开启3d
	if NiagaraEffectParam.bIs3DFx then
		NiagaraComponent:SetRenderInMainPass(false)
		--NiagaraComponent:SetRenderInDepthPass(false)
		NiagaraComponent:SetRenderCustomDepth(true)
		NiagaraComponent:SetCustomDepthStencilValue(1)
	end
end

--非VisibleComponent控制情况下，显隐控制需要手动调用此接口更新
function EffectManager:OnUpdateSpawnerVisibility(CharacterID,bVisible,Reason)
	local EffectIDs = Game.EffectManager:GetEffectIDsBySpawner(CharacterID)
	if EffectIDs == nil then
		return
	end
	for effectID, _ in pairs(EffectIDs) do
		self:UpdateNiagaraHiddenState(effectID, not bVisible, NIAGARA_HIDDEN_REASON.OWNER_SET_HIDDEN)
	end
end


function EffectManager:InternalUpdateNiagaraHiddenState(NiagaraComponent, bNiagaraHidden)
    if NiagaraComponent == nil then
        Log.ErrorFormat("EffectManager:InternalUpdateNiagaraHiddenState, NiagaraComponent should not be nil")
        return
    end

    NiagaraComponent:SetVisibility(not bNiagaraHidden)
    NiagaraComponent:SetHiddenInGame(bNiagaraHidden)

    -- todo 后续可以补充降低niagara更新频率逻辑
end

function EffectManager:GetEffectIDsBySpawner(SpawnerID)
    return self.SpawnerIdToEffectIds[SpawnerID]
end

function EffectManager:UpdateSpawner(NiagaraEffectParam)
    local Entity = Game.EntityManager:getEntity(NiagaraEffectParam.SpawnerEntityId)
	if not Entity then return end
    if Entity.bIsAttachItem == true then
        Entity = Game.EntityManager:getEntity(Entity:GetAttachItemManagerEntity())
        if not Entity then return end
    end
    NiagaraEffectParam.SpawnerEntityId = Entity:uid()
    NiagaraEffectParam.SpawnerId = Entity.CharacterID
end

function EffectManager:UpdateHiddenStateOnActivate(EffectId)
    local NiagaraEffectParam = self.NiagaraEffectParams[EffectId]
	self:UpdateSpawner(NiagaraEffectParam)

    if NiagaraEffectParam.bFollowHidden then
		-- 默认的刷新规则：
		-- 根据Attach Parent和Spawner的状态刷新
		local bOwnerVisible = true
		-- 原始逻辑只会在 AttachParentComponent 为MeshComponent的情况下检测AttachParentComponent的IsVisible
		-- 这个规则比较怪 这段逻辑先去掉 只检测 AttachOwner 和 Spawner
		local NiagaraComponent = self.cppMgr:GetNiagaraComponentByNiagaraSystemId(NiagaraEffectParam.NiagaraSystemId)
		if NiagaraComponent == nil then
			Log.Error("EffectManager:UpdateHiddenStateOnActivate, NiagaraComponent should not be nil")
		else
			local AttachParentComp = NiagaraComponent:GetAttachParent()
			if AttachParentComp ~= nil then
				local AttachParentActor = AttachParentComp:GetOwner()
				if AttachParentActor ~= nil then
					bOwnerVisible = not ActorUtil.IsActorHidden(AttachParentActor)
				end
			end
		end
		if bOwnerVisible then
			local Spawner = Game.ObjectActorManager:GetObjectByID(NiagaraEffectParam.SpawnerId)
			if Spawner ~= nil then
				bOwnerVisible = not ActorUtil.IsActorHidden(Spawner)
			end
		end

		self:UpdateNiagaraHiddenState(EffectId, not bOwnerVisible, NIAGARA_HIDDEN_REASON.OWNER_SET_HIDDEN, true)
	end

	-- 根据effect tag决定hidden state
	for _, EffectTag in ipairs(NiagaraEffectParam.EffectTags) do
		local HiddenReasons = self.EffectTagHiddenState[EffectTag]
		if HiddenReasons then
			for HiddenReason, _ in pairs(HiddenReasons) do
				self:UpdateNiagaraHiddenState(EffectId, true, HiddenReason, true)
			end
		end
	end
end

function EffectManager:EnableStabilizeAttach(NiagaraEffectParam, NiagaraComponent)
	local TargetEntity = Game.EntityManager:getEntity(NiagaraEffectParam.SpawnerEntityId)
	if TargetEntity == nil then
		Log.Error("EffectManager:EnableStabilizeAttach, invalid target entity")
		return
	end
	
	local AttachComp = Game.ObjectActorManager:GetObjectByID(NiagaraEffectParam.AttachComponentId)
	if AttachComp == nil then
		Log.Error("EffectManager:EnableStabilizeAttach, invalid attach component")
		return
	end
	
	NiagaraEffectParam.AttachSocketId = TargetEntity:AddAttachSocket(
		NiagaraEffectParam.AttachPointName, nil, EffectManager.TempVal_EmptyVector, EffectManager.TempVal_EmptyRotator,
		EffectManager.TempVal_EmptyVector, EffectManager.TempVal_EmptyRotator)

	TargetEntity.AttachJointComp.bEnableDebugDraw = true
	
	local SocketLocation = AttachComp:GetSocketTransform(NiagaraEffectParam.AttachPointName, ERelativeTransformSpace.RTS_Component):GetTranslation()
	TargetEntity:UECompAttachByVirtualSocket(NiagaraComponent, NiagaraEffectParam.AttachSocketId, EffectManager.TempVal_IdentityTransform, false)
	TargetEntity:EnableLocationStabilize(NiagaraEffectParam.SplineAttachSocketId, true, 20, 1, 5, "root", SocketLocation)
end

function EffectManager:SetSplineUserVar(NiagaraEffectParam)
    if (not NiagaraEffectParam.bNeedAttach and not NiagaraEffectParam.bEnableStabilizeAttach) or NiagaraEffectParam.AttachComponentId == 0 then
        Log.Warning("EffectManager:SetSplineUserVar, invalid attached component")
        return
    end

    local LinkTargetComp = Game.ObjectActorManager:GetObjectByID(NiagaraEffectParam.SplineLinkTargetCompId)
    if LinkTargetComp == nil then
        Log.Error("EffectManager:SetSplineUserVar, invalid target component")
        return
    end
	
    local SpawnerActor = Game.ObjectActorManager:GetObjectByID(NiagaraEffectParam.SpawnerId)
    if SpawnerActor == nil then
        Log.Error("EffectManager:SetSplineUserVar, invalid spawner actor")
        return
    end

    local SplineBPClass = nil
    for _, LoadResult in ipairs(NiagaraEffectParam.NiagaraAssetsLoadResults) do
        if LoadResult.ExtraAssetType == NIAGARA_EXTRA_ASSET_TYPE.SplineBP then
            SplineBPClass = Game.ObjectActorManager:GetClassByID(LoadResult.ExtraAssetId)
            break
        end
    end

    if SplineBPClass == nil then
        Log.Error("EffectManager:SetSplineUserVar, invalid spline bp")
        return
    end

	local AttachSocketId = 0
	if NiagaraEffectParam.bEnableSplineSocketStabilize and NiagaraEffectParam.bUseSocketLocationOnSplineTarget and
			NiagaraEffectParam.SplineLinkTargetEntityId ~= nil then
		local TargetEntity = Game.EntityManager:getEntity(NiagaraEffectParam.SplineLinkTargetEntityId)
		if TargetEntity == nil then
			Log.Error("EffectManager:SetSplineUserVar, invalid target entity")
			return
		end

		NiagaraEffectParam.SplineAttachSocketId = TargetEntity:AddAttachSocket(
			NiagaraEffectParam.SplineTargetSocketName, nil, EffectManager.TempVal_EmptyVector, EffectManager.TempVal_EmptyRotator,
			EffectManager.TempVal_EmptyVector, EffectManager.TempVal_EmptyRotator)
		AttachSocketId = NiagaraEffectParam.SplineAttachSocketId

		TargetEntity:ForceSocketUpdate(AttachSocketId, true)
		--TargetEntity.AttachJointComp.bEnableDebugDraw = true
		
		local SocketLocation = LinkTargetComp:GetSocketTransform(NiagaraEffectParam.SplineTargetSocketName, ERelativeTransformSpace.RTS_Component):GetTranslation()
		TargetEntity:EnableLocationStabilize(NiagaraEffectParam.SplineAttachSocketId, true, 20, 1, 5, "root", SocketLocation)
	end
	
    local Rot = SpawnerActor:K2_GetActorRotation()
    local Loc = SpawnerActor:K2_GetActorLocation()

    local SplineActor = Game.ObjectActorManager:SpawnActor(SplineBPClass, true, Loc.X, Loc.Y, Loc.Z, Rot.Pitch, Rot.Yaw, Rot.Roll)
    NiagaraEffectParam.SplineActorId = Game.ObjectActorManager:GetIDByObject(SplineActor)
	
    self.cppMgr:SetNiagaraSplineLinkParams(
		NiagaraEffectParam.NiagaraSystemId, LinkTargetComp, NiagaraEffectParam.bUseSocketLocationOnSplineTarget,
		NiagaraEffectParam.SplineTargetSocketName, SplineActor, NiagaraEffectParam.SplineUserVarName,
		NiagaraEffectParam.bEnableSplineSocketStabilize, AttachSocketId)
end

function EffectManager:AssembleLoadAssets(NiagaraEffectParam)
	table.clear(TempVal_NiagaraAssetsNeedsToLoad)
	table.insert(TempVal_NiagaraAssetsNeedsToLoad, NiagaraEffectParam.NiagaraEffectPath)

	if NiagaraEffectParam.UserVals_FloatCurves ~= nil then
		for ParamName, ParamVal in pairs(NiagaraEffectParam.UserVals_FloatCurves) do
			table.insert(TempVal_NiagaraAssetsNeedsToLoad, ParamVal)

			-- 为了加载结果能按序对应到参数名
			local CurveLoadParams = {
				ParamName = ParamName,
				ExtraAssetId = nil,
				ExtraAssetType = NIAGARA_EXTRA_ASSET_TYPE.CurveFloat,
				AssetPath = ParamVal
			}
			table.insert(NiagaraEffectParam.NiagaraAssetsLoadResults, CurveLoadParams)
		end
	end

    if NiagaraEffectParam.SplineBPPath ~= nil then
        table.insert(TempVal_NiagaraAssetsNeedsToLoad, NiagaraEffectParam.SplineBPPath)

        local CurveLoadParams = {
            ParamName = NiagaraEffectParam.SplineUserVarName,
            ExtraAssetId = nil,
            ExtraAssetType = NIAGARA_EXTRA_ASSET_TYPE.SplineBP,
			AssetPath = NiagaraEffectParam.SplineBPPath
        }
        table.insert(NiagaraEffectParam.NiagaraAssetsLoadResults, CurveLoadParams)
    end

	if NiagaraEffectParam.BlendOutFloatCurvePath ~= nil then
		table.insert(TempVal_NiagaraAssetsNeedsToLoad, NiagaraEffectParam.BlendOutFloatCurvePath)

		local CurveLoadParams = {
			ParamName = NiagaraEffectParam.BlendOutFloatCurvePath,
			ExtraAssetId = nil,
			ExtraAssetType = NIAGARA_EXTRA_ASSET_TYPE.BlendOutCurveFloat,
			AssetPath = NiagaraEffectParam.BlendOutFloatCurvePath
		}
		table.insert(NiagaraEffectParam.NiagaraAssetsLoadResults, CurveLoadParams)
	end

    return TempVal_NiagaraAssetsNeedsToLoad
end

function EffectManager:ClearEffectStates(NiagaraEffectParam)
	if NiagaraEffectParam.BlendOutDeactivateTimerId ~= nil then
		Game.TimerManager:StopTimerAndKill(NiagaraEffectParam.BlendOutDeactivateTimerId)
	end
	
	if NiagaraEffectParam.SplineActorId ~= nil then
		local SplineActor = Game.ObjectActorManager:GetObjectByID(NiagaraEffectParam.SplineActorId)
		if SplineActor then
			Game.ObjectActorManager:DestroyActor(SplineActor)
		end
	end

	local TargetEntity
	if NiagaraEffectParam.AttachSocketId ~= nil then
		TargetEntity = Game.EntityManager:getEntity(NiagaraEffectParam.SpawnerEntityId)
		if TargetEntity == nil then
			Log.Error("EffectManager:ClearEffectStates, invalid target entity")
			return
		end

		TargetEntity:RemoveAttachSocket(NiagaraEffectParam.AttachSocketId)
	end
	
	if NiagaraEffectParam.SplineAttachSocketId ~= nil then
		if TargetEntity == nil then
			TargetEntity = Game.EntityManager:getEntity(NiagaraEffectParam.SplineLinkTargetEntityId)
			if TargetEntity == nil then
				Log.Error("EffectManager:ClearEffectStates, invalid target entity")
				return
			end
		end

		TargetEntity:RemoveAttachSocket(NiagaraEffectParam.SplineAttachSocketId)
	end
end

function EffectManager:ClearEffectIdRecord(EffectId)
    if EffectId == nil then
        return
    end

    local NiagaraEffectParam = self.NiagaraEffectParams[EffectId]

    local SpawnerId = NiagaraEffectParam.SpawnerId
    if SpawnerId ~= nil and SpawnerId ~= 0 then
        local EffectIds = self.SpawnerIdToEffectIds[SpawnerId]
        if EffectIds ~= nil then
            EffectIds[EffectId] = nil
        end
    end

	if NiagaraEffectParam.ExtraSpawnerIds ~= nil then
		for _, ExtraSpawnerId in ipairs(NiagaraEffectParam.ExtraSpawnerIds) do
			local EffectIds = self.SpawnerIdToEffectIds[ExtraSpawnerId]
			if EffectIds ~= nil then
				EffectIds[EffectId] = nil
			end
		end
	end

	for _, EffectTag in ipairs(NiagaraEffectParam.EffectTags) do
		local EffectIds = self.EffectTagToEffectIds[EffectTag]
		EffectIds[EffectId] = nil
	end
	
    local LoadId = NiagaraEffectParam.AssetLoadId
    if LoadId ~= 0 then
        self.NiagaraLoadIdToEffectId[LoadId] = nil
    end

    self.NiagaraEffectParams[EffectId] = nil
    NiagaraEffectParamTemplate.RecycleToPool(NiagaraEffectParam)
end

function EffectManager:IsEffectTagHidden(EffectTag)
	local HiddenReasons = self.EffectTagHiddenState[EffectTag]
	return HiddenReasons ~= nil and next(HiddenReasons) ~= nil
end

-- 为了避免对当前所有播放的特效进行查询，暂不支持组合Tag的方式操作特效
function EffectManager:UpdateCommonEffectTags(EffectId, NiagaraEffectParam)
	-- 一些全局tag在这里初始化，例如阵营, 是否队友等, 特殊tag由外部直接传入
	-- 20241119 部分全局tag查询逻辑相对比较耗时, 在没有设置对应tag需要隐藏的情况下, 实际不需要为这些特效加tag, 为了避免常态下设置tag产生的性能开销
	-- 这里逻辑改为
	-- 1, 仅在全局Tag设置隐藏的情况下, 才会在每个特效播放的过程中尝试为这些特效设置tag
	-- 2, 在全局Tag由显示转为隐藏时, 由于当前正在播的特效实际没有对应的tag, 此时会尝试给所有特效加上tag
	if self:IsEffectTagHidden(NIAGARA_EFFECT_TAG.ENEMY) then
		local SpawnerEntity = Game.EntityManager:getEntity(NiagaraEffectParam.SpawnerEntityId)
		local Relation = BSFunc.GetFinalCampRelation(SpawnerEntity, Game.me)
		if Relation == Enum.ECampEnumData.Enemy and next(NiagaraEffectParam.EffectTags) == nil then
			table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.ENEMY)
		end
	end

	-- 队友和队友增益暂时一同处理
	if self:IsEffectTagHidden(NIAGARA_EFFECT_TAG.TEAMMATE) or self:IsEffectTagHidden(NIAGARA_EFFECT_TAG.TEAMMATE_POSITIVE) then
		-- 优先判断是否是受击造成的特效
		local spawnerEntityId = NiagaraEffectParam.InstigatorEntityId ~= 0 and NiagaraEffectParam.InstigatorEntityId or NiagaraEffectParam.SpawnerEntityId
		local SpawnerEntity = Game.EntityManager:getEntity(spawnerEntityId)
		local Relation = BSFunc.GetFinalCampRelation(SpawnerEntity, Game.me)
		if Relation == Enum.ECampEnumData.Friendly and next(NiagaraEffectParam.EffectTags) == nil then
			local OwnerEntity = BSFunc.GetActorInstigator(SpawnerEntity)
			if OwnerEntity ~= nil then
				if Game.TeamSystem:IsTeamMember(OwnerEntity.eid) then
					if OwnerEntity:uid() ~= Game.me:uid() then
						Log.Debug("UpdateCommonEffectTags NiagaraEffectParam.bBenefitEffect : ", NiagaraEffectParam.bBenefitEffect)
						if NiagaraEffectParam.bBenefitEffect then
							Log.Debug("UpdateCommonEffectTags TEAMMATE_POSITIVE")
							table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.TEAMMATE_POSITIVE)
						else
							Log.Debug("UpdateCommonEffectTags TEAMMATE")
							table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.TEAMMATE)
						end
					end
				else
					if OwnerEntity:uid() ~= Game.me:uid() then
						table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.NEUTRAL)
					end
				end
			end
		elseif Relation == Enum.ECampEnumData.Neutral and next(NiagaraEffectParam.EffectTags) == nil then
			table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.NEUTRAL)
		end
	end

	if self:IsEffectTagHidden(NIAGARA_EFFECT_TAG.BATTLE) then
		if NiagaraEffectParam.SourceType == NIAGARA_SOURCE_TYPE.BATTLE then
			table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.BATTLE)
		end
	end
	
	-- 这里可能有外部传入的tag, 所以还是要设置下
	for _, EffectTag in ipairs(NiagaraEffectParam.EffectTags) do
		if self.EffectTagToEffectIds[EffectTag] == nil then
			self.EffectTagToEffectIds[EffectTag] = {}
		end
		
		local EffectIds = self.EffectTagToEffectIds[EffectTag]
		EffectIds[EffectId] = true
	end
end

function EffectManager:BatchSetAllNiagaraEffectTag(EffectTag)
	for EffectId, NiagaraEffectParam in pairs(self.NiagaraEffectParams) do
		local tagType = NIAGARA_EFFECT_TAG.NEUTRAL
		if EffectTag == NIAGARA_EFFECT_TAG.ENEMY then
			local SpawnerEntity = Game.EntityManager:getEntity(NiagaraEffectParam.SpawnerEntityId)
			local Relation = BSFunc.GetFinalCampRelation(SpawnerEntity, Game.me)
			if Relation == Enum.ECampEnumData.Enemy then
				table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.ENEMY)
				tagType = NIAGARA_EFFECT_TAG.ENEMY
			end
		elseif EffectTag == NIAGARA_EFFECT_TAG.TEAMMATE or EffectTag == NIAGARA_EFFECT_TAG.TEAMMATE_POSITIVE then
			-- 优先判断是否是受击造成的特效
			local spawnerEntityId = NiagaraEffectParam.InstigatorEntityId ~= 0 and NiagaraEffectParam.InstigatorEntityId or NiagaraEffectParam.SpawnerEntityId
			local SpawnerEntity = Game.EntityManager:getEntity(spawnerEntityId)
			local Relation = BSFunc.GetFinalCampRelation(SpawnerEntity, Game.me)
			if Relation == Enum.ECampEnumData.Friendly and next(NiagaraEffectParam.EffectTags) == nil then
				local OwnerEntity = BSFunc.GetActorInstigator(SpawnerEntity)
				if OwnerEntity ~= nil then
					if Game.TeamSystem:IsTeamMember(OwnerEntity.eid) then
						if OwnerEntity:uid() ~= Game.me:uid() then
							if NiagaraEffectParam.bBenefitEffect then
								table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.TEAMMATE_POSITIVE)
								tagType = NIAGARA_EFFECT_TAG.TEAMMATE_POSITIVE
							else
								table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.TEAMMATE)
								tagType = NIAGARA_EFFECT_TAG.TEAMMATE
							end
						end
					else
						if OwnerEntity:uid() ~= Game.me:uid() then
							table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.NEUTRAL)
							tagType = NIAGARA_EFFECT_TAG.NEUTRAL
						end
					end
				end
			elseif Relation == Enum.ECampEnumData.Neutral and next(NiagaraEffectParam.EffectTags) == nil then
				table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.NEUTRAL)
				tagType = NIAGARA_EFFECT_TAG.NEUTRAL
			end
		elseif EffectTag == NIAGARA_EFFECT_TAG.BATTLE then
			if NiagaraEffectParam.SourceType == NIAGARA_SOURCE_TYPE.BATTLE then
				table.insert(NiagaraEffectParam.EffectTags, NIAGARA_EFFECT_TAG.BATTLE)
				tagType = NIAGARA_EFFECT_TAG.BATTLE
			end
		end

		if self.EffectTagToEffectIds[tagType] == nil then
			self.EffectTagToEffectIds[tagType] = {}
		end

		local EffectIds = self.EffectTagToEffectIds[tagType]
		EffectIds[EffectId] = true
	end
end

function EffectManager:UpdateNiagaraHiddenStateByEffectTag(EffectTag, bHidden, HiddenReason)
	if bHidden then
		local bIsCommonEffectTag = EffectManager.CommonEffectTags[EffectTag] ~= nil
		if bIsCommonEffectTag then
			local bOldIsHidden = self:IsEffectTagHidden(EffectTag)
			if not bOldIsHidden then
				self:BatchSetAllNiagaraEffectTag(EffectTag)
			end
		end

		if self.EffectTagHiddenState[EffectTag] == nil then
			self.EffectTagHiddenState[EffectTag] = {}
		end

		local CurHiddenReason = self.EffectTagHiddenState[EffectTag]
		if CurHiddenReason[HiddenReason] == true then
			return
		end
		
		CurHiddenReason[HiddenReason] = true
	else
		local CurHiddenReason = self.EffectTagHiddenState[EffectTag]
		if CurHiddenReason == nil then
			return
		end

		if CurHiddenReason[HiddenReason] == nil then
			return
		end

		CurHiddenReason[HiddenReason] = nil
	end 
	
	local EffectIds = self.EffectTagToEffectIds[EffectTag]
	if EffectIds == nil then
		return
	end

	for EffectId, _ in pairs(EffectIds) do
		self:UpdateNiagaraHiddenState(EffectId, bHidden, HiddenReason)
	end
end

--region NiagaraEffectTypeCheck

function EffectManager:SetEnableCheckNiagaraEffectType(bInCheckNiagaraEffectType)
	self.bDebugCheckNiagaraEffectType = bInCheckNiagaraEffectType
end

function EffectManager:IsCheckNiagaraEffectTypeEnabled()
	return self.bDebugCheckNiagaraEffectType
end

function EffectManager:PrintInvalidNiagara(Msg)
	if self.DebugMsgs == nil then
		self.DebugMsgs = {}
	end

	if self.DebugMsgs[Msg] ~= nil then
		return
	end

	self.DebugMsgs[Msg] = true
	Log.Warning(Msg)
end

function EffectManager:PrintUniquedNiagaraNum(NiagaraEffectPath)
	if self.UniqueNiagaraPaths == nil then
		self.UniqueNiagaraPaths = {}
		self.CurUniqueNiagaraNum = 0
	end

	if self.UniqueNiagaraPaths[NiagaraEffectPath] ~= nil then
		return
	end

	self.UniqueNiagaraPaths[NiagaraEffectPath] = true
	self.CurUniqueNiagaraNum = self.CurUniqueNiagaraNum + 1
	Log.Debug("[NiagaraNumCheck] Played ", self.CurUniqueNiagaraNum, " unique niagaras")
end

function EffectManager:GetNiagaraEffectType(NiagaraEffectParam, NiagaraComponent)
	local NiagaraSystem = NiagaraComponent:GetAsset()
	if NiagaraSystem == nil then
		return
	end

	local EffectType = NiagaraSystem.EffectType
	if EffectType == nil then
		local SkillIdInfo = NiagaraEffectParam.SourceSkillIdDebugUse ~= nil and "SkillId: " .. NiagaraEffectParam.SourceSkillIdDebugUse or "" 
		self:PrintInvalidNiagara(string.format(EffectManager.NiagaraEffectTypeMissingMsgFormat, SkillIdInfo, NiagaraEffectParam.NiagaraEffectPath))
		return
	end
	
	return EffectType:GetName()
end

function EffectManager:CheckNiagaraEffectType(NiagaraEffectParam, NiagaraComponent)
	--local SpawnerEntity = Game.EntityManager:getEntity(NiagaraEffectParam.SpawnerEntityId)
	self:PrintUniquedNiagaraNum(NiagaraEffectParam.NiagaraEffectPath)
	
	local SpawnerEntityId = NiagaraEffectParam.InstigatorEntityId ~= 0 and NiagaraEffectParam.InstigatorEntityId or NiagaraEffectParam.SpawnerEntityId
	local SpawnerEntity = Game.EntityManager:getEntity(SpawnerEntityId)
	if SpawnerEntity == nil then
		return
	end

	local EffectTypeName = self:GetNiagaraEffectType(NiagaraEffectParam, NiagaraComponent)
	if EffectTypeName == nil then
		return
	end
	
	local InstigatorEntity
	if SpawnerEntity.bIsAttachItem == true then
		InstigatorEntity = Game.EntityManager:getEntity(SpawnerEntity:GetAttachItemManagerEntity())
	else
		InstigatorEntity = BSFunc.GetActorInstigator(SpawnerEntity)
	end

	local EffectTypeThreshold
	if InstigatorEntity.ActorType == EWActorType.PLAYER then
		-- player
		EffectTypeThreshold = EffectManager.NiagaraEffectTypes.NET_Player

		if NiagaraEffectParam.SourceSkillIdDebugUse ~= nil then
			local SkillData = Game.TableData.GetSkillDataNewRow(NiagaraEffectParam.SourceSkillIdDebugUse)
			if SkillData then
				if SkillData.Type == AbilityConst.ESkillType.NormalAttack then
					EffectTypeThreshold = EffectManager.NiagaraEffectTypes.NET_Attack
				elseif SkillData.Type == AbilityConst.ESkillType.UltimateSkill then
					EffectTypeThreshold = EffectManager.NiagaraEffectTypes.NET_PlayerUltra
				end
			end
		end
		
	elseif InstigatorEntity.ActorType == EWActorType.NPC then
		if InstigatorEntity.BossType == Enum.EBossType.BOSS then
			-- boss
			EffectTypeThreshold = EffectManager.NiagaraEffectTypes.NET_Boss
		else
			-- monster
			EffectTypeThreshold = EffectManager.NiagaraEffectTypes.NET_Monster
		end
	end

	if EffectTypeThreshold ~= nil then
		local EffectType = EffectManager.NiagaraEffectTypes[EffectTypeName]
		if EffectType == nil or EffectType > EffectTypeThreshold then
			local SkillIdInfo = NiagaraEffectParam.SourceSkillIdDebugUse ~= nil and "SkillId: " .. NiagaraEffectParam.SourceSkillIdDebugUse or ""
			self:PrintInvalidNiagara(string.format(EffectManager.NiagaraEffectTypeInvalidUsageMsgFormat,
				SkillIdInfo, NiagaraEffectParam.NiagaraEffectPath, EffectTypeName, EffectManager.NiagaraEffectTypeNames[EffectTypeThreshold]))
		end
	end
end

--endregion NiagaraEffectTypeCheck

--endregion Niagara


--region Decal

-- return DecalUpdateWorkId
function EffectManager:RegisterDecalUpdateWork(DecalActor, OverrideParameters, StartTime, LifeTime)
    return self.cppMgr:RegisterDecalUpdateWork(DecalActor, OverrideParameters, StartTime, LifeTime)
end

function EffectManager:UnRegisterDecalUpdateWork(DecalUpdateWorkId)
    return self.cppMgr:UnRegisterDecalUpdateWork(DecalUpdateWorkId)
end

--endregion Decal

return EffectManager
