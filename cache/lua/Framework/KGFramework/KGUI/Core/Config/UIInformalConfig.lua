-- luacheck: push ignore
ComponentType =
{
    {Id = 1, name = "列表"},
    {Id = 2, name = "按钮"},
}

--name， CellDatas, url， params
ComponentData =
{
    {name = "普通列表", MenuType = 1, CellDatas = {{cellId = UICellConfig.UIListViewExample}}},
    {name = "树状列表", MenuType = 1, CellDatas = {{cellId = UICellConfig.TreeListExample}}},
    {name = "菜单栏", MenuType = 1, CellDatas = {{cellId = UICellConfig.TabListExample}}},
    {name = "按钮", MenuType = 2, CellDatas = {
        {cellId = UICellConfig.UITempComBtn, params = {"测试按钮"}}, 
        {cellId = UICellConfig.UITempComBtnBackArrow},
    }
    }
}

-- luacheck: pop