local UISimpleList = kg_require("Framework.KGFramework.KGUI.Component.UIListView.UISimpleList")
local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class UICurrentcyWidget : UIComponent
---@field view UICurrentcyWidgetBlueprint
local UICurrentcyWidget = DefineClass("UICurrentcyWidget", UIComponent)

UICurrentcyWidget.eventBindMap = {
    [_G.EEventTypes.UPDATE_CURRENCY_LIST_PANEL] = "UpdateCurrencyData",
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function UICurrentcyWidget:OnCreate()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

---初始化数据
function UICurrentcyWidget:InitUIData()
end

--- UI组件初始化，此处为自动生成
function UICurrentcyWidget:InitUIComponent()
    ---@type UISimpleList
    self.Currency_luaCom = self:CreateComponent(self.view.Currency_lua, UISimpleList)
end

---UI事件在这里注册，此处为自动生成
function UICurrentcyWidget:InitUIEvent()
end

---初始化UI基础逻辑，这里尽量避免出现和数据相关的业务逻辑调用
function UICurrentcyWidget:InitUIView()
end

---组件刷新统一入口
function UICurrentcyWidget:Refresh(moneyTypes)
    self.moneyTypes = moneyTypes
    self.Currency_luaCom:Refresh(moneyTypes)
end

function UICurrentcyWidget:UpdateCurrencyData()
    if self.Currency_luaCom then
        self.Currency_luaCom:Refresh(self.moneyTypes)
    end
end
return UICurrentcyWidget
