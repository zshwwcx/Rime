local NewUIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")

---@class UIBaseAdapter : NewUIComponent
---@field private uiBase UIBase
local UIBaseAdapter = DefineClass("UIBaseAdapter", NewUIComponent)

---@param uid string
---@param userWidget KGUserWidget
---@param widget UWidget
---@param parentComponent NewUIComponent
---@param oldComponentScript UIComponent @ 旧框架组件脚本
---@param panelUID string
---@param oldComponentScript any
function UIBaseAdapter:ctor(uid, userWidget, widget, parentComponent, panelUID, oldComponentScript, ...)
    assert(widget, "widget is nil")
    
    self.panelUID = panelUID
    if type(widget) == "table" then
        widget = widget.WidgetRoot
    end

    if not oldComponentScript then
        return
    end
    
    local targetUserWidget = widget:IsA(import("UserWidget")) and widget or self.userWidget
    local func
    if type(oldComponentScript) == 'table' and oldComponentScript.new then
        func = oldComponentScript.new
    elseif type(oldComponentScript) == 'function' then
        func = oldComponentScript
    end
    
    assert(func, "oldComponentScript must be DefineClass or function")

    local successed, uiCell = xpcall(func, _G.CallBackError, nil,
        panelUID or self.uid, targetUserWidget, widget, nil, ...)
    assert(successed, "create component instance failed.")
    self.uiBase = uiCell
end

function UIBaseAdapter:dtor()
    self.uiBase = nil
end

function UIBaseAdapter:OnCreate()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

function UIBaseAdapter:InitUIData()
end

function UIBaseAdapter:InitUIComponent()
end

function UIBaseAdapter:InitUIEvent()
end

function UIBaseAdapter:InitUIView()
end

function UIBaseAdapter:OnShow()
    if self.uiBase then
        self.uiBase:Show()
    end
end

function UIBaseAdapter:OnHide()
    if self.uiBase then
        self.uiBase:Hide()
    end
end

function UIBaseAdapter:OnRefresh(...)
    if self.uiBase then
        self.uiBase:Refresh(...)
    end
end

function UIBaseAdapter:OnOpen()
    if self.uiBase then
        self.uiBase:Open()
    end
end

function UIBaseAdapter:OnClose()
    if self.uiBase then
        self.uiBase:Close()
    end
end

function UIBaseAdapter:OnDestroy()
    if self.uiBase then
        self.uiBase:Destroy()
    end
end

-----------------------------------------------------------------------------------------
--- 桥接代码
-----------------------------------------------------------------------------------------
---@return UIBase
function UIBaseAdapter:GetUIBase()
    return self.uiBase
end

---@param cellTemplateOrCreatorFunc UIComponent
---@param baseListClass BaseList
---@param listName string
---@param bParentAction boolean
---@param buttonPath string
---@param bIsAsync boolean
---@param asyncNum number
---@return UIBaseAdapter
function UIBaseAdapter:CreateBaseList(cellTemplateOrCreatorFunc, baseListClass, listName, bParentAction, buttonPath, bIsAsync, asyncNum)
    assert(baseListClass, "baselist class is nil")
    
    local parent = self.parentComponent

    local proxy = {
        parent = parent,
        parentScript = parent,
        GetViewRoot = function () return parent.widget end,
        HandleButtonClicked = function () end,
        StartTimer = function(_, ...)
            self:StartTimer(...)
        end,
        StopTimer = function(_, ...)
            self:StopTimer(...)
        end,
    }

    local meta = {
        __index = function(t, key)
            -- for k, compare in pairs(funcNames) do
            --     if compare(key, k) then
            --         local f = parent[key]
            --         if f then
            --             local func = rawget(proxy, key)
            --             if not func then
            --                 func = function (owner, ...) return f(parent, ...) end
            --                 rawset(proxy, key, func)
            --             end
            --             return func
            --         else
            --             return nil
            --         end
            --     end
            -- end
			local var = parent[key]
			if type(var) == 'function' then
				return function(_, ...)
					return var(parent, ...)
				end
			end
            return parent[key]
        end
    }

    proxy = setmetatable(proxy, meta)

    self.uiBase = baseListClass.new(nil, self.panelUID, self.userWidget, self.widget, proxy, listName,
        cellTemplateOrCreatorFunc, bParentAction, buttonPath, bIsAsync, asyncNum)
    self.uiBase:Show()
    self.uiBase:Open()
    return self.uiBase
end

function UIBaseAdapter:HandleButtonClicked(eventType, button, prefix1, root1, prefix2, root2, param1, param2, param3)

end


function UIBaseAdapter:Dispose()
    assert(self.uiBase, "uiBase is nil")
    self.uiBase:Dispose()
end

---@return Widget|UserWidget
function UIBaseAdapter:GetViewRoot()
    return self.widget
end

---@param autoBind boolean
function UIBaseAdapter:SetAutoBind(autoBind)
    self.uiBase.autoBind = autoBind
end

--- widget绑定Lua脚本
---@param widget Widget|UserWidget
---@param componentScript UIComponent @ 组件脚本
---@return UIComponent @ 实例化对象
function UIBaseAdapter:BindComponent(widget, componentScript, ...)
    local uiBase = self.uiBase
    assert(uiBase, "uiBase is nil")
    return uiBase:BindComponent(widget, componentScript, ...)
end

---@public 创建控件，控件位于WBP_ComLib里
---@param name string @ 控件名
---@param container Widget|UserWidget @ 挂载点
---@param cell UIComponent
---@return UIComponent
function UIBaseAdapter:FormComponent(name, container, cell, ...)
    assert(self.uiBase, "uiBase is nil")
    self.uiBase:FormComponent(name, container, cell)
end

---@param component NewUIComponent|string
---@param bDontDestroyWidget boolean
function UIBaseAdapter:RemoveComponent(component, bDontDestroyWidget)
    NewUIComponent.RemoveComponent(component, bDontDestroyWidget)
    self.uiBase:RemoveComponent(component)
end

function UIBaseAdapter:PushComponents()
    self.uiBase:PushComponents()
end
---@public @回收容器内所有Lib下Component
---@param container any @容器控件
function UIBaseAdapter:PushContainerComponent(container)
    self.uiBase:PushContainerComponent(container)
end

---@public @回收单个Lib下Component
---@param container any @容器控件
---@param uiComponent UIComponent @要回收的UIComponent
function UIBaseAdapter:PushOneComponent(container, uiComponent)
    self.uiBase:PushOneComponent(container, uiComponent)
end

---@public @回收单个Lib下Component
---@param owner UIController @界面
---@param container any @容器控件
---@param uiComponent UIComponent @要回收的UIComponent
function UIBaseAdapter:PushSingleComponent(owner, container, uiComponent)
    self.uiBase:PushSingleComponent(owner,container, uiComponent)
end

---@public @回收容器内所有Lib下Component
---@param owner UIController @界面
---@param container any @容器控件
function UIBaseAdapter:PushAllComponent(owner, container)
    self.uiBase:PushAllComponent(owner, container)
end

--todo 临时方法
function UIBaseAdapter:DestroyComponent(component)
    self.uiBase:DestroyComponent(component)
end

---@param eventType EUIEventTypes
---@param widget Widget|UserWidget
---@param func string|function @ 回调函数
---@param ... any
function UIBaseAdapter:AddUIListeer(eventType, widget, func, ...)
    assert(self.uiBase, "uiBase is nil")
    self.uiBase:AddUIListener(eventType, widget, func, ...)
end

---@param eventType EUIEventTypes
---@param widget Widget|UserWidge
---@param ownedWidget Widget|UserWidget
function UIBaseAdapter:RemoveUIListener(eventType, widget, ownedWidget)
    assert(self.uiBase, "uiBase ni nil")
    self.uiBase:RemoveAllListener(eventType, widget, ownedWidget)
end


return UIBaseAdapter
