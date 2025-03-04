#include "AssetDeduplicateSettingsTypeAction.h"
#include "AssetDeduplicateSettings.h"

#define LOCTEXT_NAMESPACE "FAvatarCreatorModule"

FAssetTypeActions_AssetDeduplicateSettings::FAssetTypeActions_AssetDeduplicateSettings(EAssetTypeCategories::Type Type)
{
	AssetCategory = Type;
}

FText FAssetTypeActions_AssetDeduplicateSettings::GetName() const
{
	return LOCTEXT("FAssetDeduplicateSettingsDataTypeActionsName", "AssetDeduplicateSettingsData");
}

FColor FAssetTypeActions_AssetDeduplicateSettings::GetTypeColor() const
{
	return FColor::Green;
}

UClass* FAssetTypeActions_AssetDeduplicateSettings::GetSupportedClass() const
{
	return UAssetDeduplicateSettings::StaticClass();
}

uint32 FAssetTypeActions_AssetDeduplicateSettings::GetCategories()
{
	return AssetCategory;
}

void FAssetTypeActions_AssetDeduplicateSettings::OpenAssetEditor(const TArray<UObject*>& InObjects,
	TSharedPtr<IToolkitHost> EditWithinLevelEditor)
{
	FSimpleAssetEditor::CreateEditor(EToolkitMode::Standalone, EditWithinLevelEditor, InObjects);
}

#undef LOCTEXT_NAMESPACE
