---@class LoaderComponent
local LoaderComponent = DefineClass("LoaderComponent")
local SceneDisplayConfig = kg_require("Gameplay.LogicSystem.SceneDisplay.SceneDisplayConfig")
local UIFunctionLibrary = import("UIFunctionLibrary")

function LoaderComponent:ctor()
    ---@type table<number, table> 异步加载临时容器
    self._resHandleMap = {}
end

function LoaderComponent:dtor()
    self._resHandleMap = nil
end

function LoaderComponent:ClearLoad()
    for _, value in pairs(self._resHandleMap) do
		Game.AssetManager:CancelLoadAsset(value.loadID)
    end
    table.clear(self._resHandleMap)
end

function LoaderComponent:CancelTargetLoad(loadID)
	if self._resHandleMap[loadID] then
		Game.AssetManager:CancelLoadAsset(loadID)
	end
	self._resHandleMap[loadID] = nil
end

---@public LoadOldUIPanelAsset 加载旧框架配置的UI面板资源
---@param uid string 面板id
---@param callback function 加载完成回调(回调2个变量, panelRes面板资源, preloadResMap依赖资源(key为资源路径, value为资源))
---@param bAsync boolean 是否异步加载(默认为true)
---@return number? 异步加载资源LoadID
function LoaderComponent:LoadOldUIPanelAsset(uid, callback, bAsync)
	if _G.StoryEditor then --剧编模式下默认同步加载
		bAsync = false
	end
	local config = Game.NewUIManager:GetUIConfig(uid)
	local uiClass = kg_require(config.classpath)
	return self:loadUIAndDependenceAsset(uiClass, callback, bAsync, config.res .. "_C", config.scenename)
end

---@public LoadPanelAsset
---@param uid string 面板id
---@param callback function 加载完成回调(回调2个变量, panelRes面板资源, preloadResMap依赖资源(key为资源路径, value为资源))
---@param bAsync boolean 是否异步加载(默认为true)
---@return number? 异步加载资源LoadID
function LoaderComponent:LoadPanelAsset(uid, callback, bAsync)
	local config = Game.NewUIManager:GetUIConfig(uid)
	return self:loadUIAndDependenceAsset(config, callback, bAsync)
end

---@public LoadCellAsset
---@param cellId string
---@param callback function 加载完成回调(回调2个变量, panelRes component资源, preloadResMap依赖资源(key为资源路径, value为资源))
---@param bAsync boolean 是否异步加载(默认为true)
---@return number? 异步加载资源LoadID
function LoaderComponent:LoadCellAsset(cellId, callback, bAsync)
	local config = UICellConfig.CellConfig[cellId]
	return self:loadUIAndDependenceAsset(config, callback, bAsync)
end

---@private loadUIAndDependenceAsset 加载UI面板相关资源
---@param resConfig table 资源配置
---@param callback function 加载完成回调
---@param bAsync boolean 是否异步加载(默认为true)
---@param panelAssetName string? UI面板资源路径（仅老框架接口传）
---@param sceneName string? 3d场景资源名（仅老框架接口传）
---@return number? 异步加载资源LoadID
function LoaderComponent:loadUIAndDependenceAsset(resConfig, callback, bAsync, panelAssetName, sceneName)
	local assetList = {} -- 最终进LoadUI的ResList
	local loadID = nil
	panelAssetName = panelAssetName and panelAssetName or resConfig.res
	assetList[#assetList + 1] = panelAssetName
	-- 场景资源
	sceneName = sceneName and sceneName or resConfig.scenename
	if sceneName and sceneName ~= "default" then
		assetList[#assetList + 1] = SceneDisplayConfig.SceneConfigs[sceneName].DisplaySceneBP
	end
	if resConfig.PreloadResMap then
		for _, cellId in pairs(resConfig.PreloadResMap) do
			local config = UICellConfig.CellConfig[cellId]
			assetList[#assetList + 1] = config.res
		end
	end

	if resConfig.PreloadLibMap then
		if not resConfig.PreloadLibMapReverse then
			resConfig.PreloadLibMapReverse = table.reverse(resConfig.PreloadLibMap)
		end
		for name, path in pairs(resConfig.PreloadLibMap) do
			if not Game.UIManager.LibMap[name] then
				assetList[#assetList + 1] = path
			end
		end
	end

	if #assetList > 1 then
		-- luacheck: push ignore
		local loadCallback = function(resList)
			local panelRes = nil
			local preloadResMap = {}
			for i, v in pairs(resList) do
				local resFullName = v:GetPathName()
				if resFullName == panelAssetName then
					panelRes = v
				elseif resConfig.PreloadLibMapReverse and resConfig.PreloadLibMapReverse[resFullName] then
					local libWidget = UIFunctionLibrary.CreateWidgetWithName(_G.GetContextObject(), v, "Name_None")
					Game.UIManager.LibMap[resConfig.PreloadLibMapReverse[resFullName]] = libWidget
				else
					preloadResMap[resFullName] = v
				end
			end
			callback(panelRes, preloadResMap)
		end
		-- luacheck: pop
		if bAsync ~= false then
			loadID = self:AsyncLoadResList(assetList, loadCallback)
		else
			local resList = self:SyncLoadResList(assetList)
			loadCallback(resList)
		end
	else
		if bAsync ~= false then
			loadID = self:AsyncLoadRes(panelAssetName, callback)
		else
			callback(self:SyncLoadRes(panelAssetName))
		end
	end
	return loadID
end

function LoaderComponent:LoadRes(filePath, callback, bAsync)
	if bAsync then
		return self:AsyncLoadRes(filePath, callback)
	else
		callback(self:SyncLoadRes(filePath))
	end
end

function LoaderComponent:LoadResList(filePaths, callback, bAsync)
	if bAsync then
		return self:AsyncLoadResList(filePaths, callback)
	else
		callback(self:SyncLoadResList(filePaths))
	end
end

function LoaderComponent:SyncLoadRes(filePath)
    if string.isEmpty(filePath) then
        Log.Warning("UIFrame: LoaderComponent SyncLoadRes filePath isNil")
        return
    end
    local asset = Game.AssetManager:SyncLoadAsset(filePath)
	if not asset then
		Log.WarningFormat("UIFrame: LoaderComponent SyncLoadRes (%s) Res isNil", filePath)
		return
	end
	return asset
end

function LoaderComponent:SyncLoadResList(filePaths)
	if #filePaths == 0 then
		Log.Warning("UIFrame: LoaderComponent SyncLoadRes filePaths isEmpty")
		return
	end
	local assets = Game.AssetManager:SyncLoadAssetList(filePaths)
	if not assets then
		Log.Error("UIFrame: LoaderComponent SyncLoadResList (%s) Res isNil")
		return
	end
	return assets
end

function LoaderComponent:AsyncLoadRes(filePath, callback)
    local loadID, _ = Game.AssetManager:AsyncLoadAssetKeepReference(filePath, self, "OnAsyncLoadFinish")
    self._resHandleMap[loadID] = {loadID = loadID, onFinish = callback, filePath = filePath}
    return loadID
end

function LoaderComponent:OnAsyncLoadFinish(loadID, loadedAsset)
    local resHandle = self._resHandleMap[loadID]
    self._resHandleMap[loadID] = nil
    if resHandle then
        if resHandle.onFinish then
            if not loadedAsset then
                Log.WarningFormat("UIFrame: LoaderComponent SyncLoadRes (%s) Res isNil", resHandle.filePath)
                Game.AssetManager:RemoveAssetReferenceByLoadID(loadID)
                return
            end
            resHandle.onFinish(loadedAsset)
            Game.AssetManager:RemoveAssetReferenceByLoadID(loadID)
        end
    else
        Log.WarningFormat("UIFrame:LoaderComponent.OnAsyncLoadFinish 异步加载资源回调异常, ID和加载时的ID不对应了")
    end
end

function LoaderComponent:AsyncLoadResList(filePaths, callback)
    local loadID = Game.AssetManager:AsyncLoadAssetListKeepReference(filePaths, self, "OnAsyncLoadResListFinish")
    self._resHandleMap[loadID] = {loadID = loadID, onFinish = callback, filePaths = filePaths}
    return loadID
end

function LoaderComponent:OnAsyncLoadResListFinish(loadID, loadObjs)
    local resHandle = self._resHandleMap[loadID]
    self._resHandleMap[loadID] = nil
    if resHandle then
        if resHandle.onFinish then
            if not loadObjs then
                Log.WarningFormat("UIFrame: LoaderComponent AsyncLoadResList (%s) ResourceMap isNil", resHandle.filePaths[1])
                Game.AssetManager:RemoveAssetReferenceByLoadID(loadID)
                return
            end
            resHandle.onFinish(loadObjs)
            Game.AssetManager:RemoveAssetReferenceByLoadID(loadID)
        end
    else
        Log.WarningFormat("UIFrame:LoaderComponent.OnAsyncLoadResListFinish 异步加载资源回调异常, ID和加载时的ID不对应了")
    end
end

return LoaderComponent

