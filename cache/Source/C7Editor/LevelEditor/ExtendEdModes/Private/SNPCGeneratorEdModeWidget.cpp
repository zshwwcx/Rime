#include "SNPCGeneratorEdModeWidget.h"
#include "C7Editor/C7Editor.h"
#include "NPCGeneratorEdMode.h"
#include "Widgets/Layout/SScrollBox.h"
#include "Widgets/Layout/SGridPanel.h"
#include "EditorModeManager.h"

SNPCGeneratorEdModeWidget::SNPCGeneratorEdModeWidget()
{
	const FString TemplatePath = "DataTable'/Game/Template/NPCTemplate/NPCTemplates.NPCTemplates'";
	TemplateTable = LoadObject<UDataTable>(nullptr, *TemplatePath);
	if (TemplateTable.IsValid())
	{
		CharacterDatas.Empty();
		TArray<FName>  RowNames = TemplateTable->GetRowNames();
		// comment by shijingzhe: delete deprecated ALTNpcSpawner
		// for (const auto& Name : RowNames)
		// {
		// 	FNPCTemplateTable* Row = TemplateTable->FindRow<FNPCTemplateTable>(Name, FString(""));
		// 	CharacterDatas.Add(MakeShareable(new FString(Row->Description)));
		// }
		//
		// if (GetEdMode())
		// {
		// 	FNPCTemplateTable* Row = TemplateTable->FindRow<FNPCTemplateTable>("0", FString(""));
		//
		// 	GetEdMode()->SetNPCTemplate(Row->BlueprintPath);
		// }
	}
}

void SNPCGeneratorEdModeWidget::Construct(const FArguments& InArgs)
{
	ChildSlot
	[
		SNew(SScrollBox)

	+ SScrollBox::Slot()
		.VAlign(VAlign_Top)
		.Padding(5.f)
		[
			SNew(SVerticalBox)
			+ SVerticalBox::Slot()
			.AutoHeight()
			.Padding(0.f, 5.f, 0.f, 0.f)
			[
				SNew(STextBlock)
				.Text(FText::FromString(TEXT("Technical Support: Han Jingchao")))
			]
			+ SVerticalBox::Slot()
			.AutoHeight()
			.Padding(0.f, 5.f, 0.f, 0.f)
			[
				SNew(SHorizontalBox)
				+ SHorizontalBox::Slot()
				.Padding(2.0f)

			.VAlign(VAlign_Center)
				[
					SNew(SComboBox<TSharedPtr<FString>>)
					.OptionsSource(&this->CharacterDatas)
					.OnSelectionChanged(this, &SNPCGeneratorEdModeWidget::OnSelectNPCTemplate)
					.OnGenerateWidget_Lambda([](TSharedPtr<FString> value)->TSharedRef<SWidget>
					{
						return SNew(STextBlock).Text(FText::FromString(*value)); 
					})
					[
						SNew(STextBlock)
						.Text(this, &SNPCGeneratorEdModeWidget::OnGetNPCTemplateText)
					]
				]
				+ SHorizontalBox::Slot()
				.AutoWidth()
				.Padding(2, 0, 0, 0)
				.VAlign(VAlign_Center)
				[
					SNew(SButton)

				.Text(FText::FromString("New"))
					.OnClicked(this, &SNPCGeneratorEdModeWidget::OnAddNPC)
					.IsEnabled(this, &SNPCGeneratorEdModeWidget::CanAddNPC)
				]
				+ SHorizontalBox::Slot()
				.AutoWidth()
				.VAlign(VAlign_Center)
				.Padding(0, 0, 2, 0)
				[
					SNew(SButton)

				.Text(FText::FromString("Delete"))
					.OnClicked(this, &SNPCGeneratorEdModeWidget::OnRemoveNPC)
					.IsEnabled(this, &SNPCGeneratorEdModeWidget::CanRemoveNPC)
				]
			]
		]
	];
}

FNPCGeneratorEdMode* SNPCGeneratorEdModeWidget::GetEdMode() const
{
	return (FNPCGeneratorEdMode*)GLevelEditorModeTools().GetActiveMode(FNPCGeneratorEdMode::EM_NPCGenerator);
}

FReply SNPCGeneratorEdModeWidget::OnAddNPC()
{
	GetEdMode()->AddNPC();
	return FReply::Handled();
}

bool SNPCGeneratorEdModeWidget::CanAddNPC() const
{
	return GetEdMode()->CanAddNPC();
}

FReply SNPCGeneratorEdModeWidget::OnRemoveNPC()
{
	GetEdMode()->RemoveNPC();

	return FReply::Handled();
}

bool SNPCGeneratorEdModeWidget::CanRemoveNPC() const
{
	return GetEdMode()->CanRemoveNPC();
}

FText SNPCGeneratorEdModeWidget::OnGetNPCTemplateText() const
{
	return FText::FromString(*CharacterDatas[SelectIndex]);
}

void SNPCGeneratorEdModeWidget::OnSelectNPCTemplate(TSharedPtr<FString> NewSelection, ESelectInfo::Type SelectInfo)
{
	SelectIndex = CharacterDatas.Find(NewSelection);

	FName RowName = FName(FString::FromInt(SelectIndex));
	// comment by shijingzhe: delete deprecated ALTNpcSpawner
	// if (FNPCTemplateTable* Row = TemplateTable->FindRow<FNPCTemplateTable>(RowName, FString("")))
	// {
	// 	GetEdMode()->SetNPCTemplate(Row->BlueprintPath);
	// }
}