---@class ListItemBase : UIComponent
---@field protected _s UUserWidget
---@field protected parent IrregularListView
local ListItemBase = DefineClass("ListItemBase", UIComponent)

function ListItemBase:ctor()
    self._index = -1
end

---@param Item UListObject
function ListItemBase:SetItem(Item)
    self.Item = Item
end

---@public
---@param itemData table | number
function ListItemBase:Refresh(itemData)
    self:OnRefresh(itemData)
end

---@protected
---@param index integer | nil
function ListItemBase:SetIndex(index)
    self._index = index
end

---@protected
---@return integer
function ListItemBase:GetIndex()
    return self._index
end

---@protected
---@param data table | number
function ListItemBase:OnRefresh(data)
    assert(false, "not implemented error!")
end

---@protected
---@param selected boolean
function ListItemBase:OnSelectionChanged(selected)
    assert(false, "not implemented error!")
end

return ListItemBase