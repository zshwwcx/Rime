local RenderTargetWidgetBase = DefineClass("RenderTargetWidgetBase", UIComponent)


---------------------------------- 上层覆写内容 --------------------------------------------------
----

-- 填充SceneDisplayConfig中的SceneName, 举例:"CardDisplay" / "Scene3DDisplay"
function RenderTargetWidgetBase:GetSceneName()
    return nil
end

-- 填充场景中的Actor List参数，可填充多个，举例:
---- Param = {
    -- LocationTag = "Location_1",
    -- Model = CreateRoleFacadeDataLeft.ModelID,
    -- IdleAnim = ParamsLeft.IdleAnim,
    -- DisplayAnim = ParamsLeft.DisplayAnim,
    -- FaceData = nil,
    -- ImageWidget = self.View.Img_Role_Left,
    -- MTAsset = "/Game/Blueprint/Scene3DDisplay/Scene3DDisplay_MT_3.Scene3DDisplay_MT_3",
    -- }
---------------------------------------------
function RenderTargetWidgetBase:GetActorParams()
    return {}
end

-------------------------------- 上层覆写内容结束 ------------------------------------------------


--- 【必须】填充SceneDisplayConfig中的场景名称，用于加载场景
function RenderTargetWidgetBase:Init()
    -- 【上层子类填充，必选】SceneName
    self.SceneName = self:GetSceneName()
    -- 【上层子类填充，可选】ActorParams
    self.ActorParams = self:GetActorParams()
end

--- 【可选/可覆写】在场景中Spawn Actors，一般用于自定义添加Npc/主角类模型
function RenderTargetWidgetBase:SpawnActor()
    if not next(self.ActorParams) then return end
    self.ActorList = {}
    local ActorNum = #self.ActorParams
    for i = 1, ActorNum do
        if self.ActorParams[i].LocationTag and self.ActorParams[i].Model then
            local ActorID, _ = Game.SceneDisplayManager:SpawnDisplayCharacter(self._SceneID,
            self.ActorParams[i].LocationTag, self.ActorParams[i].Model, self.ActorParams[i].IdleAnim, self.ActorParams[i]
                .DisplayAnim)
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

--- 【可选/可覆写/预留接口】在场景中Spawn Entities，一般用于自定义添加怪物
function RenderTargetWidgetBase:SpawnExtraEntities()

end

--- 【可选/可覆写】调整场景中Components的FOV/Position等属性
function RenderTargetWidgetBase:SetFOVAndPos()

end

--- 处理材质数据
function RenderTargetWidgetBase:DealWithMTData()
    if not next(self.ActorParams) then return end
    self.MTList = {}
    self.WidgetBindList = {}
    local ActorNum = #self.ActorParams
    for i = 1, ActorNum do
        if self.ActorParams[i].ImageWidget and self.ActorParams[i].MTAsset then
            self:SetMaterial(self.ActorParams[i].ImageWidget, self.ActorParams[i].MTAsset)
        end
    end
end

-- 【必须】WidgetBase初始化，定义基础变量
function RenderTargetWidgetBase:OnCreate()
    -- 场景对应的场景ID(在SceneDisplayManager中)
    self._SceneID = nil
    -- 场景对象
    self._Scene = nil
    -- 场景Actor List
    self._ActorList = {}
    -- 异步加载任务缓存
    self._TaskCache = nil
    -- 异步加载结果列表
    self._AsyncLoadHandleList = {}
    -- 【可选】材质列表，用于采样RenderTarget并SetBrush到Image
    self.MTList = {}
    -- 【可选】材质映射列表，用于存储材质贴图和Image的映射关系
    self.WidgetBindList = {}
    -- 场景Actor List
    self.ActorList = {}

    self:Init()
end

-- 【必须】加载场景
function RenderTargetWidgetBase:LoadScene()
    if self.SceneName then
        self._SceneID = Game.SceneDisplayManager:FindOrCreateScene(self.SceneName)
        self._Scene = Game.SceneDisplayManager:GetSceneByID(self._SceneID)
    end
end

-- 【可选】动态加载RT
function RenderTargetWidgetBase:LoadRT()
    -- TEST LOGIC
    local RT = import("UIFunctionLibrary").NewRenderTarget2d(slua.getWorld(), FVector2D(100, 100))
    local SceneCaptureComponentList =  self._Scene:GetComponentsByTag(import("SceneCaptureComponent2D"), "SceneCaptureComponent")
    if SceneCaptureComponentList:Length() > 0 then
        local SceneCapture = SceneCaptureComponentList:Get(0)
        SceneCapture.TextureTarget = RT
    end
end

function RenderTargetWidgetBase:ExtraOP()

end

-- 【必须】核心逻辑
function RenderTargetWidgetBase:ExecMain()
    -- 加载场景
    self:LoadScene()
    -- 加载Actors
    self:SpawnActor()
    -- 加载Entities
    self:SpawnExtraEntities()
    -- 调整场景属性
    self:SetFOVAndPos()
    -- 处理材质相关数据
    self:DealWithMTData()

    self:ExtraOP()
    
    -- TODO:目前的RT都是预创建的，在蓝图BeginPlay的时候就已经加载了，后续如果需要支持复用场景，动态创建RT的话，这里需要迭代一波
    -- self:LoadRT()

end

-- 【必须】析构
function RenderTargetWidgetBase:Release()
    Game.SceneDisplayManager:RemoveScene(self._SceneID)
end



return RenderTargetWidgetBase