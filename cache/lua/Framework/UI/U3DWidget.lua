---@class U3DWidget:UIController
local U3DWidget = DefineClass("U3DWidget", UIComponent)

function U3DWidget:OnCreate()
    --加载场景ID
    self.SceneID = nil
    -- 异步加载资源
    self.AsyncLoadHandleList = {}
    -- 任务缓存
    self.TaskCache = nil
    -- ActorLisst
    self.ActorList = {}
    -- Save the Entity IDs of all spawned entites
    -- TODO: Save the enetities to allow anim played correctly
    self.EntityList = {}
end

U3DWidget.RtTagList = {
    Location_1st = "RenderTarget_1st",
    Location_2nd = "RenderTarget_2nd",
    Location_3rd = "RenderTarget_3rd",
    Default = "RenderTarget_Body"
}
U3DWidget.RtPosition = { FVector(-70, 0, 135), FVector(-70, 250, 135), FVector(-70, -250, 135), FVector(-200, 0, 130) }
U3DWidget.FOVAngle = { 45.0, 45.0, 45.0, 45.0 }

-- 加载场景
-- @param : ActorParam = {LocationTag, Model, IdleAnim, DisplayAnim, FaceData, ImageWidget, MTAsset}
function U3DWidget:LoadActor(SceneName, ActorParams)
    -- 初始化场景
    self.SceneID = Game.SceneDisplayManager:FindOrCreateScene(SceneName)
    -- 初始化Actors
    if self.SceneID then
        self.MTList = {}
        self.WidgetBindList = {}
        local ActorNum = #ActorParams
        self.curScene = Game.SceneDisplayManager:GetSceneByID(self.SceneID)
        for i = 1, ActorNum do
            -- 有LocationTag + Model，才会走SpawnCharacter
            if ActorParams[i].LocationTag and ActorParams[i].Model then
                local ActorID, _ = Game.SceneDisplayManager:SpawnDisplayCharacter(self.SceneID,
                    ActorParams[i].LocationTag, ActorParams[i].Model, ActorParams[i].IdleAnim, ActorParams[i]
                    .DisplayAnim)
                -- 缓存下ActorID
                self.ActorList[i] = ActorID
                -- 如果有捏脸数据，刷新捏脸数据
                if ActorParams[i].FaceData then
                    Game.SceneDisplayManager:RefreshCharacterFaceModelByData(self.SceneID, ActorID,
                        ActorParams[i].FaceData)
                end
            end
            if self.curScene then
                local rtList = self.curScene:GetComponentsByTag(import("SceneCaptureComponent2D"),
                    U3DWidget.RtTagList[ActorParams[i].LocationTag])
                self.curRt = nil
                if rtList:Length() > 0 then
                    self.curRt = rtList:Get(0)
                end
                if self.curRt then
                    self.curRt:K2_SetRelativeLocation(ActorParams[i].Position or U3DWidget.RtPosition[i], false, nil,
                        false)
                end
                self.curScene:SetFOVAngle(i, ActorParams[i].FOVAngle or U3DWidget.FOVAngle[i])
                if ActorParams[i].CaptureEveryFrame ~= nil and ActorParams[i].CaptureEveryFrame == false then
                    self.CaptureEveryFrame = false
                else
                    self.CaptureEveryFrame = true
                end
               
            end
            -- 缓存下imageWidget
            if ActorParams[i].ImageWidget then
                table.insert(self.WidgetBindList, ActorParams[i].ImageWidget)
            end
            -- 添加MT到异步加载队列
            table.insert(self.MTList, ActorParams[i].MTAsset)
        end
    end

    -- 异步加载材质节点
    Game.AssetManager:AsyncLoadAssetListKeepReference(self.MTList, self, "OnAsyncLoadMTCB")

   
end

-- 加载场景
-- 加载为LocalEntity
-- TODO:支持播放动画
-- @param : ActorParam = {LocationTag, Model, IdleAnim, DisplayAnim, FaceData, ImageWidget, MTAsset, TargetRotation}
function U3DWidget:LoadActorLocalEntity(SceneName, ActorParams, PreloadScene)
    -- 初始化场景
    self.SceneID = Game.SceneDisplayManager:FindOrCreateScene(SceneName, PreloadScene)
    -- 初始化Actors
    if self.SceneID then
        self.MTList = {}
        self.WidgetBindList = {}
        local ActorNum = #ActorParams
        self.curScene = Game.SceneDisplayManager:GetSceneByID(self.SceneID)
        for i = 1, ActorNum do
            -- 有LocationTag + Model，才会走SpawnCharacter
            if ActorParams[i].LocationTag and ActorParams[i].Model then
                local RolePlayLocalEntity = Game.SceneDisplayManager:SpawnDisplayAvatarEntity(
                       self.SceneID, ActorParams[i].LocationTag, ActorParams[i].Profession, ActorParams[i].Sex, 
                            ActorParams[i].IdleAnim, ActorParams[i].FaceData, ActorParams[i].FaceDataEID
                )
                RolePlayLocalEntity.OnActorReady:Add(self, "OnEntityReady")
                self.curRt = nil
                self.curRTList = {}
                self.curRTList = self.curScene:GetComponentsByTag(import("SceneCaptureComponent2D"),
                U3DWidget.RtTagList[ActorParams[i].LocationTag])
                if self.curRTList:Length() > 0 then
                    self.curRt = self.curRTList:Get(0)
                end
                if ActorParams[i].bWitchCamera and ActorParams[i].bWitchCamera == true then
                    --魔女
                    self.bWitchCamera = true
                    self.Index = ActorParams[i].Index
                    self.Pos = ActorParams[i].Position
                    self.Angle = ActorParams[i].Angle
                else
                    self.curScene:WitchCameraSetBack()
                    -- Rotate
                    if ActorParams[i].TargetRotation then
                        local CurrentKey = 0
                        local Rotator = RolePlayLocalEntity.Rotation
                        self:StartTimer("RolePlay_SetCharacterRotation", function(Delta)
                            CurrentKey = CurrentKey + Delta / 1000
                            local CurrentRot = ActorParams[i].TargetRotation
                            RolePlayLocalEntity:SetCharRotation(Rotator + FRotator(0, CurrentRot, 0), true)
                            if CurrentKey >= 1 then
                                self:StopTimer("RolePlay_SetCharacterRotation")
                            end
                            return false
                        end, 1, -1, nil, true)
                    end
                    -- Position
                    if self.curRt then
                        self.curRt:K2_SetRelativeLocation(ActorParams[i].Position or U3DWidget.RtPosition[i], false, nil,
                                false)
                    end
                    -- FOVAngle
                    self.curScene:SetFOVAngle(i, ActorParams[i].FOVAngle or U3DWidget.FOVAngle[i])
                end
            end

            -- Set MT Asset
            if ActorParams[i].ImageWidget and ActorParams[i].MTAsset then
                self:SetMaterial(ActorParams[i].ImageWidget, ActorParams[i].MTAsset)
            end
        end
    end
end

-- 播放动画

function U3DWidget:OnEntityReady(Entity)
    if self.bWitchCamera then
        self.curScene:WitchCameraSet(self.Index, self.Pos, self.Angle)
        self:StartTimer("WitchTimer", function()
            --延时截帧
           for key, value in pairs(self.curRTList) do
                value:CaptureScene()
           end
         end, 500, 1, true)
    end
    Entity:SetWeaponVisibilityOnActorComplete(false, Enum.EInVisibleReasons.RolePlayHideWeapon)
end

-- 刷新Actor Mesh/Anim数据
function U3DWidget:RefreshActor(ID, Model, AnimAsset)
    Game.SceneDisplayManager:RefreshPlayerModelDisplay(self.SceneID, self.ActorList[ID], Model, AnimAsset)
end

-- 刷新Actor FaceData:  Game.SceneDisplayManager:RefreshCharacterFaceModelByData()


function U3DWidget:Close()
    self:StopTimer("UpdateRTTimer")
    Game.SceneDisplayManager:RemoveScene(self.SceneID)
    self.SceneID = nil
    self.AsyncLoadHandleList = {}
    self.WidgetBindList = {}
    self.TaskCache = nil
    self.ActorList = {}
end

return U3DWidget
