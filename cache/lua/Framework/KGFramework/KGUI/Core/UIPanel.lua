local ShowSceneComponent = kg_require("Framework.KGFramework.KGUI.Component.UIShowScene.UIShowSceneComponent")
local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class UIPanel:NewUIComponent
local UIPanel = DefineClass("UIPanel", UIComponent)

local UserWidget = import("UserWidget")
local EPropertyClass = import("EPropertyClass")
local UIFunctionLibrary = import("UIFunctionLibrary")
local ESlateVisibility = import("ESlateVisibility")

UIPanel.AutoAnimationInName = "Ani_Fadein"
UIPanel.AutoAnimationOutName = "Ani_Fadeout"

--todo start 临时实现点击空白处关闭逻辑
function UIPanel:C7TouchFunc(Geometry, InMouseEvent)
	return Game.NewUIManager:OnC7TouchEvent(self, Geometry, InMouseEvent)
end

function UIPanel:ctor()
	self:AddUIEvent(self.view.OnC7TouchEvent, "C7TouchFunc")
	self.bHadAutoAnimationInfo = false
	self:getAllAutoAnimationInfo()
	self:initSceneComponent()
	self._isOpening = false 	--是否在打开中（入场动画播放过程中）
	self._isClosing = false		--是否在关闭中（退场动画播放过程中）
end
--end 临时实现点击空白处关闭逻辑

--region 面板生命周期
---打开面板，由UIManager调用，业务模块不可以调用
---@param params table 面板打开默认参数
---@param immediately boolean 是否立刻打开不播放动画
---@public
function UIPanel:Open()
	UIComponent.Open(self)
	self:OnResize()
	self._isOpening = false
	self._isClosing = false
	self.userWidget:SetRenderOpacity(0)
	self:StartTimer("UIPanelOpen_SetRenderOpacity", function()
		self.userWidget:SetRenderOpacity(1)
	end, 1, 1)
	self:playOpenAudio()
	self:playOpenAnimation()
end

---打开已经打开的面板，由UIManager调用，业务模块不可以调用
---@param params table 面板打开默认参数
---@param immediately boolean 是否立刻打开不播放动画
---@public
function UIPanel:ReOpen()
	self.userWidget:SetRenderOpacity(0)
	self:StartTimer("UIPanelReOpen_SetRenderOpacity", function()
		self.userWidget:SetRenderOpacity(1)
	end, 1, 1)
	self:playOpenAnimation()
	self:playOpenAudio()
end

---关闭面板，由UIManager调用，业务模块不可以调用
---@public
---@param immediate boolean 是否立刻关闭不播放动画
---@param finishCallback function 动画完成回调
function UIPanel:PreClose(immediate, finishCallback)
	self._isClosing = true
	Game.NewUIManager:UpdateWorldRendering()
	self:playCloseAudio()
	if immediate then
		self:closeAnimationFinish()
		if finishCallback then
			finishCallback()
		end
	else
		self:playCloseAnimation(finishCallback)
	end
end
--endregion

--region 打开/关闭动画和音效
-- 获取所有可以自动播放的动画数据
function UIPanel:getAllAutoAnimationInfo()
	if not self.userWidget:IsA(UserWidget) and self.userWidget ~= self.widget then
		Log.WarningFormat("UIPanel:GetAllAutoAnimationInfo uid%s  class%s 没有生成动画信息", self.uid, self.__cname)
		return
	end
	self.bHadAutoAnimationInfo = self.userWidget.bHadAutoAnimationInfo
	if self.bHadAutoAnimationInfo then
		self.MaxFadeInTime = self.userWidget.KGAnimMaxInTime
		self.MaxFadeOutTime = self.userWidget.KGAnimMaxOutTime
	else
		self.MaxFadeInTime = 0
		self.MaxFadeOutTime = 0
		self.AnimationFadeInList = slua.Array(EPropertyClass.Object, UserWidget)
		self.AnimationFadeOutList = slua.Array(EPropertyClass.Object, UserWidget)
		self.MaxFadeInTime, self.MaxFadeOutTime, self.AnimationFadeInList, self.AnimationFadeOutList = UIFunctionLibrary.GetAllAutoAnimationInfo(self.userWidget, self.MaxFadeInTime, self.MaxFadeOutTime, self.AnimationFadeInList, self.AnimationFadeOutList)
	end
end

-- 获取入场动效时长(包括子蓝图)
function UIPanel:GetAnimFadeInTime()
	return self.MaxFadeInTime
end

-- 获取出场动效时长(包括子蓝图)
function UIPanel:GetAnimFadeOutTime()
	return self.MaxFadeOutTime
end

function UIPanel:playOpenAnimation()
	self._isOpening = true
	-- local time = self:GetAnimFadeInTime()
	-- if time > 0 then
	-- 	if self.view[self.AutoAnimationInName] then
	-- 		self:PlayAnimation(self.view[self.AutoAnimationInName], nil, self.userWidget)
	-- 	else
	-- 		if self.bHadAutoAnimationInfo and self.userWidget.KGAnimInList:Num() > 0 then
	-- 			for _, widgetName in pairs(self.userWidget.KGAnimInList) do
	-- 				local widget = self.view[widgetName]
	-- 				if widget then
	-- 					self:PlayAnimation(widget[self.AutoAnimationInName], nil, widget)
	-- 				end
	-- 			end
	-- 		elseif not self.bHadAutoAnimationInfo and self.AnimationFadeInList:Num() > 0 then
	-- 			for _, widget in pairs(self.AnimationFadeInList) do
	-- 				self:PlayAnimation(widget[self.AutoAnimationInName], nil, widget)
	-- 			end
	-- 		end
	-- 	end
	-- 	self:StartTimer("OpenPanelTimer", function() self:openAnimationFinish() end, time * 1000, 1, true)
	-- else
	-- 	self:openAnimationFinish()
	-- end
	if self.view[self.AutoAnimationInName] then
		self:PlayAnimation(self.view[self.AutoAnimationInName], function() self:openAnimationFinish() end, self.userWidget)
	else
		self:openAnimationFinish()
	end
end

---@param finishCallback function 动画完成回调
function UIPanel:playCloseAnimation(finishCallback)
	if self.view[self.AutoAnimationOutName] then
		self:PlayAnimation(self.view[self.AutoAnimationOutName],function()
		 	if finishCallback then
				finishCallback()
			end
			self:closeAnimationFinish() 

			end, self.userWidget)
	else
		if finishCallback then
			finishCallback()
		end
		self:closeAnimationFinish()
	end
	-- local time = self:GetAnimFadeOutTime()
	-- if time > 0 then
	-- 	if self.view[self.AutoAnimationOutName] then
	-- 		self:PlayAnimation(self.view[self.AutoAnimationOutName], nil, self.userWidget)
	-- 	else
	-- 		if self.bHadAutoAnimationInfo and self.userWidget.KGAnimOutList:Num() > 0 then
	-- 			for _, widgetName in pairs(self.userWidget.KGAnimOutList) do
	-- 				local widget = self.view[widgetName]
	-- 				if widget then
	-- 					self:PlayAnimation(widget[self.AutoAnimationOutName], nil, widget)
	-- 				end
	-- 			end
	-- 		elseif not self.bHadAutoAnimationInfo and self.AnimationFadeOutList:Num() > 0 then
	-- 			for _, widget in pairs(self.AnimationFadeOutList) do
	-- 				self:PlayAnimation(widget[self.AutoAnimationOutName], nil, widget)
	-- 			end
	-- 		end
	-- 	end
	-- 	self:StartTimer("OpenPanelTimer", function()
	-- 		self:closeAnimationFinish()
	-- 		if finishCallback then
	-- 			finishCallback()
	-- 		end
	-- 	end, time * 1000, 1, true)
	-- else
	-- 	self:closeAnimationFinish()
	-- 	if finishCallback then
	-- 		finishCallback()
	-- 	end
	-- end
end

---@private openAnimationFinish
function UIPanel:openAnimationFinish()
	self._isOpening = false
	Game.NewUIManager:UpdateWorldRendering()
	self:OnOpenAnimationFinish()
end

---@protected OnOpenAnimationFinish
function UIPanel:OnOpenAnimationFinish()
end

---@private closeAnimationFinish
function UIPanel:closeAnimationFinish()
	self._isClosing = false
	self:OnCloseAnimationFinish()
end

---@protected OnCloseAnimationFinish
function UIPanel:OnCloseAnimationFinish()
end

function UIPanel:playOpenAudio()
	local config = Game.NewUIManager:GetUIConfig(self.uid)
	if config and config.opensound and #config.opensound > 0 then
		for _, opensound in ksbcipairs(config.opensound) do
			Game.AkAudioManager:PostEvent2D(opensound)
		end
	end
end

function UIPanel:playCloseAudio()
	local config = Game.NewUIManager:GetUIConfig(self.uid)
	if config and config.closesound and #config.closesound > 0 then
		for _, closesound in ksbcipairs(config.closesound) do
			Game.AkAudioManager:PostEvent2D( closesound)
		end
	end
end
--endregion

--region 设置层级
--设置面板层级 由UIManager调用，业务模块不可以调用
function UIPanel:SetCanvasOrder(order)
	self.order = order
	UIFunctionLibrary.SetZOrder(self.userWidget, order)
end

function UIPanel:EnableHitTest()
	self.widget:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
end

function UIPanel:DisableHitTest()
	self.widget:SetVisibility(ESlateVisibility.HitTestInvisible)
end
--endregion

---@public IsOpening 获取是否在打开中状态
function UIPanel:IsOpening()
	return self._isOpening
end

---@public IsClosing 获取是否在关闭中状态
function UIPanel:IsClosing()
	return self._isClosing
end

function UIPanel:OnResize()
	if self.userWidget.AdaptForShapedScreen and not _G.StoryEditor then
		self.userWidget:AdaptForShapedScreen(Game.SettingsManager:GetScreenPaddingValue())
	end
end

function UIPanel:initSceneComponent()
	local config = Game.NewUIManager:GetUIConfig(self.uid)
	if config and config.scenename then
		---@type ShowSceneComponent
		self.sceneComponent = self:CreateComponent(self.widget, ShowSceneComponent)
	end
end

function UIPanel:RefreshShowScene()
	if self.sceneComponent then
		local config = Game.NewUIManager:GetUIConfig(self.uid)
		self.sceneComponent:Refresh(config.scenename,nil, nil,config.RoleShowCameraType,config.FaceCloseUpCameraModeType, config.FocusCoord)
	end
end

function UIPanel:IsPanel()
	return true
end
return UIPanel