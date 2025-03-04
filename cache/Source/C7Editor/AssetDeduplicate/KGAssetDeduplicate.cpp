// Copyright Epic Games, Inc. All Rights Reserved.

#include "KGAssetDeduplicate.h"
#include "Widgets/Docking/SDockTab.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/Text/STextBlock.h"
#include "ToolMenus.h"
#include "Application/AssetDeduplicateWindow.h"
#include "DataModel/AssetDeduplicateSettings.h"
#include "DetailCustomization/SameAssetGroupDetail.h"
#include "IAssetTools.h"
#include "AssetToolsModule.h"
#include "DataModel/AssetDeduplicateSettingsTypeAction.h"

static const FName KGAssetDeduplicateTabName("KGAssetDeduplicate");

#define LOCTEXT_NAMESPACE "FKGAssetDeduplicate"

void FKGAssetDeduplicate::StartupModule()
{
	FGlobalTabmanager::Get()->RegisterNomadTabSpawner(KGAssetDeduplicateTabName, FOnSpawnTab::CreateStatic(&FKGAssetDeduplicate::OnSpawnPluginTab))
		.SetDisplayName(LOCTEXT("FKGAssetDeduplicateTabTitle", "KGAssetDeduplicate"))
		.SetMenuType(ETabSpawnerMenuType::Hidden);
	
	FPropertyEditorModule& PropertyEditorModule = FModuleManager::LoadModuleChecked<FPropertyEditorModule>("PropertyEditor");
	PropertyEditorModule.RegisterCustomPropertyTypeLayout(FSameAssetGroup::StaticStruct()->GetFName(),
		FOnGetPropertyTypeCustomizationInstance::CreateStatic(&FSameAssetGroupDetail::MakeInstance));
	
	IAssetTools& AssetToolModule = FModuleManager::LoadModuleChecked<FAssetToolsModule>("AssetTools").Get();
	const auto Category = AssetToolModule.RegisterAdvancedAssetCategory(FName(TEXT("C7Editor")), LOCTEXT("C7EditorCategoryDisplayName", "C7Editor"));
	AssetToolModule.RegisterAssetTypeActions(MakeShareable(new FAssetTypeActions_AssetDeduplicateSettings(Category)));
	
	RegisterMenus();
}

void FKGAssetDeduplicate::ShutdownModule()
{
	FGlobalTabmanager::Get()->UnregisterNomadTabSpawner(KGAssetDeduplicateTabName);
	
	FPropertyEditorModule& PropertyEditorModule = FModuleManager::LoadModuleChecked<FPropertyEditorModule>("PropertyEditor");
	PropertyEditorModule.UnregisterCustomPropertyTypeLayout(FSameAssetGroup::StaticStruct()->GetFName());
	
	FAssetToolsModule* AssetToolModule = FModuleManager::GetModulePtr<FAssetToolsModule>("AssetTools");
	if (AssetToolModule)
	{
		IAssetTools& AssetTools = AssetToolModule->Get();
		TWeakPtr<IAssetTypeActions> Action = AssetTools.GetAssetTypeActionsForClass(UAssetDeduplicateSettings::StaticClass());
		if (Action.IsValid())
			AssetTools.UnregisterAssetTypeActions(Action.Pin().ToSharedRef());
	}
}

TSharedRef<SDockTab> FKGAssetDeduplicate::OnSpawnPluginTab(const FSpawnTabArgs& SpawnTabArgs)
{
	return SNew(SDockTab)
		.TabRole(NomadTab)
		[
			SNew(SAssetDeduplicateWindow)
		];
}

void FKGAssetDeduplicate::RegisterMenus()
{	
	if (!IsRunningCommandlet())
	{
		UToolMenu* Menu = UToolMenus::Get()->ExtendMenu("LevelEditor.MainMenu.C7_Editor");
		{
			FToolMenuSection& Section = Menu->FindOrAddSection("C7EditorWindowLayout");
			const FToolMenuEntry& Entry = FToolMenuEntry::InitMenuEntry(
				FName("Open Asset Deduplicate"),
				LOCTEXT("Asset Deduplicate Menu Label", "Mesh资产去重窗口"),
				FText::GetEmpty(),
				FSlateIcon(),
				FUIAction(FExecuteAction::CreateLambda([]()
				{
					FGlobalTabmanager::Get()->TryInvokeTab(KGAssetDeduplicateTabName);
				}))
			);
			Section.AddEntry(Entry);
		}
	}
}

#undef LOCTEXT_NAMESPACE