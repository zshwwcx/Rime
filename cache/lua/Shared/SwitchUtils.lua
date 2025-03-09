local DefaultSwitch = kg_require("Shared.ModuleSwitch.DefaultSwitch")
local PublishSwitch = kg_require("Shared.ModuleSwitch.PublishSwitch")
local SwitchEnum = kg_require("Shared.ModuleSwitch.SwitchEnum")
local string_format = string.format
local tostring = tostring
local type = type
local Game = Game
local LOG_ERROR_FMT = LOG_ERROR_FMT
local LOG_WARN_FMT = LOG_WARN_FMT
local pairs = pairs
local tonumber = tonumber
local SLOTS = {
    ID = 1, -- 开关id
    VALUE = 2, -- 开关默认值
    SYNC_CLIENT = 3, -- 是否同步给客户端
    CORP = 4, -- 增加开关的人的kim账号
    DESC = 5, -- 开关描述
	STR_VAL_TYPE = 6, -- string开关值类型
    SAVE = 7, -- 是否存盘(dev环境下的部分开关不存)
}

SwitchesDefault = SwitchesDefault or {}
Game.Switches = Game.Switches or {}
Game.Cache = Game.Cache or {}

-- 我们的SwitchUtils设计目标是支持简单类型（即某个系统是否要禁用），对于复杂类型我们可以监听开关的变化，之后对value根据规则进行类似反序列化得到我们期望的数据
-- 复杂类型的开关数据已经从self.forbiddenData中移除，开关相关的统一收敛成SwitchUtils里面的方法，外部接口使用的时候统一收敛成使用SwitchUtils.CheckSwitchStatus
-- 相关回调业务只在process里面放一个钩子，业务处理写在SwitchUtils里面
Game.SwitchForbiddenData = Game.SwitchForbiddenData or {}

if not Game.Cache.switchConfig then
    -- 此处开关配置只会加载一遍，保证运行时的开关配置不变，避免id变化造成问题
    -- 如果需要热更开关，调用下方 AddNewSwitch
    -- 为了节省流量不会同步没有改过的开关，大部分需要从默认值中取

    local idSlot = SLOTS.ID
    local valueSlot = SLOTS.VALUE
    local saveSlot = SLOTS.SAVE
    local switchID2Conf = {}
    -- 生成一个根据id查开关的反查表，用于后续快速查找
    -- 同时根据环境替换默认值
    local coverValue = Game.IS_PUBLISH and PublishSwitch.SwitchValue or {}
    for name, conf in pairs(DefaultSwitch.SwitchDef) do
        assert(type(conf[valueSlot]) ~= "table", string_format("Switch[%s] invalid value type table", name))
        SwitchesDefault[name] = conf
        conf.name = name
        local id = conf[idSlot]
        assert(not switchID2Conf[id], string_format("Switch[%s] duplicate config id[%s]", name, id))
        switchID2Conf[id] = conf
        if coverValue[name] ~= nil then
            conf[valueSlot] = coverValue[name]
        end
        conf[saveSlot] = true
    end

    local isPublish = Game.IS_PUBLISH
    for name, conf in pairs(DefaultSwitch.DebugSwitchDef) do
        SwitchesDefault[name] = conf
        conf.name = name
        local id = conf[idSlot]
        assert(not switchID2Conf[id], string_format("Switch[%s] duplicate config id[%s]", name, id))
        -- 生产环境下，debug开关的值和id为nil
        -- 加入到SwitchesDefault中是为了取值不触发报错Invalid switch name
        if isPublish then
            conf[valueSlot] = nil
            conf[idSlot] = nil
        else
            switchID2Conf[id] = conf
            -- Debug环境的开关支持定义是否存盘
            if conf[saveSlot] == nil then
                conf[saveSlot] = true
            end
        end
    end

    Game.Cache.switchConfig = switchID2Conf
end

function GetSwitchesByLogicServerID(LogicServerID)
    local logicServerSwitches = Game.Switches[LogicServerID]
    if not logicServerSwitches then
        logicServerSwitches = {}
        Game.Switches[LogicServerID] = logicServerSwitches

        setmetatable(logicServerSwitches, {
            __index = function(t, k)
                local conf = SwitchesDefault[k]
                if not conf then
                    LOG_WARN_FMT("Invalid switch name[%s]", k)
                    return
                end

                local val = conf[SLOTS.VALUE]
                rawset(t, k, val)
                return val
            end
        })
    end
    return logicServerSwitches
end

function GetSwitchValueByName(LogicServerID, SwitchName)
    local switches = GetSwitchesByLogicServerID(LogicServerID)
    return switches[SwitchName]
end

if IS_SERVER then
    Game.ClientSwitches = Game.ClientSwitches or {}
end

function GetSwitchID(SwitchName)
    local conf = SwitchesDefault[SwitchName]
    if conf then
        return conf[SLOTS.ID], conf[SLOTS.SAVE]
    end
end

-- 热更时调用，用于线上添加/修改开关
-- 如果是修改开关不能修改ID值，可能会导致问题
function AddNewSwitch(SwitchName, Conf)
    local idSlot = SLOTS.ID
    if SwitchesDefault[SwitchName] then
        LOG_WARN_FMT("AddNewSwitch[%s] cover old Conf", SwitchName)
        if SwitchesDefault[SwitchName][idSlot] ~= Conf[idSlot] then
            LOG_ERROR_FMT("AddNewSwitch[%s] cover same switch with different id[%s]", SwitchName, Conf[idSlot])
            return
        end
    end

    SwitchesDefault[SwitchName] = Conf
    Conf.name = SwitchName
    Game.Cache.switchConfig[idSlot] = Conf
end

function RemoveInvalidID(Id2Val)
    local invalidIDs
    local switchConfig = Game.Cache.switchConfig
    for id, val in pairs(Id2Val) do
        local def = switchConfig[id]
        if not def then
            invalidIDs = invalidIDs or {}
            invalidIDs[#invalidIDs + 1] = id
            Id2Val[id] = nil
        end
    end

    return invalidIDs
end

function RemoveDefaultID(Id2Val)
    local defaultIDs
    local switchConfig = Game.Cache.switchConfig
    for id, val in pairs(Id2Val) do
        local def = switchConfig[id]
        if def then
            if def[SLOTS.VALUE] == val then
                defaultIDs = defaultIDs or {}
                defaultIDs[#defaultIDs + 1] = id
                Id2Val[id] = nil
            end
        end
    end

    return defaultIDs
end

if IS_SERVER then
    -- refresh后置空
    local switchChangeCbName = {}
    local function getProcessCbName(Name)
        if not switchChangeCbName[Name] then
            local cb = "onSwitchValueChanged__" .. Name
            switchChangeCbName[Name] = cb
            return cb
        end

        return switchChangeCbName[Name]
    end

    function GetClientSwitchesByLogicServerID(LogicServerID)
        if not Game.ClientSwitches then
            Game.ClientSwitches = {}
        end
        local allServerClientSwitches = Game.ClientSwitches
        if not allServerClientSwitches[LogicServerID] then
            allServerClientSwitches[LogicServerID] = {}
        end
        return allServerClientSwitches[LogicServerID]
    end

    function UpdateSwitches(Id2Val, LogicServerID)
        local switches = GetSwitchesByLogicServerID(LogicServerID)
        local switchConfig = Game.Cache.switchConfig
        local syncClot = SLOTS.SYNC_CLIENT
        local clientSwitches = GetClientSwitchesByLogicServerID(LogicServerID)

        local processEnt = Game.Process
        local val2ConfVal
        for id, val in pairs(Id2Val) do
            local conf = switchConfig[id]
            if conf then
                val2ConfVal = Convert2DefaultType(conf.name, val)
                if val2ConfVal ~= nil then
                    local switchName = conf.name
                    local oldVal = switches[switchName]
                    if conf[SLOTS.VALUE] == val2ConfVal then
                        switches[switchName] = nil
                    else
                        switches[switchName] = val2ConfVal
                    end
                    local cbName = getProcessCbName(switchName)
                    if processEnt[cbName] then
                        processEnt[cbName](processEnt, conf.name, oldVal, val, LogicServerID)
                    end
    
                    if conf[syncClot] then
                        if conf[SLOTS.VALUE] == val2ConfVal then
                            clientSwitches[id] = nil
                        else
                            clientSwitches[id] = val
                        end
                    end
                else
                    LOG_ERROR_FMT("[UpdateSwitches]: %s cannot set switch %s by %s", LogicServerID, conf.name, val)
                end
            end
        end
    end

else
    function UpdateSwitches(Id2Val, LogicServerID)
        local switches = GetSwitchesByLogicServerID(LogicServerID)
        local switchConfig = Game.Cache.switchConfig
        local val2ConfVal
        for id, val in pairs(Id2Val) do
            local conf = switchConfig[id]
            if conf then
                val2ConfVal = Convert2DefaultType(conf.name, val)
                if val2ConfVal ~= nil then
                    if conf[SLOTS.VALUE] == val2ConfVal then
                        switches[conf.name] = nil
                    else
                        switches[conf.name] = val2ConfVal
                    end
                else
                    LOG_ERROR_FMT("[UpdateSwitches]:cannot set switch %s by %s", conf.name, val)
                end
            end
        end
    end
end

if IS_SERVER then
    function GetSyncClientSwitches(Id2Val, LogicServerID)
        local switchConfig = Game.Cache.switchConfig
        local syncClot = SLOTS.SYNC_CLIENT
        local clientSwitches = GetClientSwitchesByLogicServerID(LogicServerID)
        local needSync = {}
        for id, val in pairs(Id2Val) do
            local conf = switchConfig[id]
            if conf then
                if conf[syncClot] then
                    clientSwitches[id] = val
                    needSync[id] = val
                end
            end
        end
        return needSync
    end
end

function Convert2DefaultType(SwitchName, Val)
    local cfgType = SwitchesDefault[SwitchName] and type(SwitchesDefault[SwitchName][SLOTS.VALUE])
    if not cfgType then
        return nil
    end

    if type(Val) ~= cfgType then
        if type(Val) == "string" then
            if cfgType == "boolean" then
                if Val:lower() == "true" then
                    Val = true
                else
                    Val = false
                end
            elseif cfgType == "number" then
                local tv = tonumber(Val)
                if not tv then
                    LOG_ERROR_FMT("cannot set switch %s by %s", SwitchName, Val)
                    return nil
                end
                Val = tv
            end
        else
            LOG_ERROR_FMT("cannot set switch %s by %s", SwitchName, Val)
            return nil
        end
    end

    return Val
end

function GetAllForbiddenDataByLogicServerID(LogicServerID)
    if not Game.SwitchForbiddenData[LogicServerID] then
        Game.SwitchForbiddenData[LogicServerID] = {}
    end
    return Game.SwitchForbiddenData[LogicServerID]
end

function UpdateSwitchForbiddenData(SwitchName, Data, LogicServerID)
    local switchEnum = GetSwitchID(SwitchName)
    local forbiddenData = GetAllForbiddenDataByLogicServerID(LogicServerID)
    forbiddenData[switchEnum] = Data
end

STRING_DEFINED_FUNCTION = {}
STRING_DEFINED_FUNCTION[SwitchEnum.FORBIDDEN_MONEY] = function(SwitchEnumID, ForbiddenArgs, LogicServerID)
    local forbiddenData = GetAllForbiddenDataByLogicServerID(LogicServerID)
    if not forbiddenData[SwitchEnumID] then
        return false
    end
    for _, moneyType in pairs(ForbiddenArgs) do
        -- body
        if forbiddenData[SwitchEnumID][moneyType] then
            return true
        end
    end
    return false
end

function CheckStringSwitchStatus(SwitchName, ConvertVal, ForbiddenArgs)
	if not ConvertVal or ConvertVal == "" or ConvertVal == "|" then
		return false
	end

	if not ForbiddenArgs then
		return true
	end

	if not Game.StringSwitchCache then
		Game.StringSwitchCache = {}
	end
	
	local cacheValue = Game.StringSwitchCache[SwitchName]
	if not cacheValue or cacheValue.rawValue ~= ConvertVal then		-- 没有cache或cache与当前值不一致要重新生成cache
		local valueList = string.split(ConvertVal, "|")
		local valueMap = {}
		local stringType = SwitchesDefault[SwitchName] and SwitchesDefault[SwitchName][SLOTS.STR_VAL_TYPE]
		stringType = stringType or DefaultSwitch.STRING_SWITCH_VALUE_TYPE.STRING_LIST
		if stringType == DefaultSwitch.STRING_SWITCH_VALUE_TYPE.NUMBER_LIST then
			for _, value in pairs(valueList) do
				valueMap[tonumber(value)] = true
			end
		else
			for _, value in pairs(valueList) do
				valueMap[value] = true
			end
		end
		
		cacheValue = {
			rawValue = ConvertVal,
			valueMap = valueMap,
		}
		
		Game.StringSwitchCache[SwitchName] = cacheValue
	end

	local valueMap = cacheValue.valueMap
	for _, arg in pairs(ForbiddenArgs) do
		if valueMap[arg] then
			return true
		end
	end
	return false
end

function CheckSwitchStatus(SwitchName, ForbiddenArgs, LogicServerID)
    if ForbiddenArgs ~= nil and type(ForbiddenArgs) ~= "table" then
        LOG_ERROR_FMT("cannot check status of switch %s, ForbiddenArgs[%s] is not table", SwitchName, ForbiddenArgs)
        return false
    end
    local switchEnum = GetSwitchID(SwitchName)
    local switches = GetSwitchesByLogicServerID(LogicServerID)
    local switchValue = switches[SwitchName]
    if switchValue ~= nil then
        local convertVal = Convert2DefaultType(SwitchName, switchValue)
        if type(convertVal) == "boolean" then
            return convertVal
        elseif type(convertVal) == "string" then
            if STRING_DEFINED_FUNCTION[switchEnum] then
                return STRING_DEFINED_FUNCTION[switchEnum](switchEnum, ForbiddenArgs, LogicServerID)
            end
            return CheckStringSwitchStatus(SwitchName, convertVal, ForbiddenArgs)
        else
            LOG_ERROR_FMT("cannot check status of switch %s, convertVal[%s] type not defined!!!", SwitchName, convertVal)
            return nil
        end
    end
    LOG_ERROR_FMT("cannot check status of switch %s, not exist", SwitchName)
    return nil    
end


-----放在最后的起服检查
if IS_SERVER then
    for id, conf in pairs(Game.Cache.switchConfig) do
        if type(conf[SLOTS.VALUE]) == "string" then
            --assert(STRING_DEFINED_FUNCTION[id] ~= nil, string.format("string type switch[%s] doesn't have define function", conf.name))
        end
    end
end
