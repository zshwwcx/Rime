---@generic T
---@class LuaDelegate 与slua LuaDelegate接口保持一致
local LuaDelegate = DefineClass("LuaDelegate")

function LuaDelegate:ctor()
    self.object = nil
    self.callback = nil
    self.isBind = false
end

---@public AddListener 绑定回调
---@param callback function|string
function LuaDelegate:AddListener(callback)
    self.callback = callback
    self.isBind = true
end

---@public RemoveListener 移除回调
function LuaDelegate:RemoveListener()
    self:Clear()
end

---@public Bind 绑定回调(且绑定回调Owner)
---@param callback function|string
---@param object table|userdata
function LuaDelegate:Bind(callback, object)
    self.callback = callback
    self.object = object
    self.isBind = true
end

---@public Clear 移除回调
function LuaDelegate:Clear()
    self.object = nil
    self.callback = nil
    self.isBind = false
end

function LuaDelegate:IsBind()
    return self.isBind
end

function LuaDelegate:Execute(...)
    if not self.isBind then
        return nil
    end
    if self.object and self.callback then
        local callback = self.callback
        if type(self.callback) == "string" then
            callback = self.object[self.callback]
        end
        if callback then
            local res, info = xpcall(callback, _G.CallBackError, self.object, ...)
            if res then
                return info
            end
        end
    else
        local res, info = xpcall(self.callback, _G.CallBackError, ...)
        if res then
            return info
        end
    end
    return nil
end

function LuaDelegate:dtor()
    self.object = nil
    self.callback = nil
    self.isBind = false
end

return LuaDelegate