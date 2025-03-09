local Game = Game
local TableData = Game.TableData or TableData
local redPacketConst = kg_require("Shared.Const.RedPacketConst")
local shopUtils = kg_require("Shared.Utils.ShopUtils")
local lume = kg_require("Shared.lualibs.lume")

if _G.IsClient then
    pairs = ksbcpairs
end

local RED_PACKET_GOODS_SHOP_ID = redPacketConst.RED_PACKET_GOODS_SHOP_ID
local RED_PACKET_GOODS_SHOP_TOKEN_ID = redPacketConst.RED_PACKET_GOODS_SHOP_TOKEN_ID
local RED_PACKET_GOODS_TOTAL_LIMITS = redPacketConst.RED_PACKET_GOODS_TOTAL_LIMITS

--- 可以加入礼金的商品类型: 可直购，金榜购买，不限购，外观类, 在出售时间
--- 注:统一使用原价, 折扣不生效
--- todo:此处因商城不完善预留, 临时判定方式: NpcShop表shopid=2300007，item子表tokenid使用货币为2001003，限购次数totallimits为-1，时间在定时上架区间范围内
---@param GoodsId number 商品id
---@param CurrentTime number 当前时间戳
---@return boolean 是否可购, number 价格
function isShopGoodsCanSendRedPacket(GoodsId, CurrentTime)
    local goodsData = TableData.GetNpcGoodsDataRow(GoodsId)     -- todo:以后可能修改商店类型
    if not goodsData then
        return false
    end
    if goodsData.ShopID ~= RED_PACKET_GOODS_SHOP_ID then
        return false
    end
    local tokenIDs = goodsData.TokenIDs
    if not tokenIDs then
        return false
    end
    local price = tokenIDs[RED_PACKET_GOODS_SHOP_TOKEN_ID]
    if not price then
        return false
    end
    for moneyType, _ in pairs(tokenIDs) do
        if moneyType ~= RED_PACKET_GOODS_SHOP_TOKEN_ID then
            return false
        end
    end
    -- todo:此处因商城不完善预留,限购判断先去掉
    --[[if goodsData.TotalLimits ~= RED_PACKET_GOODS_TOTAL_LIMITS then
        return false
    end]]
    if not shopUtils.checkInSellTime(goodsData, CurrentTime) then
        return false
    end

    return true, price
end

--- 获得红包道具的价格
---@param GoodsId number 商品id
---@return number 价格
function getRedPacketShopGoodsPrice(GoodsId)
    local goodsData = TableData.GetNpcGoodsDataRow(GoodsId)
    if not goodsData then
        return 0
    end
    local tokenIDs = goodsData.TokenIDs
    if not tokenIDs then
        return 0
    end
    return tokenIDs[RED_PACKET_GOODS_SHOP_TOKEN_ID] or 0
end

--- 红包是否已被全部领完
---@param RedPacketInfo table 红包信息
---@return boolean 是否已被领取完毕
function isRedPacketAllReceived(RedPacketInfo)
    if RedPacketInfo.bIsFinished then
        return true
    end

    local currentStatus = RedPacketInfo.currentStatus or {}
    local receiveMoneyDict = currentStatus.receiveMoneyDict or {}
    local receiveGoodsDict = currentStatus.receiveGoodsDict or {}
    local packNum = RedPacketInfo.packNum or 0

    return lume.count(receiveMoneyDict) + lume.count(receiveGoodsDict) >= packNum
end