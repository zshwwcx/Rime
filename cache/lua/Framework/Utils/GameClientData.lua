---@class GameClientData:ManagerBase
local GameClientData = DefineClass("GameClientData", ManagerBase)
local json = require "Framework.Library.json"

GameClientData.dataDirectory = import("LuaFunctionLibrary").ConvertToAbsolutePathForExternalAppForRead(
    import("KismetSystemLibrary").GetProjectSavedDirectory() .. "Documents"
)
GameClientData.dataPath = import("LuaFunctionLibrary").ConvertToAbsolutePathForExternalAppForRead(
    GameClientData.dataDirectory .. "/GameClientData.sav"
)

function GameClientData:ctor()
    self.data = {}
    self.playerData = {}
    self.accountData = {}
    self.dirtyFlag = false
end

function GameClientData:onInit()
    self:LoadData()
end

function GameClientData:onUnInit()
    self:Save()
end


--region 接口
---@public
---全局数据存储
---@param key string
---@param value any
---@param forceSave boolean 是否强制存储到本地
function GameClientData:SaveGlobal(key, value, forceSave)
    assert(type(key) == "string")
    self.dirtyFlag = true
    if key then self.data[key] = value end
    if forceSave then self:Save() end
end

---@public
---按eid存储数据
---@param key string
---@param value any
---@param forceSave boolean 是否强制存储到本地
function GameClientData:SaveByPlayer(key, value, forceSave)
    assert(type(key) == "string")
    local eid = Game.me.eid
    if not eid then
        return
    end
    self.dirtyFlag = true
    if eid and key then
        self.playerData[eid] = self.playerData[eid] or {}
        self.playerData[eid][key] = value
    end
    if forceSave then self:Save() end
end

---@public
---按account存储数据
---@param key string
---@param value any
---@param forceSave boolean 是否强制存储到本地
function GameClientData:SaveByAccount(key, value, forceSave)
    
    assert(type(key) == "string")
    local accountTag = self:GetAccountTag()
    if accountTag and key then
        self.dirtyFlag = true
        self.accountData[accountTag] = self.accountData[accountTag] or {}
        self.accountData[accountTag][key] = value
    end
    if forceSave then self:Save() end
end

---@public
---获取全局数据
---@param key string
function GameClientData:GetGlobalValue(key)
    return self.data[key]
end

---@public
---根据eid获取数据
---@param key string
function GameClientData:GetPlayerValue(key)
    local eid = Game.me.eid
    if not eid then
        return
    end
    if self.playerData[eid] then
        return self.playerData[eid][key]
    end
    return nil
end

---@public
---根据账户获取数据
---@param key string
function GameClientData:GetAccountValue(key)
    local accountTag = self:GetAccountTag()
    if not accountTag then
        return
    end
    if self.accountData[accountTag] then
        return self.accountData[accountTag][key]
    end
    return nil
end

---@public
---强制存储
function GameClientData:Save()
    if self.dirtyFlag then
        self.dirtyFlag = false
        self:SaveData()
    end
end

--endregion

function GameClientData:LoadData()
    self.data = {}
    self.playerData = {}
    self.accountData = {}
    local file = io.open(GameClientData.dataPath, "r")
    if file ~= nil then
        local contents = file:read("*all")
        file:close()
        local data = json.decode(contents)
        self.data = data.global or {}
        self.playerData = data.player or {}
        self.accountData = data.account or {}
    end
end

function GameClientData:SaveData()
    local directoryExist = import("LuaFunctionLibrary").DirectoryExists(GameClientData.dataDirectory)
    if not directoryExist then
        directoryExist = import("LuaFunctionLibrary").MakeDirectory(GameClientData.dataDirectory, false)
    end
    if not directoryExist then
        return
    end
    local file = io.open(GameClientData.dataPath, "w")
    if file ~= nil then
        local result = xpcall(file.write, _G.CallBackError, file, json.encode({global = self.data, player = self.playerData, account = self.accountData}))
		if not result then
			Log.Dump(self.data)
			Log.Dump(self.playerData)
			Log.Dump(self.accountData)
		end
        file:close()
    end
end

function GameClientData:GetAccountTag()
    local serverLoginData = Game.LoginSystem.model and Game.LoginSystem.model.serverLoginData or {}
    local accountTag
    if serverLoginData.Username and #serverLoginData.Username > 0 then
        accountTag = serverLoginData.Username
    elseif serverLoginData.GameId and #serverLoginData.GameId > 0 then
        accountTag = serverLoginData.GameId
    end
    return accountTag
end

return GameClientData