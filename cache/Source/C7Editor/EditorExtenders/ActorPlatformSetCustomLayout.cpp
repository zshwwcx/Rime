#include "ActorPlatformSetCustomLayout.h"
#include "DetailWidgetRow.h"
#include "IPropertyUtilities.h"
#include "NiagaraEditorStyle.h"
#include "PlatformInfo.h"
#include "Selection.h"
#include "DeviceProfiles/DeviceProfile.h"
#include "DeviceProfiles/DeviceProfileManager.h"
#include "GameFramework/ActorPlatformSetUtilities.h"
#include "Widgets/Layout/SWrapBox.h"

#define LOCTEXT_NAMESPACE "FActorPlatformSetCustomization"


uint8* GetBaseAddress(TSharedRef<IPropertyHandle> PropertyHandle)
{
	if (PropertyHandle->GetNumOuterObjects() > 0)
	{
		TArray<UObject*> Objects;
		PropertyHandle->GetOuterObjects(Objects);
		return reinterpret_cast<uint8*>(Objects[0]);
	}

	// walk the struct hierarchy to find the parent StructOnScope
	TSharedPtr<IPropertyHandle> LastParent = PropertyHandle;
	while (true)
	{
		TSharedPtr<IPropertyHandle> NewParent = LastParent->GetParentHandle();
		if (!ensureMsgf(NewParent.IsValid() && NewParent != LastParent, TEXT("Unable to walk property chain")))
		{
			break;
		}
		
		TSharedPtr<IPropertyHandleStruct> StructHandle = NewParent->AsStruct();
		if (StructHandle.IsValid())
		{
			return StructHandle->GetStructData()->GetStructMemory();
		}
		LastParent = NewParent;
	}

	return nullptr;
}

enum class EProfileButtonMode
{
	None,
	Include,
	Exclude,
	Remove
};

static EProfileButtonMode GetProfileMenuButtonMode(FActorPlatformSet* PlatformSet, TSharedPtr<FActorDeviceProfileViewModel> Item, int32 QualityLevel)
{
	int32 Mask = PlatformSet->GetAvailableQualityMaskForDeviceProfile(Item->Profile.Get());
	int32 QLMask = FActorPlatformSet::CreateQualityLevelMask(QualityLevel);

	if ((Mask & QLMask) == 0)
	{
		return EProfileButtonMode::None;
	}

	EActorPlatformSelectionState CurrentState = PlatformSet->GetDeviceProfileState(Item->Profile.Get(), QualityLevel);

	bool bQualityEnabled = PlatformSet->IsEffectQualityEnabled(QualityLevel);
	//FNiagaraPlatformSetEnabledState Enabled = PlatformSet->IsEnabled(Item->Profile, QualityLevel);
	bool bIsDefault = CurrentState == EActorPlatformSelectionState::Default;

	if (bIsDefault && bQualityEnabled)
	{
		return EProfileButtonMode::Exclude;
	}

	if (bIsDefault && !bQualityEnabled)
	{
		return EProfileButtonMode::Include;
	}

	return EProfileButtonMode::Remove;
}

void FActorPlatformSetCustomLayout::CustomizeHeader(TSharedRef<IPropertyHandle> InPropertyHandle, FDetailWidgetRow& HeaderRow, IPropertyTypeCustomizationUtils& CustomizationUtils)
{
	PropertyHandle = InPropertyHandle;
	TArray<TWeakObjectPtr<UObject>> WeakObjectPtrs = CustomizationUtils.GetPropertyUtilities()->GetSelectedObjects();

	uint8* BaseAddress = GetBaseAddress(InPropertyHandle);
	if (!BaseAddress)
	{
		return;
	}
	
	TargetPlatformSet = reinterpret_cast<FActorPlatformSet*>(PropertyHandle->GetValueBaseAddress(BaseAddress));

	if (PlatformSelectionStates.Num() == 0)
	{
		PlatformSelectionStates.Add(MakeShared<EActorPlatformSelectionState>(EActorPlatformSelectionState::Enabled));
		PlatformSelectionStates.Add(MakeShared<EActorPlatformSelectionState>(EActorPlatformSelectionState::Disabled));
		PlatformSelectionStates.Add(MakeShared<EActorPlatformSelectionState>(EActorPlatformSelectionState::Default));
	}

	//Look for outer types for which we need to ensure there are no conflicting settings.
	// SystemScalabilitySettings = nullptr;
	// EmitterScalabilitySettings = nullptr;
	// SystemScalabilityOverrides = nullptr;
	// EmitterScalabilityOverrides = nullptr;
	PlatformSetArray.Reset();
	PlatformSetArrayIndex = INDEX_NONE;

	//Look whether this platform set belongs to a class which must keep orthogonal platform sets.
	//We then interrogate the other sets via these ptrs to look for conflicts.
	TSharedPtr<IPropertyHandle> CurrHandle = PropertyHandle->GetParentHandle();
	while (CurrHandle)
	{
		int32 ThisIndex = CurrHandle->GetIndexInArray();
		if (ThisIndex != INDEX_NONE)
		{
			PlatformSetArray = CurrHandle->GetParentHandle()->AsArray();
			PlatformSetArrayIndex = ThisIndex;
		}

		if (FProperty* CurrProperty = CurrHandle->GetProperty())
		{
			if (UStruct* CurrStruct = CurrProperty->GetOwnerStruct())
			{
				TSharedPtr<IPropertyHandle> ParentHandle = CurrHandle->GetParentHandle();
			}
		}

		CurrHandle = CurrHandle->GetParentHandle();
	}

	// UpdateCachedConflicts();
	
	PropertyHandle->SetOnPropertyValueChanged(FSimpleDelegate::CreateSP(this, &FActorPlatformSetCustomLayout::OnPropertyValueChanged));
	PropertyHandle->SetOnChildPropertyValueChanged(FSimpleDelegate::CreateLambda([&]{ TargetPlatformSet->OnChanged(); }));

	HeaderRow.WholeRowContent()
		[
			SAssignNew(QualityLevelWidgetBox, SWrapBox)
			.UseAllottedSize(true)
		];

	QuickSelections.Empty();
	QuickSelections.Add(MakeShareable(new FString("All")));
	QuickSelections.Add(MakeShareable(new FString("Windows")));
	QuickSelections.Add(MakeShareable(new FString("Android")));
	QuickSelections.Add(MakeShareable(new FString("IOS")));
	QuickSelections.Add(MakeShareable(new FString("Mobile")));

	GenerateQualityLevelSelectionWidgets();	
}

void FActorPlatformSetCustomLayout::CustomizeChildren(TSharedRef<IPropertyHandle> InPropertyHandle, IDetailChildrenBuilder& ChildBuilder, IPropertyTypeCustomizationUtils& CustomizationUtils)
{
	
}

void FActorPlatformSetCustomLayout::GenerateQualityLevelSelectionWidgets()
{
	QualityLevelWidgetBox->ClearChildren();

	int32 NumQualityLevels = 5;
	
	QualityLevelMenuAnchors.Reset();
	QualityLevelMenuContents.Reset();
	QualityLevelMenuAnchors.SetNum(NumQualityLevels);
	QualityLevelMenuContents.SetNum(NumQualityLevels);

	for (int32 QualityLevel = 0; QualityLevel < NumQualityLevels; ++QualityLevel)
	{
		bool First = QualityLevel == 0;
		bool Last = QualityLevel == (NumQualityLevels - 1);

		if (!QualityLevelMenuAnchors[QualityLevel].IsValid())
		{
			QualityLevelMenuAnchors[QualityLevel] = SNew(SMenuAnchor)
				.ToolTipText(LOCTEXT("AddPlatformOverride", "Add an override for a specific platform."))
				.OnGetMenuContent(this, &FActorPlatformSetCustomLayout::GenerateDeviceProfileTreeWidget, QualityLevel)
				[
					SNew(SButton)
					.Visibility_Lambda([this, QualityLevel]()
					{
						return QualityLevelWidgetBox->GetChildren()->GetChildAt(QualityLevel)->IsHovered() ? EVisibility::Visible : EVisibility::Hidden;
					})
					.ButtonStyle(FAppStyle::Get(), "HoverHintOnly")
					.ForegroundColor(FSlateColor::UseForeground())
					.OnClicked(this, &FActorPlatformSetCustomLayout::ToggleMenuOpenForQualityLevel, QualityLevel)
					[
						SNew(SBox)
						.WidthOverride(8)
						.HeightOverride(8)
						.VAlign(VAlign_Center)
						[
							SNew(SImage)
							.Image(FNiagaraEditorStyle::Get().GetBrush("NiagaraEditor.PlatformSet.DropdownButton"))
						]
					]
				];
		}

		QualityLevelWidgetBox->AddSlot()
			.Padding(0, 0, 1, 0)
			[
				SNew(SBox)
				.WidthOverride(100)
				.VAlign(VAlign_Top)
				[
					SNew(SVerticalBox)
					+ SVerticalBox::Slot()
					.AutoHeight()
					[
						SNew(SCheckBox)
						.Style(FNiagaraEditorStyle::Get(), First ? "NiagaraEditor.PlatformSet.StartButton" : 
							(Last ? "NiagaraEditor.PlatformSet.EndButton" : "NiagaraEditor.PlatformSet.MiddleButton"))
						.IsChecked(this, &FActorPlatformSetCustomLayout::IsQLChecked, QualityLevel)
						.OnCheckStateChanged(this, &FActorPlatformSetCustomLayout::QLCheckStateChanged, QualityLevel)
						[
							SNew(SHorizontalBox)
							+ SHorizontalBox::Slot()
							.HAlign(HAlign_Fill)
							.Padding(6,2,2,4)
							[
								SNew(STextBlock)
								.TextStyle(FNiagaraEditorStyle::Get(), "NiagaraEditor.PlatformSet.ButtonText")
								.Text(FActorPlatformSet::GetQualityLevelText(QualityLevel))
								.ColorAndOpacity(this, &FActorPlatformSetCustomLayout::GetQualityLevelButtonTextColor, QualityLevel)
								.ShadowOffset(FVector2D(1, 1))
							]
							// error icon
							// + SHorizontalBox::Slot()
							// .AutoWidth()
							// .HAlign(HAlign_Right)
							// .VAlign(VAlign_Center)
							// .Padding(0,0,2,0)
							// [
							// 	SNew(SBox)
							// 	.WidthOverride(12)
							// 	.HeightOverride(12)
							// 	[
							// 		SNew(SImage)
							// 		.ToolTipText(this, &FActorPlatformSetCustomLayout::GetQualityLevelErrorToolTip, QualityLevel)
							// 		.Visibility(this, &FActorPlatformSetCustomLayout::GetQualityLevelErrorVisibility, QualityLevel)
							// 		.Image(FAppStyle::GetBrush("Icons.Error"))
							// 	]
							// ]
							// dropdown button
							+ SHorizontalBox::Slot()
							.AutoWidth()
							.HAlign(HAlign_Right)
							.VAlign(VAlign_Center)
							.Padding(0,0,2,0)
							[
								QualityLevelMenuAnchors[QualityLevel].ToSharedRef()
							]
						]
					]
					+ SVerticalBox::Slot()
					.AutoHeight()
					[
						GenerateAdditionalDevicesWidgetForQL(QualityLevel)
					]
				]
			];
	}

	QualityLevelWidgetBox->AddSlot()
	.Padding(0,0,1,0)
	[
		SNew(SComboBox<TSharedPtr<FString>>)
		.OptionsSource(&QuickSelections)
		.OnGenerateWidget_Lambda([](TSharedPtr<FString> ChoiceEntry)
		{
			FText ChoiceEntryText = FText::FromString(*ChoiceEntry);
			return SNew(STextBlock)
				.Text(ChoiceEntryText)
				.ToolTipText(ChoiceEntryText);
		})
		.OnSelectionChanged(this, &FActorPlatformSetCustomLayout::OnQuickSelectionChanged)
		[
			SNew(STextBlock)
			.Text(FText::FromString("QuickSet"))
		]
		];
}

void FActorPlatformSetCustomLayout::OnQuickSelectionChanged(TSharedPtr<FString> InItem, ESelectInfo::Type InSelectType)
{
	TargetPlatformSet->QualityLevelMask = INDEX_NONE;
	TargetPlatformSet->DeviceProfileStates.Reset();
	const int32 NumQualityLevels = 5;
	if(InItem->Equals("Mobile"))
	{
		UDeviceProfile* Profile = UDeviceProfileManager::Get().FindProfile("Windows", false);
		for (int32 QualityLevel = 0; QualityLevel < NumQualityLevels; ++QualityLevel)
		{
			TargetPlatformSet->SetDeviceProfileState(Profile, QualityLevel, EActorPlatformSelectionState::Disabled);
		}
	}
	else
	{
		if(UDeviceProfile* Profile = UDeviceProfileManager::Get().FindProfile(*InItem.Get(), false))
		{
			for (int32 QualityLevel = 0; QualityLevel < NumQualityLevels; ++QualityLevel)
			{
				TargetPlatformSet->SetEnabledForEffectQuality(QualityLevel, false);
				TargetPlatformSet->SetDeviceProfileState(Profile, QualityLevel, EActorPlatformSelectionState::Enabled);
			}
		}
	}
	OnPropertyValueChanged();
}

void FActorPlatformSetCustomLayout::OnPropertyValueChanged()
{
	// UpdateCachedConflicts();
	GenerateQualityLevelSelectionWidgets();
	TargetPlatformSet->OnChanged();
	TArray<AActor*> Actors;
	GEditor->GetSelectedActors()->GetSelectedObjects<AActor>(Actors);
	for (AActor* Actor : Actors)
	{
		Actor->Platforms.QualityLevelMask = TargetPlatformSet->QualityLevelMask;
		Actor->Platforms.DeviceProfileStates = TargetPlatformSet->DeviceProfileStates;
		FActorPlatformSetUtilities::OnActorPlatformPostChanged(*Actor);
		FProperty* Property = FindFProperty<FProperty>( AActor::StaticClass(), "Platforms" );
		FPropertyChangedEvent PropertyChangedEvent(Property, EPropertyChangeType::ValueSet, { Actor });
		Actor->PostEditChangeProperty(PropertyChangedEvent);
	}
}

TSharedRef<SWidget> FActorPlatformSetCustomLayout::GenerateDeviceProfileTreeWidget(int32 QualityLevel)
{
	FullDeviceProfileTree.Reset();
	if (FullDeviceProfileTree.Num() == 0)
	{
		CreateDeviceProfileTree();	
	}
	
	QualityLevelMenuContents[QualityLevel].Reset();
	
	TArray<TSharedPtr<FActorDeviceProfileViewModel>>* TreeToUse = &FullDeviceProfileTree;
	if (QualityLevel != INDEX_NONE)
	{
		check(QualityLevel < FilteredDeviceProfileTrees.Num());
		TreeToUse = &FilteredDeviceProfileTrees[QualityLevel];
	}
	
	return SAssignNew(QualityLevelMenuContents[QualityLevel], SBorder)
		.BorderImage(FAppStyle::Get().GetBrush("Menu.Background"))
		[
			SAssignNew(DeviceProfileTreeWidget, STreeView<TSharedPtr<FActorDeviceProfileViewModel>>)
			.TreeItemsSource(TreeToUse)
			.OnGenerateRow(this, &FActorPlatformSetCustomLayout::OnGenerateDeviceProfileTreeRow, QualityLevel)
			.OnGetChildren(this, &FActorPlatformSetCustomLayout::OnGetDeviceProfileTreeChildren, QualityLevel)
			.SelectionMode(ESelectionMode::None)
		];
}

TSharedRef<ITableRow> FActorPlatformSetCustomLayout::OnGenerateDeviceProfileTreeRow(TSharedPtr<FActorDeviceProfileViewModel> InItem, const TSharedRef<STableViewBase>& OwnerTable, int32 QualityLevel)
{
	TSharedPtr<SHorizontalBox> RowContainer;
	SAssignNew(RowContainer, SHorizontalBox);

	FActorPlatformSetEnabledStateDetails Details;
	FActorPlatformSetEnabledState EnabledState = TargetPlatformSet->IsEnabled(InItem->Profile.Get(), QualityLevel, false, &Details);

	FText NameTooltip = FText::Format(LOCTEXT("ProfileQLTooltipFmt", "Effects Quality: {0}"), FActorPlatformSet::GetQualityLevelMaskText(QualityLevel));

	// const UNiagaraSettings* Settings = GetDefault<UNiagaraSettings>();
	// check(Settings);
	//
	// int32 NumQualityLevels = Settings->QualityLevels.Num();
	
	int32 NumQualityLevels = 5;
	
	
	//Top level profile. Look for a platform icon.
	if (InItem->Profile->Parent == nullptr)
	{
		if (const PlatformInfo::FTargetPlatformInfo* Info = PlatformInfo::FindPlatformInfo(*InItem->Profile->DeviceType))
		{
			const FSlateBrush* DeviceProfileTypeIcon = FAppStyle::GetBrush(Info->GetIconStyleName(EPlatformIconSize::Normal));
			if (DeviceProfileTypeIcon != FAppStyle::Get().GetDefaultBrush())
			{
				RowContainer->AddSlot()
					.AutoWidth()
					.VAlign(VAlign_Center)
					.HAlign(HAlign_Left)
					.Padding(4, 0, 0, 0)
					[
						SNew(SBox)
						.WidthOverride(16)
						.HeightOverride(16)
						[
							SNew(SImage)
							.Image(DeviceProfileTypeIcon)
						]
					];
			}
		}
	}

	FName TextStyleName("NormalText");
	FSlateColor TextColor(FSlateColor::UseForeground());
	EActorPlatformSelectionState CurrentState = TargetPlatformSet->GetDeviceProfileState(InItem->Profile.Get(), QualityLevel);
	
	FSlateColor ActiveColor = FSlateColor::UseForeground();
	FSlateColor InactiveColor = FSlateColor::UseSubduedForeground();
	FSlateColor DisabledColor = FSlateColor(FLinearColor(FVector4(1, 0, 0, 1)));
	if (EnabledState.bIsActive)
	{
		TextColor = ActiveColor;
	}
	else
	{
		if (EnabledState.bCanBeActive)
		{
			TextColor = InactiveColor;
		}
		else
		{
			TextColor = DisabledColor;
		}
	}

	TSharedPtr<SVerticalBox> TooltipContentsBox = SNew(SVerticalBox);
 	if (EnabledState.bIsActive)
 	{
		TooltipContentsBox->AddSlot()
 		[
 			SNew(STextBlock)
 			.TextStyle(FAppStyle::Get(), TextStyleName)
 			.ColorAndOpacity(ActiveColor)
 			.Text(LOCTEXT("DPActiveTooltip", "Active"))
 		];
 	}
 	else
 	{
 		if(EnabledState.bCanBeActive)
 		{
			TooltipContentsBox->AddSlot()
			[
				SNew(STextBlock)
				.TextStyle(FAppStyle::Get(), TextStyleName)
				.ColorAndOpacity(InactiveColor)
				.Text(LOCTEXT("DPInActiveTooltip", "Inactive Due To:"))
			];
 			for (FText Reason : Details.ReasonsForInActive)
 			{			
				TooltipContentsBox->AddSlot()
 				[
 					SNew(STextBlock)
 					.TextStyle(FAppStyle::Get(), TextStyleName)
 					.ColorAndOpacity(InactiveColor)
 					.Text(Reason)
 				];
 			}
 		}
 		else
 		{
			TooltipContentsBox->AddSlot()
			[
				SNew(STextBlock)
				.TextStyle(FAppStyle::Get(), TextStyleName)
				.ColorAndOpacity(DisabledColor)
				.Text(LOCTEXT("DPDisabledTooltip", "Disabled Due To:"))
			];
 			for (FText Reason : Details.ReasonsForDisabled)
 			{			
				TooltipContentsBox->AddSlot()
 				[
 					SNew(STextBlock)
 					.TextStyle(FAppStyle::Get(), TextStyleName)
 					.ColorAndOpacity(DisabledColor)
 					.Text(Reason)
 				];
 			}
 		}
	}
	
	TooltipContentsBox->AddSlot()
		[
			SNew(STextBlock)
			.TextStyle(FAppStyle::Get(), TextStyleName)
			.ColorAndOpacity(ActiveColor)
			.Text(LOCTEXT("QLTooltipAvailableListHeader", "Available:"))
		];

	int32 DefaultQL = FActorPlatformSet::QualityLevelFromMask(Details.DefaultQualityMask);
	for (int32 QL = 0; QL < NumQualityLevels; ++QL)
	{
		if(Details.AvailableQualityMask & (1<<QL))
		{
			if (DefaultQL == QL)
			{
				TooltipContentsBox->AddSlot()
					[
						SNew(STextBlock)
						.TextStyle(FAppStyle::Get(), TextStyleName)
						.ColorAndOpacity(ActiveColor)
						.Text(FText::Format(LOCTEXT("QLTooltipAvailableListDefaultFmt", "{0} (Default)"), FActorPlatformSet::GetQualityLevelText(QL)))
					];
			}
			else
			{
				TooltipContentsBox->AddSlot()
					[
						SNew(STextBlock)
						.TextStyle(FAppStyle::Get(), TextStyleName)
						.ColorAndOpacity(ActiveColor)
						.Text(FActorPlatformSet::GetQualityLevelText(QL))
					];
			}
		}
	}

	RowContainer->AddSlot()
		.Padding(4, 2, 0, 2)
		.HAlign(HAlign_Fill)
		.VAlign(VAlign_Center)
		[
			SNew(SButton)
			.ButtonStyle(FAppStyle::Get(), "NoBorder")
			.OnClicked(this, &FActorPlatformSetCustomLayout::OnProfileMenuButtonClicked, InItem, QualityLevel, false)
			.IsEnabled(this, &FActorPlatformSetCustomLayout::GetProfileMenuItemEnabled, InItem, QualityLevel)
			.ForegroundColor(TextColor)
			.ToolTip(
				SNew(SToolTip)
				[
					TooltipContentsBox.ToSharedRef()
				]
			)
			[
				SNew(STextBlock)
				.TextStyle(FAppStyle::Get(), TextStyleName)
				.Text(FText::FromString(InItem->Profile->GetName()))
			]
		];

	RowContainer->AddSlot()
		.AutoWidth()
		.Padding(12, 2, 4, 4)
		.HAlign(HAlign_Right)
		.VAlign(VAlign_Center)
		[
			SNew(SButton)
			.ButtonStyle(FAppStyle::Get(), "HoverHintOnly")
			.HAlign(HAlign_Center)
			.VAlign(VAlign_Fill)
			.Visibility(this, &FActorPlatformSetCustomLayout::GetProfileMenuButtonVisibility, InItem, QualityLevel)
			.OnClicked(this, &FActorPlatformSetCustomLayout::OnProfileMenuButtonClicked, InItem, QualityLevel, true)
			.ToolTipText(this, &FActorPlatformSetCustomLayout::GetProfileMenuButtonToolTip, InItem, QualityLevel)
			[
				SNew(SBox)
				.WidthOverride(8)
				.HeightOverride(8)
				.VAlign(VAlign_Center)
				.HAlign(HAlign_Center)
				[
					SNew(SImage)
					.Image(this, &FActorPlatformSetCustomLayout::GetProfileMenuButtonImage, InItem, QualityLevel)
				]
			]
		];

	return SNew(STableRow<TSharedPtr<FActorDeviceProfileViewModel>>, OwnerTable)
		.Style(FNiagaraEditorStyle::Get(), "NiagaraEditor.PlatformSet.TreeView")
		[
			RowContainer.ToSharedRef()
		];
}

void FActorPlatformSetCustomLayout::OnGetDeviceProfileTreeChildren(TSharedPtr<FActorDeviceProfileViewModel> InItem, TArray< TSharedPtr<FActorDeviceProfileViewModel> >& OutChildren, int32 QualityLevel)
{
	{
		OutChildren = InItem->Children;
	}
}

FReply FActorPlatformSetCustomLayout::ToggleMenuOpenForQualityLevel(int32 QualityLevel)
{
	check(QualityLevelMenuAnchors.IsValidIndex(QualityLevel));

	QualityLevelMenuContents[QualityLevel].Reset();
	GenerateDeviceProfileTreeWidget(QualityLevel);
	
	TSharedPtr<SMenuAnchor> MenuAnchor = QualityLevelMenuAnchors[QualityLevel];
	MenuAnchor->SetIsOpen(!MenuAnchor->IsOpen());

	return FReply::Handled();
}

ECheckBoxState FActorPlatformSetCustomLayout::IsQLChecked(int32 QualityLevel)const
{
	if (TargetPlatformSet)
	{
		return TargetPlatformSet->IsEffectQualityEnabled(QualityLevel) ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
	}
	return ECheckBoxState::Undetermined;
}

void FActorPlatformSetCustomLayout::QLCheckStateChanged(ECheckBoxState CheckState, int32 QualityLevel)
{
	PropertyHandle->NotifyPreChange();
	TargetPlatformSet->SetEnabledForEffectQuality(QualityLevel, CheckState == ECheckBoxState::Checked);
	TArray<UObject*> Objects;
	PropertyHandle->GetOuterObjects(Objects);
	for(UObject* Object:Objects)
	{
		if(AActor* Actor=Cast<AActor>(Object))
		{
			FActorPlatformSetUtilities::OnActorPlatformPostChanged(*Actor);
		}
	}
	PropertyHandle->NotifyPostChange(EPropertyChangeType::ValueSet);

	// InvalidateSiblingConflicts();
}

FSlateColor FActorPlatformSetCustomLayout::GetQualityLevelButtonTextColor(int32 QualityLevel) const
{
	return TargetPlatformSet->IsEffectQualityEnabled(QualityLevel) ? 
		FSlateColor(FLinearColor(0.95f, 0.95f, 0.95f)) :
		FSlateColor::UseForeground();
}

TSharedRef<SWidget> FActorPlatformSetCustomLayout::GenerateAdditionalDevicesWidgetForQL(int32 QualityLevel)
{
	TSharedRef<SVerticalBox> Container = SNew(SVerticalBox);

	auto AddDeviceProfileOverrideWidget = [&](UDeviceProfile* Profile, bool bEnabled)
	{
		TSharedPtr<SHorizontalBox> DeviceBox;

		Container->AddSlot()
			.AutoHeight()
			[
				SAssignNew(DeviceBox, SHorizontalBox)
			];

		const FText DeviceNameText = FText::FromName(Profile->GetFName());

		DeviceBox->AddSlot()
			.AutoWidth()
			.HAlign(HAlign_Left)
			.VAlign(VAlign_Center)
			.Padding(3, 0, 3, 0)
			[
				SNew(SBox)
				.WidthOverride(8)
				.HeightOverride(8)
				.ToolTipText(bEnabled ?
					LOCTEXT("DeviceIncludedToolTip", "This device is included.") :
					LOCTEXT("DeviceExcludedToolTip", "This device is excluded."))
				[
					SNew(SImage)
					.Image(bEnabled ?
						FNiagaraEditorStyle::Get().GetBrush("NiagaraEditor.PlatformSet.Include") :
						FNiagaraEditorStyle::Get().GetBrush("NiagaraEditor.PlatformSet.Exclude"))
					.ColorAndOpacity(bEnabled ?
						FLinearColor(0, 1, 0) :
						FLinearColor(1, 0, 0))
					]
				];

		DeviceBox->AddSlot()
			.HAlign(HAlign_Fill)
			.Padding(0, 0, 2, 0)
			[
				SNew(STextBlock)
				.Text(DeviceNameText)
				.ToolTipText(DeviceNameText)
			];

		DeviceBox->AddSlot()
			.AutoWidth()
			.HAlign(HAlign_Right)
			.VAlign(VAlign_Center)
			.Padding(0, 0, 2, 0)
			[
				SNew(SBox)
				.WidthOverride(12)
				.HeightOverride(12)
				[
					SNew(SImage)
					.ToolTipText(this, &FActorPlatformSetCustomLayout::GetDeviceProfileErrorToolTip, Profile, QualityLevel)
					.Visibility(this, &FActorPlatformSetCustomLayout::GetDeviceProfileErrorVisibility, Profile, QualityLevel)
					.Image(FAppStyle::GetBrush("Icons.Error"))
				]
			];

		DeviceBox->AddSlot()
			.AutoWidth()
			.HAlign(HAlign_Right)
			.VAlign(VAlign_Center)
			.Padding(0, 0, 2, 0)
			[
				SNew(SButton)
				.ButtonStyle(FAppStyle::Get(), "HoverHintOnly")
				.ForegroundColor(FSlateColor::UseForeground())
				.OnClicked(this, &FActorPlatformSetCustomLayout::RemoveDeviceProfile, Profile, QualityLevel)
				.ToolTipText(LOCTEXT("RemoveDevice", "Remove this device override."))
				[
					SNew(SBox)
					.WidthOverride(8)
					.HeightOverride(8)
					.VAlign(VAlign_Center)
					[
						SNew(SImage)
						.Image(FNiagaraEditorStyle::Get().GetBrush("NiagaraEditor.PlatformSet.Remove"))
					]
				]
			];
		};

	TArray<UDeviceProfile*> EnabledProfiles;
	TArray<UDeviceProfile*> DisabledProfiles;
	TargetPlatformSet->GetOverridenDeviceProfiles(QualityLevel, EnabledProfiles, DisabledProfiles);

	for (UDeviceProfile* Profile : EnabledProfiles)
	{
		AddDeviceProfileOverrideWidget(Profile, true);
	}

	for (UDeviceProfile* Profile : DisabledProfiles)
	{
		AddDeviceProfileOverrideWidget(Profile, false);
	}

	return Container;
}

EVisibility FActorPlatformSetCustomLayout::GetDeviceProfileErrorVisibility(UDeviceProfile* Profile, int32 QualityLevel) const
{
	// not part of an array
	// if (PlatformSetArrayIndex == INDEX_NONE)
	// {
	// 	return EVisibility::Collapsed;
	// }
	//
	// for (const FNiagaraPlatformSetConflictInfo& ConflictInfo : CachedConflicts)
	// {
	// 	if (ConflictInfo.SetAIndex == PlatformSetArrayIndex || 
	// 		ConflictInfo.SetBIndex == PlatformSetArrayIndex)
	// 	{
	// 		const int32 QLMask = FNiagaraPlatformSet::CreateQualityLevelMask(QualityLevel);
	//
	// 		for (const FNiagaraPlatformSetConflictEntry& Entry : ConflictInfo.Conflicts)
	// 		{
	// 			if ((Entry.QualityLevelMask & QLMask) != 0 &&
	// 				Entry.ProfileName == Profile->GetFName())
	// 			{
	// 				return EVisibility::Visible;
	// 			}
	// 		}
	// 	}
	// }

	return EVisibility::Collapsed;
}

FText FActorPlatformSetCustomLayout::GetDeviceProfileErrorToolTip(UDeviceProfile* Profile, int32 QualityLevel) const
{
	// for (const FNiagaraPlatformSetConflictInfo& ConflictInfo : CachedConflicts)
	// {
	// 	int32 OtherIndex = INDEX_NONE;
	//
	// 	if (ConflictInfo.SetAIndex == PlatformSetArrayIndex)
	// 	{
	// 		OtherIndex = ConflictInfo.SetBIndex;
	// 	}
	//
	// 	if (ConflictInfo.SetBIndex == PlatformSetArrayIndex)
	// 	{
	// 		OtherIndex = ConflictInfo.SetAIndex;
	// 	}
	//
	// 	if (OtherIndex != INDEX_NONE)
	// 	{
	// 		const int32 QLMask = FNiagaraPlatformSet::CreateQualityLevelMask(QualityLevel);
	//
	// 		for (const FNiagaraPlatformSetConflictEntry& Entry : ConflictInfo.Conflicts)
	// 		{
	// 			if ((Entry.QualityLevelMask & QLMask) != 0 &&
	// 				Entry.ProfileName == Profile->GetFName())
	// 			{
	// 				FText FormatString = LOCTEXT("PlatformOverrideConflictToolTip", "This platform override conflicts with the set at index {Index} in this array."); 
	//
	// 				FFormatNamedArguments Args;
	// 				Args.Add(TEXT("Index"), OtherIndex);
	//
	// 				return FText::Format(FormatString, Args);
	// 			}
	// 		}
	// 	}
	// }

	return FText::GetEmpty();
}

FReply FActorPlatformSetCustomLayout::RemoveDeviceProfile(UDeviceProfile* Profile, int32 QualityLevel)
{
	PropertyHandle->NotifyPreChange();
	TargetPlatformSet->SetDeviceProfileState(Profile, QualityLevel, EActorPlatformSelectionState::Default);
	TArray<UObject*> Objects;
	PropertyHandle->GetOuterObjects(Objects);
	for(UObject* Object:Objects)
	{
		if(AActor* Actor=Cast<AActor>(Object))
		{
			FActorPlatformSetUtilities::OnActorPlatformPostChanged(*Actor);
		}
	}
	PropertyHandle->NotifyPostChange(EPropertyChangeType::ValueSet);

	// InvalidateSiblingConflicts();

	return FReply::Handled();
}

void FActorPlatformSetCustomLayout::CreateDeviceProfileTree()
{
	//Pull device profiles out by their hierarchy depth.
	TArray<TArray<UDeviceProfile*>> DeviceProfilesByHierarchyLevel;
	for (UObject* Profile : UDeviceProfileManager::Get().Profiles)
	{
		UDeviceProfile* DeviceProfile = CastChecked<UDeviceProfile>(Profile);

		TFunction<void(int32&, UDeviceProfile*)> FindDepth;
		FindDepth = [&](int32& Depth, UDeviceProfile* CurrProfile)
		{
			if (CurrProfile->Parent)
			{
				FindDepth(++Depth, Cast<UDeviceProfile>(CurrProfile->Parent));
			}
		};

		int32 ProfileDepth = 0;
		FindDepth(ProfileDepth, DeviceProfile);
		DeviceProfilesByHierarchyLevel.SetNum(FMath::Max(ProfileDepth+1, DeviceProfilesByHierarchyLevel.Num()));
		DeviceProfilesByHierarchyLevel[ProfileDepth].Add(DeviceProfile);
	}
	
	FullDeviceProfileTree.Reset(DeviceProfilesByHierarchyLevel[0].Num());
	for (int32 RootProfileIdx = 0; RootProfileIdx < DeviceProfilesByHierarchyLevel[0].Num(); ++RootProfileIdx)
	{
		TFunction<void(FActorDeviceProfileViewModel*, int32)> BuildProfileTree;
		BuildProfileTree = [&](FActorDeviceProfileViewModel* CurrRoot, int32 CurrLevel)
		{
			int32 NextLevel = CurrLevel + 1;
			if (NextLevel < DeviceProfilesByHierarchyLevel.Num())
			{
				for (UDeviceProfile* PossibleChild : DeviceProfilesByHierarchyLevel[NextLevel])
				{
					if (PossibleChild->Parent == CurrRoot->Profile)
					{
						TSharedPtr<FActorDeviceProfileViewModel>& NewChild = CurrRoot->Children.Add_GetRef(MakeShared<FActorDeviceProfileViewModel>());
						NewChild->Profile = PossibleChild;
						BuildProfileTree(NewChild.Get(), NextLevel);
					}
				}
			}
		};

		//Add all root nodes and build their trees.
		TSharedPtr<FActorDeviceProfileViewModel> CurrRoot = MakeShared<FActorDeviceProfileViewModel>();
		CurrRoot->Profile = DeviceProfilesByHierarchyLevel[0][RootProfileIdx];
		BuildProfileTree(CurrRoot.Get(), 0);
		FullDeviceProfileTree.Add(CurrRoot);
	}

	// const UNiagaraSettings* Settings = GetDefault<UNiagaraSettings>();
	// check(Settings);

	// int32 NumQualityLevels = Settings->QualityLevels.Num();
	
	int32 NumQualityLevels = 5;
	FilteredDeviceProfileTrees.Reset();
	FilteredDeviceProfileTrees.SetNum(NumQualityLevels);
	
	for (TSharedPtr<FActorDeviceProfileViewModel>& FullDeviceRoot : FullDeviceProfileTree)
	{
		for (int32 QualityLevel = 0; QualityLevel < NumQualityLevels; ++QualityLevel)
		{
			int32 QualityLevelMask = FActorPlatformSet::CreateQualityLevelMask(QualityLevel);

			if (IsTreeActiveForQL(FullDeviceRoot, QualityLevelMask))
			{
				TArray<TSharedPtr<FActorDeviceProfileViewModel>>& FilteredRoots = FilteredDeviceProfileTrees[QualityLevel];

				TSharedPtr<FActorDeviceProfileViewModel>& FilteredRoot = FilteredRoots.Add_GetRef(MakeShared<FActorDeviceProfileViewModel>());
				FilteredRoot->Profile = FullDeviceRoot->Profile;

				FilterTreeForQL(FullDeviceRoot, FilteredRoot, QualityLevelMask);
			}
		}
	}
}

bool FActorPlatformSetCustomLayout::IsTreeActiveForQL(const TSharedPtr<FActorDeviceProfileViewModel>& Tree, int32 QualityLevelMask) const
{
	if (TargetPlatformSet->CanConsiderDeviceProfile(Tree->Profile.Get()) == false)
	{
		return false;
	}

	int32 AvailableMask = TargetPlatformSet->GetAvailableQualityMaskForDeviceProfile(Tree->Profile.Get());

	return (AvailableMask & QualityLevelMask) != 0;
}

void FActorPlatformSetCustomLayout::FilterTreeForQL(const TSharedPtr<FActorDeviceProfileViewModel>& SourceTree, TSharedPtr<FActorDeviceProfileViewModel>& FilteredTree, int32 QualityLevelMask)
{
	for (const TSharedPtr<FActorDeviceProfileViewModel>& SourceChild : SourceTree->Children)
	{
		if (IsTreeActiveForQL(SourceChild, QualityLevelMask))
		{
			TSharedPtr<FActorDeviceProfileViewModel>& FilteredChild = FilteredTree->Children.Add_GetRef(MakeShared<FActorDeviceProfileViewModel>());
			FilteredChild->Profile = SourceChild->Profile;

			FilterTreeForQL(SourceChild, FilteredChild, QualityLevelMask);
		}
	}
}

EVisibility FActorPlatformSetCustomLayout::GetProfileMenuButtonVisibility(TSharedPtr<FActorDeviceProfileViewModel> Item, int32 QualityLevel) const
{
	EProfileButtonMode Mode = GetProfileMenuButtonMode(TargetPlatformSet, Item, QualityLevel);
	if (Mode == EProfileButtonMode::None)
	{
		return EVisibility::Collapsed;
	}

	return EVisibility::Visible;
}

FReply FActorPlatformSetCustomLayout::OnProfileMenuButtonClicked(TSharedPtr<FActorDeviceProfileViewModel> Item, int32 QualityLevel, bool bReopenMenu)
{
	EActorPlatformSelectionState TargetState;

	EProfileButtonMode Mode = GetProfileMenuButtonMode(TargetPlatformSet, Item, QualityLevel);
	switch(Mode)
	{
	case EProfileButtonMode::Include:
		TargetState = EActorPlatformSelectionState::Enabled;
		break;
	case EProfileButtonMode::Exclude:
		TargetState = EActorPlatformSelectionState::Disabled;
		break;
	case EProfileButtonMode::Remove:
		TargetState = EActorPlatformSelectionState::Default;
		break;
	default:
		return FReply::Handled(); // shouldn't happen, button should be collapsed
	}

	PropertyHandle->NotifyPreChange();
	TargetPlatformSet->SetDeviceProfileState(Item->Profile.Get(), QualityLevel, TargetState);
	TArray<UObject*> Objects;
	PropertyHandle->GetOuterObjects(Objects);
	for(UObject* Object:Objects)
	{
		if(AActor* Actor=Cast<AActor>(Object))
		{
			FActorPlatformSetUtilities::OnActorPlatformPostChanged(*Actor);
		}
	}
	PropertyHandle->NotifyPostChange(EPropertyChangeType::ValueSet);

	// InvalidateSiblingConflicts();

	if (!bReopenMenu)
	{
		QualityLevelMenuAnchors[QualityLevel]->SetIsOpen(false);
	}

	DeviceProfileTreeWidget->RequestTreeRefresh();

	return FReply::Handled();
}

FText FActorPlatformSetCustomLayout::GetProfileMenuButtonToolTip(TSharedPtr<FActorDeviceProfileViewModel> Item, int32 QualityLevel) const
{
	EProfileButtonMode Mode = GetProfileMenuButtonMode(TargetPlatformSet, Item, QualityLevel);
	switch(Mode)
	{
	case EProfileButtonMode::Include:
		return LOCTEXT("IncludePlatform", "Include this platform.");
	case EProfileButtonMode::Exclude:
		return LOCTEXT("ExcludePlatform", "Exclude this platform.");
	case EProfileButtonMode::Remove:
		return LOCTEXT("RemovePlatform", "Remove this platform override.");
	}

	return FText::GetEmpty();
}

bool FActorPlatformSetCustomLayout::GetProfileMenuItemEnabled(TSharedPtr<FActorDeviceProfileViewModel> Item, int32 QualityLevel) const
{
	EProfileButtonMode Mode = GetProfileMenuButtonMode(TargetPlatformSet, Item, QualityLevel);
	if (Mode == EProfileButtonMode::None)
	{
		return false;
	}

	return true;
}

const FSlateBrush* FActorPlatformSetCustomLayout::GetProfileMenuButtonImage(TSharedPtr<FActorDeviceProfileViewModel> Item, int32 QualityLevel) const
{
	EProfileButtonMode Mode = GetProfileMenuButtonMode(TargetPlatformSet, Item, QualityLevel);
	switch(Mode)
	{
	case EProfileButtonMode::Include:
		return FNiagaraEditorStyle::Get().GetBrush("NiagaraEditor.PlatformSet.Include");
	case EProfileButtonMode::Exclude:
		return FNiagaraEditorStyle::Get().GetBrush("NiagaraEditor.PlatformSet.Exclude");
	case EProfileButtonMode::Remove:
		return FNiagaraEditorStyle::Get().GetBrush("NiagaraEditor.PlatformSet.Remove");
	}

	return FAppStyle::GetBrush("NoBrush");
}

#undef LOCTEXT_NAMESPACE