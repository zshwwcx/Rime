local TimerComponent = kg_require("Framework.KGFramework.KGCore.TimerManager.TimerComponent")
local EventBase = kg_require("Framework.EventSystem.EventBase")
local LoaderComponent = kg_require("Framework.KGFramework.KGUI.Core.LoaderComponent")
local WidgetTree = kg_require("Framework.KGFramework.KGUI.Core.WidgetTree")
local UPaperSprite = import("PaperSprite")
local UDynamicSprite = import("DynamicSprite")
local ESlateVisibility = import("ESlateVisibility")

---@class NewUIComponent : TimerComponent
local UIComponent = DefineClass("NewUIComponent", TimerComponent, EventBase, LoaderComponent)

--region 构造初始化
---@private
---@param uid string
---@param userWidget KGUserWidget
---@param parentComponent UIComponent
function UIComponent:ctor(uid, userWidget, widget, parentComponent)
    ---@type string 面板Id
    self.uid = uid
    ---@type UIComponent 所属父组件
    self.parentComponent = parentComponent
    ---@type KGUserWidget 脚本所在的蓝图
    self.userWidget = userWidget
    ---@protected 脚本挂载的节点
    ---@type Widget
    self.widget = widget
    ---用来访问UI节点
    self.view = self:createView()
    ---@type UIComponent[] 子组件列表
    ---@private
    self._childComponents = {}
    ---@private 蓝图事件
    self._uiEvents = {}
    ---@private 动画事件
    self._animationBinding = {}
    ---@private 默认显隐
    self.defaultVisibility = ESlateVisibility.SelfHitTestInvisible
    local visibility = widget:GetVisibility()
    self._isShow = visibility == ESlateVisibility.Visible or visibility == ESlateVisibility.HitTestInvisible or
    visibility == ESlateVisibility.SelfHitTestInvisible
    self._isOpen = false
    self._uObjectNum = 0
    self._singleComponentInvokes = {}
    self._curOpeningSingleComponent = {}
    self._singleComponent = {}
    self._formComs = {}
    self._preloadResMap = {}
    self.imageRecord = {}
    self:OnCreate()
end

---@private
--- 面板销毁的时候会触发，关闭面板如果面板被缓存也不会触发，只有UI资源都销毁的时候会触发
function UIComponent:dtor()
    self.view = nil
    self._childComponents = nil
    self.widget = nil
    self.userWidget = nil
    self._uiEvents = nil
    self._animationBinding = nil
    self._preloadResMap = nil
end

---@private 创建view
function UIComponent:createView()
    return WidgetTree.new(self.userWidget)
end

function UIComponent:InitUIData()
end

---@protected UI事件在这里注册，此处为自动生成
function UIComponent:InitUIEvent()
end

---@protected 初始化组件
function UIComponent:InitUIComponent()
end

---@protected 初始化UI基础逻辑，这里不能出现和数据相关的业务逻辑调用
function UIComponent:InitUIView()
end

function UIComponent:setCellId(uid)
    self.cellId = uid
end

function UIComponent:setPreLoadResMap(resMap)
    if resMap then
        self._preloadResMap = resMap
    end
end
--endregion

--region 框架生命周期
---@protected
--- 面板或者组件第一次创建的时候会触发，整个生命周期触发一次
function UIComponent:OnCreate()
    self:InitUIData()
    self:InitUIComponent()
    self:InitUIEvent()
    self:InitUIView()
end

---@public 打开面板或者组件,业务侧不要调用，框架使用
function UIComponent:Open()
    self._isOpen = true
    self:BatchAddListener() -- 批量注册系统事件
    for _, comp in ipairs(self._childComponents or {}) do
        if not comp._isOpen then
            comp:Open()
        end
    end
    self:OnOpen()
end

---@protected
--- 面板打开，有需要可以继承重写方法
function UIComponent:OnOpen()

end

---@public 打开面板或者组件,业务侧不要调用，框架使用
function UIComponent:Close()
    self:OnClose()
    for _, comp in ipairs(self._childComponents or {}) do
        if comp and comp:IsOpened() then
            comp:Close()
        end
    end
    self:clearAnimation()
    self:RemoveAllListener(true)
    self:StopAllTimer()
    self:ClearLoad()
    self:ClearImageRecord()
    table.clear(self._singleComponentInvokes)
    table.clear(self._curOpeningSingleComponent)
    self._isOpen = false
end

---@protected
--- 面板关闭，有需要可以继承重写方法
function UIComponent:OnClose()

end

---@public 显示节点
---@param visibleType? ESlateVisibility
function UIComponent:Show(visibleType)
    if not self._isShow or (visibleType and self.widget:GetVisibility() ~= visibleType) then
        self._isShow = true
        visibleType = visibleType or self.defaultVisibility or ESlateVisibility.SelfHitTestInvisible
        self.widget:SetVisibility(visibleType)
        self:OnShow()
    end
end

---@protected
--- 面板显示的时候会触发，有需要可以继承重写方法,原则上一般业务侧不需要重写
function UIComponent:OnShow()

end

---@public  隐藏节点
---@param visibleType? ESlateVisibility
function UIComponent:Hide(visibleType)
    if self._isShow or (visibleType and self.widget:GetVisibility() ~= visibleType) then
        self._isShow = false
        visibleType = visibleType or UE.ESlateVisibility.Collapsed
        self.defaultVisibility = self.userWidget:GetVisibility()
        self.widget:SetVisibility(visibleType)
        self:OnHide()
    end
end

---@protected
--- 面板隐藏的时候会触发，有需要可以继承重写方法,原则上一般业务侧不需要重写
function UIComponent:OnHide()

end

function UIComponent:Refresh(...)
    self:OnRefresh(...)
end

---@public
--- 刷新业务逻辑
---@param params table 面板打开时初始化参数
function UIComponent:OnRefresh(...)

end

---@public 销毁组件
---@param bDontDestroyWidget? boolean 是否不销毁组件绑定的脚本
function UIComponent:Destroy(bDontDestroyWidget)
    if self:IsOpened() then
        self:Close()
    end
    self:OnDestroy()
    self:ClearAllUIEvent()
    for _, comp in ipairs(self._childComponents) do
        if comp.bIsOldUI then
            comp:OnDestroy()
        else
            if comp:IsNeedCache() then
                comp:CacheComponent()
            else
                comp:Destroy(true)
            end
        end
    end
    if not bDontDestroyWidget then
        if _G.InvalidationBox and self:IsPanel() and not Game.NewUIManager:GetUIConfig(self.uid).volatile then
			local parent = self.userWidget:GetParent()
			parent:RemoveFromParent()
		else
			self.widget:RemoveFromParent()
		end
        self.widget:RemoveFromParent()
    end
    self:delete()
end

function UIComponent:OnDestroy()

end

---面板是否显示
---@public
function UIComponent:IsShow()
    return self._isShow
end

---面板是否打开
---@public
function UIComponent:IsOpened()
    return self._isOpen
end

--endregion

function UIComponent:GetViewRoot()
    return self.userWidget
end

---@return UIComponent
function UIComponent:GetParent()
    return self.parentComponent
end

---@return UIPanel
function UIComponent:GetBelongPanel()
    local panel = self.parentComponent or self
    while panel and panel.parentComponent do
        panel = panel.parentComponent
    end
    return panel
end

--region 组件管理
---@public 创建组件
---@param widget
---@param class? 可以是类或者类的路径
function UIComponent:CreateComponent(widget, class, ...)
    if not class or (class and type(class) == "string") then
        if not widget:IsA(UE.UserWidget) then
            Log.WarningFormat("UIFrame.UIComponent:CreateComponent 非UserWidget 必须传入需要创建的Lua类", self.__cname)
            return
        end
        local classPath = class or widget.LuaBinder.LuaPath
        if classPath == "None" then
            Log.ErrorFormat("UIFrame.UIComponent:CreateComponent 蓝图:%s上面没有绑定脚本", widget:GetName())
            return
        end
        class = Game.NewUIManager:RequireUIClass(classPath)
    end
    if class then
        local userwidget = widget:IsA(UE.UserWidget) and widget or self.userWidget
        local component = Game.NewUIManager:CreateScript(class, self.uid, userwidget, widget, self, ...)
        if not component then
            return
        end
        self:initComponent(component)
        return component
    end
end

--- 以WBP_ComLib中存在的控件为蓝本，实例化一个控件，并实例化指定的UIComponent组件
---@param name string @ 控件名字
---@param container Widget @ 挂载点控件
---@param cell NewUIComponent @ 需要绑定的组件脚本
---@return NewUIComponent
function UIComponent:FormComponent(name, container, cell, ...)
    if not cell then
        Log.Error(self.__cname, ": widget必需绑定Component脚本(业务比较简单的话，可以绑定WidgetEmptyComponent，逻辑依旧放在父界面中)")
        return
    end

    local widget = Game.UIManager:GetInstance():GetLibComponent(name, container, self.userWidget)
    local component = self:CreateComponent(widget, cell, ...)
    component.componentContainer = container

    self._formComs[container] = self._formComs[container] or {}
    local form = self._formComs[container]
    local len = #form
    form[len + 1] = name
    form[len + 2] = widget
    form[len + 3] = component

    return component
end

---@param container Widget @ 容器控件
function UIComponent:PushContainerComponent(container)
    self:PushAllComponent(self, container)
end

---@public @回收容器内所有Lib下Component
---@param owner NewUIComponent @ 界面
---@param container Widget @ 容器控件
function UIComponent:PushAllComponent(owner, container)
    local formComs = owner._formComs[container]
    if not formComs then
        return
    end

    ---@type UIManager
    local UIManager = Game.UIManager

    ---@type string
    local name
    ---@type Widget
    local widget
    ---@type NewUIComponent
    local cell
    for index = 1, #formComs, 3 do
        name, widget, cell = formComs[index], formComs[index + 1], formComs[index + 2]
        if cell then
            cell:Close()
            cell:Destroy()
            local cellIndex = table.arrayIndexOf(self._childComponents, cell)
            if cellIndex then
                table.remove(self._childComponents, cellIndex)
            end
        else
            UIManager:GetInstance():UnbindClick(owner, widget)
            widget:RemoveFromParent()
        end

        UIManager:CacheLibComponent(name, widget)
    end

    table.clear(owner._formComs[container])
end

---@public 删除组件
---@param component NewUIComponent
---@param bool? bDontDestroyWidget
function UIComponent:RemoveComponent(component, bDontDestroyWidget)
    component:Close()
    component:Destroy(bDontDestroyWidget)
    table.removeItem(self._childComponents, component, false)
    if component.cellId then
        self._singleComponent[component.cellId] = nil
    end
end

---@public 打开子组件， 同一个cellId 只会有一个实例的时候才能用
function UIComponent:OpenComponent(cellId, root, ...)
    local component = self:GetComponentByCellId(cellId)
    if component then
        component:Show()
        component:Refresh(...)
        return
    end
    -- luacheck: push ignore
    local func = function(singleComponent)
        self._singleComponent[cellId] = singleComponent
        self._curOpeningSingleComponent[cellId] = nil  
    end
    self._curOpeningSingleComponent[cellId] = self:AsyncLoadComponent(cellId, root, func, ...)
-- luacheck: pop
end

---@public 关闭子组件， 同一个cellId 只会有一个实例的时候才能用
---@param cellId number
---@param isRemove boolean 移除之后下次再打开就需要重新创建了
function UIComponent:CloseComponent(cellId, isRemove)
    if self._curOpeningSingleComponent[cellId] then
        Game.AssetManager:CancelLoadAsset(self._curOpeningSingleComponent[cellId])
        self._curOpeningSingleComponent[cellId] = nil
        return
    end
    local component = self:GetComponentByCellId(cellId)
    if component then
        if isRemove then
            self:RemoveComponent(component)
        else
            component:Hide()
        end
    end
end

---@public 调用子组件函数， 同一个cellId 只会有一个实例的时候才能用
-- luacheck: push ignore
function UIComponent:InvokeComponent(cellId, root, funcName, ...)
    local component = self:GetComponentByCellId(cellId)
    if component then
        if component[funcName] then
            component[funcName](component, ...)
        else
            Log.WarningFormat("UIFrame.UIComponent:InvokeComponentByKey %s没有实现函数 %s", self.__cname, funcName)
            return
        end
    else
        if not self._singleComponentInvokes[cellId] then
            self._singleComponentInvokes[cellId] = {}
        end
        local invokes = self._singleComponentInvokes[cellId]
        invokes[#invokes + 1] = {funcName = funcName, params = { ... } }
        if self._curOpeningSingleComponent[cellId] then
            return
        end
        local func = function(comp)
            self._singleComponent[cellId] = comp
            self._curOpeningSingleComponent[cellId] = nil  
            if self._singleComponentInvokes[cellId] ~= nil then
                for i, v in ipairs(self._singleComponentInvokes[cellId]) do
                    comp[v.funcName](comp, unpack(v.params))
                end
            end
        end
        self:AsyncLoadComponent(cellId, root, func)
    end
end

-- luacheck: pop
---@public 同步加载组件
function UIComponent:SyncLoadComponent(cellId, root, ...)
    local cacheComponent = self:loadFormCache(cellId)
    if cacheComponent then
        return cacheComponent
    end
    local filePath = UICellConfig.CellConfig[cellId].res
    local classPath = UICellConfig.CellConfig[cellId].luaClass
    local res = self._preloadResMap[filePath]
    if res then
        local widget = Game.NewUIManager:InstanceWidget(res)
        if IsValid_L(widget) then
            Game.NewUIManager:AddChildToCanvas(widget, root)
            local component = self:CreateComponent(widget, classPath)
            if component then
                self:UpdateObjectNum(widget.UObjectNum)
                component:setCellId(cellId)
                component:Refresh(...)
            end
            return component
        end
    else
        Log.WarningFormat("SyncLoadComponent CellId: %s Need Add PreloadResMap", cellId)
    end
end

-- luacheck: push ignore
---@public 异步加载组件
function UIComponent:AsyncLoadComponent(cellId, root, loadCallBack, ...)
    local cacheComponent = self:loadFormCache(cellId)
    if cacheComponent then
        Game.NewUIManager:AddChildToCanvas(cacheComponent.userWidget, root)
        if loadCallBack then
            loadCallBack(cacheComponent)
        end
        return 0
    end
    local param = { ... }
    local classPath = UICellConfig.CellConfig[cellId].luaClass
    local resCallBack = function(res, preloadResMap)
        if self:IsOpened() == false then
            Log.WarningFormat("UIFrame:UIComponent.AsyncLoadComponent 脚本已经关闭，但是异步加载回调没有终止 class:%s, cellId:%s",
                self.__cname, cellId)
            return
        end
        if self.destroyed then
            Log.WarningFormat("UIFrame:UIComponent.AsyncLoadComponent 脚本已经销毁，但是异步加载回调没有终止 class:%s, cellId:%s",
                self.__cname, cellId)
            return
        end
        local widget = Game.NewUIManager:InstanceWidget(res)
        if IsValid_L(widget) then
            Game.NewUIManager:AddChildToCanvas(widget, root)
            local component = self:CreateComponent(widget, classPath)
            if component then
                component:UpdateObjectNum(widget.UObjectNum)
                component:setPreLoadResMap(preloadResMap)
                component:setCellId(cellId)
                component:Refresh(unpack(param))
            end
            if loadCallBack then
                loadCallBack(component)
            end
        end
    end
    return self:LoadCellAsset(cellId, resCallBack)
end

-- luacheck: pop
function UIComponent:loadFormCache(cellId)
    local component = Game.NewUIManager:PopComponentByCellId(cellId)
    if component then
        self:initComponent(component)
        component.parentComponent = self
    end
    return component
end

function UIComponent:CloseSelf()
    if self.parentComponent then
        self.parentComponent:RemoveComponent(self)
    else
        Game.NewUIManager:ClosePanel(self.uid)
    end
end

function UIComponent:CacheComponent()
    if self:IsOpened() then
        self:Close()
    end
    if self.widget:GetParent() then
        self.widget:RemoveFromParent()
    end
    self.parentComponent = nil
    Game.NewUIManager:PushComponent(self)
end

---@return NewUIComponent
function UIComponent:GetComponentByCellId(cellId)
    return self._singleComponent[cellId]
end

---@public 组件初始化
---@field widget Widget
function UIComponent:initComponent(script)
    table.insert(self._childComponents, script)
    script:Show()
    script:Open()
end

function UIComponent:IsNeedCache()
    if self.cellId == nil or _G.NoCacheUI then --不是动态加载的都不会进入缓存，动态加载的一定会有cellId
        return false
    end
    local config = UICellConfig.CellConfig[self.cellId]
    return config.cache
end

function UIComponent:HasCellId()
    return self.cellId ~= nil
end

--endregion
-- luacheck: push ignore
--region UI事件
---@param delegate Delegate | MulticastDelegate | LuaDelegate | LuaMulticastDelegate C++委托
---@param functionName string Lua函数名称
---@public
function UIComponent:AddUIEvent(delegate, functionName, ...)
    if delegate == nil then
        Log.WarningFormat("UIFrame.UIComponent:AddUIEvent %s尝试给一个不存在的委托绑定函数 %s", self.__cname, functionName)
        return
    end
    local extendParam = table.pack(...)

    local callback = function(...)
        if self[functionName] then
            if extendParam.n > 0 then
                local pack = table.pack(...)
                table.mergeList(pack, extendParam)
                return self[functionName](self, table.unpack(pack))
            end
            return self[functionName](self, ...)
        end
    end
    delegate:AddListener(callback)
    self._uiEvents[functionName] = { callback = callback, delegate = delegate }
end

-- luacheck: pop
---@param delegate Delegate | MulticastDelegate | LuaDelegate | LuaMulticastDelegate C++委托
---@param functionName string Lua函数名称
---@public
function UIComponent:RemoveUIEvent(delegate, functionName)
    local uiEvent = self._uiEvents[functionName]
    if uiEvent == nil then
        Log.WarningFormat("UIFrame.UIComponent:RemoveUIEvent 移除了一个没有注册的函数 %s", functionName)
        return
    end
    assert(uiEvent.delegate == delegate)
    delegate:RemoveListener(uiEvent.callback)
    self._uiEvents[functionName] = nil
end

---@private
function UIComponent:ClearAllUIEvent()
    for functionName, event in pairs(self._uiEvents) do
        self:RemoveUIEvent(event.delegate, functionName)
    end
end

--endregion

--region UI动画
--play UI动画
---@param widgetAnimation WidgetAnimation
---@param finishCallback function 结束回调
---@param userWidget UserWidget 默认为此界面对应的UserWidget
---@param startAtTime number 开始时间（不是归一化的时间），默认为0
---@param numberOfLoops number 循环次数，默认为1
---@param playMode number 播放模式，默认为正向播放
---@param playbackSpeed number 播放速度 默认为0
---@param bRestoreState boolean 播放完之后是否返回原状态
function UIComponent:PlayAnimation(widgetAnimation, finishCallback, userWidget, startAtTime, numberOfLoops, playMode,
                                   playbackSpeed, bRestoreState)
    if not widgetAnimation then
        Log.ErrorFormat("UIFrame.UIComponent.PlayAnimation:播放动画失败， widgetAnimation = nil")
        return
    end
    userWidget = userWidget or self.userWidget
    if finishCallback then
        self:animationFinishEventBind(userWidget, widgetAnimation, finishCallback)
    end
    userWidget:PlayAnimation(widgetAnimation, startAtTime, numberOfLoops, playMode, playbackSpeed, bRestoreState)
end

--stop UI动画
function UIComponent:StopAnimation(widgetAnimation, userWidget)
    if not widgetAnimation then
        Log.ErrorFormat("UIFrame.UIComponent.PlayAnimation:stop动画失败, widgetAnimation = nil")
        return
    end
    userWidget = userWidget or self.userWidget
    userWidget:StopAnimation(widgetAnimation)
    self:animationFinishEventUnBind(userWidget, widgetAnimation)
end

--pause UI动画
function UIComponent:PauseAnimation(widgetAnimation, userWidget)
    if not widgetAnimation then
        Log.ErrorFormat("UIFrame.UIComponent.PlayAnimation:pause动画失败, widgetAnimation = nil")
        return
    end
    userWidget = userWidget or self.userWidget
    userWidget:PauseAnimation(widgetAnimation)
end

function UIComponent:StopAllAnimations(userWidget)
	if nil == userWidget then
		Log.Error("StopAllAnimations failed, userWidget is nil")
		return
	end

	userWidget:StopAllAnimations()

	if not self._animationBinding[userWidget] then return end

	for _, Ani in pairs(self._animationBinding[userWidget]) do
		self:animationFinishEventUnBind(userWidget, Ani)
	end
end

-- luacheck: push ignore
---@private
function UIComponent:animationFinishEventBind(userWidget, widgetAnimation, finishCallback)
    if not self._animationBinding[userWidget] then
        self._animationBinding[userWidget] = {}
    end

    if self._animationBinding[userWidget][widgetAnimation] then
        userWidget:UnbindFromAnimationFinished(widgetAnimation, self._animationBinding[userWidget][widgetAnimation])
    end

    local callback = function()
        userWidget:UnbindFromAnimationFinished(widgetAnimation, self._animationBinding[userWidget][widgetAnimation])
        if finishCallback then
            finishCallback()
        end
    end
    local delegate = slua.createDelegate(function()
        callback()
    end)
    userWidget:BindToAnimationFinished(widgetAnimation, delegate)
    self._animationBinding[userWidget][widgetAnimation] = delegate
end

-- luacheck: pop
---@private
function UIComponent:animationFinishEventUnBind(userWidget, widgetAnimation)
    if not self._animationBinding[userWidget] or not self._animationBinding[userWidget][widgetAnimation] then
        return
    end
    userWidget:UnbindFromAnimationFinished(widgetAnimation, self._animationBinding[userWidget][widgetAnimation])
end

---@private
function UIComponent:clearAnimation()
    for userWidget, events in pairs(self._animationBinding) do
        userWidget:StopAllAnimations()
        for widgetAnimation, callback in pairs(events or {}) do
            userWidget:UnbindFromAnimationFinished(widgetAnimation, callback)
        end
    end
    table.clear(self._animationBindings)
end

--endregion

--region 状态组
function UIComponent:ChangeState(stateGroupName, stateValue, force)
    local stateManagement = self.widget:GetComponent(UE.KGStateManagement) ---@type KGStateManagement
    if stateManagement ~= nil then
        force = force and true or false
        stateManagement:ChangeState(stateGroupName, stateValue, force)
    end
end

--endregion

-- luacheck: push ignore
--region 设置图片接口

---ClearImageRecord 清理image图片路径记录
---@param image userdata? 为空的话清理所有image
function UIComponent:ClearImageRecord(image)
    if image then
        self.imageRecord[image] = nil
    else
        table.clear(self.imageRecord)
    end
end

---设置图片
---@public
---@param image Image
---@param path string 图片名字
---@param isAsync boolean|nil 是否异步加载（默认异步）
function UIComponent:SetImage(image, path, isAsync, bIgnoreOpacity)
    isAsync = isAsync == nil and true or isAsync
    if string.isEmpty(path) then
        Log.WarningFormat("UIFrame:UIComponent:SetImage 设置图片失败 图片资源路径不能为空 %s", self.__cname)
        return
    end
    if not IsValid_L(image) then
        Log.WarningFormat("UIFrame:UIComponent:SetImage 设置图片失败 Image控件不能为空 %s", self.__cname)
        return
    end
    path = self:checkResourcePath(path)

    if self.imageRecord[image] == path then
        return
    end
    self.imageRecord[image] = path

    local oldAlpha = nil
    local UIFunc = import("UIFunctionLibrary")
    if isAsync and not bIgnoreOpacity then
        oldAlpha = UIFunc.GetOpacity(image) -- image.ColorAndOpacity.A
        if oldAlpha <= 0 then
            oldAlpha = 1
        end
        UIFunc.SetOpacity(image, 0)
        -- image:SetOpacity(0)
    end

    if isAsync then
        local func = function(sprite)
            if self:IsOpened() == false then
                Log.ErrorFormat("UIComponent:SetImage 关闭的时候异步加载任务没有停掉 class:%s, path:%s", self.__cname, path)
                return
            end
            if self.destroyed then
                Log.Error("UIComponent:SetImage UIComponent销毁了 但是异步任务没有停掉")
                return
            end
            if not IsValid_L(sprite) then
                Log.WarningFormat("UIFrame:UIComponent:SetImage 设置图片失败 资源加载错误 class:%s, path:%s", self.__cname, path)
                return
            end
            if sprite:IsA(UPaperSprite) or sprite:IsA(UDynamicSprite) then
                image:SetBrushFromAtlasInterface(sprite, false)
            else
                image:SetBrushFromTexture(sprite, false)
            end
            if not bIgnoreOpacity then
                -- image:SetOpacity(oldAlpha)
                UIFunc.SetOpacity(image, oldAlpha)
            end
        end
        self:AsyncLoadRes(path, func)
    else
        local sprite = self:SyncLoadRes(path)
        if IsValid_L(sprite) then
            Log.WarningFormat("UIFrame:UIComponent:SetImage 设置图片失败 资源加载错误 class:%s, path:%s", self.__cname, path)
            return
        end
        if sprite:IsA(UPaperSprite) or sprite:IsA(UDynamicSprite) then
            image:SetBrushFromAtlasInterface(sprite, false)
        else
            image:SetBrushFromTexture(sprite, false)
        end
    end
end

---检查配置路径是否符合规范，如果不符合，就需要将路径修改至规范形式。
---@private
function UIComponent:checkResourcePath(path)
    if (not path) or path == "" then
        return
    end
    local correct = string.find(path, "%.")
    if correct == nil then
        local gotFileName = string.match(path, ".+/([^/]*%w+)$")
        if gotFileName then
            path = path .. "." .. gotFileName
        end
    end
    return path
end

-- luacheck: pop

---SetImageByRes
---@param image Image
---@param res Texture|PaperSprite|DynamicSprite
---@param bMatchSize boolean If true, image will change its size to texture size. If false, texture will be stretched to image size.
function UIComponent:SetImageByRes(image, res, bMatchSize)
    if res:IsA(UPaperSprite) or res:IsA(UDynamicSprite) then
        image:SetBrushFromAtlasInterface(res, bMatchSize or false)
    else
        image:SetBrushFromTexture(res, bMatchSize or false)
    end
end

---设置image的材质球
---@public
---@param image Image
---@param path string 材质球名字
---@param isAsync boolean|nil
function UIComponent:SetMaterial(image, path, isAsync, bIgnoreOpacity)
    -- luacheck: push ignore
    isAsync = isAsync == nil and true or isAsync
    if string.isEmpty(path) then
        Log.WarningFormat("UIFrame:UIComponent:SetImage 设置图片失败 图片资源路径不能为空 %s", self.__cname)
        return
    end
    if IsValid_L(image) then
        Log.WarningFormat("UIFrame:UIComponent:SetImage 设置图片失败 Image控件不能为空 %s", self.__cname)
        return
    end
    if self.imageRecord[image] == path then
        return
    end
    self.imageRecord[image] = path
    local oldAlpha = nil
    if isAsync and not bIgnoreOpacity then
        oldAlpha = image.ColorAndOpacity.A
        image:SetOpacity(0)
    end

    if isAsync then
        local func = function(material)
            if self:IsOpened() == false then
                Log.ErrorFormat("UIComponent:SetImage 关闭的时候异步加载任务没有停掉 class:%s, path:%s", self.__cname, path)
                return
            end
            if self.destroyed then
                Log.Error("UIComponent:SetImage UIComponent销毁了 但是异步任务没有停掉")
                return
            end
            if IsValid_L(material) then
                Log.WarningFormat("UIFrame:UIComponent:SetImage 设置图片失败 资源加载错误 class:%s, path:%s", self.__cname, path)
                return
            end
            image:SetBrushFromMaterial(material)
            if not bIgnoreOpacity then
                image:SetOpacity(oldAlpha)
            end
        end
        self:AsyncLoadRes(path, func)
    else
        local material = self:SyncLoadRes(path)
        if IsValid_L(material) then
            Log.WarningFormat("UIFrame:UIComponent:SetImage 设置图片失败 资源加载错误 class:%s, path:%s", self.__cname, path)
            return
        end
        image:SetBrushFromMaterial(material)
    end
    -- luacheck: pop
end

---SetMaterialByRes
---@param image Image
---@param res Material
function UIComponent:SetMaterialByRes(image, res)
    image:SetBrushFromMaterial(res)
end

function UIComponent:SetImageByUrl(image, url, imageName, bIgnoreOpacity)
    if self.imageRecord[image] == url then
        return
    end
    self.imageRecord[image] = url

    local oldAlpha = nil
    if not bIgnoreOpacity then
        oldAlpha = image.ColorAndOpacity.A
        if oldAlpha <= 0 then
            oldAlpha = 1
        end
        image:SetOpacity(0)
    end
    -- luacheck: push ignore
    local func = function(texture)
        if self:IsOpened() == false then
            Log.ErrorFormat("UIComponent:SetImageByUrl 关闭的时候异步加载任务没有停掉 class:%s, path:%s", self.__cname, url)
            return
        end
        if self.destroyed then
            Log.Error("UIComponent:SetImageByUrl UIComponent销毁了 但是异步任务没有停掉")
            return
        end
        if not IsValid_L(texture) then
            Log.WarningFormat("UIComponent:SetImageByUrl 设置图片失败 资源加载错误 class:%s, path:%s", self.__cname, url)
            return
        end
        image:SetBrushFromTexture(texture, false)
        if not bIgnoreOpacity then
            image:SetOpacity(oldAlpha)
        end
    end
    -- luacheck: pop
    Game.LocalResSystem:DownloadImgByUrls(url, imageName, func)
end

--endregion

--region 辅助函数

---控制节点显隐
---@param widget UWidget 要隐藏的节点
---@param visible boolean 显示还是隐藏
---@param hitTest boolean 响应事件
---@param hidden boolean 只隐藏不折叠 
function UIComponent:SetWidgetVisible(widget, visible, hitTest, hidden)
    local visibility
    if visible then
        visibility = hitTest and ESlateVisibility.Visible or ESlateVisibility.HitTestInvisible
    else
        visibility = hidden and ESlateVisibility.Hidden or ESlateVisibility.Collapsed 
    end
    widget:SetVisibility(visibility)
end

function UIComponent:SetVisible(visible)
    if visible then
        self:Show()
    else
        self:Hide()
    end
end

function UIComponent:IsPanel()
	return false
end

---获取UObject数量
---@public
function UIComponent:GetObjectNum()
    local num = self._uObjectNum
    for _, v in ipairs(self._childComponents) do
        num = num + v:GetObjectNum()
    end
    return num
end

---统计UObject数量
---@public
---@param isAdd boolean 增加or减少
---@param num number 变动数量
function UIComponent:UpdateObjectNum(num)
    if not num then
		return	
    end
    self._uObjectNum = num
end
return UIComponent
--endregion
