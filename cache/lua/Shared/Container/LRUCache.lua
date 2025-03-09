local lume = kg_require("Shared.lualibs.lume")
-- local inspect = kg_require("Shared.lualibs.inspect")

---@class LRUCache
LRUCache = DefineClass("LRUCache")

function LRUCache:ctor(limit, bSoftLimit)
    self.limit = limit
    self.bSoftLimit = bSoftLimit
    self:clear()
end

function LRUCache:clear()
    self.count = 0
    self.cache = {} -- 数据缓存 key->node

    local head = {}
    local tail = {}
    head.next = tail
    tail.prev = head
    self.head = head
    self.tail = tail
end

function LRUCache:set(key, value)
    local node = self.cache[key]
    if node then
        node.data = value
        node.deleteFlag = nil
        self:_removeNode(node)
        self:_pushHead(node)
    else
        node = {
            key = key,
            data = value,
            prev = nil,
            next = nil,
            dirty = true
        }
        self.cache[key] = node
        self:_pushHead(node)
        if self.count > self.limit then
            if self.bSoftLimit then
                return self:_softDelTail()
            else
                return self:_popTail()
            end
        end
    end
end

function LRUCache:update(key, value, upsert)
    -- LOG_DEBUG("LRUCache:update", key, inspect(value), inspect(self.cache[key]), debug.traceback())
    local node = self.cache[key]
    if node then
        lume.extend(node.data, value)
        node.dirty = true
        node.deleteFlag = nil
        self:_removeNode(node)
        self:_pushHead(node)
    elseif upsert then
        node = {
            key = key,
            data = value,
            prev = nil,
            next = nil,
            dirty = true
        }
        self.cache[key] = node
        self:_pushHead(node)
        if self.count > self.limit then
            if self.bSoftLimit then
                return self:_softDelTail()
            else
                return self:_popTail()
            end
        end
    end
end

function LRUCache:get(key)
    local node = self.cache[key]
    if node then
        self:_removeNode(node)
        self:_pushHead(node)
        return node.data
    end
    return nil
end

function LRUCache:clearDirty(key)
    local node = self.cache[key]
    if node then
        node.dirty = false
    end
end

function LRUCache:isDirty(key)
    local node = self.cache[key]
    if node and node.dirty then
        return true
    end
    return false
end

function LRUCache:remove(key)
    local node = self.cache[key]
    if node then
        self:_removeNode(node)
        self.cache[key] = nil
        return node.data
    end
    return nil
end

function LRUCache:removeWithDeleteFlag(key)
    local node = self.cache[key]
    if node and node.deleteFlag then
        self:_removeNode(node)
        self.cache[key] = nil
        return node.data
    end
    return nil
end

function LRUCache:size()
    return self.count
end

function LRUCache:hasKey(key)
    local node = self.cache[key]
    return node and true or false
end

function LRUCache:_removeNode(node)
    local prev = node.prev
    local next = node.next
    prev.next = next
    next.prev = prev
    self.count = self.count - 1
end

function LRUCache:_pushHead(node)
    local head = self.head
    local next = head.next
    node.prev = head
    node.next = next
    head.next = node
    next.prev = node
    self.count = self.count + 1
end

function LRUCache:_popTail()
    if self.count > 0 then
        local node = self.tail.prev
        self:_removeNode(node)
        self.cache[node.key] = nil
        return node.data
    end
end

function LRUCache:_softDelTail()
    if self.count > 0 then
        local node = self.tail.prev
        node.deleteFlag = true
        return node.data
    end
end
