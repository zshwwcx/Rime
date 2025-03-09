local Enum = Enum

function isInDiscount(GoodsData, CurrentTime)
    if GoodsData.NormalDiscountLimits == 0 or GoodsData.DiscountPrice == 0 then
        return false
    end

    local startTime = GoodsData.RegularDiscountStartTimeStamp
    local endTime = GoodsData.RegularDiscountEndTimeStamp

    if startTime and startTime ~= 0 and CurrentTime < startTime then
        return false
    end

    if endTime and endTime ~= 0 and CurrentTime > endTime then
        return false
    end
    return true
end

function checkInSellTime(GoodsData, CurrentTime)
    if GoodsData.LimitTimeUpStamp and CurrentTime < GoodsData.LimitTimeUpStamp then
        return Enum.EErrCodeData.NPC_SHOP_NOT_BEGIN_SALE
    end

    if GoodsData.LimitTimeDownStamp and GoodsData.LimitTimeDownStamp > 0 and CurrentTime > GoodsData.LimitTimeDownStamp then
        return Enum.EErrCodeData.NPC_SHOP_HAVE_END_SALE
    end
    return Enum.EErrCodeData.NO_ERR
end

function CheckCanBuyGoods(goodsId, count, goodsCountInfo)
    local goodsServerLimitData = TableData.GetGoodsServerLimitDataRow(goodsId)
    if not goodsServerLimitData then
        return 0, 0
    end

    local alreadyBuyCnt = goodsCountInfo[goodsId] or 0
    if (alreadyBuyCnt + count) <= goodsServerLimitData.ServerLimits then
        return count, goodsServerLimitData.LimitPeriod
    end

    -- 不支持买剩下所有的
    return 0, goodsServerLimitData.LimitPeriod
end
