--[[
	通过cpp.xxx.xxx调用cpp hotfix反射内容
	在鹏哥的基础上做了一些修改 tangzhangpeng@kuaishou.com, liuruilin@kuaishou.com
]]

local makeCppScopeTable

local CallableMetaTable = {
	-- display.
	__tostring = function(inst)
		return '< cpp hotfix scope: ' .. inst._fullPath_ .. ' >'
	end,

	-- get table of fullpath of hotfix cpp object.
	__index = function(inst, key)
		key = inst._fullPath_ .. '.' .. key -- inst._fullPath_ 必须不为空, 空就死掉~
		local newScope = makeCppScopeTable(key)
		rawset(inst, key, newScope)
		return newScope
	end,

	-- construct the bound cpp object, or call the bound cpp function.
	__call = function(inst, ...)
		return slua.callGlobalFunction(inst._fullPath_, table.unpack({...}))
	end,
}

--- 静态/全局变量的值-获取
local GetValue = function(self)
	return slua.callGlobalFunction(self._fullPath_ .. ".GetValue")
end

--- 静态/全局变量的值-设置
local SetValue = function(self, value)
	slua.setGlobalVariable(self._fullPath_, value)
end

makeCppScopeTable = function(scopePath)
	return setmetatable({
		_fullPath_ = scopePath, -- 这是个全路径, 即cpp.xxx.xxx.xxx, 越内层, 这个越长
		GetValue = GetValue, 
		SetValue = SetValue
	}, CallableMetaTable)
end

cpp = makeCppScopeTable("cpp") -- root


-- 提供一个函数版本，方便直接调用
function GetCppGlobalVariable(...)
	local keys = {...}
	local current = cpp
	for _, key in ipairs(keys) do
		current = current[key]
	end

	return current:GetValue()
end

function SetCppGlobalVariable(value, ...)
	local keys = {...}
	local current = cpp
	for _, key in ipairs(keys) do
		current = current[key]
	end

	current:SetValue(value)
end