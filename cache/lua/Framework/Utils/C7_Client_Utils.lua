-- luacheck: push ignore
clientConfig = {} --kg_require("common.client_config")
commonConfig = {} --kg_require("common.common_config")
local gameConst = kg_require("Gameplay.CommonDefines.C7_Game_Const")
local plateMapData = kg_require("data.plate_map_data")
function getServerConfig(id)
    -- local res = C7.global.configs[id]
    -- if res ~= nil then
    --     return res
    -- end
    local keyName = clientConfig.ID_CONFIGNAME_TABLE[id]
    if keyName then
        local detail = clientConfig.configs[keyName]
        if detail then
            return detail[2]
        end
    end
    return false
end

function checkEnableCustomerService()
    return getServerConfig(commonConfig.CONFIG_ENABLE_CUSTOMER_SERVICE)
end

-- function getCurServerInfo()
--     return C7.game.serverList:getCurServerInfo()
-- end

function checkEnableGMBridge()
    return getServerConfig(commonConfig.CONFIG_ENABLE_GMBRIGE)
end


function checkEnableGMBridge()
    return getServerConfig(commonConfig.CONFIG_ENABLE_GMBRIGE)
end

function checkEnableEnvSdk()
    return getServerConfig(commonConfig.CONFIG_ENABLE_ENV_SDK)
end

function getServerOpenTime()
    local openTime = getServerConfig(commonConfig.CONFIG_SERVER_OPEN_TIME)
    if type(openTime) == "boolean" then
        return  1
    end
    return openTime
end

function checkEnableWareHouse()
    return getServerConfig(commonConfig.CONFIG_ENABLE_WAREHOUSE)
end

function checkEnableServerLevelUp()
    return true
end

function checkIsShowNotice(source)
    -- if source == itemConstSourceData.data.ITEM_SOURCE_BOUNDCASH_COMMERCE_TRADE
    --     or source == itemConstSourceData.data.ITEM_SOURCE_UNBOUNDCASH_COMMERCE_TRADE
    --     or source == itemConstSourceData.data.ITEM_SOURCE_MAIN_QUEST_COMPLETE
    --     or source == itemConstSourceData.data.ITEM_SOURCE_DECOMPOSE
    --     or source == itemConstSourceData.data.ITEM_SOURCE_MALL_CHARGE
    --     or source == itemConstSourceData.data.ITEM_SOURCE_RECHARGE_MALL_AUTO_BUY
    --     or source == itemConstSourceData.data.ITEM_SOURCE_BRANCH_QUEST_COMPLETE then
    --     return false
    -- end
    -- return true
end

-- 获取地图左下角到(0,0)点的偏移
function getMapCenterOffset(sceneId)
    local xOffset = gameConst.DEFAULT_REAL2DISPLAY_POS_OFFSET
    local zOffset = gameConst.DEFAULT_REAL2DISPLAY_POS_OFFSET
    local mapData = plateMapData.data[sceneId]
    if mapData then
        local r = mapData["spaceRight"] -- 右下
        local l = mapData["spaceLeft"] -- 左上
        xOffset = -l[1]
        zOffset = -r[2]
    end
    return xOffset, zOffset
end

function realPos2DisplayPos(sceneId, x, z)
    local xOffset, zOffset = getMapCenterOffset(sceneId)
    return x + xOffset, z + zOffset
end