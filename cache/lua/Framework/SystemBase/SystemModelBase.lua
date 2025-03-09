---@class SystemModelBase
SystemModelBase = DefineClass("SystemModelBase")

---ctor
---@param clearOnDisconnect boolean 断线时是否执行clear
---@param clearOnLogoutOrSelectRole boolean 登出或返回选角时是否执行clear
function SystemModelBase:ctor(clearOnDisconnect,clearOnLogoutOrSelectRole)
    --Editor状态下没有Game.SystemManager，因此这里加个判断
    if clearOnDisconnect and Game.SystemManager then
        Game.SystemManager:RegisterModelOfInitOnDisconnect(self)
    end
    if clearOnLogoutOrSelectRole and Game.SystemManager then
        Game.SystemManager:RegisterModelOfInitOnLogout(self)
    end
    self:init()
end

--Clear 由框架调用，在方法内部实现清理数据
function SystemModelBase:Clear()
    self:clear()
end

function SystemModelBase:dtor()
    self:unInit()
end

function SystemModelBase:init()

end

function SystemModelBase:clear()

end

function SystemModelBase:unInit()

end