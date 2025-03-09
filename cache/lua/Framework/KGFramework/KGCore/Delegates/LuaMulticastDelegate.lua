---@generic T
---@class LuaMulticastDelegate 与slua LuaMultiDelegate接口保持一致
---@field callbacks table<number, T>
local LuaMulticastDelegate = DefineClass("LuaMulticastDelegate")

function LuaMulticastDelegate:ctor()
    self.listeners = nil
    self.callbacks = nil
end

---@public AddListener 添加回调
---@param callback function|string
function LuaMulticastDelegate:AddListener(callback)
    if self.callbacks == nil then
        self.callbacks = {}
    end
    table.insert(self.callbacks, callback)
end

---@public RemoveListener 移除回调
---@param callback function
function LuaMulticastDelegate:RemoveListener(callback)
    if self.callbacks == nil then
        return
    end
    table.removeItem(self.callbacks, callback)
end

---@public Add 添加回调(且绑定回调Owner)
---@param object table|userdata
---@param callback function|string
function LuaMulticastDelegate:Add(object, callback)
    if self.listeners == nil then
        self.listeners = {}
        setmetatable(self.listeners, {__mode = "k"})
    end
    self.listeners[object] = self.listeners[object] or {}
    self.listeners[object][callback] = callback
end

---@public Remove 移除回调(通过回调Owner)
---@param object table|userdata
---@param callback function|string
function LuaMulticastDelegate:Remove(object, callback)
    if not object or not self.listeners then
        return
    end

    local FunctionTable = self.listeners[object]
    if FunctionTable then
        FunctionTable[callback] = nil
    end
end

---@public RemoveObject 移除Object所有回调
---@param object table|userdata
function LuaMulticastDelegate:RemoveObject(object)
    if not object or not self.listeners then
        return
    end
    self.listeners[object] = nil
end

function LuaMulticastDelegate:Clear()
    table.clear(self.listeners)
    table.clear(self.callbacks)
end

function LuaMulticastDelegate:Broadcast(...)
    if self.callbacks then
        for _, callback in ipairs(self.callbacks) do
            xpcall(callback, _G.CallBackError, ...)
        end
    end
    if self.listeners then
        for object, funcs in pairs(self.listeners) do
            for _, func in pairs(funcs) do
                if type(func) == "string" then
                    local callback = object[func]
                    if callback then
                        xpcall(callback, _G.CallBackError, object, ...)
                    end
                else
                    xpcall(func, _G.CallBackError, object, ...)
                end
            end
        end
    end
end

function LuaMulticastDelegate:IsBind()
    return self.callbacks and (#self.callbacks > 0)
end

function LuaMulticastDelegate:dtor()
    self.listeners = nil
    self.callbacks = nil
end


return LuaMulticastDelegate