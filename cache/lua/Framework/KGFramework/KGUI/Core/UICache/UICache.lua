---@class UICache
local UICache = DefineClass("UICache")
function UICache:ctor(num)
	self.cacheMaxNum = num
    self.cacheCurNum = 0
    self.cacheObjects = {}
    self.keyStack = {}
end

function UICache:Push(key, obj)
    if not self.cacheObjects[key] then
        self.cacheObjects[key] = {}
    end
    table.insert(self.cacheObjects[key], 1, obj)
    table.insert(self.keyStack, 1, key)
    self.cacheCurNum = self.cacheCurNum + 1
    self:TryClearCache()
end

function UICache:Pop(key)
    local cache = self.cacheObjects[key]
	if cache and #cache > 0 then
        local index = #cache
        local object = cache[index]
        table.remove(cache, index)
        self.cacheCurNum = self.cacheCurNum - 1
        local count = #self.keyStack
        for i = count, 1, -1 do
            if self.keyStack[i] == key then
                table.remove(self.keyStack, i)
                break
            end
        end
        return object
    end
	return nil
end

function UICache:TryClearCache()
    if self.cacheCurNum >= self.cacheMaxNum then
        local count = #self.keyStack
        local cache = self.cacheObjects[self.keyStack[count]]
        if cache and #cache>0 then
            local object = cache[#cache]
            object:Destroy()
            table.remove(cache, #cache)
        else
            Log.ErrorFormat("UIFrame.UICache.TryClearCache key:%s cache res has destroy", self.keyStack[i])
        end
        self.cacheCurNum = self.cacheCurNum - 1
        table.remove(self.keyStack, count)
    end
end

function UICache:GetCacheCount()
    local count = 0
    for _,cache in pairs(self.cacheObjects) do
        for _,component in ipairs(cache) do
            count = count + component:GetObjectNum()
        end
	end
    return count
end

function UICache:DebugInfo()
    local logStr = ""
    for _,cache in pairs(self.cacheObjects) do
        if #cache > 0 then
            local count = 0
            for _,v in ipairs(cache) do
                count = count + v:GetObjectNum()
            end
            logStr = string.format("%s \n Script:  %s,  Script Num,:  %s,  uobject Num:  %s",logStr, cache[1].__cname, #cache, count)
        end
	end
    return logStr
end

function UICache:Clear()
	for _,cache in pairs(self.cacheObjects) do
        for _,object in ipairs(cache) do
            object:Destroy()
        end
    end
    table.clear(self.cacheObjects)
end

return UICache