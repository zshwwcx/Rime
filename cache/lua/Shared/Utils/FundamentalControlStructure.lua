---
--- Created by sunya.
---
---基础的逻辑控制代码工具, 解决共享、抢占等控制权处理问题
---
---

-- 一个地方获取控制权, 必须要等待其放弃控制权, 其他地方才能操作, 否则报错, 排查逻辑设计错误
-- 在获取和释放的时候, 可以进行回调执行
-- 用法: 用于底层共用逻辑有抢占性时, 如果怕被别人无故刷掉, 用这个结构可以进行报错处理

function MethodFunctor(func_name, obj)
	return function(...)
		return obj[func_name](obj, ...)
	end
end

DefineClass("ObtainAndRevertHolder")

function ObtainAndRevertHolder:ctor()
	self:ResetForNextCycleUsed()
end 

function ObtainAndRevertHolder:dtor()
	self:ResetForNextCycleUsed()
end

function ObtainAndRevertHolder:ResetForNextCycleUsed()
	self._callbackWhenObtain = nil
	self._callbackWhenReset = nil
	self._callbackWhenRevert = nil
	self._needRevertValue = nil
	self._initHoldValue = nil
	self._currentHoldValue = nil
	self._isObtained = false
end

function ObtainAndRevertHolder:InitFromCycleUsed(initHoldValue, callbackWhenResetFunctor, callWhenObtainFunctor, callbackWhenRevertFunctor)
	-- 是callable的形式就行
	self._callbackWhenReset = callbackWhenResetFunctor
	self._callbackWhenObtain = callWhenObtainFunctor
	self._callbackWhenRevert = callbackWhenRevertFunctor
	self._initHoldValue = initHoldValue
	self._currentHoldValue = initHoldValue
	self._isObtained = false
	
end

function ObtainAndRevertHolder:Reset()
	self._isObtained = false
	self._needRevertValue = nil
	self._currentHoldValue = self._initHoldValue
	if self._callbackWhenReset ~= nil then
		self._callbackWhenReset(self._currentHoldValue)
	end
end

function ObtainAndRevertHolder:ObtainValue(new_value)
	-- 要梳理逻辑, 看之前有哪个地方进行抢占了, 但是没有释放
	self._needRevertValue = self._currentHoldValue
	self._isObtained = true
	self._currentHoldValue = new_value
	if self._callbackWhenObtain ~= nil then
		self._callbackWhenObtain(self._currentHoldValue)
	end
	return true
end


function ObtainAndRevertHolder:RevertValue()
	self._currentHoldValue = self._needRevertValue
	self._needRevertValue = nil
	self._isObtained = false
	if self._callbackWhenRevert ~= nil then
		self._callbackWhenRevert(self._currentHoldValue)
	end
	
	return true
end



-- 三优先级的抢占控制结构, 业务逻辑最多三个层级, 用这个简单用用。 要再自由定制化就真的要做优先级heap了
DefineClass('ThreePriorityValve')
local NO_PRIORITY = 0
local LOW_PRIORITY = 10
local MIDDLE_PRIORITY = 20
local HIGH_PRIORITY = 30

function ThreePriorityValve:ctor()
	self:ResetForNextCycleUsed()
end

function ThreePriorityValve:dtor()
	self:ResetForNextCycleUsed()
end

function ThreePriorityValve:ResetForNextCycleUsed()
	self._initHoldValue = nil
	self._lowHoldValue = nil
	self._middleHoldValue = nil
	self._highHoldValue = nil
	self._callbackWhenPriorityChosen = nil
	self._callbackWhenNoPriorityChosen = nil
	self._currentPriority = NO_PRIORITY

end

function ThreePriorityValve:InitFromCycleUsed(initHoldValue, callbackWhenNoPriorityChosenFunctor, callbackWhenPriorityChosenFunctor)
	self._initHoldValue = initHoldValue
	self._callbackWhenPriorityChosen = callbackWhenPriorityChosenFunctor
	self._callbackWhenNoPriorityChosen = callbackWhenNoPriorityChosenFunctor
	
end

function ThreePriorityValve:Reset()
	self._lowHoldValue = nil
	self._middleHoldValue = nil
	self._highHoldValue = nil
	self._currentPriority = NO_PRIORITY
	if self._callbackWhenNoPriorityChosen ~= nil then
		self._callbackWhenNoPriorityChosen(self._initHoldValue)
	end
end

function ThreePriorityValve:doChoosePriority()
	if self._highHoldValue ~= nil then
		if self._currentPriority == HIGH_PRIORITY then
			return
		end
			
		self._currentPriority = HIGH_PRIORITY
		
		if self._callbackWhenPriorityChosen ~= nil then
			self._callbackWhenPriorityChosen(self._highHoldValue)
		end
		return
	end

	if self._middleHoldValue ~= nil then
		if self._currentPriority == MIDDLE_PRIORITY then
			return
		end

		self._currentPriority = MIDDLE_PRIORITY

		if self._callbackWhenPriorityChosen ~= nil then
			self._callbackWhenPriorityChosen(self._middleHoldValue)
		end
		return
	end

	if self._lowHoldValue ~= nil then
		if self._currentPriority == LOW_PRIORITY then
			return
		end

		self._currentPriority = LOW_PRIORITY

		if self._callbackWhenPriorityChosen ~= nil then
			self._callbackWhenPriorityChosen(self._lowHoldValue)
		end
		return
	end

	if self._currentPriority == NO_PRIORITY then
		return
	end
	
	self._currentPriority = NO_PRIORITY
	if self._callbackWhenNoPriorityChosen ~= nil then
		self._callbackWhenNoPriorityChosen(self._initHoldValue)
	end
end

function ThreePriorityValve:ObtainLowPriority(obtainValue)
	self._lowHoldValue = obtainValue
	self:doChoosePriority()
end

function ThreePriorityValve:ReleaseLowPriority()
	self._lowHoldValue = nil
	self:doChoosePriority()
end

function ThreePriorityValve:ObtainMiddlePriority(obtainValue)
	self._middleHoldValue = obtainValue
	self:doChoosePriority()
end

function ThreePriorityValve:ReleaseMiddlePriority()
	self._middleHoldValue = nil
	self:doChoosePriority()
end

function ThreePriorityValve:ObtainHighPriority(obtainValue)
	self._highHoldValue = obtainValue
	self:doChoosePriority()
end

function ThreePriorityValve:ReleaseHighPriority()
	self._highHoldValue = nil
	self:doChoosePriority()
end


-- 进行抢占控制, 要用token进行抢占和释放, 强约束底层共用接口
-- token可以用来追踪逻辑源
DefineClass('TokenPossessionHolder')
local INCREASED_TOKEN_FOR_TPH = 1
function TokenPossessionHolder:ctor() 
	self.__currentToken = nil
	self._callbackWhenObtain = nil
	self._callbackWhenRelease = nil
	
end

function TokenPossessionHolder:dtor()
	self:ResetForNextCycleUsed()
end

function TokenPossessionHolder:ResetForNextCycleUsed()
	self.__currentToken = nil
	self._callbackWhenObtain = nil
	self._callbackWhenRelease = nil

end

function TokenPossessionHolder:InitFromCycleUsed(callbackWhenObtain, callbackWhenRelease)
	self._callbackWhenObtain = callbackWhenObtain
	self._callbackWhenRelease = callbackWhenRelease
end

function TokenPossessionHolder:TryObtain(...)
	if self.__currentToken ~= nil then
		return nil
	end

	local result = self._callbackWhenObtain(...)
	if  result == false then
		return nil
	end
	
	self.__currentToken = INCREASED_TOKEN_FOR_TPH
	INCREASED_TOKEN_FOR_TPH = INCREASED_TOKEN_FOR_TPH + 1
	if INCREASED_TOKEN_FOR_TPH > 86400 then
		INCREASED_TOKEN_FOR_TPH = 1
	end
	
	return self.__currentToken
end

function TokenPossessionHolder:TryRelease(token)
	if self.__currentToken ~= token then
		return false
	end
	self._callbackWhenRelease()
	self.__currentToken = nil
	return true
end


-- 计数制开关, 用于功能开关会被多个上层应用控制时, 通过计数来进行功能实际开关控制, 强制让上层需要管理好自己的开关操作配对, 避免状态被错误强刷
DefineClass('CountableSwitcher')
local ABSOLUTE_SWITCH_VALUE = 10000
function CountableSwitcher:ctor()
	self._defaultSwitch = nil
	self._switchCount = 0
	self._callbackWhenSwitchOn = nil
	self._callbackWhenSwitchOff = nil
end

function CountableSwitcher:dtor()
	self:ResetForNextCycleUsed()
end

function CountableSwitcher:ResetForNextCycleUsed()
	self._defaultSwitch = nil
	self._switchCount = 0
	self._callbackWhenSwitchOn = nil
	self._callbackWhenSwitchOff = nil
end

function CountableSwitcher:InitFromCycleUsed(initSwitchOn, callbackWhenSwitchOn, callbackWhenSwitchOff)
	self._defaultSwitch = initSwitchOn
	self._switchCount = 0
	self._callbackWhenSwitchOn = callbackWhenSwitchOn
	self._callbackWhenSwitchOff = callbackWhenSwitchOff
	self:ResetSwitch()
end

function CountableSwitcher:ResetSwitch()
	local oldSwitchOn = self:GetIsSwitchOn()
	if oldSwitchOn == true then
		local _ = self._callbackWhenSwitchOff and self._callbackWhenSwitchOff(false)
	end
	
	self._switchCount = 0;
	if self._defaultSwitch == true then
		self:SwitchOn()
	end
end

function CountableSwitcher:_DoSwitchOn(value)
	local oldIsSwitchOn = self:GetIsSwitchOn()
	self._switchCount = self._switchCount + value
	if(oldIsSwitchOn ~= self:GetIsSwitchOn()) then
		local _ = self._callbackWhenSwitchOn and self._callbackWhenSwitchOn(true)
	end
end

-- 强行抢占, 这个要知道自己在干什么, 会不会影响其他正常逻辑
function CountableSwitcher:SwitchOn(isAbsolute)
	if isAbsolute == true then
		self:_DoSwitchOn(ABSOLUTE_SWITCH_VALUE)
	else
		self:_DoSwitchOn(1)
	end
end

function CountableSwitcher:_DoSwitchOff(value)
	local oldIsSwitchOn = self:GetIsSwitchOn()
	self._switchCount = self._switchCount - value
	if(oldIsSwitchOn ~= self:GetIsSwitchOn()) then
		local _= self._callbackWhenSwitchOff and self._callbackWhenSwitchOff(false)
	end
end

function CountableSwitcher:SwitchOff(isAbsolute)
	if isAbsolute == true then
		self:_DoSwitchOff(ABSOLUTE_SWITCH_VALUE)
	else	
		self:_DoSwitchOff(1)
	end
end

function CountableSwitcher:SwitchByCount(count)
	local oldIsSwitchOn = self:GetIsSwitchOn()
	self._switchCount = count
	local newIsSwitchOn = self:GetIsSwitchOn()
	if(oldIsSwitchOn ~= newIsSwitchOn) then
		local _ = self._callbackWhenSwitchOn and self._callbackWhenSwitchOn(newIsSwitchOn)
	end
end

function CountableSwitcher:GetIsSwitchOn()
	return self._switchCount > 0
end 

function CountableSwitcher:GetSwitchCount()
	return self._switchCount
end

function CountableSwitcher:GetIsSwitchedAbsolutely()
	if self._switchCount >= ABSOLUTE_SWITCH_VALUE / 2 then
		return true
	end

	if self._switchCount <= - ABSOLUTE_SWITCH_VALUE / 2 then
		return true
	end
	
	return false
end


-- 具有Force/Weak语义的变量，Get这个变量值时，Force值优先于Weak值
-- 其实就是一个简单的两优先级的值生效控制结构
-- 用法: 要结合逻辑优先级设置, weak一般为对应系统的默认行为, 当有更加强势的逻辑比默认行为优先级更高, 则设置force
--      force最多只能一个逻辑能够抢占设置(高优先级的行为之间是互斥的), 会检查报错, 而weak的默认行为可以按需进行替换
-- 计数制开关, 用于功能开关会被多个上层应用控制时, 通过计数来进行功能实际开关控制, 强制让上层需要管理好自己的开关操作配对, 避免状态被错误强刷
DefineClass('ForceAndWeakBarrier')

function ForceAndWeakBarrier:ctor()
	self._setActionFunctor = nil
	self._isForced = false
	self._weakValues = nil
	self._weakTag = nil
	self._forceValuesTable = {}	-- Key:Tag, Value:table(forceValues)
	self._forceTagList = {}		-- List:Tag
end

function ForceAndWeakBarrier:dtor()
	self._setActionFunctor = nil
	self._isForced = nil
	self._weakValues = nil
	self._weakTag = nil
	self._forceValuesTable = nil
	self._forceTagList = nil
end

function ForceAndWeakBarrier:ResetForNextCycleUsed()
	self._setActionFunctor = nil
	self._isForced = false
	self._weakValues = nil
	self._weakTag = nil
	table.clear(self._forceValuesTable)
	table.clear(self._forceTagList)
end

function ForceAndWeakBarrier:InitFromCycleUsed(initWeakValue, _setActionFunctor, ...)
	self:ResetForNextCycleUsed()

	self._setActionFunctor = _setActionFunctor
	self._weakValues = table.pack(initWeakValue, ...)

	if self._setActionFunctor ~= nil then
		self._setActionFunctor(table.unpack(self._weakValues))
	end
end

function ForceAndWeakBarrier:Reset(weakValue, ...)
	self._isForced = false
	self._weakValues = table.pack(weakValue, ...)
	self._weakValues = nil
	self._weakTag = nil
	table.clear(self._forceValuesTable)
	table.clear(self._forceTagList)
	
	if self._setActionFunctor ~= nil then
		self._setActionFunctor(table.unpack(self._weakValues))
	end
end

function ForceAndWeakBarrier:ClearForceValue(InTag)
	if self._isForced == false then
		return false
	end
	
	if InTag == nil then
		-- InTag为空时，认为清除所有ForceValue
		table.clear(self._forceValuesTable)
		table.clear(self._forceTagList)
		self._isForced = false
		if self._setActionFunctor ~= nil then
			self._setActionFunctor(table.unpack(self._weakValues))
		end
	else
		if self._forceValuesTable[InTag] == nil then
			-- 没有对应的ForceValueTag
			local ErrorMsf = "[ForceAndWeak]ClearForceValue Failed! No Force Value for Reason:" .. InTag .. ",\n Debug Error Only and won't Cause Crash, Please Contact Shizhengkai for This Error!"
			LOG_ERROR(ErrorMsf)
			return false
		else
			local bFindTag = false
			for i = 1, #self._forceTagList + 1 do
				if not bFindTag and self._forceTagList[i] == InTag then
					self._forceTagList[i] = nil
					bFindTag = true
				elseif bFindTag then
					self._forceTagList[i - 1] = self._forceTagList[i]
				end
			end
			self._forceValuesTable[InTag] = nil
			self._isForced = self._forceTagList[1] ~= nil

			if self._setActionFunctor ~= nil then
				if self._forceTagList[1] ~= nil then
					self._setActionFunctor(table.unpack(self._forceValuesTable[self._forceTagList[1]]))
				else
					self._setActionFunctor(table.unpack(self._weakValues))
				end
			end
		end
	end

	return true
end

function ForceAndWeakBarrier:SetForceValue(forceValue, InTag, ...)
	-- Tag已存在的情况下，不需要处理List
	if self._forceValuesTable[InTag] == nil then
		if self._forceTagList[1] ~= nil then
			-- 理论上避免重入，此分支不应该进来，要报错检查！
			local ErrorMsf = "[ForceAndWeak]SetForceValue Failed! Current Reason:" .. InTag .. ", Already Has Reason:\n"
			for index, CurReason in ipairs(self._forceTagList) do
				ErrorMsf = ErrorMsf .. "[ForceAndWeak]				" .. tostring(index) .. ":" .. CurReason .. "\n"	
			end
			ErrorMsf = ErrorMsf ..  "[ForceAndWeak]Debug Error Only and won't Cause Crash, Please Contact Shizhengkai for This Error!"
			LOG_ERROR(ErrorMsf)
			self._forceTagList[#self._forceTagList + 1] = InTag
		else
			self._forceTagList[1] = InTag
		end
	end

	self._forceValuesTable[InTag] = table.pack(forceValue, ...)
	self._isForced = true

	if self._setActionFunctor ~= nil then
		self._setActionFunctor(table.unpack(self._forceValuesTable[self._forceTagList[1]]))
	end

	return true
end 

function ForceAndWeakBarrier:SetWeakValue(weakValue, InTag, ...)
	self._weakTag = InTag
	self._weakValues = table.pack(weakValue, ...)

	if self._setActionFunctor ~= nil then
		if self._isForced then
			self._setActionFunctor(table.unpack(self._forceValuesTable[self._forceTagList[1]]))
		else
			self._setActionFunctor(table.unpack(self._weakValues))
		end
	end

	return true
end

function ForceAndWeakBarrier:GetWeakValue()
	return self:_joint_strings(self._weakValues)
end

function ForceAndWeakBarrier:GetWeakTag()
	return self._weakTag
end

function ForceAndWeakBarrier:GetForceValue()
	return self._isForced == true and self:_joint_strings(self._forceValuesTable[self._forceTagList[1]]) or nil
end

function ForceAndWeakBarrier:GetForceTag()
	if #self._forceTagList <= 1 then
		return self._forceTagList[1]
	else
		local ForceTag = ""
		for index, Tag in ipairs(self._forceTagList[1]) do
			ForceTag = ForceTag .. tostring(index) .. ":" .. Tag .. " "
		end
		return ForceTag
	end
end

function ForceAndWeakBarrier:GetDebugInfo()
	return string.format("WeakValue:%s  WeakTag:%s  ForceValue:%s, ForceTag:%s", self:GetWeakValue(), self:GetWeakTag(), self:GetForceValue(), self:GetForceTag())
end

function ForceAndWeakBarrier:_joint_strings(packedTable)
	local str = ""
	for _, v in ipairs(packedTable) do
	  str = str .. tostring(v) .. " "
	end
	return str
end

--[[
-- todo 如果需要这个功能, 需要解决客户端/服务端Set接口的require
-- 一票锁定开关，set中只要有一个值则开启，否则关闭，默认关闭状态
local Set = kg_require("Common.DataStruct.Set").Set

DefineClass('OneLockSwitcher')
function OneLockSwitcher:ctor()
	self._switchSet = Set.new()
	self._callbackWhenSwitchOn = nil
	self._callbackWhenSwitchOff = nil
end

function OneLockSwitcher:dtor()
	self:ResetForNextCycleUsed()
end

function OneLockSwitcher:ResetForNextCycleUsed()
	self._switchSet:Clear()
	self._callbackWhenSwitchOn = nil
	self._callbackWhenSwitchOff = nil
end

function OneLockSwitcher:InitFromCycleUsed(callbackWhenSwitchOn, callbackWhenSwitchOff)
	self._switchSet:Clear()
	self._callbackWhenSwitchOn = callbackWhenSwitchOn
	self._callbackWhenSwitchOff = callbackWhenSwitchOff
end

-- 开启和关闭都需要传入tag
function OneLockSwitcher:SwitchOn(tag)
	local isOldOn = self:GetIsSwitchOn()
	if not tag or self._switchSet:Contains(tag) then
		return
	end
	self._switchSet:Add(tag)
	if not isOldOn then
		if self._callbackWhenSwitchOn then
			self._callbackWhenSwitchOn()
		end
	end
end

-- 开启和关闭都需要传入tag
function OneLockSwitcher:SwitchOff(tag)
	local isOldOn = self:GetIsSwitchOn()
	if not tag or not self._switchSet:Contains(tag) then
		return
	end
	self._switchSet:Remove(tag)
	if isOldOn and not self:GetIsSwitchOn() then
		if self._callbackWhenSwitchOff then
			self._callbackWhenSwitchOff()
		end
	end
end

function OneLockSwitcher:GetIsSwitchOn()
	return self._switchSet.Count > 0
end
]]--

-- 引用计数回收基类，提供引用计数管理功能
DefineClass('RefCountRecycleBase')
function RefCountRecycleBase:ctor()
	self.refCount = 0
end

function RefCountRecycleBase:dtor()
	self:ResetForNextCycleUsed()
end

function RefCountRecycleBase:ResetForNextCycleUsed()
	self.refCount = 0
	self:Reset()
end

function RefCountRecycleBase:AddRefCount()
	self.refCount = self.refCount + 1
end

function RefCountRecycleBase:RemoveRefCount()
	self.refCount = self.refCount - 1
	if self.refCount <= 0 then
		self:OnRefCountClear()
	end
end

function RefCountRecycleBase:InitFromCycleUsed()
	self.refCount = 0
	self:Reset()
end

function RefCountRecycleBase:Reset()
end

function RefCountRecycleBase:OnRefCountClear()
end 