local AllInSDKManagerBase = require("Framework.AllInSDK.AllInSdkManagerBase")
---@class AllInSdkManager
local AllInSdkManager = DefineClass("AllInSdkManager", AllInSDKManagerBase)
local EInputEvent = import("EInputEvent")
local LowLevelFunctions = import("LowLevelFunctions")
local LuaFunctionLibrary = import("LuaFunctionLibrary")

local json = require "Framework.Library.json"
local MessageChannel = require "Framework.AllInSDK.MessageChannel"

AllInSdkManager.AllInSDKModules = {
    "CommonComp",
    "Platform",
    "Privacy",
    "Tracking",
    "CustomService",
    "Share",
}
AllInSdkManager.ModuleRootPath = "Features"

function AllInSdkManager:ctor()
    self.OnPaySuccessListener = nil --支付成功回调
    self.OnPayFailedListener = nil  --支付失败回调
    self.currencyType = nil --当前货币类型
    self.SdkData.Channel = self.CommonComp:GetChannel()
    self.SdkData.MarketChannel = self.CommonComp:GetMarketChannel()
    self.SdkData.DeviceId = self.CommonComp:GetDeviceId()
    self.SdkData.GameServerInfo = {} --服务器排队信息
    self.uploadCallbacks = nil
end

function AllInSdkManager:Init()
    self.super:Init()
    self:SetUploadListener()
    self:SetUseAllinExitDialog(true)
    self.uploadCallbacks = {}
    Game.UIInputProcessorManager:BindKeyEvent(self, "Android_Back", EInputEvent.IE_Released, "OnAndroidBackReleased")
end

--region 登录流程

---Login SDK登录
---@param successCallback function 登录成功回调
function AllInSdkManager:Login(successCallback,failedCallback)
    if Game.LoginSystem:CheckSDKHadLogin() then --检查是否处于登录状态，已登录的话跳过
        if successCallback then
            successCallback()
        end
        return
    end
    self:Track(Enum.EOperatorTrackType.Game_PlatForm_Login, {result = "1", errorMsg = ""},0)
    self.Platform:Login(
        function(code,msg,accountInfo)
            self:Track(Enum.EOperatorTrackType.Game_SDK_Token_End, {result = "1", errorMsg = ""}, 0)
            Log.DebugFormat("AllInSdkManager Login Success,gameUserId:%s,gameUserToken:%s", accountInfo.gameUserId, accountInfo.gameUserToken)
            Game.LoginSystem:SetSdkLoginData({gameUserId = accountInfo.sdkUserId,gameUserToken = accountInfo.sdkToken })
            if successCallback then
                successCallback()
            end
        end,
        function(error)
            self:Track(Enum.EOperatorTrackType.Game_SDK_Token_End, {result = tostring(error.code), errorMsg = error.msg},0)
            if failedCallback then
                failedCallback(error)
            end
        end
    )
end

function AllInSdkManager:GetServerList(successCallback, failedCallback)
    self.CommonComp:GetServerList(
        self.SdkData.KwaiGatewayZoneInfo.zoneId,
        function(code,msg,serverListData)
            Log.DebugFormat("AllInSdkManager GetServerList Success")
            self.SdkData.ServerListData = serverListData
            if successCallback then successCallback() end
        end,
        function(error)
            if failedCallback then failedCallback(error) end
        end
    )
end

function AllInSdkManager:QueryGameAccountInfo(successCallback, failedCallback)
	self.CommonComp:QueryGameAccountInfo(
		function(code,msg,data)
			Log.DebugFormat("AllInSdkManager QueryGameAccountInfo Success")
			
			local gameAccountInfo = data.gameAccountInfo[1]
			if gameAccountInfo then
				local result, extend = pcall(json.decode, gameAccountInfo.extend)		-- luacheck: ignore
				gameAccountInfo.extend = result and extend or {}
			end
			self.SdkData.GameAccountInfo = gameAccountInfo
			Game.LoginSystem:SetAccountQueueServerID(gameAccountInfo)
			if successCallback then successCallback() end
		end,
		function(error)
			if failedCallback then failedCallback(error) end
		end
	)
end

function AllInSdkManager:QueryGameServerInfo(successCallback, failedCallback)
	self.CommonComp:QueryGameServerInfo(
		function(code,msg,data)
			Log.DebugFormat("AllInSdkManager QueryGameServerInfo Success")
			local GameServerInfo = {}
			for i, v in pairs(data.gameServerInfo) do
				local result, extend = pcall(json.decode, v.extend)		-- luacheck: ignore
				if result then
					v.extend = extend
				end
				GameServerInfo[v.serverId] = v
			end
			self.SdkData.GameServerInfo = GameServerInfo
			if successCallback then successCallback() end
		end,
		function(error)
			if failedCallback then failedCallback(error) end
		end
	)
end

function AllInSdkManager:StopGetServerInfo()
    MessageChannel:UnregisterResponse("commonComp", "getServerList")
    MessageChannel:UnregisterResponse("commonComp", "queryGameAccountInfo")
    MessageChannel:UnregisterResponse("commonComp", "queryGameServerInfo")
end

function AllInSdkManager:GetRoleList(successCallback, failedCallback)
    self.CommonComp:GetRoleList(
        function(code, msg, data)
            Game.LoginSystem:SetRoleRecordData(data.roleList)
            if successCallback then
                successCallback()
            end
        end,
        function(error)
            print(string.format("AllInSdkManager GetRoleList Failed,ErrorCode :%d, ErrorMessage :%s", error.code, error.message))
            if failedCallback then
                failedCallback()
            end
        end)
end

---Logout 登出
---@param successAction function
---@param failedAction function
function AllInSdkManager:Logout(successAction,failedAction)
    self.Platform:Logout(successAction,failedAction)
end

--endregion 登录流程
-------------------------------------------------------------------------------------------------
--region 充值相关

---@overload QueryProductDetails 获取充值商品列表
function AllInSdkManager:QueryProductDetails(successAction,failedAction)
    self.Platform:GetProductList(function(code,msg,data)
        local productList = data.products
        if productList and #productList > 0 then
            self.currencyType = productList[1].price_currency_code --设置货币类型
        end
        Game.RechargeSystem.model:SetProductList(productList)
        if successAction then
            successAction()
        end
    end,function(error)
        print(string.format("AllInSdkManager QueryProductDetails Failed,ErrorCode :%d, ErrorMessage :%s",error.code,error.message))
        if failedAction then
            failedAction()
        end
    end)
end

---@overload PayProduction 调用SDk支付
---@param productId string 商品ID
---@param sign string 签名信息
---@param thirdPartyTradeNo string 订单号
---@param payNotifyUrl string 支付回调地址
---@param extension string 附加数据，在支付回调时会原样传回
function AllInSdkManager:PayProduction(productId,sign,thirdPartyTradeNo,payNotifyUrl,extension)
    extension = extension or {}
    local serverInfo = Game.LoginSystem:GetServerLoginData()
    local roleName = (Game.me and Game.me.Name) and Game.me.Name or ""
    Log.DebugFormat(
        "AllInSdkManager PayProduction productId:%s sign:%s thirdPartyTradeNo:%s payNotifyUrl:%s extension:%s",
        productId, sign, thirdPartyTradeNo, payNotifyUrl, extension
    )
    self.Platform:Pay(
        self.currencyType, extension, payNotifyUrl, productId, Game.me.eid,serverInfo.ServerId, sign, thirdPartyTradeNo, serverInfo.ServerNamer, roleName,
        function(code,msg,payResultModel)
            if self.OnPaySuccessListener then
                self.OnPaySuccessListener(payResultModel)
            end
        end,
        function(error)
            print(string.format("AllInSdkManager PayProduction Failed,ErrorCode :%d, ErrorMessage :%s",error.code,error.message))
            if self.OnPayFailedListener then
                self.OnPayFailedListener(error)
            end
        end
    )
end
--endregion 充值相关
---------------------------------------------------------------------------------------------------------------------------
--region 公告相关

---@overload GetGameNotice
---@param successAction function 获取成功回调
---@param failedAction function  获取失败回调
function AllInSdkManager:GetGameNotice(successAction,failedAction)
    self.CommonComp:GetGameNotice(0, "",    --公告类型暂时写死“登录公告”
        function(code,msg,noticeData)
            Game.AnnounceSystem:SetNoticeList(noticeData.list)
            if successAction then successAction(noticeData.list) end
        end,
        function(error)
            print(string.format("AllInSdkManager GetGameNotice Failed,ErrorCode :%d, ErrorMessage :%s",error.code,error.message))
            if failedAction then failedAction() end
        end
    )
end

--endregion 公告相关
---------------------------------------------------------------------------------------------------------------------------
--region 协议&用户中心相关

---@overload ShowUserCenter 打开用户中心
function AllInSdkManager:ShowUserCenter()
    self.Platform:OpenUserCenter()
end

---@overload ShowPrivacyProtocol 打开用户协议
function AllInSdkManager:ShowPrivacyProtocol()
    self.Privacy:ShowPrivacyProtocol("allin")
end

---ShowCustomService 打开客服
function AllInSdkManager:ShowCustomService()
    self.CustomService:ShowCustomServicePage()
end

---@overload CheckSensitiveWords 敏感词校验,回调详细数据(回调注意判空)
---@param input string 待校验string表
---@param successAction function  {{input:string,matchResults:{{action:number,replacement:string,position:number,matchedText:string,length:number}}}} 敏感词校验成功
---@param failedAction function
function AllInSdkManager:CheckSensitiveWords(inputs,successAction,failedAction)
    local inputsStr = json.encode(inputs)
    self.CommonComp:CheckSensitiveWords(
        inputsStr, "",
        function(code,msg,data)
            if code ~= 1 then
                if failedAction then failedAction() end
            else
                if successAction then successAction(data.sensitiveResult) end
            end
        end,
        failedAction
    )
end

---@overload IsSensitiveWords 判断是否包含敏感词
---@param input
---@param successAction function(boolean) 检测结果回调
---@param failedAction function
function AllInSdkManager:IsSensitiveWords(input, successAction, failedAction)
    local inputs = json.encode({input})
    self.CommonComp:CheckSensitiveWords(
        inputs,"",
        function(code, msg, data)
			if code and msg then
				Log.InfoFormat("CheckSensitiveWords code:%d msg:%s",code,msg)
			end
            if code ~= 1 then
                if failedAction then failedAction() end
            else
				if data.sensitiveResult then
					for _, v in pairs(data.sensitiveResult) do
						if v.matchResults and #v.matchResults > 0 then
							if successAction then successAction(true) end
							return
						end
					end
				end
                if successAction then successAction(false) end
            end
        end,
        failedAction
    )
end

--endregion 协议&用户中心相关
--------------------------------------------------------------------------------------------------------------------------
--region 分享

---GetShareType 获取当前支持的分享平台
---@return table{Enum.SharePlatform}
function AllInSdkManager:GetSupportPlatformList(successAction, failedAction)
    self.Share:GetSupportPlatformList(successAction, failedAction)
end

---ShareToPlatform
---@param platform Enum.SharePlatform 分享平台类型
---@param shareType Enum.ShareType 分享类型
---@param imagePath string 图片路径
---@param title string 标题
---@param content string 内容
---@param successAction function 成功回调
---@param failedAction function 失败回调
function AllInSdkManager:ShareToPlatform(platform, shareType, imagePath, title, content, successAction, failedAction)
    if PlatformUtil.IsWindows() then
        if failedAction then failedAction() end
    else
        imagePath = import("LuaFunctionLibrary").ConvertToAbsolutePathForExternalAppForRead(imagePath)
        self.Share:Share(platform, shareType, imagePath, title, content, successAction, failedAction)
    end
end

---SaveToPhotos 保存图片至相册
---@param path string 图片路径
---@param successAction function 成功回调
---@param failedAction function 失败回调
function AllInSdkManager:SaveToPhotos(path, successAction, failedAction)
    path = import("LuaFunctionLibrary").ConvertToAbsolutePathForExternalAppForRead(path)
    self.CommonComp:SaveImageToAlbum(path, successAction, failedAction)
end

--endregion
---------------------------------------------------------------------------------------------------------------------------
--region PC埋点相关
---@param event_name_param string 埋点类型
---@param extra_param table 埋点数据
---@param tracking_type_param integer?  默认0，0为全通道报，1为只报BI通道，2为只报AD通道, 
function AllInSdkManager:Track(event_name_param, extra_param,tracking_type_param)
    if not _G.AllInSDKTrackingOrReport then
        return
    end
	if not tracking_type_param then
		tracking_type_param = 0
	end
    local jsonTable = {event_name = event_name_param, tracking_type = tracking_type_param, extra = extra_param}
    self.Tracking:Track(jsonTable)
end

---UpdateRoleData 更新角色信息
---@param update_timing string 更新时机 0--角色登录  1--创建角色  2--角色升级 3--角色登出
function AllInSdkManager:UpdateRoleData(update_timing)
    if Game.me then
        local roleId = Game.me.eid
        local roleName = Game.me.Name
        local level = tostring(Game.me.Level)
        local vipLevel = "0"
        local serverId = Game.LoginSystem:GetServerLoginData().ServerId
        local serverName = Game.LoginSystem:GetServerLoginData().ServerName
        local role_sex = "0"
        local role_power = "0"
        self.Platform:UpdateRoleData(roleId, roleName, level, vipLevel, serverId, serverName, role_sex, role_power, update_timing)
    end
end

--endregion PC埋点相关

---region Misc相关
---@overload GetTotalDiskSpace --获取app所在disk的总大小
---@return number 磁盘的总字节大小
function AllInSdkManager:GetTotalDiskSpace()
    return self.CommonComp:GetTotalDiskSpace()
end

---@overload GetFreeDiskSpace --获取app所在disk的剩余大小
---@return number 磁盘剩余的字节大小
function AllInSdkManager:GetFreeDiskSpace()
    return self.CommonComp:GetFreeDiskSpace()
end

---GetLocation 归属地信息获取
---@param successAction function
---@param failedAction function
function AllInSdkManager:GetLocation(successAction,failedAction)
    self.CommonComp:GetLocation(function(code,msg,locationData)
        self.SdkData.Location = locationData
        if successAction then
            successAction(locationData)
        end
    end,function(error)
        print(string.format("AllInSdkManager GetLocation Failed,ErrorCode :%d, ErrorMessage :%s",error.code,error.message))
        if failedAction then
            failedAction(error)
        end
    end)
end

---endregion Misc相关
---------------------------------------------------------------------------------------------------------------------------
--region 上传文件

function AllInSdkManager:Upload(localFilePath, successAction, failedAction)
    localFilePath = LuaFunctionLibrary.ConvertToAbsolutePathForExternalAppForRead(localFilePath)
    local taskId = tostring(LowLevelFunctions.GetGlobalUniqueID())
    self.CommonComp:Upload(taskId, localFilePath)
    if successAction or failedAction then
        self.uploadCallbacks[taskId] = {SuccessAction = successAction, FailedAction = failedAction}
    end
    return taskId
end

function AllInSdkManager:SetUploadListener()
    self:RegisterListener("commonComp.onUploadListener",function(error, resultData) self:onUploadNotify(error, resultData) end)
end

function AllInSdkManager:onUploadNotify(error, resultData)
    if resultData then
        local taskId = resultData.data.result.taskId
        if self.uploadCallbacks[taskId] then
            if resultData.code == 1 and resultData.data.callback == "onComplete" and self.uploadCallbacks[taskId].SuccessAction then
                xpcall(self.uploadCallbacks[taskId].SuccessAction, _G.CallBackError, resultData.data.result.resourceId)
                self.uploadCallbacks[taskId] = nil
            elseif resultData.code ~= 1 and self.uploadCallbacks[taskId].FailedAction then
                xpcall(self.uploadCallbacks[taskId].FailedAction, _G.CallBackError)
                self.uploadCallbacks[taskId] = nil
            end
        end
    end
end
--endregion 上传文件
---------------------------------------------------------------------------------------------
--region 绑定回调

---@overload SetAccountLogoutCallback 绑定全局账号登出回调
---@param callback function
function AllInSdkManager:SetAccountLogoutCallback(callback)
    self:RegisterListener("platform.logout",function(error, resultData)
        if resultData and resultData.code == 1 and callback then
            callback()
        end
    end)
end

---@overload ClearAccountLogoutCallback 清理全局账号登出回调
function AllInSdkManager:ClearAccountLogoutCallback()
    self:RemoveListener("platform.logout")
end

---@overload SetPayCallback 绑定支付回调
---@param successAction function
---@param failedAction function
---@param onRequestPaymentDetail function PC平台无需传递
function AllInSdkManager:SetPayCallback(successAction,failedAction, onRequestPaymentDetail)
    self.OnPaySuccessListener = successAction
    self.OnPayFailedListener = failedAction
end

---@overload ClearPayCallback 清理支付回调
function AllInSdkManager:ClearPayCallback()
    self.OnPaySuccessListener = nil
    self.OnPayFailedListener = nil
end

--endregion 绑定回调

--region 退出按钮
function AllInSdkManager:Exit()
    self.Platform:Exit()
end
--endregion

--region WebBrowser

---@param windowStyle integer 0全屏,1弹窗；默认0
---@param rect table windowStyle为1时生效, 设置弹窗的展示尺寸
---@param orientation integer 屏幕方向： 0自动，1竖屏，2横屏；默认0，只针对 windowStyle=0，即全屏模式下才生效
---@param hideToolBar boolean 	是否隐藏底部导航 true隐藏 false展示;默认false
---@param hideTitle boolean 是否隐藏底部导航 true隐藏 false展示;默认false
---@param hideProgressBar boolean 是否隐藏顶部标题栏 true隐藏 false展示，仅竖屏下生效，横屏固定隐藏;默认false
---@param shareList table
function AllInSdkManager:InitWebviewWithConfig(windowStyle, rect, orientation, hideToolBar, hideTitle, hideProgressBar, shareList)
    self.CommonComp:InitWebviewWithConfig(windowStyle, rect, orientation, hideToolBar, hideTitle, hideProgressBar, shareList)
end

function AllInSdkManager:OpenWebviewUrl(url)
    self.CommonComp:OpenWebviewUrl(url)
end

function AllInSdkManager:DirectlyOpenWebviewUrl(url)
    self:InitWebviewWithConfig(0)   --先搞成默认，后面有需求加
    self:OpenWebviewUrl(url)
end

--endregion

--region Report
function AllInSdkManager:Feedback(reportType, reportReason, reportText, reportPics, targetId, targetServer, logID)
	return self.CommonComp:Feedback(reportType, reportReason, reportText, reportPics, targetId, targetServer, logID)
end
--endregion

--region Photo
function AllInSdkManager:ChoosePhotos(maxPhotos, resultType, permissionDesc, guideToSettings, successAction, failedAction)
	return self.CommonComp:ChoosePhotos(maxPhotos, resultType, permissionDesc, guideToSettings, successAction, failedAction)
end
--endregion

function AllInSdkManager:SetUseAllinExitDialog(useAllinExit)
    self.Platform:SetUseAllinExitDialog(useAllinExit)
end

function AllInSdkManager:OnAndroidBackReleased(keyName, inputEvent)
    Log.Debug("AllInSdkManager:OnAndroidBackReleased")
    self:Exit()
    return false
end

function AllInSdkManager:UnInit()
    Game.UIInputProcessorManager:UnBindKeyEvent(self, "Android_Back", EInputEvent.IE_Released)
    Game.EventSystem:RemoveObjListeners(self)
    self.super:UnInit()
    self.uploadCallbacks = nil
end

return AllInSdkManager