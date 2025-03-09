function CheckRemoteCallArgs(rpcName, ...)
    if not UE_EDITOR then return end
    for i, arg in ipairs({...}) do
        if type(arg) == "userdata" then
            error("invalid type[".. type(arg) .. "] for rpc[".. rpcName .. "] arg" .. i)
        end
    end
    return true
end

---@class OnlineRemoteProxy
OnlineRemoteProxy = DefineClass("OnlineRemoteProxy")
function OnlineRemoteProxy:ctor(entity)
    local metatable = {
        __index = function(_, rpcName)
            local func = function(arg0, ...)
                if not CheckRemoteCallArgs(rpcName, ...) then
                    return
                end
                if arg0 == self or arg0 == nil then
                    entity:call_logic(rpcName, ...)
                else
                    entity:call_logic(rpcName, arg0, ...)
                end
            end
            rawset(self, rpcName, func)
            return func
        end
    }
    setmetatable(self, metatable)
end

---@class DummyRemoteProxy
DummyRemoteProxy = DefineClass("DummyRemoteProxy")
function DummyRemoteProxy:ctor()
    local metatable = {
        __index = function(_, rpcName)
            local func = function(...)
            end
            rawset(self, rpcName, func)
            return func
        end
    }
    setmetatable(self, metatable)
end
