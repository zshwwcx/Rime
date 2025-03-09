local getValueByStrAddr = _ksbc_get_value_by_str_addr_key
local getValueByNum = _ksbc_get_value_by_num_key
local getLen = _ksbc_len
local getHandle = _ksbc_get_handle_from_ud
local getStrByAddr = _ksbc_get_str_by_addr
local nextWithNil = _ksbc_next_nil_key
local nextWithNum = _ksbc_next_num_key
local nextWithStrAddr = _ksbc_next_str_addr_key
local getUdByAddr = _ksbc_get_ud_by_addr
local getStartHandle = _ksbc_get_start_handle
local addStr = _ksbc_add_str
local ksbcPatch = _ksbc_patch

local Game = Game or {}

--缓存二进制表
local udCache = {}
setmetatable(udCache, {__mode = 'v'})
rawset(_G, '__KSBC_udCache', udCache)

local metatable = {}
rawset(_G, '__KSBC_metatable', metatable)

--建立字符串到地址和地址到字符串的映射关系，这样不用频繁在c++和lua之间拷贝字符串
local str2addr = {}
rawset(_G, '__KSBC_str2addr', str2addr)
local addr2str = {}
rawset(_G, '__KSBC_addr2str', addr2str)
--}}}初始化

local LANGUAGE_VT_GAP = 10
local rawNumType = 0
local rawStrType = 1
local rawIntType = 4
local LanNumType = rawNumType + LANGUAGE_VT_GAP
local LanStrType = rawStrType + LANGUAGE_VT_GAP
local LanIntType = rawIntType + LANGUAGE_VT_GAP

--{{{lua访问二进制策划表的接口
--字符串地址/table handle转成真正的值
local function ref2Val(addrOrVal, valType)
    if addrOrVal == nil then
        return nil
    end
    if not valType then
        return addrOrVal
    end
    local val

    if valType == rawStrType or valType == LanStrType then
        --string
        val = addr2str[addrOrVal]
        if not val then
            val = getStrByAddr(addrOrVal)
            addr2str[addrOrVal] = val
        end
    elseif valType == rawNumType or valType == LanNumType or valType == rawIntType or valType == LanIntType then
        val = addrOrVal
    elseif valType == 2 then
        --userdata
        val = udCache[addrOrVal]
        if val == nil then
            val = getUdByAddr(addrOrVal)
            udCache[addrOrVal] = val
        end
    end

    if valType == LanStrType or valType==LanNumType then
        return ksbcMultiLanguageQueryCB(val)
    end
    return val
end

ksbcMultiLanguageQueryCB = nil
function SetKsbcMultiLanguageSupportCB(queryCB) 
    ksbcMultiLanguageQueryCB = queryCB
end

--获取原始二进制表入口(不考虑patch)
function ksbcRawG()
    return ref2Val(getStartHandle(), 2)
end


-- 多层table转换
function ksbc2DeepTable(tbl)
    -- C7 FIX START BY SHIJINGZHE
    error("deep copy of ksbc data forbidden")
    -- C7 FIX END BY SHIJINGZHE

    local ret = {}
    for k,v in pairs(tbl) do
        if type(v) == 'table' or type(v) == 'userdata' then
            ret[k] = ksbc2DeepTable(v)
        else
            ret[k] = v
        end
    end
    return ret
end

-- C7 FIX START BY SHIJINGZHE

-- Debug接口,方便打印和运行时查看ksbcTable内部数据
function dumpKsbcTable(ksbcT)
    local luaT = {}
    for k,v in pairs(ksbcT) do
        if type(v) == 'table' or type(v) == 'userdata' then
            luaT[k] = dumpKsbcTable(v)
        else
            luaT[k] = v
        end
    end

    return luaT
end

-- C7 FIX END BY SHIJINGZHE

function table.ksbcforeach(tbl, func)
    if getmetatable(tbl) == metatable then
        for k,v in ksbcpairs(tbl) do func(k,v) end
        return
    end

    return table.foreach(tbl, func, true)
end
--}遍历相关


function ksbcdump(t, includefunc, depth)
    if t == nil then
        return ''
    end
    if depth == nil then
        depth = 0
    end

    if depth >= 10 then
        return "{too deep}"
    end

    local str = '{ '
    for k, v in pairs(t) do
        k = tostring(k)
        if string.startsWith(k, "__") then
            if includefunc then
                str = str .. k .. '=metatable, '
            end
        elseif type(v) == 'string' then
            str = str .. k .. '="' .. v .. '", '
        elseif type(v) == 'number' then
            str = str .. k .. '=' .. v .. ', '
        elseif type(v) == 'function' then
            if includefunc then
                str = str .. k .. '=function, '
            end
        elseif type(v) == 'table' or type(v) == 'userdata' then
            str = str .. k .. '=' .. ksbcdump(v, includefunc, depth + 1) .. ', '
        elseif type(v) == 'boolean' then
            str = str .. k .. '=' .. (v and 'true' or 'false') .. ', '
        else
            str = str .. k .. '=' .. type(v) .. ', '
        end
    end
    str = str .. '}'
    return str
end

--index读取
metatable.__index = function(tbl, key)
    local _t = type(key)
    if _t == 'number' then
        local v, vt = getValueByNum(tbl, key)
        return ref2Val(v, vt)

    elseif _t == 'string' then
        local addr = str2addr[key]
        if not addr then return end
        local v, vt = getValueByStrAddr(tbl, addr)
        return ref2Val(v, vt)
    end
end

--{打补丁
local function patch(handle, key, val, bLanguage)

    local bStrKey, bStrVal = false, false
    if type(key) == 'string' then
        local addr = str2addr[key]
        if not addr then
            addr = addStr(key)
            str2addr[key] = addr
            addr2str[addr] = key
        end

        bStrKey = true
        key = addr
    end
    if type(val) == 'string' then
        local addr = str2addr[val]
        if not addr then
            addr = addStr(val)
            str2addr[val] = addr
            addr2str[addr] = val
        end

        bStrVal = true
        val = addr
    end

    ksbcPatch(handle, key, val, bStrKey, bStrVal, bLanguage)
end

local _patchTbl2Flag
local function checkpatch(t, key, val)

    if _patchTbl2Flag[t] then return true end
    _patchTbl2Flag[t] = true

    if not (type(key) == 'string' or type(key) == 'number') then
        print('Error:key must be string or number!')
        assert(false)
        return false
    end

    local valTy = type(val)
    if not (val == nil
        or valTy == 'number'
        or valTy == 'string'
        or valTy == 'boolean'
        or valTy == 'table'
        or valTy == 'userdata' and getmetatable(val) == metatable) then
            print('Error:value must be string or number or boolean or table!', val)
            assert(false)
            return false
    end

    if type(val) == 'table' then
        for k,v in pairs(val) do
            if not checkpatch(val, k, v) then  return false end
        end
    end

    return true, val
end

local function check_multi_language_patch(t, key, val)

    if _patchTbl2Flag[t] then return true end
    _patchTbl2Flag[t] = true

    if not (type(key) == 'string' or type(key) == 'number') then
        print('Error:key must be string or number!')
        assert(false)
        return false
    end

    local valTy = type(val)
    if not (valTy == 'number' or valTy == 'string') then
        print('Error:multi language index value must be string or number!', val)
        assert(false)
        return false
    end

    return true, val
end


metatable.__newindex = function(t, key, val)
    if not Game.IsHotfixing then
        DebugLogError("forbid modifying excel data")
        return
    end
    _patchTbl2Flag = {}
    if not checkpatch(t, key, val) then
        return
    end

    for k, v in pairs(udCache) do
        udCache[k] = nil
    end

    _patchTbl2Flag = {}
    patch(t, key, val, false)
    _patchTbl2Flag = nil
end
--}打补丁

--{
metatable.__eq = function(a, b)
    if not (type(a) == type(b)) then return false end
    if type(a) == 'userdata' then
        return getHandle(a) == getHandle(b)
    else
        return a == b
    end
end

metatable.__len = function(tbl)
    return getLen(tbl)
end

metatable.__tostring = function(tbl)
    return 'BIN DESIGN DATA TABLE:' .. getHandle(tbl)
end


function ksbcMultiLanguageValueHotfix(t, key, val)
    _patchTbl2Flag = {}
    if not check_multi_language_patch(t, key, val) then
        return false
    end

    for k, v in pairs(udCache) do
        udCache[k] = nil
    end

    _patchTbl2Flag = {}
    patch(t, key, val, true)
    _patchTbl2Flag = nil
    return true
end

local rawPairs = pairs
local rawiPairs = ipairs
local rawUnpack = unpack
local rawNext = next
local ksbc_metatable = metatable

function isKsbcTable(tbl) 
    return getmetatable(tbl) == ksbc_metatable
end

--next
function ksbcnext(tbl, key)
    if getmetatable(tbl) == ksbc_metatable then
        local _t = type(key)
        if _t == 'nil' then
            local k, kt, v, vt = nextWithNil(tbl)
            return ref2Val(k, kt), ref2Val(v, vt)

        elseif _t == 'number' then
            local k, kt, v, vt = nextWithNum(tbl, key)
            return ref2Val(k, kt), ref2Val(v, vt)

        elseif _t == 'string' then
            local addr = str2addr[key]
            local k, kt, v, vt = nextWithStrAddr(tbl, addr)
            return ref2Val(k, kt), ref2Val(v, vt)
        else
            error("invalid key to ksbcnext!")
        end
        return
    end
    return rawNext(tbl, key, true)
end

--{遍历相关
function ksbcpairs(tbl)
    if getmetatable(tbl) == ksbc_metatable then
        return ksbcnext, tbl, nil
    end
    return rawPairs(tbl, true)
end

local inext = function(tbl, i)
    i = i + 1
    local v = tbl[i]
    if v ~= nil then
        return i, v
    end
end

function ksbcipairs(tbl)
    return inext, tbl, 0
end

function ksbcunpack(tbl, startIndex)
    local ret = {}
    for _, v in ksbcipairs(tbl) do
        ret[#ret+1] = v
    end
    return rawUnpack(ret, startIndex)
end

-- 单层table转换
function ksbc2Table(tbl)
    if getmetatable(tbl) ~= ksbc_metatable then
        return tbl
    end
    local ret = {}
    for k,v in pairs(tbl) do
        ret[k] = v
    end
    return ret
end

-- Editor环境下才会hook，用于明确提示
if UE_EDITOR then
    local ksbc_pairs = ksbcpairs
    pairs = function(table)
        if getmetatable(table) == ksbc_metatable then
            DebugLogError("pairs not support ksbc, please use ksbcpairs")
            return ksbc_pairs(table)
        end
        return rawPairs(table)
    end
    rawset(_G, 'pairs', pairs)
    
    local ksbc_ipairs = ksbcipairs
    ipairs = function(table)
        if getmetatable(table) == ksbc_metatable then
            DebugLogError("ipairs not support ksbc, please use ksbcipairs")
            return ksbc_ipairs(table)
        end
        return rawiPairs(table)
    end
    rawset(_G, 'ipairs', ipairs)
    
    local ksbc_unpack = ksbcunpack
    unpack = function(table, startIndex)
        if getmetatable(table) == ksbc_metatable then
            DebugLogError("unpack not support ksbc, please use ksbcunpack")
            return ksbc_unpack(table, startIndex)
        end
        return rawUnpack(table, startIndex)
    end
    rawset(_G, 'unpack', unpack)
    
    local ksbc_next = ksbcnext
    next = function(table, key)
        if getmetatable(table) == ksbc_metatable then
            DebugLogError("next not support ksbc, please use ksbcnext")
            return ksbc_next(table, key)
        end
        return rawNext(table, key)
    end
    rawset(_G, 'next', next)
end

--}}}lua访问二进制策划表的接口

function ksbccount(table)
    local count = 0
    local ksbcnext = ksbcnext
    for k, v in ksbcnext, table do
        if v ~= nil then
            count = count + 1
        end
    end

    return count
end

function ksbccontains(table, element)
    if table == nil then
        return false
    end

    local ksbcpairs = ksbcipairs
    for _, value in ksbcpairs(table) do
        if value == element then
            return true
        end
    end

    return false
end

--[[
if not USER_OUTER_SCRIPT then
    _script.ksbcLoad("data/pmdata.bin")
    _script.ksbcRawG = ksbcRawG()
elseif OUTER_SCRIPT_KSBC then
    _script.ksbcLoad("data/pmdata.bin")
    _script.ksbcRawG = ksbcRawG()
end--]]

-- local function checkFile(ta, tb)
--     for k,v in ksbcpairs(ta) do
--         if tb[k] == nil then
--             return false
--         end
--         local vb = tb[k]
--         if type(v) == "table" or type(v) == "userdata" then
--             local checkRet = checkFile(v, vb)
--             if not checkRet then
--                 print(k, v, vb)
--                 return false
--             end
--         else
--             if type(v) == "number" and type(vb) == "number" then
--                 if math.abs(v-vb) > 1e-4 then
--                     print(k, v, vb)
--                     return false
--                 end
--             else
--                 if v ~= vb then
--                     print(k, v, vb)
--                     return false
--                 end
--             end
--         end
--     end
--     return true
-- end
-- --压缩数据一致性检查
-- function testAllKsbc(files)
--     for i =0, files.Length-1 do
--         local dp = "data." .. files[i]
--         if not _script.ksbcIgnore[dp] then
--             FORCE_KSBC = true
--             local ta = require_ex(dp).data
--             FORCE_KSBC = nil
--             unrequire_data(dp)
--             local tb = require_ex(dp).data
--             if not checkFile(ta, tb) then
--                 print(dp .. "文件存在不一致")
--                 return
--             end
--         end
--     end
--     print("检查一致性成功")
-- end

-- -- 打包版运行时数据一致性检查
-- function runtimeTestAllKsbc()
--     local checkOk = true
--     _script.FORCE_NOT_KSBC = true
--     for k, v in pairs(_script.ksbcRawG) do
--         local dp = "data." .. k
--         unrequire_data(dp)
--         local tb = require_ex(dp).data
--         if not checkFile(v, tb) then
--             checkOk = false
--             print(dp .. "文件存在不一致")
--         end
--     end
--     _script.FORCE_NOT_KSBC = nil
--     if checkOk then
--         print("检查一致性成功")
--     else
--         print("检查一致性失败")
--     end
-- end


-- local tables = {
--     "achievement_data",
--     "actor_data",
--     "attribute_group_data",
--     "audio_data",
--     "drop_group_data",
--     "equip_data",
--     "item_data",
--     "puppet_client_data",
--     "puppet_data",
--     "quest_chat_data"
-- }

-- local function testDataReader()
--     local tk = {}
--     local tkk = {}
--     for _, tn in ipairs(tables) do
--         local td = require_ex("data." .. tn)
--         local keys = {}
--         local kv
--         for k,v in pairs(td.data) do
--             if not kv then
--                 kv = v
--             end
--             table.insert(keys, k)
--         end
--         local kks = {}
--         if type(kv) == "table" then
--             for k,v in pairs(kv) do
--                 table.insert(kks, k)
--             end
--         end
--         table.insert(tkk, kks)
--         table.insert(tk, keys)
--     end
--     return tk, tkk
-- end

-- function testLuaData()
--     _script.FORCE_NOT_KSBC = true
--     _script.loaded_data = {}
--     for i, tn in ipairs(tables) do
--         local td = require_ex("data." .. tn)
--         local md = td.data[-98761]
--     end
--     local keys, kkeys = testDataReader()
--     local t1 = os.clock()
--     for ppp=1,10 do
--         local ct = 0
--         for i, tn in ipairs(tables) do
--             local td = require_ex("data." .. tn)
--             local rd = td.data
--             local k1s = keys[i]
--             local k2s = kkeys[i]
--             local vv, vv1
--             for _, key in ipairs(k1s) do
--                 vv = rd[key]
--                 vv1 = vv[k2s[1]]
--                 ct = ct + 1
--             end
--         end
--     end
--     local t2 = os.clock()
--     print(t2 - t1, ct)
--     _script.FORCE_NOT_KSBC = nil
-- end

-- function testLuaPair()
--     _script.FORCE_NOT_KSBC = true
--     _script.loaded_data = {}
--     for i, tn in ipairs(tables) do
--         local td = require_ex("data." .. tn)
--         local md = td.data[-98761]
--     end
--     local keys, kkeys = testDataReader()
--     local t1 = os.clock()
--     for ppp=1,10 do
--         for i, tn in ipairs(tables) do
--             local td = require_ex("data." .. tn)
--             local rd = td.data
--             local k1s = keys[i]
--             local vv, vv1
--             for _, key in ipairs(k1s) do
--                 vv = rd[key]
--                 for k,v in pairs(vv) do
--                     vv1 = v
--                 end
--             end
--         end
--     end
--     local t2 = os.clock()
--     print(t2 - t1)
--     _script.FORCE_NOT_KSBC = nil
-- end

-- function testKsbc()
--     local rawG = _script.ksbcRawG
--     _script.FORCE_NOT_KSBC = true
--     _script.loaded_data = {}
--     local keys, kkeys = testDataReader()
--     _script.FORCE_NOT_KSBC = nil
--     local t1 = os.clock()

--     for ppp=1,10 do
--         local ct = 0
--         for i, tn in ipairs(tables) do
--             local rd = rawG[tn]
--             local k1s = keys[i]
--             local k2s = kkeys[i]
--             local vv, vv1
--             for _, key in ipairs(k1s) do
--                 vv = rd[key]
--                 vv1 = vv[k2s[1]]
--                 ct = ct + 1
--             end
--         end
--     end
--     local t2 = os.clock()
--     print(t2 - t1, ct)
-- end

-- function testKsbcPair()
--     local rawG = _script.ksbcRawG
--     _script.FORCE_NOT_KSBC = true
--     _script.loaded_data = {}
--     local keys, kkeys = testDataReader()
--     _script.FORCE_NOT_KSBC = nil
--     local t1 = os.clock()

--     for ppp=1,10 do
--         for i, tn in ipairs(tables) do
--             local rd = rawG[tn]
--             local k1s = keys[i]
--             local k2s = kkeys[i]
--             local vv, vv1
--             for _, key in ipairs(k1s) do
--                 vv = rd[key]
--                 for k,v in pairs(vv) do
--                     vv1 = v
--                 end
--             end
--         end
--     end
--     local t2 = os.clock()
--     print(t2 - t1)
-- end

-- function diffTable(t1, t2)
--     if (type(t1) ~= 'table' and type(t1) ~= 'userdata') or type(t2) ~= 'table' then
--         print(type(t1), type(t2))
--         return false
--     end
--     for k,v in pairs(t1) do
--         if t2[k] == nil then
--             print(22, k, v)
--             return false
--         end
--         if type(v) == 'table' or type(v) == 'userdata' then
--             if not diffTable(v, t2[k]) then
--                 return false
--             end
--         elseif v ~= t2[k] then
--             print(33, k,v, t2[k])
--             return false
--         end
--     end
--     return true
-- end

-- function testKsbcPatch()
--     local data = require_ex("data.md5_diff")
--     local ud = {}
--     for _, v in ipairs(data.data) do
--         v = string.sub(v, 1, -5)
--         local d1 = require_ex("data." .. v)
--         ud[v] = d1.data
--     end

--     local od = {}
--     _script.FORCE_NOT_KSBC = true
--     for _, v in ipairs(data.data) do
--         v = string.sub(v, 1, -5)
--         local d2 = require_data("data." .. v, true)
--         od[v] = d2.data
--     end

--     for k,v in pairs(ud) do
--         print(k)
--         if not diffTable(v, od[k]) then
--             print("diff erro ", k)
--             return false
--         end
--     end
--     return true
-- end
