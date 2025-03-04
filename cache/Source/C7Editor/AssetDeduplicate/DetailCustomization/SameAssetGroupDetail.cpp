#include "SameAssetGroupDetail.h"

#include "DetailWidgetRow.h"
#include "IDetailChildrenBuilder.h"
#include "PropertyCustomizationHelpers.h"
#include "AssetDeduplicate/DataModel/AssetDeduplicateSettings.h"
#include "AssetDeduplicate/Application/AssetDeduplicateManager.h"

#define LOCTEXT_NAMESPACE "AssetDeduplicate"

class ReplaceHelper;

TSharedRef<IPropertyTypeCustomization> FSameAssetGroupDetail::MakeInstance()
{
	return MakeShared<FSameAssetGroupDetail>();
}

void FSameAssetGroupDetail::CustomizeHeader(TSharedRef<IPropertyHandle> StructPropertyHandle, class FDetailWidgetRow& HeaderRow,
	IPropertyTypeCustomizationUtils& StructCustomizationUtils)
{
	TArray<UObject*> OutObjects;
	StructPropertyHandle->GetOuterObjects(OutObjects);
	for (auto OutObject : OutObjects)
	{
		if (OutObject->IsA<UAssetDeduplicateSettings>())
		{
			Settings = static_cast<UAssetDeduplicateSettings*>(OutObject);
			break;
		}
	}
	
	HeaderRow.NameContent()
		[
			StructPropertyHandle->CreatePropertyNameWidget()
		]
		.ValueContent()
		[
			StructPropertyHandle->CreatePropertyValueWidget()
		];
}

void FSameAssetGroupDetail::GetMeshes()
{
	void* OutArrayAddress = nullptr;
	SameMeshesHandle->GetValueData(OutArrayAddress);
	if (OutArrayAddress)
	{
		Meshes = TSet(*static_cast<TArray<FSoftObjectPath>*>(OutArrayAddress));
	}
}

void FSameAssetGroupDetail::CustomizeChildren(TSharedRef<IPropertyHandle> StructPropertyHandle, class IDetailChildrenBuilder& ChildBuilder,
                                              IPropertyTypeCustomizationUtils& StructCustomizationUtils)
{
	ReplaceMeshHandle = StructPropertyHandle->GetChildHandle(GET_MEMBER_NAME_CHECKED(FSameAssetGroup, ReplaceMesh));
	SameMeshesHandle = StructPropertyHandle->GetChildHandle(GET_MEMBER_NAME_CHECKED(FSameAssetGroup, SameMeshes));
	check(ReplaceMeshHandle.IsValid() && SameMeshesHandle.IsValid());
	
	uint32 NumChildProps = 0;
	StructPropertyHandle->GetNumChildren(NumChildProps);

	for (uint32 Idx = 0; Idx < NumChildProps; Idx++)
	{
		TSharedPtr<IPropertyHandle> PropHandle = StructPropertyHandle->GetChildHandle(Idx);
		if (!PropHandle.IsValid() || PropHandle->GetPropertyDisplayName().EqualTo(ReplaceMeshHandle->GetPropertyDisplayName()))
			continue;
		ChildBuilder.AddProperty(PropHandle.ToSharedRef());
	}
	
	GetMeshes();

	IDetailPropertyRow& Row = ChildBuilder.AddProperty(ReplaceMeshHandle.ToSharedRef());
	Row.CustomWidget().NameContent()
	[
		ReplaceMeshHandle->CreatePropertyNameWidget()
	].ValueContent()
	[
		SNew(SObjectPropertyEntryBox)
		.AllowedClass(UStaticMesh::StaticClass())
		.OnShouldFilterAsset_Lambda([this](const FAssetData& AssetData)
		{
			GetMeshes();
			return !Meshes.Contains(AssetData.GetSoftObjectPath());
		})
		.ObjectPath_Lambda([this]()
		{
			UObject* Object = nullptr;
			if (ReplaceMeshHandle.IsValid() && ReplaceMeshHandle->GetValue(Object) == FPropertyAccess::Result::Success && Object != nullptr)
			{
				return Object->GetPathName();
			}
			return FString();
		})
		.OnObjectChanged_Lambda([this](const FAssetData& AssetData)
		{
			if (ReplaceMeshHandle.IsValid())
			{
				ReplaceMeshHandle->SetValue(AssetData.GetAsset());
			}
		})
		.ThumbnailPool(StructCustomizationUtils.GetThumbnailPool())
	];

	ChildBuilder.AddCustomRow(FText::GetEmpty()).WholeRowContent()
	[
		SNew(SHorizontalBox)
		+ SHorizontalBox::Slot()
		
		+ SHorizontalBox::Slot()
		.AutoWidth()
		[
			SNew(SButton)
			.Text(LOCTEXT("ReplaceButtonLabel", "Replace"))
			.VAlign(VAlign_Center)
			.OnClicked(this, &FSameAssetGroupDetail::OnReplaceClicked)
		]
		
		+ SHorizontalBox::Slot()
		.AutoWidth()
		[
			SNew(SButton)
			.Text(LOCTEXT("ReplaceButtonLabel", "进一步比较/查看引用数量"))
			.VAlign(VAlign_Center)
			.OnClicked_Lambda([this, StructPropertyHandle]()
			{
				void* Data = nullptr;
				StructPropertyHandle->GetValueData(Data);
				if (StructPropertyHandle->GetValueData(Data) && Data)
				{
					if (Settings.IsValid() && Settings->Manager.IsValid())
					{
						Settings->Manager.Pin()->SeeMoreDetails(static_cast<FSameAssetGroup*>(Data));
					}
				}
				return FReply::Handled();
			})
		]
	];
	
	// ChildBuilder.AddCustomRow(FText::GetEmpty()).WholeRowContent()
	// [
	// 	SNew(SHorizontalBox)
	// 	+ SHorizontalBox::Slot()
	// 	
	// 	+ SHorizontalBox::Slot()
	// 	.AutoWidth()
	// 	[
	// 		SNew(SButton)
	// 		.Text(LOCTEXT("ReplaceButtonLabel", "Reference"))
	// 		.VAlign(VAlign_Center)
	// 		.OnClicked(this, &FSameAssetGroupDetail::OnReferenceClicked)
	// 	]
	// ];
}

FReply FSameAssetGroupDetail::OnReplaceClicked()
{
	if (!ReplaceMeshHandle.IsValid())
		return FReply::Handled();
	UObject* Object;
	ReplaceMeshHandle->GetValue(Object);
	if (Object == nullptr)
		return FReply::Handled();

	if (Settings.IsValid() && Settings->Manager.IsValid())
	{
		GetMeshes();
		Settings->Manager.Pin()->DoReplace(Cast<UStaticMesh>(Object), Meshes.Array());
	}
	
	return FReply::Handled();
}

FReply FSameAssetGroupDetail::OnReferenceClicked()
{
	if (!ReplaceMeshHandle.IsValid())
		return FReply::Handled();
	UObject* Object;
	ReplaceMeshHandle->GetValue(Object);
	if (Object == nullptr)
		return FReply::Handled();
	
	return FReply::Handled();
}

#undef LOCTEXT_NAMESPACE