--table
local type = type
local next = next
local pairs = pairs
-- 部分编辑器环境下没有启用ksbc
local ksbcpairs = ksbcpairs or pairs
local ksbcipairs = ksbcipairs or ipairs
--talbe.sort(t,table.ACS) talbe.sort(t,table.asc('k'))
function table.ACS(a, b) return a < b end

function table.asc(k) return function(a, b) return a[k] < b[k] end end

function table.DESC(a, b) return a > b end

function table.desc(k) return function(a, b) return a[k] > b[k] end end

function table.orderby(...) --table.orderby('score','desc','time','asc')
	local tb = { ... }
	return function(a, b)
		for i = 1, #tb, 2 do
			local k = tb[i]
			local by = tb[i + 1]
			assert(a[k] ~= nil, 'table.orderby nil ' .. k)
			assert(b[k] ~= nil, 'table.orderby nil ' .. k)
			if a[k] == b[k] then
			else
				if by == 'desc' then
					return a[k] > b[k]
				else
					return a[k] < b[k]
				end
			end
		end
		return false
	end
end

function inext(t, i)
	i = i == nil and 1 or int(i) + 1
	t = rawget(t, i)
	if t == nil then return end
	return i, t
end

local visited;
function table.singlefind(tb, func, path)
	for k, v in next, tb do
		if type(v) == 'table' then
			if not visited[v] then
				visited[v] = true;
				if func(v) then
					table.insert(path, k);
					return true;
				else
					table.insert(path, k);
					if table.singlefind(v, func, path) then
						return path;
					end
					path[#path] = nil;
				end
			end
		end
	end
	return false;
end

function table.template(tb)
	local s, loop = table.tostring(tb)
	if loop then
		if not PUBLIC then
			assert("template loop table")
		end
		return loadstring('return string.totable[===[' .. s .. ']===]')
	else
		return loadstring('return ' .. s)
	end
end

local tpns = {}
function table.templaten(n)
	if n <= 0 then return {} end
	if tpns[n] then return tpns[n]() end
	local tb = {}
	for ii = 1, n do
		tb[ii] = 0
	end
	local tpn = table.template(tb)
	tpns[n] = tpn
	return tpn()
end

function table.tocsv(tb)
	local t = {};
	for ii = 1, #tb do
		local line = tb[ii];
		if type(line) == 'table' then
			local newline = table.duplicate(line);
			for k, v in next, newline do
				if type(v) == "string" and string.find(v, ",") then
					newline[k] = '"' .. table.concat(string.split(v, '"'), '""') .. '"';
				end
			end
			table.insert(t, table.concat(newline, ','));
		else
			error("error format for csv");
		end
	end
	return table.concat(t, "\r\n");
end

function table.filter(tb, func)
	local newtb = {};
	for k, v in next, tb do
		if func(v) then
			newtb[k] = v;
		end
	end
	return newtb;
end

function table.cover(dest, src)
	local samek -- true
	for k, v in next, src do
		if dest[k] ~= v then
			dest[k] = v
			if dest[k] == nil then
				samek = false
			elseif samek == nil then
				samek = true
			end
		end
	end
	return dest, samek
end

function table.find(tb, func)
	visited = {};
	return table.singlefind(tb, func, {});
end

function table.add(tb, col, newcol)
	local v = 0
	for ii = 1, #tb do
		v = v + tb[ii][col]
		tb[ii][newcol] = v
	end
	return tb
end

function table.ikey(tb, v)
	for ii = 1, #tb do
		if tb[ii] == v then return ii; end
	end
end

if not table.clear then
	function table.clear(t)
		if not t then return t end
		for k, v in pairs(t) do
			t[k] = nil
		end
		return t
	end
else
	local clear0 = table.clear
	function table.clear(t)
		if not t then return end
		return clear0(t)
	end
end

function table.pushv(dest, src)
	for k, v in next, src do
		table.insert(dest, v)
	end
	return dest
end

function table.removev(tb, value)
	for k, v in next, tb do
		if v == value then
			table.remove(tb, k)
			return
		end
	end
end

-- slice函数，切片start_index-->end_index,包含start_index和end_index，不支持负坐标
function table.slice(tb, start_index, end_index)
	if start_index < 0 or end_index < 0 then
		return
	end

	local sliced = {}
	local n = #tb

	if end_index > #tb then
		end_index = #tb
	end

	start_index = math.max(1, start_index)
	end_index = math.min(n, end_index)

	for i = start_index, end_index do
		table.insert(sliced, tb[i])
	end

	return sliced
end

function table.recursive(dest, src)
	for k, v in next, src do
		if type(v) == "table" and type(dest[k]) == "table" then
			table.recursive(dest[k], v)
		else
			dest[k] = v
		end
	end
	return dest
end

function table.del(tb, dels)
	for k, v in next, dels do
		if type(v) == 'table' then
			table.del(tb[k], v);
		else
			tb[k] = nil;
		end
	end
end

function table.readonly(x, name, deep)
	if deep then
		for k, v in next, x do
			if type(v) == 'table' then
				x[k] = table.readonly(v, name .. '.' .. k, true)
			end
		end
	end
	local m = {}
	m.__newindex = function() error(name and 'readonly ' .. name or 'readonly') end
	return setmetatable(x, m), m
end

local oldCpoy = table.copy
function table.copy(t1, t2)
	if t2 == nil then return t1; end;
	return oldCpoy(t1, t2)
end

function table.copyAll(t1, t2)
	local t = t2;
	while t do
		table.copy(t1, t);
		t = getmetatable(t2);
	end
	return t1;
end

function table.keys(t, keys)
	local keys = keys or {}
	for k, _ in next, t do
		keys[#keys + 1] = k
	end
	return keys
end

function table.ikeys(t)
	local s = {}
	for i = 1, #t do
		s[i] = i
	end
	return s
end

function table.values(t)
	local values = {}
	for k, v in pairs(hashtable) do
		values[#values + 1] = v
	end
	return values
end

function table.compare(t1, t2)
	t1 = t1 or EMPTY
	t2 = t2 or EMPTY
	local com, r1, r2 = {}, table.append({}, t1), table.append({}, t2);
	for k, v in next, t1 do
		if t2[k] == v then
			com[k] = v;
			r1[k] = nil;
			r2[k] = nil;
		end
	end
	return com, r1, r2;
end

function table.reverse(t, func)
	local r = {};
	for k, v in next, t do
		r[v] = func and func(k) or k;
	end
	return r;
end

function table.collect(t)
	local arr = {}
	for ii = 1, table.maxn(t) do
		if t[ii] then
			table.insert(arr, t[ii]);
		end
	end
	return arr;
end

function table.minn(t)
	for ii = 1, #t do
		if t[ii] then
			return ii;
		end
	end
end

function table.minv(tb, key)
	local minv = math.huge
	for _, v in next, tb do
		local rv = key and v[key] or v
		minv = math.min(minv, rv)
	end
	return minv
end

function table.min(t)
	local firstk
	for k = 1, #t do
		if t[k] then
			firstk = k
			break
		end
	end
	local minnum = t[firstk]
	local pos = firstk
	if not minnum then return end
	for k = 1, #t do
		local v = t[k]
		if v < minnum then
			minnum = v
			pos = k
		end
	end
	return minnum, pos
end

function table.max(t)
	local firstk
	for k, _ in next, t do
		if t[k] then
			firstk = k
		end
	end
	local maxnum = t[firstk]
	local pos = firstk
	assert(maxnum, 'blank table')
	for k, v in next, t do
		if v > maxnum then
			maxnum = v
			pos = k
		end
	end
	return maxnum, pos
end

function table.count(t)
	local sum = 0
	-- 低频，可以统一表格数据和普通table的count写法
	for k, v in ksbcpairs(t) do
		sum = sum + 1
	end
	return sum
end

function table.getn(list)
	local sum = 0
	for k, _ in ksbcipairs(list) do
		sum = sum + 1
	end
	return sum
end

function table.maxn(t)
	local mn = 0
	for k, v in pairs(t) do
		if mn < k then
			mn = k
		end
	end
	return mn
end

function table.addValue(base, app)
	for k, v in pairs(app) do
		if type(v) == 'number' then
			base[k] = (base[k] or 0) + v
		else
			base[k] = table.addValue(base[k] or {}, v)
		end
	end
	return base
end

function table.flat(t, flattb, visited)
	local tbname = 'tb' .. flattb.lv
	if not visited[t] then --
		flattb[tbname] = { __ref__ = {} }
		visited[t] = tbname
		for k, v in next, t do
			if type(v) ~= 'table' then
				flattb[tbname][k] = v
			else
				if not visited[v] then
					flattb.lv = flattb.lv + 1
					local newtbname = 'tb' .. flattb.lv
					flattb[tbname][k] = newtbname
					flattb[tbname].__ref__[k] = newtbname
					table.flat(v, flattb, visited)
				else
					flattb.loop = true
					flattb[tbname][k] = visited[v]
					flattb[tbname].__ref__[k] = visited[v]
				end
			end
		end
	end
end

local function serialize(o, s)
	if type(o) == "number" then
		s = s .. o;
	elseif type(o) == "string" then
		s = s .. "[===[" .. o .. "]===]";
	elseif type(o) == "boolean" then
		s = s .. (o and "true" or "false");
	elseif type(o) == "table" then
		s = s .. "{";
		for k, v in next, o do
			if type(k) == 'number' then
				s = s .. "[" .. k .. "]=";
				s = serialize(v, s);
				s = s .. ","
			elseif type(k) == 'string' then
				s = s .. "['" .. k .. "']=";
				s = serialize(v, s);
				s = s .. ","
			elseif type(k) == "boolean" then
				s = s .. "[" .. (k and "true" or "false") .. "]=";
				s = serialize(v, s);
				s = s .. ","
			end
		end
		s = s .. "}";
	elseif type(o) == "function" then
	elseif type(o) == "userdata" then
	else
		error("cannot serialize a " .. type(o))
	end
	return s
end

function table.tonumber(t)
	local t2 = {}
	for k, v in next, t do
		t2[k] = tonumber(v);
	end
	return t2;
end

function table.tostring(t) --
	local flattb, visited = { lv = 0 }, {}
	table.flat(t, flattb, visited)
	flattb.lv = nil
	if not flattb.loop then --
		return serialize(t, ""), false;
	else
		flattb.loop = nil
		return serialize(flattb, ""), true;
	end
end

function table.minn(t)
	for ii = 1, #t do
		if not t[ii] then
			return ii
		end
	end
	return #t + 1
end

function table.tostr(t, tabnum, float, ts) --树形字串
	local tabnum = tabnum or 1
	local tt = type(t)
	assert(tt == 'table', 'bad argument #1 table expected, got ' .. tt)
	ts = ts or {}
	ts[#ts + 1] = '{\n'
	local t0 = table.keys(t)
	table.sort(t0, function(a, b)
		if type(a) == 'number' and type(b) == 'number' then
			return a < b
		elseif type(a) == 'number' and type(b) ~= 'number' then
			return true
		elseif type(b) == 'number' and type(a) ~= 'number' then
			return false
		else
			return tostring(a) < tostring(b)
		end
	end)

	for i = 1, #t0 do
		local k = t0[i]
		local v = t[k]
		local tv = type(v)
		local tk = type(k)
		for _ = 1, tabnum do
			ts[#ts + 1] = '\t'
		end
		if tk == 'number' then
			ts[#ts + 1] = '['
			ts[#ts + 1] = k
			ts[#ts + 1] = ']'
		elseif tk == 'string' then
			ts[#ts + 1] = '["'
			ts[#ts + 1] = k
			ts[#ts + 1] = '"]'
		end
		if tv == 'table' then
			ts[#ts + 1] = '='
			table.tostr(v, tabnum + 1, float, ts)
			ts[#ts + 1] = ',\n'
		elseif tv == 'string' then
			if not _G.stringflag then
				ts[#ts + 1] = "='" .. v .. "'"
			else
				ts[#ts + 1] = '=[===['
				ts[#ts + 1] = v
				ts[#ts + 1] = ']===]'
			end
			ts[#ts + 1] = ',\n'
		elseif tv == 'number' then
			if v ~= toint(v) and float then
				assert(float >= 0 and toint(float) == float, '')
				ts[#ts + 1] = '='
				ts[#ts + 1] = string.format("%." .. float .. "f", v)
				ts[#ts + 1] = ',\n'
			else
				ts[#ts + 1] = '='
				ts[#ts + 1] = tostring(v)
				ts[#ts + 1] = ',\n'
			end
		else
			ts[#ts + 1] = '='
			ts[#ts + 1] = tostring(v)
			ts[#ts + 1] = ',\n'
		end
	end
	ts[#ts + 1] = '\n'
	for i = 1, tabnum do
		ts[#ts + 1] = '\t'
	end
	ts[#ts + 1] = '}'
	return table.concat(ts)
end

if not table.duplicate then
	function table.duplicate(tb)
		return table.copy({}, tb)
	end
end

function table.cloneconf(st) --deep copy
	local dt = {}
	if type(st) ~= 'table' then
		error('source is not table in table.clone')
	else
		for k, v in next, st do
			if type(v) ~= 'table' then
				dt[k] = v
			else
				dt[k] = table.cloneconf(v)
			end
		end
	end
	return dt
end

function table.clone(st) --深copy
	local dt = table.duplicate(st)
	if type(st) ~= 'table' then
		error('source is not table in table.clone')
	else
		for k, v in next, st do
			if type(v) == 'table' then
				dt[k] = table.clone(v)
			end
		end
	end
	return dt
end

function table.replace(t, r) --  handle buff
	for k, v in next, t do
		if type(v) == "string" then
			local a = {};
			for s in string.gmatch(v, "var%d+") do
				table.insert(a, s);
			end
			if #a == 1 and a[1] == v then
				local index = string.find(v, "%d");
				local value = r["var" .. string.sub(v, index)];
				if not value then
					Log.Fatal(r.id, "no define", "var", string.sub(v, index));
				end
				t[k] = value;
			end
		elseif type(v) == "table" then
			t[k] = table.replace(v, r);
		end
	end
	return t;
end

function table.delEmpty(tbl)
	if not next(tbl) then
		return nil
	end
	for k, v in next, tbl do
		if type(v) == 'table' then
			tbl[k] = table.delEmpty(v)
		end
	end
	return tbl
end

local function hequal(tb1, tb2)
	if #table.keys(tb1) ~= #table.keys(tb2) then return false; end
	for k1, v1 in next, tb1 do
		if not table.equal(v1, tb2[k1]) then return false; end
	end
	return true;
end

function table.equal(tb1, tb2)
	local kd1, kd2 = type(tb1), type(tb2)
	if kd1 ~= kd2 then return false; end
	if kd1 == 'table' then return hequal(tb1, tb2) end
	return tb1 == tb2 or (tb1 ~= tb1 and tb2 ~= tb2) --nan
end

function table.pre(tb1, tb2)
	if not tb2 then return tb1 == nil end
	for ii = 1, #tb1 do
		if not table.equal(tb1[ii], tb2[ii]) then return false end
	end
	return true
end

function table.childequalex(v1, tb2)
	local has = false
	for k2, v2 in next, tb2 do
		if table.equal(v1, v2) then
			has = true
			break
		end
	end
	return has
end

function table.childequal(tb1, tb2)
	local kd1, kd2 = type(tb1), type(tb2)
	if kd1 ~= kd2 then return false end
	if kd1 == 'table' then
		for k1, v1 in next, tb1 do
			if not table.childequalex(v1, tb2) then return false end
		end
		for k2, v2 in next, tb2 do
			if not table.childequalex(v2, tb1) then return false end
		end
		return true
	end
	return tb1 == tb2
end

function table.recursive(dest, src)
	local type = type;
	for k, v in next, src do
		if type(v) == "table" and type(dest[k]) == "table" then
			table.recursive(dest[k], v);
		else
			dest[k] = v;
		end
	end
	return dest;
end

function table.sub(tb, from, to)
	from = from or 1
	to = to or #tb
	local ntb = {}
	for ii = from, to do
		table.insert(ntb, tb[ii])
	end
	return ntb
end

local weakk = { __mode = 'kiss me' }
function table.weakk()
	return setmetatable({}, weakk)
end

local weakv = { __mode = 'love you' }
function table.weakv()
	return setmetatable({}, weakv)
end

--
function table.intable(tb, val, key)
	for _, v in pairs(tb) do
		if val == (key and v[key] or v) then return true end
	end
end

function table.noarray(s)
	local ss = {}
	for k, v in next, s do
		if type(k) ~= 'number' then ss[k] = v end
	end
	return ss
end

function table.findpos(tb, val, key)
	for ii = 1, #tb do
		if tb[ii][key] > val then return ii - 1 end
	end
end

function table.append(a, b)
	for k, v in next, b do
		if a[k] == nil then
			a[k] = v
		end
	end
end

function table.isInArray(tab, value, begin)
	if begin == nil then
		begin = 1
	end
	for i = begin, #tab do
		if tab[i] == value then
			return true
		end
	end
	return false
end

function table.arrayIndexOf(tab, value, begin)
	if begin == nil then
		begin = 1
	end
	for i = begin, #tab do
		if tab[i] == value then
			return i
		end
	end
	return false
end

function table.extend(tab1, tab2)
	for _, val in ipairs(tab2) do
		tab1[#tab1 + 1] = val
	end
end

--- 求 table 中所有元素的和，
---@generic V1, V2
---@param tbl V1[]
---@param valueGetter fun(v: V1): V2 元素值获取器，默认元素自身
---@return V2
function table.sum(tbl, valueGetter)
	valueGetter = valueGetter or function(v) return v end
	local result = 0
	for value in table.values(tbl) do
		result = result + valueGetter(value)
	end
	return result
end

function table.merge(dest, src)
	for k, v in pairs(src) do
		dest[k] = v
	end
end

function table.mergeList(dest, src)
	for i, v in ipairs(src) do
		table.insert(dest, v)
	end
end

function table.removeItem(list, item, removeAll)
	local rmCount = 0

	for i = 1, #list do
		if list[i - rmCount] == item then
			table.remove(list, i - rmCount)

			if removeAll then
				rmCount = rmCount + 1
			else
				break
			end
		end
	end
end

function table.removeByFunc(list, func)
	local count = list and #list or 0
	for i = count, 1, -1 do
		if func(list[i]) then
			table.remove(list, i)
		end
	end
end

function table.contains(table, element)
	if table == nil then
		return false
	end

	for _, value in ksbcpairs(table) do
		if value == element then
			return true
		end
	end
	return false
end
