local ESlateVisibility = import("ESlateVisibility")
local EOrientation = import("EOrientation")
local EUMGSequencePlayMode = import("EUMGSequencePlayMode")
local MovePlayer = kg_require("Framework.UI.List.ListComponents.MoveAnimationPlayer")
local StaggerPlayer = kg_require("Framework.UI.List.ListComponents.StaggerAnimationPlayer")
local AutoPlayer = kg_require("Framework.UI.List.ListComponents.StateAnimationPlayer")
local ComListAniComp = kg_require("Framework.UI.List.ListComponents.ComListAnimationComponent")
---@class ComList:BaseList
local ComList = DefineClass("ComList", BaseList)

--[=[
---刷新列表里每个格子的回调函数
---OnRefresh_List
---OnRefresh需要符合如下格式：
---@param r 格子(滚动元素比较简单)或者UICell(适合道具格子类比较复杂的滚动元素，需要基础UICell，可参考testui.lua里BagList里的写法)
---@param index 第多少条数据
---@param selected 第多少条数据是否选中
function(r, index, selected)
    local config = Cfg.cfg_item[self.items[index]]
    local image = r.btn.image
    image.sprite = config.icon
    local choose = r.choose
    choose.active= selected
end

---点击列表里每个格子的回调函数
---OnClick_List
---OnClick需要符合如下格式：
---@param r 格子
---@param index 第多少条数据
function(r, index)

end

---双击列表里每个格子的回调函数
OnDoubleClick_List，跟OnClick要求一样

---长按列表里每个格子的回调函数
OnLongPress_List，跟OnClick要求一样
]=]--

ComList.Layout = {
    List = 1,
    Tile = 2,
}

ComList.SelectionMode = {
    Single = 1,
    SingleToggle = 2,
    Multi = 3
}

---@class ComList.Alignment
ComList.Alignment = {
    Left = 0,
    Right = 1,
    Up = 2,
    Bottom = 3,
    Center = 4,
}


function ComList.SetUpFadeV(self)
    self.View.WidgetRoot:SetSlateRectFadePositionByFloat(0, 0.1, 1.0, 1.0)
    self.View.WidgetRoot:SetSlateRectFadeSizeByFloat(0, 0.08)
end

function ComList.SetDownFadeV(self)
    self.View.WidgetRoot:SetSlateRectFadePositionByFloat(0, 0.0, 1.0, 0.9)
    self.View.WidgetRoot:SetSlateRectFadeSizeByFloat(0, 0.08)
end

function ComList.CancelFade(self)
    self.View.WidgetRoot:SetSlateRectFadePositionByFloat(0, 0, 0, 0.0)
    self.View.WidgetRoot:SetSlateRectFadeSizeByFloat(0, 0)
end

function ComList.SetBothFadeV(self)
    self.View.WidgetRoot:SetSlateRectFadePositionByFloat(0, 0.1, 1.0, 0.9)
    self.View.WidgetRoot:SetSlateRectFadeSizeByFloat(0, 0.08)
end

function ComList.SetUpFadeH(self)
    self.View.WidgetRoot:SetSlateRectFadePositionByFloat(0.1, 0, 1.0, 1.0)
    self.View.WidgetRoot:SetSlateRectFadeSizeByFloat(0, 0.08)
end

function ComList.SetDownFadeH(self)
    self.View.WidgetRoot:SetSlateRectFadePositionByFloat(0, 0.0, 0.9, 1.0)
    self.View.WidgetRoot:SetSlateRectFadeSizeByFloat(0, 0.08)
end

function ComList.SetBothFadeH(self)
    self.View.WidgetRoot:SetSlateRectFadePositionByFloat(0.1, 0, 0.9, 1.0)
    self.View.WidgetRoot:SetSlateRectFadeSizeByFloat(0, 0.08)
end

-- luacheck: push ignore
---@param widget UListView
---@param name string ListView的名字
---@param visible bool scrollbar是否显示
---@param cell UIController
---@param parentAction bool 优先执行父级界面的行为（Refresh，Click等）
function ComList.OnCreate(self, name, cell, parentAction, bIsAsync, asyncNum)
    self.doubleClickEnabled = false
    self.rightClickEnabled = false
    self.owner = self.parentScript  --所属UI
    ---@type int 列表选中的第多少条数据
    self.selectedIndex = -1
    --是否分帧创建cell
    self.bIsAsync = bIsAsync
    --分帧创建数量
    self.asyncNum = asyncNum or 3
    self._tempAsyncNum = 0
    self.total = -1
    self.cell = cell
    self._cells = {}
    self.cellIndexs = {}
    self.name = name
    self.names = {}
    self.uiCells = {}
    self.parentFirst = parentAction
    self.rawItems = {}
    self.cellMap = {}
    --可以多选的列表
    self.selectedIndexs = {}
    self.blong = {}
    self.lastClickTimes = {}
    self._tempIndex = {}
    self._temp = {}

    self.timeName = string.format("%s%s",self.parentScript.__cname, self.name) --定时器名字固定前缀
    self.timePressName = nil

    --计算组件显示用
    self._topIndex = 1
    self._bottomIndex = 1
    self._oldTop = 0
    self._oldBottom = 0
    --上次回调滑动偏移
    self.oldOffect = 0
    --记录widget对应位置
    self._indexToTopPos = {}
    self._indexToBottomPos = {}
    self._lastIndex = 0
    self._indexToXPos = {}
    --panel总长
    self.length = 0
    self.width = 0
    self.height = 0
    self.widgetX = 0
    self.widgetY = 0
    self._cacheIdx = nil
    self.minSize = self.View.MinSize
    self.maxSize = self.View.MaxSize
    --SafeRefresh
    self.isRefreshing = false
    self.tempPos = FVector2D()
    self.onStartIndexChangedCB = string.format("%s%s", name, "_OnStartIndexChanged")
    self.onScrollToEndCB = string.format("%s%s", name, "_OnScrollToEnd")
    self._bScrollToEnd = false
    --RetainerBox
    self.retainerBox = self.View.RetainerBox

    
    local Orientation = self.View.Orientation
    self.bIsVertical = Orientation == EOrientation.Orient_Vertical --

    self.bEndFlag = false
    self.bStartFlag = false

    self.scrollItems = {}
    self.ClickAudioFunc = nil
    --记录当前显示首位index
    self.startIndex = 1    --主动绑定OnRefresh_List来刷新滚动列表，不能没有
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
    local selectionMode = self.View.SelectionMode
    self.toggle = selectionMode == ComList.SelectionMode.SingleToggle
    self.multi = selectionMode == ComList.SelectionMode.Multi

    self.enabled = true
    if self.View.bSizeToContent then
        self.bChildSizeToContent = true
    else
        self.bChildSizeToContent = false
    end

    local item = self.View.ScrollWidget
    if item then
        local itemSlot = item.Slot
        if itemSlot:IsA(import("CanvasPanelSlot")) and (not self.bChildSizeToContent) then
            local size = item.Slot:GetSize()
            self.widgetX = size.X
            self.widgetY = size.Y
            self._waitGetItemSize = false
            item:SetVisibility(ESlateVisibility.Hidden)
        else
            self.tempAnchor = import("Anchors")()
            self.tempAnchor.Minimum.X = 0
            self.tempAnchor.Minimum.Y = 0
            self.tempAnchor.Maximum.X = 0
            self.tempAnchor.Maximum.Y = 0
            self._waitGetItemSize = true
            self.itemGetCachedGeometry = self.View.ScrollWidget.GetCachedGeometry
            item:SetVisibility(ESlateVisibility.Visible)
        end
        self.oneObjNum = UIHelper.GetObjectNum(item)
        self.scrollWidgetOpacity = self.View.ScrollWidget:GetRenderOpacity()
    else
        self._waitGetItemSize = false
        local libWidget = self.View.LibWidget
        self.libWidget = libWidget.libName
        self.widgetX = libWidget.sizeX
        self.widgetY = libWidget.sizeY
        --TODO:临时处理libWidget
        self.scrollWidgetOpacity = 1
    end
    
    local space = self.View.Space
    self.spaceUp = space.spaceUp
    self.spaceBottom = space.spaceBottom
    self.spaceLeft = space.spaceLeft
    self.spaceRight = space.spaceRight

    self._panel = self.View.DiffPanel
    self._diffPoint = self.View.DiffPoint
    self.alignment = self.View.Alignment

    self.bIsTileView = self.View.bIsTileView

    self.bIsCenterContent = self.View.bIsCenterContent

    local listPadding = self.View.ListPadding
    self.listPadding = {
        Left = listPadding.Left,
        Top = listPadding.Top,
        Right = listPadding.Right,
        Bottom = listPadding.Bottom,
    }

    self:getRoot():SetOrientation(Orientation)
    self:AddUIListener(EUIEventTypes.UserScrolled, self:getRoot(), self.onUserScrolled)
    --self:AddUIListener(EUIEventTypes.OnAnimationNotify, self.View.WidgetRoot, self.onNotifyPlayInAnimation)
    self.View.ListPlayAnimation:Add(
        function(key)
            self:onNotifyPlayListAnimation(key)
        end)

    self._defaultAnchors = import("Anchors")()
    self.getCachedGeometryFun = self:getRoot().GetCachedGeometry
    self.getLocalSizeFun = import("SlateBlueprintLibrary").GetLocalSize
    if (self.minSize > 0 or self.maxSize > 0) and self:checkSlotAndAnchors() then
        self:getAutoSize()
    else
        self:getSize()
    end

    
    
    ---@type boolean @标识是否需要更新大小
    self.bMarkViewportResize = nil
    ---@type boolean @标识当前是否显示
    self.bEnable = true
    ---@type number @重新获取大小的尝试次数
    self.reSizeCount = 0
    --需要监听屏幕分辨率更新
    Game.EventSystem:AddListener(_G.EEventTypes.ON_VIEWPORT_RESIZED, self, self.OnViewportResize)
    ---@type function @获取当前列表底部位置回调
    self.endPosYCallback = nil
    
    --增删
    self.addCache = {}
    self.removeCache = {}
    self.cellAddTimerID = 0
    self.extraBottom= 0
    self.cellUpdateQueue = {}
    
    --列表动画
    self.aniComp = nil
    self.animations = self.View.Animation
    --需要播放进入动画
    self.aniSetData = nil
    self.aniNotified = nil


    self:InitListAnimationData()
end
-- luacheck: pop



--TODO：临时解决方案，暂时无法获取panel的准确大小
function ComList:getSize()
    local vis = self.View.WidgetRoot:GetVisibility()
    if vis == ESlateVisibility.Collapsed or vis == ESlateVisibility.Hidden then
        return 
    end
    self:StartTimer("REFRESH_LIST_GET_SIZE", function()
        if not self.View then
            Log.Error("Timer Not End When UIComponent Dispose")
            return
        end
        --TODO:查一下被释放的界面
        if not IsValid_L(self:getRoot()) then
            Log.Error("Parent UI is free",self.owner.__cname)
            return
        end
        local size = self.getLocalSizeFun(self.getCachedGeometryFun(self:getRoot()))
        local widgetSize
        if self._waitGetItemSize then
            widgetSize = self.getLocalSizeFun(self.itemGetCachedGeometry(self.View.ScrollWidget))
        end
        if size.X == 0 or size.Y == 0 or ( widgetSize and (widgetSize.X == 0 or widgetSize.Y == 0)) then
            return self:getSize()
        end
        if self.bIsVertical then
            self.width = size.X - self.listPadding.Left - self.listPadding.Right
            self.height = size.Y
        else
            self.width = size.X
            self.height = size.Y - self.listPadding.Top - self.listPadding.Bottom
        end

        if self._waitGetItemSize then
            self.widgetX = widgetSize.X
            self.widgetY = widgetSize.Y
            self.View.ScrollWidget:SetVisibility(ESlateVisibility.Hidden)
        end

        if self.total then
            local min, max = self:getIndexMinAndMax(self.total)
            min = nil
            self.length = max
            if self.bIsVertical then
                self.tempPos.X = self.width
                self.tempPos.Y = max - self.spaceBottom + self.listPadding.Bottom
                self._diffPoint.Slot:SetPosition(self.tempPos)
            else
                self.tempPos.X = max - self.spaceRight + self.listPadding.Right
                self.tempPos.Y = self.length
                self._diffPoint.Slot:SetPosition(self.tempPos)
            end
        end

        if self._cacheIdx then
            self:ScrollToIndex(self._cacheIdx)
            self._cacheIdx = nil
        else
            self:onUserScrolled(self.oldOffect)
        end
        --设置滑动条隐藏
        self:getRoot():SetScrollBarVisibility(self.View.ScrollBarVisibility)
        if self.endPosYCallback then
            local endPosYCallback = self.endPosYCallback
            self.endPosYCallback = nil
            self:GetEndPosY(endPosYCallback)
        end
    end, 1, 1)

end

function ComList:getAutoSize()
    if not self._isShow then
        return
    end
        self:StartTimer("REFRESH_LIST_AUTO_SIZE", function()
            if not self.View then
                Log.Error("Timer Not End When UIComponent Dispose")
                return
            end
            
            local widgetSize
            local size = self.getLocalSizeFun(self.getCachedGeometryFun(self:getRoot()))
            if self._waitGetItemSize then
                widgetSize = self.getLocalSizeFun(self.itemGetCachedGeometry(self.View.ScrollWidget))
            end
            if size.X == 0 or size.Y == 0 or ( widgetSize and (widgetSize.X == 0 or widgetSize.Y == 0)) then
                return self:getAutoSize()
            end

            if self._waitGetItemSize then
                self.widgetX = widgetSize.X
                self.widgetY = widgetSize.Y
                self.View.ScrollWidget:SetVisibility(ESlateVisibility.Hidden)
            end

            if self.total then
                if self.bIsVertical then
                    local totalHeight = self.total * self.widgetY + (self.total - 1) * (self.spaceUp + self.spaceBottom)
                    self.width = size.X - self.listPadding.Left - self.listPadding.Right
                    if self.bIsTileView then
                        local tileLine = math.floor((self.width+self.spaceLeft+self.spaceRight)/(self.widgetX+self.spaceLeft+self.spaceRight))
                        local maxLineNum = math.ceil(self.total / tileLine)
                        totalHeight = maxLineNum * self.widgetY + (maxLineNum - 1) * (self.spaceUp + self.spaceBottom)
                    end
                    totalHeight = totalHeight + self.listPadding.Top + self.listPadding.Bottom
                    if totalHeight > self.maxSize then
                        self.height = self.maxSize
                    elseif totalHeight < self.minSize then
                        self.height = self.minSize
                    else
                        self.height = totalHeight
                    end
                else
                    local totalWidth = self.total * self.widgetX + (self.total - 1) * (self.spaceLeft + self.spaceRight)
                    self.height = size.Y - self.listPadding.Top - self.listPadding.Bottom
                    if self.bIsTileView then
                        local tileLine = math.floor((self.height+self.spaceUp+self.spaceBottom)/(self.widgetY+self.spaceUp+self.spaceBottom))
                        local maxLineNum = math.ceil(self.total / tileLine)
                        totalWidth = maxLineNum * self.widgetX + (maxLineNum - 1) * (self.spaceLeft + self.spaceRight)
                    end
                    totalWidth = totalWidth + self.listPadding.Left + self.listPadding.Right
                    if totalWidth > self.maxSize then
                        self.width = self.maxSize
                    elseif totalWidth < self.minSize then
                        self.width = self.minSize
                    else
                        self.width = totalWidth
                    end
                end
            end
            if self.retainerBox and self.retainerBox.Slot:IsA(import("CanvasPanelSlot")) then
                local slotSize = self.retainerBox.Slot:GetSize()
                slotSize.X = self.width
                slotSize.Y = self.height
                self.retainerBox.Slot:SetSize(slotSize)
            elseif self.View.WidgetRoot.Slot:IsA(import("CanvasPanelSlot")) then
                local slotSize = self.View.WidgetRoot.Slot:GetSize()
                slotSize.X = self.width
                slotSize.Y = self.height
                self.View.WidgetRoot.Slot:SetSize(slotSize)
            end
            if self.total then
                local min, max = self:getIndexMinAndMax(self.total)
                min = nil
                self.length = max
                if self.bIsVertical then
                    self.tempPos.X = self.width
                    self.tempPos.Y = max - self.spaceBottom + self.listPadding.Bottom
                    self._diffPoint.Slot:SetPosition(self.tempPos)
                else
                    self.tempPos.X = max - self.spaceRight + self.listPadding.Right
                    self.tempPos.Y = self.length
                    self._diffPoint.Slot:SetPosition(self.tempPos)
                end
            end

            if self._cacheIdx then
                self:ScrollToIndex(self._cacheIdx)
                self._cacheIdx = nil
            else
                self:getRoot():SetScrollOffset(self.oldOffect)
                self:onUserScrolled(self.oldOffect)
            end
            --设置滑动条隐藏
            self:getRoot():SetScrollBarVisibility(self.View.ScrollBarVisibility)
            if self.endPosYCallback then
                local endPosYCallback = self.endPosYCallback
                self.endPosYCallback = nil
                self:GetEndPosY(endPosYCallback)
            end
        end, 1, 1)
    
end

function ComList:checkSlotAndAnchors()
    if self.View.WidgetRoot.Slot and self.View.WidgetRoot.Slot:IsA(import("CanvasPanelSlot")) and (not self.bChildSizeToContent) then
        local anchor = self.View.WidgetRoot.Slot:GetAnchors()
        if anchor.Minimum.Y == anchor.Maximum.Y and anchor.Minimum.X == anchor.Maximum.X then
            return true
        end
    elseif self.retainerBox and self.retainerBox.Slot:IsA(import("CanvasPanelSlot")) and (not self.bChildSizeToContent) then
        local anchor = self.retainerBox.Slot:GetAnchors()
        if anchor.Minimum.Y == anchor.Maximum.Y and anchor.Minimum.X == anchor.Maximum.X then
            return true
        end
    end
    return false
end

function ComList:getIndexToPos(index)
    if index <= 0 then
        return -100000, -100000
    end
    local posX, posY
    if self.bIsVertical then
        if self.bIsTileView then
            local needAuto = false
            if self.bIsCenterContent then
                --自扩充
                local totalWidth = self.total*(self.widgetX+self.spaceLeft+self.spaceRight)
                local panelWidth = self.width+self.spaceRight+self.spaceLeft
                if panelWidth > totalWidth then
                    needAuto = true
                    local space = (panelWidth - totalWidth)/2
                    local numX = index - 1
                    posX = space + numX * (self.widgetX + self.spaceLeft + self.spaceRight) + self.listPadding.Left
                    posY = self.listPadding.Top
                end
            end
            if not needAuto then
                local mod = math.floor((self.width+self.spaceRight+self.spaceLeft)/(self.widgetX+self.spaceLeft+self.spaceRight))
                local floor = math.floor((index - 1) / mod)
                local numX = index - 1 - floor * mod
                if self.alignment == ComList.Alignment.Right then
                    local space = (self.width+self.spaceRight)%(self.widgetX+self.spaceLeft+self.spaceRight)
                    posX =  space + numX * (self.widgetX + self.spaceLeft + self.spaceRight)
                elseif self.alignment == ComList.Alignment.Center then
                    local space = (self.width+self.spaceRight)%(self.widgetX+self.spaceLeft+self.spaceRight)
                    posX =  space/2 + numX * (self.widgetX + self.spaceLeft + self.spaceRight)
                else
                    posX = numX * (self.widgetX + self.spaceLeft + self.spaceRight)
                end
                posX = posX + self.listPadding.Left
                posY = floor * (self.widgetY + self.spaceUp + self.spaceBottom) + self.listPadding.Top
            end
        else
            local needAuto = false
            if self.bIsCenterContent then
                --自扩充
                local totalHeight = self.total*(self.widgetY+self.spaceBottom+self.spaceUp)
                local panelHeight = self.height+self.spaceBottom+self.spaceUp
                if panelHeight > totalHeight then
                    needAuto = true
                    local space = (panelHeight - totalHeight)/2
                    local numY = index - 1
                    posX = self.listPadding.Left
                    posY = self.listPadding.Top + space + numY * (self.widgetY+self.spaceBottom+self.spaceUp)
                end
            end
            if not needAuto then
                if self.alignment == ComList.Alignment.Right then
                    local space = self.width - self.widgetX
                    posX = space
                elseif self.alignment == ComList.Alignment.Center then
                    local space = self.width - self.widgetX
                    posX = space/2
                else
                    posX = 0
                end
                posX = posX + self.listPadding.Left
                posY = (index-1) * (self.widgetY + self.spaceUp + self.spaceBottom) + self.listPadding.Top
            end
        end
    else
        if self.bIsTileView then
            local mod = math.floor((self.height+self.spaceBottom+self.spaceUp)/(self.widgetY+self.spaceUp+self.spaceBottom))
            local floor = math.floor((index - 1) / mod)
            local numY = index - 1 - floor * mod
            if self.alignment == ComList.Alignment.Bottom then
                local space = (self.height+self.spaceBottom)%(self.widgetY+self.spaceUp+self.spaceBottom)
                posY = space + numY * (self.widgetY + self.spaceUp + self.spaceBottom)
            elseif self.alignment == ComList.Alignment.Center then
                local space = (self.height+self.spaceBottom)%(self.widgetY+self.spaceUp+self.spaceBottom)
                posY = space/2 + numY * (self.widgetY + self.spaceUp + self.spaceBottom)
            else
                posY = numY * (self.widgetY + self.spaceUp + self.spaceBottom)
            end
            posY = posY + self.listPadding.Top
            posX = floor * (self.widgetX + self.spaceLeft + self.spaceRight) + self.listPadding.Left
        else
            local needAuto = false
            if self.bIsCenterContent then
                --自扩充
                local totalWidth = self.total*(self.widgetX+self.spaceLeft+self.spaceRight)
                local panelWidth = self.width+self.spaceRight
                if panelWidth > totalWidth then
                    needAuto = true
                    local space = (panelWidth - totalWidth)/2
                    local numX = index - 1
                    posX = space + numX * (self.widgetX + self.spaceLeft + self.spaceRight) + self.listPadding.Left

                    if self.alignment == ComList.Alignment.Bottom then
                        local tempSpace = self.height - self.widgetY
                        posY = tempSpace
                    elseif self.alignment == ComList.Alignment.Center then
                        local tempSpace = self.height - self.widgetY
                        posY = tempSpace/2
                    else
                        posY = 0
                    end

                    posY = posY + self.listPadding.Top
                end
            end
            if not needAuto then
                if self.alignment == ComList.Alignment.Bottom then
                    local space = self.height - self.widgetY
                    posY = space
                elseif self.alignment == ComList.Alignment.Center then
                    local space = self.height - self.widgetY
                    posY = space/2
                else
                    posY = 0
                end
                posY = posY + self.listPadding.Top
                posX = (index-1) * (self.widgetX + self.spaceLeft + self.spaceRight) + self.listPadding.Left
            end
        end
    end
    return posX, posY
end

function ComList:getPosToIndex(scrollOffset, verticalOffset)
    local index
    if self.bIsVertical then
        if self.bIsTileView then
            local needAuto = false
            if self.bIsCenterContent then
                --自扩充
                local totalWidth = self.total*(self.widgetX+self.spaceLeft+self.spaceRight)
                local panelWidth = self.width+self.spaceRight+self.spaceLeft
                if panelWidth > totalWidth then
                    needAuto = true
                    local space = (panelWidth - totalWidth)/2
                    if verticalOffset and verticalOffset > 0 then
                        index = math.floor((verticalOffset - space - self.listPadding.Left) / (self.widgetX + self.spaceLeft + self.spaceRight)) + 1
                    elseif verticalOffset and verticalOffset < 0 then
                        index = self.total
                    else
                        index = 1
                    end
                end
            end
            if not needAuto then
                local mod = math.floor((self.width+self.spaceRight+self.spaceLeft)/(self.widgetX+self.spaceLeft+self.spaceRight))
                local floor = math.floor((scrollOffset - self.listPadding.Top) / (self.widgetY + self.spaceUp + self.spaceBottom))
                
                if verticalOffset and verticalOffset > 0 then
                    if self.alignment == ComList.Alignment.Right then
                        local space = (self.width+self.spaceRight)%(self.widgetX+self.spaceLeft+self.spaceRight)
                        local numX = math.floor((verticalOffset - space) / (self.widgetX + self.spaceLeft + self.spaceRight))
                        index = numX + floor * mod + 1
                    elseif self.alignment == ComList.Alignment.Center then
                        local space = (self.width+self.spaceRight)%(self.widgetX+self.spaceLeft+self.spaceRight)
                        local numX = math.floor((verticalOffset - space/2) / (self.widgetX + self.spaceLeft + self.spaceRight))
                        index = numX + floor * mod + 1
                    else
                        local numX = math.floor(verticalOffset / (self.widgetX + self.spaceLeft + self.spaceRight))
                        index = numX + floor * mod + 1
                    end
                elseif verticalOffset and verticalOffset < 0 then
                    index = math.min((floor + 1) * mod, self.total)
                else
                    index = floor * mod + 1
                end
            end
        else
            local needAuto = false
            if self.bIsCenterContent then
                --自扩充
                local totalHeight = self.total*(self.widgetY+self.spaceBottom+self.spaceUp)
                local panelHeight = self.height+self.spaceBottom+self.spaceUp
                if panelHeight > totalHeight then
                    needAuto = true
                    local space = (panelHeight - totalHeight)/2
                    index = math.floor((scrollOffset - self.listPadding.Top - space) / (self.widgetY+self.spaceBottom+self.spaceUp)) + 1
                end
            end
            if not needAuto then
                index = math.floor((scrollOffset - self.listPadding.Top) / (self.widgetY + self.spaceUp + self.spaceBottom)) + 1 
            end
        end
    else
        if self.bIsTileView then
            local mod = math.floor((self.height+self.spaceBottom+self.spaceUp)/(self.widgetY+self.spaceUp+self.spaceBottom))
            local floor = math.floor((scrollOffset - self.listPadding.Left) / (self.widgetX + self.spaceLeft + self.spaceRight))
            if verticalOffset and verticalOffset > 0 then
                if self.alignment == ComList.Alignment.Bottom then
                    local space = (self.height+self.spaceBottom)%(self.widgetY+self.spaceUp+self.spaceBottom)
                    local numY = math.floor((verticalOffset - space) / (self.widgetY + self.spaceUp + self.spaceBottom))
                    index = numY + floor * mod + 1
                elseif self.alignment == ComList.Alignment.Center then
                    local space = (self.height+self.spaceBottom)%(self.widgetY+self.spaceUp+self.spaceBottom)
                    local numY = math.floor((verticalOffset - space/2) / (self.widgetY + self.spaceUp + self.spaceBottom))
                    index = numY + floor * mod + 1
                else
                    local numY = math.floor(verticalOffset / (self.widgetY + self.spaceUp + self.spaceBottom))
                    index = numY + floor * mod + 1
                end
            elseif verticalOffset and verticalOffset < 0 then
                index = math.min((floor + 1) * mod, self.total)
            else
                index = floor * mod + 1
            end
        else
            local needAuto = false
            if self.bIsCenterContent then
                --自扩充
                local totalWidth = self.total*(self.widgetX+self.spaceLeft+self.spaceRight)
                local panelWidth = self.width+self.spaceRight
                if panelWidth > totalWidth then
                    needAuto = true
                    local space = (panelWidth - totalWidth)/2
                    index = math.floor((scrollOffset - space - self.listPadding.Left) / (self.widgetX + self.spaceLeft + self.spaceRight)) + 1
                end
            end
            if not needAuto then
                index = math.floor((scrollOffset - self.listPadding.Left) / (self.widgetX + self.spaceLeft + self.spaceRight)) + 1
            end
        end
    end
    index = math.max(1,index)
    index = math.min(self.total, index)
    return index
end

function ComList:getIndexMinAndMax(index)
    local posX, posY = self:getIndexToPos(index)
    local min, max
    if self.bIsVertical then
        min = posY
        max = posY + self.widgetY + self.spaceBottom
    else
        min = posX
        max = posX + self.widgetX + self.spaceRight
    end

    return min, max
end

function ComList:onUserScrolled(currentOffset)
    if self.height == 0 or self.width == 0 then
        return
    end
    if self.bIsVertical then
        currentOffset = math.max(math.min(currentOffset, self.length-self.height- self.spaceBottom), 0)
    else
        currentOffset = math.max(math.min(currentOffset, self.length-self.width - self.spaceRight), 0)
    end
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

    local bottom
    if self.bIsVertical then
        bottom = currentOffset + self.height
    else
        bottom = currentOffset + self.width
    end
    
    local topidx = self:getPosToIndex(currentOffset)
    local btmidx = self:getPosToIndex(bottom, -1)
    self._topIndex = topidx
    self._bottomIndex = btmidx
    self.oldOffect = currentOffset
    self:checkRefresh(step > 0)
end

function ComList:checkRefresh(bUp)
    --先回收
    if bUp then
        if self._topIndex ~= self._oldTop then
            for i = self._oldTop, self._topIndex-1 do
                if self._cells[i] then
                    self.cellIndexs[self._cells[i]] = nil
                end
                self:setCell(self._cells[i], i)
                self._cells[i] = nil
            end
        end
    else
        if self._bottomIndex ~= self._oldBottom then
            for i = self._bottomIndex+1, self._oldBottom do
                if self._cells[i] then
                    self.cellIndexs[self._cells[i]] = nil
                end
                self:setCell(self._cells[i], i)
                self._cells[i] = nil
            end
        end
    end
    --再加载
    self._topIndex = math.min(self.total, self._topIndex)
    self._topIndex = math.max(self._topIndex, 1)
    self._bottomIndex = math.min(self._bottomIndex, self.total)

    self._oldTop = self._topIndex
    self._oldBottom = self._bottomIndex

    if self.bIsAsync then
        if not self:asynGetCell() then
            self:StartTimer("AsyncGetCell", function()
                if self:asynGetCell() then
                    self:StopTimer("AsyncGetCell")
                end
            end, 1, -1, nil, true)
        end
    else
        for i = self._topIndex, self._bottomIndex do
            if not self._cells[i] and self._indexToTopPos[i] ~= -100 then
                self._cells[i] = self:getCell(i)
                self.cellIndexs[self._cells[i]] = i
                --统一Refresh接口
                self:callRefreshFun(self.owner, self._cells[i], i, self:isSelected(i))
            end
        end
        
        self:refreshRetainerBox()
        
        --播放入场动画
        self:playListInAnimation()
    end
end


function ComList:asynGetCell()
    local bBreak = false
    self._tempAsyncNum = self.asyncNum
    for i = self._topIndex, self._bottomIndex do
        if not self._cells[i] and self._indexToTopPos[i] ~= -100 then
            local cell = self:getCell(i)
            if cell then
                self._cells[i] = cell
                self.cellIndexs[self._cells[i]] = i
                --统一Refresh接口
                self:callRefreshFun(self.owner, self._cells[i], i, self:isSelected(i))
            else
                bBreak = true
                break
            end
        end
    end
    self:refreshRetainerBox()

    --分帧暂时不支持播放入场动画
   
    if not bBreak then
        return true
    end
end

function ComList:refreshRetainerBox()
    if self.startIndex ~= self._oldTop then
        self.startIndex = self._oldTop
    end
    if self.owner[self.onStartIndexChangedCB] then
        self.owner[self.onStartIndexChangedCB](self.owner, self._oldTop)
    end

    if self.owner[self.onScrollToEndCB] then
        if (not self._bScrollToEnd) and self._bottomIndex == self.total then
            self._bScrollToEnd = true
            self.owner[self.onScrollToEndCB](self.owner)
        elseif self._bScrollToEnd and self._bottomIndex ~= self.total then
            self._bScrollToEnd = false
        end
    end

    if self.bIsVertical and self.dynamicMaterial then
        --纵向列表
        if self.oldOffect+self.height+self.spaceBottom >= self.length - 0.01 and self.oldOffect > 0.0 then --到底部没到顶部
            if not self.bEndFlag or self.bStartFlag then
                self.bEndFlag = true
                self.bStartFlag = false
                self:SetUpFadeV()
            end
        elseif self.oldOffect+self.height+self.spaceBottom < self.length - 0.01 and self.oldOffect <= 0.0 then --到顶部没到底部
            if not self.bStartFlag or self.bEndFlag then
                self.bStartFlag = true
                self.bEndFlag = false
                self:SetDownFadeV()
            end
        elseif self.oldOffect+self.height+self.spaceBottom < self.length - 0.01 and self.oldOffect > 0.0 then --没到顶部也没到底部
            if self.bEndFlag or self.bStartFlag then
                self.bStartFlag = false
                self.bEndFlag = false
                self:SetBothFadeV()
            end
        elseif not self.bEndFlag or not self.bStartFlag then --既到顶部又到底部
            self.bEndFlag = true
            self.bStartFlag = true
            self:CancelFade()
        end
        
    end
    if not self.bIsVertical and self.retainerBox and self.dynamicMaterial then
        --仅纵向列表有这个显示需求
        if self.oldOffect + self.width + self.spaceRight >= self.length - 0.01 and self.oldOffect > 0.0 then --到底部没到顶部
            if not self.bEndFlag or self.bStartFlag then
                self.bEndFlag = true
                self.bStartFlag = false
                self:SetUpFadeH()
            end
        elseif self.oldOffect + self.width + self.spaceRight < self.length - 0.01 and self.oldOffect <= 0.0 then --到顶部没到底部
            if not self.bStartFlag or self.bEndFlag then
                self.bStartFlag = true
                self.bEndFlag = false
                self:SetDownFadeH()
            end
        elseif self.oldOffect + self.width + self.spaceRight < self.length - 0.01 and self.oldOffect > 0.0 then --没到顶部也没到底部
            if self.bEndFlag or self.bStartFlag then
                self.bStartFlag = false
                self.bEndFlag = false
                self:SetBothFadeH()
            end
        elseif not self.bEndFlag or not self.bStartFlag then --既到顶部又到底部
            self.bEndFlag = true
            self.bStartFlag = true
            self:CancelFade()
        end
    end
end

function ComList:LockScroll(bLock)
    if bLock then
        self.View.List:SetVisibility(ESlateVisibility.HitTestInvisible)
        self.View.List:SetConsumeMouseWheel(import("EConsumeMouseWheel").Never)
    else
        self.View.List:SetVisibility(ESlateVisibility.Visible)
        self.View.List:SetConsumeMouseWheel(import("EConsumeMouseWheel").WhenScrollingPossible)
    end
end


function ComList:RemoveItem(index, key, useAutoAni, animation, callback)
    if index < 1 or index > self.total then
        return
    end
    local info = {
        operation = 0,
        index = index,
        animation = animation,
        callback = callback,
        useAutoAni = useAutoAni,
        anicfg = key,
    }
    table.insert(self.cellUpdateQueue, info)
    
    self:onCellUpdate(key, callback)
end

function ComList:AddItem(index, key, useAutoAni, animation, callback)
    if index < 1 or index > self.total + 1 then
        return
    end
    local info = {
        operation = 1,
        index = index,
        animation = animation,
        callback = callback,
        useAutoAni = useAutoAni,
        anicfg = key,
    }
    
    table.insert(self.cellUpdateQueue, info)
    self:onCellUpdate(key, callback)
end


function ComList:onCellUpdate(key, callback)
    local maxMoveTime = 0
    local newAddFlag = false
    local  needRepos ,rStart, rEnd, needMove, Anikey
    if not self.cellUpdating then
        self:StartTimer("UPDATE_CELL", function()
            if #self.cellUpdateQueue > 0 then
                for k = 1, #self.cellUpdateQueue, 1 do
                    --local updateInfo = self:popQueue(self.cellUpdateQueue)
                    local updateInfo = self.cellUpdateQueue[k]
                    if updateInfo.operation == 0 then
                        local cellidx = updateInfo.index
                        for i = 1, #self.removeCache, 1 do
                            if self.removeCache[i].index <= cellidx then
                                cellidx = cellidx + 1
                            end
                        end
                        local isAdding = false
                        for i = #self.addCache, 1, -1 do
                            if self.addCache[i].index == cellidx then
                                isAdding = true
                                local cell = self._cells[cellidx]
                                --cell:StopAllAnimations()
                                table.remove(self.addCache, i)
                            end
                        end
                        local cell = self._cells[cellidx]
                        local animation = updateInfo.animation
                        local useAutoAni = updateInfo.useAutoAni
                        if cell and animation and cell.View[animation] and not isAdding then
                            --有动画的延迟移除
                            self:PlayAnimation(cell.View.WidgetRoot, cell.View[animation], 0.0, 1, EUMGSequencePlayMode.Forward, 1, true, function()
                                --self:SetWidgetToAnimationStartInstantly(cell.View.WidgetRoot, cell.View[animation])
                                cell.View.WidgetRoot:SetVisibility(ESlateVisibility.Collapsed)
                                if callback then
                                    callback()
                                end
                                local aging = cell.View[animation]:GetEndTime()
                                self:refreshMoveCache(aging)
                            end)
                            local cache = {
                                index = cellidx,
                                key = key,
                                time = _G._now()
                            }
                            table.insert(self.removeCache, cache)
                        elseif cell and useAutoAni then
                            local cache = {
                                index = cellidx,
                                time = _G._now(),
                                key = key,
                            }
                            table.insert(self.removeCache, cache)
                            local nowTime = _G._now()
                            local cb = function()
                                cell.View.WidgetRoot:SetVisibility(ESlateVisibility.Collapsed)
                                if callback then
                                    callback()
                                end
                                local aging = (_G._now() - nowTime) / 1000
                                self:refreshMoveCache(aging)
                            end
                            self:PlayStateAnimation(cellidx, ListAnimationLibrary.CellState.Out, cb)
                            
                        else
                            --更新下标
                            for j = 1, #self.removeCache, 1 do
                                if self.removeCache[j].index > cellidx then
                                    self.removeCache[j].index = self.removeCache[j].index - 1
                                end
                            end
                            for j = 1, #self.addCache, 1 do
                                if self.addCache[j].index > cellidx then
                                    self.addCache[j].index = self.addCache[j].index - 1
                                end
                            end
                            --直接移除
                            self:removeSingleCell(cellidx, key)
                            if callback then
                                callback()
                            end
                        end
                        
                    elseif updateInfo.operation == 1 then
                        local cellidx = updateInfo.index
                        
                        --找到当前真正的位置
                        for i = 1, #self.removeCache, 1 do
                            if self.removeCache[i].index <= cellidx then
                                cellidx = cellidx + 1
                            end
                        end

                        --更新cache中的序号
                        for i = 1, #self.addCache, 1 do
                            if self.addCache[i].index >= cellidx then
                                self.addCache[i].index = self.addCache[i].index + 1
                            end
                        end
                        
                        for i = 1, #self.removeCache, 1 do
                            if self.removeCache[i].index >= cellidx then
                                self.removeCache[i].index = self.removeCache[i].index + 1
                            end
                        end

                        local bottom
        
                        if self.bIsVertical then
                            bottom = self.oldOffect + self.height
                        else
                            bottom = self.oldOffect + self.width
                        end
                        local newoffset
                        local posx, posy = self:getIndexToPos(cellidx)
                        if self.bIsVertical then
                            newoffset = posy
                        else
                            newoffset = posx
                        end
                        -- local cell = self._cells[cellidx]
                        local animation = updateInfo.animation
                        local useAutoAni = updateInfo.useAutoAni
                        if cellidx <= self._bottomIndex or newoffset <= bottom then
                            local cache = {
                                index = cellidx,
                                animation = animation,
                                callback = callback,
                                time = _G._now(),
                                useAutoAni = useAutoAni,
                            }
                            table.insert(self.addCache, cache)
                            newAddFlag = true
                            table.sort(self.addCache, function(a, b)
                                return a.index < b.index
                            end)

                            local moveTime = 0
                            if self._bottomIndex + 1 - cellidx > 0 and self.aniComp and key then
                                moveTime = self.aniComp:GetListAnimationEndTime(key, cellidx, self._bottomIndex - cellidx + 1) * 1000
                                --moveTime = (self._bottomIndex - cellidx - 1) * self.cellMoveFrequence + self.cellMoveDuration
                                
                            end
                            moveTime = moveTime or 0
                            if maxMoveTime < moveTime then
                                maxMoveTime = moveTime
                            end
                        end
                        
                        self:addSingleCell(cellidx, key)
                    end
                end
                if needRepos and rStart and rEnd and rStart<=rEnd then
                    if not needMove then
                        Anikey = nil
                    end
                    self:reCaculatePos(self._topIndex, self._bottomIndex, callback, Anikey)
                end
                if #self.addCache > 0 and newAddFlag then
                    self.cellAddTimerID = (self.cellAddTimerID + 1) % 100000
                    Log.Debug("DelayAdd")
                    self:StartTimer(self.cellAddTimerID, function()
                        self:refreshAddCache(maxMoveTime)
                    end, maxMoveTime, 1)
                end
                table.clear(self.cellUpdateQueue)
            else
                self:StopTimer("UPDATE_CELL")
                self.cellUpdating = false
            end
        end, 1, -1, nil)
        self.cellUpdating = true
    end
end

function ComList:refreshAddCache(aging)
    Log.Debug("refreshAddCache", aging, "num", #self.addCache)
    for i = #self.addCache, 1, -1 do
        Log.Debug("time", _G._now() - self.addCache[i].time)
        if _G._now() - self.addCache[i].time >= aging then
            local cellidx = self.addCache[i].index
            Log.Debug("cellidx", cellidx)
            local callback = self.addCache[i].callback
            local cell = self._cells[cellidx]
            Log.Debug("index", cellidx)
            if cell then
                local animation = self.addCache[i].animation
                local useAutoAni = self.addCache[i].useAutoAni
                if self.cell then
                    cell:Show()
                    -- uiComponent:Open()
                else
                    cell.WidgetRoot:SetVisibility(ESlateVisibility.Visible)
                end
                if animation and cell.View[animation] then
                    self:PlayAnimation(cell.View.WidgetRoot, cell.View[animation], 0.0, 1, EUMGSequencePlayMode.Forward, 1, false)
                elseif useAutoAni then
                    self:PlayStateAnimation(cellidx, ListAnimationLibrary.CellState.In, false)
                    
                end
                self:callRefreshFun(self.owner, cell, cellidx, self:isSelected(cell))
                Log.Debug("AddOne", cellidx)
            end
            if callback then
                callback()
            end
            table.remove(self.addCache, i)
        end
    end
end

function ComList:refreshMoveCache(aging)
    local nowTime = _G._now()
    for i = #self.removeCache, 1, -1 do
        if nowTime - self.removeCache[i].time >= aging * 1000 then
            local removeIdx = self.removeCache[i].index
            local moveKey = self.removeCache[i].key
            table.remove(self.removeCache, i)
            for j = 1, #self.removeCache, 1 do
                if self.removeCache[j].index > removeIdx then
                    self.removeCache[j].index = self.removeCache[j].index - 1
                end
            end
            for j = 1, #self.addCache, 1 do
                if self.addCache[j].index > removeIdx then
                    self.addCache[j].index = self.addCache[j].index - 1
                end
            end
            self:removeSingleCell(removeIdx, moveKey)
        end  
    end
end


function ComList:removeSingleCell(index, moveKey,callback)
    if index >= self._topIndex and index <= self._bottomIndex then
        if self._cells[index] then
            self.cellIndexs[self._cells[index]] = nil
        end
        self:setCell(self._cells[index], index)
        self._cells[index] = nil

        --重排列表
        for i = index + 1, self._bottomIndex, 1 do
            self._cells[i - 1] = self._cells[i]
            self.cellIndexs[self._cells[i - 1]] = i - 1
        end

        local bottom
        
        if self.bIsVertical then
            bottom = self.oldOffect + self.height
        else
            bottom = self.oldOffect + self.width
        end
        local bottomidx = self:getPosToIndex(bottom)
        if self._bottomIndex < self.total and self._bottomIndex <= bottomidx then
            self._cells[self._bottomIndex] = self:getCell(self._bottomIndex + 1)
            self.cellIndexs[self._cells[self._bottomIndex]] = self._bottomIndex
        else
            if self._cells[self._bottomIndex] then
                --self.cellIndexs[self._cells[self._bottomIndex]] = nil
                self._cells[self._bottomIndex] = nil
                
            end
            if self.extraBottom > 0 then
                self._bottomIndex = self._bottomIndex - 1
                self.extraBottom = self.extraBottom - 1
            end
    
        end
    end

    self.total = self.total - 1 
    self._bottomIndex = math.min(self._bottomIndex, self.total)
    self._oldBottom = self._bottomIndex

    if (self.minSize > 0 or self.maxSize > 0) and self:checkSlotAndAnchors() then
        self:getAutoSize()
    else
        if self.width > 0 and self.height > 0 then
            local min, max = self:getIndexMinAndMax(self.total)
            min = nil
            self.length = max
            if self.bIsVertical then
                self.tempPos.X = self.width
                self.tempPos.Y = max - self.spaceBottom
                self._diffPoint.Slot:SetPosition(self.tempPos)
            else
                self.tempPos.X = max - self.spaceRight
                self.tempPos.Y = self.length
                self._diffPoint.Slot:SetPosition(self.tempPos)
            end
            --self:onUserScrolled(self.oldOffect)
        else
            self:getSize()
        end
    end
    -- 重新计算显示
    
    if index < self._topIndex then
        local posX, posY = self:getIndexToPos(self._topIndex)
        local offset = self.oldOffect - posY
        posX, posY = self:getIndexToPos(self._topIndex - 1)
        offset = offset + posY
        self:getRoot():SetScrollOffset(offset)
        self:onUserScrolled(offset)
        self.oldOffect = offset
        self:reCaculatePos(self._topIndex, self._bottomIndex, callback, false)
        return
    end

    if index <= self._bottomIndex then
        self:reCaculatePos(index, self._bottomIndex, callback, false, moveKey)
    end
end

function ComList:addSingleCell(index, moveKey, callback)
    Log.Debug("ListAdd: ", index)
    local needRepos = false
    if index >= self._topIndex and index <= self._bottomIndex then
        --取出新cell
        local newcell = self:getCell(index)
        if self.cell then
            newcell:Hide()
            --newcell.View.WidgetRoot:SetVisibility(ESlateVisibility.Collapsed)
        else
            newcell.WidgetRoot:SetVisibility(ESlateVisibility.Collapsed)
        end
        
        local bottom
        
        if self.bIsVertical then
            bottom = self.oldOffect + self.height
        else
            bottom = self.oldOffect + self.width
        end
        
        if self._bottomIndex == self.total then
            --重排列表
            for i = self._bottomIndex + 1, index + 1, -1 do
                self._cells[i] = self._cells[i - 1]
                self.cellIndexs[self._cells[i]] = i
            end
            self._bottomIndex = self._bottomIndex + 1
        else
            local bottomidx
            bottomidx = self:getPosToIndex(bottom)
            if self._bottomIndex <= bottomidx then
                --重排列表
                for i = self._bottomIndex + 1, index + 1, -1 do
                    self._cells[i] = self._cells[i - 1]
                    self.cellIndexs[self._cells[i]] = i
                end
                self._bottomIndex = self._bottomIndex + 1
                self.extraBottom = self.extraBottom + 1
            else
                --回收旧的——bottom
                self:setCell(self._cells[self._bottomIndex], self._bottomIndex)
                self._cells[self._bottomIndex] = nil
                --重排列表
                for i = self._bottomIndex, index + 1, -1 do
                    self._cells[i] = self._cells[i - 1]
                    self.cellIndexs[self._cells[i]] = i
                end
            end
        end
        
        self._cells[index] = newcell
        self.cellIndexs[self._cells[index]] = index
        needRepos = true
    elseif index > self._bottomIndex then
        index = math.min(self._bottomIndex + 1, index)
        local bottom
        local newoffset
        local posx, posy = self:getIndexToPos(self._bottomIndex + 1)
        if self.bIsVertical then
            bottom = self.oldOffect + self.height
            newoffset = posy
        else
            bottom = self.oldOffect + self.width
            newoffset = posx
        end
        
        if newoffset < bottom then
            self._bottomIndex = self._bottomIndex + 1
            self._cells[self._bottomIndex] = self:getCell(self._bottomIndex)  
            needRepos = true
        end
    end

    self.total = self.total + 1 
    self._bottomIndex = math.min(self._bottomIndex, self.total)
    self._oldBottom = self._bottomIndex
    if (self.minSize > 0 or self.maxSize > 0) and self:checkSlotAndAnchors() then
        self:getAutoSize()
    else
        if self.width > 0 then
            local min, max = self:getIndexMinAndMax(self.total)
            min = nil
            self.length = max
            if self.bIsVertical then
                self.tempPos.X = self.width
                self.tempPos.Y = max - self.spaceBottom
                self._diffPoint.Slot:SetPosition(self.tempPos)
            else
                self.tempPos.X = max - self.spaceRight
                self.tempPos.Y = self.length
                self._diffPoint.Slot:SetPosition(self.tempPos)
            end
            --self:onUserScrolled(self.oldOffect)
        else
            self:getSize()
        end
    end
    if index < self._topIndex then
        local posX, posY = self:getIndexToPos(self._topIndex)
        local offset = self.oldOffect - posY
        posX, posY = self:getIndexToPos(self._topIndex + 1)
        offset = offset + posY
        self:getRoot():SetScrollOffset(offset)
        self:onUserScrolled(offset)
        self.oldOffect = offset
        self:reCaculatePos(self._topIndex, self._bottomIndex, callback, false)
        return
    end
    if needRepos then
        self:reCaculatePos(index + 1, self._bottomIndex, callback, true, moveKey) 
    end

end


function ComList:clearMoveCellData()
    table.clear(self.cellMoveData)
end

function ComList:updateCellMoveData(startIdx, endIdx, callback, bReverse)
    if not self.cellMoveData then
        self.cellMoveData = {}
    end
     
    local _startidx = startIdx
    local _endidx = endIdx
    local step = 1
    for i = 1, #self.cellMoveData, 1 do
        if self.cellMoveData[i].index < startIdx then
            startIdx = self.cellMoveData[i].index
        end
    end
    -- for i = 1, #self.cellMoveData, 1 do
    --     if self.cellMoveData[i] < startIdx then
    --         startIdx = self.cellMoveData[i]
    --     end
    -- end
    if bReverse then
         _startidx = endIdx
         _endidx = startIdx
         step = -1
    else
        _startidx = startIdx
        _endidx = endIdx
        step = 1
    end
    
    table.clear(self.cellMoveData)
    
    for i = _startidx, _endidx, step do
        local uiComponent = self._cells[i]
        local posX, posY = self:getIndexToPos(i)
        
        local nowPos
        local endCellPos = {}
        if self.cell then
            nowPos = uiComponent.View.WidgetRoot.Slot:GetPosition()
            local vb = uiComponent.View.WidgetRoot:GetVisibility()
            Log.Debug("MoveVisibility: ", i, vb)
            --uiComponent.View.WidgetRoot:SetVisibility(ESlateVisibility.Visible)
        else
            nowPos = uiComponent.WidgetRoot.Slot:GetPosition()
            local vb = uiComponent.WidgetRoot:GetVisibility()
            Log.Debug("MoveVisibility: ", i, vb)
            --uiComponent.WidgetRoot:SetVisibility(ESlateVisibility.Visible)
        end
        endCellPos.X = posX
        endCellPos.Y = posY
        local moveData = {
            index = i,
            cell = uiComponent,
            startPos = nowPos,
            endPos = endCellPos,
        }
        table.insert(self.cellMoveData, moveData)
        --table.insert(self.cellMoveData, i)
        
        self:callRefreshFun(self.owner, self._cells[i], i, self:isSelected(i))
    end

end

function ComList:reCaculatePos(startIdx, endIdx, callback, bReverse, movekey)
    self:updateCellMoveData(startIdx, endIdx, callback, bReverse)
    if movekey then
        local cb = function()
            self:clearMoveCellData()
            if callback then
                callback()
            end
            if #self.addCache then
                Log.Debug("EndMoveAdd", #self.addCache)
                self:refreshAddCache(0)
            end
            -- table.clear(self.addCache)
            -- table.clear(self.removeCache)
        end
        self:PlayListGroupAnimation(movekey, self.cellMoveData, cb)
        return
    end
    self:ForceMoveCell()
    self:clearMoveCellData()
end

function ComList:ForceMoveCell()
    if self.cellMoveData then
        local posData
    local cell
    local isOffset
    local newPos = self.tempPos   
    
    for i = 1, #self.cellMoveData, 1 do
        posData = self.cellMoveData[i]
        cell = self.cellMoveData[i].cell
        if cell then
            if not cell.WidgetRoot then cell = cell.View end
            
            if cell.Slot:GetAnchors().Maximum.X == 1 then
                isOffset = true
            else
                isOffset = false
            end
            newPos = posData.endPos
            if isOffset then
                local offsets = cell.Slot:GetOffsets()
                offsets.Left = newPos.X
                offsets.Right = -1 * newPos.X
                offsets.Top = newPos.Y
                cell.Slot:SetOffsets(offsets)
            else
                cell.Slot:SetPosition(newPos)
            end
        end
    end
    end
end

---@public @获取当前列表底部位置（只针对纵向列表且bIsCenterContent的情况的方法）
function ComList:GetEndPosY(callback)
    if self.width > 0 then
        local posY = self.height
        if self.bIsVertical then
            if not self.bIsTileView then
                if self.bIsCenterContent then
                    --自扩充
                    local totalHeight = self.total*(self.widgetY+self.spaceBottom+self.spaceUp)
                    local panelHeight = self.height+self.spaceBottom+self.spaceUp
                    if panelHeight > totalHeight then
                        local space = (panelHeight - totalHeight)/2
                        local numY = self.total - 1
                        posY = self.listPadding.Top + space + numY * (self.widgetY+self.spaceBottom+self.spaceUp) + self.widgetY
                    end
                end
            end
        end
        if callback then
            callback(posY)
        end
        return posY
    else
        --height不一定第一时间拿到
        self.endPosYCallback = callback
    end
end

function ComList:getRoot()
    return self.View.List
end

function ComList:GetCellIndex(cell)
    return self.cellIndexs[cell]
end

function ComList:EnableDoubleClick(enabled)
    self.doubleClickEnabled = enabled
end

function ComList:EnableRightClick(enabled)
    self.rightClickEnabled = enabled
end

function ComList:isSelected(index)
    if not self.multi then
        return self.selectedIndex and self.selectedIndex == index
    else
        return self.selectedIndexs[index] or false
    end
end

function ComList:SetSpaceLeft(spaceLeft)
    self.spaceLeft = spaceLeft
end

function ComList:SetSpaceRight(spaceRight)
    self.spaceRight = spaceRight
end

function ComList:SetConsumeMouseWheel(eConsumeMouseWheel)
    self:getRoot():SetConsumeMouseWheel(eConsumeMouseWheel)
end

---停止继续的滑动
function ComList:EndInertialScrolling()
    self:getRoot():EndInertialScrolling()
end
---点击处理
---@private
function ComList:HandleItemClicked(uiCell, bIsRightClick)
    if not self.enabled then return end
    if bIsRightClick and not self.rightClickEnabled then
        return
    end
    self:OnItemClicked(self.cellIndexs[uiCell], bIsRightClick)
end
---点击和刷新接口统一
function ComList:callRefreshFun(owner, component, index, bIsSelect)
    if bIsSelect == nil then
        if self.multi then
            bIsSelect = self.selectedIndexs[index]
        else
            bIsSelect = self.selectedIndex == index
        end
    end
    if self.cell and component.OnListRefresh and not self.parentFirst then
        self.isRefreshing = true
        xpcall(component.OnListRefresh, function (...)
            _G.CallBackError(...)
            self.isRefreshing = false
        end, component, self.owner, bIsSelect, self.datas, index)
        self.isRefreshing = false
        self:onRefreshItem(index, bIsSelect)
    elseif self.callback then
        self.callback(self.owner,component, index, bIsSelect)
        self:onRefreshItem(index, bIsSelect)
    end
end

---@private 调用OnClickcallback,点击事件回调
function ComList:callOnClickFun(owner, component, index, bIsRightClick)
    if self.cell and bIsRightClick and component.OnRightClick and not self.parentFirst then
        component:OnRightClick(self.owner, self.datas, index)
    elseif self.cell and component.OnClick and not self.parentFirst then
        component:OnClick(self.owner, self.datas, index)
    elseif self.onClick then
        self.onClick(self.owner, component, index)
    end
end
---@private 调用CanSelcallback,能否选中回调
function ComList:callCanSelFun(component, index)
    if self.cell and component.CanSel and not self.parentFirst then
        return component:CanSel(self.owner, self.datas, index)
    elseif self.canSel then
        return self.canSel(self.owner, index)
    else
        return true
    end
end
---@private 调用OnDoubleCcallback,双击事件回调
function ComList:callOnDoubleClickFun(component, index)
    if self.cell and component.OnDoubleClick and not self.parentFirst then
        component:OnDoubleClick(self.owner, self.datas, index)
    elseif self.onDoubleClick then
        self.onDoubleClick(self.owner,component,index)
    end
end

function ComList:callOnLongPressFun(component, index)
    if self.cell and component.OnLongPress and not self.parentFirst then
        component:OnLongPress(self.owner, self.datas, index)
    elseif self.onLongPress then
        self.onLongPress(self.owner, component, index)
    end
end

function ComList:callOnReleasedFun(component, index)
    if self.cell and component.OnReleased then
        component:OnReleased(self.owner, self.datas, index)
    end
end

---父界面点击处理(区分单击和双击)
---@private
function ComList:OnItemClicked(index, bIsRightClick)
    -- Log.Warning("[ComList] OnItemClicked ", index)
    local r = self:GetRendererAt(index)
    local id = self:GetUniqueID(r)
    if self.blong[id] then return end
    if not self.doubleClickEnabled then
        self:OnItemClickedex(index, bIsRightClick)
        return
    end
    local t = self.lastClickTimes[index]
    local name = self.timeName .. id
    if t then
        --- 双击
        self.owner:StopTimer(name)
        self.lastClickTimes[index] = nil
        self:OnItemDoubleClicked(index)
    else
        self.lastClickTimes[index] = _now()
        self.owner:StartTimer(name, function()
            self.lastClickTimes[index] = nil
            self:OnItemClickedex(index, bIsRightClick)
        end, Enum.EConstFloatData.DOUBLE_CLICK_INTERVAL, 1)
    end
end

function ComList:OnItemClickedex(index, bIsRightClick)
    local multi = self.multi
    local toggle = self.toggle
    local owner = self.owner
    local widget = self:GetRendererAt(index)
    --local canSel = not self.canSel or self.canSel(owner, index)
    local canSel
    if widget then
        canSel = self:callCanSelFun(widget, index)
    else
        canSel = false
    end
    --只能单选的列表
    if not multi then
        if self.selectedIndex and self.selectedIndex == index then
            local r = self:GetRendererAt(index)
            if toggle then
                if r then
                    self:callRefreshFun(owner, r, index, false)
                    --self:playAutoAni(index, false)
                    self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
                end
                self.selectedIndex = -1
            end
            if r then
                self:callOnClickFun(owner, r, index, bIsRightClick)
            end
            return
        end
        local oldIndex = self.selectedIndex
        if canSel and oldIndex and oldIndex > 0 then
            local r = self:GetRendererAt(oldIndex)
            if r then
                self:callRefreshFun(owner, r, oldIndex, false)
                --self:playAutoAni(oldIndex, false)
                self:PlayStateAnimation(oldIndex, ListAnimationLibrary.CellState.UnSelect)
            end
        end
        if canSel then
            self.selectedIndex = index
        end
        local r = self:GetRendererAt(index)
        if r then
            if canSel then
                self:callRefreshFun(owner, r, index, true)
                --self:playAutoAni(index, true)
                self:PlayStateAnimation(index, ListAnimationLibrary.CellState.Select)
            end
            self:callOnClickFun(owner, r, index, bIsRightClick)
        end
        return
    end
    --可以多选的列表
    local selected = not self.selectedIndexs[index]
    local r = self:GetRendererAt(index)
    if r then
        if (not selected) or canSel then
            self:callRefreshFun(owner, r, index, selected)
            if selected then
                self:PlayStateAnimation(index, ListAnimationLibrary.CellState.Select)
            else
                self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
            end
            --self:playAutoAni(index, selected)
            
        end
    end
    if (not selected) or canSel then
        self.selectedIndexs[index] = selected
    end
    if r then
        self:callOnClickFun(owner, r, index, bIsRightClick)
    end
end

function ComList:OnItemDoubleClicked(index)
    local r = self:GetRendererAt(index)
    if r then
        Log.Debug("[ComList] onDoubleClick", index)
        self:callOnDoubleClickFun(r, index)
    end
end

function ComList:GetUniqueID(UIComponent)
    if not UIComponent then
        Log.WarningFormat("ComList GetUniqueID With Nil UIComponent")
        return 0
    end
    if self.cell then
        return UIComponent.View.WidgetRoot:GetUniqueID()
    else
        return UIComponent.WidgetRoot:GetUniqueID()
    end
end

---按下处理(区分长按与单击)
---@private
function ComList:OnItemPressed(index)
    -- Log.Warning("[ComList] OnPressed ", index)

    local r = self:GetRendererAt(index)
    local id = self:GetUniqueID(r)
    self.blong[id] = false
    local name = self.timePressName .. id
    self.owner:StartTimer(name, function()
        -- Log.Warning("[ComList] onLongPress", index)
        self.blong[id] = true

        self:callOnLongPressFun(r, index)

    end, Enum.EConstFloatData.DOUBLE_CLICK_INTERVAL, 1)
end

function ComList:OnItemReleased(index)
    -- Log.Warning("[ComList] OnItemReleased ", index)
    local r = self:GetRendererAt(index)
    if not r then return end
    local id = self:GetUniqueID(r)
    local name = self.timePressName .. id
    self.owner:StopTimer(name)
    self:callOnReleasedFun(r, index)
end

function ComList:doRefresh()
    for i, widget in pairs(self._cells) do
        local selected
        if self.multi then
            selected = self.selectedIndexs[i] or false
        else
            selected = self.selectedIndex and self.selectedIndex == i
        end

        self:callRefreshFun(self.owner, widget, i, selected)

    end
end

function ComList:clearCell()
    for i = self._bottomIndex, self._topIndex, -1 do
        self:setCell(self._cells[i], i)
    end
    table.clear(self._cells)
    table.clear(self.cellIndexs)
end

---刷新滚动列表
---@public
---@param total number @滚动列表显示的数据的总数
---@param top number @让滚动列表瞬间滚动到第几条数据对应的格子(同ScrollToIndex,top为nil的时候滚动列表待在以前的状态)
---@param binAni bool 是否在本次刷新时播放入场动画
function ComList:SetData(total, top, inAni)
    if self.isRefreshing == true then
        Log.Error("Cannot SetData in OnRefresh")
        return
    end
    self.extraBottom = 0
    self:LockScroll(false)
    self.aniSetData = inAni
    local oldTotal = self.total
    if self.total and self.total ~= total then
        self.total = total
        self:clearCell()
        if (self.minSize > 0 or self.maxSize > 0) and self:checkSlotAndAnchors() then
            self:getAutoSize()
        else
            if self.width > 0 or self.height > 0 then
                local min, max = self:getIndexMinAndMax(self.total)
                min = nil
                self.length = max
                if self.bIsVertical then
                    self.tempPos.X = self.width
                    self.tempPos.Y = max - self.spaceBottom
                    self._diffPoint.Slot:SetPosition(self.tempPos)
                else
                    self.tempPos.X = max - self.spaceRight
                    self.tempPos.Y = self.length
                    self._diffPoint.Slot:SetPosition(self.tempPos)
                end
                self:getRoot():SetScrollOffset(self.oldOffect)
                self:onUserScrolled(self.oldOffect)
            else
                self:getSize()
            end
        end
    else
        self:doRefresh()
        self:playListInAnimation()
    end
    
    if top then
        self:ScrollToIndex(top)
    elseif oldTotal < 0 then
        -- self:GetViewRoot():SetCurrentScrollOffsetDefault()
        self:ScrollToIndex(1)
    else
        -- 经反馈, 取消自动滚动到末尾
        -- self:ScrollToIndex(self.total)
    end

end

---获得第多少条数据对应哪个格子
---@public
function ComList:GetRendererAt(index)
    return self._cells[index]
end

---@public 让滚动列表瞬间滚动到第几条数据对应的格子
---@param index number 索引
function ComList:ScrollToIndex(index)
    -- Log.Warning("ScrollToIndex self.name ", self.name, " index ", index)
	if (index <= 0 or index > self.total) then
        return
    end
    if self.width == 0 or self.height == 0 then
        self._cacheIdx = index
        return
    end
    local posX, posY = self:getIndexToPos(index)
    local offect
    if self.bIsVertical then
        offect = posY
    else
        offect = posX
    end
    self:getRoot():SetScrollOffset(offect)
    self:onUserScrolled(offect)
end

---@public 选中第几个数据所在的格子，需要在按钮的click里去设置
---@param index number 索引
function ComList:Sel(index)
    if not self.multi then
        index = index or self.selectedIndex or 1
        if index < 1 then index = 1 end
        if index > self.total then index = self.total end
        if self.selectedIndex == index then return end
        local oldIndex = self.selectedIndex
        self.selectedIndex = index
        --local cb = self.callback
        --if not cb then return end
        if oldIndex and oldIndex >= 0 then
            local r = self:GetRendererAt(oldIndex)
            if r then

                self:callRefreshFun(self.owner, r, oldIndex, false)
                self:PlayStateAnimation(oldIndex, ListAnimationLibrary.CellState.UnSelect)
                Log.Debug("ListUnSelect", oldIndex)
            end
        end
        local r = self:GetRendererAt(index)
        if r then
            self:callRefreshFun(self.owner, r, index, true)
            self:PlayStateAnimation(index, ListAnimationLibrary.CellState.Select)
            Log.Debug("ListSelect",index )
        end
        return
    end
    index = index or 1
    if index < 1 then index = 1 end
    if index > self.total then index = self.total end
    self.selectedIndexs[index] = true
    local r = self:GetRendererAt(index)
    if r then
        self:callRefreshFun(self.owner, r, index, true)
    end
end

---@public 如果index对应的格子在显示就执行Refresh方法刷新此格子
---@param index number 传需要刷新的格子的index
function ComList:RefreshCell(index)
    if not index then
        return
    end
    if index < 1 then index = 1 end
    if index > self.total then index = self.total end
    local r = self:GetRendererAt(index)
    if r then
        --统一Refresh接口
        self:callRefreshFun(self.owner, r, index)
    end
end

---取消选中第几个数据所在的格子
---@public
---@param index number 单选列表只能取消当前选中的，不用传参数，多选列表需要传取消选中的是哪一个
function ComList:CancelSel(index)
    if not self.multi then
        local oldIndex = self.selectedIndex
        if oldIndex and oldIndex > 0 then
            local r = self:GetRendererAt(oldIndex)
            if r then

                self:callRefreshFun(self.owner, r, oldIndex, false)
                self:PlayStateAnimation(oldIndex, ListAnimationLibrary.CellState.UnSelect)
            end
        end
        self.selectedIndex = -1
        return
    end
    if index < 1 then index = 1 end
    if index > self.total then index = self.total end
    if not self.selectedIndexs[index] then
        return
    end
    self.selectedIndexs[index] = false
    local r = self:GetRendererAt(index)
    if r then

        self:callRefreshFun(self.owner, r, index, false)
        self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
    end
end

---取消选中所有格子
---@public
function ComList:CancelAllSel()
    if not self.multi then
        local oldIndex = self.selectedIndex
        if oldIndex and oldIndex > 0 then
            local r = self:GetRendererAt(oldIndex)
            if r then

                self:callRefreshFun(self.owner, r, oldIndex, false)

            end
        end
        self.selectedIndex = -1
        return
    end
    for index, v in next, self.selectedIndexs do
        if v then
            self.selectedIndexs[index] = false
            local r = self:GetRendererAt(index)
            if r then

                self:callRefreshFun(self.owner, r, index, false)

            end
        end
    end
    table.clear(self.selectedIndexs)
end

function ComList:setCell(uiCell, index)
    if uiCell then
        Log.Debug("SetCell", index)
        self:onSetCell(index)
        if self.libWidget then
            local btn = self:getAutoButton(uiCell)
            if btn then
                self:RemoveUIListener(_G.EUIEventTypes.CLICK, btn)
                self:RemoveUIListener(_G.EUIEventTypes.Pressed, btn)
                self:RemoveUIListener(_G.EUIEventTypes.Released, btn)
                self:RemoveUIListener(_G.EUIEventTypes.RightClick, btn)
            end
            self:PushOneComponent(self._panel, uiCell)
        else
            local uiCells = self.uiCells
            uiCells[#uiCells+1] = uiCell
            if self.cell then
                uiCell:Hide()
                -- uiCell:Close()
            else
                local widget = uiCell.WidgetRoot
                widget:SetVisibility(ESlateVisibility.Collapsed)
            end
        end
    end
end

function ComList:getAutoButton(uiComponent)
    local btn
    -- if self.buttonPath then
    --     btn = uiComponent.View
    --     for key, value in pairs(self.buttonPath) do
    --         btn = btn[value]
    --         if not btn then
    --             break
    --         end
    --     end
    -- end
    if not btn then
        btn = uiComponent.View.Btn_ClickArea ~= nil and uiComponent.View.Btn_ClickArea or uiComponent.View.Big_Button_ClickArea
    end
    return btn
end

function ComList:addClickListener(uiComponent)
    --todo 后续wbp里命名都统一成Btn_ClickArea，目前为了防止旧资源报错，先加上保护措施
    local btn = self:getAutoButton(uiComponent)
    if btn then
        UIComponent.AddUIListener(self, EUIEventTypes.CLICK, btn, "HandleItemClicked", uiComponent)
        UIComponent.AddUIListener(self, EUIEventTypes.RightClick, btn, "HandleItemClicked", uiComponent, true)
        --if self.onLongPress then
            if not self.timePressName then
                self.timePressName = self.timeName .. "Press"
            end
            UIComponent.AddUIListener(self, EUIEventTypes.Pressed, btn, function()
                if not self.enabled then return end
                self:OnItemPressed(self.cellIndexs[uiComponent])
            end)
            UIComponent.AddUIListener(self, EUIEventTypes.Released, btn, function()
                if not self.enabled then return end
                self:OnItemReleased(self.cellIndexs[uiComponent])
            end)
        --end
    end
end

---得到滚动列表里的组件
---@param index number 第多少个
---@return UIController
function ComList:getCell(index)
    -- local widget = self:getWidget()
    local uiComponent
    if self.libWidget then
        --formcomponent
        uiComponent = self:FormComponent(self.libWidget, self._panel, self.cell)
        uiComponent.View.WidgetRoot.Slot:SetAutoSize(self.bChildSizeToContent)
        uiComponent.View.WidgetRoot.Slot:SetAnchors(self._defaultAnchors)
        self.tempPos.X = 0
        self.tempPos.Y = 0
        uiComponent.View.WidgetRoot.Slot:SetAlignment(self.tempPos)
        self.tempPos.X = self.widgetX
        self.tempPos.Y = self.widgetY
        uiComponent.View.WidgetRoot.Slot:SetSize(self.tempPos)
        self:addClickListener(uiComponent)
    else
        --createwidget
        local uiCells = self.uiCells
        if #uiCells > 0 then
            uiComponent = uiCells[#uiCells]
            uiCells[#uiCells] = nil
            if self.cell then
                uiComponent:Show()
                -- uiComponent:Open()
            else
                uiComponent.WidgetRoot:SetVisibility(ESlateVisibility.Visible)
            end
        else
            if self.bIsAsync then
                if self._tempAsyncNum <= 0 then
                    return
                end
                self._tempAsyncNum = self._tempAsyncNum - 1
            end
            local template = self.View.ScrollWidget
            local widget =  import("UIFunctionLibrary").C7CreateWidget(self.owner:GetViewRoot(), self._panel, template)
            table.insert(self.rawItems, widget)

            local wSlot = widget.Slot
            if self.tempAnchor then
                wSlot:SetAnchors(self.tempAnchor)
                self.tempPos.X = 0
                self.tempPos.Y = 0
                wSlot:SetAlignment(self.tempPos)
                self.tempPos.X = self.widgetX
                self.tempPos.Y = self.widgetY
                wSlot:SetSize(self.tempPos)
            else
                local tSlot = template.Slot
                wSlot:SetAnchors(tSlot:GetAnchors())
                wSlot:SetAlignment(tSlot:GetAlignment())
                wSlot:SetSize(tSlot:GetSize())
            end
            wSlot:SetAutoSize(self.bChildSizeToContent)
            uiComponent = self:BindListComponent(self.name, widget, self.cell, self.GetCellIndex, self, true)
            if uiComponent.UpdateObjectNum then
                uiComponent:UpdateObjectNum(UIHelper.GetObjectNum(widget))
            end
            if not self.cell and self._cellListeners then
                for eventType, listeners in next, self._cellListeners do
                    for names, v in next, listeners do
                        local c = uiComponent
                        for i = 1, #names do
                            c = c[names[i]]
                            if not c then
                                break
                            end
                        end
                        if c then
                            UIComponent.AddUIListener(self, eventType, c, v[1], uiComponent)
                        end
                    end
                end
            end
            self:addClickListener(uiComponent)
            if self.cell then
                uiComponent:Show()
                -- uiComponent:Open()
            else
                uiComponent.WidgetRoot:SetVisibility(ESlateVisibility.Visible)
            end
            -- self.owner:AddObjectNum(self.oneObjNum)
        end
    end

    local posX, posY = self:getIndexToPos(index)
    self.tempPos.X = posX
    self.tempPos.Y = posY
    if self.cell then
        uiComponent.View.WidgetRoot.Slot:SetPosition(self.tempPos)
        -- local pos = uiComponent.View.WidgetRoot.Slot:GetPosition(self.tempPos)
        -- Log.Debug("listAnimation: GetPos:", posY, ",", pos)
    else
        uiComponent.WidgetRoot.Slot:SetPosition(self.tempPos)
        -- local pos = uiComponent.WidgetRoot.Slot:GetPosition()
        -- Log.Debug("listAnimation: GetPos:", posY, ",", pos)
    end
    
    ---@type UIController
    -- local uiCell = self.uiCells[widget]
    -- if uiCell then
    --     return uiCell
    -- end
    -- uiCell = self:BindListComponent(self.name, widget, self.cell, self.GetCellIndex, self, true)

    -- self.uiCells[widget] = uiCell
    -- self.cellMap[uiCell] = widget
    --事件
    self.View.OnSetItem:BroadCast(uiComponent.View.WidgetRoot)

    return uiComponent
end

---得到滚动列表里的已使用的百分比
---@public
function ComList:GetDistancePercent()
    return self:GetViewRoot():GetDistancePercent()
end

---得到滚动列表里的未使用的百分比
---@public
function ComList:GetDistancePercentRemaining()
    return self:GetViewRoot():GetDistancePercentRemaining()
end

---得到滚动列表里的ScrollOffset，指的是可见的第一个元素的偏移
---@public
function ComList:GetScrollOffset()
    return self:getRoot():GetScrollOffset()
end

---设置滚动列表是否开启禁止过度滚动
---@public
---@param newAllowOverscroll bool true允许过度滚动，false不允许过度滚动
function ComList:SetAllowOverscroll(newAllowOverscroll)
    return self:GetViewRoot():SetAllowOverscroll(newAllowOverscroll)
end

---设置滚动列表是否开启循环滚动，循环滚动是高度特化的滚动列表，仅在比较少见的专用情况下使用
---@public
---@param newAllowLoopScroll bool true允许循环滚动，false不允许循环滚动
function ComList:SetAllowLoopScroll(newAllowLoopScroll)
    return self:GetViewRoot():SetAllowLoopScroll(newAllowLoopScroll)
end

function ComList:SetSingleToggle(bSingleToggle)
    if self.multi then
        self:SetMulti(false)
    end

    self.toggle = bSingleToggle

end


---设置滚动列表是否能多选
---@public
---@param multi boolean @是否多选
function ComList.SetMulti(self, multi)
    if multi then
        -- self:GetViewRoot():SetSelectionMode(import("ESelectionMode").Multi)
        local index = self.selectedIndex
        if index then
            local r = self:GetRendererAt(index)
            if r then

                self:callRefreshFun(self.owner, r, index, false)

            end
            self.selectedIndex = nil
        end
        table.clear(self.selectedIndexs)
    else

        for index, selected in next, self.selectedIndexs do
            if selected then
                local r = self:GetRendererAt(index)
                if r then

                    self:callRefreshFun(self.owner, r, index, false)

                end
            end
        end

        table.clear(self.selectedIndexs)
        self.selectedIndex = nil
        -- if self.toggle then
            -- self:GetViewRoot():SetSelectionMode(import("ESelectionMode").SingleToggle)
        -- else
            -- self:GetViewRoot():SetSelectionMode(import("ESelectionMode").Single)
        -- end
    end
    self.multi = multi
end

---获得选中的数据
---@public
---@return number|number[] 选中的数据
function ComList:GetSelectedIndex()
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

---设置列表能不能点击和滑动
---@public
---@param enable boolean @开关
function ComList:SetEnabled(enabled)
    self.enabled = enabled
end

---@屏幕分辨率变化
function ComList:OnViewportResize()
    self.bMarkViewportResize = true
    if self.bEnable then
        self:UpdateSize()
    end
end

function ComList:OnOpen()
    if self.cell then
        for index, cell in pairs(self._cells) do
            cell:Show()
            cell:Open()
        end
    end
    if self.width == 0 or self.height == 0 or (self._waitGetItemSize and self.widgetX == 0 and self.widgetY == 0) then
        if (self.minSize > 0 or self.maxSize > 0) and self:checkSlotAndAnchors() then
            return self:getAutoSize()
        else
            return self:getSize()
        end
        
    end
     -- local owner = self.owner
    -- owner:StartTimer(self.timeName .. 'time', function()
    --     if not next(self.newItems) then
    --         return
    --     end
    --     local cnt = 0
    --     while cnt <= 30 and next(self.newItems) do
    --         local item = table.remove(self.newItems, 1)
    --         local widget = table.remove(self.newItems, 1)
    --         self:OnEntryInitializedExt(item, widget)
    --         cnt = cnt + 1
    --     end
    -- end, 10, -1, nil, true)
    self.bEnable = true
    if self.bMarkViewportResize then
        self:UpdateSize()
    end
end

---list容器只处理子Component的Show和Hide,不处理OnRefresh
function ComList:OnRefresh()
    
end

function ComList:OnClose()
    UIBase.OnClose(self)
    if self.cell then
        for index, cell in pairs(self._cells) do
            cell:Hide()
            cell:Close()
        end
    end
    self.aniNotified = nil
    self.aniSetData = nil
    table.clear(self.lastClickTimes)
end

function ComList:OnDestroy()
    self:StopAllTimer()
    self:clearCell()
    for i, widget in next, self.rawItems do
        self:UnbindListComponent(widget)
    end
    self.ClickAudioFunc = nil
    self.rawItems = nil
    self.uiCells = nil
    self.scrollItems = nil
    self.cellIndexs = nil
    self.owner = nil
    self.aniComp = nil
    UIBase.OnDestroy(self)
end


function ComList:OnListClickedPlayAudio(Callback)
    self.ClickAudioFunc = Callback
end

function ComList:AddSafeRefreshFun(Callback)
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

function ComList:RemoveSafeRefreshFun()
    return self.callback
end

---- 注册UI事件
---@public
---@param eventType EUIEventTypes @事件类型
---@param widget string @控件路径
---@param func string @回调方法
---@param params any @参数
function ComList:AddUIListener(eventType, widget, func, params)
    if type(widget) == "string" then
        if not self._cellListeners then
            self._cellListeners = {}
        end
        local listeners = self._cellListeners[eventType]
        if not listeners then
            listeners = {}
            self._cellListeners[eventType] = listeners
        end
        local nfun = func .. "list"
        local arr = string.split(widget, "/")
        listeners[arr] = {nfun, params}
        self[nfun] = function(list, ...)
			local tmpParam = table.pack(...)
			local cellIndex = self:GetCellIndex(tmpParam[tmpParam.n])
			tmpParam[tmpParam.n] = cellIndex
			list.parent[func](list.parent, table.unpack(tmpParam))
        end
        return
    end
    UIComponent.AddUIListener(self, eventType, widget, func, params)
end

---@public 重新刷新ListPanel大小，会触发List更新位置
function ComList:UpdateSize()
    if self.reSizeCount > 10 then
        self.reSizeCount = 0
    end
    if (self.minSize > 0 or self.maxSize > 0) and self:checkSlotAndAnchors() then
        --self:getAutoSize()
        self.bMarkViewportResize = nil
        return
    end
    self:StartTimer("REFRESH_LIST_UPDATE_SIZE", function()
        local size = self.getLocalSizeFun(self.getCachedGeometryFun(self:getRoot()))
        local width, height
        if self.bIsVertical then
            width = size.X - self.listPadding.Left - self.listPadding.Right
            height = size.Y
        else
            width = size.X
            height = size.Y - self.listPadding.Top - self.listPadding.Bottom
        end
        self.reSizeCount = self.reSizeCount + 1
        if width == self.width and height == self.height and self.reSizeCount < 10 then
            return self:UpdateSize()
        end
        self:clearCell()
        local min, max = self:getIndexMinAndMax(self.total)
        min = nil
        self.length = max
        if self.bIsVertical then
            self.tempPos.X = self.width
            self.tempPos.Y = max - self.spaceBottom
            self._diffPoint.Slot:SetPosition(self.tempPos)
        else
            self.tempPos.X = max - self.spaceRight
            self.tempPos.Y = self.length
            self._diffPoint.Slot:SetPosition(self.tempPos)
        end
		self.height = height
		self.width = width
        self.reSizeCount = self.reSizeCount + 1
        self.bMarkViewportResize = nil
        if self._cacheIdx then
            self:ScrollToIndex(self._cacheIdx)
            self._cacheIdx = nil
        else
            self:onUserScrolled(self.oldOffect)
        end
    end, 1, 1)
end

--动画方法

--加载全部动画配置
function ComList:InitListAnimationData()
    if self.animations:Num() > 0 then
        local cmp = ComListAniComp.new(self)
        self.aniComp = cmp
        for key, cfg in pairs(self.animations) do
            self.aniComp:AddAnimationConfig(key, cfg)
            self:EnableAutoAnimation(key,"WidgetRoot")
        end
    end
    
end

--根据配置加载动画播放组件

--加载动画播放组件

function ComList:onNotifyPlayListAnimation(index)
    if self.total > 0 and next(self._cells) then
        self.aniNotified = index
        self:getRoot():EndInertialScrolling()
        self:PlayListGroupAnimation(self.aniNotified,nil, nil,1)
        self.aniSetData = nil
        self.aniNotified = nil
    else
        self.aniNotified = index
    end
    
end
--播放入场动画
function ComList:playListInAnimation()
    if (self.aniSetData and self:checkAnimationConfig(self.aniSetData)) or self:checkAnimationConfig(self.aniNotified) then
        self:getRoot():EndInertialScrolling()
        self:PlayListGroupAnimation(self.aniNotified or self.aniSetData, nil,nil, 1)
        self.aniSetData = nil
        self.aniNotified = nil
    end
end


function ComList:checkAnimationConfig(configIdx, isAniNotify)
    if not isAniNotify and not self.aniSetData then
        return false
    end
    if not self._cells or not next(self._cells) then
        return false
    end
    return true
end

function ComList:PlayListGroupAnimation(key, cells, callback, forceEnd)
    if self.aniComp then
        if not cells then
            cells = {}
            for i = self._topIndex, self._bottomIndex, 1 do
                if self._cells[i] then
                    table.insert(cells, {index = i})
                end
            end
            if #cells > 0 then
                self.aniComp:PlayListGroupAnimation(key, cells, callback, forceEnd)
            end
        else
            self.aniComp:PlayListGroupAnimation(key, cells, callback, forceEnd)    
        end
    end
   
end

function ComList:EnableAutoAnimation(key, widget)
    if self.aniComp then
        self.aniComp:EnableAutoAnimation(key, widget)
    end
end

function ComList:DisableAutoAnimation(key, widget)
    if self.aniComp then
        self.aniComp:DisableAutoAnimation(key, widget)
    end
end
function ComList:PlayStateAnimation(index, state, bRestoreState, callback)
    if self.aniComp then
        self.aniComp:PlayStateAnimation(index, state, bRestoreState, callback)
    end
end

function ComList:onRefreshItem(index, bSelected)
    if self.aniComp then
        self.aniComp:RefreshCellUpdateAni(index, bSelected)
    end
end

function ComList:onSetCell(index)
    if self.aniComp then
        self.aniComp:setCellUpdateAni(index)
    end
end
----------------------------------------------------------------------------------------
    



