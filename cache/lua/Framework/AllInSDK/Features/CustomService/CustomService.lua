local MessageChannel = require "Framework.AllInSDK.MessageChannel"
local DataBase = require "Framework.AllInSDK.DataBase"

--summary
--Crash模块处理类
--summary
local CustomService = DefineClass("CustomService")

function CustomService:ctor()
end

function CustomService:ShowCustomServicePage()
    local Param = {}
    local result = MessageChannel:SendMessageVoid(
        "customService",
        "showCustomServicePage",
        Param
    )
    return result
end

return CustomService