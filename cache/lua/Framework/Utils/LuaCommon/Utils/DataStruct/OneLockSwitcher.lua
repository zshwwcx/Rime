---
--- Created by shijingzhe
--- DateTime: 2024/6/24 21:55
---

---@class OneLockSwitcher
OneLockSwitcher = DefineClass('OneLockSwitcher')

function OneLockSwitcher:ctor()
    self._tags = {}
    self._absoluteTags = {}
    self._callbackSelf = nil
    self._callbackWhenSwitchOn = nil
    self._callbackWhenSwitchOff = nil
end

function OneLockSwitcher:dtor()
    self:ResetForNextCycleUsed()
end

function OneLockSwitcher:ResetForNextCycleUsed()
    if self:IsSwitchOn() then
        if self._callbackWhenSwitchOff then
            self._callbackWhenSwitchOff(self._callbackSelf)
        end
    end

    self._tags = {}
    self._absoluteTags = {}
    self._callbackSelf = nil
    self._callbackWhenSwitchOn = nil
    self._callbackWhenSwitchOff = nil
end

function OneLockSwitcher:InitFromCycleUsed(callbackWhenSwitchOn, callbackWhenSwitchOff, callbackSelf)
    self._tags = {}
    self._absoluteTags = {}
    self._callbackSelf = callbackSelf
    self._callbackWhenSwitchOn = callbackWhenSwitchOn
    self._callbackWhenSwitchOff = callbackWhenSwitchOff
end

-- 开启和关闭都需要传入tag
function OneLockSwitcher:IsLockedBy(tag, bAbsolute)
    if bAbsolute then
        return self._absoluteTags[tag] ~= nil
    else
        return self._tags[tag] ~= nil
    end
end

-- 开启和关闭都需要传入tag
function OneLockSwitcher:SwitchOn(tag, bAbsolute)
    -- 强制报错
    if tag == nil then
        Log.Error("cannot switch on without tag")
        return
    end

    local isOldOn = self:IsSwitchOn()

    if bAbsolute then
        if not self:absolutelySwitchOn(tag) then
            return
        end
        --Log.DebugFormat("[SwitchOn] absolute switch on with tag %s \n%s", tag, debug.traceback())
    else
        if self._tags[tag] then
            self._tags[tag] = self._tags[tag] + 1
        else
            self._tags[tag] = 1
        end
    end

    if not isOldOn then
        if self._callbackWhenSwitchOn then
            self._callbackWhenSwitchOn(self._callbackSelf)
        end
    end
end

-- 开启和关闭都需要传入tag
function OneLockSwitcher:SwitchOff(tag, bAbsolute)
    -- 强制报错
    if tag == nil then
        Log.Error("cannot switch off without tag")
        return
    end

    local isOldOn = self:IsSwitchOn()

    if bAbsolute then
        if not self:absolutelySwitchOff(tag) then
            return
        end
        --Log.DebugFormat("[SwitchOff] absolute switch off with tag %s \n%s", tag, debug.traceback())
    else
        if not self._tags[tag] then
            Log.WarningFormat("no tags for %s to switch off", tag)
        else
            self._tags[tag] = self._tags[tag] - 1
        end

        if self._tags[tag] == 0 then
            self._tags[tag] = nil
        end
    end

    if isOldOn and not self:IsSwitchOn() then
        if self._callbackWhenSwitchOff then
            self._callbackWhenSwitchOff(self._callbackSelf)
        end
    end
end

-- 抢占开
function OneLockSwitcher:absolutelySwitchOn(tag)
    if tag == nil then
        Log.Error("cannot absolutely switch on without tag")
        return false
    end

    if next(self._absoluteTags) ~= nil then
        local ErrorMsf = "[OneLockSwitcher]absolutelySwitchOn Failed! Current Tag:" .. tag .. ", Already Has Tag:\n"
        for CurTag, _ in pairs(self._absoluteTags) do
            ErrorMsf = ErrorMsf .. "[OneLockSwitcher] " .. CurTag .. "\n"
        end
        ErrorMsf = ErrorMsf .. "[OneLockSwitcher]Debug Error Only and won't Cause Crash, Please Contact Shizhengkai for This Error!"
        --todo 临时先改成warn，后续等复活修复好之后，再改成error
        LOG_WARN(ErrorMsf)
    end

    self._absoluteTags[tag] = true
    return true
end

-- 抢占关
function OneLockSwitcher:absolutelySwitchOff(tag)
    if tag == nil then
        Log.Error("cannot absolutely switch off without tag")
        return false
    end

    if next(self._absoluteTags) == nil then
        local ErrorMsf = "[OneLockSwitcher]absolutelySwitchOff Failed! No AbsoluteTag:" .. tag .. 
            "\n[OneLockSwitcher]Debug Error Only and won't Cause Crash, Please Contact Shizhengkai for This Error!"
        --todo 临时先改成warn，后续等复活修复好之后，再改成error
        LOG_WARN(ErrorMsf)
    end

    self._absoluteTags[tag] = nil
    return true
end

---@public
---@return boolean
function OneLockSwitcher:IsSwitchOn()
    if next(self._absoluteTags) ~= nil then
        return true
    else
        return next(self._tags) ~= nil
    end
end

---@public
---@return string
function OneLockSwitcher:GetDebugInfo()
    local info = "  AbsoluteTags: "
    for tag, _ in pairs(self._absoluteTags) do
        info = info .. tostring(tag) .. ", "
    end
    info = info .. "  CommonTags: "
    for tag, cnt in pairs(self._tags) do
        info = info .. tostring(tag) .. ":" .. tostring(cnt) .. ", "
    end
    return info
end

return OneLockSwitcher
