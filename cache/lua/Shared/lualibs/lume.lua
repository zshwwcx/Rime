--
-- lume
--
-- Copyright (c) 2015 rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local lume = { _version = "2.2.3" }

local pairs, ipairs, select = pairs, ipairs, select
local type, assert, unpack = type, assert, unpack or table.unpack
local tostring, tonumber = tostring, tonumber
local math_floor = math.floor
local math_ceil = math.ceil
local math_random = math.random
local math_atan2 = math.atan2 or math.atan
local math_sqrt = math.sqrt
local math_abs = math.abs
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local table_getn = table.getn

local noop = function()
end

local identity = function(x)
  return x
end

local patternescape = function(str)
  return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

local absindex = function(len, i)
  return i < 0 and (len + i + 1) or i
end

local iscallable = function(x)
  if type(x) == "function" then return true end
  local mt = getmetatable(x)
  return mt and mt.__call ~= nil
end

local getiter = function(x)
  if lume.isarray(x) then
    return ipairs
  elseif type(x) == "table" then
    return pairs
  end
  error("expected table", 3)
end

local iteratee = function(x)
  if x == nil then return identity end
  if iscallable(x) then return x end
  if type(x) == "table" then
    return function(z)
      for k, v in pairs(x) do
        if z[k] ~= v then return false end
      end
      return true
    end
  end
  return function(z) return z[x] end
end



function lume.clamp(x, min, max)
  return x < min and min or (x > max and max or x)
end


function lume.round(x, increment)
  if increment then return lume.round(x / increment) * increment end
  return x >= 0 and math_floor(x + .5) or math_ceil(x - .5)
end


function lume.sign(x)
  return x < 0 and -1 or 1
end


function lume.lerp(a, b, amount)
  return a + (b - a) * lume.clamp(amount, 0, 1)
end


function lume.smooth(a, b, amount)
  local t = lume.clamp(amount, 0, 1)
  local m = t * t * (3 - 2 * t)
  return a + (b - a) * m
end


function lume.pingpong(x)
  return 1 - math_abs(1 - x % 2)
end


function lume.distance(x1, y1, x2, y2, squared)
  local dx = x1 - x2
  local dy = y1 - y2
  local s = dx * dx + dy * dy
  return squared and s or math_sqrt(s)
end

-- 向量点乘
function lume.getVector3Dot(v1, v2)
  return v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3]
end

-- 向量叉乘
function lume.getVector3Cross(v1, v2)
  return {v1[2] * v2[3] - v2[2] * v1[3], v2[1] * v1[3] - v1[1] * v2[3], v1[1] * v2[2] - v2[1] * v1[2]}
end

-- 向量的模
function lume.getVector3Module(v)
  return math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
end

-- 求两向量间夹角（弧度）
function lume.getVector3Angle(v1, v2)
  local cos = lume.getVector3Dot(v1, v2) / (lume.getVector3Module(v1) * lume.getVector3Module(v2))
  if math.abs(cos) > 1 then
    cos = math.modf(cos)
  end
  return math.acos(cos)
end

function lume.random(a, b)
  if not a then a, b = 0, 1 end
  if not b then a, b = 0, a end
  return a + math_random() * (b - a)
end


function lume.randomchoice(t)
  local len = table_getn(t)
  if len == 0 then return end
  return t[math_random(len)]
end


function lume.uniquerandom(a, b, n)
  assert(b - a + 1 >= n)
  local replace = {}
  local ret = {}
  for i = 1, n do
    local r = math_random(a, b)
    ret[i] = replace[r] or r
    replace[r] = replace[b] or b
    b = b - 1
  end
  return ret
end


function lume.weightedchoice(t)
  local sum = 0
  for _, v in pairs(t) do
    assert(v >= 0, "weight value less than zero")
    sum = sum + v
  end
  assert(sum ~= 0, "all weights are zero")
  local rnd = lume.random(sum)
  for k, v in pairs(t) do
    if rnd < v then return k end
    rnd = rnd - v
  end
end

-- accept array k->weight, example: {{k1, weight}, {k2, weight}, ...}
function lume.weightedchoicearray(t)
  local sum = 0
  for _, v in ipairs(t) do
    assert(v[2] >= 0, "weight value less than zero")
    sum = sum + v[2]
  end
  if sum <= 0 then
    -- choice nothing is allowed
    return nil, nil
  end
  local rnd = lume.random(sum)
  for i, v in ipairs(t) do
    if rnd < v[2] then return v[1], i end
    rnd = rnd - v[2]
  end
end


function lume.isarray(t)
  if type(t) ~= "table" then
    return false
  end
  local n = table_getn(t)
  local floor = math.floor
  for k in pairs(t) do
    if type(k) ~= "number" or k <=0 or k > n or floor(k) ~= k then
      return false
    end
  end
  return true
end


function lume.push(t, ...)
  local n = select("#", ...)
  for i = 1, n do
    t[table_getn(t) + 1] = select(i, ...)
  end
  return ...
end


function lume.remove(t, x)
  local iter = pairs
  for i, v in iter(t) do
    if v == x then
      if lume.isarray(t) then
        table_remove(t, i)
        break
      else
        t[i] = nil
        break
      end
    end
  end
  return x
end

function lume.iremove(t, x)
  local iter = ipairs
  for i, v in iter(t) do
    if v == x then
      if lume.isarray(t) then
        table_remove(t, i)
        break
      else
        t[i] = nil
        break
      end
    end
  end
  return x
end

function lume.clear(t)
  for k in pairs(t) do
    t[k] = nil
  end
  return t
end


function lume.extend(t, ...)
  for i = 1, select("#", ...) do
    local x = select(i, ...)
    if x then
      for k, v in pairs(x) do
        t[k] = v
      end
    end
  end
  return t
end

function lume.extendArrayInPlace(t, ...)
  for i = 1, select("#", ...) do
    local x = select(i, ...)
    if x then
      for _, v in pairs(x) do
        t[table_getn(t) + 1] = v
      end
    end
  end
  return t
end

function lume.extendArray(...)
  local ret = {}
  for i = 1, select("#", ...) do
    local x = select(i, ...)
    if x then
      for _, v in pairs(x) do
        ret[table_getn(ret) + 1] = v
      end
    end
  end
  return ret
end

function lume.shuffle(t)
  local rtn = {}
  for i = 1, table_getn(t) do
    local r = math_random(i)
    if r ~= i then
      rtn[i] = rtn[r]
    end
    rtn[r] = t[i]
  end
  return rtn
end


function lume.sort(t, comp)
  local rtn = lume.clone(t)
  if comp then
    if type(comp) == "string" then
      table_sort(rtn, function(a, b) return a[comp] < b[comp] end)
    else
      table_sort(rtn, comp)
    end
  else
    table_sort(rtn)
  end
  return rtn
end


function lume.array(...)
  local t = {}
  for x in ... do t[table_getn(t) + 1] = x end
  return t
end


function lume.each(t, fn, ...)
  local iter = pairs
  if type(fn) == "string" then
    for _, v in iter(t) do v[fn](v, ...) end
  else
    for _, v in iter(t) do fn(v, ...) end
  end
  return t
end

function lume.ieach(t, fn, ...)
  local iter = ipairs
  if type(fn) == "string" then
    for _, v in iter(t) do v[fn](v, ...) end
  else
    for _, v in iter(t) do fn(v, ...) end
  end
  return t
end

function lume.map(t, fn)
  fn = iteratee(fn)
  local iter = pairs
  local rtn = {}
  for k, v in iter(t) do rtn[k] = fn(v) end
  return rtn
end

function lume.imap(t, fn)
  fn = iteratee(fn)
  local iter = ipairs
  local rtn = {}
  for k, v in iter(t) do rtn[k] = fn(v) end
  return rtn
end

function lume.all(t, fn)
  fn = iteratee(fn)
  local iter = pairs
  for _, v in iter(t) do
    if not fn(v) then return false end
  end
  return true
end

function lume.iall(t, fn)
  fn = iteratee(fn)
  local iter = ipairs
  for _, v in iter(t) do
    if not fn(v) then return false end
  end
  return true
end


function lume.any(t, fn)
  fn = iteratee(fn)
  local iter = pairs
  for _, v in iter(t) do
    if fn(v) then return true end
  end
  return false
end

function lume.iany(t, fn)
  fn = iteratee(fn)
  local iter = ipairs
  for _, v in iter(t) do
    if fn(v) then return true end
  end
  return false
end

function lume.reduce(t, fn, first)
  local acc = first
  local started = first and true or false
  local iter = pairs
  for _, v in iter(t) do
    if started then
      acc = fn(acc, v)
    else
      acc = v
      started = true
    end
  end
  assert(started, "reduce of an empty table with no first value")
  return acc
end

function lume.ireduce(t, fn, first)
  local acc = first
  local started = first and true or false
  local iter = ipairs
  for _, v in iter(t) do
    if started then
      acc = fn(acc, v)
    else
      acc = v
      started = true
    end
  end
  assert(started, "reduce of an empty table with no first value")
  return acc
end


function lume.set(t)
  local rtn = {}
  for k in pairs(lume.invert(t)) do
    rtn[table_getn(rtn) + 1] = k
  end
  return rtn
end


function lume.filter(t, fn, retainkeys)
  fn = iteratee(fn)
  local iter = pairs
  local rtn = {}
  if retainkeys then
    for k, v in iter(t) do
      if fn(v) then rtn[k] = v end
    end
  else
    for _, v in iter(t) do
      if fn(v) then rtn[table_getn(rtn) + 1] = v end
    end
  end
  return rtn
end

function lume.ifilter(t, fn, retainkeys)
  fn = iteratee(fn)
  local iter = ipairs
  local rtn = {}
  if retainkeys then
    for k, v in iter(t) do
      if fn(v) then rtn[k] = v end
    end
  else
    for _, v in iter(t) do
      if fn(v) then rtn[table_getn(rtn) + 1] = v end
    end
  end
  return rtn
end


function lume.reject(t, fn, retainkeys)
  fn = iteratee(fn)
  local iter = pairs
  local rtn = {}
  if retainkeys then
    for k, v in iter(t) do
      if not fn(v) then rtn[k] = v end
    end
  else
    for _, v in iter(t) do
      if not fn(v) then rtn[table_getn(rtn) + 1] = v end
    end
  end
  return rtn
end

function lume.ireject(t, fn, retainkeys)
  fn = iteratee(fn)
  local iter = ipairs
  local rtn = {}
  if retainkeys then
    for k, v in iter(t) do
      if not fn(v) then rtn[k] = v end
    end
  else
    for _, v in iter(t) do
      if not fn(v) then rtn[table_getn(rtn) + 1] = v end
    end
  end
  return rtn
end


function lume.merge(...)
  local rtn = {}
  for i = 1, select("#", ...) do
    local t = select(i, ...)
    local iter = pairs
    for k, v in iter(t) do
      rtn[k] = v
    end
  end
  return rtn
end


function lume.concat(...)
  local rtn = {}
  for i = 1, select("#", ...) do
    local t = select(i, ...)
    if t ~= nil then
      local iter = pairs
      for _, v in iter(t) do
        rtn[table_getn(rtn) + 1] = v
      end
    end
  end
  return rtn
end


function lume.append(t, ...)
  for i = 1, select("#", ...) do
    local x = select(i, ...)
    if x then
      for _, v in ipairs(x) do
        t[table_getn(t) + 1] = v
      end
    end
  end
end


function lume.find(t, value)
  for k, v in pairs(t) do
    if v == value then return k end
  end
  return nil
end

function lume.findAll(t, value)
  local rtn = {}
  for k, v in pairs(t) do
    if v == value then rtn[table_getn(rtn) + 1] = k end
  end
  return rtn
end

function lume.match(t, fn)
  fn = iteratee(fn)
  for k, v in pairs(t) do
    if fn(v) then return v, k end
  end
  return nil
end


function lume.count(t, fn)
  local count = 0
  local iter = pairs
  if fn then
    fn = iteratee(fn)
    for _, v in iter(t) do
      if fn(v) then count = count + 1 end
    end
  else
    for _ in iter(t) do count = count + 1 end
  end
  return count
end


function lume.slice(t, i, j)
  i = i and absindex(table_getn(t), i) or 1
  j = j and absindex(table_getn(t), j) or table_getn(t)
  local rtn = {}
  for x = i < 1 and 1 or i, j > table_getn(t) and table_getn(t) or j do
    rtn[table_getn(rtn) + 1] = t[x]
  end
  return rtn
end


function lume.first(t, n)
  if not n then return t[1] end
  return lume.slice(t, 1, n)
end


function lume.last(t, n)
  if not n then return t[table_getn(t)] end
  return lume.slice(t, -n, -1)
end


function lume.invert(t)
  local rtn = {}
  for k, v in pairs(t) do rtn[v] = k end
  return rtn
end


function lume.pick(t, ...)
  local rtn = {}
  for i = 1, select("#", ...) do
    local k = select(i, ...)
    rtn[k] = t[k]
  end
  return rtn
end


function lume.keys(t)
  local rtn = {}
  local iter = pairs
  for k in iter(t) do rtn[table_getn(rtn) + 1] = k end
  return rtn
end


function lume.clone(t)
  local rtn = {}
  for k, v in pairs(t) do rtn[k] = v end
  return rtn
end

function lume.iclone(t)
  local rtn = {}
  for k, v in ipairs(t) do rtn[k] = v end
  return rtn
end

function lume.tostrkey(t)
  local rtn = {}
  for k, v in pairs(t) do rtn[tostring(k)] = v end
  return rtn
end

function lume.tonumkey(t)
  local rtn = {}
  for k, v in pairs(t) do rtn[tonumber(k)] = v end
  return rtn
end

function lume.tonumtable(t)
  local rtn = {}
  for k, v in pairs(t) do rtn[tonumber(k)] = tonumber(v) end
  return rtn
end

function lume.fn(fn, ...)
  assert(iscallable(fn), "expected a function as the first argument")
  local args = { ... }
  return function(...)
    local a = lume.concat(args, { ... })
    return fn(unpack(a))
  end
end


function lume.once(fn, ...)
  local f = lume.fn(fn, ...)
  local done = false
  return function(...)
    if done then return end
    done = true
    return f(...)
  end
end


local memoize_fnkey = {}
local memoize_nil = {}

function lume.memoize(fn)
  local cache = {}
  return function(...)
    local c = cache
    for i = 1, select("#", ...) do
      local a = select(i, ...) or memoize_nil
      c[a] = c[a] or {}
      c = c[a]
    end
    c[memoize_fnkey] = c[memoize_fnkey] or {fn(...)}
    return unpack(c[memoize_fnkey])
  end
end


function lume.combine(...)
  local n = select('#', ...)
  if n == 0 then return noop end
  if n == 1 then
    local fn = select(1, ...)
    if not fn then return noop end
    assert(iscallable(fn), "expected a function or nil")
    return fn
  end
  local funcs = {}
  for i = 1, n do
    local fn = select(i, ...)
    if fn ~= nil then
      assert(iscallable(fn), "expected a function or nil")
      funcs[#funcs + 1] = fn
    end
  end
  return function(...)
    for _, f in ipairs(funcs) do f(...) end
  end
end


function lume.call(fn, ...)
  if fn then
    return fn(...)
  end
end


function lume.time(fn, ...)
  local start = os.clock()
  local rtn = {fn(...)}
  return (os.clock() - start), unpack(rtn)
end


local lambda_cache = {}

function lume.lambda(str)
  if not lambda_cache[str] then
    local args, body = str:match([[^([%w,_ ]-)%->(.-)$]])
    assert(args and body, "bad string lambda")
    local s = "return function(" .. args .. ")\nreturn " .. body .. "\nend"
    lambda_cache[str] = lume.dostring(s)
  end
  return lambda_cache[str]
end


local serialize

local serialize_map = {
  [ "boolean" ] = tostring,
  [ "nil"     ] = tostring,
  [ "function" ] = tostring,
  [ "string"  ] = function(v) return string.format("%q", v) end,
  [ "number"  ] = function(v)
    if      v ~=  v     then return  "0/0"      --  nan
    elseif  v ==  1 / 0 then return  "1/0"      --  inf
    elseif  v == -1 / 0 then return "-1/0" end  -- -inf
    return tostring(v)
  end,
  [ "table"   ] = function(t, stk)
    stk = stk or {}
    if stk[t] then error("circular reference") end
    local rtn = {}
    stk[t] = true
    for k, v in pairs(t) do
      rtn[table_getn(rtn) + 1] = "[" .. serialize(k, stk) .. "]=" .. serialize(v, stk)
    end
    stk[t] = nil
    return "{" .. table_concat(rtn, ",") .. "}"
  end
}

setmetatable(serialize_map, {
  __index = function(_, k) error("unsupported serialize type: " .. k) end
})

serialize = function(x, stk)
  return serialize_map[type(x)](x, stk)
end

function lume.serialize(x)
  return serialize(x)
end


function lume.deserialize(str)
  return lume.dostring("return " .. str)
end


function lume.split(str, sep)
  if not sep then
    return lume.array(str:gmatch("([%S]+)"))
  else
    assert(sep ~= "", "empty separator")
    local psep = patternescape(sep)
    return lume.array((str..sep):gmatch("(.-)("..psep..")"))
  end
end


function lume.trim(str, chars)
  if not chars then return str:match("^[%s]*(.-)[%s]*$") end
  chars = patternescape(chars)
  return str:match("^[" .. chars .. "]*(.-)[" .. chars .. "]*$")
end


function lume.wordwrap(str, limit)
  limit = limit or 72
  local check
  if type(limit) == "number" then
    check = function(s) return table_getn(s) >= limit end
  else
    check = limit
  end
  local rtn = {}
  local line = ""
  for word, spaces in str:gmatch("(%S+)(%s*)") do
    local s = line .. word
    if check(s) then
      table_insert(rtn, line .. "\n")
      line = word
    else
      line = s
    end
    for c in spaces:gmatch(".") do
      if c == "\n" then
        table_insert(rtn, line .. "\n")
        line = ""
      else
        line = line .. c
      end
    end
  end
  table_insert(rtn, line)
  return table_concat(rtn)
end


function lume.format(str, vars)
  if not vars then return str end
  local f = function(x)
    return tostring(vars[x] or vars[tonumber(x)] or "{" .. x .. "}")
  end
  return (str:gsub("{(.-)}", f))
end


function lume.trace(...)
  local info = debug.getinfo(2, "Sl")
  local t = { info.short_src .. ":" .. info.currentline .. ":" }
  for i = 1, select("#", ...) do
    local x = select(i, ...)
    if type(x) == "number" then
      x = string.format("%g", lume.round(x, .01))
    end
    t[table_getn(t) + 1] = tostring(x)
  end
  print(table_concat(t, " "))
end


function lume.dostring(str)
  return assert((loadstring or load)(str))()
end


function lume.uuid()
  local fn = function(x)
    local r = math_random(16) - 1
    r = (x == "x") and (r + 1) or (r % 4) + 9
    return ("0123456789abcdef"):sub(r, r)
  end
  return (("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"):gsub("[xy]", fn))
end


function lume.hotswap(modname)
  local oldglobal = lume.clone(_G)
  local updated = {}
  local function update(old, new)
    if updated[old] then return end
    updated[old] = true
    local oldmt, newmt = getmetatable(old), getmetatable(new)
    if oldmt and newmt then update(oldmt, newmt) end
    for k, v in pairs(new) do
      if type(v) == "table" then update(old[k], v) else old[k] = v end
    end
  end
  local err = nil
  local function onerror(e)
    for k in pairs(_G) do _G[k] = oldglobal[k] end
    err = lume.trim(e)
  end
  local ok, oldmod = pcall(require, modname)
  oldmod = ok and oldmod or nil
  xpcall(function()
    package.loaded[modname] = nil
    local newmod = require(modname)
    if type(oldmod) == "table" then update(oldmod, newmod) end
    for k, v in pairs(oldglobal) do
      if v ~= _G[k] and type(v) == "table" then
        update(v, _G[k])
        _G[k] = v
      end
    end
  end, onerror)
  package.loaded[modname] = oldmod
  if err then return nil, err end
  return oldmod
end


local ripairs_iter = function(t, i)
  i = i - 1
  local v = t[i]
  if v then return i, v end
end

function lume.ripairs(t)
  return ripairs_iter, t, (table_getn(t) + 1)
end


function lume.color(str, mul)
  mul = mul or 1
  local r, g, b, a
  r, g, b = str:match("#(%x%x)(%x%x)(%x%x)")
  if r then
    r = tonumber(r, 16) / 0xff
    g = tonumber(g, 16) / 0xff
    b = tonumber(b, 16) / 0xff
    a = 1
  elseif str:match("rgba?%s*%([%d%s%.,]+%)") then
    local f = str:gmatch("[%d.]+")
    r = (f() or 0) / 0xff
    g = (f() or 0) / 0xff
    b = (f() or 0) / 0xff
    a = f() or 1
  else
    error(("bad color string '%s'"):format(str))
  end
  return r * mul, g * mul, b * mul, a * mul
end


function lume.rgba(color)
  local factor = 1.0 / 255.0
  local r = math_floor((color / 16777216) % 256) * factor
  local g = math_floor((color /    65536) % 256) * factor
  local b = math_floor((color /      256) % 256) * factor
  local a = math_floor((color) % 256) * factor
  return r, g, b, a
end

function lume.mergeList(dest, src)
  for i, v in ipairs(src) do
    table_insert(dest, v)
  end
end

local chain_mt = {}
chain_mt.__index = lume.map(lume.filter(lume, iscallable, true),
  function(fn)
    return function(self, ...)
      self._value = fn(self._value, ...)
      return self
    end
  end)
chain_mt.__index.result = function(x) return x._value end

function lume.chain(value)
  return setmetatable({ _value = value }, chain_mt)
end

function lume.sum(arr)
  local num = 0
  for _, v in ipairs(arr) do
    num = num + v
  end
  return num
end

function lume.average(arr)
  local num = 0
  for _, v in ipairs(arr) do
    num = num + v
  end
  if table_getn(arr) > 0 then
    return num / table_getn(arr)
  end
  return 0
end

function lume.union(src_arr, dst_arr)
  local ret = {}
  for _, v in pairs(src_arr) do
    ret[table_getn(ret) + 1] = v
  end
  for _, v in pairs(dst_arr) do
    if not lume.find(ret, v) then
      ret[table_getn(ret) + 1] = v
    end
  end
  return ret
end

function lume.intersection(src_arr, dst_arr)
  local ret = {}
  for _, v in pairs(src_arr) do
    if lume.find(dst_arr, v) then
      ret[table_getn(ret) + 1] = v
    end
  end
  return ret
end

function lume.difference(src_arr, dst_arr)
  local ret = {}
  for _, v in pairs(src_arr) do
    if not lume.find(dst_arr, v) then
      ret[table_getn(ret) + 1] = v
    end
  end
  return ret
end

function lume.limit(v, min_v, max_v)
  if min_v and v < min_v then
    v = min_v
  end
  if max_v and v > max_v then
    v = max_v
  end
  return v
end

-- 插入k,v 结果: t = {[key1] = {val1, val2}, [key2] = {val3, val4}}
-- @param t table
-- @param key any
-- @param val any
function lume.insertkv(t, key, val)
  if not t then
    return
  end
  t[key] = t[key] or {}
  local tmp = t[key]
  tmp[#tmp + 1] = val
end


setmetatable(lume,  {
  __call = function(_, ...)
    return lume.chain(...)
  end
})


return lume
