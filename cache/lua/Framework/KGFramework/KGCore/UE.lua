local UE = DefineClass("UE")
-- luacheck: push ignore
local mt = {}
mt.__index = function(tb, key)
    local v = rawget(tb, key)
    if not v then
        v = import(key)
    end
    return v
end

UE = setmetatable({},mt)
-- luacheck: pop
return UE
