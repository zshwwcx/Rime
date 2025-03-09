local MessageChannel = require "Framework.AllInSDK.MessageChannel"
local DataBase = require "Framework.AllInSDK.DataBase"

--summary
--para大区信息
--summary
--子类型
---@class KwaiGatewayZoneInfo
KwaiGatewayZoneInfo = DefineClass("AllinKwaiGatewayZoneInfo", DataBase)

function KwaiGatewayZoneInfo:ctor(Param)
	self.zoneId = self:ParseLongValue("zoneId")
	self.zoneName = self:ParseStringValue("zoneName")
	self.loginHost = self:ParseStringValue("loginHost")
	self.hotfixVersion = self:ParseStringValue("hotfixVersion")
	self.hotfixUrl = self:ParseStringValue("hotfixUrl")
	self.zoneStatus = self:ParseStringValue("zoneStatus")
	self.maintainText = self:ParseStringValue("maintainText")
	self.subpackageUrl = self:ParseStringValue("subpackageUrl")
	self.extJson = self:ParseTableValue("extJson")
	
end
--summary
--para服务器信息
--summary
--子类型
---@class ServerInfo
ServerInfo = DefineClass("AllinServerInfo", DataBase)

function ServerInfo:ctor(Param)
    self.serverId = self:ParseStringValue("serverId")
    self.name = self:ParseStringValue("name")
    self.displayId = self:ParseStringValue("displayId")
    self.ip = self:ParseStringValue("ip")
    self.port = self:ParseIntValue("port")
    self.status = self:ParseStringValue("status")
    self.color = self:ParseStringValue("color")
    self.maintainMessage = self:ParseStringValue("maintainMessage")
    self.tags = self:ParseTableValue("tags")
    self.extJson = self:ParseTableValue("extJson")

end
--summary
--para区服列表信息
--summary
--子类型
---@class GroupData
GroupData = DefineClass("AllinGroupData", DataBase)

function GroupData:ctor(Param)
    self.serverList = self:ParseTableValue("serverList")
    self.groupId = self:ParseIntValue("groupId")
    self.groupName = self:ParseStringValue("groupName")

end
--summary
--para区服列表信息
--summary
--子类型
---@class ServerListData
ServerListData = DefineClass("AllinServerListData", DataBase)

function ServerListData:ctor(Param)
    self.groupDatas = self:ParseTableValue("groupDatas")
	if next(self.data.recommendData) then
		self.recommendData =  ServerInfo.new(self.data.recommendData) -- 推荐服
	end
    self.count = self:ParseIntValue("count")
    self.pageNumber = self:ParseIntValue("pageNumber")
    self.pages = self:ParseIntValue("pages")

end
--summary
--para敏感词类
--summary
--子类型
---@class MatchResult
MatchResult = DefineClass("AllinMatchResult", DataBase)

function MatchResult:ctor(Param)
	self.action = self:ParseIntValue("action")
	self.position = self:ParseIntValue("position")
	self.length = self:ParseIntValue("length")
	self.matchedText = self:ParseStringValue("matchedText")
	self.replacement = self:ParseStringValue("replacement")
	
end
--summary
--para敏感词返回结果
--summary
--子类型
---@class SensitiveResult
SensitiveResult = DefineClass("AllinSensitiveResult", DataBase)

function SensitiveResult:ctor(Param)
    self.sensitiveResult = self:ParseTableValue("sensitiveResult")

end
--summary
--para敏感词返回结果
--summary
--子类型
---@class SensitiveCheckResult
SensitiveCheckResult = DefineClass("AllinSensitiveCheckResult", DataBase)

function SensitiveCheckResult:ctor(Param)
    self.input = self:ParseStringValue("input")
    self.matchResults = self:ParseTableValue("matchResults")

end
--summary
--通用模块处理类
--summary
local CommonComp = DefineClass("AllinCommonComp")

function CommonComp:ctor()
end


--summary
--para初始化相关 待补充
--para初始化相关 待补充
--summary>
--param name="successAction">Action(int,string,KwaiGatewayZoneInfo),,,大区信息--param name="failedAction">Action(Error}),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para AllinSDK.Account.Init(loginType, 
--para delegate(AccountInfo accountInfo) { 
--para }, delegate(Error error) { 
--para }); 
--example 
--seealso cref="初始化相关"
--remarks
--para初始化相关 待补充
--remarks
---@param successAction function
---@param failedAction function
function CommonComp:GetGameZone(successAction,failedAction)
    local Param = {}
    local result = MessageChannel:SendMessageCallback(
        "commonComp",
        "getGameZone",
        Param,
        function(error, resultData)
            if error and failedAction then
                failedAction(error)
                return
            end
            if resultData and successAction then
                local code = nil
                if resultData.code then
                    code = MessageChannel:ParseIntValue(resultData["code"])
                end
                local msg = nil
                if resultData.msg then
                    msg = MessageChannel:ParseStringValue(resultData["msg"])
                end
                local data = nil
                if resultData.data then
                    data = KwaiGatewayZoneInfo.new(resultData.data) -- 大区信息
                end
                successAction(code,msg,data)
            elseif failedAction then
                failedAction({["code"]=-1,["msg"]="data parsing failed"})
            end
        end
    )
    return result
end

--summary
--para获取区服列表,文档地址：https://sdkdocs-beta.game.kuaishou.com/sdkdoc/1.28-alpha/sdkdoc/gate/gate/#3
--summary>
--param name="zoneId" long,大区id
--param name="successAction">Action(int,string,ServerListData),,,服务器列表信息--param name="failedAction">Action(Error}),code:错误码,message:错误描述
--example  
--para ServerListAgent.GetServerList(data,groupNum, 
--para delegate(ServerListData serverListData) { 
--para }, delegate(Error error,ServerListData serverListData) { 
--para }); 
--example 
---@param zoneId number
---@param successAction function
---@param failedAction function
function CommonComp:GetServerList(zoneId,successAction,failedAction)
    local Param = {}
    Param["zoneId"] = zoneId
    local result = MessageChannel:SendMessageCallback(
        "commonComp",
        "getServerList",
        Param,
        function(error, resultData)
            if error and failedAction then
                failedAction(error)
                return
            end
            if resultData and successAction then
                local code = nil
                if resultData.code then
                    code = MessageChannel:ParseIntValue(resultData["code"])
                end
                local msg = nil
                if resultData.msg then
                    msg = MessageChannel:ParseStringValue(resultData["msg"])
                end
                local data = nil
                if resultData.data then
                    data = ServerListData.new(resultData.data) -- 服务器列表信息
                end
                successAction(code,msg,data)
            elseif failedAction then
                failedAction({["code"]=-1,["msg"]="data parsing failed"})
            end
        end
    )
    return result
end

function CommonComp:QueryGameAccountInfo(successAction,failedAction)
	local Param = {}
	local result = MessageChannel:SendMessageCallback(
		"commonComp",
		"queryGameAccountInfo",
		Param,
		function(error, resultData)
			if error and failedAction then
				failedAction(error)
				return
			end
			if resultData and successAction then
				local code = nil
				if resultData.code then
					code = MessageChannel:ParseIntValue(resultData["code"])
				end
				local msg = nil
				if resultData.msg then
					msg = MessageChannel:ParseStringValue(resultData["msg"])
				end
				local data = nil
				if resultData.data then
					data =  MessageChannel:ParseTableValue(resultData.data)
				end
				successAction(code,msg,data)
			elseif failedAction then
				failedAction({["code"]=-1,["msg"]="data parsing failed"})
			end
		end
	)
	return result
end

function CommonComp:QueryGameServerInfo(successAction,failedAction)
	local Param = {}
	local result = MessageChannel:SendMessageCallback(
		"commonComp",
		"queryGameServerInfo",
		Param,
		function(error, resultData)
			if error and failedAction then
				failedAction(error)
				return
			end
			if resultData and successAction then
				local code = nil
				if resultData.code then
					code = MessageChannel:ParseIntValue(resultData["code"])
				end
				local msg = nil
				if resultData.msg then
					msg = MessageChannel:ParseStringValue(resultData["msg"])
				end
				local data = nil
				if resultData.data then
					data =  MessageChannel:ParseTableValue(resultData.data)
				end
				successAction(code,msg,data)
			elseif failedAction then
				failedAction({["code"]=-1,["msg"]="data parsing failed"})
			end
		end
	)
	return result
end

--summary
--para弹窗显示登陆公告
--summary>
--param name="gameNoticeType" int,公告类型 0 登录公告 1 游戏公告
--param name="serverId" string,公告类型
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para AllinSDK.Notice.ShowGameNoticeDialog(noticeType, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param gameNoticeType int
---@param serverId string
function CommonComp:ShowGameNoticeDialog(gameNoticeType,serverId)
    local Param = {}
    Param["gameNoticeType"] = gameNoticeType
    Param["serverId"] = serverId
    local result = MessageChannel:SendMessageVoid(
        "commonComp",
        "showGameNoticeDialog",
        Param
    )
    return result
end

--summary
--para获取游戏公告内容
--summary>
--param name="gameNoticeType" int,公告类型 0 登录公告 1 游戏公告
--param name="serverId" string,公告类型
--param name="successAction">Action(int,string,string),,,公告信息--param name="failedAction">Action(Error}),code:错误码,message:错误描述
--example  
--para AllinSDK.Notice.GetGameNotice(noticeType, 
--para delegate(string content) { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param gameNoticeType int
---@param serverId string
---@param successAction function
---@param failedAction function
function CommonComp:GetGameNotice(gameNoticeType,serverId,successAction,failedAction)
    local Param = {}
    Param["gameNoticeType"] = gameNoticeType
    Param["serverId"] = serverId
    local result = MessageChannel:SendMessageCallback(
        "commonComp",
        "getGameNotice",
        Param,
        function(error, resultData)
            if error and failedAction then
                failedAction(error)
                return
            end
            if resultData and successAction then
                local code = nil
                if resultData.code then
                    code = MessageChannel:ParseIntValue(resultData["code"])
                end
                local msg = nil
                if resultData.msg then
                    msg = MessageChannel:ParseStringValue(resultData["msg"])
                end
                local data = nil
                if resultData.data then
                    data = MessageChannel:ParseStringValue(resultData["data"])
                end
                successAction(code,msg,data)
            elseif failedAction then
                failedAction({["code"]=-1,["msg"]="data parsing failed"})
            end
        end
    )
    return result
end

--summary
--para敏感词
--summary>
--param name="inputs" List<string>,敏感词数组
--param name="serverId" string,公告类型
--param name="successAction">Action(int,string,SensitiveResult),,,敏感词结果--param name="failedAction">Action(Error}),code:错误码,message:错误描述
--example  
--para AllinSDK.Notice.ShowGameNoticeDialog(noticeType, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param inputs List<string>
---@param serverId string
---@param successAction function
---@param failedAction function
function CommonComp:CheckSensitiveWords(inputs,serverId,successAction,failedAction)
    local Param = {}
    Param["inputs"] = inputs
    Param["serverId"] = serverId
    local result = MessageChannel:SendMessageCallback(
        "commonComp",
        "checkSensitiveWords",
        Param,
        function(error, resultData)
            if error and failedAction then
                failedAction(error)
                return
            end
            if resultData and successAction then
                local code = nil
                if resultData.code then
                    code = MessageChannel:ParseIntValue(resultData["code"])
                end
                local msg = nil
                if resultData.msg then
                    msg = MessageChannel:ParseStringValue(resultData["msg"])
                end
                local data = nil
                if resultData.data then
                    data = SensitiveResult.new(resultData.data) -- 敏感词结果
                end
                successAction(code,msg,data)
            elseif failedAction then
                failedAction({["code"]=-1,["msg"]="data parsing failed"})
            end
        end
    )
    return result
end

--summary
--para***相关 待补充
--para***相关 待补充
--summary>
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
function CommonComp:GetChannel()
    local Param = {}
    local result = MessageChannel:SendMessageString(
        "commonComp",
        "getChannel",
        Param
    )
    return result
end

--summary
--para***相关 待补充
--para***相关 待补充
--summary>
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
function CommonComp:GetSDKVersion()
    local Param = {}
    local result = MessageChannel:SendMessageString(
        "commonComp",
        "getSDKVersion",
        Param
    )
    return result
end

--summary
--para***相关 待补充
--para***相关 待补充
--summary>
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
function CommonComp:GetConfig()
    local Param = {}
    local result = MessageChannel:SendMessageString(
        "commonComp",
        "getConfig",
        Param
    )
    result =  HashTable.new(result)
    return result
end

--summary
--para***相关 待补充
--para***相关 待补充
--summary>
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
function CommonComp:GetMarketChannel()
    local Param = {}
    local result = MessageChannel:SendMessageString(
        "commonComp",
        "getMarketChannel",
        Param
    )
    return result
end

--summary
--para***相关 待补充
--para***相关 待补充
--summary>
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
function CommonComp:GetGameEnv()
    local Param = {}
    local result = MessageChannel:SendMessageInt(
        "commonComp",
        "getGameEnv",
        Param
    )
    return result
end

--summary
--para***相关 待补充
--para***相关 待补充
--summary>
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
function CommonComp:GetCPUName()
    local Param = {}
    local result = MessageChannel:SendMessageString(
        "commonComp",
        "getCPUName",
        Param
    )
    return result
end

--summary
--para***相关 待补充
--para***相关 待补充
--summary>
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
function CommonComp:GetScreenResolution()
    local Param = {}
    local result = MessageChannel:SendMessageString(
        "commonComp",
        "getScreenResolution",
        Param
    )
    return result
end

--summary
--para***相关 待补充
--para***相关 待补充
--summary>
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
function CommonComp:GetAppId()
    local Param = {}
    local result = MessageChannel:SendMessageString(
        "commonComp",
        "getAppId",
        Param
    )
    return result
end

--region 中台未生成，手动添加

function CommonComp:GetDeviceId()
    local Param = {}
    local result = MessageChannel:SendMessageString(
            "commonComp",
            "getDeviceId",
            Param
    )
    return result
end

--获取app所在disk的总大小 by leyiwei 中台漏生成，手动添加的
function CommonComp:GetTotalDiskSpace()
    local Param = {}
    local result = MessageChannel:SendMessageString(
        "commonComp",
        "getTotalDiskSpace",
        Param
    )
    return result
end

--获取app所在disk的剩余大小
function CommonComp:GetFreeDiskSpace()
    local Param = {}
    local result = MessageChannel:SendMessageString(
        "commonComp",
        "getFreeDiskSpace",
        Param
    )
    return result
end

--文档地址 https://game-sdkdocs.corp.kuaishou.com/sdkdoc/gate/gate/#23
function CommonComp:GetRoleList(successAction,failedAction)
    local Param = {}
    local result = MessageChannel:SendMessageCallback(
            "commonComp",
            "getRoleList",
            Param,
            function(error, resultData)
                if error and failedAction then
                    failedAction(error)
                    return
                end
                if resultData and successAction then
                    local code = nil
                    if resultData.code then
                        code = MessageChannel:ParseIntValue(resultData["code"])
                    end
                    local msg = nil
                    if resultData.msg then
                        msg = MessageChannel:ParseStringValue(resultData["msg"])
                    end
                    local data = nil
                    if resultData.data then
                        data =  MessageChannel:ParseTableValue(resultData.data)
                    end
                    successAction(code,msg,data)
                elseif failedAction then
                    failedAction({["code"]=-1,["msg"]="data parsing failed"})
                end
            end
    )
    return result
end

function CommonComp:GetLocation(successAction,failedAction)
    local Param = {}
    local result = MessageChannel:SendMessageCallback(
            "commonComp",
            "getLocation",
            Param,
            function(error, resultData)
                if error and failedAction then
                    failedAction(error)
                    return
                end
                if resultData and successAction then
                    local code = nil
                    if resultData.code then
                        code = MessageChannel:ParseIntValue(resultData["code"])
                    end
                    local msg = nil
                    if resultData.msg then
                        msg = MessageChannel:ParseStringValue(resultData["msg"])
                    end
                    local data = nil
                    if resultData.data then
                        data =  MessageChannel:ParseTableValue(resultData.data)
                    end
                    successAction(code,msg,data)
                elseif failedAction then
                    failedAction({["code"]=-1,["msg"]="data parsing failed"})
                end
            end
    )
    return result
end

function CommonComp:SaveImageToAlbum(filePath, successAction,failedAction)
    local Param = {
        filePath = filePath
    }
    local result = MessageChannel:SendMessageCallback(
        "commonComp",
        "saveImageToAlbum",
        Param,
        function(error, resultData)
            if error and failedAction then
                failedAction(error)
                return
            end
            if resultData and successAction then
                local code = nil
                if resultData.code then
                    code = MessageChannel:ParseIntValue(resultData["code"])
                end
                local msg = nil
                if resultData.msg then
                    msg = MessageChannel:ParseStringValue(resultData["msg"])
                end
                local data = nil
                if resultData.data then
                    data =  MessageChannel:ParseTableValue(resultData.data)
                end
                successAction(code,msg,data)
            elseif failedAction then
                failedAction({["code"]=-1,["msg"]="data parsing failed"})
            end
        end
    )
    return result
end

function CommonComp:Upload(taskId, localFilePath)
    local Param = {
        taskId = taskId,
        localFilePath = localFilePath
    }
    local result = MessageChannel:SendMessageVoid(
            "commonComp",
            "upload",
            Param
    )
    return result
end

function CommonComp:InitWebviewWithConfig(windowStyle, rect, orientation, hideToolBar, hideTitle, hideProgressBar, shareList)
    local params = {
        windowStyle = windowStyle or 0,
        rect = rect or {widthScale = 100, heightScale = 100, leftScale = 10, topScale = 100},
        orientation = orientation or 1, hideToolBar = hideToolBar or false,
        hideTitle = hideTitle or false, hideProgressBar = hideProgressBar or false, shareList = shareList or {}
    }
    return MessageChannel:SendMessageVoid("commonComp", "initWebviewWithConfig", params)
end

function CommonComp:OpenWebviewUrl(curUrl)
    local params = {url = curUrl}
    return MessageChannel:SendMessageVoid("commonComp", "openWebviewUrl", params)
end

function CommonComp:Feedback(reportType, reportReason, reportText, reportPics, targetId, targetServer, logID)
	local params = {
		reportType = reportType or 0,
		reportText = reportText or "",
		reportPics = reportPics or {},
		reportLogfiles = logID and {logID} or {},
		extend = {
			reported_role_id = targetId or nil,
			reported_server_id = targetServer or nil,
			report_reason_type = reportReason,
		}
	}
	return MessageChannel:SendMessageVoid("commonComp", "feedback", params)
end

function CommonComp:ChoosePhotos(maxPhotos, resultType, permissionDesc, guideToSettings, successAction, failedAction)
	local params = {
		maxPhotos = maxPhotos,
		resultType = resultType,
		permissionDesc = permissionDesc,
		guideToSettings = guideToSettings,
	}
	local result = MessageChannel:SendMessageCallback("commonComp", "choosePhotos", params, 
		function(error, resultData)
			if error and failedAction then
				failedAction(error)
				return
			end
			if resultData and successAction then
				local code = nil
				if resultData.code then
					code = MessageChannel:ParseIntValue(resultData["code"])
				end
				local msg = nil
				if resultData.msg then
					msg = MessageChannel:ParseStringValue(resultData["msg"])
				end
				local data = nil
				if resultData.data then
					data =  MessageChannel:ParseTableValue(resultData.data)
				end
				successAction(code,msg,data)
			elseif failedAction then
				failedAction({["code"]=-1,["msg"]="data parsing failed"})
			end
	end)
	return result
end

--endregion 中台漏生成，手动添加

-- sdk 下载保活 :https://game-sdkdocs.corp.kuaishou.com/sdkdoc/extension/keepalive/
function CommonComp:StartKeepAlive()
    MessageChannel:SendMessageVoid(
        "commonComp",
        "startKeepAlive",
        {}
    )
end

--下载patch阶段关闭保活
function CommonComp:StopKeepAlive()
    MessageChannel:SendMessageVoid(
        "commonComp",
        "stopKeepAlive",
        {}
    )
end

-- https://game-sdkdocs.corp.kuaishou.com/sdkdoc/extension/audio/#2
-- 如果是ios平台保活还需要申请音频防止被杀进程
function CommonComp:StartAudioPlay()

    local Param = {}
    Param["duration"] = 120000  --时间需要大于0
 
    MessageChannel:SendMessageVoid(
        "media",
        "startAudioPlay",
        Param
    )
end

function CommonComp:StopAudioPlay()
    MessageChannel:SendMessageVoid(
        "media",
        "stopAudioPlay",
        nil
    )
end
--保活目前需要和音频放到一起
---




return CommonComp