--- lua层表格数据，直接从lua文件中加载，并缓存数据
---@class LuaTableData : TableData
---@field tableName string 缓存下table name，方便后续debug
---@field dataPrefix string lua数据的存储目录
---@field data table<table, table> 原始表数据
---@field attrs table<string, table> 自定义的数据
---@field hasLoaded boolean 是否全部加载
---@field hasHotfix boolean 是否被热更过
---@field hotfixData table<table, table> 热更的表数据
---@field hotfixAttrs table<string, table> 热更的属性数据
DefineClass("LuaTableData", TableData)

function LuaTableData:ctor(tableName, dataPrefix)
    self.dataPrefix = dataPrefix or "OriginLuaTableData."
end

function LuaTableData:dtor()
end

--region read
--- 获取全部data数据，会全部解压，非必要不要使用
function LuaTableData:GetData()
    if not self.hasLoaded then
        self:loadData()

        -- 优先访问hotfixData 和 hotfixAttrs
        for k, v in pairs(self.hotfixData) do
            self.data[k] = v
        end
        for k, v in pairs(self.hotfixAttrs) do
            self.attrs[k] = v
        end
    end
    
    return self.data
end

--- 获取data的某行数据
function LuaTableData:GetRow(key)
    if self.hotfixData[key] ~= nil then
        return self.hotfixData[key]
    end
    if self.hasLoaded then
        return self.data[key]
    end
    
    self:loadData()
    return self.data[key]
end

--- 获取attrs的某个属性
function LuaTableData:GetAttr(key)
    if self.hotfixAttrs[key] ~= nil then
        return self.hotfixAttrs[key]
    end
    if self.hasLoaded then
        return self.attrs[key]
    end

    self:loadData()
    return self.attrs[key]
end
--endregion

--- 清空缓存数据
function LuaTableData:ReleaseCache()
    self.hasLoaded = false
    self.data = {}
    self.attrs = {}
end

local dataModuleEnv = setmetatable({}, {__index = _G})
function LuaTableData:loadData()
    if self.hasLoaded then
        return
    end
    
    self.hasLoaded = true
    local tablePath = self.dataPrefix .. self.tableName
    local langTableName = self.tableName .. "_EN"  -- todo 根据当前语言配置加载
    if Game.TableDataManager:CheckHasLangConfig(langTableName) == true then
        tablePath = self.dataPrefix .. langTableName
    end

    local luaData
    if UE_EDITOR then
        -- 临时方案，清理package.loaded 没用，因为unlua中自己缓存了一份
        -- TODO: 后续切换成Slua有更加完善的热更新方案，需要进行替换
        luaData = loadfile2(tablePath, dataModuleEnv)()
    else
        luaData = require(tablePath)
    end

    self.data = luaData["data"]
    for k, v in pairs(luaData) do
        if k ~= "data" then
            self.attrs[k] = v
        end
    end
end

return LuaTableData
