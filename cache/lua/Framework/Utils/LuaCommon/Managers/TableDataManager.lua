require(LuaCommonPrefix .. "TableData.CacheDict")
local TableData = require(LuaCommonPrefix .. "TableData.TableData")
local LuaTableData = require(LuaCommonPrefix .. "TableData.LuaTableData")
local CTableData = require(LuaCommonPrefix .. "TableData.CTableData")


--- 表格管理组件
---@class TableDataManager
---@field tableMap CacheDict string -> TableData instance
TableDataManager = DefineClass("TableDataManager")

-- c7 fix start
-- local TableConfig = {
--     UseOriginLuaTable = false,
--     UseCLuaTable = false,
--     OriginLuaTablePrefix = "OriginLuaTableData.",
--     CacheParam = {
--         TableCacheSize = 100,
--         RowCacheSize = 16,
--     }
-- }
TableDataManager.TableConfig = {
    UseOriginLuaTable = true,
    UseCLuaTable = false,
    OriginLuaTablePrefix = "Data.Excel.",
    CacheParam = {
        TableCacheSize = 100,
        RowCacheSize = 16,
    }
}
-- c7 fix end

function TableDataManager:ctor()
    -- table name to table data instance
    local TableConfig = TableDataManager.TableConfig
    self.tableMap = CacheDict.new(TableConfig.CacheParam.TableCacheSize, 
        function(tableName) return self:createTableInstance(tableName) end,
        function(tableName) self:impReleaseTable(tableName)  end
    )
    if TableConfig.UseOriginLuaTable or TableConfig.UseCLuaTable then
        self.langConfigDB = Set.new()
        self:loadLangConfigDB()
    end
end

function TableDataManager:dtor()
    self.tableMap:delete()
    self.tableMap = nil
    if self.langConfigDB then
        self.langConfigDB:Clear()
        self.langConfigDB = nil
    end
end

---获取data，会在lua层创建一个data整表的缓存，如非必须，谨慎使用
---@param priority number|nil 
function TableDataManager:GetData(tableName, priority)
    -- c7 fix start by zhangyoujun  Get表格偶现报错
    if priority then
        assert(type(priority) == "number")
    end
    -- c7 fix end by zhangyoujun  Get表格偶现报错
    local instance = self:getTableInstance(tableName, priority)
    return instance:GetData()
end

---获取data的某行数据，会在lua层创建一行数据的缓存
---@param priority number|nil
function TableDataManager:GetRow(tableName, key, priority)
    -- c7 fix start by zhangyoujun  Get表格偶现报错
    if priority then
        assert(type(priority) == "number")
    end
    -- c7 fix end by zhangyoujun  Get表格偶现报错
    local instance = self:getTableInstance(tableName, priority)
    return instance:GetRow(key)
end

---获取某个自定义的属性，会在lua层创建对应属性的缓存
function TableDataManager:GetAttr(tableName, key)
    local instance = self:getTableInstance(tableName)
    return instance:GetAttr(key)
end

---手动释放缓存的数据，持有table instance的话，需要调用ReleaseTableInstance方法
---@param tableName string 表格名称
function TableDataManager:ReleaseTableData(tableName)
    self.tableMap:Release(tableName)
end

---手动释放所有缓存资源
function TableDataManager:ReleaseAllTableData()
    self:Broadcast("PreReleaseAllTableData")
    self.tableMap:ReleaseAll()
    self:Broadcast("PostReleaseAllTableData")
end

---按照LRU原则，释放指定数量table对应的资源
---@param releaseNum number 希望释放的表格数量
function TableDataManager:ReleaseLRUTableData(releaseNum)
    self.tableMap:ReleaseLRU(releaseNum)
end

--region 访问table instance, 以下两个方法需配对使用
---获取某个表
---@param priority number|nil 优先级
---@return TableData
function TableDataManager:GetTableInstance(tableName, priority)
    -- c7 fix start by zhangyoujun  Get表格偶现报错
    if priority then
        assert(type(priority) == "number")
    end
    -- c7 fix end by zhangyoujun  Get表格偶现报错
    local tableInstance = self:getTableInstance(tableName, priority)
    tableInstance:OnRef()
    return tableInstance
end

---释放某个table instance的引用计数
---@param instance TableData
function TableDataManager:ReleaseTableInstance(instance)
    instance:ReleaseRef()
    if not instance:HasRef() then
        self:ReleaseTableData(instance.tableName)
    end
end
--endregion

--region 字符串常数表
function TableDataManager:GetConstStr(index)
    return self:GetRow("LanguageData.ConstStringData", index).value
end
--endregion

--region 多语言

-- C7 CODE START BY shijingzhe@kuaishou.com: 接入中台新的多语言导表

---查询id对应的语言字符串值
function TableDataManager:GetLangStr(index)
    index = self:GetRow(self:GetKeyMapTableName(), index, 1)
    return self:GetRow(self:GetLangTableName(), index, 1)
end

function TableDataManager:GetLangTableName()
    local langTableName = "LanguageData.StringDB_" .. self:GetLangType() .. "_Data"
    return langTableName
end

function TableDataManager:GetKeyMapTableName()
    local langTableName = "LanguageData.KeyMappingTable_" .. self:GetLangType() .. "_Data"
    return langTableName
end

function TableDataManager:GetLangType()
    -- TODO(): 默认返回中文
    return "CN"
end

-- C7 CODE END BY shijingzhe@kuaishou.com

---切换语言配置
function TableDataManager:OnLangChange(oldLang, newLang)
    self:ReleaseAllTableData()
end

function TableDataManager:CheckHasLangConfig(langModuleName)
    return self.langConfigDB:Contains(langModuleName)
end
--endregion

--region 热更
---热更某行数据
function TableDataManager:HotfixRow(tableName, key, value)
    local instance = self:getTableInstance(tableName)
    return instance:HotfixRow(key, value)
end

---热更某个属性
function TableDataManager:HotfixAttr(tableName, key, value)
    local instance = self:getTableInstance(tableName)
    return instance:HotfixAttr(key, value)
end
--endregion

function TableDataManager:getTableInstance(tableName, priority)
    -- c7 fix start by zhangyoujun  Get表格偶现报错
    if priority then
        assert(type(priority) == "number")
    end
    -- c7 fix end by zhangyoujun  Get表格偶现报错
    return self.tableMap:GetOrCreate(tableName, priority)
end

function TableDataManager:createTableInstance(tableName)
    -- 创建table data instance
    local TableConfig = TableDataManager.TableConfig
    if TableConfig.UseOriginLuaTable then
        return LuaTableData.new(tableName, TableConfig.OriginLuaTablePrefix)
    elseif TableConfig.UseCLuaTable then
        return CTableData.new(tableName, TableConfig.CacheParam.RowCacheSize)
    else
        return TableData.new(tableName, TableConfig.CacheParam.RowCacheSize)
    end
end

function TableDataManager:impReleaseTable(tableName)
    local tableInstance = self.tableMap:RawGet(tableName)
    if tableInstance then
        tableInstance:ReleaseCache()
        if tableInstance:CanRemove() then
            self.tableMap:Remove(tableName)
        end
    end
end

function TableDataManager:getLangTableName(lang)
    local languagePostfix = "CN" -- todo 根据当前语言获取后缀
    local langTableName = "LanguageData.StringDB_" .. languagePostfix .. "_Data"
    return langTableName
end

function TableDataManager:loadLangConfigDB()
    local langConfigDB = {}
    local TableConfig = TableDataManager.TableConfig
    if TableConfig.UseCLuaTable then
        langConfigDB = self:GetData("LangConfigDB")
    else
        langConfigDB = require(TableConfig.OriginLuaTablePrefix .. "LangConfigDB").data
    end
    self.langConfigDB:Update(langConfigDB)
end

-- c7 fix start

function TableDataManager:RegisterListener(listener)
    local listeners = self.listeners
    if not listeners then
        listeners = {
            __keyCounter = 0,
            order = {},
            key2Obj = setmetatable({}, {
                __mode = "v"
            }),
            obj2Key = setmetatable({}, {
                __mode = "k"
            }),

            Contains = function(tbl, observer)
                return tbl.obj2Key[observer] ~= nil
            end,
            
            Add = function(tbl, observer)
                if tbl.obj2Key[observer] then
                    return
                end

                local key = tbl.__keyCounter + 1
                tbl.__keyCounter = key
                tbl.key2Obj[key] = observer
                tbl.obj2Key[observer] = key
                tbl.order[#tbl.order + 1] = key
            end,

            Remove = function(tbl, observer)
                local key = tbl.obj2Key[observer]
                if key then
                    tbl.key2Obj[key] = nil
                    tbl.obj2Key[observer] = nil
                    local index 
                    local order = tbl.order
                    for i = 1, #order do
                        if order[i] == key then
                            index = i
                            break
                        end
                    end

                    if index then
                        table.remove(tbl.order, index)
                    end
                end
            end,

            Broadcast = function(tbl, event, ...)
                local errorHandle = _G.CallBackError
                local insert = table.insert
                local key
                local observer
                local callback
                local order = tbl.order
                local key2Obj = tbl.key2Obj
                local pendingRemove = {}
                for i = 1, #order do
                    key = order[i]
                    observer = key2Obj[key]
                    if observer then
                        callback = observer[event]
                        if callback then
                            xpcall(callback, errorHandle, observer, ...)
                        end
                    else
                        insert(pendingRemove, i)
                    end
                end

                local remove = table.remove
                for i = #pendingRemove, 1, -1 do
                    remove(order, pendingRemove[i])
                end
            end
        }
        self.listeners = listeners
    end

    if not listeners:Contains(listener) then
        listeners:Add(listener)
    end    
end

function TableDataManager:UnregisterListener(observer)
    self.listeners:Remove(observer)
end

function TableDataManager:Broadcast(event, ...)
    local listeners = self.listeners
    if listeners then
        listeners:Broadcast(event, ...)
    end
end

---@public
function TableDataManager:HotfixKsbcData(t, key, value)
    if not _G.bUseKsbc then
        return
    end

    if not isKsbcTable(t) then
        Log.Error("[HotfixKsbcData] not ksbc table")
        return
    end

    if not t[key] then
        Log.WarningFormat("[HotfixKsbcData] %s not found", key)
        return
    end

    Game.IsHotfixing = true
    t[key] = value
    Game.IsHotfixing = false
end

-- 热修指定某一行的attr
---@public
function TableDataManager:HotfixAttrRow(tableName, attrName, key, value)
    local attr = Game.TableDataManager:GetAttr(tableName, attrName)
    if not attr then
        Log.ErrorFormat("[HotfixKsbcAttr] %s attr not found", attrName)
        return
    end

    Game.IsHotfixing = true
    attr[key] = value
    Game.IsHotfixing = false
end

-- 热修某个attr全部数据
---@public
function TableDataManager:HotfixAttrAll(tableName, attrName, attrValue)
    local t = ksbcRawG()[tableName]
    if not t then
        Log.ErrorFormat("[HotfixAttrAll] %s not found", tableName)
        return
    end

    Game.IsHotfixing = true
    if type(attrValue) == "table" then
        -- 避免引用失效的问题
        for k, v in pairs(attrValue) do
            t[attrName][k] = v
        end
    else
        t[attrName] = attrValue
    end
    Game.IsHotfixing = false
end

---@class HfLangInfo
---@field key string
---@field value string

-- 热修复某个指定key的对应多语言字符串
---@public
---@param langInfo table<string, HfLangInfo>
function TableDataManager:HotfixLangData(langInfo)
    local langType = self:GetLangType()
    local targetInfo = langInfo[langType]
    if not targetInfo then
        Log.WarningFormat("[HotfixLangData] not math current lang %s", langType)
        return
    end

    if not Game.KsbcMgr.langKeyMap[targetInfo.key] then
        Log.WarningFormat("[HotfixLangData] %s langKey not found", targetInfo.key)
        return
    end

    -- 直接用外层key作为stringDB的新key
    Game.KsbcMgr.stringDB[targetInfo.key] = targetInfo.value
    Game.KsbcMgr.langKeyMap[targetInfo.key] = targetInfo.key
end

---@class HfStringDBInfo
---@field key number
---@field value string

-- 热修复某个指定语言的的字符串
---@public
---@param stringDBInfo table<string, HfStringDBInfo>
function TableDataManager:HotfixStringDB(stringDBInfo)
    local langType = self:GetLangType()
    local targetInfo = stringDBInfo[langType]
    if not targetInfo then
        Log.WarningFormat("[HotfixStringDB] not math current lang %s", langType)
        return
    end

    if not Game.KsbcMgr.stringDB[targetInfo.key] then
        Log.WarningFormat("[HotfixStringDB] %s stringDB not found", targetInfo.key)
        return
    end

    Game.KsbcMgr.stringDB[targetInfo.key] = targetInfo.value
end

-- c7 fix end

return TableDataManager
