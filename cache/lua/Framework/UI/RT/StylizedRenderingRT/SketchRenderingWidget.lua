local RenderTargetWidgetBase = require "Framework.UI.RT.RenderTargetWidgetBase"
local SketchRenderingWidget = DefineClass("SketchRenderingWidget", RenderTargetWidgetBase)
local Const = kg_require("Shared.Const")
function SketchRenderingWidget:GetSceneName()
    return "UISkeletch"
end

function SketchRenderingWidget:ExtraOP()
    self:StartTimer("test", function ()
        self._Scene:BeginCapture()
    end, 500, 1)
end

function SketchRenderingWidget:SetParams(StyleType)
    self._Scene:SetParams(StyleType)
end

function SketchRenderingWidget:GetActorParams(prefessionID, sex)
    local ActorParams = {}
    if not prefessionID then prefessionID = 1200001 end
    
    local ParamsLeft = Game.TableData.GetGuildTargetCameraDataRow(prefessionID)
    local CreateRoleFacadeIDLeft = Game.TableData.GetPlayerSocialDisplayDataRow(prefessionID)
        .CreateRoleFacade
    local CreateRoleFacadeDataLeft = Game.TableData.GetFacadeControlDataRow(CreateRoleFacadeIDLeft)
    table.insert(ActorParams, {
        LocationTag = "Location_1", 
        Model = CreateRoleFacadeDataLeft.ModelID,
        IdleAnim = ParamsLeft.IdleAnim,
        DisplayAnim = ParamsLeft.DisplayAnim,
        Profession = prefessionID,
		Sex = sex,
        -- FaceData = nil,
        ImageWidget = self.View.Img_Player,
        --MTAsset = "/Game/Blueprint/Scene3DDisplay/UISketch/MI_Sketch_Arbitrator.MI_Sketch_Arbitrator",
        -- Position = FVector(-100, -250, 160),
        -- FOVAngle = 45,-
        -- CaptureEveryFrame = false
    })
    return ActorParams
end

--- 【可选/可覆写】在场景中Spawn Actors，一般用于自定义添加Npc/主角类模型
function SketchRenderingWidget:SpawnActor()
    if not next(self.ActorParams) then return end
    self.ActorList = {}
    local ActorNum = #self.ActorParams
    for i = 1, ActorNum do
        if self.ActorParams[i].LocationTag and self.ActorParams[i].Model then
            -- local ActorID, _ = Game.SceneDisplayManager:SpawnDisplayCharacter(self._SceneID,
            -- self.ActorParams[i].LocationTag, self.ActorParams[i].Model, self.ActorParams[i].IdleAnim, self.ActorParams[i]
            --     .DisplayAnim)
            local ActorID, _ = Game.SceneDisplayManager:SpawnDisplayAvatarEntity(self._SceneID,self.ActorParams[i].LocationTag, self.ActorParams[i].Profession, 
				self.ActorParams[i].Sex, "A_Fea_Idle",nil, GetMainPlayerPropertySafely("eid"), Const.VIEW_ROLE_FACE_DATA_SOURCE.INDIVIDUAL)
            -- 缓存下ActorID
            self.ActorList[i] = ActorID
            -- 如果有捏脸数据，刷新捏脸数据
            if self.ActorParams[i].FaceData then
                Game.SceneDisplayManager:RefreshCharacterFaceModelByData(self._SceneID, ActorID,
                self.ActorParams[i].FaceData)
            end
        end
    end
end

return SketchRenderingWidget
