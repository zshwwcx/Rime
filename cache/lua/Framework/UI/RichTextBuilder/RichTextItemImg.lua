local EStretch = import("EStretch")

--require "UnLua"
local RichTextItemBase =require "Framework.UI.RichTextBuilder.RichTextItemBase"
local RichTextBuilderCommon = require"Framework.UI.RichTextBuilder.RichTextBuilderCommon"
local RichTextItemImg= DefineClass("RichTextItemImg",RichTextItemBase)



function RichTextItemImg:OnInit(Params)
    self.Tag= "img"
    if Params then
        self:SetImg(Params.ImageType,Params.Path)
    end
end

function RichTextItemImg:SetWidth(InWidth)
    self:AddProterty("width",InWidth)
end

function RichTextItemImg:SetHeight(InHeight)
    self:AddProterty("height",InHeight)
end

function RichTextItemImg:SetImg(ImageType,InPathOrRowID)
    self:RemoveProterty("tex2d")
    self:RemoveProterty("sprite")
    self:RemoveProterty("mat")
    self:RemoveProterty("id")

    self.Type = ImageType
    if self.Type == RichTextBuilderCommon.EImageTypes.Texture2D then
        self:AddProterty("tex2d",InPathOrRowID)
    elseif self.Type == RichTextBuilderCommon.EImageTypes.Sprite then
        self:AddProterty("sprite",InPathOrRowID)
    elseif self.Type == RichTextBuilderCommon.EImageTypes.Material then
        self:AddProterty("mat",InPathOrRowID)
    elseif self.Type == RichTextBuilderCommon.EImageTypes.DataTable then
        self:AddProterty("id",InPathOrRowID)
     end
end

function RichTextItemImg:SetImgSource(InPath)
    if self.Type == RichTextBuilderCommon.EImageTypes.Texture2D then
        self:AddProterty("tex2d",InPath)
    elseif self.Type == RichTextBuilderCommon.EImageTypes.Sprite then
        self:AddProterty("sprite",InPath)
    elseif self.Type == RichTextBuilderCommon.EImageTypes.Material then
        self:AddProterty("mat",InPath)
    elseif self.Type == RichTextBuilderCommon.EImageTypes.DataTable then
        self:AddProterty("res",InPath)
    end
end


function RichTextItemImg:SetStretch(InStretch)
    if InStretch then
        local EStretchString = ""
        if InStretch == EStretch.None then
            EStretchString="None"
        elseif InStretch == EStretch.Fill then
            EStretchString="fill"
        elseif InStretch == EStretch.ScaleToFit then
            EStretchString="ScaleToFit"
        elseif InStretch == EStretch.ScaleToFitX then
            EStretchString="ScaleToFitX"
        elseif InStretch == EStretch.ScaleToFitY then
            EStretchString="ScaleToFitY"
        elseif InStretch == EStretch.ScaleToFill then
            EStretchString="ScaleToFill"
        elseif InStretch == EStretch.ScaleBySafeZone then
            EStretchString="ScaleBySafeZone"
        elseif InStretch == EStretch.UserSpecified then
            EStretchString="UserSpecified"
        end

        self:AddProterty("stretch",EStretchString)
    end
end

function RichTextItemImg:OnUnInit()
end




return RichTextItemImg

