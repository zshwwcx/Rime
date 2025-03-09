local UITreeItem = kg_require("Framework.KGFramework.KGUI.Component.UITreeView.UITreeItem")
---@class UIAccordionListTab : UIComponent
---@field view UITabBlueprint
local UIAccordionListTab = DefineClass("UIAccordionListTab", UITreeItem)

--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function UIAccordionListTab:OnCreate()
    self:InitWidget()
    self:InitUIComponent()
    self:InitUIData()
    self:InitUIEvent()
    self:InitUIView()
end

function UIAccordionListTab:InitWidget()
    self.text_Name = self.view.Text_Name
    self.text_ExtraDesc = self.view.Text_ExtraDesc
    self.img_Icon = self.view.Img_Icon
    self.img_Bkg = self.view.Img_Bkg
end

--- UI组件初始化，此处为自动生成
---@param data UITreeViewChildData
function UIAccordionListTab:OnRefresh(data, otherInfo)
    local tabData = data.tabData
    self:SetName(tabData.name)
    self:SetIcon(tabData.iconPath)
    self:SetBkg(tabData.bkgPath)
    self:SetExtraDesc(tabData.extraDesc)
    self:SetRedPoint(tabData.redPointId, tabData.redPointSuff)
end

function UIAccordionListTab:SetRedPoint(redPointId, redPointSuff)
    if redPointId then
        Game.RedPointSystem:RegisterRedPoint(self:GetBelongPanel(), self.userWidget,redPointId, redPointSuff)
    end
end

function UIAccordionListTab:SetName(name)
    if self.text_Name then
        self.text_Name:SetText(name or "")
    end
end

function UIAccordionListTab:SetExtraDesc(desc)
    if self.text_ExtraDesc then
        self.text_ExtraDesc:SetText(desc or "")
    end
end

function UIAccordionListTab:SetIcon(iconPath)
    if self.img_Icon and iconPath then
        self:SetImage(self.img_Icon, iconPath)
    end
end

function UIAccordionListTab:SetBkg(bkgPath)
    if self.img_Icon and bkgPath then
        self:SetImage(self.img_Bkg, bkgPath)
    end
end

---@public
---更新展开的业务表现
---@param expanded bool
function UIAccordionListTab:UpdateExpansionState(expanded)
    if self.userWidget.SetArrow then
        self.userWidget:SetArrow(true)
    end
    self.userWidget:SetCollapse(expanded)
    self.userWidget:SetSelected(expanded)
end

---更新选择的业务表现
---@field selected bool
function UIAccordionListTab:UpdateSelectionState(selected)
    if self.userWidget.SetArrow then
        self.userWidget:SetArrow(false)
    end
    self.userWidget:SetSelected(selected)
end
return UIAccordionListTab
