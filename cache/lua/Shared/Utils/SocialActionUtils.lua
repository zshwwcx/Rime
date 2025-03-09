local bit = Game and Game.bit or require("bit")
local math = math
local bit_bor = bit.bor
local bit_band = bit.band
local bit_lshift = bit.lshift
local bit_not = bit.bnot
local BIT_PER_INT = 32

function IsSocialActionCollected(collectDict, actionID)
    local pos = math.floor(actionID/BIT_PER_INT)
    local index = actionID % BIT_PER_INT
    if not collectDict[pos] then
        return false
    end

    local value = collectDict[pos]
    local mask = bit_lshift(1, index)
    return (bit_band(value, mask) > 0)
end

function SetSocialActionCollected(collectDict, actionID)
    local pos = math.floor(actionID/BIT_PER_INT)
    local index = actionID % BIT_PER_INT
    local value = collectDict[pos] or 0
    local mask = bit_lshift(1, index)
    collectDict[pos] = bit_bor(value, mask)
end

function SetSocialActionUnCollected(collectDict, actionID)
    local pos = math.floor(actionID/BIT_PER_INT)
    local index = actionID % BIT_PER_INT
    if not collectDict[pos] then
        return
    end

    local value = collectDict[pos]
    local mask = bit_not(bit_lshift(1, index))
	collectDict[pos] = bit_band(value, mask)

    if collectDict[pos] == 0 then 
        collectDict[pos] = nil
    end
end

function IsSocialActionUnlocked(unlockDict, actionID)
    local pos = math.floor(actionID/BIT_PER_INT)
    local index = actionID % BIT_PER_INT
    if not unlockDict[pos] then
        return false
    end

    local value = unlockDict[pos]
    local mask = bit_lshift(1, index)
    return (bit_band(value, mask) > 0)
end

function SetSocialActionUnlocked(unlockDict, actionID)
    local pos = math.floor(actionID/BIT_PER_INT)
    local index = actionID % BIT_PER_INT
    local value = unlockDict[pos] or 0
    local mask = bit_lshift(1, index)
    unlockDict[pos] = bit_bor(value, mask)
    
    if unlockDict[pos] == 0 then 
        unlockDict[pos] = nil
    end

    return pos
end