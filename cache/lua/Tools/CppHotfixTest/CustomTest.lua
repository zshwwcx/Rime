---
--- Created by liuruilin@kuaishou.com.
--- DateTime: 2025/1/14 15:10
---

local tname = "int32" -- 这是注册元表时用的名字
local reg = debug.getregistry()
for k, v in pairs(reg) do
	print(k, v)
end

local AvatarModelLib = require "Data.Config.Model.AvatarModelLib"
local a = AvatarModelLib[1]

--local cls = import("CppHotfixAutomationTest") 
--local test = cpp["UCppHotfixAutomationTest"]()
--local result = test:GetInt2()
--print(result)

--TestStaticVariable("FTestField", "Y", 1, {2147483647, -2147483648})
--TestMemberVariable("FTestField", "X", 1, {2147483647, -2147483648})
--TestFunctionReturn("FTestField", "TestFunc", false, 2)