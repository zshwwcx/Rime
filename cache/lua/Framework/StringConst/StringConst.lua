---@class LRUCacheNode
---@field key string
---@field value any
---@field prev LRUCacheNode
---@field next LRUCacheNode

---@class LRUCache
---@field private capacity number
---@field private cache table<string, {value: any, node: LRUCacheNode}>
---@field private count number
---@field private head LRUCacheNode
---@field private tail LRUCacheNode
local LRUCache = {} --luacheck: ignore
local Language_zhs = kg_require("Framework.StringConst.Language_zhs")
---@param capacity number
---@return LRUCache
function LRUCache:new(capacity)
    local o = setmetatable({}, self)
    self.__index = self
    o.capacity = capacity
    o.cache = {}
    o.count = 0
    o.head = nil
    o.tail = nil
    return o
end

---@param key string
---@return any
function LRUCache:Get(key)
    local node = self.cache[key]
    if node then
        self:Remove(node)
        self:InsertToHead(node)
        return node.value
    end
    return nil
end

---@param key string
---@param value any
function LRUCache:Put(key, value)
    local node = self.cache[key]
    if node then
        node.value = value
        self:Remove(node)
        self:InsertToHead(node)
    else
        if self.count >= self.capacity then
            local tailNode = self.tail
            self:Remove(tailNode)
            self.cache[tailNode.key] = nil
            self.count = self.count - 1
        end

        local newNode = {
            key = key,
            value = value,
            prev = nil,
            next = nil
        }
        self:InsertToHead(newNode)
        self.cache[key] = newNode
        self.count = self.count + 1
    end
end

function LRUCache:Clear()
    self.cache = {}
    self.count = 0
    self.head = nil
    self.tail = nil
end

---@private
---@param node LRUCacheNode
function LRUCache:Remove(node)
    if node.prev then
        node.prev.next = node.next
    else
        self.head = node.next
    end
    if node.next then
        node.next.prev = node.prev
    else
        self.tail = node.prev
    end
end

---@private
---@param node LRUCacheNode
function LRUCache:InsertToHead(node)
    node.next = self.head
    node.prev = nil
    if self.head then
        self.head.prev = node
    end
    self.head = node
    if not self.tail then
        self.tail = node
    end
end

-------------------------------------------------------------------------------------------

---@class StringConst
---@field private caches LRUCache
---@field private DataTableFunction function[]
local StringConst = {}

StringConst.caches = LRUCache:new(100)

StringConst.DataTableFunction = {
    Game.TableData.GetStringConstDataRow,
    Game.TableData.GetStringConstDungeonStatisticsDataRow,
    Game.TableData.GetStringConstArena3v3DataRow,
    Game.TableData.GetStringConstBagDataRow,
    Game.TableData.GetStringConstDungeonDataRow,
    Game.TableData.GetStringConstDropDataRow,
    Game.TableData.GetStringConstMailDataRow,
    Game.TableData.GetStringConstTeamDataRow,
    Game.TableData.GetShowStringConstDataRow,
    Game.TableData.GetStringConstHUDDataRow,
    Game.TableData.GetStringConstTaskDataRow,
    Game.TableData.GetStringConstSkillCustomizerDataRow,
    Game.TableData.GetStringConstRoleSelectDataRow,
    Game.TableData.GetStringConstEquipmentDataRow,
    Game.TableData.GetStringConstStoreDataRow,
    Game.TableData.GetStringConstMapDataRow,
    Game.TableData.GetStringConstOpenUIDataRow,
    Game.TableData.GetStringConstHotPatchDataRow,
    Game.TableData.GetStringConstSocialDataRow,
    Game.TableData.GetStringConstGuildDataRow,
    Game.TableData.GetStringConstFellowDataRow,
    Game.TableData.GetStringConstGachaDataRow,
    Game.TableData.GetStringConstMultiPvpDataRow,
    Game.TableData.GetStringConstLoginDataRow,
    Game.TableData.GetStringConstAnnouncementDataRow,
    Game.TableData.GetStringConstSealedDataRow,
    Game.TableData.GetStringConstDeathReliveDataRow,
    Game.TableData.GetStringConstSettingsDataRow,
    Game.TableData.GetStringConstMallDataRow,
    Game.TableData.GetStringConstTowerDataRow,
    Game.TableData.GetStringConstCashMarketDataRow,
    Game.TableData.GetStringConstPopUpDataRow,
    Game.TableData.GetBidStringConstDataRow,
    Game.TableData.GetStringConstSequenceDataRow,
    Game.TableData.GetStringConstGuildMaterialTaskDataRow,
    Game.TableData.GetDancingPartyStringConstDataRow,
    Game.TableData.GetStringConstRolePlayDataRow,
    Game.TableData.GetStringConstSocialActionDataRow,
    Game.TableData.GetStringConstCutPriceDataRow,
    Game.TableData.GetStringConstMiniGameDataRow,
    Game.TableData.GetDanceStringConstDataRow,
    Game.TableData.GetFashionStringConstDataRow,
    Game.TableData.GetStringConstActivityDataRow,
    Game.TableData.GetStringConstRedPacketDataRow,
    Game.TableData.GetInteractorStringConstDataRow,
    Game.TableData.GetStringConstGuildLeagueDataRow,
    Game.TableData.GetPVPEntranceStringConstRow,
    Game.TableData.GetLetterStrRow,
}

function StringConst:Init()
    local tableMgr = Game.TableDataManager
    if tableMgr then
        tableMgr:RegisterListener(self)
    end
end

function StringConst:OnPreHotfix()
end

function StringConst:OnPostHotfix()
    self.caches:Clear()
end

function StringConst:PreReleaseAllTableData()
end

function StringConst:PostReleaseAllTableData()
    self.caches:Clear()
end

---@private
---@param key string
---@return string
function StringConst:InternalGet(key)
    local config = self.caches:Get(key)
    if config then
        return config
    end

    for i = 1, #self.DataTableFunction do
        if config == nil then
            if self.DataTableFunction[i] ~= nil then
                config = self.DataTableFunction[i](key)
            end
        else
            break
        end
    end

    if config then
        local str = config["StringValue"]
        self.caches:Put(key, str)
        return str
    end

    if _G.UE_EDITOR and not config then
        local str = Language_zhs[key]
        if str then
            self.caches:Put(key, str)
            return str
        end
    end

    return nil
end

function StringConst.Get(key, ...)
    local stringValue = StringConst:InternalGet(key)
    if stringValue == nil then
        if ... ~= nil then
            return string.format(key, ...)
        else
            return key
        end
    end

    if ... ~= nil then
        return string.format(stringValue, ...)
    else
        return stringValue
    end
end

function StringConst.GetList(key)
    return StringConst:InternalGet(key)
end

StringConst:Init()

return StringConst
