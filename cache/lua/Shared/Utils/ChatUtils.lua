local colorTextData = kg_require("data.color_text_data")
local gameplayConfigData = kg_require("data.gameplay_config_data")
local sceneData = kg_require("data.scene_data")
local utils = kg_require("Shared.Utils")
local lang = kg_require("Shared.language_" .. language)
local const = kg_require("Shared.Const")
local clientUtils = kg_require("Framework.Utils.C7_Client_Utils")

function saveChatHistoryMessage(gbId, messages)
    -- local config = C7.cjson.encode(messages)
    -- local path = CSUtil.persistentDataPath  .. "/chat_".. gbId .. ".json"
    -- C7.global.gameMgr:SaveText(path, config)
end

function readChatHistoryMessage(gbId)
    -- local path = CSUtil.persistentDataPath  .. "/chat_".. gbId .. ".json"
    -- local chat = C7.global.gameMgr:LoadText(path)
    -- if string.notNilOrEmpty(chat) then
    --     local messages = C7.cjson.decode_keep_nil(chat) or {}
    --     return messages
    -- end
    -- return {}
end

function getAtPlayerGbIdByMessageText(text)
    local gbId
    if string.isEmpty(text)  then
        return nil
    end
    string.gsub(text, "<a=at:(%d+)>.*</a>", function (v)
        gbId = tonumber(v)
    end)
    return gbId
end

function checkHasGmCustomerService()
    if clientUtils.checkEnableCustomerService() then
        local serviceInfo = Game.me.customerServiceGmInfo or {}
        return string.notNilOrEmpty(serviceInfo.gmId)
    end
    return false
end

function getGmCustomerServiceRelationInfo()
    local serviceInfo = Game.me.customerServiceGmInfo
    if not serviceInfo then
        return
    end
    return {
        gbId = tonumber(serviceInfo.gmId),
        attraction = 0,
        favorability = 0,
        favorabilityLv = 0,
        groupId = const.FRIEND_SERVER_FRIEND_GROUP_ID,
        isCrossServer = true,
        isNpc = false,
        lv = 0,
        npcId = 0,
        remark = "",
        rolename = serviceInfo.gmNick,
        shcool = 0,
        state = serviceInfo.gmOnline,
        photo = serviceInfo.gmIcon,
        signName = {serviceInfo.gmSign},
        top = true,
    }
end
