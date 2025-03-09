---@class DiffList:BaseList
local DiffList = DefineClass("DiffList", BaseList)
local ESlateVisibility = import("ESlateVisibility")
local EDescendantScrollDestination = import("EDescendantScrollDestination")
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
]=]--

DiffList.DefaultCacheSize = 60

---@param widget UScrollBox
---@param name string UScrollBox的名字
---@param visible bool scrollbar是否显示
---@param cells UIController[]
---@param cell UIController
function DiffList.OnCreate(self, name, visible, cells) -- luacheck: ignore
    ---@type table @子UIComponent待注册的事件存储
    self._cellListeners = nil
    ---@type UIController @所属UI
    self.owner = self.parentScript
    --local widget = self:GetViewRoot()
    if visible then
        self:GetViewRoot():SetScrollBarVisibility(ESlateVisibility.Visible)
    else
        self:GetViewRoot():SetScrollBarVisibility(ESlateVisibility.Hidden)
    end
    ---@type number @列表选中的第多少条数据
    self.selectedIndex = -1
    ---@type number @数据总数
    self.total = -1
    ---@type table<number,UIComponent> @类型与UIComponet类的索引
    self.cell = cells or {}
    ---@type table<UIComponent,number> @UIComponent与index的索引
    self.cellIndexs = {}
    ---@type table<UIComponent,number> @UIComponent与数据下标的索引
    self.SBIndexs = {}
    ---@type string @列表名称
    self.name = name
    ---@type table<number,string> @子UIComponet名称
    self.names = {}
    ---@type table<number,UIComponent> @数据下标与UIComponent的索引
    self.scrollItems = {}
    ---@type table<number,table<UserWidget,UIComponent>> @控件与UIComponent的映射
    self.uiCells = {}
    --AudioMgr绑定Cell类型
    self.cellskind = {}
    --主动绑定OnRefresh_List来刷新滚动列表，不能没有
    local methodName = "OnRefresh_" .. name
    local callback = self.parentScript[methodName]
    if not callback then
        Log.Error("[UI] Cannot Find Lua Function For UIEvent, ", methodName, " in ui ", self.parentScript.__cname)
        return
    end
    ---@type boolean @用来标记列表刷新过程的标记
    self.isRefreshing = false
    self:AddSafeRefreshFun(callback)
    ---@type table<number,UserWidget> @index与控件的索引
    self.rawItems = {}
    ---@type table<number,number> @记录当下类型使用数量
    self.usedItemCnts = {}
    ---@type table<number,number> @记录之前类型使用数量
    self.lastUsedItemCnts = {}
    ---@type table<number,table<number,UIComponent>> @所有子UIComponent
    self.rawScrollItems = {}
    ---@type table @当下位置与控件索引
    self.wigetPoses = {}
    ---@type table @旧的位置与控件索引
    self.oldWidgetPoses = {}
    ---@type table<number,number> @用来记录UObject数量
    self.oneObjNum = {}

    ---@type number @顶部index
    self.startIndex = 1
    ---@type table<number,table> @列表数据
    self.datas = {}
    ---@type number @顶部索引
    self.SlicedTopIndex = 1
    ---@type number @底部索引
    self.SlicedEndIndex = 1

    ---@type table<UIComponent,number> @UIComponent与index映射
    self.Widget2DataIdxMap = {}

    ---@type boolean @滑动结束标记
    self.EndTouch = false
    ---@type boolean @初始化标记
    self.widetsInited = false
    ---@type number @子成员类型数量
    self.kind = 0
    --self:AddUIListener(EUIEventTypes.UserScrolled, self:GetViewRoot(), self.onUserScrolled)
end

function DiffList:InitWidgets()
    self.widetsInited = true
    local widget = self:GetViewRoot()
    local name = self.name
    local total = widget:GetChildrenCount()
    for i = 1, total do
        self.uiCells[i] = {}
        local item = widget:GetChildAt(i-1)
        local itemName = item:GetName()
        if string.endsWith(itemName, "_lua") then
            itemName = string.sub(itemName, 1, -5)
        end
        self.names[i] = name .. "_" .. itemName .. "_"
        self.cellskind[i] = itemName
        self.rawItems[i] = {item}
        self.usedItemCnts[i] = 0
        self.lastUsedItemCnts[i] = 0
        local cell = self:GetCell(item, 1, i)
        if self.cell[i] then
            cell:Hide()
            cell:Close()
        else
            UIHelper.SetActive(item, false)
        end
        self.rawScrollItems[i] = {cell}
        self.wigetPoses[i] = item
        self.oneObjNum[i] = UIHelper.GetObjectNum(item)
    end
    self.kind = total
    self.objNum = 0
end

function DiffList:onUserScrolled(currentOffset)
    self:_InnerRefreshList(currentOffset)
    if self.IndexChangedCallback then
        local index = self:GetViewRoot():GetViewStartChildIndex()
        -- Log.Warning("GetViewStartChildIndex ", index)
        if self.startIndex ~= index then
            self.startIndex = index
            self.IndexChangedCallback(self.owner, index)
        end
    end
end

function DiffList:GetCellIndex(cell)
    return self.cellIndexs[cell], self.SBIndexs[cell]
end

---点击处理
---@private
function DiffList:HandleItemClicked(uiCell)

end

function DiffList:OnStartIndexChanged(callback)
    self.IndexChangedCallback = callback
end

-- 刷新列表长度范围
function DiffList:_InnerRefreshList(currentOffset)
    -- 如果当前数据长度小于默认cache长度，不需要处理动态加载，直接return
    if #self.datas <= DiffList.DefaultCacheSize then
        return
    end

    if self.EndTouch then
        return
    end

    local startIndex = self:GetViewRoot():GetViewStartChildIndex()
    local startWidget = self:GetViewRoot():GetChildAt(startIndex - 1)
    local startDataIdx = self.Widget2DataIdxMap[startWidget]


    local endIndex = self:GetViewRoot():GetViewEndChildIndex()
    local endWidget = self:GetViewRoot():GetChildAt(endIndex - 1)
    local endDataIdx = self.Widget2DataIdxMap[endWidget]

    local DelayTime = 0.6

    -- TODO: 修改方案，参考微信，每次上拉，加载n条cache widget到view中，然后scroll到中间
    -- 而不是采用现在这种，滑动到顶部加载一条顶部数据，滑动到底部加载一条底部数据
    if self.SlicedTopIndex == startDataIdx then
        if startDataIdx > 1 then
            local datas = table.slice(self.datas, self.SlicedTopIndex - 1, self.SlicedEndIndex - 1)
            -- Log.Warning("DiffList===========Reach Top===============")
            self:_SetData(datas, nil, self.SlicedTopIndex - 2)
            self:ScrollToIndex(2)
            self.EndTouch = true
            self.owner:StartTimer("difflistDelayTimer", function ()
                self.SlicedTopIndex = self.SlicedTopIndex - 1
                self.SlicedEndIndex = self.SlicedEndIndex - 1
                self.EndTouch = false
            end, DelayTime, 1)
        end
        return
    end

    if self.SlicedEndIndex == endDataIdx then
        if endDataIdx < #self.datas then
            local datas = table.slice(self.datas, self.SlicedTopIndex + 1, self.SlicedEndIndex + 1)
            -- Log.Warning("DiffList===========Reach End===============")
            self:_SetData(datas, nil, self.SlicedTopIndex)
            self:ScrollToIndex(2)
            self.EndTouch = true
            self.owner:StartTimer("difflistDelayTimer", function ()
                self.SlicedTopIndex = self.SlicedTopIndex + 1
                self.SlicedEndIndex = self.SlicedEndIndex + 1
                -- Log.Warning("DiffList: SlicedEndIndex = ", tostring(self.SlicedEndIndex))
                self.EndTouch = false
            end, DelayTime, 1)
        end
        return
    end

end

-- 数据剪枝
function DiffList:DataPruning(datas, top)
    local sliced, offset = {}, 0

    if top and (top + DiffList.DefaultCacheSize - 1 <= #datas) then
        sliced = table.slice(datas, top, top + DiffList.DefaultCacheSize - 1)
        offset = top - 1
        self.SlicedTopIndex = top
        self.SlicedEndIndex = top + DiffList.DefaultCacheSize - 1
    else
        sliced = table.slice(datas, #datas-DiffList.DefaultCacheSize + 1, #datas)
        offset = #datas - DiffList.DefaultCacheSize
        self.SlicedTopIndex = #datas - DiffList.DefaultCacheSize + 1
        self.SlicedEndIndex = #datas
    end

    return sliced, offset
end

-- 外部调用，传入全量data数据，内部处理剪枝，动态加载当前需要展示的部分
function DiffList:SetData(datas, top)
    if not self.widetsInited then
        self:InitWidgets()
    end
    if self.isRefreshing == true then
        Log.Error("Cannot SetData in OnRefresh")
        return
    end
    local offset = 0

    if #datas > DiffList.DefaultCacheSize then
        self.datas = datas
        datas, offset = self:DataPruning(self.datas, top) -- 数据裁切
    end
    self:_SetData(datas, top, offset)
end

---内部调用，刷新滚动列表
---@public
---@param total 滚动列表显示的数据的总数
---@param top 让滚动列表瞬间滚动到第几条数据对应的格子(同ScrollToIndex,top为nil的时候滚动列表待在以前的状态)
---@param offset 外部传入的数据偏移，datas是经过剪枝的数据 slice offset
function DiffList:_SetData(datas, top, offset)
    self.Widget2DataIdxMap = {}
    for i = 1, self.kind do
        self.lastUsedItemCnts[i] = self.usedItemCnts[i]
        self.usedItemCnts[i] = 0
    end
    self.oldWidgetPoses = self.wigetPoses
    self.wigetPoses = {}
    for i = 1, #datas do
        local data = datas[i]
        local kind = data[1]
        local items = self.rawItems[kind]
        local usedItemCnts = self.usedItemCnts[kind]
        --local lastUsedItemCnts = self.lastUsedItemCnts[kind]
        local index = usedItemCnts + 1
        local cell--, isNew
        if index > #items then
            local widget = import("UIFunctionLibrary").C7CreateWidget(self.owner:GetViewRoot(), self:GetViewRoot(), items[1])
            cell = self:GetCell(widget, index, kind)
            if self.cell[kind] then
                cell:Show()
                cell:Open()
            end
            self.rawScrollItems[kind][index] = cell
            table.insert(items, widget)

            local oldWidget = self.oldWidgetPoses[i]
            table.insert(self.oldWidgetPoses, oldWidget)
            self.oldWidgetPoses[i] = widget
            self.wigetPoses[i] = widget
            self.Widget2DataIdxMap[widget] = i + offset
            -- Log.Warning("SwapChild ", i, " ", #self.oldWidgetPoses)
            import("UIFunctionLibrary").SwapChild(self:GetViewRoot(), i-1, #self.oldWidgetPoses-1)
        else
            local widget = items[index]
            self.wigetPoses[i] = widget
            cell = self.rawScrollItems[kind][index]
            if self.cell[kind] then
                cell:Show()
                cell:Open()
            else
                UIHelper.SetActive(widget, true)
            end
            self.Widget2DataIdxMap[widget] = i + offset
        end
        self.cellIndexs[cell] = index
        self.SBIndexs[cell] = i
        self.scrollItems[i] = cell
        local selected = self.selectedIndex == index
        if self.callback then
            self.callback(self.owner, cell, i + offset, selected)
        end
        self.usedItemCnts[kind] = index
    end
    for i = 1, self.kind do
        local items = self.rawItems[i]
        local usedItemCnts = self.usedItemCnts[i]
        local lastUsedItemCnts = self.lastUsedItemCnts[i]
        for index = usedItemCnts + 1, #items do
            local widget = items[index]
            if index <= lastUsedItemCnts then
                local cell = self.rawScrollItems[i][index]
                if self.cell[i] then
                    cell:Hide()
                    cell:Close()
                else
                    UIHelper.SetActive(widget, false)
                end
            end
            table.insert(self.wigetPoses, widget)
        end
    end
    local i, len = 1, #self.wigetPoses
    while i < len do
        local oldWidget = self.oldWidgetPoses[i]
        local widget = self.wigetPoses[i]
        if oldWidget == widget then
            i = i + 1
        else
            local oldPos = table.ikey(self.oldWidgetPoses, widget)
            if not oldPos then
                -- Log.Warning(">>>>>>>>>>DiffList swap error >>>>>>> cannot find ikey: ", tostring(widget))
                i = i + 1
            else
                self.oldWidgetPoses[oldPos] = oldWidget
                self.oldWidgetPoses[i] = widget
                -- Log.Warning("SwapChild ", i, " ", oldPos)
                import("UIFunctionLibrary").SwapChild(self:GetViewRoot(), i-1, oldPos-1)
                i = i + 1
            end
        end
    end

    self.total = #datas
    if top then
        self:ScrollToIndex(top)
    end
end

---获得第多少条数据对应哪个格子
---@public
function DiffList:GetRendererAt(index)
    return self.scrollItems[index]
end

---让滚动列表瞬间滚动到第几条数据对应的格子
---@public
function DiffList.ScrollToIndex(self, index)
	if (index <= 0 or index > self.total) then
        return
    end
    if index == 1 then
        self:GetViewRoot():ScrollToStart()
    elseif index == self.total then
        self:GetViewRoot():ScrollToEnd()
    else
        local r = self:GetRendererAt(index)
        if r then
            self:GetViewRoot():ScrollWidgetIntoView(r.View.WidgetRoot, true, EDescendantScrollDestination.TopOrLeft, 0)
        end
    end
end

---选中第几个数据所在的格子，需要在按钮的click里去设置
---@public
---@param index int
function DiffList:Sel(index)
    index = index or self.selectedIndex or 1
    if index < 1 then index = 1 end
    if index > self.total then index = self.total end
    if self.selectedIndex == index then return end
    local oldIndex = self.selectedIndex
    self.selectedIndex = index
    local cb = self.callback
    if not cb then return end
    if oldIndex >= 0 then
        local r = self:GetRendererAt(oldIndex)
        if r then
            cb(self.owner, r, oldIndex, false)
        end
    end
    local r = self:GetRendererAt(index)
    if r then
        cb(self.owner, r, index, true)
    end
end

---取消选中第几个数据所在的格子
---@public
---@param index int 单选列表只能取消当前选中的，不用传参数，多选列表需要传取消选中的是哪一个
function DiffList:CancelSel(index)
    local oldIndex = self.selectedIndex
    if oldIndex > 0 then
        local r = self:GetRendererAt(oldIndex)
        if r then
            local cb = self.callback
            if cb then
                cb(self.owner, r, oldIndex, false)
            end
        end
    end
    self.selectedIndex = -1
end

---得到滚动列表里的组件
---@param widget  滚动列表组件
---@param index 第多少个
---@return UIController
function DiffList:GetCell(widget, index, kind)
    ---@type UIController
    local uiCell = self.uiCells[kind][widget]
    if uiCell then
        return uiCell
    end
    uiCell = self:BindListComponent(self.names[kind], widget, self.cell[kind], self.GetCellIndex, self, true)
    if not self.cell[kind] and self._cellListeners then
        local cellListeners = self._cellListeners[kind]
        if cellListeners then
            for eventType, listeners in next, cellListeners do
                for names, v in next, listeners do
                    local c = uiCell
                    for i = 1, #names do
                        c = c[names[i]]
                        if not c then
                            break
                        end
                    end
                    if c then
                        UIComponent.AddUIListener(self, eventType, c, v[1], uiCell)
                    end
                end
            end
        end
    end
    self.uiCells[kind][widget] = uiCell
    if uiCell.UpdateObjectNum then
        uiCell:UpdateObjectNum(UIHelper.GetObjectNum(widget))
    end
    return uiCell
end

---得到滚动列表里的已使用的百分比
---@public
function DiffList:GetDistancePercent()
    return self:GetViewRoot():GetDistancePercent()
end

---得到滚动列表里的未使用的百分比
---@public
function DiffList:GetDistancePercentRemaining()
    return self:GetViewRoot():GetDistancePercentRemaining()
end

---得到滚动列表里的ScrollOffset，指的是可见的第一个元素的偏移
---@public
function DiffList:GetScrollOffset()
    return self:GetViewRoot():GetScrollOffset()
end

---设置滚动列表是否开启禁止过度滚动
---@public
---@param newAllowOverscroll bool true允许过度滚动，false不允许过度滚动
function DiffList:SetAllowOverscroll(newAllowOverscroll)
    return self:GetViewRoot():SetAllowOverscroll(newAllowOverscroll)
end

---设置滚动列表是否开启循环滚动，循环滚动是高度特化的滚动列表，仅在比较少见的专用情况下使用
---@param newAllowLoopScroll bool true允许循环滚动，false不允许循环滚动
function DiffList:SetAllowLoopScroll(newAllowLoopScroll)
    return self:GetViewRoot():SetAllowLoopScroll(newAllowLoopScroll)
end

function DiffList:OnOpen()
    for i = 1, self.kind do
        if self.cell[i] then
            for index = 1, self.usedItemCnts[i] do
                local cell = self.rawScrollItems[i][index]
                cell:Show()
                cell:Open()
            end
        end
    end
end

---list容器只处理子Component的Show和Hide,不处理OnRefresh
function DiffList:OnRefresh()
end

function DiffList:OnClose()
    UIBase.OnClose(self)
    for i = 1, self.kind do
        if self.cell[i] then
            for index = 1, self.usedItemCnts[i] do
                local cell = self.rawScrollItems[i][index]
                cell:Hide()
                cell:Close()
            end
        end
    end
end

function DiffList:OnDestroy()
    for i = 1, self.kind do
        for widget, cell in next, self.uiCells[i] do
            self:UnbindListComponent(widget)
        end
    end
    self.uiCells = nil
    self.scrollItems = nil
    self.cellIndexs = nil
    self.rawScrollItems = nil
    self.wigetPoses = nil
    self.oldWidgetPoses = nil
    self.Widget2DataIdxMap = nil
    self.owner = nil
    UIBase.OnDestroy(self)
end



function DiffList:AddSafeRefreshFun(Callback)
    self.callback = function(...)
        self.isRefreshing = true
        xpcall(Callback, function (...)
            _G.CallBackError(...)
            self.isRefreshing = false
        end, ...)
        self.isRefreshing = false
    end
end

function DiffList:RemoveSafeRefreshFun()
    return self.callback
end

---- 注册UI事件
---@public
---@param eventType EUIEventTypes
---@param widget string
---@param Func string
---@param Params any
function DiffList:AddUIListener(eventType, kind, widget, func, params) -- luacheck: ignore
    if type(kind) == "number" then
        if not self._cellListeners then
            self._cellListeners = {}
        end
        local cellListeners = self._cellListeners[kind]
        if not cellListeners then
            cellListeners = {}
            self._cellListeners[kind] = cellListeners
        end
        local listeners = cellListeners[eventType]
        if not listeners then
            listeners = {}
            cellListeners[eventType] = listeners
        end
        local nfun = func .. "list"
        local arr = string.split(widget, "/")
        listeners[arr] = {nfun, params}
        self[nfun] = function(selff, ...)
			local tmpParam = table.pack(...)
			local cellIndex = self:GetCellIndex(tmpParam[tmpParam.n])
			tmpParam[tmpParam.n] = cellIndex
			selff.parent[func](selff.parent, table.unpack(tmpParam))
        end
        return
    end
    UIComponent.AddUIListener(self, kind, widget, func)
end