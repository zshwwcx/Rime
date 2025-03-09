local INewTreeListComponent = kg_require("Framework.UI.List.NewList.INewTreeListComponent")
---@class ComTabFoldParentNew : UIComponent
---@field view ComTabFoldParentNewBlueprint
local ComTabFoldParentNew = DefineClass("ComTabFoldParentNew", INewTreeListComponent)

ComTabFoldParentNew.eventBindMap = {
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function ComTabFoldParentNew:OnCreate()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

---初始化数据
function ComTabFoldParentNew:InitUIData()
end

--- UI组件初始化，此处为自动生成
function ComTabFoldParentNew:InitUIComponent()
end

---UI事件在这里注册，此处为自动生成
function ComTabFoldParentNew:InitUIEvent()
end

---初始化UI基础逻辑，这里尽量避免出现和数据相关的业务逻辑调用
function ComTabFoldParentNew:InitUIView()
end

---组件刷新统一入口
function ComTabFoldParentNew:Refresh(...)
end

---@param bSelect bool 如果有子页签,是bFold
function ComTabFoldParentNew:OnListRefresh(parentUI, bSelect, allData, index)
	local tabInfo = allData[index]
	self.view.Text_Name_lua:SetText(tabInfo.Name or "")
	-- 如果有子页签
	if tabInfo.Children and next(tabInfo.Children) ~= nil then
		self.userWidget:SetArrow(true)
		self.userWidget:SetSelected(not bSelect)
	else
		self.userWidget:SetSelected(bSelect)
		self.userWidget:SetArrow(false)
	end
	
	if tabInfo and tabInfo.SubName then
		self.userWidget:SetSub(true)
		self.view.Text_Sub_lua:SetText(tabInfo.SubName)
		self.userWidget:SetLimited(tabInfo.bLimited and tabInfo.bLimited or false)
	else
		self.userWidget:SetSub(false)
	end
end

function ComTabFoldParentNew:OnClick(parentUI, allData, index)
	local bFold = self:GetParent():IsFold(index)
	self:GetParent():Fold(not bFold, index)
	---如果有子页签的话
	if allData[index].Children and next(allData[index].Children) then
		if bFold then
			self:GetParent():Sel(index, 1)
			self:GetParent().owner:OnClick(index, 1)
		end
	else
		self:GetParent().owner:OnClick(index)
	end
end


return ComTabFoldParentNew
