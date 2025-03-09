
local __pubkey = [[
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDBbU2iGlLMO63+m06hpEgdiXiz
/YuEdbJ0cao5wW+pvy9Tjh1/W1lqWHsMy87hrKdIDOPNSs8yJlMyal3NI2QiG3yr
wA4emt3ZzfKcAb+6Y9EiPousRo/eGg8rOtYcN2ADfad3QH8VusC0JelWjcYfK1Kk
EXmMgR1/9rxLWeFedwIDAQAB
-----END PUBLIC KEY-----
]]


DefineClass("SdkCallbackHandler")
function SdkCallbackHandler.create_entity(_, entId, ent, is_player, is_brief)
    Log.DebugFormat("[AOIEntity-LifeTimeStage] create_entity Entity:%s, Uid:%s cname:%s isPlayer: %s, is_brief:%s", entId, ent:uid(), ent.__cname, is_player, is_brief)
    Game.EntityManager:AddEntity(ent, is_brief)
    ent:OnCreate()

    if ent.LoadActor then
        ent:LoadActor()
        local eid = ent.eid
        Game.EventSystem:Publish(_G.EEventTypes.NET_ON_ENTITY_CREATE, eid)
    end
end

function SdkCallbackHandler.destroy_entity(entId, intID, entType, is_brief)
    --todo后续支持之后，从EntityBase中移过来
    --Game.EntityManager:RemoveEntity(self)
end

function SdkCallbackHandler.unpack_entity_failed(_, className, entityID, is_player, is_brief)
    if className == "MainPlayer" then
        Game.EventSystem:Publish(_G.EEventTypes.GAME_MAINPLAYER_ENTITY_CREATE_FAILED)
    end
end

function SdkCallbackHandler.on_entity_to_brief_entity(_, oldEnt, newEnt)
    Log.DebugFormat(
        "[AOIEntity-LifeTimeStage] on_entity_to_brief_entity oldEnt_eid:%s, oldEnt_Uid:%s old_cname:%s newEnt_eid:%s, newEnt_uid:%s, new_cname:%s", 
        oldEnt.eid, oldEnt:uid(), oldEnt.__cname, newEnt.eid, newEnt:uid(), newEnt.__cname)
    
    local entity_type = oldEnt.ENTITY_TYPE

    if newEnt.On_Entity_To_Brief then
        newEnt:On_Entity_To_Brief(oldEnt)
    end

    local oldEntCls = Game.EntityManager:getEntityCls(entity_type, false)
    CallEntityDtorFunc(oldEnt, oldEntCls)
    local newEntCls = Game.EntityManager:getEntityCls(entity_type, true)
    CallEntityCtorFunc(newEnt, newEntCls)
    Game.EntityManager:AddEntity(newEnt, true)
    newEnt:OnCreate()

    if newEnt.LoadActor then
        newEnt:LoadActor()
    end

    Game.EventSystem:Publish(_G.EEventTypes.NET_ON_ENTITY_CREATE, newEnt.eid)
end

function SdkCallbackHandler.on_brief_entity_to_entity(_, oldEnt, newEnt)
    Log.DebugFormat(
        "[AOIEntity-LifeTimeStage] on_brief_entity_to_entity oldEnt_eid:%s, oldEnt_Uid:%s oldEnt_cname:%s  newEnt_eid:%s, newEnt_uid:%s  newEnt_cname:%s", 
        oldEnt.eid, oldEnt:uid(), oldEnt.__cname,  newEnt.eid, newEnt:uid(), newEnt.__cname)
    local entity_type = oldEnt.ENTITY_TYPE

    if newEnt.On_Brief_To_Entity then
        newEnt:On_Brief_To_Entity(oldEnt)
    end

    local oldEntCls = Game.EntityManager:getEntityCls(entity_type, true)
    CallEntityDtorFunc(oldEnt, oldEntCls)
    local newEntCls = Game.EntityManager:getEntityCls(entity_type, false)
    CallEntityCtorFunc(newEnt, newEntCls)
    Game.EntityManager:AddEntity(newEnt, false)
    newEnt:OnCreate()

    if newEnt.LoadActor then
        newEnt:LoadActor()
    end

    Game.EventSystem:Publish(_G.EEventTypes.NET_ON_ENTITY_CREATE, newEnt.eid)
end

Game.GameSDK:setObject(SdkCallbackHandler.new())
Game.GameSDK:enableAsGlobal()

---@class C7Client
C7Client = DefineClass("C7Client")
function C7Client:ctor()
    Log.Debug("[ReqLogin]C7Client:ctor")
    self:refresh_connection()
end

function C7Client:dtor()
    Log.Debug("[ReqLogin]C7Client:dtor")
    if self.connection then
        self.connection:set_callback(nil)
    end
    self.connection = nil
end

function C7Client:refresh_connection()
    self.connection = Game.GameSDK:newRouter()
    self.connection:set_callback(self)
end

function C7Client:set_handshake_key()
    Log.Debug("[ReqLogin]C7Client:set_handshake_key")
    self.connection:set_handshake_key(__pubkey)
end

--请求连接Router
function C7Client:connect(ip, port)
    local protocol = "kcp"
    if not UseKCP then
        protocol = "tcp"
    end
    self.connection:connect(ip, port, protocol)
end

--请求断开连接
function C7Client:disconnect()
    Log.Debug("[ReqLogin]C7Client:disconnect")
    self.connection:disconnect()
end

---stop 游戏客户端停止的操作，disconnect掉客户端的连接
---@param retainEntity boolean 是否保留Entity
function C7Client:stop(retainEntity, notRefresh)
    Log.Debug("[ReqLogin]C7Client:stop")
    if not retainEntity then
        self:ClearAllEntity()
    end
    self.connection:set_callback(nil)
    self.connection:stop()
    if not notRefresh then
        self:refresh_connection()
    end
end

--清理所有的Entity
function C7Client:ClearAllEntity()
    Log.Debug("[ReqLogin]C7Client:ClearAllEntity")
    if Game.me then
        Game.me.disconnectRetain = true
    end
    Game.EntityManager:clear()
end

--已连接到服务器(errcode == 0)
function C7Client:on_connect(errcode)
    Log.Debug("[ReqLogin]on_connect", self, errcode)
    Game.NetworkManager:ServerOnConnect(errcode)
end

--SDK主动断开连接
function C7Client:on_disconnect()
    Log.Debug("[ReqLogin]on_disconnect", self)
    Game.GameLoopManagerV2:ServeOnDisconnect()
end

--客户端端与服务器连接，连接成功之后，Account已经创建之后的回调；
--参数:errcode，只有在加密加密相关验证失败的情况下值是-1，其他都是成功值是0
function C7Client:on_handshake(errcode)
    Log.Debug("[ReqLogin]on_handshake", self, errcode)
    --实际的请求登录
    self.connection:login("C7Login")
end

------------------------------ Hotfix Start ------------------------------
function C7Client:client_hotfix(versionInfo, hotfixInfos)
    local cmsgUnpack = _script.cmsgpack.unpack
    hotfixInfos = cmsgUnpack(hotfixInfos)
    Game.HotfixUtils.doHotfix(hotfixInfos)
    versionInfo = cmsgUnpack(versionInfo)
    Log.InfoFormat("hotfix version server:%s client:%s", versionInfo[1], versionInfo[2])
end

------------------------------ Hotfix End ------------------------------

--[[
    世界拍卖信息通知(拍卖开启时广播给所有玩家时推送通知)
    beginTime           拍卖开始时间
    prepareEndTime      拍卖准备阶段结束时间
    bidingEndTime       拍卖持续阶段结束时间
    buttonDisappearTime 拍卖按钮消失时间
--]]
function C7Client:OnMsgWorldBidInfoNotice(beginTime, prepareEndTime, bidingEndTime, buttonDisappearTime,
                                          totalDisappearTime)
    print("===============OnMsgWorldBidInfoNotice beginTime, prepareEndTime, bidingEndTime, buttonDisappearTime:",
        beginTime, prepareEndTime, bidingEndTime, buttonDisappearTime, totalDisappearTime)

    if Game.me then
        Game.me:OnMsgWorldBidInfoNotice(beginTime, prepareEndTime, bidingEndTime, buttonDisappearTime, totalDisappearTime)
    end
end

--[[
    世界拍卖道具数据更新 增量同步
    引擎走链接广播，目前只能挂在C7Client下，在转发到当前链接的客户端
--]]
function C7Client:OnMsgUpdateWorldBidItemInfo(bidItemSimpleInfo)
    if Game.me then
        Game.me:OnMsgUpdateWorldBidItemInfo(bidItemSimpleInfo)
    end
end


--[[
    公会晚间活动
--]]
function C7Client:onReceiveGuildNightInvitation()
    Game.GuildSystem.sender:onReceiveGuildNightInvitation()
end

--[[
    职业聊天
--]]
function C7Client:OnMsgChannelChat(clientMethodName, chatInfo)
    if Game.me then
        Game.me[clientMethodName](Game.me, chatInfo)
    end
end

--[[
    匿名消息揭露同步
--]]
function C7Client:OnMsgChatExposeUpdate(chatExposeInfo,userID,userRealName)
    if Game.me then
        Game.me:OnMsgChatExposeUpdate(chatExposeInfo,userID,userRealName)
    end
end

--[[
    隐秘状态同步
--]]
function C7Client:OnMsgChatUserStartShield(eid,time)
    if Game.me then
        Game.me:OnMsgChatUserStartShield(eid,time)
    end
end



--[[
    跑马灯
--]]
function C7Client:onMsgReceiveMarquee(marqueeID, endTime, content, curIndex)
    if Game.me then
        Game.me:onMsgReceiveMarquee(marqueeID, endTime, content, curIndex)
    end
end


--[[
    Reminder
]]
function C7Client:OnMsgGenReminder(ID, ParamList)
    if Game.me then
        Game.me:OnMsgGenReminder(ID,ParamList)
    end
end

--[[
    清除本地下载好的图片
]]
function C7Client:OnClearPictureCache(resID)
    if Game.me then
        Game.me:OnClearPictureCache(resID)
    end
end


return C7Client
