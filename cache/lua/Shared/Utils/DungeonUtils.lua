local Const = kg_require("Shared.Const")

local TableData = Game.TableData or TableData

local pairs = pairs
local ipairs = ipairs
local next = next
local unpack = unpack
if _G.IsClient then
	pairs = ksbcpairs
	ipairs = ksbcipairs
	next = ksbcnext
	unpack = ksbcunpack
	table.getn = function(t) return #t  end
end

DUNGEON_BUFF_LEVEL_FUNC_NAME = {
	[Const.DUNGEON_BUFF_CONDITION.DUNGEON_OPEN] = "getDungeonOpenBuffLevel",
	[Const.DUNGEON_BUFF_CONDITION.FIRST_COMPLETE] = "getDungeonFirstCompleteBuffLevel",
	[Const.DUNGEON_BUFF_CONDITION.DIFFERENT_CLASS] = "getDungeonDifferentClassBuffLevel",
}

function getDungeonOpenBuffLevel(dungeonBuffData, dungeonID, dungeonMode)
	local infos = dungeonBuffData.Arg2Level
	local dungeonData = TableData.GetDungeonDataRow(dungeonID)
	local startTime = dungeonData.DungeonStartTimes[dungeonMode]
	local buffLevel = 0
	local TimeInSecCache = _G._now(1)
	for _, info in pairs(infos) do
		if TimeInSecCache - startTime > (info[1] or 0) * 86400 then
			buffLevel = info[2] or 0
		end
	end
	
	return buffLevel
end

function getDungeonFirstCompleteBuffLevel(dungeonBuffData, dungeonID, dungeonMode)
	local infos = dungeonBuffData.Arg2Level
	local dungeonRecord = Game.Process:GetDungeonFirstPassageRecord(self.LogicServerID, self.dungeonTemplateID)
	local buffLevel = 0
	if dungeonRecord then
		local TimeInSecCache = _G._now(1)
		local startTime = (dungeonRecord.time / 1000)
		for _, info in pairs(infos) do
			if TimeInSecCache - startTime > (info[1] or 0) * 86400 then
				buffLevel = info[2] or 0
			end
		end
	end

	return buffLevel
end

function getDungeonDifferentClassBuffLevel(dungeonBuffData, dungeonID, dungeonMode, teamInfo)
	local professionDict = {}
	local buffLevel = 0
	for _, playerInfo in pairs(teamInfo) do
		if playerInfo then
			professionDict[playerInfo.profession] = true
		end
	end

	local professionCount = table.getn(professionDict)
	for _, info in pairs(dungeonBuffData.Arg2Level) do
		if professionCount > (info[1] or 0) then
			buffLevel = info[2] or 0
		end
	end
	return buffLevel
end