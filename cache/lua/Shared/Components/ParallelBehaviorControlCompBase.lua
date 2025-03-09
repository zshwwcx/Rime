---
--- Created by sunya.
-- locomotion层和Action层的逻辑行为层控制结构, 可并行执行, 也有互斥约束;
---

-- 先理顺逻辑上的并行后， 再去控制表现层

-- 技能/受击/使用道具/...各业务系统尝试触发行为:
-- 1) 各行为系统入口: 先进行系统内部的资源消耗、非行为层的玩法状态检查； 例如:血量、魔量
-- 2) 行为层约束请求接口: 会内部进行行为层的互相约束检查 : 例如: 攀爬上墙过程中无法放技能
-- 3) 行为层执行器执行: 入口是一个状态机, 提供状态机层面、状态层面的进入管控接口, 简单逻辑可以直接写到状态里, 复杂的数据驱动功能可以持有例如 技能/受击执等行器，

-- 行为执行结束, 分逻辑正常执行完毕结束、被打断两种情况, 提供结束原因, 方便逻辑退出状态机时的数据正确清理：
-- 1) 如果逻辑有明显控制下一状态, 那么走状态交换接口
-- 2) 如果逻辑没有没有明显控制状态， 走回默认状态， 且默认状态下会进行一些自动跳转（这个要显示进行代码聚拢, 写最肮的逻辑) ; 例如: 飞行技能被打断后, 要进入跌落状态; 飞行过程中死亡(isAlive为false了, 但是行为层不能做死亡表现)，但空中要下落, 下落之后再死亡行为
-- 目标是能够逻辑内聚再一起, 而且能够把链接关系清晰的进行处理

local parallelBehaviorControlConst = kg_require("Shared.Const.ParallelBehaviorControlConst")
local PARALLEL_BEHAVIOR_CONST = parallelBehaviorControlConst.PARALLEL_BEHAVIOR_CONST

local AbilityConst = kg_require("Shared.Const.AbilityConst")
local EDSRID = AbilityConst.EDisableSkillRequestID

local PB_CONSTRAINT_PASS = 1 -- 约束通过, 允许跳转
local PB_CONSTRAINT_NOT_PASS = 0 -- 约束不通过, 限制跳转



ParallelBehaviorControlCompBase = DefineComponent("ParallelBehaviorControlCompBase")

function ParallelBehaviorControlCompBase:ctor()
	-- Property
	-- LocoType: Locomotion的状态标志位
	-- ActionType: Action层的状态标志位
	-- Property End
	
	-- 1. locomotion层可以根据配表进行基础重力、感知...等等开关的控制， 这一层locomotion控制直接封到这里
	-- 2. Action层 执行器可以是ability, 可以是自己写的状态机, 这里提供执行黑盒的进入、退出、打断等接口协议, 各个逻辑按照接口协议实现
	-- 3. locomotion与Action有行为层的约束检测, 统一封到这里； 而诸如技能、使用物品等逻辑则是在各自的逻辑系统中先检查逻辑条件, 然后再来请求行为执行; 直接二维表数据控制关系
	-- 4. 在3的基础上, 提供locomotion和action的Giveupable机制, 用于主动操控下放弃当前行为, 可以允许进入下一行为。注意这个与被动的Interruptable不一样, 后者是被动的、会被强制执行的,但是一定要给出Interrupt原因

	self.PBC_DisableCastSkillNumber = 0
end 

function ParallelBehaviorControlCompBase:dtor()
end

-- 简单的基于ActionType的标记为行为约束关系检测接口
function ParallelBehaviorControlCompBase:CanParallelBehaviorTransfer(toBehaviorType)
	local toBehaviorTypeName = PARALLEL_BEHAVIOR_CONST[toBehaviorType]
	-- 传入的类型未定义, 直接不允许
	-- todo: 最好能够加一个开发期的assert逻辑 @sunya 20220222
	if toBehaviorTypeName == nil then
		return false
	end
	
	-- 这里客户端服务器共用, Table两边是有一定差异, 用这样的方式来挑选对应接口Module
	local tableDataModule = Game.TableData or TableData
	
	-- ======================1.检查Locomotion对目标行为的约束======================================
	if self.isAvatar then
		-- todo 这里直接在导表后处理做掉key变成int值 @sunya 20240222
		local parallelBCRDataUnderLocomotion = tableDataModule.GetParallelBehaviorConstraintRulesDataRow(self.LocoType)
		-- 注意: 没有配置, 直接失败
		if parallelBCRDataUnderLocomotion == nil then
			return false
		end

		-- 目前BStateType是全局唯一的, 所以先可以直接用BehaviorStateType来判断就行 
		local checkLocomotionResult = parallelBCRDataUnderLocomotion[toBehaviorTypeName]
		
		if checkLocomotionResult ~= PB_CONSTRAINT_PASS then
			return false
		end
	end

	-- ===================================2.检查Action对目标行为的约束======================================
	-- Action 是空闲的, 那么没有约束
	if self.ActionType == PARALLEL_BEHAVIOR_CONST.A_LEISURE then
		return true
	end

	-- 当前action是否实在可放弃阶段, 例如 后摇
	local parallelBCRDataUnderAction = tableDataModule.GetParallelBehaviorConstraintRulesDataRow(self.ActionType)
	-- 没有配置, 直接失败
	if parallelBCRDataUnderAction == nil then
		return false
	end

	local checkActionResult = PB_CONSTRAINT_PASS
	checkActionResult = parallelBCRDataUnderAction[toBehaviorTypeName]
	if checkActionResult == PB_CONSTRAINT_PASS then
		return true
	end

	return false
end

-- 判断是否静止（没有locomotion，也没有技能的纯IDLE）
function ParallelBehaviorControlCompBase:PBC_IsInIdle()
	return self.LocoType == PARALLEL_BEHAVIOR_CONST.L_IDLE and self.ActionType == PARALLEL_BEHAVIOR_CONST.A_LEISURE
end

-- 判断是否处于移动中
function ParallelBehaviorControlCompBase:PBC_IsMoving(GivenType)
	if not GivenType then
		GivenType = self.LocoType
	end
	-- 移动
	if (GivenType == PARALLEL_BEHAVIOR_CONST.L_MOVE) then
		return true
	end

	-- 转向
	if (GivenType == PARALLEL_BEHAVIOR_CONST.L_MOVE_TURN) then
		return true
	end

	-- 冲刺
	if (GivenType == PARALLEL_BEHAVIOR_CONST.L_DODGE) then
		return true
	end

	-- 坠落
	if (GivenType == PARALLEL_BEHAVIOR_CONST.L_DROPPING) then
		return true
	end

	return false
end

-- 判断是否处于跳跃
function ParallelBehaviorControlCompBase:PBC_IsJumping(GivenType)
	if not GivenType then
		GivenType = self.LocoType
	end
	return GivenType == PARALLEL_BEHAVIOR_CONST.L_JUMP
end

-- 判断是否处于技能释放中
function ParallelBehaviorControlCompBase:PBC_IsCastingSkill(GivenType)
	if not GivenType then
		GivenType = self.ActionType
	end
	-- 地面战斗
	if (GivenType == PARALLEL_BEHAVIOR_CONST.A_SKILL_GBATTLE) then
		return true
	end

	-- 地面解控
	if (GivenType == PARALLEL_BEHAVIOR_CONST.A_SKILL_GRCONTROL) then
		return true
	end

	-- 处刑表演
	if (GivenType == PARALLEL_BEHAVIOR_CONST.A_SKILL_INSTAGGER) then
		return true
	end

	-- 可并行技能
	if (GivenType == PARALLEL_BEHAVIOR_CONST.A_SKILL_PARALLEL) then
		return true
	end

	-- 空中可释放的技能
	if (GivenType == PARALLEL_BEHAVIOR_CONST.A_SKILL_AIR) then
		return true
	end

	return false
end

-- 停止玩家的技能释放行为
function ParallelBehaviorControlCompBase:PBC_StopPlayerCastSkill()
	if (self.CancelAllSkill ~= nil) then
		-- 停止理由：ERequestCancelSkillReason.Proaction
		self:CancelAllSkill(3)
	end
end


-- 状态冲突自己做计数管理，不再把计数更新到锁中。
-- 仅用于状态冲突调用，禁用玩家的移动行为
function ParallelBehaviorControlCompBase:PBC_DisablePlayerMovement(InDisable)
	if (self.DisableLocoMove ~= nil) then
		self:DisableLocoMove(Enum.ELocoControlTag.ConflictState, InDisable, false, true)
	end
end

-- 仅用于状态冲突调用，禁用玩家的跳跃行为
function ParallelBehaviorControlCompBase:PBC_DisablePlayerJump(InDisable)
	if (self.DisableLocoJump ~= nil) then
		self:DisableLocoJump(Enum.ELocoControlTag.ConflictState, InDisable, false, ETE.EDisabledSkillReason.StateConflict, true)
	end
end

-- 仅用于状态冲突调用，禁用玩家的技能释放行为
function ParallelBehaviorControlCompBase:PBC_DisablePlayerCastSkill(InDisable)
	local OldValue = self.PBC_DisableCastSkillNumber
	
	if (InDisable == true) then
		self.PBC_DisableCastSkillNumber = 1
	else
		self.PBC_DisableCastSkillNumber = 0
	end

	local NewValue = self.PBC_DisableCastSkillNumber

	if (OldValue <= 0) and (NewValue > 0) then
		if (self.DisableAllSkillType ~= nil) then
			self:DisableAllSkillType(ETE.EDisabledSkillReason.StateConflict)
		end
	elseif (OldValue > 0) and (NewValue <= 0) then
		if (self.EnableAllSkillType ~= nil) then
			self:EnableAllSkillType(ETE.EDisabledSkillReason.StateConflict)
		end
	end
end

function ParallelBehaviorControlCompBase:SetActionTypeToDefault()
	self:SetActionType(PARALLEL_BEHAVIOR_CONST.A_LEISURE)
end

function ParallelBehaviorControlCompBase:SetActionType(InActionType)
	if self == Game.me and InActionType ~= self.ActionType then
		Game.EventSystem:PublishBehavior(_G.EEventTypes.SKILLHUD_DISABLE_SKILL, self.eid)
		Game.StateConflictManager:CheckOnStateChange({Enum.EStateConflictAction.CastCombatSkill,}, self.ActionType, InActionType)
	end
	self.ActionType = InActionType
end

function ParallelBehaviorControlCompBase:GetActionType()
	return self.ActionType
end
-- =============================================只有客户端用=================================================
function ParallelBehaviorControlCompBase:__component_AppendGamePlayDebugInfo__(debugInfos)
	table.insert(debugInfos, "<Title_Red>[ParallelControlComponent]</>")
	table.insert(debugInfos, string.format('LocoType:%s  ActionType:%s ',self.LocoType, self.ActionType))
	table.insert(debugInfos, string.format("HasLocoGroundSupport:%s",self:GetHasLocoGroundSupport()))
	return true
end

function ParallelBehaviorControlCompBase:set_ActionType(Entity, NewValue, OldValue)
	if Entity == Game.me and NewValue ~= OldValue then
		Game.EventSystem:PublishBehavior(_G.EEventTypes.SKILLHUD_DISABLE_SKILL, self.eid)
	end
end

return ParallelBehaviorControlCompBase