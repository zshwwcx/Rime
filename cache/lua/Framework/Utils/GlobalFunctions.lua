
local error = error
local setmetatable = setmetatable
local string_gsub = string.gsub
local string_sub = string.sub
local table_insert = table.insert
local table_sort = table.sort
local type = type

MT_KEY = {}
MT_KEY.__metatable = "READ_ONLY"

function getlen(t)
    if t[MT_KEY] ~= nil then
        return #(t[MT_KEY])
    else
        return #t
    end
end

function loadfile2(moduleName, env)
    local found, chunk
    for i, searcher in ipairs(package.searchers) do
        chunk = searcher(moduleName)
        if type(chunk) == "function" then
            found = true
            break
        end
    end

    if not found then
        error("load " .. moduleName .. ' failed, msg ' .. (msg or 'nil'))
        return
    end

    debug.setupvalue(chunk, 1, env)
    return chunk
end

Game.loaded_data = Game.loaded_data or {}
function require_data(dataName, isReload)
    if Game.loaded_data[dataName] == nil or isReload then
        local data
        local met =  {__index = _G}
        local moduleEnv = setmetatable({}, met)
        if string.lead(dataName, "Shared.data") then
            local name = string_gsub(dataName, "Shared.data", "Data.data", 1)
            local dataModule = loadfile_ex(name, "bt", moduleEnv)
            data = moduleEnv and dataModule() or {}
        elseif string.lead(dataName, "data.") then
            local dataModule = loadfile_ex("Data/" .. dataName, "bt", moduleEnv)
            data = dataModule and dataModule() or {}
        -- elseif C7.bddIgnore and not C7.bddIgnore[dataName] and (not (C7.FORCE_NOT_BDD or USER_OUTER_SCRIPT) and (not UE_EDITOR or FORCE_BDD)) then
        --     data = C7.bddRawG[string_sub(dataName, 6)]
        -- elseif C7.bddIgnore and not C7.bddIgnore[dataName] and OUTER_SCRIPT_BDD and USER_OUTER_SCRIPT then
        --     data = C7.bddRawG[string_sub(dataName, 6)]
        else
            local dataModule = loadfile_ex(dataName, "bt", moduleEnv)
            data = dataModule and dataModule() or {}
        end
        if Game.loaded_data[dataName] == nil then
            Game.loaded_data[dataName] = {}
        end
        Game.loaded_data[dataName].data = data
    end
    return Game.loaded_data[dataName]
end

function unrequire_data(dataName)
    if Game.loaded_data[dataName] then
        Game.loaded_data[dataName] = nil
    end
end

Game.loaded = Game.loaded or {}

local kg_require_black_list = {
    C7 = 1,
    global_functions = 1,
    bson = 1,
    jit = 1,
    bit = 1,
    ffi = 1,
}

local global_var_white_list = {
    "utils.",
    "helpers.const.",
    "common.",
    "share.common.",
    "command.",
    "world.",
}

local global_var_pattern_white_list = {
    "^gameapp%..*_const$",
    "^gameapp%..*_define$",
    "^gameapp%..*_utils$",
}

function forbidGlobalVal(moduleName)
    if true then return false end
    for _, prefix in ipairs(global_var_white_list) do
        if string.lead(moduleName, prefix) then
            return false
        end
    end
    for _, pattern in ipairs(global_var_pattern_white_list) do
        if string.find(moduleName, pattern) then
            return false
        end
    end
    return true
end

forbid_global_val = false

global_val_warn = function(t, k, v)
    if forbid_global_val then
        Log.Error("Do not define global variables here!", tostring(k),  " ", ((debug.getinfo (2, 'n') or {}).name or ""))
    else
        rawset(t, k, v)
    end
end

function kg_require(moduleName, isReload)
    if not isReload and Game.loaded[moduleName] then
        local module = Game.loaded[moduleName]
        return module.Ret ~= nil and module.Ret or module.ENV
    end

    if string.lead(moduleName, "common.") then
        moduleName = string_gsub(moduleName, "common.", "Shared.", 1)
    elseif string.lead(moduleName, "utils.") then
        moduleName = string_gsub(moduleName, "utils.", "Utils.", 1)
    end
    if kg_require_black_list[moduleName] ~= nil or string.lead(moduleName, "Shared.lualibs.") then
        return require(moduleName)
    end
    if string.lead(moduleName, "data.") then
        return nil
    end

    if not Game.loaded[moduleName] then
        Game.loaded[moduleName] = {ENV = {}, Ret = nil}
    end

    local module = Game.loaded[moduleName]
    local met = {__index = _G}
    if UE_EDITOR and forbidGlobalVal(moduleName) then
        met.__newindex = global_val_warn
    end

    local moduleEnv = module.ENV
    setmetatable(moduleEnv, met)
    local ret = loadfile2(moduleName, moduleEnv)
    if ret == nil then
        return nil
    end
    --debug.setupvalue(ret, 1, moduleEnv)
    module.Ret = ret()
    Game.loaded[moduleName] = module
    if module.Ret == nil then  --Module没有返回值的话，尝试获取下Module里定义的唯一class
        local envValueCount, value, bOnlyOne = 0, nil, true
        for i, v in pairs(moduleEnv) do
            envValueCount = envValueCount + 1
            if envValueCount > 1 then
                bOnlyOne = false
                break
            end
            value = v
        end
        if bOnlyOne and type(value) == "table" and value.__cname then
            module.Ret = value
        end
    end
    return module.Ret ~= nil and module.Ret or module.ENV
end

function ReloadAllLua()
    Game.RefreshScript = true
    ComponentToEntity = {}
    ComponentToEntityMap = {}
    for k, v in pairs(Game.loaded or {}) do
        kg_require(k, true)
    end
    Game.RefreshScript = false
    DebugInfo("RefreshLuaComplete !")
end
--c7 fix End

local primalPrint = _G.print
_G.print = function(...)
    local t = {...}
    local len = select("#", ...)
    for i = 1, len do
        if t[i] == nil then
            t[i] = "nil"
        elseif type(t[i]) == "string" then
            t[i] = "\""..t[i].."\""
        end
    end
    return primalPrint(unpack(t))
end

function pairsByKeys (t, f)
    local a = {}
    for n in pairs(t) do table_insert(a, n) end
    table_sort(a, f)
    local i = 0                 -- iterator variable
    local iter = function ()    -- iterator function
       i = i + 1
       if a[i] == nil then return nil
       else return a[i], t[a[i]]
       end
    end
    return iter
end

function callFormula(formulaId, ...)
    local formulaData = kg_require("data.formula_data")
    local formula = formulaData.data[formulaId].formula
    return formula(...)
end



