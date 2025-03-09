local ListAnimationLibrary = DefineClass("ListAnimationLibrary")

ListAnimationLibrary.CellAnimationType = {
    AddAnimation = 1,
    RemoveAnimation = 2,
    InAnimation = 3,
    OutAnimation = 4,
    Custom0 = 5,
    Custom1 = 6,
    Custom2 = 7
}
ListAnimationLibrary.CellState = {
    Other = 0,
    In = 1,
    Out = 2,
    Select = 3,
    UnSelect = 4,
    Idle = 5,
}

ListAnimationLibrary.Player = {
    Auto = 0,
    Stagger = 1,
    Move = 2,
}

function ListAnimationLibrary.InitPlayerPool()
    local pool = {
        [ListAnimationLibrary.Player.Auto] = {},
        [ListAnimationLibrary.Player.Stagger] = {},
        [ListAnimationLibrary.Player.Move] = {},
    }
    return pool
end

function ListAnimationLibrary.GetAniDataByType(config)
    if not config or not config.AnimationType then return end
    if config.AnimationType == ListAnimationLibrary.Player.Auto then
        return config.CellAnimation, ListAnimationLibrary.Player.Auto
    elseif config.AnimationType == ListAnimationLibrary.Player.Stagger then
        return config.StaggerAnimation, ListAnimationLibrary.Player.Stagger
    elseif config.AnimationType == ListAnimationLibrary.Player.Move then
        return config.MoveAnimation, ListAnimationLibrary.Player.Move
    end
end


function ListAnimationLibrary.getWidgetByPath(uiComponent, path)
    local widget = uiComponent.View
    for i = 1, #path do
        widget = widget[path[i]]
        if not widget then
            break
        end
    end
    return widget
end

function ListAnimationLibrary.GetCellAnimation(cell, type)
    local ani
    if cell and type then
        if type == ListAnimationLibrary.CellAnimationType.AddAnimation then
            ani = cell.View.WidgetRoot:AddAnimation()
        elseif type == ListAnimationLibrary.CellAnimationType.RemoveAnimation then
            ani = cell.View.WidgetRoot:RemoveAnimation()
        elseif type == ListAnimationLibrary.CellAnimationType.InAnimation then
            ani = cell.View.WidgetRoot:InAnimation()
        elseif type == ListAnimationLibrary.CellAnimationType.OutAnimation then
            ani = cell.View.WidgetRoot:OutAnimation()
        elseif type == ListAnimationLibrary.CellAnimationType.Custom0 then
            ani = cell.View.WidgetRoot:CustomAnimation0()
        elseif type == ListAnimationLibrary.CellAnimationType.Custom1 then
            ani = cell.View.WidgetRoot:CustomAnimation1()
        elseif type == ListAnimationLibrary.CellAnimationType.Custom2 then
            ani = cell.View.WidgetRoot:CustomAnimation2()
        end
    end
    return ani
end

return ListAnimationLibrary