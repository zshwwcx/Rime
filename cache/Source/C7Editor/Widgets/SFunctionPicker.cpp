// Copyright 2020 T, Inc. All Rights Reserved.
#include "SFunctionPicker.h"

#include "Widgets/Text/STextBlock.h"
#include "Framework/MultiBox/MultiBoxBuilder.h"
#include "Framework/Application/SlateApplication.h"
#include "Widgets/Images/SImage.h"
#include "Widgets/Input/SButton.h"
#include "Widgets/Input/SComboButton.h"
#include "Binding/PropertyBinding.h"
#include "DetailLayoutBuilder.h"
#include "EdGraphSchema_K2.h"

#define LOCTEXT_NAMESPACE "SFunctionPicker"

void SFunctionPicker::Construct(const FArguments& InArgs, UClass* InFromClass, UFunction* InAllowedSignature)
{
	FromClass = InFromClass;
	FuncSignature = InAllowedSignature;
	CurrentFunction = InArgs._CurrentFunction;
	SelectedFunctionDelegate = InArgs._OnSelectedFunction;
	FunctionFilterDelegate = InArgs._OnFilterFunction;

	ChildSlot
	[
		SNew(SHorizontalBox)

		+ SHorizontalBox::Slot()
		.FillWidth(1.0f)
		[
			SNew(SComboButton)
			.OnGetMenuContent(this, &SFunctionPicker::OnGenerateDelegateMenu)
			.ContentPadding(1)
			.ButtonContent()
			[
				SNew(SHorizontalBox)
				+ SHorizontalBox::Slot()
				.AutoWidth()
				.VAlign(VAlign_Center)
				.Padding(4, 1, 0, 0)
				[
					SNew(STextBlock)
					.Text(this, &SFunctionPicker::GetCurrentFunctionText)
					.Font(IDetailLayoutBuilder::GetDetailFont())
				]
			]
		]

		+ SHorizontalBox::Slot()
		.AutoWidth()
		[
			SNew(SButton)
			.ButtonStyle(FAppStyle::Get(), "HoverHintOnly")
			.Visibility(this, &SFunctionPicker::GetGotoFunctionVisibility)
			.OnClicked(this, &SFunctionPicker::HandleGotoFunctionClicked)
			.VAlign(VAlign_Center)
			.ToolTipText(LOCTEXT("GotoFunction", "Goto Function"))
			[
				SNew(SImage)
				.Image(FAppStyle::GetBrush("PropertyWindow.Button_Browse"))
			]
		]
	];
}

TSharedRef<SWidget> SFunctionPicker::OnGenerateDelegateMenu()
{
	const bool bInShouldCloseWindowAfterMenuSelection = true;
	FMenuBuilder MenuBuilder(bInShouldCloseWindowAfterMenuSelection, nullptr);

	MenuBuilder.BeginSection("BindingActions");
	{
		if (HasFunctionBinding())
		{
			MenuBuilder.AddMenuEntry(
				LOCTEXT("ResetFunction", "Reset"),
				LOCTEXT("ResetFunctionTooltip", "Reset this function and clear it out."),
				FSlateIcon(FAppStyle::GetAppStyleSetName(), "Cross"),
				FUIAction(FExecuteAction::CreateSP(this, &SFunctionPicker::ResetFunctionBinding))
			);
		}
	}
	MenuBuilder.EndSection();

	MenuBuilder.BeginSection("Functions", LOCTEXT("Functions", "Functions"));
	{
		static FName FunctionIcon(TEXT("GraphEditor.Function_16x"));

		for ( TFieldIterator<UFunction> FuncIt(FromClass, EFieldIteratorFlags::IncludeSuper); FuncIt; ++FuncIt )
		{
			UFunction* Function = *FuncIt;
			const FName FunctionName = Function->GetFName();

			// 只有蓝图中能调的函数才会被显示
			if ( !UEdGraphSchema_K2::CanUserKismetCallFunction(Function) )
			{
				continue;
			}

			bool bIsValidFunction = true;
			// 检查函数签名
			if (FuncSignature)
			{
				if ( !Function->IsSignatureCompatibleWith(FuncSignature, UFunction::GetDefaultIgnoredSignatureCompatibilityFlags() | CPF_ReturnParm) )
				{
					bIsValidFunction = false;
				}
			}

			if (FunctionFilterDelegate.IsBound())
			{
				bIsValidFunction &= FunctionFilterDelegate.Execute(Function);
			}

			if (bIsValidFunction)
			{
				MenuBuilder.AddMenuEntry(
					FText::FromName(FunctionName),
					FText::FromString(Function->GetMetaData("Tooltip")),
					FSlateIcon(FAppStyle::GetAppStyleSetName(), FunctionIcon),
					FUIAction(FExecuteAction::CreateSP(this, &SFunctionPicker::PickFunction, Function))
					);
			}
		}
	}
	MenuBuilder.EndSection(); //Functions



	FDisplayMetrics DisplayMetrics;
	FSlateApplication::Get().GetCachedDisplayMetrics(DisplayMetrics);

	return
		SNew(SVerticalBox)

		+ SVerticalBox::Slot()
		.MaxHeight(DisplayMetrics.PrimaryDisplayHeight * 0.5)
		[
			MenuBuilder.MakeWidget()
		];

}

bool SFunctionPicker::HasFunctionBinding() const
{
	TOptional<FName> Current = CurrentFunction.Get();
	if (Current.IsSet())
	{
		if (Current.GetValue() != NAME_None)
		{
			return true;
		}
	}
	return false;
}

void SFunctionPicker::PickFunction(UFunction* SelectedFunction)
{
	const FName& FunctionName = SelectedFunction ? SelectedFunction->GetFName() : NAME_None;
	if (!CurrentFunction.IsBound())
	{
		CurrentFunction.Set(FunctionName);
	}
	SelectedFunctionDelegate.ExecuteIfBound(FunctionName);
}

void SFunctionPicker::ResetFunctionBinding()
{
	PickFunction(nullptr);
}

EVisibility SFunctionPicker::GetGotoFunctionVisibility() const
{
	if (HasFunctionBinding())
	{
		return EVisibility::Visible;
	}
	
	return EVisibility::Collapsed;
}

void SFunctionPicker::GotoFunction(class UEdGraph* FunctionGraph)
{
	//Editor.Pin()->SetCurrentMode(FWidgetBlueprintApplicationModes::GraphMode);
	//Editor.Pin()->OpenDocument(FunctionGraph, FDocumentTracker::OpenNewDocument);
}

FReply SFunctionPicker::HandleGotoFunctionClicked()
{
	GotoFunction(nullptr);
	return FReply::Handled();
}

FText SFunctionPicker::GetCurrentFunctionText() const
{
	TOptional<FName> Current = CurrentFunction.Get();

	if (Current.IsSet())
	{
		if (Current.GetValue() == NAME_None)
		{
			return LOCTEXT("SelectFunction", "Select Function");
		}
		else
		{
			return FText::FromName(Current.GetValue());
		}
	}

	return LOCTEXT("SelectFunction", "Select Function");
}
#undef LOCTEXT_NAMESPACE
