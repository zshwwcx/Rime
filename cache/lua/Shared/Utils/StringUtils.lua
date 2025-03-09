local table_insert = table.insert
local table_concat = table.concat
local string_byte = string.byte


-- 判断utf8字符byte长度
local function chsize(char)
    if not char then
        return 0
    elseif char > 240 then
        return 4
    elseif char > 225 then
        return 3
    elseif char > 192 then
        return 2
    else
        return 1
    end
end


--截取字符串，按字符截取
-- str:         要截取的字符串
-- startChar:   开始字符下标,从1开始
-- numChars:    要截取的字符长度
function utf8sub(str, startChar, numChars)
	local startIndex = 1
    while startChar > 1 do
        local char = string_byte(str, startIndex)
        startIndex = startIndex + chsize(char)
        startChar = startChar - 1
    end

    local currentIndex = startIndex

    while numChars > 0 and currentIndex <= #str do
        local char = string_byte(str, currentIndex)
        currentIndex = currentIndex + chsize(char)
        numChars = numChars -1
    end
    return str:sub(startIndex, currentIndex - 1), numChars
end


-- 计算utf8字符串字符数, 各种字符都按一个字符计算
function utf8len(str)
    local len = 0
    local currentIndex = 1
    while currentIndex <= #str do
        local char = string_byte(str, currentIndex)
        currentIndex = currentIndex + chsize(char)
        len = len +1
    end
    return len
end


-- 计算utf8字符串字符数, 中文按两个字符计算
function utf8len_ChineseInTwo(str)
    local len = 0
    local currentIndex = 1
    while currentIndex <= #str do
        local char = string_byte(str, currentIndex)
        local charLength = chsize(char)
        currentIndex = currentIndex + charLength
        if charLength > 2 then
            len = len + 2
        else
            len = len +1
        end
    end
    return len
end


-- 中英文字符都按一位算，进行字符替换
function utf8replace(str, startIdx, length, replaceChar)
    if replaceChar == nil then
        replaceChar = "*"
    end
    local chars = {}
    for i = 1, utf8len(str) do
        local t, _ = utf8sub(str, i, 1)
        table_insert(chars, t)
    end
    for i = startIdx, startIdx + length - 1 do
        chars[i] = replaceChar
    end
    return table_concat(chars)
end
