local ESlateVisibility = import("ESlateVisibility")

--require "Gameplay.3C.Character.CharacterHelper" --todo slua适配注释

---注意：和c++里的定义保持完全一致
local EAnimType = { -- luacheck: ignore
    Begin = 0,
    Middle = 1,
    End = 2,
}
-- _enum("EAnimType", EAnimType)


---@class UIHelper:Object
local UIHelper = DefineClass("UIHelper")

--让UWidget可见，但不接受点击事件，子元素不受影响，一般是框架层用到
function UIHelper.SetViewActive(go, active)
    if active then
        go:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    else
        go:SetVisibility(ESlateVisibility.Collapsed)
    end
end

--让UWidget可见，接受点击事件，业务大部分情况都用这个
function UIHelper.SetActive(go, active)
    if active then
        go:SetVisibility(ESlateVisibility.Visible)
    else
        go:SetVisibility(ESlateVisibility.Collapsed)
    end
end

function UIHelper.SetActiveRecursively(active, ...)
    for i = 1, select("#", ...) do
        local go = select(i, ...)
        if active then
            go:SetVisibility(ESlateVisibility.Visible)
        else
            go:SetVisibility(ESlateVisibility.Collapsed)
        end
    end
end

---得到控件屏幕坐标
function UIHelper.GetScreenPosition(c)
    local slot = c.Slot
    local pos = slot:GetPosition()
    local geometry = c:GetCachedGeometry()
    -- local pixelPosition, viewportPosition = FVector2D(), FVector2D()
    local pixelPosition = import("SlateBlueprintLibrary").LocalToViewport(_G.GetContextObject(), geometry, pos, nil, nil)
    local x, y = pixelPosition.X, pixelPosition.Y
    return x, y
end

---屏幕坐标转化为控件局部坐标
function UIHelper.ScreenToWidgetLocal(c, x, y)
    local geometry = c:GetCachedGeometry()
    local LocalCoordinate = import("SlateBlueprintLibrary").ScreenToWidgetLocal(_G.GetContextObject(), geometry, FVector2D(x, y), nil, true)
    return LocalCoordinate
end

---得到模型配置的高度
function UIHelper.GetModelHeight(actor)
    if not actor.ConfigID then
       return 88 + 30
    end
    local RPCEntity = Game.EntityManager:getEntity(actor:GetEntityUID())
    local NpcData
    if RPCEntity then
        NpcData  = RPCEntity:GetEntityConfigData()
    end

    local ModelID = "0"
    if NpcData then
        --- 外观表统一配置 @zhaojunjie
        ModelID = RPCEntity:GetConfigModelID()
    end

    local RoleModeData = GetRoleCompositeData(ModelID)

    local SpecializedOffset = Game.TableData.GetOverHeadInfoSpecializedOffsetDataRow(actor.ConfigID)

    local height
    if SpecializedOffset and SpecializedOffset.Offset then
        height = SpecializedOffset.Offset + 30
    elseif RoleModeData and RoleModeData.Capsule then
        -- height = RoleModeData.Capsule.CapsuleHalfHeight + 30 --世界偏移
        --- 涉及模型缩放后统一半高获取方式 @zhaojunjie
        height = GetCharacterModelFinalCapsuleHalfHeight(NpcData, RoleModeData) --世界偏移
    else
        height = 88 + 30
    end
    return height
end

---模型位置转为控件局部坐标，默认取模型高度
function UIHelper.PlayerToWidgetLocal(player, c)
    local playerController = import("GameplayStatics").GetPlayerController(_G.GetContextObject(), 0)
    local worldPos = player:K2_GetActorLocation()
    local height = UIHelper.GetModelHeight(player)
    worldPos.Z = worldPos.Z + height
    local _, screenPos = import("GameplayStatics").ProjectWorldToScreen(playerController, worldPos, nil, false)
    local geometry = c:GetCachedGeometry()
    local pos = import("SlateBlueprintLibrary").ScreenToWidgetLocal(_G.GetContextObject(), geometry, screenPos, nil, false)
    return pos
end

---模型位置转为控件局部坐标，所有模型中心骨骼名为pelvis，默认为这个
function UIHelper.PlayerBoneToWidgetLocal(player, c, bone)
    local playerController = import("GameplayStatics").GetPlayerController(_G.GetContextObject(), 0)
    local BoneWT = import("BSFunctionLibrary").GetActorSocketTransform(player, bone or "pelvis", 0)
    local worldPos = BoneWT:GetLocation()
    local _, screenPos = import("GameplayStatics").ProjectWorldToScreen(playerController, worldPos, nil, false)
    local geometry = c:GetCachedGeometry()
    local pos = import("SlateBlueprintLibrary").ScreenToWidgetLocal(_G.GetContextObject(), geometry, screenPos, nil, false)
    return pos
end
--[[上面有个重名的
---模型位置+模型高度 转为控件局部坐标
function UIHelper.PlayerToWidgetLocal(player, c)
    local playerController = import("GameplayStatics").GetPlayerController(_G.GetContextObject(), 0)
    local worldPos = player:K2_GetActorLocation()
    local height = UIHelper.GetModelHeight(player)
    local _, screenPos = import("GameplayStatics").ProjectWorldToScreen(playerController, worldPos, nil, false)
    local geometry = c:GetCachedGeometry()
    local pos = import("SlateBlueprintLibrary").ScreenToWidgetLocal(_G.GetContextObject(), geometry, screenPos, nil, false)
    return pos
end
]]

local TraditionalChineseLib = require("Framework.UI.TraditionalChineseLib")

--临时：检查字符串是否为中文
function UIHelper:CheckChinese(Name)
    local Pattern = "[\u{4E00}-\u{9FA5}]"
    if not string.match(Name, "^"..Pattern.."*$") then
        return false
    end
    return true
end

--临时：检查字符是否包含繁体汉字
function UIHelper:CheckTraditionalChinese(Name)
    if not TraditionalChineseLib then
        Game.Logger:DebugWarning("Cannot load string blacklist")
        return false
    end
    for char in Name:gmatch("[\0-\x7F\xC2-\xF4][\x80-\xBF]*") do
        for _, V in utf8.codes(char) do
            if TraditionalChineseLib[V] then
                return true
            end
        end
    end
    return false
end

--临时：检查字符是否为简体中文
function UIHelper:CheckCodeIsTraditionalChinese(Utf8Code)
    if TraditionalChineseLib[Utf8Code] then
        return false
    end
    return true
end

local UserWidget = import("UserWidget")
function UIHelper.GetObjectNum(widget)
    if widget and widget:IsA(UserWidget) then
        return widget.UObjectNum
    else
        return 0
    end
end

--[[
local maxTransition = 5
local uiAnimCallBacks = {}

function UIHelper.GetAllInTransitionComponents(go)
    local anims = {}
    for i = 1, maxTransition do
        local anim = go["InAnim"..i]
        if anim then
            table.insert(anims, anim)
        end
    end
    return anims
end

function UIHelper.GetAllOutTransitionComponents(go)
    local anims = {}
    for i = 1, maxTransition do
        local anim = go["OutAnim"..i]
        if anim then
            table.insert(anims, anim)
        end
    end
    return anims
end

---播放UI动画
---@public
---@param TT TT 协程函数标识
---@param ui UUserWidget 动画所在的界面
---@param animation UWidgetAnimation 动画
---@param reverse boolean 倒序还是顺序播放，倒序为1，顺序为0
---@param onFinish function 播放完回调函数
---@param speed float 播放速度
---@param restoreState bool Restores widgets to their pre-animated state when the animation stops
function UIHelper:PlayAnimation(TT, ui, animation, reverse, onFinish, speed, restoreState)
    ui:PlayAnimation(ui, animation, 0, 1, reverse and 1 or 0, speed or 1, restoreState or false)
    if onFinish then
        while ui:IsAnimationPlaying(animation) do
            YIELD(TT)
        end
        onFinish()
    end
end

function UIHelper.AddAnimCallBack(anim, callBack)
    uiAnimCallBacks[anim] = callBack
end

function UIHelper.DelAnimCallBack(anim)
    uiAnimCallBacks[anim] = nil
end

function UIHelper.AnimCallBack(anim, animType)
    local callBack = uiAnimCallBacks[anim]
    if callBack then
        callBack(animType)
    end
end
]]--

--endregion
