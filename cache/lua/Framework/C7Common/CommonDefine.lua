
--local stringSub = string.sub

-- region 全局锁相关函数
function GlobalLock(t)
    --local mt = getmetatable(t) or {}
    --mt.__newindex = function(table, k, v)
    --    if (k ~= "_" and stringSub(k, 1, 2) ~= "__") then
    --        error("GLOBALS are locked -- " .. k .. " must be declared local or prefix with '__' for globals.", 2)
    --    else
    --        rawset(table, k, v)
    --    end
    --end
    --setmetatable(t, mt)
    --
    --__G_LOCK = true -- luacheck: ignore
end

function GlobalUnlock(t)
    --local mt = getmetatable(t) or {}
    --mt.__newindex = rawset
    --setmetatable(t, mt)
    --
    --__G_LOCK = false  -- luacheck: ignore
end
-- endregion