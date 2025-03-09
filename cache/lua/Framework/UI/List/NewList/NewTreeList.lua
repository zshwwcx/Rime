---@field doubleClickEnabled boolean 双击开关，默认打开
---@field owner UIController 归属界面
---@field selectedIndex number 列表选中的第多少条数据
---@field total number 列表元素总数
---@field cell UIComponent[] 包含的UIComponent类型数组
---@field cells table<number, UIComponent> 当前显示的UIComponent对象表
---@field cellIndexs table<UIComponent, number> UIComponent映射index的map
---@field name string list唯一标识
---@field names string[] 包含的UIComponent类型的name
---@field uiCells table<number, table<UUserWidget, UIComponent>> UUserWidget与Cell的映射
---@field rawItems table<number, UIComponent[]> Cell对象池
---@field wigets UIComponent[] 所有创建的cell的唯一索引，包括池子内
---@field cellMap table<UIComponent, UUserWidget> UUserWidget与Cell的映射
---@field refItems number UnLua.Ref
---@field blong boolean[] 长按标记
---@field lastClickTimes table<number, number> 双击时间记录
---@field iTogMap table<number, UIComponent> --GroupCell对应的索引
---@field iTotMap table<number, UIComponent> --GroupCell对应的组
---@field gToiMap table<UIComponent, number> --GroupCell逆向索引
---@field tToiMap table<UIComponent, number> --title逆向索引
---@field timeName string 双击计时器标识
---@field timePressName string 长按计时器标识
---@field _foldMap NewTreeList.Kind[] 类型索引
---@field _topIndex number 当前最上面的widget索引
---@field _bottomIndex number 当前最下面的widget索引
---@field _oldTop number 上次最上面的widget索引
---@field _oldBottom number 上次最下面的widget索引
---@field oldOffect number 上次回调滑动偏移
---@field _indexToTopPos number[] 记录widget的Top对应位置
---@field _indexToBottomPos number[] 记录widget的Bottom对应位置
---@field _indexToXPos number[] 记录widget的X坐标对应位置
---@field _lastIndex number 当前最后未折叠的index
---@field foldSwitch boolean[] 折叠标识
---@field space number 纵向间隔
---@field length number listpanel总高
---@field width number 可显示区域宽度
---@field height number 可显示区域高度
---@field onStartIndexChangedCB function startIndex改变回调
---@field startIndex number 当前显示区域开始坐标
---@field tempPos FVector2D 修改cell坐标用
---@field _panel UCanvasPanel listpanel
---@field _diffPoint UBorder 控制listpanel大小的定位点
---@field kind number cell类型数量总数

local ESlateVisibility = import("ESlateVisibility")
local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
local TreeListAniComp = kg_require("Framework.UI.List.ListComponents.TreeListAnimationComponent")
---@class NewTreeList:UIComponent
local NewTreeList = DefineClass("NewTreeList", UIComponent)


---@class NewTreeList.Kind
NewTreeList.Kind = {
    Title = 1,
    Cell = 2,
}

---@class NewTreeList.Layout
NewTreeList.Layout = {
    List = 0, --行布局
    Gird = 1, --格子布局
}


---@class NewTreeList.Alignment
NewTreeList.Alignment = {
    Left = 0,
    Center = 1,
    Right = 2,
}

---@class NewTreeList.SelectionMode
NewTreeList.SelectionMode = {
    Single = 1, --单选
    SingleToggle = 2, --单项勾选（重复点击取消选中）
    Multi = 3 --多选
}

NewTreeList.eventBindMap = {
    --需要监听屏幕分辨率更新
    [EEventTypes.ON_VIEWPORT_RESIZED] = "OnViewportResize",
}
--[=[
---刷新列表里每个格子的回调函数
---OnRefresh_List
---OnRefresh需要符合如下格式：
---@param r 格子(滚动元素比较简单)或者UIComponent(适合道具格子类比较复杂的滚动元素，需要基础UIComponent，可参考testui.lua里BagList里的写法)
---@param index 第多少条数据
---@param selected 第多少条数据是否选中
function(r, index, selected)
    local config = Cfg.cfg_item[self.items[index]]
    local image = r.btn.image
    image.sprite = config.icon
    local choose = r.choose
    choose.active= selected
end
]=]
--

function NewTreeList.SetUpFade(self)
    self.userWidget:SetSlateRectFadePositionByFloat(0, 0.1, 1.0, 1.0)
    self.userWidget:SetSlateRectFadeSizeByFloat(0, 0.08)
end

function NewTreeList.SetDownFade(self)
    self.userWidget:SetSlateRectFadePositionByFloat(0, 0.0, 1.0, 0.9)
    self.userWidget:SetSlateRectFadeSizeByFloat(0, 0.08)
end

function NewTreeList.CancelFade(self)
    self.userWidget:SetSlateRectFadePositionByFloat(0, 0, 0, 0.0)
    self.userWidget:SetSlateRectFadeSizeByFloat(0, 0)
end

function NewTreeList.SetBothFade(self)
    self.userWidget:SetSlateRectFadePositionByFloat(0, 0.1, 1.0, 0.9)
    self.userWidget:SetSlateRectFadeSizeByFloat(0, 0.08)
end

---@param view UScrollBox
---@param name string TreeList的名字
---@param visible boolean scrollbar是否显示
---@param cells UIController[]


function NewTreeList:ctor(_, _, widget, parentComponent, cells, name, bParentAction, buttonPath, bIsAsync, asyncNum)
    self.doubleClickEnabled = false
    self.rightClickEnabled = false
    self.owner = parentComponent --所属UI
    --设置滑动条隐藏
    -- if visible then
        -- self:getRoot():SetScrollBarVisibility(import("ESlateVisibility").Visible)
    -- else
        self:getRoot():SetScrollBarVisibility(ESlateVisibility.Collapsed)
    -- end

    self.selectedIndex = -1
    --可以多选的列表
    self.selectedIndexs = {}
    --是否分帧创建cell
    self.bIsAsync = bIsAsync
    --分帧加载数量
    self.asyncNum = asyncNum or 3
    self._tempAsyncNum = 0
    self.total = -1
    self.cell = cells or {}
    self._cells = {}
    self.cellIndexs = {}
    if not name then
        name = widget:GetName()
    end
    self.name = name
    self.names = {}
    if buttonPath then
        self.buttonPath = string.split(buttonPath, ".")
    end
    self.uiCells = {}

    -- self.wigets = {}
    --对象类型（是否为Lib的）
    self.libWidget = {}
    --对象池
    self.rawItems = {}
    --目标库
    self.template = {}
    --对象引用池
    self.refItems = {}
    self.cellMap = {}
    self.blong = {}
    self.lastClickTimes = {}
    self._tempIndex = {}
    self._temp = {}
    self.bIsBottomFirst = false
    --index对应第几层
    self._floorMap = {}
    --index对应的当前层的第几个
    self._groupMap = {}
    --index对应的父层的index
    self._parentMap = {}
    --第几层第几个对应的index
    self._indexMap = {}

    ---@type number 记录需要滚动的index
    self._cacheIdx = nil

    self.timeName = string.format("%s%s", self.owner.__cname, self.name)  --定时器名字固定前缀
    self.timePressName = nil
    --折叠映射
    self._foldMap = {}
    --类型映射
    self._kindMap = {}
    --布局类型映射
    self.layout = {}
    --计算组件显示用
    self._topIndex = 1
    self._bottomIndex = 1
    self._oldTop = 0
    self._oldBottom = 0
    --上次回调滑动偏移
    self.oldOffect = 0
    self.sizeCache = {}
    --记录widget对应位置
    self._indexToTopPos = {}
    self._indexToBottomPos = {}
    self._lastIndex = 0
    self._indexToXPos = {}
    self._itemPadding = {}
    self._padding = {}
    --折叠
    self.foldSwitch = {}
    --间隔
    self.space = {}
    self.alignment = {}
    --选中模式
    local selectionMode = self.view.SelectionMode
    self.toggle = selectionMode == ComList.SelectionMode.SingleToggle
    self.multi = selectionMode == ComList.SelectionMode.SingleToggle
    --多层菜单（排行榜
    self.isMultiMenu = self.view.IsMultiMenu

    --panel总长
    self.length = 0
    self.width = 0
    self.height = 0
    --UObject数量统计
    self.oneObjNums = {}

    --Refresh安全锁，防止在Refresh过程中SetData
    self.isRefreshing = false
    --
    self.onStartIndexChangedCB = string.format("%s%s", name, "_OnStartIndexChanged")
    self.onGetWidgetSizeFunCB = nil

    self:SetDownFade()
    -- end

    self.bEndFlag = false
    self.bStartFlag = false
    self.onScrollToEndCB = nil
    self.tempPos = FVector2D()

    self:bindAllWidget()
    self._panel = self.view.DiffPanel_lua
    self._diffPoint = self.view.DiffPoint_lua

    self.startIndex = 1

    self:AddUIEvent(self:getRoot().OnUserScrolled, "onUserScrolled")
    --self:AddUIListener(EUIEventTypes.OnAnimationNotify, self.userWidget, self.onNotifyPlayAnimation)
    self.view.ListPlayAnimation:Add(
        function(key)
            self:onNotifyPlayListAnimation(key)
        end)
    self._defaultAnchors = import("Anchors")()

    self.getCachedGeometryFun = self:getRoot().GetCachedGeometry
    self.getLocalSizeFun = import("SlateBlueprintLibrary").GetLocalSize
    self:getSize()

    ---@type boolean @标识是否需要更新大小
    self.bMarkViewportResize = nil
    ---@type boolean @标识当前是否显示
    self.bEnable = true
    ---@type number @重新获取大小的尝试次数
    self.reSizeCount = 0

    --列表动画
    self.aniComp = nil
    self.animations = self.view.Animation
    --需要播放进入动画
    self.aniSetData = nil
    self.aniNotified = nil

    self:InitListAnimationData()

    self.AnimationsData = self.view.Animation
    self.floorFrequence = self.view.FloorFrequence
    self.groupFrequence = self.view.GroupFrequence
end
function NewTreeList:getRoot()
    return self.view.TreeList_lua
end

function NewTreeList:getSpace(floor, kind)
    if not self.space[floor] then
        return 0,0,0,0
    end
    if not self.space[floor][kind] then
        return 0,0,0,0
    end
    local space = self.space[floor][kind]
    return space[1],space[2],space[3],space[4]
end

function NewTreeList:bindAllWidget()
    local structure = self.view.Structure
    local listPadding = self.view.ListPadding
    self._padding = {
        Left = listPadding.Left,
        Top = listPadding.Top,
        Right = listPadding.Right,
        Bottom = listPadding.Bottom,
    }
    for floor = 1, structure:Num(), 1 do
        local data = structure:Get(floor-1)
        self.uiCells[floor] = {}
        self.libWidget[floor] = {}
        self.template[floor] = {}
        self.layout[floor] = {}
        self.names[floor] = {}
        self.space[floor] = {}
        self.alignment[floor] = {}
        self.oneObjNums[floor] = {}

        local itemPadding = data.padding
        self._itemPadding[floor] = {
            Left = itemPadding.Left + self._padding.Left,
            Top = itemPadding.Top,
            Right = itemPadding.Right + self._padding.Right,
            Bottom = itemPadding.Bottom,
        }
	    local layoutLength = data.layout:Num()
        local alignmentLength = data.alignment:Num()
        local spaceLength = data.space:Num()
        for kind = 1, data.widget:Num(), 1 do
            local widget = data.widget:Get(kind-1)
            local libWidget = widget.libWidget
            local itemName
            if libWidget.libName ~= "" then
                local name = libWidget.libName
                self.libWidget[floor][kind] = {name, libWidget.sizeX, libWidget.sizeY}
                itemName = name
            else
                self.uiCells[floor][kind] = {}
                widget = widget.widget
                widget:SetVisibility(ESlateVisibility.Hidden)
                itemName = widget:GetName()
                self.template[floor][kind] = widget
                self.oneObjNums[floor][kind] = UIHelper.GetObjectNum(widget)
            end
            self.names[floor][kind] = string.format("%s%s%s%s", self.name, "_", itemName, "_")
            if kind <= layoutLength then
                self.layout[floor][kind] = data.layout:Get(kind - 1)
            else
                self.layout[floor][kind] = NewTreeList.Layout.List
            end

            if kind <= spaceLength then
                self.space[floor][kind] = {
                    data.space:Get(kind - 1).SpaceUp,
                    data.space:Get(kind - 1).SpaceBottom,
                    data.space:Get(kind - 1).SpaceLeft,
                    data.space:Get(kind - 1).SpaceRight
                }
            end
            if kind <= alignmentLength then
                self.alignment[floor][kind] = data.alignment:Get(kind - 1)
            else
                self.alignment[floor][kind] = NewTreeList.Alignment.Left
            end
        end
    end
    self.floor = structure:Num() - 1
end

function NewTreeList:SetDiffSizeFun(funcName)
    if self.owner[funcName] then
        self.onGetWidgetSizeFunCB = funcName
    end
end

function NewTreeList:SetScrollToEndListener(funcName)
    if self.owner[funcName] then
        self.onScrollToEndCB = funcName
    end
end

function NewTreeList:getCellIndex(cell)
    local index = self.cellIndexs[cell]
    if index then
        return self:getAllIndex(index)
    end
end

function NewTreeList:getAllIndex(index)
    local tIndex = self._floorMap[index]
    local gIndex = self._groupMap[index]
    if tIndex == 1 then
        return gIndex
    end
    local parentIndex = index
    self._tempIndex[#self._tempIndex + 1] = gIndex
    for i = 1, tIndex, 1 do
        parentIndex = self._parentMap[parentIndex]
        if parentIndex > 0 then
            self._tempIndex[#self._tempIndex + 1] = self._groupMap[parentIndex]
        end
    end
    table.clear(self._temp)
    for i = #self._tempIndex, 1, -1 do
        self._temp[#self._temp + 1] = self._tempIndex[i]
    end
    table.clear(self._tempIndex)

    return self._temp[1], self._temp[2], self._temp[3], self._temp[4], self._temp[5]
end

function NewTreeList:isFold(index)
    return self:IsFold(self:getAllIndex(index))
end

function NewTreeList:isParentFold(index)
    local parentIndex = self._parentMap[index]
    if parentIndex > 0 then
        return self:IsFold(self:getAllIndex(parentIndex))
    else
        return false
    end
end

---@public @设置从底部开始的布局
function NewTreeList:SetBottomFirst(bIsBottomFirst)
    self.bIsBottomFirst = bIsBottomFirst
end

function NewTreeList:getOrSetFold(value, index1, index2, index3, index4, index5)
    if not index1 then
        return true
    end
    local foldSwitch = self.foldSwitch[index1]
    local _foldSwitch
    if type(foldSwitch) == "table" then
        if index2 then
            _foldSwitch = foldSwitch
            foldSwitch = foldSwitch[index2]
            if type(foldSwitch) == "table" then
                if index3 then
                    _foldSwitch = foldSwitch
                    foldSwitch = foldSwitch[index3]
                    if type(foldSwitch) == "table" then
                        if index4 then
                            _foldSwitch = foldSwitch
                            foldSwitch = foldSwitch[index4]
                            if type(foldSwitch) == "table" then
                                if index5 then
                                    if value ~= nil then
                                        foldSwitch[index5] = value
                                    end
                                    foldSwitch = foldSwitch[index5]
                                else
                                    if value ~= nil then
                                        foldSwitch[0] = value
                                    end
                                    foldSwitch = foldSwitch[0]
                                end
                            elseif value ~= nil then
                                _foldSwitch[index4] = value
                            end
                        else
                            if value ~= nil then
                                foldSwitch[0] = value
                            end
                            foldSwitch = foldSwitch[0]
                        end
                    elseif value ~= nil then
                        _foldSwitch[index3] = value
                    end
                else
                    if value ~= nil then
                        foldSwitch[0] = value
                    end
                    foldSwitch = foldSwitch[0]
                end
            elseif value ~= nil then
                _foldSwitch[index2] = value
            end
        else
            if value ~= nil then
                foldSwitch[0] = value
            end
            foldSwitch = foldSwitch[0]
        end
    elseif value ~= nil then
        self.foldSwitch[index1] = value
    end
    if foldSwitch == nil then
        return true
    end
    return foldSwitch
end

---@public 是否折叠
function NewTreeList:IsFold(index1, index2, index3, index4, index5)
    return self:getOrSetFold(nil, index1, index2, index3, index4, index5)
end

---点击处理
---@private
function NewTreeList:HandleItemClicked(uiCell, bIsRightClick)
    if bIsRightClick and not self.rightClickEnabled then
        return
    end
    self:onItemClicked(self.cellIndexs[uiCell], bIsRightClick)
end

---@private 调用Refreshcallback,刷新UIComponent回调
function NewTreeList:callRefreshFun(owner, component, index, bIsSelect)
    if bIsSelect == nil then
        if self._foldMap[index] == NewTreeList.Kind.Title then
            bIsSelect = self:isFold(index)
        else
            if self.multi then
                bIsSelect = self.selectedIndexs[index]
            else
                bIsSelect = self.selectedIndex == index
            end
        end
    end
    component:OnItemRefresh(index)
    if component.OnListRefresh then
        self.isRefreshing = true
        xpcall(component.OnListRefresh, function (...)
            _G.CallBackError(...)
            self.isRefreshing = false
        end, component, self.owner, bIsSelect, self.datas, self:getAllIndex(index))
        self.isRefreshing = false
        self:onRefreshItem(index, bIsSelect)
    end
end


function NewTreeList:callParentRefreshFun(owner, component, index, bIsSelect)
    
end
---@private 调用OnClickcallback,点击事件回调
function NewTreeList:callOnClickFun(owner, component, index, bIsRightClick)
    if bIsRightClick and component.OnRightClick then
        component:OnRightClick(self.owner, self.datas, self:getAllIndex(index))
    elseif component.OnClick then
        component:OnClick(self.owner, self.datas, self:getAllIndex(index))
    end
end

---@private 调用CanSelcallback,能否选中回调
function NewTreeList:callCanSelFun(component, index)
    if component.CanSel then
        return component:CanSel(self.owner, self.datas, self:getAllIndex(index))
    else
        return true
    end
end

---@private 调用OnDoubleCcallback,双击事件回调
function NewTreeList:callOnDoubleClickFun(component, index)
    if component.OnDoubleClick then
        component:OnDoubleClick(self.owner, self.datas, self:getAllIndex(index))
    end
end

---@private 调用OnLongPresscallback,长按事件回调
function NewTreeList:callOnLongPressFun(component, index)
    if component.OnLongPress then
        component:OnLongPress(self.owner, self.datas, self:getAllIndex(index))
    end
end

---@private 调用OnReleasedcallback,按下释放回调
function NewTreeList:callOnReleasedFun(component, index)
    if component.OnReleased then
        component:OnReleased(self.owner, self.datas, self:getAllIndex(index))
    end
end

--TODO：临时解决方案，暂时无法获取panel的准确大小
function NewTreeList:getSize()
    local vis = self.userWidget:GetVisibility()
    if vis == ESlateVisibility.Collapsed or vis == ESlateVisibility.Hidden then
        return 
    end
    self:StartTimer("REFRESH_HIERARCHYLIST_GET_SIZE_NEW", function()
        local size = self.getLocalSizeFun(self.getCachedGeometryFun(self:getRoot()))
        if size.X == 0 or size.Y == 0 then
            return self:getSize()
        end
        self.width = size.X
        self.height = size.Y
        self:calculatePos()
    end, 1, 1)
end

function NewTreeList:onUserScrolled(currentOffset)
    if self.height == 0 then
        return
    end
    local currentOffset = math.max(math.min(currentOffset, self.length - self.height), 0)
    local delta = self.oldOffect - currentOffset
    local step, limit, reLimit
    if delta > 0 then
        step = -1
        limit = 1
        reLimit = self.total
    else
        step = 1
        limit = self.total
        reLimit = 1
    end
    if self.total <= 0 then
        self.oldOffect = currentOffset
        self:checkRefresh(step > 0)
        return
    end
    local top = currentOffset
    local bottom = currentOffset + self.height
    if top <= self._indexToTopPos[1] then
        self._topIndex = 1
    else
        for i = self._oldTop, limit, step do
            if self._indexToTopPos[i] and self._indexToTopPos[i] ~= -100 then
                local bMiddle = top >= self._indexToTopPos[i] and top < self._indexToBottomPos[i]
                local bSpace = false
                if self._indexToBottomPos[i + 1] then
                    if top < self._indexToTopPos[i + 1] and top >= self._indexToBottomPos[i] then
                        bSpace = true
                    end
                end
                if bMiddle or bSpace then
                    self._topIndex = i
                    break
                end
            end
        end
    end
    local _indexToTopPos = self._indexToTopPos[self._topIndex]
    if step > 0 then
        for i = self._topIndex, reLimit, -step do
            if _indexToTopPos == self._indexToTopPos[i] then
                self._topIndex = i
            else
                break
            end
        end
    else
        for i = self._topIndex, limit, step do
            if _indexToTopPos == self._indexToTopPos[i] then
                self._topIndex = i
            else
                break
            end
        end
    end
    if (not self._lastIndex) or (not self._indexToBottomPos[self._lastIndex]) then
        Log.WarningFormat("NewTreeList BottomPos Index error, indexToBottomPos Count:: %s, lastIndex:: %s",
            #self._indexToBottomPos, self._lastIndex or "nil")
    end
    if self._lastIndex and self._indexToBottomPos[self._lastIndex] and self._indexToBottomPos[self._lastIndex] <= bottom then
        self._bottomIndex = self._lastIndex
    else
        for i = self._oldBottom, limit, step do
            if self._indexToTopPos[i] and self._indexToTopPos[i] ~= -100 then
                local bMiddle = bottom >= self._indexToTopPos[i] and bottom < self._indexToBottomPos[i]
                local bSpace = false
                if self._indexToTopPos[i - 1] then
                    if bottom < self._indexToTopPos[i] and bottom >= self._indexToBottomPos[i - 1] then
                        bSpace = true
                    end
                end
                if bMiddle or bSpace then
                    self._bottomIndex = i
                    break
                end
            end
        end
        _indexToTopPos = self._indexToTopPos[self._bottomIndex]
        if step < 0 then
            for i = self._bottomIndex, reLimit, -step do
                if _indexToTopPos == self._indexToTopPos[i] then
                    self._bottomIndex = i
                else
                    break
                end
            end
        else
            for i = self._bottomIndex, limit, step do
                if _indexToTopPos == self._indexToTopPos[i] then
                    self._bottomIndex = i
                else
                    break
                end
            end
        end
    end
    self.oldOffect = currentOffset
    self:checkRefresh(step > 0)
end

function NewTreeList:checkRefresh(bUp)
    --先回收
    if bUp then
        if self._topIndex ~= self._oldTop then
            for i = self._oldTop, self._topIndex - 1 do
                if self._cells[i] then
                    self.cellIndexs[self._cells[i]] = nil
                end
                self:setCell(self._cells[i], i)
                self._cells[i] = nil
            end
        end
    else
        if self._bottomIndex ~= self._oldBottom then
            for i = self._bottomIndex + 1, self._oldBottom do
                if self._cells[i] then
                    self.cellIndexs[self._cells[i]] = nil
                end
                self:setCell(self._cells[i], i)
                self._cells[i] = nil
            end
        end
    end
    if self.total <= 0 then
        return
    end
    --再加载
    self._topIndex = math.max(self._topIndex, 1)
    self._bottomIndex = math.min(self._bottomIndex, self.total)

    self._oldTop = self._topIndex
    self._oldBottom = self._bottomIndex
    if self.bIsAsync then
        if not self:asyncGetCell() then
            self:StartTimer("AsyncGetCell", function()
                if self:asyncGetCell() then
                    self:StopTimer("AsyncGetCell")                    
                end
            end, 1, -1, nil, true)
        end
    else
        for i = self._topIndex, self._bottomIndex do
            if not self._cells[i] and self._indexToTopPos[i] ~= -100 then
                self._cells[i] = self:getCell(i)
                if self._cells[i] then
                    self._cells[i]:Show()
                    self._cells[i]:Open()
                    self.cellIndexs[self._cells[i]] = i
                    self:callRefreshFun(self.owner, self._cells[i], i)
                end
            end
        end

        self:refreshRetainerBox()
        --
        --self:StartStaggerAnimation(self.aniIdx)
        self:playListInAnimation()
    end
end

function NewTreeList:asyncGetCell()
    local bBreak = false
    self._tempAsyncNum = self.asyncNum
    for i = self._topIndex, self._bottomIndex do
        if not self._cells[i] and self._indexToTopPos[i] ~= -100 then
            local cell = self:getCell(i)
            if cell then
                self._cells[i] = cell
                self._cells[i]:Show()
                self._cells[i]:Open()
                self.cellIndexs[self._cells[i]] = i
                self:callRefreshFun(self.owner, self._cells[i], i)
            else
                bBreak = true
                break
            end
        end
    end

    self:refreshRetainerBox()

    if not bBreak then
        return true
    end
end

function NewTreeList:refreshRetainerBox()
    if self.owner[self.onStartIndexChangedCB] then
        if self.startIndex ~= self._oldTop then
            self.startIndex = self._oldTop
            self.owner[self.onStartIndexChangedCB](self.owner, self:getAllIndex(self._oldTop))
        end
    end

    -- if self.owner[self.onScrollToEndCB] then
    if self.oldOffect+self.height >= self.length - 0.01 and self.oldOffect > 0.0 then --到底部没到顶部
        if not self.bEndFlag or self.bStartFlag then
            self.bEndFlag = true
            self.bStartFlag = false
            if self.owner[self.onScrollToEndCB] then
                self.owner[self.onScrollToEndCB](self.owner, true)
            end
            self:SetUpFade()
        end
    elseif self.oldOffect+self.height < self.length - 0.01 and self.oldOffect <= 0.0 then --到顶部没到底部
        if not self.bStartFlag or self.bEndFlag then
            self.bEndFlag = true
            self.bStartFlag = false
            if self.owner[self.onScrollToEndCB] then
                self.owner[self.onScrollToEndCB](self.owner, true)
            end
            
            self:SetDownFade()
        end
    elseif self.oldOffect+self.height < self.length - 0.01 and self.oldOffect > 0.0 then --没到顶部也没到底部
        if self.bEndFlag or self.bStartFlag then
            self.bStartFlag = false
            self.bEndFlag = false
            if self.owner[self.onScrollToEndCB] then
                self.owner[self.onScrollToEndCB](self.owner, false)
            end
            
            self:SetBothFade()
        end
    elseif not self.bEndFlag or not self.bStartFlag then --既到顶部又到底部
        self.bEndFlag = true
        self.bStartFlag = true
        if self.owner[self.onScrollToEndCB] then
            self.owner[self.onScrollToEndCB](self.owner, true)
        end
        
        self:CancelFade()
    end
    -- end
end

function NewTreeList:_getSizeFun(floor, kind)
    if self.libWidget[floor][kind] then
        return self.libWidget[floor][kind][2], self.libWidget[floor][kind][3]
    end
    local sizeCache = self.sizeCache[floor]
    if not sizeCache then
        sizeCache = {}
        self.sizeCache[floor] = sizeCache
    end
    local _sizeCache = sizeCache[kind]
    if not _sizeCache then
        _sizeCache = {}
        sizeCache[kind] = _sizeCache
        local item = self.template[floor][kind]
        import("WidgetLayoutLibrary").GetViewportSize(item)
        local size = item.Slot:GetSize()
        _sizeCache[1] = size.X
        _sizeCache[2] = size.Y
    end

    return _sizeCache[1], _sizeCache[2]
end

function NewTreeList:doRefresh()
    for i, widget in pairs(self._cells) do
        self:callRefreshFun(self.owner, self._cells[i], i)
    end
end

function NewTreeList:getSubCell(parent, indexMap, defaultFold, foldSwitch, fold, level, index, parentIndex)
    local total = 0
    for i = 1, #parent do
        self._floorMap[index] = level
        self._groupMap[index] = i
        self._parentMap[index] = parentIndex or -1
        local subDatas = parent[i]
        local isTable = type(subDatas) == "table"
        if isTable and subDatas.Kind then
            self._kindMap[index] = subDatas.Kind
        else
            self._kindMap[index] = 1
        end
        if isTable and subDatas.Children and #subDatas.Children > 0 then
            if fold and (fold[i] ~= nil) then
                foldSwitch[i] = { [0] = fold[i] }
            else
                foldSwitch[i] = { [0] = defaultFold }
            end

            self._foldMap[index] = NewTreeList.Kind.Title
            local _indexMap = { [0] = index }
            indexMap[i] = _indexMap
            index = index + 1
            total = total + 1
            local subNum
            if fold and fold.Children then
                subNum = self:getSubCell(subDatas.Children, _indexMap, defaultFold, foldSwitch[i], fold.Children, level +
                    1, index, index - 1)
            else
                subNum = self:getSubCell(subDatas.Children, _indexMap, defaultFold, foldSwitch[i], nil, level + 1, index,
                    index - 1)
            end
            index = index + subNum
            total = total + subNum
        else
            -- foldSwitch[i] = true
            self._foldMap[index] = NewTreeList.Kind.Cell
            indexMap[i] = index
            index = index + 1
            total = total + 1
        end
    end
    return total
end

function NewTreeList:clearCell()
    for i = self._bottomIndex, self._topIndex, -1 do
        self:setCell(self._cells[i], i)
    end
    table.clear(self._cells)
    table.clear(self.cellIndexs)
end

---@public 刷新滚动列表
---@param datas table list内的数据结构{ [1] = {Info = data, Children = {[1] = {Info = data, Children = {...}}}, [2] = {Info = data}}}, [2] = ... }
---@param defaultFold boolean 默认折叠开关
---@param foldSwitch table 折叠开关boolean数组
function NewTreeList:SetData(datas, defaultFold, foldSwitch, inAni, ...)
    if not self._cells then
        Log.Warning("NewTreeList Already Close")
        return
    end
    if self.isRefreshing == true then
        Log.Error("Cannot SetData in OnRefresh")
        return
    end
    self:LockScroll(false)
    self.aniSetData = inAni
    if datas then
        self.datas = datas
        self:clearCell()

        -- table.clear(self._foldMap)
        -- table.clear(self._floorMap)
        -- table.clear(self._groupMap)
        -- table.clear(self._indexMap)
        -- table.clear(self._parentMap)
        -- table.clear(self._kindMap)

        self.total = self:getSubCell(datas, self._indexMap, defaultFold, self.foldSwitch, foldSwitch, 1, 1)
        if foldSwitch and type(foldSwitch)=="table" and self.isMultiMenu then
            self._currMenuUnfold = 0
            for i=1,#foldSwitch do
                if not foldSwitch[i] then
                    self._currMenuUnfold = i
                end
            end
        end

        if self.width > 0 then
            self:calculatePos()
        else
            self:getSize()
        end
        --self.total = #self._foldMap
    else
        self:doRefresh()
        --self:StartStaggerAnimation(self.aniIdx)
        self:playListInAnimation()
    end

    self:ScrollToIndex(...)
end

function NewTreeList:calculatePos()
    local totalLenght = 0
    local totalX = 0
    self:clearCell()
    table.clear(self._indexToTopPos)
    table.clear(self._indexToBottomPos)
    table.clear(self._indexToXPos)
    local oldLayout = NewTreeList.Layout.List
    local oldPosX = 0
    local oldPosY = self._padding.Top
    local oldGridSpace = 0
    local oldfloor = -1
    --for i = 1, #self._foldMap, 1 do
    for i = 1, self.total, 1 do
        local floor = self._floorMap[i]
        local kind = self._kindMap[i]
        local layout = self.layout[floor][kind]
        local padding = self._itemPadding[floor]
        local spaceUp,spaceBottom,spaceLeft,spaceRight = self:getSpace(floor, kind)
        local aligment = self.alignment[floor][kind]
        local sizeX, sizeY
        if self.onGetWidgetSizeFunCB then
            sizeX, sizeY = self.owner[self.onGetWidgetSizeFunCB](self.owner, self:getAllIndex(i))
            if (not sizeX) or (not sizeY) then
                sizeX, sizeY = self:_getSizeFun(floor, kind)
            end
        else
            sizeX, sizeY = self:_getSizeFun(floor, kind)
        end
        if not self:isParentFold(i) then
            if oldLayout == NewTreeList.Layout.Gird then
                if layout == NewTreeList.Layout.Gird then
                    if oldPosX + spaceLeft + sizeX + padding.Right > self.width then
                        if aligment == NewTreeList.Alignment.Left then
                            self._indexToXPos[i] = spaceLeft + padding.Left
                            oldPosX = spaceLeft + sizeX + spaceRight + padding.Left
                        else
                            local widthSpace = (self.width+spaceRight-padding.Right-padding.Left)%(spaceLeft + sizeX + spaceRight)
                            if aligment == NewTreeList.Alignment.Center then
                                self._indexToXPos[i] = spaceLeft + padding.Left + widthSpace/2
                                oldPosX = spaceLeft + padding.Left + sizeX + spaceRight + widthSpace/2
                            elseif aligment == NewTreeList.Alignment.Right then
                                self._indexToXPos[i] = spaceLeft + widthSpace
                                oldPosX = spaceLeft + sizeX + spaceRight + widthSpace
                            end
                        end
                        local topPos
                        if oldfloor ~= floor then
                            topPos = oldPosY + oldGridSpace + spaceUp + padding.Top
                        else
                            topPos = oldPosY + oldGridSpace + spaceUp
                        end
                        self._indexToTopPos[i] = topPos
                        self._indexToBottomPos[i] = topPos + sizeY
                        oldPosY = topPos
                        oldGridSpace = spaceBottom + sizeY
                        totalLenght = oldPosY + sizeY
                    else
                        self._indexToXPos[i] = oldPosX + spaceLeft
                        self._indexToTopPos[i] = oldPosY
                        self._indexToBottomPos[i] = oldPosY + sizeY
                        oldPosX = oldPosX + spaceLeft + sizeX + spaceRight
                        oldGridSpace = math.max(oldGridSpace, (spaceBottom + sizeY))
                        totalLenght = math.max(totalLenght, oldPosY + sizeY)
                    end
                else
                    if aligment == NewTreeList.Alignment.Left then
                        self._indexToXPos[i] = padding.Left
                        oldPosX = padding.Left
                    elseif aligment == NewTreeList.Alignment.Center then
                        local tempWidth = self.width-padding.Left-padding.Right
                        self._indexToXPos[i] = tempWidth/2 - sizeX/2
                        oldPosX = tempWidth/2 - sizeX/2
                    elseif aligment == NewTreeList.Alignment.Right then
                        local tempWidth = self.width-padding.Left-padding.Right
                        self._indexToXPos[i] = tempWidth - sizeX
                        oldPosX = tempWidth - sizeX
                    end
                    local topPos
                    if oldfloor ~= floor then
                        topPos = oldPosY + oldGridSpace + spaceUp + padding.Top
                    else
                        topPos = oldPosY + oldGridSpace + spaceUp
                    end
                    self._indexToTopPos[i] = topPos
                    self._indexToBottomPos[i] = topPos + sizeY
                    oldPosY = topPos + sizeY + spaceBottom
                    oldGridSpace = 0
                    totalLenght = topPos + sizeY
                end
            else
                if layout == NewTreeList.Layout.Gird then
                    if aligment == NewTreeList.Alignment.Left then
                        self._indexToXPos[i] = spaceLeft + padding.Left
                        oldPosX = spaceLeft + padding.Left + sizeX + spaceRight
                    else
                        local widthSpace = (self.width+spaceRight-padding.Left-padding.Right)%(spaceLeft + sizeX + spaceRight)
                        if aligment == NewTreeList.Alignment.Center then
                            self._indexToXPos[i] = spaceLeft + padding.Left + widthSpace/2
                            oldPosX = spaceLeft + padding.Left + sizeX + spaceRight + widthSpace/2
                        elseif aligment == NewTreeList.Alignment.Right then
                            self._indexToXPos[i] = spaceLeft + padding.Left + widthSpace
                            oldPosX = spaceLeft + padding.Left + sizeX + spaceRight + widthSpace
                        end
                    end
                    local topPos
                    if oldfloor ~= floor then
                        topPos = oldPosY + spaceUp + padding.Top
                    else
                        topPos = oldPosY + spaceUp
                    end
                    self._indexToTopPos[i] = topPos
                    self._indexToBottomPos[i] = topPos + sizeY
                    oldPosY = topPos
                    oldGridSpace = spaceBottom + sizeY
                    totalLenght = topPos + sizeY
                else
                    if aligment == NewTreeList.Alignment.Left then
                        self._indexToXPos[i] = padding.Left
                        oldPosX = padding.Left
                    elseif aligment == NewTreeList.Alignment.Center then
                        local tempWidth = self.width-padding.Left-padding.Right
                        self._indexToXPos[i] = tempWidth/2 - sizeX/2
                        oldPosX = tempWidth/2 - sizeX/2
                    elseif aligment == NewTreeList.Alignment.Right then
                        local tempWidth = self.width-padding.Left-padding.Right
                        self._indexToXPos[i] = tempWidth - sizeX
                        oldPosX = tempWidth - sizeX
                    end
                    local topPos
                    if oldfloor ~= floor then
                        topPos = oldPosY + spaceUp + padding.Top
                    else
                        topPos = oldPosY + spaceUp
                    end
                    self._indexToTopPos[i] = topPos
                    self._indexToBottomPos[i] = topPos + sizeY
                    oldPosY = topPos + sizeY + spaceBottom
                    totalLenght = topPos + sizeY
                end
            end
            oldfloor = floor
            oldLayout = layout
            self._lastIndex = i
        else
            self._indexToXPos[i] = 0
            self._indexToTopPos[i] = -100
            self._indexToBottomPos[i] = -100
        end
    end

    self.length = totalLenght + self._padding.Top + self._padding.Bottom
    if self.bIsBottomFirst then
        if self.length < self.height then
            --未超过滑动框
            local offect = self.height - self.length
            for i, Pos in ipairs(self._indexToTopPos) do
                if Pos >= 0 then
                    self._indexToTopPos[i] = Pos + offect
                end
            end
            for i, Pos in ipairs(self._indexToBottomPos) do
                if Pos >= 0 then
                    self._indexToBottomPos[i] = Pos + offect
                end
            end
            self.length = self.height
        end
    end
    self.tempPos.X = self.width
    self.tempPos.Y = self.length
    --self.total = #self._foldMap
    self._diffPoint.Slot:SetPosition(self.tempPos)
    local offect = math.max(math.min(self.oldOffect, self.length - self.height), 0)

    if self.oldOffect > offect then
        --滑动框区域回缩了
        -- self._oldTop = #self._foldMap
        -- self._oldBottom = #self._foldMap
        self._oldTop = self.total
        self._oldBottom = self.total
    else
        --滑动框区域未变
        self._oldTop = 1
        self._oldBottom = 1
    end
    if self._cacheIdx then
        self:ScrollToIndex(self._cacheIdx)
        self._cacheIdx = nil
    else
        self:onUserScrolled(offect)
        self:getRoot():SetScrollOffset(offect)
    end
end

------------------------eventfunc------------------------
---@public 双击检测开关
---@param enabled boolean true开false关
function NewTreeList:EnableDoubleClick(enabled)
    self.doubleClickEnabled = enabled
end

---@public 右键检测开关
---@param enabled boolean true开false关
function NewTreeList:EnableRightClick(enabled)
    self.rightClickEnabled = enabled
end

---@private
function NewTreeList:onItemClicked(index, bIsRightClick)
    local r = self:GetRendererAt(index)
    -- local k = table.ikey(self.wigets, r)
    local id = r.userWidget:GetUniqueID()
    if self.blong[id] then return end
    if not self.doubleClickEnabled then
        self:onItemClickedex(index, bIsRightClick)
        return
    end
    local t = self.lastClickTimes[index]
    local name = self.timeName .. id
    if t then
        --- 双击
        self:StopTimer(name)
        self.lastClickTimes[index] = nil
        self:onItemDoubleClicked(index)
    else
        self.lastClickTimes[index] = _now()
        self:StartTimer(name, function()
            self.lastClickTimes[index] = nil
            self:onItemClickedex(index, bIsRightClick)
        end, Enum.EConstFloatData.DOUBLE_CLICK_INTERVAL, 1)
    end
end

--单选逻辑
function NewTreeList:onItemClickSingle(index, canSel, bIsRightClick)
    local toggle = self.toggle

    local bIsLeafNode = self._foldMap[index] == NewTreeList.Kind.Cell
    if self.selectedIndex and self.selectedIndex == index then
        local widget = self:GetRendererAt(index)
        if bIsLeafNode and toggle then
            if widget then
                self:callRefreshFun(self.owner, widget, index, false)
                --self:playAutoAni(index, false)
                self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
            end
            self.selectedIndex = -1
        end
        if widget then
            self:callOnClickFun(self.owner, widget, index, bIsRightClick)
        end
        return
    end
    local oldIndex = self.selectedIndex
    if bIsLeafNode and canSel and oldIndex and oldIndex > 0 then
        local widget = self:GetRendererAt(oldIndex)
        if widget then
            self:callRefreshFun(self.owner, widget, oldIndex, false)
            --self:playAutoAni(oldIndex, false)
            self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
        end
    end
    if bIsLeafNode and canSel then
        self.selectedIndex = index
    end
    local widget = self:GetRendererAt(index)
    if widget then
        if bIsLeafNode and canSel then
            self:callRefreshFun(self.owner, widget, index, true)
            --self:playAutoAni(index, true)
            self:PlayStateAnimation(index, ListAnimationLibrary.CellState.Select)
        end
        self:callOnClickFun(self.owner, widget, index, bIsRightClick)
    end
    -- if self.isMultiMenu and not bIsLeafNode then
    --     -- multiMenu（排行榜菜单
    --     local subWidget = self:GetRendererAt(index+1)
    --     if subWidget and self._foldMap[index+1] == NewTreeList.Kind.Cell then
    --         self:callOnClickFun(self.owner, subWidget, index+1, false)
    --     end
    -- end
end

function NewTreeList:onItemClickedex(index, bIsRightClick)
    local multi = self.multi
    local canSel
    local widget = self:GetRendererAt(index)
    if widget then
        canSel = self:callCanSelFun(widget, index)
    else
        canSel = false
    end

    if not multi then
        --只能单选的列表
        self:onItemClickSingle(index, canSel, bIsRightClick)
    else
        --可以多选的列表
        local bIsLeafNode = self._foldMap[index] == NewTreeList.Kind.Cell
        local selected = not self.selectedIndexs[index]
        if widget and bIsLeafNode then
            if canSel then
                self:callRefreshFun(self.owner, widget, index, selected)
                self.selectedIndexs[index] = selected
                --self:playAutoAni(index, selected)
                if selected then
                    self:PlayStateAnimation(index, ListAnimationLibrary.CellState.Select)
                else
                    self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
                end
            end
        end
        if canSel then
            self.selectedIndexs[index] = selected
        end
        if widget then
            self:callOnClickFun(self.owner, widget, index, bIsRightClick)
        end
    end
end

function NewTreeList:onItemDoubleClicked(index)
    local component = self:GetRendererAt(index)
    if component then
        self:callOnDoubleClickFun(component, index)
    end
end

---按下处理(区分长按与单击)
---@private
function NewTreeList:onItemPressed(index)
    -- Log.Warning("[ListView] OnPressed ", index)

    local component = self:GetRendererAt(index)
    -- local k = table.ikey(self.wigets, component)
    local id = component.userWidget:GetUniqueID()
    self.blong[id] = false
    local name = self.timePressName .. id
    self:StartTimer(name, function()
        -- Log.Warning("[ListView] onLongPress", index)
        self.blong[id] = true
        self:callOnLongPressFun(component, index)
    end, Enum.EConstFloatData.LONG_PRESS_TIME, 1)
end

function NewTreeList:onItemReleased(index)
    -- Log.Warning("[ListView] onItemReleased ", index)
    local component = self:GetRendererAt(index)
    if not component then return end
    local id = component.userWidget:GetUniqueID()
    local name = self.timePressName .. id
    self:StopTimer(name)
    self:callOnReleasedFun(component, index)
end


function NewTreeList:SetSingleToggle(bSingleToggle)
    if self.multi then
        self:SetMulti(false)
    end

    self.toggle = bSingleToggle

end

---设置滚动列表是否能多选
---@public
---@param multi bool
function NewTreeList:SetMulti(multi)
    if multi then
        local index = self.selectedIndex
        if index and index > 0 then
            local r = self:GetRendererAt(index)
            if r then
                self:callRefreshFun(self.owner, r, index, false)
                --self:playAutoAni(index, false)
                self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
            end
            self.selectedIndex = -1
        end
        table.clear(self.selectedIndexs)
    else
        for index, selected in next, self.selectedIndexs do
            if selected then
                local r = self:GetRendererAt(index)
                if r then
                    self:callRefreshFun(self.owner, r, index, false)
                    --self:playAutoAni(index, false)
                    self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
                end
            end
        end

        table.clear(self.selectedIndexs)
        self.selectedIndex = -1
    end
    self.multi = multi
end
---------------------------------------------------------
---获得第多少条数据对应哪个格子
---@public
function NewTreeList:GetRendererAt(index)
    return self._cells[index]
end

function NewTreeList:getIndex(index1, index2, index3, index4, index5)
    if not index1 then
        return -1
    end
    local index = self._indexMap[index1]
    if type(index) == "table" then
        if index2 then
            index = index[index2]
            if type(index) == "table" then
                if index3 then
                    index = index[index3]
                    if type(index) == "table" then
                        if index4 then
                            index = index[index4]
                            if type(index) == "table" then
                                if index5 then
                                    index = index[index5]
                                else
                                    index = index[0]
                                end
                            end
                        else
                            index = index[0]
                        end
                    end
                else
                    index = index[0]
                end
            end
        else
            index = index[0]
        end
    end
    if not index then
        return -1
    end
    return index
end

---@public 让滚动列表滚动到最上面
function NewTreeList:ScrollToBegin()
    if self.height == 0 then
        self.oldOffect = 0
        return
    end
    self:getRoot():SetScrollOffset(0)
    self:onUserScrolled(0)
end

---@public 让滚动列表瞬间滚动到第几条数据对应的格子
function NewTreeList:ScrollToIndex(...)
    local index = self:getIndex(...)
    if index < 0 then
        return
    end
    local offect = self._indexToTopPos[index] or 0
    offect = (offect > self.length - self.height) and (self.length - self.height) or offect
    if self.width == 0 or self.height == 0 then
        self._cacheIdx = index
        self.oldOffect = offect
        return
    end
    self:getRoot():SetScrollOffset(offect)
    self:onUserScrolled(offect)
end

---@public 选中第几个数据所在的格子，需要在按钮的click里去设置
---@param tIndex number 第几层
---@param gIndex number 当前层的第几个成员
function NewTreeList:Sel(...)
    if not self.multi then
        --单选
        local oldIndex = self.selectedIndex
        self.selectedIndex = -1
        if oldIndex >= 0 then
            local r = self:GetRendererAt(oldIndex)
            if r then
                self:callRefreshFun(self.owner, r, oldIndex, false)
                --self:playAutoAni(oldIndex, false)
                self:PlayStateAnimation(oldIndex, ListAnimationLibrary.CellState.UnSelect)
            end
        end
        local index = self:getIndex(...)
        if index < 0 then
            return
        end
        if index > self.total then return end
        if self.selectedIndex == index then return end
        local oldIndex = self.selectedIndex
        self.selectedIndex = index
        if oldIndex >= 0 then
            local widget = self:GetRendererAt(oldIndex)
            if widget then
                self:callRefreshFun(self.owner, widget, oldIndex, false)
                --self:playAutoAni(oldIndex, false)
                self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
            end
        end
        local widget = self:GetRendererAt(index)
        if widget then
            self:callRefreshFun(self.owner, widget, index, true)
            --self:playAutoAni(index, true)
            self:PlayStateAnimation(index, ListAnimationLibrary.CellState.Select)
        end
    else
        --多选
        local index = self:getIndex(...)
        if index < 0 then
            return
        end
        if index > self.total then return end
        local bIsLeafNode = self._foldMap[index] == NewTreeList.Kind.Cell
        --非叶子节点没有选中态，只有折叠态
        if not bIsLeafNode then return end
        self.selectedIndexs[index] = true
        local widget = self:GetRendererAt(index)
        if widget then
            self:callRefreshFun(self.owner, widget, index, true)
            --self:playAutoAni(index, true)
            self:PlayStateAnimation(index, ListAnimationLibrary.CellState.Select)
        end
    end
end

---@public 折叠第几层的第几组
---@param bFold boolean 是否折叠
function NewTreeList:Fold(bFold, index1, index2, index3, index4, index5)
    if self.isMultiMenu and not bFold then
        -- multiMenu需要满足同一时间只有一个页签展开
        self:getOrSetFold(true, self._currMenuUnfold)
        self:getOrSetFold(false, index1,index2,index3,index4,index5)
    else
        self:getOrSetFold(bFold, index1, index2, index3, index4, index5)
    end
    if self.isMultiMenu then
        if not bFold then
            self._currMenuUnfold = index1
        else
            self._currMenuUnfold = 0
        end
    end
    self:calculatePos()
end

---@public 取消当前选中 单选列表只能取消当前选中的，不用传参数，多选列表需要传取消选中的是哪一个
function NewTreeList:CancelSel(...)
    if not self.multi then
        --单选
        local oldIndex = self.selectedIndex
        if oldIndex > 0 then
            self.selectedIndex = -1
            local widget = self:GetRendererAt(oldIndex)
            if widget then
                self:callRefreshFun(self.owner, widget, oldIndex, false)
                --self:playAutoAni(oldIndex, false)
                self:PlayStateAnimation(oldIndex, ListAnimationLibrary.CellState.UnSelect)
            end
        end
    else
        --多选
        local index = self:getIndex(...)
        if index < 0 then
            return
        end
        if index > self.total then return end
        local bIsLeafNode = self._foldMap[index] == NewTreeList.Kind.Cell
        --非叶子节点没有选中态，只有折叠态
        if not bIsLeafNode then return end
        if not self.selectedIndexs[index] then return end
        self.selectedIndexs[index] = false
        local widget = self:GetRendererAt(index)
        if widget then
            self:callRefreshFun(self.owner, widget, index, false)
            --self:playAutoAni(index, false)
            self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
        end
    end
end

---@public 取消选中所有格子
function NewTreeList:CancelAllSel()
    if not self.multi then
        return self:CancelSel()
    else
        for index, bSelect in pairs(self.selectedIndexs) do
            if bSelect then
                local widget = self:GetRendererAt(index)
                if widget then
                    self:callRefreshFun(self.owner, widget, index, false)
                    --self:playAutoAni(index, false)
                    self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
                end
            end
        end
        table.clear(self.selectedIndexs)
    end
end

function NewTreeList:setCell(uiCell, index)
    if uiCell then
        local floor = self._floorMap[index]
        local kind = self._kindMap[index]
        if self.libWidget[floor][kind] then
            --formcomponent
            --self.owner:AddObjectNum(-UIHelper.GetObjectNum(uiCell.userWidget))
            local btn = self:getAutoButton(uiCell)
            if btn then
                self:RemoveUIListener(_G.EUIEventTypes.CLICK, btn)
                self:RemoveUIListener(_G.EUIEventTypes.Pressed, btn)
                self:RemoveUIListener(_G.EUIEventTypes.Released, btn)
                self:RemoveUIListener(_G.EUIEventTypes.RightClick, btn)
            end
            uiCell.parentUI = nil
            self:PushOneComponent(self._panel, uiCell)
        else
            --createwidget
            local uiCells = self.uiCells[floor][kind]
            uiCells[#uiCells+1] = uiCell
            uiCell:Hide()
            uiCell:Close()
        end
    end
end

function NewTreeList:getAutoButton(uiComponent)
    local btn
    if self.buttonPath then
        btn = uiComponent.view
        for key, value in pairs(self.buttonPath) do
            btn = btn[value]
            if not btn then
                break
            end
        end
    end
    if not btn then
		if uiComponent.view.Btn_ClickArea_lua then
			btn = uiComponent.view.Btn_ClickArea_lua
		end
		if not btn and uiComponent.view.Btn_ClickArea then
			btn = uiComponent.view.Btn_ClickArea
		end
		if not btn and uiComponent.view.Big_Button_ClickArea_lua then
			btn = uiComponent.view.Big_Button_ClickArea_lua
		end
    end
    return btn
end

function NewTreeList:addClickListener(uiComponent)
    --todo 后续wbp里命名都统一成Btn_ClickArea，目前为了防止旧资源报错，先加上保护措施
    local btn = self:getAutoButton(uiComponent)
    if btn then
        uiComponent:AddUIEvent( btn.OnClicked, "OnItemClick")
        uiComponent:AddUIEvent( btn.C7OnRightClicked, "OnItemRightClick")
        -- self:AddUIListener(_G.EUIEventTypes.CLICK, btn, "HandleItemClicked", uiComponent)
        -- self:AddUIListener(_G.EUIEventTypes.RightClick, btn, "HandleItemClicked", uiComponent, true)
        --TODO::
        if not self.timePressName then
            self.timePressName = self.timeName .. "Press"
        end
        uiComponent:AddUIEvent(btn.OnPressed, "OnItemPressed")
        -- self:AddUIListener(_G.EUIEventTypes.Pressed, btn, function()
        --     self:onItemPressed(self.cellIndexs[uiComponent])
        -- end)
        uiComponent:AddUIEvent(btn.OnReleased, "OnItemReleased")

        -- self:AddUIListener(_G.EUIEventTypes.Released, btn, function()
        --     self:onItemReleased(self.cellIndexs[uiComponent])
        -- end)
    end
end

function NewTreeList:getFloorAndKind(index)
    local floor = self._floorMap[index]
    local kind = self._kindMap[index]
    return floor, kind
end

function NewTreeList:getParent(index)
    return self._parentMap[index]
end

function NewTreeList:getGroupIndex(index)
    return self._groupMap[index]
end

---@private 得到滚动列表里的组件
---@param widget  滚动列表组件
---@param index 第多少个
---@return UIController
function NewTreeList:getCell(index)
    -- local kind = self._foldMap[index]
    -- if not kind then
    --     Log.Error("Error List Kind")
    --     return
    -- end
    local floor = self._floorMap[index]
    if not floor then
        Log.Warning("Error List Level")
        return
    end
    local kind = self._kindMap[index]
    local uiComponent
    if self.libWidget[floor][kind] then
        --formcomponent
        local libWidget = self.libWidget[floor][kind]
        uiComponent = self:FormComponent(libWidget[1], self._panel, self.cell[floor][kind])
        uiComponent.userWidget.Slot:SetAutoSize(false)
        uiComponent.userWidget.Slot:SetAnchors(self._defaultAnchors)
        self.tempPos.X = 0
        self.tempPos.Y = 0
        uiComponent.userWidget.Slot:SetAlignment(self.tempPos)
        self.tempPos.X = libWidget[2]
        self.tempPos.Y = libWidget[3]
        uiComponent.userWidget.Slot:SetSize(self.tempPos)
        self:addClickListener(uiComponent)
        --self.owner:AddObjectNum(UIHelper.GetObjectNum(uiComponent.userWidget))
    else
        --createwidget
        local uiCells = self.uiCells[floor][kind]
        if #uiCells > 0 then
            uiComponent = uiCells[#uiCells]
            uiCells[#uiCells] = nil
            local sizeX, sizeY
            if self.onGetWidgetSizeFunCB then
                sizeX, sizeY = self.owner[self.onGetWidgetSizeFunCB](self.owner, self:getAllIndex(index))
                if (not sizeX) or (not sizeY) then
                    sizeX, sizeY = self:_getSizeFun(floor, kind)
                end
            else
                sizeX, sizeY = self:_getSizeFun(floor, kind)
            end
            local size = uiComponent.userWidget.Slot:GetSize()
            self.tempPos.X = size.X
            self.tempPos.Y = sizeY
            uiComponent.userWidget.Slot:SetSize(self.tempPos)
        else
            if self.bIsAsync then
                if self._tempAsyncNum <= 0 then
                    return
                end
                self._tempAsyncNum = self._tempAsyncNum - 1
            end
            local template = self.template[floor][kind]
            local widget = import("UIFunctionLibrary").C7CreateWidget(self.owner.userWidget, self._panel, template)
            --self.refItems[#self.refItems+1] = UnLua.Ref(widget)
            self.rawItems[#self.rawItems+1] = widget
            widget.Slot:SetAnchors(template.Slot:GetAnchors())
            widget.Slot:SetAlignment(template.Slot:GetAlignment())
            local sizeX, sizeY
            if self.onGetWidgetSizeFunCB then
                sizeX, sizeY = self.owner[self.onGetWidgetSizeFunCB](self.owner, self:getAllIndex(index))
                if (not sizeX) or (not sizeY) then
                    sizeX, sizeY = self:_getSizeFun(floor, kind)
                end
            else
                sizeX, sizeY = self:_getSizeFun(floor, kind)
            end
            local size = template.Slot:GetSize()
            self.tempPos.X = size.X
            self.tempPos.Y = sizeY
            widget.Slot:SetSize(self.tempPos)
            uiComponent = self:CreateComponent(widget,self.cell[floor][kind])
            self:addClickListener(uiComponent)
            if uiComponent.UpdateObjectNum then
                uiComponent:UpdateObjectNum(UIHelper.GetObjectNum(widget))
            end
        end
    end
    self.tempPos.X = self._indexToXPos[index]
    self.tempPos.Y = self._indexToTopPos[index]
    uiComponent.userWidget.Slot:SetPosition(self.tempPos)
    --AniCheck
    return uiComponent
    -- ---@type UIComponent
    -- local uiCell = self.uiCells[widget]
    -- if uiCell then
    --     return uiCell, self.cell[level][kind]
    -- end
    -- self.uiCells[widget] = uiCell

    -- table.insert(self.wigets, uiCell)
    -- return uiCell, self.cell[level][kind]
end

---@public 设置滚动列表是否开启禁止过度滚动
---@param newAllowOverscroll boolean true允许过度滚动，false不允许过度滚动
function NewTreeList:SetAllowOverscroll(newAllowOverscroll)
    return self:getRoot():SetAllowOverscroll(newAllowOverscroll)
end

---@屏幕分辨率变化
function NewTreeList:OnViewportResize()
    self.bMarkViewportResize = true
    if self.bEnable then
        self:UpdateSize()
    end
end

function NewTreeList:OnOpen()
    -- for i = self._topIndex, self._bottomIndex do
    --     local kind = self._kindMap[i]
    --     if self.cell[kind] then
    --         local cell = self._cells[i]
    --         if cell then
    --             cell:Show()
    --             cell:Open()
    --         end
    --     end
    -- end
    for index, cell in pairs(self._cells) do
        cell:Show()
        cell:Open()
    end
    self.bEnable = true
    if self.bMarkViewportResize then
        self:UpdateSize()
    end
end

---list容器只处理子Component的Show和Hide,不处理OnRefresh
function NewTreeList:OnRefresh()
end

function NewTreeList:OnClose()
    self.bEnable = false
    self.aniNotified = nil
    self.aniSetData = nil
    table.clear(self.lastClickTimes)
    -- for i = self._topIndex, self._bottomIndex do
    --     local kind = self._kindMap[i]
    --     if self.cell[kind] then
    --         local cell = self._cells[i]
    --         if cell then
    --             cell:Hide()
    --             cell:Close()
    --         end
    --     end
    -- end
    for index, cell in pairs(self._cells) do
        cell:Hide()
        cell:Close()
    end
end

function NewTreeList:OnDestroy()
    self:clearCell()
    -- for floor, tab in pairs(self.uiCells) do
    --     for kind, uiCells in pairs(tab) do
    --         for _, uiCell in pairs(uiCells) do
    --             self:UnbindListComponent(uiCell.userWidget)
    --         end
    --     end
    -- end
    self.uiCells = nil
    self._cells = nil
    self.cellIndexs = nil
    -- table.clear(self.wigets)
    self.tempPos = nil
    -- for floor = 1, self.floor do
    --     local items = self.template[floor]
    --     for kind, widgets in pairs(items) do
    --         for index = 1, #widgets do
    --             local widget = widgets[index]
    --             UnLua.Unref(widget)
    --         end
    --     end
    -- end
    self.template = nil
    --for _, refWidget in pairs(self.rawItems) do
    --    UnLua.Unref(refWidget)
    --end
    self.rawItems = nil
    self.refItems = nil
    self.onStartIndexChangedCB = nil
    self.owner = nil
    self.aniComp = nil
end

---@public 如果对应的格子在显示就执行Refresh方法刷新此格子
---@param tIndex number 第几层
---@param gIndex number 第几层的第几个
function NewTreeList:RefreshCell(...)
    local index = self:getIndex(...)
    if index < 1 then index = 1 end
    if index > self.total then
        index = self.total
    end
    local r = self:GetRendererAt(index)
    if r then
        self:callRefreshFun(self.owner, r, index)
    end
end

function NewTreeList:IsLeafNode(...)
    local index = self:getIndex(...)
    return self._foldMap[index] == NewTreeList.Kind.Cell
end

function NewTreeList:FoldAll(value, index1, index2, index3, index4, index5)
    local foldSwitch = self.foldSwitch
    local _foldSwitch
    if index1 then
        _foldSwitch = foldSwitch[index1]
        if not _foldSwitch then return end
        if type(_foldSwitch) ~= "table" then
            return self:getOrSetFold(value, index1)
        end
        foldSwitch = _foldSwitch
        if index2 then
            _foldSwitch = foldSwitch[index2]
            if not _foldSwitch then return end
            if type(_foldSwitch) ~= "table" then
                return self:getOrSetFold(value, index1, index2)
            end
            foldSwitch = _foldSwitch
            if index3 then
                _foldSwitch = foldSwitch[index3]
                if not _foldSwitch then return end
                if type(_foldSwitch) ~= "table" then
                    return self:getOrSetFold(value, index1, index2, index3)
                end
                foldSwitch = _foldSwitch
                if index4 then
                    _foldSwitch = foldSwitch[index4]
                    if not _foldSwitch then return end
                    if type(_foldSwitch) ~= "table" then
                        return self:getOrSetFold(value, index1, index2, index3, index4)
                    end
                    foldSwitch = _foldSwitch
                    if index5 then
                        _foldSwitch = foldSwitch[index5]
                        if not _foldSwitch then return end
                        if type(_foldSwitch) ~= "table" then
                            return self:getOrSetFold(value, index1, index2, index3, index4, index5)
                        end
                        foldSwitch = _foldSwitch
                    end
                end
            end
        end
    end
    if foldSwitch then
        for index, _foldSwitch in pairs(foldSwitch) do
            if type(_foldSwitch) == "table" then
                _foldSwitch[0] = value
            else
                foldSwitch[index] = value
            end
        end
        self:calculatePos()
    end
end

--单选
function NewTreeList:hasSingleSelect(index1, index2, index3, index4, index5)
    if not index1 then
        return self.selectedIndex ~= -1
    end
    if self.selectedIndex and self.selectedIndex > 0 then
        local _index1, _index2, _index3, _index4, _index5 = self:getAllIndex(self.selectedIndex)
        if index1 then
            if index1 ~= _index1 then return false end
            if index2 then
                if index2 ~= _index2 then return false end
                if index3 then
                    if index3 ~= _index3 then return false end
                    if index4 then
                        if index4 ~= _index4 then return false end
                        if index5 then return index5 == _index5 end
                    else
                        return true
                    end
                else
                    return true
                end
            else
                return true
            end
        end
    end
end

function NewTreeList:checkMultiSelect(minIndex, maxIndex)
    for index, bSelected in pairs(self.selectedIndexs) do
        if index >= minIndex and index < maxIndex and bSelected then
            return true
        end
    end
    return false
end

function NewTreeList:hasMultiSelect(index1, index2, index3, index4, index5)
    if not index1 then
        for index, bSelected in pairs(self.selectedIndexs) do
            if bSelected then
                return true
            end
        end
        return false
    end
    local minIndex, maxIndex
    if not index2 then
        minIndex = self:getIndex(index1)
        maxIndex = self:getIndex(index1+1)
    elseif not index3 then
        minIndex = self:getIndex(index1, index2)
        maxIndex = self:getIndex(index1, index2+1)
    elseif not index4 then
        minIndex = self:getIndex(index1, index2, index3)
        maxIndex = self:getIndex(index1, index2, index3+1)
    elseif not index5 then
        minIndex = self:getIndex(index1, index2, index3, index4)
        maxIndex = self:getIndex(index1, index2, index3, index4+1)
    end
    if maxIndex == -1 then
        maxIndex = self.total
    end
    return self:checkMultiSelect(minIndex, maxIndex)
end

---获得选中的数据
---@public
---@return boolean 是否有选中
function NewTreeList:HasSelect(...)
    if not self.multi then
        --单选
        return self:hasSingleSelect(...)
    else
        --多选
        return self:hasMultiSelect(...)
    end
end

function NewTreeList:isSeleceted(index)
    if not self.multi then
        return index == self.selectedIndex
    else
        return self.selectedIndexs[index]
    end
end

function NewTreeList:getMultiSelected(index)
    local index1, index2, index3, index4, index5 = self:getAllIndex(index)
    if not index2 then
        return index1
    end
    return {index1, index2, index3, index4, index5}
end

---获得选中的数据
---@public
---@return table 选中的数据
function NewTreeList:GetSelectedIndex(outData)
    if not self.multi then
        if self.selectedIndex <= 0 then
            return
        end
        return self:getAllIndex(self.selectedIndex)
    end
    local allSelected = outData or {}
    for index, bSelected in next, self.selectedIndexs do
        if bSelected then
            table.insert(allSelected, self:getMultiSelected(index))
        end
    end
    return allSelected
end

---@public 重新刷新ListPanel大小，会触发List更新位置
function NewTreeList:UpdateSize()
    if self.reSizeCount > 10 then
        self.reSizeCount = 0
    end
    self:StartTimer("REFRESH_HIERARCHYLIST_UPDATE_SIZE_NEW", function()
        local size = self.getLocalSizeFun(self.getCachedGeometryFun(self:getRoot()))
        self.reSizeCount = self.reSizeCount + 1
        if size.X == self.width and size.Y == self.height and self.reSizeCount < 10 then
            return self:UpdateSize()
        end
        self.reSizeCount = self.reSizeCount + 1
        self.bMarkViewportResize = nil
        self.width = size.X
        self.height = size.Y
        self:calculatePos()
    end, 1, 1)
end

---重新计算cell的高度、宽度
function NewTreeList:ReSize()
    self:calculatePos()
end

function NewTreeList:GetTopIndex()
    return self._topIndex
end 

function NewTreeList:GetBottomIndex()
    return self._bottomIndex
end 

function NewTreeList:LockScroll(bLock)
    if bLock then
        self:getRoot():SetVisibility(ESlateVisibility.HitTestInvisible)
    else
        self:getRoot():SetVisibility(ESlateVisibility.Visible)
    end
end

--加载全部动画配置
function NewTreeList:InitListAnimationData()
    if self.animations:Num() > 0 then
        local cmp = TreeListAniComp.new(self)
        self.aniComp = cmp
        for key, cfg in pairs(self.animations) do
            self.aniComp:AddAnimationConfig(key, cfg)
            self:EnableAutoAnimation(key, "WidgetRoot")
        end
    end
end

function NewTreeList:onNotifyPlayListAnimation(index)
    if self.total > 0 and next(self._cells) then
        self.aniNotified = index
        self:getRoot():EndInertialScrolling()
        self:PlayListGroupAnimation(self.aniNotified)
        self.aniSetData = nil
        self.aniNotified = nil
    else
        self.aniNotified = index
    end
    
end
--播放入场动画
function NewTreeList:playListInAnimation()
    if (self.aniSetData and self:checkAnimationConfig(self.aniSetData)) or self:checkAnimationConfig(self.aniNotified) then
        self:getRoot():EndInertialScrolling()
        self:PlayListGroupAnimation(self.aniNotified or self.aniSetData)
        self.aniSetData = nil
        self.aniNotified = nil
    end
end

function NewTreeList:checkAnimationConfig(configIdx, isAniNotify)
    if not isAniNotify and not self.aniSetData then
        return false
    end
    if not self._cells or not next(self._cells) then
        return false
    end
    return true
end

function NewTreeList:PlayListGroupAnimation(key, cells, callback)
    if self.aniComp then
        if not cells then
            cells = {}
            for i = self._topIndex, self._bottomIndex, 1 do
                if self._cells[i] then
                    table.insert(cells, {index = i})
                end
            end
            if #cells > 0 then
                self.aniComp:PlayListGroupAnimation(key, cells, callback)
            end
        else
            self.aniComp:PlayListGroupAnimation(key, cells, callback)    
        end
    end
end

function NewTreeList:EnableAutoAnimation(key, widget)
    if self.aniComp then
        self.aniComp:EnableAutoAnimation(key, widget)
    end
end

function NewTreeList:DisableAutoAnimation(key, widget)
    if self.aniComp then
        self.aniComp:DisableAutoAnimation(key, widget)
    end
end

function NewTreeList:PlayStateAnimation(index, state)
    if self.aniComp then
        self.aniComp:PlayStateAnimation(index, state)
    end

end

function NewTreeList:onRefreshItem(index, bSelected)
    if self.aniComp then
        self.aniComp:RefreshCellUpdateAni(index, bSelected)
    end
end

function NewTreeList:onSetCell(index)
    if self.aniComp then
        self.aniComp:setCellUpdateAni(index)
    end
end

return NewTreeList