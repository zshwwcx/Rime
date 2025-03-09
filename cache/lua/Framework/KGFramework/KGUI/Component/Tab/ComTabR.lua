local BaseListItemComponent = kg_require("Framework.UI.List.NewList.BaseListItemComponent")
---@class ComTabR : BaseListItemComponent
---@field view ComTabRBlueprint
local ComTabR = DefineClass("ComTabR", BaseListItemComponent)

ComTabR.eventBindMap = {
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function ComTabR:OnCreate()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

---初始化数据
function ComTabR:InitUIData()
	self.bIsOn = nil	-- 选中态
	self.idx = nil		-- index
end

--- UI组件初始化，此处为自动生成
function ComTabR:InitUIComponent()
end

---UI事件在这里注册，此处为自动生成
function ComTabR:InitUIEvent()
end

---初始化UI基础逻辑，这里尽量避免出现和数据相关的业务逻辑调用
function ComTabR:InitUIView()
end

---组件刷新统一入口
function ComTabR:Refresh(...)
	self:ResetAnim()
end

function ComTabR:ResetAnim()
	local animTime = self.view.Ani_Off:GetEndTime()
	self:PlayAnimation(self.view.Ani_Off, nil, nil, animTime)
	self.IsOn = false
end



function ComTabR:Refresh(Index, text, selected, tabType)
	--self.userWidget:SetStyle(tabType)
	if text and type(text) == "string" then
		self.view.Text_tab_lua:SetText(text)
	end
	self.Index = Index

	if selected ~= self.IsOn and selected then
		self:AnimOn()
	elseif selected ~= self.IsOn and not selected then
		self:AnimOff()
	elseif selected then
		local animTime = self.view.Ani_On:GetEndTime()
		self:PlayAnimation(self.view.Ani_On, nil, nil, animTime)
	elseif not selected then
		local animTime = self.view.Ani_Off:GetEndTime()
		self:PlayAnimation(self.view.Ani_Off, nil, nil, animTime)
	end
end

function ComTabR:AnimOn()
	self.userWidget:StopAllAnimations()
	self:PlayAnimation(self.view.Ani_On)
	self.IsOn = true
end
function ComTabR:AnimOff()
	self.userWidget:StopAllAnimations()
	self:PlayAnimation(self.view.Ani_Off)
	self.IsOn = false
end

return ComTabR
