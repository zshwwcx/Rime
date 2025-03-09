local UIButton = kg_require("Framework.KGFramework.KGUI.Component.Button.UIButton")
---@class UITempComBtn : NewUIComponent
---@field view UITempComBtnBlueprint
local UITempComBtn = DefineClass("UITempComBtn", UIButton)

function UITempComBtn:InitWidget()
    self.img_Icon = self.view.Image_lua or self.view.Icon_lua
    self.text_Name = self.view.Text_Com_lua or self.view.TextName_lua
    self.btn_ClickArea = self.view.Btn_Com_lua or self.view.Button_lua
end

return UITempComBtn
