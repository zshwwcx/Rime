local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class ComMaskBgAdaptive : UIComponent
---@field view ComMaskBgAdaptiveBlueprint
local ComMaskBgAdaptive = DefineClass("ComMaskBgAdaptive", UIComponent)

ComMaskBgAdaptive.eventBindMap = {
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function ComMaskBgAdaptive:OnCreate()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

---初始化数据
function ComMaskBgAdaptive:InitUIData()
    self.sizeX = 0
    self.sizeY = 0
end

--- UI组件初始化，此处为自动生成
function ComMaskBgAdaptive:InitUIComponent()
end

---UI事件在这里注册，此处为自动生成
function ComMaskBgAdaptive:InitUIEvent()
    self:AddUIEvent(self.view.NS_Content_lua.OnPrepassDone, "OnPostPrepass")
end

---初始化UI基础逻辑，这里尽量避免出现和数据相关的业务逻辑调用
function ComMaskBgAdaptive:InitUIView()
end

---组件刷新统一入口
function ComMaskBgAdaptive:Refresh(...)
    self.userWidget:OnUpdateBgSize()
end

function ComMaskBgAdaptive:OnClose()

end

function ComMaskBgAdaptive:OnPostPrepass(sizeX, sizeY)
    local lastSizeX = self.sizeX
    local lastSizeY = self.sizeY
    local abs = math.abs
    if abs(sizeX - lastSizeX) > 1 or abs(sizeY - lastSizeY) > 1 then
        self.userWidget:OnUpdateBgSize()
        self.sizeX = sizeX
        self.sizeY = sizeY
        Log.Debug("ComMaskBgAdaptive:OnPostPrepass newsize = ", sizeX, sizeY)
    end
end

return ComMaskBgAdaptive
