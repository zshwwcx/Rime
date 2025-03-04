#pragma once
#include "AssetDeduplicate/DataModel/AssetDeduplicateSettings.h"

class FSameAssetGroupDetail : public IPropertyTypeCustomization
{
public:
	static TSharedRef<IPropertyTypeCustomization> MakeInstance();

	// IPropertyTypeCustomization interface
	virtual void CustomizeHeader(TSharedRef<IPropertyHandle> StructPropertyHandle, class FDetailWidgetRow& HeaderRow, IPropertyTypeCustomizationUtils& StructCustomizationUtils) override;
	void GetMeshes();
	virtual void CustomizeChildren(TSharedRef<IPropertyHandle> StructPropertyHandle, class IDetailChildrenBuilder& ChildBuilder, IPropertyTypeCustomizationUtils& StructCustomizationUtils) override;
	// IPropertyTypeCustomization interface end

private:
	FReply OnReplaceClicked();
	FReply OnReferenceClicked();
	
	TSet<FSoftObjectPath> Meshes;
	
	TSharedPtr<IPropertyHandle> ReplaceMeshHandle;
	TSharedPtr<IPropertyHandle> SameMeshesHandle;
	TWeakObjectPtr<UAssetDeduplicateSettings> Settings;
};
