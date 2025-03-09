local ComBtnBackNew = kg_require("Framework.KGFramework.KGUI.Component.Button.ComBtnBackNew")
local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class UIPanelFrame : NewUIComponent
---@field view ComFrameBlueprint
local UIPanelFrame = DefineClass("UIPanelFrame", UIComponent)

UIPanelFrame.eventBindMap = {
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function UIPanelFrame:OnCreate()
    self:InitWidget()
    self:InitUIComponent()
    self:InitUIData()
    self:InitUIEvent()
    self:InitUIView()
end

function UIPanelFrame:InitWidget()
    self.titleButton = self.view.WBP_TitleButton
    self.moneyRoot = self.view.MoneyRoot
end

---初始化数据
function UIPanelFrame:InitUIData()
    if self.titleButtonCom then
        ---预关闭界面事件，可以在里面处理关闭前的逻辑检查，返回ture就会执行关闭false不执行
        ---@type LuaDelegate<fun():bool>
        self.onPreCloseEvent = self.titleButtonCom.onPreCloseEvent

        ---tips 按钮点击事件
        ---@type LuaDelegate<fun()>
        self.onTipClickEvent = self.titleButtonCom.onTipClickEvent
    end
end

function UIPanelFrame:InitUIComponent()
    if self.titleButton then
        ---@type ComBtnBackNew
        self.titleButtonCom = self:CreateComponent(self.titleButton, ComBtnBackNew)
    end
end

---初始化UI基础逻辑，这里尽量避免出现和数据相关的业务逻辑调用
function UIPanelFrame:InitUIView()
    self:InitCurrencyWidget()
end

---组件刷新统一入口
function UIPanelFrame:Refresh(titleName, tipsId)
    self:SetTitleButtonCom(titleName, tipsId)
end

function UIPanelFrame:SetTitleButtonCom(titleName, tipsId)
    if self.titleButtonCom then
        self.titleButtonCom:Refresh(titleName, tipsId)
    end
end

function UIPanelFrame:InitCurrencyWidget()
    local moneyType = Game.NewUIManager:GetUIConfig(self.uid).moneyType
    if moneyType then
        self:OpenComponent(UICellConfig.UICurrentcyWidget, self.moneyRoot, moneyType)
    end
end

function UIPanelFrame:GetTipsBtnGeometry()
    if not self.titleButtonCom then
        return 
    end
    return self.titleButtonCom:GetTipsBtnGeometry()
end
return UIPanelFrame
