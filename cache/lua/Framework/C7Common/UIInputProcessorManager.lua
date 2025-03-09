local EInputEvent = import("EInputEvent")
---@class UIInputProcessorManager
UIInputProcessorManager = DefineClass("UIInputProcessorManager")

function UIInputProcessorManager:Init()
    -- 初始化C++管理器
    self.cppMgr = import("C7UIInputProcessorManager")(Game.WorldContext)
	Game.GameInstance:CacheManager(self.cppMgr)
    self.cppMgr:NativeInit()
    
    -- 按键输入回调
    self.onKeyInputProcessorNotify = self.cppMgr.OnGetKeyEventDelegate:Bind(
        function(keyName, inputEvent) return self:OnKeyInputProcessor(keyName, inputEvent) end
    )
    
    -- 鼠标按下输入回调
    self.onMouseInputDownProcessorNotify = self.cppMgr.OnGetMouseButtonDownDelegate:Bind(
        function(mouseEvent) return self:OnMouseButtonDownInputProcessor(mouseEvent) end
    )

    -- 鼠标抬起输入回调
    self.onMouseInputUpProcessorNotify = self.cppMgr.OnGetMouseButtonUpDelegate:Bind(
        function(mouseEvent) return self:OnMouseButtonUpInputProcessor(mouseEvent) end
    )
    
    self.keyDownBindInfo = {}       -- 键盘按下绑定
    self.keyDownBindObjects = {}    -- 绑定对象列表
    self.keyDownBindNum = {}        -- 绑定对象数量

    self.keyUpBindInfo = {}         -- 键盘抬起绑定
    self.keyUpBindObjects = {}      -- 绑定对象列表
    self.keyUpBindNum = {}          -- 绑定对象数量
    
    self.mouseDownBindInfo = {}     -- 鼠标按下绑定
    self.mouseDownObjects = {}      -- 绑定对象列表
    self.mouseDownBindNum = 0       -- 绑定对象数量
    self.mouseUpBindInfo = {}       -- 鼠标抬起绑定
    self.mouseUpObjects = {}        -- 绑定对象列表
    self.mouseUpBindNum = 0         -- 绑定对象数量
end

function UIInputProcessorManager:UnInit()
    self:UnbindAllKeys()
    self:UnBindAllMouseEvents()
    self.cppMgr.OnGetKeyEventDelegate:Clear()
    self.cppMgr.OnGetMouseButtonDownDelegate:Clear()
    self.cppMgr.OnGetMouseButtonUpDelegate:Clear()
    self.cppMgr:NativeUninit()
end

function UIInputProcessorManager:BindKeyEvent(owner, keyName, eventType, func)
    local needRealBind, bindInfo, bindObjects, bindNum
    if eventType == EInputEvent.IE_Pressed then
        needRealBind, bindInfo, bindObjects, bindNum = self:RecordBindEvent(
            owner, func, self.keyDownBindInfo[keyName], self.keyDownBindObjects[keyName], self.keyDownBindNum[keyName]
        )
    elseif eventType == EInputEvent.IE_Released then
        needRealBind, bindInfo, bindObjects, bindNum = self:RecordBindEvent(
            owner, func, self.keyUpBindInfo[keyName], self.keyUpBindObjects[keyName], self.keyUpBindNum[keyName]
        )
    else
        return
    end

    if needRealBind == nil then return end

    if eventType == EInputEvent.IE_Pressed then
        self.keyDownBindInfo[keyName], self.keyDownBindObjects[keyName], self.keyDownBindNum[keyName] = bindInfo, bindObjects, bindNum
    elseif eventType == EInputEvent.IE_Released then
        self.keyUpBindInfo[keyName], self.keyUpBindObjects[keyName], self.keyUpBindNum[keyName] = bindInfo, bindObjects, bindNum
    end
    
    if needRealBind then
        if eventType == EInputEvent.IE_Released then
            self.cppMgr:BindKeyUpEvent(keyName)
        elseif eventType == EInputEvent.IE_Pressed then
            self.cppMgr:BindKeyDownEvent(keyName)
        end
    end
end

function UIInputProcessorManager:UnBindKeyEvent(owner, keyName, eventType)
    local needRealBind, bindNum
    if eventType == EInputEvent.IE_Pressed then
        needRealBind, bindNum = self:RecordUnBindEvent(
            owner, self.keyDownBindInfo[keyName], self.keyDownBindObjects[keyName], self.keyDownBindNum[keyName]
        )
    elseif eventType == EInputEvent.IE_Released then
        needRealBind, bindNum = self:RecordUnBindEvent(
            owner, self.keyUpBindInfo[keyName], self.keyUpBindObjects[keyName], self.keyUpBindNum[keyName]
        )
    else
        return
    end
    
    if bindNum == nil then return end
    
    if eventType == EInputEvent.IE_Pressed then
        self.keyDownBindNum[keyName] = bindNum
    elseif eventType == EInputEvent.IE_Released then
        self.keyUpBindNum[keyName] = bindNum
    end
    
    if needRealBind then
        if eventType == EInputEvent.IE_Pressed then
            self.cppMgr:UnBindKeyDownEvent(keyName)
        elseif eventType == EInputEvent.IE_Released then
            self.cppMgr:UnBindKeyUpEvent(keyName)
        end
    end
end

function UIInputProcessorManager:BindMouseButtonDownEvent(owner, func)
    local needRealBind, bindInfo, bindObjects, bindNum = self:RecordBindEvent(
        owner, func, self.mouseDownBindInfo, self.mouseDownObjects, self.mouseDownBindNum
    )
    if needRealBind == nil then return end
    self.mouseDownBindInfo, self.mouseDownObjects, self.mouseDownBindNum = bindInfo, bindObjects, bindNum
    if needRealBind then
        self.cppMgr:BindMouseButtonDownEvent()
    end
end

function UIInputProcessorManager:BindMouseButtonUpEvent(owner, func)
    local needRealBind, bindInfo, bindObjects, bindNum = self:RecordBindEvent(
        owner, func, self.mouseUpBindInfo, self.mouseUpObjects, self.mouseUpBindNum
    )
    if needRealBind == nil then return end
    self.mouseUpBindInfo, self.mouseUpObjects, self.mouseUpBindNum = bindInfo, bindObjects, bindNum
    if needRealBind then
        self.cppMgr:BindMouseButtonUpEvent()
    end
end

function UIInputProcessorManager:UnBindMouseButtonDownEvent(owner)
    local needRealBind, bindNum = self:RecordUnBindEvent(
        owner, self.mouseDownBindInfo, self.mouseDownObjects, self.mouseDownBindNum
    )
    if bindNum == nil then return end
    self.mouseDownBindNum = bindNum
    if needRealBind then
        self.cppMgr:UnBindMouseButtonDownEvent()
    end
end

function UIInputProcessorManager:UnBindMouseButtonUpEvent(owner)
    local needRealBind, bindNum = self:RecordUnBindEvent(
        owner, self.mouseUpBindInfo, self.mouseUpObjects, self.mouseUpBindNum
    )
    if bindNum == nil then return end
    self.mouseUpBindNum = bindNum
    if needRealBind then
        self.cppMgr:UnBindMouseButtonUpEvent()
    end
end

function UIInputProcessorManager:UnBindAllMouseEvents()
    Log.Debug("[UIInputProcessorManager]UnBindAllMouseEvents")

    table.clear(self.mouseDownBindInfo)
    table.clear(self.mouseDownObjects)
    self.mouseDownBindNum = 0
    
    table.clear(self.mouseUpBindInfo)
    table.clear(self.mouseUpObjects)
    self.mouseUpBindNum = 0
    
    self.cppMgr:UnBindAllMouseEvents()
end

function UIInputProcessorManager:UnbindAllKeys()
    Log.Debug("[UIInputProcessorManager]UnbindAllKeys")
    table.clear(self.keyDownBindInfo)
    table.clear(self.keyDownBindObjects)
    table.clear(self.keyDownBindNum)
    table.clear(self.keyUpBindInfo)
    table.clear(self.keyUpBindObjects)
    table.clear(self.keyUpBindNum)
    self.cppMgr:UnBindAllKeyEvents()
end

function UIInputProcessorManager:OnKeyInputProcessor(keyName, inputEvent)
    Log.Debug("[UIInputProcessorManager]OnKeyInputProcessor: ", keyName, inputEvent)
    local needSwallow = false
    if inputEvent == EInputEvent.IE_Pressed and self.keyDownBindInfo[keyName] then
        needSwallow, self.keyDownBindNum[keyName] = self:ProcessFuncs(
            self.keyDownBindInfo[keyName], self.keyDownBindObjects[keyName], self.keyDownBindNum[keyName], keyName, inputEvent
        )
    elseif inputEvent == EInputEvent.IE_Released and self.keyUpBindInfo[keyName] then
        needSwallow, self.keyUpBindNum[keyName] = self:ProcessFuncs(
            self.keyUpBindInfo[keyName], self.keyUpBindObjects[keyName], self.keyUpBindNum[keyName], keyName, inputEvent
        )
    end
    return needSwallow
end

function UIInputProcessorManager:OnMouseButtonDownInputProcessor(mouseEvent)
    Log.Debug("[UIInputProcessorManager]OnMouseButtonInputProcessor: ", mouseEvent)
    local needSwallow = false
    needSwallow, self.mouseDownBindNum = self:ProcessFuncs(
        self.mouseDownBindInfo, self.mouseDownObjects, self.mouseDownBindNum, mouseEvent
    )
    return needSwallow
end

function UIInputProcessorManager:OnMouseButtonUpInputProcessor(mouseEvent)
    Log.Debug("[UIInputProcessorManager]OnMouseButtonInputProcessor: ", mouseEvent)
    local needSwallow = false
    needSwallow, self.mouseUpBindNum = self:ProcessFuncs(
        self.mouseUpBindInfo, self.mouseUpObjects, self.mouseUpBindNum, mouseEvent
    )
    return needSwallow
end

---@private RecordBindEvent
function UIInputProcessorManager:RecordBindEvent(owner, func, bindInfo, bindObjects, bindNum)
    assert(type(func) == "string")
    if bindInfo and bindInfo[owner] ~= nil then
        Log.WarningFormat("[UIInputProcessorManager] Repeat BindEvent By %s", owner)
        return
    end

    local currentBindNum, needRealBind = bindNum or 0, false
    if currentBindNum <= 0 then
        needRealBind = true
    end

    if bindInfo == nil then
        bindInfo = {}
        setmetatable(bindInfo, { __mode = "k" })
    end
    bindInfo[owner] = func

    bindNum = currentBindNum + 1
    currentBindNum = bindNum
    if bindObjects == nil then
        bindObjects = {}
        setmetatable(bindObjects, { __mode = "v" })
    end
    bindObjects[currentBindNum] = owner

    Log.DebugFormat("[UIInputProcessorManager]BindEvent: owner: %s, num: %s", owner, currentBindNum)

    return needRealBind, bindInfo, bindObjects, bindNum
end

---@private RecordUnBindEvent
function UIInputProcessorManager:RecordUnBindEvent(owner, bindInfo, bindObjects, bindNum)
    if not bindInfo or bindInfo[owner] == nil then
        Log.WarningFormat("[UIInputProcessorManager] Try UnBindEvent Failed By %s", tostring(owner))
        return false, nil
    end
    bindInfo[owner] = nil

    local realIndex, mouseUpObjects, needRealUnBind = 0, {}, false
    setmetatable(mouseUpObjects, {__mode = "v"})
    for index = 1, bindNum do
        local curOwner = bindObjects[index]
        if curOwner ~= nil and curOwner ~= owner then
            realIndex = realIndex + 1
            table.insert(mouseUpObjects, curOwner)
        end
    end
    bindNum = realIndex
    bindObjects = mouseUpObjects

    if realIndex < 1 then
        needRealUnBind = true
    end
    Log.DebugFormat("[UIInputProcessorManager]UnBindEvent: %s", tostring(owner))
    return needRealUnBind, realIndex
end

---@private ProcessFuncs
function UIInputProcessorManager:ProcessFuncs(bindInfo, bindObjects, bindNum, ...)
    local needSwallow, realIndex = false, 0
    local keyDownBindObjects = {}
    setmetatable(keyDownBindObjects, {__mode = "v"})
    for index = 1, bindNum do
        local owner = bindObjects[index]
        if owner then
            realIndex = realIndex + 1
            if not needSwallow then
				local func = owner[bindInfo[owner]]
				if func ~= nil then
					local ok, result = xpcall(func, _G.CallBackError, owner, ...)
					if ok and type(result) == "boolean" then
						needSwallow = needSwallow or result
					end
				end
            end
            keyDownBindObjects[realIndex] = owner
        end
    end
    bindObjects = keyDownBindObjects
    return needSwallow, realIndex
end

return UIInputProcessorManager