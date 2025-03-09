-- luacheck: push ignore
local UELogLevel = 
{
    Fatal = 1,
    Error = 2,
    Warning = 3,
    Log = 5,
}
-- luacheck: pop

local UELoger = import("Loger")
local WriteLog = UELoger.WriteLog

--init log levels
UELoger.SetGameLogLevel(UELogLevel.Log)
UELoger.SetLogOnScreenLevel(UELogLevel.Error)
UELoger.SetThirdPartyLogLevel(UELogLevel.Error)

function DebugLog(msg)
    WriteLog(UELogLevel.Log, msg)
end

function DebugInfo(msg)
    WriteLog(UELogLevel.Log, 'Info: '..msg)
end

function DebugLogWarning(msg)
    WriteLog(UELogLevel.Warning, msg)
end

function DebugLogError(msg)
    WriteLog(UELogLevel.Error, debug.traceback(msg, 3))
end

function DebugLogFatal(msg)
    WriteLog(UELogLevel.Error, 'Fatal: '..debug.traceback(msg, 3))
end

function ReleaseLog(msg)
    WriteLog(UELogLevel.Log, msg)
end

function ReleaseLogWarning(msg)
    WriteLog(UELogLevel.Warning, msg)
end

function ReleaseLogError(msg)
    WriteLog(UELogLevel.Error, msg)
end

if USE_LUA_CLOGGER then
    DebugLog = LuaCLogger.Log
    DebugInfo = LuaCLogger.Log
    DebugLogWarning = LuaCLogger.Warn
    DebugLogError = LuaCLogger.Error
    DebugLogFatal = LuaCLogger.Fatal

    ReleaseLog = LuaCLogger.Log
    ReleaseLogWarning = LuaCLogger.Warn
    ReleaseLogError = LuaCLogger.Error
end 