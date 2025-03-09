---
--- Created by liuruilin@kuaishou.com
--- DateTime: 2025/1/14 15:13
---

local function CppHotfixCompare(value1, value2, epsilon, visited)
	epsilon = epsilon or 1e-5 -- 默认浮点数比较精度, 有些float进来, 精度就是很差
	visited = visited or {}   -- 用于处理循环引用

	local type1 = type(value1)
	local type2 = type(value2)
	if type1 ~= type2 then
		return false
	end

	if type1 == "number" then
		return math.abs(value1 - value2) < epsilon
	elseif type1 == "string" or type1 == "boolean" or type1 == "nil" or type1 == "function" or type1 == "thread" then
		return value1 == value2
	elseif type1 == "table" then
		local visitedKey = tostring(value1) .. tostring(value2)
		if visited[visitedKey] then
			return true -- 如果已比较过，则认为相等
		end
		visited[visitedKey] = true

		-- 比较两张表的键值对
		for k, v in pairs(value1) do
			if not CppHotfixCompare(v, value2[k], epsilon, visited) then
				return false
			end
		end

		-- 检查第二张表是否有多余的键
		for k in pairs(value2) do
			if value1[k] == nil then
				return false
			end
		end

		return true
	elseif type1 == "userdata" then
		-- 一些 ue math 类型实现了 Equals 方法, 这里先尝试调用 Equals 方法, 可以传入精度.
		if type(value1.Equals) == "function" then
			local ok, equal = xpcall(function() return value1:Equals(value2, epsilon) end, function() end)
			if ok and equal then 
				return true 
			end
		end
		return value1 == value2
	else
		return false
	end
end

local function CppHotfixToString(entryValue)
	local function serialize(value, visited)
		local valueType = type(value)
		if valueType == "nil" then
			return "nil"
		elseif valueType == "number" or valueType == "boolean" then
			return tostring(value)
		elseif valueType == "string" then
			return string.format("%q", value) -- 对字符串进行转义
		elseif valueType == "table" then
			if visited[value] then
				return string.format("<table: %s>", tostring(value))
			end
			visited[value] = true
			local parts = {}
			for k, v in pairs(value) do
				table.insert(parts, string.format("[%s] = %s", serialize(k, visited), serialize(v, visited)))
			end
			return string.format("{%s}", table.concat(parts, ", "))
		elseif valueType == "function" then
			return string.format("<function: %s>", tostring(value))
		elseif valueType == "userdata" then
			return string.format("<userdata: %s>", tostring(value))
		elseif valueType == "thread" then
			return string.format("<thread: %s>", tostring(value))
		else
			return string.format("<unknown: %s>", tostring(value))
		end
	end

	local visited = {}
	return serialize(entryValue, visited)
end

local function ErrorHandler(errorMessage)
	print(errorMessage.value, getmetatable(errorMessage.value))
	DebugLogError(CppHotfixToString(errorMessage))
	return errorMessage
end

local function MakeMessage(path, message, value, supposedValue)
	local messageTable = { path = path, message = message }
	if value or supposedValue then
		messageTable.value = value
		messageTable.supposedValue = supposedValue
		messageTable.valueType = type(value)
		messageTable.supposedValueType = type(supposedValue)
	end
	return messageTable
end

local function AssertTrue(condition, message)
	if condition ~= true then
		DebugLogError(CppHotfixToString(errorMessage))
		error(message) -- 这个Error可能被吞掉
		return false
	end
	
	return true
end

local function TestVariableInternal(getter, setter, initValue, changedValues, path)
	local ok, ret = xpcall(function()
		local currentInitValue = getter()
		if type(currentInitValue) == "userdata" and type(initValue) ~= "userdata" and getmetatable(currentInitValue) == nil then
			DebugLogWarning(path .. " is userdata without metatable.")
			return
		end
		AssertTrue(CppHotfixCompare(getter(), initValue), MakeMessage(path, "not equal init value", getter(), initValue))
		for _, value in pairs(changedValues) do
			setter(value)
			AssertTrue(CppHotfixCompare(getter(), value), MakeMessage(path, "not equal changed value", getter(), value))
		end
		
		-- 静态变量得设置回去
		if (changedValues and #changedValues > 0) then
			setter(initValue)
			AssertTrue(CppHotfixCompare(getter(), initValue), MakeMessage(path, "set back init value failed", getter(), initValue))
		end
	end, ErrorHandler)
	
	-- 不管成不成, 都尽量把值设置回初始值
	--if (changedValues and #changedValues > 0) then
	--	xpcall(setter(initValue), function() end)
	--end
	
	if ok then
		print("TestVariable passed: " .. path, "initValue: " .. tostring(initValue), "changedValues: " .. CppHotfixToString(changedValues))
	else
		DebugLogError("TestVariable failed: " .. path, "initValue: " .. tostring(initValue), "changedValues: " .. CppHotfixToString(changedValues) .. "error message: " .. CppHotfixToString(ret))
	end
end 

--- test static variable get/set
function TestStaticVariable(classPathUnderCpp, variableName, initValue, changedValues)
	local pathUnderCpp = classPathUnderCpp .. "." .. variableName
	local cppScope = cpp[pathUnderCpp] -- 必不为空, 但是这就有点抽象, 怎么可能必不为空呢? 因为根本没去cpp里检查!!!
	
	TestVariableInternal(
		function() return cppScope:GetValue() end,
		function(value) cppScope:SetValue(value) end,
		initValue, changedValues, pathUnderCpp
	)
end

--- test class/struct member variable get/set
function TestMemberVariable(classPathUnderCpp, variableName, initValue, changedValues)
	local variablePath = classPathUnderCpp .. "." .. variableName
	
	-- 创建对象
	local cppObj = cpp[classPathUnderCpp]() -- type: ordinary instance
	
	-- 对象是否已经创建出来了
	AssertTrue(cppObj ~= nil, MakeMessage(classPathUnderCpp, "parent of variable not found"))
	
	TestVariableInternal(
		function() return cppObj[variableName] end,
		function(value) cppObj[variableName] = value end,
		initValue, changedValues, variablePath
	)
end

--- 修改指针指向, 需要两个变量, 只测Global/Static
--- 1. 测试两个指针值不相等.
--- 2. 将一个指针指向另一个指针的指向的值.
--- 3. 测试两个指针指向同一个地址, 修改一个指针的值内部的值, 另一个也同样修改.
function TestStaticPointerVariable_ChangePointer(classPathUnderCpp, variableName1, variableName2, innerVariableName, changeValue)
	local path1 = classPathUnderCpp .. "." .. variableName1
	local path2 = classPathUnderCpp .. "." .. variableName2
	local cppScope1 = cpp[path1]
	local cppScope2 = cpp[path2]
	AssertTrue(CppHotfixCompare(cppScope1:GetValue(), cppScope2:GetValue()) == false, MakeMessage(path1, "pointer init value equal!"))
	AssertTrue(CppHotfixCompare(cppScope1:GetValue()[innerVariableName], cppScope2:GetValue()[innerVariableName]) == false, MakeMessage(path1, "pointer init inner value equal!"))
	cppScope1:SetValue(cppScope2:GetValue())
	
	cppScope1:GetValue()[innerVariableName] = changeValue
	local value1 = cppScope1:GetValue()[innerVariableName]
	local value2 = cppScope2:GetValue()[innerVariableName]
	AssertTrue(CppHotfixCompare(value1, value2) == true, MakeMessage(path1, "pointer changed value not equal!", value1, value2))
	AssertTrue(CppHotfixCompare(value2, changeValue) == true, MakeMessage(path1, "pointer changed value not equal!", value2, changeValue))
end

-- Todo: test readonly variable (liuruilin@kuaishou.com)

local function GetFunction(parentPathUnderCpp, functionName, isStatic)
	local functionPath = parentPathUnderCpp .. "." .. functionName
	local func = cpp[functionPath]
	if not isStatic then
		local obj = cpp[parentPathUnderCpp]()
		AssertTrue(obj ~= nil, MakeMessage(parentPathUnderCpp, "parent of function not found"))
		func = function(...) return obj[functionName](obj, ...) end
	end
	
	AssertTrue(func ~= nil, MakeMessage(functionPath, "function not found"))
	
	return func
end

--- test function parameters call
--- 单参数, 单返回, 参数 == 返回值
function TestFunctionCall(parentPathUnderCpp, functionName, isStatic, argValue)
	local functionPath = parentPathUnderCpp .. "." .. functionName
	local ok, result = xpcall(function()
		local func = GetFunction(parentPathUnderCpp, functionName, isStatic)

		local result, ref_out = func(argValue)
		if string.find(functionName, "_Ref_") and not string.find(functionName, "_Const_Ref") then
			print("ref_out", ref_out, "ref_in_arg", argValue)
			AssertTrue(CppHotfixCompare(ref_out, argValue), MakeMessage(functionPath, "function ref out not equal", result, argValue))
		end
		AssertTrue(CppHotfixCompare(result, argValue), MakeMessage(functionPath, "function result not equal", result, argValue))
	end, ErrorHandler)

	if ok then
		print("TestFunctionCall passed: " .. functionPath, "argValue: " .. CppHotfixToString(argValue))
	else
		DebugLogError(
			"TestFunctionCall failed: " .. functionPath,
			"argValue: " .. CppHotfixToString(argValue),
			"error message: " .. CppHotfixToString(result)
		)
	end
end

--- test function 'before' inject 
function TestFunctionInject(parentPathUnderCpp, functionName, injectFuncName, injectType, isStatic, defaultValue, changedValues)
	local functionPath = parentPathUnderCpp .. "." .. functionName
	local ok, result = xpcall(function()
		local func = GetFunction(parentPathUnderCpp, functionName, isStatic)
		local hotfixClassName = "cpp_" .. parentPathUnderCpp
		injectFuncName = injectFuncName .. "_" .. injectType

		for _, changedValue in pairs(changedValues) do
			-- break inject
			slua.addFunctionHotfix(hotfixClassName, injectFuncName, function(inArg)
				AssertTrue(CppHotfixCompare(inArg, changedValue), MakeMessage(functionPath, "function break inject inArg not equal", inArg, changedValue))
				return true, inArg
			end)
			local result = func(changedValue)
			AssertTrue(CppHotfixCompare(result, changedValue), MakeMessage(functionPath, "function break inject result not equal", result, changedValue))

			-- no break inject
			slua.addFunctionHotfix(hotfixClassName, injectFuncName, function(inArg)
				return false, changedValue
			end)
			result = func(defaultValue)
			AssertTrue(CppHotfixCompare(result, defaultValue), MakeMessage(functionPath, "function no break inject result not equal", result, changedValue))
		end

		slua.removeFunctionHotfix(parentPathUnderCpp, injectFuncName)
		TestFunctionCall(parentPathUnderCpp, functionName, isStatic, defaultValue)
	end, ErrorHandler)
	
	if ok then
		print("TestFunctionInject passed: " .. functionPath, "argValue: ")
	else
		DebugLogError(
			"TestFunctionInject failed: " .. functionPath ..
			"error message: " .. CppHotfixToString(result)
		)
	end
end