SDKPrefix = SDKPrefix or "Framework.DoraSDK.SDK."

LuaCommonPrefix = LuaCommonPrefix or  "Framework.Utils.LuaCommon."

USE_LUA_CLOGGER = true



--次序不能调整
require "Framework.C7Common.CommonDefine"
require "Framework.C7Common.C7Log"

require("Framework.DoraSDK.Require")
require("Framework.Entity.Require")

require(LuaCommonPrefix.."Utils.Require")
require(LuaCommonPrefix.."Managers.Require")





