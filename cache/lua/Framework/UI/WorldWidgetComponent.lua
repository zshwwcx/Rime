---@class WorldWidgetComponent:UIBase
local WorldWidgetComponent = DefineClass("WorldWidgetComponent", UIBase)
local UUserWidget = import("UserWidget")
-- function WorldWidgetComponent.ctor(self, widget, forbidClick, parent, ...)
-- 	-- if CHECKCELL then
-- 	-- 	local info = debug.getinfo(3)
-- 	-- 	local from = info.name
-- 	-- 	if from ~= "BindListComponent" and from ~= "BindComponent" then
-- 	-- 		Log.Error("use uiowner.BindComponent instead of new", info.source, "|", info.currentline)
-- 	-- 	end
-- 	-- end
-- 	if type(widget) == "table" then
-- 		widget = widget.WidgetRoot
-- 	end
-- 	self.widgetRoot = widget
-- 	local uiView = _G[self.__cname.."View"]
-- 	if uiView then
-- 		self.View = uiView.new(widget, self)
-- 	else
-- 		if widget:IsA(UUserWidget) then
-- 			self.View = setmetatable({WidgetRoot = widget}, UIView._rootMeta)
-- 		else
-- 			self.View = setmetatable({WidgetRoot = widget}, BaseList._rootMeta)
-- 		end
-- 	end
-- 	self.parent = parent
-- 	self:OnCreate(forbidClick, parent, ...)
-- 	if Game.StatAtlasSystem:CheckNeedStatsAtlas() and widget:IsA(UUserWidget) then
-- 		xpcall(Game.StatAtlasSystem.RecordWidget,_G.CallBackError,Game.StatAtlasSystem,self.View.WidgetRoot,self)
-- 	end
-- end

-- function WorldWidgetComponent:ResetParent(parent)
-- 	self.parent = parent
-- end

-- function WorldWidgetComponent:HandleButtonClicked(eventType, button, prefix1, root1, prefix2, root2, param1, param2, param3)
-- 	local r
-- 	if self.parent then
-- 		r = self.parent:HandleButtonClicked(eventType, button, prefix1, root1, prefix2, root2, param1, param2, param3)
-- 	end
-- 	local r2 = UIBase.HandleButtonClicked(self, eventType, button, prefix1, root1, prefix2, root2, param1, param2, param3)
-- 	if r2 then
-- 		return r2
-- 	end
-- 	return r
-- end

-- function WorldWidgetComponent:AddObjectNum(num)
-- 	if self.parent then
-- 		return self.parent:AddObjectNum(num)
-- 	end
-- end

return WorldWidgetComponent