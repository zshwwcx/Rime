require("Framework.UI.TestUI.TestIrregularBagItemView")
require("Framework.UI.TestUI.TestIrregularBagItemView")
---@class TestIrregularBagItem : UIController
---@field public View TestIrregularBagItemView
local TestIrregularBagItem = DefineClass("TestIrregularBagItem", ListItemBase)

function TestIrregularBagItem:OnCreate()

end

function TestIrregularBagItem:OnClose()
    UIBase.OnClose(self)
end

function TestIrregularBagItem:OnRefresh(data)
    if self._index == nil then return end

    local c = self.View
    c.num:SetText(self._index)
end

function TestIrregularBagItem:OnSelectionChanged(selected)
    local c = self.View
    UIHelper.SetActive(c.selected, selected)
    local icon = c.selected
    if selected then
        local IconPath = "/Game/Arts/UI_2/Resource/Common_2/Atlas/Sprite01/UI_Com_Bg_PlayBack_Sprite.UI_Com_Bg_PlayBack_Sprite"
        self:SetImage(icon, IconPath)
    else
        local IconPath = "/Game/Arts/UI_2/Resource/Common_2/Atlas/Sprite01/UI_Com_Bg_Write_Sprite.UI_Com_Bg_Write_Sprite"
        self:SetImage(icon, IconPath)
    end
end


function TestIrregularBagItem:OnClick_Btn_ClickArea()
	Log.Debug("Btn_ClickArea clicked self.itemId ", self.index)
end

function TestIrregularBagItem:OnClick_RequestBtn()
	Log.Debug("RequestBtn clicked self.itemId ", self.index)
end

return TestIrregularBagItem
