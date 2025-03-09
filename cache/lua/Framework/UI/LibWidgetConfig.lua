-- 这里为了解决WBP_Lib被前置加载，在Loading时内存就占用极大的问题，改为配置加载，每个页面依赖的LibWidget对象在PreLoadList时被确定，同时在UIManager做好name->WidgetInstance的缓存。

-- todo1: 先将子蓝图部分加过来，部分不是子蓝图的内容，后面拼接成子蓝图也挂这里。

-- todo2: 几个列表的LibWidget是从蓝图里面读取的，这里需要修改对应的FormComponent接口，不从Lib里面去Form，直接从自身蓝图去Form

local LibWidgetConfig = {
   ["GuildResponseInvite"] = '/Game/Arts/UI_2/Blueprint/Chat/WBP_ChatBubble_GuildResponse.WBP_ChatBubble_GuildResponse_C',

   ["WBP_GuildDanceFlick"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_GuildDance/WBP_HUDGuildDanceFlick.WBP_HUDGuildDanceFlick_C',

   ["WBP_GuildDanceHold"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_GuildDance/WBP_HUDGuildDanceTabHold.WBP_HUDGuildDanceTabHold_C',

   ["WBP_GuildDanceTap"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_GuildDance/WBP_HUDGuildDanceTap.WBP_HUDGuildDanceTap_C',

   ["WBP_DanceTap"] = '/Game/Arts/UI_2/Blueprint/Guild/GuildDance/Test/WBP_DanceTap.WBP_DanceTap_C',

   ["WBP_DanceHold"]  = '/Game/Arts/UI_2/Blueprint/Guild/GuildDance/Test/WBP_DanceHold.WBP_DanceHold_C',

   ["WBP_DanceFlick"] = '/Game/Arts/UI_2/Blueprint/Guild/GuildDance/Test/WBP_DanceFlick.WBP_DanceFlick_C',

   ["Title"] = '/Game/Arts/UI_2/Blueprint/Lib/WBP_Lib_Title.WBP_Lib_Title_C',

   -- Title_Auction 没用

   ["Equipment"] = '/Game/Arts/UI_2/Blueprint/Lib/WBP_Lib_Equipment.WBP_Lib_Equipment_C',

   -- Equipment_IconAttribute 没用

   ["Line"] = '/Game/Arts/UI_2/Blueprint/Lib/WBP_Lib_Line.WBP_Lib_Line_C',

   ["Text"] = '/Game/Arts/UI_2/Blueprint/Lib/WBP_Lib_Text.WBP_Lib_Text_C',

   -- ["Text_MultiColumn"] = ,

   ["Sealed"] = '/Game/Arts/UI_2/Blueprint/Sealed/WBP_SealedBuff.WBP_SealedBuff_C',

   ["TreasureReward"] = '/Game/Arts/UI_2/Blueprint/Tips/ItemTips/WBP_ItemDetailList.WBP_ItemDetailList_C',

   ["BtnNormM"] = '/Game/Arts/UI_2/Blueprint/Tips/ItemTips/WBP_ItemTipsBtn.WBP_ItemTipsBtn_C',

   -- EquipEnhance 没用

   ["ChatBarrage"] = '/Game/Arts/UI_2/Blueprint/Chat/WBP_ChatBarrage.WBP_ChatBarrage_C',

   -- Currency 没用

   ["CurrencyList"] = '/Game/Arts/UI_2/Blueprint/Common/Tag/WBP_ComCurrencyList.WBP_ComCurrencyList_C',

   ["FloatingDamage"] = '/Game/Arts/UI_2/Blueprint/FloatingDamage/WBP_FloatingDamage.WBP_FloatingDamage_C',

   ["ForwardBtn"] = '/Game/Arts/UI_2/Blueprint/Common/Button/WBP_ComBtn.WBP_ComBtn_C',

   ["NPCBtnSelect"] = '/Game/Arts/UI_2/Blueprint/NPC/WBP_NPCBtnSelect.WBP_NPCBtnSelect_C',

   ["P_ChatSmall"] = '/Game/Arts/UI_2/Blueprint/Chat/WBP_ChatSmall.WBP_ChatSmall_C',

   -- Size Box 没用

   ["ComRedPoint"] = '/Game/Arts/UI_2/Blueprint/Lib/WBP_Lib_RedPoint.WBP_Lib_RedPoint_C',

   -- WBP_ChatAtBtn 没用

   ["WBP_ItemBox"] = '/Game/Arts/UI_2/Blueprint/Item/WBP_ItemBox.WBP_ItemBox_C',

   --["WBP_ItemQuality4"] = '/Game/Arts/UI_2/Blueprint/Item/WBP_ItemQuality4.WBP_ItemQuality4_C',

   ["WBP_ItemQuality5"] = '/Game/Arts/UI_2/Blueprint/Item/WBP_ItemQuality5.WBP_ItemQuality5_C',

   ["WBP_ItemQuality6"] = '/Game/Arts/UI_2/Blueprint/Item/WBP_ItemQuality6.WBP_ItemQuality6_C',

   ["WBP_ItemQuality7"] = '/Game/Arts/UI_2/Blueprint/Item/WBP_ItemQuality7.WBP_ItemQuality7_C',

   ["ItemNml"] = '/Game/Arts/UI_2/Blueprint/Item/WBP_ItemNml.WBP_ItemNml_C',

   ["WBP_ItemReward"] = '/Game/Arts/UI_2/Blueprint/Item/WBP_ItemReward.WBP_ItemReward_C',

   ["DungeonPlayerDisplayItem"] = '/Game/Arts/UI_2/Blueprint/Dungeon/WBP_DungeonCards.WBP_DungeonCards_C',

   ["ChatExpression"] = '/Game/Arts/UI_2/Blueprint/Chat/WBP_ChatBubble_Emo.WBP_ChatBubble_Emo_C',

   ["TeamInvite"] = '/Game/Arts/UI_2/Blueprint/Chat/WBP_ChatBubble_TeamRecruit.WBP_ChatBubble_TeamRecruit_C',

   ["GroupInvite"] = '/Game/Arts/UI_2/Blueprint/Chat/WBP_ChatBubble_GroupRecruit.WBP_ChatBubble_GroupRecruit_C',

   ["GuildHelp"] = '/Game/Arts/UI_2/Blueprint/Chat/WBP_ChatBubble_GuildHelp.WBP_ChatBubble_GuildHelp_C',

   ["AshButton2"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_AshQTE/WBP_HUDAshQTEBtn_2.WBP_HUDAshQTEBtn_2_C',

   ["AshButton"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_AshQTE/WBP_HUDAshQTEBtn.WBP_HUDAshQTEBtn_C',

   -- SubTitle 没用

   ["SealedBreak"] = '/Game/Arts/UI_2/Blueprint/Lib/WBP_Lib_SealedBreak.WBP_Lib_SealedBreak_C',

   -- LimitedInfo 没用

   ["Countdown"] = '/Game/Arts/UI_2/Blueprint/Lib/WBP_Lib_Countdown.WBP_Lib_Countdown_C',

   ["WBP_HUDElementChaos"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_Element/WBP_HUDElementChaos.WBP_HUDElementChaos_C',

   ["WBP_ComSelectedLight"] = '/Game/Arts/UI_2/Blueprint/Item/WBP_ComSelectedLight.WBP_ComSelectedLight_C',

   ["WBP_RedPacket"] = '/Game/Arts/UI_2/Blueprint/RedPacket/RedPacket_Item/WBP_RedPacket_Envelope_Small_Item.WBP_RedPacket_Envelope_Small_Item_C',

   -- WBP_ShopDesText 没用

   -- KGImage_Split 没用

   ["WBP_ShopDesRichText"] = '/Game/Arts/UI_2/Blueprint/Shop/Shop/WBP_ShopDesRichText.WBP_ShopDesRichText_C',

   ["WBP_ShopDscItem_Item"] = '/Game/Arts/UI_2/Blueprint/Shop/Shop/WBP_ShopDscItem_Item.WBP_ShopDscItem_Item_C',

   ["WBP_HUDElementChaos"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_Element/WBP_HUDElementChaos.WBP_HUDElementChaos_C',

   ["WBP_HUDElementSleep"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_Element/WBP_HUDElementSleep.WBP_HUDElementSleep_C',

   ["WBP_HUDElementShadow"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_Element/WBP_HUDElementShadow.WBP_HUDElementShadow_C',

   ["WBP_HUDElementRich"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_Element/WBP_HUDElementRich.WBP_HUDElementRich_C',

   ["WBP_HUDElementMysterious"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_Element/WBP_HUDElementMysterious.WBP_HUDElementMysterious_C',

   ["WBP_HUDElementDisaster"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_Element/WBP_HUDElementDisaster.WBP_HUDElementDisaster_C',

   ["WBP_HUDElementDisorder"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_Element/WBP_HUDElementDisorder.WBP_HUDElementDisorder_C',

   ["WBP_HUDElementKnowledge"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_Element/WBP_HUDElementKnowledge.WBP_HUDElementKnowledge_C',

   ["WBP_HUDElementDestiny"] = '/Game/Arts/UI_2/Blueprint/HUD/HUD_Element/WBP_HUDElementDestiny.WBP_HUDElementDestiny_C',

   ["WBP_ComSelectedLight"] = '/Game/Arts/UI_2/Blueprint/Item/WBP_ComSelectedLight.WBP_ComSelectedLight_C',

   ["WBP_ChatBubble_TeamRecruitL"] = '/Game/Arts/UI_2/Blueprint/Chat/WBP_ChatBubble_TeamRecruitL_Item.WBP_ChatBubble_TeamRecruitL_Item_C',

   ["WBP_ChatBubble_TeamRecruitR"] = '/Game/Arts/UI_2/Blueprint/Chat/WBP_ChatBubble_TeamRecruitR_Item.WBP_ChatBubble_TeamRecruitR_Item_C',

   ["WBP_RolePlaySkillNode"]  = '/Game/Arts/UI_2/Blueprint/RolePlay/RolePlayNew/WBP_RolePlaySkillNode.WBP_RolePlaySkillNode_C',
   
   ["WBP_PharmacistPointItem"] = '/Game/Arts/UI_2/Blueprint/Pharmacist/Make/WBP_PharmacistPointItem.WBP_PharmacistPointItem_C',
   ["WBP_PharmacistGrid_Item"] = '/Game/Arts/UI_2/Blueprint/Pharmacist/Make/WBP_PharmacistGrid_Item.WBP_PharmacistGrid_Item_C',

}

return LibWidgetConfig