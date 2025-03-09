local post_export = require("Tools.AbilityPostExport.loader").post_export

local LOG_INFO = require("Tools.AbilityPostExport.loader").LOG_INFO
local LOG_ERROR = require("Tools.AbilityPostExport.loader").LOG_ERROR

local bit = require("Framework.Utils.bit")

local CampTypeToRelation = {
    [ETE.EBSTargetCampType.TCT_Self] = "self",
    [ETE.EBSTargetCampType.TCT_SquadMate] = "team",
    [ETE.EBSTargetCampType.TCT_TeamMate] = "group",
    [ETE.EBSTargetCampType.TCT_Allies] = "friend",
    [ETE.EBSTargetCampType.TCT_Neutral] = "neutral",
    [ETE.EBSTargetCampType.TCT_Enemy] = "enemy",
}

local RELATION_MODE = {
    MUST = 1,
    ALLOW = 2,
    FORBID = 3
}

---将指定Relation内容转为唯一key。这个key用于查询是否已经存在相同的relation，避免重复
local function EncodeRelationKey(RelationSet)
    local list = {}
    for k, v in pairs(RelationSet) do
        list[#list + 1] = { k, v }
    end
    table.sort(list, function(a, b)
        return a[1] < b[1]
    end)
    local key = ""
    for _, v in ipairs(list) do
        key = key .. string.format("[%s:%d]", v[1], v[2])
    end
    return key
end

local function LoadRelationFromFile(relationSetData, RelationContext)
    local data = relationSetData
    RelationContext.Relations = data
    RelationContext.RelationKeyIdMap = {}
    for id, relation in pairs(data) do
        local key = EncodeRelationKey(relation)
        RelationContext.RelationKeyIdMap[key] = id
        if id >= RelationContext.RelationId then
            RelationContext.RelationId = id + 1
        end
    end
end

local function GenNewRelation(RelationContext, RelationSet)
    local key = EncodeRelationKey(RelationSet)
    local id = RelationContext.RelationKeyIdMap[key]
    if id then
        return id
    end
    local Relations = RelationContext.Relations
    local id = RelationContext.RelationId
    Relations[id] = RelationSet
    RelationContext.RelationId = RelationContext.RelationId + 1
    return id
end

local function ConvertAndGenRelations(RelationContext, CampTypeMask, bOnlyCampRelation)
    local CampMap = bOnlyCampRelation and RelationContext.CampMapOnlyCampR or RelationContext.CampMap
    if CampMap[CampTypeMask] then
        return CampMap[CampTypeMask]
    end

    local set = bOnlyCampRelation and {} or {
        -- 默认的关系，后续根据需求再改
        dead = RELATION_MODE.FORBID,
        observer = RELATION_MODE.FORBID,
        hit_limit = RELATION_MODE.FORBID,
        skill_agent = RELATION_MODE.FORBID,
        mission_group = RELATION_MODE.MUST,
        battle_zone = RELATION_MODE.MUST,
    }
    for _, enum in pairs(ETE.EBSTargetCampType) do
        local flag = bit.lshift(1, enum)
        if bit.band(flag, CampTypeMask) ~= 0 then
            local name = CampTypeToRelation[enum]
            if name then
                set[name] = RELATION_MODE.ALLOW
            end
        end
    end
    local id = GenNewRelation(RelationContext, set)
    CampMap[CampTypeMask] = id
    return id
end


local function ProcessTaskCampAndRelation(RelationContext, task)
    if task.TargetFilter then
        task.TargetFilter.RelationId = ConvertAndGenRelations(RelationContext, task.TargetFilter.TargetCampType, false)
    end
    if task.BuffTargetInfo then
        task.BuffTargetInfo.RelationId = ConvertAndGenRelations(RelationContext, task.BuffTargetInfo.TargetCampType,
            false)
    end
    if task.ProjectileData and task.ProjectileData.TargetFilter then
        task.ProjectileData.TargetFilter.RelationId = ConvertAndGenRelations(RelationContext,
            task.ProjectileData.TargetFilter.TargetCampType, false)
    end
end



post_export(
    "relation",
    "RelationMap",
    "关系id表生成",
    "SkillMap|BuffMap",
    function(ctx)
        local RelationContext = {
            Relations = {},
            RelationKeyIdMap = {},
            RelationId = 1000,
            CampMap = {},
            CampMapOnlyCampR = {}
        }
        local relationSetData = ctx.read_from_file("relation_set.lua")
        if relationSetData then
            LoadRelationFromFile(relationSetData, RelationContext)
        end
        for skillId, skillAsset in pairs(ctx.SkillMap) do
            for _, section in ipairs(skillAsset.Sections) do
                for _, task in ipairs(section.TaskList) do
                    ProcessTaskCampAndRelation(RelationContext, task)
                end
            end
        end
        for buffId, buffAsset in pairs(ctx.BuffMap) do
            for _, section in ipairs(buffAsset.Sections) do
                for _, task in ipairs(section.TaskList) do
                    ProcessTaskCampAndRelation(RelationContext, task)
                end
            end
        end
        ctx.RelationMap = RelationContext.Relations
        ctx.write_to_file(RelationContext.Relations, "relation_set.lua", "relation")
    end
)
