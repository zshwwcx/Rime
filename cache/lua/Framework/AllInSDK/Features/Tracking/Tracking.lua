local MessageChannel = require "Framework.AllInSDK.MessageChannel"
local DataBase = require "Framework.AllInSDK.DataBase"

--summary
--数据上报模块处理类
--summary
local Tracking = DefineClass("Tracking")

function Tracking:ctor()
end


--summary
--para打点方法
--summary>
--param name="params" Hashtable,打点参数 json字符串
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para AllinSDK.Report.Report(reportAction,reportParam, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param params Hashtable
function Tracking:Track(params)
    local Param = params
    local result = MessageChannel:SendMessageVoid(
        "tracking",
        "track",
        Param
    )
    return result
end

--summary
--para打点方法
--summary>
--param name="params" Hashtable,打点参数 json字符串
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para AllinSDK.Report.Report(reportAction,reportParam, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param params Hashtable
function Tracking:SetExtraReportParams(params)
    local Param = {}
    Param["params"] = params
    local result = MessageChannel:SendMessageVoid(
        "tracking",
        "setExtraReportParams",
        Param
    )
    return result
end

--summary
--para打点方法
--summary>
--param name="params" Hashtable,打点参数 json字符串
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para AllinSDK.Report.Report(reportAction,reportParam, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param params Hashtable
function Tracking:ReportNetworkDelay(params)
    local Param = {}
    Param["params"] = params
    local result = MessageChannel:SendMessageVoid(
        "tracking",
        "reportNetworkDelay",
        Param
    )
    return result
end

--summary
--para打点方法
--summary>
--param name="fps" int,上报帧数
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para AllinSDK.Report.Report(reportAction,reportParam, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param fps int
function Tracking:ReportTargetFPS(fps)
    local Param = {}
    Param["fps"] = fps
    local result = MessageChannel:SendMessageVoid(
        "tracking",
        "reportTargetFPS",
        Param
    )
    return result
end

--summary
--para打点方法
--summary>
--param name="pictureQuality" int,上报画质
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para AllinSDK.Report.Report(reportAction,reportParam, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param pictureQuality int
function Tracking:ReportPictureQuality(pictureQuality)
    local Param = {}
    Param["pictureQuality"] = pictureQuality
    local result = MessageChannel:SendMessageVoid(
        "tracking",
        "reportPictureQuality",
        Param
    )
    return result
end

--summary
--para打点方法
--summary>
--param name="params" Hashtable,打点参数 json字符串
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para AllinSDK.Report.Report(reportAction,reportParam, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param params Hashtable
function Tracking:ReportExpandInfo(params)
    local Param = {}
    Param["params"] = params
    local result = MessageChannel:SendMessageVoid(
        "tracking",
        "reportExpandInfo",
        Param
    )
    return result
end

--summary
--para打点方法
--summary>
--param name="sceneName" string,场景名称
--param name="action" string,动作
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para AllinSDK.Report.Report(reportAction,reportParam, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param sceneName string
---@param action string
function Tracking:ReportSceneAction(sceneName,action)
    local Param = {}
    Param["sceneName"] = sceneName
    Param["action"] = action
    local result = MessageChannel:SendMessageVoid(
        "tracking",
        "reportSceneAction",
        Param
    )
    return result
end


return Tracking