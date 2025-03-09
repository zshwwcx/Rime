UECompositeOperateLibClass = kg_require("Framework.C7Common.UECompositeOperateLib")

local ActorAppearanceManager = DefineClass("ActorAppearanceManager")

Enum.ActorAppearanceType = {
    Base = 0,
    Avatar = 1, --通用外观
    Avatar_B = 4, --B级通用外观
    Suit = 2, --套装
    AttachItem = 3 --挂接物
}

Enum.AvatarPresetLevel = {
    ["ROLE_CREATE"] = "ROLE_CREATE",
    ["S-High"] = "S",
    ["S-Mid"] = "S",
    ["S-Low"] = "S",
    ["A"] = "A",
    ["B"] = "B",
    ["Unset"] = "B"
}

Enum.UECompositePreLoadType = {
    Anim = 1,
    Skill = 2,
}

Enum.UECompositeStage = {
    None = 0,
    ConvertData = 1,
    CollectAssetPath = 2,
    Execute = 3,
}

Enum.ActorAppearanceModifyType = 
{
    Create = 1,
    Changed = 2,
    Destroy = 3,
}

Enum.AOPriority = {
    P_01 = 1,
    P_02 = 2,
    P_03 = 3,
    P_04 = 4,
    P_05 = 6,
    P_06 = 6,
    P_07 = 7,
    P_08 = 8,
}

WHOLE_LOGIC_BODY_PART_TYPE = 0

local function IsStringValid(Str)
    return Str and type(Str) == "string" and string.len(Str) > 0
end

ActorAppearanceDataMemoryAlloc = DefineClass("ActorAppearanceMemoryAlloc")

function ActorAppearanceDataMemoryAlloc:ctor()
    self.PoolSize = {} --{cls:SizeNum}
    self.FreeDataInsPools = {} --{cls:{FreeData}}
    self.UsedDataInsPools = {} --{cls:{UsedData}}
end

function ActorAppearanceDataMemoryAlloc:dtor()
    self:Reset()
end

function ActorAppearanceDataMemoryAlloc:Reset()
    self.PoolSize = nil
    self.DataInsPools = nil
    self.UsedDataInsPools = nil
end

function ActorAppearanceDataMemoryAlloc:GetFreeData(Cls)
    local _newData = nil

    local _FreePool = self.FreeDataInsPools[Cls]
    if _FreePool and #_FreePool > 0 then
        _newData = table.remove(_FreePool, 1)
    else
        _newData = Cls.new()
    end

    local _UsedPoos = self.UsedDataInsPools[Cls]
    if _UsedPoos == nil then
        _UsedPoos = {}
        self.UsedDataInsPools[Cls] = _UsedPoos
    end

    _UsedPoos[_newData] = _newData

    return _newData
end

function ActorAppearanceDataMemoryAlloc:ReleaseData(InData)
    local _UsedPool = self.UsedDataInsPools[InData.class]
    if _UsedPool == nil then
        Log.ErrorFormat("ActorAppearanceDataMemoryAlloc _UsedPool class %s", InData.__cname)
        return
    end

    local _UsedData = _UsedPool[InData]
    if _UsedData == nil then
        Log.ErrorFormat("ActorAppearanceDataMemoryAlloc _UsedData class %s", InData.__cname)
        return
    end

    local _PoolSize = self.PoolSize[InData.class]
    if _PoolSize == nil then
        Log.ErrorFormat("ActorAppearanceDataMemoryAlloc _PoolSize class %s", InData.__cname)
        return
    end

    local _FreePool = self.FreeDataInsPools[InData.class]
    if _FreePool == nil then
        _FreePool = {}
        self.FreeDataInsPools[InData.class] = _FreePool
    end

    if #_FreePool < _PoolSize then

        CallEntityCtorFunc(_UsedData, _UsedData.class)

        table.insert(_FreePool, _UsedData)
    end

    _UsedPool[InData] = nil
end

function ActorAppearanceDataMemoryAlloc:AssignPoolSize(Cls, InPoolSize)
    self.PoolSize[Cls] = InPoolSize
end


UECompositeParamsV3 = DefineClass("UECompositeParamsV3")
function UECompositeParamsV3:ctor()
    
    self.CompositeType = Enum.EUECompositeType.Appearance --拼装类型

    --Model
    self.ModelID = nil --模型ID 根据CompositeType 来确定数据来源
	self.OverrideBodyparts = nil
	self.OverrideHeadMakeupData = nil -- 现在这部分, 目前应该是只包含了头部；设计是一个序列化的字符串, 解析的使用C++做
	self.OverrideBodyshapeCompactData = nil-- 从捏脸来的骨骼数据, 包括脸、身体
	self.OverrideFaceAndBodyShapePresetModelID = nil -- 捏脸会有一个妆容、骨骼的预设ID

    --TA
    self.LightChannels = nil --受光通道设置

    --Anim
    self.AnimAssetID = nil  --动画库ID
    self.AnimAssetOverride = nil --初始动画覆盖
    
    --Face
    self.FaceModelData = nil --动态的捏脸数据
    
    --Modify
    self.InitModelMaterialID = nil --出生时覆盖的材质，索引ModelMaterialData

    self.FacadeScaleValue = nil  --整体缩放

    self.UID = nil  --唯一ID 标记

    --Callback
    self.CompositeCallFunc = nil --完成函数回调 用全局函数 --正常拼装不需要赋值
    
    --OP
    self.bEnableMeshOptimization = true
    
    -- ViewBudget能力标识
    self.ViewDownGradingBudgetFlags = 0

    --预加载 PreLoadType Enum.UECompositePreLoadType
    self.PreLoadMap = nil --{PreLoadType:{"PathXXX","PathXXX"}}
end

function UECompositeParamsV3:id()
end

function UECompositeParamsV3:SetAppearanceData(modelId, overrideBodyparts, overrideFaceAndBodyShapePresetModelID, overrideHeadMakeupData, overrideBodyshapeCompactData)
	self.ModelID = modelId
	self.OverrideFaceAndBodyShapePresetModelID = overrideFaceAndBodyShapePresetModelID
	self.OverrideBodyparts = overrideBodyparts 
	self.OverrideHeadMakeupData = overrideHeadMakeupData  -- 现在这部分, 目前应该是只包含了头部； 且全身的材质参数是全局唯一的； 如果后面要改成每个part的材质参数允许重复, 这里对应逻辑要审一下
	self.OverrideBodyshapeCompactData =overrideBodyshapeCompactData  -- 从捏脸来的骨骼数据, 包括脸、身体
end

function UECompositeParamsV3:SetAppearanceHeadOverrideData(overrideHeadMakeupData)
	self.OverrideHeadMakeupData = overrideHeadMakeupData  
end


function UECompositeParamsV3:GetFreeData()
    if self.class ~= nil then
        Log.ErrorFormat("UECompositeParamsV3 class %s", self.__cname)
        return nil
    end
    return UECompositeParamsV3.MemoryAlloc:GetFreeData(self)
end

function UECompositeParamsV3:ReleaseData()
    return UECompositeParamsV3.MemoryAlloc:ReleaseData(self)
end

ActorAppearanceDataBase = DefineClass("ActorAppearanceDataBase")
function ActorAppearanceDataBase:ctor()
    self.PartType = 0
    self.bMarkDirty = false

    self.ModifyType = Enum.ActorAppearanceModifyType.Create

    --模型状态描述数据
	if self.ModelLibData ~= nil then
		table.clear(self.ModelLibData)
	else
		self.ModelLibData = {}
	end

    --关联组件修改数据
	if self.ComOperateDatas ~= nil then
		table.clear(self.ComOperateDatas)
	else
		self.ComOperateDatas = {}
	end
end

function ActorAppearanceDataBase:id()
end

--修改数据
function ActorAppearanceDataBase:ModifyData()
    
    --修改对比有差异, 标脏 转换数据
    --bMarkDirty = true

    --OnConvertData()
end

-- InPriority Enum.AOPriority
function ActorAppearanceDataBase:GetOperateData(InPriority)
    return self.ComOperateDatas[InPriority]
end

function ActorAppearanceDataBase:UpdateOperateData(InPriority, OperateData)
    self.ComOperateDatas[InPriority] = OperateData
end

function ActorAppearanceDataBase:RemoveOperateData(InPriority)
    local OpData = self.ComOperateDatas[InPriority]
    if OpData then
        OpData:ReleaseData()
    end
end

function ActorAppearanceDataBase:ClearOperateDatas()
    for _, OpData in pairs(self.ComOperateDatas) do
        OpData:ReleaseData()
    end
    self.ComOperateDatas = {}
end

--模型编辑器数据未优化完毕, 需要转换
function ActorAppearanceDataBase:OnConvertData()
    
end

function ActorAppearanceDataBase:GetFreeData()
    if self.class ~= nil then
        Log.ErrorFormat("ActorAppearanceDataBase class %s", self.__cname)
        return nil
    end
    return ActorAppearanceDataBase.MemoryAlloc:GetFreeData(self)
end

function ActorAppearanceDataBase:ReleaseData()
    return ActorAppearanceDataBase.MemoryAlloc:ReleaseData(self)
end

--模型身体数据
ActorAppearance_PartData_Body = DefineClass("ActorAppearance_PartData_Body", ActorAppearanceDataBase)
function ActorAppearance_PartData_Body:ctor()
    self.PartType = 0
    --模型状态描述数据
    --self.ModelLibData = {} --{ModelID:"xxx",UID:xxx} 

    --关联组件修改数据
    --self.ComOperateDatas = {} --{OperateType:{Data1, Data2}}
end

--PartType Enum.EAvatarBodyPartType
function ActorAppearance_PartData_Body:ModifyData(ModelID, UID)
    if self.ModelLibData.ModelID ~= ModelID then
        self.ModelLibData.ModelID = ModelID
        self.ModelLibData.UID = UID
        self.bMarkDirty = true
    end
end

function ActorAppearance_PartData_Body:OnConvertData(OpGroup, OwnerActorID)
    local ModelData, MakeupData, BodyPartList, ProfileName = Game.RoleCompositeMgr:GetModelLibData(self.ModelLibData.ModelID)
    if ModelData == nil then
        self:ClearOperateDatas()
        return
    end

    --胶囊体
    if ModelData.Capsule then
        local CapsuleOP = OpGroup:GetOperate(Enum.UECompositeTypeV2.Capsule)
        local CapsuleOPData = self:GetOperateData(Enum.AOPriority.P_01)
        CapsuleOPData = CapsuleOP:GetData(CapsuleOPData)
    
        CapsuleOPData.OwnerActorID = OwnerActorID
        CapsuleOPData.CapsuleHalfHeight = ModelData.Capsule.CapsuleHalfHeight
        CapsuleOPData.CapsuleRadius = ModelData.Capsule.CapsuleRadius
    
        self:UpdateOperateData(Enum.AOPriority.P_01, CapsuleOPData)
    end

    --受击盒
    if ModelData.HitBox and ModelData.HitBox.bUseHitBox == true then
        local HitBoxOP = OpGroup:GetOperate(Enum.UECompositeTypeV2.HitBox)
        local HitBoxOPData = self:GetOperateData(Enum.AOPriority.P_02)
        HitBoxOPData = HitBoxOP:GetData(HitBoxOPData)
        
        HitBoxOPData.OwnerActorID = OwnerActorID
        HitBoxOPData.BoxExtent = ModelData.HitBox.BoxExtent
        HitBoxOPData.Offset = ModelData.HitBox.Offset
        HitBoxOPData.ParentSocket = ModelData.HitBox.ParentSocket
    
        self:UpdateOperateData(Enum.AOPriority.P_02, HitBoxOPData)
    end

    --特效
    if ModelData.Effect and #ModelData.Effect > 0 then
        local EffectOP = OpGroup:GetOperate(Enum.UECompositeTypeV2.Effect)
        local EffectOPData = self:GetOperateData(Enum.AOPriority.P_03)
        EffectOPData = EffectOP:GetData(EffectOPData)
        
        EffectOPData.UID = self.ModelLibData.UID
        EffectOPData.OwnerActorID = OwnerActorID
        EffectOPData.EffectDatas = ModelData.Effect
    
        self:UpdateOperateData(Enum.AOPriority.P_03, EffectOPData)
    end
end

--模型部件数据
ActorAppearance_PartData_Model = DefineClass("ActorAppearance_PartData_Model", ActorAppearanceDataBase)
function ActorAppearance_PartData_Model:ctor()
    --self.PartType = 0 --Enum.EAvatarBodyPartType
    
    --模型状态描述数据
    --self.ModelLibData = {} --{ModelID:"xxx", PartID:"xxx", PartMakeupID:xxx} 

    --关联组件修改数据
    --self.ComOperateDatas = {} --{OperateType1:{Data1, Data2},OperateType2:{Data1, Data2},OperateType3:{Data1, Data2}}
	self.OverrideFaceAndBodyShapePresetModelID = nil
	self.OverrideBodyPartMakeupData = nil
	self.OverrideBodyShapeCompactData = nil
end

--PartType Enum.EAvatarBodyPartType
function ActorAppearance_PartData_Model:ModifyData(UID, PartType, ModelID, BodyPartType, PartData, PartID, PartMakeupID, InitModelMaterialID, AnimConfigID, AnimAssetOverridePathMap)
	self.PartType = PartType
	self.bMarkDirty = true

	self.ModelLibData.ModelID = ModelID
	self.ModelLibData.UID = UID
	self.ModelLibData.BodyPartType = BodyPartType
	self.ModelLibData.PartData = PartData

	self.ModelLibData.PartID = PartID
	self.ModelLibData.InitModelMaterialID = InitModelMaterialID
	self.ModelLibData.PartMakeupID = PartMakeupID

	self.ModelLibData.AnimConfigID = AnimConfigID
	self.ModelLibData.AnimAssetOverridePathMap = AnimAssetOverridePathMap
end

function ActorAppearance_PartData_Model:InitModifyBodyPartOverrideData(overrideFaceAndBodyShapePresetModelID, OverrideBodyPartMakeupData, overrideBodyShapeCompactData)
	if overrideFaceAndBodyShapePresetModelID ~= nil then
		self.OverrideFaceAndBodyShapePresetModelID = overrideFaceAndBodyShapePresetModelID
		self.bMarkDirty = true
	end

	if OverrideBodyPartMakeupData ~= nil then
		self.OverrideBodyPartMakeupData = OverrideBodyPartMakeupData
		self.bMarkDirty = true
	end

	if overrideBodyShapeCompactData ~= nil then
		self.OverrideBodyShapeCompactData = overrideBodyShapeCompactData
		self.bMarkDirty = true
	end

end


function ActorAppearance_PartData_Model:OnConvertData(OpGroup, OwnerActorID, bEnableMeshOptimization, LightChannels, UEActorType)
	
	local curRoleCompositeMgr = Game.RoleCompositeMgr
	local ModelData, _, _, ProfileName = curRoleCompositeMgr:GetModelLibData(self.ModelLibData.ModelID)
    local PartLibMakeupData = curRoleCompositeMgr.AvatarModelPartLib.MakeupDataV2
   
    local ProfileLib = curRoleCompositeMgr.AvatarProfileLib[ProfileName]
    local PartDataLib = curRoleCompositeMgr.AvatarModelPartLib[ProfileName]
   

    local BodyPartList_PartData = self.ModelLibData.PartData

	local SKData = self:GetOperateData(Enum.AOPriority.P_01)
	--Mesh
	local SKMeshOP = OpGroup:GetOperate(Enum.UECompositeTypeV2.SkeletalMeshCom)

	SKData = SKMeshOP:GetData(SKData)

	SKData.UID = self.ModelLibData.UID
	SKData.OwnerActorID = OwnerActorID
	local _ModelPartData = PartDataLib[self.ModelLibData.PartID]

	if  self.ModelLibData.BodyPartType == Enum.EAvatarBodyPartType.Head then
		-- 有预设, 就从预设拿
		local faceCompactData, bodyCompactData = curRoleCompositeMgr:GetFaceAndBodyshapeCompactData(self.OverrideFaceAndBodyShapePresetModelID or self.ModelLibData.ModelID)
		local isNpcSuit =  curRoleCompositeMgr:IsNpcSuitAppearance(self.ModelLibData.ModelID)
		if isNpcSuit then
			-- NPC的头部能够引用其他现成的头部部件, 这个是NPC拼装的一个编辑器规则; @倪铁 如果数据展开, 这里也可以不用用了
			if IsStringValid(_ModelPartData.FacePresetMeshID) then
				_ModelPartData = PartDataLib[_ModelPartData.FacePresetMeshID]
			end
		end
		
		--预设体型 + 编辑的override数据
		if faceCompactData ~= nil or bodyCompactData ~= nil or self.OverrideBodyShapeCompactData ~= nil then
			local BodyShapeOP = OpGroup:GetOperate(Enum.UECompositeTypeV2.BodyShape)
			local BodyShapeData = self:GetOperateData(Enum.AOPriority.P_04)
			BodyShapeData = BodyShapeOP:GetData(BodyShapeData)
			BodyShapeData.OwnerActorID = OwnerActorID
			BodyShapeData.ProfileName = ProfileName
			BodyShapeData.FaceCompactData = faceCompactData
			BodyShapeData.BodyCompactData = bodyCompactData
			BodyShapeData.OverrideAllBodyShapeData = self.OverrideBodyShapeCompactData
			self:UpdateOperateData(Enum.AOPriority.P_04, BodyShapeData)
		end
		
	end

    if self.ModelLibData.BodyPartType == Enum.EAvatarBodyPartType.BodyUpper then
        SKData.Tag = Enum.UECompositeComTagV2.Mesh

        SKData.Offset = ModelData.SKMesh.Offset
		
		-- todo 这里导出数据没有男女数据, 现在都是走的默认女性的配置 @sunya 
        if ModelData.Sex == Enum.ERoleCompositeSex.Man then
            SKData.CapsuleShadow_AssetID = Game.RoleCompositeMgr.CapsuleShadow_ManAssetID
        else
            SKData.CapsuleShadow_AssetID = Game.RoleCompositeMgr.CapsuleShadow_WomanAssetID
        end
    else
        SKData.Tag = Enum.EAvatarBodyPartTypeName[self.ModelLibData.BodyPartType]

        SKData.AttachTargetTag = Enum.UECompositeComTagV2.Mesh
        SKData.LeaderPoseComTag = Enum.UECompositeComTagV2.Mesh
		
		-- 耳环之类的part, 玩家在捏的时候, 可以有offset
		-- 编辑器预设数据里面导出内容是没有的
        SKData.Offset = BodyPartList_PartData.Offset and BodyPartList_PartData.Offset * _ModelPartData.Offset or _ModelPartData.Offset
    end

    SKData.SkeletalMesh = _ModelPartData.SkeletalMeshPath
    SKData.DecorationComponents = _ModelPartData.DecorationComponents
	-- todo 这个瑞林要确认是否还有 @sunya 
	SKData.OverrideMaterials = _ModelPartData.OverrideMaterials -- Mesh在不同材质下复用
	SKData.MaterialFollowerTags = _ModelPartData.MaterialFollowerTags -- Part材质跟随

    if _ModelPartData.AttachType == Enum.EDressType.AttachToSocket then
        local SocketName = ""
		-- 这里只是导出问题, 理论上最多只有一个值
        if _ModelPartData.SocketNameList[1] then
            SocketName = _ModelPartData.SocketNameList[1]
        end
		-- 如果part是外面传入的, 则外部数据会写入SocketName
        if BodyPartList_PartData.SocketName then
            SocketName = BodyPartList_PartData.SocketName
        end
        SKData.SocketName = SocketName
        SKData.LeaderPoseComTag = nil
    end

    SKData.bReceivesDecals = ModelData.bReceivesDecals or false
    SKData.bVisibility = true

    SKData.bRenderCustomDepthPass = ModelData.bRenderCustomDepthPass or false
    SKData.MaterialOverlay = ModelData.MaterialOverlay

    --OP
    SKData.bEnableMeshOptimization = bEnableMeshOptimization
 
    --TA
    SKData.LightChannels = LightChannels

    self:UpdateOperateData(Enum.AOPriority.P_01, SKData)
	
	local IsNpcSuitAppearance = IsStringValid(ModelData.NPCSuit)
    --妆容
	-- todo 这里之前腾飞说过, 如果有捏脸数据, 如果某些部件是要露肤色出来, 肤色要跟着脸部的makeup数据走的 @胡江龙
    if self.ModelLibData.PartMakeupID or IsNpcSuitAppearance then
        local MaterialOP = OpGroup:GetOperate(Enum.UECompositeTypeV2.Material)
        local MaterialData = self:GetOperateData(Enum.AOPriority.P_02)
        MaterialData = MaterialOP:GetData(MaterialData)

        MaterialData.OwnerActorID = OwnerActorID
        MaterialData.UID = self.ModelLibData.UID
		
		-- todo 如果会使用Tag来打唯一标识符, 例如SkeletalCom上的ComponentTag， 之前没有处理BodyPartType可能存在复数个实例, 就会打重复tag, 这里就会有内容设置潜在错误 @sunya 
        MaterialData.Tag = Enum.EAvatarBodyPartTypeName[_ModelPartData.BodyPartType]
        
		-- 基础part的材质数据, NPCSuit和AvatarPreset中的BodyPart都可能会有
		-- 对于AvatarPreset 如果有MakeupID就使用
		-- 对于NpcSuit, 如果有MakeupID就使用, 没有就使用B级Npc里的染色数据  (NPC除了头可能MakeupID, 其他一定不会有MakeupID)
		if self.ModelLibData.PartMakeupID then
			MaterialData.MeshMaterialData = PartLibMakeupData[self.ModelLibData.PartMakeupID]
		else
			-- 这里逻辑是只处理NPC
			-- 设计上是不允许NPC来染头的
			if _ModelPartData.BodyPartType ~= Enum.EAvatarBodyPartType.Head then
				local NPCSuitLibMakeupData = curRoleCompositeMgr.NPCSuitLibMakeupData
				-- NPC 复用了捏脸的材质参数, 这个是可以Override上面的基础MakeupID中的数据
				if IsNpcSuitAppearance and NPCSuitLibMakeupData.OtherPartAndSlots then
					local _SuitMakeupData = NPCSuitLibMakeupData.OtherPartAndSlots[ModelData.NPCSuit]
					if _SuitMakeupData and _SuitMakeupData.CompositeOtherPartAndSlotsDataMap and MaterialData.Tag then
						MaterialData.MeshMaterialData = _SuitMakeupData.CompositeOtherPartAndSlotsDataMap:Get(MaterialData.Tag)
					end
				end
			end
		end

        MaterialData.MakeupProfileName = ProfileName
        if Enum.EAvatarBodyPartType.Head == _ModelPartData.BodyPartType then
			local CaptureData = Game.RoleCompositeMgr.AvatarModelPartLib.CaptureData
			-- 玩家捏妆容的时候, 部分效果是会直接生成脸部对应的贴图
            MaterialData.MakeupCaptureMaterials = ProfileLib.MakeupCaptureMaterials --RT
            MaterialData.CaptureMaterialData = CaptureData[self.ModelLibData.PartMakeupID]
        end
		
		-- 这里应该是业务逻辑: 灵体逻辑
		-- todo 这个业务逻辑要往外拆  @sunya
        if self.ModelLibData.InitModelMaterialID then
            local InitMaterialData = Game.TableData.GetModelMaterialDataRow(self.ModelLibData.InitModelMaterialID)
            if InitMaterialData then
                MaterialData.MainMaterialPath = InitMaterialData.MainMaterial
                MaterialData.EyeLashMaterialPath = InitMaterialData.EyeLashMaterial
            end
        end

		if self.OverrideBodyPartMakeupData ~= nil then
			MaterialData.OverrideBodyPartMakeupData = self.OverrideBodyPartMakeupData
		end
		

        self:UpdateOperateData(Enum.AOPriority.P_02, MaterialData)
    end

    --动画
    if self.ModelLibData.AnimConfigID or self.ModelLibData.AnimAssetOverridePathMap then
        local AnimOP = OpGroup:GetOperate(Enum.UECompositeTypeV2.Anim)
        local AnimData = self:GetOperateData(Enum.AOPriority.P_03)
        AnimData = AnimOP:GetData(AnimData)
        
        AnimData.UID = self.ModelLibData.UID
        AnimData.OwnerActorID = OwnerActorID
        AnimData.Tag = Enum.EAvatarBodyPartTypeName[_ModelPartData.BodyPartType]
        AnimData.AnimConfigID = self.ModelLibData.AnimConfigID
        if ModelData.AnimData then
            -- todo 为了区分P1/P3进行临时处理 @sunya 20240810
            if UEActorType == Enum.EUEActorType.AoiPlayer and ModelData.AnimData.AnimClass == "/Game/Blueprint/3C/Animation/AnimPublic/Player/ABP_Player_R4.ABP_Player_R4_C" then
                AnimData.AnimClassPath = "/Game/Blueprint/3C/Animation/AnimPublic/Player/ABP_AOI_Player_R4.ABP_AOI_Player_R4_C"
            else
                AnimData.AnimClassPath = ModelData.AnimData.AnimClass
            end
        else
            AnimData.AnimClassPath = nil
        end
        
        AnimData.AnimAssetOverridePathMap = self.ModelLibData.AnimAssetOverridePathMap
        
        self:UpdateOperateData(Enum.AOPriority.P_03, AnimData)
    end


end

-- 下面这个AOPriority有点坑, 每个BodyPart不一样的时候, 这个语义可能是不一样的
function ActorAppearance_PartData_Model:GetOperateMaterialData()
	return self.ComOperateDatas[Enum.AOPriority.P_02]
end

function ActorAppearance_PartData_Model:GetOperateBodyShapeData()
	return self.ComOperateDatas[Enum.AOPriority.P_04]
end

--模型自定义部件数据
ActorAppearance_PartData_MeshCustom = DefineClass("ActorAppearance_PartData_MeshCustom", ActorAppearanceDataBase)
function ActorAppearance_PartData_MeshCustom:ctor()
    --self.PartType = 0 --Enum.EAvatarBodyPartType
    
    --模型状态描述数据
    --self.ModelLibData = {} --{ModelID:"XXX"}

    --关联组件修改数据
    --self.ComOperateDatas = {} --{OperateType1:{Data1, Data2},OperateType2:{Data1, Data2},OperateType3:{Data1, Data2}}
end

--PartType Enum.EAvatarBodyPartType
function ActorAppearance_PartData_MeshCustom:ModifyData(PartType, UID, ModelID, AnimConfigID, AnimAssetOverridePathMap)
    if self.PartType ~= PartType then
        self.PartType = PartType
        self.bMarkDirty = true
    end

    if self.ModelLibData.ModelID ~= ModelID then
        self.ModelLibData.ModelID = ModelID
        self.ModelLibData.UID = UID
        self.bMarkDirty = true
    end

    if self.ModelLibData.AnimConfigID ~= AnimConfigID then
        self.ModelLibData.AnimConfigID = AnimConfigID
        self.bMarkDirty = true
    end

    if self.ModelLibData.AnimAssetOverridePathMap ~= AnimAssetOverridePathMap then
        self.ModelLibData.AnimAssetOverridePathMap = AnimAssetOverridePathMap
        self.bMarkDirty = true
    end
end

--模型编辑器数据未优化完毕, 需要转换
function ActorAppearance_PartData_MeshCustom:OnConvertData(OpGroup, OwnerActorID, bEnableMeshOptimization, LightChannels, UEActorType)
    local ModelData = Game.RoleCompositeMgr:GetModelLibData(self.ModelLibData.ModelID)
    if ModelData == nil then
        self:ClearOperateDatas()
        return
    end

    local SKMeshCP = OpGroup:GetOperate(Enum.UECompositeTypeV2.SkeletalMeshCom)
    local SKData = self:GetOperateData(Enum.AOPriority.P_01)
    SKData = SKMeshCP:GetData(SKData)

    SKData.UID = self.ModelLibData.UID
    SKData.OwnerActorID = OwnerActorID
    SKData.Tag = Enum.UECompositeComTag.Mesh

    SKData.SkeletalMesh = ModelData.SKMesh.SkeletalMesh
    SKData.Offset = ModelData.SKMesh.Offset

    if ModelData.Sex == Enum.ERoleCompositeSex.Man then
        SKData.CapsuleShadow_AssetID = self.CapsuleShadow_ManAssetID
    else
        SKData.CapsuleShadow_AssetID = self.CapsuleShadow_WomanAssetID
    end

    SKData.bReceivesDecals = ModelData.bReceivesDecals or false
    SKData.bVisibility = true

    SKData.bRenderCustomDepthPass = ModelData.bRenderCustomDepthPass or false
    SKData.MaterialOverlay = ModelData.MaterialOverlay

    --OP
    SKData.bEnableMeshOptimization = bEnableMeshOptimization

    --TA
    SKData.LightChannels = LightChannels

    self:UpdateOperateData(Enum.AOPriority.P_01, SKData)

    --动画
    if self.ModelLibData.AnimConfigID or self.ModelLibData.AnimAssetOverridePathMap then
        local AnimOP = OpGroup:GetOperate(Enum.UECompositeTypeV2.Anim)
        local AnimData = self:GetOperateData(Enum.AOPriority.P_03)
        AnimData = AnimOP:GetData(AnimData)
        
        AnimData.UID = self.ModelLibData.UID
        AnimData.OwnerActorID = OwnerActorID
        AnimData.Tag = Enum.UECompositeComTag.Mesh
        AnimData.AnimConfigID = self.ModelLibData.AnimConfigID
        if ModelData.AnimData then
            -- todo 为了区分P1/P3进行临时处理 @sunya 20240810
            if UEActorType == Enum.EUEActorType.AoiPlayer and ModelData.AnimData.AnimClass == "/Game/Blueprint/3C/Animation/AnimPublic/Player/ABP_Player_R4.ABP_Player_R4_C" then
                AnimData.AnimClassPath = "/Game/Blueprint/3C/Animation/AnimPublic/Player/ABP_AOI_Player_R4.ABP_AOI_Player_R4_C"
            else
                AnimData.AnimClassPath = ModelData.AnimData.AnimClass
            end
        else
            AnimData.AnimClassPath = nil
        end
        
        AnimData.AnimAssetOverridePathMap = self.ModelLibData.AnimAssetOverridePathMap
        
        self:UpdateOperateData(Enum.AOPriority.P_03, AnimData)
    end
end

--角色外观状态数据
ActorAppearance_AvatarData = DefineClass("ActorAppearance_AvatarData", ActorAppearanceDataBase)
ActorAppearance_AvatarData.AppearanceDataType = Enum.ActorAppearanceType.Avatar
function ActorAppearance_AvatarData:ctor()
    --外观处理阶段
    self.Stage = Enum.UECompositeStage.None

    self.UID = 0
    self.OwnerActorID = 0
	self.BaseModelID = nil
    self.bEnableMeshOptimization = true
    self.LightChannels = nil
    self.UEActorType = nil

    --使用的操作组
    self.OpGroup = nil

    --部件数据
    self.PartDataMap = {} --{PartType:ActorAppearanceDataBase}

    --搜集的外观资源
    self.CurrentLoadAssetPaths = nil
	self.IsNeedResetRegisterAsset = nil
    --当前加载完成情况列表
    self.LoadIDMap = {} --{LoadID:false}
	

--写入上下文
    --
    self.CompositeCallFunc = nil
    --Enum.UECompositePreLoadType
    self.PreLoadContext = nil -- {Request:{PreLoadType:{"PathXXX","PathXXX"}, Result:{Loading:{LoadID:PreLoadType}}, Loaded:{PreLoadType:LoadID}}
end

function ActorAppearance_AvatarData:PrepareForLoadAssets(isNeedResetRegisterAssets)
	-- 数据太多, 直接用新的
	self.CurrentLoadAssetPaths = {}
	self.IsNeedResetRegisterAsset = isNeedResetRegisterAssets
end

function ActorAppearance_AvatarData:RegisterAssetsToRoleCompositeMgr(Assets)

	if self.CurrentLoadAssetPaths and Assets then
		if Assets.Num == nil then
			Game.RoleCompositeMgr:AddActorAppearanceAssetRef(self.UID, self.CurrentLoadAssetPaths, {Assets}, self.IsNeedResetRegisterAsset)
		else
			Game.RoleCompositeMgr:AddActorAppearanceAssetRef(self.UID, self.CurrentLoadAssetPaths, Assets, self.IsNeedResetRegisterAsset)
		end
	end
	
	self.CurrentLoadAssetPaths = nil
	self.IsNeedResetRegisterAsset = nil
end

function ActorAppearance_AvatarData:ReleaseData()
    --释放所有部件数据到各自池
    for k, _PartData in pairs(self.PartDataMap) do
        _PartData:ReleaseData()

        self.PartDataMap[k] = nil
    end

    self.super.ReleaseData(self)
end

--PartCls ActorAppearance_PartData_Body ActorAppearance_PartData_Model ActorAppearance_PartData_MeshCustom
--InPartType Enum.EAvatarBodyPartType
function ActorAppearance_AvatarData:GetPartData(PartCls, InPartType, ForceNeedNewData)
    local _PartData = self.PartDataMap[InPartType]
    if ForceNeedNewData == false and _PartData and _PartData.class == PartCls then
        return _PartData
    end

    if _PartData ~= nil then
        _PartData:ReleaseData()
    end

    local _NewPartData = PartCls:GetFreeData()
    _NewPartData.PartType = InPartType

    self.PartDataMap[InPartType] = _NewPartData

    return _NewPartData
end

function ActorAppearance_AvatarData:GetExistPartData(BodyPartType) 
	return self.PartDataMap[BodyPartType]
end

function ActorAppearance_AvatarData:OnConvertData(OpGroup, OwnerActorID, bEnableMeshOptimization, LightChannels, UEActorType)
    self.Stage = Enum.UECompositeStage.ConvertData
    for k, PartData in pairs(self.PartDataMap) do
        if PartData.bMarkDirty then
            PartData:OnConvertData(OpGroup, OwnerActorID, bEnableMeshOptimization, LightChannels, UEActorType)
        end
    end
end

function ActorAppearance_AvatarData:CollectAssetPath(OpGroup, OutPaths)
    self.Stage = Enum.UECompositeStage.CollectAssetPath
    for k, PartData in pairs(self.PartDataMap) do
        if PartData.bMarkDirty then
            for k, OperateData in pairs(PartData.ComOperateDatas) do
                local Op = OpGroup:GetOperate(OperateData:GetUECompositeType())
                Op:CollectAssetPath(OperateData, OutPaths)
            end
        end
    end
end

--修改部件数据
function ActorAppearance_AvatarData:ModifyPart(PartType, PartData)

end

--移除部件
function ActorAppearance_AvatarData:MarkRemovePart(PartType)
    local _PartData = self.PartDataMap[PartType]
    if _PartData then
        _PartData.bMarkDirty = true
        _PartData.ModifyType = Enum.ActorAppearanceModifyType.Destroy
    end
end


function ActorAppearance_AvatarData:MarkRemoveAllPart()
    for k, _PartData in pairs(self.PartDataMap) do
        _PartData.bMarkDirty = true
        _PartData.ModifyType = Enum.ActorAppearanceModifyType.Destroy
    end
end

function ActorAppearance_AvatarData:IsExecuteDone()
	return self.Stage == Enum.UECompositeStage.Execute
end

ActorAppearanceOperateGroupBase = DefineClass("ActorAppearanceOperateGroupBase")
ActorAppearanceOperateGroupBase.GroupType = Enum.ActorAppearanceType.Base
ActorAppearanceOperateGroupBase.ActorAppearanceDataCls = nil
function ActorAppearanceOperateGroupBase:ctor()
    self.OperateMap = {}
end

function ActorAppearanceOperateGroupBase:dtor()
    self.OperateMap = nil
end

-- InOperateType Enum.UECompositeTypeV2
function ActorAppearanceOperateGroupBase:GetOperate(InOperateType)
    return self.OperateMap[InOperateType]
end

function ActorAppearanceOperateGroupBase:RegisterOperate(InOperateType)
    local Operate = Game.ActorAppearanceManager:GetOperateByType(InOperateType)
    if Operate then
        self.OperateMap[InOperateType] = Operate
    end
    
    return Operate
end

--模型编辑器数据未优化完毕, 需要转换
function ActorAppearanceOperateGroupBase:ConvertData(InModelData)
    
end

--收集资源
function ActorAppearanceOperateGroupBase:CollectAssetPath(OutPaths)
    
end

--执行修改
function ActorAppearanceOperateGroupBase:Execute(InData)

end

--模型库描述的通用外观(主角,第三方玩家,Npc,UI展示,本地Npc)
AAOG_Avatar = DefineClass("AAOG_Avatar", ActorAppearanceOperateGroupBase)
AAOG_Avatar.ActorAppearanceDataCls = ActorAppearance_AvatarData
AAOG_Avatar.GroupType = Enum.ActorAppearanceType.Avatar

function AAOG_Avatar:ctor()

    self.ActorUIDRef = {}
	self.ActorLoadAllAssetMapping = {}

    --注册通用外观所需的操作单元
    local SKCompositeOperate = self:RegisterOperate(Enum.UECompositeTypeV2.SkeletalMeshCom)
    --特定组件公用参数 调整
    --SKCompositeOperate.Level = 2

    self:RegisterOperate(Enum.UECompositeTypeV2.Anim)

    self:RegisterOperate(Enum.UECompositeTypeV2.Material)

    self:RegisterOperate(Enum.UECompositeTypeV2.Capsule)
    self:RegisterOperate(Enum.UECompositeTypeV2.HitBox)
    self:RegisterOperate(Enum.UECompositeTypeV2.BodyShape)
    self:RegisterOperate(Enum.UECompositeTypeV2.Effect)
end


local TempAllBodyparts = {}
local TempForbiddenPartsByConflictRule = {}

--模型编辑器数据未优化完毕需要转换
function AAOG_Avatar:ConvertData(AvatarData, OwnerActorID, InUECompositeParams)
    if AvatarData == nil then
        AvatarData = ActorAppearance_AvatarData:GetFreeData()
    else
        AvatarData:MarkRemoveAllPart()
    end

    AvatarData.UID = InUECompositeParams.UID
    AvatarData.OwnerActorID = OwnerActorID
    AvatarData.CompositeCallFunc = InUECompositeParams.CompositeCallFunc
	AvatarData.BaseModelID = InUECompositeParams.ModelID
	AvatarData.UEActorType = InUECompositeParams.UEActorType

    if InUECompositeParams.PreLoadMap then
        AvatarData.PreLoadContext = {}
        AvatarData.PreLoadContext.Request = InUECompositeParams.PreLoadMap
    end

    --临时 后续戴唯调整初始默认值, 这边不再进行二次处理
    if InUECompositeParams.LightChannels then
        local _LightChannels = {}
        if InUECompositeParams.LightChannels[0] == nil then
            table.insert(_LightChannels, false)
        else
            table.insert(_LightChannels, InUECompositeParams.LightChannels[0])
        end
        if InUECompositeParams.LightChannels[1] == nil then
            table.insert(_LightChannels, false)
        else
            table.insert(_LightChannels, InUECompositeParams.LightChannels[1])
        end
        if InUECompositeParams.LightChannels[2] == nil then
            table.insert(_LightChannels, false)
        else
            table.insert(_LightChannels, InUECompositeParams.LightChannels[2])
        end

        InUECompositeParams.LightChannels = _LightChannels
		AvatarData.LightChannels = _LightChannels
    end

    local ModelData, ModelData_MakeupData, ModelData_BodyPartList, ModelData_ProfileName, AvatarPresetLevel = Game.RoleCompositeMgr:GetModelLibData(AvatarData.BaseModelID)
    
    -- 头部LOD设置功能 @hujianglong
    -- AvatarPresetLevel = Enum.AvatarPresetLevel["ROLE_CREATE"] -- todo 创角界面的头部LOD设置，需要上层告知
    if AvatarPresetLevel then
        local lodValuesStr = Enum.EConstListData["AVATAR_HEAD_LOD_"..AvatarPresetLevel]
        if lodValuesStr then
            local Ret = {}
            for _, v in ipairs(lodValuesStr) do
                local intValue = tonumber(v)
                if intValue == nil then intValue = 0 end
                table.insert(Ret, intValue)
            end

            if #Ret == 3 then
                local OwnerActor = Game.ObjectActorManager:GetObjectByID(OwnerActorID)
                local FaceControlComponent = OwnerActor:GetComponentByClass(import("FaceControlComponent"))
                if FaceControlComponent then
                    FaceControlComponent:EnableHeadLodOffset(true)
                    FaceControlComponent:SetHeadLodOffset(Ret[1]+1,Ret[2]+1,Ret[3]+1)
                end
            end
        end
    end
	
	local appearanceCompositedByBodypart = (ModelData_ProfileName ~= nil)
    if appearanceCompositedByBodypart then
		
		table.clear(TempAllBodyparts)
		table.clear(TempForbiddenPartsByConflictRule)
		for _, _PartValue in pairs(ModelData_BodyPartList) do
			-- todo 容错, 还是要@倪铁从数据到处清理无效数据
			if _PartValue.ID ~= nil and _PartValue.ID ~= "" then
				local bodypartData = Game.RoleCompositeMgr:GetPartData(ModelData_ProfileName, _PartValue.ID)
				TempAllBodyparts[bodypartData.BodyPartType] = _PartValue
				
			end
		end
		
		local hasOverrideBodyparts = InUECompositeParams.OverrideBodyparts ~= nil and next(InUECompositeParams.OverrideBodyparts)
		
		for bodypartType, _ in pairs(TempAllBodyparts) do
			-- 编辑器导出的Preset预设数据, 没有提前做冲突part去除处理, 这里实时处理掉
			if Game.RoleCompositeMgr:IsBodypartForbiddenByPartConflictRule(ModelData_ProfileName, TempAllBodyparts, bodypartType) then
				TempForbiddenPartsByConflictRule[bodypartType] = true
			end
			
			-- Override外部传入的部件可能会禁掉预设中的某些部件
			if hasOverrideBodyparts then
				if Game.RoleCompositeMgr:IsBodypartForbiddenByPartConflictRule(ModelData_ProfileName, InUECompositeParams.OverrideBodyparts, bodypartType) then
					TempForbiddenPartsByConflictRule[bodypartType] = true
				end
			end
		end

		for partType, _ in pairs(TempForbiddenPartsByConflictRule) do
			TempAllBodyparts[partType] = nil
		end
			
		-- 外部传入的OverrideParts, 之前默认已经是处理好冲突规则, 这里数据不再处理
		-- 先拿出ModelID预设部分, 然后再通过外部传入的部分部件数据, 进行最终要用的部件更新
		if hasOverrideBodyparts then
			for partType, PartValue in pairs(InUECompositeParams.OverrideBodyparts) do
				TempAllBodyparts[partType] = PartValue
			end
		end
		
		local FinalBodyPartList = TempAllBodyparts
        local PartDataLib = Game.RoleCompositeMgr.AvatarModelPartLib[ModelData_ProfileName]
        
        for bodypartType, _PartValue in pairs(FinalBodyPartList) do
			local _PartData = PartDataLib[_PartValue.ID]
			-- [1] 部件冲突部分, 在编辑器导出的时候, 就已经可以提前把冲突部件都去掉, 剩下的只是最终需要
			local PartData_Model = AvatarData:GetPartData(ActorAppearance_PartData_Model, _PartData.BodyPartType)

			PartData_Model.ModifyType = Enum.ActorAppearanceModifyType.Create
			local AnimAssetID = nil
			local AnimAssetOverride = nil

			if _PartData.BodyPartType == Enum.EAvatarBodyPartType.BodyUpper then
				AnimAssetID = InUECompositeParams.AnimAssetID
				AnimAssetOverride = InUECompositeParams.AnimAssetOverride
			end

			if _PartData.BodyPartType == Enum.EAvatarBodyPartType.Head then
				PartData_Model:InitModifyBodyPartOverrideData(InUECompositeParams.OverrideFaceAndBodyShapePresetModelID, InUECompositeParams.OverrideHeadMakeupData, InUECompositeParams.OverrideBodyshapeCompactData)
			end

			PartData_Model:ModifyData(AvatarData.UID, _PartData.BodyPartType, AvatarData.BaseModelID, bodypartType, _PartValue, _PartValue.ID, _PartValue.MakeupID, 
				InUECompositeParams.InitModelMaterialID, AnimAssetID, AnimAssetOverride)
		end
    else
        --单个全身Mesh --编辑器导出 需要处理成同样的身体部件
        local PartData_MeshCustom = AvatarData:GetPartData(ActorAppearance_PartData_MeshCustom, Enum.EAvatarBodyPartType.BodyUpper)
        if PartData_MeshCustom then
            PartData_MeshCustom.ModifyType = Enum.ActorAppearanceModifyType.Create
            PartData_MeshCustom:ModifyData(Enum.EAvatarBodyPartType.BodyUpper, AvatarData.UID, AvatarData.BaseModelID, InUECompositeParams.AnimAssetID, InUECompositeParams.AnimAssetOverride)
        end
    end

    local PartData_Body = AvatarData:GetPartData(ActorAppearance_PartData_Body, WHOLE_LOGIC_BODY_PART_TYPE)
    PartData_Body.ModifyType = Enum.ActorAppearanceModifyType.Create
    PartData_Body:ModifyData(AvatarData.BaseModelID, AvatarData.UID)

    AvatarData:OnConvertData(self, OwnerActorID, InUECompositeParams.bEnableMeshOptimization, AvatarData.LightChannels, AvatarData.UEActorType)

    return AvatarData
end



--收集
---@param isNeedResetRegisterAssets 如果为true, C++里面留的所有资源引用就会重置, 一般用于一次完整的拼装才重置为全集; 如果只是部件更新, 就不重置, 进行积累
--- 在局内的外观衣柜里, 要分全身套装还是部件,  部件替换时可以积累， 全身套装则重置一次， 避免资源一直累积
-- todo  最好全部做成自己part 处理自己的, 部件替换, 不要的就可以精确操作了
function AAOG_Avatar:CollectAssetPath(InData, isNeedResetRegisterAssets)
	InData:PrepareForLoadAssets(isNeedResetRegisterAssets)
    InData:CollectAssetPath(self, InData.CurrentLoadAssetPaths)
end

function AAOG_Avatar:Execute(InData)

    local loadID, obj = Game.AssetManager:AsyncLoadAssetListKeepReference(InData.CurrentLoadAssetPaths, self, "OnAllAssetsLoaded")
    self.ActorUIDRef[loadID] = InData.UID
    InData.LoadIDMap[loadID] = false

    if InData.PreLoadContext and InData.PreLoadContext.Request then
        InData.PreLoadContext.Result = {Loading={},Loaded={}}
        for PreLoadType, PreLoadPaths in pairs(InData.PreLoadContext.Request) do
            if PreLoadPaths and #PreLoadPaths > 0 then
                local PreloadID, _ = Game.AssetManager:AsyncLoadAssetListKeepReference(PreLoadPaths, self, "OnAllAssetsLoaded")
                self.ActorUIDRef[PreloadID] = InData.UID
                InData.LoadIDMap[PreloadID] = false

                InData.PreLoadContext.Result.Loading[PreloadID] = PreLoadType
            end
        end
    end
end


function AAOG_Avatar:OnAllAssetsLoaded(LoadID, Assets)

    local UID = self.ActorUIDRef[LoadID]
    if UID == nil then
        return
    end

    self.ActorUIDRef[LoadID] = nil

    local AppearanceData = Game.ActorAppearanceManager:GetActorAppearanceData(UID)
    if AppearanceData == nil then
        return
    end

    if AppearanceData.PreLoadContext and AppearanceData.PreLoadContext.Result 
        and AppearanceData.PreLoadContext.Result.Loading
        and AppearanceData.PreLoadContext.Result.Loaded then
        local PreLoadType = AppearanceData.PreLoadContext.Result.Loading[LoadID]
        if PreLoadType then

            AppearanceData.PreLoadContext.Result.Loaded[PreLoadType] = LoadID
            AppearanceData.PreLoadContext.Result.Loading[LoadID] = nil
        end
    end

    local bAppearanceAssetLoaded = true
    for _LoadID, bLoaded in pairs(AppearanceData.LoadIDMap) do
        if _LoadID == LoadID then
            AppearanceData.LoadIDMap[_LoadID] = true
        else
            if bLoaded == false then
                bAppearanceAssetLoaded = false
            end
        end
    end

    if bAppearanceAssetLoaded == false then
        return
    end

    --local start = os.clock()
    --local end1 = os.clock()

	AppearanceData:RegisterAssetsToRoleCompositeMgr(Assets)
    --具体操作单元执行修改
    AppearanceData.Stage = Enum.UECompositeStage.Execute
	
	
	-- Part执行控一下顺序: 其余部件---->头部部件(有肤色同步逻辑, 要先准备好其他部件)---->BodyShape最后
    for _PartType, PartData in pairs(AppearanceData.PartDataMap) do
        if PartData.bMarkDirty then
            if PartData.ModifyType == Enum.ActorAppearanceModifyType.Destroy then
                self:Execute_RemovePart(AppearanceData, _PartType)
            else
				if not (_PartType == WHOLE_LOGIC_BODY_PART_TYPE or _PartType == Enum.EAvatarBodyPartType.Head) then
					for k, OperateData in pairs(PartData.ComOperateDatas) do
						local Op = self:GetOperate(OperateData:GetUECompositeType())
						Op:Execute(OperateData)
					end

					PartData.bMarkDirty = false
				end
            end
        end
    end
	
	-- 头部, 等其他部件好了再做, 有肤色同步的需求
	local HeadPartData =  AppearanceData.PartDataMap[Enum.EAvatarBodyPartType.Head]
	if HeadPartData ~= nil and HeadPartData.bMarkDirty then
		for k, OperateData in pairs(HeadPartData.ComOperateDatas) do
			local Op = self:GetOperate(OperateData:GetUECompositeType())
			Op:Execute(OperateData)
		end
		HeadPartData.bMarkDirty = false
	end
	
	-- 整体体型、特效、挂接、胶囊体等
	local WholeLogicBodyPartData =  AppearanceData.PartDataMap[WHOLE_LOGIC_BODY_PART_TYPE]
	if WholeLogicBodyPartData ~= nil and WholeLogicBodyPartData.bMarkDirty then
		for k, OperateData in pairs(WholeLogicBodyPartData.ComOperateDatas) do
			local Op = self:GetOperate(OperateData:GetUECompositeType())
			Op:Execute(OperateData)
		end
		WholeLogicBodyPartData.bMarkDirty = false
	end

    -- end1 = os.clock()
    -- print("AAOG_AvatarTest6",tostring(end1 - start))

    -- start = os.clock()

    --回调
    --UEActor 主流程 暂定
    local OwnerActor = Game.ObjectActorManager:GetObjectByID(AppearanceData.OwnerActorID)
    if OwnerActor then
        local CompositeCallFunc = AppearanceData.CompositeCallFunc
        if CompositeCallFunc and UID then
            xpcall(CompositeCallFunc, _G.CallBackError, OwnerActor, UID, AppearanceData.PreLoadContext and AppearanceData.PreLoadContext.Result.Loaded, nil)
            AppearanceData.PreLoadContext = nil
        end
    end

    --非强制操作,小部件,饰品异步加载

end

function AAOG_Avatar:Execute_RemovePart(InData, PartType, isNeedDelete)
    if InData.Stage == Enum.UECompositeStage.Execute then
        local _PartData = InData.PartDataMap[PartType]
        if _PartData then
            if _PartData.bMarkDirty then
                for k, OperateData in pairs(_PartData.ComOperateDatas) do
                    local Op = self:GetOperate(OperateData:GetUECompositeType())
					if Op.Rollback then
						Op:Rollback(OperateData, isNeedDelete)
					end
                end
    
                _PartData:ReleaseData()
                InData.PartDataMap[PartType] = nil
            end
        end
    end
end

function AAOG_Avatar:ModifyPart(InData, ModelData_BodyPartList, ModelData_ProfileName)
    if ModelData_BodyPartList and #ModelData_BodyPartList > 0 and ModelData_ProfileName then
        local PartDataLib = Game.RoleCompositeMgr.AvatarModelPartLib[ModelData_ProfileName]
        for _BodyPartList_Index, _PartValue in pairs(ModelData_BodyPartList) do
            if IsStringValid(_PartValue.ID) then
                local _PartData = PartDataLib[_PartValue.ID]
                if _PartData and not Game.RoleCompositeMgr:IsBodypartForbiddenByPartConflictRule(ModelData_ProfileName, ModelData_BodyPartList, _PartData.BodyPartType) then
                    local PartData_Model = InData:GetPartData(ActorAppearance_PartData_Model, _PartData.BodyPartType)
                    if PartData_Model then

                        PartData_Model.ModifyType = Enum.ActorAppearanceModifyType.Changed

                        local AnimAssetID = nil
                        local AnimAssetOverride = nil

                        if _PartData.BodyPartType == Enum.EAvatarBodyPartType.BodyUpper then
                            AnimAssetID = PartData_Model.ModelLibData.AnimAssetID
                            AnimAssetOverride = PartData_Model.ModelLibData.AnimAssetOverride
                        end

                        PartData_Model:ModifyData(InData.UID, _PartData.BodyPartType, PartData_Model.ModelLibData.ModelID, _BodyPartList_Index, _PartValue, _PartValue.ID, _PartValue.MakeupID, 
                            PartData_Model.ModelLibData.InitModelMaterialID, AnimAssetID, AnimAssetOverride)
                    end
                end
            end
        end

        InData:OnConvertData(self, InData.OwnerActorID, true, InData.LightChannels, InData.UEActorType)

        self:CollectAssetPath(InData)

        self:Execute(InData)
    end
end

function ActorAppearanceManager:ctor()
    self.UECompositeOperateLib = UECompositeOperateLibClass.new()
end

function ActorAppearanceManager:dtor()
    self.UECompositeOperateLib = nil
end

function ActorAppearanceManager:Reset()

end

function ActorAppearanceManager:Init()
    self.EnableFun = true
    self.EnableFunv2 = false

    self.UECompositeParamPool = UECompositeParamsV3

    --数据分配池
    self.ActorAppearanceDataMemoryAlloc = ActorAppearanceDataMemoryAlloc.new()

    --修改请求操作参数
    UECompositeParamsV3.MemoryAlloc = self.ActorAppearanceDataMemoryAlloc
    self.ActorAppearanceDataMemoryAlloc:AssignPoolSize(UECompositeParamsV3, 20)

    --组件操作数据
    self.UECompositeOperateLib:Init(self.ActorAppearanceDataMemoryAlloc)

    --模型数据
    ActorAppearanceDataBase.MemoryAlloc = self.ActorAppearanceDataMemoryAlloc

    --各外观部件数据分配对象池(在下列统一定池大小)
    self.ActorAppearanceDataMemoryAlloc:AssignPoolSize(ActorAppearance_PartData_Body, 100)
    self.ActorAppearanceDataMemoryAlloc:AssignPoolSize(ActorAppearance_PartData_Model, 600)
    self.ActorAppearanceDataMemoryAlloc:AssignPoolSize(ActorAppearance_PartData_MeshCustom, 100)

    --各外观数据
    self.ActorAppearanceDataMemoryAlloc:AssignPoolSize(ActorAppearance_AvatarData, 100)
    
    self.ActorAppearance_DataMap = {}

    self.AAOG_Avatar = AAOG_Avatar.new()



    --模型刷新测试内存
    --self:Test_RefreshActorAppearance()

    --测试内存池
    --self:Test_DataPool()

    --测试模型刷新

    --大量skeleton 模型的instance渲染优化开关
    self.EnableRenderSkeletonInstance = false
    
end

function ActorAppearanceManager:UnInit()

    self.ActorAppearance_DataMap = {}

    self.ActorAppearanceDataMemoryAlloc:Reset()
    self.ActorAppearanceDataMemoryAlloc = nil
end

function ActorAppearanceManager:GetActorAppearanceData(UID)
    return self.ActorAppearance_DataMap[UID]
end

function ActorAppearanceManager:GetOperateByType(OperateType)
    return self.UECompositeOperateLib:GetOperateByType(OperateType)
end

function ActorAppearanceManager:OnDestoryActor(UID)
	Log.DebugFormat("[LogicUnit-LifeTimeStage][ActorAppearanceManager:OnDestoryActor] UID:%s", UID)
    --清理资源索引
    Game.RoleCompositeMgr:RemoveActorAppearanceAssetRef(UID)

    local _AppearanceData = self.ActorAppearance_DataMap[UID]
    if _AppearanceData then
        _AppearanceData:ReleaseData()
        self.ActorAppearance_DataMap[UID] = nil
    end
end

--刷新角色外观
-- 角色外观数据的Override的流程:  预设数据  + 运行时Override数据
-- 预设数据主要包含如下:
-- [1] BodyPart外观预设数据: {ID:部件模型预设ID,  MakeUpID:部件材质参数预设ID}
-- [2] 脸部、身体骨骼数据:  FaceCompactList --> {[1]=脸部骨骼数据, [2]=身体骨骼数据}

--  运行时数据(主要来自于捏脸流程, 详见DeSerializationCustomRoleData), 主要包含: 
--  [1] 每个角色的预设模板ID
--  [2] 头发: {部件预设ID, 部件预设MakeUpID}
--  [3] 骨骼数据: 脸型 + 体型
--  [4] Head染色数据:  所有材质相关的, 注意需要在ApplyHeadMakeupData之前设置好参数
--  todo [5] 部件的挑染:  还未支持  @汲滕飞

-- 执行流程:
--  [1] 根据模板预设确定所有bodypart部件集合
--  [2] 每个bodypart根据override的规则, 进行override数据关联
--  [3] 收集所有资源, 进行一次异步加载
--  [4] 异步加载后进行每个bodypart的Execute处理,  bodypart间有执行依赖:   除头以外的bodypart -> 头 bodypart(要处理肤色同步、 bodyshape逻辑部分) -> 剩余的ModelLib额外功能(挂接、特效)

-- todo 待确认 @胡江龙:
-- todo [1] 部分part(例如挂饰) 是支持多个实例的, 这个逻辑并未完善, 需要完善处理; 饰品部分和策划确认, 还没有正式推进, 推进时再和@汲滕飞定协议流程
-- todo [2] override数据部分的材质设置, 将服务器字符串直接传到c++, c++进行反序列化、批量处理。 包括材质、体型数据。 注意: head部分和非head是有设置接口差异, 需要处理 @刘瑞林
-- todo [3] c++ 肤色同步流程支持。 因为[2]在c++中做的, 后续如果进行某个非头部部件替换, 需要在c++侧支持Head的材质参数查询功能  @刘瑞林

function ActorAppearanceManager:Refresh_Avatar(InActor, InUECompositeParams)
    --整理模型数据
    if not IsValid_L(InActor) or not IsValid_L(InActor.Mesh) then
        return
    end
    
    local OwnerActorID = Game.ObjectActorManager:GetIDByObject(InActor)
	Log.DebugFormat("[LogicUnit-LifeTimeStage][ActorAppearanceManager:Refresh_Avatar] UID:%s, OwnerActorId: %s", InUECompositeParams.UID, OwnerActorID)
    if OwnerActorID == nil then
        return 
    end

    local UID = InUECompositeParams.UID
    if UID == nil then
        UID = OwnerActorID
    end

    --转换数据
    local _AvatarData = self:GetActorAppearanceData(UID)
    --AAOG_Avatar
    _AvatarData = self.AAOG_Avatar:ConvertData(_AvatarData, OwnerActorID, InUECompositeParams)
    self.ActorAppearance_DataMap[UID] = _AvatarData

    --收集资源
    self.AAOG_Avatar:CollectAssetPath(_AvatarData, true)

    --执行修改
    self.AAOG_Avatar:Execute(_AvatarData)

    --回收请求参数(待全部替换, 方法检测移除)
    if InUECompositeParams.ReleaseData then
        InUECompositeParams:ReleaseData()
    end
end

--移除角色部件
function ActorAppearanceManager:Avatar_RemovePart(UID, PartType)
    local _AvatarData = self:GetActorAppearanceData(UID)
    if _AvatarData then
        _AvatarData:MarkRemovePart(PartType)
        self.AAOG_Avatar:Execute_RemovePart(_AvatarData, PartType)
    end
end

--修改部件
--[[
function ActorAppearanceManager:Avatar_ModifyPart(UID, ModelData_BodyPartList, ModelData_ProfileName)
    local _AvatarData = self:GetActorAppearanceData(UID)
    if _AvatarData then
        self.AAOG_Avatar:ModifyPart(_AvatarData, ModelData_BodyPartList, ModelData_ProfileName)
    end
end
]]--
function ActorAppearanceManager:EnsureCutsceneActorVisible(InActor)
	if not InActor then
		return
	end

	local skeletalComponents = 	InActor:K2_GetComponentsByClass(import("SkeletalMeshComponent"))
	-- 美术做动画, 都是mesh脱离root, 很容易被裁剪, CutScene里面都把动态更新包围盒打开
	for _, sc in pairs(skeletalComponents) do
		sc:SetUpdateBoundWithFirstSkinnedBone(true)
		sc.BoundsScale = 10
	end
end


--=========================================外部封装接口==========================================
--编辑器刷新外观用, 其他模块不要调用
function ActorAppearanceManager:EditorRefreshModel(InActor, ModelID, AnimAssetID, ScaleValue, InitMaterialID, CallBack, UID)
	local compositeParam =Game.ActorAppearanceManager.UECompositeParamPool:GetFreeData()
	compositeParam.UID = UID
	compositeParam.AnimAssetID = AnimAssetID
	compositeParam.ModelID = ModelID
	compositeParam.CompositeCallFunc = CallBack
	compositeParam.CompositeType = Enum.EUECompositeType.Appearance --拼装类型
	if compositeParam.FacadeScaleValue then
		InActor:SetActorScale3D(FVector(compositeParam.FacadeScaleValue, compositeParam.FacadeScaleValue, compositeParam.FacadeScaleValue))
	end
	compositeParam.InitModelMaterialID = InitMaterialID

	Game.ActorAppearanceManager:Refresh_Avatar(InActor, compositeParam)
end


-- 批量进行部件替换
---Avatar_Modify_BodyParts
---@param UID
---@param RemovedBodyParts 移除部件的part数组
---@param AddedBodyParts {Enum.EAvatarBodyPartType.BodyUpper:{ID:xxx,  MakeUpID:yyy}, Enum.EAvatarBodyPartType.Hair:{..}}
---@param AddedOverrideMakeupDataMapping  {Enum.EAvatarBodyPartType.BodyUpper:OverrideMakeUpData1, Enum.EAvatarBodyPartType.Hair: OverrideMakeUpData2}
---@param OverrideBodyShapeAllCompactData table
function ActorAppearanceManager:Avatar_Modify_BodyParts(UID, RemovedBodyPartsList, AddedBodyPartsMapping, AddedOverrideMakeupDataMapping, CallbackObj, CallbackName , EnableMeshOptimization)

	local AvatarData = self:GetActorAppearanceData(UID)
	if AvatarData == nil then
		Log.ErrorFormat("[Avatar_Modify_BodyParts] Cannot Find Appearance Data, UID:%s ", UID)
		return false
	end

	if AvatarData:IsExecuteDone() == false then
		Log.ErrorFormat("[Avatar_Modify_BodyParts] Cannot Modify Parts When Parts Are Loading, UID:%s ", UID)
		return false
	end

	if RemovedBodyPartsList ~= nil then
		for _, BodyPartType in pairs(RemovedBodyPartsList) do
			AvatarData:MarkRemovePart(BodyPartType)
			self.AAOG_Avatar:Execute_RemovePart(AvatarData, BodyPartType, AddedBodyPartsMapping[BodyPartType] == nil)
		end
		
	end


	table.clear(TempAllBodyparts)
	table.clear(TempForbiddenPartsByConflictRule)

	local ModelData, ModelData_MakeupData, ModelData_BodyPartList, ModelData_ProfileName, AvatarPresetLevel = Game.RoleCompositeMgr:GetModelLibData(AvatarData.BaseModelID)
	local PartDataLib = Game.RoleCompositeMgr.AvatarModelPartLib[ModelData_ProfileName]

	for bodypartType, _PartValue in pairs(AddedBodyPartsMapping) do
		local _PartData = PartDataLib[_PartValue.ID]
		-- [1] 部件冲突部分, 在编辑器导出的时候, 就已经可以提前把冲突部件都去掉, 剩下的只是最终需要
		local PartData_Model = AvatarData:GetPartData(ActorAppearance_PartData_Model, _PartData.BodyPartType, true)

		PartData_Model.ModifyType = Enum.ActorAppearanceModifyType.Create
		if _PartData.BodyPartType == Enum.EAvatarBodyPartType.Head then
			Log.ErrorFormat("Cannot Modify Head Part:%s", UID)
		end

		PartData_Model:ModifyData(AvatarData.UID, _PartData.BodyPartType, AvatarData.BaseModelID, bodypartType, _PartValue, _PartValue.ID, _PartValue.MakeupID,
			nil, nil, nil)

		if AddedOverrideMakeupDataMapping ~= nil and AddedOverrideMakeupDataMapping[bodypartType] ~= nil then
			PartData_Model:InitModifyBodyPartOverrideData(nil, AddedOverrideMakeupDataMapping[bodypartType], nil)
		end
		
	end

	AvatarData:OnConvertData(self.AAOG_Avatar, AvatarData.OwnerActorID, EnableMeshOptimization, AvatarData.LightChannels, AvatarData.UEActorType)
	-- 重新进行收集, 之前的是可以不用要了, 理论上是没有作用了
	self.AAOG_Avatar:CollectAssetPath(AvatarData, false)

	self.AAOG_Avatar:Execute(AvatarData)

end

--改脸部件MakeUpData, 全量的Override数据
function ActorAppearanceManager:Avatar_ModifyPart_MakeUpData(UID, BodyPart, OverrideMakeUpData, CallbackObj, CallbackName)
	local _AvatarData = self:GetActorAppearanceData(UID)
	local CanExecute = true
	if _AvatarData == nil then
		Log.ErrorFormat("[Avatar_ModifyPart_MakeUpData] Cannot Find Appearance Data, UID:%s ", UID)
		CanExecute = false
	end

	local BodyPartPartData = _AvatarData:GetExistPartData(BodyPart)
	if CanExecute and BodyPartPartData == nil then
		Log.DebugFormat("[ModifyPart_MakeUpData]  Cannot Get Existed Bodypart UID:%s BodyPartType:%s", UID, BodyPart)
		CanExecute = false
	end

	local operateMatData = BodyPartPartData:GetOperateMaterialData()
	if CanExecute and operateMatData == nil then
		Log.DebugFormat("[ModifyPart_MakeUpData]  Cannot Get Existed Material Operate Data, UID:%s BodyPartType:%s", UID, BodyPart)
		CanExecute = false
	end

	local ExecuteSuccess = false
	if CanExecute and operateMatData:ExecuteOverrideHeadMakeUpData(OverrideMakeUpData, CallbackObj, CallbackName) then
		ExecuteSuccess = true
	end

	if CanExecute == false or ExecuteSuccess == false then
		if CallbackObj ~= nil then
			CallbackObj[CallbackName](CallbackObj, false, UID)
		end
		return false
	end

	return true
end

-- 改体型, 全量的脸 + 体型的Override数据
function ActorAppearanceManager:Avatar_Modify_BodyShape(UID, OverrideBodyShapeAllCompactData)
	local _AvatarData = self:GetActorAppearanceData(UID)
	if _AvatarData == nil then
		Log.ErrorFormat("[Avatar_Modify_BodyShape] Cannot Find Appearance Data, UID:%s ", UID)
		return false
	end

	local BodyPartPartData = _AvatarData:GetExistPartData(Enum.EAvatarBodyPartType.Head)
	if BodyPartPartData == nil then
		Log.DebugFormat("[Avatar_Modify_BodyShape]  Cannot Get Existed Bodypart UID:%s BodyPartType:%s", UID, Enum.EAvatarBodyPartType.Head)
		return false
	end

	local operateMatData = BodyPartPartData:GetOperateBodyShapeData()
	if operateMatData == nil then
		Log.DebugFormat("[Avatar_Modify_BodyShape]  Cannot Get Existed Material Operate Data, UID:%s BodyPartType:%s", UID, Enum.EAvatarBodyPartType.Head)
		return false
	end

	return operateMatData:ExecuteOverrideBodyShape(OverrideBodyShapeAllCompactData)
end



-- ========================================外部封装接口============================================

-------------测试 Begin---------------------------

---对象池测试
function ActorAppearanceManager:Test_DataPool()

    self.ActorAppearanceDataMemoryAlloc:AssignPoolSize(ActorAppearance_PartData_Body, 1000)

    local sss1= {}
    for i = 1, 1000, 1 do
        local sss = ActorAppearance_PartData_Body:GetFreeData()
        table.insert(sss1, sss)
    end

    for i = 1, 1000, 1 do
        sss1[i]:ReleaseData()
    end

    local start = os.clock()
    local SM  = collectgarbage("count")

    for i = 1, 100, 1 do
        local sss = ActorAppearance_PartData_Body:GetFreeData()
    end

    for i = 1, 100, 1 do
        sss1[i]:ReleaseData()
    end

    local end1 = os.clock()
    local EM  = collectgarbage("count")
	print("PoolTest",tostring(end1 - start), "  ", tostring(EM - SM))
end


--测试模型刷新
function ActorAppearanceManager:Test_RefreshActorAppearance()


    --Pool Test
    self.SKCompositeOperate = Game.ActorAppearanceManager:GetOperateByType(Enum.UECompositeTypeV2.SkeletalMeshCom)
    
    local _TestOP = {}

    for i = 1, 600, 1 do
        local OperateData = self.SKCompositeOperate:GetData()
        table.insert(_TestOP, OperateData)
    end

    for i = 1, 600, 1 do
        _TestOP[i]:ReleaseData()
    end

    local start = os.clock()
    local SM  = collectgarbage("count")

    for i = 1, 100, 1 do
        self.SKCompositeOperate:GetData()
    end

    for i = 1, 100, 1 do
        _TestOP[i]:ReleaseData()
    end

    local end1 = os.clock()
    local EM  = collectgarbage("count")
	print("Test_RefreshActorAppearance Pool Time: ",tostring(end1 - start), " Memory: ", tostring(EM - SM))

    local MoveTest = {}

    for i = 1, 60, 1 do
        table.insert(MoveTest, tostring(i))
    end

    local MoveTest2 = {}
    for i = 60, 120, 1 do
        table.insert(MoveTest2, tostring(i))
    end

    start = os.clock()
    SM  = collectgarbage("count")

    table.move(MoveTest, 1, #MoveTest, #MoveTest2, MoveTest2)

    end1 = os.clock()
    EM  = collectgarbage("count")

    print("Test_RefreshActorAppearance MoveTest Time: ",tostring(end1 - start), " Memory: ", tostring(EM - SM))

    print(MoveTest2)

    --Appearance Test
    --self.AAOG_Appearance = AAOG_Appearance.new()



end

-------------测试 End---------------------------

return ActorAppearanceManager