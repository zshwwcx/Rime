local UIListItem = kg_require("Framework.KGFramework.KGUI.Component.UIListView.UIListItem")
---@class UITabListItem : UIComponent
---@field view ComTabBlueprint
local UITabListItem = DefineClass("UITabListItem", UIListItem)

--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function UITabListItem:OnCreate()
    self:InitWidget()
    self:InitUIComponent()
    self:InitUIData()
    self:InitUIEvent()
    self:InitUIView()
end

function UITabListItem:InitWidget()
    self.text_Name = self.view.Text_Name
    self.text_ExtraDesc = self.view.Text_ExtraDesc
    self.img_Icon = self.view.Img_Icon
    self.img_Bkg = self.view.Img_Bkg
end

--- UI组件初始化，此处为自动生成
---@param data UITabData
function UITabListItem:OnRefresh(data, otherInfo)
    self:SetName(data.name)
    self:SetIcon(data.iconPath)
    self:SetBkg(data.bkgPath)
    self:SetExtraDesc(data.extraDesc)
    self:SetRedPoint(data.redPointId, data.redPointSuff)
end

function UITabListItem:SetRedPoint(redPointId, redPointSuff)
    if redPointId then
        Game.RedPointSystem:RegisterRedPoint(self:GetBelongPanel(),redPointId, redPointSuff)
    end
end

function UITabListItem:SetName(name)
    if self.text_Name then
        self.text_Name:SetText(name or "")
    end
end

function UITabListItem:SetExtraDesc(desc)
    if self.text_ExtraDesc then
        self.text_ExtraDesc:SetText(desc or "")
    end
end

function UITabListItem:SetIcon(iconPath)
    if self.img_Icon and string.notNilOrEmpty(iconPath) then
        self:SetImage(self.img_Icon, iconPath)
    end
end

function UITabListItem:SetBkg(bkgPath)
    if self.img_Bkg and string.notNilOrEmpty(bkgPath) then
        self.img_Bkg:SetText(bkgPath)
    end
end
return UITabListItem
