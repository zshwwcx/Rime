local post_export = require("Tools.AbilityPostExport.loader").post_export


local LOG_INFO = require("Tools.AbilityPostExport.loader").LOG_INFO
local LOG_ERROR = require("Tools.AbilityPostExport.loader").LOG_ERROR

post_export(
    "skill_map",
    "SkillMap",
    "SkillMap全局变量生成",
    "",
    function(ctx)
        local skillCount = 0
        local SkillMap = {}
        for _, skillAssetMap in pairs(ctx.BSAS) do
            for skillId, skillAsset in pairs(skillAssetMap) do
                if type(skillId) == "number" then
                    SkillMap[skillId] = skillAsset
                    skillCount = skillCount + 1
                end
            end
        end

        LOG_INFO("SkillMap created, total SkillAsset: %s", skillCount)
        ctx.SkillMap = SkillMap
    end
)
