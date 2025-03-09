local LQueue= DefineClass("LQueue")

function LQueue:ctor()
    self.Queue = {
        First = 0,
        Last = -1
    }
end

function LQueue:dtor()
    self.Queue = nil
end

function LQueue:PushLeft(Value)
    local Queue = self.Queue
    local First = Queue.First - 1
    Queue.First = First
    Queue[First] = Value
end

function LQueue:PushRight(Value)
    local Queue = self.Queue
    local Last = Queue.Last + 1
    Queue.Last = Last
    Queue[Last] = Value
end

function LQueue:PopLeft()
    local Queue = self.Queue
    local First = Queue.First
    if First > Queue.Last then
        Log.Warning("LQueue:PopLeft, Queue is empty")
    end
    local Value = Queue[First]
    Queue[First] = nil -- to allow garbage collection
    Queue.First = First + 1
    return Value
end

function LQueue:PopRight()
    local Queue = self.Queue
    local Last = Queue.Last
    if Queue.First > Last then
        Log.Warning("LQueue:PopRight, Queue is empty")
    end
    local Value = Queue[Last]
    Queue[Last] = nil -- to allow garbage collection
    Queue.Last = Last - 1
    return Value
end

LQueue.Enqueue = LQueue.PushRight
LQueue.Dequeue = LQueue.PopLeft

function LQueue:Count()
    local Queue = self.Queue
    return Queue.Last - Queue.First + 1
end

function LQueue:Peek()
    local Queue = self.Queue
    if Queue.First > Queue.Last then
        Log.Warning("LQueue:Peak, Queue is empty")
        return nil
    end
    return Queue[Queue.First]
end

function LQueue:Clear()
    self.Queue = {
        First = 0,
        Last = -1
    }
end

function LQueue:IsEmpty()
    local Queue = self.Queue
    if Queue.First > Queue.Last then
        return true
    end
    return false
end

local RawNew = LQueue.new
LQueue.new = function(...)
    local NewObj = RawNew(...)
    local MT = getmetatable(NewObj)
    MT.__pairs = function(T)
        -- Log.Debug("__pairs")
        local function Next(TB, Index)
            -- Log.Debug(Index,TB.First)
            -- Index = Index or TB.Queue.First
            local Value = TB.Queue[Index]
            Index = Index + 1
            if Value then
                return Index, Value
            end
        end
        return Next, T, T.Queue.First
    end
    return NewObj
end


return LQueue
