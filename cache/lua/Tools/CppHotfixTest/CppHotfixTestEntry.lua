---
--- Created by liuruilin@kuaishou.com.
--- DateTime: 2025/1/14 15:10
---

-- 会报一个Error, 引用测试结果.
--xpcall(function()
--	package.cpath = package.cpath .. ';C:/Users/Administrator/AppData/Roaming/JetBrains/PyCharmCE2024.3/plugins/EmmyLua/debugger/emmy/windows/x64/?.dll'
--	local dbg = require('emmy_core')
--	dbg.tcpConnect('localhost', 9966)
--end, function() end)

require "Framework.C7Common.C7Log"
require "Framework.Library.CppReflection"
require "Tools.CppHotfixTest.TestFramework"


local TextureClass = import("Texture2D")
print(TextureClass)
local Texture = TextureClass()
print(Texture)

-- Test
require("Tools.CppHotfixTest.CustomTest")
require("Tools.CppHotfixTest.AutomationTest")
return true
