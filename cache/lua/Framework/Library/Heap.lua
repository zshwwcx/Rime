local LSLHeap= DefineClass("LSLHeap")

local function ctor(self, Cmp)
    if not _G.IsCallable(Cmp) then
        Log.Warning("LSTHeap.__init => Cmp is not callable")
        return
    end

    self._data = {}

    self._cmp = Cmp
end

local function dtor(self)
    self._data = {}

    self._cmp = nil
end

local function Swap(self, LIndex, RIndex)
    self._data[LIndex], self._data[RIndex] = self._data[RIndex], self._data[LIndex]
end

local function HeapSiftUp(self, Index)
    while Index > 1 do
        local Parent = math.floor(Index / 2)

        if not self._cmp(self._data[Index], self._data[Parent]) then
            break
        end

        Swap(self, Index, Parent)

        Index = Parent
    end
end

local function HeapSiftDown(self, Index)
    if Index >= self:Num() then
        return
    end

    while true do
        local Min = Index

        local Child = 2 * Index

        for i = Child, Child + 1 do
            if i <= self:Num() and self._cmp(self._data[i], self._data[Min]) then
                Min = i
            end
        end

        if Min == Index then
            break
        end

        Swap(self, Index, Min)

        Index = Min
    end
end

local function HeapPush(self, Element)
    table.insert(self._data, self:Num() + 1, Element)

    HeapSiftUp(self, self:Num())
end

local function HeapPop(self)
    if not self:IsEmpty() then
        self._data[1] = self._data[self:Num()]

        table.remove(self._data, self:Num())

        HeapSiftDown(self, 1)
    end
end

local function HeapRemoveAt(self, Index)
    if Index > 0 and self:Num() >= Index then
        table.remove(self._data, Index)

        HeapSiftDown(self, 1)

        return true
    end

    return false
end

local function Empty(self)
    self._data = {}

    self._cmp = nil
end

local function HeapTop(self)
    if not self:IsEmpty() then
        return self._data[1]
    end

    return nil
end

local function Find(self, Data)
    for i = 1, self:Num() do
        if self._data[i] == Data then
            return i
        end
    end

    return -1
end

local function Num(self)
    return #self._data
end

local function IsEmpty(self)
    return self:Num() == 0
end

local function FindByIndex(self, Index)
    if not self:IsEmpty() and Index > 0 then
        if Num(self) >= Index then
            return self._data[Index]
        end
    end
    return nil
end

LSLHeap.ctor = ctor
LSLHeap.dtor = dtor
LSLHeap.HeapPush = HeapPush
LSLHeap.HeapPop = HeapPop
LSLHeap.HeapRemoveAt = HeapRemoveAt
LSLHeap.Empty = Empty
LSLHeap.HeapTop = HeapTop
LSLHeap.Find = Find
LSLHeap.Num = Num
LSLHeap.IsEmpty = IsEmpty
LSLHeap.FindByIndex = FindByIndex
return LSLHeap
