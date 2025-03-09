-- 热更新
local Export = {}

function Export.RefreshAllData()
    -- TODO: levelFlow 热更支持
    Game.TableDataManager:ReleaseAllTableData()
    -- 目前Ksbc不支持重载，再次调用_ksbc_load时会报错
    -- 因此在需要重载时，会切换回TableDataManager
    if _G.bUseKsbc then
        _G.bUseKsbc = false
        -- TableData.lua的接口重载
        Game.KsbcMgr:UnInit()
    end

    -- flowchart数据热更
    -- ReloadAIData()
end

return Export
