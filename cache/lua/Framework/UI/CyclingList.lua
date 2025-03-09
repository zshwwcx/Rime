
---@class P_CyclingList
---@field private _s C7CyclingList
local P_CyclingList = DefineClass("P_CyclingList", BaseList)


function P_CyclingList.CreateCyclingList(widget, Owner, Name, Component)
    local newCyclingList = Owner:BindComponent(widget, P_CyclingList)
    newCyclingList:Init(Owner, Name, Component)
    return newCyclingList
end

function P_CyclingList:Init(Owner, Name, Component)
    self.Name = Name
    self.component = Component
    self.uiComponents = {}
    local CallbackName = "OnRefresh_" .. self:GetViewRoot():GetName()
    if string.endsWith(CallbackName, "_lua") then
        CallbackName = string.sub(CallbackName, 1, -5)
    end
    self.OnRefresh_Callback = Owner[CallbackName]
   -- if Component then
    self:GetViewRoot().BP_OnListItemRefresh:Add(
        function(Item, Widget, Index, bSelected)
            if self.OnRefresh_Callback then
                self.OnRefresh_Callback(self.parent, self.uiComponents[Widget], Index + 1, bSelected)
            end
        end
    )
    local OnFocusCallback = "OnFocus_" .. self:GetViewRoot():GetName()
    if string.endsWith(OnFocusCallback, "_lua") then
        OnFocusCallback = string.sub(OnFocusCallback, 1, -5)
    end
    self.OnFocus_Callback = Owner[OnFocusCallback]
    self:GetViewRoot().BP_OnListItemFocus:Add(
        function(Item, Widget, Index, bFocus)
            if self.OnFocus_Callback then
               -- Log.DebugFormat("@bylizhemian OnFocus:%s, %s", Index, bFocus)
                self.OnFocus_Callback(self.parent, self.uiComponents[Widget], Index + 1, bFocus)
            end
        end
    )
    self:GetViewRoot().BP_OnListItemInitialized:Add(
        function(Item, Widget, Index, bFocus)
            self:OnEntryInitialized(Item, Widget, Index + 1, bFocus)
        end
    )
  --  end
end

function P_CyclingList:OnCreate()

end

function P_CyclingList:OnEntryInitialized(Item, Widget, Index, bFocus)
    local component = self:getComponent(Widget)
    component:Show()
    component:Open()
    if self.OnRefresh_Callback then
        self.OnRefresh_Callback(self.parent, component, Index, bFocus)
    end
    if self.OnFocus_Callback and bFocus then
        self.OnFocus_Callback(self.parent, component, Index, bFocus)
    end
end

function P_CyclingList:SetData(Num, selectedIndex)
    self:GetViewRoot():SetDataNum(Num, selectedIndex and (selectedIndex - 1) or -1)
end

function P_CyclingList:getComponent(Widget)
    local uiComponent = self.uiComponents[Widget]
    if uiComponent then
        return uiComponent
    end
    uiComponent = self:BindListComponent(self.Name, Widget, self.component, self.GetComponentIndex, self)
    ---@todo Add UIListener For Component
    self.uiComponents[Widget] = uiComponent
    ---@todo Add Btn UIListener
    return uiComponent

end

function P_CyclingList:GetComponentIndex(Component)
    return self.componentIndexs[Component]
end

function P_CyclingList:OnDestroy()
    self:GetViewRoot().BP_OnListItemFocus:Clear()
    self:GetViewRoot().BP_OnListItemInitialized:Clear()
    self:GetViewRoot().BP_OnListItemRefresh:Clear()
    for widget, component in pairs(self.uiComponents) do
        self:UnbindListComponent(widget)
    end
    self.uiComponents = nil
    UIBase.OnDestroy(self)
end

return P_CyclingList