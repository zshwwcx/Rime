local UIFunctionLibrary = import("UIFunctionLibrary")
local UIAnimation = kg_require("Framework.UI.UIAnimation")
local EventBase = kg_require("Framework.EventSystem.EventBase")
local TimerComponent = kg_require("Framework.KGFramework.KGCore.TimerManager.TimerComponent")
local LuaFunctionLibrary = import("LuaFunctionLibrary")
local KGCustomEvent = import("KGCustomEvent")

---@class UIBase:EventBase
local UIBase = DefineClass("UIBase",UIAnimation, LoaderComponent, EventBase, TimerComponent)
UIBase.bIsOldUI = true
local UWidgetBlueprintLibrary = import("WidgetBlueprintLibrary")
local ESlateVisibility = import("ESlateVisibility")
local UUserWidget = import("UserWidget")
local UPaperSprite = import("PaperSprite")
local UDynamicSprite = import("DynamicSprite")
local UImage = import("Image")

---@class EUIEventTypes
_G.EUIEventTypes = {
    CLICK = "OnClicked",					--按钮点击
	RightClick = "C7OnRightClicked",            --鼠标右键点击
	TextCommitted = "OnTextCommitted",			--文本Committed
	TextChanged = "OnTextChanged",			--文本改变
	C7TextChanged = "OnC7TextChanged",			--c7文本改变
	SelectionChanged = "OnSelectionChanged",		--UComboBoxString改变
	CheckStateChanged = "OnCheckStateChanged",		--UCheckBox选中状态改变
	OnValueChanged = "OnValueChanged",			--USlider滑条值改变
	MouseCaptureBegin = "OnMouseCaptureBegin",		--USlider按下鼠标并开始捕获
	MouseCaptureEnd = "OnMouseCaptureEnd",		--USlider鼠标停止并结束捕获
	ControllerCaptureBegin = "OnControllerCaptureBegin",--USlider开始捕获控制器或键盘
	ControllerCaptureEnd = "OnControllerCaptureEnd",	--USlider控制器或键盘捕获结束
	Pressed = "OnPressed",				--按钮按下
	Released = "OnReleased",				--按钮弹起
	Hovered = "OnHovered",				--按钮悬上
	Unhovered = "OnUnhovered",				--按钮悬过
	DragDetected = "OnDragDetectedEvent",			--UC7UserWidget检测到拖拽
	DragCancelled = "OnDragCancelledEvent",			--UC7UserWidget取消拖拽
	MouseButtonDown = "OnMouseButtonDownEvent",		--UC7UserWidget 按下
	MouseButtonUp = "OnMouseButtonUpEvent",			--UC7UserWidget 弹起
	MouseWheel = "OnMouseWheelEvent",			--UC7UserWidget 滚轮滚动
	MouseLeave = "OnMouseLeaveEvent",			-- 鼠标离开
	MouseMove = "OnMouseMoveEvent",              --鼠标滑动
	Drop = "OnDropEvent",					--DragDrop
	ImageMouseButtonDown = "OnMouseButtonDownEvent",	--UC7Image按下
	TouchStarted = "OnTouchStartedEvent",			--开始拖动
	TouchMoved = "OnTouchMovedEvent",			--拖着移动
	TouchEnded = "OnTouchEndedEvent",			--拖动结束
	FocusLost = "OnFocusLostEvent",				--失去焦点
	DragEnter = "OnDragEnterEvent",				--UC7UserWidget进入拖拽
	DragLeave = "OnDragLeaveEvent",				--UC7UserWidget离开拖拽
	UserScrolled = "OnUserScrolled",			--scrollbox 列表用户拖动
	C7Touch = "OnC7TouchEvent",				--C7Touch
	MediaReachedEnd = "OnMediaReachedEnd",		--视频播放结束
	SpineAnimationComplete = "AnimationComplete", --spine动画播放结束
	UserTouchEnded =  "OnUserTouchEnded",  		--scrollbox 抬起操作
	OnAnimationStarted = "OnAnimationStartedEvent",	--动画开始
	OnAnimationFinished = "OnAnimationFinishedEvent",	--动画结束
	UrlClicked = 1,				--超链接点击
	OnAnimationNotify = 2,		--动画中间事件
	CustomEvent = 3,  		--KGCustomEvent自定义事件
}

local EUIEventTypes = _G.EUIEventTypes

local handled = UWidgetBlueprintLibrary.Handled()
local unhandled = UWidgetBlueprintLibrary.Unhandled()

UIBase.HANDLED = handled

UIBase.UNHANDLED = unhandled

---@class EUIEventReturns
_G.EUIEventReturns = {
    [EUIEventTypes.CLICK] = handled,
	[EUIEventTypes.MouseButtonDown] = handled,
	[EUIEventTypes.MouseButtonUp] = handled,
	[EUIEventTypes.MouseWheel] = handled,
	[EUIEventTypes.MouseMove] = handled,
	[EUIEventTypes.ImageMouseButtonDown] = handled,
	[EUIEventTypes.TouchStarted] = handled,
	[EUIEventTypes.TouchMoved] = handled,
	[EUIEventTypes.TouchEnded] = handled,
	[EUIEventTypes.UserTouchEnded] = handled,
	[EUIEventTypes.RightClick] = handled,
	[EUIEventTypes.Drop] = true,
}

---@class EUIEventUnhandleReturns
_G.EUIEventUnhandleReturns = {
	[EUIEventTypes.MouseButtonDown] = unhandled,
	[EUIEventTypes.MouseButtonUp] = unhandled,
	[EUIEventTypes.MouseWheel] = unhandled,
	[EUIEventTypes.MouseMove] = unhandled,
	[EUIEventTypes.Drop] = false,
	[EUIEventTypes.ImageMouseButtonDown] = unhandled,
	[EUIEventTypes.TouchStarted] = unhandled,
	[EUIEventTypes.TouchMoved] = unhandled,
	[EUIEventTypes.TouchEnded] = unhandled,
	[EUIEventTypes.UserTouchEnded] = unhandled,
}

---@field uid string ui名称 如果没有则是父节点的名称
---@field userWidget UserWidget 脚本最近的一个userwidget
---@field widget Widget 脚本绑定的节点
---@field parentScript UIBase 父脚本，面板没有
function UIBase:ctor(uid, panelUID, userWidget, widget, parentScript, ...)
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
	self.widgetEventsList = {}
	self._uiEvents = {}
	self:createView()
	self:OnCreate(...)
	self:GetAllAutoAnimationInfo()
	self:InitUIEvent()
	self:InitCustomComponent()
	self:InitComponent()
end

function UIBase:InitUIEvent()
end

function UIBase:InitComponent()
end

function UIBase:InitCustomComponent()
	local config = self:getUIConfig()
	if config and config.moneyType then
		self.currencyComponent = self:createMoneyComponent()
	end
	if config and config.scenename then
		local ShowSceneComponent = kg_require("Framework.UI.ShowSceneComponent")
		---@type ShowSceneComponent
		self.sceneComponent = self:BindComponent(self:GetViewRoot(), ShowSceneComponent)
	end
end

function UIBase:OnCreate()
end

function UIBase:Show()
	self._isShow = true
	self.widget:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
	self:OnShow()
end

function UIBase:OnShow()
    for _, comp in ipairs(self._childComponents or {}) do
        if comp then
            comp:OnShow()
        end
    end
end

---todo UIBase
function UIBase:Hide()
	self._isShow = false
	self.widget:SetVisibility(ESlateVisibility.Collapsed)
	self:OnHide()
end

function UIBase:OnHide()
    for _, comp in ipairs(self._childComponents or {}) do
        if comp then
			comp:OnHide()
        end
    end
end

function UIBase:Open()
	self._isOpen = true
	self:BatchAddListener()
	for _, comp in ipairs(self._childComponents or {}) do
        if comp and not comp:IsOpened() then
            comp:Open(nil, true)
        end
    end
	self:OnOpen()
end

function UIBase:OnOpen()

end

function UIBase:Close()
	if self._childComponents then
		for i = #self._childComponents, 1, -1 do
			local comp = self._childComponents[i]
			if comp.bIsOldUI then
				if comp and comp:IsOpened() then
					if string.notNilOrEmpty(comp.uid) and Game.UIConfig[comp.uid] then --说明是子界面，直接移除
						table.remove(self._childComponents, i)
						self:RemoveChildPanel(comp.uid, comp) --RemoveChildPanel实现在UIControl
					else
						comp:Close()
					end
				end
			else
				comp:Close()
			end
		end
	end
	self:ClearAnimation()
	self:RemoveAllListener(true)
	self:StopAllTimer()
	self:ClearLoad()
	table.clear(self.imageRecord)
	self._isOpen = false
	self:OnClose()
end

--- 面板关闭，有需要可以继承重写方法
---@private
function UIBase:OnClose()
end

---

function UIBase:Refresh(...)
	self:SetCurrencyData()
	self:RefreshShowScene()
	self:OnRefresh(...)
end

function UIBase:OnRefresh(...)
end

function UIBase:Destroy(bRetainWidget)
	self:OnDestroy()
	if self.View.OnDestroy then
		self.View:OnDestroy()
	end
	if not bRetainWidget then
		if _G.InvalidationBox and not self:IsComponent() and not self:getUIConfig().volatile then
			local parent = self.userWidget:GetParent()
			parent:RemoveFromParent()
		else
			self.widget:RemoveFromParent()
		end
	end
	self:PushComponents()
	self.View = nil
	self.widget = nil
	self.userWidget = nil
	self.currencyComponent = nil
	self.sceneComponent = nil
	self:delete()
end

function UIBase:OnDestroy()
	if self._childComponents then
		for i = #self._childComponents, 1, -1 do
			local comp = self._childComponents[i]
			table.remove(self._childComponents, i)
			if comp then
				comp:OnDestroy()
			end
		end
	end
	self:RemoveAllUIListener()
	EventBase.OnDestroy(self)
end

function UIBase:GetViewRoot()
	return self.widget
end

function UIBase:SetAutoBind(autoBind)
	self.autoBind = autoBind
end

function UIBase:IsShow()
	return self._isShow
end

function UIBase:IsOpened()
	return self._isOpen
end

---public widget绑定Lua脚本
---@param widget userdata  UI组件
---@param cell UIComponent 继承自UICell的Lua脚本
---@return UIComponent 脚本实例化对象
function UIBase:BindComponent(widget, cell, ...)
	if not widget then
		return
	end
	if type(widget) == "table" then
		widget = widget.WidgetRoot
	end
	local userwidget = widget:IsA(UE.UserWidget) and widget or self.userWidget
	local panelUID = self.panelUID and self.panelUID or self.uid
	local component
	if cell.bIsOldUI then
		component = cell.new(nil, panelUID, userwidget, widget, self, ...)
	else
        component = Game.NewUIManager:CreateScript(cell, self.panelUID, userwidget, widget, self, ...)
	end
	table.insert(self._childComponents, component)
	component:Show()
	component:Open()
	--todo 兼容旧框架
	if ... then
		component:OnRefresh(...)
	end
	return component
end

---@public 创建控件，控件位于WBP_ComLib里
---@param name 控件名
---@param container 挂载点
---@param cell UIComponent
---@return UIComponent
-- function UIBase:FormComponent(name, container, cell, ...)
-- 	if not cell then
-- 		Log.Error(self.__cname, ": widget必需绑定Component脚本(业务比较简单的话，可以绑定WidgetEmptyComponent，逻辑依旧放在父界面中)")
-- 		return
-- 	end
-- 	local manager = UIManager:GetInstance()
-- 	local c = manager:GetLibComponent(name, container)
-- 	if not c then
-- 		Log.ErrorFormat("GetLibComponent error, name:%s, scriptName:%s  %s",
-- 			tostring(name), tostring(self.__cname), self.parentScript ~= nil and self.parentScript.__cname or "")
-- 		return
-- 	end
-- 	self.foms[container] = self.foms[container] or {}
-- 	local foms = self.foms[container]
-- 	local len = #foms
-- 	foms[len + 1] = name
-- 	foms[len + 2] = c
-- 	local component
-- 	if cell.__cname == "WidgetEmptyComponent" then
-- 		component = self:BindComponent(c, cell, name, ...)
-- 	else
-- 		component = self:BindComponent(c, cell, ...)
-- 	end
-- 	foms[len + 3] = component
-- 	component.componentContainer = container
-- 	--component:UpdateObjectNum(UIHelper.GetObjectNum(c))
-- 	return component
-- end

function UIBase:FormComponent(name, container, cell, ...)
	if not cell then
		Log.Error(self.__cname, ": widget必需绑定Component脚本(业务比较简单的话，可以绑定WidgetEmptyComponent，逻辑依旧放在父界面中)")
		return
	end
	local manager = UIManager:GetInstance()
	local c = manager:GetLibComponent(name, container, self.widget)
	if not c then
		Log.ErrorFormat("GetLibComponent error, name:%s, scriptName:%s  %s",
			tostring(name), tostring(self.__cname), self.parentScript ~= nil and self.parentScript.__cname or "")
		return
	end
	self.foms[container] = self.foms[container] or {}
	local foms = self.foms[container]
	local len = #foms
	foms[len + 1] = name
	foms[len + 2] = c
	local component
	if cell.__cname == "WidgetEmptyComponent" then
		component = self:BindComponent(c, cell, name, ...)
	else
		component = self:BindComponent(c, cell, ...)
	end
	foms[len + 3] = component
	component.componentContainer = container
	return component
end

--todo 删除 临时兼容旧版本 组件访问
function UIBase:GetChildComponent(uid)
	for k, v in ipairs(self._childComponents) do
		if v.uid == uid then
			return v
		end
	end
end
--todo
--很奇怪后面研究下为什么无效框子节点变动就要刷
function UIBase:InvalidateRootChildOrder()
	local ui = self
	while ui.parentScript do
		ui = ui.parentScript
	end
	UIFunctionLibrary.SetCanCache(ui.userWidget)
end

---@public @回收UIController内所有Lib下Component
function UIBase:PushComponents()
	for container, _ in next, self.foms do
		self:PushAllComponent(self, container)
	end
end

---@public @回收容器内所有Lib下Component
---@param container any @容器控件
function UIBase:PushContainerComponent(container)
	local foms = self.foms[container]
	if foms then
		self:PushAllComponent(self, container)
	end
end

---@public @回收单个Lib下Component
---@param container any @容器控件
---@param uiComponent UIComponent @要回收的UIComponent
function UIBase:PushOneComponent(container, uiComponent)
	local foms = self.foms[container]
	if foms then
		self:PushSingleComponent(self, container, uiComponent)
	end
end


---@public @回收单个Lib下Component
---@param owner UIController @界面
---@param container any @容器控件
---@param uiComponent UIComponent @要回收的UIComponent
function UIBase:PushSingleComponent(owner, container, uiComponent)
	local foms = owner.foms[container]
	if not foms then return end
	for ii = #foms,  1,  -3 do
		local name, widget, cell = foms[ii - 2], foms[ii - 1], foms[ii]
		if uiComponent == cell then
			table.remove(foms, ii)
			table.remove(foms, ii - 1)
			table.remove(foms, ii - 2)
			self:DestroyComponent(uiComponent)
			cell:Close(true)
			cell:Destroy(true)
			Game.UIManager:CacheLibComponent(name, widget)
			break
		end
	end
end

---@public @回收容器内所有Lib下Component
---@param owner UIController @界面
---@param container any @容器控件
function UIBase:PushAllComponent(owner, container)
	local foms = owner.foms[container]
	if not foms then return end
	for ii = 1, #foms, 3 do
		local name, widget, cell = foms[ii], foms[ii + 1], foms[ii + 2]
		if cell then
			cell:Close(true)
			cell:Destroy(true)
			self:DestroyComponent(cell)
		end
		Game.UIManager:CacheLibComponent(name, widget)
	end
	table.clear(owner.foms[container])
end

--todo 临时方法
function UIBase:DestroyComponent(component)
	for i,v in ipairs(self._childComponents) do
		if v == component then
			table.remove(self._childComponents, i)
			return
		end
	end
end
--endregion
---------------------------------------------------------------------------------------------------------------------
function UIBase:GetObjectNum()
	local num = self._uObjectNum
    for _, v in ipairs(self._childComponents) do
        num = num + v:GetObjectNum()
    end
    return num
end

---统计UObject数量
---@public
---@param isAdd boolean 增加or减少
---@param num number 变动数量
function UIBase:UpdateObjectNum(num)
    if not num then
		return
	end
    self._uObjectNum = num
end


function UIBase:createView()
	local config = self:getUIConfig()
	local uiView = _G[self.__cname .. "View"]
	if config or uiView then
		if not uiView then
			local file = config.classpath .. "View"
			if LuaFunctionLibrary.ScriptFileExists(file) then
				uiView = kg_require(file)
			end
		end
		if uiView then
			self.View = uiView.new(self.widget, self)
			return
		end
	end
	if self.widget:IsA(UUserWidget) then
		self.View = setmetatable({WidgetRoot = self.widget}, UIView._rootMeta)
	else
		self.View = setmetatable({WidgetRoot = self.widget}, BaseList._rootMeta)
	end
end

function UIBase:IsComponent()
	local config = self:getUIConfig()
	if not config then
		return true
	end
	return string.notNilOrEmpty(config.parent)
end

function UIBase:getUIConfig()
	if not self.uid then
		return nil
	end
	return UIManager:GetInstance():GetUIConfig(self.uid)
end

---ClearImageRecord 清理image图片路径记录
---@param image userdata? 为空的话清理所有image
function UIBase:ClearImageRecord(image)
	if image then
		self.imageRecord[image] = nil
	else
		table.clear(self.imageRecord)
	end
end

---设置图片
---@public
---@param image UImage
---@param path string 图片名字
---@param callBack function|nil 加载完回调函数
---@param isAsync boolean|nil 是否异步加载（默认异步）
---@param bIgnoreOpacity boolean|nil 修改图片前是否先隐藏（默认隐藏）
---@param bMatchSize boolean If true, image will change its size to texture size. If false, texture will be stretched to image size.
function UIBase:SetImage(image, path, callBack, isAsync, bIgnoreOpacity, bMatchSize)
	if self._isOpen == false then
		Log.Error("UIBase:SetImage 调用了已经关闭的UI接口 class:%s, path:%s, %s", self.__cname,path)
		return
	end

	--临时处理：禁止给image，使用DynamicSprite
	if image:IsA(UImage) and string.endsWith(path, "_DynamicSprite") then
		path = string.sub(path, 1, #path - #"_DynamicSprite")
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
	local UIFunc = import("UIFunctionLibrary")
	if not bIgnoreOpacity then
		oldAlpha = UIFunc.GetOpacity(image) -- image.ColorAndOpacity.A
		if oldAlpha <= 0 then
			oldAlpha = 1
		end
		-- image:SetOpacity(0)
		UIFunc.SetOpacity(image, 0)
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
		if res:IsA(UPaperSprite) or res:IsA(UDynamicSprite) then
			image:SetBrushFromAtlasInterface(res, bMatchSize or false)
		else
			image:SetBrushFromTexture(res, bMatchSize or false)
		end
		if not bIgnoreOpacity then
			-- image:SetOpacity(oldAlpha)
			UIFunc.SetOpacity(image, oldAlpha)
		end
		if callBack then
			callBack()
		end
	end
	self:LoadRes(path, func, isAsync)
	    -- luacheck: pop
end

---SetImageByRes
---@param image Image
---@param res Texture|PaperSprite|DynamicSprite
---@param bMatchSize boolean If true, image will change its size to texture size. If false, texture will be stretched to image size.
function UIBase:SetImageByRes(image, res, bMatchSize)
	if res:IsA(UPaperSprite) or res:IsA(UDynamicSprite) then
		image:SetBrushFromAtlasInterface(res, bMatchSize or false)
	else
		image:SetBrushFromTexture(res, bMatchSize or false)
	end
end

---设置image的材质球
---@public
---@param image Image
---@param path string 材质球名字
---@param callBack function|nil 加载完回调函数
---@param isAsync boolean|nil
---@param bIgnoreOpacity boolean|nil 修改图片前是否先隐藏（默认隐藏）
function UIBase:SetMaterial(image, path, callBack, isAsync, bIgnoreOpacity)
	-- luacheck: push ignore
	isAsync = isAsync == nil and true or isAsync
	path = self:checkResourcePath(path)
	if string.isEmpty(path) or self.imageRecord[image] == path then
		return
	end
	self.imageRecord[image] = path
	local oldAlpha = nil
	if not bIgnoreOpacity then
		oldAlpha = image.ColorAndOpacity.A
		image:SetOpacity(0)
	end
	local func = function(res)
		image:SetBrushFromMaterial(res)
		if not bIgnoreOpacity then
			image:SetOpacity(oldAlpha)
		end
		if callBack then
			callBack()
		end
	end
	self:LoadRes(path, func, isAsync)
	-- luacheck: pop
end

---SetMaterialByRes
---@param image Image
---@param res Material
function UIBase:SetMaterialByRes(image, res)
	image:SetBrushFromMaterial(res)
end

function UIBase:SetImageByUrl(image, url, imageName, callback, bIgnoreOpacity)
	if self.imageRecord[image] == url then
		if callback then
			callback()
		end
		return
	end
	self.imageRecord[image] = url
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
			Log.WarningFormat("UIBase:SetImageByUrl 设置图片失败 请检查图片url是否正确 %s", url)
			return
		end
		if not self._isOpen or self.destroyed then
			return
		end
		image:SetBrushFromTexture(res, false)
		if not bIgnoreOpacity then
			image:SetOpacity(oldAlpha)
		end
		if callback then
			callback()
		end
	end
	-- luacheck: pop
	Game.LocalResSystem:DownloadImgByUrls(url, imageName, func)
end

--设置MaterialInstanceDynamic上的Texture2D
---@param image Image
---@param paramName string
---@param path string
---@param callback fun()
---@param isAsync boolean
---@param bIgnoreOpacity boolean
function UIBase:SetTextureParameterValue(image, paramName, path, callback, isAsync, bIgnoreOpacity)
	isAsync = isAsync == nil and true or isAsync
	path = self:checkResourcePath(path)
	if string.isEmpty(path) or self.imageRecord[image] == path then
		return
	end

	local oldAlpha = nil
	if not bIgnoreOpacity then
		oldAlpha = image.ColorAndOpacity.A
		image:SetOpacity(0)
	end
	---@param res Texture
	local func = function(res)
		local MID = image:GetDynamicMaterial()
		MID:SetTextureParameterValue(paramName, res)
		if not bIgnoreOpacity then
			image:SetOpacity(oldAlpha)
		end
		if callback then
			callback()
		end
	end
	self:LoadRes(path, func, isAsync)

end

---检查配置路径是否符合规范，如果不符合，就需要将路径修改至规范形式。
---@private
function UIBase:checkResourcePath(image)
	if (not image) or image == "" then
		local config = self:getUIConfig()
		local auth = config and config.auth or ""
		Log.WarningFormat("UIFrame:UIBase:checkResourcePath() @%s 图片路径不能传空", auth)
		return
	end
    local correct = string.find(image, "%.")
	if correct == nil then
		local gotFileName = string.match(image, ".+/([^/]*%w+)$")
		if gotFileName then
			image = image .. "." .. gotFileName
		end
	end
	return image
end

function UIBase:GetParent()
	return self.parent
end

--region 自动创建的通用组件  --todo 待优化
function UIBase:createMoneyComponent()
	local root
	if self.GetMoney then
		root = self:GetMoney()
	else
		root = self.View["Money"]
	end
	if root then
		local P_ComCurrencyList = kg_require("Gameplay.LogicSystem.CommonUI.P_ComCurrencyList")
		return self:FormComponent('CurrencyList', root, P_ComCurrencyList)
	else
		local config = self:getUIConfig()
		local auth = config and config.auth or ""
		Log.WarningFormat("UIFrame:UIBase:createMoneyComponent() @%s 加载货币栏失败，没有挂在结点 %s 请检查Money结点是否存在", auth or "", self.uid)
	end
end

function UIBase:SetCurrencyData(moneyType)
	if self.currencyComponent then
		if not moneyType then
			moneyType = self:getUIConfig().moneyType
		end
		self.currencyComponent:Refresh(moneyType)
	end
end

function UIBase:RefreshShowScene()
	if self.sceneComponent then
		local config = self:getUIConfig()
		self.sceneComponent:Refresh(config.scenename,nil, nil,config.RoleShowCameraType,config.FaceCloseUpCameraModeType, config.FocusCoord)
	end
end

--endregion

function UIBase:AddUIListener(uiEventType, widget, func, ...)
	if func == nil or (type(func) == "string" and self[func] == nil) then
		Log.ErrorFormat("AddUIListener callback is nil, UIEventType: %s",tostring(uiEventType))
		return
	end
	if type(widget) == "table" then
		widget = widget.WidgetRoot
	end
	local extendParam = table.pack(...)

	if not self.widgetEventsList[widget] then
		self.widgetEventsList[widget] = {}
	end
	local widgetEventTypes = self.widgetEventsList[widget]
	if uiEventType == EUIEventTypes.OnAnimationStarted or uiEventType == EUIEventTypes.OnAnimationFinished then
		self:bindAnimationEvent(uiEventType, widget, func, extendParam)
	else
		if widgetEventTypes[uiEventType] then
			Log.Error("UI event duplicated binding")
			return
		end
		
		-- luacheck: push ignore
		local callback = function(...)
			return self:callUIEventCallback(widget, uiEventType, func, extendParam, ...)
		end
		-- luacheck: pop

		local eventData = {Callback = callback, ExtendParam = extendParam}
		widgetEventTypes[uiEventType] = eventData
		if uiEventType == EUIEventTypes.UrlClicked then
			local delegate = widget.C7HyperLinkBlockDecorator.OnUrlClicked
			eventData.Delegate = delegate
			delegate:AddListener(callback)
		elseif uiEventType == EUIEventTypes.OnAnimationNotify then
			eventData.FirstDelegate = widget.UMGAnimationNotifyEvents.First.Delegate
			eventData.SecondDelegate = widget.UMGAnimationNotifyEvents.Second.Delegate
			eventData.FirstDelegate:AddListener(callback)
			eventData.SecondDelegate:AddListener(callback)
		elseif uiEventType == EUIEventTypes.CustomEvent then
			local customEventList = widget:GetComponents(KGCustomEvent)
			local Delegates = {}
			eventData.Delegates = Delegates
			for i, customEvent in pairs(customEventList) do
				local delegate = customEvent.OnCustomEventDelegate
				delegate:AddListener(callback)
				Delegates[i] = delegate
			end
		else
			local delegate = widget[uiEventType]
			if delegate then
				eventData.Delegate = delegate
				delegate:AddListener(callback)
			else
				self.widgetEventsList[widget][uiEventType] = nil
			end
		end
	end
end

function UIBase:bindAnimationEvent(uiEventType, widget, animEventCallback, extendParam)
	local animBindList = self.widgetEventsList[widget][uiEventType]
	if widget[uiEventType] then	--widget有对应的属性，说明是KGUserWidget，事件是直接绑在Widget的
		-- luacheck: push ignore
		local callback = function(animationName)
			local eventData = self.widgetEventsList[widget][uiEventType].Anims[animationName]
			if eventData then
				return self:callUIEventCallback(widget, uiEventType, eventData.AnimEventCallback, extendParam)
			end
		end
		-- luacheck: pop

		local animName = extendParam[1]:GetName()
		if not animBindList then
			animBindList = {}
			self.widgetEventsList[widget][uiEventType] = animBindList
			local delegate = widget[uiEventType]
			delegate:AddListener(callback)
			animBindList.Delegate = delegate
			animBindList.BindCount = 0
			animBindList.Anims = {}
		elseif animBindList.Anims[animName] then
			Log.Error("UI event duplicated binding")
			return
		end
		local eventData = {ExtendParam = extendParam, AnimEventCallback = animEventCallback}
		table.remove(extendParam,1)
		animBindList.Anims[animName] = eventData
		animBindList.BindCount = animBindList.BindCount + 1
	else   --todo 等所有UserWidget都替换成KGUserWidget后，删除else里的逻辑
		-- luacheck: push ignore
		local callback = function(...)
			return self:callUIEventCallback(widget, uiEventType, animEventCallback, extendParam, ...)
		end
		-- luacheck: pop
		local bindFunc = uiEventType == EUIEventTypes.OnAnimationStarted and widget.BindToAnimationStarted or widget.BindToAnimationFinished
		local anim = extendParam[1]
		if not animBindList then
			animBindList = {}
			self.widgetEventsList[widget][uiEventType] = animBindList
		elseif animBindList[anim] then
			Log.Error("UI event duplicated binding")
			return
		end
		local eventData = {Callback = callback, ExtendParam = extendParam}
		table.remove(extendParam,1)
		animBindList[anim] = eventData
		local animationFinishedDelegate = slua.createDelegate(callback)
		bindFunc(widget, anim, animationFinishedDelegate)
	end
end

function UIBase:callUIEventCallback(widget, uiEventType, func, extendParam, ...)
	if not self._isOpen then
		return --界面已经关闭的情况下不调用回调事件
	end
	Game.UIManager:OnUIEvent(widget, uiEventType)
	func = type(func) == "function" and func or self[func]
	local ok, result  = nil
	if extendParam.n > 0 then
		local pack = table.pack(...)
		table.mergeList(pack, extendParam)
		ok, result = xpcall(func, _G.CallBackError, self, table.unpack(pack))
	else
		ok, result = xpcall(func, _G.CallBackError, self, ...)
	end
	if ok and result ~= nil then
		return result
	end
	return EUIEventReturns[uiEventType]
end

---RemoveUIListener 移除UI事件绑定
---@param uiEventType EUIEventTypes 事件类型
---@param widget Widget 事件所在的widget
---@param anim WidgetAnimation? 当事件绑定对象是动画时需要传入
function UIBase:RemoveUIListener(uiEventType, widget, anim)
	if type(widget) == "table" then
		widget = widget.WidgetRoot
	end
	if not self.widgetEventsList[widget] or not self.widgetEventsList[widget][uiEventType] then
		return
	end
	local eventData = self.widgetEventsList[widget][uiEventType]
	if uiEventType == EUIEventTypes.OnAnimationStarted or uiEventType == EUIEventTypes.OnAnimationFinished then
		local isNewType = widget[uiEventType] ~= nil
		anim = isNewType and anim:GetName() or anim
		self:removeAnimationListener(uiEventType, widget, anim, eventData, isNewType)
	else
		self:removeNormalUIListener(uiEventType, widget, eventData)
	end
end

---@private removeAnimationListener
function UIBase:removeAnimationListener(uiEventType, widget, anim, eventData, isNewType)
	if isNewType then --widget有对应的属性，说明是KGUserWidget，事件是直接绑在Widget的
		if eventData.Anims[anim] then
			eventData.Anims[anim] = nil
			eventData.BindCount = eventData.BindCount - 1
			if eventData.BindCount == 0 then
				eventData.Delegate:RemoveListener()
				self.widgetEventsList[widget][uiEventType] = nil
			end
		end
	else	--todo 等所有UserWidget都替换成KGUserWidget后，删除else里的逻辑
		eventData[anim] = nil
		local unbindFunc = uiEventType == EUIEventTypes.OnAnimationStarted and widget.UnbindAllFromAnimationStarted or widget.UnbindAllFromAnimationFinished
		unbindFunc(widget, anim)
	end
end

---@private removeNormalUIListener
function UIBase:removeNormalUIListener(uiEventType, widget, eventData)
	self.widgetEventsList[widget][uiEventType] = nil
	if uiEventType == EUIEventTypes.OnAnimationNotify then
		eventData.FirstDelegate:RemoveListener()
		eventData.SecondDelegate:RemoveListener()
	elseif uiEventType == EUIEventTypes.CustomEvent then
		for i, v in pairs(eventData.Delegates) do
			v:RemoveListener()
		end
	else
		eventData.Delegate:RemoveListener(eventData.Callback)
	end
end

function UIBase:RemoveAllUIListener()
	self:ClearAllUIEvent() -- todo 兼容新框架
	for widget, events in pairs(self.widgetEventsList) do
		for eventType, value in pairs(events) do
			if eventType == EUIEventTypes.OnAnimationStarted or eventType == EUIEventTypes.OnAnimationFinished then
				local isNewType = widget[eventType] ~= nil
				local list = isNewType and value.Anims or value 
				for anim, _ in pairs(list) do
					self:removeAnimationListener(eventType, widget, anim, value, isNewType)
				end
			else
				self:removeNormalUIListener(eventType, widget, value)
			end
		end
	end
	table.clear(self.widgetEventsList)
end

function UIBase:setCellId(uid)
    self.uid = uid
end


-- luacheck: push ignore
--region UI事件
---@param delegate Delegate | MulticastDelegate | LuaDelegate | LuaMulticastDelegate C++委托
---@param functionName string Lua函数名称
---@public
function UIBase:AddUIEvent(delegate, functionName, ...)
    if delegate == nil then
        Log.WarningFormat("UIFrame.UIComponent:AddUIEvent %s尝试给一个不存在的委托绑定函数 %s", self.__cname, functionName)
        return
    end
    local extendParam = table.pack(...)

    local callback = function(...)
        if self[functionName] then
            if extendParam.n > 0 then
                local pack = table.pack(...)
                table.mergeList(pack, extendParam)
                return self[functionName](self, table.unpack(pack))
            end
            return self[functionName](self, ...)
        end
    end
    delegate:AddListener(callback)
    self._uiEvents[functionName] = { callback = callback, delegate = delegate }
end

-- luacheck: pop
---@param delegate Delegate | MulticastDelegate | LuaDelegate | LuaMulticastDelegate C++委托
---@param functionName string Lua函数名称
---@public
function UIBase:RemoveUIEvent(delegate, functionName)
    local uiEvent = self._uiEvents[functionName]
    if uiEvent == nil then
        Log.WarningFormat("UIFrame.UIComponent:RemoveUIEvent 移除了一个没有注册的函数 %s", functionName)
        return
    end
    assert(uiEvent.delegate == delegate)
    delegate:RemoveListener(uiEvent.callback)
    self._uiEvents[functionName] = nil
end

---@private
function UIBase:ClearAllUIEvent()
    for functionName, event in pairs(self._uiEvents) do
        self:RemoveUIEvent(event.delegate, functionName)
    end
end

--endregion
return UIBase