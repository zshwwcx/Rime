local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class UIShowSceneComponent:NewUIComponent
local UIShowSceneComponent = DefineClass("UIShowSceneComponent", UIComponent)

UIShowSceneComponent.defaultSceneName = "default" --默认场景名字

function UIShowSceneComponent:OnCreate()
	self.sceneID = nil --场景id
	self.cameraTag = nil  --相机Tag
	self.sceneActors = nil  --创建的Actor列表
	self.sceneEntities = nil --创建的Entity列表
	self.sceneName = nil --场景名称
	self.bUseEnterBlackMask = false --退场时是否需要黑屏过渡
	self.bUseExitBlackMask = false --退场时是否需要黑屏过渡
end

function UIShowSceneComponent:OnOpen()
	local whiteList = {}
	table.insert(whiteList, self.uid)
	table.mergeList(whiteList, UIConst.HIDE_ALL_WHITE_LIST)
	Game.NewUIManager:HideAllPanel(self.uid, whiteList)
end

---OnShow
---@param sceneName string 场景名称
---@param bUseEnterBlackMask boolean 入场时是否需要黑屏过渡
---@param bUseExitBlackMask boolean 退场时是否需要黑屏过渡
function UIShowSceneComponent:OnRefresh(sceneName, bUseEnterBlackMask,bUseExitBlackMask,RoleShowCameraType,FaceCloseUpCameraModeTag,FocusCoord)
	self.sceneName = sceneName
	self.bUseEnterBlackMask = bUseEnterBlackMask
	self.bUseExitBlackMask = bUseExitBlackMask
	Log.DebugFormat("ShowScene:%s", sceneName)
	self:showScene(sceneName, bUseEnterBlackMask,RoleShowCameraType,FaceCloseUpCameraModeTag, FocusCoord)
	self:SetSequencerCineCamera()   --TODO:临时处理有sequencer播放的场景
	Game.NewUIManager:UpdateWorldRendering()
end

---@private showScene 显示场景
---@param sceneName string  场景名称，见SceneDisplayConfig配置
---@param bUseBlackMask boolean  是否使用黑屏过渡
function UIShowSceneComponent:showScene(sceneName, bUseBlackMask,RoleShowCameraType,FaceCloseUpCameraModeTag,FocusCoord)
	if sceneName == UIShowSceneComponent.defaultSceneName then
		Game.SceneDisplayManager:ShowScene(-1, bUseBlackMask, nil,RoleShowCameraType,FaceCloseUpCameraModeTag,FocusCoord)
		return
	end
	if self.sceneID == nil
		or not Game.SceneDisplayManager:SceneExists(self.sceneID)
		or Game.SceneDisplayManager:GetSceneConfigName(self.sceneID) ~= sceneName then
		self.sceneID = Game.SceneDisplayManager:FindOrCreateScene(sceneName)
		self.sceneActors = {}
		self.sceneEntities = {}
	end
	Game.SceneDisplayManager:ShowScene(self.sceneID, bUseBlackMask, self.cameraTag)
end

--- 切换相机
---@param cameraTag string  相机tag
---@param blendTime number  混合时间
function UIShowSceneComponent:SwitchCamera(cameraTag, blendTime)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	self.cameraTag = cameraTag
	Game.SceneDisplayManager:SwitchCameraInScene(self.sceneID, cameraTag, blendTime)
end

--- 在指定位置显示一个Actor
---@param locationTag string 目标位置component标记的Tag
---@param actorBPTypeOrActorClass string  Actor类型或BP名称
function UIShowSceneComponent:SpawnSceneActorAtLocation(locationTag, actorBPTypeOrActorClass)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end

	if self.sceneActors[locationTag] == nil or not Game.SceneDisplayManager:ActorExists(self.sceneID, self.sceneActors[locationTag]) then
		self.sceneActors[locationTag] = Game.SceneDisplayManager:SpawnSceneActorAtLocation(self.sceneID, locationTag, actorBPTypeOrActorClass)
	end
end

--- 在指定位置显示一个Character
---@param locationTag string  目标位置component标记的Tag
---@param model string  模型
---@param animAssetID string  动画资源
function UIShowSceneComponent:SpawnSceneCharacter(locationTag, model, animAssetID, equips)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] == nil or not Game.SceneDisplayManager:ActorExists(self.sceneID, self.sceneActors[locationTag]) then
		self.sceneActors[locationTag] = Game.SceneDisplayManager:SpawnSceneCharacter(self.sceneID, locationTag, model, animAssetID, equips)
	end
end

--- 根据职业直接生成
---@param locationTag string  目标位置component标记的Tag
---@param profession number  职业ID
function UIShowSceneComponent:SpawnSceneCharacterByProf(locationTag, profession)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] == nil or not Game.SceneDisplayManager:ActorExists(self.sceneID, self.sceneActors[locationTag]) then
		--TODO: GetPlayerBattleDataRow这边临时处理
		local playerData = Game.TableData.GetPlayerBattleDataRow(profession)[0]
		if playerData then
			self.sceneActors[locationTag] = Game.SceneDisplayManager:SpawnSceneCharacter(self.sceneID, locationTag,
				"RoleCreate_Character_" .. profession, playerData.AnimAssetID)
		end
	end
end

--- 根据职业直接生成
---@param locationTag string  目标位置component标记的Tag
---@param profession number  职业ID
function UIShowSceneComponent:RefreshPlayerModelDisplayByProfession(locationTag, profession, equips)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] ~= nil and Game.SceneDisplayManager:ActorExists(self.sceneID, self.sceneActors[locationTag]) then
		local sceneActor = Game.SceneDisplayManager:GetSceneActorByID(self.sceneID, self.sceneActors[locationTag])
		--TODO: GetPlayerBattleDataRow这边临时处理
		local playerData = Game.TableData.GetPlayerBattleDataRow(profession)[0]
		if playerData and sceneActor then
			Game.SceneDisplayManager:RefreshPlayerModelDisplayByProfession(self.sceneID, self.sceneActors[locationTag],
				profession, equips)
		end
	end
end

---根据职业直接生成
---@param locationTag string  目标位置component标记的Tag
---@param profession number  职业ID
function UIShowSceneComponent:RefreshCharacterFaceModelByEid(locationTag, eid, sourceID)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] ~= nil and Game.SceneDisplayManager:ActorExists(self.sceneID, self.sceneActors[locationTag]) then
		Game.SceneDisplayManager:RefreshCharacterFaceModelByEid(self.sceneID, self.sceneActors[locationTag], eid,
			sourceID)
	end
end

---根据职业直接生成
---@param locationTag string  目标位置component标记的Tag
---@param profession number  职业ID
function UIShowSceneComponent:RefreshCharacterFaceModelByData(locationTag, faceData)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] ~= nil and Game.SceneDisplayManager:ActorExists(self.sceneID, self.sceneActors[locationTag]) then
		Game.SceneDisplayManager:RefreshCharacterFaceModelByData(self.sceneID, self.sceneActors[locationTag], faceData)
	end
end

--- 生成展示角色
---@param locationTag string  目标位置component标记的Tag
---@param model string  模型
---@param idleAnim string  闲置动画名称
---@param displayAnim string  展示动画名称
---@param equips table 装备列表
function UIShowSceneComponent:SpawnDisplayCharacter(locationTag, model, idleAnim, displayAnim, equips)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] == nil or not Game.SceneDisplayManager:ActorExists(self.sceneID, self.sceneActors[locationTag]) then
		self.sceneActors[locationTag] = Game.SceneDisplayManager:SpawnDisplayCharacter(self.sceneID, locationTag, model,
			idleAnim, displayAnim, equips)
	end
end

---@param transformOrLocationCompTagName string
---@param profession number
---@param sex number
---@param animOverrides table
---@param faceData table
---@param faceDataEid number
---@param faceDataSourceID number
---@param bDissolve boolean
---@param bAttachWeapon boolean
function UIShowSceneComponent:SpawnDisplayAvatarEntity(transformOrLocationCompTagName, profession, sex, animOverrides,
													 faceData, faceDataEid, faceDataSourceID, bDissolve, bAttachWeapon, finishCallback)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneEntities[transformOrLocationCompTagName] == nil then
		self.sceneEntities[transformOrLocationCompTagName] = Game.SceneDisplayManager:SpawnDisplayAvatarEntity(
			self.sceneID, transformOrLocationCompTagName, profession, sex, animOverrides, faceData, faceDataEid, faceDataSourceID, bDissolve, bAttachWeapon, finishCallback)
	end
end

function UIShowSceneComponent:SpawnDisplayEntity(transformOrLocationCompTagName, facadeControlID, animOverrides)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneEntities[transformOrLocationCompTagName] == nil then
		self.sceneEntities[transformOrLocationCompTagName] = Game.SceneDisplayManager:SpawnDisplayEntity(
			self.sceneID, transformOrLocationCompTagName, facadeControlID, animOverrides)
	end
end

function UIShowSceneComponent:RemoveDisplayEntity(entityID)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	Game.SceneDisplayManager:RemoveDisplayEntity(self.sceneID, entityID)
end

function UIShowSceneComponent:RemoveDisplayEntityAtLocation(TransformOrLocationCompTagName)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneEntities[TransformOrLocationCompTagName] == nil or self.sceneEntities[TransformOrLocationCompTagName].int_id == nil then
		return
	end
	self:RemoveDisplayEntity(tostring(self.sceneEntities[TransformOrLocationCompTagName].int_id))
	self.sceneEntities[TransformOrLocationCompTagName] = nil
end

--- 重新播放展示动画
---@param locationTag string  目标位置component标记的Tag
function UIShowSceneComponent:PlayDisplayAnimation(locationTag)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] ~= nil then
		Game.SceneDisplayManager:RotateActor(self.sceneID, self.sceneActors[locationTag], rotationDelta)
	end
end

--- 清除指定位置角色
---@param locationTag string  目标位置component标记的Tag
function UIShowSceneComponent:ClearLocation(locationTag)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] ~= nil then
		Game.SceneDisplayManager:DestroySceneCharacter(self.sceneID, self.sceneActors[locationTag])
		self.sceneActors[locationTag] = nil
	end
end

--- 旋转Actor
---@param locationTag string  目标位置component标记的Tag
---@param rotationDelta FRotator  旋转偏移值
function UIShowSceneComponent:RotateActor(locationTag, rotationDelta)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] ~= nil then
		Game.SceneDisplayManager:RotateActor(self.sceneID, self.sceneActors[locationTag], rotationDelta)
	end
end

--- 移动Actor
---@param locationTag string  目标位置component标记的Tag
---@param locationDelta FVector  旋转偏移值
function UIShowSceneComponent:MoveActor(locationTag, locationDelta)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] ~= nil then
		Game.SceneDisplayManager:MoveActor(self.sceneID, self.sceneActors[locationTag], locationDelta)
	end
end

--- 重置位置
---@param locationTag string  目标位置component标记的Tag
function UIShowSceneComponent:ResetActorLocationAndRotation(locationTag)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] ~= nil then
		Game.SceneDisplayManager:ResetActor(self.sceneID, self.sceneActors[locationTag], locationTag)
	end
end

---@brief 获取该位置的Actor
---@param locationTag string 目标位置component标记的Tag
function UIShowSceneComponent:GetSceneActor(locationTag)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] ~= nil then
		return Game.SceneDisplayManager:GetSceneActorByID(self.sceneID, self.sceneActors[locationTag])
	end
end

function UIShowSceneComponent:RefreshPlayerModelDisplay(locationTag, model, animAssetID)
	if self.sceneID == nil or not Game.SceneDisplayManager:SceneExists(self.sceneID) then
		return nil
	end
	if self.sceneActors[locationTag] ~= nil then
		Game.SceneDisplayManager:RefreshPlayerModelDisplay(self.sceneID, self.sceneActors[locationTag], model,
			animAssetID)
	end
end

---@param params LevelSequencePlayParams
function UIShowSceneComponent:PlayLevelSequence(params)
	return Game.SceneDisplayManager:PlayLevelSequence(params)
end

function UIShowSceneComponent:OtherRequirementLoaded()
	Game.SceneDisplayManager:OtherRequirementLoaded()
end

function UIShowSceneComponent:TerminateLevelSequence(loadID)
	Game.SceneDisplayManager:TerminateLevelSequence(loadID)
end

function UIShowSceneComponent:SetLevelSequenceToLastFrame()
	Game.SceneDisplayManager:SetLevelSequenceToLastFrame()
end

function UIShowSceneComponent:SetSequencerCineCamera()
	return Game.SceneDisplayManager:SetSequencerCineCamera(self.sceneID)
end

---@private hideScene 隐藏场景
function UIShowSceneComponent:hideScene()
	if self.sceneName == "default" then
		Game.SceneDisplayManager:HideScene(-1, self.bUseExitBlackMask)
	end
	if self.sceneID ~= nil then
		self:TerminateLevelSequence()
		Game.SceneDisplayManager:HideScene(self.sceneID, self.bUseExitBlackMask)
		--self.sceneActors 待删除
		for _, actorID in pairs(self.sceneActors) do
			Game.SceneDisplayManager:DestroySceneCharacter(self.sceneID, actorID)
		end
		for _, value in pairs(self.sceneEntities) do
			Game.SceneDisplayManager:RemoveDisplayEntity(self.sceneID, tostring(value.int_id))
		end
		self.sceneID = nil
		table.clear(self.sceneActors)
		table.clear(self.sceneEntities)
	end
end

function UIShowSceneComponent:clearData()
	self.sceneID = nil
	table.clear(self.sceneActors)
	table.clear(self.sceneEntities)
end

function UIShowSceneComponent:OnShow()
	if self.sceneID then
		Game.SceneDisplayManager:ShowScene(self.sceneID, self.bUseEnterBlackMask, self.cameraTag)
		self:SetSequencerCineCamera()
	end
end

function UIShowSceneComponent:OnHide()
	if self.sceneID then
		Game.SceneDisplayManager:HideScene(self.sceneID, self.bUseExitBlackMask)
	end
end

function UIShowSceneComponent:OnClose()
	Game.NewUIManager:RestoreAllPanel(self.uid)
	Game.NewUIManager:UpdateWorldRendering()
	self:hideScene()
	self:clearData()
end

function UIShowSceneComponent:OnDestroy()
	Game.SceneDisplayManager:RemoveScene(self.sceneID)
	self:clearData()
end

return UIShowSceneComponent