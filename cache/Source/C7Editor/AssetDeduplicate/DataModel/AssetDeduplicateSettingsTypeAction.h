#pragma once

#include "CoreMinimal.h"
#include "AssetTypeActions_Base.h"

/**
 * Avatar Profile Data Asset Type Actions
 */
class FAssetTypeActions_AssetDeduplicateSettings : public FAssetTypeActions_Base
{
public:
	FAssetTypeActions_AssetDeduplicateSettings(EAssetTypeCategories::Type Type);

	virtual FText GetName() const override;

	virtual FColor GetTypeColor() const override;

	virtual UClass* GetSupportedClass() const override;

	virtual void OpenAssetEditor(const TArray<UObject*>& InObjects, TSharedPtr<class IToolkitHost> EditWithinLevelEditor = TSharedPtr<IToolkitHost>()) override;

	virtual uint32 GetCategories() override;

private:
	EAssetTypeCategories::Type AssetCategory;
};
