require(LuaCommonPrefix .. "TableData.CacheDict")

--- 表格数据，对接c#层表格管理类，并缓存表数据
---@class CTableData
---@field tableName string 缓存下table name，方便后续debug
---@field maxCacheSize number
---@field data CacheDict|table hasLoaded -> table; else -> CacheDict
---@field attrs table<string, table> 自定义的数据
---@field hasLoaded boolean 是否全部加载
---@field refCount number 引用计数
---@field hasHotfix boolean 是否被热更过
---@field hotfixData table<table, table> 热更的表数据
---@field hotfixAttrs table<string, table> 热更的属性数据
---@field tableIndex number 数据表在c table data manager的slot index
DefineClass("CTableData")

function CTableData:ctor(tableName, maxCacheSize)
    self.tableName = tableName
    self.maxCacheSize = maxCacheSize or 0
    self.data = self:createCacheDict()
    self.attrs = {}
    self.hasLoaded = false
    self.refCount = 0
    self.hasHotfix = false
    self.hotfixData = {}
    self.hotfixAttrs = {}
    self.tableIndex = -1  -- valid value > 0
    -- todo 后期正式使用c table data后，再将这部分代码移到外面去
    if Game.CTableDataProxy == nil then
        local cTableDataManager = require("CTableDataManager")
        Game.CTableDataProxy = cTableDataManager.new(10)
    end
end

function CTableData:dtor()
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
    self.tableIndex = -1
end

--region 访问接口
--- 获取全部data数据，会全部解压，非必要不要使用
function CTableData:GetData()
    if not self.hasLoaded then
        self.hasLoaded = true
        self.attrs = Game.CTableDataProxy:getAttrs(self:getTableIndex())
        self.data = Game.CTableDataProxy:getData(self:getTableIndex())
        -- 优先访问hotfixData 和 hotfixAttrs
        for k, v in pairs(self.hotfixData) do
            self.data[k] = v
        end
        for k, v in pairs(self.hotfixAttrs) do
            self.attrs[k] = v
        end
        -- lua层拿到所有数据后，释放csharp的数据
        self:releaseCData()
    end
    
    return self.data
end

--- 获取data的某行数据
function CTableData:GetRow(key)
    if self.hotfixData[key] ~= nil then
        return self.hotfixData[key]
    end
    if self.hasLoaded then
        return self.data[key]
    end

    return self.data:GetOrCreate(key)
end

--- 获取attrs的某个属性
function CTableData:GetAttr(key)
    if self.hotfixAttrs[key] ~= nil then
        return self.hotfixAttrs[key]
    end
    if self.attrs[key] ~= nil then
        return self.attrs[key]
    end
    if self.hasLoaded then
        return
    end
    self.attrs[key] = Game.CTableDataProxy:getAttrByName(self:getTableIndex(), key)
    return self.attrs[key]
end
--endregion

--- 清空缓存数据，data manager调用，逻辑层不要调用
function CTableData:ReleaseCache()
    self:releaseCData()
    if self.hasLoaded then
        self.data = self:createCacheDict()
    else
        self.data:ReleaseAll()
    end
    self.hasLoaded = false
    self.attrs = {}
end

--- 释放引用计数，data manager调用，逻辑层不要调用
function CTableData:ReleaseRef()
    self.refCount = self.refCount - 1
end

function CTableData:OnRef()
    self.refCount = self.refCount + 1
end

function CTableData:HasRef()
    return self.refCount > 0
end

---判断是否可以remove table data
function CTableData:CanRemove()
    return not self.hasHotfix and not self:HasRef()
end

--region hotfix, 注意，只可以增改，不可以删除
function CTableData:HotfixRow(key, value)
    self.hasHotfix = true
    self.hotfixData[key] = value
    if self.hasLoaded then
        self.data[key] = value -- 处理已经loaded的情况
    end
end

function CTableData:HotfixAttr(key, value)
    self.hasHotfix = true
    self.hotfixAttrs[key] = value
    self.attrs[key] = value  -- 处理已经loaded的情况
end
--endregion

function CTableData:getCRowData(key)
    return Game.CTableDataProxy:getDataByKey(self:getTableIndex(), key)
end

function CTableData:releaseCData()
    Game.CTableDataProxy:releaseTableData(self:getTableIndex())
    self.tableIndex = -1
end

function CTableData:createCacheDict()
    return CacheDict.new(self.maxCacheSize,
            function(key) return self:getCRowData(key) end
    )
end

function CTableData:getTableIndex()
    if self.tableIndex >= 0 then
        return self.tableIndex
    end
    -- init table index
    local langTableName = self.tableName .. "_EN" -- todo 根据语言配置识别
    local buffer = ""
    if self.tableName ~= "LangConfigDB" and Game.TableDataManager:CheckHasLangConfig(langTableName) == true then
        buffer = Game.CsharpTableDataProxy:ReadFile(langTableName)
    else
        buffer = Game.CsharpTableDataProxy:ReadFile(self.tableName)
    end
    self.tableIndex = Game.CTableDataProxy:addTableData(self.tableName, buffer, #buffer)
    return self.tableIndex
end

return CTableData
