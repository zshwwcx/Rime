local json = require "Framework.Library.json"
local WorldViewBudgetConst = kg_require("Gameplay.CommonDefines.WorldViewBudgetConst")
local VIEW_FREQUENCY_LIMIT_TAG = WorldViewBudgetConst.VIEW_FREQUENCY_LIMIT_TAG

-- 提供全局方法获取所有业务中性能相关的统计数据
-- 每帧获取，避免搜集数据需要遍历所有单位，减少搜集数据开销
-- isComplete:是否完整数据，传入true表示只获取完整数据，不填或者false表示精简数据
function GetProfileData(isComplete)
	local data = {}
	GetBaseData(data, isComplete)
	GetLogicUnitData(data, isComplete)
	GetViewObjectData(data, isComplete)
	return json.encode(data)
end

-- 获取基础数据
function GetBaseData(data, isComplete)
	-- timer 数量
	data.TimerCount = table.count(Game.TimerManager.timerRunPool)
	-- event 监听数量
	data.EventCount = Game.EventSystem:GetListenCount()
	-- rpc触发数量
	data.RpcCount = Game.ProfilerInstrumentation.GetRpcCountAndClear()
	-- entity 数量
	data.EntityCount = table.count(Game.EntityManager.entities)
	-- brief entity 数量
	data.BriefEntityCount = table.count(Game.EntityManager.briefEntities)
	-- local entity 数量
	data.LocalEntityCount = table.count(Game.LocalEntityManager.localEntities)
	if isComplete then
		-- 玩家数量
		data.AvatarEntityCount = Game.EntityManager:GetEntitiesCountByType("AvatarActor")
			+ Game.EntityManager:GetEntitiesCountByType("MainPlayer")
		-- npc（含怪物）数量
		data.NpcEntityCount = Game.EntityManager:GetEntitiesCountByType("NpcActor")
		-- scene actor 数量
		data.SceneActorCount = table.count(Game.EntityManager.sceneActorMap)
	end
end

-- 获取logic unit数据(技能，buff，子弹，法术场等)
function GetLogicUnitData(data, isComplete)
	-- 技能数量
	data.SkillCount = Game.BSManager.runningSkillCount
	-- buff数量
	data.BuffCount = Game.BSManager.runningBuffCount
	-- todo 子弹数量
	-- todo 陷阱光环法术场数量 
end

-- 获取表现对象数据（特效，mesh，ghost，宠物，音效）
function GetViewObjectData(data, isComplete)
	-- 特效数量
	data.EffectCount = table.count(Game.EffectManager.NiagaraEffectParams)
	-- 音效数量
	data.AudioCount = Game.WorldManager.ViewBudgetMgr:GetRequestSuccessCount(VIEW_FREQUENCY_LIMIT_TAG.ATTACK_SOUND) + 
		Game.WorldManager.ViewBudgetMgr:GetRequestSuccessCount(VIEW_FREQUENCY_LIMIT_TAG.LOCO_SOUND)
	Game.WorldManager.ViewBudgetMgr:ClearRequestSuccess(VIEW_FREQUENCY_LIMIT_TAG.ATTACK_SOUND)
	Game.WorldManager.ViewBudgetMgr:ClearRequestSuccess(VIEW_FREQUENCY_LIMIT_TAG.LOCO_SOUND)
	-- Ghost数量
	data.GhostCount = table.count(Game.BSManager.RunningActorMap["A_GhostActor"] and Game.BSManager.RunningActorMap["A_GhostActor"] or {})
	-- 受击数量
	data.HitAdditivePerformCount = Game.WorldManager.ViewBudgetMgr:GetRequestSuccessCount(VIEW_FREQUENCY_LIMIT_TAG.HIT_ADDITIVE_PERFORM)
	-- 跳字数量
	data.DamageShowCount = #Game.DamageEffectSystem.DamageQueue
	-- 材质数量
	data.MaterialChangeCount = table.count(Game.MaterialManager.ChangeMaterialRequests)
	-- todo动画缓存池数量
	
end