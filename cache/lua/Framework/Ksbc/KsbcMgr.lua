local KsbcIgnore = kg_require("Data.Config.Ksbc.KsbcIgnore").KsbcIgnore

---@class KsbcMgr
local KsbcMgr = DefineClass("KsbcMgr")

function KsbcMgr:ctor()
    self.stringDB = {}
    self.langKeyMap = {}
end

function KsbcMgr:dtor()
    self.stringDB = {}
    self.langKeyMap = {}
end

function KsbcMgr:Init()
    -- 控制变量开启且非编辑器才会启用ksbc
    if (_G.bUseKsbc == false) and (_G.UE_EDITOR == true) then
        Log.Debug("[Init] gonna not use ksbc")
        return
    end

    Log.Debug("[Init] gonna use ksbc")

    -- 加载Ksbc数据
    local ret, msg = pcall(_ksbc_load, "Data\\Excel\\ksbc\\TableData.ksbc")
    if not ret then
        Log.ErrorFormat("[Init] ksbc bin load failed, use normal table data \n%s", msg)
        _G.bUseKsbc = false
        return
    end

    -- 加载原始多语言数据
    local lang = Game.TableDataManager:GetLangType()
    local stringDBPath = "Data.Excel.LanguageData.StringDB_" .. lang .."_Data"
    local langKeyMapPath = "Data.Excel.LanguageData.KeyMappingTable_" .. lang .. "_Data"
    self.stringDB = require(stringDBPath).data
    self.langKeyMap = require(langKeyMapPath).data

    -- 多语言接口重载
    SetKsbcMultiLanguageSupportCB(function(index)
        return self:KsbcGetLangStr(index)
    end)

    -- TableData.lua的接口重载
    local RawGetRow = Game.TableDataManager.GetRow
    Game.TableDataManager.GetRow = function(_, tableName, key)
        if KsbcIgnore[tableName] then
            return RawGetRow(_, tableName, key)
        end
        return ksbcRawG()[tableName].data[key]
    end

    local RowGetData = Game.TableDataManager.GetData
    Game.TableDataManager.GetData = function(_, tableName)
        if KsbcIgnore[tableName] then
            return RowGetData(_, tableName)
        end
        return ksbcRawG()[tableName].data
    end

    local RowGetAttr = Game.TableDataManager.GetAttr
    Game.TableDataManager.GetAttr = function(_, tableName, attrName)
        if KsbcIgnore[tableName] then
            return RowGetAttr(_, tableName, attrName)
        end
        return ksbcRawG()[tableName][attrName]
    end

    local RowHotfixRow = Game.TableDataManager.HotfixRow
    Game.TableDataManager.HotfixRow = function(_, tableName, key, newRow)
        if KsbcIgnore[tableName] then
            RowHotfixRow(_, tableName, key, newRow)
            return
        end
        local targetRow = ksbcRawG()[tableName] and ksbcRawG()[tableName].data[key] or nil

        Game.IsHotfixing = true
        if type(targetRow) == "table" and type(newRow) == "table" then
            for newKey, newValue in pairs(newRow) do
                targetRow[newKey] = newValue
            end
        else
            ksbcRawG()[tableName].data[key] = newRow
        end
        Game.IsHotfixing = false
    end
end

function KsbcMgr:UnInit()
    self.stringDB = {}
    self.langKeyMap = {}
    Game.TableDataManager.GetRow = nil
    Game.TableDataManager.GetData = nil
    Game.TableDataManager.GetAttr = nil
    Game.TableDataManager.HotfixRow = nil
end

function KsbcMgr:KsbcGetLangStr(index)
    return self.stringDB[self.langKeyMap[index]]
end

return KsbcMgr.new()
