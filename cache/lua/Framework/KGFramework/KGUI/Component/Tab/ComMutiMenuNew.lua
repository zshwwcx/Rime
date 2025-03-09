local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class ComMutiMenuNew : UIComponent
---@field view ComMutiMenuNewBlueprint
local ComMutiMenuNew = DefineClass("ComMutiMenuNew", UIComponent)
local NewTreeList = kg_require("Framework.UI.List.NewList.NewTreeList")
local ComTabFoldParentNew = kg_require("Framework.KGFramework.KGUI.Component.Tab.ComTabFoldParentNew")
local ComTabFoldSubNew = kg_require("Framework.KGFramework.KGUI.Component.Tab.ComTabFoldSubNew")

ComMutiMenuNew.eventBindMap = {
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function ComMutiMenuNew:OnCreate()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

---初始化数据
function ComMutiMenuNew:InitUIData()
end

--- UI组件初始化，此处为自动生成
function ComMutiMenuNew:InitUIComponent()
	self.tabTreeList = self:CreateComponent(self.view.TabList_lua,NewTreeList, {{ComTabFoldParentNew},{ComTabFoldSubNew}})
end

---UI事件在这里注册，此处为自动生成
function ComMutiMenuNew:InitUIEvent()
end

---初始化UI基础逻辑，这里尽量避免出现和数据相关的业务逻辑调用
function ComMutiMenuNew:InitUIView()
end

---组件刷新统一入口
function ComMutiMenuNew:Refresh(...)
end

---@param data table treelist页签的构造数据 
---@param callback func 点击页签的回调函数
function ComMutiMenuNew:RefreshItem(data, callback)
	self.params = data
	self.callback = callback
	self.tabTreeList:SetData(data)
	self:SelTab(1)
end

--- 设置选中态
---@param index1 int 一级页签index
---@param index2 int 二级页签index
function ComMutiMenuNew:SelTab(index1, index2)
	if not index1 and not index2 then return end
	if self.params[index1].Children and next(self.params[index1].Children) ~= nil then
		self.tabTreeList:Fold(false, index1)
		if index2 then
			self.tabTreeList:Sel(index1, index2)
		else
			self.tabTreeList:Sel(index1, 1)
		end
	else
		self.tabTreeList:Sel(index1)
	end
	self:OnClick(index1, index2)
end

function ComMutiMenuNew:OnClick(index1, index2)
	if self.callback then
		self.callback(index1, index2)
	end
end

function ComMutiMenuNew:GetSelectedIndex()
	return self.tabTreeList:GetSelectedIndex()
end

return ComMutiMenuNew
