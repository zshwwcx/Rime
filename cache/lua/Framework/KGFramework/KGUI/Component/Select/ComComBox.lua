local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class ComComBox : UIComponent
---@field view ComComBoxBlueprint
local ComComBox = DefineClass("ComComBox", UIComponent)
local P_ComboBoxFloat = kg_require("Gameplay.LogicSystem.CommonUI.P_ComboBoxFloat")

--通用下拉框KGUI版

ComComBox.eventBindMap = {
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function ComComBox:OnCreate()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

---初始化数据
function ComComBox:InitUIData()
end

--- UI组件初始化，此处为自动生成
function ComComBox:InitUIComponent()
end

---UI事件在这里注册，此处为自动生成
function ComComBox:InitUIEvent()
    self:AddUIEvent(self.view.Button_lua.OnClicked, "on_Button_lua_Clicked")
end

---初始化UI基础逻辑，这里尽量避免出现和数据相关的业务逻辑调用
function ComComBox:InitUIView()
end

function ComComBox:OnClose()
	if UI.IsShow("P_ComboBoxFloat") then
		UI.HideUI("P_ComboBoxFloat")
	end
end

--- 此处为自动生成
function ComComBox:on_Button_lua_Clicked()
	Game.AkAudioManager:PostEvent2D(Enum.EUIAudioEvent.Play_UI_Common_Expand, true)
	if UI.GetUI("P_ComboBoxFloat") and UI.GetUI("P_ComboBoxFloat"):IsShow() then
		UI.HideUI("P_ComboBoxFloat")
		self:SetArrowState(false)
	else
		P_ComboBoxFloat.ComboBox = self--.view.KImg_CustomBG_lua
		UI.ShowUI("P_ComboBoxFloat", --[[self,]] self.optionsData, self.currentSelectIndex)
		self:SetArrowState(true)
	end
end

function ComComBox:InitComboBox(Owner, SelectOptionCallBack, Options, CurrentSelectIndex, parentWidget)
	self.currentSelectIndex = CurrentSelectIndex
	self.visibleWidget = parentWidget
	self.owner = Owner
	self.selectOptionCallBack = SelectOptionCallBack
	if Options then
		self:SetComboBoxData(Options, CurrentSelectIndex)
	end
end

--Options 选项内容
--当前选中的Index，不传默认选中第1个，传-1不选中任何条目
--notifyEvent，选中条目时是否执行回调,传nil 默认通知
--SetData(Options)  --设置选项，选中第1个，执行回调
--SetData(Options, 1, false) --设置选项，选中第1个，不执行回调
function ComComBox:SetComboBoxData(Options, SelectIndex, notifyEvent)
	self.currentSelectIndex = SelectIndex
	self.optionsData = Options
	self:CreateOptions(self.optionsData)
	if SelectIndex ~= -1 then
		SelectIndex = SelectIndex or 1
		if SelectIndex <= #Options then
			self:SelectIndex(SelectIndex, notifyEvent)
			self:UpdateTitle()
		end
	end
end

function ComComBox:CreateOptions(Options)
	self:SetArrowState(false)
	if UI.IsShow("P_ComboBoxFloat") then
		UI.Invoke("P_ComboBoxFloat", "createOptions", Options)
	end
end

function ComComBox:SetArrowState(bOpen)
	if not bOpen then
		self.view.Img_Arrow_lua:SetRenderTransformAngle(0)
	else
		self.view.Img_Arrow_lua:SetRenderTransformAngle(180)
	end
end

function ComComBox:SelectIndex(index, notifyEvent)
	if index == self.currentSelectIndex then
		--选中相同条目，不处理
		return
	end
	self.currentSelectIndex = index
	self:UpdateTitle()
	if notifyEvent ~= false then
		self.selectOptionCallBack(self.owner, index)
	end
end

function ComComBox:GetSelectedIndex()
	return self.currentSelectIndex
end

function ComComBox:UpdateTitle()
	local OptionData = self.optionsData[self.currentSelectIndex]
	if OptionData.IsDefaultSize == true then
		self.view.Text_Target_lua.font.size = 20
	elseif OptionData.IsDefaultSize == false then
		self.view.Text_Target_lua.font.size = 16
	end
	self.view.Text_Target_lua:SetFont(self.view.Text_Target_lua.font)
	--self.View.WidgetRoot:SetTitle(self:nameFormat(OptionData.text))
	self.view.Text_Target_lua:SetText(OptionData.text)
end

return ComComBox
