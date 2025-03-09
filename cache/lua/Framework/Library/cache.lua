---@class Cache:Object
local Cache = DefineClass("Cache")
function Cache.ctor(self, num)
	self.queue = { }
	self.objs = { }
	self.objkeys = { }
	self.limitn = num
end

function Cache.push(self, key, obj)
	--Log.debug("Cachepush", key, #self.queue)
	local oldobj = self.objs[key]
	if oldobj then
		assert(nil, 'push same key obj : '..key)
		self.objkeys[oldobj] = nil
		oldobj:Dispose()
		table.removev(self.queue, oldobj)
	end
	self.objs[key] = obj
	table.insert(self.queue, obj)
	local len = #self.queue
	self.objkeys[obj] = key
	if self.limitn < len then
		local robj = table.remove(self.queue, 1)
		local rkey = self.objkeys[robj]
		self.objkeys[robj] = nil
		self.objs[rkey] = nil
		robj:Dispose()
	end
end

function Cache.pop(self, key)
	local obj = self.objs[key]
	if not obj then return end
	self.objs[key] = nil
	table.removev(self.queue, obj)
	self.objkeys[obj] = nil
	return obj
end

function Cache.get(self, key)
	local obj = self.objs[key]
	return obj
end

function Cache.contain(self, key)
	return self.objs[key] ~= nil
end

function Cache.getObjs(self)
	return self.objs
end

function Cache.Clear(self)
	local next = next
	for name, obj in next, self.objs do
		obj:Dispose()
	end
	table.clear(self.queue)
	table.clear(self.objs)
	table.clear(self.objkeys)
end

function Cache.ClearOne(self)
	if #self.queue < 1 then return false end
	local robj = table.remove(self.queue, 1)
	local rkey = self.objkeys[robj]
	self.objkeys[robj] = nil
	self.objs[rkey] = nil
	robj:Dispose()
	return true
end