local EUMGSequencePlayMode = import("EUMGSequencePlayMode")
local ESlateVisibility = import("ESlateVisibility")
local IListAnimationPlayer = kg_require("Framework.UI.List.ListComponents.IListAnimationPlayer")
local StaggerAnimationPlayer = DefineClass("StaggerAnimationPlayer", IListAnimationPlayer)

function StaggerAnimationPlayer:ctor(list)
    self.list = list
    self.StaggerCache = {}
    self.isPlaying = false
end


function StaggerAnimationPlayer:PlayListAnimation(cellDatas, aniData, callback)
    local name = "CellStagger"
    UIBase.StopTimer(self.list, name)
    --计算计时器时长
    local maxTime = 0
    local endTime = 0

    if not self.StaggerCache then self.StaggerCache = {} end
    table.clear(self.StaggerCache)
    --for i = 1, #aniDatas, 1 do
    local ani
    local floor
    local kind
    for idx, data in pairs(cellDatas) do
        local cell = self.list:GetRendererAt(idx)
        maxTime = math.max(maxTime, data.startTime)
        floor = data.floor or 1
        kind = data.kind or 1
        ani = cell.View[aniData[floor][kind].animation]
        if ani then
            endTime = math.max(endTime, ani:GetEndTime() + (data.startTime / 1000))
        end
        local cache = {
            startTime = data.startTime,
            started = false,
            ani = ani
        }
        self.StaggerCache[idx] = cache
        
        if cell and ani then
            UIBase.SetWidgetToAnimationStartInstantly(self.list, cell.View.WidgetRoot, ani)
        end
    end

    endTime = endTime * 1000

    local aniTime = 0
    local func = function(e)
        aniTime = aniTime + e
        if aniTime > maxTime then
            for idx, cache in pairs(self.StaggerCache) do
                if not cache.started then
                    local cell = self.list:GetRendererAt(idx)
                    ani = cache.ani
                    if cell and ani then
                        UIBase.PlayAnimation(self.list, cell.View.WidgetRoot, ani, 0.0, 1, EUMGSequencePlayMode.Forward, 1, false)
                        cache.started = true
                    end
                end 
            end
            self:onStaggeredAnimation(endTime - maxTime, callback)
            UIBase.StopTimer(self.list, name)
        else
            for idx, data in pairs(cellDatas) do
                local cache = self.StaggerCache[idx]
                if cache then
                    local cell = self.list:GetRendererAt(idx)
                    ani = cache.ani
                    if cell and ani then
                        if not cache.started and aniTime >= cache.startTime then
                            UIBase.PlayAnimation(self.list, cell.View.WidgetRoot, ani, 0.0, 1, EUMGSequencePlayMode.Forward, 1, false)
                            cache.started = true
                        end
                    end
                end
            end
        end
    end
    UIBase.StartTimer(self.list, name, func, 1, -1, nil, true)
    self.isPlaying = true
end

function StaggerAnimationPlayer:onStaggeredAnimation(delay, callback)
    table.clear(self.StaggerCache)
    UIBase.StartTimer(self.list, "StaggerEnd", function()
        self.isPlaying = false
        if callback then
            callback()
        end
    end, delay, 1)
end

function StaggerAnimationPlayer:StopListAnimation(startOrend)
    
end

function StaggerAnimationPlayer:IsAnimationPlaying()
    return self.isPlaying
end

function StaggerAnimationPlayer:dtor()
    self.StaggerCache = nil
end
return StaggerAnimationPlayer