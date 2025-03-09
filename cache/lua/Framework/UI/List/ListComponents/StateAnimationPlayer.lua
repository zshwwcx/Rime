local EUMGSequencePlayMode = import("EUMGSequencePlayMode")
local ESlateVisibility = import("ESlateVisibility")

local StateAnimationPlayer = DefineClass("StateAnimationPlayer")

function StateAnimationPlayer:ctor(list)

    self.list = list
    ---@type table<number,table<string,ListSelectAniInfo>> @自动处理的动画
    self.autoAni = {
        [ListAnimationLibrary.CellState.Select] = {},
        [ListAnimationLibrary.CellState.UnSelect] = {},
        [ListAnimationLibrary.CellState.Idle] = {},
        [ListAnimationLibrary.CellState.In] = {},
        [ListAnimationLibrary.CellState.Out] = {},
        [ListAnimationLibrary.CellState.Other] = {},
    }
    ---@type table<number,table<string,ListSelectAniInfo>> @选中动画数据缓存
    self.autoAniCache = {
        [ListAnimationLibrary.CellState.Select] = {},
        [ListAnimationLibrary.CellState.UnSelect] = {},
        [ListAnimationLibrary.CellState.Idle] = {},
        [ListAnimationLibrary.CellState.In] = {},
        [ListAnimationLibrary.CellState.Out] = {},
        [ListAnimationLibrary.CellState.Other] = {},
    }
    self.playingAni = {}
end

function StateAnimationPlayer:addAutoAniInfo(aniKind, widget, aniName, bLoop, floor, kind)
    
    floor = floor or 1
    kind = kind or 1
    local arr = string.split(widget, ".")
    local selectAniInfo = self.autoAni[aniKind]
    if not selectAniInfo[floor] then
        selectAniInfo[floor] = {}
    end
    if not selectAniInfo[floor][kind] then
        selectAniInfo[floor][kind] = {}
    end
    if selectAniInfo[floor][kind][widget] then
        for i = 1, #selectAniInfo[floor][kind][widget], 1 do
            if selectAniInfo[floor][kind][widget][i] == aniName then
                return
            end
        end
    else
        selectAniInfo[floor][kind][widget] = {}
    end
    -- selectAniInfo[floor][kind][widget] = {
    --     arr = arr,
    --     aniName = aniName
    -- }
    table.insert(selectAniInfo[floor][kind][widget], {aniName = aniName,arr = arr, bLoop = bLoop})
end

function StateAnimationPlayer:removeAutoAniInfo(aniKind, widget, aniName, floor, kind)
    floor = floor or 1
    kind = kind or 1
    local selectAniInfo = self.autoAni[aniKind]
    if not selectAniInfo[floor] then
        return
    end
    if not selectAniInfo[floor][kind] then
        return
    end
    for i = 1, #selectAniInfo[floor][kind][widget], 1 do
        if selectAniInfo[floor][kind][widget][i].aniName == aniName then
            table.remove(selectAniInfo[floor][kind][widget], i)
            return
        end
    end
    -- if selectAniInfo[floor][kind][widget] then
    --     selectAniInfo[floor][kind][widget] = nil
    -- end
end

function StateAnimationPlayer:SetAutoAnimation(AniType, widget, aniName, bLoop, floor, kind)
    self:addAutoAniInfo(AniType, widget, aniName, bLoop, floor, kind)
end

function StateAnimationPlayer:ClearAutoAnimation(AniType, widget, aniName, floor, kind)
    self:removeAutoAniInfo(AniType, widget, aniName, floor, kind)
end

function StateAnimationPlayer:getWidgetByPath(uiComponent, path)
    local widget = uiComponent.View
    for i = 1, #path do
        widget = widget[path[i]]
        if not widget then
            break
        end
    end
    return widget
end

function StateAnimationPlayer:PlayListAnimation(cellDatas, aniData, callback)
    self:playAutoAni(cellDatas, aniData, callback)
end

function StateAnimationPlayer:playAutoAni(index, state, callback)
    local uiComponent = self.list:GetRendererAt(index)
    if not uiComponent then
        return
    end

    local bSelected = false
    if state == ListAnimationLibrary.CellState.Select then
        bSelected = true
    elseif state == ListAnimationLibrary.CellState.UnSelect then
        bSelected = false
    end
    local aniKind = state
    --local aniKind = bSelected and ListAnimationLibrary.CellState.Select or ListAnimationLibrary.CellState.UnSelect
    local stopKind = bSelected and ListAnimationLibrary.CellState.UnSelect or ListAnimationLibrary.CellState.Select
    local stopAni = self.autoAni[stopKind] 
    local stopAniCache = self.autoAniCache[stopKind]
    
    local autoAni = self.autoAni[aniKind]
    local autoAniCache = self.autoAniCache[aniKind]
    local floor = 1
    local kind = 1
    if self.list.getFloorAndKind then
        floor, kind = self.list:getFloorAndKind(index)
    end
    if not autoAni[floor] then
        return
    end
    autoAni = autoAni[floor]
    if not autoAni[kind] then
        return
    end
    autoAni = autoAni[kind]
    local loop 
    --TODO:统一自动状态动画
    if state ~= ListAnimationLibrary.CellState.Select and state ~= ListAnimationLibrary.CellState.UnSelect then
        if not next(autoAni) then
            if callback then
                callback()
            end 
        end
        local bRestoreState = state == ListAnimationLibrary.CellState.Out
        for path, aniInfo in pairs(autoAni) do
            for i = 1, #aniInfo, 1 do
                local widget = self:getWidgetByPath(uiComponent, aniInfo[i].arr)
                if widget then
                    if not autoAniCache[index] then
                        autoAniCache[index] = {}
                    end
                    autoAniCache[index][path] = _now()
                    if aniInfo[i].bLoop then
                        loop = 0
                    else
                        loop = 1
                    end
                    self.playingAni[index] = aniKind
                    UIBase.PlayAnimation(self.list, widget, widget[aniInfo[i].aniName], 0, loop, EUMGSequencePlayMode.Forward, 1, bRestoreState, function()
                        if callback then
                            callback()
                        end 
                        self.playingAni[index] = nil
                    end)
                end
            end
        end
        return
    end
    -------------------------------
    if stopAni[floor] and stopAni[floor][kind] then
        for path, aniInfo in pairs(stopAni[floor][kind]) do
            for i = 1, #aniInfo, 1 do
                local widget = self:getWidgetByPath(uiComponent, aniInfo[i].arr)
                if widget then
                    if aniInfo[i].bLoop then
                        loop = 0
                    else
                        loop = 1
                    end
                    UIBase.StopAnimation(self.list, widget, widget[aniInfo[i].aniName])
                    if stopAniCache[index] and stopAniCache[index][path] then
                        stopAniCache[index][path] = nil
                    end
                end
            end
            
        end
    end
    self:doPlayAutoAni(uiComponent, index, autoAni, autoAniCache)
end

function StateAnimationPlayer:doPlayAutoAni(uiComponent, index, autoAni, autoAniCache)
    local loop = 1
    for path, aniInfo in pairs(autoAni) do
        for i = 1, #aniInfo, 1 do
            local widget = self:getWidgetByPath(uiComponent, aniInfo[i].arr)
            if widget then
                if not autoAniCache[index] then
                    autoAniCache[index] = {}
                end
                autoAniCache[index][path] = _now()
                if aniInfo[i].bLoop then
                    loop = 0
                else
                    loop = 1
                end
                UIBase.PlayAnimation(self.list, widget, widget[aniInfo[i].aniName], 0 , loop, EUMGSequencePlayMode.Forward, 1, false)
            end
        end
    end
end

function StateAnimationPlayer:checkAutoAni(index, bSelected, floor, kind)
    local uiComponent = self.list:GetRendererAt(index)
    if not uiComponent then
        return
    end

    local stopKind = bSelected and ListAnimationLibrary.CellState.UnSelect or ListAnimationLibrary.CellState.Select
    local stopAni = self.autoAni[stopKind] 
    local stopAniCache = self.autoAniCache[stopKind]
    if stopAni[floor] and stopAni[floor][kind] then
        for path, aniInfo in pairs(stopAni[floor][kind]) do
            for i = 1, #aniInfo, 1 do
                local widget = self:getWidgetByPath(uiComponent, aniInfo[i].arr)
                if widget then
                    if not aniInfo[i].bLoop then
                        UIBase.SetWidgetToAnimationStartInstantly(self.list, widget, widget[aniInfo[i].aniName])
                    end
                    UIBase.StopAnimation(self.list, widget, widget[aniInfo[i].aniName])
                    if stopAniCache[index] and stopAniCache[index][path] then
                        stopAniCache[index][path] = nil
                    end
                end
            end
        end
    end

    local aniKind = bSelected and ListAnimationLibrary.CellState.Select or ListAnimationLibrary.CellState.UnSelect
    local autoAni = self.autoAni[aniKind]
    local autoAniCache = self.autoAniCache[aniKind]
    if not autoAni[floor] then
        return
    end
    --临时解决一下状态冲突
    -- if self.playingAni[index] and self.playingAni[index] ~= aniKind then
    --     return
    -- end
    
    autoAni = autoAni[floor]
    if not autoAni[kind] then
        return
    end
    autoAni = autoAni[kind]

    for path, aniInfo in pairs(autoAni) do
        for i = 1, #aniInfo, 1 do
            local widget = self:getWidgetByPath(uiComponent, aniInfo[i].arr)
            if widget then
                if not aniInfo[i].bLoop then
                if not autoAniCache[index] then
                    --TODO 直接播放到最后一帧有问题，临时这样解决
                    
                    UIBase.PlayAnimation(self.list, widget, widget[aniInfo[i].aniName], widget[aniInfo[i].aniName]:GetEndTime(), 1, EUMGSequencePlayMode.Forward, 1, false)
                    -- UIBase.SetWidgetToAnimationEndInstantly(self, widget, widget[aniInfo.aniName])
                    
                else
                    local startTime = autoAniCache[index][path]
                    if startTime then
                        local deltaTime = _now() - startTime
                        local aniLength = widget[aniInfo[i].aniName]:GetEndTime()*1000
                        if deltaTime >= aniLength then
                            UIBase.PlayAnimation(self.list, widget, widget[aniInfo[i].aniName], widget[aniInfo[i].aniName]:GetEndTime(), 1, EUMGSequencePlayMode.Forward, 1, false)
                            -- UIBase.SetWidgetToAnimationEndInstantly(self, widget, widget[aniInfo.aniName])
                        else
                            UIBase.PlayAnimation(self.list, widget, widget[aniInfo[i].aniName], deltaTime/1000)
                        end
                    else
                        UIBase.PlayAnimation(self.list, widget, widget[aniInfo[i].aniName], widget[aniInfo[i].aniName]:GetEndTime(), 1, EUMGSequencePlayMode.Forward, 1, false)
                    end
                end
            end
            end
        end
    end
end

function StateAnimationPlayer:initAutoAniInfo(index, floor, kind)
    local selectAniInfo = self.autoAni[ListAnimationLibrary.CellState.Select]
    if not selectAniInfo[floor] then
        local uiComponent = self.list:GetRendererAt(index)
        if not uiComponent then
            return
        end
        selectAniInfo[floor] = {}
        if not selectAniInfo[floor][kind] then
            local selectAni
            if uiComponent.GetSelectAni then
                selectAni = uiComponent:GetSelectAni()
            end
            if not selectAni then
                selectAniInfo[floor][kind] = {}
                return
            end
            local aniInfo = {}
            for path, aniName in pairs(selectAni) do
                local arr = string.split(path, ".")
                aniInfo[path] = {
                    arr = arr,
                    aniName = aniName
                }
            end
            selectAniInfo[floor][kind] = aniInfo
        end
    end
    local unSelectAniInfo = self.autoAni[ListAnimationLibrary.CellState.UnSelect]
    if not unSelectAniInfo[floor] then
        local uiComponent = self.list:GetRendererAt(index)
        if not uiComponent then
            return
        end
        unSelectAniInfo[floor] = {}
        if not unSelectAniInfo[floor][kind] then
            local unSelectAni
            if uiComponent.GetUnSelectAni then
                unSelectAni = uiComponent:GetUnSelectAni()
            end
            if not unSelectAni then
                unSelectAniInfo[floor][kind] = {}
                return
            end
            local aniInfo = {}
            for path, aniName in pairs(unSelectAni) do
                local arr = string.split(path, ".")
                aniInfo[path] = {
                    arr = arr,
                    aniName = aniName
                }
            end
            unSelectAniInfo[floor][kind] = aniInfo
        end
    end
end

function StateAnimationPlayer:onRefreshItem(index, bSelected)
    local floor = 1
    local kind = 1
    if self.list.getFloorAndKind then
        floor, kind = self.list:getFloorAndKind(index)
    end
    --self:initAutoAniInfo(index, floor, kind)

    self:checkAutoAni(index, bSelected, floor, kind)
    Log.Debug("SelectReFresh")
end

function StateAnimationPlayer:onSetCell(index)

end

return StateAnimationPlayer