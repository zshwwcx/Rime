local math = math
local pairs = pairs
local ipairs = ipairs
local next = next
local unpack = unpack

function isInGroup(player)
	return player.groupID ~= 0
end

function isInTeamGroup(player)
	return player.groupTeamID ~= 0
end