local UIFunctionLibrary = import("UIFunctionLibrary")
local Margin = import("Margin")
---@class UIController:UIBase
local UIController = DefineClass("UIController", UIBase)

-- todo 统一迭代掉 不走touch处理空白区域关闭
UIController.C7Func = function(ui, Geometry, InMouseEvent)
	-- return UIManager:GetInstance():OnC7TouchEvent(ui, Geometry, InMouseEvent)
end

function UIController:ctor()
	self._paddingOffset = 0
	self._paddingSubOffset = {}
	self._adaptDealingWBPList = {}
	self._isOpening = false
	self._isClosing = false
	self.cacheChilePanel = Cache.new(4) --子界面缓存
	self._loadingChildPanel = {} --当前正在加载的UI
	self._lastChildPanelParam = {}  --子界面最后一次打开传入的参数
	self:AddUIListener(EUIEventTypes.C7Touch, self.View.WidgetRoot, self.C7Func)
end

---打开面板，由UIManager调用，业务模块不可以调用
---@param params table 面板打开默认参数
---@param immediately boolean 是否立刻打开不播放动画
---@private
function UIController:Open(params, immediately)
	self._isOpen = true
	self._isOpening = false
	self._isClosing = false
	self._isReOpen = false
	self:tryPlayOpenAnimation(immediately)
	self:playerOpenAudio()
	UIBase.Open(self)
	if self.View.WidgetRoot.AdaptForShapedScreen and not _G.StoryEditor then
		self.View.WidgetRoot:AdaptForShapedScreen(Game.SettingsManager:GetScreenPaddingValue())
	end
	-- -- 非SHIPPING包，在内部使用过程中收集打开参数，用于UIAutomationProfile
	-- if not SHIPPING_MODE then
	-- 	self:RecordShowParam(params)
	-- end
	self.widget:SetRenderOpacity(0.0)
	self:StartTimer("UIControllerOpenSetRenderOpacity", function ()
		self.widget:SetRenderOpacity(1.0)
	end, 1, 1)
end

-- -- Debug模式，内部记录打开参数，用于UIAutomationProfile Start
-- function UIController:RecordShowParam(...)
-- 	if import("C7FunctionLibrary").IsC7Editor() or import("C7FunctionLibrary").IsBuildShipping() or _G.bUIAutomationProfile then
-- 		return
-- 	end
-- 	local param = self:tableToString( ... )
-- 	local str = string.format("%s;%s", self.__cname, param)
-- 	HttpRequest("POST", 3, "172.31.136.107", 8000, "text/html", str, false, {},
-- 		function(errorStr, httpCode, responseHeader, body)
-- 			if errorStr and errorStr ~= "" then
-- 				Log.Debug(errorStr)
-- 			end
-- 		end)
-- end

function UIController:tableToString(tbl, indent, depth, maxDepth, visited)
	indent = indent or 0
	depth = depth or 0
	maxDepth = maxDepth or 20

	if depth > maxDepth then
		return string.rep("  ", indent) .. "\"<max depth reached>\""
	end

	visited = visited or {}

	if visited[tbl] then
		return "<circular reference>"
	end

	if type(tbl) ~= "table" and not isKsbcTable(tbl) then
		local tblType = type(tbl)
		if tblType == "string" then
			return string.format("%q", tbl)
		elseif tblType == "number" or tblType == "boolean" then
			return tostring(tbl)
		else
			return "<" .. tblType .. ">"
		end
	end

	visited[tbl] = true

	local lines = {}
	lines[#lines + 1] = string.rep("  ", indent) .. "{"
	for k, v in pairs(tbl) do
		local formattedKey = type(k) == "string" and string.format("[%q]", k) or "[" .. tostring(k) .. "]"
		lines[#lines + 1] = string.rep("  ", indent + 1) .. formattedKey .. " = " ..
			self:tableToString(v, indent + 1, depth + 1, maxDepth, visited) .. ","
	end
	lines[#lines + 1] = string.rep("  ", indent) .. "}"

	visited[tbl] = nil

	return table.concat(lines, "\n")
end

--- Debug模式，内部记录打开参数，用于UIAutomationProfile End 

---打开已经打开的面板，由UIManager调用，业务模块不可以调用
---@param params table 面板打开默认参数
---@param immediately boolean 是否立刻打开不播放动画
---@private
function UIController:ReOpen(params, immediately)
	self._isClosing = false
	self._isReOpen = true
	self:tryPlayOpenAnimation(immediately)
	self:playerOpenAudio()
end

---关闭面板，由UIManager调用，业务模块不可以调用
---@private
---@param immediate boolean 是否立刻关闭不播放动画
---@param finishCallback function 动画完成回调
function UIController:PreClose(immediate, finishCallback)
	self._isClosing = true
	self:changeWorldRendering()
	self:playerCloseAudio()
    if immediate or UIConst.IgnoreAutoFadeOutUI[self.uid]  then
		self:closeAnimationFinish()
		if finishCallback then
			finishCallback()
		end
    else
		self:playCloseAnimation(finishCallback)
	end
end

---@public IsOpening 获取是否在打开中状态
function UIController:IsOpening()
	return self._isOpening
end

---@public IsClosing 获取是否在关闭中状态
function UIController:IsClosing()
	return self._isClosing
end

function UIController:Close()
    --todo wanghuihui cutscene编辑器依赖uimanager，会showui和hideui，hideui依赖红点，红点系统编辑器模式启动有问题
	if Game.RedPointSystem then
		Game.RedPointSystem:OnUIClosed(self.uid, self)
	end
	self._isReOpen = false
	self._isOpening = false
	UIBase.Close(self)
	table.clear(self._loadingChildPanel)
	table.clear(self._lastChildPanelParam)
end

---@param immediately boolean 是否立刻打开不播放动画
function UIController:tryPlayOpenAnimation(immediately)
	self:stopOpenAndCloseTimer()
	if not immediately then
		self:AutoPlayAnimFadeIn()
		self._isOpening = true
		local time = self:GetAnimFadeInTime()
		self:StartTimer("OpenPanelTimer", function() self:openAnimationFinish() end, time * 1000, 1, true)
	else
		self:openAnimationFinish()
	end
end

---@private openAnimationFinish 入场动画播放完成回调
function UIController:openAnimationFinish()
	self._isOpening = false
	self:changeWorldRendering()
	self:OnOpenAnimationFinish()
end

---@protected OnOpenAnimationFinish 入场动画播放完成回调，子类实现
function UIController:OnOpenAnimationFinish()
end

---@param finishCallback function 动画完成回调
function UIController:playCloseAnimation(finishCallback)
	self:AutoPlayAnimFadeOut()
	local time = self:GetAnimFadeOutTime()
	if time > 5 then-- 做下容错防止时间错误界面关不掉
		Log.WarningFormat("UIController: 关闭动画时间超过5秒请检查是否正常 %s", self.uid)
		time = 5
	end
	self:stopOpenAndCloseTimer()
	if time > 0 then
		self:StartTimer("ClosePanelTimer", function()
			self:closeAnimationFinish()
			if finishCallback then
				finishCallback()
			end
		end, time * 1000, 1, true)
	else
		self:closeAnimationFinish()
		if finishCallback then
			finishCallback()
		end
	end
end

---@private closeAnimationFinish
function UIController:closeAnimationFinish()
	self._isClosing = false
	self:OnCloseAnimationFinish()
end

---@protected OnCloseAnimationFinish
function UIController:OnCloseAnimationFinish()
end

function UIController:stopOpenAndCloseTimer()
	self:StopTimer("ClosePanelTimer")
	self:StopTimer("OpenPanelTimer")
end

function UIController:playerOpenAudio()
	local config = self:getUIConfig()
	if config.layout == Enum.EUILayout.FullScreen or config.layout == Enum.EUILayout.FloatFullScreen then
		Game.AkAudioManager:SetGroupState(Enum.EAudioConstData.UI_INTERFACE_GLOBAL_GROUP, Enum.EAudioConstData.IN_INTERFACE_GLOBAL_STATE)
	elseif config.layout == Enum.EUILayout.LeftHalfScreen or config.layout == Enum.EUILayout.RightHalfScreen then
		Game.AkAudioManager:SetGroupState(Enum.EAudioConstData.UI_INTERFACE_HALF_GROUP, Enum.EAudioConstData.IN_INTERFACE_HALF_STATE)
	end
	if config and config.opensound and #config.opensound > 0 then
		for _, opensound in ksbcipairs(config.opensound) do
			Game.AkAudioManager:PostEvent2D(opensound)
		end
	end
end

function UIController:playerCloseAudio()
	local config = self:getUIConfig()
	if config.layout == Enum.EUILayout.FullScreen or config.layout == Enum.EUILayout.FloatFullScreen then
		Game.AkAudioManager:SetGroupState(Enum.EAudioConstData.UI_INTERFACE_GLOBAL_GROUP, Enum.EAudioConstData.OUT_INTERFACE_GLOBAL_STATE)
	elseif config.layout == Enum.EUILayout.LeftHalfScreen or config.layout == Enum.EUILayout.RightHalfScreen then
		Game.AkAudioManager:SetGroupState(Enum.EAudioConstData.UI_INTERFACE_GLOBAL_GROUP, Enum.EAudioConstData.OUT_INTERFACE_HALF_STATE)
	end
	if config and config.closesound and #config.closesound > 0 then
		for _, closesound in ksbcipairs(config.closesound) do
			Game.AkAudioManager:PostEvent2D( closesound)
		end
	end
end

---@private changeWorldRendering
function UIController:changeWorldRendering()
	local config = self:getUIConfig()
	if not config.parent then  --非子界面才能生效
		Game.NewUIManager:UpdateWorldRendering()	
	end
end

--设置面板层级 由UIManager调用，业务模块不可以调用
function UIController:SetCanvasOrder(order)
	self.order = order
	UIFunctionLibrary.SetZOrder(self.userWidget, order)
	if _G.InvalidationBox and not self:getUIConfig().volatile then
		UIFunctionLibrary.SetCanCache(self.userWidget)
	end
end

function UIController:addChildToCanvas(child)
	local slot = self.userWidget:AddChildToCanvas(child)
	local NewAnchors = import("Anchors")()
	NewAnchors.Minimum = FVector2D(0, 0)
	NewAnchors.Maximum = FVector2D(1, 1)
	slot:SetAnchors(NewAnchors)
	slot:SetOffsets(Margin(0, 0, 0, 0))
end

--region ui分辨率适配
function UIController:OnResize()
	if self.View.WidgetRoot.AdaptForShapedScreen and not _G.StoryEditor then
		self.View.WidgetRoot:AdaptForShapedScreen(Game.SettingsManager:GetScreenPaddingValue())
	end
end
--endregion

function UIController:Dispose()
	self.cacheChilePanel:Clear()	--清理缓存的子界面
	self.preloadResMap = nil --释放依赖资源
	self:Destroy()
end

function UIController:CloseSelf()
	if self:IsComponent() and self.parent then
		if self.componentContainer then
			self.parent:PushOneComponent(self.componentContainer,self)
		else
			self.parent:RemoveChildPanel(self.uid)
		end
	else
		UIManager:GetInstance():ClosePanel(self.uid)
	end
end

--region 加载子界面
function UIController:LoadChildPanel(uid, callback, ...)
	local params = {...}
	if self._loadingChildPanel[uid] then
		self._lastChildPanelParam[uid] = params
		Log.InfoFormat("UIFrame.UIController: 打开正在打开的子面板 %s", uid)
		return
	end
	local panel = self.cacheChilePanel:pop(uid)
	if panel then
		self:showChildPanel(panel, params, callback)
		return
	end

	-- luacheck: push ignore
	local func = function(panelRes, preloadResMap)
		self._loadingChildPanel[uid] = nil
		if self._lastChildPanelParam[uid] then
			params = self._lastChildPanelParam[uid]
			self._lastChildPanelParam[uid] = nil
		end
		panel = Game.UIManager:CreatePanel(panelRes, uid, preloadResMap)
		if not panel then
			return
		end
		self:showChildPanel(panel, params, callback)
	end
	-- luacheck: pop
	self._loadingChildPanel[uid] = self:LoadOldUIPanelAsset(uid, func, true)
end

function UIController:showChildPanel(panel, params, callback)
	table.insert(self._childComponents, panel)
	panel:Show()
	panel:Open()
	panel:Refresh(unpack(params))
	UIManager:GetInstance():addIdle(panel)
	self:InvalidateRootChildOrder()
	if callback then
		callback(panel)
	end
end

function UIController:RemoveChildPanel(uid, component)
	if self:stopLoadingChildPanel(uid) then
		return
	end
	if not component then
		for k, v in ipairs(self._childComponents) do
			if v.uid == uid then
				table.remove(self._childComponents, k)
				component = v
				break
			end
		end
		if not component then
			return
		end
	end
	
	if not _G.NoCacheUI then
		self.cacheChilePanel:push(uid, component)
	end
	component:Hide()
	component:Close()
	UIManager:GetInstance():removeIdle(uid)
	if _G.NoCacheUI then
		component:Destroy()
	end
end

function UIController:stopLoadingChildPanel(uid)
	if self._loadingChildPanel[uid] then
		self:CancelTargetLoad(self._loadingChildPanel[uid])
		self._loadingChildPanel[uid] = nil
		self._lastChildPanelParam[uid] = nil
		return true
	end
	return false
end

function UIController:CancelAllLoadingUI()
	for i, v in pairs(self._loadingChildPanel) do
		self:CancelTargetLoad(v)
	end
	table.clear(self._loadingChildPanel)
	table.clear(self._lastChildPanelParam)
end

--endregion 加载子界面

return UIController