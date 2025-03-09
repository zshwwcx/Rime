--require "UnLua"

--local function InnerPrintTable(InTable, MaxLevel, level, __TableString)
--    level = level or 1
--    local indent = ""
--
--    for i = 1, level do
--        indent = indent .. "  "
--    end
--
--    table.insert(__TableString, indent .. "{")
--    for k, v in pairs(InTable) do
--        if type(v) == "table" and level < MaxLevel then
--            Currentkey = k
--            if Currentkey ~= "" then
--                table.insert(__TableString, indent .. tostring(k) .. " " .. "=")
--            end
--
--            InnerPrintTable(v, MaxLevel, level + 1, __TableString)
--        else
--            local content = string.format("%s%s = %s", indent .. "  ", tostring(k), tostring(v))
--            table.insert(__TableString, content)
--        end
--    end
--    table.insert(__TableString, indent .. "}")
--end

-- function PrintTable(InTable, MaxLevel, level)
--     if type(InTable) ~= "table" then
--         Log.Debug("Error To Print Table ", tostring(InTable))
--         return
--     end

--     if not MaxLevel then
--         MaxLevel = 10
--     end
--     __TableString = {
--         "Table : " .. tostring(InTable),
--     }
--     InnerPrintTable(InTable, MaxLevel, level, __TableString)
--     Log.Debug(table.concat(__TableString, "\n"))
-- end

function TestFunction()
    Log.Debug("this is a test")
end

function CreateInstance(InClass)
    return setmetatable({}, InClass)
end

function IsDerivedFromLuaClass(DerivedClass, SuperClass)
    if DerivedClass == SuperClass then
        return true
    elseif DerivedClass.Super then
        return IsDerivedFromLuaClass(DerivedClass.Super, SuperClass)
    else
        return false
    end
end

function IsInstanceOfLuaClass(Instance, LuaClass)
    if type(Instance) == "table" then
        local ClassType = Instance.ClassType
        if ClassType then
            return IsDerivedFromLuaClass(ClassType, LuaClass)
        end
    end
    return false
end

function SetContextObject(Obj)
    _G.ContextObject = Obj
end

function GetContextObject()
    return _G.ContextObject
end

function _G.IsStringNullOrEmpty(str)
    if type(str) ~= "string" then
        return true
    elseif string.len(str) == 0 then
        return true
    elseif string.len(string.gsub(str, "%s", "")) == 0 then
        return true
    elseif str == "None" then
        return true
    end

    return false
end

function _G.CallBackError(e)
    if _G.IsStringNullOrEmpty(e) then
        e = "None"
    end
    Log.Error(e)
end

local _wrap = coroutine.wrap

coroutine.wrap = function(f)
    return _wrap(
            function()
                xpcall(f, _G.CallBackError)
            end
    )
end

function _G.Co(code)
    coroutine.wrap(code)()
end

function _G.IsCallable(target)
    if target == nil then
        return false
    end

    if type(target) == "function" then
        return true
    end

    if type(target) == "table" then
        local mt = getmetatable(target)

        if mt ~= nil then
            return (mt.__call ~= nil)
        end
    end

    return false

end

function _G.GetEnumTextByValue(Enum, Value)
    for k, v in pairs(Enum) do
        if v == Value then
            return k
        end
    end
    return nil
end

---@param RawTable table
---@param bNeedCopyMetaTable boolean
---@return table
function DeepCopy(RawTable, bNeedCopyMetaTable)
    local LookupTable = {}

    local function InnerCopy(T)
        if type(T) ~= "table" then
            return T
        elseif LookupTable[T] then
            return LookupTable[T]
        end
        local NewTable = {}
        LookupTable[T] = NewTable
        for key, value in pairs(T) do
            NewTable[InnerCopy(key)] = InnerCopy(value)
        end

        if bNeedCopyMetaTable then
            return setmetatable(NewTable, getmetatable(T))
        else
            return NewTable
        end
    end

    return InnerCopy(RawTable)
end
