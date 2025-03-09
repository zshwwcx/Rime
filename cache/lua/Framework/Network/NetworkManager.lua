local C7Client = require "Framework.Network.C7Client"

NetworkManager = DefineClass("NetworkManager")

---@private
---私有不注册回调表
---@param table
NetworkManager.DontRegisterTable = {
    ["CurrentMaxHp"] = 1,
    ["Exp"] = 1,
    ["Camp"] = 1,
    ["teamID"] = 1,
    ["guildId"] = 1,
    ["groupID"] = 1,
    ["isInTeamMatch"] = 1,
    ["isInSingleMatch"] = 1,
    ["FollowState"] = 1,
    ["isCaptain"] = 1,
    ["teamTargetID"] = 1,
    ["Level"] = 1,
    ["IsOnline"] = 1,
    ["bTargetedByBoss"] = 1,
    ["groupBlockVoices"] = 1,
    ["invitedInfoList"] = 1,
    ["teamInfoList"] = 1,
    ["teamApplicatorList"] = 1,
    ["teamCombineList"] = 1,
    ["teamCollectList"] = 1,
    ["singleMatchInfoList"] = 1,
    ["teamPositionNeedList"] = 1,
    ["teamZhanliLimit"] = 1,
    ["teamInfoList.name"] = 1,
    ["teamInfoList.profession"] = 1,
    ["teamInfoList.level"] = 1,
    ["teamInfoList.isCaptain"] = 1,
    ["teamInfoList.hp"] = 1,
    ["teamInfoList.maxHp"] = 1,
    ["teamInfoList.isDead"] = 1,
    ["teamInfoList.bFollowing"] = 1,
    ["teamInfoList.bTargetByBoss"] = 1,
    ["teamInfoList.voiceState"] = 1,
    ["teamInfoList.lineID"] = 1,
    ["teamInfoList.map"] = 1,
    ["groupLeaderUid"] = 1,
    ["groupTeamLeaderUid"] = 1,
    ["bGroupFollow"] = 1,
    ["guildAnswerIndex"] = 1,
    ["FightRelationship"] = 1,
    ["FightModeType"] = 1,
    ["Bounty"] = 1,
    ["quickMedicineItemId"] = 1,
    ["teamInfoList.location"] = 1,
    ["teamInfoList.mapInstID"] = 1,
    ["teamInfoList.isOnline"] = 1,
    ["YellowNameTime"] = 1,
}

--网络实体属性定义xml解析
local function InitDefs()
    -- copied from game.lua
    --local Content = import("LuaFunctionLibrary").LoadFileUnderScript("App/PropertyDefs/alias.xml")
    local readFile = import("LuaFunctionLibrary").LoadFileUnderScript
    local script_root_path = "Data/NetDefs/"
    -- local script_root_path = "App/PropertyDefs/"
    local alias_path = script_root_path .. "alias.xml"
    local aliasContent = readFile(alias_path)
    if aliasContent == "" then
        Log.Warning("read alias.xml error")
    end

    local entity_defs = {}
    local allEntities = Game.EntityManager:getEntityClsMap()
    for entName, entCls in pairs(allEntities) do
        if entCls.HAS_ENTITY_DEF then
            entity_defs[entName] = ""
            -- @todo: c7 fix start
            -- by shijingzhe
            -- 原有的component实现没有HAS_ENTITY_DEF参数, 所以在这里不会被注册到entity_defs中
            -- 这会导致读取xml时漏掉entity本来包含的component, 导致doraemon报错, 从而导致int类型参数不能被正确打包的问题
            -- 因此, 在entity中添加了一个新的COMPONENTS_DEF定义, 用以包含component到entity_defs中, 使其能够正确读取xml
            -- 定义的使用方法参见, App\NetEntities\AvatarActor.lua:16
            if entCls.__supers then
                for _, super in pairs(entCls.__supers) do
                    entity_defs[super.__cname] = ""
                end
            end
            if entCls.__components then
                for _, component in pairs(entCls.__components) do
                    entity_defs[component.__cname] = ""
                end
            end
        -- @todo: c7 fix end
        end
    end

    for eType, _ in pairs(entity_defs) do
        local ent_path = script_root_path .. eType .. ".xml"
        print("initDefs entity def path: " .. ent_path)
        local entContent = readFile(ent_path)
        if entContent == "" then
            Log.WarningFormat("read %s error!!", ent_path)
        end
        entity_defs[eType] = entContent
    end
    local broadcastRpcXmlName = "BroadcastRpc"
    local entContent = readFile(script_root_path .. broadcastRpcXmlName .. ".xml")
    if entContent == "" then
        Log.WarningFormat("read %s error!!", broadcastRpcXmlName)
    end
    entity_defs[broadcastRpcXmlName] = entContent

    if not _script.parseDefs(aliasContent, entity_defs) then
        -- c7 fix start
        error("parse alias.xml error")
        -- c7 fix end
    end

    _script.setBroadcastEntityDef("BroadcastRpc")
    -- if not _script.parseDefs(Content) then
    --     Log.Warning("parse alias.xml error")
    -- end
end


NetworkManager.LocalAvatarActor = nil

NetworkManager.LocalAvatar = nil

-- @todo: c7 fix start
-- by zhangyoujun
NetworkManager.LocalSpace = nil
NetworkManager.LocalSpaceState = nil
-- @todo: c7 fix end

local ErrCodes = {}
NetworkManager.ErrCodes = ErrCodes

NetworkManager.ConnectTimeout = 3000  --服务器连接超时时间(ms)
NetworkManager.KcpTryCountLimit = 3 --KCP模式连接尝试次数


function NetworkManager:ctor()
    self.client = nil
    self.username = 0
    self.password = 0
    self.ip = 0
    self.port = 0

    self.RetLoginData = {}

    --临时移动到这, 后期删除
    self.EntitySingletons = {}
    
    --缓存下table
    self.TimeoutList = {}
    self.connectTimeoutTimer = nil
end

function NetworkManager:dtor()
    self.client = nil
end

function NetworkManager:Init()
    print("NetworkManager:Init")
    self.tryKCPNumber = 0;

    --网络实体属性定义xml解析
    InitDefs()

    self.RetLoginData = {}
    self.TimeoutList = {}

    --临时移动到这, 后期删除
    self.EntitySingletons = {}

    NetworkManager.ErrCodes = Enum.EErrCodeData
end

function NetworkManager:UnInit()
    print("NetworkManager:UnInit")
    Game.TimerManager:StopTimerAndKill(self.timer)
    self.client = nil
end

function NetworkManager:ConnectServer(ip, port)
	Log.DebugFormat("[GameLoop-LifeTimeStage]NetworkManager:ConnectServer ip:%s  port:%s", ip, port)
    self.ip = ip
    self.port = port

    if self.client == nil then
        self.client = C7Client.new()
        Log.Debug("[ReqLogin]new client ip:"..ip)
        --self.client:add_user_callback(NetCallbackType.CONNECT, self.OnConnect, self)
    end

    self.client:disconnect()
    self.client:set_handshake_key()
    self.client:connect(ip, port)
    self.connectTimeoutTimer = Game.TimerManager:CreateTimerAndStart(function()
        if _G.UseKCP then
            self.connectTimeoutTimer = nil
            self.tryKCPNumber = self.tryKCPNumber + 1
            if self.tryKCPNumber >= self.KcpTryCountLimit then
                _G.UseKCP = false
            end
            self.client:stop(true)
            self:ConnectServer(ip,port)
        end
    end, self.ConnectTimeout, 1)
end

function NetworkManager:ServerOnConnect(errcode)
	Log.DebugFormat("[GameLoop-LifeTimeStage]NetworkManager:ServerOnConnect errcode:%s ", errcode)
    Game.GameLoopManagerV2:ServerOnConnect(errcode)
    if errcode == 0 then
        self:ClearAllEntity()
        Game:OnNetConnected()
    end
end

function NetworkManager:ServerAccountGetControl()
	Log.Debug("[GameLoop-LifeTimeStage]NetworkManager:ServerAccountGetControl ")
    Game.NetworkManager:ReqLogin()
    if self.connectTimeoutTimer then
        Game.TimerManager:StopTimerAndKill(self.connectTimeoutTimer)
        self.connectTimeoutTimer = nil
    end
    if _G.UseKCP then
        self.tryKCPNumber = 0
    end
end

--请求登录
function NetworkManager:ReqLogin()
    local loginData = Game.LoginSystem.model.serverLoginData
    Log.DebugFormat("[GameLoop-LifeTimeStage] NetworkManager:ReqLogin Username:%s  Password:%s  GameId:%s  GameToken:%s  ClientVersion:%s", 
            loginData.Username, loginData.Password,loginData.GameId, loginData.GameToken ,loginData.ClientVersion)

    self:SetUserInfo(loginData.Username, loginData.Password)

    -- for PerfSight
    import("PerfSightHelper").SetUserId(loginData.Username)
    -- for PerfSight
    local Account = Game.NetworkManager.GetAccountEntity()
    local sdkData = Game.AllInSdkManager.SdkData
    local pakUpdateSubSystem = import("SubsystemBlueprintLibrary").GetEngineSubsystem(import("PakUpdateSubsystem"))
    local patchP4Version = UE_EDITOR and 0 or pakUpdateSubSystem:GetLocalP4Version()
    Account:ReqLogin(loginData.Username, loginData.Password, loginData.ClientVersion,loginData.GameId,
            loginData.GameToken, PlatformUtil.GetPlatformName(), loginData.ServerId,sdkData.Channel,sdkData.MarketChannel,
            sdkData.DeviceId,sdkData.Location.countryRegionCode,sdkData.Location.country,sdkData.Location.province,sdkData.Location.city,patchP4Version)
end

function NetworkManager:SetUserInfo(uname, pwd)
    self.username = uname
    self.password = pwd
end

function NetworkManager:SetProcessName(processName)
    self.RetLoginData.processName = processName
end

----游戏客户端停止的操作，会清除掉所有Entity，并disconnect掉客户端的连接
function NetworkManager:Stop(retainEntity, notRefresh)
	Log.Debug("[GameLoop-LifeTimeStage]NetworkManager:Stop ")
    if self.client then
        self.client:stop(retainEntity, notRefresh)
        if not retainEntity and Game.me then  --停止时主动清理下MainPlayer,避免编辑器崩溃
            self.SetLocalAvatarActor(nil)
        end
    end
end

--清理所有的Entity
function NetworkManager:ClearAllEntity()
	Log.Debug("[GameLoop-LifeTimeStage]NetworkManager:ClearAllEntity ")
    if self.client then
        self.client:ClearAllEntity()
    end
end

--关闭与服务器的连接
function NetworkManager:Disconnect()
	Log.Debug("[GameLoop-LifeTimeStage]NetworkManager:Disconnect ")
    if self.client then
        self.client:disconnect()
    end
end


function NetworkManager.GetErrCodeName(ErrCode)
    local Row = Game.TableData.GetErrCodeDataRow(ErrCode)
    if Row then
        return Row.ErrCode
    else
        return "Err Name not found: " .. tostring(ErrCode)
    end
end

function NetworkManager.GetErrCodeDesc(ErrCode)
    local Row = Game.TableData.GetErrCodeDataRow(ErrCode)
    if Row then
        return Row.ErrCodeDesc
    else
        return "Err Desc not found: " .. tostring(ErrCode)
    end
end

function NetworkManager.GetErrCodeReminderDesc(ErrCode)
    local Row = Game.TableData.GetErrCodeDataRow(ErrCode)
    if Row then
        return Row.ReminderDesc
    else
        return "Err ReminderDesc not found: " .. tostring(ErrCode)
    end
end

function NetworkManager.GetErrCodeReminderID(ErrCode)
    local Row = Game.TableData.GetErrCodeDataRow(ErrCode)
    if Row then
        return Row.ReminderID
    else
        return nil
    end
end

function NetworkManager:ServerOnLogin(result, uid, roles, serverVersion, clientVersion, minVersion, maxVersion, lastLoginRoleId, processName, bEnterGame, creatingRoleInfo)
    self.RetLoginData = {result=result, uid=uid, roles=roles, serverVersion=serverVersion, 
                        clientVersion=clientVersion, minVersion=minVersion, maxVersion=maxVersion, 
                        lastLoginRoleId=lastLoginRoleId, processName=processName, creatingRoleInfo = creatingRoleInfo}

	Log.Debug("[GameLoop-LifeTimeStage]NetworkManager:ServerOnLogin ")
    Game.GameLoopManagerV2:ServerOnLogin(result, uid, roles, serverVersion,
        clientVersion, minVersion, maxVersion, lastLoginRoleId, processName, bEnterGame, creatingRoleInfo)
end

function NetworkManager.SetAccountEntity(entity)
    NetworkManager.AccountEntity = entity
	if entity then
		Game.LoginSystem:SetAccountID(entity.eid)
	end
end

function NetworkManager.GetAccountEntity()
    return NetworkManager.AccountEntity
end

function NetworkManager.GetLocalAvatarActor()
    return NetworkManager.LocalAvatarActor
end

---SetLocalAvatarActor
---@param actor MainPlayer|nil 
---@param bDestroy boolean 是否销毁上一个MainPlayer(默认为true)
function NetworkManager.SetLocalAvatarActor(actor, bDestroy)
    bDestroy = bDestroy == nil and true or bDestroy
	local info = debug.getinfo(2, "Sl")
	Log.Debug("[LocalAvatarActor]SetLocalAvatarActor",actor, info.source ..":" .. tostring(info.currentline))
    if (actor or bDestroy) and Game.me then
        if actor and (not Game.me.disconnectRetain or Game.me.eid == actor.eid) then
            Log.Error(string.format("SetLocalAvatarActor LocalAvatarActor Exist. EntityID:%s", Game.me.eid))
        end
        Game.me:destroy()
    end
    NetworkManager.LocalAvatarActor = actor
    ---@type AvatarActor
    Game.me = actor
    SystemSenderBase.MainPlayer = actor
end

-- @todo: c7 fix start
-- by zhangyoujun

function NetworkManager.GetLocalSpace()
    return NetworkManager.LocalSpace
end

function NetworkManager.SetLocalSpace(Space)
    NetworkManager.LocalSpace = Space
end

-- @todo: c7 fix end

function NetworkManager.GetLocalAvatar()
    return NetworkManager.LocalAvatar
end

function NetworkManager.SetLocalAvatar(avatar)
    NetworkManager.LocalAvatar = avatar
end

function NetworkManager.ShowNetWorkResultReminder(RPCName,Result)
    if Result~= nil and type(Result) == "table" and Result.Code then
        if Result.Code ~= Enum.EErrCodeData.NO_ERR then
            local ErrCodeName = NetworkManager.GetErrCodeName(Result.Code)
            local ErrCodeDesc = NetworkManager.GetErrCodeDesc(Result.Code)
            Log.Debug(string.format("RPC %s Error: Code %s - %s" ,tostring(RPCName), tostring(ErrCodeName), tostring(ErrCodeDesc)))
            if _G.IsStringNullOrEmpty(Result.Trace) then
                Log.Debug(string.format("TracInfo : %s)" ,tostring(Result.Trace)))
            end
            local ReminderID =  NetworkManager.GetErrCodeReminderID(Result.Code)
            if ReminderID and ReminderID > 0 then
                Game.ReminderManager:AddTextReminderByConfig(ReminderID, {{}})
            end
            local ReminderDesc = NetworkManager.GetErrCodeReminderDesc(Result.Code)
            if not _G.IsStringNullOrEmpty(ReminderDesc) then
                Game.ReminderManager:OnNetErrorCode(Result.Code,ReminderDesc)
            end
        end
    end
end

function NetworkManager.HandleRequestRet(RPCName, Result,...)
    xpcall(NetworkManager.ShowNetWorkResultReminder,_G.CallBackError,RPCName,Result)
end

--这个方法是Promise的用法，不应该调用这个，先在方法内部处理下，后续调用这个方法的地方应该全部改成self.remote.ReqXXX
function NetworkManager.HandleRequest(RPCName, RPCFunc, DebugInfo)
    RPCFunc(1)
end

function NetworkManager:StopSendRemote()
    local avatarEntity = self.GetLocalAvatarActor()
    if avatarEntity then --断线的时候重置下发消息接口，避免报错“xxx has no router to get mailbox”
        avatarEntity:CreateDummyRemoteProxy()
    end
end

return NetworkManager
