---@class NewGroupView:BaseList
local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
local defaultComponent = kg_require("Framework.UI.List.NewList.BaseListItemComponent")
local NewGroupView = DefineClass("NewGroupView", UIComponent)

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
---@param widget UWidget
---@param name string ListView的名字
---@param cell UIController
function NewGroupView:ctor(_, _, widget, parentComponent, cell, name)
    ---@type number @用来记录UObject数量
    self.oneObjNum = 0
    ---@type UIController @所属UI
    self.owner = self:GetParent()
    ---@type number @选中的第多少条数据
    self.selectedIndex = -1
    ---@type number @列表总数
    self.total = -1
    ---@type table<number,UIComponent> @index与UIComponent的索引
    self.scrollItems = {}
    ---@type table<UIComponent,number> @UIComponent与index的索引
    self.cellIndexs = {}
    ---@type string @列表名称
    if not name then
        name = widget:GetName()
    end
    self.name = name
    ---@type UIComponent @子UIComponent类
    self.cell = cell
    if not self.cell then
        self.cell = defaultComponent
    end
    ---@type table<UserWidget,UIComponent> @控件与UIComponent的索引
    self.uiCells = {}
    --主动绑定OnRefresh_Group来刷新滚动列表，不能没有
    local methodName = "OnRefresh_" .. name
    local callback = self.owner[methodName]
    
    ---@type boolean @用来标记列表刷新过程的标记
    self.isRefreshing = false
    self:AddSafeRefreshFun(callback)
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

    if not callback then
        Log.Error("[UI] Cannot Find Lua Function For UIEvent, ", methodName, " in ui ", self.owner.__cname)
        return
    end
end



function NewGroupView:GetTemplateComponent()
    return self:GetRendererAt(1)
end

function NewGroupView:InitWidgets()
    self.widetsInited = true
    local widget = self.widget
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
        end
        self.scrollItems[i] = cell
        self.cellIndexs[cell] = i
    end
end

function NewGroupView:GetCellIndex(cell)
    return self.cellIndexs[cell]
end

---点击处理
---@private
function NewGroupView:HandleItemClicked(uiCell)
    self:OnItemClicked(self.cellIndexs[uiCell])
end

---点击处理(单击)
---@private
function NewGroupView:OnItemClicked(index)
    self:Sel(index)
end

--设置slot参数
function NewGroupView:CopySlot(Slot)
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
function NewGroupView:SetData(total, top)
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
                local widget = import("UIFunctionLibrary").C7CreateWidget(self.owner.userWidget, self.widget, self.item)
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
                    end
                end

            end
            local selected = self.selectedIndex == index
            if self.callback then
                self.callback(self.owner, cell, index, selected)
            end
        end
        for index = self.usedItemCnts + 1, self.lastUsedItemCnts do
            local widget = self.rawItems[index]
            local cell = self:GetCell(widget, index)
            if self.cell then
                cell:Hide()
                cell:Close()
            end
        end
    else
        local callback = self.callback
        local owner = self.owner
        for index = 1, total do
            local r = self:GetRendererAt(index)
            if r then
                local selected = self.selectedIndex == index
                if callback then
                    callback(owner, r, index, selected)
                end
            end
        end
    end
end

---获得第多少条数据对应哪个格子
---@public
function NewGroupView:GetRendererAt(index)
    return index <= self.total and self.scrollItems[index] or nil
end

---选中第几个数据所在的格子，需要在按钮的click里去设置
---@public
---@param index number
function NewGroupView:Sel(index)
    if not self.multi then
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

---取消选中第几个数据所在的格子
---@public
---@param index number 单选列表只能取消当前选中的，不用传参数，多选列表需要传取消选中的是哪一个
function NewGroupView:CancelSel(index)
    if not self.multi then
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

function NewGroupView:OnListUIEvent(cell,funcName,...)
	local index = self.cellIndexs[cell]
	self.owner[funcName](self.owner, ...)
end

---得到滚动列表里的组件
---@param widget  滚动列表组件
---@param index 第多少个
---@return UIController
function NewGroupView:GetCell(widget, index)
    ---@type UIController
    local uiCell = self.uiCells[widget]
    if uiCell then
        return uiCell
    end
    uiCell = self:CreateComponent(widget, self.cell)
    if self._cellListeners then
        for delegate, listeners in next, self._cellListeners do
            for names, v in next, listeners do
                local c = uiCell
                for i = 1, #names do
                    c = c.view[names[i]]
                    if not c then
                        break
                    end
                end
                if c then
                    local funcName = v[1]
                    local param = v[2]
                    uiCell[funcName] = function(cell, funcName)
                        cell.parentComponent:OnListUIEvent(cell,funcName)
                    end
                    if param.n > 0 then
                        uiCell:AddUIEvent(c[delegate], funcName, funcName, table.unpack(param))
                    else
                        uiCell:AddUIEvent(c[delegate], funcName, funcName)
                    end
                end
            end
        end
    end
    self.uiCells[widget] = uiCell
    return uiCell
end

---获得选中的数据
---@public
---@return 选中的数据
function NewGroupView:GetSelectedIndex()
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

function NewGroupView:GetItems()
    return self.uiCells
end

function NewGroupView:OnOpen()
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
function NewGroupView:OnRefresh()
end

function NewGroupView:OnClose()
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

function NewGroupView:OnDestroy()
    
    self.uiCells = nil
    self.scrollItems = nil
    self.rawItems = nil
    self.cellIndexs = nil
    self.owner = nil
end

function NewGroupView:AddSafeRefreshFun(Callback)
    self.callback = function(...)
        self.isRefreshing = true
        xpcall(Callback, function (...)
            _G.CallBackError(...)
            self.isRefreshing = false
        end, ...)
        self.isRefreshing = false
    end
end

function NewGroupView:RemoveSafeRefreshFun()
    return self.callback
end

---- 注册UI事件
---@public
---@param eventType EUIEventTypes
---@param widget string
---@param Func string
---@param Params any
function NewGroupView:AddListItemEvent(widget, delegate, functionName, ...)
    if type(widget) == "string" then
        if not self._cellListeners then
            self._cellListeners = {}
        end
        local nfun = functionName    
        local arr = string.split(widget, ".")
        local listeners = self._cellListeners[delegate]
        local tmpParam = table.pack(...)
        if not listeners then
            listeners = {}
            self._cellListeners[delegate] = listeners
        end
        listeners[arr] = {nfun, tmpParam}
        return 
    end
    self:AddUIEvent(widget[delegate], functionName, ...)
end

---@public 如果index对应的格子在显示就执行Refresh方法刷新此格子
---@param index int 传需要刷新的格子的index
function NewGroupView:RefreshCell(index)
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