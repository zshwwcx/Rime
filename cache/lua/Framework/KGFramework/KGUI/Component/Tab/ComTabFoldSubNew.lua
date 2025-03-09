local INewTreeListComponent = kg_require("Framework.UI.List.NewList.INewTreeListComponent")
---@class ComTabFoldSubNew : UIComponent
---@field view ComTabFoldSubNewBlueprint
local ComTabFoldSubNew = DefineClass("ComTabFoldSubNew", INewTreeListComponent)

ComTabFoldSubNew.eventBindMap = {
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function ComTabFoldSubNew:OnCreate()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

---初始化数据
function ComTabFoldSubNew:InitUIData()
end

--- UI组件初始化，此处为自动生成
function ComTabFoldSubNew:InitUIComponent()
end

---UI事件在这里注册，此处为自动生成
function ComTabFoldSubNew:InitUIEvent()
end

---初始化UI基础逻辑，这里尽量避免出现和数据相关的业务逻辑调用
function ComTabFoldSubNew:InitUIView()
end

---组件刷新统一入口
function ComTabFoldSubNew:Refresh(...)
end

function ComTabFoldSubNew:OnListRefresh(parentUI, bSelect, allData, index1, index2)
	local tabSecondInfo = allData[index1].Children[index2]
	self.view.Text_Name:SetText(tabSecondInfo and tabSecondInfo.Name or "")
	self.userWidget:SetSelected(bSelect)
	local lineType = 0
	if allData[index1].Children and #allData[index1].Children == index2 then
		lineType = 2
	else
		lineType = 1
	end
	self.userWidget:SetLine(lineType)
end

function ComTabFoldSubNew:OnClick(parentUI, allData, index1, index2)
	self:GetParent().owner:OnClick(index1, index2)
end


return ComTabFoldSubNew
