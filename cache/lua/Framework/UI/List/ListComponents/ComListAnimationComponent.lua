local IListAnimationComponent = kg_require("Framework.UI.List.ListComponents.IListAnimationComponent")
local MovePlayer = kg_require("Framework.UI.List.ListComponents.MoveAnimationPlayer")
local StaggerPlayer = kg_require("Framework.UI.List.ListComponents.StaggerAnimationPlayer")
local AutoPlayer = kg_require("Framework.UI.List.ListComponents.StateAnimationPlayer")
local ComListAnimationComponent = DefineClass("ComListAnimationComponent", IListAnimationComponent)
function ComListAnimationComponent:ctor(list)
    self.list = list
    self.aniPlayerMap = {}
    self.aniPlayerType = {}   
    self.autoPlayer = nil
    self.aniCfg = {}
    self.aniPlayerPool = ListAnimationLibrary.InitPlayerPool()
end

function ComListAnimationComponent:dtor()
    self.list =  nil
    self.aniPlayerMap = nil
    self.aniPlayerType = nil  
    self.autoPlayer = nil
    self.aniPlayerPool = nil
end

function ComListAnimationComponent:AddAnimationConfig(key, cfg)
    self.aniCfg[key] = cfg
    self.aniPlayerType[key] = cfg.AnimationType
    
end

function ComListAnimationComponent:RemoveAniamtionConfig(key)
    self.aniCfg[key] = nil
    self.aniPlayerType[key] = nil
end


function ComListAnimationComponent:getPlayerByConfig(configIdx)
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

function ComListAnimationComponent:setPlayerByConfig(configIdx)
    local player = self.aniPlayerMap[configIdx]
    local playerType
    if player then
        playerType = self.aniPlayerType[configIdx]
        self:setPlayer(player, playerType)
        self.aniPlayerMap[configIdx] = nil
    end
end

function ComListAnimationComponent:getAutoPlayer()
    if not self.autoPlayer then
        self.autoPlayer = self:getPlayer(ListAnimationLibrary.Player.Auto)
    end
    return self.autoPlayer
end

function ComListAnimationComponent:getPlayer(playerType)
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

function ComListAnimationComponent:setPlayer(player, playerType)
    if player then
        if playerType then 
            table.insert(self.aniPlayerPool[playerType], player)
        else
            player:delete()
        end
    end
end
function ComListAnimationComponent:getStaggerAniData(cells, config)
    if config then
        local celldata = {}
        local startTime = 0
        local frequence = config.Frequence
        local ani = config.Animation
        local aniData = {
                  [1] = {
                        [1] = {animation = ani}
                        }
                        }
        for i = 1, #cells, 1 do
            startTime = (i - 1) * frequence
            local moveData = {
                startTime = startTime * 1000,
                floor = 1,
                kind = 1
            }
            celldata[cells[i].index] = moveData
        end
        return celldata, aniData
    end
end

function ComListAnimationComponent:getMoveAniData(cells, config)
    if config then
        local celldata = {}
        local startTime = 0
        local cellidx

        local frequence = config.Frequence
        local animationData = config.AnimationData
        local duration = animationData.Duration
        local endOpacity = animationData.EndOpacity
        local startOpacity = animationData.StartOpacity
        local moveCurve = animationData.MoveCurve
        local opCurve = animationData.OpacityCurve

        local startOffset = animationData.StartOffset
        local endOffset = animationData.EndOffset
        
        local aniData = {
                  [1] = {[1] = {frequence = frequence * 1000,
                         duration = duration * 1000,
                         startOffset = startOffset,
                         endOffset = endOffset,
                         startOpacity = startOpacity,
                         endOpacity = endOpacity,
                         moveCurve = moveCurve,
                         opCurve = opCurve}}
                        }
        
        for i = 1, #cells, 1 do
            cellidx = cells[i].index
            local uiComponent = self.list:GetRendererAt(cellidx)
            if uiComponent then
                local nowPos
                nowPos = uiComponent.View.WidgetRoot.Slot:GetPosition()

                local startCellPos = {X = nowPos.X,
                                    Y = nowPos.Y}
                local endCellPos = {X = nowPos.X,
                                    Y = nowPos.Y}

                

                startTime = (i - 1) * frequence
                local moveData = {
                    startTime = startTime * 1000,
                    index = cellidx,
                    cell = uiComponent,
                    startPos = cells[i].startPos or startCellPos,
                    endPos = cells[i].endPos or endCellPos,
                }
                table.insert(celldata, moveData)
            end
        end
        return celldata, aniData
    end
end

function ComListAnimationComponent:getAutoAniData(cfg)
    return cfg.State, cfg.Animation, cfg.Loop
end

function ComListAnimationComponent:EnableAutoAnimation(key, widget)
    local cfg = self.aniCfg[key]
    local type
    cfg, type = ListAnimationLibrary.GetAniDataByType(cfg)
    if cfg and type then
        if type == ListAnimationLibrary.Player.Auto then
            local state, aniName, bLoop = self:getAutoAniData(cfg)
            self:getAutoPlayer():SetAutoAnimation(state, widget, aniName, bLoop)
        end
    end    
end

function ComListAnimationComponent:DisableAutoAnimation(key, widget)
    local cfg = self.aniCfg[key]
    local type
    cfg, type = ListAnimationLibrary.GetAniDataByType(cfg)
    if cfg and type then
        if type == ListAnimationLibrary.Player.Auto then
            local state, aniName = self:getAutoAniData(cfg)
            self:getAutoPlayer():ClearAutoAnimation(state, widget, aniName)
        end
    end
end

function ComListAnimationComponent:PlayStateAnimation(index, state, callback)
    self:getAutoPlayer():PlayListAnimation(index, state, callback)
end

function ComListAnimationComponent:PlayListGroupAnimation(key, cells, callback, forceEnd)
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

function ComListAnimationComponent:setCellUpdateAni(index)
    
end

function ComListAnimationComponent:RefreshCellUpdateAni(index, bSelected)
    self:getAutoPlayer():onRefreshItem(index, bSelected)
end

function ComListAnimationComponent:GetListAnimationEndTime(key, index, number)
    local cfg = self.aniCfg[key]
    local type
    cfg, type = ListAnimationLibrary.GetAniDataByType(cfg)
    if type == ListAnimationLibrary.Player.Move then
        return self:getMoveEndTime(cfg, index, number)
    elseif type == ListAnimationLibrary.Player.Stagger then
        return self:getStaggerEndTime(cfg, index, number)
    end
end

function ComListAnimationComponent:getMoveEndTime(cfg, index, number)
    local frequence = cfg.Frequence
    local animationData = cfg.AnimationData
    local duration = animationData.Duration

    return frequence * (number - 1) + duration
end

function ComListAnimationComponent:getStaggerEndTime(cfg, index, number)
    local frequence = cfg.Frequence
    local ani = cfg.Animation
    local cell = self.list:GetRendererAt(index)
    local animation = cell.View[ani]
    return frequence * (number - 1) + animation:GetEndTime()
end

return ComListAnimationComponent