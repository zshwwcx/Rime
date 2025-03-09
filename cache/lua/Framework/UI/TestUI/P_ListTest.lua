local P_ListTest = DefineClass("P_ListTest", UIController)
local ESlateVisibility = import("ESlateVisibility")
local testcomp = kg_require("Framework.UI.TestUI.ListTestComponent")
local testTreeComp = kg_require("Framework.UI.TestUI.TreeListTestComponent")
function P_ListTest:OnCreate()
    self.verList = BaseList.CreateList(self, BaseList.Kind.ComList, self.View.VerList)
    self.hotList = BaseList.CreateList(self, BaseList.Kind.ComList, self.View.HorList)
    self.tileListV = BaseList.CreateList(self, BaseList.Kind.ComList, self.View.TileListV)
    self.tileListH = BaseList.CreateList(self, BaseList.Kind.ComList, self.View.TileListH)
    self.pageListV = BaseList.CreateList(self, BaseList.Kind.PageList, self.View.PageListV)
    self.testList = BaseList.CreateList(self, BaseList.Kind.ComList, self.View.WBP_SelectList.SB_NPCInteractItems)
    self.treeList = BaseList.CreateList(self, BaseList.Kind.TreeList, self.View.TreeList, {{testTreeComp},{testTreeComp},{testTreeComp}})
    self:AddUIListener(EUIEventTypes.CLICK, self.View.Close, self.Close)
    self:AddUIListener(EUIEventTypes.CLICK, self.View.Refresh, self.RefreshListNum)
    self:AddUIListener(EUIEventTypes.CLICK, self.View.Switch, self.SwitchList)
    self:AddUIListener(EUIEventTypes.CLICK, self.View.ReSize, self.RefreshListSize)
    self:AddUIListener(EUIEventTypes.CLICK, self.View.Page, self.Paging)
    self:AddUIListener(EUIEventTypes.CLICK, self.View.Scroll, self.Scrolling)
    self:AddUIListener(EUIEventTypes.CLICK, self.View.Remove, self.RemoveMuti)
    self:AddUIListener(EUIEventTypes.CLICK, self.View.Add, self.RemoveTest)
    self:AddUIListener(EUIEventTypes.CLICK, self.View.TreeListSwitch, self.SwitchTreeList)
    self.num = 10
    self.curList = self.verList
    self.listArray = {self.verList, self.hotList, self.tileListV, self.tileListH, self.pageListV,self.testList,}
    self.treeListArray = {self.treeList}
    self.listIndex = 1
    self.ListSize = nil
    self.MinSize = 0
    self.MaxSize = 0
end

function P_ListTest:OnRefresh()
    for i = 1, #self.listArray, 1 do 
        self.listArray[i].View.WidgetRoot:SetVisibility(ESlateVisibility.Collapsed)
    end
    self.curList.View.WidgetRoot:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    self.curList:SetData(self.num)
    --self.ListSize = self.curList.View.WidgetRoot.Slot:GetSize()
    self.MinSize = self.curList.View.MinSize
    self.MaxSize = self.curList.View.MaxSize
end

function P_ListTest:OnRefresh_PageListV(widget, index, selected)
    widget.Head.Text_level:SetText(index)
end

function P_ListTest:OnRefresh_VerList(widget, index, selected)
    --widget.View.Head.Text_level:SetText(index)
end

function P_ListTest:Close()
    self:CloseSelf()
end

function P_ListTest:Paging()
    local pagenum = self.View.PageNum:GetText()
    if pagenum then
        pagenum = tonumber(num)
        if pagenum then
            pagenum = math.floor(pagenum)
            self.curList:ScrollPage(pagenum)
        end
    end
end

function P_ListTest:Scrolling()
    local cellindex = self.View.CellIndex:GetText()
    if cellindex then
        cellindex = tonumber(cellindex)
        if cellindex then
            cellindex = math.floor(cellindex)
            self.curList:ScrollToIndex(cellindex)
        end
    end
end

function P_ListTest:RefreshListNum()
    local num = self.View.ListNum:GetText()
    if num then
        num = tonumber(num)
        if num then
            num = math.floor(num)
            self.num = num
            
        end
    end
    self.curList:SetData(self.num)
end

function P_ListTest:SwitchList()
    self.listIndex = self.listIndex + 1
    if self.listIndex > #self.listArray then
        self.listIndex = 1
    end
    self.curList.View.WidgetRoot:SetVisibility(ESlateVisibility.Collapsed)
    self.curList = self.listArray[self.listIndex]
    self.curList.View.WidgetRoot:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    --self.ListSize = self.curList.View.WidgetRoot.Slot:GetSize()
    self.MinSize = self.curList.View.MinSize
    self.MaxSize = self.curList.View.MaxSize
    self:RefreshListSize()
    self:RefreshListNum()
end

function P_ListTest:RefreshListSize()
    local sizex = self.View.SizeX:GetText()
    local sizey = self.View.SizeX:GetText()
    local minSize = self.View.MinSize:GetText()
    local maxSize = self.View.MaxSize:GetText()
    if not self.ListSize then
        self.ListSize = FVector2D()
    end
    if sizex then
        sizex = tonumber(sizex)
        if sizex then
            self.ListSize.X = sizex  
        end
    end
    if sizey then
        sizey = tonumber(sizey)
        if sizey then
            self.ListSize.Y = sizey  
        end
    end
    if minSize then
        minSize = tonumber(minSize)
        if minSize then
            self.MinSize = minSize  
        end
    end
    if maxSize then
        maxSize = tonumber(maxSize)
        if maxSize then
            self.MaxSize = maxSize  
        end
    end
    self.curList.View.MinSize = self.MinSize
    self.curList.View.MaxSize = self.MaxSize
    --self.curList.View.WidgetRoot.Slot:SetSize(self.ListSize)
    self.curList:SetData(self.num)
end

function P_ListTest:Remove()
    local idx = self.View.RemoveIdx:GetText()
    if idx then
        idx = tonumber(idx)
    end
    self.curList:RemoveOneItem(idx,nil,"Ani_Remove")
end

function P_ListTest:Add()
    local idx = self.View.AddIdx:GetText()
    if idx then
        idx = tonumber(idx)
    end
    self.curList:AddOneItem(idx,nil, "Ani_Add")
end

function P_ListTest:RemoveMuti()
    --self.curList:RemoveItems({2,3,4},"Ani_Remove")
    self.curList:RemoveOneItem(2, nil,"Ani_Remove")
    self.curList:RemoveOneItem(2, nil,"Ani_Remove")
    --self.curList:RemoveOneItem(2, nil,"Ani_Remove")
end

function P_ListTest:AddMuti()
    --self.curList:RemoveItems({2,3,4},"Ani_Remove")
    self.curList:AddOneItem(2, nil,"Ani_Add")
    --self.curList:AddOneItem(3,"Ani_Add")
    self.curList:AddOneItem(2, nil, "Ani_Add")
end

function P_ListTest:RemoveTest()
--     self.curList:AddOneItem(2, nil,"Ani_Add")
--     self.curList:RemoveOneItem(2, nil,"Ani_Remove")
--     self.curList:RemoveOneItem(2, nil,"Ani_Remove")
--     self.curList:RemoveOneItem(2, nil,"Ani_Remove")
--     self.curList:AddOneItem(3, nil, "Ani_Add")
--    self.curList:RemoveOneItem(2, nil,"Ani_Remove")

    self.curList:AddOneItem(2, nil, "Ani_Add")
    self.curList:RemoveOneItem(2, nil)
    self.curList:RemoveOneItem(2, nil,"Ani_Remove")
    self.curList:RemoveOneItem(2)
    self.curList:AddOneItem(3)
    self.curList:RemoveOneItem(2, nil)
    
end

function P_ListTest:SwitchTreeList()
    for i = 1, #self.listArray, 1 do
        self.listArray[i].View.WidgetRoot:SetVisibility(ESlateVisibility.Collapsed)
    end
    self.testList.View.WidgetRoot:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    local data = {}
    data = {
        [1] = {Kind = 1, Children = {
            [1] = {
                Kind = 1, 
                Children = {
                    [1] = {
                        Kind = 1
                    },
                    [2] = {
                        Kind = 1
                    },
                }
            },
            [2] = {
                Kind = 1, 
                -- Children = {
                --     [1] = {
                --         Kind = 1
                --     },
                --     [2] = {
                --         Kind = 1
                --     },
                -- }
            }
        }},
        [2] = {Kind = 1, Children = {
            [1] = {
                Kind = 1
            },
            [2] = {
                Kind = 1
            },
            [3] = {
                Kind = 1
            },
        }},
        [3] = {Kind = 1, Children = {
            [1] = {
                Kind = 1
            },
            [2] = {
                Kind = 1
            },
        }}
        -- [1] = {Kind = 1},
        -- [2] = {Kind = 1},
        -- [3] = {Kind = 1},
        -- [4] = {Kind = 1},
        -- [5] = {Kind = 1},
        -- [6] = {Kind = 1},
    }
    self.treeList:SetData(data,false)
end

function P_ListTest:TestTreeListAnimaiont()
    self.treeList:StaggeredAnimation()
end
return P_ListTest

