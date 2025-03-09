---@class WBP_SealedBuffView : WBP_SealedBuff_C
---@field public WidgetRoot WBP_SealedBuff_C
---@field public Text_Title C7TextBlock
---@field public RTB_Detail C7RichTextBlock
---@field public IsDebuff boolean
---@field public IsExpansion boolean
---@field public Offset01 Margin
---@field public Offset02 Margin
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetDebuff fun(self:self,IsDebuff:boolean):void
---@field public SetExpansion fun(self:self,IsExpansion:boolean):void


---@class WBP_ItemDetailListView : WBP_ItemDetailList_C
---@field public WidgetRoot WBP_ItemDetailList_C
---@field public PackList VerticalBox


---@class WBP_ItemTipsBtnView : WBP_ItemTipsBtn_C
---@field public WidgetRoot WBP_ItemTipsBtn_C
---@field public Text_Com TextBlock
---@field public Button C7Button
---@field public False SlateBrush
---@field public True SlateBrush
---@field public False_0 SlateFontInfo
---@field public True_0 SlateFontInfo
---@field public False_1 SlateColor
---@field public True_1 SlateColor
---@field public Is Light boolean
---@field public SetLight fun(self:self,IsLight:boolean):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void


---@class WBP_ItemTipsStarView : WBP_ItemTipsStar_C
---@field public WidgetRoot WBP_ItemTipsStar_C
---@field public WS_Star WidgetSwitcher
---@field public se_lua number
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void


---@class WBP_ChatResourceView : WBP_ChatResource_C
---@field public WidgetRoot WBP_ChatResource_C
---@field public sb SizeBox
---@field public text_channel TextBlock
---@field public FontOutline FontOutlineSettings
---@field public Channel Type number
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetColor fun(self:self,ChannelType:number):void


---@class WBP_ChatBarrageView : WBP_ChatBarrage_C
---@field public WidgetRoot WBP_ChatBarrage_C
---@field public OL Overlay
---@field public HB HorizontalBox
---@field public WBP_Channel WBP_ChatResourceView
---@field public Text_BarrageName C7RichTextBlock
---@field public Text_BarrageContent C7RichTextBlock


---@class WBP_ComCurrencyView : WBP_ComCurrency_C
---@field public WidgetRoot WBP_ComCurrency_C
---@field public Icon C7Image
---@field public img_add Image
---@field public Text_Count C7TextBlock
---@field public Text_HasNum C7TextBlock
---@field public CostNum C7TextBlock
---@field public Text_FullPrice C7TextBlock
---@field public Button C7Button
---@field public Ani_Hover WidgetAnimation
---@field public Type E_ComCurrencyType
---@field public Lack boolean
---@field public PriceOff boolean
---@field public IsCenter boolean
---@field public ChargeType number
---@field public TipColor LinearColor
---@field public Event_UI_Style fun(self:self):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetType fun(self:self,Type:E_ComCurrencyType):void
---@field public SetPriceOff fun(self:self,PriceOff:boolean):void
---@field public SetCenter fun(self:self):void
---@field public SetCharge fun(self:self,ChargeType:number):void
---@field public SetOutline fun(self:self,TextTarget:TextBlock,Outline:FontOutlineSettings):void
---@field public SetColor fun(self:self,Lack:boolean):void
---@field public SetIsLack fun(self:self,IsLack:boolean):void


---@class WBP_ComCurrencyListView : WBP_ComCurrencyList_C
---@field public WidgetRoot WBP_ComCurrencyList_C
---@field public Currency HorizontalBox
---@field public CurrencyItem WBP_ComCurrencyView


---@class WBP_FloatingDamageView : WBP_FloatingDamage_C
---@field public WidgetRoot WBP_FloatingDamage_C
---@field public DamagePanel CanvasPanel
---@field public HB_Panel HorizontalBox
---@field public icon_element C7Image
---@field public text_num TextBlock
---@field public Broken CanvasPanel
---@field public icon_shield C7Image
---@field public text_immune C7TextBlock
---@field public Ani_Universal_Target_Attack WidgetAnimation
---@field public Ani_Universal_Self_Attack WidgetAnimation
---@field public Ani_Target_Crit WidgetAnimation
---@field public Ani_Self_Crit WidgetAnimation
---@field public Ani_Universal_Target_Element_Attack WidgetAnimation
---@field public Ani_Universal_Self_Element_Attack WidgetAnimation
---@field public Ani_Target_Element_Crit WidgetAnimation
---@field public Ani_Self_Element_Crit WidgetAnimation
---@field public Ani_Universal_Treat_Attack WidgetAnimation
---@field public Ani_Universal_Treat_Crit WidgetAnimation
---@field public Ani_Block_Shield WidgetAnimation
---@field public Ani_ShieldBroken WidgetAnimation
---@field public Ani_Self_Immune WidgetAnimation
---@field public Ani_Target_Immune WidgetAnimation
---@field public Type number
---@field public DMG_Type number
---@field public Is ELM boolean
---@field public Is Critical boolean
---@field public Immune boolean
---@field public Percent number
---@field public ELMStyleNum number
---@field public DamageNum number
---@field public DefaultOutline FontOutlineSettings
---@field public CriticalOutline FontOutlineSettings
---@field public SelfOutline FontOutlineSettings
---@field public CureOutline FontOutlineSettings
---@field public BlockOutline FontOutlineSettings
---@field public ScaleCurve CurveFloat
---@field public BlockColor01 Color
---@field public SelfColor01 Color
---@field public SelfColor02 Color
---@field public RevertColor01 Color
---@field public RevertColor02 Color
---@field public CriticalClolo01 Color
---@field public CriticalClolo02 Color
---@field public DefaultColor01 Color
---@field public DefaultColor02 Color
---@field public TakeCriticalClolo01 Color
---@field public TakeCriticalClolo02 Color
---@field public ELMStyle SlateBrush
---@field public CriticalIcon SlateBrush
---@field public Event_DMG_Style fun(self:self,Type:number,DMG_Type:number,IsELM:boolean,IsCritical:boolean):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetCriticalType fun(self:self,IsCritical:boolean,Type:number,ELM:boolean):void
---@field public SetBlock fun(self:self,IsBlock:boolean):void
---@field public SetShield fun(self:self,IsShield:boolean):void
---@field public SetText fun(self:self,Type:number,DMG_Type:number,IsCritical:boolean,IsELM:boolean):void
---@field public SetScale fun(self:self,Percent:number):void
---@field public SetColor fun(self:self,TargetText:TextBlock,Color1:Color,Color2:Color):void
---@field public SetFontOutLine fun(self:self,InFontInfo_OutlineSettings:FontOutlineSettings,InFontInfo_Size:number,TargetText:TextBlock):void
---@field public SetCriticalIcon fun(self:self,Index:boolean,Index1:number):void
---@field public SetCritical fun(self:self,Target:boolean):void
---@field public SetImmunity fun(self:self,Immunity:boolean):void
---@field public SetELM fun(self:self,ELM:boolean,Critical:boolean):void


---@class WBP_ComBtnView : WBP_ComBtn_C
---@field public WidgetRoot WBP_ComBtn_C
---@field public OutOverlay CanvasPanel
---@field public Text_Com C7TextBlock
---@field public Text_Time TextBlock
---@field public Image C7Image
---@field public Btn_Com C7Button
---@field public Ani_Press WidgetAnimation
---@field public Ani_Tower WidgetAnimation
---@field public Ani_Fadein WidgetAnimation
---@field public Ani_Fadein_Light WidgetAnimation
---@field public IsLight boolean
---@field public BtnType E_ComBtnType
---@field public IsDisabled boolean
---@field public IsPlayVx boolean
---@field public SetDisabled fun(self:self,bIsDisabled:boolean):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public Construct fun(self:self):void
---@field public OnVisibilityChangedEvent fun(self:self,InVisibility:ESlateVisibility):void
---@field public BndEvt__WBP_ComBtn_Btn_Com_lua_K2Node_ComponentBoundEvent_1_OnButtonPressedEvent__DelegateSignature fun(self:self):void
---@field public SetType fun(self:self):void
---@field public SetPlayVx fun(self:self,IsPlay:boolean):void


---@class WBP_ItemSmallView : WBP_ItemSmall_C
---@field public WidgetRoot WBP_ItemSmall_C
---@field public Bg_Rarity Image
---@field public icon Image
---@field public Num C7TextBlock
---@field public Button Button
---@field public Quality number
---@field public Is Score Up boolean
---@field public Has Num boolean
---@field public Size Btn X number
---@field public Size Btn Y number
---@field public IsGet boolean
---@field public Event_UI_Style fun(self:self,Quality:number,IsScoreUp:boolean,HasNum:boolean,SizeBtnX:number,SizeBtnY:number,IsGet:boolean):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetQuality fun(self:self,Quality:number):void
---@field public SetScoreUp fun(self:self,IsScoreUp:boolean):void
---@field public SetShowNum fun(self:self,HasNum:boolean):void
---@field public SetSize fun(self:self,Size Btn X:number,Size Btn Y :number):void
---@field public SetGet fun(self:self,IsGet:boolean):void


---@class WBP_KeyPromptView : WBP_KeyPrompt_C
---@field public WidgetRoot WBP_KeyPrompt_C
---@field public img_mouse C7Image
---@field public text_key TextBlock
---@field public key string
---@field public PromptStyle SlateBrush
---@field public Style number
---@field public Pressed SlateColor
---@field public Default SlateColor
---@field public OnRelease fun(self:self):void
---@field public OnPress fun(self:self):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetStyle fun(self:self,Style:number):void
---@field public SetActiveIndex fun(self:self,IsImage:boolean):void


---@class WBP_NPCBtnSelectView : WBP_NPCBtnSelect_C
---@field public WidgetRoot WBP_NPCBtnSelect_C
---@field public Btn_Select C7Button
---@field public O_BtnContent CanvasPanel
---@field public Img_Hover Image
---@field public hover1 C7Image
---@field public hover2 C7Image
---@field public CP_Icon CanvasPanel
---@field public Img_SelectBg Image
---@field public Img_Select Image
---@field public CP_Item CanvasPanel
---@field public WBP_Item WBP_ItemSmallView
---@field public Text_ItemNum TextBlock
---@field public Text_Select C7TextBlock
---@field public Img_Lock C7Image
---@field public WBP_KeyPrompt WBP_KeyPromptView
---@field public Ani_NpcHover_Pingpang WidgetAnimation
---@field public An_In WidgetAnimation
---@field public An_On WidgetAnimation
---@field public IconBrush SlateBrush
---@field public In Brush SlateBrush
---@field public In Brush_0 SlateBrush
---@field public In Brush_1 SlateBrush
---@field public In Color and Opacity SlateColor
---@field public In Color and Opacity_0 SlateColor
---@field public In Color and Opacity_1 SlateColor
---@field public State number
---@field public In Brush_2 SlateBrush
---@field public In Brush_3 SlateBrush
---@field public In Brush_4 SlateBrush
---@field public In Color and Opacity_2 LinearColor
---@field public In Color and Opacity_3 LinearColor
---@field public In Color and Opacity_4 LinearColor
---@field public In Brush_5 SlateBrush
---@field public In Color and Opacity_5 LinearColor
---@field public In Color and Opacity_6 LinearColor
---@field public 自定义事件 fun(self:self,Selection:number):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetOptionState fun(self:self,Selection:number):void


---@class WBP_ChatInputSpecialView : WBP_ChatInputSpecial_C
---@field public WidgetRoot WBP_ChatInputSpecial_C
---@field public Overlay Overlay
---@field public HistoryBtn C7Button
---@field public EditText C7EditableTextBox
---@field public Btn C7Button
---@field public SearchButton Overlay
---@field public Btn_2 C7Button
---@field public Img_Cancel_2 Image
---@field public Cancel1_Brush SlateBrush
---@field public Cancel2_Brush SlateBrush
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void


---@class WBP_ChatInputSmallView : WBP_ChatInputSmall_C
---@field public WidgetRoot WBP_ChatInputSmall_C
---@field public VoiceBtn C7Button
---@field public WBP_Input WBP_ChatInputSpecialView
---@field public EmotBtn C7Button
---@field public SendBtn WBP_ComBtnView


---@class WBP_ComBtnIconNewView : WBP_ComBtnIconNew_C
---@field public WidgetRoot WBP_ComBtnIconNew_C
---@field public OutCanvas CanvasPanel
---@field public Icon Image
---@field public Text_Name TextBlock
---@field public Big_Button_ClickArea C7Button
---@field public Anim_1 WidgetAnimation
---@field public Anim_2 WidgetAnimation
---@field public Anim_3 WidgetAnimation
---@field public Anim_4 WidgetAnimation
---@field public Ani_Press WidgetAnimation
---@field public Ani_Hover WidgetAnimation
---@field public Ani_Tower WidgetAnimation
---@field public Ani_Fadein WidgetAnimation
---@field public Btn Style ST_ComBtnIcon
---@field public Btn Name name
---@field public Press Sound SlateSound
---@field public Top number
---@field public Event_UI_Style fun(self:self,BtnName:string):void
---@field public Play Hint Anim fun(self:self):void
---@field public BndEvt__WBP_ComBtnIcon_Button_lua_K2Node_ComponentBoundEvent_0_OnButtonClickedEvent__DelegateSignature fun(self:self):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public Set Btn Style fun(self:self,Btn Style:ST_ComBtnIcon):void


---@class WBP_ComBtnCloseNewView : WBP_ComBtnCloseNew_C
---@field public WidgetRoot WBP_ComBtnCloseNew_C
---@field public Button C7Button
---@field public Ani_Fadein WidgetAnimation
---@field public Ani_Press WidgetAnimation
---@field public IconBrush SlateBrush
---@field public OnClicked MulticastDelegate
---@field public OnReleased MulticastDelegate
---@field public OnPressed MulticastDelegate
---@field public Construct fun(self:self):void
---@field public BndEvt__WBP_ComBtnClose_Button_lua_K2Node_ComponentBoundEvent_2_OnButtonReleasedEvent__DelegateSignature fun(self:self):void
---@field public BndEvt__WBP_ComBtnClose_Button_lua_K2Node_ComponentBoundEvent_1_OnButtonPressedEvent__DelegateSignature fun(self:self):void
---@field public BndEvt__WBP_ComBtnClose_Button_lua_K2Node_ComponentBoundEvent_0_OnButtonClickedEvent__DelegateSignature fun(self:self):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public Get_Icon_lua_Brush_0 fun(self:self):SlateBrush


---@class WBP_ChatSmallSView : WBP_ChatSmallS_C
---@field public WidgetRoot WBP_ChatSmallS_C
---@field public OpenWindowBtn C7Button
---@field public Text_Name C7TextBlock
---@field public VoiceBtn C7Button


---@class WBP_ChatSmallView : WBP_ChatSmall_C
---@field public WidgetRoot WBP_ChatSmall_C
---@field public MoveBox SizeBox
---@field public WindowBig CanvasPanel
---@field public WBP_ChatInput WBP_ChatInputSmallView
---@field public Text_Name C7TextBlock
---@field public ChatList ScrollBox
---@field public MaxBtn WBP_ComBtnIconNewView
---@field public MinBtn WBP_ComBtnIconNewView
---@field public CloseBtn WBP_ComBtnCloseNewView
---@field public WS_Btm CanvasPanel
---@field public Button_ToEnd C7Button
---@field public Text_NewMsg TextBlock
---@field public Button_ToEnd2 C7Button
---@field public WBP_ChatSmallS WBP_ChatSmallSView


---@class WBP_ComRedPointView : WBP_ComRedPoint_C
---@field public WidgetRoot WBP_ComRedPoint_C
---@field public Ani_in WidgetAnimation


---@class WBP_ItemBoxView : WBP_ItemBox_C
---@field public WidgetRoot WBP_ItemBox_C
---@field public OutOverlay Overlay
---@field public Bg_Equip Image
---@field public item_slot NamedSlot
---@field public img_mask Image
---@field public Image_select C7Image
---@field public Btn_ClickArea C7Button
---@field public btn_delete C7Button
---@field public Ani_Fadein WidgetAnimation
---@field public Ani_Loop WidgetAnimation
---@field public Type number
---@field public Is Selected boolean
---@field public Center SlateBrush
---@field public selected_vx fun(self:self,Object:Object,Field:FieldNotificationId):void
---@field public Event_UI_Style fun(self:self,Type:number,IsSelected:boolean):void
---@field public Construct fun(self:self):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetInverse fun(self:self,IsInverse:boolean):void
---@field public SetBoxType fun(self:self,Type:number):void
---@field public SetSelected fun(self:self,IsSelected:boolean):void


---@class WBP_ItemQuality4View : WBP_ItemQuality4_C
---@field public WidgetRoot WBP_ItemQuality4_C


---@class WBP_ItemQuality5View : WBP_ItemQuality5_C
---@field public WidgetRoot WBP_ItemQuality5_C


---@class WBP_ItemQuality6View : WBP_ItemQuality6_C
---@field public WidgetRoot WBP_ItemQuality6_C


---@class WBP_ItemNmlView : WBP_ItemNml_C
---@field public WidgetRoot WBP_ItemNml_C
---@field public Bg_Rarity Image
---@field public Icon Image
---@field public NS_HQ NamedSlot
---@field public TB_Text TextBlock
---@field public TB_Name C7RichTextBlock
---@field public BG_CD Image
---@field public text_center TextBlock
---@field public Status number
---@field public Quality number
---@field public Left Up number
---@field public Is Timeliness boolean
---@field public Is Advent boolean
---@field public IsLock boolean
---@field public Is New boolean
---@field public Is Score Up boolean
---@field public LTEmpty_Brush SlateBrush
---@field public LTEquip_Brush SlateBrush
---@field public LTTrade_Brush SlateBrush
---@field public Mask_Brush SlateBrush
---@field public TagBrushArray SlateBrush
---@field public TagTextOutline FontOutlineSettings
---@field public TagTextColorArray SlateColor
---@field public Event_UI_Style fun(self:self,Status:number,LeftUp:number,IsTimeliness:boolean,IsAdvent:boolean,IsScoreUp:boolean,IsNew:boolean,IsLock:boolean):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetLT fun(self:self,LeftUp:number):void
---@field public SetRT fun(self:self,IsTimeliness:boolean,IsAdvent:boolean,IsScoreUp:boolean,Status:number):void
---@field public SetStatus fun(self:self,Status:number):void
---@field public SetQuality fun(self:self,Quality:number):void
---@field public SetNew fun(self:self,IsNew:boolean):void
---@field public SetTag fun(self:self,TagState:number):void
---@field public SetRB fun(self:self,IsLock:boolean):void


---@class WBP_ItemRewardView : WBP_ItemReward_C
---@field public WidgetRoot WBP_ItemReward_C
---@field public Overlay Overlay
---@field public WBP_ItemNml WBP_ItemNmlView
---@field public New_Tip Image
---@field public Checked C7Image
---@field public Selected C7Image
---@field public Big_Button_ClickArea C7Button
---@field public Ani_NewTip WidgetAnimation
---@field public Ani_NewTip_Loop WidgetAnimation
---@field public Is Received boolean
---@field public Size number
---@field public Event_UI_Style fun(self:self,IsReceived:boolean):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetReceived fun(self:self,IsReceived:boolean):void
---@field public SetSelected fun(self:self,isSelected:boolean):void
---@field public SetSize fun(self:self,Size:number):void


---@class WBP_DungeonElementTitleView : WBP_DungeonElementTitle_C
---@field public WidgetRoot WBP_DungeonElementTitle_C
---@field public Title_Desc C7TextBlock
---@field public Title_Value C7TextBlock
---@field public IsColor number
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public Event_UI_Style fun(self:self,Index:number):void


---@class WBP_DungeonCardsView : WBP_DungeonCards_C
---@field public WidgetRoot WBP_DungeonCards_C
---@field public VB_Card VerticalBox
---@field public WBP_ComElementTitle WBP_DungeonElementTitleView
---@field public Text_Name C7TextBlock
---@field public IconHead C7Image
---@field public HB_Button HorizontalBox
---@field public WBP_Like WBP_ComBtnIconNewView
---@field public WBP_AddBtn WBP_ComBtnIconNewView


---@class WBP_ChatBgView : WBP_ChatBg_C
---@field public WidgetRoot WBP_ChatBg_C
---@field public WS WidgetSwitcher
---@field public Bg_brush SlateColor


---@class WBP_ChatBubble_EmoView : WBP_ChatBubble_Emo_C
---@field public WidgetRoot WBP_ChatBubble_Emo_C
---@field public Bg2 WBP_ChatBgView
---@field public Img_Emoji C7Image


---@class WBP_CharacterHeadView : WBP_CharacterHead_C
---@field public WidgetRoot WBP_CharacterHead_C
---@field public img_HeadBack Image
---@field public icon_head C7Image
---@field public icon_LT Image
---@field public img_LB Image
---@field public scale_LB ScaleBox
---@field public Text_level C7TextBlock
---@field public Btn_Head C7Button
---@field public Is TeamGroup boolean
---@field public Bg SlateBrush
---@field public Empty boolean
---@field public Is Fellow boolean
---@field public Tint SlateColor
---@field public Dead boolean
---@field public Icon Object
---@field public LT SlateBrush
---@field public Event_UI_Style fun(self:self,Team:boolean,Empty:boolean,IsFellow:boolean,Icon:C7Image,Tint:SlateColor,Dead:boolean):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetBg fun(self:self,Team:boolean):void
---@field public SetEmpty fun(self:self,Empty:boolean):void
---@field public SetHead fun(self:self,IsFellow:boolean,Tint:SlateColor):void
---@field public SetDead fun(self:self,Dead:boolean):void
---@field public SetLT fun(self:self,Member:number):void


---@class WBP_ChatBubble_TeamRecruitView : WBP_ChatBubble_TeamRecruit_C
---@field public WidgetRoot WBP_ChatBubble_TeamRecruit_C
---@field public TeamInvite CanvasPanel
---@field public TeamRecruitBg C7Image
---@field public Text_Goal C7TextBlock
---@field public Text_ZL TextBlock
---@field public Text_Describe C7RichTextBlock
---@field public HB_TeamMemberList HorizontalBox
---@field public TeamHead1 WBP_CharacterHeadView
---@field public TeamHead2 WBP_CharacterHeadView
---@field public TeamHead3 WBP_CharacterHeadView
---@field public TeamHead4 WBP_CharacterHeadView
---@field public TeamHead5 WBP_CharacterHeadView
---@field public WS_TeamAdd CanvasPanel
---@field public RecruitAddBtn WBP_ComBtnView
---@field public Text_HasInvited C7TextBlock


---@class WBP_ChatGroupTeamView : WBP_ChatGroupTeam_C
---@field public WidgetRoot WBP_ChatGroupTeam_C
---@field public Overlay_Attack CanvasPanel
---@field public Text_Num TextBlock
---@field public In Brush SlateBrush
---@field public In Brush_0 SlateBrush
---@field public In Brush_1 SlateBrush
---@field public In Brush_2 SlateBrush
---@field public In Brush_3 SlateBrush
---@field public In Brush_4 SlateBrush
---@field public Index number
---@field public 自定义事件 fun(self:self,Index:number):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetActiveIndex fun(self:self,Index:number):void


---@class WBP_ChatBubble_GroupRecruitView : WBP_ChatBubble_GroupRecruit_C
---@field public WidgetRoot WBP_ChatBubble_GroupRecruit_C
---@field public GroupInvite CanvasPanel
---@field public GroupRecruitBg C7Image
---@field public Text_GroupGoal C7TextBlock
---@field public Text_GroupZL TextBlock
---@field public Text_GroupDescribe C7RichTextBlock
---@field public WBP_GroupPos0 WBP_ChatGroupTeamView
---@field public WBP_GroupPos2 WBP_ChatGroupTeamView
---@field public WBP_GroupPos1 WBP_ChatGroupTeamView
---@field public WS_GroupAdd CanvasPanel
---@field public Text_HasInvited C7TextBlock
---@field public RecruitGroupAddBtn WBP_ComBtnView


---@class WBP_ChatBubble_GuildHelpView : WBP_ChatBubble_GuildHelp_C
---@field public WidgetRoot WBP_ChatBubble_GuildHelp_C
---@field public GuildHelp Overlay
---@field public GuildHelpLeft Overlay
---@field public WBP_ChatBg WBP_ChatBgView
---@field public TB_Content C7RichTextBlock
---@field public Big_Button_ClickAreaL C7Button
---@field public WBP_ItemNml WBP_ItemNmlView
---@field public Text_ItemName C7RichTextBlock
---@field public Text_ItemNum C7RichTextBlock
---@field public MaskL Overlay
---@field public Text_NameL TextBlock
---@field public WBP_GuildHelp WBP_ComBtnIconNewView
---@field public GuildHelpRight Overlay
---@field public WBP_ChatBg2 WBP_ChatBgView
---@field public TB_Content1 C7RichTextBlock
---@field public Big_Button_ClickAreaR C7Button
---@field public WBP_ItemNml1 WBP_ItemNmlView
---@field public Text_ItemName1 C7RichTextBlock
---@field public Text_ItemNum1 C7RichTextBlock
---@field public MaskR Overlay
---@field public Text_NameR TextBlock
---@field public WBP_GuildHelp2 WBP_ComBtnIconNewView


---@class WBP_HUDAshQTEBtn_2View : WBP_HUDAshQTEBtn_2_C
---@field public WidgetRoot WBP_HUDAshQTEBtn_2_C
---@field public VX_group_click CanvasPanel
---@field public Text_key C7TextBlock
---@field public Btn_ClickArea C7Button
---@field public Ani_Fadein WidgetAnimation
---@field public Ani_Loop WidgetAnimation
---@field public Ani_Click WidgetAnimation
---@field public Ani_Fadeout WidgetAnimation


---@class WBP_HUDAshQTEBtnView : WBP_HUDAshQTEBtn_C
---@field public WidgetRoot WBP_HUDAshQTEBtn_C
---@field public SizeBox SizeBox
---@field public Text_key C7TextBlock
---@field public Btn_ClickArea C7Button
---@field public play WidgetAnimation
---@field public loop WidgetAnimation
---@field public clicked WidgetAnimation
---@field public unclicked WidgetAnimation
---@field public CountDown number
---@field public PreConstructPCStyle fun(self:self):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void


---@class WBP_SystemTipsTitleView : WBP_SystemTipsTitle_C
---@field public WidgetRoot WBP_SystemTipsTitle_C
---@field public Text_Title C7TextBlock


---@class WBP_SealedStarListView : WBP_SealedStarList_C
---@field public WidgetRoot WBP_SealedStarList_C
---@field public Star SlateBrush
---@field public Level number
---@field public StarSize Vector2D
---@field public SlotPadding Vector2D
---@field public Event_UI_Style fun(self:self,StarSize:Vector2D,SlotPadding:Vector2D):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public SetProgress fun(self:self,StarTarget:Image,Index:number,In Brush Image Size:DeprecateSlateVector2D):void
---@field public SetStar fun(self:self,Item Image Size:DeprecateSlateVector2D,InPadding:Vector2D):Vector2D,Vector2D
---@field public SetLevel fun(self:self,Level:number):void


---@class WBP_ComBtnTransparentView : WBP_ComBtnTransparent_C
---@field public WidgetRoot WBP_ComBtnTransparent_C
---@field public OutOverlay CanvasPanel
---@field public Btn_Com C7Button
---@field public IsLight boolean
---@field public BtnType E_ComBtnType
---@field public IsDisabled boolean
---@field public IsPlayVx boolean


---@class WBP_LibView : WBP_Lib_C
---@field public WidgetRoot WBP_Lib_C
---@field public Title CanvasPanel
---@field public Text_Name TextBlock
---@field public TitleItemList VerticalBox
---@field public Img_prop Image
---@field public Equipment CanvasPanel
---@field public RTB_Key C7RichTextBlock
---@field public RTB_Val C7RichTextBlock
---@field public RTB_ValMax C7RichTextBlock
---@field public WidgetSwitcher CanvasPanel
---@field public Equipment_IconAttribute CanvasPanel
---@field public OL_Icon Overlay
---@field public Img_Icon C7Image
---@field public RT_TKey C7RichTextBlock
---@field public RT_TVal C7RichTextBlock
---@field public RT_InfoKey C7RichTextBlock
---@field public RT_InfoVal C7RichTextBlock
---@field public Line CanvasPanel
---@field public Spacer1 Spacer
---@field public Spacer2 Spacer
---@field public LineItemList VerticalBox
---@field public Text CanvasPanel
---@field public Text_TipsContent C7RichTextBlock
---@field public Text_MultiColumn CanvasPanel
---@field public RT_Key C7RichTextBlock
---@field public RT_Val C7RichTextBlock
---@field public Sealed WBP_SealedBuffView
---@field public TreasureReward WBP_ItemDetailListView
---@field public BtnNormM WBP_ItemTipsBtnView
---@field public EquipEnhance CanvasPanel
---@field public TB_Time TextBlock
---@field public WBP_Star1 WBP_ItemTipsStarView
---@field public WBP_Star2 WBP_ItemTipsStarView
---@field public WBP_Star3 WBP_ItemTipsStarView
---@field public WBP_Star4 WBP_ItemTipsStarView
---@field public WBP_Star5 WBP_ItemTipsStarView
---@field public WBP_Star6 WBP_ItemTipsStarView
---@field public WBP_Star7 WBP_ItemTipsStarView
---@field public WBP_Star8 WBP_ItemTipsStarView
---@field public WBP_Star9 WBP_ItemTipsStarView
---@field public WBP_Star10 WBP_ItemTipsStarView
---@field public Text_Attr TextBlock
---@field public Text_EnhanceVal TextBlock
---@field public HorizontalBox HorizontalBox
---@field public Text_lv TextBlock
---@field public ChatBarrage CanvasPanel
---@field public WBP_ChatBarrage WBP_ChatBarrageView
---@field public Currency HorizontalBox
---@field public CurrencyItem WBP_ComCurrencyView
---@field public CurrencyList WBP_ComCurrencyListView
---@field public FloatingDamage WBP_FloatingDamageView
---@field public ForwardBtn WBP_ComBtnView
---@field public NPCBtnSelect WBP_NPCBtnSelectView
---@field public P_ChatSmall WBP_ChatSmallView
---@field public ComRedPoint ScaleBox
---@field public RedPointWidget WBP_ComRedPointView
---@field public WBP_ItemBox WBP_ItemBoxView
---@field public WBP_ItemQuality4 WBP_ItemQuality4View
---@field public WBP_ItemQuality5 WBP_ItemQuality5View
---@field public WBP_ItemQuality6 WBP_ItemQuality6View
---@field public ItemNml WBP_ItemNmlView
---@field public WBP_ItemReward WBP_ItemRewardView
---@field public DungeonPlayerDisplayItem WBP_DungeonCardsView
---@field public ChatExpression WBP_ChatBubble_EmoView
---@field public TeamInvite WBP_ChatBubble_TeamRecruitView
---@field public GroupInvite WBP_ChatBubble_GroupRecruitView
---@field public GuildHelp WBP_ChatBubble_GuildHelpView
---@field public AshButton2 WBP_HUDAshQTEBtn_2View
---@field public AshButton WBP_HUDAshQTEBtnView
---@field public SubTitle CanvasPanel
---@field public WBP_SystemTipsTitle WBP_SystemTipsTitleView
---@field public TitleItemsList VerticalBox
---@field public SealedBreak CanvasPanel
---@field public WBP_SealedStarList WBP_SealedStarListView
---@field public WBP_ComBtnTransparent WBP_ComBtnTransparentView

---@class P_Lib_AutomationTestView : WBP_LibView
---@field public controller P_Lib_AutomationTest
local P_Lib_AutomationTestView = DefineClass("P_Lib_AutomationTestView", UIView)

function P_Lib_AutomationTestView:OnCreate()
    local controller = self.controller
    controller:SetAutoBind(false)

---Auto Generated by UMGExtensions
	self.AnimationInfo = {AnimFadeIn = {{self.ForwardBtn_lua.WidgetRoot, 3.066683},{self.WBP_ItemBox_lua.WidgetRoot, 0.15},{self.AshButton2_lua.WidgetRoot, 0.333333},},AnimFadeOut = {{self.AshButton2_lua.WidgetRoot, 0.766667},}}
end

function P_Lib_AutomationTestView:OnDestroy()
end

return P_Lib_AutomationTestView
