require("Framework.UI.TestUI.TestRankItemView")
---@class TestRankItem : UIComponent
---@field public View TestRankItemView
local TestRankItem = DefineClass("TestRankItem", UIComponent, ITreeListComponent)

function TestRankItem:OnCreate()
    self:AddUIListener(EUIEventTypes.CLICK, self.View.GoBtn, self.OnClick_GoBtn)
    self.itemId = nil --ID
end

function TestRankItem:OnListRefresh(parentUI, bSelect, allData, index)
    self.index = index
    self:Refresh(index, bSelect)
end

function TestRankItem:OnRefresh(itemId, selected) -- luacheck: ignore
    self:Refresh(itemId, selected)
end

function TestRankItem:Refresh(itemId, selected)
    if itemId == nil then return end
    self.itemId = itemId
    local c = self.View

    local icon = c.icon
    if selected then
        local IconPath = "/Game/Arts/UI_2/Resource/Common_2/Atlas/Sprite01/UI_Com_Bg_PlayBack_Sprite.UI_Com_Bg_PlayBack_Sprite"
        self:SetImage(icon, IconPath)
    else
        local IconPath = "/Game/Arts/UI_2/Resource/Common_2/Atlas/Sprite01/UI_Com_Bg_Write_Sprite.UI_Com_Bg_Write_Sprite"
        self:SetImage(icon, IconPath)
    end
    c.num:SetText(itemId)
end


function TestRankItem:OnClick_Btn_ClickArea()

end
function TestRankItem:OnClick_GoBtn()
    local index = self.index
    if self.parent:IsFold(index) then
        self.parent:Fold(false, index)
    else
        self.parent:Fold(true, index)
    end

end

return TestRankItem
