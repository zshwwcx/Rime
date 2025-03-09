local IListAnimationComponent = DefineClass("IListAnimationComponent")


function IListAnimationComponent:AddAnimationConfig(key, cfg)
  
end

function IListAnimationComponent:RemoveAniamtionConfig(key)
   
end

function IListAnimationComponent:getPlayerByConfig(key)
    
end

function IListAnimationComponent:setPlayerByConfig(key)
    
end
function IListAnimationComponent:getAutoPlayer()
    
end
function IListAnimationComponent:getPlayer(playerType)
    
end
function IListAnimationComponent:setPlayer(player, playerType)
    
end

function IListAnimationComponent:checkAnimationConfig(key, isAniNotify)
    
end

function IListAnimationComponent:getStaggerAniData(cells, config)
    
end

function IListAnimationComponent:getMoveAniData(cells, config)
    
end

function IListAnimationComponent:getAutoAniData(cfg)
    
end

function IListAnimationComponent:EnableAutoAnimation(key, widget)
    
end

function IListAnimationComponent:DisableAutoAnimation(key, widget)
    
end

function IListAnimationComponent:PlayListGroupAnimation(key, cells, callback)
end

function IListAnimationComponent:PlayStateAnimation(index, state)
    
end

function IListAnimationComponent:GetListAnimationEndTime(key, index, number)
    
end

function IListAnimationComponent:setCellUpdateAni(index)
    
end

function IListAnimationComponent:RefreshCellUpdateAni(index, bSelected)
   
end

return IListAnimationComponent