
AssetManager = DefineClass("AssetManager")

function AssetManager:Init()
    -- 初始化成员变量
    self.onAsyncLoadCompleteNotify = nil
    self.callbackTable = {}

    -- 初始化C++管理器
    self.cppMgr = import("KGResourceManager2")(Game.WorldContext)
    Game.GameInstance:CacheManager(self.cppMgr)
    self.cppMgr:NativeInit()

    --回调绑定：
    self.onAsyncLoadCompleteNotify = self.cppMgr.OnAssetLoadedDelegate:Add(function(LoadID, LoadedAsset)
        self:OnAsyncLoadAssetComplete(LoadID, LoadedAsset)
    end)

    self.onAsyncLoadListCompleteNotify = self.cppMgr.OnAssetListLoadedDelegate:Add(function(LoadID, LoadedAssets)
        self:OnAsyncLoadAssetListComplete(LoadID, LoadedAssets)
    end)

end

function AssetManager:UnInit()
    self.cppMgr.OnAssetLoadedDelegate:Remove(self.onAsyncLoadCompleteNotify)
    self.cppMgr:NativeUninit()
end


function AssetManager:OnAsyncLoadAssetComplete(LoadID, LoadedAsset)
    --Log.DebugFormat("OnAsyncLoadAssetComplete LoadID[%s], LoadedAsset [%s]", LoadID, LoadedAsset)

    local v = self.callbackTable[LoadID]
    self.callbackTable[LoadID] = nil
    
    if v == nil or v[1] == nil or v[2] == nil then
        Log.ErrorFormat("OnAsyncLoadAssetComplete can not find value from callback table by key %d", LoadID)
        return
    end
    
    --Log.DebugFormat("v1[%s], v2[%s]", v[1], v[2])
    local func = v[1][v[2]]
    if (func == nil) then
        Log.ErrorFormat("OnAsyncLoadAssetComplete can not find callback function %s %s, loadID:%s", tostring(v[1].__cname), v[2], tostring(LoadID))
        return
    end

    xpcall(func, _G.CallBackError, v[1], LoadID, LoadedAsset)
end

function AssetManager:OnAsyncLoadAssetListComplete(LoadID, LoadedAssets)
    --Log.DebugFormat("OnAsyncLoadAssetListComplete LoadID[%s], LoadedAssets [%s]", LoadID, LoadedAsset)

    local v = self.callbackTable[LoadID]
    self.callbackTable[LoadID] = nil
    
    if v == nil or v[1] == nil or v[2] == nil then
        Log.ErrorFormat("OnAsyncLoadAssetListComplete can not find value from callback table by key %d", LoadID)
        return
    end

    --Log.DebugFormat("v1[%s], v2[%s]", v[1], v[2])
    local func = v[1][v[2]]
    if (func == nil) then
        Log.ErrorFormat("OnAsyncLoadAssetComplete can not find callback function %s %s, loadID:%s", tostring(v[1].__cname), v[2], tostring(LoadID))
        return
    end

    xpcall(func, _G.CallBackError, v[1], LoadID, LoadedAssets)
end

function AssetManager:addAsyncLoadTask(LoadID, InRequester, InCallbackName)
    --Log.DebugFormat("addAsyncLoadTask %d", LoadID)
    self.callbackTable[LoadID] = {InRequester, InCallbackName}
end


--[[异步加载资源
    注意事项：
    1. C++层会默认进行引用操作避免被引擎立即GC，用完后，需要通过UnrefAssetByLoadID释放引用
       （并不会强制删除，除非这个对象没有被其他任何对象引用）；
       如果不进行引用释放操作，这个对象会被C++管理器引用得不到释放，在游戏退出时，会有没有释放对象的警告输出
    2 如果对象在内存中找到，会直接返回，回调函数在下一帧也会被调用，暂不支持取消回调，如果需要在技术群提出需求

    3 参数说明：
    InPath: 资源路径
        格式参考：
            资源    /Game/Arts/Character/Animation/Common/Story/NPC/Boy/A_B_Run.A_B_Run
            蓝图类  /Game/Blueprint/3C/Animation/AnimPublic/HumanCommon/KawaiiAnimLayer/ABP_AL_Kawaii_Male.ABP_AL_Kawaii_Male_C

    InRequester: 请求者(table)
    InCallbackName: 回调函数名称，注意是是函数名字符串。 回调函数包含两个参数：
        参数1   加载ID
        参数2   加载到的对象（如果加载失败则是nil）

    4 不单独返回失败原因， 游戏日志里会有失败输出
]]
function AssetManager:AsyncLoadAssetKeepReference(InPath, InRequester, InCallbackName)
    --Log.DebugFormat("AsyncLoadAssetKeepReference InPath[%s]", InPath)

    local LoadID, LoadedAsset = self.cppMgr:AsyncLoadAssetKeepReference(InPath, 0, nil)
    self:addAsyncLoadTask(LoadID, InRequester, InCallbackName)

    return LoadID, LoadedAsset
end

function AssetManager:AsyncLoadAssetListKeepReference(InPaths, InRequester, InCallbackName)
    --Log.DebugFormat("AsyncLoadAssetListKeepReference InPath[%s]", InPaths)

    local LoadID, LoadedAssets = self.cppMgr:AsyncLoadAssetListKeepReference(InPaths, 0, nil)
    self:addAsyncLoadTask(LoadID, InRequester, InCallbackName)

    return LoadID, LoadedAssets

end

function AssetManager:RemoveAssetReferenceByLoadID(InLoadID)
    --Log.DebugFormat("RemoveAssetReferenceByLoadID[%s]", InLoadID)

    self.cppMgr:RemoveAssetReferenceByLoadID(InLoadID)
end

--[[
    主动取消加载任务，不会有完成回调
    如果出现引擎层取消加载（例如游戏退出等异常情况），完成回调会被调用
]]
function AssetManager:CancelLoadAsset(InLoadID)
    --Log.DebugFormat("CancelLoadAsset[%s]", InLoadID)
    self.cppMgr:CancelAsyncLoadByLoadID(InLoadID)
	self.callbackTable[InLoadID] = nil
end


function AssetManager:SyncLoadAsset(InPath)
    return self.cppMgr:SyncLoadAsset(InPath)
end



function AssetManager:SyncLoadAssetList(InPaths)
    return self.cppMgr:SyncLoadAssetList(InPaths)
end

function AssetManager:SyncLoadAssetKeepReference(InPath)
	local LoadID, LoadedAsset = self.cppMgr:SyncLoadAssetKeepReference(InPath, nil)
	return LoadID, LoadedAsset
end

function AssetManager:SyncLoadAssetListKeepReference(InPaths)
	local LoadID, LoadedAssets = self.cppMgr:SyncLoadAssetListKeepReference(InPaths, nil)
	return LoadID, LoadedAssets
end



return AssetManager