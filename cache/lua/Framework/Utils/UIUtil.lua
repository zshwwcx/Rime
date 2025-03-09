local SlateBlueprintLibrary = import("SlateBlueprintLibrary")

-- 设置面板相对某个控件位置自适应
---@param relatedWidget userdata 相对的控件
---@param smartPositioningWidget userdata KGSmartPositionArea控件
function AdaptRelatedUIPos(relatedWidget, smartPositioningWidget, offsetX, offsetY)
    offsetX = offsetX or 0     
    offsetY = offsetY or 0
    local cachedGeometry = relatedWidget:GetCachedGeometry()
    local localSize = SlateBlueprintLibrary.GetLocalSize(cachedGeometry)
    if localSize.X == 0 and localSize.Y == 0 then
        Log.Error(">>>AdaptRelatedUIPos param error, the size of relatedWidget is (0, 0)")
        return
    end
    local _, viewportPosition = SlateBlueprintLibrary.LocalToViewport(
        _G.GetContextObject(), cachedGeometry, localSize, nil, nil
    )
    smartPositioningWidget.Slot:SetSize(localSize)
    smartPositioningWidget.Slot:SetPosition(FVector2D(viewportPosition.X - localSize.X + offsetX, viewportPosition.Y - localSize.Y + offsetY))
end