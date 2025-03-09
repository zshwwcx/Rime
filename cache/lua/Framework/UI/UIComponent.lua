---@class UIComponent:UIBase
local UIComponent = DefineClass("UIComponent", UIBase)

function UIComponent:HandleButtonClicked(eventType, button, prefix1, root1, prefix2, root2, param1, param2, param3)
	local r
	if self.parent then
		r = self.parent:HandleButtonClicked(eventType, button, prefix1, root1, prefix2, root2, param1, param2, param3)
	end
	local r2 = UIBase.HandleButtonClicked(self, eventType, button, prefix1, root1, prefix2, root2, param1, param2, param3)
	if r2 then
		return r2
	end
	return r
end
return UIComponent