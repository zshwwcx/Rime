local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class ComSortBtn : UIComponent
---@field view ComSortBtnBlueprint
local ComSortBtn = DefineClass("ComSortBtn", UIComponent)

ComSortBtn.eventBindMap = {
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function ComSortBtn:OnCreate()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

---@class ComSortBtnParam --- 排序按钮参数
---@field sortStyle boolean
---@field sortKey boolean

---初始化数据
function ComSortBtn:InitUIData()
    ---@type ComSortBtnParam  设置默认值
    self.data = { sortStyle = 0, sortKey = "" }

    ---@type LuaMulticastDelegate<fun(isReverse:boolean,sortKey:string)>
    self.onReverseChange = LuaMulticastDelegate.new()
end

--- UI组件初始化，此处为自动生成
function ComSortBtn:InitUIComponent()
end

---UI事件在这里注册，此处为自动生成
function ComSortBtn:InitUIEvent()
    self:AddUIEvent(self.view.Btn_ClickArea_lua.OnClicked, "on_Btn_ClickArea_lua_Clicked")
end

---初始化UI基础逻辑，这里尽量避免出现和数据相关的业务逻辑调用
function ComSortBtn:InitUIView()
end

---组件刷新统一入口
function ComSortBtn:Refresh()
    --切换样式
    self.userWidget:Event_UI_Style(self.data.sortStyle, -50)
end


--- 此处为自动生成
function ComSortBtn:on_Btn_ClickArea_lua_Clicked()
    --切换样式
    self.data.sortStyle = (self.data.sortStyle + 1) % 3
    self:Refresh()
    self.onReverseChange:Broadcast(self.data.sortStyle, self.data.sortKey)
end

---@param param ComSortBtnParam
function ComSortBtn:SetData(param)
    self.data.sortStyle = param.sortStyle
    self.data.sortKey = param.sortKey
    self:Refresh()
end

return ComSortBtn
