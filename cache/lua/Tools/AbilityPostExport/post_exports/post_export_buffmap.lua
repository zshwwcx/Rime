local post_export = require("Tools.AbilityPostExport.loader").post_export

local LOG_INFO = require("Tools.AbilityPostExport.loader").LOG_INFO
local LOG_ERROR = require("Tools.AbilityPostExport.loader").LOG_ERROR

post_export(
    "buff_map",
    "BuffMap",
    "BuffMap全局变量生成",
    "",
    function(ctx)
        local buffCount = 0
        local BuffMap = {}
        for _, buffAssetMap in pairs(ctx.BSAB) do
            for skillId, skillAsset in pairs(buffAssetMap) do
                if type(skillId) == "number" then
                    BuffMap[skillId] = skillAsset
                    buffCount = buffCount + 1
                end
            end
        end

        LOG_INFO("BuffMap created, total BuffAsset: %s", buffCount)
        ctx.BuffMap = BuffMap
    end
)