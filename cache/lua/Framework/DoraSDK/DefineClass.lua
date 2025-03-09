---
--- Lua 面向对象类机制实现
--- Created by Administrator.
--- DateTime: 2022/5/9 13:28
---


--[[
-- 关于多继承构造/析构函数的调用顺序
-- 父类深度优先，继承链中出现重复类时，不重复调用构造/析构函数
DefineClass("A")
DefineClass("B", A)
DefineClass("C", A, B)
DefineClass("D", B)
DefineClass("E", D, C)

-- c++ ctor: A -> B -> D -> A -> A -> B -> C -> E
-- lua ctor: A -> B -> D -> C -> E
local e = E.new()

-- c++ dtor: E -> C -> B -> A -> A -> D -> B -> A
-- lua dtor: E -> C -> B -> A -> D
e:delete()
--]]

local DebugFlag = require("Gameplay.Debug.DebugFlag")
local function GetCtorList(cls, cache)
    local ctorList = rawget(cls, "__CTOR_LIST__")
    if ctorList then return ctorList end

    ctorList = {}
    if cache then
        rawset(cls, "__CTOR_LIST__", ctorList)
    end

    local ctorMap = {}
    local index = 1

    local function initCtorList(base)
        --保证顺序，先基类再自己
        if base.__supers then
            for _, super in ipairs(base.__supers) do
                initCtorList(super)
            end
        end

        -- c7 fix start
        if base.__components then
            for _, component in ipairs(base.__components) do
                initCtorList(component)
            end
        end
        -- c7 fix end

        local ctor = rawget(base, "ctor")
        if ctor and not ctorMap[ctor] then
            ctorMap[ctor] = index
            ctorList[index] = ctor
            index = index + 1
        end
    end

    initCtorList(cls)
    ctorMap = nil
    return ctorList
end

local function GetDtorList(cls, cache)
    local dtorList = rawget(cls, "__DTOR_LIST__")
    if dtorList then return dtorList end

    dtorList = {}
    if cache then
        rawset(cls, "__DTOR_LIST__", dtorList)
    end

    local dtorMap = {}
    local index = 1

    local function initDtorList(base)
        --保证顺序，先自己再基类
        local dtor = rawget(base, "dtor")
        if dtor and not dtorMap[dtor] then
            dtorMap[dtor] = index
            dtorList[index] = dtor
            index = index + 1
        end

        -- 反序component dtor函数
        if base.__components then
            local components = base.__components
            for i = #components, 1, -1 do
                initDtorList(components[i])
            end
        end

        -- 反序析构
        if base.__supers then
            local supers = base.__supers
            for i = #supers, 1, -1 do
                initDtorList(supers[i])
            end
        end
    end

    initDtorList(cls)
    dtorMap = nil
    return dtorList
end

local beforeInstanceCtor, afterInstanceCtor
if UE_EDITOR then
    -- 只在编辑器模式下做检查吧

    local specialInstanceAttributes = {
        class = true,
        super = true,
        __cname = true,
    }

    beforeInstanceCtor = function(cls, instance)
        local attributes = rawget(cls, "__attributes")
        if attributes == nil then
            -- 第一次类的实例化
            attributes = {}
            rawset(cls, "__attributes", attributes)

            for k, _ in pairs(instance) do
                if not specialInstanceAttributes[k] then attributes[k] = true end
            end
        end
        getmetatable(instance).__newindex = function(t, k, v)
            attributes[k] = true
            rawset(t, k, v)
        end
    end

    afterInstanceCtor = function(cls, instance)
        local attributes = rawget(cls, "__attributes")
        getmetatable(instance).__newindex = function(t, k, v)
            if attributes[k] then
                rawset(t, k, v)
            else
                rawset(t, k, v)  --ADD BY DaiWei:LClass迁移，临时运行设置未定义的成员变量，待LClass迁移完成关闭
                -- DebugLogError(debug.traceback(string.format("cls name(%s) attempt to add key(%s) value(%s)", cls.__cname, k, v), 2))
                DebugLogWarning(string.format("cls name(%s) attempt to add key(%s) value(%s)", cls.__cname, k, v))
            end
        end
    end
else
    beforeInstanceCtor = function() end
    afterInstanceCtor = function() end
end

local function ClassStorage(classname, env)
    local cls
    if env[classname] then
        if not Game.RefreshScript then
            DebugLogError(string.format('class() - create class "%s" with multiple DefineClass, please check', classname))
        end
        cls = env[classname]
        cls.__cname = classname
    else
        cls = {__cname = classname}
        if _G ~= env then
            _G[classname] = cls
        end
        env[classname] = cls
    end
    return cls
end

function resetClsOnRefresh(cls)
    cls.__supers = nil
    rawset(cls, "__DTOR_LIST__", nil)
    rawset(cls, "__CTOR_LIST__", nil)
end

--- 自定义oop类，可以完成继承
---@param classname string
---@vararg LuaClass
---@return LuaClass
function DefineClass(classname, ...)
    local func = debug.getinfo(2).func
    local _, env = debug.getupvalue(func, 1)
    local cls = ClassStorage(classname, env)
    local supers = {...}

    -- refreh的时候会用到
    resetClsOnRefresh(cls)
    
    for _, super in ipairs(supers) do
        local superType = type(super)
        if superType == "table" then
            -- super is pure lua class
            cls.__supers = cls.__supers or {}
            cls.__supers[#cls.__supers + 1] = super
            if not cls.super then
                cls.super = super -- set first super pure lua class as class.super
            end
        else
            DebugLogError(string.format("class() - create class \"%s\" with invalid super type \"%s\"", classname, superType), 0)
        end
    end

    cls.__index = cls
    if not cls.__supers or #cls.__supers == 1 then
        setmetatable(cls, {__index = cls.__supers and cls.__supers[1]})
    else
        local clsSupers = cls.__supers
        setmetatable(cls, {__index = function(_, key)
            for i = 1, #clsSupers do
                local super = clsSupers[i]
                local v = super[key]
                if v ~= nil then
                    return v
                end
            end
        end})
    end

    if not cls.ctor then
        cls.ctor = function() end
    end

    cls.new = function(...)
        local instance = cls.__create ~= nil and cls.__create(...) or {}
        setmetatable(instance, cls)
        instance.class = cls
        instance.__cname = cls.__cname
        beforeInstanceCtor(cls, instance)
        for _, ctor in ipairs(GetCtorList(cls, true)) do
            ctor(instance, ...)
        end
        -- 属性只能在构造函数里定义
        -- 调用完构造函数之后禁止新增属性
        afterInstanceCtor(cls, instance)

        return instance
    end

    cls.delete = function(inst, ...)
        for _, dtor in ipairs(GetDtorList(cls, true)) do dtor(inst, ...) end
        setmetatable(inst, nil)
        inst.destroyed = true
    end
    return cls
end

-- c7 fix 接入C8一些流程
-- Add New Feature: 接入C8的component call生命周期环节的机制 by孙亚 20240223
local cls_component_func_set = "__cls_components_func_set__"
local cls_component_func_index = "__cls_components_func_index__"
local call_component_func_prefix = '__component_'
local call_component_func_postfix = '__'
local function checkCallComponentFunc(k, v)

    -- 支持call_component('xxx'), 调用Entity身上所有的component中的形如 __component_xxx__的函数
    if string.startsWith(k, call_component_func_prefix) and string.startsWith(k, call_component_func_postfix) and type(v) == 'function' then
        return true
    end

    return false
end
-- END: Add New Feature 

local function checkUnwindComponentField(k, v)
    local keyType = type(k)
    if keyType ~= "string" then
        return false
    end

    if k == "ctor" or k == "dtor" then
        return false
    end

    -- Add New Feature: 接入C8的component call生命周期环节的机制 by孙亚 20240223
    if checkCallComponentFunc(k, v) then
        return true
    end
    -- END: Add New Feature 

    -- 过滤掉__supers等__开头的变量
    if string.startsWith(k, "__") then
        return false
    end

    return true
end

function DefineComponent(classname, ...)
    local env = _G

    if env[classname] == nil then
        env[classname] = {__cname = classname}
    else
        setmetatable(env[classname], nil)
    end

    local cls = env[classname]

    cls.__cname = classname
    rawset(env, "__main_cls", cls)

    local supers = {...}
    if #supers > 0 then
        cls.__supers = {}
    end

    for _, super in pairs(supers) do
        local superType = type(super)
        assert(superType == "table", string.format("class() - create class \"%s\" with invalid super class type \"%s\"",
                classname, superType))
        cls.__supers[#cls.__supers + 1] = super
    end

    -- 将supers的函数展开
    local unwind
    unwind = function (cls, scls)
        for k, v in pairs(scls) do
            if checkUnwindComponentField(k, v) then
                -- 等于nil的时候才设置，否则就是子类覆盖父类
                if cls[k] == nil then
                    cls[k] = v
                end
            end
        end

        -- 递归下去
        if scls.__supers then
            for _, sscls in pairs(scls.__supers) do
                unwind(cls, sscls)
            end
        end
    end

    for _, super in pairs(supers) do
        unwind(cls, super)
    end
    return cls
end

local function GetAllComponent(cls, components)
    if not cls.__components then
        return
    end
    for _, comp in ipairs(cls.__components) do
        if not table.isInArray(components, comp) then
            components[#components + 1] = comp
        end
    end
    for _, super in ipairs(cls.__supers or {}) do
        GetAllComponent(super, components)
    end
end

ComponentToEntity = {}
ComponentToEntityMap = {}
local function recordComponentToEntity(cls, componentList, bGetAll)
    if bGetAll then
        componentList = {}
        GetAllComponent(cls, componentList)
    end
    if not componentList or next(componentList) == nil then
        return
    end
    for _,component in ipairs(componentList) do
        local name = component.__cname
        if not ComponentToEntity[name] then
            ComponentToEntity[name] = {}
            ComponentToEntityMap[name] = {}
        end

        local superComponents = component.__supers
        if superComponents and next(superComponents) then
            recordComponentToEntity(cls, superComponents, false)
        end
        table.insert(ComponentToEntity[name], cls)
        if ComponentToEntityMap[name][cls] then
            error(string.format("entity %s record component %s duplicate", cls.__cname, name))
        end
        ComponentToEntityMap[name][cls] = true
    end
end

-- Add New Feature: 接入C8的component call生命周期环节的机制 by孙亚 20240223


function checkCallComponentFunc(k, v)
    -- 支持call_component('xxx'), 调用Entity身上所有的component中的形如 __component_xxx__的函数
    if string.startsWith(k, call_component_func_prefix) and string.startsWith(k, call_component_func_postfix) and type(v) == 'function' then
        return true
    end

    return false
end

function genCompleteComponentFuncName(component_func_middle_part)
    return call_component_func_prefix..component_func_middle_part..call_component_func_postfix
end

local function AddComponentsCall(cls, components, copyFunc)
    -- 引擎层已自动添加__components
    cls.__components = {}
    components = components or {}
    for _, component in ipairs(components) do
        local ctype = type(component)
        assert(ctype == "table", string.format("class() - create class \"%s\" with invalid component class type \"%s\"",
                cls.__cname, ctype))
        cls.__components[#cls.__components + 1] = component
    end

    -- 存放components身上类似__component_XXX__的函数
    if rawget(cls, cls_component_func_set) == nil or _script.isRefresh then
        rawset(cls, cls_component_func_set, {})
        rawset(cls, cls_component_func_index, {})
    end

    -- 将组件字段展开到entity
    local all_components = {}
    GetAllComponent(cls, all_components)
    for _, component in ipairs(all_components) do
        for k, v in pairs(component) do
            if checkUnwindComponentField(k, v) then
                if checkCallComponentFunc(k, v) then
                    if cls[cls_component_func_set][k] == nil then
                        cls[cls_component_func_set][k] = {}
                        cls[cls_component_func_index][k] = {}
                    end
                    local index = #cls[cls_component_func_set][k]+1
                    cls[cls_component_func_set][k][index] = v
                    cls[cls_component_func_index][k][component.__cname] = index
                else
                    if copyFunc then
                        cls[k] = v
                    end
                end
            end
        end
    end

    -- 增加call_components接口
    local component_func_mapping = {}
    cls.call_components = function(self, component_func_middle_part, ...)
		if DebugFlag.OpenComponentLifeStageLog then
			Log.DebugFormat("[LogicUnit-LifeTimeStage][Component:Func] Entity:%s, Uid:%s ComponentStage:%s", self.eid, self:uid(), component_func_middle_part)
		end
        local component_whole_func_name = component_func_mapping[component_func_middle_part]
        if component_whole_func_name == nil then
            component_whole_func_name = genCompleteComponentFuncName(component_func_middle_part)
            component_func_mapping[component_func_middle_part] = component_whole_func_name
        end

        if cls[cls_component_func_set][component_whole_func_name] ~=nil then
            for _,v in ipairs(cls[cls_component_func_set][component_whole_func_name]) do
                -- if not UE_EDITOR then
                    v(self, ...)
                -- else  -- 早期主干不稳定，容错处理，减少策划阻塞
                --     xpcall(v, _G.CallBackError, self, ...)
                --end
            end
        end
    end

end

function HotfixComponentCall(componentName, funcName, func)
    local clsList = ComponentToEntity[componentName]
    if not clsList then
        return
    end

    for _, cls in ipairs(clsList) do
        -- 新加component_call
        if cls[cls_component_func_set][funcName] == nil then
            cls[cls_component_func_set][funcName] = {}
            cls[cls_component_func_index][funcName] = {}
        end

        local funcIndex = cls[cls_component_func_index][funcName][componentName]
        if not funcIndex then -- 新增一个component_call
            local index = #cls[cls_component_func_set][funcName]+1
            cls[cls_component_func_set][funcName][index] = func
            cls[cls_component_func_index][funcName][componentName] = index
        else -- 修改（如果要删除某个component_call,把component_call的函数置空）
            cls[cls_component_func_set][funcName][funcIndex] = func
        end
    end
end

function GetComponentCall(componentName, funcName)
    local clsList = ComponentToEntity[componentName]
    if not clsList or #clsList == 0 then
        return
    end
    for _, cls in pairs(clsList) do
        local funcIndex = cls[cls_component_func_index][funcName][componentName]
        if funcIndex then
            return cls[cls_component_func_set][funcName][funcIndex]
        end
    end
end

-- END: Add New Feature 

function DefineEntity(classname, supers, components, briefClass)
    local cls = _script.defineEntity(classname, supers or {}, components or {}, briefClass or classname)
    recordComponentToEntity(cls, components, true)
    AddComponentsCall(cls, components)
    return cls
end

function DefineBriefEntity(classname, supers, components)
    local cls = _script.defineBriefEntity(classname, supers or {}, components or {})
    recordComponentToEntity(cls, components, true)
    AddComponentsCall(cls, components)
    return cls
end

-- 添加local entity机制
function DefineLocalEntity(classname, supers, components)
    local cls = DefineClass(classname, supers)
    recordComponentToEntity(cls, components, false)
    AddComponentsCall(cls, components, true)
    return cls
end


-- c7 fix end 接入C8一些流程

function DefineSingletonClass(classname, ...)
    local cls = DefineClass(classname, ...)
    cls.class = cls
    cls.new = function(...)
        assert(rawget(cls, "__Instanced") == nil, "Singleton class[" .. cls.__cname .. "] can not new twice")

        beforeInstanceCtor(cls, cls)
        for _, ctor in ipairs(GetCtorList(cls)) do
            ctor(cls, ...)
        end
        afterInstanceCtor(cls, cls)

        rawset(cls, "__Instanced", true)
        return cls
    end

    -- c7 fix start
    cls.GetInstance = function()
        if not cls._instance then
            cls._instance = cls.new()
        end
        return cls._instance
    end

    cls.HasInstance = function()
        return cls._instance
    end
    -- c7 fix end

    return cls
end

function EnableNewIndex(cls, instance)
    return beforeInstanceCtor(cls, instance)
end

function DisableNewIndex(cls, instance)
    return afterInstanceCtor(cls, instance)
end

function CallEntityCtorFunc(ent, cls)
    ent.class = cls
    beforeInstanceCtor(cls, ent)
    for _, ctor in ipairs(GetCtorList(cls, true)) do ctor(ent, ent:id()) end
    afterInstanceCtor(cls, ent)
end

function CallEntityDtorFunc(ent, cls)
    if ent["before_dtor"] then
        ent["before_dtor"](ent)
    end

    for _, dtor in ipairs(GetDtorList(cls, true)) do dtor(ent) end
end
