local EUMGSequencePlayMode = import("EUMGSequencePlayMode")
local ESlateVisibility = import("ESlateVisibility")
local IListAnimationPlayer = kg_require("Framework.UI.List.ListComponents.IListAnimationPlayer")
local MoveAnimationPlayer = DefineClass("MoveAnimationPlayer",IListAnimationPlayer)

function MoveAnimationPlayer:ctor(list)
    self.list = list
    self.isPlaying = false
    self.cellMoveCache = {}
end

function MoveAnimationPlayer:initMoveStart(cellDatas)
    local tempPos = FVector2D()
    local cellnum = #cellDatas
    local cellIdx 
    local cell 
    local cache 
    local isOffset 
    for i = 1, cellnum, 1 do
        cellIdx = cellDatas[i].index
        cell = cellDatas[i].cell
        cache = self.cellMoveCache[cellIdx]
        isOffset = false
        if cell then
            if not cell.WidgetRoot then cell = cell.View end
            local cache = self.cellMoveCache[cellIdx]
            if not cache then
                Log.Warning("No Move Cell: ", cellIdx)
            end
            if cell.Slot:GetAnchors().Maximum.X == 1 then
                isOffset = true
            else
                isOffset = false
            end
            tempPos.X = cache.startPosX
            tempPos.Y = cache.startPosY
            if isOffset then
                local offsets = cell.Slot:GetOffsets()
                offsets.Left = tempPos.X
                offsets.Right = -1 * tempPos.X
                offsets.Top = tempPos.Y
                cell.Slot:SetOffsets(offsets)
            else
                cell.Slot:SetPosition(tempPos)
            end
            cell.WidgetRoot:SetRenderOpacity(cache.startOpacity)
        end
    end
end

function MoveAnimationPlayer:PlayListAnimation(cellDatas, aniData, callback)
    local tempPos = FVector2D()
    local name = "AniMove"
    local flyTime = 0
    local duration 
    -- local frequence = aniData.frequence
    local moveCurve 
    local opCurve 
    local cellnum = #cellDatas
    if cellnum <= 0 then
        return
    end 
    UIBase.StopTimer(self.list, name)
    self:clearMoveCell()
    local maxTime = 0
    for i = 1, #cellDatas, 1 do
        maxTime = math.max(self:addMoveCell(cellDatas[i], aniData),maxTime)
    end 
    self:initMoveStart(cellDatas)
    self.list:LockScroll(true)
    local func = function(e)
        flyTime = flyTime + e
        --if flyTime > (cellnum - 1) * frequence + duration then
        local cellIdx 
        local cell 
        local cache 
        local isOffset 
        if flyTime > maxTime then
            for i = 1, cellnum, 1 do
                cellIdx = cellDatas[i].index
                cell = cellDatas[i].cell
                cache = self.cellMoveCache[cellIdx]
                isOffset = false
                if cell then
                    if not cell.WidgetRoot then cell = cell.View end
                    local cache = self.cellMoveCache[cellIdx]
                    if not cache then
                        Log.Warning("No Move Cell: ", cellIdx)
                    end
                    if cell.Slot:GetAnchors().Maximum.X == 1 then
                        isOffset = true
                    else
                        isOffset = false
                    end
                    tempPos.X = cache.endPosX
                    tempPos.Y = cache.endPosY
                    cache.nowPosX = tempPos.X
                    cache.nowPosY = tempPos.Y
                    if isOffset then
                        local offsets = cell.Slot:GetOffsets()
                        offsets.Left = tempPos.X
                        offsets.Right = -1 * tempPos.X
                        offsets.Top = tempPos.Y
                        cell.Slot:SetOffsets(offsets)
                    else
                        cell.Slot:SetPosition(tempPos)
                    end
                    cell.WidgetRoot:SetRenderOpacity(cache.endOpacity)
                end
                
            end
            if callback then
                callback()
            end
            UIBase.StopTimer(self.list, name)
            self:onCellMoveEnd()
        else
            for i = 1, cellnum, 1 do
                cellIdx = cellDatas[i].index
                cell = cellDatas[i].cell
                cache = self.cellMoveCache[cellIdx]
                --local cell = self:GetRendererAt(cellIdx)
                local isOffset = false
                if cell then
                    moveCurve = aniData[cache.floor][cache.kind].moveCurve
                    opCurve = aniData[cache.floor][cache.kind].opCurve
                    duration = aniData[cache.floor][cache.kind].duration
                    if flyTime >= cache.startTime then
                        if not cell.WidgetRoot then cell = cell.View end
                        -- local cache = self.cellMoveCache[cellIdx]
                        if not cache then
                            Log.Warning("No Move Cell: ", cellIdx)
                        end
                        if cell.Slot:GetAnchors().Maximum.X == 1 then
                            isOffset = true
                        else
                            isOffset = false
                        end
                        local schedule = math.max(flyTime - cache.startTime, 0)

                        local v = 1
                        local o = 1
                        if moveCurve then
                            v = moveCurve:GetFloatValue(schedule/duration)
                        else
                            v = math.min(schedule / duration, 1)
                        end
                        if opCurve then
                            o = opCurve:GetFloatValue(schedule/duration)
                        else
                            o = math.min(schedule / duration, 1)
                        end 
                        tempPos.X = cache.startPosX + (cache.endPosX - cache.startPosX) * v
                        tempPos.Y = cache.startPosY + (cache.endPosY - cache.startPosY) * v
                        --Log.Warning("ListViewRemove: ",tempPos.Y)
                        cache.nowPosX = tempPos.X
                        cache.nowPosY = tempPos.Y
                        
                        cache.nowOpacity = cache.startOpacity + (cache.endOpacity - cache.startOpacity) * o
                        if isOffset then
                            local offsets = cell.Slot:GetOffsets()
                            offsets.Left = tempPos.X
                            offsets.Right = -1 * tempPos.X
                            offsets.Top = tempPos.Y
                            cell.Slot:SetOffsets(offsets)
                        else
                            cell.Slot:SetPosition(tempPos)
                        end
                        cell.WidgetRoot:SetRenderOpacity(cache.nowOpacity)
                        --Log.Debug("MoveAnimation: ",cellIdx," ", tempPos.Y)
                    end
                else
                    Log.Warning("Cell is Missing!", cellIdx)
                end
            end
        end
    end
    self.list:LockScroll(true)
    UIBase.StartTimer(self.list, name, func, 1, -1, nil, true)
    self.isPlaying = true
end

function MoveAnimationPlayer:addMoveCell(cellData, aniData)
    local index = cellData.index
    local cell = cellData.cell
    local startPos = cellData.startPos
    local endPos = cellData.endPos
    
    local startTime = cellData.startTime
    local floor = cellData.floor or 1
    local kind = cellData.kind or 1

    if not aniData[floor] or not aniData[floor][kind] then --允许某一类型的节点没有动画
        return
    end

    local startOpacity = aniData[floor][kind].startOpacity or 1
    local endOpacity = aniData[floor][kind].endOpacity or 1
    local startOffset = {X = 0,Y = 0}
    local endOffset = {X = 0,Y = 0}
    if aniData[floor][kind] then
        startOffset = aniData[floor][kind].startOffset
        endOffset = aniData[floor][kind].endOffset    
    end

    if not index then
        Log.Error("Move index is nil")
        return
    end
    
    if not startPos or not endPos then
        Log.Error("Move Position is nil", index)
        return
    end

    local cache = self.cellMoveCache[index]
    if not cache then cache = {} end
    
    cache = {
        startTime = startTime,
        floor = floor,
        kind = kind,
        startPosX = startPos.X + startOffset.X,
        startPosY = startPos.Y + startOffset.Y,
        endPosX = endPos.X + endOffset.X,
        endPosY = endPos.Y + endOffset.Y,
        nowPosX = startPos.X + startOffset.X,
        nowPosY = startPos.Y + startOffset.Y,
        startOpacity = startOpacity,
        endOpacity = endOpacity,
        nowOpacity = startOpacity
    } 
    self.cellMoveCache[index] = cache
    return startTime + aniData[floor][kind].duration
end

function MoveAnimationPlayer:clearMoveCell(index)
    Log.Debug("clearCache")
    if index then
        if self.cellMoveCache[index] then
            self.cellMoveCache[index] = nil
        end
        for i = #self.cachedData, 1, -1 do
            
        end
    else
        -- for k, v in pairs(self.cellMoveCache) do
        --     self.cellMoveCache[k] = nil
        -- end
        table.clear(self.cellMoveCache)
        self.cachedData = nil
    end
    
end

function MoveAnimationPlayer:StopListAnimation(startOrend)
    Log.Debug("StopAllCellMove")
    UIBase.StopTimer(self.list, "AniMove")
    
    if startOrend and self.cachedData then
        local cellIdx 
        local cell 
        local cache 
        local isOffset 
        local cellDatas = self.cachedData
        local tempPos = FVector2D()
        for i = 1, #cellDatas, 1 do
            cellIdx = cellDatas[i].index
            cell = cellDatas[i].cell
            cache = self.cellMoveCache[cellIdx]
            isOffset = false
            if cell then
                if not cell.WidgetRoot then cell = cell.View end
                local cache = self.cellMoveCache[cellIdx]
                if not cache then
                    Log.Warning("No Move Cell: ", cellIdx)
                end
                if cell.Slot:GetAnchors().Maximum.X == 1 then
                    isOffset = true
                else
                    isOffset = false
                end
                if startOrend == 0 then
                    tempPos.X = cache.startPosX
                    tempPos.Y = cache.startPosY
                else
                    tempPos.X = cache.endPosX
                    tempPos.Y = cache.endPosY
                end
                cache.nowPosX = tempPos.X
                cache.nowPosY = tempPos.Y
                if isOffset then
                    local offsets = cell.Slot:GetOffsets()
                    offsets.Left = tempPos.X
                    offsets.Right = -1 * tempPos.X
                    offsets.Top = tempPos.Y
                    cell.Slot:SetOffsets(offsets)
                else
                    cell.Slot:SetPosition(tempPos)
                end
                if startOrend == 0 then
                    cell.WidgetRoot:SetRenderOpacity(cache.startOpacity)
                else
                    cell.WidgetRoot:SetRenderOpacity(cache.endOpacity)
                end
            end
        end
    end
    
    self.isPlaying = false
    self.list:LockScroll(false)
    self:clearMoveCell()
end

function MoveAnimationPlayer:onCellMoveEnd()
    self.isPlaying = false
    self:clearMoveCell()
    self.list:LockScroll(false)
end

function MoveAnimationPlayer:IsAnimationPlaying()
    return self.isPlaying
end

function MoveAnimationPlayer:dtor()
    self.isPlaying = false
    self.cellMoveCache = {}
end

return MoveAnimationPlayer