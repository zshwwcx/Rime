---@class UIAutomationProfileLua
UIAutomationProfile = DefineClass("UIAutomationProfile")
local ProfileConfig = require("Tools.UIAutomationProfile.UIAutomationProfileConfig")
local mri = require("Tools.LuaMemSnapshot")
local UPaperSprite = import("PaperSprite")
local UUserWidget = import("UserWidget")
local UTexture2D = import("Texture2D")


function UIAutomationProfile:HookLogic()
    -- 修改UIBase Refresh逻辑，用于统计UIController打开计时
    UIBase.Refresh = function(self, ...)
        self:SetCurrencyData()
        self:RefreshShowScene()
        self:OnRefresh(...)
        --- UIAutomationProfile 统计整个页面打开计时
        if not SHIPPING_MODE then
            Game.EventSystem:Publish(_G.EEventTypes.ON_UI_REFRESH_END, self.uid)
        end
    end

    -- 修改打开UI规则锁，默认全部可以解锁
    Game.OpenPanelCheckSystem.CanOpen = function(self, uid)
        return true
    end

    -- 处理UIBase SetImage Atlas统计
    UIBase.SetImage = function(self, image, path, callBack, isAsync, bIgnoreOpacity)
        if self._isOpen == false then
            Log.Error("UIBase:SetImage 调用了已经关闭的UI接口 class:%s, path:%s, %s", self.__cname,path)
            return
        end
        isAsync = isAsync == nil and true or isAsync
        path = self:checkResourcePath(path)
        if string.isEmpty(path) then
            return
        end
        if self.imageRecord[image] == path then
            if callBack then
                callBack()
            end
            return
        end
        self.imageRecord[image] = path
        local oldAlpha = nil
        if not bIgnoreOpacity then
            oldAlpha = image.ColorAndOpacity.A
            if oldAlpha <= 0 then
                oldAlpha = 1
            end
            image:SetOpacity(0)
        end
            -- luacheck: push ignore
        local func = function(res)
            if res == nil then
                Log.WarningFormat("UIFrame:UIBase:SetImage 设置图片失败 请检查图片路径是否正确 %s", path)
                return
            end
            if self._isOpen == false then
                Log.Error("UIBase:SetImage 关闭的时候异步加载任务没有停掉 class:%s, path:%s", self.__cname,path)
                return
            end
            if self.destroyed then
                Log.Error("UIBase:SetImage UI没有触发关闭但是对象销毁了")
                return
            end
            if res:IsA(UPaperSprite) then
                image:SetBrushFromAtlasInterface(res, false)
                if Game.StatAtlasSystem:CheckNeedStatsAtlas() then
					xpcall(Game.StatAtlasSystem.RecordPaperSprite,_G.CallBackError,Game.StatAtlasSystem,res,self.__cname)
					xpcall(Game.StatAtlasSystem.RecordPaperSpriteDatadByJson,_G.CallBackError,Game.StatAtlasSystem)
				end
            elseif res:IsA(UTexture2D) then
                image:SetBrushFromTexture(res, false)
                if Game.StatAtlasSystem:CheckNeedStatsAtlas() then
					xpcall(Game.StatAtlasSystem.RecordTexture,_G.CallBackError,Game.StatAtlasSystem,res,self.__cname)
					xpcall(Game.StatAtlasSystem.RecordNoAtalsDataByJson,_G.CallBackError,Game.StatAtlasSystem)
				end
            end
            if not bIgnoreOpacity then
                image:SetOpacity(oldAlpha)
            end
            if callBack then
                callBack()
            end
        end
        self:LoadRes(path, func, isAsync)
    end

    -- Hook UIBase/UIComponent，统计图集信息
    UIBase.ctor = function(self, uid, panelUID, userWidget, widget, parentScript, ...)
        UIAnimation.ctor(self, self)
        -- todo 兼容老版本后续删除
        --------------------------------
        if type(widget) == "table" then
            widget = widget.WidgetRoot
        end
        self.parent = parentScript
        self.autoBind = true
        self.foms = {}
        -------------------------------
        self.imageRecord = {}
        self.widget = widget
        self.uid = uid
        self.userWidget = userWidget
        self.parentScript = parentScript
        self.panelUID = panelUID
        self._isOpen = nil
        self._isShow = nil
        self._childComponents = {}
        self._uObjectNum = 0
        self.widgetEventsList = setmetatable({}, {__mode = "k"})
        self:createView()
        self:OnCreate(...)
        self:GetAllAutoAnimationInfo()
        self:InitUIEvent()
        self:InitCustomComponent()
        self:InitComponent()

        if self.View.WidgetRoot:IsA(UUserWidget) then
            xpcall(Game.StatAtlasSystem.RecordWidget,_G.CallBackError,Game.StatAtlasSystem,self.View.WidgetRoot,self)
        end
    end

    -- UIBase RemoveComponent要触发ON_UI_CLOSE消息，保证子UI能够正常收到关闭通知
    UIBase.RemoveComponent = function(self, uid)
        self:TryCancelLoadUI(uid)
        for k, v in ipairs(self._childComponents) do
            if v.uid == uid then
                table.remove(self._childComponents, k)
                v:Hide()
                v:Close(true)
                v:Destroy()
                Game.EventSystem:Publish(_G.EEventTypes.ON_UI_CLOSE, uid)
                break
            end
        end
    end

    -- 关掉UIManager对于WorldRendering的控制
    Game.UIManager.processWorldRendering = function()
        return
    end

end

function UIAutomationProfile:Init(bLogin, bTest)
    _G.NoCacheUI = true
    _G.bUIAutomationProfile = true
    ---@type UIAutomationProfile
    self.UIAutomationProfileHelper = import("UIAutomationProfile")(_G.GetContextObject())
    self.UIList = {}
    self.bTest = bTest
    self.NoContinue = false
    Game.StatAtlasSystem:StartStatAtlas()
    -- 记录UI打开时间
    self.UIStartOpenTime = os.time()
    self.UIFinishOpenTime = os.time()

    self.UIStartOpenTimeMap = {}
    self.UIFinishOpenTimeMap = {}

    -- 记录下是否遇到了异常
    self.WithError = false

    -- 这里处理一些对于其他模块侵入式的修改，比如UIBase, UIController, UIManager等逻辑
    self:HookLogic()
end 

function UIAutomationProfile:OnLoginSuc()

    -- Game.GameLoopManagerV2:innerOpenMap("", Game.GameLoopManagerV2.LoginMapID, nil, Game.GameLoopManagerV2.EGameStageType.InGame)
    Game.GMManager.ExecuteCommand("SwitchMap 5200055")
    Game.TimerManager:CreateTimerAndStart(function()
        import("GameplayStatics").SetEnableWorldRendering(_G.GetContextObject(), false)
        local player = GetMainPlayerCharacter()
        if player then
            player:SetActorHiddenInGame(true)
        end

        -- 清理所有UI，销毁场景
        self:ClearUI()
        Game.EventSystem:RemoveObjListeners(self)

        self:StartProfile()
    end, 15000, 1)

end

function UIAutomationProfile:GetWBPName(config)
    local res = config.res
    if res then
        return string.match(res, "([^/]+)%.") or ""
    else
        return ""
    end
end

-- function UIAutomationProfile:CheckConfigValid(config)

--     return true
-- end

function UIAutomationProfile:StartProfile()
    if not self.UIAutomationProfileHelper then
        self.UIAutomationProfileHelper = import("UIAutomationProfile")(_G.GetContextObject())
    end
    self.UIAutomationProfileHelper:Init()
    -- table.insert(self.UIList, {name = "P_Lib_AutomationTest", params = nil})
    local index = 0
    for k, v in pairs(Game.UIConfig) do
        if k ~= "_Default" then
            local WBPName = self:GetWBPName(v)
            -- 一级页面
            if v.parent == nil and v.parentui == nil then
                -- if index % 20 == 0 then
                    if ProfileConfig[k] then
                        for index, vv in pairs(ProfileConfig[k]) do
                            table.insert(self.UIList, {name = k,
                                                    displayName = string.format("%s_%d",k,index), params = vv.Params, luaCodeAfterShow = vv.LuaCodeAfterShow, isFirstLevelPage = true, wbpName = WBPName})
                        end
                    else
                        -- 一级页面没有被UI自动上报统计到，默认其参数为空，执行UI Perf
                        table.insert(self.UIList, {name = k,
                                                    displayName = string.format("%s_%d",k,1), params = {}, luaCodeAfterShow = nil, isFirstLevelPage = true, wbpName = WBPName})
                    -- else
                    --     Log.Debug("[UIAutomationProfile StartProfile]一级页面收集,当前一级页面:%s 缺少页面参数配置", tostring(k))
                    end
                -- end
            -- -- 【二级页面性能监测】添加二级页面信息到UIList中
            -- else
            --     if ProfileConfig[k] then
            --         for index, vv in pairs(ProfileConfig[k]) do
            --             table.insert(self.UIList, {name = k,
            --             displayName = string.format("%s_%d",k,index), params = vv.Params, luaCodeAfterShow = vv.LuaCodeAfterShow, isFirstLevelPage = false})
            --         end
            --     else
            --         Log.Debug("[UIAutomationProfile StartProfile]二级页面收集,当前二级页面:%s 缺少页面参数配置", tostring(k))
            --     end
            end
        end
        index = index + 1
    end
    self.ProfileIndex = 0
    -- UIManager:GetInstance().libui = nil
    self:StartSingleUIProfile()
end

function UIAutomationProfile:ClearUI()
    local uiManager = UIManager:GetInstance()
    -- 关闭所有UI
    xpcall(uiManager.DestroyAllPanel, function(e)
        Log.Debug(e)
    end, uiManager)
    -- 清理缓存
    uiManager:ClearCache()
    -- 有些UI报错，流程终端,uiManager OpenPanelStack不会持有UI数据，DestroyAllPanel无法正常清理，那么需要走这里
    UIManager:GetUIRoot().CanvasPanels:Get(2):ClearChildren()
    -- 隐藏头顶UI
    HideAllWorldWidget()
    -- 清理场景
    Game.SceneDisplayManager:RemoveAllScene()
end

function UIAutomationProfile:StartSingleUIProfile()
    Log.Debug("UIAutomationProfile_StartSingleUIProfile")
    self.WithError = false
    import("GameplayStatics").SetEnableWorldRendering(_G.GetContextObject(), false)
    if not self.ProfileIndex then
        return
    end
    -- 如果超时保护Timer存在，清理掉
    if self.checkUITimer then
        Game.TimerManager:StopTimerAndKill(self.checkUITimer)
        self.checkUITimer = nil
    end
    self.ProfileIndex = self.ProfileIndex + 1
    -- 清理所有UI，销毁场景
    self:ClearUI()
    -- Game.TimerManager:CreateTimerAndStart(function()
    -- 判断下是否越界，如果越界，导出数据
    if self.ProfileIndex > #self.UIList then
        --Game.LuaInsightProfiler:Stop()
        GetContextObject():ConsoleCommand("obj list")
        self.UIAutomationProfileHelper:ExportCSV()
        return
    end
    Log.Debug("StartSingleUIProfile", self.UIList[self.ProfileIndex].name, self.UIList[self.ProfileIndex].params)
    -- 执行全量GC,先Lua，后UE
    self:RunGarbageCollection()
    -- end, 2000, 1)

    -- 先清理掉可能存在的NextUITimer
    if self.NextUITimer then
        Game.TimerManager:StopTimerAndKill(self.NextUITimer)
        self.NextUITimer = nil
    end

    -- 【二级页面性能监测】这里前置判断下是否是二级页面，如果是二级页面，先把父页面给show出来
    local isFirstLevelPage = self.UIList[self.ProfileIndex].isFirstLevelPage
    if not isFirstLevelPage then
        local name = self.UIList[self.ProfileIndex].name
        local parentUIName = Game.UIConfig[name].parentui
        local parentUIParams = ProfileConfig[parentUIName]
        if type(parentUIParams) == "table" then
            xpcall(UI.ShowUI, function(e)
                self.ReportError(e) 
            end, parentUIName, table.unpack(parentUIParams))
        else
            xpcall(UI.ShowUI, function(e)
                self.ReportError(e)
            end, parentUIName, parentUIParams)
        end
    end

    self.ShowUIWithError = false

    self.wbpName = self.UIList[self.ProfileIndex].wbpName
    
    self.NextUITimer = Game.TimerManager:CreateTimerAndStart(function()
        if self.ProfileIndex == 1 then
            GetContextObject():ConsoleCommand("obj list forget")
        end
        local name = self.UIList[self.ProfileIndex].name or self.UIList[self.ProfileIndex].displayName
        collectgarbage("collect")
        local luaMemory = collectgarbage("count")
        self.UIAutomationProfileHelper:StartSingleUIProfile(name, luaMemory)
        --mri.m_cMethods.DumpMemorySnapshot("./LuaMemDump/", string.format("%s_Open",name), -1)
        -- 记录下打开时间
        self.UIStartOpenTimeMap[self.UIList[self.ProfileIndex].name] = os.time()
        local params = self.UIList[self.ProfileIndex].params

        Game.EventSystem:RemoveObjListeners(self)
        -- 真正在执行ShowUI的时候，才会开始监听ON_UI_OPEN
        Game.EventSystem:AddListener(EEventTypes.ON_UI_REFRESH_END, self, self.OnSingleUIOpened)

        if type(params) == "table" then
            xpcall(UI.ShowUI, function(e)
                self.ReportError(e)
                self.WithError = true
                Game.EventSystem:RemoveObjListeners(self)
                -- 有报错的话，手动执行OnSingleUIOpened
                self:OnSingleUIOpened(self.UIList[self.ProfileIndex].name, self.wbpName)
                -- -- 有报错，立即执行OnSingleUIOpened, 随后Close，做数据统计，然后执行下一个UI的Profile
                -- Game.TimerManager:CreateTimerAndStart(function()
                --     self:ClearUI()
                --     self:OnSingleUIClosed(self.UIList[self.ProfileIndex].name)
                -- end, 10000, 1)
            end, self.UIList[self.ProfileIndex].name, table.unpack(params))
        else
            xpcall(UI.ShowUI, function(e)
                self.ReportError(e)
                self.WithError = true
                Game.EventSystem:RemoveObjListeners(self)
                -- 有报错的话，手动执行OnSingleUIOpened
                self:OnSingleUIOpened(self.UIList[self.ProfileIndex].name, self.wbpName)
                -- -- 有报错，立即执行OnSingleUIOpened, 随后Close，做数据统计，然后执行下一个UI的Profile
                -- Game.TimerManager:CreateTimerAndStart(function()
                --     self:ClearUI()
                --     self:OnSingleUIClosed(self.UIList[self.ProfileIndex].name)
                -- end, 10000, 1)
            end, self.UIList[self.ProfileIndex].name, params)
        end
    end, 5000, 1)

    -- 如果因为一些其他原因，没能正常走到OnSingleUIOpened，添加超时机制，直接执行关闭，走下一个UI数据
    self.checkUITimer = Game.TimerManager:CreateTimerAndStart(function()
        Log.Debug("UI Open Error, start Profile next UI")
        -- self:StartSingleUIProfile()
        self:OnSingleUIOpened(self.UIList[self.ProfileIndex].name, self.wbpName)
    end, 25000, 1)
end

function UIAutomationProfile:OnSingleUIOpened(uid, wbpName)
    print("UIAutomationProfile_OnSingleUIOpened")
    -- 过滤掉不是当前Profile的uid
    if not self.NoContinue and (self.UIList[self.ProfileIndex] == nil or uid ~= self.UIList[self.ProfileIndex].name) then
        return
    end
    if self.UIList and self.UIList[self.ProfileIndex] and self.UIList[self.ProfileIndex].luaCodeAfterShow ~= nil then
        local func = load(self.UIList[self.ProfileIndex].luaCodeAfterShow)
        if func then
            xpcall(func, function(e)
                self.ReportError(e)
            end)
        end
    end
    -- 计算下打开时间
    local UIOpenTime = 0
    if self.UIStartOpenTimeMap[uid] then
        UIOpenTime = os.time() - self.UIStartOpenTimeMap[uid]
    end
    Log.Debug("UI", uid, "打开时间:",  UIOpenTime)

    if self.ProfileTimer then
        Game.TimerManager:StopTimerAndKill(self.ProfileTimer, false)
    end
    if self.Timer1 then
        Game.TimerManager:StopTimerAndKill(self.Timer1, false)
    end
    if self.Timer2 then
        Game.TimerManager:StopTimerAndKill(self.Timer2, false)
    end

    if self.checkUITimer then
        Game.TimerManager:StopTimerAndKill(self.checkUITimer, false)
    end

    local ui = UIManager:GetInstance():getUI(uid)
    -- UI打开1s后，真正开始执行UI Profile数据统计工作
    self.ProfileTimer = Game.TimerManager:CreateTimerAndStart(function()
        Log.Debug("OnSingleUIOpened", uid)  
        local luaMemory = collectgarbage("count")


        if not ui or not ui.View or not ui.View.WidgetRoot then
            self.UIAutomationProfileHelper:OnSingleUIOpened(nil, self.UIList[self.ProfileIndex].name, luaMemory, UIOpenTime)
        else
            self.UIAutomationProfileHelper:OnSingleUIOpened(ui.View.WidgetRoot, self.UIList[self.ProfileIndex].name, luaMemory, UIOpenTime)
        end

        local textureTable, atlasTable = Game.StatAtlasSystem:GetUIAtlasData(uid)
        if textureTable then
            for k, v in pairs(textureTable) do
                self.UIAutomationProfileHelper:AddDependenceTextureName(k)
            end
        end
        if atlasTable then
            for k, v in pairs(atlasTable) do
                local atlasName = string.format("%s(%s;%s)",k, v.UseCountPercent, v.UseSizePercent)
                self.UIAutomationProfileHelper:AddDependenceAtlasName(atlasName)
            end
        end
    end, 1000, 1)

    -- 2s后，统计Slate Stats数据，以及截屏相关操作
    self.Timer1 = Game.TimerManager:CreateTimerAndStart(function()
        self.Timer1 = nil
        self.UIAutomationProfileHelper:StopCollectSlateStatData()
        self.UIAutomationProfileHelper:TakeSnapShot()
        Game.TimerManager:CreateTimerAndStart(function()
            -- 统计正常的OverDraw数据
            self.UIAutomationProfileHelper:TakeSnapShotOverdraw()
            Game.TimerManager:CreateTimerAndStart(function()
                self.UIAutomationProfileHelper:GetOverDrawData()
                GetContextObject():ConsoleCommand("slate.showviewportoverdraw 0")
            end, 500, 1)

            -- 统计collapsed掉所有材质节点后，OverDraw数据
            if ui and ui.View and ui.View.WidgetRoot then
                Game.TimerManager:CreateTimerAndStart(function()
                    self.UIAutomationProfileHelper:CollapseMaterialForOverDrawCheck(ui.View.WidgetRoot)
                end, 1000, 1)

                Game.TimerManager:CreateTimerAndStart(function()
                    self.UIAutomationProfileHelper:GetOverDrawDataWithOutMaterial()
                    GetContextObject():ConsoleCommand("slate.showviewportoverdraw 0")
                end, 1500, 1)
            end

            -- -- 这时候如果有报错,ui可能是nil，直接执行 OnClosed进入下一步
            -- if self.WithError then
            --     Game.EventSystem:RemoveListenerFromType(EEventTypes.ON_UI_CLOSE, self, self.OnSingleUIClosed)
            --     self:OnSingleUIClosed(uid)
            -- end
        end, 500, 1)

        -- 5.0s后，关闭页面，走Close消息
        self.Timer2 = Game.TimerManager:CreateTimerAndStart(function()
            self.Timer2 = nil
            self.NoShowAnyUI = true
            -- 真正调用CloseSelf的时候，才会监听OnSingleUIClosed
            Game.EventSystem:RemoveListenerFromType(EEventTypes.ON_UI_CLOSE, self, self.OnSingleUIClosed)
            Game.EventSystem:AddListener(EEventTypes.ON_UI_CLOSE, self, self.OnSingleUIClosed)
            if not ui then
                -- 关闭UI遇到异常， 那么手动执行OnSingleUIClosed
                Game.EventSystem:RemoveListenerFromType(EEventTypes.ON_UI_CLOSE, self, self.OnSingleUIClosed)
                self:OnSingleUIClosed(uid)
            else
                xpcall(ui.CloseSelf, function(e)
                    self.ReportError(e)
                    -- Log.Debug("OnSingleUIClosed", uid)
                    -- local luaMemory = collectgarbage("count")
                    -- self.UIAutomationProfileHelper:OnSingleUIClosed(luaMemory)
                    -- self:StartSingleUIProfile()
                    -- 关闭UI遇到异常， 那么手动执行OnSingleUIClosed
                    Game.EventSystem:RemoveListenerFromType(EEventTypes.ON_UI_CLOSE, self, self.OnSingleUIClosed)
                    self:OnSingleUIClosed(uid)
                end, ui)
            end
        end, 3000, 1)
    end, 2000, 1)

    -- 如果因为一些其他原因，没能正常走到OnSingleUIClosed，添加超时机制，直接执行关闭，走下一个UI数据
    self.checkUITimer2 = Game.TimerManager:CreateTimerAndStart(function()
        Log.Debug("UI Open Error, start Profile next UI")
        -- self:StartSingleUIProfile()
        self:OnSingleUIClosed(self.UIList[self.ProfileIndex].name)
    end, 25000, 1)
end

function UIAutomationProfile:OnSingleUIClosed(uiName)
    print("UIAutomationProfile_OnSingleUIClosed")
    if self.ProfileIndex > #self.UIList then
        return
    end
    if not self.NoContinue and (self.UIList[self.ProfileIndex] == nil or uiName ~= self.UIList[self.ProfileIndex].name) then
        return
    end
    if self.Timer1 then
        Game.TimerManager:StopTimerAndKill(self.Timer1, false)
    end
    if self.Timer2 then
        Game.TimerManager:StopTimerAndKill(self.Timer2, false)
    end

    if self.checkUITimer2 then
        Game.TimerManager:StopTimerAndKill(self.checkUITimer2, false)
    end

    --Game.EventSystem:DealPendingList()
    Game.SceneDisplayManager:RemoveAllScene()
    Log.Debug("OnSingleUIClosed", uiName)
    self:RunGarbageCollection()
    Game.TimerManager:CreateTimerAndStart(function()
        local luaMemory = collectgarbage("count")
        -- local name = self.UIList[self.ProfileIndex].displayName or self.UIList[self.ProfileIndex].name
        --mri.m_cMethods.DumpMemorySnapshot("./LuaMemDump/", string.format("%s_Close",name), -1)
        --local fileA = "LuaMemRefInfo-All-[" .. name .. "_Open]"
        --local fileB = "LuaMemRefInfo-All-[" .. name .. "_Close]"
        --mri.m_cMethods.DumpMemorySnapshotComparedFile("./", name .. "_Diff", -1, fileA, fileB)
        self.UIAutomationProfileHelper:OnSingleUIClosed(luaMemory)
        self.NoShowAnyUI = false
        if self.NoContinue then
        else
            self:StartSingleUIProfile()
        end
        self.NoContinue = false
    end, 3000, 1)
end

function UIAutomationProfile.ReportError(e)
    Log.Debug(e)
    UIAutomationProfile.UIAutomationProfileHelper:ReportError(e)
end

function UIAutomationProfile:RunGarbageCollection()
    collectgarbage("collect")
    self.UIAutomationProfileHelper:ForceGarbageCollection(true)
    collectgarbage("collect")
    self.UIAutomationProfileHelper:ForceGarbageCollection()
    collectgarbage("collect")
    self.UIAutomationProfileHelper:ForceGarbageCollection()
    Game.TimerManager:CreateTimerAndStart(function()
        collectgarbage("collect")
        self.UIAutomationProfileHelper:ForceGarbageCollection()
        collectgarbage("collect")
        self.UIAutomationProfileHelper:ForceGarbageCollection()
        collectgarbage("collect")
        self.UIAutomationProfileHelper:ForceGarbageCollection()
    end, 1500, 1)
end
