require(LuaCommonPrefix .. "TableData.CacheDict")

--- 表格数据，对接c#层表格管理类，并缓存表数据
---@class TableData
---@field tableName string 缓存下table name，方便后续debug
---@field maxCacheSize number
---@field data CacheDict|table hasLoaded -> table; else -> CacheDict
---@field attrs table<string, table> 自定义的数据
---@field hasLoaded boolean 是否全部加载
---@field refCount number 引用计数
---@field hasHotfix boolean 是否被热更过
---@field hotfixData table<table, table> 热更的表数据
---@field hotfixAttrs table<string, table> 热更的属性数据
DefineClass("TableData")

function TableData:ctor(tableName, maxCacheSize)
    self.tableName = tableName
    self.maxCacheSize = maxCacheSize or 0
    self.data = self:createCacheDict()
    self.attrs = {}
    self.hasLoaded = false
    self.refCount = 0
    self.hasHotfix = false
    self.hotfixData = {}
    self.hotfixAttrs = {}
end

function TableData:dtor()
    self:ReleaseCache()
    self.tableName = nil
    if self.data.delete then
        self.data:delete()
    end
    self.data = nil
    self.attrs = nil
    self.hotfixData = nil
    self.hotfixAttrs = nil
    self.hasHotfix = false
end

--region 访问接口
--- 获取全部data数据，会全部解压，非必要不要使用
function TableData:GetData()
    if not self.hasLoaded then
        self.hasLoaded = true
        self.data = Game.CsharpTableDataProxy:GetLuaData(self.tableName)
        self.attrs = Game.CsharpTableDataProxy:GetLuaAttrs(self.tableName)
        -- 优先访问hotfixData 和 hotfixAttrs
        for k, v in pairs(self.hotfixData) do
            self.data[k] = v
        end
        for k, v in pairs(self.hotfixAttrs) do
            self.attrs[k] = v
        end
        -- lua层拿到所有数据后，释放csharp的数据
        self:releaseCSharpData()
    end
    
    return self.data
end

--- 获取data的某行数据
function TableData:GetRow(key)
    if self.hotfixData[key] ~= nil then
        return self.hotfixData[key]
    end
    if self.hasLoaded then
        return self.data[key]
    end

    return self.data:GetOrCreate(key)
end

--- 获取attrs的某个属性
function TableData:GetAttr(key)
    if self.hotfixAttrs[key] ~= nil then
        return self.hotfixAttrs[key]
    end
    if self.attrs[key] ~= nil then
        return self.attrs[key]
    end
    if self.hasLoaded then
        return
    end
    self.attrs[key] = Game.CsharpTableDataProxy:GetLuaAttrByKey(self.tableName, key)
    return self.attrs[key]
end
--endregion

--- 清空缓存数据，data manager调用，逻辑层不要调用
function TableData:ReleaseCache()
    self:releaseCSharpData()
    if self.hasLoaded then
        self.data = self:createCacheDict()
    else
        self.data:ReleaseAll()
    end
    self.hasLoaded = false
    self.attrs = {}
end

--- 释放引用计数，data manager调用，逻辑层不要调用
function TableData:ReleaseRef()
    self.refCount = self.refCount - 1
end

function TableData:OnRef()
    self.refCount = self.refCount + 1
end

function TableData:HasRef()
    return self.refCount > 0
end

---判断是否可以remove table data
function TableData:CanRemove()
    return not self.hasHotfix and not self:HasRef()
end

--region hotfix, 注意，只可以增改，不可以删除
function TableData:HotfixRow(key, value)
    self.hasHotfix = true
    self.hotfixData[key] = value
    if self.hasLoaded then
        self.data[key] = value -- 处理已经loaded的情况
    end
end

function TableData:HotfixAttr(key, value)
    self.hasHotfix = true
    self.hotfixAttrs[key] = value
    self.attrs[key] = value  -- 处理已经loaded的情况
end
--endregion

function TableData:getCSharpRowData(key)
    return Game.CsharpTableDataProxy:GetLuaDataByKey(self.tableName, key)
end

function TableData:releaseCSharpData()
    Game.CsharpTableDataProxy:ReleaseTableCache(self.tableName)
end

function TableData:createCacheDict()
    return CacheDict.new(self.maxCacheSize,
            function(key) return self:getCSharpRowData(key) end
    )
end

return TableData
