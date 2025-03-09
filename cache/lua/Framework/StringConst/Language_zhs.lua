-- luacheck: push ignore

-- 1. 这个文件会在提交后通过CI流水线自动提取文本到StringLua.xlsl中
-- 2. 配置的格式必须是：["key_string"] = "value_sring"
-- 3. 所有被导出到excel的文本都会自动标记 --[[exported]]，标记后的文本就不能在这里进行修改，需要到StringLua.xlsl中进行修改
-- 4. 代码中获取这里的文本，请使用StringConst.Get(key)方法


local StrTable = {
    -- Achievement
    ["UI_ACHIEVEMENT"] = "成就", --[[exported]]
    ["UI_COLLECTIBLES"] = "收藏品", --[[exported]]
    ["UI_PLOTRECAP"] = "迷雾", --[[exported]]
    -- ['TEST_11'] = 'TEST_11',
	
	--CustomRole、Fashion
	["FASHION_SAVE_THE_MATCH"] = "保存搭配",
	["FASHION_BUY"] = "购买",
	["FASHION_GO_GET"] = "前往获取",
}


return StrTable





-- luacheck: pop ignore