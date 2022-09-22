# Lua OOP

Lua本身没有明确的OOP概念，并且也没有内置的关于“类"的明确定义，但是我们可以通过lua tables和metatables"方便"的创建属于你自己的类对象。

一个简单的基于metatable的lua类
```lua
local MyClass = {} -- the table representing the class, which will double as the metatable for the instances
MyClass.__index = MyClass -- failed table lookups on the instances should fallback to the class table, to get methods

function MyClass.new(init)
    local self = setmetatable({}, MyClass)
    self.value = init
    return self
end

function MyClass.set_value(self, newval)
    self.value = newval
end

function MyClass.get_value(self)
    return self.value
end

local i = MyClass.new(5)

print(i:get_value()) --> print 5
i:set_value(6) --> set_value as 6
print(i:get_value()) --> print 6
```

一个实现简单继承的lua案例
```lua
local BaseClass = {}
BaseClass.__index = BaseClass

setmetatable(BaseClass, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:_init(...)
    return self
  end,
})

function BaseClass:_init(init)
  self.value = init
end

function BaseClass:set_value(newval)
  self.value = newval
end

function BaseClass:get_value()
  return self.value
end

---

local DerivedClass = {}
DerivedClass.__index = DerivedClass

setmetatable(DerivedClass, {
  __index = BaseClass, -- this is what makes the inheritance work
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:_init(...)
    return self
  end,
})

function DerivedClass:_init(init1, init2)
  BaseClass._init(self, init1) -- call the base class constructor
  self.value2 = init2
end

function DerivedClass:get_value()
  return self.value + self.value2
end

local i = DerivedClass(1, 2)
print(i:get_value()) --> 3
i:set_value(3)
print(i:get_value()) --> 5
```

## MetatableEvents in Lua

### __index
覆盖写，如果原table有字段，则覆盖，如果没有则添加。
```lua
local func_example = setmetatable({}, {__index = function (t, k)  -- {} an empty table, and after the comma, a custom function failsafe
  return "key doesn't exist"
end})

local fallback_tbl = setmetatable({   -- some keys and values present, together with a fallback failsafe
  foo = "bar",
  [123] = 456,
}, {__index=func_example})

local fallback_example = setmetatable({}, {__index=fallback_tbl})  -- {} again an empty table, but this time with a fallback failsafe

print(func_example[1]) --> key doesn't exist
print(fallback_example.foo) --> bar
print(fallback_example[123]) --> 456
print(fallback_example[456]) --> key doesn't exist
```

### __newindex
This metamethod is called when you try to assign to a key in a table, and that key doesn't exist (contains nil). If the key exists, the metamethod is not triggered.
```lua
local t = {}

local m = setmetatable({}, {__newindex = function (table, key, value)
  t[key] = value
end})

m[123] = 456
print(m[123]) --> nil
print(t[123]) --> 456
```

### __metatable

__metatable is for protecting metatables. If you do not want a program to change the contents of a metatable, you set its __metatable field. With that, the program cannot access the metatable (and therefore cannot change it).


