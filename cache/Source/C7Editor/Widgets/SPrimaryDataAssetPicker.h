// Copyright 2020 T, Inc. All Rights Reserved.

#pragma once
#include "CoreMinimal.h"
#include "Widgets/SCompoundWidget.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/Input/SComboButton.h"
#include "Fonts/SlateFontInfo.h"
#include "EditorStyleSet.h"
#include "ContentBrowserModule.h"
#include "IContentBrowserSingleton.h"
#include "PropertyCustomizationHelpers.h"
#include "AssetRegistryModule.h"

template<typename AssetType>
class SPrimaryDataAssetPicker : public SCompoundWidget
{
	DECLARE_DELEGATE_OneParam(FOnPickAsset, FName/* NpcId */)
private:
	FOnPickAsset OnPicked;
	FName CurrAssetId;
	TSharedPtr<SComboButton> AssetPicker;
public:
    SLATE_BEGIN_ARGS( SPrimaryDataAssetPicker )
		: _InitAssetId(NAME_None)
		, _Font( FAppStyle::GetFontStyle( TEXT("NormalFont") ) )
	{}
		SLATE_ARGUMENT(FName, InitAssetId)
		SLATE_ATTRIBUTE( FSlateFontInfo, Font )
		SLATE_EVENT(FOnPickAsset, OnPicked)
	SLATE_END_ARGS()

public:
	void Construct(const FArguments& InArgs)
	{
		this->CurrAssetId = InArgs._InitAssetId;
		this->OnPicked = InArgs._OnPicked;

		AssetPicker = SNew(SComboButton)
			.OnGetMenuContent(this, &SPrimaryDataAssetPicker::GetMenuContent)
			.ContentPadding(0)
			.ButtonContent()
			[
				SNew(SHorizontalBox)
				+SHorizontalBox::Slot()
				.AutoWidth()
				.VAlign(VAlign_Center)
				.HAlign(HAlign_Left)
				[
					SNew(STextBlock)
					.Text(this, &SPrimaryDataAssetPicker::GetCurrentAssetName)
					.Font( InArgs._Font )
				]
			];

		TSharedRef<SHorizontalBox> ButtonBox = SNew(SHorizontalBox)
			+ SHorizontalBox::Slot()
			.VAlign(VAlign_Center)
			.AutoWidth()
			.Padding(2.0f, 0.0f)
			[
				PropertyCustomizationHelpers::MakeBrowseButton(
					FSimpleDelegate::CreateSP( this, &SPrimaryDataAssetPicker::OnBrowse ),
					FText()
					)
			];

		this->ChildSlot
		[
			SNew(SHorizontalBox)
			+SHorizontalBox::Slot()
			.FillWidth(1.0f)
			.VAlign(VAlign_Center)
			[
				AssetPicker.ToSharedRef()
			]
			+ SHorizontalBox::Slot()
			.AutoWidth()
			[
				SNew(SBox)
				.Padding(FMargin(0.0f, 2.0f, 4.0f, 2.0f))
				[
					ButtonBox
				]
			]
		];
	}

	TSharedRef<SWidget> GetMenuContent()
	{
		FContentBrowserModule& ContentBrowserModule = FModuleManager::Get().LoadModuleChecked<FContentBrowserModule>(TEXT("ContentBrowser"));
		FAssetPickerConfig AssetPickerConfig;
		{
			AssetPickerConfig.Filter.ClassNames.Add(AssetType::StaticClass()->GetFName());
			AssetPickerConfig.Filter.bRecursiveClasses = true;
			AssetPickerConfig.InitialAssetViewType = EAssetViewType::List;
			AssetPickerConfig.bAllowNullSelection = false;
			AssetPickerConfig.bFocusSearchBoxWhenOpened = true;
			AssetPickerConfig.bAllowDragging = false;
			AssetPickerConfig.SaveSettingsName = TEXT("AssetPropertyPicker");
			AssetPickerConfig.OnAssetSelected = FOnAssetSelected::CreateLambda(
				[&](const FAssetData& AssetData) {
				if (UObject* Obj = AssetData.GetAsset())
				{
					if (AssetType* Asset = Cast<AssetType>(Obj))
					{
						OnPickAsset(Asset);
					}
				}
				AssetPicker->SetIsOpen(false);
			});
		}

		return SNew(SBox)
		.MinDesiredWidth(300.0f)
		.MaxDesiredHeight(400.0f)
		[
			ContentBrowserModule.Get().CreateAssetPicker(AssetPickerConfig)
		];
	}

	void OnPickAsset(AssetType* Asset)
	{
		if (Asset)
		{
			CurrAssetId = Asset->GetFName();
			if (OnPicked.IsBound())
			{
				OnPicked.ExecuteIfBound(CurrAssetId );
			}
		}
	}

	FText GetCurrentAssetName() const
	{
		return FText::FromName(CurrAssetId);
	}

	void OnBrowse()
	{
		TArray< UObject* > Objects;
		FAssetRegistryModule& AssetRegistryModule = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry");
		IAssetRegistry& AssetRegistry = AssetRegistryModule.Get();
		TArray<FAssetData> OutAssetDatas;
		FString LongPackageName;
		bool bOutSuccess = FPackageName::SearchForPackageOnDisk(CurrAssetId.ToString(), &LongPackageName);
		AssetRegistry.GetAssetsByPackageName(*LongPackageName, OutAssetDatas);
		for (FAssetData& AssetData : OutAssetDatas)
		{
			Objects.Add(AssetData.GetAsset());
		}
		GEditor->SyncBrowserToObjects( Objects );
	}
};