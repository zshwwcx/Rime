local MessageChannel = require "Framework.AllInSDK.MessageChannel"
local DataBase = require "Framework.AllInSDK.DataBase"

--summary
--Crash模块处理类
--summary
local Crash = DefineClass("Crash")

function Crash:ctor()
end


--summary
--para注册自定义参数
--summary>
--param name="params" Hashtable,key value
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para AllinSDK.Report.Report(reportAction,reportParam, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param params Hashtable
function Crash:RegisterCustomReportParams(params)
    local Param = {}
    Param["params"] = params
    local result = MessageChannel:SendMessageVoid(
        "crash",
        "registerCustomReportParams",
        Param
    )
    return result
end

--summary
--para上报自定义异常
--summary>
--param name="params" Hashtable,key value
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para AllinSDK.Report.Report(reportAction,reportParam, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param params Hashtable
function Crash:LogCustomException(params)
    local Param = {}
    Param["params"] = params
    local result = MessageChannel:SendMessageVoid(
        "crash",
        "logCustomException",
        Param
    )
    return result
end


return Crash