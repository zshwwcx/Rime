// Copyright 2020 T, Inc. All Rights Reserved.
#pragma once

#include "CoreMinimal.h"
#include "Widgets/DeclarativeSyntaxSupport.h"
#include "Widgets/SCompoundWidget.h"
#include "DetailLayoutBuilder.h"
#include "Widgets/Input/SComboBox.h"
#include "Widgets/SToolTip.h"
#include "IDocumentation.h"

class PROJECTCEDITOR_API SComboEnum : public SCompoundWidget
{
public:
	DECLARE_DELEGATE_OneParam(FOnEnumSelected, int64 /*EnumValue*/);
	SLATE_BEGIN_ARGS( SComboEnum )
		: _Content()
		, _Font(  IDetailLayoutBuilder::GetDetailFont() ) 
	{}
		SLATE_DEFAULT_SLOT( FArguments, Content )
		SLATE_ARGUMENT(int64, InitiallySelectedEnum)
		SLATE_ARGUMENT( FSlateFontInfo, Font )
		SLATE_EVENT(FOnEnumSelected, OnEnumSelected)

	SLATE_END_ARGS()
public:
	void Construct( const FArguments& InArgs, UEnum* InEnum )
	{
		Enum = InEnum;

		Font = InArgs._Font;
		EnumValue = InArgs._InitiallySelectedEnum;
		OnEnumSelectedDelegate = InArgs._OnEnumSelected;

		if (!Enum->IsValidEnumValue(EnumValue))
		{
			EnumValue = Enum->GetValueByIndex(0);
			OnEnumSelectedDelegate.ExecuteIfBound(EnumValue);
		}

		GenerateComboBoxStrings(ComboItems);

		// Set up content
		TSharedPtr<SWidget> ButtonContent = InArgs._Content.Widget;
		if (InArgs._Content.Widget == SNullWidget::NullWidget)
		{
			SAssignNew(ButtonContent, STextBlock)
				.Text(this, &SComboEnum::GetDisplayText)
				.Font(InArgs._Font);
		}

		ChildSlot
		[
			SAssignNew(ComboBox, SComboBox< TSharedPtr<FString> >)
				.OptionsSource(&ComboItems)
				.InitiallySelectedItem(ComboItems[Enum->GetIndexByValue(EnumValue)])
				.OnGenerateWidget(this, &SComboEnum::OnGenerateComboWidget)
				.OnSelectionChanged(this, &SComboEnum::OnComboSelectionChanged)
				.ContentPadding(FMargin(4.0, 1.0f))
				[
					ButtonContent.ToSharedRef()
				]
		];
	}

	FText GetDisplayText() const
	{
		return FText::FromString(*ComboItems[Enum->GetIndexByValue(EnumValue)].Get());
	}

	void GenerateComboBoxStrings(TArray< TSharedPtr<FString> >& OutComboBoxStrings)
	{
		int32 Num = Enum->NumEnums();
		for (int i = 0; i < Num - 1; ++i)
		{
			bool bShouldBeHidden = Enum->HasMetaData(TEXT("Hidden"), i) || Enum->HasMetaData(TEXT("Spacer"), i);
			if (bShouldBeHidden) continue;

			TSharedPtr< FString > EnumStr(new FString(Enum->GetDisplayNameTextByIndex(i).ToString() ) );
			OutComboBoxStrings.Add(EnumStr);
			RichToolTips.Add(IDocumentation::Get()->CreateToolTip(
				Enum->GetToolTipTextByIndex(i), nullptr, 
				FString(), 
				Enum->GetNameStringByIndex(i)));
		}
	}

	void OnComboSelectionChanged(TSharedPtr<FString> NewValue, ESelectInfo::Type SelectInfo)
	{
		int32 Index = ComboItems.IndexOfByKey(NewValue);
		EnumValue = Enum->GetValueByIndex(Index);
		OnEnumSelectedDelegate.ExecuteIfBound(EnumValue);
	}

	TSharedRef<SWidget> OnGenerateComboWidget( TSharedPtr<FString> InComboString )
	{
		TSharedPtr<SToolTip> RichToolTip = nullptr;
		bool bEnabled = true;
		if (RichToolTips.Num() > 0)
		{
			int32 Index = ComboItems.IndexOfByKey(InComboString);
			if (Index >= 0)
			{
				check(ComboItems.Num() == RichToolTips.Num());
				RichToolTip = RichToolTips[Index];
			}
		}

		return
			SNew(STextBlock)
			.Text(FText::FromString(*InComboString))
			.Font(Font)
			.ToolTip(RichToolTip);
	}


private:
	FSlateFontInfo Font;
	TArray<TSharedPtr<FString>> ComboItems;
	TArray<TSharedPtr<SToolTip>> RichToolTips;
	TObjectPtr<UEnum> Enum;
	int64 EnumValue;
	TSharedPtr<SComboBox< TSharedPtr<FString>>> ComboBox;
	FOnEnumSelected OnEnumSelectedDelegate;
};
