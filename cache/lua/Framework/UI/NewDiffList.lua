local ford_005_6200501_10038025 = require("Data.Config.Dialogue.Ford_005_6200501_10038025")
local NewDiffList = DefineClass("NewDiffList", BaseList)
local ESlateVisibility = import("ESlateVisibility")
local TreeListAniComp = kg_require("Framework.UI.List.ListComponents.TreeListAnimationComponent")



---@class NewDiffList.Kind
NewDiffList.Kind = {
    Title = 1,
    Cell = 2,
}

---@class NewDiffList.Layout
NewDiffList.Layout = {
    List = 0, --行布局
    Gird = 1, --格子布局
}


---@class NewDiffList.Alignment
NewDiffList.Alignment = {
    Left = 0,
    Center = 1,
    Right = 2,
}

---@class NewDiffList.SelectionMode
NewDiffList.SelectionMode = {
    Single = 1, --单选
    SingleToggle = 2, --单项勾选（重复点击取消选中）
    Multi = 3 --多选
}

function NewDiffList.SetUpFade(self)
    self.View.WidgetRoot:SetSlateRectFadePositionByFloat(0, 0.1, 1.0, 1.0)
    self.View.WidgetRoot:SetSlateRectFadeSizeByFloat(0, 0.08)
end

function NewDiffList.SetDownFade(self)
    self.View.WidgetRoot:SetSlateRectFadePositionByFloat(0, 0.0, 1.0, 0.9)
    self.View.WidgetRoot:SetSlateRectFadeSizeByFloat(0, 0.08)
end

function NewDiffList.CancelFade(self)
    self.View.WidgetRoot:SetSlateRectFadePositionByFloat(0, 0, 0, 0.0)
    self.View.WidgetRoot:SetSlateRectFadeSizeByFloat(0, 0)
end

function NewDiffList.SetBothFade(self)
    self.View.WidgetRoot:SetSlateRectFadePositionByFloat(0, 0.1, 1.0, 0.9)
    self.View.WidgetRoot:SetSlateRectFadeSizeByFloat(0, 0.08)
end
function NewDiffList.OnCreate(self, name, cells, parentAction, buttonPath, bIsAsync, asyncNum)
    self.doubleClickEnabled = false
    self.rightClickEnabled = false
    self.owner = self.parentScript --所属UI

    self.doubleClickEnabled = false
    self.rightClickEnabled = false
    self.owner = self.parentScript --所属UI
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
    self.name = name
    self.names = {}
	self.parentFirst = parentAction
    if buttonPath then
        self.buttonPath = string.split(buttonPath, ".")
    end
    self.uiCells = {}

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

    ---@type number 记录需要滚动的index
    self._cacheIdx = nil

    self.timeName = string.format("%s%s", self.parentScript.__cname, self.name)  --定时器名字固定前缀
    self.timePressName = nil
    
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


    self._indexToTopPos = {}
    self._indexToBottomPos = {}
    self._indexToXPos = {}
    self._padding = {}

    --间隔
    self.space = {}
    self.alignment = {}
    --选中模式
    local selectionMode = self.View.SelectionMode
    self.toggle = selectionMode == ComList.SelectionMode.SingleToggle
    self.multi = selectionMode == ComList.SelectionMode.SingleToggle
    --多层菜单（排行榜
    self.isMultiMenu = self.View.IsMultiMenu

    self.length = 0
    self.width = 0
    self.height = 0

    --UObject数量统计
    self.oneObjNums = {}

    --Refresh安全锁，防止在Refresh过程中SetData
    self.isRefreshing = false


    self.onStartIndexChangedCB = string.format("%s%s", name, "_OnStartIndexChanged")
    self.onGetWidgetSizeFunCB = nil
    self.onGetWidgetKindFunCB = nil
    --RetainerBox
    self.retainerBox = self.View.RetainerBox
    if self.retainerBox then
        self.retainerBox:SetRetainRendering(false)
    end
    self.retainerBoxMaxValueDown = self.View.MaxValueDown
    self.retainerBoxMaxValueUp = self.View.MaxValueUp
    
    self:SetDownFade()
   

    self.bEndFlag = false
    self.bStartFlag = false
    self.onScrollToEndCB = nil
    self.tempPos = FVector2D()

    self:bindAllWidget()
    self._panel = self.View.DiffPanel
    self._diffPoint = self.View.DiffPoint

    self.startIndex = 1

    self:AddUIListener(EUIEventTypes.UserScrolled, self:getRoot(), self.checkPosUpdate)
    --self:AddUIListener(EUIEventTypes.OnAnimationNotify, self.View.WidgetRoot, self.onNotifyPlayAnimation)
    self.View.ListPlayAnimation:Add(
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
    --需要监听屏幕分辨率更新
    Game.EventSystem:AddListener(_G.EEventTypes.ON_VIEWPORT_RESIZED, self, self.OnViewportResize)

    --列表动画
    self.aniComp = nil
    self.animations = self.View.Animation
    --需要播放进入动画
    self.aniSetData = nil
    self.aniNotified = nil

    self:InitListAnimationData()

    self.updateFlags = {}
    self.defaultGap = 100
    self.inited = false
    self.datas = nil

    local methodName = "OnRefresh_" .. name
    local callback = self.parentScript[methodName]
    -- if not callback then
    --     Log.Error("[UI] Cannot Find Lua Function For UIEvent, ", methodName, " in ui ", self.parentScript.__cname)
    --     return
    -- end
    self:AddSafeRefreshFun(callback)
    --主动绑定OnClick_List事件，没有方法不绑定，OnClick_List方法定义参考前面注释
    local onClick = self.parentScript["OnClick_" .. name]
    self.onClick = onClick  -- luacheck: ignore
    local canSel = self.parentScript["CanSel_" .. name]
    self.canSel = canSel

    local onDoubleClick = self.parentScript["OnDoubleClick_" .. name]
    if onDoubleClick then
        self.onDoubleClick = onDoubleClick
    end

    local onLongPress = self.parentScript["OnLongPress_" .. name]
    if onLongPress then
        self.onLongPress = onLongPress
    end

    --回收缓存
    self.setCellCache = {}
    --添加/删除队列
    self.cellUpdateQueue = {}
    self.addCache = {}
    self.removeCache = {}
end

function NewDiffList:getRoot()
    return self.View.List
end

function NewDiffList:getSpace(kind)
    
    if not self.space[kind] then
        return 0,0,0,0
    end
    local space = self.space[kind]
    return space[1],space[2],space[3],space[4]
end

function NewDiffList:bindAllWidget()
    local structure = self.View.Widgets
    local listPadding = self.View.ListPadding
    local libWidget
    local widget
    local itemName
    local data

    self._padding = {
        Left = listPadding.Left,
        Top = listPadding.Top,
        Right = listPadding.Right,
        Bottom = listPadding.Bottom,
    }
    for kind = 1, structure:Num(), 1 do
        data = structure:Get(kind-1)
        libWidget = data.LibWidget
        self.uiCells[kind] = {}
        
        self.template[kind] = {}
        self.layout[kind] = {}
        self.names[kind] = {}
        self.space[kind] = {}
        self.alignment[kind] = {}
        self.oneObjNums[kind] = {}

        if libWidget.libName ~= "" then
            local name = libWidget.libName
            self.libWidget[kind] = {name, libWidget.sizeX, libWidget.sizeY}
            itemName = name
        else
            widget = data.ScrollWidget
            widget:SetVisibility(ESlateVisibility.Hidden)
            itemName = widget:GetName()
            self.template[kind] = widget
            self.oneObjNums[kind] = UIHelper.GetObjectNum(widget)
        end
        self.names[kind] = string.format("%s%s%s%s", self.name, "_", itemName, "_")
        
        self.space[kind] = {
            data.Space.SpaceUp,
            data.Space.SpaceBottom,
            data.Space.SpaceLeft,
            data.Space.SpaceRight
        }
    
        self.alignment[kind] = data.Alignment
    end
   
end

function NewDiffList:SetDiffSizeFun(funcName)
    if self.owner[funcName] then
        self.onGetWidgetSizeFunCB = funcName
    end
end
function NewDiffList:SetDiffKindFun(funcName)
    if self.owner[funcName] then
        self.onGetWidgetKindFunCB = funcName
    end
end

function NewDiffList:getCellKind(index)
    local kind
    if self.updateFlags[index] or not self._kindMap[index] then
        if self.onGetWidgetKindFunCB then
            kind = self.owner[self.onGetWidgetKindFunCB](self.owner, index)
        end
        
        if not kind then
            kind = 1
        end
        self._kindMap[index] = kind
        return kind
    else
        return self._kindMap[index]
    end
end

function NewDiffList:SetScrollToEndListener(funcName)
    if self.owner[funcName] then
        self.onScrollToEndCB = funcName
    end
end

function NewDiffList:getCellIndex(cell)
    return self.cellIndexs[cell]
end

function NewDiffList:SetBottomFirst(bIsBottomFirst)
    self.bIsBottomFirst = bIsBottomFirst
end


function NewDiffList:AddSafeRefreshFun(Callback)
    if not Callback then
        self.callback = nil
        return
    end
    self.callback = function(...)
        self.isRefreshing = true
        xpcall(Callback, function (...)
            _G.CallBackError(...)
            self.isRefreshing = false
        end, ...)
        self.isRefreshing = false
    end
end

function NewDiffList:RemoveSafeRefreshFun()
    return self.callback
end

function NewDiffList:HandleItemClicked(uiCell, bIsRightClick)
    if bIsRightClick and not self.rightClickEnabled then
        return
    end
    self:onItemClicked(self.cellIndexs[uiCell], bIsRightClick)
end


function NewDiffList:callRefreshFun(owner, component, index, bIsSelect)
    Log.Debug("CallRefresh", index)
    if bIsSelect == nil then
        if self.multi then
            bIsSelect = self.selectedIndexs[index]
        else
            bIsSelect = self.selectedIndex == index
        end
    end
    local kind = self:getCellKind(index)
    if self.cell[kind] and component.OnListRefresh and not self.parentFirst then
        self.isRefreshing = true
       
        xpcall(component.OnListRefresh, function (...)
            _G.CallBackError(...)
            self.isRefreshing = false
        end, component, self.owner, bIsSelect, self.datas, index)
        self.isRefreshing = false
        self:onRefreshItem(index, bIsSelect)
    elseif self.callback then
        self.callback(self.owner, component, index, bIsSelect)
        self:onRefreshItem(index, bIsSelect)
    end
end

function NewDiffList:callOnClickFun(owner, component, index, bIsRightClick)
    local kind = self:getCellKind(index)
    if self.cell[kind] and bIsRightClick and component.OnRightClick then
        component:OnRightClick(self.owner, self.datas, index)
    elseif self.cell[kind] and component.OnClick then
        component:OnClick(self.owner, self.datas, index)
    elseif self.onClick then
        self.onClick(self.owner, component, index)
    end
end

---@private 调用CanSelcallback,能否选中回调
function NewDiffList:callCanSelFun(component, index)
    local kind = self:getCellKind(index)
    if self.cell[kind] and component.CanSel then
        return component:CanSel(self.owner, self.datas, index)
    elseif self.canSel then
        return self.canSel(self.owner, index)
    else
        return true
    end
end

---@private 调用OnDoubleCcallback,双击事件回调
function NewDiffList:callOnDoubleClickFun(component, index)
    local kind = self:getCellKind(index)
    if self.cell[kind] and component.OnDoubleClick then
        component:OnDoubleClick(self.owner, self.datas, index)
    elseif self.onDoubleClick then
        self.onDoubleClick(self.owner,component,index)
    end
end

---@private 调用OnLongPresscallback,长按事件回调
function NewDiffList:callOnLongPressFun(component, index)
    local kind = self:getCellKind(index)
    if self.cell[kind] and component.OnLongPress then
        component:OnLongPress(self.owner, self.datas, index)
    elseif self.onLongPress then
        self.onLongPress(self.owner, component, index)
    end
end

---@private 调用OnReleasedcallback,按下释放回调
function NewDiffList:callOnReleasedFun(component, index)
    local kind = self:getCellKind(index)
    if self.cell[kind] and component.OnReleased then
        component:OnReleased(self.owner, self.datas, index)
    end
end

--TODO：临时解决方案，暂时无法获取panel的准确大小
function NewDiffList:getSize()
    local vis = self.View.WidgetRoot:GetVisibility()
    if vis == ESlateVisibility.Collapsed or vis == ESlateVisibility.Hidden then
        return 
    end
    self:StartTimer("REFRESH_HIERARCHYLIST", function()
        local size = self.getLocalSizeFun(self.getCachedGeometryFun(self:getRoot()))
        if size.X == 0 or size.Y == 0 then
            return self:getSize()
        end
        self.width = size.X
        self.height = size.Y
        if self.total > 0 then
            
           
        for i = 1, self.total, 1 do
            self.updateFlags[i] = true
        end
        if self._cacheIdx then
            self:checkPosUpdate(self.oldOffect, self._cacheIdx)
        else
            self:checkPosUpdate(self.oldOffect, self._topIndex)
        end
            
            
        end
    end, 1, 1)
end

function NewDiffList:onUserScrolled(currentOffset)
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
    local indexToTopPos = self._indexToTopPos
    local indexToBottomPos = self._indexToBottomPos
    local top = currentOffset
    local bottom = currentOffset + self.height
    if indexToTopPos[1] and top <= indexToTopPos[1] and not self.updateFlags[1] then
        self._topIndex = 1
    else
        for i = self._oldTop, limit, step do
            if indexToTopPos[i] and indexToTopPos[i] ~= -100 and not self.updateFlags[i] then
                local bMiddle = top >= indexToTopPos[i] and top < indexToBottomPos[i]
                local bSpace = false
                if indexToBottomPos[i + 1] then
                    if top < indexToTopPos[i + 1] and top >= indexToBottomPos[i] then
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
    local _indexToTopPos = indexToTopPos[self._topIndex]
    if step > 0 then
        for i = self._topIndex, reLimit, -step do
            if _indexToTopPos == indexToTopPos[i] and not self.updateFlags[i] then
                self._topIndex = i
            else
                break
            end
        end
    else
        for i = self._topIndex, limit, step do
            if _indexToTopPos == indexToTopPos[i] and not self.updateFlags[i] then
                self._topIndex = i
            else
                break
            end
        end
    end

    if (not self._lastIndex) or (not indexToBottomPos[self._lastIndex]) then
        Log.WarningFormat("TreeList BottomPos Index error, indexToBottomPos Count:: %s, lastIndex:: %s",
            #indexToBottomPos, self._lastIndex or "nil")
    end
    if self._lastIndex and indexToBottomPos[self._lastIndex] and indexToBottomPos[self._lastIndex] <= bottom and not self.updateFlags[self._lastIndex] then
        self._bottomIndex = self._lastIndex
    else
        for i = self._oldBottom, limit, step do
            if indexToTopPos[i] and indexToTopPos[i] ~= -100 and not self.updateFlags[i] then
                local bMiddle = bottom >= indexToTopPos[i] and bottom < indexToBottomPos[i]
                local bSpace = false
                if indexToTopPos[i - 1] then
                    if bottom < indexToTopPos[i] and bottom >= indexToBottomPos[i - 1] then
                        bSpace = true
                    end
                end
                if bMiddle or bSpace then
                    self._bottomIndex = i
                    break
                end
            end
        end
        _indexToTopPos = indexToTopPos[self._bottomIndex]
        if step < 0 then
            for i = self._bottomIndex, reLimit, -step do
                if _indexToTopPos == indexToTopPos[i] and not self.updateFlags[i] then
                    self._bottomIndex = i
                else
                    break
                end
            end
        else
            for i = self._bottomIndex, limit, step do
                if _indexToTopPos == indexToTopPos[i] and not self.updateFlags[i] then
                    self._bottomIndex = i
                else
                    break
                end
            end
        end
    end
    self.oldOffect = currentOffset
    if self.updateFlags[self._topIndex] then
        self:checkPosUpdate(self.oldOffect,self._topIndex)

    end
    self:checkRefresh(step > 0)
end

function NewDiffList:checkRefresh(bUp)
    local cells = self._cells
    local cell
    local cellIdxs = self.cellIndexs
    --先回收
    if bUp then
        if self._topIndex ~= self._oldTop then
            for i = self._oldTop, self._topIndex - 1 do
                cell = cells[i]
                if cell then
                    cellIdxs[cell] = nil
                end
                self:setCell(cell, i)
                cells[i] = nil
            end
        end
    else
        if self._bottomIndex ~= self._oldBottom then
            for i = self._bottomIndex + 1, self._oldBottom do
                if cells[i] then
                    cellIdxs[cells[i]] = nil
                end
                self:setCell(cells[i], i)
                cells[i] = nil
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
    local kind
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
            if not cells[i] and self._indexToTopPos[i] ~= -100 then
                cells[i] = self:getCell(i)
                cell = cells[i]
                if cells[i] then
                    kind = self:getCellKind(i)
                    --if not self.setCellCache[cell] then
                        if self.cell[kind] then
                            cells[i]:Show()
                            cells[i]:Open()
                        else
                            cells[i].WidgetRoot:SetVisibility(ESlateVisibility.Visible)
                        end
                    --end
                    cellIdxs[cells[i]] = i
                    self:callRefreshFun(self.owner, cells[i], i)
                end
            end
        end

        self:refreshRetainerBox()
        --
        --self:StartStaggerAnimation(self.aniIdx)
        self:playListInAnimation()
    end
    --self:setCellEventrally()
end

function NewDiffList:asyncGetCell()
    local cells = self._cells
    local cell
    local cellIdxs = self.cellIndexs
    local bBreak = false
    self._tempAsyncNum = self.asyncNum
    for i = self._topIndex, self._bottomIndex do
        if not cells[i] and self._indexToTopPos[i] ~= -100 then
            local cell = self:getCell(i)
            if cell then
                cells[i] = cell
                cells[i]:Show()
                cells[i]:Open()
                cellIdxs[cells[i]] = i
                self:callRefreshFun(self.owner, cells[i], i)
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

function NewDiffList:refreshRetainerBox()
    if self.owner[self.onStartIndexChangedCB] then
        if self.startIndex ~= self._oldTop then
            self.startIndex = self._oldTop
            self.owner[self.onStartIndexChangedCB](self.owner, self:getAllIndex(self._oldTop))
        end
    end

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
            self.bEndFlag = false
            self.bStartFlag = true
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

function NewDiffList:_getSizeFun(kind)
    if self.libWidget[kind] then
        return self.libWidget[kind][2], self.libWidget[kind][3]
    end
    local sizeCache = self.sizeCache
    if not sizeCache then
        sizeCache = {}
        self.sizeCache = sizeCache
    end
    local _sizeCache = sizeCache[kind]
    if not _sizeCache then
        _sizeCache = {}
        sizeCache[kind] = _sizeCache
        local item = self.template[kind]
        import("WidgetLayoutLibrary").GetViewportSize(item)
        local size = item.Slot:GetSize()
        _sizeCache[1] = size.X
        _sizeCache[2] = size.Y
    end

    return _sizeCache[1], _sizeCache[2]
end

function NewDiffList:doRefresh()
    for i, widget in pairs(self._cells) do
        self:callRefreshFun(self.owner, self._cells[i], i)
    end
end

function NewDiffList:clearCell()
    for i = self._bottomIndex, self._topIndex, -1 do
        self:setCell(self._cells[i], i)
    end
    table.clear(self._cells)
    table.clear(self.cellIndexs)
end


function NewDiffList:SetData(total, top, inAni, datas)
    if not self._cells then
        Log.Warning("TreeList Already Close")
        return
    end
    if self.isRefreshing == true then
        Log.Error("Cannot SetData in OnRefresh")
        return
    end
    self.datas = datas
    self:LockScroll(false)
    self.aniSetData = inAni
    local oldTotal = self.total
    if self.total and self.total ~= total then
        self.total = total
        self:clearCell()
        self._lastIndex = nil

        if self.width > 0 or self.height > 0 then
            if self.total > 0 then
                for i = 1, self.total, 1 do
                    self.updateFlags[i] = true
                end
                if self._topIndex > self.total then
                    self._topIndex = self.total
                end
                local index = top
                if not index or index == -1 then
                    index = self._topIndex
                end
                self:checkPosUpdate(self.oldOffect, index)
            else
                self._topIndex = 1
                self._bottomIndex = 1
                self._oldTop = 0
                self._oldBottom = 0
            end
        else
            if top and top > 0 and top <= self.total then
                self._cacheIdx = top 
            end
            self:getSize()
        end
    else
        self:doRefresh()
        self:playListInAnimation()
    end
    -- if not self.inited and top then
    --     self:ScrollToIndex(top)
    -- end
end


function NewDiffList:checkPosUpdate(offset, forceIndex, force)
    if not offset and forceIndex <= 0 or (forceIndex and forceIndex > self.total) then
        return
    end
    local diff
    if offset then
        diff = offset - self.oldOffect
    else
        diff = 0
    end
    --如果向上滑动或者瞬间刷新到某一个位置
    if diff < 0 or forceIndex or force then
         local topPos
         local moveup = false
         local startIdx = self._topIndex
         local indexToTopPos = self._indexToTopPos
         local indexToBottomPos = self._indexToBottomPos
         if forceIndex and forceIndex <= self.total then
            startIdx = forceIndex
         end
         local top, firstFlag = startIdx, nil

         --查看上面是否有标记
         local needUpdate
         --向上多计算一个位置
         for i = startIdx - 1, 1 , -1 do 
            needUpdate =  self.updateFlags[i]
            if needUpdate then
                firstFlag = i
                break
            end
            
            --如果找到一个计算过的位置，且满足滚动位置要求
            if offset then
                topPos = indexToTopPos[i]
                if topPos and not needUpdate and topPos <= offset then
                    top = i
                    break
                end
            end
         end
        if not firstFlag then
            firstFlag = self.updateFlags[startIdx]
        end
        --如果没找到计算过的位置
        if firstFlag then
            if forceIndex and diff == 0 then
                --瞬间滚动位置的直接用位置查找最上面一个
                top, firstFlag = self:calculateTopIndex(startIdx)
            else
                --有滚动位置的带滚动位置查找最上面一个
                top, firstFlag = self:calculateTopIndex(startIdx, math.abs(diff))
            end
            local defaultFlag = false
            local markOffset
            self._topIndex = top
            --如果top是第一个或者上面一个位置已计算过，直接更新top之下的位置
            if (top > 1 and not self.updateFlags[top - 1]) or top == 1 then
                if not offset then
                    markOffset = true
                end
                self:updatePos(top, offset, forceIndex, markOffset)
                return
            else
                --否则，给top的上一个节点一个临时的默认位置，然后更新top之下的位置
                indexToTopPos[top - 1] = 0
                indexToBottomPos[top - 1] = self.defaultGap
                for i = top - 2, 1, -1 do
                    if not self.updateFlags[i] then
                        indexToTopPos[top - 1] = indexToBottomPos[i] + (top - i - 2) * self.defaultGap
                        defaultFlag = true
                        break
                    elseif i == 1 then
                        indexToTopPos[top - 1] = (top - 2) * self.defaultGap
                        defaultFlag = true
                    end
                end
                --需要补充默认间隔
                if defaultFlag then
                    indexToBottomPos[top - 1] = indexToTopPos[top - 1] + self.defaultGap
                end
                --矫正滚动位置
                
                if forceIndex or (offset and offset < indexToBottomPos[top - 1]) then
                    offset = indexToBottomPos[top - 1]
                    if self.oldOffect < offset then
                        self.oldOffect = offset + 1
                    end
                elseif firstFlag then
                    markOffset = true
                    Log.Debug("markOffset")
                end
                --更新位置
                self:updatePos(top, offset, forceIndex, markOffset)
                return
            end
        else
            if forceIndex then
                offset = indexToTopPos[top]
                for i = top, self.total, 1 do
                    if self.updateFlags[i] then
                        self:updatePos(i,offset,top)
                        return
                    end
                end
            end
        end
    --向下滚动，可见区域位置都已计算过
    elseif diff > 0 then
        --找到向下第一个未计算的位置
        local firstFlag
        for i = self._bottomIndex + 1, self.total, 1 do
            if self.updateFlags[i] then
                firstFlag = i
                break
            end
        end
        --尝试更新
        if firstFlag then
            self:updatePos(firstFlag, offset,nil,nil)
            return
        end
    end
    if not offset then
        return
    end
    --如果不需要更新位置，直接滚动
    self:getRoot():SetScrollOffset(offset)
    self:onUserScrolled(offset)
end

function NewDiffList:calculateTopIndex(startIdx, diffOffset)
    local top
    local totalLength = 0
    local sizeX, sizeY
    local kind

    local newScale = 0
    local spaceUp,spaceBottom,spaceLeft,spaceRight 
    
    local firstFlag
    local indexToTopPos = self._indexToTopPos
    local indexToBottomPos = self._indexToBottomPos
    --先向下查看是否填满
    if not diffOffset and startIdx then
        for i = startIdx, self.total, 1 do
            kind = self:getCellKind(i)
            
            local topPos
            
            if self.updateFlags[i] or (firstFlag and i > firstFlag) then
                if not firstFlag then
                    firstFlag = i
                end
                if self.onGetWidgetSizeFunCB then
                    sizeX, sizeY = self.owner[self.onGetWidgetSizeFunCB](self.owner, i)
                    if (not sizeX) or (not sizeY) then
                        sizeX, sizeY = self:_getSizeFun(kind)
                    end
                else
                    sizeX, sizeY = self:_getSizeFun(kind)
                end
                spaceUp,spaceBottom,spaceLeft,spaceRight = self:getSpace(kind)
                topPos = newScale + spaceUp
                newScale = topPos + sizeY + spaceBottom
            else
                spaceUp,spaceBottom,spaceLeft,spaceRight = self:getSpace(kind)
                sizeY = indexToBottomPos[i] - indexToTopPos[i]
                topPos = indexToTopPos[i]
                newScale = indexToBottomPos[i] + spaceBottom
            end

            totalLength = topPos + sizeY
            if totalLength >= self.height then
                top = startIdx
                break
            end
        end
    end
    --填不满向上找
    if not top then
        if diffOffset and self.oldOffect - diffOffset >= indexToTopPos[startIdx] then
            return startIdx
        end
        newScale = 0
        local addLength = 0

        firstFlag = nil
        for i = startIdx - 1, 1, -1 do
            top = i
            kind = self:getCellKind(i)
            if self.updateFlags[i] then
                firstFlag = i
                if self.onGetWidgetSizeFunCB then
                    sizeX, sizeY = self.owner[self.onGetWidgetSizeFunCB](self.owner, i)
                    if (not sizeX) or (not sizeY) then
                        sizeX, sizeY = self:_getSizeFun(kind)
                    end
                else
                    sizeX, sizeY = self:_getSizeFun(kind)
                end
            else
                sizeY = indexToBottomPos[i] - indexToTopPos[i]
            end
            spaceUp,spaceBottom,spaceLeft,spaceRight = self:getSpace(kind)
            local topPos
            
            topPos = newScale + spaceBottom
            addLength = spaceBottom
            
            newScale = topPos + sizeY + spaceUp
            totalLength = totalLength + addLength + sizeY

            if totalLength >= self.height and not diffOffset then
                break
            end
            if diffOffset and newScale>= diffOffset then
                top = i
                break
            end
        end
    end
    return top or startIdx, firstFlag
end

function NewDiffList:updatePos(startIdx, curOffset, forceIndex, markOffset, noRefresh)
    --Log.Debug("NewCalculatePos Start = ", startIdx,"Offset = ", curOffset)
    local totalLength = 0

    local oldPosX = 0
    local oldPosY = self._padding.Top
    local kind
    local spaceUp,spaceBottom,spaceLeft,spaceRight 
    local aligment
    local padding = self._padding
    local sizeX, sizeY 
    local indexToXPos = self._indexToXPos
    local indexToTopPos = self._indexToTopPos
    local indexToBottomPos = self._indexToBottomPos
    if startIdx > 0 then
        if not noRefresh then
            for i = startIdx, self.total, 1 do
                self.updateFlags[i] = true
            end
        end
    else
        return
    end

    if startIdx > 1 then
        kind = self:getCellKind(startIdx - 1)

        oldPosX = indexToXPos[startIdx - 1]
        oldPosY = indexToTopPos[startIdx - 1]

        oldPosY = indexToBottomPos[startIdx - 1]
        spaceUp,spaceBottom,spaceLeft,spaceRight = self:getSpace(kind)
        oldPosY = oldPosY + spaceBottom
        
    end

        for i = startIdx, self.total, 1 do
            kind = self:getCellKind(i)
            
            if self.updateFlags[i] and self.onGetWidgetSizeFunCB then
                sizeX, sizeY = self.owner[self.onGetWidgetSizeFunCB](self.owner, i)
                if (not sizeX) or (not sizeY) then
                    sizeX, sizeY = self:_getSizeFun(kind)
                end
            else
                sizeX, sizeY = self:_getSizeFun(kind)
            end

            spaceUp,spaceBottom,spaceLeft,spaceRight = self:getSpace(kind)
            aligment = self.alignment[kind]

            if aligment == NewDiffList.Alignment.Left then
                indexToXPos[i] = padding.Left
                oldPosX = padding.Left
            elseif aligment == NewDiffList.Alignment.Center then
                local tempWidth = self.width-padding.Left-padding.Right
                indexToXPos[i] = tempWidth/2 - sizeX/2
                oldPosX = tempWidth/2 - sizeX/2
            elseif aligment == NewDiffList.Alignment.Right then
                local tempWidth = self.width-padding.Left-padding.Right
                indexToXPos[i] = tempWidth - sizeX
                oldPosX = tempWidth - sizeX
            end
            local topPos
            
            topPos = oldPosY + spaceUp
            
            indexToTopPos[i] = topPos
            indexToBottomPos[i] = topPos + sizeY
            oldPosY = topPos + sizeY + spaceBottom
            totalLength = topPos + sizeY
                
            self._lastIndex = i
            --更新已有的位置
            local cell = self._cells[i]
            if cell then
                self.tempPos.X = indexToXPos[i]
                self.tempPos.Y = indexToTopPos[i]
                cell.View.WidgetRoot.Slot:SetPosition(self.tempPos)
            end
            self.updateFlags[i] = nil
            if not curOffset then
                curOffset = indexToTopPos[startIdx]
            elseif markOffset then
                curOffset = indexToBottomPos[startIdx]
            end
            self._bottomIndex = i
            if totalLength >= curOffset + self.height then
                --self._bottomIndex = i
                break
            end
           
        end
        for i = self._bottomIndex + 1, self.total, 1 do
            if self._cells[i] then
                self.cellIndexs[self._cells[i]] = nil
            end
            self:setCell(self._cells[i], i)
            self._cells[i] = nil
        end
    
    self.length = indexToBottomPos[self._lastIndex] + padding.Top + padding.Bottom + self.defaultGap * math.max((self.total - self._lastIndex),0)
    if self.bIsBottomFirst then
        if self.length < self.height then
            --未超过滑动框
            local offect = self.height - self.length
            for i, Pos in ipairs(self._indexToTopPos) do
                if Pos >= 0 and i <= self.total then
                    self._indexToTopPos[i] = Pos + offect
                end
            end
            for i, Pos in ipairs(indexToBottomPos) do
                if Pos >= 0 and i <= self.total then
                    indexToBottomPos[i] = Pos + offect
                end
            end
            self.length = self.height
        end
    end
    self.tempPos.X = self.width
    self.tempPos.Y = self.length
    --self.total = #self._foldMap
    self._diffPoint.Slot:SetPosition(self.tempPos)
    if forceIndex and not self.updateFlags[forceIndex] and indexToTopPos[forceIndex] then
        curOffset = indexToTopPos[forceIndex]
    end
    if not curOffset then
        curOffset = 0 
    end
    local offect = math.max(math.min(curOffset, self.length - self.height), 0)
    
    if self.oldOffect > offect then
        --滑动框区域回缩了
        self._oldTop = self.total
        self._oldBottom = self.total
        noRefresh = false
    end
    if not noRefresh then
        if self._cacheIdx then
            self:ScrollToIndex(self._cacheIdx)
            self._cacheIdx = nil
        else
            self:onUserScrolled(offect)
            self:getRoot():SetScrollOffset(offect)
        end
    end
    
end

function NewDiffList:MarkDiffSize(index)
    if index < 0 or index > self.total then
        return
    end
    self.updateFlags[index] = true

    if index <= self._bottomIndex and index >= self._topIndex then
        for i = index, self.total, 1 do
            self.updateFlags[i] = true
        end
        self:updatePos(index, self.oldOffect)
    end
end

------------------------eventfunc------------------------
---@public 双击检测开关
---@param enabled boolean true开false关
function NewDiffList:EnableDoubleClick(enabled)
    self.doubleClickEnabled = enabled
end

---@public 右键检测开关
---@param enabled boolean true开false关
function NewDiffList:EnableRightClick(enabled)
    self.rightClickEnabled = enabled
end

---@private
function NewDiffList:onItemClicked(index, bIsRightClick)
    local r = self:GetRendererAt(index)
    -- local k = table.ikey(self.wigets, r)
    local id 
    local kind = self:getCellKind(index)
    if self.cell[kind] then
        id = r.View.WidgetRoot:GetUniqueID()
    else
        id = r.WidgetRoot:GetUniqueID()
    end
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

function NewDiffList:onItemClickSingle(index, canSel, bIsRightClick)
    local toggle = self.toggle
    if self.selectedIndex and self.selectedIndex == index then
        local widget = self:GetRendererAt(index)
        if toggle then
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
    if canSel and oldIndex and oldIndex > 0 then
        local widget = self:GetRendererAt(oldIndex)
        if widget then
            self:callRefreshFun(self.owner, widget, oldIndex, false)
            --self:playAutoAni(oldIndex, false)
            self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
        end
    end
    if canSel then
        self.selectedIndex = index
    end
    local widget = self:GetRendererAt(index)
    if widget then
        if canSel then
            self:callRefreshFun(self.owner, widget, index, true)
            --self:playAutoAni(index, true)
            self:PlayStateAnimation(index, ListAnimationLibrary.CellState.Select)
        end
        self:callOnClickFun(self.owner, widget, index, bIsRightClick)
    end
end

function NewDiffList:onItemClickedex(index, bIsRightClick)
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
        local selected = not self.selectedIndexs[index]
        if widget then
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


function NewDiffList:onItemDoubleClicked(index)
    local component = self:GetRendererAt(index)
    if component then
        self:callOnDoubleClickFun(component, index)
    end
end

---按下处理(区分长按与单击)
---@private
function NewDiffList:onItemPressed(index)
    -- Log.Warning("[ListView] OnPressed ", index)

    local component = self:GetRendererAt(index)
    -- local k = table.ikey(self.wigets, component)
    local id 
    local kind = self:getCellKind(index)
    if self.cell[kind] then
        id = component.View.WidgetRoot:GetUniqueID()
    else
        id = component.WidgetRoot:GetUniqueID()
    end
    self.blong[id] = false
    local name = self.timePressName .. id
    self:StartTimer(name, function()
        -- Log.Warning("[ListView] onLongPress", index)
        self.blong[id] = true
        self:callOnLongPressFun(component, index)
    end, Enum.EConstFloatData.LONG_PRESS_TIME, 1)
end

function NewDiffList:onItemReleased(index)
    -- Log.Warning("[ListView] onItemReleased ", index)
    
    local component = self:GetRendererAt(index)
    if not component then return end
    local id 
    local kind = self:getCellKind(index)
    if self.cell[kind] then
        id = component.View.WidgetRoot:GetUniqueID()
    else
        id = component.WidgetRoot:GetUniqueID()
    end
    local name = self.timePressName .. id
    self:StopTimer(name)
    self:callOnReleasedFun(component, index)
end

function NewDiffList:SetSingleToggle(bSingleToggle)
    if self.multi then
        self:SetMulti(false)
    end

    self.toggle = bSingleToggle

end

---设置滚动列表是否能多选
---@public
---@param multi bool
function NewDiffList:SetMulti(multi)
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

---获得第多少条数据对应哪个格子
---@public
function NewDiffList:GetRendererAt(index)
    return self._cells[index]
end

---@public 让滚动列表滚动到最上面
function NewDiffList:ScrollToBegin()
    if self.height == 0 then
        self.oldOffect = 0
        return
    end
    self:getRoot():SetScrollOffset(0)
    self:onUserScrolled(0)
end

function NewDiffList:ScrollToIndex(index)
    
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
    if self._cacheIdx then
        self._cacheIdx = nil
    end
    
    if not self.updateFlags[index] then
        offect = self._indexToTopPos[index] or 0
        self:checkPosUpdate(offect, index)
    else
        self:checkPosUpdate(nil, index)
    end
    return
   
end

function NewDiffList:Sel(index)
    if not self.multi then
        --单选
        local oldIndex = self.selectedIndex
        self.selectedIndex = -1
        if oldIndex and oldIndex >= 0 then
            local r = self:GetRendererAt(oldIndex)
            if r then
                self:callRefreshFun(self.owner, r, oldIndex, false)
                --self:playAutoAni(oldIndex, false)
                self:PlayStateAnimation(oldIndex, ListAnimationLibrary.CellState.UnSelect)
            end
        end
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
        if index < 0 then
            return
        end
        if index > self.total then return end
        
        self.selectedIndexs[index] = true
        local widget = self:GetRendererAt(index)
        if widget then
            self:callRefreshFun(self.owner, widget, index, true)
            --self:playAutoAni(index, true)
            self:PlayStateAnimation(index, ListAnimationLibrary.CellState.Select)
        end
    end
end

---@public 取消当前选中 单选列表只能取消当前选中的，不用传参数，多选列表需要传取消选中的是哪一个
function NewDiffList:CancelSel(index)
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
        if index < 0 then
            return
        end
        if index > self.total then return end
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
function NewDiffList:CancelAllSel()
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

function NewDiffList:setCell(uiCell, index)
    if uiCell then
        local kind = self:getCellKind(index)
        if self.libWidget[kind] then
            --formcomponent
            --self.owner:AddObjectNum(-UIHelper.GetObjectNum(uiCell.View.WidgetRoot))
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
            local uiCells = self.uiCells[kind]
            uiCells[#uiCells+1] = uiCell
            self.setCellCache[uiCell] = kind

            if self.cell[kind] then
                uiCell:Hide()
                -- uiCell:Close()
            else
                local widget = uiCell.WidgetRoot
                widget:SetVisibility(ESlateVisibility.Collapsed)
            end

        end
    end
end

--延迟关闭cell
function NewDiffList:setCellEventrally()
    for uiCell, kind in pairs(self.setCellCache) do
        --延迟关闭
        if self.cell[kind] then
            uiCell:Hide()
            -- uiCell:Close()
        else
            local widget = uiCell.WidgetRoot
            widget:SetVisibility(ESlateVisibility.Collapsed)
        end
    end
    table.clear(self.setCellCache)
end
function NewDiffList:getAutoButton(uiComponent)
    local btn
    if self.buttonPath then
        btn = uiComponent.View
        for key, value in pairs(self.buttonPath) do
            btn = btn[value]
            if not btn then
                break
            end
        end
    end
    if not btn then
        btn = uiComponent.View.Btn_ClickArea ~= nil and uiComponent.View.Btn_ClickArea or uiComponent.View.Big_Button_ClickArea
    end
    return btn
end

function NewDiffList:addClickListener(uiComponent)
    --todo 后续wbp里命名都统一成Btn_ClickArea，目前为了防止旧资源报错，先加上保护措施
    local btn = self:getAutoButton(uiComponent)
    if btn then
        self:AddUIListener(_G.EUIEventTypes.CLICK, btn, "HandleItemClicked", uiComponent)
        self:AddUIListener(_G.EUIEventTypes.RightClick, btn, "HandleItemClicked", uiComponent, true)
        --TODO::
        if not self.timePressName then
            self.timePressName = self.timeName .. "Press"
        end
        self:AddUIListener(_G.EUIEventTypes.Pressed, btn, function()
            self:onItemPressed(self.cellIndexs[uiComponent])
        end)
        self:AddUIListener(_G.EUIEventTypes.Released, btn, function()
            self:onItemReleased(self.cellIndexs[uiComponent])
        end)
    end
end

function NewDiffList:getKind(index)
    return self._kindMap[index]
end

function NewDiffList:getCell(index)
    local sizeX, sizeY
    local kind = self:getCellKind(index)
    
    local cell = self.cell[kind]
    local uiComponent
    local WidgetSlot
    if self.libWidget[kind] then
        --formcomponent
        local libWidget = self.libWidget[kind]
        uiComponent = self:FormComponent(libWidget[1], self._panel, cell)

        if cell then
            WidgetSlot = uiComponent.View.WidgetRoot.Slot
        else
            WidgetSlot = uiComponent.WidgetRoot.Slot
        end
        
        WidgetSlot:SetAutoSize(false)
        WidgetSlot:SetAnchors(self._defaultAnchors)
        self.tempPos.X = 0
        self.tempPos.Y = 0
        WidgetSlot:SetAlignment(self.tempPos)
        self.tempPos.X = libWidget[2]
        self.tempPos.Y = libWidget[3]
        WidgetSlot:SetSize(self.tempPos)
        self:addClickListener(uiComponent)
        --self.owner:AddObjectNum(UIHelper.GetObjectNum(uiComponent.View.WidgetRoot))
    else
        --createwidget
        local uiCells = self.uiCells[kind]
        if #uiCells > 0 then
            uiComponent = uiCells[#uiCells]
            if cell then
                WidgetSlot = uiComponent.View.WidgetRoot.Slot
            else
                WidgetSlot = uiComponent.WidgetRoot.Slot
            end
            uiCells[#uiCells] = nil
            if self.onGetWidgetSizeFunCB then
                sizeX, sizeY = self.owner[self.onGetWidgetSizeFunCB](self.owner, index)
                if (not sizeX) or (not sizeY) then
                    sizeX, sizeY = self:_getSizeFun(kind)
                end
            else
                sizeX, sizeY = self:_getSizeFun(kind)
            end
            local size = WidgetSlot:GetSize()
            self.tempPos.X = size.X
            self.tempPos.Y = sizeY
            WidgetSlot:SetSize(self.tempPos)
        else
            if self.bIsAsync then
                if self._tempAsyncNum <= 0 then
                    return
                end
                self._tempAsyncNum = self._tempAsyncNum - 1
            end
            local template = self.template[kind]
            local widget = import("UIFunctionLibrary").C7CreateWidget(self.owner:GetViewRoot(), self._panel, template)
            --self.refItems[#self.refItems+1] = UnLua.Ref(widget)
            self.rawItems[#self.rawItems+1] = widget
            widget.Slot:SetAnchors(template.Slot:GetAnchors())
            widget.Slot:SetAlignment(template.Slot:GetAlignment())

            if self.onGetWidgetSizeFunCB then
                sizeX, sizeY = self.owner[self.onGetWidgetSizeFunCB](self.owner, index)
                if (not sizeX) or (not sizeY) then
                    sizeX, sizeY = self:_getSizeFun(kind)
                end
            else
                sizeX, sizeY = self:_getSizeFun(kind)
            end

            local size = template.Slot:GetSize()
            self.tempPos.X = size.X
            self.tempPos.Y = sizeY
            widget.Slot:SetSize(self.tempPos)
            uiComponent = self:BindListComponent(self.names[kind], widget, self.cell[kind], self.getCellIndex, self, true)
            if cell then
                WidgetSlot = uiComponent.View.WidgetRoot.Slot
            else
                WidgetSlot = uiComponent.WidgetRoot.Slot
            end
            self:addClickListener(uiComponent)
            if uiComponent.UpdateObjectNum then
                uiComponent:UpdateObjectNum(UIHelper.GetObjectNum(widget))
            end
        end
    end
    self.tempPos.X = self._indexToXPos[index]
    self.tempPos.Y = self._indexToTopPos[index]
    WidgetSlot:SetPosition(self.tempPos)
    --uiComponent.View.WidgetRoot.Slot:SetPosition(self.tempPos)
    --AniCheck
    return uiComponent
    
end

---@public 设置滚动列表是否开启禁止过度滚动
---@param newAllowOverscroll boolean true允许过度滚动，false不允许过度滚动
function NewDiffList:SetAllowOverscroll(newAllowOverscroll)
    return self:getRoot():SetAllowOverscroll(newAllowOverscroll)
end

---@屏幕分辨率变化
function NewDiffList:OnViewportResize()
    self.bMarkViewportResize = true
    if self.bEnable then
        self:UpdateSize()
    end
end

function NewDiffList:OnOpen()
    local kind
    for index, cell in pairs(self._cells) do
        kind = self:getCellKind(index)
        if self.cell[kind] then
            cell:Show()
            cell:Open()
        end
    end
    self.bEnable = true
    if self.bMarkViewportResize then
        self:UpdateSize()
    end
end

---list容器只处理子Component的Show和Hide,不处理OnRefresh
function NewDiffList:OnRefresh()
end

function NewDiffList:OnClose()
    UIBase.OnClose(self)
    self.bEnable = false
    self.aniNotified = nil
    self.aniSetData = nil
    self.inited = false
    self.datas = nil
    table.clear(self.lastClickTimes)
    
    local kind
    for index, cell in pairs(self._cells) do
        kind = self:getCellKind(index)
        if self.cell[kind] then
            cell:Hide()
            cell:Close()
        end
    end
end

function NewDiffList:OnDestroy()
    self:clearCell()
    for kind, uiCells in pairs(self.uiCells) do
        for _, uiCell in pairs(uiCells) do
            self:UnbindListComponent(uiCell.View.WidgetRoot)
        end
    end
    self.retainerBox = nil
    self.uiCells = nil
    self._cells = nil
    self.cellIndexs = nil

    self.tempPos = nil
    
    self.template = nil
    
    self.rawItems = nil
    self.refItems = nil
    self.onStartIndexChangedCB = nil
    self.owner = nil
    self.aniComp = nil
    UIBase.OnDestroy(self)
end

---@public 如果对应的格子在显示就执行Refresh方法刷新此格子
---@param tIndex number 第几层
---@param gIndex number 第几层的第几个
function NewDiffList:RefreshCell(index)
    if index < 1 then index = 1 end
    if index > self.total then
        index = self.total
    end
    local r = self:GetRendererAt(index)
    if r then
        self:callRefreshFun(self.owner, r, index)
    end
end

function NewDiffList:isSeleceted(index)
    if not self.multi then
        return index == self.selectedIndex
    else
        return self.selectedIndexs[index]
    end
end

---获得选中的数据
---@public
---@return table 选中的数据
function NewDiffList:GetSelectedIndex()
    if not self.multi then
        return self.selectedIndex
    end
    local t = {}
    for k, v in next, self.selectedIndexs do
        if v then
            table.insert(t, k)
        end
    end
    return t
end

---@public 重新刷新ListPanel大小，会触发List更新位置
function NewDiffList:UpdateSize()
    if self.reSizeCount > 10 then
        self.reSizeCount = 0
    end
    self:StartTimer("REFRESH_HIERARCHYLIST", function()
        local size = self.getLocalSizeFun(self.getCachedGeometryFun(self:getRoot()))
        self.reSizeCount = self.reSizeCount + 1
        if size.X == self.width and size.Y == self.height and self.reSizeCount < 10 then
            return self:UpdateSize()
        end
        self.reSizeCount = self.reSizeCount + 1
        self.bMarkViewportResize = nil
        self.width = size.X
        self.height = size.Y
        
        if self.total > 0 then
            for i = 1, self.total, 1 do
                self.updateFlags[i] = true

            end
            self:checkPosUpdate(self.oldOffect, self._topIndex)
        
        end
    end, 1, 1)
end

---重新计算cell的高度、宽度
function NewDiffList:ReSize()
    if self.total > 0 then
        for i = 1, self.total, 1 do
            self.updateFlags[i] = true

        end
        self:checkPosUpdate(self.oldOffect, self._topIndex)
    
    end
end

function NewDiffList:GetTopIndex()
    return self._topIndex
end 

function NewDiffList:GetBottomIndex()
    return self._bottomIndex
end 

function NewDiffList:LockScroll(bLock)
    if bLock then
        self.View.List:SetVisibility(ESlateVisibility.HitTestInvisible)
        self.View.List:SetConsumeMouseWheel(import("EConsumeMouseWheel").Never)
    else
        self.View.List:SetVisibility(ESlateVisibility.Visible)
        self.View.List:SetConsumeMouseWheel(import("EConsumeMouseWheel").WhenScrollingPossible)
    end
end

function NewDiffList:InitListAnimationData()
    -- if self.animations:Num() > 0 then
    --     local cmp = TreeListAniComp.new(self)
    --     self.aniComp = cmp
    --     for key, cfg in pairs(self.animations) do
    --         self.aniComp:AddAnimationConfig(key, cfg)
    --         self:EnableAutoAnimation(key, "WidgetRoot")
    --     end
    -- end
end

function NewDiffList:onNotifyPlayListAnimation(index)
    if self.total > 0 then
        self.aniNotified = index
        self:getRoot():EndInertialScrolling()
        self:PlayListGroupAnimation(self.aniNotified)
        self.aniSetData = nil
        self.aniNotified = nil
    else
        self.aniNotified = index
    end
    
end
function NewDiffList:playListInAnimation()
    if (self.aniSetData and self:checkAnimationConfig(self.aniSetData)) or self:checkAnimationConfig(self.aniNotified) then
        self:getRoot():EndInertialScrolling()
        self:PlayListGroupAnimation(self.aniNotified or self.aniSetData)
        self.aniSetData = nil
        self.aniNotified = nil
    end
end

function NewDiffList:checkAnimationConfig(configIdx, isAniNotify)
    if not isAniNotify and not self.aniSetData then
        return false
    end
    if not self._cells or not next(self._cells) then
        return false
    end
    return true
end

function NewDiffList:PlayListGroupAnimation(key, cells, callback)
    if self.aniComp then
        if not cells then
            cells = {}
            for i = self._topIndex, self._bottomIndex, 1 do
                table.insert(cells, {index = i})
            end
            self.aniComp:PlayListGroupAnimation(key, cells, callback)
        else
            self.aniComp:PlayListGroupAnimation(key, cells, callback)    
        end
    end
end

function NewDiffList:EnableAutoAnimation(key, widget)
    if self.aniComp then
        self.aniComp:EnableAutoAnimation(key, widget)
    end
end

function NewDiffList:DisableAutoAnimation(key, widget)
    if self.aniComp then
        self.aniComp:DisableAutoAnimation(key, widget)
    end
end

function NewDiffList:PlayStateAnimation(index, state)
    if self.aniComp then
        self.aniComp:PlayStateAnimation(index, state)
    end

end

function NewDiffList:onRefreshItem(index, bSelected)
    if self.aniComp then
        self.aniComp:RefreshCellUpdateAni(index, bSelected)
    end
end

function NewDiffList:onSetCell(index)
    if self.aniComp then
        self.aniComp:setCellUpdateAni(index)
    end
end

function NewDiffList:AddItem2(indexs, noRefresh)
    local index
    local addnum = 0
    local len = #indexs
    local cells = self._cells
    local cellIndexs = self.cellIndexs
    local beginIdx = 1
    local endIdx
    local curAdd = 0
    local firstIdx
    local topAdd = 0
    local oldBottom = self._bottomIndex
    table.sort(indexs)

    --添加可视区域之前的Item
    for i = 1, len, 1 do
        index = indexs[i]
        if index >= 1 and index <= self.total + len then
            if not beginIdx then
                beginIdx = i
            end
            if index >= self._topIndex + curAdd then
                break
            end
            curAdd = curAdd + 1
        end
        endIdx = i
    end
    if curAdd > 0 then
        self:addItemTop(indexs, beginIdx, endIdx, addnum, curAdd)
    end
    addnum = addnum + curAdd
    
    --添加可视区域的Item
    if not endIdx or endIdx < len then
        if endIdx then
            beginIdx = endIdx + 1
        end
        curAdd = 0
        for i = beginIdx, len, 1 do
            index = indexs[i]
            if index >= 1 and index <= self.total + len - beginIdx + 1 then
                if index > self._bottomIndex then
                    break
                end
                curAdd = curAdd + 1
                --self:updateAddViewBottomIndex(indexs, i, addnum, 1)      
            end
            endIdx = i
        end
        if curAdd > 0 then
            self:addItemInView(indexs, beginIdx, endIdx, addnum, curAdd)
        end
        addnum = addnum + curAdd
    end


    if not endIdx or endIdx < len then
    --添加可视区域之后的Item
        if endIdx then
            beginIdx = endIdx + 1
        end
        curAdd = 0
        for i = beginIdx, len, 1 do
            index = indexs[i]
            if index >= 1 and index <= self.total + len - beginIdx + 1 then
                curAdd = curAdd + 1
            end
            endIdx = i
        end
        if curAdd > 0 then
            self:addItemBottom(indexs, beginIdx, endIdx, addnum, curAdd)
        end
        addnum = addnum + curAdd
    end

    if not noRefresh then
        local topidx = math.max(self._topIndex, firstIdx)
        local bottomidx = math.min(self._bottomIndex, oldBottom)
        for i = topidx ,bottomidx, 1 do
            self:callRefreshFun(self.owner, cells[i], i)
        end
    end
   
end

function NewDiffList:AddItem(indexs, noRefresh)
    local index
    local addnum = 0
    local len = #indexs
    local cells = self._cells
    local cellIndexs = self.cellIndexs
    local firstIdx
    local topidx
    local oldBottom = self._bottomIndex
    local oldTop = self._topIndex
    for i = 1, len, 1 do
        index = indexs[i]
        if index <= self._topIndex and self.total > 0 then
            for k = self._bottomIndex + 1, self._topIndex + 1, -1 do
                if cells[k-1] then
                    cells[k] = cells[k - 1]
                    cellIndexs[cells[k]] = k
                    self._kindMap[k] = self._kindMap[k - 1]
                    self._indexToTopPos[k] = self._indexToTopPos[k - 1]
                    self._indexToBottomPos[k] = self._indexToBottomPos[k - 1]
                    self._indexToXPos[k] = self._indexToXPos[k - 1]
                    cells[k - 1] = nil
                end
            end
            self._topIndex = self._topIndex + 1
            self._oldTop = self._topIndex
            self._bottomIndex = self._bottomIndex + 1
            self._oldBottom = self._bottomIndex
            addnum = addnum + 1
        elseif index <= self._bottomIndex then
            if not firstIdx then
                firstIdx = index
            end
            
            for k = self._bottomIndex + 1, index, -1 do
                if cells[k-1] then
                    cells[k] = cells[k - 1]
                    cellIndexs[cells[k]] = k
    
                    self._kindMap[k] = self._kindMap[k - 1]
                    self._indexToTopPos[k] = self._indexToTopPos[k - 1]
                    self._indexToBottomPos[k] = self._indexToBottomPos[k - 1]
                    self._indexToXPos[k] = self._indexToXPos[k - 1]
                    self.updateFlags[k] = nil
                end
            end
            if self.total  == 0 then
                self._bottomIndex = 1
                
                self._indexToTopPos[1] = 0
                self._indexToBottomPos[1] = 0
                self._indexToXPos[1] = 0
            else
                self._bottomIndex = self._bottomIndex + 1
            end
            
            self._oldBottom = self._bottomIndex
            self.updateFlags[index] = true
            local newCell = self:getCell(index)
            if newCell then
                cells[index] = newCell
                cells[index]:Show()
                cells[index]:Open()
                cellIndexs[cells[index]] = index
                self:callRefreshFun(self.owner, cells[index], index)
            end
            addnum = addnum + 1
        else
            if not firstIdx then
                firstIdx = index
            end
            addnum = addnum + 1
        end
    end
    self.total = self.total + addnum
    topidx = math.max(self._topIndex,indexs[1])
    for i = indexs[1], self._topIndex - 1 do
        self.updateFlags[i] = true
    end
    
    
    if firstIdx then
        self:updatePos(firstIdx,self.oldOffect, nil, nil)
    end

end

function NewDiffList:RemoveItem(indexs, noRefresh)
    local index
    local removenum = 0
    local len = #indexs
    local cells = self._cells
    local cellIndexs = self.cellIndexs
    local firstIdx
    local topidx
    local oldtop = self._topIndex

    for i = len, 1, -1 do
        index = indexs[i]
        if index < self._topIndex then
            for k = self._topIndex, self._bottomIndex, 1 do
                cells[k - 1] = cells[k]
                cellIndexs[cells[k - 1]] = k - 1
                self._kindMap[k - 1] = self._kindMap[k]
                self._indexToTopPos[k - 1] = self._indexToTopPos[k]
                self._indexToBottomPos[k - 1] = self._indexToBottomPos[k]
                self._indexToXPos[k - 1] = self._indexToXPos[k]
                cells[k] = nil
            end
            self._topIndex = self._topIndex - 1
            self._oldTop = self._topIndex
            self._bottomIndex = self._bottomIndex - 1
            self._oldBottom = self._bottomIndex
            removenum = removenum + 1
        elseif index <= self._bottomIndex then
           
            firstIdx = index
            if cells[index] then
                self:setCell(cells[index], index)
            end
            for k = index + 1, self._bottomIndex, 1 do
                if cells[k] then
                    
                    cells[k - 1] = cells[k]
                    cellIndexs[cells[k - 1]] = k - 1
    
                    self._kindMap[k - 1] = self._kindMap[k]
                    self._indexToTopPos[k - 1] = self._indexToTopPos[k]
                    self._indexToBottomPos[k - 1] = self._indexToBottomPos[k]
                    self._indexToXPos[k - 1] = self._indexToXPos[k]
                    self.updateFlags[k - 1] = nil
                end
            end
            cells[self._bottomIndex] = nil
            self._bottomIndex = self._bottomIndex - 1
            self._oldBottom = self._bottomIndex
            removenum = removenum + 1
        else
            firstIdx = index
            removenum = removenum + 1
        end
    end
    self.total = self.total - removenum
    topidx = math.max(self._topIndex,indexs[1])
    for i = indexs[1], self._topIndex - 1 do
        self.updateFlags[i] = true
    end
    for i = oldtop, self._topIndex, -1 do
        self.updateFlags[i] = nil
    end
    if firstIdx then
        for i = firstIdx, self.total do
            self.updateFlags[i] = true
        end
        firstIdx = math.min(firstIdx, self._topIndex)
        self:updatePos(indexs[1],self.oldOffect, nil, nil, true)
        self:checkPosUpdate(self.oldOffect, nil, true)
        
    end
end

function NewDiffList:addSingltItem(index, noRefresh)
    if index <= 0 then
        return
    elseif index > self.total + 1 then
        index = self.total + 1
    end
    local cells = self._cells
    local cellIndexs = self.cellIndexs
    if index >= self._topIndex and index <= self._bottomIndex then

        --重排可视区域列表
        for i = self._bottomIndex + 1, index + 1, -1 do
            cells[i] = cells[i - 1]
            cellIndexs[cells[i]] = i
        end
        local newBottom = self._bottomIndex + 1
        --更新可视区域位置
        self.total = self.total + 1
        self:updatePos(index, self.oldOffect, nil, nil, true)

        --回收多余item
        local bottom
        bottom = self.oldOffect + self.height
        if newBottom > self._bottomIndex and self._indexToBottomPos[self._bottomIndex] >= bottom then
            self:setCell(cells[newBottom],newBottom)
        end
        for i = index + 1, self._bottomIndex, 1 do
            self:moveItem(i)
            if not noRefresh then
                self:callRefreshFun(self.owner, cells[i], i)
            end
        end
        local newcell = self:getCell(index)
        if newcell then
            cells[index] = newcell
            if not self.setCellCache[newcell] then
                cells[index]:Show()
                cells[index]:Open()
            end
            cellIndexs[cells[index]] = index
            self:callRefreshFun(self.owner, cells[index], index)
        end
    elseif index < self._topIndex then
        self.total = self.total + 1
        for i = self._bottomIndex + 1, self._topIndex + 1, -1 do
            self._cells[i] = self._cells[i - 1]
            self.cellIndexs[self._cells[i]] = i
            self._kindMap[i] = self._kindMap[i - 1]
            self._indexToTopPos[i] = self._indexToTopPos[i - 1]
            self._indexToBottomPos[i] = self._indexToBottomPos[i - 1]
            self._indexToXPos[i] = self._indexToXPos[i - 1]
        end
        self._cells[self._topIndex] = nil
        
        self._topIndex = self._topIndex + 1
        self._bottomIndex = self._bottomIndex + 1
        self._oldTop = self._topIndex
        self._oldBottom = self._bottomIndex
        for i = index ,self._topIndex - 1, 1 do
            self.updateFlags[i] = true
        end
        if not noRefresh then
            for i = self._topIndex ,self._bottomIndex, 1 do
                self:callRefreshFun(self.owner, cells[i], i)
            end
        end
    else
        self.total = self.total + 1
        self.updateFlags[index] = true
        local bottom
        bottom = self.oldOffect + self.height

        if self._indexToBottomPos[self._bottomIndex] < bottom then
            self:updatePos(index, self.oldOffect)
        else
            self:updatePos(index, self.oldOffect, nil, nil, true)
        end
    end
end


function NewDiffList:moveItem(index)
    if self.updateFlags[index] then
        return
    end
    local cell = self._cells[index]
    local kind = self._kindMap[index]
    local WidgetSlot
    if cell then
        if self.cell[kind] then
            WidgetSlot = cell.View.WidgetRoot.Slot
        else
            WidgetSlot = cell.WidgetRoot.Slot
        end
        self.tempPos.X = self._indexToXPos[index]
        self.tempPos.Y = self._indexToTopPos[index]
        WidgetSlot:SetPosition(self.tempPos)
    end
end
function NewDiffList:removeSingltItem(index, noRefresh)
    if index <= 0 or index > self.total then
        return
    end
    local cells = self._cells
    local cellIndexs = self.cellIndexs
    if index >= self._topIndex and index <= self._bottomIndex then
        self:setCell(cells[index], index)
        cells[index] = nil
        --重排可视区域列表
        for i = index + 1, self._bottomIndex, 1 do
            cells[i - 1] = cells[i]
            cellIndexs[cells[i - 1]] = i - 1
        end
        cells[self._bottomIndex] = nil
        
        local newBottom = self._bottomIndex - 1
        --更新可视区域位置
        self.total = self.total - 1
        self:updatePos(index, self.oldOffect, nil, nil, true)

        if self._bottomIndex > newBottom then
            for i = newBottom + 1, self._bottomIndex, 1 do
                local newcell = self:getCell(i)
                if newcell then
                    cells[i] = newcell
                    cells[i]:Show()
                    cells[i]:Open()
                    cellIndexs[cells[i]] = i
                    self:callRefreshFun(self.owner, cells[i], i)
                end
            end
        end

        --移动位置
        for i = index, newBottom, 1 do
            self:moveItem(i)
            if not noRefresh then
                self:callRefreshFun(self.owner, cells[i], i)
            end
        end
    elseif index < self._topIndex then
        self.updateFlags[index] = true
        self.total = self.total - 1
        for i = self._topIndex, self._bottomIndex, 1 do
            self._cells[i - 1] = self._cells[i]
            self.cellIndexs[self._cells[i - 1]] = i - 1
            self._kindMap[i - 1] = self._kindMap[i]
            self._indexToTopPos[i-1] = self._indexToTopPos[i]
            self._indexToBottomPos[i - 1] = self._indexToBottomPos[i]
            self._indexToXPos[i - 1] = self._indexToXPos[i]
        end
        self._topIndex = self._topIndex-1
        self._bottomIndex = self._bottomIndex - 1
        self._oldTop = self._topIndex
        self._oldBottom = self._bottomIndex
        for i = index ,self._topIndex - 1, 1 do
            self.updateFlags[i] = true
        end
        if not noRefresh then
            for i = self._topIndex ,self._bottomIndex, 1 do
                self:callRefreshFun(self.owner, cells[i], i)
            end
        end
    else
        self.total = self.total - 1
        self.updateFlags[index] = true
        local bottom
        bottom = self.oldOffect + self.height

        if self._indexToBottomPos[self._bottomIndex] < bottom then
            self:updatePos(index, self.oldOffect)
        else
            self:updatePos(index, self.oldOffect, nil, nil, true)
        end
    end
end


return NewDiffList