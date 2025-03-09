-- 防止重复创建同名类
if (_G.PriorityQueueBase ~= nil) then
    return _G.PriorityQueueBase
end

local PriorityQueueElementBase = require("Shared.PriorityQueue.PriorityQueueElementBase")

local PriorityQueueBase = DefineClass("PriorityQueueBase")



-- region Important
function PriorityQueueBase:ctor(InElementClass)
    -- 有序的优先级队列
    self.PriorityElementList = {}

    -- 激活的优先级数量
    self.ActivatePriorityNum = 1

    -- ElementClass
    self.ElementClass = InElementClass or PriorityQueueElementBase
    
    -- 待使用的ElementPool
    self.ElementPool = {}
    self.ElementPoolSize = 5
end

function PriorityQueueBase:dtor()
    self.PriorityToElementList = nil
    self.ActivatePriorityNum = nil
    self.ElementClass = nil
    self.ElementPool = nil
end
-- endregion Important



-- region PrivateAPI
function PriorityQueueBase:AddElement(InElement)
    if not self:CanAddElement(InElement) then
        return false
    end

    for Index, Element in ipairs(self.PriorityElementList) do
        -- 相同Priority按照事件依次向后排序
        if InElement.Priority > Element.Priority then
            self:_InnerAddElement(InElement, Index)
            return true
        end
    end

    self:_InnerAddElement(InElement)
    return true
end

function PriorityQueueBase:RemoveElement(InElement)
    if not self:CanRemoveElement(InElement) then
        return false
    end

    for Index, Element in ipairs(self.PriorityElementList) do
        if Element == InElement then
            self:_InnerRemoveElement(Index)
            return true
        end
    end

    return false
end

function PriorityQueueBase:RemoveElementByIndex(InIndex)
    if not self:CanRemoveElement(self.PriorityElementList[InIndex]) then
        return false
    end

    self:_InnerRemoveElement(InIndex)
    return true
end

function PriorityQueueBase:CanAddElement(InElement)
    if InElement == nil then
        return false
    end

    return true
end

function PriorityQueueBase:CanRemoveElement(InElement)
    if InElement == nil then
        return false
    end

    return true
end

function PriorityQueueBase:ActivateElement(InElement)
    if self:CanActivateElement(InElement) == true then
        self:_InnerActivateElement(InElement)
        return true
    end

    return false
end

function PriorityQueueBase:DeActivateElement(InElement)
    if self:CanDeActivateElement(InElement) == true then
        self:_InnerDeActivateElement(InElement)
        return true
    end

    return false
end

function PriorityQueueBase:CanActivateElement(InElement)
    if InElement == nil or InElement:IsActivate() == true then
        return false
    end

    for i = 1, self.ActivatePriorityNum do
        if InElement == self.PriorityElementList[i] then
            return true
        end
    end

    return false
end

function PriorityQueueBase:CanDeActivateElement(InElement)
    if InElement == nil or InElement:IsActivate() == false then
        return false
    end

    for i = 1, self.ActivatePriorityNum do
        if InElement == self.PriorityElementList[i] then
            return false
        end
    end

    return true
end
-- endregion PrivateAPI



-- region Pool 
function PriorityQueueBase:GetElement(InInstigator, InPriority, ...)
    if #self.ElementPool > 0 then
        local OutElement = self.ElementPool[#self.ElementPool]
        table.remove(self.ElementPool, #self.ElementPool)

        OutElement.Instigator = InInstigator
        OutElement.Priority = InPriority
        OutElement:Init(...)
        return OutElement
    else
        return self.ElementClass.new(InInstigator, InPriority, ...)
    end
end

function PriorityQueueBase:ReturnElement(InElement)
    if #self.ElementPool < self.ElementPoolSize then
        table.insert(self.ElementPool, InElement)
    else
        InElement = nil
    end
end
-- endregion Pool



-- region Private
function PriorityQueueBase:_InnerAddElement(InElement, Index)
    if Index ~= nil then
        if Index <= self.ActivatePriorityNum then
            -- 插入需要激活的项目后，需要先失活原队末项目，再激活新加入的需要激活项目
            local ElementToDeActive = self.PriorityElementList[self.ActivatePriorityNum]
            
            table.insert(self.PriorityElementList, Index, InElement)
            InElement:OnAdd(self)

            self:DeActivateElement(ElementToDeActive)
            self:_InnerActivateElement(InElement)
        else
            -- 无需激活
            table.insert(self.PriorityElementList, Index, InElement)
            InElement:OnAdd(self)
        end
    else
        -- Index为空，认为加入队尾
        local CurrentIndex = #self.PriorityElementList + 1
        table.insert(self.PriorityElementList, InElement)
        InElement:OnAdd(self)
        
        if CurrentIndex <= self.ActivatePriorityNum then
            self:_InnerActivateElement(InElement)
        end
    end
end

function PriorityQueueBase:_InnerRemoveElement(Index)
    -- 移除已激活的项目，则先失活该激活项目，再激活队末需要激活项目
    if Index <= self.ActivatePriorityNum then
        local ElementToRemove = self.PriorityElementList[Index]
        self:_InnerDeActivateElement(ElementToRemove)
        table.remove(self.PriorityElementList, Index)
        ElementToRemove:OnRemove()
        self:ReturnElement(ElementToRemove)

        self:ActivateElement(self.PriorityElementList[self.ActivatePriorityNum])

        return
    end

    local ElementToRemove = self.PriorityElementList[Index]
    table.remove(self.PriorityElementList, Index)
    ElementToRemove:OnRemove()
    self:ReturnElement(ElementToRemove)
end

function PriorityQueueBase:_InnerActivateElement(InElement)
    self:ActivateElement_Impl(InElement)

    InElement:OnActivated()
end

function PriorityQueueBase:_InnerDeActivateElement(InElement)
    self:DeActivateElement_Impl(InElement)

    InElement:OnDeActivated()
end
-- endregion Private



-- region Public
function PriorityQueueBase:SimpleAddElement(InInstigator, InPriority, ...)
    for index, Element in ipairs(self.PriorityElementList) do
        if Element.Instigator == InInstigator then
            self:RemoveElement(Element)
        end
    end

    return self:AddElement(self:GetElement(InInstigator, InPriority, ...))
end

function PriorityQueueBase:SimpleRemoveElement(InInstigator)
    for index, Element in ipairs(self.PriorityElementList) do
        if Element.Instigator == InInstigator then
            return self:RemoveElementByIndex(index)
        end
    end

    return false
end

function PriorityQueueBase:ClearElements()
    for i = #self.PriorityElementList, 1, -1 do
        self:RemoveElementByIndex(i)
    end
end

function PriorityQueueBase:Peek()
	if  #self.PriorityElementList > 0 then
		return self.PriorityElementList[1].Instigator
	end
end
-- endregion Public



-- region ToOverride
function PriorityQueueBase:ActivateElement_Impl(InElement)
    -- Example
    -- print("Hello World", table.unpack(InElement.DataBuffer))
end

function PriorityQueueBase:DeActivateElement_Impl(InElement)
    -- Example
    -- print("GoodBye MyLover", table.unpack(InElement.DataBuffer))
end
-- endregion ToOverride


return PriorityQueueBase