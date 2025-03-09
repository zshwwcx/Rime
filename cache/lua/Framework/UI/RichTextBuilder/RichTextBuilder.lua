--require "UnLua"
local RichTextBuilderCommon = require "Framework.UI.RichTextBuilder.RichTextBuilderCommon"
local RichTextItemText = require "Framework.UI.RichTextBuilder.RichTextItemText"
local RichTextItemImg = require "Framework.UI.RichTextBuilder.RichTextItemImg"

local RichTextBuilder= DefineClass("RichTextBuilder")

function RichTextBuilder:ctor()
    self.__Items = {}
end

function RichTextBuilder:dtor()
    for _, V in pairs(self.__Items) do
        V:UnInit()
    end
    self.__Items = nil
end

--Clear All
function RichTextBuilder:ClearAll()
    for _, V in pairs(self.__Items) do
        V:UnInit()
    end
    self.__Items = {}
end

--Build the RichText String
function RichTextBuilder:BuildString()
    local OutString = ""
    for _, V in pairs(self.__Items) do
        OutString = OutString .. V:ToString()
    end
    return OutString
end

--Generate a text item
function RichTextBuilder:GenerateTextItem(InString, Style)
    local TextItem = RichTextItemText.new()
    TextItem:Init(
        {
            Builder = self,
            Style = Style,
            Content = InString
        }
    )
    return TextItem
end

--Generate an ImageItem
function RichTextBuilder:GenerateImgItem(ImageType, Path)
    local ImgItem = RichTextItemImg.new()
    ImgItem:Init(
        {
            Builder = self,
            ImageType = ImageType,
            Path = Path
        }
    )
    return ImgItem
end

--Append Text at End
function RichTextBuilder:AppendText(String, Style)
    local TextItem = self:GenerateTextItem(String, Style)
    table.insert(self.__Items, TextItem)
    return TextItem
end

--Insert Text at Position
function RichTextBuilder:InsertText(String, Pos, Style)
    local TextItem = self:GenerateTextItem(String, Style)
    -- Log.Debug(String,Pos,Style)
    table.insert(self.__Items, Pos, TextItem)
    return TextItem
end

--Append a New line at End
function RichTextBuilder:AppendNewLine()
    return self:AppendText("\n")
end

--Append a New line at Position
function RichTextBuilder:InsertNewLine(Pos)
    return self:InsertText("\n", Pos)
end

-- Insert Img at End
function RichTextBuilder:AppendImage(ImageType, Path)
    if ImageType == nil or Path == nil then
        Log.Warning("AppendImage Fail:  ImgItem is nil")
        return
    end

    local ImgItem = self:GenerateImgItem(ImageType, Path)
    table.insert(self.__Items, ImgItem)
    return ImgItem
end

-- Insert Img at Position
function RichTextBuilder:InsertImage(ImageType, Path, Pos)
    if ImageType == nil or Path == nil then
        Log.Warning("InsertImage Fail:  ImgItem is nil")
        return
    end
    local ImgItem = self:GenerateImgItem(ImageType, Path)
    table.insert(self.__Items, Pos, ImgItem)
    return ImgItem
end

-- Append Item at Position
function RichTextBuilder:AppendItem(Item)
    if Item == nil then
        Log.Warning("AppendItem Fail:  Item is nil")
        return
    end

    table.insert(self.__Items, Item)
    return Item
end

-- Insert Item at Postion
function RichTextBuilder:InsertItem(Item, Pos)
    if Item == nil then
        Log.Warning("InsertItem Fail:  Item or Pos is nil")
        return
    end

    table.insert(self.__Items, Pos, Item)
    return Item
end

--RemoveItem
function RichTextBuilder:RemoveItem(Pos)
    table.remove(self.__Items, Pos)
end

--Get a copy table of all items
function RichTextBuilder:GetItems()
    local Items = {}
    for _, V in pairs(self.__Items) do
        table.insert(Items, V)
    end
    return Items
end

--GetItem
function RichTextBuilder:GetItem(idx)
    return self.__Items[idx]
end

--GetNumber of items
function RichTextBuilder:ItemCount()
    return #self.__Items
end

--find the location of the item, it will return the first found,return 0 if not found
function RichTextBuilder:FindItemPos(Item)
    for Idx, V in pairs(self.__Items) do
        if V == Item then
            return Idx
        end
    end
    return 0
end

RichTextBuilder.EImageTypes = RichTextBuilderCommon.EImageTypes
return RichTextBuilder
