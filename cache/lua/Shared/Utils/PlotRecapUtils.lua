local plotRecapStateConst = kg_require("Shared.Const.PlotRecapConst").PLOT_RECAP_STATE

function checkPlotRecapFinished(plotState)
    -- bool, 返回剧情回归是否完成
    return plotState == plotRecapStateConst.UNLOCK

end