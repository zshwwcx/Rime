SDKHelper = SDKHelper or {}

function SDKHelper.mergeListToTableAsSet(des, target)
    for _, k in ipairs(target) do
        des[k] = true
    end
end

function SDKHelper.tableKeyList(target)
    local out = {}
    for k, _ in pairs(target) do
        out[#out + 1] = k
    end
    return out
end


function SDKHelper.tableCount(target)
    local out = 0
    for _, _ in pairs(target) do
        out = out + 1
    end
    return out
end


--- 数组反转迭代器
---@generic T
---@param tbl T[]
---@return fun(): T
function SDKHelper.ReverseTable(tbl)
    local index = #tbl + 1
    return function()
        index = index - 1
        return tbl[index]
    end
end