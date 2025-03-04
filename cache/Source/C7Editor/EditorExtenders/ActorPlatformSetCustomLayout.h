#pragma once

#include "CoreMinimal.h"
#include "IPropertyTypeCustomization.h"
#include "GameFramework/ActorPlatformSet.h"
#include "Widgets/Layout/SWrapBox.h"

struct FActorDeviceProfileViewModel
{
	TWeakObjectPtr<UDeviceProfile> Profile;
	TArray<TSharedPtr<FActorDeviceProfileViewModel>> Children;
};

class FActorPlatformSetCustomLayout : public IPropertyTypeCustomization
{
public:
	static TSharedRef<IPropertyTypeCustomization> MakeInstance()
	{
		return MakeShareable(new FActorPlatformSetCustomLayout());
	}

	// IPropertyTypeCustomization interface
	virtual void CustomizeHeader(TSharedRef<IPropertyHandle> InPropertyHandle, FDetailWidgetRow& HeaderRow, IPropertyTypeCustomizationUtils& CustomizationUtils);
	virtual void CustomizeChildren(TSharedRef<IPropertyHandle> InPropertyHandle, IDetailChildrenBuilder& ChildBuilder, IPropertyTypeCustomizationUtils& CustomizationUtils);
	// End of IPropertyTypeCustomization interface

	FActorPlatformSet* GetRawStructData(TSharedRef<IPropertyHandle> InPropertyHandle);

	void GenerateQualityLevelSelectionWidgets();

	void OnQuickSelectionChanged(TSharedPtr<FString> InItem, ESelectInfo::Type InSelectType);

	void OnPropertyValueChanged();

	TSharedRef<SWidget> GenerateDeviceProfileTreeWidget(int32 QualityLevel);
	
	FReply ToggleMenuOpenForQualityLevel(int32 QualityLevel);
	
	ECheckBoxState IsQLChecked(int32 QualityLevel)const;
	
	void QLCheckStateChanged(ECheckBoxState CheckState, int32 QualityLevel);

	FSlateColor GetQualityLevelButtonTextColor(int32 QualityLevel) const;
	
	TSharedRef<SWidget> GenerateAdditionalDevicesWidgetForQL(int32 QualityLevel);
	
	FText GetDeviceProfileErrorToolTip(UDeviceProfile* Profile, int32 QualityLevel) const;
	
	EVisibility GetDeviceProfileErrorVisibility(UDeviceProfile* Profile, int32 QualityLevel) const;

	FReply RemoveDeviceProfile(UDeviceProfile* Profile, int32 QualityLevel);

	void CreateDeviceProfileTree();
	TSharedRef<ITableRow> OnGenerateDeviceProfileTreeRow(TSharedPtr<FActorDeviceProfileViewModel> InItem, const TSharedRef<STableViewBase>& OwnerTable, int32 QualityLevel);
	void OnGetDeviceProfileTreeChildren(TSharedPtr<FActorDeviceProfileViewModel> InItem, TArray< TSharedPtr<FActorDeviceProfileViewModel> >& OutChildren, int32 QualityLevel);
	
	bool IsTreeActiveForQL(const TSharedPtr<FActorDeviceProfileViewModel>& Tree, int32 QualityLevelMask) const;
	void FilterTreeForQL(const TSharedPtr<FActorDeviceProfileViewModel>& SourceTree, TSharedPtr<FActorDeviceProfileViewModel>& FilteredTree, int32 QualityLevelMask);
	
	EVisibility GetProfileMenuButtonVisibility(TSharedPtr<FActorDeviceProfileViewModel> Item, int32 QualityLevel) const;
	FReply OnProfileMenuButtonClicked(TSharedPtr<FActorDeviceProfileViewModel> Item, int32 QualityLevel, bool bReopenMenu);
	FText GetProfileMenuButtonToolTip(TSharedPtr<FActorDeviceProfileViewModel> Item, int32 QualityLevel) const;
	bool GetProfileMenuItemEnabled(TSharedPtr<FActorDeviceProfileViewModel> Item, int32 QualityLevel) const;
	const FSlateBrush* GetProfileMenuButtonImage(TSharedPtr<FActorDeviceProfileViewModel> Item, int32 QualityLevel) const;

private:
	TSharedPtr<IPropertyHandle> PropertyHandle;
	
	TArray<TSharedPtr<FActorDeviceProfileViewModel>> FullDeviceProfileTree;
	TArray<TArray<TSharedPtr<FActorDeviceProfileViewModel>>> FilteredDeviceProfileTrees;
	
	TSharedPtr<STreeView<TSharedPtr<FActorDeviceProfileViewModel>>> DeviceProfileTreeWidget;


protected:
	FActorPlatformSet* TargetPlatformSet;
	
	TArray<TSharedPtr<EActorPlatformSelectionState>> PlatformSelectionStates;
	
	TSharedPtr<IPropertyHandleArray> PlatformSetArray;
	
	int32 PlatformSetArrayIndex;

	TArray<TSharedPtr<SMenuAnchor>> QualityLevelMenuAnchors;
	TArray<TSharedPtr<SWidget>> QualityLevelMenuContents;
	TSharedPtr<SWrapBox> QualityLevelWidgetBox;

	TArray<TSharedPtr<FString>> QuickSelections;
};
