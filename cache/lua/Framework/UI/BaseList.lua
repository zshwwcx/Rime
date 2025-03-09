local IListAnimation =  kg_require("Framework.UI.List.ListComponents.IListAnimation")
--local ListAnimationLibrary = kg_require("Framework.UI.ListAnimationLibrary")
---@class BaseList:UIComponent,IListAnimation
local BaseList = DefineClass("BaseList", UIComponent, IListAnimation)

BaseList._rootMeta = {
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

---@class BaseList.Kind
BaseList.Kind = {
    ComList = 1,        --通用列表
    TreeList = 2,       --树形列表
    GroupView = 3,      --简单容器
    IrregularList = 4,  --异形列表
    DiffList = 5,       --多类型子节点列表（可以用treelist替代，待删）
    OldList = 6,        --老的ExListView（可以用ComList替代，待删）
    OldTileList = 7,    --老的ExTileView（可以用ComList替代，待删）
    PageList = 8,
    NewDiffList = 9,
}

BaseList.createFunc = {
    [BaseList.Kind.ComList] = function(uiController, widget, cell, listName, bParentAction, buttonPath, bIsAsync)
        local list = uiController:BindComponent(widget, ComList, listName, cell, bParentAction, bIsAsync)
        return list
    end,
    [BaseList.Kind.TreeList] = function(uiController, widget, cells, listName, bParentAction, buttonPath, bIsAsync)
        local list = uiController:BindComponent(widget, TreeList, listName, cells, bParentAction, buttonPath, bIsAsync)
        return list
    end,
    [BaseList.Kind.GroupView] = function(uiController, widget, cell, listName, bParentAction, buttonPath, bIsAsync)
        local list = uiController:BindComponent(widget, GroupView, listName, cell)
        --local list = GroupView.new(uiController.uid, uiController.userWidget, widget, uiController, listName, cell, #uiController.lists)
        --list:Show()
        --list:Open()
        return list
    end,
    [BaseList.Kind.IrregularList] = function(uiController, widget, cell, listName, bParentAction, buttonPath, bIsAsync)
        local list = uiController:BindComponent(widget, IrregularListView, cell)
        --local list = IrregularListView.new(uiController.uid, uiController.userWidget, widget, uiController, cell)
        return list
    end,
    [BaseList.Kind.DiffList] = function(uiController, widget, cells, listName, bParentAction, buttonPath, bIsAsync)
        local list = uiController:BindComponent(widget, DiffList, listName, false, cells)
        --local list = DiffList.new(uiController.uid, uiController.userWidget, widget, uiController, listName, false, cells)
        --list:Show()
        --list:Open()
        return list
    end,
    [BaseList.Kind.OldList] = function(uiController, widget, cell, listName, bParentAction, buttonPath, bIsAsync)
        local list = uiController:BindComponent(widget, ListView, listName, false, cell)
        --local list = ListView.new(uiController.uid, uiController.userWidget, widget, uiController, listName, false, cell)
        --list:Show()
        --list:Open()
        return list
    end,
    [BaseList.Kind.OldTileList] = function(uiController, widget, cell, listName, bParentAction, buttonPath, bIsAsync)
        local list = uiController:BindComponent(widget, TileView, listName, false, cell)
        --local list = TileView.new(uiController.uid, uiController.userWidget, widget, uiController, listName, false, cell)
        --list:Show()
        --list:Open()
        return list
    end,
    [BaseList.Kind.PageList] = function(uiController, widget, cell, listName, bParentAction, buttonPath, bIsAsync)
        local list = uiController:BindComponent(widget, PageList, listName, cell, bParentAction, bIsAsync)
        return list
    end,
    [BaseList.Kind.NewDiffList] = function(uiController, widget, cell, listName, bParentAction, buttonPath, bIsAsync)
        local list = uiController:BindComponent(widget, NewDiffList, listName, cell, bParentAction, bIsAsync)
        return list
    end,
}

--region 滚动列表
---@param uiController UIController @持有List的父界面
---@param kind BaseList.Kind @列表类型枚举
---@param nameOrWidget Widget|string @ListView的名字或者widget
---@param cell UIComponent|nil @列表内元素类
---@param listName string|nil @自定义列表名称（会替代控件名称作为回调拼接字段）
---@param bParentAction bool @优先执行父级界面的行为（Refresh，Click等, 目前仅ComList类型生效）
---@param buttonPath string @自定义Click响应按钮路径（目前仅TreeList类型生效）
function BaseList.CreateList(uiController, kind, nameOrWidget, cell, listName, bParentAction, buttonPath, bIsAsync)
    local widgetName, widget
    if type(nameOrWidget) == "string" then
        widgetName = nameOrWidget
        widget = uiController.View[widgetName]
    else
        widgetName = nameOrWidget:GetName()
        if not widgetName then
            widgetName = nameOrWidget.WidgetRoot:GetName()
        end
        if string.endsWith(widgetName, "_lua") then
            widgetName = string.sub(widgetName, 1, -5)
        end
        widget = nameOrWidget
    end
    if not listName then
        listName = widgetName
    end
    -- if uiController.lists[listName] then
    --     Log.Error("repeate create list ", listName)
    --     return
    -- end
    local list = BaseList.createFunc[kind](uiController, widget, cell, listName, bParentAction, buttonPath, bIsAsync)
    return list
end

---public 列表里widget绑定Lua脚本
---@param name 控件名
---@param widget userdata  UI组件
---@param cell UIComponent 继承自UICell的Lua脚本
---@param func function GetCellIndex函数
---@param list 列表
---@return UIComponent 脚本实例化对象
function BaseList:BindListComponent(name, widget, cell, func, list, forbidClick)
    local c = widget
    if cell then
        local uiCell = self:BindComponent(widget, cell, name)
        return uiCell
    else
        if widget and widget:IsA(import("UserWidget")) then
            c = setmetatable({WidgetRoot = widget}, UIView._rootMeta)
        else
            c = setmetatable({WidgetRoot = widget}, BaseList._rootMeta)
        end
        c.View = c
    end
	return c
end

---public 列表里widget绑定Lua脚本
---@param name 控件名
---@param widget userdata  UI组件
---@param cell UIComponent 继承自UICell的Lua脚本
---@param func function GetCellIndex函数
---@param list 列表
---@return UIComponent 脚本实例化对象
function BaseList:UnbindListComponent(widget)
end

return BaseList