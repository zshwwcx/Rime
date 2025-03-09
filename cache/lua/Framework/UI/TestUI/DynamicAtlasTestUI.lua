local DynamicAtlasTestUI = DefineClass("DynamicAtlasTestUI", UIController)
local SubsystemBlueprintLibrary = import("SubsystemBlueprintLibrary")
local DynamicAtlasSubsystem = import("DynamicAtlasSubsystem")

function DynamicAtlasTestUI:OnCreate()
    self:AddUIListener(EUIEventTypes.CLICK, self.View.button1, self.OnClick1)
    self:AddUIListener(EUIEventTypes.CLICK, self.View.button2, self.OnClick2)
    self:AddUIListener(EUIEventTypes.CLICK, self.View.button3, self.OnClick3)
	
    self:Init()
end

function DynamicAtlasTestUI:OnRefresh()
end

function DynamicAtlasTestUI:Init()
    self.spritePath = {
        "/Game/Arts/UI_2/Blueprint/TestUI/DynamicAtlas/myte1_DynamicSprite.myte1_DynamicSprite",
        "/Game/Arts/UI_2/Blueprint/TestUI/DynamicAtlas/myte2_DynamicSprite.myte2_DynamicSprite",
        "/Game/Arts/UI_2/Blueprint/TestUI/DynamicAtlas/myte3_DynamicSprite.myte3_DynamicSprite",
        "/Game/Arts/UI_2/Blueprint/TestUI/DynamicAtlas/myte4_DynamicSprite.myte4_DynamicSprite",
    }
end

function DynamicAtlasTestUI:OnRefresh_ItemList(widget, index, selected)
    --self:SetImage(widget.View.image1, self.spritePath[index])
end

function DynamicAtlasTestUI:OnClick1()
	local system = SubsystemBlueprintLibrary.GetGameInstanceSubsystem(
		_G.GetContextObject(), DynamicAtlasSubsystem
	)
	
	system:TestShowBig(self.View.image1, 0)
end

function DynamicAtlasTestUI:OnClick2()
	self:SetImage(self.View.image2, self.spritePath[math.random(1, #self.spritePath)])
end

function DynamicAtlasTestUI:OnClick3()
	self:SetImage(self.View.image3, self.spritePath[math.random(1, #self.spritePath)])
end

return DynamicAtlasTestUI
