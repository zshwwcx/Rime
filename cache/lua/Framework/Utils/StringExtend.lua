function string.lead(s, prefix)
	return string.find(s, "^" .. prefix) and true or false
end

function string.MD5(s)
	return string.upper(s:md5())
end

function string.tohex(c)
	local i = string.byte(c)
	return string.format("%%%X", i)
end

function string.diff(s1, s2)
	local len1, len2 = _String.len(s1), _String.len(s2);
	local b, e1, e2 = 0, len1, len2
	local len = math.min(len1, len2)
	for ii = 1, len do
		if _String.sub(s1, ii, ii) ~= _String.sub(s2, ii, ii) then
			break;
		end
		b = ii;
	end

	for ii = 1, len do
		if _String.sub(s1, e1, e1) ~= _String.sub(s2, e2, e2) then
			break;
		end
		e2 = len2 - ii;
		e1 = len1 - ii;
	end
	return b, e1, e2
end

function string.split0(str, pattern)
	pattern = pattern or "[^%s]+"
	if pattern == ',' then pattern = '[^,%s+]' end
	if pattern:len() == 0 then pattern = "[^%s]+" end
	local parts = { __index = table.insert }
	setmetatable(parts, parts)
	str:gsub(pattern, parts)
	setmetatable(parts, nil)
	parts.__index = nil
	return parts
end

function string.split(split_string, pattern, search_pos_begin, plain)
	assert(type(split_string) == "string")

	assert(type(pattern) == "string" and #pattern > 0)

	search_pos_begin = search_pos_begin or 1

	plain = plain or true

	local split_result = {}

	while true do
		local find_pos_begin, find_pos_end =
			string.find(split_string, pattern, search_pos_begin, plain)

		if not find_pos_begin then
			break
		end

		local cur_str = ""

		if find_pos_begin > search_pos_begin then
			cur_str = string.sub(split_string, search_pos_begin, find_pos_begin - 1)
		end
		split_result[#split_result + 1] = cur_str

		search_pos_begin = find_pos_end + 1
	end

	if search_pos_begin <= string.len(split_string) then
		split_result[#split_result + 1] = string.sub(split_string, search_pos_begin)
	else
		split_result[#split_result + 1] = ""
	end

	return split_result
end

function string.uchar(u)
	if u <= 127 then return string.char(u) end
	if u <= 0x7ff then return string.char(0xc0 + toint(u / 64), 0x80 + u % 64) end
	return string.char(0xe0 + toint(u / 4096), 0x80 + toint(u / 64 % 64), 0x80 + u % 64)
end

function string.ulen(s)
	return _String.len(s)
end

function string.slen(s)
	local chars = string.ulen(s)
	local bytes = string.len(s)
	local utfch = (bytes - chars) / 2
	return chars + utfch
end

function string.trim(s) --?
	return (s:gsub('^%s*(.-)%s*$', '%1'))
end

function string.ip2string(ip) --ip int->xxx.xxx.xxx.xxx
	local s = string.format('%08x', ip)
	local h1 = toint('0x' .. string.sub(s, 1, 2))
	local h2 = toint('0x' .. string.sub(s, 3, 4))
	local l1 = toint('0x' .. string.sub(s, 5, 6))
	local l2 = toint('0x' .. string.sub(s, 7, 8))
	return string.format('%s.%s.%s.%s', h1, h2, l1, l2)
end

function string.contains(target_string, pattern, plain)
	plain = plain or true

	local find_pos_begin, _ = string.find(target_string, pattern, 1, plain)

	return find_pos_begin ~= nil
end

function string.findLast(str, pattern)
	local lastMatchIndex = nil
	local startPosition = 1
	repeat
		local matchStart, matchEnd = string.find(str, pattern, startPosition)
		if matchStart ~= nil then
			lastMatchIndex = matchStart
			startPosition = matchEnd + 1
		end
	until matchStart == nil

	return lastMatchIndex
end

function string.notNilOrEmpty(str)
	local result = str and string.len(str) > 0
	return result == true
end

function string.isEmpty(str)
	return str == nil or str == ""
end

function string.startsWith(str, start)
	if str == nil or start == nil then
		return false
	end
	return str:sub(1, #start) == start
end

function string.endsWith(str, ending)
	if str == nil or ending == nil then
		return false
	end
	return ending == "" or str:sub(- #ending) == ending
end

-- local function unserialize(flattb, tb, visited)
-- 	if not visited[tb] then
-- 		visited[tb] = true
-- 		for key, v in next, tb.__ref__ do
-- 			tb[key] = flattb[v]
-- 			unserialize(flattb, flattb[v], visited)
-- 		end
-- 		tb.__ref__ = nil
-- 	end
-- end

-- function string.toTable(str)
-- 	local flattb = loadstring('return ' .. str)()
-- 	if #flattb > 1 then --
-- 		local tbs = {}
-- 		for _, ftb in next, flattb do
-- 			local tb = ftb['tb0']
-- 			if tb then
-- 				unserialize(ftb, tb, {})
-- 			else
-- 				tb = ftb
-- 			end
-- 			table.insert(tbs, tb)
-- 		end
-- 		return tbs
-- 	else
-- 		local tb = flattb['tb0']
-- 		if tb then
-- 			unserialize(flattb, tb, {})
-- 		else
-- 			tb = flattb
-- 		end
-- 		return { tb }
-- 	end
-- end

function string.chsize(char)
    local arr = { 0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc }

    if not char then
        return 0
    else
        for i = #arr, 1, -1 do
            if char >= arr[i] then
                return i
            end
        end
    end
end

function string.toList(str)
	local list = {}
	local currentIndex = 1
	while currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		local cLen = string.chsize(char)
		list[#list + 1] = str:sub(currentIndex, currentIndex + cLen - 1)
		currentIndex = currentIndex + cLen
	end
	return list
end

function string.utf8len(input)
	local len = string.len(input)
	local left = len
	local cnt = 0
	local arr = { 0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc }
	while left ~= 0 do
		local tmp = string.byte(input, -left)
		local i = #arr
		while arr[i] do
			if tmp >= arr[i] then
				left = left - i
				break
			end
			i = i - 1
		end
		cnt = cnt + 1
	end
	return cnt
end

local function chsize(char)
	local arr = { 0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc }

	if not char then
		return 0
	else
		for i = #arr, 1, -1 do
			if char >= arr[i] then
				return i
			end
		end
	end
end

function string.utf8sub(str, startChar, numChars)
	local startIndex = 1
	while startChar > 1 do
		local char = string.byte(str, startIndex)
		startIndex = startIndex + chsize(char)
		startChar = startChar - 1
	end
	local currentIndex = startIndex

	while numChars > 0 and currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		currentIndex = currentIndex + chsize(char)
		numChars = numChars - 1
	end
	return str:sub(startIndex, currentIndex - 1)
end

-- 策划特殊需求:截取前n个字符, 中文算2个字符,
-- 若截断处为中文,中文字要保留完整。
function string.pm02sub(str, numChars)
	local currentIndex = 1

	while numChars > 0 and currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		local cLen = chsize(char)
		local minus = cLen > 1 and 2 or 1
		currentIndex = currentIndex + cLen
		numChars = numChars - minus
	end
	return str:sub(1, currentIndex - 1)
end

-- 用法与pm02sub一样，在保证中文完整的基础上，不超过numChars的限制
function string.pm02strictSub(str, numChars)
	local currentIndex = 1
	while numChars > 0 and currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		local cLen = chsize(char)
		local minus = cLen > 1 and 2 or 1
		numChars = numChars - minus
		if numChars >= 0 then
			currentIndex = currentIndex + cLen
		end
	end
	return str:sub(1, currentIndex - 1), currentIndex - 1
end

-- 用法与pm02sub一样，返回截断的前后字符串
function string.pm02subTotal(str, numChars)
	local currentIndex = 1

	while numChars > 0 and currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		local cLen = chsize(char)
		local minus = cLen > 1 and 2 or 1
		currentIndex = currentIndex + cLen
		numChars = numChars - minus
	end
	return str:sub(1, currentIndex - 1), str:sub(currentIndex)
end

-- 截断字符串，每行最多numlimit个字符
function string.strictCutText(text, numLimit)
	local ret = ""
	local strList = string.split(text, '\n')
	for i, str in ipairs(strList) do
		local numChars, startIndex, currentIndex = numLimit, 1, 1
		while currentIndex <= #str do
			while numChars > 0 and currentIndex <= #str do
				local char = string.byte(str, currentIndex)
				local cLen = chsize(char)
				local minus = cLen > 1 and 2 or 1
				numChars = numChars - minus
				if numChars >= 0 then
					currentIndex = currentIndex + cLen
				end
			end
			if startIndex == currentIndex then
				Log.Error("numlimit is wrong，string can not be cut")
				return
			end
			local part = str:sub(startIndex, currentIndex - 1)
			ret = ret .. part
			if i ~= #strList or currentIndex <= #str then
				ret = ret .. '\n'
			end
			startIndex, numChars = currentIndex, numLimit
		end
	end
	return ret
end

function string.lcfirst(input)
	return string.lower(string.gsub(input, 1, 1)) .. string.gsub(input, 2)
end
