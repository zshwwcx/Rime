--todo 不走全局变量访问 都走局部变量访问
require("Framework.UI.UI")
require("Framework.UI.UIBase")
require("Framework.UI.UIView")
require("Framework.UI.UIComponent")
require("Framework.UI.UIController")
require("Framework.UI.List.ListComponents.ListAnimationLibrary")
require("Framework.UI.BaseList")
require("Framework.UI.ListView2")
require("Framework.UI.ComList")
require("Framework.UI.DiffList")
require("Framework.UI.NewDiffList")
require("Framework.UI.GroupView")
require("Framework.UI.UIHelper")
require("Framework.UI.TreeList")
require("Framework.UI.PageList")
require("Framework.UI.ITreeListComponent")
require("Framework.UI.IrregularListView")
require("Framework.UI.ListItemBase")

local KismetInputLibrary = import("KismetInputLibrary")
local UIFunctionLibrary = import("UIFunctionLibrary")
local CanvasPanel = import("CanvasPanel")
local Anchors = import("Anchors")
local Margin = import("Margin")

local CanvasPanelSlot = import("CanvasPanelSlot")

---@class UIManager : ManagerBase
---@field GetInstance UIManager
local UIManager = DefineSingletonClass("UIManager", ManagerBase, LoaderComponent)

--region 初始化
function UIManager:onCtor()
	self:initData()
	self.staticCachePanel = Cache.new(100) --设大点，避免push时超上限
	self.dynamicCachePanel = Cache.new(4)
	self._warmPanelResMap = {}	--存储warm ui的资源
	self.dynamicCacheLib = {}
	-- LibMap是name->WidgetInstance的映射，同一个name只有一个Widget对象，不会同时持有多个
	self.LibMap = {}

	self.uiTreeTb = {} --用于getUI时缓存数据
	self._loadingPanel = {} --当前正在加载的UI
	self._lastPanelParam = {}  --面板最后一次打开传入的参数
end

function UIManager:initData()
    ---@type table<number, UIPanel>
	self._idleUI = {}
end

function UIManager:onDestroy()
	self:delete()
end

function UIManager:StartUp()
	if self._bInitialized then
		return
	end
	Game.NewUIManager:StartUp()
	-- initRoot处理libCanvas挂载，这里可以干掉了，UI_CACHE不需要挂载到UI_PANEL上，直接在UIManager上用一个lua table持有住即可
	self:initRoot()
	self._bInitialized = true
end

function UIManager:initRoot()
	self.libCanvas = Game.NewUIManager.uiRoot:CreateCanvas(UIConst.CANVAS_TYPE.UI_CACHE)
	UIHelper.SetActive(self.libCanvas, false)
	-- self:LoadRes("/Game/Arts/UI_2/Blueprint/Lib/WBP_Lib.WBP_Lib_C", function(res) self:onLibLoadFinish(res) end)
end

function UIManager:GetUIRoot()
	return Game.NewUIManager.uiRoot
end

function UIManager:onLibLoadFinish(res)
	local baseType = getmetatable(res)
	if baseType and baseType.__name == "UClass" and import("KismetSystemLibrary").IsValidClass(res) then
		local widget = import("WidgetBlueprintLibrary").Create(_G.GetContextObject(), res)
		if not widget or not IsValid_L(widget) then
			Log.ErrorFormat("UIFrame:UIManager: Create ui %s failed WBP_Lib 资源加载失败")
			return
		end
		Game.NewUIManager.uiRoot:AddChildToLayer(UIConst.CANVAS_TYPE.UI_CACHE, widget, false)
		self.libui = setmetatable({ WidgetRoot = widget}, UIView._rootMeta)
	else
		Log.ErrorFormat("UIFrame:UIManager:加载了一个错误的UI资源类型 WBP_Lib")
	end
end
--endregion

--region 对外接口

function UIManager:ShowUI(uid, b, ...)
	local idx = UI.GetCfg(uid)
	if idx.parent then
		if b then
			local ui = self:getUI(uid)
			if ui then
				ui:Show(...)
				ui:Refresh(...)
				return
			end
			self:OpenChildPanel(uid, ...)
		else
			self:CloseChildPanel(uid)
		end
	else
		if b then
			self:OpenPanel(uid, {...}, true,nil,nil)
		else
			self:ClosePanel(uid, false)
		end
	end
end

---打开面板
---@param uid number 面板Id，必须填
---@param params table 面板打开默认参数，没有可不填
---@param bAsync boolean 是否异步加载 不填默认同步加载
---@param callback fun(param:UIPanel) 异步加载回调 没有需要可以不填
---@param immediately boolean 是否不播放open动画立刻打开，
function UIManager:OpenPanel(uid, params, bAsync, callback, immediately)
	if UIPanelConfig.PanelConfig[uid] then
		Game.NewUIManager:OpenPanel(uid, unpack(params or {})) -- todo 临时兼容旧框架打开新系统
		return
	end
	if not Game.OpenPanelCheckSystem:CanOpen(uid) then
		Log.InfoFormat("UIFrame:UIManager: OpenPanelCheck No Pass %s ", uid)
		return
	end
	if self._loadingPanel[uid] then
		self._lastPanelParam[uid] = params
		Log.InfoFormat("UIFrame.NewUIManager: 打开正在打开的面板 %s", uid)
		return
	end
    Log.InfoFormat("UIFrame:UIManager: 请求打开面板 %s ", uid)
	self:clearPanelHideFlag(uid)

    if self:CheckPanelIsOpen(uid) then
        self:openExistPanel(uid, params, callback, immediately)
    else
        self:openNoExistPanel(uid, params, callback, bAsync, immediately)
    end
end

---关闭面板
---@param uid number
---@param immediate boolean 是否立刻关闭，不播放动画
function UIManager:ClosePanel(uid, immediate)
	if UIPanelConfig.PanelConfig[uid] then
		Game.NewUIManager:ClosePanel(uid, immediate)
		return
	end
	self:removeIdle(uid)
	if self:stopLoadingPanel(uid) then
		return
	end
	if not self:CheckPanelIsOpen(uid) then --UI没打开或者还在打开过程中（会被取消打开过程）
		return
	end
	local panel = self:getOpenPanelMap()[uid]
	if panel._isClosing then
		return --正在关闭中，不能再调用关闭
	end
	Log.InfoFormat("UIFrame:UIManager:请求关闭界面 %s", uid)
    -- luacheck: push ignore
    local closeFinishCallback = function()
        self:processPanelClose(panel)
		Game.EventSystem:Publish(_G.EEventTypes.ON_UI_CLOSE, uid)
        Log.InfoFormat("UIFrame:UIManager:关闭界面 %s", uid)
    end
	self:clearPanelHideFlag(uid)
	if panel.PreClose == nil then
		Log.ErrorFormat("UIFrame:UIManager panel %s  %s PreClose is nil isDestroy %s", panel.uid, panel.__cname, panel.destroyed)
	end
    panel:PreClose(immediate, closeFinishCallback)
	    -- luacheck: pop
end

---@private 停止正在异步加载的面板
---@param uid string
function UIManager:stopLoadingPanel(uid)
	if self._loadingPanel[uid] then
		self:CancelTargetLoad(self._loadingPanel[uid])
		self._loadingPanel[uid] = nil
		self._lastPanelParam[uid] = nil
		return true
	elseif self._warmPanelResMap[uid] and self._warmPanelResMap[uid].CallBack then
		self._warmPanelResMap[uid].CallBack = nil
		return true
	end
	return false
end

function UIManager:WarmPanel(uid)
	if _G.NoCacheUI or self:CheckPanelIsOpen(uid) or self.staticCachePanel:contain(uid) or self.dynamicCachePanel:contain(uid) or self._warmPanelResMap[uid] then
		return
	end
	local config = UI.GetCfg(uid)
	if not config then
		return
	end
	Log.InfoFormat("UIFrame:UIManager:预加载面板 %s", uid)
	self._warmPanelResMap[uid] = {}
	-- luacheck: push ignore
	local func = function(res, preloadResMap)
		self._warmPanelResMap[uid].LoadID = nil
		if IsValid_L(res) then
			if self._warmPanelResMap[uid].CallBack then --说明warm的UI需要打开, 直接调用回调，不需要在保存资源
				self._warmPanelResMap[uid].CallBack(res, preloadResMap)
				self._warmPanelResMap[uid] = nil
			else
				self._warmPanelResMap[uid].PanelRes = res
				self._warmPanelResMap[uid].PreloadResMap = preloadResMap
			end
		end
	end
	local loadID = self:LoadOldUIPanelAsset(uid, func, true)
	if loadID then
		self._warmPanelResMap[uid].LoadID = loadID
	end
	-- luacheck: pop
end

--todo 删除 临时兼容旧版本
function UIManager:OpenChildPanel(uid, ...)
	local panel = self:GetParentScript(uid)
	if panel then
		panel:LoadChildPanel(uid, nil, ...)
	else
		Log.ErrorFormat("UIManager:添加子控件%s，但是依赖的父面板不存在", uid)
	end
end

--todo 删除 临时兼容旧版本
function UIManager:CloseChildPanel(uid)
	local panel = self:GetParentScript(uid)
	if panel then
		panel:RemoveChildPanel(uid)
	else
		Log.ErrorFormat("UIManager:删除子控件%s，但是依赖的父面板不存在", uid)
	end
end

--todo 删除 临时兼容旧版本
function UIManager:GetParentScript(uid)
	local config = UI.GetCfg(uid)
	local tree = {}
	while(config.parentui) do
		config = UI.GetCfg(config.parentui)
		table.insert(tree, 1, config)
	end
	local parent
	for k, v in ipairs(tree) do
		if k == 1 then
			parent = self:getOpenPanelMap()[v.__ui]
		else
			if parent then
				parent = parent:GetChildComponent(v.__ui)
			end
		end
	end
	return parent
end

function UIManager:GetBelongPanel(uid)
	local config = self:GetUIConfig(uid)
	local tree = {}
	table.insert(tree, 1, config)
	while(config.parentui) do
		table.insert(tree, 1, config.parentui)
		config = self:GetUIConfig(config.parentui)
	end
	return self:getOpenPanelMap()[tree[1]]
end

---隐藏一些普通UI HIDE_ALL_WHITE_LIST 这些白名单UI不隐藏
---@field ui UIController
function UIManager:HideNormalFormPanel(uid)
	Game.NewUIManager:HideNormalFormPanel(uid)
end

---恢复显示一些普通 和 HideNormalFormPanel 成对调用
---@field ui UIController
function UIManager:RestoreNormalFormPanel(uid)
	self:RestoreAllPanel(uid)
end

---隐藏现有的面板，结束之后需要调用 RestoreAllPanel 恢复
---@param hideType HIDE_PANELS_SOURCE_TYPE 隐藏面板的来源
---@param whiteList string[] 白名单列表，白名单的面板不隐藏
function UIManager:HideAllPanel(hideSource, whiteList)
	Game.NewUIManager:HideAllPanel(hideSource, whiteList)
end

---恢复之前隐藏的UI面板 需要和HideAllPanel接口保持成对的调用
---@param hideSource HIDE_PANELS_SOURCE_TYPE|string(uid) 隐藏面板的来源
function UIManager:RestoreAllPanel(hideSource)
	Game.NewUIManager:RestoreAllPanel(hideSource)
end

---HidePanel 隐藏UI面板（只关闭渲染，不影响lua逻辑）
---@param hideSource HIDE_PANELS_SOURCE_TYPE|string(uid) 隐藏面板的来源
---@param uid string 要隐藏的面板
function UIManager:HidePanel(hideSource, uid)
	Game.NewUIManager:HidePanel(hideSource, uid)
end

---ShowPanel 显示被关闭的UI面板（与HidePanel对应）
---@param hideSource HIDE_PANELS_SOURCE_TYPE|string(uid) 隐藏面板的来源
---@param uid string 要重新显示的面板
function UIManager:ShowPanel(hideSource, uid)
	Game.NewUIManager:ShowPanel(hideSource, uid)
end

---检查面板是否打开
function UIManager:CheckPanelIsOpen(uid)
    return self:getOpenPanelMap()[uid] ~= nil
end

---关闭所有面板
function UIManager:CloseAllPanel(whiteList)
	for uid, _ in pairs(self._loadingPanel) do
		if not whiteList or (not table.contains(whiteList, uid)) then
			self:stopLoadingPanel(uid)
		end
	end
    for k,v in pairs(self:getOpenPanelMap()) do
		if Game.UIConfig[k] then
			if not whiteList or (not table.contains(whiteList, k)) then
				self:ClosePanel(k, true)
				self:getOpenPanelMap()[k] = nil
			end
		elseif UIPanelConfig.PanelConfig[k] then
			if not whiteList or (not table.contains(whiteList, k)) then
				Game.NewUIManager:ClosePanel(k, true)
				self:getOpenPanelMap()[k] = nil
			end
		end
    end
end

---销毁所有面板
function UIManager:DestroyAllPanel(whiteList)
	self:CloseAllPanel(whiteList)
end

function UIManager:OnC7TouchEvent(ui, Geometry, InMouseEvent)
	self:ManualHideAutoCloseUI(ui)
	local ScreenPos = KismetInputLibrary.PointerEvent_GetScreenSpacePosition(InMouseEvent)
	Game.EventSystem:Publish(_G.EEventTypes.On_TOUCHSTART, ScreenPos)
	Game.EventSystem:Publish(_G.EEventTypes.On_ClickEffect, ScreenPos)
	return true
end

function UIManager:ManualHideAutoCloseUI(ui)
	if ui and ui:IsComponent() then
		ui = self:getOpenPanelMap()[ui.panelUID]
	end
	local panel = self:GetOpenPanelStack()[#self:GetOpenPanelStack()]
	local config = self:GetUIConfig(panel.uid)
	if config.autoclose then
		if ui and ui == panel then
			return
		end
		panel:CloseSelf()
	end
end

function UIManager:ExecuteExitAction()
	Game.NewUIManager:ExecuteExitAction()
end

---public
---关闭UI并且把这个UI上面的UI也关闭
function UIManager:CloseAboveUI(uid)
	return Game.NewUIManager:CloseAboveUI(uid)
end

--获取最上面的面板
function UIManager:GetTopUI()
	return Game.NewUIManager:GetTopUI()
end

--检查面板是否是最上面的面板
function UIManager:CheckPanelIsTop(uid)
	return Game.NewUIManager:CheckPanelIsTop(uid)
end

--检查堆栈里是否存在layout为layoutEnum的面板
function UIManager:CheckLayoutInStack(layoutEnum)
	return Game.NewUIManager:CheckLayoutInStack(layoutEnum)
end


-- 新建的LibWidget Instance持有对象为对应的UserWidget，它的生命周期管理会跟着父UI走，不会被UIManager持有
function UIManager:CreateLibUIWidget(name, container, OwnerWidget)
	local widget = self.LibMap[name]
	if not widget then
		Log.Error("[UIManager_CreateLibUIWidget2] UIManager中没有名字为"..name.."的Lib对象实例")
		return
	end
	---- TODO:后续关注下这边的开销， 如果开销比较高的话，这里考虑直接放到C++去处理

	-- -- -- 测试同步加载
	-- -- local LibWidgetConfig = kg_require("Framework.UI.LibWidgetConfig")
	-- -- local widgetClass = slua.loadClass(LibWidgetConfig[name])
	-- -- 根据widgetClass创建出对应的widgetInstance
	-- local widget = UIFunctionLibrary.CreateWidgetWithName(_G.GetContextObject(), widgetClass, 0)

	local newWidget = UIFunctionLibrary.C7CreateWidget(OwnerWidget, container, widget)
	-- 挂载到container上面取
	local slot = container:AddChild(newWidget)
	if slot and slot:IsA(CanvasPanelSlot) then
		-- 确保slot是一个CanvasPanelSlot，它有SetAnchors
		-- 设置一下四角拉伸
		local NewAnchors = UE.Anchors()
		NewAnchors.Minimum = FVector2D(0, 0)
		NewAnchors.Maximum = FVector2D(1, 1)
		slot:SetAnchors(NewAnchors)
		slot:SetOffSets(UE.Margin())
	end
	
	return newWidget
end

--todo 不在面板提供update接口 如果要使用 则使用定时器
function UIManager:CallIdles(e)
	local panels = self._idleUI
	for _, panel in next, panels do
		if panel.OnIdle then
			panel:OnIdle(e)
		end
	end
end

function UIManager:addIdle(ui)
	if ui.OnIdle then
		self._idleUI[ui.uid] = ui
	end
end

function UIManager:removeIdle(uid)
	if self._idleUI[uid] then
		self._idleUI[uid] = nil
	end
end

function UIManager:OnIdle(e)
	local luaProfiler <close> = Game.ProfilerInstrumentation:Start(ProfilerInstrumentationConfig.UITick.name) -- 代码插桩统计
	self:CallIdles(e)
end

--重置刷新尺寸
function UIManager:OnResize()
	for _, v in pairs(self:getOpenPanelMap()) do
		if v.OnResize then
			v:OnResize()
		end
	end
end

function UIManager:OnMemoryWarning()
	self:ClearCache()
end

function UIManager:OnObjectCountNearlyExceed(currentObjectCount)
	self:ClearCache()
end

function UIManager:ClearCache(bIgnoreStatic)
	self.dynamicCachePanel:Clear()
    if not bIgnoreStatic then
        self.staticCachePanel:Clear()
	end
	
	for libName, libList in pairs(self.dynamicCacheLib) do
		for _, widget in pairs(libList) do
			widget:RemoveFromParent()
		end
	end
	table.clear(self.dynamicCacheLib)
end

function UIManager:ClearWarmUI()
	for i, v in pairs(self._warmPanelResMap) do
		if v.LoadID then
			self:CancelTargetLoad(v.LoadID)
			self._warmPanelResMap[i] = nil
		end
	end
	table.clear(self._warmPanelResMap)
end

---获取UI对象数
function UIManager:GetObjectNum(name)
	Game.NewUIManager:GetObjectNum(name)
end

---获取所有UI对象数
function UIManager:GetAllObjectNum()
	Game.NewUIManager:GetAllObjectNum()
end

---获取平台适配的偏移量
function UIManager:GetPlatformAdaptOffset(name)
	return Game.NewUIManager:GetPlatformAdaptOffset(name)
end

---打印所有UI对象数
function UIManager:PrintAllObjectNum()
	Game.NewUIManager:PrintAllObjectNum()
end

--是否UI处于纯净大厅状态，当前UI只有约定的UI存在
function UIManager:IsPureLobby()
	Game.NewUIManager:IsPureLobby()
end

function UIManager:CheckESCEnabled()
	Game.NewUIManager:CheckESCEnabled()
end

function UIManager:SetEnableESC(bEnable)
	Game.NewUIManager:SetEnableESC(bEnable)
end

--endregion

--region ui管理内部实现
---重新打开一个面板
function UIManager:openNoExistPanel(uid, params, callback, async, immediately)
	local panel = self.staticCachePanel:pop(uid) or self.dynamicCachePanel:pop(uid)
	if panel then
		xpcall(self.processPanelOpen, _G.CallBackError, self, panel, params, immediately)
		if callback then
			xpcall(callback, _G.CallBackError, panel)
		end
		return
	end

	-- luacheck: push ignore
	local func = function(panelRes, preloadResMap)
		self._loadingPanel[uid] = nil
		panel = self:CreatePanel(panelRes, uid, preloadResMap)
		if panel then
			if self._lastPanelParam[uid] then
				params = self._lastPanelParam[uid]
				self._lastPanelParam[uid] = nil
			end
			xpcall(self.processPanelOpen, _G.CallBackError, self, panel, params, immediately)
			if callback then
				xpcall(callback, _G.CallBackError, panel)
			end
		end
	end
	-- luacheck: pop
	if self._warmPanelResMap[uid] then
		if self._warmPanelResMap[uid].LoadID then --warm的资源还没加载成功
			self._warmPanelResMap[uid].CallBack = func
		else
			func(self._warmPanelResMap[uid].PanelRes, self._warmPanelResMap[uid].PreloadResMap)
		end
	else
		self._loadingPanel[uid] = self:LoadOldUIPanelAsset(uid, func, async)
	end
end

---打开已经打开的面板
function UIManager:openExistPanel(uid, params, callback, immediately)
    local panel = self:getOpenPanelMap()[uid]
	table.removeItem(self:GetOpenPanelStack(), panel)
	self:processPanelOpen(panel, params, immediately, true)
    if callback then
        callback(panel)
    end
	Game.EventSystem:Publish(_G.EEventTypes.ON_UI_OPEN, panel.uid)
	Log.InfoFormat("UIFrame:UIManager:二次打开面板 %s ", uid)
end

---真正处理打开面板逻辑
function UIManager:processPanelOpen(panel, params, immediately, isReOpen)
	local uid = panel.uid
	self:processMutualUIOpen(uid)
    self:GetOpenPanelStack()[#self:GetOpenPanelStack() + 1] = panel
	Game.NewUIManager:updateUILayoutInfo(uid, true)
    self:getOpenPanelMap()[uid] = panel
    self:updateCanvasOrder(panel)
	panel:Show()
	if isReOpen then
		if immediately == nil then
			immediately = not panel._isClosing --_isClosing为true说明界面正在关闭中，需要重新播放下入场动画，否则UI显示状态可能不对
		end
		panel:ReOpen(params, immediately)
	else
		panel:Open(params, immediately)
	end
	panel:Refresh(unpack(params or {}))
	self:addIdle(panel)
	Log.InfoFormat("UIFrame:UIManager:面板 %s 已打开 UObject Num %s", uid, panel:GetObjectNum())
	Game.EventSystem:Publish(_G.EEventTypes.ON_UI_OPEN, uid)
end

--- 真正处理关闭面板的逻辑
function UIManager:processPanelClose(panel)
	local uid = panel.uid
    table.removeItem(self:GetOpenPanelStack(), panel)
	Game.NewUIManager:updateUILayoutInfo(uid, false)
    self:getOpenPanelMap()[uid] = nil
    local config = panel:getUIConfig()
	if not _G.NoCacheUI then
		if config.cache then
			self.staticCachePanel:push(uid, panel)
		else
			self.dynamicCachePanel:push(uid, panel)
		end
	end
	panel:Hide()
	panel:Close()
	if _G.NoCacheUI then
		self:destroyPanel(panel)
	end
	self:processMutualUIClose(uid)
	self:processSceneUIClose(uid)
end

function UIManager:CacheLibComponent(name, widget)
	if _G.NoCacheUI then
		widget:RemoveFromParent() --不缓存的话需要Remove下，因为在Destroy函数里没有调
		return
	end
	if not self.dynamicCacheLib[name] then
		self.dynamicCacheLib[name] = {}
	end
	local itemLibList = self.dynamicCacheLib[name]
	if #itemLibList >= 15 then
		widget:RemoveFromParent()
		return
	else
		itemLibList[#itemLibList + 1] = widget
		UIHelper.SetActive(widget, false)
		UIFunctionLibrary.AddChild(self.libCanvas, widget)
	end
end

function UIManager:GetLibComponent(name, container, ownerWidget)
	local itemLibList = self.dynamicCacheLib[name]
	if itemLibList then
		local length = #itemLibList
		if length > 0 then
			local widget = itemLibList[length]
			itemLibList[length] = nil
			local slot = container:AddChild(widget)
			if slot and slot:IsA(CanvasPanelSlot) then
				-- 确保slot是一个CanvasPanelSlot，它有SetAnchors
				-- 设置一下四角拉伸
				local NewAnchors = UE.Anchors()
				NewAnchors.Minimum = FVector2D(0, 0)
				NewAnchors.Maximum = FVector2D(1, 1)
				slot:SetAnchors(NewAnchors)
				slot:SetOffSets(UE.Margin())
			end
			return widget
		end
	end
	return self:CreateLibUIWidget(name, container, ownerWidget)
end

---更新面板层级
---@param panel UIController
function UIManager:updateCanvasOrder(panel)
	return Game.NewUIManager:updateCanvasOrder(panel)
end

---获取一个新的待用order
function UIManager:getNewCanvasOrder()
	return Game.NewUIManager:getNewCanvasOrder()
end

---重置面板深度
function UIManager:resetPanelOrder()
	Game.NewUIManager:resetPanelOrder()
end

function UIManager:CreatePanel(panelRes, uid, preloadResMap)
	local config = self:GetUIConfig(uid)
	local widget = UIFunctionLibrary.CreateWidgetWithName(_G.GetContextObject(), panelRes, uid)
	if not widget or not IsValid_L(widget) then
		Log.ErrorFormat("UILoader Create ui %s failed 资源加载失败", uid)
		return
	end
	widget:SetRenderOpacity(0)

	local parentScript = self:getUI(config.parentui)
	local panelUID = uid
	if parentScript then
		local panelUI = self:GetBelongPanel(uid)
		panelUID = panelUI and panelUI.uid
		self:addChildToCanvas(uid, parentScript, widget, config)
	else
		Game.NewUIManager.uiRoot:AddChildToLayer(UIConst.CANVAS_TYPE.NORMAL_UI, widget, _G.InvalidationBox and not config.volatile)
	end
	local scriptPath = config.classpath
	if string.isEmpty(scriptPath) then
		Log.Error("UIFrame:UILoaderCreateUIScript UIConfig没有配置Lua路径", scriptPath)
		return
	end
	local requireOk, uiClass = xpcall(kg_require, _G.CallBackError, scriptPath)
	if not requireOk or not uiClass or uiClass.new == nil then
		Log.Error("UIFrame:UILoaderCreateUIScript 脚本Require出错 ", uid, scriptPath)
		return
	end
	local newOk, panelInstance = xpcall(uiClass.new, _G.CallBackError, uid, panelUID, widget, widget, parentScript)
	if not newOk then
		local tmpWidget = (_G.InvalidationBox and not parentScript) and widget:GetParent() or widget
		tmpWidget:RemoveFromParent()
		return
	end
	panelInstance.preloadResMap = preloadResMap
	return panelInstance
end

function UIManager:addChildToCanvas(uid, parentScript, widget, config)
	if parentScript then
		local rootPath = string.sub(config.parent, string.findLast(config.parent, '/') + 1)
		local root = parentScript.View[rootPath]
		if not root then
			Log.ErrorFormat("UIFrame:UILoader@%s添加子控件%s，但是根节点%s不存在", config.auth or "no auth", uid, config.parent)
			return
		end
		if type(root) == "table" then
			root = widget.WidgetRoot
		end
		if root:IsA(CanvasPanel) then
			local slot = root:addChildToCanvas(widget)
			local NewAnchors = Anchors()
			NewAnchors.Minimum = FVector2D(0, 0)
			NewAnchors.Maximum = FVector2D(1, 1)
			slot:SetAnchors(NewAnchors)
			slot:SetOffsets(Margin(0, 0, 0, 0))
		else
			root:AddChild(widget)
		end
	else
		Log.ErrorFormat("UIFrame:UILoader@%s添加子控件%s，但是依赖的父面板不存在",config.auth or "no auth",  uid)
	end
end

---@field panel UIController
function UIManager:destroyPanel(panel)
    panel:Destroy()
end

function UIManager:processMutualUIOpen(uid)
	Game.NewUIManager:processMutualUIOpen(uid)
end

function UIManager:processMutualUIClose(uid)
	Game.NewUIManager:processMutualUIClose(uid)
end

-- todo 临时处理等辉辉迭代UI场景管理
function UIManager:processSceneUIClose(uid)
	Game.NewUIManager:processSceneUIClose(uid)
end

--- 清除隐藏这个面板的标记，如果被标记隐藏了，然后又再次打开了，就会从恢复列表异常
---@private
---@param uid number 面板Id
function UIManager:clearPanelHideFlag(uid)
	Game.NewUIManager:clearPanelHideFlag(uid)
end

function UIManager:GetUIConfig(uid)
	return Game.NewUIManager:GetUIConfig(uid)
end

--todo 移除接口 不允许直接获取UI面板调用内部接口 通信通过事件
function UIManager:getUI(uid)
	if not uid then
		return nil
	end
	local config = UI.GetCfg(uid)
	table.clear(self.uiTreeTb)
	table.insert(self.uiTreeTb, 1,config)
	while(config.parentui) do
		config = UI.GetCfg(config.parentui)
		table.insert(self.uiTreeTb, 1, config)
	end
	local ui
	for k, v in ipairs(self.uiTreeTb) do
		if k == 1 then
			ui = self:getOpenPanelMap()[v.__ui]
		else
			if ui and ui.GetChildComponent then
				ui = ui:GetChildComponent(v.__ui)
			end
		end
	end
	return ui
end
--endregion

--region 新老框架数据共享结构
function UIManager:getOpenPanelMap()
	return Game.NewUIManager._openPanelMap
end

function UIManager:GetOpenPanelStack()
	return Game.NewUIManager._openPanelStack
end

function UIManager:OnUIEvent(widget, eventType)
	Game.AkAudioManager:OnUIPostEvent(widget, eventType)
end

function UIManager:OnViewportResized(resX, resY)

end

function UIManager:onUnInit()
	self:ClearWarmUI()
	self:ClearLoad()
	self:DestroyAllPanel()
	self:ClearCache()
end
--endregion

