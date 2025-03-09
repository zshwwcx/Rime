--require "UnLua"

local RichTextItemBase= DefineClass("RichTextItemBase")


function RichTextItemBase:Init(Params)
    local mt = getmetatable(self)
    mt.__tostring = self.ToString
    setmetatable(self, mt)

    self.Tag = nil
    self.Properties ={}
    self.Content = nil

    self:OnInit(Params)
end

function RichTextItemBase:UnInit()
    self.Tag = nil
    self.Properties = nil
    self.Content = nil
end

function RichTextItemBase:SetContent(InContent)
    self.Content = InContent or ""
end

function RichTextItemBase:SetTag(InTag)
    self.Tag = InTag
end

local function BuildPropertiesString(self)
    local PropertiesString = ""
    for K,V in pairs(self.Properties) do
        PropertiesString = PropertiesString .. " " .. tostring(K) .. "=" .. "\"" ..tostring(V).. "\""
    end
    return PropertiesString
end

function RichTextItemBase:AddProterty(key,Value)
    self.Properties[key] = Value
end

function RichTextItemBase:RemoveProterty(key)
    self.Properties[key] = nil
end

-- functions to override
function RichTextItemBase:OnInit(Params)
end

function RichTextItemBase:OnUnInit(Params)
end


function RichTextItemBase:ToString()
    local PropertiesString = BuildPropertiesString(self)
    if self.Tag==nil then
        return tostring(self.Content)
    end

    if self.Content == nil then
        return "<" .. tostring(self.Tag) .. PropertiesString.."/>"
    else
        return "<" .. tostring(self.Tag) .. PropertiesString..">" ..tostring(self.Content) .."</>"
    end
end

return RichTextItemBase

