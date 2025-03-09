
---@class UITreeViewData
local UITreeViewData = DefineClass("UITreeViewData")

function UITreeViewData:ctor()
    self.children = {}  ---@type table<integer, UITreeViewChildData>
end

---@param data table 任意类型数据
---@return UITreeViewChildData
function UITreeViewData:NewUITreeViewChildData(data)
    return {tabData = data}
end

---@param data table 任意类型数据
---添加一级节点数据
function UITreeViewData:AddFirstNode(data)
    self.children[#self.children + 1] = self:NewUITreeViewChildData(data)
end

---@param firstIndex integer 一级列表下标
---@param data table 任意类型数据
---插入一级节点数据
function UITreeViewData:InsertFirstNode(firstIndex, data)
    table.insert(self.children, firstIndex, self:NewUITreeViewChildData(data))
end

---@param firstIndex integer 一级列表下标
---删除一级节点数据
function UITreeViewData:RemoveFirstNode(firstIndex)
    table.remove(self.children, firstIndex)
end

---@param firstIndex integer 一级列表下标
---@param secondIndex integer 二级列表下标
---@param data table
---添加二级节点数据
function UITreeViewData:AddTwoNode(firstIndex, data)
    self.children[firstIndex] = self.children[firstIndex] or {children = {}}
    if not self.children[firstIndex].children then
        self.children[firstIndex].children = {}
    end
    self.children[firstIndex].children = self.children[firstIndex].children or {}
    local datas = self.children[firstIndex].children
    datas[#datas + 1] =self:NewUITreeViewChildData(data)
end

---@param firstIndex integer 一级列表下标
---@param secondIndex integer 二级列表下标
---@param data table
---插入二级节点数据
function UITreeViewData:InsertTwoNode(firstIndex, secondIndex, data)
    self.children[firstIndex] = self.children[firstIndex] or {children = {}}
    if not self.children[firstIndex].children then
        self.children[firstIndex].children = {}
    end
    self.children[firstIndex].children = self.children[firstIndex].children or {}
    table.insert(self.children[firstIndex].children, secondIndex,  self:NewUITreeViewChildData(data))
end

---@param firstIndex integer 一级列表下标
---@param secondIndex integer 二级列表下标
---删除二级节点数据
function UITreeViewData:RemoveTwoNode(firstIndex, secondIndex)
    if not self.children[firstIndex] then
        Log.WarningFormat("UITreeViewData:RemoveTwoNode, FirstChildren is nil")
		return 
    end
    local datas = self.children[firstIndex].children
    if not datas then
        Log.WarningFormat("UITreeViewData:RemoveTwoNode, TwoChildren is nil")
		return
    end
    table.remove(datas, secondIndex)
end


---@param firstIndex integer 一级列表下标
---@param secondIndex integer 二级列表下标
---@param threeIndex integer 三级列表下标
---@param data table
---添加三级节点数据
function UITreeViewData:AddThreeNode(firstIndex, secondIndex, data)
    if not self.children[firstIndex] then
        Log.WarningFormat("UITreeViewData:AddThreeNode, FirstChildren is nil")
		return 
    end
    if not self.children[firstIndex].children then
        Log.WarningFormat("UITreeViewData:AddThreeNode, TwoChildren is nil")
		return
    end
    local datas = self.children[firstIndex].children[secondIndex].children or {}
    self.children[firstIndex].children[secondIndex].children = datas
    datas[#datas + 1] = self:NewUITreeViewChildData(data)
end

---@param firstIndex integer 一级列表下标
---@param secondIndex integer 二级列表下标
---@param threeIndex integer 三级列表下标
---@param data table
---插入三级节点数据
function UITreeViewData:InsertThreeNode(firstIndex, secondIndex, threeIndex, data)
    if not self.children[firstIndex] then
        Log.WarningFormat("UITreeViewData:InsertThreeNode, FirstChildren is nil")
		return
    end
    if not self.children[firstIndex].children then
        Log.WarningFormat("UITreeViewData:InsertThreeNode, TwoChildren is nil")
		return
    end
    local datas = self.children[firstIndex].children[secondIndex].children or {}
    self.children[firstIndex].children[secondIndex].children = datas
    table.insert(datas, threeIndex,  self:NewUITreeViewChildData(data))
end

---@param firstIndex integer 一级列表下标
---@param secondIndex integer 二级列表下标
---@param threeIndex integer 三级列表下标
---删除三级节点数据
function UITreeViewData:RemoveThreeNode(firstIndex, secondIndex, threeIndex)
    if not self.children[firstIndex] then
        Log.WarningFormat("UITreeViewData:RemoveThreeNode, FirstChildren is nil")
		return
    end
    if not self.children[firstIndex].children then
        Log.WarningFormat("UITreeViewData:RemoveThreeNode, TwoChildren is nil")
		return
    end
    local datas = self.children[firstIndex].children[secondIndex].children
    if not datas then
        Log.WarningFormat("UITreeViewData:RemoveThreeNode, ThreeChildren is nil")
        return
    end
    table.insert(datas, threeIndex)
end
return UITreeViewData