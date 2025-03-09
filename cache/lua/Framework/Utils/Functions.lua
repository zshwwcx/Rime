function traceback(msg)
    msg = debug.traceback(msg, 2)
    return msg
end

function LuaGC()
    local c = collectgarbage("count")
    Log.Info("Begin gc count = {0} kb", c)
    collectgarbage("collect")
    c = collectgarbage("count")
    Log.Info("End gc count = {0} kb", c)
end

--------------------------------------------------
-- Util functions about table
function RemoveTableItem(list, item, removeAll)
    local rmCount = 0

    for i = 1, #list do
        if list[i - rmCount] == item then
            table.remove(list, i - rmCount)

            if removeAll then
                rmCount = rmCount + 1
            else
                break
            end
        end
    end
end

-- function table.equal(a, b)
--     if a == nil then
--         return b == nil
--     end
--     if b == nil then
--         return false
--     end
--     if #a ~= #b then
--         return false
--     end
--     for i = 1, #a do
--         if a[i] ~= b[i] then
--             return false
--         end
--     end
--     return true
-- end

-- From http://lua-users.org/wiki/TableUtils
function table.val_to_str(v)
    if "string" == type(v) then
        v = string.gsub(v, "\n", "\\n")
        if string.match(string.gsub(v, "[^'\"]", ""), '^"+$') then
            return "'" .. v .. "'"
        end
        return '"' .. string.gsub(v, '"', '\\"') .. '"'
    else
        return "table" == type(v) and table.tostring(v) or tostring(v)
    end
end

function table.key_to_str(k)
    if "string" == type(k) and string.match(k, "^[_%a][_%a%d]*$") then
        return k
    else
        return "[" .. table.val_to_str(k) .. "]"
    end
end

function PrintLua(name, lib)
    local m
    lib = lib or _G

    for w in string.gmatch(name, "%w+") do
        lib = lib[w]
    end

    m = lib
    if (m == nil) then
        Log.InfoFormat("Lua Module %s not exists", name)
        return
    end

    Log.InfoFormat("-----------------Dump Table %s-----------------", name)
    if (type(m) == "table") then
        for k, v in pairs(m) do
            Log.InfoFormat("Key: %s, Value: %s", k, tostring(v))
        end
    end

    local meta = getmetatable(m)
    Log.InfoFormat("-----------------Dump meta %s-----------------", name)

    while meta ~= nil and meta ~= m do
        for k, v in pairs(meta) do
            if k ~= nil then
                Log.InfoFormat("Key: %s, Value: %s", tostring(k), tostring(v))
            end
        end

        meta = getmetatable(meta)
    end

    Log.Info("-----------------Dump meta Over-----------------")
    Log.Info("-----------------Dump Table Over-----------------")
end

--------------------------------------------------
-- Util functions about string
local function chsize(char)
    local arr = { 0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc }

    if not char then
        return 0
    else
        for i = #arr, 1, -1 do
            if char >= arr[i] then
                return i
            end
        end
    end
end

function GetDir(path)
    return string.match(path, ".*/")
end

function GetFileName(path)
    return string.match(path, ".*/(.*)")
end

-- function IsNullUserData(data)
--     if not data or data == C7.cjson.null or data == "" then
--         return true
--     end
--     return false
-- end

-- isnan
function isnan(number)
    return not (number == number)
end

function isinf(number)
    return number == math.huge or number == -math.huge
end

function math.clamp(val, lower, upper)
    assert(val and lower and upper, "any parameter is nil")
    if lower > upper then
        lower, upper = upper, lower
    end
    return math.max(lower, math.min(upper, val))
end

function math.round(value)
    return value >= 0 and math.floor(value + .5) or math.ceil(value - .5)
end

function dump_table(t, includefunc, depth)
    if t == nil then
        return ''
    end
    if depth == nil then
        depth = 0
    end

    if depth >= 10 then
        return "{too deep}"
    end

    local str = '{ '
    for k, v in pairs(t) do
        k = tostring(k)
        if string.startsWith(k, "__") then
            if includefunc then
                str = str .. k .. '=metatable, '
            end
        elseif type(v) == 'string' then
            str = str .. k .. '="' .. v .. '", '
        elseif type(v) == 'number' then
            str = str .. k .. '=' .. v .. ', '
        elseif type(v) == 'function' then
            if includefunc then
                str = str .. k .. '=function, '
            end
        elseif type(v) == 'table' then
            str = str .. k .. '=' .. dump_table(v, includefunc, depth + 1) .. ', '
        elseif type(v) == 'boolean' then
            str = str .. k .. '=' .. (v and 'true' or 'false') .. ', '
        else
            str = str .. k .. '=' .. type(v) .. ', '
        end
    end
    str = str .. '}'
    return str
end

function rprint(msg)
    print('<color=#ff0000>' .. msg .. '</color>')
end

function IsValid_L(Obj)
    if Obj == nil then
        return false
    end
    return slua.isValid(Obj)
end
