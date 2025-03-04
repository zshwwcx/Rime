#include "AssetDeduplicateWindow.h"

#include "AssetDeduplicateManager.h"
#include "AssetDeduplicate/DataModel/AssetDeduplicateSettings.h"

void SAssetDeduplicateWindow::Construct(const FArguments& InArgs)
{
	Manager = MakeShared<FAssetDeduplicateManager>();
	Manager->Settings->Manager = Manager.ToWeakPtr();
	
	FPropertyEditorModule& PropertyEditorModule = FModuleManager::GetModuleChecked<FPropertyEditorModule>("PropertyEditor");
	FDetailsViewArgs DetailsViewArgs;
	DetailsViewArgs.NameAreaSettings = FDetailsViewArgs::HideNameArea;
	TSharedRef<IDetailsView> DetailsView = PropertyEditorModule.CreateDetailView(DetailsViewArgs);
	DetailsView->SetObject(Manager->Settings.Get());
	
	ChildSlot
	[
		SNew(SVerticalBox)
		+ SVerticalBox::Slot()
		[
			DetailsView
		]

		+ SVerticalBox::Slot()
		.AutoHeight()
		[
			SNew(SBorder)
			[
				SNew(SHorizontalBox)
				+ SHorizontalBox::Slot()
				
				+ SHorizontalBox::Slot()
				.AutoWidth()
				[
					SNew(SButton)
					.OnClicked(this, &SAssetDeduplicateWindow::OnStartClicked)
					.Text(FText::FromString("Search"))	
				]
				
				// + SHorizontalBox::Slot()
				// .AutoWidth()
				// [
				// 	SNew(SButton)
				// 	.OnClicked(this, &SAssetDeduplicateWindow::OnReferenceClicked)
				// 	.Text(FText::FromString("Reference"))	
				// ]
				
				+ SHorizontalBox::Slot()
				.AutoWidth()
				[
					SNew(SButton)
					.OnClicked(this, &SAssetDeduplicateWindow::OnFilterClicked)
					.Text(FText::FromString("Filter"))	
				]
			]	
		]
	];	
}

FReply SAssetDeduplicateWindow::OnStartClicked()
{
	Manager->RunDetect();
	return FReply::Handled();
}

FReply SAssetDeduplicateWindow::OnReferenceClicked()
{
	Manager->RunReference();
	return FReply::Handled();
}

FReply SAssetDeduplicateWindow::OnFilterClicked() const
{
	Manager->RunResultFilter();
	return FReply::Handled();
}
