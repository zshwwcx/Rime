
ObjectActorManager = DefineClass("ObjectActorManager")

function ObjectActorManager:Init()
    -- 初始化成员变量
    self.onActorDestoryedCallbackTable = {}

    -- 初始化C++管理器
    self.cppMgr = import("KGObjectActorManager")(Game.WorldContext)
    Game.GameInstance:CacheManager(self.cppMgr)
    self.cppMgr:NativeInit()

    --回调绑定：
    self.onActorDestoryedDelegate = self.cppMgr.OnActorDestoryedDelegate:Add(function(InActor, InActorID)
        self:onActorDestoryedNotify(InActor, InActorID)
    end)

	self.AvailableObjects = {}
	self.AvailableTables = {}
	-- 这里是为了记录每个对象当前已经分配的数量, 当InUse对量数量已经超过两倍的该对象设定的最大PoolSize时，就会报错提醒业务潜在的逻辑问题
	self.AllocatedObjectNum = {}
	self.bEnableObjectPool = true
end

function ObjectActorManager:UnInit()
    self.cppMgr.OnActorDestoryedDelegate:Remove(self.onActorDestoryedDelegate)

    table.clear(self.onActorDestoryedCallbackTable)
	
	self:DumpPoolInfoOnUnInit()
	table.clear(self.AvailableObjects)
	table.clear(self.AvailableTables)
	table.clear(self.AllocatedObjectNum)

    self.cppMgr:NativeUninit()
end
 
--region ObjectPool

ObjectActorManager.MaxTableSize = 1024
ObjectActorManager.ObjectReservePercentageOnLevelChange = 0.5
ObjectActorManager.ObjectReserveNumOnLowMemory = 5
-- 进池以后切换metatable, 避免池内对象错误访问
ObjectActorManager.ObjectMetatableInPool = {
	__index = function(_, key)
		Log.Error("cannot access object when object in pool", key)
	end,
	__newindex = function(_, k, v)
		Log.Error("cannot access object when object in pool", k, v)
	end
}

function ObjectActorManager:AllocateTable()
	if not self.bEnableObjectPool then
		return {}
	end
	
	local AvailableTableNum = #self.AvailableTables
	if AvailableTableNum == 0 then
		return {}
	end
	
	local Object = table.remove(self.AvailableTables)
	setmetatable(Object, nil)
	return Object
end

function ObjectActorManager:ReleaseTable(Object)
	if not self.bEnableObjectPool then
		return	
	end
	
	local AvailableTableNum = #self.AvailableTables
	if AvailableTableNum >= ObjectActorManager.MaxTableSize then
		return
	end
	
	table.clear(Object)
	setmetatable(Object, ObjectActorManager.ObjectMetatableInPool)
	table.insert(self.AvailableTables, Object)
end

--- ObjectClass需要通过DefineClass定义
--- 所有需要分配的对象需要实现 on_alloc_from_pool 以及 on_recycle_to_pool 方法, 定义当前对象最大的 __PoolSize
function ObjectActorManager:AllocateObject(ObjectClass)
	if not self.bEnableObjectPool then
		return ObjectClass.new()
	end
	
	local Pool = self.AvailableObjects[ObjectClass]
	if Pool == nil then
		Pool = {}
		self.AvailableObjects[ObjectClass] = Pool
	end

	if self.AllocatedObjectNum[ObjectClass] == nil then
		self.AllocatedObjectNum[ObjectClass] = 1
	else
		local ObjectNum = self.AllocatedObjectNum[ObjectClass]
		self.AllocatedObjectNum[ObjectClass] = ObjectNum + 1

		local PoolSizeWarningThreshold = ObjectClass.__PoolSizeWarningThreshold and ObjectClass.__PoolSizeWarningThreshold or 2 * ObjectClass.__PoolSize
		if ObjectNum >= PoolSizeWarningThreshold then
			Log.Warning("ObjectActorManager:AllocateObject, object num exceeds limit", ObjectClass.__cname, ObjectNum)
		end
	end
	
	if #Pool == 0 then
		return ObjectClass.new()
	else
		local Object = table.remove(Pool)
		setmetatable(Object, Object.__origin_metatable)
		Object.__origin_metatable = nil
		-- on_alloc_from_pool is optional
		if Object.on_alloc_from_pool then
			Object:on_alloc_from_pool()
		end
		return Object
	end
end

function ObjectActorManager:ReleaseObject(Object)
	if not self.bEnableObjectPool then
		return
	end
	
	local ObjectClass = Object.class
	local Pool = self.AvailableObjects[ObjectClass]
	local PoolSize = ObjectClass.__PoolSize

	self.AllocatedObjectNum[ObjectClass] = self.AllocatedObjectNum[ObjectClass] - 1 
	
	if #Pool < PoolSize then
		-- on_recycle_to_pool is necessary
		Object:on_recycle_to_pool()
		Object.__origin_metatable = getmetatable(Object)
		setmetatable(Object, ObjectActorManager.ObjectMetatableInPool)
		table.insert(Pool, Object)
	end
end

function ObjectActorManager:OnWorldMapDestroy(_)
	self:ClearObjectPools(nil, ObjectActorManager.ObjectReservePercentageOnLevelChange)
end

function ObjectActorManager:OnMemoryWarning()
	self:ClearObjectPools(ObjectActorManager.ObjectReserveNumOnLowMemory, nil)
end

function ObjectActorManager:ClearObjectPools(InTargetSize, InTargetPercentage)
	for ObjectClass, AvailableObjectList in pairs(self.AvailableObjects) do
		local PoolSize = ObjectClass.__PoolSize
		local CurSize = #AvailableObjectList
		local TargetSize = InTargetSize and InTargetSize or math.floor(PoolSize * InTargetPercentage)
		if CurSize > TargetSize then
			for i = CurSize, TargetSize, -1 do
				table.remove(AvailableObjectList, i)
			end
			Log.Debug("Clear objects when map destroy,", ObjectClass.__cname, CurSize, TargetSize)
		end
	end

	local CurTableSize = #self.AvailableTables
	local TargetTabletSize = InTargetSize and InTargetSize or math.floor(ObjectActorManager.MaxTableSize * InTargetPercentage)
	if CurTableSize > TargetTabletSize then
		for i = CurTableSize, TargetTabletSize, -1 do
			table.remove(self.AvailableTables, i)
		end
		Log.Debug("Clear available tables when map destroy,", CurTableSize, TargetTabletSize)
	end
end

function ObjectActorManager:DumpPoolInfoOnUnInit()
	for ObjectClass, CurNum in pairs(self.AllocatedObjectNum) do
		if CurNum ~= 0 then
			Log.Warning("Pool objects not released", ObjectClass.__cname, CurNum)
		end
	end
end

function ObjectActorManager:DumpPoolInfo()
	for ObjectClass, CurNum in pairs(self.AllocatedObjectNum) do
		Log.Debug("Pool objects info", ObjectClass.__cname, "CurNum:", CurNum, "AvailableNum:", #self.AvailableObjects[ObjectClass])
	end
end

--endregion


function ObjectActorManager:SpawnActor(ClassObject, bKeepReference, LocationX, LocationY, LocationZ, Pitch,Yaw, Roll)
    if ClassObject == nil then
        Log.Error("SpawnActor with null Class")
        return
    end

    local newActor = self.cppMgr:SpawnActor(ClassObject, bKeepReference, LocationX, LocationY, LocationZ, Pitch,Yaw, Roll)
    if newActor == nil then
        Log.ErrorFormat("can not spawn actor by class[%s] bKeepReference[%s] X[%s] Y[%s] Z[%s]", ClassObject, bKeepReference, LocationX, LocationY, LocationZ)
        return
    end
    
    return newActor
end

function ObjectActorManager:DestroyActor(InActor)
    if InActor == nil then
        Log.Error("DestroyActor with null InActor")
        return
    end

    self.cppMgr:DestroyActor(InActor)
end

function ObjectActorManager:DestroyActorByID(InID)
    self.cppMgr:DestroyActorByID(InID)
end

function ObjectActorManager:GetIDByObject(InObject)
    return self.cppMgr:GetIDByObject(InObject)
end

function ObjectActorManager:GetObjectByID(InID)
    return self.cppMgr:GetObjectByID(InID)
end

function ObjectActorManager:GetIDByClass(InObject)
    return self.cppMgr:GetIDByClass(InObject)
end

function ObjectActorManager:GetClassByID(InID)
    return self.cppMgr:GetClassByID(InID)
end


function ObjectActorManager:onActorDestoryedNotify(InActor, InActorID)
    local v = self.onActorDestoryedCallbackTable[InActorID]
    if v == nil then
        return
    end
    
    self.onActorDestoryedCallbackTable[InActorID] = nil
    
    if v == nil or v[1] == nil or v[2] == nil then
        Log.ErrorFormat("onActorDestoryedNotify can not find value from callback table by key %d", InActorID)
        return
    end

    --Log.DebugFormat("v1[%s], v2[%s]", v[1], v[2])
    local func = v[1][v[2]]
    if (func == nil) then
        Log.ErrorFormat("onActorDestoryedNotify can not find callback function %s %s, InActorID:%s", tostring(v[1].__cname), v[2], tostring(LoadID))
        return
    end

    xpcall(func, _G.CallBackError, v[1], InActor, InActorID)
end

function ObjectActorManager:AddActorDestoryedNotifyCallback(InActorID, InRequester, InCallbackName)
    if InActorID <= 0 or InRequester == nil or InCallbackName == nill then
        Log.ErrorFormat("AddActorDestoryedNotifyCallback InValid Parameters [%s %s %s]", InActorID, InRequester.__cname, InCallbackName)
        return
    end

    if self.onActorDestoryedCallbackTable[InActorID] then
        Log.ErrorFormat("can not call AddActorDestoryedNotifyCallback on the same actor ps[%s, %s]", InActorID, InRequester.__cname)
        return
    end

    self.onActorDestoryedCallbackTable[InActorID] = {InRequester, InCallbackName}

end

function ObjectActorManager:RemoveActorDestoryedNotifyCallback(InActorID)
    if self.onActorDestoryedCallbackTable[InActorID] then
        self.onActorDestoryedCallbackTable[InActorID] = nil
    end
end

function ObjectActorManager:KGNewObject(InClass, InOuter, bKeepReference)
	return self.cppMgr:KGNewObject(InClass, InOuter, bKeepReference)
end

function ObjectActorManager:ReferenceObject(InObj)
	return self.cppMgr:ReferenceObject(InObj)
end

function ObjectActorManager:RemoveObjectReference(InObject)
	return self.cppMgr:RemoveObjectReference(InObject)
end

return ObjectActorManager