local MessageChannel = require "Framework.AllInSDK.MessageChannel"
local DataBase = require "Framework.AllInSDK.DataBase"

--summary
--隐私模块处理类
--summary
local Privacy = DefineClass("Privacy")

function Privacy:ctor()
end


--summary
--para打开隐私协议页面，隐私协议名称类型：allin:查看隐私弹窗、policy:用户协议、privacy:隐私协议、privacy_child:儿童协议
--summary>
--param name="protocol" string,传入显示的类型
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para  
--example 
---@param protocol string
function Privacy:ShowPrivacyProtocol(protocol)
    local Param = {}
    Param["protocol"] = protocol
    local result = MessageChannel:SendMessageVoid(
        "privacy",
        "showPrivacyProtocol",
        Param
    )
    return result
end

--summary
--para设置隐私状态，目前不可用
--summary>
--param name="agree" bool,设置隐私状态类型
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para  
--example 
---@param agree bool
function Privacy:SetPrivacyState(agree)
    local Param = {}
    Param["agree"] = agree
    local result = MessageChannel:SendMessageVoid(
        "privacy",
        "setPrivacyState",
        Param
    )
    return result
end


return Privacy