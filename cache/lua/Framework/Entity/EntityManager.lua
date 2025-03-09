---@class EntityManager
EntityManager = DefineClass("EntityManager")

EEntityType = {
    MainPlayer = "MainPlayer", --主角
    AvatarActor = "AvatarActor", --第三方玩家
    NpcActor = "NpcActor", --NPC及怪物
}

EntityManager.EntitysCountChangedEventName = "EntitysCountChangedEvent"

function EntityManager.Instance()
    if EntityManager.instance == nil then
        EntityManager.instance = EntityManager.new()
    end
    return EntityManager.instance
end

function EntityManager:ctor()
    self.entityClsMap = {}
    self.briefEntityClsMap = {}
	--self.entities = Game.GameSDK.entityManager.entities
	self.entities = {}			-- 普通entity,int id做key
	self.entitiesStrKey = {}	-- 普通entity，string做key，后续删除
	self.briefEntities = {}		-- brief entity
    self.briefEntitiesStrKey = {}	-- 普通entity，string做key, 目前很多的业务逻辑都是基于Entity的eid(服务器有的地方叫uid)，这里只能兼容，性能有需求的用uid(服务器叫int_id) @hujianglong

	-- 包含local entity
    self.allEntities = {}
    self.allEntityMap = {}
    self.allEntityNum = {}
	
	-- 保存所有的scene actor
	self.sceneActorMap = {}
	-- 保存所有的avatar，包括brief avatar
	self.allAvatarMap = {}

    if Events then
        self.EntitysCountChangedEvents = Events.new()
    end
end

function EntityManager:dtor()
    self.entityClsMap = {}
    self.briefEntityClsMap = {}
    self:clear()
    
    self.allEntities = {}
    self.allEntityMap = {}
    self.allEntityNum = {}
	self.sceneActorMap = {}
	self.allAvatarMap = {}

    if self.EntitysCountChangedEvents then
        self.EntitysCountChangedEvents:RemoveAllListener(EntityManager.EntitysCountChangedEventName)
    end
end

function EntityManager:clear()
    for k, v in pairs(self.entities) do
        if v ~= Game.me then  --MainPlayer始终不主动销毁，获取到新的后再销毁老的
			Log.Debug("entity destroy", v.eid, v.__cname) --todo 加个log排查下“memory allocation error: block too big”报错
            v:destroy()
            self.entities[k] = nil
        end
    end
end

function EntityManager:registerEntity(entityName, entityCls, bBriefEntity)
    if bBriefEntity then
        self.briefEntityClsMap[entityName] = entityCls
    else
        self.entityClsMap[entityName] = entityCls
    end
end

function EntityManager:getEntitiesByType(EntityType)
    return  self.allEntities[EntityType]
end

function EntityManager:getEntityCharacterList()
    return self.allEntities["AvatarActor"]
end

function EntityManager:getEntity(entityId)
    local entity = self.entities[entityId]
    if entity then
        return entity
    end
	entity = self.entitiesStrKey[entityId]
	if entity then
		return entity
	end
    entity = Game.LocalEntityManager:getEntity(entityId)
    if entity then
        return entity
    end
    -- 兼容下整型id获取
    return self:GetEntityByIntID(entityId)
end

-- C7 CODE ADD START BY shijingzhe@kuaishou.com
-- 兼容接口

function EntityManager:GetEntityEIDByUID(uid)
    local ent = self:getEntity(uid)
    return ent and ent.eid or nil
end

-- C7 CODE ADD END BY shijingzhe@kuaishou.com

function EntityManager:getEntityCls(entityType, bBriefEntity)
    if bBriefEntity then
        return self.briefEntityClsMap[entityType]
    else
        return self.entityClsMap[entityType]
    end
end

function EntityManager:getEntityClsMap()
    return self.entityClsMap
end

-- 按类型添加entity
function EntityManager:AddEntity(entity, is_brief)
	if is_brief then
		self.briefEntities[entity:uid()] = entity
        self.briefEntitiesStrKey[entity.eid] = entity
	else
		self.entities[entity:uid()] = entity
		self.entitiesStrKey[entity.eid] = entity

		if not self.allEntities[entity.ENTITY_TYPE] then
			self.allEntities[entity.ENTITY_TYPE] = {}
		end
		self.allEntities[entity.ENTITY_TYPE][entity:uid()] = entity
		self.allEntityMap[entity:uid()] = entity
	end
	if entity.ENTITY_TYPE == "AvatarActor" then
		self.allAvatarMap[entity:uid()] = entity
	end
	
    self:ModifyEntitysNum(entity.ENTITY_TYPE, 1)
end

-- 按类型移除entity
function EntityManager:RemoveEntity(entity)
    self:ModifyEntitysNum(entity.ENTITY_TYPE, -1)

	self.briefEntities[entity:uid()] = nil
    self.briefEntitiesStrKey[entity.eid] = nil
	self.entities[entity:uid()] = nil
	self.entitiesStrKey[entity.eid] = nil
    if self.allEntities[entity.ENTITY_TYPE] then
		self.allEntities[entity.ENTITY_TYPE][entity:uid()] = nil
		self.allEntityMap[entity:uid()] = nil
    end
	if entity.ENTITY_TYPE == "AvatarActor" then
		self.allAvatarMap[entity:uid()] = nil
	end
end

function EntityManager:AddLocalEntity(entity)
	if not self.allEntities[entity.ENTITY_TYPE] then
		self.allEntities[entity.ENTITY_TYPE] = {}
	end
	self.allEntities[entity.ENTITY_TYPE][entity:uid()] = entity
	self.allEntityMap[entity:uid()] = entity
	if entity.isSceneActor then
		self.sceneActorMap[entity:uid()] = entity
	end
end

function EntityManager:RemoveLocalEntity(entity)
	if not self.allEntities[entity.ENTITY_TYPE] then
		return
	end
	self.allEntities[entity.ENTITY_TYPE][entity:uid()] = nil
	self.allEntityMap[entity:uid()] = nil
	if entity.isSceneActor then
		self.sceneActorMap[entity:uid()] = nil
	end
end

function EntityManager:GetEntityByIntID(iid)
    local entity = self.allEntityMap[iid]
    if entity then
        return entity
    end
    return Game.LocalEntityManager:getEntity(tostring(iid))
end

function EntityManager:IsAvatar(entity)
    return entity.ENTITY_TYPE == "AvatarActor" or entity.ENTITY_TYPE == "MainPlayer"
end

function EntityManager:IsNpc(entity)
    return entity.ENTITY_TYPE == "NpcActor"
end

function EntityManager:ModifyEntitysNum(EType, AddNum)
    local _Num = self.allEntityNum[EType]
    if _Num == nil then
        _Num = 0
    end

    _Num  = _Num + AddNum
    if _Num < 0 then
        _Num = 0
    end

    self.allEntityNum[EType] = _Num

    if EEntityType.AvatarActor == EType and self.EntitysCountChangedEvents then
        self.EntitysCountChangedEvents:Fire(EntityManager.EntitysCountChangedEventName, EType, _Num)
    end
end

function EntityManager:GetEntitiesCountByType(EntityType)
	if self.allEntities[EntityType] then
		return table.count(self.allEntities[EntityType])
	end
	return 0
end

-- 只供aoi分级访问，获取所有的avatar，包括brief avatar
function EntityManager:GetAllAvatarsWithBrief()
	return self.allAvatarMap
end

-- 兼容查询brief entity actor
function EntityManager:getEntityWithBrief(entityId)

    local entity = self.briefEntities[entityId]
    if entity then
        return entity
    end
	entity = self.briefEntitiesStrKey[entityId]
	if entity then
		return entity
	end
	return self:getEntity(entityId)
end

return EntityManager.Instance()
