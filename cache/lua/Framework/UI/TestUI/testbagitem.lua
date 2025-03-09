require("Framework.UI.TestUI.testbagitemView")
---@class testbagitem : UIComponent
--- @field public View BagItemView
local TestBagItem = DefineClass("TestBagItem", UIComponent)

function TestBagItem:OnCreate() -- luacheck: ignore
    self.itemId = nil
end

function TestBagItem:OnRefresh(itemId, selected) -- luacheck: ignore
    self:Refresh(itemId, selected)
end

function TestBagItem:Refresh(itemId, selected)
    if itemId == nil then return end
    self.itemId = itemId
    local c = self.View
    UIHelper.SetActive(c.selected, selected)
    c.num:SetText(itemId)

    local icon = c.selected
    if selected then
        local IconPath = "/Game/Arts/UI_2/Resource/Common_2/Atlas/Sprite01/UI_Com_Bg_PlayBack_Sprite.UI_Com_Bg_PlayBack_Sprite"
        self:SetImage(icon, IconPath)
    else
        local IconPath = "/Game/Arts/UI_2/Resource/Common_2/Atlas/Sprite01/UI_Com_Bg_Write_Sprite.UI_Com_Bg_Write_Sprite"
        self:SetImage(icon, IconPath)
    end
end

function TestBagItem:OnClick_RequestBtn()
	Log.Debug("RequestBtn clicked self.itemId ", self.itemId)

end

function TestBagItem:OnClick_Big_Button_ClickArea()
	Log.Debug("Big_Button_ClickArea clicked self.itemId ", self.itemId)
end

return TestBagItem
