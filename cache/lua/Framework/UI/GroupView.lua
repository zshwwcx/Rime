---@class GroupView:BaseList
local GroupView = DefineClass("GroupView", BaseList)

--[=[
---刷新Group里每个格子的回调函数
---OnRefresh_Group
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
]=]
--
GroupView.SelectionMode = {
    Single = 1,
    SingleToggle = 2,
    Multi = 3
}

---@param widget UWidget
---@param name string ListView的名字
---@param cell UIController
function GroupView.OnCreate(self, name, cell) -- luacheck: ignore
    ---@type number @用来记录UObject数量
    self.oneObjNum = 0
    ---@type UIController @所属UI
    self.owner = self.parentScript
    ---@type number @选中的第多少条数据
    self.selectedIndex = -1
    self.selectedIndexs = {}
    ---@type number @列表总数
    self.total = -1
    ---@type table<number,UIComponent> @index与UIComponent的索引
    self.scrollItems = {}
    ---@type table<UIComponent,number> @UIComponent与index的索引
    self.cellIndexs = {}
    self.blong = {}
    self.toggle = false
    self.multi = false
    self.enabled = false
    ---@type string @列表名称
    self.name = name .. "_"
    ---@type UIComponent @子UIComponent类
    self.cell = cell
    ---@type table<UserWidget,UIComponent> @控件与UIComponent的索引
    self.uiCells = {}
    self.timeName = string.format("%s%s",self.parentScript.__cname, self.name) --定时器名字固定前缀
    self.timePressName = nil
    --主动绑定OnRefresh_Group来刷新滚动列表，不能没有
    local methodName = "OnRefresh_" .. name
    local callback = self.parentScript[methodName]
    if not callback then
        Log.Error("[UI] Cannot Find Lua Function For UIEvent, ", methodName, " in ui ", self.parentScript.__cname)
        return
    end
    ---@type boolean @用来标记列表刷新过程的标记
    self.isRefreshing = false
    self:AddSafeRefreshFun(callback)
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
    ---@type table<number,UserWidget> @index与控件的索引
    self.rawItems = {}
    ---@type boolean @初始化标记
    self.widetsInited = false
    ---@type number @当前使用的子控件数量
    self.usedItemCnts = 0
    ---@type number @之前使用的子控件数量
    self.lastUsedItemCnts = 0
    ---@type table @子UIComponent待注册的事件存储
    self._cellListeners = nil
end

function GroupView:GetTemplateComponent()
    return self:GetRendererAt(1)
end

function GroupView:InitWidgets()
    self.widetsInited = true
    local widget = self:GetViewRoot()
    local num = widget:GetChildrenCount()
    for i = 1, num do
        local item = widget:GetChildAt(i - 1)
        if i == 1 then
            self.item = item
        end
        self.rawItems[i] = item
        local cell = self:GetCell(item, i)
        if self.cell then
            cell:Hide()
            cell:Close()
        else
            UIHelper.SetActive(item, false)
        end
        self.scrollItems[i] = cell
        self.cellIndexs[cell] = i
    end
    self.oneObjNum = UIHelper.GetObjectNum(self.item)
end

function GroupView:GetCellIndex(cell)
    return self.cellIndexs[cell]
end

function GroupView:callRefreshFun(owner, component, index, bIsSelect)
    if bIsSelect == nil then
        if self.multi then
            bIsSelect = self.selectedIndexs[index]
        else
            bIsSelect = self.selectedIndex == index
        end
    end
    if self.callback then
        self.callback(self.owner,component, index, bIsSelect)
    end
end

function GroupView:callOnClickFun(owner, component, index, bIsRightClick)
    if self.onClick then
        self.onClick(self.owner, component, index)
    end
end
---@private 调用CanSelcallback,能否选中回调
function GroupView:callCanSelFun(component, index)
    if self.canSel then
        return self.canSel(self.owner, index)
    else
        return true
    end
end
---@private 调用OnDoubleCcallback,双击事件回调
function GroupView:callOnDoubleClickFun(component, index)
    if self.onDoubleClick then
        self.onDoubleClick(self.owner,component,index)
    end
end

function GroupView:callOnLongPressFun(component, index)
    if self.onLongPress then
        self.onLongPress(self.owner, component, index)
    end
end

function GroupView:callOnReleasedFun(component, index)
    if self.cell and component.OnReleased then
        component:OnReleased(self.owner, self.datas, index)
    end
end

function GroupView:SetEnabled(enabled)
    self.enabled = enabled
end
---点击处理
---@private
function GroupView:HandleItemClicked(uiCell, bIsRightClick)
    if not self.enabled then return end
    if bIsRightClick and not self.rightClickEnabled then
        return
    end
    self:OnItemClicked(self.cellIndexs[uiCell], bIsRightClick)
end

---点击处理(单击)
---@private
function GroupView:OnItemClicked(index, bIsRightClick)
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

function GroupView:OnItemClickedex(index, bIsRightClick)
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
                self.selectedIndex = -1
                if r then
                    self:callRefreshFun(owner, r, index, false)
                    --self:playAutoAni(index, false)
                    --self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
                end
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
                --self:PlayStateAnimation(oldIndex, ListAnimationLibrary.CellState.UnSelect)
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
                --self:PlayStateAnimation(index, ListAnimationLibrary.CellState.Select)
            end
            self:callOnClickFun(owner, r, index, bIsRightClick)
        end
        return
    end
    --可以多选的列表
    local selected = not self.selectedIndexs[index]
    local r = self:GetRendererAt(index)
    if (not selected) or canSel then
        self.selectedIndexs[index] = selected
    end
    if r then
        if (not selected) or canSel then
            self:callRefreshFun(owner, r, index, selected)
        end
    end
    if r then
        self:callOnClickFun(owner, r, index, bIsRightClick)
    end
end

function GroupView:OnItemDoubleClicked(index)
    local r = self:GetRendererAt(index)
    if r then
        Log.Debug("[ComList] onDoubleClick", index)
        self:callOnDoubleClickFun(r, index)
    end
end

function GroupView:GetUniqueID(UIComponent)
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
function GroupView:OnItemPressed(index)
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

-- function GroupView:OnItemReleased(index)
--     -- Log.Warning("[ComList] OnItemReleased ", index)
--     local component = self:GetRendererAt(index)
--     local r = self:GetRendererAt(index)
--     local id = self:GetUniqueID(r)
--     local name = self.timePressName .. id
--     self.owner:StopTimer(name)
--     self:callOnReleasedFun(component, index)
-- end

--设置slot参数
function GroupView:CopySlot(Slot)
    if Slot:IsA(import("VerticalBoxSlot")) or Slot:IsA(import("HorizontalBoxSlot")) then
        local sSlot = self.item.Slot
        Slot:SetPadding(sSlot.Padding)
        Slot:SetSize(sSlot.Size)
        Slot:SetHorizontalAlignment(sSlot.HorizontalAlignment)
        Slot:SetVerticalAlignment(sSlot.VerticalAlignment)
    end
end

---刷新滚动列表
---@public
---@param total number 滚动列表显示的数据的总数
---@param top number|nil 让滚动列表瞬间滚动到第几条数据对应的格子(同ScrollToIndex,top为nil的时候滚动列表待在以前的状态)
function GroupView:SetData(total, top)
    if not self.widetsInited then
        self:InitWidgets()
    end
    if self.isRefreshing == true then
        Log.Error("Cannot SetData in OnRefresh")
        return
    end
    if self.total ~= total then
        self.total = total
        self.lastUsedItemCnts = self.usedItemCnts
        self.usedItemCnts = total
        local old = #self.scrollItems
        for index = 1, total do
            local cell, isNew
            if index > old then
                local widget = import("UIFunctionLibrary").C7CreateWidget(self.owner:GetViewRoot(), self:GetViewRoot(), self.item)
                self:CopySlot(widget.Slot)
                cell = self:GetCell(widget, index)
                self.scrollItems[index] = cell
                self.cellIndexs[cell] = index
                self.rawItems[index] = widget
                if self.cell then
                    cell:Show()
                    cell:Open()
                end
            else
                cell = self.scrollItems[index]
                if index > self.lastUsedItemCnts then
                    if self.cell then
                        cell:Show()
                        cell:Open()
                    else
                        UIHelper.SetActive(self.rawItems[index], true)
                    end
                end

            end
            local selected = self.selectedIndex == index

            self:callRefreshFun(self.owner, cell, index, selected)

        end
        for index = self.usedItemCnts + 1, self.lastUsedItemCnts do
            local widget = self.rawItems[index]
            local cell = self:GetCell(widget, index)
            if self.cell then
                cell:Hide()
                cell:Close()
            else
                UIHelper.SetActive(widget, false)
            end
        end
    else
        for index = 1, total do
            local r = self:GetRendererAt(index)
            if r then
                local selected = self.selectedIndex == index
                self:callRefreshFun(self.owner, r, index, selected)
            end
        end
    end
end

---获得第多少条数据对应哪个格子
---@public
function GroupView:GetRendererAt(index)
    return index <= self.total and self.scrollItems[index] or nil
end

---选中第几个数据所在的格子，需要在按钮的click里去设置
---@public
---@param index number
function GroupView:Sel(index)
    local multi = self.multi
    local toggle = self.toggle
    if not multi then
        index = index or self.selectedIndex or 1
        if index < 1 then index = 1 end
        if index > self.total then index = self.total end
        if self.selectedIndex == index then 
            local r = self:GetRendererAt(index)
            if toggle then
                if r then
                    self:callRefreshFun(self.owner, r, index, false)
                    --self:playAutoAni(index, false)
                    --self:PlayStateAnimation(index, ListAnimationLibrary.CellState.UnSelect)
                end
                self.selectedIndex = -1
            end
            return
        end
        local oldIndex = self.selectedIndex
        self.selectedIndex = index
        local cb = self.callback
        if not cb then return end
        if oldIndex > 0 then
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
    local selected = not self.selectedIndexs[index]
    local r = self:GetRendererAt(index)
    if r then
        self:callRefreshFun(self.owner, r, index, selected)
    end
    if (not selected) then
        self.selectedIndexs[index] = selected
    else
        self.selectedIndexs[index] = nil
    end
    self.selectedIndexs[index] = true
end

---取消选中第几个数据所在的格子
---@public
---@param index number 单选列表只能取消当前选中的，不用传参数，多选列表需要传取消选中的是哪一个
function GroupView:CancelSel(index)
    if not self.multi then
        local oldIndex = self.selectedIndex
        if oldIndex > 0 then
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
function GroupView:SetSingleToggle(bSingleToggle)
    if self.multi and not bSingleToggle then
        self:SetMulti(false)
    end

    self.toggle = bSingleToggle
    
end
function GroupView:SetMulti(multi)
    if multi then
        self.toggle = true
        -- self:GetViewRoot():SetSelectionMode(import("ESelectionMode").Multi)
        local index = self.selectedIndex
        if index > 0 then
            local r = self:GetRendererAt(index)
            if r then

                self:callRefreshFun(self.owner, r, index, false)

            end
            self.selectedIndex = nil
        end
        table.clear(self.selectedIndexs)
    else
        self.toggle = false
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
    end
    self.multi = multi
end

function GroupView:CancelAllSel()
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


function GroupView:getAutoButton(uiComponent)
    local btn
 
    if not btn then
        btn = uiComponent.View.Btn_ClickArea ~= nil and uiComponent.View.Btn_ClickArea or uiComponent.View.Big_Button_ClickArea
    end
    return btn
end

function GroupView:addClickListener(uiComponent)
    --todo 后续wbp里命名都统一成Btn_ClickArea，目前为了防止旧资源报错，先加上保护措施
    local btn = self:getAutoButton(uiComponent)
    if btn then
        UIComponent.AddUIListener(self, EUIEventTypes.CLICK, btn, "HandleItemClicked", uiComponent)
        UIComponent.AddUIListener(self, EUIEventTypes.RightClick, btn, "HandleItemClicked", uiComponent, true)

            if not self.timePressName then
                self.timePressName = self.timeName .. "Press"
            end
            UIComponent.AddUIListener(self, EUIEventTypes.Pressed, btn, function()
                if not self.enabled then return end
                self:OnItemPressed(self.cellIndexs[uiComponent])
            end)
            -- UIComponent.AddUIListener(self, EUIEventTypes.Released, btn, function()
            --     if not self.enabled then return end
            --     self:OnItemReleased(self.cellIndexs[uiComponent])
            -- end)

    end
end
---得到滚动列表里的组件
---@param widget  滚动列表组件
---@param index 第多少个
---@return UIController
function GroupView:GetCell(widget, index)
    ---@type UIController
    if not widget then
        Log.Error("GroupView GetWidget Widget is nil", self.owner.__cname)
        return
    end
    local uiCell = self.uiCells[widget]
    if uiCell then
        return uiCell
    end
    uiCell = self:BindListComponent(self.name, widget, self.cell, self.GetCellIndex, self)
    if not self.cell and self._cellListeners then
        for eventType, listeners in next, self._cellListeners do
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
    if self.enabled then
        self:addClickListener(uiCell)
    end
    self.uiCells[widget] = uiCell
    if uiCell.UpdateObjectNum then
        uiCell:UpdateObjectNum(UIHelper.GetObjectNum(widget))
    end
    return uiCell
end

---获得选中的数据
---@public
---@return 选中的数据
function GroupView:GetSelectedIndex()
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

function GroupView:GetItems()
    return self.uiCells
end

function GroupView:OnOpen()
    if not self.cell then
        return
    end
    for index = 1, self.usedItemCnts do
        local widget = self.rawItems[index]
        local cell = self:GetCell(widget, index)
        cell:Show()
        cell:Open()
    end
end

---list容器只处理子Component的Show和Hide,不处理OnRefresh
function GroupView:OnRefresh()
end

function GroupView:OnClose()
    UIBase.OnClose(self)
    if not self.cell then
        return
    end
    for index = 1, self.usedItemCnts do
        local widget = self.rawItems[index]
        local cell = self:GetCell(widget, index)
        cell:Hide()
        cell:Close()
    end
end

function GroupView:OnDestroy()
    for widget, cell in next, self.uiCells or {} do
        self:UnbindListComponent(widget)
    end
    self.uiCells = nil
    self.scrollItems = nil
    self.rawItems = nil
    self.cellIndexs = nil
    self.owner = nil
    UIBase.OnDestroy(self)
end

function GroupView:AddSafeRefreshFun(Callback)
    self.callback = function(...)
        self.isRefreshing = true
        xpcall(Callback, function (...)
            _G.CallBackError(...)
            self.isRefreshing = false
        end, ...)
        self.isRefreshing = false
    end
end


---- 注册UI事件
---@public
---@param eventType EUIEventTypes
---@param widget string
---@param Func string
---@param Params any
function GroupView:AddUIListener(eventType, widget, func, params)
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
        self[nfun] = function(selff, ...)
			local tmpParam = table.pack(...)
			local cellIndex = self:GetCellIndex(tmpParam[tmpParam.n])
			tmpParam[tmpParam.n] = cellIndex
            selff.parent[func](selff.parent, table.unpack(tmpParam))
        end
        return
    end
    UIComponent.AddUIListener(self, eventType, widget, func, params)
end

---@public 如果index对应的格子在显示就执行Refresh方法刷新此格子
---@param index int 传需要刷新的格子的index
function GroupView:RefreshCell(index)
    if not index then
        return
    end
    if index < 1 then index = 1 end
    if index > self.total then index = self.total end
    local cb = self.callback
    if not cb then return end
    local r = self:GetRendererAt(index)
    if r then
        cb(self.owner, r, index, self.selectedIndex == index)
    end
end