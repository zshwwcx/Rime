local MessageChannel = require "Framework.AllInSDK.MessageChannel"
local DataBase = require "Framework.AllInSDK.DataBase"

--分享平台
---@class Enum.SharePlatform
Enum.SharePlatform =
{
    QQ = "qq",  --分享到qq
    QQ_ZONE = "qq_zone",  --分享到qq空间
    WEIXIN = "weixin",  --分享到微信
    WEIXIN_TIMELINE = "weixin_timeline",  --分享到微信朋友圈
    WEIBO = "weibo",  --分享到新浪微博
}

--分享类型
---@class Enum.ShareType
Enum.ShareType =
{
    Web = 1,    -- 网页分享
    Image = 3,  -- 图片分享
}

--summary
--para分享模块
--summary
--子类型
---@class ShareModel
ShareModel = DefineClass("AllinShareModel", DataBase)
function ShareModel:ctor()
    self.shareType = self:ParseEnumValue("shareType")
    self.title = self:ParseStringValue("title")
    self.url = self:ParseStringValue("url")
    self.content = self:ParseStringValue("content")
    self.image = self:ParseStringValue("image")
end



--summary
--Crash模块处理类
--summary
local Share = DefineClass("Share")

function Share:ctor()
end

function Share:GetSupportPlatformList(successAction, failedAction)
    local Param = {}
    local result = MessageChannel:SendMessageCallback(
        "customService",
        "showCustomServicePage",
        Param,
        function(error, resultData)
            if error and failedAction then failedAction() end
            if resultData and successAction then
                local code
                if resultData.code then
                    code = MessageChannel:ParseIntValue(resultData["code"])
                end
                local msg
                if resultData.msg then
                    msg = MessageChannel:ParseStringValue(resultData["msg"])
                end
                local data
                if resultData.data then
                    data = MessageChannel:ParseTableValue(resultData["data"])
                end
                successAction(code, msg, data)
            elseif failedAction then
                failedAction({["code"]=-1,["msg"]="data parsing failed"})
            end
        end
    )
    return result
end

function Share:Share(platform, shareType, imagePath, title, content, successAction, failedAction)
    local params = {
        platform = platform,
        shareData = ShareModel.new({
            shareType = shareType,
            title = title,
            content = content,
            image = imagePath,
        }):Serialize()
    }
    local result = MessageChannel:SendMessageCallback(
        "share",
        "share",
        params,
        function(error, resultData)
            if error and failedAction then failedAction() end
            if resultData and successAction then
                local code
                if resultData.code then
                    code = MessageChannel:ParseIntValue(resultData["code"])
                end
                successAction(code)
            elseif failedAction then
                failedAction({["code"]=-1,["msg"]="data parsing failed"})
            end
        end
    )
    return result
end 

return Share