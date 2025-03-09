local LoaderComponent = kg_require("Framework.KGFramework.KGUI.Core.LoaderComponent")
local UICachePool = kg_require("Framework.KGFramework.KGUI.Core.UICache.UICachePool")
local json = require "Framework.Library.json"
local DataTableFunctionLibrary = import("DataTableFunctionLibrary")
local UIFunctionLibrary = import("UIFunctionLibrary")
local KismetInputLibrary = import("KismetInputLibrary")
local LinkedList = require("Framework.Library.LinkedList")
local ipairs = ipairs
local pairs = pairs
local SubsystemBlueprintLibrary = import("SubsystemBlueprintLibrary")
local NiagaraUISubSystem = import("NiagaraUISubSystem")

---@class NewUIManager : ManagerBase
local UIManager = DefineClass("NewUIManager", ManagerBase, LoaderComponent)

--region 初始化
---@private
function UIManager:onCtor()
	self:initData()
end
---@private
function UIManager:initData()
	self._bInitialized = false  			--是否初始化
	self.uiRoot = nil						--uiroot
	self._enableSceneRender = nil				--开启场景渲染
	self._bEnableEsc = true					--
	self._bViewportResized = false          -- 窗口是否发生变化
    ---@type UIPanel[] 						--所有打开的面板的队列
    self._openPanelStack = {}
    ---@type table<string, UIPanel>         --key:uid所有打开的面板字典
    self._openPanelMap = {}
    ---@type number 						--当前非固定层级面板的最大Order
    self._curCanvasOrder = UIConst.PANEL_ORDER_MIN
    ---@type table<string, UIPanel> 		--key:uid记录面板被隐藏的来源数据，用于后面恢复
    self._panelHideFlag = {}
	self._uiConfigCache = {}				--uiconfig 缓存 是配表config 和 程序config合在一起的
	self._loadingPanel = {}                 --当前正在加载的UI
	self._lastPanelParam = {}               --面板最后一次打开传入的参数
	---@type UICachePool
	self._uiCachePool = UICachePool.new()

	---@type table<number, LinkedList> 所有不同布局类型的UI集合
	self.layoutUIs = {}
	for i, v in pairs(Enum.EUILayout) do
		self.layoutUIs[v] = LinkedList.new()
	end

	self.SceneCapture = nil                -- 移动端BackGroundBlur需要的SceneCapture
	
	-- 屏幕型号适配
	self:initScreenData()
end

function UIManager:onInit()
	 --注册全屏半屏冲突
     Game.StateConflictManager:Register(Enum.EStateConflictAction.FullScreenUi, false)
     Game.StateConflictManager:Register(Enum.EStateConflictAction.NonFullScreenUi, false)
end

---@private
function UIManager:onDestroy()
	self._uiCachePool:delete()
    self.uiRoot = nil
    self._openPanelStack = nil
    self._openPanelMap = nil
	self.layoutUIs = nil
	self.SceneCapture = nil
	self:delete()
end
---@private
function UIManager:onUnInit()
	self:ClearLoad()
	self:DestroyAllPanel()
	if not self.uiRoot then
		local isOnDestroy = self._openPanelMap == nil
		Log.WarningFormat("UIFrame.NewUIManager 销毁时序异常, onDestroy is %s", isOnDestroy)
		return
	end
	self.uiRoot.ViewportResizedEvent:Clear()
	self.uiRoot:RemoveFromViewport()
     --注册全屏半屏冲突
     Game.StateConflictManager:UnRegister(Enum.EStateConflictAction.FullScreenUi)
     Game.StateConflictManager:UnRegister(Enum.EStateConflictAction.NonFullScreenUi)
end
---@public
function UIManager:StartUp()
	if self._bInitialized then
		return
	end
	self:initRoot()
	self._bInitialized = true
end
---@private
function UIManager:initRoot()
	local ContextObject = _G.StoryEditorWorld and _G.StoryEditorWorld or _G.GetContextObject()
	self.uiRoot = UE.WidgetBlueprintLibrary.Create(ContextObject, UE.UIRoot)
	self.uiRoot.ViewportResizedEvent:Bind(function(resX, resY)
		self:OnViewportResized(resX, resY)
	end)
	self.uiRoot:Init()
	self.uiRoot:AddToViewport(2)
    self.uiRoot:DontAutoRemoveWithWorld()
	self.panelCanvas = self.uiRoot:CreateCanvas(UIConst.CANVAS_TYPE.NORMAL_UI)
end
--endregion

--region 面板管理
--主动功能点：打开面板、关闭面板、隐藏和显示全部面板、关闭和销毁所有面板、面板预加载、
--被动功能：全屏UI关闭3d渲染、同侧半屏UI互斥
--region 面板管理对外接口
---@public 同步打开面板
---@param uid string 面板Id，必须填
function UIManager:SyncOpenPanel(uid, ...)
    self:internalOpenPanel(uid, false, ...)
end

---@public 异步打开面板
---@param uid string 面板Id，必须填
function UIManager:OpenPanel(uid, ...)
    self:internalOpenPanel(uid, true, ...)
end

---@public 关闭面板
---@param uid string
---@param immediate？ boolean 是否立刻关闭，不播放动画
function UIManager:ClosePanel(uid, immediate)
	if self:stopLoadingPanel(uid) then
		return
	end
    if not self:CheckPanelIsOpen(uid) then
		local config = self:GetUIConfig(uid)
		Log.WarningFormat("UIFrame.NewUIManager@【%s】 尝试关闭一个没有打开的界面 %s trace%s", config.auth, uid, debug.traceback())
        return
    end
    local panel = self._openPanelMap[uid]
	self:clearPanelHideFlag(uid)
-- luacheck: push ignore
    local closeFinishCallback = function()
        self:processPanelClose(panel)
		Game.EventSystem:Publish(_G.EEventTypes.ON_UI_CLOSE, uid)
        Log.InfoFormat("UIFrame.NewUIManager:关闭界面 %s", uid)
    end
    panel:PreClose(immediate, closeFinishCallback)
-- luacheck: pop
end

---@public 预加载面板
---@param uid string
function UIManager:WarmPanel(uid)
	if not self:CheckPanelIsOpen(uid) then
		Log.InfoFormat("UIFrame.NewUIManager:预加载面板 %s", uid)
		    -- luacheck: push ignore
		local func = function(panel)
			if panel then
				panel:Hide()
				self._uiCachePool:PushPanel(panel)
			end
		end
		self:getPanelFormPool(uid, func, true)
	    -- luacheck: pop
    end
end

---@public IsShow UI是否打开且显示
---@param uid string 
function UIManager:IsShow(uid)
	local panel = self._openPanelMap[uid]
	return panel and panel:IsShow()
end

---@public IsOpened UI是否打开
---@param uid string
function UIManager:IsOpened(uid)
	local panel = self._openPanelMap[uid]
	return panel and panel:IsOpened()
end

---@public 隐藏一些普通UI HIDE_ALL_WHITE_LIST 这些白名单UI不隐藏
---@field uid string
function UIManager:HideNormalFormPanel(uid)
	local whiteList = {uid}
	table.mergeList(whiteList, UIConst.HIDE_ALL_WHITE_LIST)
    self:HideAllPanel(uid, whiteList)
end

---@public 恢复显示一些普通 和 HideNormalFormPanel 成对调用
---@field uid string
function UIManager:RestoreNormalFormPanel(uid)
	self:RestoreAllPanel(uid)
end

---隐藏现有的面板，结束之后需要调用 RestoreAllPanel 恢复
---@param hideType HIDE_PANELS_SOURCE_TYPE 隐藏面板的来源
---@param whiteList string[] 白名单列表，白名单的面板不隐藏
function UIManager:HideAllPanel(hideSource, whiteList)
	Log.InfoFormat("UIFrame.NewUIManager:HideAllPanel By %s ", hideSource)
    whiteList = whiteList or {}
	for uid, panel in pairs(self._openPanelMap) do
        if not table.contains(whiteList, uid) then
			self:HidePanel(hideSource, uid)
        end
    end
end

---恢复之前隐藏的UI面板 需要和HideAllPanel接口保持成对的调用
---@param hideSource HIDE_PANELS_SOURCE_TYPE|string(uid) 隐藏面板的来源
function UIManager:RestoreAllPanel(hideSource)
	Log.InfoFormat("UIFrame.NewUIManager:RestoreAllPanel By %s ", hideSource)
	for uid, panel in pairs(self._openPanelMap) do
		self:ShowPanel(hideSource,uid)
    end
end

---HidePanel 隐藏UI面板（只关闭渲染，不影响lua逻辑）
---@param hideSource HIDE_PANELS_SOURCE_TYPE|string(uid) 隐藏面板的来源
---@param uid string 要隐藏的面板
function UIManager:HidePanel(hideSource, uid)
	local panel = self._openPanelMap[uid]
	if panel then
		local flagInfo = self._panelHideFlag[uid] or {sourceMap = {}, flagNum = 0}
		if not flagInfo.sourceMap[hideSource] then
			flagInfo.sourceMap[hideSource] = true
			flagInfo.flagNum = flagInfo.flagNum + 1
		end
		panel:Hide()
		self:UpdateWorldRendering()
		self._panelHideFlag[uid] = flagInfo
	end
end

---ShowPanel 显示被关闭的UI面板（与HidePanel对应）
---@param hideSource HIDE_PANELS_SOURCE_TYPE|string(uid) 隐藏面板的来源
---@param uid string 要重新显示的面板
function UIManager:ShowPanel(hideSource, uid)
	local flagInfo = self._panelHideFlag[uid]
	if flagInfo and flagInfo.sourceMap[hideSource] then
		flagInfo.sourceMap[hideSource] = nil
		flagInfo.flagNum = flagInfo.flagNum - 1
		if flagInfo.flagNum == 0 then
			local panel = self._openPanelMap[uid]
			panel:Show()
			self:UpdateWorldRendering()
			self:ResetInvalidationBox(panel)
		end
	end
end

---@public 关闭所有面板
---@param whiteList string[]
function UIManager:CloseAllPanel(whiteList)
    for k,_ in pairs(self._openPanelMap) do
		if UIPanelConfig.PanelConfig[k] then
			if not whiteList or (not table.contains(whiteList, k)) then
				self:ClosePanel(k, true)
				self._openPanelMap[k] = nil
			end
		end
    end
end

---@public 销毁所有面板
---@param whiteList string[]
function UIManager:DestroyAllPanel(whiteList)
	self:CloseAllPanel(whiteList)
	self._uiCachePool:ClearPanel()
end

---@public 检查面板是否打开
---@param uid string
function UIManager:CheckPanelIsOpen(uid)
    return self._openPanelMap[uid] ~= nil
end

---@public 是否UI处于纯净大厅状态，当前UI只有大厅的UI存在
function UIManager:IsPureLobby()
	for k, v in ipairs(self._openPanelMap) do
		if not table.contains(UIConst.LOBBY_UI, k) then
			return false
		end
	end
	return true
end

---public
---关闭UI并且把这个UI上面的UI也关闭
function UIManager:CloseAboveUI(uid)
	if self._openPanelMap[uid] then
		local uiList = {}
		for i = #self._openPanelStack, 1, -1 do
			local panel = self._openPanelStack[i]
			if panel.uid == uid then
				table.insert(uiList, panel)
				break
			end
            if UIConst.IgnoreAutoCloseUI[panel.uid] == nil then
			    table.insert(uiList, panel)
            end
		end
		for _, v in ipairs(uiList) do
			v:CloseSelf()
		end
	else
		Log.WarningFormat("NewUIManager:CloseAboveUI 尝试关闭一个没有打开的UI %s", uid)
	end
end

---@public 获取最上面的面板
function UIManager:GetTopUI()
	return self._openPanelStack[#self._openPanelStack]
end

---@public 检查面板是否是最上面的面板
function UIManager:CheckPanelIsTop(uid)
	local panel = self:GetTopUI()
	if not panel then
		return false
	end
	return panel.uid == uid
end

function UIManager:GetTopRenderUI()
	local panel
	for _,p in ipairs(self._openPanelStack) do
		if not panel then
			panel = p
		end
		if p.order > panel.order then
			panel = p
		end
	end
	return panel
end

---@public 检查堆栈里是否存在layout为layoutEnum的面板
function UIManager:CheckLayoutInStack(layoutEnum)
	if layoutEnum == nil then
		Log.Error("NewUIManager:CheckLayoutInStack layoutEnum is nil")
		return false
	end
	return self.layoutUIs[layoutEnum]:GetLength() > 0
end

--endregion

--region 面板管理内部实现
---@private 打开面板
---@param uid number 面板Id，必须填
---@param asyn boolean 是否异步加载 不填默认同步加载
function UIManager:internalOpenPanel(uid, asyn, ...)
    asyn = asyn or true
	if not Game.OpenPanelCheckSystem:CanOpen(uid) then
		Log.InfoFormat("UIFrame.NewUIManager: OpenPanelCheck No Pass %s ", uid)
		return
	end
	if self._loadingPanel[uid] then
		self._lastPanelParam[uid] = {...}
		Log.InfoFormat("UIFrame.NewUIManager: 打开正在打开的面板 %s", uid)
		return
	end
    Log.InfoFormat("UIFrame.NewUIManager: 请求打开面板 %s ", uid)
	self:clearPanelHideFlag(uid)

    if self:CheckPanelIsOpen(uid) then
        self:openExistPanel(uid, ...)
    else
        self:openNoExistPanel(uid, asyn, {...})
    end
end

---@private 重新打开一个面板
function UIManager:openNoExistPanel(uid, asyn, params)
    -- luacheck: push ignore
    local func = function(panel)
        if panel then
			if self._lastPanelParam[uid] then
				params = self._lastPanelParam[uid]
				self._lastPanelParam[uid] = nil
			end
            self:processPanelOpen(panel, false, unpack(params))
			if not panel.GetObjectNum then
				Log.ErrorFormat("UIFrame.NewUIManager:面板 %s GetObjectNum Is Nil", uid)
			end
            Log.InfoFormat("UIFrame.NewUIManager:面板 %s 已打开 uobjectNum:%s", uid, panel:GetObjectNum())
            Game.EventSystem:Publish(_G.EEventTypes.ON_UI_OPEN, panel.uid)
        end
    end

    self:getPanelFormPool(uid, func, asyn)
        -- luacheck: pop
end

---@private 打开已经打开的面板
function UIManager:openExistPanel(uid, ...)
    local panel = self._openPanelMap[uid]
    table.removeItem(self._openPanelStack, panel)
    self:processPanelOpen(panel, true, ...)
    Log.InfoFormat("UIFrame.NewUIManager:二次打开面板 %s ", uid)
	Game.EventSystem:Publish(_G.EEventTypes.ON_UI_OPEN, uid)
end

---@private 获取一个可用的panel,没有则创建新的
function UIManager:getPanelFormPool(uid, func, asyn)
	local panel = self._uiCachePool:PopPanel(uid)
    if panel then
		self:ResetInvalidationBox(panel)
        func(panel)
        return
    end
-- luacheck: push ignore
	local loadCallBack = function(res, preloadResMap)
		self._loadingPanel[uid] = nil
		self:createPanel(res, uid, func, preloadResMap)
	end
	self._loadingPanel[uid] = self:LoadPanelAsset(uid, loadCallBack, asyn)
-- luacheck: pop
end

---@private 创建面板脚本
function UIManager:createPanel(res, uid, func, preloadResMap)
	local widget = self:InstanceWidget(res, uid)
	local config = self:GetUIConfig(uid)
	self:AddPanelToRoot(widget, config.volatile)
	local scriptPath =  widget.LuaBinder.LuaPath
	local class = self:RequireUIClass(scriptPath)
	if class then
		local panel = self:CreateScript(class, uid, widget, widget, nil)
		panel:UpdateObjectNum(widget.UObjectNum)
		panel:setPreLoadResMap(preloadResMap)
		func(panel)
	end
end

---@private 真正处理打开面板逻辑
function UIManager:processPanelOpen(panel, isReOpen, ...)
	local uid = panel.uid
    self:processMutualUIOpen(uid)
    self._openPanelStack[#self._openPanelStack + 1] = panel
    self._openPanelMap[uid] = panel
	self:updateUILayoutInfo(uid, true)
    self:updateCanvasOrder(panel)
    panel:Show()
    if isReOpen then
        panel:ReOpen()
    else
        panel:Open()
    end
	panel:RefreshShowScene()
    panel:Refresh(...)
end

---@private 真正处理关闭面板的逻辑
---@param panel UIPanel
function UIManager:processPanelClose(panel)
	table.removeItem(self._openPanelStack, panel)
    local uid = panel.uid
	self:updateUILayoutInfo(uid, false)
    panel:Hide()
    panel:Close()
    self:processMutualUIClose(uid)
	self:processSceneUIClose(uid, panel)
	if _G.NoCacheUI then
		panel:Destroy()
	else
		self._uiCachePool:PushPanel(panel)
	end
	self._openPanelMap[uid] = nil
end

function UIManager:updateUILayoutInfo(uid, bOpen)
	local uiConfig = self:GetUIConfig(uid)
	local layout = uiConfig.layout
	if layout == nil then
		layout = Enum.EUILayout.Normal
	end
	local targetLayoutUI = self.layoutUIs[layout]
	if bOpen then
		if targetLayoutUI:GetValueByKey(uid) then
			targetLayoutUI:RemoveNodeByKey(uid)
		end
        if targetLayoutUI.listLength == 0 then
            if layout == Enum.EUILayout.FullScreen then
                Game.StateConflictManager:ForceSetState(Enum.EStateConflictAction.FullScreenUi)
            elseif layout == Enum.EUILayout.RightHalfScreen or layout == Enum.EUILayout.LeftHalfScreen then
                Game.StateConflictManager:ForceSetState(Enum.EStateConflictAction.NonFullScreenUi)
            end
        end
        targetLayoutUI:InsertNode(uid, uid)
	else
		targetLayoutUI:RemoveNodeByKey(uid)
        if targetLayoutUI.listLength == 0 then
            if layout == Enum.EUILayout.FullScreen then
                Game.StateConflictManager:RemoveState(Enum.EStateConflictAction.FullScreenUi)
            elseif layout == Enum.EUILayout.RightHalfScreen or layout == Enum.EUILayout.LeftHalfScreen then
                Game.StateConflictManager:RemoveState(Enum.EStateConflictAction.NonFullScreenUi)
            end
        end
	end
end

---@private更新面板层级
---@param panel UIPanel
function UIManager:updateCanvasOrder(panel)
    local config = self:GetUIConfig(panel.uid)
    if config.order then
        panel:SetCanvasOrder(config.order)
        return
    end
    panel:SetCanvasOrder(self:getNewCanvasOrder())
end

---@private 获取一个新的待用order
function UIManager:getNewCanvasOrder()
    if self._curCanvasOrder > UIConst.PANEL_ORDER_MAX then
        self:resetPanelOrder()
    end
    self._curCanvasOrder = self._curCanvasOrder + UIConst.PANEL_ORDER_SPACE
    return self._curCanvasOrder
end

---@private 重置面板深度
function UIManager:resetPanelOrder()
    self._curCanvasOrder = UIConst.PANEL_ORDER_MIN
    for _, panel in ipairs(self._openPanelStack) do
        self:updateCanvasOrder(panel)
    end
end

function UIManager:processMutualUIOpen(uid)
	if not self:GetTopUI() then return end
	
	local EUILayout = Enum.EUILayout
	local uiConfig = self:GetUIConfig(uid)
	if uiConfig.layout == EUILayout.LeftHalfScreen and self.layoutUIs[EUILayout.LeftHalfScreen]:GetLength() > 0 then
		local topLeftUID = self.layoutUIs[EUILayout.LeftHalfScreen]:GetTailNodeValue()
		if topLeftUID ~= uid then
			self:HidePanel(uid .. "_Mutex", topLeftUID)
		end
	elseif uiConfig.layout == EUILayout.RightHalfScreen and self.layoutUIs[EUILayout.RightHalfScreen]:GetLength() > 0 then
		local topRightUID = self.layoutUIs[EUILayout.RightHalfScreen]:GetTailNodeValue()
		if topRightUID ~= uid then
			self:HidePanel(uid .. "_Mutex", topRightUID)
		end
	elseif uiConfig.layout == EUILayout.FloatFullScreen and self.layoutUIs[EUILayout.FloatFullScreen]:GetLength() > 0 then
		local topFloatFullUID = self.layoutUIs[EUILayout.FloatFullScreen]:GetTailNodeValue()
		if topFloatFullUID ~= uid then
			self:HidePanel(uid .. "_Mutex", topFloatFullUID)
		end
	end
end

function UIManager:processMutualUIClose(uid)
	if not self:GetTopUI() then return end
	
	local EUILayout = Enum.EUILayout
	local uiConfig = self:GetUIConfig(uid)
	if uiConfig.layout == EUILayout.LeftHalfScreen or uiConfig.layout == EUILayout.RightHalfScreen or uiConfig.layout == EUILayout.FloatFullScreen then
		self:RestoreAllPanel(uid .. "_Mutex")
	end
end

function UIManager:processSceneUIClose(uid, beClosePanel)
	local config = self:GetUIConfig(uid)
	if not config or not (config.scenename ~= nil or (beClosePanel and beClosePanel.sceneComponent))then
		return
	end
	local ids = {}
	for i = #self._openPanelStack, 1, -1 do
		local panel = self._openPanelStack[i]
		table.insert(ids, panel.uid)
		if panel and panel.sceneComponent then
			local sceneComponent = panel.sceneComponent
			config = self:GetUIConfig(panel.uid)
			sceneComponent:Refresh(sceneComponent.sceneName, false, false)
			break
		end
	end
end

--- 清除隐藏这个面板的标记，如果被标记隐藏了，然后又再次打开了，就会从恢复列表异常
---@private
---@param uid number 面板Id
function UIManager:clearPanelHideFlag(uid)
    self._panelHideFlag[uid] = nil
end

---@private 停止正在异步加载的面板
---@param uid string
function UIManager:stopLoadingPanel(uid)
	if self._loadingPanel[uid] then
		self._loadingPanel[uid] = nil
		self._lastPanelParam[uid] = nil
		return true
	end
	return false
end

---@public
function UIManager:UpdateWorldRendering()
	local enableSceneRender = true

	local targetLayoutUI = self.layoutUIs[Enum.EUILayout.FullScreen]
	local fullUICount = targetLayoutUI:GetLength()
	if fullUICount > 0 then
		local panelNode = targetLayoutUI.tailNode
		while(panelNode) do
			---@type UIPanel
			local panel = self._openPanelMap[panelNode.Value]
			if (not panel:IsOpening() and not panel:IsClosing() and panel:IsShow() and panel.sceneComponent == nil) then
				enableSceneRender = false
				break
			end
			panelNode = panelNode.Prev
		end
	end
	if self._enableSceneRender ~= enableSceneRender then
		self._enableSceneRender = enableSceneRender
		UE.GameplayStatics.SetEnableWorldRendering(_G.GetContextObject(), self._enableSceneRender)
	end
end

function UIManager:IsFullScreenUIOpen()
	return self:CheckLayoutInStack(Enum.EUILayout.FullScreen)
end
--endregion

--region 面板缓存
function UIManager:PopComponentByCellId(cellId)
	return self._uiCachePool:PopComponent(cellId)
end

function UIManager:PopComponentByWidgetType(widgetType)
	return self._uiCachePool:PopListComponent(widgetType)
end

function UIManager:PushComponent(component)
	if component:HasCellId() then
		self._uiCachePool:PushComponent(component)
	else
		self._uiCachePool:PushListComponent(component.userWidget:GetClass(), component)
	end
end
--endregion

--region 性能数据检测
function UIManager:OnMemoryWarning()
	self:DebugInfo()
end

---获取单个面板对象数
---@param uid string
function UIManager:GetObjectNum(uid)
	local panel = self._openPanelMap[uid]
	if panel then
		return panel:GetObjectNum()
	end
	return 0
end

---获取所有UI对象数
function UIManager:GetAllObjectNum()
	local num = 0
	for _,v in ipairs(self._openPanelStack) do
		num = num+ v:GetObjectNum()
	end
	num = num+ self._uiCachePool:GetObjectNum()
	return num
end

--endregion

--region ESC 关闭UI
function UIManager:ExecuteExitAction()
	if self:checkESCEnabled() then
		return
	end
	local panel = self._openPanelStack[#self._openPanelStack]
	if self:GetUIConfig(panel.uid).CanBeEsc then
		panel:CloseSelf()
	end
end

function UIManager:SetEnableESC(bEnable)
	self._bEnableEsc = bEnable
end

function UIManager:checkESCEnabled()
	if Game.PopupManager:CheckPoupShowing() then
		return false
	end

	return not self._bEnableEsc
end

--endregion

--region 辅助函数
function UIManager:CreateScript(script, uid, userWidget, widget, parentScript, ...)
	if not script then
		local config = self:GetUIConfig(uid)
        Log.ErrorFormat("NewUIManager.CreateScript@%s 创建lua失败 Script is Nil %s", config.auth or "no auth",debug.traceback())
		return
	end
	local  ui
	if script.bIsOldUI then
		_, ui = xpcall(script.new,_G.CallBackError, nil, uid, userWidget, widget, parentScript, ...)
	else
		_, ui = xpcall(script.new,_G.CallBackError, uid, userWidget, widget, parentScript, ...)
	end
	return ui
end

function UIManager:RequireUIClass(scriptPath)
    if string.isEmpty(scriptPath) then
        Log.ErrorFormat("UIFrame.NewUIManager.RequireUIClass scriptPath is nil")
        return
    end
	--todo 等待优化保持两边路径一致
	scriptPath = string.gsub(scriptPath, "/", ".")
    local _, uiClass = xpcall(kg_require, _G.CallBackError, scriptPath)
	return uiClass
end

function UIManager:InstanceWidget(res, uid)
	local baseType = getmetatable(res)
	if baseType and baseType.__name == "UClass" then
		if not UE.KismetSystemLibrary.IsValidClass(res) then
			Log.ErrorFormat("UIFrame.NewUIManager.InstanceWidget IsValidClass, %s", debug.traceback())
			return
		end
		local widget = nil
		if uid then
			widget = UIFunctionLibrary.CreateWidgetWithName(_G.GetContextObject(), res, uid)
		else
			widget = UE.WidgetBlueprintLibrary.Create(_G.GetContextObject(), res)
		end
		if not IsValid_L(widget) then
			Log.ErrorFormat("UIFrame.NewUIManager.Create ui %s failed 资源加载失败", debug.traceback())
			return
		end
		return widget
	else
		Log.ErrorFormat("UIFrame.NewUIManager:InstanceWidget Error ClassType:%s, %s", baseType.__name, debug.traceback())
	end
end

function UIManager:AddPanelToRoot(widget, volatile)
	if widget then
		self.uiRoot:AddChildToLayer(UIConst.CANVAS_TYPE.NORMAL_UI, widget,  _G.InvalidationBox and not volatile)
	end
end

function UIManager:AddChildToCanvas(widget, root)
	if root:IsA(UE.CanvasPanel) then
		local slot = root:AddChildToCanvas(widget)
		local NewAnchors = UE.Anchors()
		NewAnchors.Minimum = FVector2D(0, 0)
		NewAnchors.Maximum = FVector2D(1, 1)
		slot:SetAnchors(NewAnchors)
		slot:SetOffsets(UE.Margin(0, 0, 0, 0))
	else
		root:AddChild(widget)
	end
end

function UIManager:GetUIConfig(uid)
	if not self._uiConfigCache[uid] then
		local getCfgMeta = {
			__index = function(tb, key)
				local ui = rawget(tb, "__ui")
				if key == "class" then
					return ui
				end
				local config = Game.UIConfig[ui] or UIPanelConfig.PanelConfig[ui]
				local value = config and config[key]
				if not value then
					local cfg = Game.TableData.GetUIDataRow(ui)
					if cfg then
						value = cfg[key]
					end
				end
				return value
			end
		}
		self._uiConfigCache[uid] = setmetatable({ __ui = uid }, getCfgMeta)
	end
	return self._uiConfigCache[uid]
end

--endregion

function UIManager:GetUICachePool()
	return self._uiCachePool
end

--todo start 临时实现点击空白处关闭界面逻辑
function UIManager:OnC7TouchEvent(ui, Geometry, InMouseEvent)
	self:ManualHideAutoCloseUI(ui)
	local ScreenPos = KismetInputLibrary.PointerEvent_GetScreenSpacePosition(InMouseEvent)
	Game.EventSystem:Publish(_G.EEventTypes.On_TOUCHSTART, ScreenPos)
	Game.EventSystem:Publish(_G.EEventTypes.On_ClickEffect, ScreenPos)
	return true
end

function UIManager:ManualHideAutoCloseUI(ui)
	local panel = self._openPanelStack[#self._openPanelStack]
	local config = self:GetUIConfig(panel.uid)
	if config.autoclose then
		if ui and ui == panel then
			return
		end
		panel:CloseSelf()
	end
end
--end 临时实现点击空白处关闭界面逻辑

function UIManager:OnViewportResized(resX, resY)
	Game.UIManager:OnViewportResized(resX, resY)
	if self._openPanelMap then
		Game.TimerManager:CreateTimerAndStart(function ()
			for _, v in pairs(self._openPanelMap) do
				self:ResetInvalidationBox(v)
			end
		end, 30, 1)
	end
	Game.EventSystem:Publish(EEventTypes.ON_VIEWPORT_RESIZED, resX, resY)
	self._bViewportResized = true
end

function UIManager:ResetInvalidationBox(uiPanel)
	if _G.InvalidationBox then
		local config = self:GetUIConfig(uiPanel.uid)
		if not config.volatile then
			UIFunctionLibrary.SetCanCache(uiPanel.userWidget)
		end
	end
end

--region 异形屏数据读取
function UIManager:initScreenData()
	self.CurrentPlatform = UIFunctionLibrary.GetDeviceTypeName() or "WindowsEditor"
	
	local res = slua.loadObject("/Game/Editor/UserWidgetPreview/DT_PlatformScreenOffset.DT_PlatformScreenOffset")
	self.PlatformScreenOffset = {}
	if IsValid_L(res) then
		local success,jsonStr = DataTableFunctionLibrary.ExportDataTableToJSONString(res,"")
		if success then
			for _,value in pairs(json.decode(jsonStr)) do
				self.PlatformScreenOffset[value.Name] = value.AdaptOffset
			end
		end
	end

	Log.InfoFormat("UIFrame.NewUIManager:CurrentPlatform  %s", self.CurrentPlatform)
end

function UIManager:GetPlatformAdaptOffset(name)
	if not name then
		return self.PlatformScreenOffset[self.CurrentPlatform] or 0
	end
	return self.PlatformScreenOffset[name] or 0
end
--endregion

--region 移动端SceneCapture
function UIManager:InitSceneCapture()
	if not self.SceneCapture then
		self.SceneCapture = UIFunctionLibrary.CreateSceneCapture2DActor(slua.getWorld())
	end
end

function UIManager:CaptureSceneForBackGroundBlur(ImageWidget)
	if not self.SceneCapture then
		self:InitSceneCapture()
	end
	-- 缓存的相机Location + inRotation
	local Location = Game.CameraManager.CameraCachePrivate.POV.Location
	local Rotation = Game.CameraManager.CameraCachePrivate.POV.Rotation
	local CaptureResult = UIFunctionLibrary.CaptureBlurImage(self.SceneCapture, ImageWidget, Location, Rotation)
	if not CaptureResult then
		Log.Error("NewUIManager.CaptureSceneForBackGroundBlur 截帧失败")
		return
	end
	-- 截帧成功，关闭WorldRendering
	UE.GameplayStatics.SetEnableWorldRendering(_G.GetContextObject(), false)
end

--endregion

--region 处理NiagaraSystemWidget跨场景重置
function UIManager:ResetNiagaraSystemWidgets()
	local system = SubsystemBlueprintLibrary.GetGameInstanceSubsystem(
		_G.GetContextObject(), NiagaraUISubSystem
	)
	system:ReInitializeAllNiagaraWidgets()
end
--endregion

--region 调试函数
function UIManager:DebugInfo()
	local statusLog = ""
	local errorLog = ""
	local panelLog = ""

	statusLog = string.format("%s \n UObject Total:%s ", statusLog, self:GetAllObjectNum())

	for i,v in ipairs(self._openPanelStack) do
		panelLog = string.format("%s\n uid:%s,  index:%s,  order:%s,  isOpen:%s,  isShow:%s, objectNum:%s",panelLog, v.uid,i,v.order, v:IsOpened(), v:IsShow(), v:GetObjectNum())
	end

	local log = string.format("*****ErrorLog*****\n%s  \n\n*****StatusLog*****\n%s  \n\n******PanelLog*******\n%s ", errorLog, statusLog,panelLog)
	return log
end
--endregion
return UIManager
