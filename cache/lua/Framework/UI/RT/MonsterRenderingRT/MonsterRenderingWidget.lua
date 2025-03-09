local RenderTargetWidgetBase = require "Framework.UI.RT.RenderTargetWidgetBase"
local MonsterRenderingWidget = DefineClass("MonsterRenderingWidget", RenderTargetWidgetBase)

function MonsterRenderingWidget:OnCreate()
    RenderTargetWidgetBase.OnCreate(self)
    self.MonsterLoadFinish = LuaMulticastDelegate.new()  -- luacheck: ignore
end

function MonsterRenderingWidget:StartCapture()
    if self.captureTimer then
        self:StopTimer(self.captureTimer)
    end

    self.captureTimer = self:StartTimer("CaptureTick", function ()
        self._Scene:BeginCapture()
    end, 60, -1, false, true)
end

function MonsterRenderingWidget:EndCapture()
    if not self.captureTimer then
        return
    end

    self:StopTimer(self.captureTimer)
end

function MonsterRenderingWidget:ChangeMonster()
    if not self._SceneID or not self.ActorList then
        return
    end

    for _, actor in pairs(self.ActorList) do
        Game.SceneDisplayManager:RemoveDisplayEntity(self._SceneID, actor.eid)
    end
    table.clear(self.ActorList)

    self:SpawnActor()
end

function MonsterRenderingWidget:GetSceneName()
    return "UIRTMonster"
end

function MonsterRenderingWidget:GetActorParams(modelID)
    local ActorParams = {}
    table.insert(ActorParams, {
        Model = modelID
    })
    return ActorParams
end

function MonsterRenderingWidget:SpawnActor()
    if not next(self.ActorParams) then 
        return 
    end
    
    self.ActorList = {}
    for i, actorParam in ipairs(self.ActorParams) do
        if actorParam.Model then
            local Actor = Game.SceneDisplayManager:SpawnDisplayEntity(self._SceneID, FTransform(), actorParam.Model)
            Actor.OnActorReady:Add(self, "OnLoadPlayerFinish")
            self.ActorList[i] = Actor
        end
    end
end

function MonsterRenderingWidget:OnLoadPlayerFinish(Entity)
    local SceneCaptureComponentList =  self._Scene:GetComponentsByTag(import("SceneCaptureComponent2D"), "SceneCaptureComponent")
    if SceneCaptureComponentList:Length() > 0 then
        local SceneCapture = SceneCaptureComponentList:Get(0)
        SceneCapture.ShowOnlyActors:Clear()
        SceneCapture.ShowOnlyActors:Add(Game.ObjectActorManager:GetObjectByID(Entity.CharacterID))
    end

    self:StartCapture()
    self.MonsterLoadFinish:Broadcast(Entity)
end

return MonsterRenderingWidget
