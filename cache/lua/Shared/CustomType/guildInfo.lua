local const = kg_require("Shared.Const")
local lume = kg_require("Shared.lualibs.lume")

-- local timeUtils = kg_require("Shared.Utils.TimeUtils")

-- local guildBabyTaskData = kg_require("data.guild_baby_task_data")

local math_min = math.min

DefineClass("PlayerGuild")


function PlayerGuild:ctor(dict)
    if not dict then
        return
    end
    self.status = dict.status or 0
    local roles = dict.roles
    if not roles then
        roles = {}
        for _, v in pairs(const.GUILD_ROLE_TYPE) do
            roles[v] = 0
        end
    end
    self.roles = roles
    self.guildBabyName = dict.guildBabyName or ""
    self.signature = dict.signature or ""
    self.lastSignInTime = dict.lastSignInTime or 0
    self.isVoiceSignature = dict.isVoiceSignature or false
    self.enterTime = dict.enterTime or 0
    self.guildShopLv = dict.guildShopLv or 0
end

function PlayerGuild:extend(info)
    lume.extend(self, info)
end

function PlayerGuild:update(info)
    for k, v in pairs(info) do
        if self[k] ~= nil then
            self[k] = v
        end
    end
end

DefineClass("GuildMember")

function GuildMember:ctor(dict)
    if not dict then
        return
    end
    self.id = dict.id or 0
    self.school = dict.school or 0
    self.rolename = dict.rolename or ""
    self.lv = dict.lv or 0
    local roles = dict.roles
    if not roles then
        roles = {}
        for _, v in pairs(const.GUILD_ROLE_TYPE) do
            roles[v] = 0
        end
    end
    self.roles = roles
    self.curContribution = dict.curContribution or 0
    self.weekContribution = dict.weekContribution or 0
    self.contribution = dict.contribution or 0
    self.offlineTime = dict.offlineTime or 0
    self.enterTime = dict.enterTime or 0
    self.spaceId = dict.spaceId or 0
    self.power = dict.power or 0
    self.dayGuildChatNum = dict.dayGuildChatNum or 0
    self.weekGuildChatNum = dict.weekGuildChatNum or 0
    self.accountId = dict.accountId or ""
    self.groupID = dict.groupID or 0
    self.lastEnterGuildLeague = dict.lastEnterGuildLeague or 0

    self.teamLeaderName = dict.teamLeaderName or ""
    self.groupLeaderName = dict.groupLeaderName or ""
end


function GuildMember:update(info)
    if info then
        for key, value in pairs(info) do
            self[key] = value
        end
    end
end

function GuildMember:getRoleByType(type)
    return self.roles[type] or 0
end

function GuildMember:isBaby()
    for _, v in pairs(self.roles) do
        if v == const.GUILD_ROLE.BABY then
            return true
        end
    end
    return false
end

function GuildMember:isApprentice()
    return self.roles[const.GUILD_ROLE_TYPE.COMMON_ROLE] == const.GUILD_ROLE.APPRENTICE
end

function GuildMember:getMaxRankRole()
    local roles = self.roles
    local role = roles[const.GUILD_ROLE_TYPE.COMMON_ROLE]
    local grdd = TableData.GetGuildRightDataRow(role)
    local maxRankRole = role
    local maxRank = grdd.Rank 
    for _, v in pairs(roles) do
        local grdd = TableData.GetGuildRightDataRow(v)
        if grdd and grdd.Rank > maxRank then
            maxRankRole = v
            maxRank = grdd.Rank
        end
    end

    return maxRankRole
end

function GuildMember:isCommon()
    local roles = self.roles

    for k, v in pairs(roles) do
        if k ~= const.GUILD_ROLE_TYPE.COMMON_ROLE and  v ~= 0 then
            return false
        end
    end

    local commonRole = roles[const.GUILD_ROLE_TYPE.COMMON_ROLE]

    return commonRole == const.GUILD_ROLE.MEMBER or commonRole == const.GUILD_ROLE.APPRENTICE
end

function GuildMember:isPresident()
    local role = self.roles[const.GUILD_ROLE_TYPE.COMMON_ROLE]
    return role == const.GUILD_ROLE.PRESIDENT or role == const.GUILD_ROLE.BOSS
end

function GuildMember:isFounder()
    local role = self.roles[const.GUILD_ROLE_TYPE.COMMON_ROLE]
    return role == const.GUILD_ROLE.FOUNDER or role == const.GUILD_ROLE.BOSS
end

function GuildMember:isOnline()
    return self.offlineTime == 0
end

--- 是否属于转让
-- @param tgtRole 转让的职位
function GuildMember:isDemise(tgtNewRole)
    return tgtNewRole == const.GUILD_ROLE.BOSS
end

--- 是否在time前离线
-- @param time 时间戳
function GuildMember:isOfflineBefore(time)
    return self.offlineTime > 0 and self.offlineTime < time
end

--- 是否在time后离线
-- @param time 时间戳
function GuildMember:isOfflineAfter(time)
    return self.offlineTime == 0 or self.offlineTime >= time
end

function GuildMember:canFreeKick(now)
    local offFreeTime = now - Enum.EConstIntData.GUILD_FREE_KICK_OFFLINE_DAYS * const.SECONDS_ONE_DAY
    if self.offlineTime ~= 0 and self.offlineTime <= offFreeTime then
        return true
    end

    local conFreeTime = now - Enum.EConstIntData.GUILD_FREE_KICK_CONTRIBUTION_DAYS * const.SECONDS_ONE_DAY
    return self.enterTime <= conFreeTime and self.contribution < Enum.EConstIntData.GUILD_FREE_KICK_CONTRIBUTION_NUM
end

local function memberHasRight(role, rightKey, customRights)
    local grdd = TableData.GetGuildRightDataRow(role)
    local rightType = grdd and grdd.Right and grdd.Right[rightKey]
    if not rightType then
        return false
    end
    local custom = customRights and customRights[role] or {}
    if custom[rightKey] ~= nil and (rightType == const.GUILD_RIGHT_VARIABLE_TRUE or rightType == const.GUILD_RIGHT_VARIABLE_FALSE) then
        return custom[rightKey]
    end

    if rightType == const.GUILD_RIGHT_TRUE or rightType == const.GUILD_RIGHT_VARIABLE_TRUE then
        return true
    else
        return false
    end
end

function GuildMember:hasRight(rightKey, customRights)
    for _, v in pairs(self.roles) do
        if memberHasRight(v, rightKey, customRights) then
            return true
        end
    end
    return false
end

local function getRoleRank(role)
    local grdd = TableData.GetGuildRightDataRow(role)
    return grdd and grdd.Rank or 0
end

function GuildMember:getRank()
    local maxRank = -1
    for _, v in pairs(self.roles) do
        local roleRank = getRoleRank(v)
        if roleRank > maxRank then
            maxRank = roleRank
        end
    end
    return maxRank
end


DefineClass("CompleteGuildMember", GuildMember)

function CompleteGuildMember:ctor(dict)
    if not dict then
        return
    end
    self.lastWeekWage = dict.lastWeekWage or 0
    self.curWeekWage = dict.curWeekWage or 0
    self.mailbox = dict.mailbox
    self.isInTeam = dict.isInTeam or false
    self.wageFlag = dict.wageFlag or false
    self.goods = dict.goods or {}
    self.dayOnlineTime = dict.dayOnlineTime or 0
    self.chatTitle = dict.chatTitle or {}
    self.dayMailNum = dict.dayMailNum or 0
    self.dayFirstLoginTime = dict.dayFirstLoginTime or 0
end

function CompleteGuildMember:getLogDetail()
    return {
        id = self.id,
        school = self.school,
        rolename =self.rolename,
        lv = self.lv,
        roles = self.roles,
        candidate = self.candidate,
        curContribution = self.curContribution,
        weekContribution = self.weekContribution,
        contribution = self.contribution,
        offlineTime  = self.offlineTime,
        enterTime = self.enterTime,
        lastWeekWage  = self.lastWeekWage,
        curWeekWage = self.curWeekWage,
        lastDayOnlineTime = self.lastDayOnlineTime or 0,
    }
end

function CompleteGuildMember:addContribution(addNum)
    if addNum <= 0 then
        return
    end
    self.curContribution = self.curContribution + addNum
    if addNum > 0 then
        self.weekContribution = self.weekContribution + addNum
        self.contribution = self.contribution + addNum
        return addNum
    end
end

function CompleteGuildMember:addWage(num)
    self.curWeekWage = math_min(self.curWeekWage + num, Enum.EConstIntData.WEEK_MAX_WAGE_NUM)
end

function CompleteGuildMember:getCurWeekWage()
    return math_min(Enum.EConstIntData.WEEK_MAX_WAGE_NUM, self.curWeekWage)
end

function CompleteGuildMember:getLastWeekWage()
    return math_min(Enum.EConstIntData.WEEK_MAX_WAGE_NUM, self.lastWeekWage)
end

function CompleteGuildMember:addDayOnlineTime(num)
    if num <= 0 then
        return
    end
    self.dayOnlineTime = self.dayOnlineTime + num
end

function CompleteGuildMember:dayRefreshOnlineTime()
    self.lastDayOnlineTime = self.dayOnlineTime
    self.dayOnlineTime = 0
end

DefineClass("GuildSimpleInfo")

function GuildSimpleInfo:ctor(dict)
    if not dict then
        return
    end
    self.id = dict.id or 0
    self.shortId = dict.shortId or 0
    self.name = dict.name or 0
    self.lv = dict.lv or 0
    self.memberNum = dict.memberNum or 0
    self.apprenticeNum = dict.apprenticeNum or 0
    self.leaderName = dict.leaderName or ""
    self.leaderId = dict.leaderId or 0
    self.createTime = dict.createTime or 0
    self.liveValue = dict.liveValue or 0
    self.isAutoAgree = dict.isAutoAgree or false
    self.maxMemberNum = dict.maxMemberNum or 0
    self.totalMaxMemberNum = dict.totalMaxMemberNum or 0
    self.createType = dict.createType or 0
    self.badgeFrameId = dict.badgeFrameId or 0
    self.powerSum = dict.powerSum or 0
    self.guildType = dict.guildType or 1
    self.badgeIndex = dict.badgeIndex or 1
end

function GuildSimpleInfo:update(info)
    for key, value in pairs(info) do
        self[key] = value
    end
end

function GuildSimpleInfo:isApprenticeFull()
    return (self.memberNum + self.apprenticeNum) >= self.totalMaxMemberNum
end

function GuildSimpleInfo:getTotalMemberNum()
    return self.memberNum + self.apprenticeNum
end

function GuildSimpleInfo:isActive(now)
    return (now - self.createTime < Enum.EConstIntData.GUILD_NEW_CREATE_DAYAS * const.SECONDS_ONE_DAY) or
        self.liveValue >= Enum.EConstIntData.MIN_SHOW_GUILD_LIVE_VALUE
end

function MakeGuildApply(avatar, apply)
    if not avatar or not apply then
        return
    end
    apply.id = avatar.id or ""
    apply.school = avatar.school or 0
    apply.rolename = avatar.rolename or ""
    apply.lv = avatar.lv or 0
    apply.power = avatar.power or 0
    apply.applyTime = avatar.applyTime or 0
    apply.reason = avatar.reason or ""
    apply.power = avatar.ZhanLi or avatar.power or ""
end


DefineClass("StoreContribution")

function StoreContribution:ctor(dict)
    if not dict then
        return
    end
    self.weekContribution = dict.weekContribution or 0
    self.contribution = dict.contribution or 0
    self.overTime = dict.overTime or 0
end


function StoreContribution:isOverTime(now)
    return self.overTime > 0 and self.overTime <= now
end

function StoreContribution:weekReset()
    self.weekContribution = 0
end