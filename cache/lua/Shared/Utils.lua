-- 前后端公用的基础Utils函数，业务模块相关的不要加到这里，加到自己模块对应的XXUtils文件
local const = kg_require("Shared.Const")
local timeUtils = kg_require("Shared.Utils.TimeUtils")
local bitset = kg_require("Shared.lualibs.bitset")

local TableData = Game.TableData or TableData

local math_random = math.random
local math_floor = math.floor
local math_ceil = math.ceil
local math_cos = math.cos
local math_sin = math.sin
local math_sqrt = math.sqrt
local string_byte = string.byte
local string_format = string.format
local string_gsub = string.gsub
local string_len = string.len
local string_sub = string.sub
local table_remove = table.remove
local tostring = tostring
local type = type


-- List随机洗牌
function ShuffleList(InTable)
    if (InTable == nil) or (type(InTable) ~= "table") then
        return InTable
    end

    local Size = #InTable
    for i = 1, Size do
        local j = math.random(i, Size)
        InTable[i], InTable[j] = InTable[j], InTable[i]
    end

    return InTable
end

function PopFromMapByNum(map, num)
    local r = {}
    for i, v in pairs(map) do
        if num <= 0 then
            return r
        end
        num = num - 1
        r[i] = v
        map[i] = nil
    end
    return r
end

function CompressArray(array, beginIndex, oldSize)
    local j = beginIndex
    for i = beginIndex, oldSize do
        local temp = array[i]
        if temp ~= nil then
            if i ~= j then
                array[i] = nil
                array[j] = temp
            end
            j = j + 1
        end
    end
end

function deepCopyTable(t)
    if not t then
        return
    end
    local ret = {}
    for k, v in pairs(t) do
        -- 部分属性是userdata
        if type(v) == "table" or type(v) == "userdata" then
            ret[k] = deepCopyTable(v)
        else
            ret[k] = v
        end
    end
    return ret
end

function HasKeyValue(list, key, value)
    for i, v in ipairs(list) do
        if v[key] == value then
            return v, i
        end
    end
end

function isnan(number)
    return not (number == number)
end

function isinf(number)
    return number == math.huge or number == -math.huge
end

function IsNanOrInf(number)
    return isnan(number) or isinf(number)
end

function getUnicodeValue(utf8Value)
    if not utf8Value then
        return 0
    end
    local input = utf8Value
    local base = 0x80
    local arr = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    local len = string_len(input)
    local value = 0
    for i = 1, len do
        local tmp = string_byte(input, i)
        if i == 1 then
            local j = #arr
            while arr[j] do
                if tmp >= arr[j] then
                    break
                end
                j = j - 1
            end
            value = tmp - arr[j]
        else
            value = bitset.lshift(value, 6) + tmp - base
        end
    end
    return value
end

function checkChineseOrAscii(input)
    local ranges = {
        [1] = {0, 127}, --unicode ascii范围
        [2] = {0x4e00, 0x9fa5}, -- unicode 中文范围
    }
    local value = getUnicodeValue(input)
    for _, range in ipairs(ranges) do
        if range[1] <= value and value <= range[2] then
            return true
        end
    end
    return false
end

function Compare2fNumber(value, target)
    if type(value) == "number" then
        if value % 1 ~= 0 then  -- 数字是小数
            return math_floor(value * 100) == target * 100
        end
    end

    return value == target
end

--- 过滤除中文和ascii表的字符
-- @param input
-- @return output
function GetFilterString(input)
    if not input then
        return ""
    end

    local output = ""
    local len = string_len(input)
    local left = len
    local arr = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string_byte(input, -left)
        local i = #arr
        while arr[i] do
            if tmp >= arr[i] then
                local tmpString = string_sub(input, -left, -(left - i + 1))
                if checkChineseOrAscii(tmpString) then
                    output = output .. tmpString
                end
                left = left - i
                break
            end
            i = i - 1
        end
    end
    return output
end

-- TODO: 待实现
function GetPlayerHref(name, gbId, colorFormat)
    return name
end

function PopByKeyValue(list, key, value)
    for i, v in ipairs(list) do
        if v[key] == value then
            table_remove(list, i)
            return v
        end
    end
end

function GetGroupCD(cdGroupId)
    local cfd = TableData.GetCDGroupDataRow(cdGroupId)
    return cfd and cfd.groupCD or 0
end

function GetItemCdInfo(itemId)
    local cdGroupId = 0
    local cdServerGroupId = 0
    local groupCD = 0
    local serverGroupCD = 0
    local idd = TableData.GetItemNewDataRow(itemId)
    cdGroupId = idd and idd.cdGroupId
    cdGroupId = cdGroupId or 0
    cdServerGroupId = idd and idd.cdServerGroupId or 0
    groupCD = GetGroupCD(cdGroupId)
    serverGroupCD = GetGroupCD(cdServerGroupId)
    return cdGroupId, groupCD, cdServerGroupId, serverGroupCD
end

function getServerOpenDays(openTime, now)
    if now < openTime then
        return 0
    else
        local dayStartTime = timeUtils.getDayStartTime(openTime)
        return math.ceil((now - dayStartTime + 1) / const.SECONDS_ONE_DAY)
    end
end

function GetWeekNumFromServerOpen(openTime, now)
    local openWeekStartTime = timeUtils.getWeekStartTime(openTime)
    local nowWeekStartTime = timeUtils.getWeekStartTime(now)
    local day = getServerOpenDays(openWeekStartTime, nowWeekStartTime)
    if day <= 0 then
        return 0
    else
        return math.floor((day - 1) / const.DAYS_ONE_WEEK) + 1
    end
end

function GetAddAttractionBySourceType(sourceType)
    local asdd = TableData.GetFriendAttractionSourceDataRow(sourceType)
    if not asdd then
        return
    end

    return asdd.AttractionIncrement
end

function math.round(value)
    return value >= 0 and math_floor(value + .5) or math_ceil(value - .5)
end

function table.nums(t)
    local count = 0
    for k, v in pairs(t) do
        count = count + 1
    end
    return count
end

function table.keys(hashtable)
    local keys = {}
    for k, v in pairs(hashtable) do
        keys[#keys + 1] = k
    end
    return keys
end

function table.values(hashtable)
    local values = {}
    for k, v in pairs(hashtable) do
        values[#values + 1] = v
    end
    return values
end

function table.merge(dest, src)
    for k, v in pairs(src) do
        dest[k] = v
    end
end

function string.ltrim(input)
    return string_gsub(input, "^[ \t\n\r]+", "")
end

function string.rtrim(input)
    return string_gsub(input, "[ \t\n\r]+$", "")
end

function string.trim(input)
    input = string_gsub(input, "^[ \t\n\r]+", "")
    return string_gsub(input, "[ \t\n\r]+$", "")
end

local function urlencodechar(char)
    return "%" .. string_format("%02X", string_byte(char))
end

function string.urlencode(input)
    -- convert line endings
    input = string_gsub(tostring(input), "\n", "\r\n")
    -- escape all characters but alphanumeric, '.' and '-'
    input = string_gsub(input, "([^%w%.%- ])", urlencodechar)
    -- convert spaces to "+" symbols
    return string_gsub(input, " ", "+")
end

function string.urldecode(input)
    input = string_gsub (input, "+", " ")
    input = string_gsub (input, "%%(%x%x)", function(h) return string_char(checknumber(h,16)) end)
    input = string_gsub (input, "\r\n", "\n")
    return input
end

function string.utf8len(input)
    local len  = string_len(input)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string_byte(input, -left)
        local i   = #arr
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

RandomInt = math.random
ABS = math.abs
MAX = math.max
MIN = math.min
ROUND = math.round
FLOOR = math.floor
CEIL = math.ceil