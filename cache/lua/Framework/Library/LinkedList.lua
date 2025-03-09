---@class LinkedListNode
---@field Prev LinkedListNode?
---@field Next LinkedListNode?
---@field Key any
---@field Value any

---@class LinkedList 增强链表
---@field iteratorNode LinkedListNode? 用于递归的节点
local LinkedList = DefineClass("LinkedList")

---@public iterator 迭代器
---建议使用这个而不是直接用iteratorNode遍历LinkedList
---但是如果是高频场景（比如tick里递归），为了降低闭包创建，可以使用iteratorNode
---@param linkedList LinkedList
function LinkedList.iterator(linkedList)
	linkedList.iteratorNode = linkedList.headNode
	return function()
		if linkedList.iteratorNode then
			local result = linkedList.iteratorNode
			linkedList.iteratorNode = result.Next
			
			return result.Value
		end
	end
end

function LinkedList:ctor()
	---@type LinkedListNode
	self.headNode = nil
	---@type LinkedListNode
	self.tailNode = nil
	self.listLength = 0
	---@type table<any, LinkedListNode>
	self.keyValues = {}
	---@type LinkedListNode[]
	self.nodeCaches = {}
	---@type LinkedListNode
	self.iteratorNode = nil
end

---@public InsertNode 插入节点
---@param key any
---@param value any
---@param pos number? 默认插入尾部
function LinkedList:InsertNode(key, value, pos)
	if self.keyValues[key] then
		Log.Error("The linked list already has the same key, key: ", key)
		return
	end
	if pos == 0 or (pos ~= nil and (pos > self.listLength or pos + self.listLength < 0)) then
		Log.Error("Insertion position exception, pos: ", pos)
		return
	end
	local node = self:newNode(key, value)
	self.keyValues[key] = node
	if self.tailNode == nil and self.headNode == nil then
		self.listLength = self.listLength + 1
		self.tailNode = node
		self.headNode = node
		return
	end
	
	pos = pos == nil and self.listLength or (pos < 0 and pos + self.listLength + 1 or pos)
	if pos == self.listLength then
		local prevTailNode = self.tailNode
		prevTailNode.Next = node
		node.Prev = prevTailNode
		self.tailNode = node
	elseif pos == 1 then
		local prevHeadNode = self.headNode
		prevHeadNode.Prev = node
		node.Next = prevHeadNode
		self.headNode = node
	else
		local tmpNode = nil
		if pos < self.listLength / 2 then
			tmpNode = self.headNode
			for i = 1, pos - 2, 1 do
				tmpNode = tmpNode.Next
			end
		else
			tmpNode = self.tailNode
			for i = 1, self.listLength - pos + 1, 1 do
				tmpNode = tmpNode.Prev
			end
		end
		tmpNode.Next.Prev = node
		node.Next = tmpNode.Next
		tmpNode.Next = node
		node.Prev = tmpNode
	end
	self.listLength = self.listLength + 1
	self:updateIteratorNodeOnInsert(node)
end

---@private updateIteratorNodeOnRemove 在插入节点的时候更新迭代器节点
---@param node LinkedListNode
function LinkedList:updateIteratorNodeOnInsert(node)
	if node.Next == self.iteratorNode then
		self.iteratorNode = node
	end
end

---@public RemoveNodeByKey 移除指定key的节点
---@param key any
function LinkedList:RemoveNodeByKey(key)
	if not self.keyValues[key] then
		return
	end
	self.listLength = self.listLength - 1
	local node = self.keyValues[key]
	self:updateIteratorNodeOnRemove(node)

	if self.headNode == self.tailNode and self.headNode == node then
		self.headNode = nil
		self.tailNode = nil
	else
		if node == self.tailNode then
			self.tailNode = node.Prev
			node.Prev.Next = nil
		elseif node == self.headNode then
			self.headNode = node.Next
			node.Next.Prev = nil
		else
			node.Next.Prev = node.Prev
			node.Prev.Next = node.Next
		end
	end
	self:recycleNode(node)
end

---@public RemoveNodeByPos 移除指定位置的节点
---@param pos number
function LinkedList:RemoveNodeByPos(pos)
	local node = self:getNodeByPos(pos)
	if node and not self:emptyHeadAndTail() then
		self:updateIteratorNodeOnRemove(node)
		if node == self.headNode then
			self.headNode.Next.Prev = nil
			self.headNode = self.headNode.Next
		elseif node == self.tailNode then
			self.tailNode.Prev.Next = nil
			self.tailNode = self.tailNode.Prev
		else
			node.Prev.Next = node.Next
			node.Next.Prev = node.Prev
		end
		self:recycleNode(node)
		self.listLength = self.listLength - 1
	end
end

---@private emptyHeadAndTail 处理下链表为空或者头尾节点相同的特殊情况 
function LinkedList:emptyHeadAndTail()
	if self.headNode == nil and self.tailNode == nil then
		return true
	end
	if self.headNode == self.tailNode then
		self:recycleNode(self.headNode)
		self.listLength = self.listLength - 1
		self.headNode = nil
		self.tailNode = nil
		return true
	end
end

---RemoveTail 移除尾节点
function LinkedList:RemoveTail()
	if self:emptyHeadAndTail() then
		return
	end
	self:updateIteratorNodeOnRemove(self.tailNode)
	local tmpTailNode = self.tailNode 
	self.tailNode.Prev.Next = nil
	self.tailNode = self.tailNode.Prev
	self:recycleNode(tmpTailNode)
	self.listLength = self.listLength - 1
end

---RemoveHead 移除头节点
function LinkedList:RemoveHead()
	if self:emptyHeadAndTail() then
		return
	end
	local tmpHeadNode = self.headNode
	self.headNode.Next.Prev = nil
	self.headNode = self.headNode.Next
	self:recycleNode(tmpHeadNode)
	self.listLength = self.listLength - 1
end

---@private updateIteratorNodeOnRemove 在移除节点的时候更新迭代器节点
---@param node LinkedListNode
function LinkedList:updateIteratorNodeOnRemove(node)
	if node == self.iteratorNode then 
		self.iteratorNode = node.Next
	end
end

---Contains 是否包含指定key的节点
---@param key any
function LinkedList:Contains(key)
	return self.keyValues[key] ~= nil
end

---@public GetTailNodeValue 获取尾节点数据
---@return any
function LinkedList:GetTailNodeValue()
	if self.tailNode then
		return self.tailNode.Value
	end
end

---@public GetHeadNode 获取头节点数据
---@return any
function LinkedList:GetHeadNodeValue()
	if self.headNode then
		return self.headNode.Value
	end
end

---@public GetValueByKey 获取指定key的节点数据
---@param key any
---@return any
function LinkedList:GetValueByKey(key)
	local node = self.keyValues[key]
	if node then
		return node.Value
	end
end

---@public GetValueByPos 获取指定位置的节点数据
---@param pos number
---@return any
function LinkedList:GetValueByPos(pos)
	local node = self:getNodeByPos(pos)
	if node then
		return node.Value
	end
end

---@private getNodeByPos 获取指定位置的节点
---@param pos number 负数的话从尾部向前计数，-1==length
---@return LinkedListNode
function LinkedList:getNodeByPos(pos)
	if pos == nil then
		Log.Error("pos cannot be nil")
		return
	end
	if pos < 0 then
		pos = self.listLength + pos + 1
	end
	if pos < 1 then
		Log.Error("target pos don't exist")
		return
	end
	
	---@type LinkedListNode
	local targetNode = nil
	if pos <= self.listLength / 2 then
		targetNode = self.headNode
		for _ = 1, pos - 1, 1 do
			targetNode = targetNode.Next
		end
	else
		targetNode = self.tailNode
		for _ = 1, self.listLength - pos, 1 do
			targetNode = targetNode.Prev
		end
	end
	return targetNode
end

---@public GetLength 获取链表长度
---@return number
function LinkedList:GetLength()
	return self.listLength
end

---@private newNode 创建一个node
---@param key any
---@param value any
---@return LinkedListNode
function LinkedList:newNode(key, value)
	local count = #self.nodeCaches 
	if count == 0 then
		return {Prev = nil, Next = nil, Key = key, Value = value}
	else
		local node = self.nodeCaches[count]
		table.remove(self.nodeCaches, count)
		node.Key = key
		node.Value = value
		return node
	end
end

---@private recycleNode 回收一个Node
---@param node LinkedListNode
function LinkedList:recycleNode(node)
	local count = #self.nodeCaches
	self.keyValues[node.Key] = nil
	node.Prev = nil
	node.Next = nil
	node.Key = nil
	node.Value = nil
	self.nodeCaches[count + 1] = node
end

return LinkedList