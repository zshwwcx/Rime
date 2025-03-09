---@class WBP_ComListView : WBP_ComList_C
---@field public WidgetRoot WBP_ComList_C
---@field public List ScrollBox
---@field public DiffPanel CanvasPanel
---@field public DiffPoint Border
---@field public bIsTileView boolean
---@field public PreviewCount number
---@field public LibWidget ListLib
---@field public ScrollWidget Widget
---@field public Orientation EOrientation
---@field public ScrollBarVisibility ESlateVisibility
---@field public SelectionMode number
---@field public Space ListSpace
---@field public Alignment ComListAligment
---@field public bIsCenterContent boolean
---@field public tempIndex number
---@field public oldPosX number
---@field public oldPosY number
---@field public tempPosX number
---@field public tempPosY number
---@field public widgetX number
---@field public widgetY number
---@field public spaceUp number
---@field public spaceBottom number
---@field public spaceLeft number
---@field public spaceRight number
---@field public bSizeToContent boolean
---@field public ListPadding Margin
---@field public MaxValue number
---@field public RetainerBox RetainerBox
---@field public OnSetItem MulticastDelegate
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public CalculatePos fun(self:self):void
---@field public CreatListCell fun(self:self,widget:Widget,posX:number,posY:number):void
---@field public SetAllSlot fun(self:self,Src:Widget,Tag:Widget,Position:Vector2D):void
---@field public GetListSize fun(self:self):number,number,number,number
---@field public GetWidgetSize fun(self:self,Widget:Widget):number,number,number,number,number,number
---@field public VerticalTileChange fun(self:self):void
---@field public VerticalTile fun(self:self):void
---@field public VerticalList fun(self:self):void
---@field public HorizontalTileChange fun(self:self):void
---@field public HorizontalTile fun(self:self):void
---@field public HorizontalList fun(self:self):void
---@field public VerticalTileAuto fun(self:self):void
---@field public SetSlot fun(self:self,Pos:Vector2D,SrcWidget:Widget,TarWidfget:Widget):void


---@class BagItemView : BagItem_C
---@field public WidgetRoot BagItem_C
---@field public bg Image
---@field public selected Image
---@field public icon Image
---@field public num TextBlock
---@field public Big_Button_ClickArea Button
---@field public RequestBtn Button
---@field public anim1 WidgetAnimation
---@field public anim2 WidgetAnimation
---@field public anim3 WidgetAnimation


---@class P_GMOverlayInnerView : P_GMOverlayInner_C
---@field public WidgetRoot P_GMOverlayInner_C
---@field public Overlay Overlay
---@field public Text_Name TextBlock
---@field public Btn_Debug C7Button


---@class P_FeedbackOverlayInnerView : P_FeedbackOverlayInner_C
---@field public WidgetRoot P_FeedbackOverlayInner_C
---@field public Overlay Overlay
---@field public Text_Name TextBlock
---@field public Btn_Debug C7Button


---@class WBP_GMOverlayView : WBP_GMOverlay_C
---@field public WidgetRoot WBP_GMOverlay_C
---@field public SB_PanelRoot SizeBox
---@field public GM P_GMOverlayInnerView
---@field public Feedback P_FeedbackOverlayInnerView
---@field public TargetVisual SizeBox
---@field public CtrlTDispatcher MulticastDelegate
---@field public InpActEvt_Ctrl_G_K2Node_InputKeyEvent_0 fun(self:self,Key:Key):void


---@class WBP_TestUIView : WBP_TestUI_C
---@field public WidgetRoot WBP_TestUI_C
---@field public scroll ScrollBox
---@field public RankList WBP_ComListView
---@field public icon C7Image
---@field public num TextBlock
---@field public Btn_ClickArea Button
---@field public GoBtn Button
---@field public BagList WBP_ComListView
---@field public btn_close Button
---@field public Button1 Button
---@field public Button2 Button
---@field public Button3 Button
---@field public SB_PanelRoot SizeBox
---@field public Btn_Debug Button
---@field public BagItem1 BagItemView
---@field public BagItem2 BagItemView
---@field public GroupItems VerticalBox
---@field public GroupItems2 VerticalBox
---@field public icon2 C7Image
---@field public num2 TextBlock
---@field public GoBtn2 Button
---@field public CheckBox CheckBox
---@field public TestSubUI NamedSlot
---@field public Money NamedSlot
---@field public auto_time TextBlock
---@field public once_timer TextBlock
---@field public onminute TextBlock
---@field public hp ProgressBar
---@field public hp2 ProgressBar
---@field public flyitemto CanvasPanel
---@field public flyitem BagItemView
---@field public flyitem2 C7Image
---@field public WBP_GMOverlay WBP_GMOverlayView
---@field public Effect CanvasPanel
---@field public CyclingList C7CyclingList
---@field public inanim WidgetAnimation

---@class testuiView : WBP_TestUIView
---@field public controller testui
local TestUIView = DefineClass("TestUIView", UIView)

function TestUIView:OnCreate()
    local controller = self.controller
    controller:SetAutoBind(false)
    controller:AddUIListener(EUIEventTypes.CLICK, self.btn_close, "OnClick_btn_close")
    controller:AddUIListener(EUIEventTypes.CLICK, self.Button1, "OnClick_Button1")
    controller:AddUIListener(EUIEventTypes.CLICK, self.Button2, "OnClick_Button2")
    controller:AddUIListener(EUIEventTypes.CLICK, self.Button3, "OnClick_Button3")

    local Overlay = self.WBP_GMOverlay.GM
    controller:AddUIListener(EUIEventTypes.MouseButtonDown, Overlay, "OnMouseBtnDown")
    controller:AddUIListener(EUIEventTypes.DragDetected, Overlay, "OnDragDetected")
    controller:AddUIListener(EUIEventTypes.DragCancelled, Overlay, "OnDragCancelled")
    controller:AddUIListener(EUIEventTypes.MouseButtonUp, Overlay, "OnReleased")
end

function TestUIView:OnDestroy()
end

return TestUIView
