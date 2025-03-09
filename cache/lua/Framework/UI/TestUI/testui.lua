---@class testui : UIController
---@field public View WBP_TestUIView
local TestUI = DefineClass("TestUI", UIController)
local BagItem = require("Framework.UI.TestUI.testbagitem")
local P_CyclingList = require("Framework.UI.CyclingList")
local EUMGSequencePlayMode = import("EUMGSequencePlayMode")

function TestUI:OnCreate()
    local c = self.View

    -- 创建n*1的滚动列表
    self.list = BaseList.CreateList(self, BaseList.Kind.ComList, "RankList") --通用列表测试UI
    self.list:AddUIListener(EUIEventTypes.CLICK, "GoBtn", "OnClick_RankList_GoBtn")

    self.rankDatas = {}  --滚动列表测试数据
    for i = 1, 10 do
        table.insert(self.rankDatas, i)
    end
    -- 刷新列表数据
    self.list:SetData(10)
    self.selectedIndex1 = 2     --通用列表选中的item index
    -- 设置选中列表第几条数据
    self.list:Sel(self.selectedIndex1)

    -- self.diffList = BaseList.CreateList(self, BaseList.Kind.DiffList, "scroll")
    -- self.diffDatas = {}
    -- for i = 1, 1 do
    --     table.insert(self.diffDatas, {1, i})
    -- end
    -- -- 刷新列表数据
    -- self.diffList:SetData(self.diffDatas, 1)
    -- self.selectedIndex = 1
    -- -- 设置选中列表第几条数据
    -- self.diffList:Sel(self.selectedIndex)

    self.itemDatas = {}     --tileList测试数据
    for i = 1, 100 do
        table.insert(self.itemDatas, 100 + i)
    end

    -- 创建n*m的滚动列表
    self.tileList = BaseList.CreateList(self, BaseList.Kind.ComList, "BagList", BagItem) --tileList测试UI
    -- 刷新列表数据
    self.tileList:SetData(#self.itemDatas)
    self.selectedIndex2 = 1         --tileList 选中的item index
    -- 设置选中列表第几条数据
    self.tileList:Sel(self.selectedIndex2)

    -- n个一样的格子,在界面里提前放好的
    self.items = {} -- luacheck: ignore
    self.itemIds = {}  -- luacheck: ignore
    for i = 1, 2 do
        local item = c["BagItem" .. i]
        self.itemIds[i] = i
        local uiCell = self:BindComponent(item, BagItem, self.itemIds[i], true)
        self.items[i] = uiCell

    end

    -- n个一样的格子，界面里只放一个，其他都是动态创建
    -- 创建一组对象
    self.groupItems = BaseList.CreateList(self, BaseList.Kind.GroupView, "GroupItems", BagItem)
    -- 刷新数据
    self.groupItemsDatas = {}
    for i = 1, 5 do
        table.insert(self.groupItemsDatas, 100 + i)
    end
    self.groupItems:SetData(#self.groupItemsDatas)
    -- 设置选中第几个
    self.selectedIndex3 = 1
    self.groupItems:Sel(self.selectedIndex3)

    -- n个一样的格子，界面里只放一个，其他都是动态创建
    -- 创建一组对象
    self.groupItems2 = BaseList.CreateList(self, BaseList.Kind.GroupView, "GroupItems2")
    self.groupItems2:AddUIListener(EUIEventTypes.CLICK, "GoBtn2", "OnClick_GroupItems2_GoBtn2")
    self.groupItems2:AddUIListener(EUIEventTypes.CheckStateChanged, "CheckBox", "OnCheckStateChanged_GroupItems2_CheckBox")
    -- 刷新数据
    self.groupItemsDatas2 = {}
    for i = 1, 3 do
        table.insert(self.groupItemsDatas2, 100 + i)
    end
    self.groupItems2:SetData(#self.groupItemsDatas2)
    -- 设置选中第几个
    self.selectedIndex5 = 1
    self.groupItems2:Sel(self.selectedIndex5)

    --region CyclingList
    self.cyclingList = P_CyclingList.CreateCyclingList(self.View.CyclingList,self,"CyclingList",BagItem)
    self.cyclingList:SetData(10)
    --endregion
end

--刷新滚动列表sas
function TestUI:OnRefresh_scroll(r, index, selected)
    local data = self.diffDatas[index]
    local kind = data[1]
    if kind == 1 then
        --刷新格子数据
        self.list:SetData(#self.rankDatas)
    elseif kind == 2 then

    end
end

function TestUI:TimerCountDownCallBack()
    local nowTime = self.endTime - _G._now(1)
    if nowTime > 0 then
        self.View.auto_time:SetText(string.format('Esit after %d second', nowTime))
    else
        self.View.auto_time:SetText("Count Down has Finished")
        return true
    end
end

function TestUI:OnceTimerSetText()
    self.View.once_timer:SetText("3 second has gone")
end

function TestUI:OnceTimerSetHp()

end

function TestUI:OnceTimerSetHp2(h)
    self.View.hp2:SetPercent(h / self.maxHp)
end

function TestUI:OnRefresh(arg1, arg2)
    --[[
    ---@type UWidgetAnimation
    local anim = self:GetGameObject("AnimTest")
    ---@type UUserWidget
    local widget = self:GetGameObject()
    --绑定动画结束
    self:AddUIEvent(UIEvent.AnimFinished, anim)
    -- self:AddCustomEvent("NewEventDispatcher_0")
    ---从动画的0.5s开始播放，抛出两事件，Middle和End
    self:PlayAnim(anim, 0.5)
    self:StartTask(self.UpdateList, self)
    ]]
       --

    -- 刷新格子数据
    local selected = false
    for k, item in next, self.items do
        local itemId = self.itemIds[k]
        item:Refresh(itemId, selected)
    end

    local c = self.View

    self.endTime = 5 + _G._now(1) -- 倒计时结束时间（秒）
    self:StartTimer('taskcomplete_auto_time', function()
        self:TimerCountDownCallBack()
    end,1000, -1, nil, true)

    self:StartTimer('unlockui', function()
        self:StartTimerSetText()
    end, 3 * 1000, 1)

    self.hp = 20
    self.maxHp = 100
    --local time = _now() + 300
    -- 3ooms后血条开始变化
    self:StartTimer('hp', function()
        self:StartTimerSetHp()
    end, 300, 1)

    --local flyitem = c.flyitem2
    --local endx, endy = UIHelper.GetScreenPosition(c.flyitemto)
    -- self:FlyTo(flyitem, endx, endy, function()
    --     -- self:CloseSelf()
    -- end, nil, nil, 2000, 0.5)

    -- flyitem = c.flyitem
    --endx, endy = UIHelper.GetScreenPosition(c.flyitemto)
    -- self:FlyItemTo(flyitem, endx, endy, function()
    --     -- self:CloseSelf()
    -- end)
    self:PlayAnimation(c, c.inanim, 0, 1, EUMGSequencePlayMode.Forward, 1, false, self.OnAnimEnd, self)
end

function TestUI:OnAnimEnd()
    Log.Warning("TestUI OnAnimEnd", self)
end

function TestUI:OnClose()
    UIBase.OnClose(self)
end

-- 滚动列表里子元素的点击事件
function TestUI:OnClick_RankList_GoBtn(index)
    local data = self.rankDatas[index]
    Log.Debug("OnClick_RankList_GoBtn", data)
end

function TestUI:CanSel_RankList(index)
    return index <= 1000
end

--刷新滚动列表
function TestUI:OnRefresh_RankList(r, index, selected)
    -- 刷新格子数据
    local icon = r.icon
    local num = r.num
    local data = self.rankDatas[index]
    if selected then
        local IconPath = "/Game/Arts/UI_2/Resource/Common_2/Atlas/Sprite01/UI_Com_Bg_PlayBack_Sprite.UI_Com_Bg_PlayBack_Sprite"
        self:SetImage(icon, IconPath)
    else
        local IconPath = "/Game/Arts/UI_2/Resource/Common_2/Atlas/Sprite01/UI_Com_Bg_Write_Sprite.UI_Com_Bg_Write_Sprite"
        self:SetImage(icon, IconPath)
    end
    num:SetText(data)
end

--点击滚动列表
function TestUI:OnClick_RankList(r, index)
    local data = self.rankDatas[index]
    Log.Warning("OnClick_RankList ", data)
end

function TestUI:OnDoubleClick_RankList(r, index)
    local data = self.rankDatas[index]
    Log.Warning("OnDoubleClick_RankList ", data)
end

function TestUI:OnLongPress_RankList(r, index)
    local data = self.rankDatas[index]
    Log.Warning("OnLongPress_RankList ", data)
end

--刷新滚动列表
function TestUI:OnRefresh_BagList(r, index, selected)
    --刷新格子数据
    r:Refresh(self.itemDatas[index], selected)
end

--点击滚动列表
function TestUI:OnClick_BagList(r, index)
    local itemId = self.itemDatas[index]
    Log.Debug("OnClick_BagList ", itemId)
end

-- 显示子界面
function TestUI:OnClick_Button1()
    UI.ShowUI("TestSubUI")
    -- self.diffList:SetData({})
    self.list:SetData(2)
    --local c = self.View
    --local effect = c.Effect
    --self:PlayEffect(effect, "/Game/Arts/UI_2/Blueprint/TestUI/WBP_TestEffect.WBP_TestEffect_C")
end

local function GC() -- luacheck: ignore
    -- local GI = import("GameplayStatics").GetGameInstance(_G.GetContextObject())
    -- local world = slua.getWorld()
    collectgarbage('collect')
    collectgarbage('collect')
    collectgarbage('collect')
    -- world:ForceGarbageCollection(true)
    -- world:ForceGarbageCollection(true)
    -- world:ForceGarbageCollection(true)
    collectgarbage('collect')
    collectgarbage('collect')
    collectgarbage('collect')
    -- world:ForceGarbageCollection(true)
    -- world:ForceGarbageCollection(true)
    -- world:ForceGarbageCollection(true)
end
-- 设置列表不能点击和滑动 || 设置列表是否可以多选
function TestUI:OnClick_Button2()
    --local c = self.View
    -- self.diffList:SetData(self.diffDatas, 1)
    -- self.tileList:SetEnabled(false)
    self.tileList:SetMulti(true)
    -- GC()
    UI.Invoke("TestSubUI", "ChangeData", 6, 4)
    -- self.groupItemsDatas = {}
    -- for i = 1, 5 do
    --     table.insert(self.groupItemsDatas, 100 + i)
    -- end
    -- self.groupItems:SetData(#self.groupItemsDatas)
end

-- 设置列表能点击和滑动
function TestUI:OnClick_Button3()
    -- self.tileList:SetEnabled(true)
    --获取列表选中了哪些
    local sels = self.tileList:GetSelectedIndex()
    if sels then
        Log.Dump(sels)
    end
    -- self.tileList:SetMulti(false)
    self.tileList:CancelAllSel()
    -- GC()
    UI.Invoke("TestSubUI", "ChangeData", 3, 4)
    -- self.groupItemsDatas = {}
    -- for i = 1, 2 do
    --     table.insert(self.groupItemsDatas, 100 + i)
    -- end
    -- self.groupItems:SetData(#self.groupItemsDatas)
end

function TestUI:OnClick_GroupItems2_GoBtn2(index)
    Log.Debug("OnClick_GroupItems2_GoBtn2 ", index)
end

function TestUI:OnCheckStateChanged_GroupItems2_CheckBox(bIsChecked, index)
    Log.Debug("OnCheckStateChanged_GroupItems2_CheckBox ", bIsChecked, index)
end

-- 刷新一组格子
function TestUI:OnRefresh_GroupItems(r, index, selected)
    --刷新格子数据
    r:Refresh(self.groupItemsDatas[index], selected)
end

-- 刷新一组格子
function TestUI:OnRefresh_GroupItems2(r, index, selected)
    --刷新格子数据
    local wiget = r.WidgetRoot
    local total = wiget:GetChildrenCount()
    for i = 1, total do
        local item = wiget:GetChildAt(i - 1)
        local name = item:GetName()
        Log.Debug(" i ", i, " name", name)
    end
    local icon = r.icon2
    local num = r.num2
    local data = self.groupItemsDatas2[index]
    if selected then
        local IconPath = "/Game/Arts/UI_2/Resource/Common_2/Atlas/Sprite01/UI_Com_Bg_PlayBack_Sprite.UI_Com_Bg_PlayBack_Sprite"
        self:SetImage(icon, IconPath)
    else
        local IconPath = "/Game/Arts/UI_2/Resource/Common_2/Atlas/Sprite01/UI_Com_Bg_Write_Sprite.UI_Com_Bg_Write_Sprite"
        self:SetImage(icon, IconPath)
    end
    num:SetText(data)
end

function TestUI:OnRefresh_CyclingList(widget, index, selected)
    -- Log.Debug("This is CyclingList OnRefresh")
    widget:Refresh(index, selected)
end

function TestUI:OnFocus_CyclingList(widget, index, focused)
    -- Log.Debug("This is CyclingList OnFocus")
    widget:Refresh(index, focused)
end


-- 关闭按钮
function TestUI:OnClick_btn_close()
    self:CloseSelf()
end

--region 实现拖拽
function TestUI:OnMouseBtnDown(MyGeometry, InMouseEvent)
    Log.Warning(" P_GMInputOutputPanel:OnMouseBtnDown(MyGeometry,InMouseEvent)")
    self.DragStartPos = import("KismetInputLibrary").PointerEvent_GetScreenSpacePosition(InMouseEvent)
    local EventReply = import("WidgetBlueprintLibrary").DetectDragIfPressed(
        InMouseEvent,
        self.View.WBP_GMOverlay.Overlay.WidgetRoot,
        import("UIFunctionLibrary").GetKeyFromName("LeftMouseButton")
    )
    self.bIsDrag = false
    return EventReply
end

function TestUI:OnReleased()
    Log.Warning("TestUI OnReleased---")
    return nil
end

--endregion

--[[function TestUI:UpdateList(TT)
    YIELD(TT)
    local render = self.list:GetRendererAt(1)
    dump(render)
end

function TestUI:NewEventDispatcher_0()
    Log.debug("1111111111111111")
end

function TestUI:AnimTestOnStarted()
    Log.debug("AnimTestStarted")
end

function TestUI:AnimTestOnFinished()
    Log.debug("AnimTestFinished")
end

function TestUI:AnimTestCallBack(animType)
     if animType == EAnimType.Begin then
        Log.debug("AnimTestCallBack Begin")
    elseif animType == EAnimType.Middle then
        Log.debug("AnimTestCallBack Middle")
    elseif animType == EAnimType.End then
        Log.debug("AnimTestCallBack End")
    end
end

function TestUI:CheckBox1OnCheckStateChanged(bIsChecked)
    Log.debug("CheckBox1OnCheckStateChanged "..tostring(bIsChecked))
end
]]
   --
