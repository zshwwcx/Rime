local UIComponent = kg_require("Framework.KGFramework.KGUI.Core.UIComponent")
---@class UIComMask : UIComponent
---@field view UIComMaskBlueprint
local UIComMask = DefineClass("UIComMask", UIComponent)
local ESlateVisibility = import("ESlateVisibility")

UIComMask.eventBindMap = {
}
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function UIComMask:OnCreate()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

---初始化数据
function UIComMask:InitUIData()
end

--- UI组件初始化，此处为自动生成
function UIComMask:InitUIComponent()
end

---UI事件在这里注册，此处为自动生成
function UIComMask:InitUIEvent()
end

---初始化UI基础逻辑，这里尽量避免出现和数据相关的业务逻辑调用
function UIComMask:InitUIView()
    -- TODO: 移动端检查，现在先全部打开试用下，后面考虑只放移动端
    Game.NewUIManager:CaptureSceneForBackGroundBlur(self.view.KGImage_Blur)
    self.view.KGImage_Blur:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    -- 停止场景渲染
    UE.GameplayStatics.SetEnableWorldRendering(_G.GetContextObject(), false)
end

---组件刷新统一入口
function UIComMask:Refresh(...)
end

-- function UIComMask:OnHide()
--     -- 恢复场景渲染
--     UE.GameplayStatics.SetEnableWorldRendering(_G.GetContextObject(), true)
-- end

-- function UIComMask:OnDestroy()
--     -- 恢复场景渲染
--     UE.GameplayStatics.SetEnableWorldRendering(_G.GetContextObject(), true)
-- end

return UIComMask
