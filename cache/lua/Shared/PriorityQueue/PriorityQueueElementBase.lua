-- 防止重复创建同名类
if (_G.PriorityQueueElementBase ~= nil) then
    return _G.PriorityQueueElementBase
end

local PriorityQueueElementBase = DefineClass("PriorityQueueElementBase")



-- region Important
function PriorityQueueElementBase:ctor(InInstigator, InPriority, ...)
    self._bActivated = false
    
    -- 优先级
    self.Priority = InPriority

    -- 所在的队列
    self.OwnerQueue = nil

    -- 该优先级Element的申请者（目前认为一个队列中，一个申请者只能有一个Element）
    -- 也可以理解为该Element的Key
    self.Instigator = InInstigator

    self:Init(...)
end

function PriorityQueueElementBase:dtor()
    self.Priority = nil
    self.OwnerQueue = nil
    self.DataBuffer = nil
end

function PriorityQueueElementBase:Init(...)
    -- 涉及的数据
    self.DataBuffer = table.pack(...)
end
-- endregion Important



-- region API
function PriorityQueueElementBase:OnAdd(InParentQueue)
    self.OwnerQueue = InParentQueue
end

function PriorityQueueElementBase:OnRemove()
    if self:IsActivate() == true then
        self:OnDeActivated()
    end

    self.OwnerQueue = nil
end

function PriorityQueueElementBase:OnActivated()
    self._bActivated = true
end

function PriorityQueueElementBase:OnDeActivated()
    self._bActivated = false
end

function PriorityQueueElementBase:IsActivate()
    return self._bActivated
end
-- endregion API



return PriorityQueueElementBase