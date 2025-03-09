local LuaDelegate = kg_require("Framework.KGFramework.KGCore.Delegates.LuaDelegate")
local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class UIButton : NewUIComponent
---@field view UIButtonBlueprint
local UIButton = DefineClass("UIButton", UIComponent)

UIButton.eventBindMap = {
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function UIButton:OnCreate()
    self:InitWidget()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

function UIButton:InitWidget()
    self.img_Icon = self.view.Img_Icon
    self.text_Name = self.view.Text_Name
    self.btn_ClickArea = self.view.Btn_ClickArea
end

---初始化数据
function UIButton:InitUIData()
    ---按钮点击事件
    ---@type LuaDelegate<fun()>AutoBoundWidgetEvent
    self.onClickEvent = LuaDelegate.new()
end

--- UI组件初始化，此处为自动生成
function UIButton:InitUIComponent()
end

---UI事件在这里注册，此处为自动生成
function UIButton:InitUIEvent()
    self:AddUIEvent(self.btn_ClickArea.OnClicked, "OnClickBtn_ClickArea")
end

---初始化UI基础逻辑，这里尽量避免出现和数据相关的业务逻辑调用
function UIButton:InitUIView()
end

---组件刷新统一入口
---@param name string 按钮名称
---@param iconPath string 按钮图标
function UIButton:Refresh(name, iconPath)
    self:SetName(name)
    self:SetIcon(iconPath)
end

function UIButton:SetName(name)
    if self.text_Name and name then
        self.text_Name:SetText(name)
    end
end

function UIButton:SetIcon(iconPath)
    if self.img_Icon and iconPath then
        self:SetImage(self.img_Icon, iconPath)
    end
end

function UIButton:SetTimer(time, timeFormat)
    --self:StartTimer("UIButtonTimer", func)
end

function UIButton:OnClickBtn_ClickArea()
    self.onClickEvent:Execute()
end
return UIButton
