---@class AllInSdkManagerBase
local AllInSDKManagerBase = DefineClass("AllInSDKManagerBase")
require("Data.Config.AllInSDKTrack.AllInSDKEnum")
local MessageChannel = require "Framework.AllInSDK.MessageChannel"

-- ErrorCode
AllInSDKManagerBase.ErrorCode = {
    LOGIN_CANCEL_BY_USER = 10001
}

AllInSDKManagerBase.bAllInSDKEnabled = import("AllInManager").IsAllInSDKEnabled()

function AllInSDKManagerBase:ctor()
    if self.AllInSDKModules then
        for _, value in ipairs(self.AllInSDKModules) do
            self[value] = require(string.format("Framework.AllInSDK.%s.%s.%s",self.ModuleRootPath,value, value)).new()
        end
    end
    self.cppAllInManager = nil
    self.OnPayFailedListener = nil
    self.SdkData = { Channel = "", MarketChannel = "", DeviceId = "", IsMock = false, Location = { countryRegionCode = "", country = "", province = "", city = "" } }
end

function AllInSDKManagerBase:Init()
	self.cppAllInManager = import("AllInManager")(_G.GetContextObject())
	self.cppAllInManager:Init()
	self.cppAllInManager:RegisterCallbackEvent()
end

--region 模拟AllInSdk提供的接口功能

function AllInSDKManagerBase:Logout() end

function AllInSDKManagerBase:QueryProductDetails(successAction,failedAction)
    if successAction then successAction() end
end

function AllInSDKManagerBase:PayProduction(productId,sign,thirdPartyTradeNo,payNotifyUrl,extension)
    if self.OnPayFailedListener then self.OnPayFailedListener({code = -1,msg = "nothing"}) end
end

function AllInSDKManagerBase:GetGameNotice(successAction,failedAction)
    local emptyTable = {}
    Game.AnnounceSystem:SetNoticeList(emptyTable)
    if successAction then successAction(emptyTable) end
end

function AllInSDKManagerBase:GetServerList() end

function AllInSDKManagerBase:StopGetServerInfo() end

function AllInSDKManagerBase:QueryGameAccountInfo(successCallback, failedCallback) end

function AllInSDKManagerBase:QueryGameServerInfo(successCallback, failedCallback) end

function AllInSDKManagerBase:ShowUserCenter() end

function AllInSDKManagerBase:ShowPrivacyProtocol() end

function AllInSDKManagerBase:CheckSensitiveWords(inputs,successAction,failedAction)
    local result = {}
    for _, data in ipairs(inputs) do
        table.insert(result, {input = data, matchResults = {}})
    end
    if successAction then successAction(result) end
end

function AllInSDKManagerBase:IsSensitiveWords(input,successAction,failedAction)
    if successAction then successAction(false) end
end

function AllInSDKManagerBase:SetAccountLogoutCallback(callback) end

function AllInSDKManagerBase:ClearAccountLogoutCallback() end

function AllInSDKManagerBase:SetPayCallback(successAction,failedAction,onRequestPaymentDetail)
    self.OnPayFailedListener = failedAction
end

function AllInSDKManagerBase:ClearPayCallback()
    self.OnPayFailedListener = nil
end

function AllInSDKManagerBase:GetDeviceType()
    return 0
end

function AllInSDKManagerBase:IsSimulator()
    return false
end

function AllInSDKManagerBase:Track(event_name_param,extra_param,tracking_type_param)
end

function AllInSDKManagerBase:UpdateRoleData(update_timing)
end

function AllInSDKManagerBase:GetTotalDiskSpace()
    return 0
end

function AllInSDKManagerBase:GetFreeDiskSpace()
    return 0
end
function AllInSDKManagerBase:Upload(localFilePath, successAction, failedAction)
	if failedAction then failedAction() end
    return 0
end

---GetShareType 获取当前支持的分享平台
---@return table{Enum.SharePlatform}
function AllInSDKManagerBase:GetSupportPlatformList(successAction, failedAction)
    if failedAction then failedAction() end
end

---ShareToPlatform
---@param platform Enum.SharePlatform 分享平台类型
---@param shareType Enum.ShareType 分享类型
---@param imagePath string 图片路径
---@param title string 标题
---@param content string 内容
---@param successAction function 成功回调
---@param failedAction function 失败回调
function AllInSDKManagerBase:ShareToPlatform(platform, shareType, imagePath, title, content, successAction, failedAction)
    if failedAction then failedAction() end
end

---SaveToPhotos 保存图片至相册
---@param path string 图片路径(相对路径即可)
---@param successAction function 成功回调
---@param failedAction function 失败回调
function AllInSDKManagerBase:SaveToPhotos(path, successAction, failedAction)
    if failedAction then failedAction() end
end

function AllInSDKManagerBase:Exit()
end

--region WebBrowser

function AllInSDKManagerBase:InitWebviewWithConfig(windowStyle, rect, orientation, hideToolBar, hideTitle, hideProgressBar, shareList)
end

function AllInSDKManagerBase:OpenWebviewUrl(url)
end

function AllInSDKManagerBase:DirectlyOpenWebviewUrl(url)
end

--endregion

--region Report
function AllInSDKManagerBase:Feedback(reportType, reportReason, reportText, reportPics, targetId, targetServer)
end
--endregion

--region Photos
function AllInSDKManagerBase:ChoosePhotos(maxPhotos, resultType, permissionDesc, guideToSettings, successAction, failedAction)
end
--endregion

function AllInSDKManagerBase:SetUseAllinExitDialog(useAllinExit)
end

--endregion 模拟AllInSdk提供的接口功能

---RegisterListener 注册监听函数
---@param Command string 监听方法名字
---@param Callback function 回调函数
function AllInSDKManagerBase:RegisterListener(Command, Callback)
    MessageChannel:RegisterListener(Command, Callback)
end

function AllInSDKManagerBase:RemoveListener(Command)
    MessageChannel:RemoveListener(Command)
end

function AllInSDKManagerBase.GetNeedSdk()
    if _G.SkipAllInSdk or not AllInSDKManagerBase.bAllInSDKEnabled then
        return false
    elseif import("GameplayStatics").DoesSaveGameExist("AllInSdkSave", 0) then
        local saveObj = import("GameplayStatics").LoadGameFromSlot("AllInSdkSave", 0)
        if not saveObj then
            return not import("C7FunctionLibrary").IsC7Editor()
        end
        return saveObj.SdkLogin
    else
        return not import("C7FunctionLibrary").IsC7Editor()
    end
end

function AllInSDKManagerBase:SetNeedSdk(value)
    local sdkGameSlot = "AllInSdkSave"
    local saveObj
    if import("GameplayStatics").DoesSaveGameExist(sdkGameSlot, 0) then
        saveObj = import("GameplayStatics").LoadGameFromSlot(sdkGameSlot, 0)
    end
    if not saveObj then
        saveObj = import("GameplayStatics").CreateSaveGameObject(slua.loadClass("/Game/Arts/UI_Update/Blueprint/BP_AllInSdkData.BP_AllInSdkData_C"))
    end
    saveObj.SdkLogin = value
    import("GameplayStatics").SaveGameToSlot(saveObj, sdkGameSlot, 0)
end

function AllInSDKManagerBase:UnInit()
    MessageChannel:ClearResponseAndListener()
    
    if self.cppAllInManager  then 
        self.cppAllInManager:UnregisterCallbackEvent()
    end

    self.cppAllInManager = nil
end

return AllInSDKManagerBase