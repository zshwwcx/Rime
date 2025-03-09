local string_len = string.len
local string_sub = string.sub
local table_insert = table.insert
local table_sort = table.sort

local function pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do table_insert(a, n) end
    table_sort(a, f)
    local i = 0              -- iterator variable
    local iter = function()  -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

local function split_table_line(str_tab, indent, splitline)
    if not splitline then
        return
    end
    table_insert(str_tab, '\n')
    for i = 1, indent do
        table_insert(str_tab, '    ')
    end
    return
end

local function is_pure_array(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    for i = 1, count do
        if t[i] == nil then
            return false
        end
    end

    if type(t[1]) == 'table' then
        local isSubTableArray = is_pure_array(t[1])
        if isSubTableArray then
            return true, false
        else
            return true, true
        end
    else
        return true, false
    end
end

-- 将\n, \', \"转义成\\n, \\', \\"，不然在输出lua文件时会直接当成对应的字符生效了
local function escape_string(str)
    local tmp = str:gsub('\n', '\\n')
    tmp = tmp:gsub("\'", "\\'")
    tmp = tmp:gsub('\"', '\\"')
    return tmp
end

---将table转成string格式，支持嵌套table，不支持table里有function的情况
---@param t table 序列化的目标
---@param indent int 当前行的缩进
---@param splitline boolean 当前table是否分行
---@param formulaKey string 可选，标识公式的key
---@param isSingleTb boolean 可选，部分宏定义table输出尾部不带逗号
---@return string 返回对应table的字符串表达
local function serialize_table(t, indent, splitline, formulaKey, isSingleTb)
    assert(type(t) == 'table')
    local str_tab = {}
    table_insert(str_tab, '{')
    local isPureArray = is_pure_array(t)
    if isPureArray then
        -- 纯数组采用数组形式输出 不用[k]=v的格式
        for i = 1, #t do
            -- if indent < indent + 1 then
            --     split_table_line(str_tab, indent + 1, splitline)
            --     table_insert(str_tab, '[')
            --     table_insert(str_tab, tostring(i))
            --     table_insert(str_tab, '] = ')
            -- end

            local value = t[i]
            local value_type = type(value)
            if value_type == 'table' then
                table_insert(str_tab, serialize_table(value, indent + 1, false))
            else
                if value_type == 'string' then
                    table_insert(str_tab, "'")
                    local tmp = escape_string(value)
                    table_insert(str_tab, tmp)
                    table_insert(str_tab, "'")
                else
                    assert(value_type ~= 'function')
                    table_insert(str_tab, tostring(value))
                end
                if i ~= #t then
                    table_insert(str_tab, ', ')
                end
            end
        end
    else
        for key, value in pairsByKeys(t) do
            if string_sub(key, 1, 2) ~= '__' then
                local key_type = type(key)
                local value_type = type(value)
                split_table_line(str_tab, indent + 1, splitline)
                if key_type == 'string' then
                    table_insert(str_tab, "['")
                    table_insert(str_tab, key)
                    table_insert(str_tab, "']")
                    table_insert(str_tab, ' = ')
                else
                    table_insert(str_tab, '[')
                    table_insert(str_tab, tostring(key))
                    table_insert(str_tab, '] = ')
                end
                if value_type == 'table' then
                    table_insert(str_tab, serialize_table(value, indent + 1, false, formulaKey))
                else
                    if value_type == 'string' then
                        if formulaKey and key == formulaKey then
                            table_insert(str_tab, value)
                        else
                            table_insert(str_tab, "'")
                            local tmp = escape_string(value)
                            table_insert(str_tab, tmp)
                            table_insert(str_tab, "'")
                        end
                    else
                        assert(value_type ~= 'function')
                        table_insert(str_tab, tostring(value))
                    end
                    table_insert(str_tab, ', ')
                end
            end
        end
    end

    split_table_line(str_tab, indent, splitline)
    table_insert(str_tab, isSingleTb and '}' or '}, ')
    return table.concat(str_tab, '')
end

local function gen_data_line(key, value, indent, ignoreQuotes, formulaKey)
    local line = {}
    for _ = 1, indent do
        table_insert(line, '    ')
    end
    if type(key) == 'string' then
        if not ignoreQuotes then
            table_insert(line, "['")
        end
        table_insert(line, key)
        if not ignoreQuotes then
            table_insert(line, "']")
        end
        table_insert(line, ' = ')
    else
        table_insert(line, '[')
        table_insert(line, tostring(key))
        table_insert(line, '] = ')
    end

    local value_str = ''
    local value_type = type(value)
    if value_type == 'table' then
        value_str = serialize_table(value, indent, true, formulaKey)
        if string_sub(value_str, string_len(value_str), string_len(value_str)) == " " then
            value_str = string_sub(value_str, 1, string_len(value_str) - 1)
        end
    elseif value_type == 'string' then
        if formulaKey and key == formulaKey then
            value_str = value_str .. ', '
        else
            value_str = escape_string(value)
            value_str = "'" .. value_str .. "', "
        end
    else
        assert(value_type ~= 'function')
        value_str = tostring(value) .. ', '
    end
    table_insert(line, value_str)
    table_insert(line, '\n')
    return line
end

---输出data到文件, 忽略 __ 开头的key
---@param data table 要写入文件的table对象
---@param outputPath string 文件路径, 含文件名
---@param commentTableName string 注释, 比如 "xxx（后处理）"
---@param extraTb table，可选，用于输出和data平级的一些字段
---@param formulaKey string 可选, 标识公式的key（unused)
local function write_data(data, outputPath, commentTableName, extraTb, formulaKey)
    local file = io.open(outputPath, 'w')
    if not file then
        error('cannot open file: ' .. outputPath)
        return
    end

    file:write('--\n')
    file:write('-- 表名: ' .. commentTableName .. '\n')
    file:write('--\n\n')
    file:write('local TopData = {\n')

    for key, value in pairsByKeys(extraTb or {}) do
        local line = gen_data_line(key, value, 1, true, formulaKey)
        file:write(table.concat(line, ''))
    end

    file:write('    data = {\n')
    for key, value in pairsByKeys(data) do
        if string_sub(key, 1, 2) ~= '__' then
            local line = gen_data_line(key, value, 2, false, formulaKey)
            file:write(table.concat(line, ''))
        end
    end

    file:write('    }\n')
    file:write('}\n')
    file:write('return TopData')
    file:close()
end

local function write_to_file(dir, data, fileName, comment)
    local outputPath = dir .. "\\" .. fileName
    write_data(data, outputPath, comment)
end

return {
    serialize = serialize_table,
    write = write_to_file
}
