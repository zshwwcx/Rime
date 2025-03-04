#include "NPCActorDetails.h"
#include "C7Editor/C7Editor.h"
#include "DetailCategoryBuilder.h"
#include "DetailWidgetRow.h"

TSharedRef<IDetailCustomization> FNPCActorDetails::MakeInstance()
{
	return MakeShareable(new FNPCActorDetails);
}

FNPCActorDetails::FNPCActorDetails()
{
	const FString TemplatePath = "DataTable'/Game/Template/NPCTemplate/NPCTemplates.NPCTemplates'";
	// TemplateTable = LoadObject<UDataTable>(nullptr, *TemplatePath);
	// if (TemplateTable)
	// {
	// 	CharacterDatas.Empty();
	// 	TArray<FName>  RowNames = TemplateTable->GetRowNames();
	// 	for (const auto& Name : RowNames)
	// 	{
	// 		FNPCTemplateTable* Row = TemplateTable->FindRow<FNPCTemplateTable>(Name, FString(""));
	// 		CharacterDatas.Add(MakeShareable(new FString(Row->Description)));
	// 	}
	//
	// 	if (GetEdMode())
	// 	{
	// 		FNPCTemplateTable* Row = TemplateTable->FindRow<FNPCTemplateTable>("0", FString(""));
	// 		GetEdMode()->SetNPCTemplate(Row->BlueprintPath);
	// 	}
	// }
}

void FNPCActorDetails::CustomizeDetails(IDetailLayoutBuilder& DetailLayout)
{	
	//TArray<TWeakObjectPtr<UObject>> Objects;
	//DetailLayout.GetObjectsBeingCustomized(Objects);
	//if (Objects.Num() != 1)
	//{
	//	return;
	//}
	//ALTNPCActor* Actor = (ALTNPCActor*)Objects[0].Get();
	//DetailLayout.HideProperty(DetailLayout.GetProperty(GET_MEMBER_NAME_CHECKED(ALTNPCActor, ShowMeshInEditor)));
	//DetailLayout.HideProperty(DetailLayout.GetProperty(GET_MEMBER_NAME_CHECKED(ALTNPCActor, DisableMeshInEditor)));

	//IDetailCategoryBuilder& OptionsCategory = DetailLayout.EditCategory("Options", FText::FromString(""), ECategoryPriority::Important);
	//OptionsCategory.AddCustomRow(FText::FromString("Options"))
	//			.WholeRowContent()
	//			[
	//				SNew(SVerticalBox)
	//				+ SVerticalBox::Slot()
	//				.AutoHeight()
	//				.VAlign(VAlign_Center)
	//				[
	//					SNew(SCheckBox)
	//					.Style(FAppStyle::Get(), "RadioButton")
	//					.IsChecked(this, &FNPCActorDetails::IsModeRadioChecked, Actor, 1)
	//					.OnCheckStateChanged(this, &FNPCActorDetails::OnModeRadioChanged, Actor, 1)
	//					[
	//						SNew(STextBlock).Text(FText::FromString("ShowMeshInEditor"))
	//					]
	//				]
	//				+ SVerticalBox::Slot()
	//				.AutoHeight()
	//				.VAlign(VAlign_Center)
	//				[
	//					SNew(SCheckBox)
	//					.Style(FAppStyle::Get(), "RadioButton")
	//					.IsChecked(this, &FNPCActorDetails::IsModeRadioChecked, Actor, 2)
	//					.OnCheckStateChanged(this, &FNPCActorDetails::OnModeRadioChanged, Actor, 2)
	//					[
	//						SNew(STextBlock).Text(FText::FromString("DisableMeshInEditor"))
	//					]
	//				]
	//				/*+ SVerticalBox::Slot()
	//				.VAlign(VAlign_Center)
	//				[
	//					SNew(SComboBox<TSharedPtr<FString>>)
	//					.OptionsSource(&this->CharacterDatas)
	//					.OnSelectionChanged(this, &FNPCActorDetails::OnSelectNPCTemplate)
	//					.OnGenerateWidget_Lambda([](TSharedPtr<FString> value)->TSharedRef<SWidget>
	//					{
	//						return SNew(STextBlock).Text(FText::FromString(*value));
	//					})
	//					[
	//						SNew(STextBlock)
	//						.Text(this, &FNPCActorDetails::OnGetNPCTemplateText)
	//					]
	//				]*/
	//			];
	
}

// comment by shijingzhe: delete deprecated ALTNpcSpawner
// ECheckBoxState FNPCActorDetails::IsModeRadioChecked(ALTNpcSpawner* Actor, int OptionIndex) const
// {
// 	bool ShowMesh = false;
// 	if (Actor)
// 	{
// 		if (OptionIndex == 1)
// 			ShowMesh = Actor->ShowMeshInEditor;
//
// 	else if (OptionIndex == 2)
// 			ShowMesh = Actor->DisableMeshInEditor;
// 	}
// 	// to do, show mesh in editor
// 	return ShowMesh ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
// }

// comment by shijingzhe: delete deprecated ALTNpcSpawner
// void FNPCActorDetails::OnModeRadioChanged(ECheckBoxState CheckType, ALTNpcSpawner* Actor, int OptionIndex)
// {
// 	bool bCheck = (CheckType == ECheckBoxState::Checked);
// 	if (Actor)
// 	{
// 		Actor->Modify();
// 		if (bCheck)
// 		{
// 			Actor->ShowMeshInEditor = false;
// 			Actor->DisableMeshInEditor = false;
// 		}
//
// 		if (OptionIndex == 1)
// 		{
// 			Actor->ShowMeshInEditor = bCheck;
// 			Actor->ShowMeshInEditorFunc(true);
// 		}
// 		else
// 		{
// 			Actor->DisableMeshInEditor = bCheck;
// 			Actor->ShowMeshInEditorFunc(false);
// 		}
// 	}
// }

FText FNPCActorDetails::OnGetNPCTemplateText() const
{
	return FText::FromString(*CharacterDatas[SelectIndex]);
}

void FNPCActorDetails::OnSelectNPCTemplate(TSharedPtr<FString> NewSelection, ESelectInfo::Type SelectInfo)
{
	SelectIndex = CharacterDatas.Find(NewSelection);

	// comment by shijingzhe: delete deprecated ALTNpcSpawner
	// FName RowName = FName(FString::FromInt(SelectIndex));
	// if (FNPCTemplateTable* Row = TemplateTable->FindRow<FNPCTemplateTable>(RowName, FString("")))
	// {
	// 	//GetEdMode()->SetNPCTemplate(Row->BlueprintPath);
	// }
}