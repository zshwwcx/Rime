local string_format = string.format
local string_sub = string.sub
local patchFlag = "patch:"

local string_starts = function(str, start)
    if str == nil or start == nil then
        return false
    end
    return str:sub(1, #start) == start
end

function OnSocketConnected(cid, address)
    local _ = DEBUG and Log.DebugFormat("SGameDebugger onSocketConnected, ClientID:%d  ,Address:%s",cid,address)
end

function OnSocketClose(cid)
    local _ = DEBUG and Log.DebugFormat("SGameDebugger onDebugConnectionClose-------------------------------%d", cid)
    local debugClient = Game.debug_info[cid]
    if debugClient ~= nil then
        debugClient.co = nil
        debugClient._local = nil
        debugClient._output_str = nil
    end
    Game.debug_info[cid] = nil
end

--暂时不支持，先注释了
--function refresh()
--    local _ = DEBUG and Log.Debug("SGameDebugger begin refresh client")
--    require("Framework.Utils.ScriptRefresh").RefreshAllScript()
--    local _ = DEBUG and Log.Debug("SGameDebugger refresh client finish")
--    return "refresh"
--end

local function doPatch(cmd)
    local patchCmd = string_sub(cmd, #patchFlag+1)
    local res, msg = load(patchCmd)
    if res == nil then
        return "patch fail "..msg
    end
    local ok,errorMsg = pcall(res)
    if not ok then
        return errorMsg
    end
    return "patch success"
end



local function onDebugCmd(cid, cmd)
    Game.debug_info = Game.debug_info or {}
    Game.debug_shortcuts = Game.debug_shortcuts or {}
    Game.debug_preimport_modules = Game.debug_preimport_modules or setmetatable(Game.debug_shortcuts, {["__index"] = _G})
    Game.debug_terminator = "<end>"
    local _ = DEBUG and Log.DebugFormat("SGameDebugger clientId:%d  logic.on_debug_cmd-------------------%s",cid,cmd)
    if Game.debug_info[cid] == nil then
        Game.debug_info[cid] = {}
        Game.debug_info[cid]._local = {}
        Game.debug_info[cid]._output_str = ""

        setmetatable(
            Game.debug_info[cid]._local,
            {
                ["__index"] = Game.debug_preimport_modules,
                ["__mode"] = "kv"
            }
        )
        Game.debug_info[cid].co = function()
            local oldPrint = _G["print"]
            local function feedback_print(...)
                for i = 1, select("#", ...) do
                    local v = select(i, ...)
                    Game.debug_info[cid]._output_str = Game.debug_info[cid]._output_str .. tostring(v) .. "\n"
                end
            end
            local function debug_print(...)
                oldPrint(...)
                feedback_print(...)
            end
            local function error_print(...)
                feedback_print(...)
            end

            local input = Game.debug_info[cid].cmd
            -- 先尝试看看输入的语句是否能赋值给临时变量，若能，用inspect打印，如输入的是 a
            local res, msg = load(string_format([[
                    local inspect = require("Tools.SGameDebugger.Inspect")
                    local _ENV = Game.debug_info[%s]._local
                    local temp = %s
                    if temp ~= nil then
                        if type(temp) == "userdata" then
                            temp = getmetatable(temp)
                        end
                        print(inspect(temp, {depth = 1}))
                    end
                ]], cid,input),"DebugConsole_Assignment")
            if res ~= nil then
                rawset(_G, "print", debug_print)
                xpcall(res, function(errormsg) errormsg = debug.traceback(errormsg,3) error_print(errormsg) return errormsg end)
                Game.debug_info[cid]._output_str = Game.debug_info[cid]._output_str ..Game.debug_terminator
                rawset(_G, "print", oldPrint)
            else
                -- 如果上面的假设不成立，就尝试直接执行这条语句，并拿到返回值，如输入的是 a={}
                res, msg = load(string_format([[
                        local _ENV = Game.debug_info[%s]._local
                            %s
                        local debugId=1
                        while true do
                            local name, value = debug.getlocal(1, debugId)
                            if not name then break end
                            rawset(Game.debug_info[%s], name, value)
                            debugId = debugId + 1
                        end
                        ]], cid, input, cid),"DebugConsole_Execute")
                if res ~= nil then
                    rawset(_G, "print", debug_print)
                    xpcall(res, function(errormsg) errormsg = debug.traceback(errormsg,3) error_print(errormsg) return errormsg end)
                    Game.debug_info[cid]._output_str = Game.debug_info[cid]._output_str ..Game.debug_terminator
                    rawset(_G, "print", oldPrint)
                end
            end
            return msg
        end
    end

    --if cmd=="refresh()" then   C7不支持，先屏蔽了
    --    refresh()
    --    Game.SGameDebugger:SendString(cid, "refresh finish"..Game.debug_terminator)
    --    return
    --end
    if string_starts(cmd, patchFlag) then
        local ret = doPatch(cmd)
        local _ = DEBUG and Log.DebugFormat("patch %s",ret)
        Game.SGameDebugger:SendString(cid, ret..Game.debug_terminator)
        return
    end

    Game.debug_info[cid].cmd = cmd
    Game.debug_info[cid]._output_str = ""
    local output = Game.debug_info[cid].co()
    if output then
        Game.SGameDebugger:SendString(cid, output..Game.debug_terminator)
        return
    end
    Game.SGameDebugger:SendString(cid, Game.debug_info[cid]._output_str)
end

function OnSocketData(cid, msg)
    onDebugCmd(cid, msg)
 end