---@class ListView:BaseList
local ListView = DefineClass("ListView", BaseList)
local ESelectionMode = import("ESelectionMode")

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

ListView._rootMeta = {
	__index = function(tb, key)
		local v = rawget(tb, key)
		if v == nil then
            v = import("UIFunctionLibrary").FindWidget(tb.WidgetRoot, key.."_lua")
			if not v then
				Log.Debug("can not find ", key, " in UI ", tb.WidgetRoot:GetName())
				return
			end
			if v and v:IsA(import("UserWidget")) then
				v = setmetatable({WidgetRoot = v}, UIView._rootMeta)
			end
			rawset(tb, key, v)
		end
		return v
	end
}

---@param widget UListView
---@param name string ListView的名字
---@param visible bool scrollbar是否显示
---@param cell UIController
function ListView.OnCreate(self, name, visible, cell) -- luacheck: ignore
    ---@type number @用来记录UObject数量
    self.oneObjNum = 0
    ---@type table @子UIComponent待注册的事件存储
    self._cellListeners = nil
    ---@type boolean @双击开关
    self.doubleClickEnabled = true
    ---@type UIController @所属UI
    self.owner = self.parentScript
    local widget = self:GetViewRoot()
    if visible == nil then
        visible = false
    end
    self:GetViewRoot():SetScrollbarVisibilityEx(visible)
    ---@type int 列表选中的第多少条数据
    self.selectedIndex = -1
    ---@type number @列表数据总数
    self.total = -1
    ---@type table @listviewitem与UIComponent的索引
    self.scrollItems = {}
    ---@type table<UIComponent,number> @UIComponent与index索引
    self.cellIndexs = {}
    ---@type table<number,number> @双击用的点击时间记录
    self.lastClickTimes = {}
    ---@type string @列表名称
    self.name = name .. "_"
    self.timeName = self.parentScript.__cname .. self.name  --定时器名字固定前缀
    ---@type UIComponent @UIComponent类
    self.cell = cell
    ---@type table<UserWidget,UIComponent> @控件与UIComponent索引
    self.uiCells = {}
    ---@type table<number,UIComponent> @index与UIComponent索引
    self.wigets = {}
    ---@type function @按钮点击音频播放方法
    self.ClickAudioFunc = nil
    ---@type number @按钮点击音频
    self.btnAudio = nil
    --SafeRefresh
    self.isRefreshing = false
    --可以多选的列表
    self.selectedIndexs = {}
    ---@type table<number,boolean> @标记子UIComponent长按
    self.blong = {}
    --主动绑定OnRefresh_List来刷新滚动列表，不能没有
    local methodName = "OnRefresh_" .. name
    local callback = self.parentScript[methodName]
    if not callback then
        Log.Error("[UI] Cannot Find Lua Function For UIEvent, ", methodName, " in ui ", self.parentScript.__cname)
        return
    end
    self:AddSafeRefreshFun(callback)
    --主动绑定OnClick_List事件，没有方法不绑定，OnClick_List方法定义参考前面注释
    local onClick = self.parentScript["OnClick_" .. name]
    ---@type function @点击回调方法
    self.onClick = onClick
    local canSel = self.parentScript["CanSel_" .. name]
    ---@type function @能否选中的回调方法
    self.canSel = canSel
    local root = self.parentScript:GetViewRoot()

    if _G.GMSHOWWIDGETPATH then
        widget.BP_OnItemClicked:Add(root, function(item)
            Log.Warning("Please Add Big_Button_ClickArea")
            if not self.enabled then return end
            if self.btnAudio and self.btnAudio ~= 0 then
                local r = self:GetRendererAt(item.Index)
                if r and r.Btn_ClickArea then
                    Game.AkAudioManager:OnUIPostEvent(r.Btn_ClickArea, EUIEventTypes.CLICK)
                end            end
            self:OnItemClicked(item.Index)
            if self.ClickAudioFunc then
                self.ClickAudioFunc()
            end

        end)
    else
        widget.BP_OnItemClicked:Add(function(item)
            Log.Warning("Please Add Big_Button_ClickArea")
            if not self.enabled then return end
            if self.btnAudio and self.btnAudio ~= 0 then
                local r = self:GetRendererAt(item.Index)
                if r.Btn_ClickArea then
                    Game.AkAudioManager:OnUIPostEvent(r.Btn_ClickArea, EUIEventTypes.CLICK)
                end
            end
            self:OnItemClicked(item.Index)
            if self.ClickAudioFunc then
                self.ClickAudioFunc()
            end
        end)
    end

    local onDoubleClick = self.parentScript["OnDoubleClick_" .. name]
    if onDoubleClick then
        self.onDoubleClick = onDoubleClick
        widget.BP_OnItemDoubleClicked:Add(function(item)
            Log.Warning("Please Add Big_Button_ClickArea")
            if not self.enabled then return end
            self:OnItemDoubleClicked(item.Index)
        end)
    end

    local onLongPress = self.parentScript["OnLongPress_" .. name]
    if onLongPress then
        self.onLongPress = onLongPress
    end


    -- self.newItems = {}

    widget.BP_OnEntryInitializedExt:Add(function(item, inWidget)
        if not self.enabled then return end
        -- Log.Warning("BP_OnEntryInitializedExt name ".. self.name .. "index "..item.Index, " widget ", widget)
        self:OnEntryInitializedExt(item, inWidget)
        -- table.insert(self.newItems, item)
        -- table.insert(self.newItems, widget)
    end)
    local selectionMode = widget.SelectionMode
    ---@type boolean @是否是单选toggle模式
    self.toggle = selectionMode == ESelectionMode.SingleToggle
    ---@type boolean @是否是多选
    self.multi = selectionMode == ESelectionMode.Multi
    ---@type boolean @标记列表是否生效
    self.enabled = true
end

function ListView:GetCellIndex(cell)
    return self.cellIndexs[cell]
end

function ListView:EnableDoubleClick(enabled)
    self.doubleClickEnabled = enabled
end

function ListView:SetScrollbarVisibility(visible)
    self:GetViewRoot():SetScrollbarVisibilityEx(visible)
end

---点击处理
---@private
function ListView:HandleItemClicked(uiCell)
    if not self.enabled then return end
    self:OnItemClicked(self.cellIndexs[uiCell])
end

---点击处理(区分单击和双击)
---@private
function ListView:OnItemClicked(index)
    -- Log.Warning("[ListView] OnItemClicked ", index)
    local r = self:GetRendererAt(index)
    if not r then return end
    local k = table.ikey(self.wigets, r)
    if self.blong[k] then return end
    if not self.onDoubleClick or not self.doubleClickEnabled then
        self:OnItemClickedex(index)
        return
    end
    local t = self.lastClickTimes[index]
    local name = self.timeName .. k
    if t then
        --- 双击
        self.owner:StopTimer(name)
        self.lastClickTimes[index] = nil
        self:OnItemDoubleClicked(index)
    else
        self.lastClickTimes[index] = _now()
        self.owner:StartTimer(name, function()
            self.lastClickTimes[index] = nil
            self:OnItemClickedex(index)
        end, Enum.EConstFloatData.DOUBLE_CLICK_INTERVAL, 1)
    end
end

function ListView:OnItemClickedex(index)
    local multi = self.multi
    local toggle = self.toggle
    local callback = self.callback
    local onClick = self.onClick
    local owner = self.owner
    local canSel = not self.canSel or self.canSel(owner, index)
    --只能单选的列表
    if not multi then
        if self.selectedIndex and self.selectedIndex == index then
            local r = self:GetRendererAt(index)
            if r and onClick then
                onClick(owner, r, index)
            end
            if toggle then
                if r then
                    callback(owner, r, index, false)
                end
                self.selectedIndex = -1
            end
            return
        end
        local oldIndex = self.selectedIndex
        if canSel and oldIndex and oldIndex > 0 then
            local r = self:GetRendererAt(oldIndex)
            if r then
                callback(owner, r, oldIndex, false)
            end
        end
        if canSel then
            self.selectedIndex = index
        end
        local r = self:GetRendererAt(index)
        if r then
            if canSel then
                callback(owner, r, index, true)
            end
            if onClick then
                onClick(owner, r, index)
            end
        end
        return
    end
    --可以多选的列表
    local selected = not self.selectedIndexs[index]
    local r = self:GetRendererAt(index)
    if r then
        if canSel then
            callback(owner, r, index, selected)
        end
    end
    if not selected or canSel then
        self.selectedIndexs[index] = selected
    end
    if r then
        if onClick then
            onClick(owner, r, index)
        end
    end
end

function ListView:OnItemDoubleClicked(index)
    local r = self:GetRendererAt(index)
    if r then
        Log.Debug("[ListView] onDoubleClick", index)
        self.onDoubleClick(self.owner, r, index)
    end
end

---按下处理(区分长按与单击)
---@private
function ListView:OnItemPressed(index)
    -- Log.Warning("[ListView] OnPressed ", index)

    local r = self:GetRendererAt(index)
    if not r then return end
    local k = table.ikey(self.wigets, r)
    self.blong[k] = false
    local name = self.timePressName .. k
    self.owner:StartTimer(name, function()
        -- Log.Warning("[ListView] onLongPress", index)
        self.blong[k] = true
        self.onLongPress(self.owner, r, index)
    end, Enum.EConstFloatData.LONG_PRESS_TIME, 1)
end

function ListView:OnItemReleased(index)
    -- Log.Warning("[ListView] OnItemReleased ", index)
    local r = self:GetRendererAt(index)
    if not r then return end
    local name = self.timePressName .. table.ikey(self.wigets, r)
    self.owner:StopTimer(name)
end

function ListView:OnEntryInitializedExt(item, widget)
    -- Log.Warning("OnEntryInitializedExt name ".. self.name .. "index "..item.Index)
    local multi = self.multi
    local callback = self.callback
    local owner = self.owner
    local index = item.Index
    --只能单选的列表
    if not multi then
        local selected = self.selectedIndex and self.selectedIndex == index
        local cell = self:GetCell(widget, index)
        if self.cell then
            cell:Show()
            cell:Open()
        end
        self.scrollItems[item] = cell
        self.cellIndexs[cell] = index
        if callback then
            callback(owner, cell, index, selected)
        end
        return
    end
    --可以多选的列表
    --local index = item.Index
    local selected = self.selectedIndexs[index] or false
    local cell = self:GetCell(widget, index)
    if self.cell then
        cell:Show()
        cell:Open()
    end
    self.scrollItems[item] = cell
    self.cellIndexs[cell] = index
    if callback then
        callback(owner, cell, index, selected)
    end
end

---刷新滚动列表
---@public
---@param total number 滚动列表显示的数据的总数
---@param top number|nil 让滚动列表瞬间滚动到第几条数据对应的格子(同ScrollToIndex,top为nil的时候滚动列表待在以前的状态)
function ListView:SetData(total, top)
    if self.isRefreshing == true then

        Log.Error("Cannot SetData in OnRefresh")
        return
    end
    -- Log.Warning("SetData self.name ", self.name, " total ", total)
    local oldTotal = self.total
    if self.total ~= total then
        self.total = total
        local items = import("UIFunctionLibrary").GetListObject(self:GetViewRoot(), total)
        self:GetViewRoot():BP_SetListItems(items)
        self:GetViewRoot():RegenerateAllEntries()
        items:Clear()
        -- Log.Warning("*********************RegenerateAllEntries self.name", self.name, " total ", total)
    else
        -- Log.Warning("no*********************RegenerateAllEntries self.name", self.name, " total ", total)
        local multi = self.multi
        local callback = self.callback
        local owner = self.owner
        for index = 1, total do
            local r = self:GetRendererAt(index)
            if r then
                --只能单选的列表
                if not multi then
                    local selected = self.selectedIndex and self.selectedIndex == index
                    if callback then
                        callback(owner, r, index, selected)
                    end
                else
                    --可以多选的列表
                    local selected = self.selectedIndexs[index] or false
                    if callback then
                        callback(owner, r, index, selected)
                    end
                end
            end
        end
    end
    if top then
        self:ScrollToIndex(top)
    elseif oldTotal < 0 then
        self:GetViewRoot():SetCurrentScrollOffsetDefault()
        self:ScrollToIndex(1)
    end
end

---获得第多少条数据对应哪个格子
---@public
function ListView:GetRendererAt(index)
    local item = self:GetViewRoot():GetItemAt(index-1)
    if self:GetViewRoot():BP_IsItemVisible(item) then
        return self.scrollItems[item]
    end
end

---让滚动列表瞬间滚动到第几条数据对应的格子
---@public
function ListView.ScrollToIndex(self, index)
    -- Log.Warning("ScrollToIndex self.name ", self.name, " index ", index)
	if (index <= 0 or index > self.total) then
        return
    end
    if index == 1 then
        self:GetViewRoot():ScrollIndexIntoView(index-1)
    elseif index == self.total then
        self:GetViewRoot():ScrollIndexIntoView(index-1)
    else
       self:GetViewRoot():ScrollIndexIntoView(index-1)
    end
end

---选中第几个数据所在的格子，需要在按钮的click里去设置
---@public
---@param index number
function ListView:Sel(index)
    if self.canSel and not self.canSel(self.owner, index) then
        return
    end
    if not self.multi then
        index = index or self.selectedIndex or 1
        if index < 1 then index = 1 end
        if index > self.total then index = self.total end
        if self.selectedIndex == index then return end
        local oldIndex = self.selectedIndex
        self.selectedIndex = index
        local cb = self.callback
        if not cb then return end
        if oldIndex and oldIndex >= 0 then
            local r = self:GetRendererAt(oldIndex)
            if r then
                cb(self.owner, r, oldIndex, false)
            end
        end
        local r = self:GetRendererAt(index)
        if r then
            cb(self.owner, r, index, true)
        end
        return
    end
    index = index or 1
    if index < 1 then index = 1 end
    if index > self.total then index = self.total end
    self.selectedIndexs[index] = true
    local cb = self.callback
    if not cb then return end
    local r = self:GetRendererAt(index)
    if r then
        cb(self.owner, r, index, true)
    end
end

---如果index对应的格子在显示就执行Refresh方法刷新此格子
---@public
---@param index int 传需要刷新的格子的index
function ListView:RefreshCell(index)
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

---取消选中第几个数据所在的格子
---@public
---@param index int 单选列表只能取消当前选中的，不用传参数，多选列表需要传取消选中的是哪一个
function ListView:CancelSel(index)
    if not self.multi then
        local oldIndex = self.selectedIndex
        if oldIndex and oldIndex > 0 then
            local r = self:GetRendererAt(oldIndex)
            if r then
                local cb = self.callback
                if cb then
                    cb(self.owner, r, oldIndex, false)
                end
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
        local cb = self.callback
        if cb then
            cb(self.owner, r, index, false)
        end
    end
end

---取消选中所有格子
---@public
function ListView:CancelAllSel()
    if not self.multi then
        local oldIndex = self.selectedIndex
        if oldIndex and oldIndex > 0 then
            local r = self:GetRendererAt(oldIndex)
            if r then
                local cb = self.callback
                if cb then
                    cb(self.owner, r, oldIndex, false)
                end
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
                local cb = self.callback
                if cb then
                    cb(self.owner, r, index, false)
                end
            end
        end
    end
    table.clear(self.selectedIndexs)
end

---得到滚动列表里的组件
---@param widget  滚动列表组件
---@param index 第多少个
---@return UIController
function ListView:GetCell(widget, index)
    ---@type UIController
    local uiCell = self.uiCells[widget]
    if uiCell then
        return uiCell
    end
    uiCell = self:BindListComponent(self.name, widget, self.cell, self.GetCellIndex, self, true)
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
    self.uiCells[widget] = uiCell
    local btn = uiCell.View.Btn_ClickArea ~= nil and uiCell.View.Btn_ClickArea or uiCell.View.Big_Button_ClickArea --todo 后续wbp里命名都统一成Btn_ClickArea，目前为了防止旧资源报错，先加上保护措施
    if btn then
        if btn.Audio then
            self.btnAudio = btn.Audio
        end
        self:AddUIListener(EUIEventTypes.CLICK, btn, self.HandleItemClicked, uiCell)
        if self.onLongPress then
            if not self.timePressName then
                self.timePressName = self.timeName .. "Press"
            end
            self:AddUIListener(EUIEventTypes.Pressed, btn, function()
                if not self.enabled then return end
                self:OnItemPressed(self.cellIndexs[uiCell])
            end)
            self:AddUIListener(EUIEventTypes.Released, btn, function()
                if not self.enabled then return end
                self:OnItemReleased(self.cellIndexs[uiCell])
            end)
        end
    end

    table.insert(self.wigets, uiCell)
    -- if self.oneObjNum < 1 then
    --     self.oneObjNum = UIHelper.GetObjectNum(widget) or 1
    -- end
    -- self.owner:AddObjectNum(self.oneObjNum)
    return uiCell
end

---得到滚动列表里的已使用的百分比
---@public
function ListView:GetDistancePercent()
    return self:GetViewRoot():GetDistancePercent()
end

---得到滚动列表里的未使用的百分比
---@public
function ListView:GetDistancePercentRemaining()
    return self:GetViewRoot():GetDistancePercentRemaining()
end

---得到滚动列表里的ScrollOffset，指的是可见的第一个元素的偏移
---@public
function ListView:GetScrollOffset()
    return self:GetViewRoot():GetScrollOffset()
end

---设置滚动列表是否开启禁止过度滚动
---@public
---@param newAllowOverscroll bool true允许过度滚动，false不允许过度滚动
function ListView:SetAllowOverscroll(newAllowOverscroll)
    return self:GetViewRoot():SetAllowOverscroll(newAllowOverscroll)
end

---设置滚动列表是否开启循环滚动，循环滚动是高度特化的滚动列表，仅在比较少见的专用情况下使用
---@public
---@param newAllowLoopScroll bool true允许循环滚动，false不允许循环滚动
function ListView:SetAllowLoopScroll(newAllowLoopScroll)
    return self:GetViewRoot():SetAllowLoopScroll(newAllowLoopScroll)
end

---设置滚动列表是否能多选
---@public
---@param multi bool
function ListView.SetMulti(self, multi)
    if multi then
        self:GetViewRoot():SetSelectionMode(ESelectionMode.Multi)
        local index = self.selectedIndex
        if index then
            local r = self:GetRendererAt(index)
            if r then
                self.callback(self.owner, r, index, false)
            end
            self.selectedIndex = nil
        end
        table.clear(self.selectedIndexs)
    else

        for index, selected in next, self.selectedIndexs do
            if selected then
                local r = self:GetRendererAt(index)
                if r then
                    self.callback(self.owner, r, index, false)
                end
            end
        end

        table.clear(self.selectedIndexs)
        self.selectedIndex = nil
        if self.toggle then
            self:GetViewRoot():SetSelectionMode(ESelectionMode.SingleToggle)
        else
            self:GetViewRoot():SetSelectionMode(ESelectionMode.Single)
        end
    end
    self.multi = multi
end

---获得选中的数据
---@public
---@return 选中的数据
function ListView:GetSelectedIndex()
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

function ListView:IsSelected(index)
    if self.multi then
        return self.selectedIndexs[index]
    else
        return self.selectedIndex == index
    end
end

---设置列表能不能点击和滑动
---@public
function ListView:SetEnabled(enabled)
    self.enabled = enabled
end

function ListView:OnOpen()
    if self.cell then
        for _, cell in next, self.uiCells do
            cell:Show()
            cell:Open()
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
end

---list容器只处理子Component的Show和Hide,不处理OnRefresh
function ListView:OnRefresh()
end

function ListView:OnClose()
    UIBase.OnClose(self)
    if self.cell then
        for _, cell in next, self.uiCells do
            cell:Hide()
            cell:Close()
        end
    end
    table.clear(self.lastClickTimes)
end

function ListView:OnDestroy()
    local widget = self:GetViewRoot()
    widget.BP_OnItemClicked:Clear()
    widget.BP_OnItemDoubleClicked:Clear()
    widget.BP_OnEntryInitializedExt:Clear()
    for _widget, cell in next, self.uiCells do
        self:UnbindListComponent(_widget)
    end
    self.uiCells = nil
    self.cellIndexs = nil
    self.scrollItems = nil
    self.wigets = nil
    self.ClickAudioFunc = nil
    self.owner = nil
    UIBase.OnDestroy(self)
end

function ListView:OnListClickedPlayAudio(Callback)
    self.ClickAudioFunc = Callback
end


function ListView:AddSafeRefreshFun(Callback)
    self.callback = function(...)
        self.isRefreshing = true
        xpcall(Callback, function (...)
            _G.CallBackError(...)
            self.isRefreshing = false
        end, ...)
        self.isRefreshing = false
    end

end

function ListView:RemoveSafeRefreshFun()
    return self.callback
end

---- 注册UI事件
---@public
---@param eventType EUIEventTypes
---@param widget string
---@param Func string
---@param Params any
function ListView:AddUIListener(eventType, widget, func, params)
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

---@class TileView:ListView
local TileView = DefineClass("TileView", ListView) -- luacheck: ignore