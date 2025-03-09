-- 客户端为lua 5.4
local bit
if IS_SERVER then
	bit = kg_require("bit")
else
	bit = require("Framework.Utils.bit")
end

-- luacheck: push ignore
local band = bit.band
local bnot = bit.bnot
local bor  = bit.bor
local lshift = bit.lshift
local rshift = bit.rshift
local MAGIC_DIGIT = 5 
--Game.bit导出的操作只处理32位
local MAGIC_NUM = 2 ^ MAGIC_DIGIT 

local bitset = {
    band = bit.band,
    bnot = bit.bnot,
    bor  = bit.bor,
    lshift = bit.lshift,
    rshift = bit.rshift,
}
-- luacheck: pop

--- 对于一个offset首先确定它位于数组的那位idx, 然后确定设置flags[idx]值的哪个bit位(pos).

function bitset.getBit(flags, offset)
    local idx = rshift(offset, MAGIC_DIGIT) + 1  -- floor(offset / MAGIC_NUM) + 1
    local pos = band(offset, MAGIC_NUM - 1)      -- offset % MAGIC_NUM (MAGIC_NUM 为 2^n 才成立)
    local byte = lshift(1, pos)
    return band(flags[idx] or 0, byte) ~= 0
end

function bitset.setBit(flags, offset)
    local idx = rshift(offset, MAGIC_DIGIT) + 1
    local pos = band(offset, MAGIC_NUM - 1)
    local byte = lshift(1, pos)
    flags[idx] = bor(flags[idx] or 0, byte)
end

function bitset.clearBit(flags, offset)
    local idx = rshift(offset, MAGIC_DIGIT) + 1
    if flags[idx] then
        local pos = band(offset, MAGIC_NUM - 1)
        local byte = bnot(lshift(1, pos))
        flags[idx] = band(flags[idx] or 0, byte)
        if flags[idx] == 0 then
            flags[idx] = nil
        end
    end
end

function bitset.getList(flags)
    local res = {}
    for idx, val in pairs(flags) do
        for pos = 0, MAGIC_NUM - 1 do
            if band(val, lshift(1, pos)) ~= 0 then
                res[#res + 1] = MAGIC_NUM * (idx - 1) + pos
            end
        end
    end
    return res
end

--- 用于将传入的flags的offset指定的bit置为1或0
-- @param flags, 正整数, 将被修改的数
-- @param value, boolean, true则置1, false则置0
-- @param offset, 正整数, 哪一位
-- @return 返回置位后的数的十进制表达
function bitset.updateBit(flags, value, offset)
    if value then
        return bor(flags, lshift(1, offset - 1))
    else
        return band(flags, bnot(lshift(1, offset - 1)))
    end
end

-- 获取数据flags 的offset位是否为1
function bitset.getBitBool(flags, offset)
    local idx = lshift(1, offset - 1)
    return band(flags, idx) == idx
end

return bitset