local UIFly = DefineClass("UIFly")

local FVector2D = FVector2D

local tempPos = FVector2D()
local tempOpacity = 0.0

function UIFly:ctor(ui)
	self._flytb = nil
	self._baseui = ui
end

---向上飞，线性插值过去
---@public
---@param ui 控件
---@param endX 结束点屏幕x坐标
---@param endY 结束点屏幕y坐标
---@param callback function 结束移动后回调函数
---@param stax 开始点屏幕x坐标，默认值为控件当前位置
---@param stay 开始点屏幕y坐标，默认值为控件当前位置
---@param t int 移动时间，ms值，默认为1000ms
---@param endScale number 结束时缩放值，为空不进行缩放
function UIFly:FlyTo(ui, endX, endY, callback, stax, stay, t, endScale, staScale, endOpacity, staOpacity)
	if not stax then
		local pos = ui.Slot:GetPosition()
		stax, stay = pos.X, pos.Y
	else
		local pos = UIHelper.ScreenToWidgetLocal(ui, stax, stay)
		ui.Slot:SetPosition(pos)
		stax, stay = pos.X, pos.Y
	end

	local pos = UIHelper.ScreenToWidgetLocal(ui, endX, endY)
	endX, endY = pos.X, pos.Y
	self:FlyToLocal(ui, endX, endY, callback, stax, stay, t, endScale, staScale, endOpacity, staOpacity)
end

---向上飞，线性插值过去
---@public
---@param ui 控件
---@param endX 结束点局部x坐标
---@param endY 结束点局部y坐标
---@param callback function 结束移动后回调函数
---@param stax 开始点局部x坐标，默认值为控件当前位置
---@param stay 开始点局部y坐标，默认值为控件当前位置
---@param t int 移动时间，ms值，默认为1000ms
---@param endScale number 结束时缩放值，为空不进行缩放
function UIFly:FlyToLocal(ui, endX, endY, callback, stax, stay, t, endScale, staScale, endOpacity, staOpacity)
	-- Log.Warning("FlyTo1 ", stax, " stay ", stay, " endX ", endX, " endY ", endY)
	if not stax then
		local pos = ui.Slot:GetPosition()
		stax, stay = pos.X, pos.Y
	end

	-- Log.Warning("FlyTo2 ", stax, " stay ", stay, " endX ", endX, " endY ", endY)
	local size
	if endScale then
		size = ui.Slot:GetSize()
	end

	local opacity
	if endOpacity then
		opacity = staOpacity or ui:GetRenderOpacity()
	end
	local disy = endY - stay
	local disx = endX - stax


	t = t or 1000
	local ax = disx / t -- vt=1/3v0 => v0=1.5at, a=s/t^2
	local ay = disy / t

	local name
	if type(ui) == "table" then
		name = ui.WidgetRoot:GetName()
	else
		name = ui:GetName()
	end
	name = name .. '_fly'
	-- if self._baseui.UITimer._timers then
	-- 	local tid = self._baseui.UITimer._timers[name]
	-- 	if tid then
	-- 		Game.TimerManager:StopTimerAndKill(tid)
	-- 		self._baseui.UITimer._timers[name] = nil
	-- 		local tb = self._flytb[name]
	-- 		if tb and tb.ui then
	-- 			local ui = tb.ui
	-- 			tempPos.X = tb.x
	-- 			tempPos.Y = tb.y
	-- 			ui.Slot:SetPosition(tempPos)
	-- 			if tb.cb then tb.cb() end
	-- 		end
	-- 		self._flytb[name] = nil
	-- 		tb = nil
	-- 	end
	-- end
	
	self._baseui:StopTimer(name)
	if self._flytb and self._flytb[name] then
		local tb = self._flytb[name]
		if tb and tb.ui then
			local ui = tb.ui
			tempPos.X = tb.x
			tempPos.Y = tb.y
			ui.Slot:SetPosition(tempPos)
			if tb.cb then tb.cb() end
		end
		self._flytb[name] = nil
		tb = nil
	end
	if not self._flytb then
		self._flytb = {}
	end

	local nowfly = { ui = 1, x = 1, y = 1, cb = 1 }
	nowfly.ui = ui
	nowfly.x = endX
	nowfly.y = endY
	nowfly.cb = callback
	self._flytb[name] = nowfly
	nowfly = nil

	local flytime = 0

	local func = function(e)
		flytime = flytime + e
		if flytime >= t then
			tempPos.X = endX
			tempPos.Y = endY
			ui.Slot:SetPosition(tempPos)
			if endScale then
				tempPos.X = size.X * endScale
				tempPos.Y = size.Y * endScale
				ui.Slot:SetSize(tempPos)
			end
			if endOpacity then
				ui:SetRenderOpacity(endOpacity)
			end
			-- local tid = self._timers[name]
			-- if tid then
			-- 	Game.TimerManager:StopTimerAndKill(tid)
			-- 	self._timers[name] = nil
			-- 	self._flytb[name] = nil
			-- 	if callback then callback() end
			-- end
			self._baseui:StopTimer(name)
			if self._flytb and self._flytb[name] then
				self._flytb[name] = nil
				if callback then callback() end
			end
		else
			local temp = flytime
			tempPos.X = stax + temp * ax
			tempPos.Y = stay + temp * ay
			ui.Slot:SetPosition(tempPos)
			if endScale then
				tempPos.X = size.X * (1 - (1 - endScale) * flytime / t)
				tempPos.Y = size.Y * (1 - (1 - endScale) * flytime / t)
				ui.Slot:SetSize(tempPos)
			end
			if endOpacity then
				tempOpacity = opacity * (1 - (1 - endOpacity) * flytime / t)
				ui:SetRenderOpacity(tempOpacity)
			end
		end
	end
	self._baseui:StartTimer(name,func, 1,-1) --调用次数较多时，即每帧调用
end


---向上飞，曲线飞过去
---@public
---@param ui 控件
---@param endX 结束点屏幕x坐标
---@param endY 结束点屏幕y坐标
---@param callback function 结束移动后回调函数
function UIFly:FlyItemTo(ui, endX, endY, callback) --向上飞,复用型FlyItemTo
	local pos = ui.Slot:GetPosition()
	local stax, stay = pos.X, pos.Y
	local size = ui.Slot:GetSize()
	local npos = UIHelper.ScreenToWidgetLocal(ui, endX, endY)
	endX, endY = npos.X, npos.Y

	local disy = endY - stay
	local disx = endX - stax

	local name
	if type(ui) == "table" then
		name = ui.WidgetRoot:GetName()
	else
		name = ui:GetName()
	end
	name = name .. '_flyItem'

	-- if self._timers then
	-- 	local tid = self._timers[name]
	-- 	if tid then
	-- 		Game.TimerManager:StopTimerAndKill(tid)
	-- 		self._timers[name] = nil
	-- 		local tb = self._flytb[name]
	-- 		if tb and tb.ui then
	-- 			local ui = tb.ui
	-- 			tempPos.X = tb.x
	-- 			tempPos.Y = tb.y
	-- 			ui.Slot:SetPosition(tempPos)
	-- 			if tb.cb then tb.cb() end
	-- 		end
	-- 		self._flytb[name] = nil
	-- 		tb = nil
	-- 	end
	-- end
	self._baseui:StopTimer(name)
	if self._flytb and self._flytb[name] then
		local tb = self._flytb[name]
		if tb and tb.ui then
			local ui = tb.ui
			tempPos.X = tb.x
			tempPos.Y = tb.y
			ui.Slot:SetPosition(tempPos)
			if tb.cb then tb.cb() end
		end
		self._flytb[name] = nil
		tb = nil
	end

	if not self._flytb then
		self._flytb = {}
	end

	local nowfly = { ui = 1, x = 1, y = 1, cb = 1 }
	nowfly.ui = ui
	nowfly.x = endX
	nowfly.y = endY
	nowfly.cb = callback
	self._flytb[name] = nowfly
	nowfly = nil

	local flytime = 0
	local func = function(e)
		flytime = flytime + e
		if flytime >= 1000 then
			tempPos.X = endX
			tempPos.Y = endY
			ui.Slot:SetPosition(tempPos)
			--local tid = self._timers[name]
			-- if tid then
			-- 	Game.TimerManager:StopTimerAndKill(tid)
			-- 	self._timers[name] = nil
			-- 	self._flytb[name] = nil
			-- 	if callback then callback() end
			-- end
			self._baseui:StopTimer(name)
			if self._flytb and self._flytb[name] then
				self._flytb[name] = nil
				if callback then callback() end
			end
		else
			local temp = flytime * flytime / 1000000
			local temp2 = math.sin(flytime / 1000 * 3.14)
			local temp3 = 1 - flytime / 1400
			tempPos.X = stax + temp * disx - temp2 * disy / 3
			tempPos.Y = stay + temp * disy - temp2 * math.abs(disx) / 3
			ui.Slot:SetPosition(tempPos)
			tempPos = size * temp3
			ui.Slot:SetSize(tempPos)
		end
	end
	self._baseui:StartTimer(name,func, 30, -1) --调用次数较多时，即每帧调用
end

function UIFly:Dispose()
	self._flytb = nil
	self._baseui = nil
end

--endregion
return UIFly