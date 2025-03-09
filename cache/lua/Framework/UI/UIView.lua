---@class UIView:Object
local UIView = DefineClass("UIView")
local UIFunctionLibrary = import("UIFunctionLibrary")
local GetWidgetFromName = UIFunctionLibrary.GetWidgetFromName

UIView._rootMetaIndex = function(tb, key)
	local v = rawget(tb, key)
	if not tb.WidgetRoot then
		return nil
	end
	if v == nil then
		--v = tb.WidgetRoot[key.."_lua"]
		v = GetWidgetFromName(tb.WidgetRoot, key .. "_lua")
		if v and not slua.isValid(v) then
			Log.Error(key," maybe unreachable", type(v))
			return
		end
		if v and v:IsA(import("UserWidget")) then
			v = setmetatable({ WidgetRoot = v }, UIView._rootMeta)
		end
		if not v then
			local InnerValue = tb.WidgetRoot[key]
			if type(InnerValue) == "function" then
				v = function(self, ...)
					if self == tb then
						InnerValue(tb.WidgetRoot, ...)
					else
						InnerValue(self, ...)
					end
				end
			else
				v = InnerValue
			end
		end
		rawset(tb, key, v)
	end
	return v
end

--访问节点metatable
UIView._rootMeta = {
	__index = UIView._rootMetaIndex
}

UIViewMetatable = UIViewMetatable or {}
function ModifyUIViewMetatable(instance)
    local cname = instance.__cname
    if UIViewMetatable[cname] then
        setmetatable(instance, UIViewMetatable[cname])
        return
    end

    local oldMt = getmetatable(instance)
    local newMt = {
        __index = function(tb, key)
            return oldMt[key] or UIView._rootMetaIndex(tb, key)
        end
    }
    setmetatable(instance, newMt)
    UIViewMetatable[cname] = newMt
end

function UIView.ctor(self, root, controller)
    ModifyUIViewMetatable(self)
	self.WidgetRoot = root
	self.controller = controller
	self:OnCreate()
end

function UIView:OnCreate()
end

function UIView:OnDestroy()
end