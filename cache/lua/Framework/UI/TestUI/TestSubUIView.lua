---@class TestRankItemView : TestRankItem_C
---@field public WidgetRoot TestRankItem_C
---@field public icon C7Image
---@field public num TextBlock
---@field public Btn_ClickArea Button
---@field public GoBtn Button


---@class WBP_ComTreeListView : WBP_ComTreeList_C
---@field public WidgetRoot WBP_ComTreeList_C
---@field public TreeList ScrollBox
---@field public DiffPanel CanvasPanel
---@field public DiffPoint Border
---@field public Structure TreeListCell
---@field public SelectionMode number
---@field public IndexList number
---@field public LayoutList ListLayout
---@field public SpaceUpList number
---@field public SpaceBottomList number
---@field public SpaceLeftList number
---@field public SpaceRightList number
---@field public AlignmentList ListAligment
---@field public indexToTopPos number
---@field public indexToBottomPos number
---@field public indexToXPos number
---@field public oldBottomIndex number
---@field public oldTopIndex number
---@field public allLength number
---@field public PaddingList Margin
---@field public ListPadding Margin
---@field public MaxValue number
---@field public RetainerBox RetainerBox
---@field public OnUserScrolled fun(self:self,CurrentOffset:number):void
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void
---@field public CreatListCell fun(self:self,widget:Widget,posX:number,posY:number,libWidget:string,sizeX:number,sizeY:number):void
---@field public SetAllSlot fun(self:self,Src:Widget,Tag:Widget,Position:Vector2D):void
---@field public InsertSubIndex fun(self:self,floor:number):void
---@field public GetArrayWidget fun(self:self,index:number):Widget,string,number,number,number,Widget,string,number,number,number
---@field public GetListSize fun(self:self):number,number
---@field public GetWidgetSize fun(self:self,Widget:Widget):number,number
---@field public SetSlot fun(self:self,Pos:Vector2D,SrcWidget:Widget,TarWidget:Widget,LibSize:Vector2D):void
---@field public CalculatePos fun(self:self):void
---@field public RebulidList fun(self:self,CurrentOffset:number):void
---@field public Cal_OnGirdNextGrid fun(self:self,SizeX:number,SizeY:number,SpaceUp:number,SpaceBottom:number,SpaceLeft:number,SpaceRight:number,OldPosX:number,oldPosY:number,OldGridSpace:number,TotalLenght:number,Alignment:ListAligment,Padding:Margin,bIsNewFloor:boolean):number,number,number,number,number,number,number,number
---@field public Cal_OnGirdNextList fun(self:self,SizeX:number,SizeY:number,SpaceUp:number,SpaceBottom:number,SpaceLeft:number,SpaceRight:number,OldPosX:number,OldPosY:number,OldGridSpace:number,TotalLenght:number,Alignment:ListAligment,Padding:Margin,bIsNewFloor:boolean):number,number,number,number
---@field public Cal_OnListNextGrid fun(self:self,SizeX:number,SizeY:number,SpaceUp:number,SpaceBottom:number,SpaceLeft:number,SpaceRight:number,OldPosX:number,OldPosY:number,OldGridSpace:number,TotalLenght:number,Alignment:ListAligment,Padding:Margin,bIsNewFloor:boolean):number,number,number,number
---@field public Cal_OnListNextList fun(self:self,SizeX:number,SizeY:number,SpaceUp:number,SpaceBottom:number,SpaceLeft:number,SpaceRight:number,OldPosX:number,OldPosY:number,OldGridSpace:number,TotalLenght:number,Alignment:ListAligment,Padding:Margin,bIsNewFloor:boolean):number,number,number,number


---@class TestIrregularListView : TestIrregularList_C
---@field public WidgetRoot TestIrregularList_C
---@field public IrregularList KGIrregularListView
---@field public PreConstruct fun(self:self,IsDesignTime:boolean):void


---@class TestSubUIView : TestSubUI_C
---@field public WidgetRoot TestSubUI_C
---@field public TestRankItem TestRankItemView
---@field public DiffList ScrollBox
---@field public icon C7Image
---@field public num TextBlock
---@field public GoBtn Button
---@field public formcell CanvasPanel
---@field public formitem CanvasPanel
---@field public Equip CanvasPanel
---@field public Equip2 CanvasPanel
---@field public RankList ListViewEx
---@field public icon1 C7Image
---@field public num1 TextBlock
---@field public GoBtn1 Button
---@field public Big_Button_ClickArea Button
---@field public BagTreeList WBP_ComTreeListView
---@field public TestIrregularList TestIrregularListView

---@class testsubuiView : TestSubUIView
---@field public controller testsubui
local TestSubUIView = DefineClass("TestSubUIView", UIView)

function TestSubUIView:OnCreate()
    local controller = self.controller
    controller:SetAutoBind(false)
end

function TestSubUIView:OnDestroy()
    --local controller = self.controller
end

return TestSubUIView
