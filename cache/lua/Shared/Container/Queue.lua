local string_format = string.format
local math_floor = math.floor
DefineClass("Queue")

--- @class Queue
function Queue:ctor()
    self.data = {}
    self.head = 1
    self.tail = 0
    self.length = 0
end

function Queue:push(val)
    self.tail = self.tail + 1
    self.data[self.tail] = val
    self.length = self.length + 1
end

function Queue:empty()
    return self.head > self.tail
end

function Queue:pop()
    assert(not self:empty(), string_format("pop error %d %d", self.head, self.tail))
    local val = self.data[self.head]
    self.data[self.head] = nil
    self.head = self.head + 1
    self.length = self.length - 1
    return val
end

function Queue:front()
    assert(not self:empty(), string_format("front error %d %d", self.head, self.tail))
    return self.data[self.head]
end

function Queue:size()
    return self.length
end

function Queue:atIndex(index)
    if self.head + index - 1 > self.tail then
        LOG_ERROR(string.format("index is larger than length, index: %d length: %d ", index, self.length))
        return
    end
    return self.data[self.head + index - 1]
end

DefineClass("CircularQueue")

function CircularQueue:ctor(maxSize)
    self.maxSize = maxSize + 1
    self.data = {}
    self.front = 1
    self.rear = 1
end

function CircularQueue:push(data)
    if self:isFull() then
        self.data[self.front] = nil
        self.front = (self.front + 1) % self.maxSize
    end

    self.data[self.rear] = data
    self.rear = (self.rear + 1) % self.maxSize
end

function CircularQueue:pop()
    if self:isEmpty() then
        return
    end

    local value = self.data[self.front]
    self.data[self.front] = nil

    self.front = (self.front + 1) % self.maxSize

    return value
end

function CircularQueue:isEmpty()
    return self.front == self.rear
end

function CircularQueue:isFull()
    return (self.rear + 1) % self.maxSize == self.front
end

function CircularQueue:size()
    return ((self.rear - self.front) + self.maxSize) % self.maxSize
end

function CircularQueue:getDataRef()
    return self.data
end

function CircularQueue:clearDataByIndex(index)
    if index < 0 or index > (self.maxSize - 1) then
        return
    end

    self.data[index] = nil
end

function CircularQueue:clear()
    self.data = {}
    self.front = 1
    self.rear = 1
end

-- 优先队列 小顶堆
DefineClass("PriorityQueue")
function PriorityQueue:ctor()
    self.data = {}
    self.length = 0
end

function PriorityQueue:exchangeElement(indexA, indexB)
    if (indexA < 1 or indexA > self.length or indexB < 1 or indexB > self.length) then
        return
    end

    local data = self.data
    local temp = data[indexA]
    data[indexA] = data[indexB]
    data[indexB] = temp
end

function PriorityQueue:isEmpty()
    return self.length == 0
end

function PriorityQueue:size()
    return self.length
end

function PriorityQueue:checkCanSwin(childIndex, parentIndex)
    if childIndex <= 1 then
        return
    end
    local data = self.data
    local elementA = data[childIndex]
    local elementB = data[parentIndex]
    return elementA.value < elementB.value
end

function PriorityQueue:swin(index)
    local parentIndex = math_floor(index / 2)
    while(index > 1 and self:checkCanSwin(index, parentIndex)) do
        self:exchangeElement(index, parentIndex)
        index = parentIndex
        parentIndex = math_floor(index / 2)
    end
end

function PriorityQueue:sink(index)
    local data = self.data
    while index * 2 <= self.length do
        local childIndex = index * 2
        if childIndex < self.length and data[childIndex].value < data[childIndex + 1].value then
            childIndex = childIndex + 1
        end

        if data[index].value > data[childIndex].value then
            self:exchangeElement(index, childIndex)
            index = childIndex
        else
            break
        end
    end
end

function PriorityQueue:insert(element)
    self.length = self.length + 1
    local newLength = self.length
    self.data[newLength] = element
    self:swin(newLength)
end

function PriorityQueue:peekTop()
    return self.length >= 1 and self.data[1]
end

function PriorityQueue:popTop()
    local currentLength = self.length
    if currentLength <= 0 then
        return
    end
    local minElement = self.data[1]
    self:exchangeElement(1, currentLength)
    self.length = currentLength - 1
    self:sink(1)
    return minElement
end