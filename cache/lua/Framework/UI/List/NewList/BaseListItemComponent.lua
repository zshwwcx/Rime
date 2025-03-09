local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")

---@class BaseListItemComponent : UIComponent
local BaseListItemComponent = DefineClass("BaseListItemComponent", UIComponent)

function BaseListItemComponent:OnItemRefresh(index)
    self.index = index
end

function BaseListItemComponent:OnItemClick()
    local list = self:GetParent()
    if list then
        local func = list.HandleItemClicked 
        if func then
            func(list, self, false)
        end
    end
end

function BaseListItemComponent:OnItemRightClick()
    local list = self:GetParent()
    if list then
        local func = list.HandleItemClicked 
        if func then
            func(list,self, true)
        end
    end
end

function BaseListItemComponent:OnItemPressed()
    local list = self:GetParent()
    if list then
        local func = list.OnItemPressed 
        if func then
            func(list, self.index)
        end
    end
end

function BaseListItemComponent:OnItemReleased()
    local list = self:GetParent()
    if list then
        local func = list.OnItemReleased 
        if func then
            func(list, self.index)
        end
    end
end


return BaseListItemComponent