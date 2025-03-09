INV_BAG_FULL_MAIL_TEMPLATE_ID               = 6260002        
DROP_RECOVER_MAIL_TEMPLATE_ID               = 6260003 
GUILD_CREATE_FAIL_LEADER_MAIL_TEMPLATE_ID   = 6260012
ANSWER_ACTIVITY_MAIL_TEMPLATE_ID            = 6260013
DUNGEON_AUCTION_MAIL_TEMPLATE_ID            = 6260014
GUILD_CREATE_FAIL_MEMBER_MAIL_TEMPLATE_ID   = 6260017
GUILD_MERGE_SUCCESS_TEMPLATE_ID             = 6260018
GUILD_INACTIVE_TEMPLATE_ID                  = 6260019
RED_PACKET_RETURN_MONEY_MAIL_TEMPLATE_ID    = 6260025
GUILD_CREATE_FINISH_MAIL_TEMPLATE_ID        = 6260026
GUILD_JOIN_SUCCESS_MAIL_TEMPLATE_ID         = 6260029
GUILD_KICK_MAIL_TEMPLATE_ID                 = 6260030
GUILD_CAN_NOT_JOIN_GUILD_LEAGUE_TEMPLATE_ID = 6260036

function CheckAfterLoadModule(moduleEnv)
    local checkValueMap = {}  -- luacheck: ignore
    for k, v in pairs(moduleEnv) do
        assert(not checkValueMap[v], string.format("value duplicate %s %s ", k, checkValueMap[v]))
        checkValueMap[v] = k
    end
end
