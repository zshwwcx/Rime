local MessageChannel = require "Framework.AllInSDK.MessageChannel"
local DataBase = require "Framework.AllInSDK.DataBase"


--登录类型
--UNDEFINE,无效值,undefine
--KS,快手登录,ks
--QQ,QQ登录,qq
--WEIXIN,微信登录,weixin
--VISITOR,游客登录,vistor
--PHONE,手机号登录,phone
--STAND_ALONE,(Android),stand_alone
--QRCODE,二维码登录,qr_code
--FACEBOOK,Facebook登录(海外),facebook
--GOOGLE,Google登录(海外),google
--CHANNEL,渠道登录（Android）,channel
--APPLE,Apple登录(iOS),apple
--GAMECENTER,苹果GameCenter登录(iOS),game_center
--TAPTAP,TapTap登录(Android),taptap
--LINE,LINE登录,line
--enum枚举
Enum.LoginTypeOption =
{
    UNDEFINE = "undefine",   --无效值 
    KS = "ks",   --快手登录 
    QQ = "qq",   --QQ登录 
    WEIXIN = "weixin",   --微信登录 
    VISITOR = "vistor",   --游客登录 
    PHONE = "phone",   --手机号登录 
    STAND_ALONE = "stand_alone",   --(Android) 
    QRCODE = "qr_code",   --二维码登录 
    FACEBOOK = "facebook",   --Facebook登录(海外) 
    GOOGLE = "google",   --Google登录(海外) 
    CHANNEL = "channel",   --渠道登录（Android） 
    APPLE = "apple",   --Apple登录(iOS) 
    GAMECENTER = "game_center",   --苹果GameCenter登录(iOS) 
    TAPTAP = "taptap",   --TapTap登录(Android) 
    LINE = "line",   --LINE登录 

}
--summary
--para账号信息数据类
--summary
--子类型
---@class AccountInfo
AccountInfo = DefineClass("AllinAccountInfo", DataBase)

function AccountInfo:ctor(Param)
    self.sdkUserId = self:ParseStringValue("sdkUserId")
    self.sdkToken = self:ParseStringValue("sdkToken")
    self.newUser = self:ParseBoolValue("newUser")
    self.loginType = self:ParseEnumValue("loginType")

end
--summary
--para游戏账号数据类
--summary
--子类型
---@class KwaiGameUser
KwaiGameUser = DefineClass("AllinKwaiGameUser", DataBase)

function KwaiGameUser:ctor(Param)
    self.gameUserId = self:ParseStringValue("gameUserId")
    self.uid = self:ParseStringValue("uid")
    self.userName = self:ParseStringValue("userName")
    self.unionID = self:ParseStringValue("unionID")
    self.userHead = self:ParseStringValue("userHead")
    self.userGender = self:ParseStringValue("userGender")
    self.userCity = self:ParseStringValue("userCity")
    self.anonymous = self:ParseBoolValue("anonymous")
    self.certificated = self:ParseBoolValue("certificated")
    self.adult = self:ParseBoolValue("adult")
    self.ksOpenId = self:ParseStringValue("ksOpenId")
    self.banStatus =  UserBanStatus.new(self.data.banStatus) -- 账号的封禁状态
    self.bindChannel = self:ParseStringValue("bindChannel")

end
--summary
--para产品详情
--summary
--子类型
---@class ProductDetail
ProductDetail = DefineClass("AllinProductDetail", DataBase)

function ProductDetail:ctor(Param)
    self.productId = self:ParseStringValue("productId")
    self.title = self:ParseStringValue("title")
    self.des = self:ParseStringValue("des")
    self.price = self:ParseStringValue("price")
    self.micros_price = self:ParseFloatValue("micros_price")
    self.price_currency_code = self:ParseStringValue("price_currency_code")
    self.price_codes = self:ParseStringValue("price_codes")
    self.rawData = self:ParseStringValue("rawData")

end
--summary
--para价格和币种
--summary
--子类型
---@class PriceAndCode
PriceAndCode = DefineClass("AllinPriceAndCode", DataBase)

function PriceAndCode:ctor(Param)
    self.price = self:ParseStringValue("price")
    self.price_code = self:ParseStringValue("price_code")

end
--summary
--para支付模块数据类
--summary
--子类型
---@class PayModel
PayModel = DefineClass("AllinPayModel", DataBase)

function PayModel:ctor(Param)
    self.currencyType = self:ParseStringValue("currencyType")
    self.extension = self:ParseStringValue("extension")
    self.notifyUrl = self:ParseStringValue("notifyUrl")
    self.productId = self:ParseStringValue("productId")
    self.roleId = self:ParseStringValue("roleId")
    self.serverId = self:ParseStringValue("serverId")
    self.sign = self:ParseStringValue("sign")
    self.thirdPartyTradeNo = self:ParseStringValue("thirdPartyTradeNo")

end
--summary
--para支付返回信息
--summary
--子类型
---@class PayResultModel
PayResultModel = DefineClass("AllinPayResultModel", DataBase)

function PayResultModel:ctor(Param)
    self.productId = self:ParseStringValue("productId")
    self.productName = self:ParseStringValue("productName")
    self.extension = self:ParseStringValue("extension")

end
--summary
--账号模块处理类
--summary
local Platform = DefineClass("AllinPlatform")

function Platform:ctor()
end


--summary
--para初始化相关 待补充
--para初始化相关 待补充
--summary>
--param name="successAction">Action(int,string),,--param name="failedAction">Action(Error}),code:错误码,message:错误描述
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
function Platform:Init(successAction,failedAction)
    local Param = {}
    local result = MessageChannel:SendMessageCallback(
            "platform",
            "init",
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
                    successAction(code,msg)
                elseif failedAction then
                    failedAction({["code"]=-1,["msg"]="data parsing failed"})
                end
            end
    )
    return result
end

--summary
--para登录相关 待补充
--para登录相关 待补充
--summary>
--param name="login_type" string,登录类型string，例如：google
--param name="successAction">Action(int,string,AccountInfo),,,登录成功后返回的账号信息--param name="failedAction">Action(Error}),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para AllinSDK.Account.Login(delegate(AccountInfo accountInfo) { 
--para delegate(AccountInfo accountInfo) { 
--para }, delegate(Error error) { 
--para }); 
--example 
--seealso cref="登录相关"
--remarks
--para登录相关 待补充
--remarks
---@param successAction function
---@param failedAction function
function Platform:Login(successAction, failedAction)
    local Param = {}
    local result = MessageChannel:SendMessageCallback(
            "platform",
            "login",
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
                        data = AccountInfo.new(resultData.data) -- 登录成功后返回的账号信息
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
--param name="successAction">Action(int,string),,--param name="failedAction">Action(Error}),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
---@param successAction function
---@param failedAction function
function Platform:Logout(successAction,failedAction)
    local Param = {}
    local result = MessageChannel:SendMessageCallback(
            "platform",
            "logout",
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
                    successAction(code,msg)
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
--param name="login_type" string,登录类型string，例如：google
--param name="successAction">Action(int,string,Hashtable),,,--param name="failedAction">Action(Error}),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
---@param login_type string
---@param successAction function
---@param failedAction function
function Platform:BindAccount(login_type,successAction,failedAction)
    local Param = {}
    Param["login_type"] = login_type
    local result = MessageChannel:SendMessageCallback(
            "platform",
            "bindAccount",
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
                        data = MessageChannel:ParseTableValue(resultData["data"])
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
--param name="login_type" string,登录类型string，例如：google
--param name="successAction">Action(int,string,Hashtable),,,--param name="failedAction">Action(Error}),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
---@param login_type string
---@param successAction function
---@param failedAction function
function Platform:UnbindAccount(login_type,successAction,failedAction)
    local Param = {}
    Param["login_type"] = login_type
    local result = MessageChannel:SendMessageCallback(
            "platform",
            "unbindAccount",
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
                        data = MessageChannel:ParseTableValue(resultData["data"])
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
--param name="successAction">Action(int,string),,--param name="failedAction">Action(Error}),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
---@param successAction function
---@param failedAction function
function Platform:LogoffAccount(successAction,failedAction)
    local Param = {}
    local result = MessageChannel:SendMessageCallback(
            "platform",
            "logoffAccount",
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
                    successAction(code,msg)
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
function Platform:GetGameUser()
    local Param = {}
    local result = MessageChannel:SendMessageString(
            "platform",
            "getGameUser",
            Param
    )
    result =  KwaiGameUser.new(result)
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
function Platform:HasUserCenter()
    local Param = {}
    local result = MessageChannel:SendMessageBool(
            "platform",
            "hasUserCenter",
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
function Platform:OpenUserCenter()
    local Param = {}
    local result = MessageChannel:SendMessageVoid(
            "platform",
            "openUserCenter",
            Param
    )
    return result
end

--summary
--para更新角色信息
--summary>
--param name="roleId" string,角色信息
--param name="roleName" string,角色名称
--param name="level" string,角色等级
--param name="vipLevel" string,角色vip等级
--param name="serverId" string,角色服务器id
--param name="serverName" string,角色服务器名称
--param name="role_sex" string,角色性别
--param name="role_power" string,角色能力值
--param name="update_timing" string,角色更新时间
--param name="successAction">Action(),回调函数无返回值
--param name="failedAction">Action(Error),code:错误码,message:错误描述
--example  
--para AllinSDK.Account.UpdateRoleData(roleData, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
---@param roleId string
---@param roleName string
---@param level string
---@param vipLevel string
---@param serverId string
---@param serverName string
---@param role_sex string
---@param role_power string
---@param update_timing string
function Platform:UpdateRoleData(roleId,roleName,level,vipLevel,serverId,serverName,role_sex,role_power,update_timing)
    local Param = {}
    Param["roleId"] = roleId
    Param["roleName"] = roleName
    Param["level"] = level
    Param["vipLevel"] = vipLevel
    Param["serverId"] = serverId
    Param["serverName"] = serverName
    Param["role_sex"] = role_sex
    Param["role_power"] = role_power
    Param["update_timing"] = update_timing
    local result = MessageChannel:SendMessageVoid(
            "platform",
            "updateRoleData",
            Param
    )
    return result
end

--summary
--para获取商品列表
--para***相关 待补充
--summary>
--param name="successAction">Action(int,string,),,,--param name="failedAction">Action(Error}),code:错误码,message:错误描述
--exception cref="无">无
--returns 无
--example  
--para 调用代码示例*** 
--example 
--seealso cref="***相关"
--remarks
--para***相关 待补充
--remarks
---@param successAction function
---@param failedAction function
function Platform:GetProductList(successAction,failedAction)
    local Param = {}
    local result = MessageChannel:SendMessageCallback(
            "platform",
            "getProductList",
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
                        data = MessageChannel:ParseStringValue(resultData.data)
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
--para支付,文档地址：https://sdkdocs.game.kuaishou.com/sdkdoc/sdkdoc/pay/pay/#pay_success_callback
--para调起客户端支付
--summary>
--param name="currencyType" string,货币类型
--param name="extension" string,拓展信息
--param name="notifyUrl" string,支付回调url
--param name="productId" string,商品id
--param name="roleId" string,用户id
--param name="serverId" string,服务器id
--param name="sign" string,签名
--param name="thirdPartyTradeNo" string,三方订单id
--param name="successAction">Action(int,string,PayResultModel),,,--param name="failedAction">Action(Error}),code:错误码,message:错误描述
--example  
--para AllinSDK.Pay.Pay(payModel, 
--para delegate() { 
--para }, delegate(Error error) { 
--para }); 
--example 
--remarks
--para账号登录成功之后调用支付接口。参考文档：https://sdkdocs-beta.game.kuaishou.com/sdkdoc/1.28-alpha/sdkdoc/pay/pay/#21
--remarks
---@param currencyType string
---@param extension string
---@param notifyUrl string
---@param productId string
---@param roleId string
---@param serverId string
---@param sign string
---@param thirdPartyTradeNo string
---@param successAction function
---@param failedAction function
function Platform:Pay(currencyType,extension,notifyUrl,productId,roleId,serverId,sign,thirdPartyTradeNo,serverName,roleName,successAction,failedAction)
    local Param = {}
    Param["currencyType"] = currencyType
    Param["extension"] = extension
    Param["notifyUrl"] = notifyUrl
    Param["productId"] = productId
    Param["roleId"] = roleId
    Param["serverId"] = serverId
    Param["sign"] = sign
    Param["thirdPartyTradeNo"] = thirdPartyTradeNo
    Param["serverName"] = serverName
    Param["roleName"] = roleName
    local result = MessageChannel:SendMessageCallback(
            "platform",
            "pay",
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
                        data = PayResultModel.new(resultData.data) -- 
                    end
                    successAction(code,msg,data)
                elseif failedAction then
                    failedAction({["code"]=-1,["msg"]="data parsing failed"})
                end
            end
    )
    return result
end

function Platform:Exit()
    local Param = {}
    MessageChannel:SendMessageVoid(
        "platform",
        "exit",
        Param
    )
end

function Platform:SetUseAllinExitDialog(bUseAllinExit)
    local Param = {}
    Param["useAllinExit"] = bUseAllinExit
    MessageChannel:SendMessageVoid(
        "platform",
        "setUseAllinExitDialog",
        Param
    )
end

return Platform