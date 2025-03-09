local data_util = require("Tools.AbilityPostExport.data_util")

local POST_EXPORT_PREFIX = "Tools.AbilityPostExport.post_exports"
local POST_EXPORT_FILES = {
    "post_export_buffmap",
    "post_export_skillmap",
    "post_export_relation",
}

local LOG_ERROR = function(msg, ...)
    error(string.format(msg, ...))
end

local LOG_INFO = function(msg, ...)
    print(string.format(msg, ...))
end

local STATE = {
    INIT = 0,    -- 未执行
    RUNNING = 1, -- 执行中
    FINISHED = 2 -- 执行完毕
}

---@class PostExportTask
---@field name string 后处理名
---@field outputs string[] 产生的输出内容名字，用|分割。没有可以填nil或者""
---@field comment string 描述
---@field depends string[] 依赖的输出内容，其余后处理的output的字符串列表，用|分割。没有可以填nil或者""
---@field func function 后处理函数
---@field state int STATE的枚举
---@field error string 错误信息


---@type table<string, PostExportTask>
local POST_EXPORTS = {}

---@type string[]
local EXECUTION_ORDER = {}

---@type table<string, string>
local POST_OUTPUT_MAP = {}

local function split(str, sep)
    local ret = {}
    for w in string.gmatch(str, "[^" .. sep .. "]+") do
        ret[#ret + 1] = w
    end
    return ret
end

---声明一个后处理任务
---@param name string 后处理名
---@field outputs string[] 产生的输出内容，用|分割。没有可以填nil或者""
---@param comment string 描述
---@param depends string[] 依赖的后处理，name的的字符串列表，用|分割。没有可以填nil或者""
---@param func function 后处理函数，传入ctx表，用于后处理之间的数据传递
local post_export = function(name, outputs, comment, depends, func)
    EXECUTION_ORDER[#EXECUTION_ORDER + 1] = name
    if outputs and #outputs > 0 then
        for _, output in ipairs(split(outputs, "|")) do
            POST_OUTPUT_MAP[output] = name
        end
    end
    POST_EXPORTS[name] = {
        outputs = outputs,
        depends = (depends == nil or depends == "") and {} or split(depends, "|"),
        func = func,
        comment = comment,
        state = STATE.INIT
    }
end

local function initContext(bsDir, InID, InAssetTable)
    local BSAS = {}
    local BSAB = {}
    local BSBT = {}
    local BSCT = {}
    local BSAPS = {}


    if InID % 10 == 1 then
        BSAS[InID] = InAssetTable
    elseif InID % 10 == 2 then
        BSAB[InID] = InAssetTable
    end

    local outputDir = bsDir .. "\\Extra"

    local context = {
        BSAS = BSAS,
        BSAB = BSAB,
        BSBT = BSBT,
        BSCT = BSCT,
        BSAPS = BSAPS,

        bsDir = bsDir,
        outputDir = outputDir,
        outMap = {},
        read_from_file = function(fileName)
            local file = outputDir .. "\\" .. fileName
            local ret = loadfile(file)
            if not ret then
                return nil
            end
            return ret()
        end
    }

    context.write_to_file = function(data, fileName, comment)
        context.outMap[fileName] = data
    end

    return context
end

local function processOnePostExport(ctx, name)
    local exportInfo = POST_EXPORTS[name]
    if exportInfo.state == STATE.FINISHED then
        return true
    end
    LOG_INFO("process export [%s] start", name)
    for _, dependOutput in ipairs(exportInfo.depends) do
        local dependName = POST_OUTPUT_MAP[dependOutput]
        local postInfo = POST_EXPORTS[dependName]
        if not postInfo then
            LOG_ERROR("process export [%s] depend output %s (%s) not found", name, dependOutput, dependName)
            return false
        end
        if postInfo.state == STATE.RUNNING then
            LOG_ERROR("process export [%s] circular dependency found, %s depend %s running", name, name, dependName)
            return false
        end

        if postInfo.state == STATE.INIT then
            if not processOnePostExport(dependName) then
                return false
            end
        end

        if postInfo.state ~= STATE.FINISHED then
            LOG_ERROR("process export [%s] state error", dependName)
            return false
        end
    end

    exportInfo.func(ctx)

    exportInfo.state = STATE.FINISHED
    LOG_INFO("process export [%s] finish", name)
    return true
end

local function processPostExports(ctx)
    for _, postExportFile in ipairs(POST_EXPORT_FILES) do
        local packageName = POST_EXPORT_PREFIX .. "." .. postExportFile
        package.loaded[packageName] = nil
        require(packageName)
    end

    for _, name in ipairs(EXECUTION_ORDER) do
        local ret = processOnePostExport(ctx, name)
        if not ret then
            return false
        end
    end
end


local function start(bsDir, InID, InAssetTable)
    if InID <= 0 then
        return
    end


    LOG_INFO("--> LoadExportedEnum, fileName: %s", "ExportedEnum")

    local ctx = initContext(bsDir, InID, InAssetTable)

    processPostExports(ctx, "post_exports")

    return ctx.outMap
end

return {
    start = start,
    post_export = post_export,
    LOG_INFO = LOG_INFO,
    LOG_ERROR = LOG_ERROR,
    
}
