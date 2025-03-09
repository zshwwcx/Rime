local LuaDelegate = kg_require("Framework.KGFramework.KGCore.Delegates.LuaDelegate")
local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class UITitleButton : NewUIComponent
---@field view UITitleButtonBlueprint
local UITitleButton = DefineClass("UITitleButton", UIComponent)

--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function UITitleButton:OnCreate()
    self:InitWidget()
    self:InitUIComponent()
    self:InitUIData()
    self:InitUIEvent()
    self:InitUIView()
end

---初始化数据
function UITitleButton:InitUIData()
    ---预关闭界面事件，可以在里面处理关闭前的逻辑检查，返回ture就会执行关闭false不执行
    ---@type LuaDelegate<fun():bool>
    self.onPreCloseEvent = LuaDelegate.new()

    ---tips 按钮点击事件
    ---@type LuaDelegate<fun()>
    self.onTipClickEvent = LuaDelegate.new()
end

function UITitleButton:InitWidget()
    self.btn_Close = self.view.Btn_Close
    self.btn_Tips = self.view.Btn_Tips
    self.text_Name = self.view.Text_Name
end

---UI事件在这里注册，此处为自动生成
function UITitleButton:InitUIEvent()
    if self.btn_Close then
        self:AddUIEvent(self.btn_Close.OnClicked, "OnClickBtn_Close")
    end
    if self.btn_Tips then
        self:AddUIEvent(self.btn_Tips.OnClicked, "OnClickBtn_Tips")
    end
end

---组件刷新统一入口
---@param name string 必选
---@param tipsId number 可选
function UITitleButton:Refresh(name, tipsId)
    self.tipsId = tipsId
    self.text_Name:SetText(name)
    self:RefreshTipsBtnVisible()
end

function UITitleButton:RefreshTipsBtnVisible()
    local visible = self.tipsId ~= nil
    if self.btn_Tips then
        local visibleType = visible and UE.ESlateVisibility.Visible or UE.ESlateVisibility.Collapsed
        self.btn_Tips:SetVisibility(visibleType)
    end
end

function UITitleButton:OnClickBtn_Tips()
    if self.onTipClickEvent:IsBind() then
        self.onTipClickEvent:Execute()
    else
        Game.TipsSystem:ShowTipsExtra(self.tipsId, self.btn_Tips:GetCachedGeometry())
    end
end

function UITitleButton:OnClickBtn_Close()
    if self.onPreCloseEvent:IsBind() then
        if self.onPreCloseEvent:Execute() then
            Game.NewUIManager:ClosePanel(self.uid)
        end
    else
        Game.NewUIManager:ClosePanel(self.uid)
    end
end

function UITitleButton:GetTipsBtnGeometry()
    if not self.btn_Tips then
        return 
    end
    return self.btn_Tips:GetCachedGeometry()
end
return UITitleButton
