local function mergemro(inLists)
    if not inLists then
        return {}
    end

    for i, mroList in ipairs(inLists) do
        local head = mroList[1]
        local flag = true
        for j = i + 1, #inLists do
            if table.isInArray(inLists[j], head, 2) then
                flag = false
                break
            end
        end

        if flag then
            local nextList = {}
            for _, mergeItem in ipairs(inLists) do
                table.removev(mergeItem, head)
                if #mergeItem >= 1 then
                    table.insert(nextList, mergeItem)
                end
            end
            local res = {head}
            table.extend(res, mergemro(nextList))
            return res
        end
    end

    return {}
end

local function c3mro(cls)
    if cls.__supers == nil then
        return {}
    end

    local mergeList = {}
    for _, baseCls in ipairs(cls.__supers) do
        mergeList[#mergeList+1] = c3mro(baseCls)
    end
    local supersCopy = {}
    for _,s in ipairs(cls.__supers) do
        supersCopy[#supersCopy+1] = s
    end
    mergeList[#mergeList+1] = supersCopy
    local mro = {cls}
    table.extend(mro, mergemro(mergeList))
    return mro
end

-- 枚举下table的所有属性
local function enumDictAttr(obj, res, flag)
    for k,v in pairs(obj) do
        if flag[k] == nil then
            if type(v) == "function" then
                res[#res+1] = k.." f"
            else
                res[#res+1] = k.." v"
            end
            flag[k] = true
        end
    end
end

function GetAllAttr(obj, name)
    -- 在发布版本上禁止这个功能
    if SHIPPING_MODE then
        return ""
    end
    -- 服务端的type(entity)是一个userdata
    local objType = type(obj)
    if not (objType == "table" or (IS_SERVER and objType == "userdata")) then
        return ""
    end

    local isServerEnity = false
    if IS_SERVER and obj.__entity_type ~= nil then
        isServerEnity = true
    end

    local res = {}
    local flag = {}
    -- 直接访问客户端从c#导出类的class属性，如果这个类没有class属性会报错
    local isClass, classContent = pcall(function() return obj.class end)
    if (isClass and classContent) or isServerEnity then
        local mro = c3mro(obj)
        table.insert(mro, obj.class)

        for _, cls in ipairs(mro) do
            enumDictAttr(cls, res, flag)
        end
        -- 服务端table的属性存在metatable的__index里
        if isServerEnity then
            enumDictAttr(getmetatable(obj).__index, res, flag)
            -- 获取一遍entity的属性
            for _,component in ipairs(obj.__components or {})do
                enumDictAttr(component, res, flag)
            end
        else
            enumDictAttr(obj, res, flag)
        end

    else
        enumDictAttr(obj, res, flag)
    end

    -- merge Game.debug_info[cid]._local里的变量
    if name == "_G;" then
        enumDictAttr(_G, res, flag)
    end

    return "<GetAttr>" .. name .. table.concat(res, ";")
end
