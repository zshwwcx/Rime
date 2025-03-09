local UITitleButton = kg_require("Framework.KGFramework.KGUI.Component.Button.UITitleButton")
---@class ComBtnBackNew : NewUIComponent
---@field view ComBtnBackNewBlueprint
local ComBtnBackNew = DefineClass("ComBtnBackNew", UITitleButton)

function ComBtnBackNew:InitWidget()
    self.btn_Close = self.view.Btn_Back_Lua
    self.btn_Tips = self.view.Btn_Info_lua
    self.text_Name = self.view.Text_Back_lua
end

return ComBtnBackNew
