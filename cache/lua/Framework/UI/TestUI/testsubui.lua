---@class testsubui : UIController
---@field public View TestSubUIView
local TestSubUI = DefineClass("TestSubUI", UIController)

local RankItem = require("Framework.UI.TestUI.TestRankItem")
local BagItem = require("Framework.UI.TestUI.testbagitem")
local IrregularBagItem = require("Framework.UI.TestUI.TestIrregularBagItem")
local WidgetEmptyComponent = kg_require "Framework.UI.WidgetEmptyComponent"


local LibWidgetConfig = kg_require("Framework.UI.LibWidgetConfig")
TestSubUI.PreloadLibMap = {
    BtnNormM = LibWidgetConfig.BtnNormM,
    Title = LibWidgetConfig.Title,
    BagItem = LibWidgetConfig.BagItem
}

function TestSubUI:OnCreate()
    -- 创建n*1的滚动列表，里面元素不一样
    self.diffList = BaseList.CreateList(self, BaseList.Kind.DiffList, "DiffList", {BagItem})
    self.diffList:AddUIListener(EUIEventTypes.CLICK, 2, "GoBtn", "OnClick_DiffList_rankItem_1_GoBtn")
    self.diffDatas = {} --difflist 示例数据
    for i = 1, 3 do
        table.insert(self.diffDatas, {1, i})
    end
    for i = 1, 3 do
        table.insert(self.diffDatas, {2, i})
    end
    -- 刷新列表数据
    self.diffList:SetData(self.diffDatas, 6)
    self.selectedIndex = 4 --difflist示例:选中index
    -- 设置选中列表第几条数据
    self.diffList:Sel(self.selectedIndex)

    --name, container, cell, ...)
    local title = self:FormComponent("Title", self.View.formcell, WidgetEmptyComponent)
    title.View.Text_Name:SetText("111111111111111111")

    -- local item = self:FormComponent("BagItem", self.View.formitem, BagItem)
    -- item:Refresh(10001, false)

    self:FormComponent('BtnNormM', self.View.Equip, WidgetEmptyComponent, Game.BagSystem.BtnType.EQUIP)
    self:FormComponent('BtnNormM', self.View.Equip2, WidgetEmptyComponent, Game.BagSystem.BtnType.DECOMPOSE)

    --region TreeList例子
    self.treeList = BaseList.CreateList(self, BaseList.Kind.TreeList, "BagTreeList",{{RankItem},{BagItem}})
    self.treeData = {  --treeList示例数据
        {Kind=1,Children={11,12,13}},
        {Kind=1,Children={21,22}},
        {Kind=1,Children={31,32,33}},
        {Kind=1,Children={41,42}},
        {Kind=1,Children={51,52,53}},
    }
    self.treeList:SetData(self.treeData,false,nil)
    --endregion

    --region IrregularList例子
    self.irregularList = BaseList.CreateList(self, BaseList.Kind.IrregularList, self.View.TestIrregularList.IrregularList, IrregularBagItem)
    self.irregularData = {} --IrregularList例子示例数据
    for i = 1,10 do
        table.insert(self.irregularData, i)
    end
    --endregion
end

function TestSubUI:OnRefresh_BtnNormM(widget, BtnType)
    local BtnName = Game.TableData.GetBtnTypeDataRow(BtnType)
    widget.View.Text_Com:SetText(BtnName.BtnName)
end

function TestSubUI:OnClick_BtnNormM_Button(BtnType)
    local BtnName = Game.TableData.GetBtnTypeDataRow(BtnType)
    Log.Warning("OnClick_BtnNormM ", BtnName.BtnName)
end

-- 滚动列表里子元素的点击事件
function TestSubUI:OnClick_DiffList_rankItem_1_GoBtn(index, sbindex)
    local data = self.diffDatas[sbindex]
    Log.Debug("OnClick_DiffList_rankItem_1_GoBtn ", data[2])
end

--刷新滚动列表
function TestSubUI:OnRefresh_DiffList(r, index, selected)
    local data = self.diffDatas[index]
    local kind = data[1]
    if kind == 1 then
        --刷新格子数据
        r:Refresh(data[2], selected)
    elseif kind == 2 then
        local icon = r.icon
        local num = r.num
        if selected then
			self:SetImage(icon,"/Game/Arts/UI_2/Resource/Common_2/Atlas/Sprite01/UI_Com_Bg_PlayBack_Sprite.UI_Com_Bg_PlayBack_Sprite")
        else
			self:SetImage(icon, "/Game/Arts/UI_2/Resource/Common_2/Atlas/Sprite01/UI_Com_Bg_Write_Sprite.UI_Com_Bg_Write_Sprite")
        end
        num:SetText(data[2])
    end
end

function TestSubUI:ChangeData(num, num2)
    table.clear(self.diffDatas)
    if num > num2 then
        for i = 1, num do
            table.insert(self.diffDatas, {1, i})
        end
    for i = 1, num2 do
            table.insert(self.diffDatas, {2, i})
        end
    else
        for i = 1, num do
            table.insert(self.diffDatas, {2, i})
        end
        for i = 1, num2 do
            table.insert(self.diffDatas, {1, i})
        end
    end    
    -- 刷新列表数据
    self.diffList:SetData(self.diffDatas)
end

function TestSubUI:OnRefresh(arg1, arg2)
    self.irregularList:Refresh(self.irregularData)
end

function TestSubUI:OnClose()
    UIBase.OnClose(self)
end