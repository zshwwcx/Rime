local json = require "Framework.Library.json"
local DataBase = DefineClass("DataBase")

function DataBase:ctor(Param)
    self.data = Param or {}
    self.DefaultValues = {}
end

function DataBase:InitByParam(Param)
end

function DataBase:ParseStringValue(Key)
    if Key == nil then
        return ""
    end
    self.DefaultValues[Key] = ""
    return self.data[Key]
end

function DataBase:ParseIntValue(Key)
    if Key == nil then
        return 0
    end
    self.DefaultValues[Key] = 0
    return tonumber(self.data[Key])
end

function DataBase:ParseLongValue(Key)
    if Key == nil then
        return 0
    end
    self.DefaultValues[Key] = 0
    return tonumber(self.data[Key])
end

function DataBase:ParseEnumValue(Key)
    if Key == nil then
        return 0
    end
    self.DefaultValues[Key] = 0
    return tonumber(self.data[Key])
end

function DataBase:ParseBoolValue(Key)
    if Key == nil then
        return false
    end
    self.DefaultValues[Key] = false
    if self.data[Key] == false or self.data[Key] == "false" then
        return false
    else
        return true
    end
end

function DataBase:ParseFloatValue(Key)
    if Key == nil then
        return 0
    end
    self.DefaultValues[Key] = 0
    return tonumber(self.data[Key])
end

function DataBase:ParseTableValue(Key)
    if Key == nil then
        return {}
    end
    self.DefaultValues[Key] = {}
    local Value = self.data[Key]
    local valueType = type(Value)
    if valueType == "table" then
        return Value
    elseif valueType == "string" then
        return json.decode(Value)
    else
        return {}
    end
end

function DataBase:Serialize()
    local result = {}
    for k, v in pairs(self.DefaultValues) do
        local value = self[k]
        if value ~= nil then
            result[k] = value
        else
            result[k] = v
        end
    end
    return result
end

return DataBase