local itemConst = kg_require("Shared.ItemConst")
local UIListItem = kg_require("Framework.KGFramework.KGUI.Component.UIListView.UIListItem")
---@class UICurrentcyItem : UIListItem
---@field view UICurrentcyItemBlueprint
local UICurrentcyItem = DefineClass("UICurrentcyItem", UIListItem)

UICurrentcyItem.eventBindMap = {
}

---UI事件在这里注册，此处为自动生成
function UICurrentcyItem:InitUIEvent()
    self:AddUIEvent(self.view.Button_lua.OnClicked, "on_Button_lua_Clicked")
    self:AddUIEvent(self.view.Button_lua.OnHovered, "on_Button_lua_Hovered")
    self:AddUIEvent(self.view.Button_lua.OnUnhovered, "on_Button_lua_Unhovered")
end

---面板打开的时候触发
function UICurrentcyItem:OnRefresh(currencyId)
    local IconPath = Game.UIIconUtils.GetIconByItemId(currencyId)
    self:SetImage(self.view.Icon_lua, IconPath)
    local moneyNum = Game.BagSystem:GetItemCount(currencyId) or 0
    --- 金榜/绑定金榜
    if currencyId == itemConst.ITEM_SPECIAL_MONEY_COIN_BOUND or currencyId == itemConst.ITEM_SPECIAL_MONEY_COIN then
        self.view.Text_Count_lua:SetText(moneyNum)
    else
        --- 游戏币
        self.view.Text_Count_lua:SetText(Game.CurrencyUtils.GetGameMoneyFormat(moneyNum))
    end
end

--- 此处为自动生成
function UICurrentcyItem:on_Button_lua_Clicked()
    Game.CurrencyExchangeSystem:CurrencyItemClickHandler(self.data)
end

--- 此处为自动生成
function UICurrentcyItem:on_Button_lua_Hovered()
    self:PlayAnimation(self.view.Ani_Hover, nil, self.view.userWidget, 0.0, 1, UE.EUMGSequencePlayMode.Forward, 1, false)
end

--- 此处为自动生成
function UICurrentcyItem:on_Button_lua_Unhovered()
    self:PlayAnimation(self.view.Ani_Hover, nil, self.view.userWidget, 0.0, 1, UE.EUMGSequencePlayMode.Reverse, 1, false)
end

return UICurrentcyItem
