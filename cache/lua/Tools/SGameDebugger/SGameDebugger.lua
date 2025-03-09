require "Tools.SGameDebugger.DebugConsole"
require "Tools.SGameDebugger.SocketDebugUtils"
require("Framework.Utils.PlatformUtil")

local SGameDebugger = {}

local SGameDebuggerDefaultPort = 20001

---Start
function SGameDebugger:Start()
    if SHIPPING_MODE then
        return
    end
    self.sGameDebugger = import("TcpSocketServer")(slua.getGameInstance())
    -- self.sGameDebugger:StartServer(SGameDebuggerDefaultPort) --(int32 Port = 20001, int32 RecvBufferSize = 65536, int32 SendBufferSize = 65536,float TimeBetweenTicks = 0.06
    if PlatformUtil.IsWindows() == true then
        self:StarWithRandomPort()
    else
        self.sGameDebugger:StartServer(SGameDebuggerDefaultPort) --(int32 Port = 20001, int32 RecvBufferSize = 65536, int32 SendBufferSize = 65536,float TimeBetweenTicks = 0.06
    end
end

function SGameDebugger:Stop()
    if SHIPPING_MODE then
        return
    end
    if self.sGameDebugger ~= nil then
        self.sGameDebugger:StopServer()
        self.sGameDebugger = nil
    end
end

function SGameDebugger:SendString(clientId,msg)
    self.sGameDebugger:SendData(clientId, msg)
end

---DisconnectClient 断开指定id的Client
---@param clientId number 可以不传，默认断开所有的client
function SGameDebugger:DisconnectClient(clientId)
    if SHIPPING_MODE then
        return
    end
    self.sGameDebugger:DisconnectClient(clientId)
end

function SGameDebugger:StarWithRandomPort()
    -- windows 上使用 netstat, -- 查找监听 200xx 端口的TCP进程
    local hasFindPort = false
    local command = string.format('netstat -ano | findstr "TCP.*:200*"')
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    for i = 1, 100 do
        local port = SGameDebuggerDefaultPort + i - 1
        if self:CheckPortAvailable(result, port) then
            self.sGameDebugger:StartServer(port)
            hasFindPort = true
            break
        end
    end
end


function SGameDebugger:CheckPortAvailable(result, target_port)
    if result == "" then
        return true
    end
    -- 解析 进程名、端口号、状态、pid
    for _, port, state, _ in result:gmatch("(%w+)%s+%S+:(%d+)%s+%S+%s+(%w*)%s*(%d+)") do            
        if tonumber(port) == target_port and state ~= 'CLOSED' then
            return false
        end
    end
    return true
end

return SGameDebugger