local json = require "Framework.Library.json"

local MessageChannel = DefineSingletonClass("MessageChannel")

function MessageChannel.table_clear(t)
    if not t then return t end
    for k, v in next, t do
        t[k] = nil
    end
    return t
end

Enum.EAllInReturnType = {
    None = 0, -- 不需要返回
    Return = 1, -- 返回值
    Callback = 2, -- 异步返回
    CallbackToNative = 3, -- 原生层回调
}

function MessageChannel:ctor()
    self.Responses = {}
    self.Listener = {}
end

function MessageChannel:dtor()
    self.Responses = {}
    self.Listener = {}
end

function MessageChannel:RegisterResponse(Command, Callback)
    if self.Responses[Command] == nil then
        self.Responses[Command] = {}
    end
    table.insert(self.Responses[Command], Callback)
end

function MessageChannel:UnregisterResponse(Module, Func)
    local Command = Module .. "." .. Func
    table.clear(self.Responses[Command])
end

function MessageChannel:RegisterListener(Command, Callback)
    if self.Listener[Command] == nil then
        self.Listener[Command] = {}
    end
    table.insert(self.Listener[Command], Callback)
end

function MessageChannel:RemoveListener(Command)
    MessageChannel.table_clear(self.Listener[Command])
end

function MessageChannel:ClearResponseAndListener()  -- luacheck: ignore
    MessageChannel.table_clear(self.Listener)
    MessageChannel.table_clear(self.Responses)
end

function MessageChannel:ParamToJsonData(Param)
    local Data = nil
    if Param == nil or next(Param) == nil then
        Data = ""
    else
        Data = json.encode(Param)
    end
    return Data
end

function MessageChannel:SendMessageVoid(Module, Func, Param)
    import("AllInSDKBlueprintLibrary").SendMessageToNative(Module, Func, self:ParamToJsonData(Param))
end

function MessageChannel:SendMessageBool(Module, Func, Param)
    return import("AllInSDKBlueprintLibrary").SendMessageToNativeBool(Module, Func, self:ParamToJsonData(Param))
end

function MessageChannel:SendMessageString(Module, Func, Param)
    return import("AllInSDKBlueprintLibrary").SendMessageToNativeString(Module, Func, self:ParamToJsonData(Param))
end

function MessageChannel:SendMessageInt(Module, Func, Param)
    return import("AllInSDKBlueprintLibrary").SendMessageToNativeInt(Module, Func, self:ParamToJsonData(Param))
end

function MessageChannel:SendMessageLong(Module, Func, Param)
    return import("AllInSDKBlueprintLibrary").SendMessageToNativeLong(Module, Func, self:ParamToJsonData(Param))
end

function MessageChannel:SendMessageFloat(Module, Func, Param)
    return import("AllInSDKBlueprintLibrary").SendMessageToNativeFloat(Module, Func, self:ParamToJsonData(Param))
end

function MessageChannel:SendMessageCallback(Module, Func, Param, Callback)
    local Data = self:ParamToJsonData(Param)
    local Command = Module .. "." .. Func
    self:RegisterResponse(Command, Callback)
    import("AllInSDKBlueprintLibrary").SendMessageToNative(Module, Func, Data)
end

function MessageChannel:ReceiveAllInSDKMessage(Message) -- luacheck: ignore
    print(string.format("AllInSdk  ReceiveAllInSDKMessage: %s",Message))
    local Data = json.decode(Message)
    local Module = Data.module
    local Func = Data.func
    local Result = Data.result
    local Command = Module .. "." .. Func

    local Error = nil
    if Result and Result.code ~= 1 then
        Error = Result
    end

    if self.Responses[Command] then
        for index, Callback in ipairs(self.Responses[Command]) do
            Callback(Error, Result)
        end
        MessageChannel.table_clear(self.Responses[Command])
    end
    if self.Listener[Command] then
        for index, Callback in ipairs(self.Listener[Command]) do
            Callback(Error, Result)
        end
    end
end
--end

function MessageChannel:ParseIntValue(Value)
    return tonumber(Value)
end

function MessageChannel:ParseLongValue(Value)
    return tonumber(Value)
end

function MessageChannel:ParseFloatValue(Value)
    return tonumber(Value)
end

function MessageChannel:ParseBoolValue(Value)
    if Value == false or Value == "false" or Value == "False" then
        return false
    else
        return true
    end
end

function MessageChannel:ParseEnumValue(Value)
    return tonumber(Value)
end

function MessageChannel:ParseStringValue(Value)
    if Value == nil then
        return ""
    end
    return Value
end

function MessageChannel:ParseTableValue(Value)
    if string.isEmpty(Value) then
        return {}
    end
    if type(Value) == "table" then
        return Value
    end
    local table = json.decode(Value)
    return table
end

return MessageChannel.new() -- luacheck: ignore