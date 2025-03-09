local IListAnimationComponent = kg_require("Framework.UI.List.ListComponents.IListAnimationComponent")
local MovePlayer = kg_require("Framework.UI.List.ListComponents.MoveAnimationPlayer")
local StaggerPlayer = kg_require("Framework.UI.List.ListComponents.StaggerAnimationPlayer")
local AutoPlayer = kg_require("Framework.UI.List.ListComponents.StateAnimationPlayer")
local TreeListAnimationComponent = DefineClass("TreeListAnimationComponent", IListAnimationComponent)

function TreeListAnimationComponent:ctor(list)
    self.list = list
    self.aniPlayerMap = {}
    self.aniPlayerType = {}   
    self.autoPlayer = nil
    self.aniCfg = {}
    self.aniPlayerPool = ListAnimationLibrary.InitPlayerPool()
end

function TreeListAnimationComponent:dtor()
    self.list =  nil
    self.aniPlayerMap = nil
    self.aniPlayerType = nil  
    self.autoPlayer = nil
    self.aniPlayerPool = nil
end

function TreeListAnimationComponent:AddAnimationConfig(key, cfg)
    self.aniCfg[key] = cfg
    self.aniPlayerType[key] = cfg.AnimationType
    
end

function TreeListAnimationComponent:RemoveAniamtionConfig(key)
    self.aniCfg[key] = nil
    self.aniPlayerType[key] = nil
end


function TreeListAnimationComponent:getPlayerByConfig(configIdx)
    local playerType
    if configIdx then
        playerType = self.aniPlayerType[configIdx] 
        if not playerType then
            Log.Warning("No Animation Config: ", configIdx)
            return
        end
    else
        Log.Warning("InVaild Animation Config")
        return
    end
    local player = self.aniPlayerMap[configIdx]
    if player then
        Log.Debug("Has Player")
        return player
    end
    Log.Debug("Get From Pool")
    player = self:getPlayer(playerType)
    if player then
        self.aniPlayerMap[configIdx] = player
    end
    return player
end

function TreeListAnimationComponent:setPlayerByConfig(configIdx)
    local player = self.aniPlayerMap[configIdx]
    local playerType
    if player then
        playerType = self.aniPlayerType[configIdx]
        self:setPlayer(player, playerType)
        self.aniPlayerMap[configIdx] = nil
    end
end

function TreeListAnimationComponent:getAutoPlayer()
    if not self.autoPlayer then
        self.autoPlayer = self:getPlayer(ListAnimationLibrary.Player.Auto)
    end
    return self.autoPlayer
end

function TreeListAnimationComponent:getPlayer(playerType)
    local player
    if self.aniPlayerPool[playerType] then
        local num = #self.aniPlayerPool[playerType]
        if num > 0 then
            player = self.aniPlayerPool[playerType][num]
            table.remove(self.aniPlayerPool[playerType], num)
            return player
        else
            if playerType == ListAnimationLibrary.Player.Stagger then
                player = StaggerPlayer.new(self.list)
                return player
            elseif playerType == ListAnimationLibrary.Player.Move then
                player = MovePlayer.new(self.list)
                return player
            elseif playerType == ListAnimationLibrary.Player.Auto then
                player = AutoPlayer.new(self.list)
                return player
            end
        end
    end
    return player
end

function TreeListAnimationComponent:setPlayer(player, playerType)
    if player then
        if playerType then 
            table.insert(self.aniPlayerPool[playerType], player)
        else
            player:delete()
        end
    end
end

function TreeListAnimationComponent:getStaggerAniData(cells, config)
    local celldata = {}
    local aniData = {}
    local startTime = 0
    local cellidx
    local floor = 1
    local group = 1
    local kind = 1
    local widgetAni
    if config then
        local UnifiedFrequence = config.UnifiedFrequence
        for f = 1, config.Animations:Num(), 1 do
            local widgetAni = config.Animations:Get(f - 1)
            for k = 1, widgetAni.Widget:Num(), 1 do
                aniData[f] = {}
                aniData[f][k] = {animation = widgetAni.Widget:Get(k - 1)}
            end 
        end
        if UnifiedFrequence then
            local gf = config.GroupFrequence:Get(0)
            for i = 1, #cells, 1 do
                cellidx = cells[i].index
                startTime = (cellidx - 1 - cells[1]) * gf
                floor, kind = self.list:getFloorAndKind(cellidx)
                local moveData = {
                    startTime = startTime * 1000,
                    floor = floor,
                    kind = kind
                }
                celldata[cellidx] = moveData
            end 
        else
            local parent = -1
            local ff = 0
            local gf = 0
            
            for i = 1, #cells, 1 do
                local movedata = {}
                cellidx = cells[i].index
                floor, kind = self.list:getFloorAndKind(cellidx)
                parent = self.list:getParent(cellidx)
                group = self.list:getGroupIndex(cellidx)
                if floor > 1 then
                    ff = config.FloorFrequence:Get(floor - 2) * 1000
                end
                if not ff then
                    ff = 0
                end
                local gf = config.GroupFrequence:Get(floor - 1) * 1000
                if not gf then
                    gf = 0
                end
                if parent == -1 then
                    --table.insert(cellTimes, (group - 1) * gf)
                    startTime = (group - 1) * gf
                else
                    local pt = celldata[parent]
                    if not pt then
                        --table.insert(cellTimes, (cellidx - 1 - self._topIndex) *gf )
                        startTime = (cellidx - 1 - cells[1].index) *gf
                    else
                        pt = pt.startTime
                        --table.insert(cellTimes, (pt + ff + (group - 1) * gf))
                        startTime = (pt + ff + (group - 1) * gf)
                    end
                end
                movedata = {
                    startTime = startTime,
                    floor = floor,
                    kind = kind
                }
                celldata[cellidx] = movedata
            end
        end
        return celldata, aniData
    end
end

function TreeListAnimationComponent:getMoveAniData(cells, config)
    if config then
        local celldata = {}
        local aniData = {}
        local startTime = 0
        local duration
        local endOpacity
        local startOpacity
        local moveCurve
        local opCurve
        local startOffset
        local endOffset 

        local UnifiedFrequence = config.UnifiedFrequence

        for f = 1, config.AnimationData:Num(), 1 do
            local widgetAni = config.AnimationData:Get(f - 1)
			aniData[f] = {}
            for k = 1, widgetAni.Widget:Num(), 1 do
                local animationData = widgetAni.Widget:Get(k - 1)

                duration = animationData.Duration
                endOpacity = animationData.EndOpacity
                startOpacity = animationData.StartOpacity
                moveCurve = animationData.MoveCurve
                opCurve = animationData.OpacityCurve
                startOffset = animationData.StartOffset
                endOffset = animationData.EndOffset

                aniData[f][k] = {
                    duration = duration * 1000,
                    startOffset = startOffset,
                    endOffset = endOffset,
                    startOpacity = startOpacity,
                    endOpacity = endOpacity,
                    moveCurve = moveCurve,
                    opCurve = opCurve
                }
            end 
        end
        local cellidx
        local floor = 1
        local group = 1
        local kind = 1
        if UnifiedFrequence then
            local gf = config.GroupFrequence:Get(0)
            for i = 1, #cells, 1 do
                cellidx = cells[i].index
                local uiComponent = self.list:GetRendererAt(cellidx)
                local nowPos
                nowPos = uiComponent.View.WidgetRoot.Slot:GetPosition()

                local startCellPos = {X = nowPos.X,
                                    Y = nowPos.Y}
                local endCellPos = {X = nowPos.X,
                                    Y = nowPos.Y}
                startTime = (cellidx - 1 - cells[1]) * gf
                floor, kind = self.list:getFloorAndKind(cellidx)
                local moveData = {
                    startTime = startTime * 1000,
                    index = cellidx,
                    cell = uiComponent,
                    startPos = startCellPos,
                    endPos = endCellPos,
                    floor = floor,
                    kind = kind
                }
                celldata[cellidx] = moveData
            end 
        else
            local parent = -1
            local ff = 0
            local gf = 0
            
            for i = 1, #cells, 1 do
                local movedata = {}
                cellidx = cells[i].index
                floor, kind = self.list:getFloorAndKind(cellidx)
                parent = self.list:getParent(cellidx)
                if floor > 1 then
                    ff = config.FloorFrequence:Get(floor - 2)
                end
                if not ff then
                    ff = 0
                end
                local gf = config.GroupFrequence:Get(floor - 1)
                if not gf then
                    gf = 0
                end
                if parent == -1 then
                    --table.insert(cellTimes, (group - 1) * gf)
                    startTime = (group - 1) * gf
                else
                    local pt = celldata[parent]
                    if not pt then
                        --table.insert(cellTimes, (cellidx - 1 - self._topIndex) *gf )
                        startTime = (cellidx - 1 - cells[1].index) *gf
                    else
                        pt = pt.startTime
                        --table.insert(cellTimes, (pt + ff + (group - 1) * gf))
                        startTime = (pt + ff + (group - 1) * gf)
                    end
                end

                local uiComponent = self.list:GetRendererAt(cellidx)
                local nowPos
                nowPos = uiComponent.View.WidgetRoot.Slot:GetPosition()

                local startCellPos = {X = nowPos.X,
                                    Y = nowPos.Y}
                local endCellPos = {X = nowPos.X,
                                    Y = nowPos.Y}

                movedata = {
                    startTime = startTime * 1000,
                    index = cellidx,
                    cell = uiComponent,
                    startPos = cells[i].startPos or startCellPos,
                    endPos = cells[i].endPos or endCellPos,
                    floor = floor,
                    kind = kind
                }
                celldata[cellidx] = movedata
            end
        end
        return celldata, aniData
    end
end

function TreeListAnimationComponent:getAutoAniData(cfg)
    -- local anis = {}
    -- local floor, kind, ani
    -- for i = 1, cfg.Animation:Num(), 1 do
    --     floor = i
    --     local widgetAni = cfg.Animation:Get(floor - 1)
    --     for k = 1, widgetAni.Widget:Num(), 1 do
    --         kind = k
    --         ani = widgetAni.Widget:Get(kind - 1)
    --         --table.insert(anis, {floor = floor, kind = kind, ani = ani})
    --     end
    -- end
    return cfg.State, cfg.Floor, cfg.Kind, cfg.Animation, cfg.Loop
end

function TreeListAnimationComponent:EnableAutoAnimation(key, widget)
    local cfg = self.aniCfg[key]
    local type
    cfg, type = ListAnimationLibrary.GetAniDataByType(cfg)
    if cfg and type then
        if type == ListAnimationLibrary.Player.Auto then
            local state, floor, kind, ani, bLoop = self:getAutoAniData(cfg)
                self:getAutoPlayer():SetAutoAnimation(state, widget, ani, bLoop, floor, kind)
            
        end
    end    
end

function TreeListAnimationComponent:DisableAutoAnimation(key, widget)
    local cfg = self.aniCfg[key]
    local type
    cfg, type = ListAnimationLibrary.GetAniDataByType(cfg)
    if cfg and type then
        if type == ListAnimationLibrary.Player.Auto then
            local state, floor, kind, ani, bLoop = self:getAutoAniData(cfg)
            
                self:getAutoPlayer():ClearAutoAnimation(state, widget, ani, floor, kind)
            
        end
    end
end

function TreeListAnimationComponent:PlayStateAnimation(index, state)
    local floor 
    self:getAutoPlayer():PlayListAnimation(index, state)
end

function TreeListAnimationComponent:PlayListGroupAnimation(key, cells, callback, forceEnd)
    local cfg = self.aniCfg[key]
    local type
    cfg, type = ListAnimationLibrary.GetAniDataByType(cfg)
    if cfg and type then
        local player = self:getPlayerByConfig(key)
        if forceEnd and player:IsAnimationPlaying() then
            player:StopListAnimation(forceEnd)
        end
        local cb = function()
        if callback then
            callback()
        end
        self:setPlayerByConfig(key)
        end
        if type == ListAnimationLibrary.Player.Move then
            local celldata, aniData = self:getMoveAniData(cells, cfg)
            player:PlayListAnimation(celldata, aniData, cb)
        elseif type == ListAnimationLibrary.Player.Stagger then
            local celldata, aniData = self:getStaggerAniData(cells, cfg)
            player:PlayListAnimation(celldata, aniData, cb)     
        end
    end
end

function TreeListAnimationComponent:setCellUpdateAni(index)
    
end

function TreeListAnimationComponent:RefreshCellUpdateAni(index, bSelected)
    self:getAutoPlayer():onRefreshItem(index, bSelected)
end

function TreeListAnimationComponent:GetListAnimationEndTime(key, index, number)
    local cfg = self.aniCfg[key]
    local type
    cfg, type = ListAnimationLibrary.GetAniDataByType(cfg)
    if type == ListAnimationLibrary.Player.Move then
        return self:getMoveEndTime(cfg, index, number)
    elseif type == ListAnimationLibrary.Player.Stagger then
        return self:getStaggerEndTime(cfg, index, number)
    end
end

function TreeListAnimationComponent:getMoveEndTime(cfg, index, number)
    -- local frequence = cfg.Frequence
    -- local animationData = cfg.AnimationData
    -- local duration = animationData.Duration

    -- return frequence * (number - 1) + duration
end

function TreeListAnimationComponent:getStaggerEndTime(cfg, index, number)
    -- local frequence = cfg.Frequence
    -- local ani = cfg.Animation
    -- local cell = self.list:GetRendererAt(index)
    -- local animation = cell.View[ani]
    -- return frequence * (number - 1) + animation:GetEndTime()
end

return TreeListAnimationComponent