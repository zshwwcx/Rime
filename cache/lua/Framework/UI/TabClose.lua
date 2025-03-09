---@class TabClosePointerCheckResult
---@field Outside TabClosePointerCheckResult @ 鼠标指针在面板外，且不在触发控件内
---@field InsidePanel TabClosePointerCheckResult @ 鼠标指针在面板内，判断优先级高于InsideExcluded
---@field InsideExcluded TabClosePointerCheckResult @ 鼠标指针在触发控件内

---@class TabCloseEventTransition
---@field public Resume TabCloseEventTransition
---@field public Consumed TabCloseEventTransition
---@field public Recheck TabCloseEventTransition

---@class TabCloseItem
---@field public panelUID string @ 关联的Panel的UID
---@field public component UIComponent|NewUIComponent @ 关联的子UI
---@field public control Widget @ 触发控件
---@field public rectPanel {left:number, top:number, right:number, bottom:number}[] @ 关联Panel的显示区域
---@field public rectExcluded {left:number, top:number, right:number, bottom:number} @ 被排除的区域
---@field public policy Enum.EUIBlockPolicy @ 阻拦策略
---@field public hasValidRect boolean
---@field public funcOnClose fun(owner:string|UIComponent|NewUIComponent, ...):void

---@class TabClose
---@field private stack TabCloseItem[]
---@field private count number
---@field private lookup table<string|NewUIComponent|UIComponent, TabCloseItem> @ 查询表，kv弱表
---@field private rectViewport {left:number, top:number, right:number, bottom:number} @ 视口区域
---@field public BlockPolicy TabClockBlockPolicy
---@field public PointerCheckResult TabClosePointerCheckResult
local TabClose = DefineSingletonClass("TabClose", ManagerBase)

local UIFunctionLibrary = import("UIFunctionLibrary")
local KismetInputLibrary = import("KismetInputLibrary")

---@type TabClockBlockPolicy
TabClose.BlockPolicy = {
    None = 0,
    All = 1,
    TriggerControl = 2, 
}

---@type TabClosePointerCheckResult
TabClose.PointerCheckResult = {
    Outside = -1,
    InsidePanel = 0,
    InsideExcluded = 1,
}

---@type TabCloseEventTransition
TabClose.EventTransition = {
    Resume = 0,
    Consumed = 1,
    Recheck = 2,
}

function TabClose:onCtor()
    self.stack = {}
    self.count = 0
    self.lookup = setmetatable({}, {__mode = "kv"})
    self.poolItems = {}
    self.cachePointerIndex = {}
end

function TabClose:onDestroy()
    self.stack = nil
    self.count = 0
end

function TabClose:onInit()
   Game.EventSystem:AddListener(_G.EEventTypes.ON_UI_OPEN, self, self.OnOpenPanel)
   Game.UIInputProcessorManager:BindMouseButtonDownEvent(self, "OnMouseButtonDown")
   Game.UIInputProcessorManager:BindMouseButtonUpEvent(self, "OnMouseButtonUp")

    local left, right, top, bottom = UIFunctionLibrary.GetViewportBounds(_G.GetContextObject())
    self.rectViewport = { left = left, right = right, top = top, bottom = bottom }

    local BlockPolicy = Enum.EUIBlockPolicy
    self.procPolicy = {
        [BlockPolicy.Unblock] = self.UnblockButClose,
        [BlockPolicy.BlockOutsideBounds] = self.BlockOutside,
        [BlockPolicy.BlockOutsideBoundsExcludeRegions] = self.BlockOutsideExcludeRegions,
        [BlockPolicy.UnblockOutsideBounds] = self.UnblockOutside,
        [BlockPolicy.UnblockOutsideBoundsExcludeRegions] = self.UnblockOutsideExcludeRegions,
    }
end

function TabClose:onUnInit()
    Game.EventSystem:RemoveObjListeners(self)
    Game.UIInputProcessorManager:UnBindMouseButtonDownEvent(self)
    Game.UIInputProcessorManager:UnBindMouseButtonUpEvent(self)
end

---@param panelUID string @ 关联Panel的UID
---@param blockPolicy Enum.EUIBlockPolicy @ 拦截策略
---@param triggerCtrl Widget @ 触发控件
---@param funcOnClose fun(panelUID:string):void @ 关闭回调
---@param ... any @ 关联panel参数
function TabClose:AttachPanel(panelUID, blockPolicy, triggerCtrl, funcOnClose, ...)
    local item = self:ObtainItem()
    item.panelUID = panelUID
    item.policy = blockPolicy
    item.control = triggerCtrl
    local params = {...}
    item.funcOnClose = function()
        if funcOnClose then
            funcOnClose(panelUID, unpack(params))
        end

        if UIPanelConfig.PanelConfig[panelUID] then
            Game.NewUIManager:ClosePanel(panelUID)
        else
            Game.UIManager:ClosePanel(panelUID)
        end
    end

    if triggerCtrl and (blockPolicy == Enum.EUIBlockPolicy.BlockOutsideBoundsExcludeRegions or
        blockPolicy == Enum.EUIBlockPolicy.UnblockOutsideBoundsExcludeRegions) then
        local rect = {left = 0, top = 0, right = 0, bottom = 0}
        self:GetRenderingBoundingRect(triggerCtrl, rect)
        if self:IsValidRect(rect) then
            item.rectExcluded[1] = rect
            item.rectExcluded.n = 1
        end
    end

    self:PushToStack(panelUID, item)
    Log.Debug("TabClose:AttachPanel", panelUID, "blockPolicy:", blockPolicy)
end

---@param component UIComponent|NewUIComponent @关联的Component
---@param blockPolicy Enum.EUIBlockPolicy @ 阻拦策略
---@param triggerCtrl Widget @ 触发控件
---@param funcOnClose fun(component:UIComponent|NewUIComponent):void @ 关闭回调
---@param ... any @ 关联的Component参数
function TabClose:AttachComponent(component, blockPolicy, triggerCtrl, funcOnClose, ... )
    local item = self:ObtainItem()
    item.component = component
    item.policy = blockPolicy
    item.control = triggerCtrl

    local params = {...}
    -- luacheck: push ignore
    item.funcOnClose = function()
        if funcOnClose then
            funcOnClose(component, unpack(params))
        end
        Game.UIManager:ShowUI(component.uid, false)
    end
    -- luacheck: pop

    local rawClose = component.Close
    component.Close = function(com, ...)
        component.Close = rawClose
        rawClose(com, ...)
        self:RemoveFromStack(component, item)
    end

    if triggerCtrl 
        and (blockPolicy == Enum.EUIBlockPolicy.BlockOutsideBoundsExcludeRegions 
        or blockPolicy == Enum.EUIBlockPolicy.UnblockOutsideBoundsExcludeRegions) then
        local rect = { left = 0, top = 0, right = 0, bottom = 0 }
        self:GetRenderingBoundingRect(triggerCtrl, rect)
        if self:IsValidRect(rect) then
            item.rectExcluded[1] = rect
            item.rectExcluded.n = 1
        end
    end

    self:PushToStack(component, item)
    Log.Debug("TabClose:AttachComponent", component.uid, "blockPolicy:", blockPolicy)
end

---@param owner string|UIComponent|NewUIComponent
function TabClose:Dettach(owner)
    local item = self.lookup[owner]
    if item then
        self:RemoveFromStack(owner, item)
    end
end

function TabClose:Hide(panelUID, ... )
end

---@param mouseEvent PointerEvent
---@return boolean @ 返回true表示拦截，返回false表示透传
function TabClose:OnMouseButtonDown(mouseEvent)
    local pointerIndex = KismetInputLibrary.PointerEvent_GetPointerIndex(mouseEvent)
    self.cachePointerIndex[pointerIndex] = nil
    if self.count <= 0 then
        return false
    end

    local topItem = self.stack[self.count]
    ---@type FVector2D
    local screenPos = KismetInputLibrary.PointerEvent_GetScreenSpacePosition(mouseEvent)
    local userIndex = KismetInputLibrary.PointerEvent_GetUserIndex(mouseEvent)
    if not self:InternalPreCheck(topItem, screenPos.X, screenPos.Y, userIndex) then
        return false
    end
    
    -- 根据拦截策略判断
    local funcPolicy = self:GetPolicyFunc(topItem.policy)
    if funcPolicy then
        local eventTransition = funcPolicy(self, topItem, screenPos.X, screenPos.Y)
        if eventTransition == self.EventTransition.Consumed then
            return true
        elseif eventTransition == self.EventTransition.Recheck then
            return self.count > 0
        end

        return false
    end

    return false
end

---@param mouseEvent MouseEvent
function TabClose:OnMouseButtonUp(mouseEvent)
    if self.bIgnoreNextMouseUpEvent then
        self.bIgnoreNextMouseUpEvent = false
        return
    end
    
    return self:DoClose(mouseEvent)
end

function TabClose:DoClose(mouseEvent, bScreenInput)
    local pointerIndex = KismetInputLibrary.PointerEvent_GetPointerIndex(mouseEvent)
    if bScreenInput and self.cachePointerIndex[pointerIndex] then
        self.cachePointerIndex[pointerIndex] = nil
        return true
    end

    if self.count <= 0 then
        return false
    end

    local topItem = self.stack[self.count]
    ---@type FVector2D
    local screenPos = KismetInputLibrary.PointerEvent_GetScreenSpacePosition(mouseEvent)
    local userIndex = KismetInputLibrary.PointerEvent_GetUserIndex(mouseEvent)
    if not self:InternalPreCheck(topItem, screenPos.X, screenPos.Y, userIndex) then
        return false
    end

    if topItem.component then
        Log.Debug("TabClose:DoClose", topItem.component.uid)
    else
        Log.Debug("TabClose:DoClose", topItem.panelUID)
    end

    if bScreenInput then
        xpcall(topItem.funcOnClose, _G.CallBackError)
        self.cachePointerIndex[pointerIndex] = nil
        return false
    end

    -- 根据拦截策略判断
    local funcPolicy = self:GetPolicyFunc(topItem.policy)
    if funcPolicy then       
        local eventTransition, needCache = funcPolicy(self, topItem, screenPos.X, screenPos.Y, topItem.funcOnClose)

        if not bScreenInput and needCache then
            self.cachePointerIndex[pointerIndex] = true
        end

        if eventTransition == self.EventTransition.Consumed then
            return true
        elseif eventTransition == self.EventTransition.Recheck then
            return self.count > 0
        end

        return false
    end

    return false
end

function TabClose:OnOpenPanel(panelUID)
    local item = self.lookup[panelUID]
    if item == nil then
        self:AttachPanel(panelUID, nil, nil, nil)
        item = self.lookup[panelUID]
    end

    ---@type UIPanel|UIBase
    local panel = UIManager:GetInstance():getUI(panelUID)
    if not panel then
        return
    end

    local blockPolicy = item.policy
    if not blockPolicy then
        local config = Game.UIManager:GetInstance():GetUIConfig(panelUID)
        if config and config.autoclose then
            blockPolicy = config.blockpolicy or Enum.EUIBlockPolicy.Unblock
        else
            blockPolicy = self.BlockPolicy.None
        end
        item.policy = blockPolicy
    end

    local rawClose = panel.Close
    panel.Close = function(p, ...)
        p.Close = rawClose
        rawClose(p, ...)
        self:RemoveFromStack(panelUID, item)
    end
end

---@param reason string
function TabClose:IgnoreNextMouseUpEvent(reason)
    assert(reason and reason ~= "", "Must have an ignore reasonF!!")
    self.bIgnoreNextMouseUpEvent = true
    Log.Debug("TabClose:IgnoreNextMouseUpEvent reason:", reason)
end

-------------------------------------------------------------------------------
--- private
-------------------------------------------------------------------------------

---@private
---@param rect {left:number, top:number, right:number, bottom:number}
---@return boolean
function TabClose:IsValidRect(rect)   
    return rect and rect.left < rect.right and rect.top < rect.bottom
end

---@privte
---@param ptX number
---@param ptY number
---@param rect {left:number, top:number, right:number, bottom:number}
function TabClose.IsInRect(ptX, ptY, rect)
    return rect.left <= ptX and ptX <= rect.right and rect.top <= ptY and ptY <= rect.bottom
end

---@private
---@param item TabCloseItem
---@param pointerX number @ 鼠标/指针X轴坐标
---@param pointerY number @ 鼠标/指针Y轴坐标
---@return TabCloseEventTransition, boolean
function TabClose:UnblockButClose(item, pointerX, pointerY, callback)
    if callback then
        xpcall(callback, _G.CallBackError)
    end
    return self.EventTransition.Resume, false
end

---@private
---@param item TabCloseItem
---@param pointerX number @ 鼠标/指针X轴坐标
---@param pointerY number @ 鼠标/指针Y轴坐标
---@return TabCloseEventTransition, boolean
function TabClose:BlockOutside(item, pointerX, pointerY, callback)
    local result = self:DetectPointer(item, pointerX, pointerY, false)

    if result == self.PointerCheckResult.InsidePanel then
        return self.EventTransition.Resume, false
    end

    if callback then
        xpcall(callback, _G.CallBackError)
    end

    return self.EventTransition.Consumed, false
end

---@private
---@param item TabCloseItem
---@param pointerX number @ 鼠标/指针X轴坐标
---@param pointerY number @ 鼠标/指针Y轴坐标
---@return TabCloseEventTransition
function TabClose:BlockOutsideExcludeRegions(item, pointerX, pointerY, callback)
    local result = self:DetectPointer(item, pointerX, pointerY, true)

    if result == self.PointerCheckResult.InsidePanel then
        return self.EventTransition.Resume, false
    end

    if callback then
        xpcall(callback, _G.CallBackError)
    end

    if result == self.PointerCheckResult.InsideExcluded then
        return self.EventTransition.Resume, true
    end

    return self.EventTransition.Consumed, false
end

---@private
---@param item TabCloseItem
---@param pointerX number @ 鼠标/指针X轴坐标
---@param pointerY number @ 鼠标/指针Y轴坐标
---@return TabCloseEventTransition
function TabClose:UnblockOutside(item, pointerX, pointerY, callback)
    local result = self:DetectPointer(item, pointerX, pointerY, false)
    if result == self.PointerCheckResult.InsidePanel then
        return self.EventTransition.Resume, false
    end

    if callback then
        xpcall(callback, _G.CallBackError)
    end

    return self.EventTransition.Resume, true
end

---@private
---@param item TabCloseItem
---@param pointerX number @ 鼠标/指针X轴坐标 
---@param pointerY number @ 鼠标/指针Y轴坐标
---@return TabCloseEventTransition
function TabClose:UnblockOutsideExcludeRegions(item, pointerX, pointerY, callback)
    local result = self:DetectPointer(item, pointerX, pointerY, true)
    if result == self.PointerCheckResult.InsidePanel then
        return self.EventTransition.Resume, false
    end

    if callback then
        xpcall(callback, _G.CallBackError)
    end

    if result == self.PointerCheckResult.InsideExcluded then
        return self.EventTransition.Consumed, false
    end

    return self.EventTransition.Resume, true
end

---@private
---@param item TabCloseItem
---@param pointerX number @ 鼠标/指针X轴坐标
---@param pointerY number @ 鼠标/指针Y轴坐标
---@return boolean
function TabClose:Unblock(item, pointerX, pointerY)
    return self.EventTransition.Resume, false
end

---@private
---@return TabCloseItem
function TabClose:ObtainItem()
    local pool = self.poolItems
    local count = #pool
    if count > 0 then
        local item = pool[count]
        table.remove(pool)
        return item
    else
        return {
            panelUID = "",
            component = nil,
            control = nil,
            rectPanel = { n = 0 },
            rectExcluded = { n = 0 },
            policy = self.BlockPolicy.None,
            funcOnClose = nil,
            hasValidRect = false,
        }
    end
end

---@private
---@param item TabCloseItem
function TabClose:ReleaseItem(item)
    item.panelUID = ""
    item.component = nil
    item.control = nil
    item.funcOnClose = nil
    item.hasValidRect = false

    item.rectExcluded.n = 0    
    item.rectPanel.n = 0

    table.insert(self.poolItems, item)
end

---@private
---@param policy Enum.EUIBlockPolicy
---@return fun(pointerX:number, pointerY:number):boolean
function TabClose:GetPolicyFunc(policy)
    local proc = self.procPolicy[policy]
    if proc then
        return proc
    end

    return self.Unblock
end

---@private
---@param owner string|NewUIComponent|UIComponent
---@return number
function TabClose:PushToStack(owner, item)
    table.insert(self.stack, item)
    self.count = self.count + 1
    self.lookup[owner] = item

    return self.count
end

---@param owner string|NewUIComponent|UIComponent
---@param item TabCloseItem
function TabClose:RemoveFromStack(owner, item)
    self.lookup[owner] = nil
    for i, v in ipairs(self.stack) do
        if v == item then
            if item.component then
                Log.Debug("TabClose:RemoveFromStack: ", item.component.uid)
            else
                Log.Debug("TabClose:RemoveFromStack: ", item.panelUID)
            end
            
            table.remove(self.stack, i)
            self.count = self.count - 1
            self:ReleaseItem(item)
            return
        end
    end
end

function TabClose:PopFromStack()
    local item = table.remove(self.stack, self.count)
    self.count = self.count - 1
    local owner = item.component or item.panelUID
    self.lookup[owner] = nil
    self:ReleaseItem(item)
end

---@private
---@param item TabCloseItem
---@param pointerX number
---@param pointerY number
---@return number @ 返回0：表示指针在面板范围内；返回1：表示指针在触发控件范围内；返回-1：表示指针在触发控件范围和面板范围外
function TabClose:DetectPointer(item, pointerX, pointerY, bCheckExcluded)
    local IsInRect = self.IsInRect

    -- 是否在面板内
    -- local rectPanel = item.rectPanel
    -- for i = 1, rectPanel.n do
    --     if IsInRect(pointerX, pointerY, rectPanel[i]) then
    --         return self.PointerCheckResult.InsidePanel
    --     end
    -- end

    if bCheckExcluded then
        -- 点击发生在触发控件范围内，就不透传输入事件
        local rectExcluded = item.rectExcluded
        for i = 1, rectExcluded.n do
            if IsInRect(pointerX, pointerY, rectExcluded[i]) then
                return self.PointerCheckResult.InsideExcluded
            end
        end
    end

    return self.PointerCheckResult.Outside
end

---@param widget Widget
---@param rect {left:number, top:number, right:number, bottom:number}
function TabClose:GetRenderingBoundingRect(widget, rect)
    local left, right, top, bottom = UIFunctionLibrary.GetRenderingBoundingRect(widget)

    rect.left = left or 0
    rect.right = right or 0
    rect.top = top or 0
    rect.bottom = bottom or 0
end

---@private
---@param item TabCloseItem
---@param topUID string
---@return boolean
function TabClose:CanClose(item, topUID)
    -- 如果TopUID为P_ScreenInput，说明已经没有其他界面拦截了
    if topUID == "P_ScreenInput" then
        return true
    end

    local component = item.component
    if component then
        return component.panelUID == topUID or component.uid == topUID
    end

    return item.panelUID == topUID
end

---@private
---@param item TabCloseItem
---@param pointerX number
---@param pointerY number
---@param userIndex number
---@return boolean
function TabClose:InternalPreCheck(item, pointerX, pointerY, userIndex)
    if item.policy == Enum.EUIBlockPolicy.None then
        return false
    end

    -- TODO:limunan
    -- 这里GetTopUI返回的是界面入栈的顺序，可能跟界面的层级顺序不一致， 
    -- 等框架提供了相应接口，这里需要改掉
    local topUI = Game.UIManager:GetInstance():GetTopUI()
    local topUID = topUI.uid
    if not self:CanClose(item, topUID) then
        return false
    end

    local owner = item.component or topUI

    -- 不在视口内
    local left, right, top, bottom = UIFunctionLibrary.GetViewportBounds(_G.GetContextObject())
    self.rectViewport = { left = left, right = right, top = top, bottom = bottom }
    local rectViewport = self.rectViewport
    if self:IsValidRect(rectViewport) then
        if not self.IsInRect(pointerX, pointerY, rectViewport) then
            Log.Debug("TabClose:InternalPreCheck: out of viewport")
            return false
        end
    end

    if owner.UpdateBoundRectWidgets then
        owner:UpdateBoundRectWidgets()
    end

    local bInPanel = false
    local array = owner.widget.PanelRegionWidgets
    if array and array:Num() > 0 then
        bInPanel = owner.widget:IsPointerInPanel(pointerX, pointerY, userIndex)
    else
        bInPanel = UIFunctionLibrary.IsPointerInWidget(owner.widget, pointerX, pointerY, userIndex)
    end

    Log.Debug("TabClose:InternalPreClick: in panel?", bInPanel)
    return not bInPanel
end

return TabClose