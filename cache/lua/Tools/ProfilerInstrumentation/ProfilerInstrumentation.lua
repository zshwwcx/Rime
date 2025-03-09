local ProfilerInstrumentation = DefineClass("ProfilerInstrumentation")

local Stack = require("Framework.Library.Stack")
local ProfilerInstrumentationConfig = require("Tools.ProfilerInstrumentation.ProfilerInstrumentationConfig")
local KismetSystemLibrary = import("KismetSystemLibrary")
local FLuaStats = import("ProfilerInstrumentation")   -- luacheck: ignore
local ULLFunc = import("LowLevelFunctions")
local statsEnum = {
    'STATS_MISC',
    'STATS_MESSAGE',
    'STATS_PROPERTY',
    'STATS_VOLATILE_UPDATE',
    'STATS_VOLATILE_CONTROLLED_BY',
    'STATS_ENTER_SPACE',
    'STATS_LEAVE_SPACE',
    'STATS_CLIENT_HOTFIX',
    'STATS_SCENE_MESSAGE',
    'STATS_DESTROY_ENTITY',
    'STATS_CREATE_ENTITY',
    'STATS_CALLBACK_MESSAGE',
    'STATS_CREATE_ENTITY_BRIEF',
    'STATS_ENTITY_TO_BRIEF',
    'STATS_BRIEF_TO_ENTITY',
    'STATS_TRACEROUTE'
}

QualityLevel = { -- luacheck: ignore
    low = 0,
    medium = 1,
    high = 2,
    epic = 3,
    cinematic = 4
}

-- rpc 性能统计开关，打开后会统计每次rpc调用的时间
ProfilerInstrumentation.RPC_PERFORMANCE_ANALYSIS = false
ProfilerInstrumentation.performanceData = {}
ProfilerInstrumentation.RpcCount = 0

if not SHIPPING_MODE then

    function ProfilerInstrumentation:ctor()
        self.qualityLevel = 1
        self.recordOvertimeData = {}
        self.instrumentMap = {}
        self.instrumentStack = Stack.new()
        self.instrumentAdditionInfoStack = Stack.new()

        self.canRecord = false

        self.rpcCallStack = {}  -- 记录当前调用的rpc
        self.rpcCallFuncStack = {}  -- 记录当前调用的rpc的函数

        if slua.getGameInstance() then
            --self.statsStartCB = slua.createDelegate(function(statsType)
            --    self:OnStatsStart(statsType)
            --end)
            --self.statsEndCB = slua.createDelegate(function()
            --    self:OnStatsEnd()
            --end)
            self.scriptCallStartCB = slua.createDelegate(function(statsType, funcName, length)
                self:OnScriptCallStart(statsType, funcName, length)
            end)
            self.scriptCallEndCB = slua.createDelegate(function()
                self:OnScriptCallEnd()
            end)
            import("DoraSDK").BindRpcSTATCallBack(self.scriptCallStartCB, self.scriptCallEndCB)
        end
    end

    function ProfilerInstrumentation:ResetData()
        table.clear(self.recordOvertimeData)
    end

    ---Create 创建插装计数器
    ---@param statName string
    ---@param statDesc string 可以为空
    function ProfilerInstrumentation:CreateInstrument(statName, addition)
        if self.instrumentMap[statName] then
            Log.ErrorFormat("Profiler instrument already exist : %s", statName)
            return
        end
        FLuaStats.CycleCounterCreate(statName)
        local instrumentIns = { StatName = statName,Addition = addition}
        setmetatable(instrumentIns, { __close = function(value)
            --绑定__close元方法，插桩处方法结束时自动调用Stop
            self:Stop(value.StatName, value.Addition)
        end })
        self.instrumentMap[statName] = { 0, instrumentIns }
    end

    ---Start 插桩Profiler开始统计
    ---@param statName string
    ---@param additionInfo string 附加信息
    ---@param autoStop boolean 是否在方法结束的时候做保护处理(自动调用Stop)(默认为true,除非确定调用者方法执行过程中不会报错中断)
    ---@return table 请在调用处使用local xx<close>变量持有返回值
    function ProfilerInstrumentation:Start(statName, additionInfo, autoStop)
        if not self.canRecord then
            return
        end
        if self.instrumentMap[statName] == nil then
            self:CreateInstrument(statName, additionInfo)
        end
        local instrument = self.instrumentMap[statName]
        instrument[1] = instrument[1] + 1
        self.instrumentStack:Push(statName)
        FLuaStats.CycleCounterStart(statName)
        if autoStop ~= false then
            return instrument[2]
        end
    end

    ---Stop 插桩Profiler结束统计
    ---@param statName string
    function ProfilerInstrumentation:Stop(statName, addition)
        if not self.canRecord or self.instrumentMap[statName] == nil or self.instrumentMap[statName][1] == 0 then
            return
        end
        local tmpStatName = self.instrumentStack:Top()
        self.instrumentStack:Pop()
        self.instrumentMap[tmpStatName][1] = self.instrumentMap[tmpStatName][1] - 1

        local result, timeConsuming = false, 0 
        result,timeConsuming = FLuaStats.CycleCounterStop(timeConsuming)
        if not result then
            return
        end

        local curFrameCount = KismetSystemLibrary.GetFrameCount()

        if timeConsuming > ProfilerInstrumentationConfig[statName].Threshold[self.qualityLevel] then
            if not self.recordOvertimeData[curFrameCount] then
                self.recordOvertimeData[curFrameCount] = {LevelId = Game.LevelManager.GetCurrentLevelID() or -1,RecordData = {}}
            end
            local recordData = self.recordOvertimeData[curFrameCount].RecordData
            recordData[#recordData + 1] = {statName,timeConsuming,addition,Game.LevelManager.GetCurrentLevelID() or -1}
        end
    end

    function ProfilerInstrumentation:OpenCounter()
        if self.canRecord then
            return
        end
        self.qualityLevel = Game.SettingsManager:GetQualityLevel() + 1
        if self.qualityLevel < 1 then
            self.qualityLevel = QualityLevel.low + 1
        end
        self.canRecord = true
        self:ResetData()
    end

    function ProfilerInstrumentation:CloseCounter()
        if not self.canRecord then
            return
        end
        FLuaStats.AllCounterStop()
        self.canRecord = false

        local saveData = "frameCount,LevelId,,,,".."DeviceInfo:"..FLuaStats.GetDeviceProfileName()..",CPU Info:"..FLuaStats.GetCPUInfo()
        if Game.me then
            saveData = saveData .. ", PlayerName:"..Game.me.Name .. ", PlayerID:"..Game.me.eid
        end
        local keys = table.keys(self.recordOvertimeData)
        table.sort(keys)
        for _, frameCount in pairs(keys) do
            local frameRecordData = self.recordOvertimeData[frameCount].RecordData
            saveData = saveData .. "\n" .. tostring(frameCount) .. "," .. self.recordOvertimeData[frameCount].LevelId ..","
            for _, stateRecordData in pairs(frameRecordData) do
                if stateRecordData[3] then
                    saveData = saveData .. (stateRecordData[1].."_"..stateRecordData[3]) .. "," .. tostring(stateRecordData[2]) .. ","
                else
                    saveData = saveData .. (stateRecordData[1]) .. "," .. tostring(stateRecordData[2]) .. ","
                end
            end
        end

        import("UIFunctionLibrary").SaveStringToFile('profiler-' .. os.date("%Y.%m.%d-%H.%M.%S", os.time()) .. '.csv', saveData)
        self:ResetData()
    end

    --region rpc监控回调
    function ProfilerInstrumentation:OnStatsStart(statsType)
        local statName = statsEnum[statsType + 1]
        table.insert(self.rpcCallStack, statsType)
        self:Start(statName,false)
    end

    function ProfilerInstrumentation:OnStatsEnd()
        local statName = statsEnum[self.rpcCallStack[#self.rpcCallStack] + 1]
        table.remove(self.rpcCallStack, #self.rpcCallStack)
        self:Stop(statName)
    end

    function ProfilerInstrumentation:OnScriptCallStart(statsType, funcName, length)
		ProfilerInstrumentation.RpcCount = ProfilerInstrumentation.RpcCount + 1
		local startTime = ULLFunc.GetGameMicrosecond()
        table.insert(self.rpcCallFuncStack, { statsType, funcName, startTime })
        local statName = statsEnum[self.rpcCallFuncStack[#self.rpcCallFuncStack][1] + 1]
        self:Start(statName, funcName,false)
    end

    function ProfilerInstrumentation:OnScriptCallEnd()
        local statsType = self.rpcCallFuncStack[#self.rpcCallFuncStack][1]
        local funcName = self.rpcCallFuncStack[#self.rpcCallFuncStack][2]
		local startTime = self.rpcCallFuncStack[#self.rpcCallFuncStack][3]
        table.remove(self.rpcCallFuncStack, #self.rpcCallFuncStack)
        self:Stop(statsEnum[statsType + 1], funcName)

		if ProfilerInstrumentation.RPC_PERFORMANCE_ANALYSIS then
			local endTime = ULLFunc.GetGameMicrosecond()
			ProfilerInstrumentation.AddPerformanceData(funcName, (endTime-startTime) / 1000.0)
		end
    end

	-- 毫秒
	function ProfilerInstrumentation.AddPerformanceData(funcName, t)
		if Game.GameLoopManagerV2:GetCurGameLoopStage() == Game.GameLoopManagerV2.EGameStageType.Loading then
			return
		end
		local performanceData = ProfilerInstrumentation.performanceData
		if not performanceData[funcName] then
			performanceData[funcName] = {}
		end
		table.insert(performanceData[funcName], t)
	end
	
	function ProfilerInstrumentation.SavePerformanceData()
		local dataStr = "RpcFile,RpcFunc,CallCount,TotalTime(ms),AverageTime(ms),MaxTime(ms)\n"
		for funcName, data in pairs(ProfilerInstrumentation.performanceData) do
			local count = #data
			local totalT = 0
			local maxT = 0
			for _, t in ipairs(data) do
				totalT = totalT + t
				if t > maxT then
					maxT = t
				end
			end
			local func = nil
			if Game.me then
				func = Game.me[funcName]
			end
			local Account = Game.NetworkManager.GetAccountEntity()
			if not func and Account then
				func = Account[funcName]
			end
			local funcFile = ""
			if func then
				local info = debug.getinfo(func, "Sl")
				funcFile = string.format("%s:%s", info.short_src, info.linedefined)
			end
			local info = string.format("%s,%s,%s,%s,%s,%s\n", funcFile, funcName, count, totalT, totalT/count, maxT)
			dataStr = dataStr .. info
		end
		local localP4Version = import("SubsystemBlueprintLibrary").GetEngineSubsystem(import("PakUpdateSubsystem")):GetLocalP4Version()	--客户端当前资源版本号
		local fileName =  string.format("rpc_profiling_%d_%s.csv", localP4Version, os.date("%Y_%m_%d_%H_%M_%S"))
		local path = import("BlueprintPathsLibrary").ProfilingDir().. fileName
		path = import("LuaFunctionLibrary").ConvertToAbsolutePathForExternalAppForRead(path)
		local file = io.open(path, "w")
		if file then
			file:write(dataStr)
			file:close()
		else
			-- 找不到文件，尝试创建目录
			local profilePath = import("BlueprintPathsLibrary").ProfilingDir()
			profilePath = import("LuaFunctionLibrary").ConvertToAbsolutePathForExternalAppForRead(profilePath)
			import("LuaFunctionLibrary").MakeDirectory(profilePath, false)
			file = io.open(path, "w")
			if file then
				file:write(dataStr)
				file:close()
			end
		end
		ProfilerInstrumentation.SendPerformanceData(dataStr, fileName)
	end

	function ProfilerInstrumentation.SendPerformanceData(dataStr, fileName)
		local EPropertyClass = import("EPropertyClass")
		local heads = slua.Map(EPropertyClass.Str, EPropertyClass.Str)
		heads:Add("X-TOKEN", "NRV2CSVXqQm3N7WHfeL5JpGM")
		heads:Add("X-OVERWRITE", "1")
		heads:Add("X-FILENAME", fileName)
		heads:Add("Content-Type", "text/plain")
		local callback = slua.createDelegate( function(result, content)
			Log.Debug("EventSystem performance data upload ", result and "success"  or "failed", content)
		end)
		import("C7FunctionLibrary").HttpPost("172.31.141.230:8008/engine_file_upload", heads, dataStr, callback)
	end
	
	function ProfilerInstrumentation.GetRpcCountAndClear()
		local count = ProfilerInstrumentation.RpcCount
		ProfilerInstrumentation.RpcCount = 0
		return count
	end
    
    --endregion
else
    function ProfilerInstrumentation:ctor() end
    
    function ProfilerInstrumentation:CreateInstrument() end
    
    function ProfilerInstrumentation:Start() end
    
    function ProfilerInstrumentation:Stop() end
    
    function ProfilerInstrumentation:OpenCounter() end
    
    function ProfilerInstrumentation:CloseCounter() end
    
    function ProfilerInstrumentation:OnStatsStart(statsType) end
    
    function ProfilerInstrumentation:OnStatsEnd() end
    
    function ProfilerInstrumentation:OnScriptCallStart(statsType, funcName, length) end
    
    function ProfilerInstrumentation:OnScriptCallEnd() end
end

return ProfilerInstrumentation