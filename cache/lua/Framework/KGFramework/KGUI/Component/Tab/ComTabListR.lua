local ComTabR = kg_require("Framework.KGFramework.KGUI.Component.Tab.ComTabR")
local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class ComTabListR : UIComponent
---@field view ComTabListRBlueprint
local ComTabListR = DefineClass("ComTabListR", UIComponent)

local NewComList = kg_require("Framework.UI.List.NewList.NewComList")

ComTabListR.eventBindMap = {
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function ComTabListR:OnCreate()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

---初始化数据
function ComTabListR:InitUIData()
	---@type number 当前选中序号
	self.SelectIndex = 0
	---@type table tab数据
	self.tabData = nil
	---@type number 样式
	self.tabType = 1
	
	--选中回调方法名
	---@type LuaMulticastDelegate<fun()>
	self.OnSelectCb = LuaMulticastDelegate.new()
	--红点方法
	---@type LuaMulticastDelegate<fun()>
	self.OnRedPointCb = LuaMulticastDelegate.new()
end

--- UI组件初始化，此处为自动生成
function ComTabListR:InitUIComponent()
	self.tabListView = self:CreateComponent(self.view.ComList_lua, NewComList, ComTabR)
end

---UI事件在这里注册，此处为自动生成
function ComTabListR:InitUIEvent()
end

---初始化UI基础逻辑，这里尽量避免出现和数据相关的业务逻辑调用
function ComTabListR:InitUIView()
end

---组件刷新统一入口
function ComTabListR:Refresh(...)
end

function ComTabListR:dtor()
	self.OnSelectCb = nil
	self.OnRedPointCb = nil
end

---初始化数据
---@param tabData table<number,table> tab数据,必选项。 table包含key：Text、SubTitle
---@param selectIndex nil|number 当前选中 默认为1
function ComTabListR:SetData(tabData,selectIndex, tabType)
	self.SelectIndex = 0
	local tabLength = tabData and #tabData or 0

	if selectIndex and selectIndex > tabLength then
		Log.Error("selectIndex error")
		return
	end
	self.tabType = tabType or 1
	self.tabData = tabData
	self.tabListView:SetData(#self.tabData)

	self:OnSelectIndex(selectIndex or 1)
end

---获取当前选中tab的Index
function ComTabListR:GetSelectedIndex()
	return self.SelectIndex
end

---设置当前选中
---@param index number
function ComTabListR:Sel(index)
	self:OnSelectIndex(index)
end

---ComList Scroll封装
---@param index number
function ComTabListR:ScrollToIndex(index)
	self.tabListView:ScrollToIndex(index)
end
-------------------------------------------------------
--------------------------------------------------- private ------------------------------------------------------
function ComTabListR:OnRefresh_ComList_lua(widget, index, bSelect)
	widget:Refresh(index, self.tabData[index].Text, bSelect, self.tabType)
	self.OnRedPointCb:Broadcast(widget, index)
end
function ComTabListR:OnClick_ComList_lua(widget, index, selected)
	self:OnSelectIndex(index)
end

function ComTabListR:OnSelectIndex(index)
	self:SelectIndexView(index)
	self.OnSelectCb:Broadcast(index)
end

function ComTabListR:SelectIndexView(index)
	if self.SelectIndex == index or index > #self.tabData then
		return
	end
	self.tabListView:Sel(index)
	self.SelectIndex = index
end

return ComTabListR
