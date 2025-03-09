-- luacheck: push ignore

TaskTag = "TaskTag"
ReportTargetPage = "ReportTargetPage"
ReportReasonPage = "ReportReasonPage"
ReportInfoPage = "ReportInfoPage"
ReportImagePage = "ReportImagePage"

EquipStrengthenPage = "EquipStrengthenPage"
EquipAttributeChangePage = "EquipAttributeChangePage"
EquipEntryPage = "EquipEntryPage"
EquipApplyEntryPage = "EquipApplyEntryPage"
EquipPropAttribute_Item = "EquipPropAttribute_Item"
EquipTagText_Item = "EquipTagText_Item"

ItemNml = "ItemNml"
ComSelectedLight = "ComSelectedLight"

GuildOutApplyPage = "GuildOutApplyPage"
GuildOutResponseOtherPage = "GuildOutResponseOtherPage"
GuildOutResponseCreatorPage = "GuildOutResponseCreatorPage"
GuildOutCreatePage = "GuildOutCreatePage"
GuildInMemberList = "GuildInMemberList"
GuildInMemberPage = "GuildInMemberPage"
GuildInMemberApply = "GuildInMemberApply"
GuildInMemberInvite = "GuildInMemberInvite"
GuildInBuildMain = "GuildInBuildMain"
GuildHomeWelfarePage = "GuildHomeWelfarePage"
GuildInActivity = "GuildInActivity"
GuildInStructure = "GuildInStructure"

GuildBattleOutVS_Item = "GuildBattleOutVS_Item"
GuildBattleOutRanking_Item = "GuildBattleOutRanking_Item"
GuildBattleOutResultRanking_Item = "GuildBattleOutResultRanking_Item"
GuildBattleOutResultLine_Item = "GuildBattleOutResultLine_Item"

PlayerFriendGroupPost_Item = "PlayerFriendGroupPost_Item"
FriendGroupTopic = "FriendGroupTopic"
HistoryMomentsPage = "HistoryMomentsPage"

FashionClass_Page = "FashionClass_Page"
FashionPresets_Page = "FashionPresets_Page"

EleCoreTreeNodeItem = "EleCoreTreeNodeItem"
SkillCustomizerPeculiarityComponent = "SkillCustomizerPeculiarityComponent"
SkillRoutineAllSkill_Sub = "SkillRoutineAllSkill_Sub"
SkillRoutineSwitch = "SkillRoutineSwitch"

PVPMatch_SeasonList_Panel = "PVPMatch_SeasonList_Panel"
PVPMatch_Data_Panel = "PVPMatch_Data_Panel"
PVPMatch_Record_Panel = "PVPMatch_Record_Panel"
PVPMatch_Season_Panel = "PVPMatch_Season_Panel"
RolePlaySkillNode = "RolePlaySkillNode"
RolePlaySkillPanel = "RolePlaySkillPanel"
PharmacistMake = "PharmacistMake"
PharmacistRefine = "PharmacistRefine"

StatisticsCure = "StatisticsCure"
StatisticsData = "StatisticsData"

UIListViewExample = "UIListViewExample"
TreeListExample = "TreeListExample"
UICurrentcyWidget = "UICurrentcyWidget"
TabListExample = "TabListExample"
UITempComBtn = "UITempComBtn"
UITempComBtnBackArrow = "UITempComBtnBackArrow"
SettlementDungeonAwardAuction = "SettlementDungeonAwardAuction"
SettlementDungeonAwardTips = "SettlementDungeonAwardTips"
SettlementDungeonAwardAssignment = "SettlementDungeonAwardAssignment"
Scene3DDisplay = "Scene3DDisplay"
ReminderExplorationResult_Panel = "ReminderExplorationResult_Panel"
---AutoGenerateTag
---@field res string （必填）资源路径
---@field cache boolean （选填）是否进入公共缓存池
---@field auth string (必填)程序负责�---@field luaClass string （选填）不填会用资源上的脚本，填了会覆盖资源上的脚本
---@field PreloadResMap table (选填) 预加载资源路径
CellConfig = {
    [UITempComBtnBackArrow] = {res = "/Game/Arts/UI_2/Blueprint/Common/Button/WBP_ComBtnBackArrowNew.WBP_ComBtnBackArrowNew_C", cache = false, auth = ""},
    [UITempComBtn] = {res = "/Game/Arts/UI_2/Blueprint/Common/Button/WBP_ComBtn.WBP_ComBtn_C", cache = false, auth = "huangjinbao"},
    [TabListExample] = {res = "/Game/Arts/UI_2/Blueprint/UMGPreview/UMGPreviewPanel/TabListExample/WBP_TabListExample.WBP_TabListExample_C", cache = false, auth = "huangjinbao"},
    [UICurrentcyWidget] = {res = "/Game/Arts/UI_2/Blueprint/Common/Tag/WBP_ComCurrencyList.WBP_ComCurrencyList_C", cache = false, auth = "huangjinbao"},
    [TreeListExample] = {res = "/Game/Arts/UI_2/Blueprint/UMGPreview/UMGPreviewPanel/TreeListExample/WBP_TreeListExample.WBP_TreeListExample_C", cache = false, auth = "huangjinbao"},
    [UIListViewExample] = {res = "/Game/Arts/UI_2/Blueprint/UMGPreview/UMGPreviewPanel/ListExample/WBP_UIListViewExample.WBP_UIListViewExample_C", cache = false, auth = "huangjinbao"},
	[Scene3DDisplay] = {res = "/Game/Blueprint/Scene3DDisplay/Scene3DDisplay.Scene3DDisplay_C", auth = "yuanhanqing"},
	[TaskTag] = {
		res = "/Game/Arts/UI_2/Blueprint/Task/WBP_TaskTag.WBP_TaskTag_C", 
		cache = false, auth = "tangshenghao",
		luaClass = "Gameplay.LogicSystem.Task.TaskTag"
	},
	[ItemNml] = {
		res = "/Game/Arts/UI_2/Blueprint/Item/WBP_ItemNml.WBP_ItemNml_C",
		cache = false, auth = "tangshenghao",
		luaClass = "Gameplay.LogicSystem.Item.ItemNml"
	},
	[ComSelectedLight] = {
		res = "/Game/Arts/UI_2/Blueprint/Item/WBP_ComSelectedLight.WBP_ComSelectedLight_C",
		cache = false, auth = "tangshenghao",
		luaClass = "Gameplay.LogicSystem.Item.ComSelectedLight"
	},
	[EquipStrengthenPage] = {
		res = "/Game/Arts/UI_2/Blueprint/Equip/Strengthen/WBP_EquipStrengthenPage.WBP_EquipStrengthenPage_C",
		cache = false,auth = "tangshenghao",
		luaClass = "Gameplay.LogicSystem.Equip.Strengthen.EquipStrengthenPage"
	},
	[EquipAttributeChangePage] = {
		res = "/Game/Arts/UI_2/Blueprint/Equip/AttributeChange/WBP_EquipAttributeChangePage.WBP_EquipAttributeChangePage_C",
		cache = false,auth = "tangshenghao",
		luaClass = "Gameplay.LogicSystem.Equip.AttributeChange.EquipAttributeChangePage"
	},
	[EquipEntryPage] = {
		res = "/Game/Arts/UI_2/Blueprint/Equip/Entry/WBP_EquipEntryPage.WBP_EquipEntryPage_C",
		cache = false,auth = "tangshenghao",
		luaClass = "Gameplay.LogicSystem.Equip.Entry.EquipEntryPage"
	},
	[EquipApplyEntryPage] = {
		res = "/Game/Arts/UI_2/Blueprint/Equip/Apply/WBP_EquipApplyEntryPage.WBP_EquipApplyEntryPage_C",
		cache = false,auth = "tangshenghao",
		luaClass = "Gameplay.LogicSystem.Equip.Apply.EquipApplyEntryPage"
	},
	[EquipPropAttribute_Item] = {
		res = "/Game/Arts/UI_2/Blueprint/Equip/ChosePropPanel/WBP_EquipPropAttribute_Item.WBP_EquipPropAttribute_Item_C",
		cache = true,auth = "tangshenghao",
	},
	[EquipTagText_Item] = {
		res = "/Game/Arts/UI_2/Blueprint/Equip/WBP_EquipTagText_Item.WBP_EquipTagText_Item_C",
		cache = false,auth = "tangshenghao",
	},
	[ReportTargetPage] = {
		res = "/Game/Arts/UI_2/Blueprint/Report/WBP_ReportTargetPage.WBP_ReportTargetPage_C", 
		cache = false, auth = "tangshenghao",
		luaClass = "Gameplay.LogicSystem.Report.ReportTargetPage"
	},
	[ReportReasonPage] = {
		res = "/Game/Arts/UI_2/Blueprint/Report/WBP_ReportReasonPage.WBP_ReportReasonPage_C", 
		cache = false, auth = "tangshenghao",
		luaClass = "Gameplay.LogicSystem.Report.ReportReasonPage"
	},
	[ReportInfoPage] = {
		res = "/Game/Arts/UI_2/Blueprint/Report/WBP_ReportInfoPage.WBP_ReportInfoPage_C", 
		cache = false, auth = "tangshenghao",
		luaClass = "Gameplay.LogicSystem.Report.ReportInfoPage"
	},
	[ReportImagePage] = {
		res = "/Game/Arts/UI_2/Blueprint/Report/WBP_ReportImagePage.WBP_ReportImagePage_C", 
		cache = false, auth = "tangshenghao",
		luaClass = "Gameplay.LogicSystem.Report.ReportImagePage"
	},
    [GuildOutApplyPage] = {
        res = "/Game/Arts/UI_2/Blueprint/Guild/Outside_2/Apply/WBP_GuildOutApplyPage.WBP_GuildOutApplyPage_C",
        cache = false, auth = "liyixiong",
        luaClass = "Gameplay.LogicSystem.Guild.Outside_2.Apply.GuildOutApplyPage"
    },
    [GuildOutResponseOtherPage] = {
        res = "/Game/Arts/UI_2/Blueprint/Guild/Outside_2/Response/WBP_GuildOutResponseOtherPage.WBP_GuildOutResponseOtherPage_C",
        cache = false, auth = "liyixiong",
        luaClass = "Gameplay.LogicSystem.Guild.Outside_2.Response.GuildOutResponseOtherPage"
    },
    [GuildOutResponseCreatorPage] = {
        res = "/Game/Arts/UI_2/Blueprint/Guild/Outside_2/Response/WBP_GuildOutResponseCreatorPage.WBP_GuildOutResponseCreatorPage_C",
        cache = false, auth = "liyixiong",
        luaClass = "Gameplay.LogicSystem.Guild.Outside_2.Response.GuildOutResponseCreatorPage"
    },
    [GuildOutCreatePage] = {
        res = "/Game/Arts/UI_2/Blueprint/Guild/Outside_2/Create/WBP_GuildOutCreatePage.WBP_GuildOutCreatePage_C",
        cache = false, auth = "liyixiong",
        luaClass = "Gameplay.LogicSystem.Guild.Outside_2.Create.GuildOutCreatePage"
    },
    [GuildInMemberPage] = {
        res = "/Game/Arts/UI_2/Blueprint/Guild/Inside_2/Member/WBP_GuildInMemberPage.WBP_GuildInMemberPage_C",
        cache = false, auth = "liyixiong",
        luaClass = "Gameplay.LogicSystem.Guild.Inside_2.Member.GuildInMemberPage"
    },
    [GuildInMemberList] = {
        res = "/Game/Arts/UI_2/Blueprint/Guild/Inside_2/Member/WBP_GuildInMemberList.WBP_GuildInMemberList_C",
        cache = false, auth = "liyixiong",
        luaClass = "Gameplay.LogicSystem.Guild.Inside_2.Member.GuildInMemberList"
    },
    [GuildInMemberApply] = {
        res = "/Game/Arts/UI_2/Blueprint/Guild/Inside_2/Member/WBP_GuildInMemberApply.WBP_GuildInMemberApply_C",
        cache = false, auth = "liyixiong",
        luaClass = "Gameplay.LogicSystem.Guild.Inside_2.Member.GuildInMemberApply"
    },
    [GuildInMemberInvite] = {
        res = "/Game/Arts/UI_2/Blueprint/Guild/Inside_2/Member/WBP_GuildInMemberInvite.WBP_GuildInMemberInvite_C",
        cache = false, auth = "liyixiong",
        luaClass = "Gameplay.LogicSystem.Guild.Inside_2.Member.GuildInMemberInvite"
    },
    [GuildInBuildMain] = {
        res = "/Game/Arts/UI_2/Blueprint/Guild/Inside_2/Build/WBP_GuildInBuildMain.WBP_GuildInBuildMain_C",
        cache = false, auth = "liyixiong",
        luaClass = "Gameplay.LogicSystem.Guild.Inside_2.Build.GuildInBuildMain"
    },
    [GuildInStructure] = {
        res = "/Game/Arts/UI_2/Blueprint/Guild/Inside_2/Structure/WBP_GuildInStructure.WBP_GuildInStructure_C",
        cache = false, auth = "liyixiong",
        luaClass = "Gameplay.LogicSystem.Guild.Inside_2.Structure.GuildInStructure"
    },
    [GuildHomeWelfarePage] = {
        res = "/Game/Arts/UI_2/Blueprint/Guild/Inside_2/Welfare/WBP_GuildHomeWelfarePage.WBP_GuildHomeWelfarePage_C",
        cache = false, auth = "liyixiong",
        luaClass = "Gameplay.LogicSystem.Guild.Inside_2.Welfare.GuildHomeWelfarePage"
    },
    [GuildInActivity] = {
        res = "/Game/Arts/UI_2/Blueprint/Guild/Inside_2/Activity/WBP_GuildInActivity.WBP_GuildInActivity_C",
        cache = false, auth = "liyixiong",
        luaClass = "Gameplay.LogicSystem.Guild.Inside_2.Activity.GuildInActivity"
    },
	[GuildBattleOutVS_Item] = {
		res = '/Game/Arts/UI_2/Blueprint/Guild/GuildBattle/OutPanel/WBP_GuildBattleOutVS_Item.WBP_GuildBattleOutVS_Item_C',
		cache = false, auth = "qusicheng03",
		luaClass = "Gameplay.LogicSystem.Guild.GuildBattle.OutPanel.GuildBattleOutVS_Item"
	},
	[GuildBattleOutRanking_Item] = {
		res = '/Game/Arts/UI_2/Blueprint/Guild/GuildBattle/OutPanel/WBP_GuildBattleOutRanking_Item.WBP_GuildBattleOutRanking_Item_C',
		cache = false, auth = "qusicheng03",
		luaClass = "Gameplay.LogicSystem.Guild.GuildBattle.OutPanel.GuildBattleOutRanking_Item"
	},
	[GuildBattleOutResultRanking_Item] = {
		res = "/Game/Arts/UI_2/Blueprint/Guild/GuildBattle/OutPanel/WBP_GuildBattleOutResultRanking_Item.WBP_GuildBattleOutResultRanking_Item_C",
		cache = false, auth = "qusicheng03",
		luaClass = "Gameplay.LogicSystem.Guild.GuildBattle.OutPanel.GuildBattleOutResultRanking_Item"
	},
	[GuildBattleOutResultLine_Item] = {
		res = '/Game/Arts/UI_2/Blueprint/Guild/GuildBattle/OutPanel/WBP_GuildBattleOutResultLine_Item.WBP_GuildBattleOutResultLine_Item_C',
		cache = false, auth = "qusicheng03",
		luaClass = "Gameplay.LogicSystem.Guild.GuildBattle.OutPanel.GuildBattleOutResultLine_Item"
	},
    [PlayerFriendGroupPost_Item] = {
        res = "/Game/Arts/UI_2/Blueprint/Chat/FriendGroup/WBP_PlayerFriendGroupPost_Item.WBP_PlayerFriendGroupPost_Item_C",
        cache = false, auth = "yecaifeng05",
        luaClass = "Gameplay.LogicSystem.Chat.FriendGroup.PlayerFriendGroupPost_Item"
    },
    [FriendGroupTopic] = {
        res = "/Game/Arts/UI_2/Blueprint/Chat/FriendGroup/WBP_FriendGroupTopic.WBP_FriendGroupTopic_C",
        cache = false, auth = "yecaifeng05",
    },
	[HistoryMomentsPage] = {
		res = "/Game/Arts/UI_2/Blueprint/Chat/FriendGroup/WBP_HistoryMomentsPage.WBP_HistoryMomentsPage_C",
		cache = false, auth = "yecaifeng05",
	},
	[FashionClass_Page] = {
		res = "/Game/Arts/UI_2/Blueprint/Fashion/WBP_FashionClass_Page.WBP_FashionClass_Page_C",
		cache = false, auth = "gushengyu",
		luaClass = "Gameplay.LogicSystem.Fashion.FashionClass_Page.FashionClass_Page"
	},
	[FashionPresets_Page] = {
		res = "/Game/Arts/UI_2/Blueprint/Fashion/WBP_FashionPresets_Page.WBP_FashionPresets_Page_C",
		cache = false, auth = "gushengyu",
		luaClass = "Gameplay.LogicSystem.Fashion.FashionPresets_Page.FashionPresets_Page"
	},
	[EleCoreTreeNodeItem] = {
		res = "/Game/Arts/UI_2/Blueprint/ElementCore/EleTalentTree/WBP_EleCoreTreeNodeItem1.WBP_EleCoreTreeNodeItem1_C",
		cache = false, auth = "qusicheng03",
	},
	[SkillCustomizerPeculiarityComponent] = {
		res = "/Game/Arts/UI_2/Blueprint/SkillCustomizer_2/SkillPeculiarity/WBP_SkillCustomizerPeculiarityComponent.WBP_SkillCustomizerPeculiarityComponent_C",
		cache = false, auth = "qusicheng03",
	},
	[SkillRoutineAllSkill_Sub] = {
		res = "/Game/Arts/UI_2/Blueprint/SkillCustomizer_2/SkillRoutine/WBP_SkillRoutineAllSkill_Sub.WBP_SkillRoutineAllSkill_Sub_C",
		cache = false, auth = "qusicheng03",
	},
	[SkillRoutineSwitch] = {
		res = "/Game/Arts/UI_2/Blueprint/SkillCustomizer_2/SkillRoutine/WBP_SkillRoutineSwitch.WBP_SkillRoutineSwitch_C",
		cache = false, auth = "qusicheng03",
	},
	[PVPMatch_SeasonList_Panel] = {
		res = '/Game/Arts/UI_2/Blueprint/PVP/PVP_Match/WBP_PVPMatch_SeasonList_Panel.WBP_PVPMatch_SeasonList_Panel_C',
		cache = false, auth = "qusicheng03",
		luaClass = "Gameplay.LogicSystem.PVP.PVP_Match.PVPMatch_SeasonList_Panel"
	},
	[PVPMatch_Data_Panel] = {
		res = '/Game/Arts/UI_2/Blueprint/PVP/PVP_Match/WBP_PVPMatch_Data_Panel.WBP_PVPMatch_Data_Panel_C',
		cache = false, auth = "qusicheng03",
		luaClass = "Gameplay.LogicSystem.PVP.PVP_Match.PVPMatch_Data_Panel"
	},
	[PVPMatch_Record_Panel] = {
		res = '/Game/Arts/UI_2/Blueprint/PVP/PVP_Match/WBP_PVPMatch_Record_Panel.WBP_PVPMatch_Record_Panel_C',
		cache = false, auth = "qusicheng03",
		luaClass = "Gameplay.LogicSystem.PVP.PVP_Match.PVPMatch_Record_Panel"
	},
	[PVPMatch_Season_Panel] = {
		res = '/Game/Arts/UI_2/Blueprint/PVP/PVP_Match/WBP_PVPMatch_Season_Panel.WBP_PVPMatch_Season_Panel_C',
		cache = false, auth = "qusicheng03",
		luaClass = "Gameplay.LogicSystem.PVP.PVP_Match.PVPMatch_Season_Panel"
	},
	[RolePlaySkillNode] = {
		res = '/Game/Arts/UI_2/Blueprint/RolePlay/RolePlayNew/WBP_RolePlaySkillNode.WBP_RolePlaySkillNode_C',
		cache = false, auth = "zhangsuohao",
		luaClass = "Gameplay.LogicSystem.RolePlay.RolePlayNew.RolePlaySkillNode"
	},
	[RolePlaySkillPanel] = {
		res = '/Game/Arts/UI_2/Blueprint/RolePlay/RolePlayNew/WBP_RolyPlaySkill_Panel.WBP_RolyPlaySkill_Panel_C',
		cache = true, auth = "zhangsuohao",
		luaClass = "Gameplay.LogicSystem.RolePlay.RolePlayNew.RolePlaySkillPanel"
	},
	[StatisticsCure] = {
		res = '/Game/Arts/UI_2/Blueprint/Dungeon/StatisticsDungeon/WBP_StatisticsCure.WBP_StatisticsCure_C',
		cache = true, auth = "qusicheng03",
		luaClass = "Gameplay.LogicSystem.Dungeon.StatisticsDungeon.StatisticsCure"
	},
	[PharmacistMake] = {
		res = '/Game/Arts/UI_2/Blueprint/Pharmacist/Make/WBP_PharmacistMake.WBP_PharmacistMake_C',
		auth = "chengqi03",
		luaClass = "Gameplay.LogicSystem.Pharmacist.Make.PharmacistMake"
	},
	[PharmacistRefine] = {
		res = '/Game/Arts/UI_2/Blueprint/Pharmacist/Refine/WBP_PharmacistRefine.WBP_PharmacistRefine_C',
		auth = "chengqi03",
		luaClass = "Gameplay.LogicSystem.Pharmacist.Refine.PharmacistRefine"
	},
	[StatisticsData] = {
		res = '/Game/Arts/UI_2/Blueprint/Dungeon/StatisticsDungeon/WBP_StatisticsData.WBP_StatisticsData_C',
		cache = true, auth = "qusicheng03",
		luaClass = "Gameplay.LogicSystem.Dungeon.StatisticsDungeon.StatisticsData"
	},
	[SettlementDungeonAwardAssignment] = {
		res = "/Game/Arts/UI_2/Blueprint/HUD/HUD_BtnTime/WBP_HUDBtnTime.WBP_HUDBtnTime_C",
		auth = "hejiaqi05",
		luaClass = "Gameplay.LogicSystem.Dungeon.Settlement.SettlementDungeonAwardAssignment"
	},
	[SettlementDungeonAwardAuction] = {
		res = "/Game/Arts/UI_2/Blueprint/HUD/HUD_BtnTime/WBP_HUDBtnTime.WBP_HUDBtnTime_C",
		auth = "hejiaqi05",
		luaClass = "Gameplay.LogicSystem.Dungeon.Settlement.SettlementDungeonAwardAuction"
	},
	[SettlementDungeonAwardTips] = {
		res = "/Game/Arts/UI_2/Blueprint/HUD/HUD_BtnTime/WBP_HUDBtnTimeAcution.WBP_HUDBtnTimeAcution_C",
		auth = "hejiaqi05",
		luaClass = "Gameplay.LogicSystem.Dungeon.Settlement.SettlementDungeonAwardTips"
	},
	[ReminderExplorationResult_Panel] = {
		res = "/Game/Arts/UI_2/Blueprint/Reminder/Exploration/WBP_ReminderExplorationResult_Panel.WBP_ReminderExplorationResult_Panel_C",
		auth = "shijiaxing05",
		luaClass = "Gameplay.LogicSystem.Reminder.Exploration.ReminderExplorationResult_Panel",
		parent = "P_ReminderPanel/InteractorGameResult",
		parentui = "P_ReminderPanel",
	}
}

-- luacheck: pop