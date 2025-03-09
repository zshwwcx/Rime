local ESlateVisibility = import("ESlateVisibility")
local EOrientation = import("EOrientation")

---@class PageList:BaseList
local PageList = DefineClass("PageList", BaseList)


PageList.Layout = {
    List = 1,
    Tile = 2,
}

PageList.SelectionMode = {
    Single = 1,
    SingleToggle = 2,
    Multi = 3
}

---@class PageList.Alignment
PageList.Alignment = {
    Left = 0,
    Right = 1,
    Up = 2,
    Bottom = 3,
    Center = 4,
}

function PageList.OnCreate(self, name, cell, parentAction, bIsAsync, asyncNum)
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

    --翻页列表
    self.maxPageNum = 0
    self.pages = {}
    self.curPage = 1
    self.totalPage = 0
    self.pageLeftSpace = 0
    self.cellOffset = 0
    self._topPage = 0
    self._bottomPage = 0
    self.pageDuration = self.View.PageDuration * 1000
    self.bAutoFill = self.View.AutoFill
    if self.pageDuration <= 0 then
        self.pageDuration = 500
    end
    if _G.StoryEditor then
        --add by kanzhengjie, review by jiawenjian
        self.retainerBox = nil
    end

    self.retainerBoxMaxValueDown = self.View.MaxValueDown
    self.retainerBoxMaxValueUp = self.View.MaxValueUp
    self.retainerBoxMaxValueRight = self.View.MaxValueRight
    self.retainerBoxMaxValueLeft = self.View.MaxValueLeft
    --需要播放进入动画
    self.binAni = false
    self.playingInAnimation = false
    self.aniNotified = false
    local Orientation = self.View.Orientation
    local PageOrientation = self.View.PageOrientation
    self.bIsVertical = Orientation == EOrientation.Orient_Vertical --
    self.bIsVerticalPage = PageOrientation == EOrientation.Orient_Vertical
    if self.retainerBox then
        local dynamicMaterial = self.retainerBox:GetEffectMaterial()
        if self.bIsVerticalPage then
            dynamicMaterial:SetScalarParameterValue("Max_Down", self.retainerBoxMaxValueDown)
            dynamicMaterial:SetScalarParameterValue("Min_Down", 1)
            dynamicMaterial:SetScalarParameterValue("Max", self.retainerBoxMaxValueUp)
            dynamicMaterial:SetScalarParameterValue("Min", 0)
        else
            dynamicMaterial:SetScalarParameterValue("Max_Left", self.retainerBoxMaxValueLeft)
            dynamicMaterial:SetScalarParameterValue("Min_Left", 0)
            dynamicMaterial:SetScalarParameterValue("Max_Right", self.retainerBoxMaxValueRight)
            dynamicMaterial:SetScalarParameterValue("Min_Right", 1)
        end
    end

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
    self.toggle = selectionMode == PageList.SelectionMode.SingleToggle
    self.multi = selectionMode == PageList.SelectionMode.Multi

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

    local PagePadding = self.View.PagePadding
    self.pagePadding = {
        Left = PagePadding.Left,
        Top = PagePadding.Top,
        Right = PagePadding.Right,
        Bottom = PagePadding.Bottom,
    }

    self:getRoot():SetOrientation(PageOrientation)
   
    self:AddUIListener(EUIEventTypes.OnAnimationNotify, self.View.WidgetRoot, self.onNotifyPlayInAnimation)
    --临时处理松手
    self:AddUIListener(EUIEventTypes.UserTouchEnded, self.View.List, self.CheckPageScroll)
    self:AddUIListener(EUIEventTypes.UserScrolled, self:getRoot(), self.onUserScrolled)
    -- self:AddUIListener(EUIEventTypes.TouchStarted, self.View.WidgetRoot, self.OnTouchStart)
    -- self:AddUIListener(EUIEventTypes.TouchMoved, self.View.WidgetRoot, self.OnTouchMove)
    -- self:AddUIListener(EUIEventTypes.TouchEnded, self.View.WidgetRoot, self.OnTouchEnd)
    --
    self._defaultAnchors = import("Anchors")()
    self.getCachedGeometryFun = self:getRoot().GetCachedGeometry
    self.getLocalSizeFun = import("SlateBlueprintLibrary").GetLocalSize
    self.bAutoSize =  (self.minSize > 0 or self.maxSize > 0) and self:checkSlotAndAnchors()
    if self.bAutoSize then self.bAutoFill = false end
    if self.bAutoSize then
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
end

function PageList:getSize()
    self:StartTimer("REFRESH_LIST", function()
        if not self.View then
            Log.Error("Timer Not End When UIComponent Dispose")
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
        -- if self.bIsVertical then
        --     self.width = size.X - self.pagePadding.Left - self.pagePadding.Right
        --     self.height = size.Y - self.pagePadding.Top - self.pagePadding.Bottom
        -- else
        --     self.width = size.X - self.pagePadding.Left - self.pagePadding.Right
        --     self.height = size.Y - self.pagePadding.Top - self.pagePadding.Bottom
        -- end
        self.width = size.X - self.pagePadding.Left - self.pagePadding.Right
        self.height = size.Y - self.pagePadding.Top - self.pagePadding.Bottom

        if self._waitGetItemSize then
            self.widgetX = widgetSize.X
            self.widgetY = widgetSize.Y
            self.View.ScrollWidget:SetVisibility(ESlateVisibility.Hidden)
        end

        self:RefreshPages()
        

        if self.total then
            -- local min, max = self:getIndexMinAndMax(self.total)
            -- min = nil
            -- --填充页数
            -- local lastPageNum = #self.pages[self.totalPage]
            -- local fillSize = 0
            -- if lastPageNum < self.maxPageNum then
            --     if self.bIsVertical then
            --         fillSize = self.height - max
            --     else
            --         fillSize = self.width - max
            --     end
            -- end
            if self.bIsVertical then
                if self.bIsVerticalPage then
                    self.length = (self.height + self.pagePadding.Top + self.pagePadding.Bottom) * self.totalPage
                    self.tempPos.X = self.width
                    self.tempPos.Y = self.length 
                else
                    self.length = (self.width + self.pagePadding.Left + self.pagePadding.Right) * self.totalPage
                    self.tempPos.X = self.length
                    self.tempPos.Y = self.height
                end
            else
                if self.bIsVerticalPage then
                    self.length = (self.height + self.pagePadding.Top + self.pagePadding.Bottom) * self.totalPage
                    self.tempPos.X = self.width
                    self.tempPos.Y = self.length 
                else
                    self.length = (self.width + self.pagePadding.Left + self.pagePadding.Right) * self.totalPage
                    self.tempPos.X = self.length
                    self.tempPos.Y = self.height
                end
            end
            self._diffPoint.Slot:SetPosition(self.tempPos)     
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
    end,1,1)
end

function PageList:getAutoSize()
    if not self._isShow then
        return
    end
    
        self:StartTimer("REFRESH_LIST", function()
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
            self.width = size.X - self.pagePadding.Left - self.pagePadding.Right
            self.height = size.Y - self.pagePadding.Top - self.pagePadding.Bottom
            if self.total then
                if self.bIsVertical then
                    local totalHeight = self.total * self.widgetY + (self.total - 1) * (self.spaceUp + self.spaceBottom)
                    self.width = size.X - self.pagePadding.Left - self.pagePadding.Right
                    if self.bIsTileView then
                        local tileLine = math.floor((self.width+self.spaceLeft+self.spaceRight)/(self.widgetX+self.spaceLeft+self.spaceRight))
                        local maxLineNum = math.ceil(self.total / tileLine)
                        totalHeight = maxLineNum * self.widgetY + (maxLineNum - 1) * (self.spaceUp + self.spaceBottom)
                    end
                    totalHeight = totalHeight + self.pagePadding.Top + self.pagePadding.Bottom
                    if totalHeight > self.maxSize then
                        self.height = self.maxSize
                    elseif totalHeight < self.minSize then
                        self.height = self.minSize
                    else
                        self.height = totalHeight
                    end
                else
                    local totalWidth = self.total * self.widgetX + (self.total - 1) * (self.spaceLeft + self.spaceRight)
                    self.height = size.Y - self.pagePadding.Top - self.pagePadding.Bottom
                    if self.bIsTileView then
                        local tileLine = math.floor((self.height+self.spaceUp+self.spaceBottom)/(self.widgetY+self.spaceUp+self.spaceBottom))
                        local maxLineNum = math.ceil(self.total / tileLine)
                        totalWidth = maxLineNum * self.widgetX + (maxLineNum - 1) * (self.spaceLeft + self.spaceRight)
                    end
                    totalWidth = totalWidth + self.pagePadding.Left + self.pagePadding.Right
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
                if self.bIsVertical then 
                    slotSize.Y = self.height 
                else
                    slotSize.X = self.width
                end
                self.retainerBox.Slot:SetSize(slotSize)
            elseif self.View.WidgetRoot.Slot:IsA(import("CanvasPanelSlot")) then
                local slotSize = self.View.WidgetRoot.Slot:GetSize()
                if self.bIsVertical then 
                    slotSize.Y = self.height 
                else
                    slotSize.X = self.width
                end
                self.View.WidgetRoot.Slot:SetSize(slotSize)
            end

            self:RefreshPages()

            if self.total then
                if self.bIsVertical then
                    if self.bIsVerticalPage then
                        self.length = (self.height + self.pagePadding.Top + self.pagePadding.Bottom) * self.totalPage
                        self.tempPos.X = self.width
                        self.tempPos.Y = self.length 
                    else
                        self.length = (self.width + self.pagePadding.Left + self.pagePadding.Right) * self.totalPage
                        self.tempPos.X = self.length
                        self.tempPos.Y = self.height
                    end
                else
                    if self.bIsVerticalPage then
                        self.length = (self.height + self.pagePadding.Top + self.pagePadding.Bottom) * self.totalPage
                        self.tempPos.X = self.width
                        self.tempPos.Y = self.length 
                    else
                        self.length = (self.width + self.pagePadding.Left + self.pagePadding.Right) * self.totalPage
                        self.tempPos.X = self.length
                        self.tempPos.Y = self.height
                    end
                end
                self._diffPoint.Slot:SetPosition(self.tempPos)    
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
        end,1,1)
    
end

function PageList:checkSlotAndAnchors()
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

function PageList:RefreshPages()
    if self.total then
        self.totalPage = 1
        self.pageLeftSpace = 0
        self.cellOffset = 0
        if self.width > 0 and self.height > 0 and self.widgetX > 0 and self.widgetY > 0 then
            if self.bIsVertical then
                if self.bIsTileView then
                    local tileLine = math.floor((self.width+self.spaceLeft+self.spaceRight)/(self.widgetX+self.spaceLeft+self.spaceRight))
                    local maxLineNum = math.ceil(self.total / tileLine)
                    local maxPageLine = math.floor((self.height+self.spaceUp+self.spaceBottom)/(self.widgetY+self.spaceUp+self.spaceBottom))
                    self.maxPageNum = maxPageLine * tileLine
                    if self.bIsVerticalPage then
                        self.pageLeftSpace = self.height - (maxPageLine * self.widgetY + (maxPageLine - 1) * (self.spaceUp + self.spaceBottom))
                        self.cellOffset = self.pageLeftSpace / (maxPageLine - 1)
                    else
                        self.pageLeftSpace = self.width - (tileLine * self.widgetX + (tileLine - 1) * (self.spaceLeft + self.spaceRight))
                        self.cellOffset = self.pageLeftSpace / (tileLine - 1)
                    end
                else
                    self.maxPageNum = math.floor((self.height+self.spaceUp+self.spaceBottom)/(self.widgetY+self.spaceUp+self.spaceBottom))
                    if self.bIsVerticalPage then
                        self.pageLeftSpace = self.height - (self.maxPageNum * self.widgetY + (self.maxPageNum - 1) * (self.spaceUp + self.spaceBottom))
                        self.cellOffset = self.pageLeftSpace / (self.maxPageNum - 1)
                    end
                    
                end
                
                self.totalPage = math.ceil(self.total / self.maxPageNum)
                
            else
                if self.bIsTileView then
                    local tileLine = math.floor((self.height+self.spaceUp+self.spaceBottom)/(self.widgetY+self.spaceUp+self.spaceBottom))
                    local maxLineNum = math.ceil(self.total / tileLine)
                    local maxPageLine = math.floor((self.width+self.spaceLeft+self.spaceRight)/(self.widgetX+self.spaceLeft+self.spaceRight))
                    self.maxPageNum = maxPageLine * tileLine
                    if self.bIsVerticalPage then
                        self.pageLeftSpace = self.height - (tileLine * self.widgetY + (tileLine - 1) * (self.spaceUp + self.spaceBottom))
                        self.cellOffset = self.pageLeftSpace / (tileLine - 1)
                    else
                        self.pageLeftSpace = self.width - (maxPageLine * self.widgetX + (maxPageLine - 1) * (self.spaceLeft + self.spaceRight))
                        self.cellOffset = self.pageLeftSpace / (maxPageLine - 1)
                    end
                    self.pageLeftSpace = self.width - (maxPageLine * self.widgetX + (maxPageLine - 1) * (self.spaceLeft + self.spaceRight))
                    self.cellOffset = self.pageLeftSpace / (maxPageLine - 1)
                else
                    self.maxPageNum = math.floor((self.width+self.spaceLeft+self.spaceRight)/(self.widgetX+self.spaceLeft+self.spaceLeft))
                    if not self.bIsVerticalPage then
                        self.pageLeftSpace = self.width - (self.maxPageNum * self.widgetX + (self.maxPageNum - 1) * (self.spaceLeft + self.spaceRight))
                        self.cellOffset = self.pageLeftSpace / (self.maxPageNum - 1)
                    end
                end
                self.totalPage = math.ceil(self.total / self.maxPageNum)
                
            end
            local pagenum = 1
            if not self.pages then self.pages = {} end
            table.clear(self.pages)
            local idx = 1
            for i = 1, self.total, 1 do

                if idx > self.maxPageNum then
                    pagenum = pagenum + 1
                    
                    idx = 1
                end
                if not self.pages[pagenum] then self.pages[pagenum] = {} end
                table.insert(self.pages[pagenum], i)
                idx = idx + 1 
            end
        else
            -- if (self.minSize > 0 or self.maxSize > 0) and self:checkSlotAndAnchors() then
            --     self:getAutoSize()
            -- else
            --     self:getSize()
            -- end
        end
    end
end

function PageList:getIndexInPage(index)
    local pageidx = math.ceil(index / self.maxPageNum)
    local res = -1
    if self.pages and self.pages[pageidx] then
        for i = 1, #self.pages[pageidx], 1 do
            if self.pages[pageidx][i] == index then
                res = i 
                break
            end
        end
    end
    return pageidx, res
end

function PageList:getIndexToPos(index)
    if index <= 0 then
        return -100000, -100000
    end
    local posX, posY
    local autoOffset = 0
    if self.bAutoFill then
        autoOffset = self.cellOffset
    end
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
                    posX = space + numX * (self.widgetX + self.spaceLeft + self.spaceRight) + self.pagePadding.Left
                    posY = self.pagePadding.Top
                end
            end
            if not needAuto then
                local mod = math.floor((self.width+self.spaceRight+self.spaceLeft)/(self.widgetX+self.spaceLeft+self.spaceRight))
                local floor = math.floor((index - 1) / mod)
                local numX = index - 1 - floor * mod
                if self.alignment == PageList.Alignment.Right then
                    local space = (self.width+self.spaceRight)%(self.widgetX+self.spaceLeft+self.spaceRight)
                    posX =  space + numX * (self.widgetX + self.spaceLeft + self.spaceRight)
                elseif self.alignment == PageList.Alignment.Center then
                    local space = (self.width+self.spaceRight)%(self.widgetX+self.spaceLeft+self.spaceRight)
                    posX =  space/2 + numX * (self.widgetX + self.spaceLeft + self.spaceRight)
                else
                    posX = numX * (self.widgetX + self.spaceLeft + self.spaceRight)
                end
                posX = posX + self.pagePadding.Left
                local page, idxInPage = self:getIndexInPage(index)
                if self.bIsVerticalPage then -- 纵向列表纵向排布
                    floor = math.floor((idxInPage - 1) / mod)
                    
                    posY = (page-1) * (self.height + self.pagePadding.Bottom) + page * self.pagePadding.Top + floor * (self.widgetY + self.spaceUp + self.spaceBottom + autoOffset)
                else
                    floor = math.floor((idxInPage - 1) / mod)
                    posX = posX + (page - 1) * (self.width + self.pagePadding.Right + self.pagePadding.Left) + numX * autoOffset
                    posY = floor * (self.widgetY + self.spaceUp + self.spaceBottom) + self.pagePadding.Top
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

                    if self.alignment == PageList.Alignment.Right then
                        local space = self.width - self.widgetX
                        posX = space
                    elseif self.alignment == PageList.Alignment.Center then
                        local space = self.width - self.widgetX
                        posX = space/2
                    else
                        posX = 0
                    end
                    posX = posX + self.pagePadding.Left
                    
                    local page, idxInPage = self:getIndexInPage(index)
                    
                    if self.bIsVerticalPage then -- 纵向列表纵向排布
                        posY = (page-1) * (self.height + self.pagePadding.Bottom) + page * self.pagePadding.Top + space + (idxInPage - 1) * (self.widgetY + self.spaceUp + self.spaceBottom)
                    else
                        posX = posX + (page - 1) * (self.width + self.pagePadding.Right + self.pagePadding.Left)
                        posY = (idxInPage - 1) * (self.widgetY + self.spaceUp + self.spaceBottom) + self.pagePadding.Top + space
                    end
                end
            end
            if not needAuto then
                if self.alignment == PageList.Alignment.Right then
                    local space = self.width - self.widgetX
                    posX = space
                elseif self.alignment == PageList.Alignment.Center then
                    local space = self.width - self.widgetX
                    posX = space/2
                else
                    posX = 0
                end
                posX = posX + self.pagePadding.Left
                local page, idxInPage = self:getIndexInPage(index)
                if self.bIsVerticalPage then -- 纵向列表纵向排布
                    posY = (page-1) * (self.height + self.pagePadding.Bottom) + page * self.pagePadding.Top + (idxInPage - 1) * (self.widgetY + self.spaceUp + self.spaceBottom + autoOffset)
                else
                    posX = posX + (page - 1) * (self.width + self.pagePadding.Right + self.pagePadding.Left)
                    posY = (idxInPage - 1) * (self.widgetY + self.spaceUp + self.spaceBottom) + self.pagePadding.Top
                end
            end
        end
    else
        if self.bIsTileView then
            local mod = math.floor((self.height+self.spaceBottom+self.spaceUp)/(self.widgetY+self.spaceUp+self.spaceBottom))
            local floor = math.floor((index - 1) / mod)
            local numY = index - 1 - floor * mod
            if self.alignment == PageList.Alignment.Bottom then
                local space = (self.height+self.spaceBottom)%(self.widgetY+self.spaceUp+self.spaceBottom)
                posY = space + numY * (self.widgetY + self.spaceUp + self.spaceBottom)
            elseif self.alignment == PageList.Alignment.Center then
                local space = (self.height+self.spaceBottom)%(self.widgetY+self.spaceUp+self.spaceBottom)
                posY = space/2 + numY * (self.widgetY + self.spaceUp + self.spaceBottom)
            else
                posY = numY * (self.widgetY + self.spaceUp + self.spaceBottom)
            end
            posY = posY + self.pagePadding.Top
            local page, idxInPage = self:getIndexInPage(index)
            if self.bIsVerticalPage then 
                floor = math.floor((idxInPage - 1) / mod)
                posX = floor * (self.widgetX + self.spaceLeft + self.spaceRight) + self.pagePadding.Left
                posY = posY + (page - 1) * (self.height + self.pagePadding.Bottom + self.pagePadding.Top) + numY * autoOffset
                --posY = (page-1) * self.height + self.pagePadding.Top + (idxInPage - 1) * (self.widgetY + self.spaceUp + self.spaceBottom + offset)
            else
                floor = math.floor((idxInPage - 1) / mod)
                posX = (page-1) * (self.width + self.pagePadding.Right) + page * self.pagePadding.Left + floor * (self.widgetX + self.spaceLeft + self.spaceRight + autoOffset)
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
                    local numX = index - 1
                    posX = space + numX * (self.widgetX + self.spaceLeft + self.spaceRight) + self.pagePadding.Left

                    if self.alignment == PageList.Alignment.Bottom then
                        local tempSpace = self.height - self.widgetY
                        posY = tempSpace
                    elseif self.alignment == PageList.Alignment.Center then
                        local tempSpace = self.height - self.widgetY
                        posY = tempSpace/2
                    else
                        posY = 0
                    end

                    posY = posY + self.pagePadding.Top
                end
            end
            if not needAuto then
                if self.alignment == PageList.Alignment.Bottom then
                    local space = self.height - self.widgetY
                    posY = space
                elseif self.alignment == PageList.Alignment.Center then
                    local space = self.height - self.widgetY
                    posY = space/2
                else
                    posY = 0
                end
                posY = posY + self.pagePadding.Top
                local page, idxInPage = self:getIndexInPage(index)
                if self.bIsVerticalPage then 
                    posX = (idxInPage - 1) * (self.widgetX + self.spaceLeft + self.spaceRight) + self.pagePadding.Left
                    posY = posY + (page - 1) * (self.height + self.pagePadding.Bottom + self.pagePadding.Top)
                    --posY = (page-1) * self.height + self.pagePadding.Top + (idxInPage - 1) * (self.widgetY + self.spaceUp + self.spaceBottom + offset)
                else
                    posX = (page-1) * (self.width + self.pagePadding.Right) + page * self.pagePadding.Left + (idxInPage - 1) * (self.widgetX + self.spaceLeft + self.spaceRight + autoOffset)
                end
            end
        end
    end
    return posX, posY
end

function PageList:getIndexMinAndMax(index, usePageDir)
    local posX, posY = self:getIndexToPos(index)
    local min, max
    if usePageDir then
        if self.bIsVerticalPage then
            min = posY
            max = posY + self.widgetY + self.spaceBottom
        else
            min = posX
            max = posX + self.widgetX + self.spaceRight
        end
    else
        if self.bIsVertical then
            min = posY
            max = posY + self.widgetY + self.spaceBottom
        else
            min = posX
            max = posX + self.widgetX + self.spaceRight
        end
    end

    return min, max
end

function PageList:getPageMinAndMax(page)
    local min, max
    if not self.pages[page] then
        return -10000, -10000
    end
    if self.pages[page] then
        local pageFirstIndex = self.pages[page][1]
        if pageFirstIndex then
            local posX, posY = self:getIndexToPos(pageFirstIndex)
            if self.bIsVertical then
                if self.bIsVerticalPage then
                    min = posY - self.pagePadding.Top
                    max = posY + self.height + self.pagePadding.Bottom
                else
                    min = posX - self.pagePadding.Left
                    max = posX + self.width + self.pagePadding.Right
                end
            else
                if self.bIsVerticalPage then
                    min = posY - self.pagePadding.Top
                    max = posY + self.height + self.pagePadding.Bottom
                else 
                    min = posX - self.pagePadding.Left
                    max = posX + self.width + self.pagePadding.Right
                end
            end 
        end
    end
    return min, max
end

function PageList:CheckPageScroll()
    self:getRoot():EndInertialScrolling()
    for i = 1, self.totalPage, 1 do
        local pmin, pmax = self:getPageMinAndMax(i)
        if self.oldOffect >= pmin and self.oldOffect < pmax then
            if self.oldOffect - pmin > (pmax - pmin) / 2 then
                self:ScrollToPage(i+1)
            else
                self:ScrollToPage(i)
            end
            break
        end
    end
end


function PageList:onUserScrolled(currentOffset)
    if self.height == 0 or self.width == 0 then
        return
    end
    if self.bIsVerticalPage then
        currentOffset = math.max(math.min(currentOffset, self.length - self.height - self.spaceBottom), 0)
    else
        currentOffset = math.max(math.min(currentOffset, self.length - self.width - self.spaceRight), 0)
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

    for i = self._oldTop, limit, step do
        local min, max = self:getIndexMinAndMax(i)
        local page, idxInpage = self:getIndexInPage(i)
        if not (self.bIsVertical == self.bIsVerticalPage) then
            local pmin, pmax = self:getPageMinAndMax(page)
            if pmin then
                local bMiddle = currentOffset >= pmin and currentOffset < pmax
                local bSpace = false
                if page + 1 <= self.totalPage then
                    local _pmin, _pmax = self:getPageMinAndMax(page+1)
                    _pmax = nil
                    if currentOffset < _pmin and currentOffset >= pmax then
                        bSpace = true
                    end
                end
                if bMiddle or bSpace then
                    self._topIndex = self.pages[page][1]
                    self._topPage = page
                    break
                end
            end
        else
            if min then
                local bMiddle = currentOffset >= min and currentOffset < max
                local bSpace = false
                if i+1 <= self.total then
                    local _min, _max = self:getIndexMinAndMax(i+1)
                    _max = nil
                    if currentOffset < _min and currentOffset >= max then
                        bSpace = true
                    end
                end
                if bMiddle or bSpace then
                    self._topIndex = i
                    self._topPage = page
                    break
                end
            end
        end
    end
    local min, max = self:getIndexMinAndMax(self._topIndex)
    max = nil
    if step > 0 then
        if not (self.bIsVertical == self.bIsVerticalPage) and self._topPage > 0 then
            local pagefirst = self.pages[self._topPage][1]
            local pagelast = self.pages[self._topPage][#self.pages[self._topPage]]
            for i = pagefirst, pagelast, 1 do
                local _min, _max = self:getIndexMinAndMax(i, true)

                local bMiddle = currentOffset >= _min and currentOffset < _max
                local bSpace = false
                if i+1 <= self.total then
                    local _tmin, _tmax = self:getIndexMinAndMax(i+1, true)
                    _tmax = nil
                    if currentOffset < _tmin and currentOffset >= _max then
                        bSpace = true
                    end
                end
                if bMiddle or bSpace then
                    self._topIndex = i
                    break
                end
            end
        else
            for i = self._topIndex, reLimit, -step do
                local _min, _max = self:getIndexMinAndMax(i)
                _max = nil
                local page = self:getIndexInPage(i)
                if min == _min and page == self._topPage then
                    self._topIndex = i
                else
                    break
                end
            end
        end
    else
        if not (self.bIsVertical == self.bIsVerticalPage) and self._topPage > 0 then
            local pagefirst = self.pages[self._topPage][1]
            local pagelast = self.pages[self._topPage][#self.pages[self._topPage]]
            for i = pagefirst, pagelast, 1 do
                local _min, _max = self:getIndexMinAndMax(i, true)

                local bMiddle = currentOffset >= _min and currentOffset < _max
                local bSpace = false
                if i+1 <= self.total then
                    local _tmin, _tmax = self:getIndexMinAndMax(i+1, true)
                    _tmax = nil
                    if currentOffset < _tmin and currentOffset >= _max then
                        bSpace = true
                    end
                end
                if bMiddle or bSpace then
                    self._topIndex = i
                    break
                end
            end
        else
            for i = self._topIndex, limit, step do
                local _min, _max = self:getIndexMinAndMax(i)
                _max = nil
                local page = self:getIndexInPage(i)
                if min == _min and page == self._topPage then
                    self._topIndex = i
                else
                    break
                end
            end
        end
    end
    local bottom
    if self.bIsVerticalPage then
        bottom = currentOffset + self.height + self.pagePadding.Top + self.pagePadding.Bottom
    else
        bottom = currentOffset + self.width  + self.pagePadding.Left + self.pagePadding.Right
    end
    local endMin, endMax
    if self.bIsVertical == self.bIsVerticalPage then
        endMin, endMax = self:getIndexMinAndMax(self.total)
    else
        local page = self:getIndexInPage(self.total)
        endMin, endMax = self:getPageMinAndMax(page)
    end
    if endMax <= bottom then
        self._bottomIndex = self.total
    else
        for i = self._oldBottom, limit, step do
            local tmin, tmax = self:getIndexMinAndMax(i)
            local page, idxInpage = self:getIndexInPage(i)
            if not (self.bIsVertical == self.bIsVerticalPage) then
                local pmin, pmax = self:getPageMinAndMax(page)
                if pmin then
                    local bMiddle = bottom > pmin and bottom <= pmax
                    local bSpace = false
                    if page > 1 then
                        local _pmin, _pmax = self:getPageMinAndMax(page - 1)
                        _pmin = nil
                        if bottom < pmin and bottom >= _pmax then
                            bSpace = true
                        end 
                    end
                    if bMiddle or bSpace then
                        self._bottomIndex = self.pages[page][#self.pages[page]]
                        self._bottomPage = page
                        break
                    end
                end
            else
                if tmin then
                    local bMiddle = bottom >= tmin and bottom < tmax
                    local bSpace = false
                    if i > 1 then
                        local _min, _max = self:getIndexMinAndMax(i-1)
                        _min = nil
                        if bottom < tmin and bottom >= _max then
                            bSpace = true
                        end
                    end
                    if bMiddle then
                        page = self:getIndexInPage(i)
                        self._bottomIndex = i
                        self._bottomPage = page
                        break
                    elseif bSpace then
                        self._bottomIndex = i
                        self._bottomPage = page
                        break
                    end
                end
            end
        end
        min, max = self:getIndexMinAndMax(self._bottomIndex)
        if step < 0 then
            if not (self.bIsVertical == self.bIsVerticalPage) and self._bottomPage > 0 then
                local pagefirst = self.pages[self._bottomPage][1]
                local pagelast = self.pages[self._bottomPage][#self.pages[self._bottomPage]]
                for i = pagelast, pagefirst, -1 do
                    local _min, _max = self:getIndexMinAndMax(i, true)
                    local bMiddle = bottom >= _min and bottom < _max
                    local bSpace = false
                    if i > 1 then
                        local _tmin, _tmax = self:getIndexMinAndMax(i-1, true)
                        _tmin = nil
                        if bottom < _min and bottom >= _tmax then
                            bSpace = true
                        end
                    end
                    if bMiddle or bSpace then
                        self._bottomPage = i
                        break
                    end
                    
                end
            else
                for i = self._bottomIndex, reLimit, -step do
                    local page = self:getIndexInPage(i)
                    local _min, _max = self:getIndexMinAndMax(i)
                    _max = nil
                    if min == _min and page == self._bottomPage then
                        self._bottomIndex = i
                    else
                        break
                    end
                end
            end
        else
            if not (self.bIsVertical == self.bIsVerticalPage) and self._bottomPage > 0 then
                local pagefirst = self.pages[self._bottomPage][1]
                local pagelast = self.pages[self._bottomPage][#self.pages[self._bottomPage]]
                for i = pagelast, pagefirst, -1 do
                    local _min, _max = self:getIndexMinAndMax(i, true)
                    local bMiddle = bottom >= _min and bottom < _max
                    local bSpace = false
                    if i > 1 then
                        local _tmin, _tmax = self:getIndexMinAndMax(i-1, true)
                        _tmin = nil
                        if bottom < _min and bottom >= _tmax then
                            bSpace = true
                        end
                    end
                    if bMiddle or bSpace then
                        self._bottomPage = i
                        break
                    end
                    
                end
            else
                for i = self._bottomIndex, limit, step do
                    local page = self:getIndexInPage(i)
                    local _min, _max = self:getIndexMinAndMax(i)
                    _max = nil
                    if min == _min and page == self._bottomPage then
                        self._bottomIndex = i
                    else
                        break
                    end
                end
            end
        end
    end
    self.oldOffect = currentOffset
    self:checkRefresh(step > 0)
end

function PageList:checkRefresh(bUp)
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

--播放入场动画
function PageList:playListInAnimation()
    if (self.binAni and self:checkInAnimation()) or self:checkInAnimation(self.aniNotified) then
        self:PlayInAnimation(self._topIndex, self._bottomIndex)
        self.binAni = false
        self.aniNotified = false
    end
end

function PageList:asynGetCell()
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
    -- if self.binAni and self:checkInAnimation() then
    --     self:PlayInAnimation(self._topIndex, self._bottomIndex)
    --     self.binAni = false
    -- end
    if not bBreak then
        return true
    end
end

function PageList:refreshRetainerBox()
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

    if self.bIsVerticalPage and self.retainerBox then
        --纵向列表
        if self.oldOffect+self.height+self.spaceBottom >= self.length - 0.01 and self.oldOffect > 0.0 then --到底部没到顶部
            if not self.bEndFlag or self.bStartFlag then
                self.bEndFlag = true
                self.bStartFlag = false
                local dynamicMaterial = self.retainerBox:GetEffectMaterial()
                dynamicMaterial:SetScalarParameterValue("Max_Down", 0)
                dynamicMaterial:SetScalarParameterValue("Min_Down", 0)
                dynamicMaterial:SetScalarParameterValue("Max", self.retainerBoxMaxValueUp)
                dynamicMaterial:SetScalarParameterValue("Min", 0)
            end
        elseif self.oldOffect+self.height+self.spaceBottom < self.length - 0.01 and self.oldOffect <= 0.0 then --到顶部没到底部
            if not self.bStartFlag or self.bEndFlag then
                self.bStartFlag = true
                self.bEndFlag = false
                local dynamicMaterial = self.retainerBox:GetEffectMaterial()
                dynamicMaterial:SetScalarParameterValue("Max_Down", self.retainerBoxMaxValueDown)
                dynamicMaterial:SetScalarParameterValue("Min_Down", 1)
                dynamicMaterial:SetScalarParameterValue("Max", 0)
                dynamicMaterial:SetScalarParameterValue("Min", 0)
            end
        elseif self.oldOffect+self.height+self.spaceBottom < self.length - 0.01 and self.oldOffect > 0.0 then --没到顶部也没到底部
            if self.bEndFlag or self.bStartFlag then
                self.bStartFlag = false
                self.bEndFlag = false
                local dynamicMaterial = self.retainerBox:GetEffectMaterial()
                dynamicMaterial:SetScalarParameterValue("Max_Down", self.retainerBoxMaxValueDown)
                dynamicMaterial:SetScalarParameterValue("Min_Down", 1)
                dynamicMaterial:SetScalarParameterValue("Max", self.retainerBoxMaxValueUp)
                dynamicMaterial:SetScalarParameterValue("Min", 0)
            end
        elseif not self.bEndFlag or not self.bStartFlag then --既到顶部又到底部
            self.bEndFlag = true
            self.bStartFlag = true
            local dynamicMaterial = self.retainerBox:GetEffectMaterial()
            dynamicMaterial:SetScalarParameterValue("Max_Down", 0)
            dynamicMaterial:SetScalarParameterValue("Min_Down", 0)
            dynamicMaterial:SetScalarParameterValue("Max", 0)
            dynamicMaterial:SetScalarParameterValue("Min", 0)
        end
    end
    if not self.bIsVerticalPage and self.retainerBox then
        --仅纵向列表有这个显示需求
        if self.oldOffect + self.width + self.spaceRight >= self.length - 0.01 and self.oldOffect > 0.0 then --到底部没到顶部
            if not self.bEndFlag or self.bStartFlag then
                self.bEndFlag = true
                self.bStartFlag = false
                local dynamicMaterial = self.retainerBox:GetEffectMaterial()
                dynamicMaterial:SetScalarParameterValue("Max_Right", 0)
                dynamicMaterial:SetScalarParameterValue("Min_Right", 0)
                dynamicMaterial:SetScalarParameterValue("Max_Left", self.retainerBoxMaxValueLeft)
                dynamicMaterial:SetScalarParameterValue("Min_Left", 0)
            end
        elseif self.oldOffect + self.width + self.spaceRight < self.length - 0.01 and self.oldOffect <= 0.0 then --到顶部没到底部
            if not self.bStartFlag or self.bEndFlag then
                self.bStartFlag = true
                self.bEndFlag = false
                local dynamicMaterial = self.retainerBox:GetEffectMaterial()
                dynamicMaterial:SetScalarParameterValue("Max_Right", self.retainerBoxMaxValueRight)
                dynamicMaterial:SetScalarParameterValue("Min_Right", 1)
                dynamicMaterial:SetScalarParameterValue("Max_Left", 0)
                dynamicMaterial:SetScalarParameterValue("Min_Left", 0)
            end
        elseif self.oldOffect + self.width + self.spaceRight < self.length - 0.01 and self.oldOffect > 0.0 then --没到顶部也没到底部
            if self.bEndFlag or self.bStartFlag then
                self.bStartFlag = false
                self.bEndFlag = false
                local dynamicMaterial = self.retainerBox:GetEffectMaterial()
                dynamicMaterial:SetScalarParameterValue("Max_Right", self.retainerBoxMaxValueRight)
                dynamicMaterial:SetScalarParameterValue("Min_Right", 1)
                dynamicMaterial:SetScalarParameterValue("Max_Left", self.retainerBoxMaxValueLeft)
                dynamicMaterial:SetScalarParameterValue("Min_Left", 0)
            end
        elseif not self.bEndFlag or not self.bStartFlag then --既到顶部又到底部
            self.bEndFlag = true
            self.bStartFlag = true
            local dynamicMaterial = self.retainerBox:GetEffectMaterial()
            dynamicMaterial:SetScalarParameterValue("Max_Right", 0)
            dynamicMaterial:SetScalarParameterValue("Min_Right", 0)
            dynamicMaterial:SetScalarParameterValue("Max_Left", 0)
            dynamicMaterial:SetScalarParameterValue("Min_Left", 0)
        end
    end
end

function PageList:onNotifyPlayInAnimation()
    self.aniNotified = true
    -- if self:checkInAnimation(true) then
    --     --self:PlayInAnimation(self._topIndex, self._bottomIndex)
        
    -- end
end

---@public @获取当前列表底部位置（只针对纵向列表且bIsCenterContent的情况的方法）
function PageList:GetEndPosY(callback)
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
                        posY = self.pagePadding.Top + space + numY * (self.widgetY+self.spaceBottom+self.spaceUp) + self.widgetY
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

function PageList:getRoot()
    return self.View.List
end

function PageList:GetCellIndex(cell)
    return self.cellIndexs[cell]
end

function PageList:EnableDoubleClick(enabled)
    self.doubleClickEnabled = enabled
end

function PageList:EnableRightClick(enabled)
    self.rightClickEnabled = enabled
end

function PageList:isSelected(index)
    if not self.multi then
        return self.selectedIndex and self.selectedIndex == index
    else
        return self.selectedIndexs[index] or false
    end
end

function PageList:SetSpaceLeft(spaceLeft)
    self.spaceLeft = spaceLeft
end

function PageList:SetSpaceRight(spaceRight)
    self.spaceRight = spaceRight
end

function PageList:SetConsumeMouseWheel(eConsumeMouseWheel)
    self:getRoot():SetConsumeMouseWheel(eConsumeMouseWheel)
end

---停止继续的滑动
function PageList:EndInertialScrolling()
    self:getRoot():EndInertialScrolling()
end
---点击处理
---@private
function PageList:HandleItemClicked(uiCell, bIsRightClick)
    if not self.enabled then return end
    if bIsRightClick and not self.rightClickEnabled then
        return
    end
    self:OnItemClicked(self.cellIndexs[uiCell], bIsRightClick)
end
---点击和刷新接口统一
function PageList:callRefreshFun(owner, component, index, bIsSelect)
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
function PageList:callOnClickFun(owner, component, index, bIsRightClick)
    if self.cell and bIsRightClick and component.OnRightClick and not self.parentFirst then
        component:OnRightClick(self.owner, self.datas, index)
    elseif self.cell and component.OnClick and not self.parentFirst then
        component:OnClick(self.owner, self.datas, index)
    elseif self.onClick then
        self.onClick(self.owner, component, index)
    end
end
---@private 调用CanSelcallback,能否选中回调
function PageList:callCanSelFun(component, index)
    if self.cell and component.CanSel and not self.parentFirst then
        return component:CanSel(self.owner, self.datas, index)
    elseif self.canSel then
        return self.canSel(self.owner, index)
    else
        return true
    end
end
---@private 调用OnDoubleCcallback,双击事件回调
function PageList:callOnDoubleClickFun(component, index)
    if self.cell and component.OnDoubleClick and not self.parentFirst then
        component:OnDoubleClick(self.owner, self.datas, index)
    elseif self.onDoubleClick then
        self.onDoubleClick(self.owner,component,index)
    end
end

function PageList:callOnLongPressFun(component, index)
    if self.cell and component.OnLongPress and not self.parentFirst then
        component:OnLongPress(self.owner, self.datas, index)
    elseif self.onLongPress then
        self.onLongPress(self.owner, component, index)
    end
end

function PageList:callOnReleasedFun(component, index)
    if self.cell and component.OnReleased then
        component:OnReleased(self.owner, self.datas, index)
    end
end

---父界面点击处理(区分单击和双击)
---@private
function PageList:OnItemClicked(index, bIsRightClick)
    -- Log.Warning("[PageList] OnItemClicked ", index)
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

function PageList:OnItemClickedex(index, bIsRightClick)
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
                    self:playAutoAni(index, false)
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
                self:playAutoAni(oldIndex, false)
            end
        end
        if canSel then
            self.selectedIndex = index
        end
        local r = self:GetRendererAt(index)
        if r then
            if canSel then
                self:callRefreshFun(owner, r, index, true)
                self:playAutoAni(index, true)
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
            self:playAutoAni(index, selected)
        end
    end
    if (not selected) or canSel then
        self.selectedIndexs[index] = selected
    end
    if r then
        self:callOnClickFun(owner, r, index, bIsRightClick)
    end
end

function PageList:OnItemDoubleClicked(index)
    local r = self:GetRendererAt(index)
    if r then
        Log.Debug("[PageList] onDoubleClick", index)
        self:callOnDoubleClickFun(r, index)
    end
end

function PageList:GetUniqueID(UIComponent)
    if not UIComponent then
        Log.WarningFormat("PageList GetUniqueID With Nil UIComponent")
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
function PageList:OnItemPressed(index)
    -- Log.Warning("[PageList] OnPressed ", index)

    local r = self:GetRendererAt(index)
    local id = self:GetUniqueID(r)
    self.blong[id] = false
    local name = self.timePressName .. id
    self.owner:StartTimer(name, function()
        -- Log.Warning("[ListView3] onLongPress", index)
        self.blong[id] = true

        self:callOnLongPressFun(r, index)

    end, Enum.EConstFloatData.DOUBLE_CLICK_INTERVAL, 1)
end

function PageList:OnItemReleased(index)
    -- Log.Warning("[PageList] OnItemReleased ", index)
    local component = self:GetRendererAt(index)
    if not component then return end
    
    local id = self:GetUniqueID(component)
    local name = self.timePressName .. id
    self.owner:StopTimer(name)
    self:callOnReleasedFun(component, index)
end

function PageList:doRefresh()
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

function PageList:clearCell()
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
function PageList:SetData(total, top, binAni)
    if self.isRefreshing == true then
        Log.Error("Cannot SetData in OnRefresh")
        return
    end
    self.binAni = binAni
    local oldTotal = self.total
    if self.total and self.total ~= total then
        self.total = total
        self:clearCell()
        if self.bAutoSize then
            self:getAutoSize()
        else
            if self.width > 0 then
                self:RefreshPages()
                if self.bIsVertical then
                    if self.bIsVerticalPage then
                        self.length = (self.height + self.pagePadding.Top + self.pagePadding.Bottom) * self.totalPage
                        self.tempPos.X = self.width
                        self.tempPos.Y = self.length 
                    else
                        self.length = (self.width + self.pagePadding.Left + self.pagePadding.Right) * self.totalPage
                        self.tempPos.X = self.length
                        self.tempPos.Y = self.height
                    end
                else
                    if self.bIsVerticalPage then
                        self.length = (self.height + self.pagePadding.Top + self.pagePadding.Bottom) * self.totalPage
                        self.tempPos.X = self.width
                        self.tempPos.Y = self.length 
                    else
                        self.length = (self.width + self.pagePadding.Left + self.pagePadding.Right) * self.totalPage
                        self.tempPos.X = self.length
                        self.tempPos.Y = self.height
                    end
                end
                self._diffPoint.Slot:SetPosition(self.tempPos)   
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

    --播放入场动画
    -- self.binAni = binAni
    -- if (self.binAni and self:checkInAnimation()) or self:checkInAnimation(self.aniNotified) then
    --     self:PlayInAnimation(self._topIndex, self._bottomIndex)
    --     self.binAni = false
    --     self.aniNotified = false
    -- end
end

---获得第多少条数据对应哪个格子
---@public
function PageList:GetRendererAt(index)
    return self._cells[index]
end

---@public 让滚动列表瞬间滚动到第几条数据对应的格子
---@param index number 索引
function PageList:ScrollToIndex(index)
    -- Log.Warning("ScrollToIndex self.name ", self.name, " index ", index)
    local tarPage, idxInPage = self:getIndexInPage(index)
    
    
	if (index <= 0 or index > self.total) then
        return
    end
    if self.width == 0 or self.height == 0 then
        self._cacheIdx = index
        return
    end
    local pageFirstIndex = self.pages[tarPage][1]
    local posX, posY = self:getIndexToPos(pageFirstIndex)
    local offect
    if self.bIsVerticalPage then
        offect = posY - self.pagePadding.Top
    else
        offect = posX - self.pagePadding.Left
    end
    -- self:getRoot():SetScrollOffset(offect)
    -- self:onUserScrolled(offect)
    self:PageScrolling(self.oldOffect, offect)
    self.curPage = tarPage
end

---@public 让滚动列表瞬间滚动到第几条数据对应的格子
---@param num number 翻页数，正数向后翻页，负数向前翻页
function PageList:ScrollPage(num)
    local tarPage = math.max(math.min(self.curPage + num, self.totalPage), 1)
    local pageFirstIndex = self.pages[tarPage][1]
    local posX, posY = self:getIndexToPos(pageFirstIndex)
    local offect
    if self.bIsVerticalPage then
        offect = posY - self.pagePadding.Top
    else
        offect = posX - self.pagePadding.Left
    end
    -- self:getRoot():SetScrollOffset(offect)
    -- self:onUserScrolled(offect)
    self:PageScrolling(self.oldOffect, offect)
    self.curPage = tarPage
end

function PageList:PageScrolling(startOffset, endOffset)
    local duration = self.pageDuration
    if self.bIsVerticalPage then
        duration = duration * math.abs(endOffset - startOffset) / self.height
    else
        duration = duration * math.abs(endOffset - startOffset) / self.width
    end
    local flyTime = 0
    local name = "scrolling"
    self:StopTimer(name)
    local flyFunc = function(e)
        flyTime = flyTime + e
        if flyTime >= duration then
            self:getRoot():SetScrollOffset(endOffset)
            self:onUserScrolled(endOffset)
            self:StopTimer(name)
            Log.Debug("PageList: EndScroll")
        else
            local p = flyTime/duration
            local offset = startOffset + (endOffset - startOffset) * p
            self:getRoot():SetScrollOffset(offset)
            self:onUserScrolled(offset)
            Log.Debug("PageList: start: ",startOffset, "cur:", offset)
        end
    end
    
    self:StartTimer(name, flyFunc, 1, -1, nil, true)
    Log.Debug("PageList: TimerStart")
end

function PageList:PageScrollEnd()
    
end

---@public 让滚动列表瞬间滚动到第几条数据对应的格子
---@param page number 翻到第几页
function PageList:ScrollToPage(page)
    local tarPage = math.max(math.min(page, self.totalPage), 1)
    local pageFirstIndex = self.pages[tarPage][1]
    local posX, posY = self:getIndexToPos(pageFirstIndex)
    local offect
    if self.bIsVerticalPage then
        offect = posY - self.pagePadding.Top
    else
        offect = posX - self.pagePadding.Left
    end
    -- self:getRoot():SetScrollOffset(offect)
    -- self:onUserScrolled(offect)
    self:PageScrolling(self.oldOffect, offect)
    self.curPage = tarPage
end

---@public 选中第几个数据所在的格子，需要在按钮的click里去设置
---@param index number 索引
function PageList:Sel(index)
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

            end
        end
        local r = self:GetRendererAt(index)
        if r then
            self:callRefreshFun(self.owner, r, index, true)
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
function PageList:RefreshCell(index)
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
function PageList:CancelSel(index)
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
    if index < 1 then index = 1 end
    if index > self.total then index = self.total end
    if not self.selectedIndexs[index] then
        return
    end
    self.selectedIndexs[index] = false
    local r = self:GetRendererAt(index)
    if r then

        self:callRefreshFun(self.owner, r, index, false)

    end
end

---取消选中所有格子
---@public
function PageList:CancelAllSel()
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

function PageList:setCell(uiCell, index)
    if uiCell then
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

function PageList:getAutoButton(uiComponent)
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

function PageList:addClickListener(uiComponent)
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
function PageList:getCell(index)
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
    else
        uiComponent.WidgetRoot.Slot:SetPosition(self.tempPos)
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
function PageList:GetDistancePercent()
    return self:GetViewRoot():GetDistancePercent()
end

---得到滚动列表里的未使用的百分比
---@public
function PageList:GetDistancePercentRemaining()
    return self:GetViewRoot():GetDistancePercentRemaining()
end

---得到滚动列表里的ScrollOffset，指的是可见的第一个元素的偏移
---@public
function PageList:GetScrollOffset()
    return self:getRoot():GetScrollOffset()
end

---设置滚动列表是否开启禁止过度滚动
---@public
---@param newAllowOverscroll bool true允许过度滚动，false不允许过度滚动
function PageList:SetAllowOverscroll(newAllowOverscroll)
    return self:GetViewRoot():SetAllowOverscroll(newAllowOverscroll)
end

---设置滚动列表是否开启循环滚动，循环滚动是高度特化的滚动列表，仅在比较少见的专用情况下使用
---@public
---@param newAllowLoopScroll bool true允许循环滚动，false不允许循环滚动
function PageList:SetAllowLoopScroll(newAllowLoopScroll)
    return self:GetViewRoot():SetAllowLoopScroll(newAllowLoopScroll)
end

function PageList:SetSingleToggle(bSingleToggle)
    if self.multi then
        self:SetMulti(false)
    end

    self.toggle = bSingleToggle

end


---设置滚动列表是否能多选
---@public
---@param multi boolean @是否多选
function PageList.SetMulti(self, multi)
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
function PageList:GetSelectedIndex()
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
function PageList:SetEnabled(enabled)
    self.enabled = enabled
end

---@屏幕分辨率变化
function PageList:OnViewportResize()
    self.bMarkViewportResize = true
    if self.bEnable then
        self:UpdateSize()
    end
end

function PageList:OnOpen()
    if self.cell then
        for index, cell in pairs(self._cells) do
            cell:Show()
            cell:Open()
        end
    end
    if self.width == 0 or self.height == 0 or (self._waitGetItemSize and self.widgetX == 0 and self.widgetY == 0) then
        if self.bAutoSize then
            self:getAutoSize()
        else
            return self:getSize()
        end
        
    end
     -- local owner = self.owner
    -- owner:CtrlTimer(self.timeName .. 'time', function()
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
    -- end, 10)
    self.bEnable = true
    if self.bMarkViewportResize then
        self:UpdateSize()
    end
end

---list容器只处理子Component的Show和Hide,不处理OnRefresh
function PageList:OnRefresh()
end

function PageList:OnClose()
    UIBase.OnClose(self)
    if self.cell then
        for index, cell in pairs(self._cells) do
            cell:Hide()
            cell:Close()
        end
    end
    table.clear(self.lastClickTimes)
end

function PageList:OnDestroy()
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
    UIBase.OnDestroy(self)
end


function PageList:OnListClickedPlayAudio(Callback)
    self.ClickAudioFunc = Callback
end

function PageList:AddSafeRefreshFun(Callback)
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

function PageList:RemoveSafeRefreshFun()
    return self.callback
end

---- 注册UI事件
---@public
---@param eventType EUIEventTypes @事件类型
---@param widget string @控件路径
---@param func string @回调方法
---@param params any @参数
function PageList:AddUIListener(eventType, widget, func, params)
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
function PageList:UpdateSize()
    if self.reSizeCount > 10 then
        self.reSizeCount = 0
    end
    if self.bAutoSize then
        --self:getAutoSize()
        self.bMarkViewportResize = nil
        return
    end
    self:StartTimer("REFRESH_LIST", function()
        local size = self.getLocalSizeFun(self.getCachedGeometryFun(self:getRoot()))
        local width, height
        if self.bIsVertical then
            width = size.X - self.pagePadding.Left - self.pagePadding.Right
            height = size.Y - self.pagePadding.Top - self.pagePadding.Bottom
        else
            width = size.X - self.pagePadding.Left - self.pagePadding.Right
            height = size.Y - self.pagePadding.Top - self.pagePadding.Bottom
        end
        self.reSizeCount = self.reSizeCount + 1
        if width == self.width and height == self.height and self.reSizeCount < 10 then
            return self:UpdateSize()
        end
        self.reSizeCount = self.reSizeCount + 1
        self.bMarkViewportResize = nil
        if self._cacheIdx then
            self:ScrollToIndex(self._cacheIdx)
            self._cacheIdx = nil
        else
            self:onUserScrolled(self.oldOffect)
        end
    end,1,1)
end