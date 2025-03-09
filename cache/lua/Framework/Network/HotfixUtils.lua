-- luacheck: push ignore
local MD5 = require("Framework.Utils.MD5")
local SHIPPING_MODE = SHIPPING_MODE

local HotfixUtils = {}

HotfixUtils.hotfixInfoList = {}		--记录已经执行过的hotfix内容的MD5值

---getP4Version 获取客户端当前资源版本号
function HotfixUtils.getP4Version()
	local localP4Version = 0
	if UE_EDITOR then
		local versionPath = import("BlueprintPathsLibrary").EngineDir().."/Build/Build.version"
		local file = io.open(versionPath, "r")
		if file then
			local contentStr = file:read("*all")
			file:close()
			local content = require("Framework.Library.json").decode(contentStr)
			localP4Version = content.Changelist
		end
	else
		localP4Version = import("SubsystemBlueprintLibrary").GetEngineSubsystem(import("PakUpdateSubsystem")):GetLocalP4Version()
	end
	return localP4Version
end

local LocalP4Version = HotfixUtils.getP4Version()

function HotfixUtils.PreHotfix()
	local StringConst = StringConst
	if StringConst then
		StringConst:OnPreHotfix()
	end
end

function HotfixUtils.PostHotfix()
    local StringConst = StringConst
    if StringConst then
		StringConst:OnPostHotfix()
	end
end

function HotfixUtils.doHotfix(hotfixList)
    if hotfixList and #hotfixList > 0 then
		HotfixUtils.PreHotfix()

        for _, hotfixInfo in ipairs(hotfixList) do
            local hotfixName = hotfixInfo[1]
            local hotfixContent = hotfixInfo[2]
			local hotfixContentMD5 = MD5.sumhexa(hotfixContent)
			if HotfixUtils.hotfixInfoList[hotfixName] ~= nil and HotfixUtils.hotfixInfoList[hotfixName] == hotfixContentMD5 then --相同的hotfix已经执行过，不再重复执行
				return
			end
			HotfixUtils.hotfixInfoList[hotfixName] = hotfixContentMD5
            if not string.isEmpty(hotfixContent) then
				if hotfixInfo[3] == nil or hotfixInfo[3] >= LocalP4Version then
					local chunkName = "Hotfix/"..hotfixName
					Game.IsHotfixing = true --打开ksbc开关，允许运行时修改表格数据
					local result = xpcall(load(hotfixContent, chunkName),
						function(error)
							HotfixUtils.popHotfixErrorMsg(hotfixName,error)
						end)
					Game.IsHotfixing = false
					
					if result then
						Log.DebugFormat("[OnMsgHotfix] do client hotfix success. chunkName:%s, hotfixName:%s", chunkName, hotfixName)
					end
				else
					Log.DebugFormat("[OnMsgHotfix] do client hotfix failed, the version is outdated. chunkName:%s, hotfixName:%s", chunkName, hotfixName)
				end
			end
        end

		HotfixUtils.PostHotfix()
    end
end

--region Component Hotfix

local ComponentToEntity = ComponentToEntity
local HotfixComponentCall = HotfixComponentCall
local GetComponentCall = GetComponentCall

---HotfixComponentFunction Hotfix Component内的方法
---@param componentName string
---@param funcName string
---@param func function
function HotfixUtils.HotfixComponentFunction(componentName, funcName, func)
	if string.startsWith(funcName, "__component_") then
		HotfixComponentCall(componentName, funcName, func)
	else
		local clsList = ComponentToEntity[componentName]
		if not clsList or #clsList == 0 then
			return
		end
		for _, cls in ipairs(clsList) do
			cls[funcName] = func
		end
	end
end

---GetComponentFunction 获取Component内方法
---@param componentName string
---@param funcName string
function HotfixUtils.GetComponentFunction(componentName, funcName)
	if string.startsWith(funcName, "__component_") then
		GetComponentCall(componentName, funcName)
	else
		local clsList = ComponentToEntity[componentName]
		if not clsList or #clsList == 0 then
			return nil
		end
		return clsList[1][funcName]
	end
end

--endregion Component Hotfix

--region LuaOverriderHotfix  

function HotfixUtils.LuaOverriderHotfix(tb, key, func)
    local __inner_impl = rawget(tb,"__inner_impl")
    if __inner_impl then
        rawset(__inner_impl,key,func)
    else
        Log.Error("not a LuaOverrider class")
    end
end

--endregion LuaOverriderHotfix

function HotfixUtils.popHotfixErrorMsg(hotfixName, error)
    Log.Error(string.format("Client hotfix error :[%s], hotfix name：%s", debug.traceback(error), hotfixName))
end

return HotfixUtils
-- luacheck: pop