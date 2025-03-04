//// Copyright 2021 T, Inc. All Rights Reserved.
//#include "SComponentPicker.h"
//
//#include "Widgets/Text/STextBlock.h"
//#include "Framework/MultiBox/MultiBoxBuilder.h"
//#include "Framework/Application/SlateApplication.h"
//#include "Widgets/Images/SImage.h"
//#include "Widgets/Input/SButton.h"
//#include "Widgets/Input/SComboButton.h"
//#include "Binding/PropertyBinding.h"
//#include "DetailLayoutBuilder.h"
//#include "EdGraphSchema_K2.h"
//#include "Kismet2/ComponentEditorUtils.h"
//#include "Styling/SlateIconFinder.h"
//#include "PropertyCustomizationHelpers.h"
//
//#define LOCTEXT_NAMESPACE "SComponentPicker"
//
//void SComponentPicker::Construct(const FArguments& InArgs)
//{
//	HostActorClass = InArgs._HostActorClass;
//	HostActor = InArgs._HostActor;
//	CurrentComponent = InArgs._CurrentComponent;
//	SelectedFunctionDelegate = InArgs._OnSelectedComponent;
//	ComponentFilterDelegate = InArgs._OnFilterComponent;
//
//	ChildSlot
//	[
//		SNew(SHorizontalBox)
//
//		+ SHorizontalBox::Slot()
//		.FillWidth(1.0f)
//		[
//			SNew(SComboButton)
//			.OnGetMenuContent(this, &SComponentPicker::OnGetMenuContent)
//			.ContentPadding(1)
//			.ButtonContent()
//			[
//				SNew(SHorizontalBox)
//				+ SHorizontalBox::Slot()
//				.AutoWidth()
//				.VAlign(VAlign_Center)
//				.Padding(4, 1, 0, 0)
//				[
//					SNew(STextBlock)
//					.Text(this, &SComponentPicker::GetCurrentComponentText)
//					.Font(IDetailLayoutBuilder::GetDetailFont())
//				]
//			]
//		]
//	];
//}
//
//FString SComponentPicker::GetComponentDisplayString(UActorComponent* InComponent) const
//{
//	FName VariableName = FComponentEditorUtils::FindVariableNameGivenComponentInstance(InComponent);
//
//	UBlueprint* Blueprint = HostActorClass.Get() ? Cast<UBlueprint>(HostActorClass.Get()->ClassGeneratedBy) : nullptr;
//	UClass* VariableOwner = (Blueprint != nullptr) ? Blueprint->SkeletonGeneratedClass : nullptr;
//
//	bool const bHasValidVarName = (VariableName != NAME_None);
//	bool const bIsArrayVariable = bHasValidVarName && (VariableOwner != nullptr) && 
//		FindFProperty<FArrayProperty>(VariableOwner, VariableName);
//
//	if ((VariableName != NAME_None) && !bIsArrayVariable)
//	{
//		return VariableName.ToString();
//	}
//	else if ( InComponent != nullptr )
//	{
//		return InComponent->GetFName().ToString();
//	}
//	else
//	{
//		bool bIsNative = InComponent->CreationMethod == EComponentCreationMethod::Native;
//		FString UnnamedString = LOCTEXT("UnnamedToolTip", "Unnamed").ToString();
//		FString NativeString = bIsNative ? LOCTEXT("NativeToolTip", "Native ").ToString() : TEXT("");
//
//		if (InComponent != NULL)
//		{
//			return FString::Printf(TEXT("[%s %s%s]"), *UnnamedString, *NativeString, *InComponent->GetClass()->GetName());
//		}
//		else
//		{
//			return FString::Printf(TEXT("[%s %s]"), *UnnamedString, *NativeString);
//		}
//	}
//}
//
//TSharedRef<SWidget> SComponentPicker::OnGetMenuContent()
//{
//	const bool bInShouldCloseWindowAfterMenuSelection = true;
//	FMenuBuilder MenuBuilder(bInShouldCloseWindowAfterMenuSelection, nullptr);
//
//	MenuBuilder.BeginSection("BindingActions");
//	{
//		if (CurrentComponent.Get())
//		{
//			MenuBuilder.AddMenuEntry(
//				LOCTEXT("ResetComponent", "Reset"),
//				LOCTEXT("ResetComponentTooltip", "Reset this component and clear it out."),
//				FSlateIcon(FAppStyle::GetAppStyleSetName(), "Cross"),
//				FUIAction(FExecuteAction::CreateSP(this, &SComponentPicker::ResetComponent))
//			);
//		}
//	}
//	MenuBuilder.EndSection();
//
//	MenuBuilder.BeginSection("Functions", LOCTEXT("Functions", "Functions"));
//	{
//		TInlineComponentArray<UActorComponent*> Components;
//		if (HostActor.Get())
//		{
//			HostActor.Get()->GetComponents(Components);
//		}
//		else if (HostActorClass.Get())
//		{
//			HostActorClass.Get().GetDefaultObject()->GetComponents(Components);
//			UBlueprint* Blueprint = HostActorClass.Get() ? Cast<UBlueprint>(HostActorClass.Get()->ClassGeneratedBy) : nullptr;
//			if (Blueprint)
//			{
//				for (class UActorComponent* Comp : Blueprint->ComponentTemplates)
//				{
//					Components.Add(Comp);
//				}
//			}
//		}
//		for (UActorComponent* Component : Components)
//		{
//			bool bIsValidFunction = true;
//			if (ComponentFilterDelegate.IsBound())
//			{
//				bIsValidFunction &= ComponentFilterDelegate.Execute(Component);
//			}
//
//			if (bIsValidFunction)
//			{
//				MenuBuilder.AddMenuEntry(
//					FText::FromString(GetComponentDisplayString(Component)),
//					FText::FromString(Component->GetClass()->GetMetaData("Tooltip")),
//					FSlateIconFinder::FindIconForClass( Component->GetClass(), TEXT("SCS.Component") ),
//					FUIAction(FExecuteAction::CreateSP(this, &SComponentPicker::PickComponent, Component))
//					);
//			}
//		}
//
//	}
//	MenuBuilder.EndSection();
//
//	FDisplayMetrics DisplayMetrics;
//	FSlateApplication::Get().GetCachedDisplayMetrics(DisplayMetrics);
//
//	return
//		SNew(SVerticalBox)
//
//		+ SVerticalBox::Slot()
//		.MaxHeight(DisplayMetrics.PrimaryDisplayHeight * 0.5)
//		[
//			MenuBuilder.MakeWidget()
//		];
//}
//
//void SComponentPicker::PickComponent(UActorComponent* SelectedComponent)
//{
//	if (!CurrentComponent.IsBound())
//	{
//		CurrentComponent = SelectedComponent;
//	}
//	SelectedFunctionDelegate.ExecuteIfBound(SelectedComponent);
//}
//
//void SComponentPicker::ResetComponent()
//{
//	PickComponent(nullptr);
//}
//
//FText SComponentPicker::GetCurrentComponentText() const
//{
//	if (CurrentComponent.Get() != nullptr)
//	{
//		return FText::FromString(GetComponentDisplayString(CurrentComponent.Get()));
//	}
//
//	return LOCTEXT("SelectComponent", "Select Component");
//}
//#undef LOCTEXT_NAMESPACE
