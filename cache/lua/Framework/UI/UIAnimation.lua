local UIAnimation = DefineClass("UIAnimation")
local UserWidget = import("UserWidget")
local UIFunctionLibrary = import("UIFunctionLibrary")
UIAnimation.aid = 0

UIAnimation.AutoAnimationInName = "Ani_Fadein"
UIAnimation.AutoAnimationOutName = "Ani_Fadeout"
local EUMGSequencePlayMode = import("EUMGSequencePlayMode")
local EPropertyClass = import("EPropertyClass")

function UIAnimation:ctor()
	---@type table<UIView, table<UWidgetAnimation, UWidgetAnimation>>
	self._animationBindings = {}--播前绑定，播完立刻解绑，避免出现动画有时想要回调，有时又不想回调的情况
	self.bHadAutoAnimationInfo = false --蓝图是否包含入场/出场动画数据
end

--region 播放动画
-- 2024.12.16 update by ZSH: 这里做了一波性能优化，干掉了第10个参数：bIsAsync的参数传递，默认全部为true，将PlayAnimation平均耗时从480us降低到了70us。但是只修改了UIAnimation接口+CPP部分代码，业务侧没有执行清理，走lua默认多参抛弃，后续新增接口的时候需要注意
function UIAnimation:PlayAnimation(widget, inAnimation, startAtTime, numLoopsToPlay, playMode, playbackSpeed, bRestoreState, onComplete, args)
	if self.IsShow and not self:IsShow() then
		return
	end
	if nil == widget then
		Log.Error("PlayAnimation failed, widget is nil")
		return
	end

	if nil == inAnimation then
		Log.Error("PlayAnimation failed, inAnimation is nil")
		return
	end
	-- 播放动效开始， force Volatile，降低cache的性能消耗
	widget:ForceVolatile(true)

	startAtTime = startAtTime or 0
	playbackSpeed = playbackSpeed or 1.0

	if not self._animationBindings[widget] then
		self._animationBindings[widget] = {}
	end

	self:RemoveUIListener(EUIEventTypes.OnAnimationFinished, widget, inAnimation)
	if onComplete then
		-- luacheck: push ignore
		local callback = function()
			self:RemoveUIListener(EUIEventTypes.OnAnimationFinished, widget, inAnimation)
			self._animationBindings[widget][inAnimation] = nil
			-- 播放动效结束，取消Volatile，继续保持cache
			widget:ForceVolatile(false)
			onComplete(args)
		end
		-- luacheck: pop
		self:AddUIListener(EUIEventTypes.OnAnimationFinished, widget, callback, inAnimation)
		self._animationBindings[widget][inAnimation] = inAnimation
	end
	widget:PlayAnimation(inAnimation, startAtTime, numLoopsToPlay, playMode, playbackSpeed, bRestoreState)
end

function UIAnimation:PlayAnimationTimeRange(widget, inAnimation, startAtTime, endAtTime, numLoopsToPlay, playMode, playbackSpeed, bRestoreState, onComplete, args)
	if not self:IsShow() then
		return
	end
	if nil == widget then
		Log.Error("PlayAnimationTimeRange failed, widget is nil")
		return
	end

	if nil == inAnimation then
		Log.Error("PlayAnimationTimeRange failed, inAnimation is nil")
		return
	end
	-- 播放动效开始， force Volatile，降低cache的性能消耗
	widget:ForceVolatile(true)

	startAtTime = startAtTime or 0
	endAtTime = endAtTime or inAnimation:GetEndTime()
	playbackSpeed = playbackSpeed or 1.0
	if not self._animationBindings[widget] then
		self._animationBindings[widget] = {}
	end

	self:RemoveUIListener(EUIEventTypes.OnAnimationFinished, widget, inAnimation)

	if onComplete then
		-- luacheck: push ignore
		local callback = function()
			self:RemoveUIListener(EUIEventTypes.OnAnimationFinished, widget, inAnimation)
			self._animationBindings[widget][inAnimation] = nil
			-- 播放动效结束，取消Volatile，继续保持cache
			widget:ForceVolatile(false)
			onComplete(args)
		end
		-- luacheck: pop
		self:AddUIListener(EUIEventTypes.OnAnimationFinished, widget, callback, inAnimation)
		self._animationBindings[widget][inAnimation] = inAnimation
	end
	widget:PlayAnimationTimeRange(inAnimation, startAtTime, endAtTime, numLoopsToPlay or 1, playMode or EUMGSequencePlayMode.Forward, playbackSpeed, bRestoreState or false)
end

function UIAnimation:PlayAnimationForward(widget, inAnimation, playbackSpeed, bRestoreState, onComplete, args)
	if not self:IsShow() then
		return
	end
	if nil == widget then
		Log.Error("PlayAnimationForward failed, widget is nil")
		return
	end

	if nil == inAnimation then
		Log.Error("PlayAnimationForward failed, inAnimation is nil")
		return
	end
	-- 播放动效开始， force Volatile，降低cache的性能消耗
	widget:ForceVolatile(true)

	local startAtTime = 0
	playbackSpeed = playbackSpeed or 1.0

	if not self._animationBindings[widget] then
		self._animationBindings[widget] = {}
	end
	self:RemoveUIListener(EUIEventTypes.OnAnimationFinished, widget, inAnimation)

	if onComplete then
		-- luacheck: push ignore
		local callback = function()
			self:RemoveUIListener(EUIEventTypes.OnAnimationFinished, widget, inAnimation)
			self._animationBindings[widget][inAnimation] = nil
			-- 播放动效结束，取消Volatile，继续保持cache
			widget:ForceVolatile(false)
			onComplete(args)
		end
		-- luacheck: pop
		self:AddUIListener(EUIEventTypes.OnAnimationFinished, widget, callback, inAnimation)
		self._animationBindings[widget][inAnimation] = inAnimation
		if widget:IsAnimationPlaying(inAnimation) then
			startAtTime = widget:GetAnimationCurrentTime(inAnimation)
		end
	end
	widget:PlayAnimation(inAnimation, startAtTime, 1, EUMGSequencePlayMode.Forward, playbackSpeed, bRestoreState or false)
end

function UIAnimation:PlayAnimationReverse(widget, inAnimation, playbackSpeed, bRestoreState, onComplete, args)
	if not self:IsShow() then
		return
	end
	if nil == widget then
		Log.Error("PlayAnimationReverse failed, widget is nil")
		return
	end

	if nil == inAnimation then
		Log.Error("PlayAnimationReverse failed, inAnimation is nil")
		return
	end
	-- 播放动效开始， force Volatile，降低cache的性能消耗
	widget:ForceVolatile(true)

	local startAtTime = 0
	playbackSpeed = playbackSpeed or 1.0

	if not self._animationBindings[widget] then
		self._animationBindings[widget] = {}
	end
	self:RemoveUIListener(EUIEventTypes.OnAnimationFinished, widget, inAnimation)

	if onComplete then
		-- luacheck: push ignore
		local callback = function()
			self:RemoveUIListener(EUIEventTypes.OnAnimationFinished, widget, inAnimation)
			self._animationBindings[widget][inAnimation] = nil
			-- 播放动效结束，取消Volatile，继续保持cache
			widget:ForceVolatile(false)
			onComplete(args)
		end
		-- luacheck: pop
		self:AddUIListener(EUIEventTypes.OnAnimationFinished, widget, callback, inAnimation)
		self._animationBindings[widget][inAnimation] = inAnimation
		if widget:IsAnimationPlaying(inAnimation) then
			startAtTime = inAnimation:GetEndTime() - widget:GetAnimationCurrentTime(inAnimation)
		end
	end
	widget:PlayAnimation(inAnimation, startAtTime, 1, EUMGSequencePlayMode.Reverse, playbackSpeed, bRestoreState or false)
end

function UIAnimation:StopAnimation(widget, inAnimation, recover)
	if nil == widget then
		Log.Error("StopAnimation failed, widget is nil")
		return
	end

	if nil == inAnimation then
		Log.Error("StopAnimation failed, inAnimation is nil")
		return
	end

	if recover then
		self:SetWidgetToAnimationStartInstantly(widget, inAnimation)
	end

	widget:StopAnimation(inAnimation)

	local bindingsfromwidget = self._animationBindings[widget]
	if not bindingsfromwidget then
		return
	end
	bindingsfromwidget[inAnimation] = nil
	self:RemoveUIListener(EUIEventTypes.OnAnimationFinished, widget, inAnimation)
	-- 播放动效结束，取消Volatile，继续保持cache
	widget:ForceVolatile(false)
end

function UIAnimation:StopAllAnimations(widget)
	if nil == widget then
		Log.Error("StopAllAnimations failed, widget is nil")
		return
	end

	widget:StopAllAnimations()

	if not self._animationBindings[widget] then return end

	for _, Ani in pairs(self._animationBindings[widget]) do
		self:RemoveUIListener(EUIEventTypes.OnAnimationFinished, widget, Ani)
	end
	table.clear(self._animationBindings[widget])
end

-- 递归停止所有userWidget的动效，包括所有子蓝图，有递归性能消耗，谨慎使用
function UIAnimation:StopAllAnimationsRecursively(widget)
	widget:StopAllAnimationsRecursively()
end

function UIAnimation:PauseAnimation(widget, inAnimation)
	if not self:IsShow() then
		return
	end
	if nil == widget then
		Log.Error("PauseAnimation failed, widget is nil")
		return
	end

	widget:PauseAnimation(inAnimation)

	local bindingsfromwidget = self._animationBindings[widget]
	if not bindingsfromwidget then
		return
	end
	bindingsfromwidget[inAnimation] = nil
	self:RemoveUIListener(EUIEventTypes.OnAnimationFinished, widget, inAnimation)
	-- 播放动效结束，取消Volatile，继续保持cache
	widget:ForceVolatile(false)
end

function UIAnimation:ClearAnimation()
	for widget, Animations in pairs(self._animationBindings) do
		for Ani, _ in pairs(Animations) do
			self:RemoveUIListener(EUIEventTypes.OnAnimationFinished, widget, Ani)
		end
		widget:StopAllAnimations()
	end
	table.clear(self._animationBindings)
end


---UE原生逻辑下，直接播放动画到最后一帧势必会分两帧执行
---即：第一帧开始播放，在SequencePlayer->PlayInternal中更新
---第二帧在SequencePlayer->Tick中更新，并停止播放
---这里开始播后立即结束，即在同一帧执行两次分别来自SequencePlayer->Play/Stop的更新
---强制在一帧内结束工作，防止和框架控制显隐发生冲突
---@param widget UC7UserWidget
---@param inAnimation UWidgetAnimation
function UIAnimation:SetWidgetToAnimationEndInstantly(widget, inAnimation)
	if nil == widget then
		Log.Error("PlayAnimation failed, widget is nil")
		return
	end

	if nil == inAnimation then
		Log.Error("PlayAnimation failed, inAnimation is nil")
		return
	end
	widget:PlayAnimation(
		inAnimation, inAnimation:GetEndTime(), 1,
		EUMGSequencePlayMode.Forward, 1, false, true
	)
	widget:StopAnimation(inAnimation)
end

---@param widget UC7UserWidget
---@param inAnimation UWidgetAnimation
function UIAnimation:SetWidgetToAnimationStartInstantly(widget, inAnimation)
	if nil == widget then
		Log.Error("PlayAnimation failed, widget is nil")
		return
	end

	if nil == inAnimation then
		Log.Error("PlayAnimation failed, inAnimation is nil")
		return
	end
	widget:PlayAnimation(
		inAnimation, inAnimation:GetEndTime(), 1,
		EUMGSequencePlayMode.Reverse, 1, false, true
	)
	widget:StopAnimation(inAnimation)
end
--endregion


-- 获取所有可以自动播放的动画数据
function UIAnimation:GetAllAutoAnimationInfo()
	if not self.userWidget:IsA(UserWidget) and self.userWidget ~=self.Widget then
		Log.WarningFormat("UIAnimation:GetAllAutoAnimationInfo uid%s  class%s 没有生成动画信息", self.uid, self.__cname)
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
		self.MaxFadeInTime , self.MaxFadeOutTime, self.AnimationFadeInList, self.AnimationFadeOutList = UIFunctionLibrary.GetAllAutoAnimationInfo(self.userWidget, self.MaxFadeInTime, self.MaxFadeOutTime, self.AnimationFadeInList, self.AnimationFadeOutList)
	end
end

-- 自动播放入场动效: Ani_Fadein
function UIAnimation:AutoPlayAnimFadeIn()
	if self.MaxFadeInTime <= 0 then
		return
	end
	if self.View[UIAnimation.AutoAnimationInName] then
		self:PlayAnimation(self.View.WidgetRoot, self.View[UIAnimation.AutoAnimationInName], 0.0, 1, EUMGSequencePlayMode.Forward, 1, false)
	else
		if self.bHadAutoAnimationInfo and self.userWidget.KGAnimInList:Num() > 0 then
			for _, widgetName in pairs(self.userWidget.KGAnimInList) do
				local widget = self.View[widgetName]
				if widget then
					self:PlayAnimation(widget, widget[UIAnimation.AutoAnimationInName], 0.0, 1, EUMGSequencePlayMode.Forward, 1, false)
				end
			end
		elseif not self.bHadAutoAnimationInfo and self.AnimationFadeInList:Num() > 0 then
			for _, widget in pairs(self.AnimationFadeInList) do
				self:PlayAnimation(widget, widget[UIAnimation.AutoAnimationInName], 0.0, 1, EUMGSequencePlayMode.Forward, 1, false)
			end
		end
	end
end

-- 自动播放出场动效: Ani_Fadeout
function UIAnimation:AutoPlayAnimFadeOut()
	if self.MaxFadeOutTime <= 0 then
		return
	end
	
	if self.View[UIAnimation.AutoAnimationOutName] then
		self:PlayAnimation(self.View.WidgetRoot, self.View[UIAnimation.AutoAnimationOutName], 0.0, 1, EUMGSequencePlayMode.Forward, 1, false)
	else
		if self.bHadAutoAnimationInfo and self.userWidget.KGAnimOutList:Num() > 0 then
			local StartTime = 0
			for index, widgetName in pairs(self.userWidget.KGAnimOutList) do
				local widget = self.View[widgetName]
				if widget then
					local TimerName = "Timer_AniOut"..tostring(index)
					if self[TimerName] then
						self:StopTimer(TimerName)
					end
					self[TimerName] = self:StartTimer(TimerName, function ()
						widget:PlayAnimation(widget[UIAnimation.AutoAnimationOutName], 0.0, 1, EUMGSequencePlayMode.Forward, 1, false)
					end, StartTime, 1)
					StartTime = StartTime + 30
				end
			end
		elseif not self.bHadAutoAnimationInfo and self.AnimationFadeOutList:Num() > 0 then
			local StartTime = 0
			for index, widget in pairs(self.AnimationFadeOutList) do
				local TimerName = "Timer_AniOut"..tostring(index)
				if self[TimerName] then
					self:StopTimer(TimerName)
				end
				self[TimerName] = self:StartTimer(TimerName, function ()
					widget:PlayAnimation(widget[UIAnimation.AutoAnimationOutName], 0.0, 1, EUMGSequencePlayMode.Forward, 1, false)
				end, StartTime, 1)
				StartTime = StartTime + 30
			end
		end
	end
end

-- 获取入场动效时长(包括子蓝图)
function UIAnimation:GetAnimFadeInTime()
	return self.MaxFadeInTime
end

-- 获取出场动效时长(包括子蓝图)
function UIAnimation:GetAnimFadeOutTime()
	return self.MaxFadeOutTime
end

function UIAnimation:GetAid()
	UIAnimation.aid = UIAnimation.aid + 1
	return UIAnimation.aid
end

return UIAnimation