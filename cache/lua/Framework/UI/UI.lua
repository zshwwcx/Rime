---@class UI:Object
---@field GetInstance UI
local UI = DefineSingletonClass("UI")

local LuaFunctionLibrary = import("LuaFunctionLibrary")

function UI.GetUI(name, nocheck)
	if name == nil or name == "" then
		Log.Error("UI.GetUI name is nil")
		return
	end

	return UIManager:GetInstance():getUI(name)
end

function UI.IsShow(uid)
	if UIPanelConfig.PanelConfig[uid] then
		Game.NewUIManager:IsShow(uid)
	else
		local ui = UI.GetUI(uid)
		return ui and ui:IsShow()
	end
end

function UI.IsOpened(uid)
	if UIPanelConfig.PanelConfig[uid] then
		Game.NewUIManager:IsOpened(uid)
	else
		local ui = UI.GetUI(uid)
		return ui and ui:IsOpened()
	end
end

--程序UI配置表参数查询
UI._cfgMatch = {
	classpath = true,
	res = true,
	layer = true,
	top = true,
	parent = true,
	parentui = true,
	cache = true,
	layout = Enum.EUILayout.Normal,
	scenename = true,
	depends = true,
	volatile = true,
	TransparentPanelPath = true,
	order = true,
	auth = true,
}

UI._cfgMetas = {}

UI._getCfgMeta = {
	__index = function(tb, key)
		local ui = rawget(tb, "__ui")
		if key == "class" then
			return ui
		end
		local v = UI._cfgMatch[key]
		if v then
			local config = Game.UIConfig[ui]
			if not config then
				Log.Warning("not uiconfig", ui)
				return
			end
			return config[key]
		else
			local cfg = Game.TableData.GetUIDataRow(ui)
			if cfg then
				return cfg[key]
			else
				return Game.UIConfig._Default[key]
			end
		end
	end
}

function UI.GetCfg(ui)
	return Game.NewUIManager:GetUIConfig(ui)
end

function UI.ClearCfgMeta()
	table.clear(UI._cfgMetas)
end


function UI.ShowUI(ui, ...)
	UIManager:GetInstance():ShowUI(ui, true, ...)
end

function UI.HideUI(ui)
	UIManager:GetInstance():ShowUI(ui, false)
end

function UI.Invoke(name, func, arg1, arg2, arg3, arg4, arg5)
	local ui = UI.GetUI(name)
	if not ui then
		Log.WarningFormat("ui.invoke: Unable to find UI %s", name)
		return
	end
	if not ui[func] then
		Log.WarningFormat("ui.invoke: UI %s does not have callable function %s", name, func)
		return
	end
	return ui[func](ui, arg1, arg2, arg3, arg4, arg5)
end

function UI.ShowUIInEditor(ui, ...)
	UI.ShowUI(ui, ...)
	local uiinstance = UI.GetUI(ui)
	if not uiinstance then return end
	return uiinstance:GetViewRoot(), uiinstance
end

function UI.GMRefreshAllWidget()
	--UIManager:GetInstance():DisposeCache()
end

---@public 界面预加载 TODO：临时方案，后续从UIManager的资源加载着手处理
function UI.WarmUI(ui)
	UIManager:GetInstance():WarmPanel(ui)
end
