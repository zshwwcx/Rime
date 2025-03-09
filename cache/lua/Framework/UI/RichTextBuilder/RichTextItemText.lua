--require "UnLua"
local RichTextItemBase = require "Framework.UI.RichTextBuilder.RichTextItemBase"

local RichTextItemText= DefineClass("RichTextItemText",RichTextItemBase)



function RichTextItemText:ctor(Params)
    self.Tag = nil
    self.Content =  nil
    self.Properties = nil
    
end


function RichTextItemText:OnInit(Params)
    if Params then
        self.Tag = Params.Style
        self.Content = Params.Content or nil
    end
    -- Log.Debug("RichTextItemText:OnInit",self.Tag,self.Content)
end

function RichTextItemText:SetStyle(InStyle)
    self.Tag = InStyle
end

function RichTextItemText:SetColor(InColor)
    self:AddProterty("color", InColor)
end

function RichTextItemText:SetColorFromTable(TableName, RowName)
    local Prefix = "DT_"
    if string.sub(TableName, 1, #Prefix) == Prefix then
        TableName = string.sub(TableName, #Prefix + 1, -1)
    end

    self:AddProterty("tablecolor", TableName .. "_" .. RowName)
end

function RichTextItemText:ToString()
    if #self.Properties > 0 and self.Tag == nil then
        self.Tag = "default"
    end
    return RichTextItemBase.ToString(self)
end

function RichTextItemText:SetSize(InSize)
    self:AddProterty("size", InSize)
end

function RichTextItemText:SetHyperLinkStyle(style)
    self:AddProterty("stylename", style)
end

function RichTextItemText:SetHyperLinkUrl(url)
    self:AddProterty("url", url)
end

function RichTextItemText:OnUnInit()
end

return RichTextItemText
