---@class SystemSenderBase
SystemSenderBase = DefineClass("SystemSenderBase")

---@field Bridge table 
---@field MainPlayer MainPlayer 主角Entity

SystemSenderBase.MainPlayer = nil
SystemSenderBase.Bridge = {}
setmetatable(SystemSenderBase.Bridge,{__index = function(t,key)
    if SystemSenderBase.MainPlayer then
        return SystemSenderBase.MainPlayer[key]
    else
        return SystemSenderBase.emptySendFunc
    end
end})

function SystemSenderBase:ctor()
end

function SystemSenderBase:emptySendFunc()
    return false
end