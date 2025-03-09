-- luacheck: push ignore
UI_RES_PATH_FORMAT = "/Game/Arts/UI/Panels/%s/WBP_%s.WBP_%s_C"

PANEL_ORDER_SPACE = 50
PANEL_ORDER_MIN = 10000
PANEL_ORDER_MAX = 100000

CANVAS_TYPE =
{
    UI_CACHE = 1,     --放置缓存UI的节点
    NORMAL_UI = 2,    --正常面板放置节点
    DISPLAY_UI = 3,   --独显UI节点
}

---@class HIDE_PANELS_SOURCE_TYPE 隐藏面板的来源
HIDE_PANELS_SOURCE_TYPE =
{
    CUSTOM = 0, --自定义
    UI_SCENE = 1,
    UI_QTE = 2,
    ITEM_SUBMIT = 3,
    DIALOGUE = 4,
    NPC_APPERANCES = 5,
    NPC = 6,
    PHOTOGRAPH = 7,
    MANOR = 8,
    CUTSCENE = 9,
    UI_SCENE = 10,
    SequenceTalk = 11,
}

LOBBY_UI =
{
    "P_GMOverlay",
    "P_ScreenInput",
    "P_ReminderPanel",
    "P_HUDBaseView",
    "P_ClickEffectPanel"
}

---@class HIDE_ALL_WHITE_LIST
HIDE_ALL_WHITE_LIST =
{
    "P_ScreenInput",
    "P_ReminderPanel",
    "P_Reconnect",
    "P_GMOverlay",
    "P_GMCombatData",
    "P_BlackMask",
    "P_ShowSceneBlackMask",
    "P_WhiteMask",
    "P_LoginWhiteMask",
    "P_ComLoading",
    "P_CommonAside",
    "P_HUDAside",
    "P_ClickEffectPanel",
    "P_HUDBranch",
	"P_ReminderMarquee",
}

BlackMaskUIName = "P_BlackMask"

--GameLoop 切换Stage时保留的UI（其他UI都会被关闭）
SwitchStageUIWhiteList = {
    "P_GMOverlay",
    "P_GM",
    "P_DebugInfoPanel",
    "P_ReminderPanel",
    "P_FakeWorldWidgetPanel",
    "P_ReminderMarquee",
	"P_Reconnect",
    "P_PopupDialog",
	"P_PopupCurrencyDialog",
	"P_BottomPopupDialog",
	"P_BottomPopupDialogDance",
    "P_LoadingDefault",
    "P_LoadingQuick",
    "P_LoadingSpecial",
    "P_LoadingAbsorb",
    "P_WhiteMask",
    "P_LoginWhiteMask",
    "P_ClickEffectPanel",
    "P_DebugFPS",
    "P_Dialogue",
}

--动作模式下屏蔽鼠标的UI
OperatorModeUI = {
    P_GMOverlay = true,
    P_DebugFPS = true,
    P_DebugInfoPanel = true,
    P_ReminderPanel = true,
	P_ReminderMarquee = true,
    P_FakeWorldWidgetPanel = true,
    P_ClickEffectPanel = true,
    P_HUDBaseView = true,
    P_HUDInteract = true,
    P_ScreenInput = true,
    P_LoadingDefault = true,
    P_LoadingQuick = true,
    P_TowerLoading = true,
    P_HoverTips = true,
    P_NPCCSBg = true,
    P_NPCCS = true,
    P_CommonAside = true,
    P_ScreenEffectTop = true,
    P_ChatSmallWindowLayer = true,
    P_TeamApplyInviteTips = true,
    P_ChatBarrageLayer = true,
}

SceneTransitionView = "P_ShowSceneBlackMask" --打开3D场景时的转场UI

--屏蔽出场动画的UI
IgnoreAutoFadeOutUI = {
    P_Bag = true,
    P_Book = true,
    P_Social = true,
    P_PartnerAddTotal = true,
    P_HUDSocialAction = true,
    P_MapSubwayDetail = true,
    P_MapExplore = true,
    P_MapV2 = true,
    P_PharmacistMain = true,
    P_PharmacistQuickRefine = true,
    P_PharmacistRefine = true,
    P_PharmacistPrescriptionDiscovery = true,
    P_Refine = true,
    P_ReminderDungeonAreaChange = true,
    P_RolePlayNewRoleCard = true,
    P_RolePlayDetails = true,
    P_RolePlayIdentify = true,
    P_Sealed = true,
    P_SefirotCore = true,
    P_SwitchCore = true,
    P_SealedCultivate = true,
    P_Settings = true,
    P_QuestBoard = true,
}

IgnoreAutoCloseUI ={
    P_CommonAside = true
}


UICacheLevel =
{
    MobileHigh = 1,
    MobileMiddle = 2,
    MobileLow = 3,
    PCHigh = 4,
    PCMiddle = 5,
    PCLow = 6,
}

UICacheConfig =
{
    [UICacheLevel.MobileHigh] = {dynamicPanel = 3, staticPanel = 20, component = 20, item = 100},
    [UICacheLevel.MobileMiddle] ={dynamicPanel = 3, staticPanel = 20, component = 20, item = 100},
    [UICacheLevel.MobileLow] = {dynamicPanel = 3, staticPanel = 20, component = 20, item = 100},
    [UICacheLevel.PCHigh] = {dynamicPanel = 3, staticPanel = 20, component = 20, item = 100},
    [UICacheLevel.PCMiddle] = {dynamicPanel = 3, staticPanel = 20, component = 20, item = 100},
    [UICacheLevel.PCLow] = {dynamicPanel = 3, staticPanel = 20, component = 20, item = 100},
}
-- luacheck: pop