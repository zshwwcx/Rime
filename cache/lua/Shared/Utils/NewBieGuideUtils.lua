local bit = Game and Game.bit or require("bit")
local math = math
local bit_bor = bit.bor
local bit_band = bit.band
local bit_lshift = bit.lshift
local bit_bnot = bit.bnot
local BIT_PER_INT = 32

function IsNewBieGuideDone(doneGuidesDict, guideID)
    local pos = math.floor(guideID/BIT_PER_INT)
    local index = guideID % BIT_PER_INT
    if not doneGuidesDict[pos] then
        return false
    end

    local value = doneGuidesDict[pos]
    local mask = bit_lshift(1, index)
    return (bit_band(value, mask) > 0)
end

function SetNewBieGuideDone(doneGuidesDict, guideID)
    local pos = math.floor(guideID/BIT_PER_INT)
    local index = guideID % BIT_PER_INT
    local value = doneGuidesDict[pos] or 0
    local mask = bit_lshift(1, index)
    doneGuidesDict[pos] = bit_bor(value, mask)
end

function ResetNewBieGuide(doneGuidesDict, guideID)
    local pos = math.floor(guideID / BIT_PER_INT)
    local index = guideID % BIT_PER_INT
    local value = doneGuidesDict[pos] or 0
    local mask = bit_lshift(1, index)
    doneGuidesDict[pos] = bit_band(value, bit_bnot(mask))
end

function IsNewBieGuideOperationRewarded(rewardedDict, guideID)
    local pos = math.floor(guideID/BIT_PER_INT)
    local index = guideID % BIT_PER_INT
    if not rewardedDict[pos] then
        return false
    end

    local value = rewardedDict[pos]
    local mask = bit_lshift(1, index)
    return (bit_band(value, mask) > 0)
end

function SetNewBieGuideOperationRewarded(rewardedDict, guideID)
    local pos = math.floor(guideID/BIT_PER_INT)
    local index = guideID % BIT_PER_INT
    local value = rewardedDict[pos] or 0
    local mask = bit_lshift(1, index)
    rewardedDict[pos] = bit_bor(value, mask)
end
