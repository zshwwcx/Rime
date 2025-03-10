// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "Misc/Attribute.h"
#include "Layout/Visibility.h"
#include "Widgets/DeclarativeSyntaxSupport.h"
#include "Textures/SlateIcon.h"
#include "Layout/Margin.h"
#include "Widgets/SBoxPanel.h"
#include "SLevelViewport.h"
#include "Widgets/Text/STextBlock.h"
#include "Framework/MultiBox/MultiBoxDefs.h"
#include "Framework/MultiBox/MultiBoxBuilder.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Layout/SBox.h"
#include "EditorStyleSet.h"
#include "LevelEditorViewport.h"
#include "SViewportToolBar.h"
#include "LevelViewportActions.h"
#include "SSimpleEdViewport.h"
#include "SimpleEdViewportClient.h"

#define LOCTEXT_NAMESPACE "SActorLockedViewportToolbar"

class SActorLockedViewportToolbar : public SViewportToolBar
{
public:
	SLATE_BEGIN_ARGS(SActorLockedViewportToolbar){}
		SLATE_ARGUMENT(TSharedPtr<SSimpleEdViewport>, Viewport)
	SLATE_END_ARGS()

	FText GetActiveText() const
	{
		const AActor* Pilot = nullptr;
		auto ViewportPtr = Viewport.Pin();
		if (ViewportPtr.IsValid())
		{
			Pilot = ViewportPtr->GetSimpleViewportClient()->GetLockedActor();
		}
		
		return Pilot ? FText::Format(LOCTEXT("ActiveText", "[ Pilot Active - {0} ]"), FText::FromString(Pilot->GetActorLabel())) : FText();
	}

	EVisibility GetLockedTextVisibility() const
	{
		const AActor* Pilot = nullptr;
		auto ViewportPtr = Viewport.Pin();
		if (ViewportPtr.IsValid())
		{
			Pilot = ViewportPtr->GetSimpleViewportClient()->GetLockedActor();
		}

		return Pilot && Pilot->bLockLocation ? EVisibility::Visible : EVisibility::Collapsed;
	}

	void Construct(const FArguments& InArgs)
	{
		SViewportToolBar::Construct(SViewportToolBar::FArguments());

		Viewport = InArgs._Viewport;

		auto& ViewportCommands = FLevelViewportCommands::Get();

		FToolBarBuilder ToolbarBuilder(InArgs._Viewport->GetCommandList(), FMultiBoxCustomization::None);

		// Use a custom style
		FName ToolBarStyle = "ViewportMenu";
		ToolbarBuilder.SetStyle(&FAppStyle::Get(), ToolBarStyle);
		ToolbarBuilder.SetStyle(&FAppStyle::Get(), ToolBarStyle);
		ToolbarBuilder.SetLabelVisibility(EVisibility::Collapsed);

		ToolbarBuilder.BeginSection("ActorPilot");
		ToolbarBuilder.BeginBlockGroup();
		{
			static FName EjectActorPilotName = FName(TEXT("EjectActorPilot"));
			ToolbarBuilder.AddToolBarButton(ViewportCommands.EjectActorPilot, NAME_None, TAttribute<FText>(), TAttribute<FText>(), TAttribute<FSlateIcon>(), EjectActorPilotName);

			//static FName ToggleActorPilotCameraViewName = FName(TEXT("ToggleActorPilotCameraView"));
			//ToolbarBuilder.AddToolBarButton(ViewportCommands.ToggleActorPilotCameraView, NAME_None, TAttribute<FText>(), TAttribute<FText>(), TAttribute<FSlateIcon>(), ToggleActorPilotCameraViewName);
		}
		ToolbarBuilder.EndBlockGroup();
		ToolbarBuilder.EndSection();

		ToolbarBuilder.BeginSection("ActorPilot_Label");
		ToolbarBuilder.AddWidget(
			SNew(SBox)
			// Nasty hack to make this VAlign_center properly. The parent Box is set to VAlign_Bottom, so we can't fill properly.
			.HeightOverride(24.f)
			[
				SNew(SHorizontalBox)
				+ SHorizontalBox::Slot()
				.VAlign(VAlign_Center)
				[
					SNew(STextBlock)
					.TextStyle(FAppStyle::Get(), "LevelViewport.ActorPilotText")
					.Text(this, &SActorLockedViewportToolbar::GetActiveText)
				]
				+ SHorizontalBox::Slot()
				.Padding(5.0f, 0.0f)
				.VAlign(VAlign_Center)
				.AutoWidth()
				[
					SNew(STextBlock)
					.TextStyle(FAppStyle::Get(), "LevelViewport.ActorPilotText")
					.ColorAndOpacity(FLinearColor::Red)
					.Text(LOCTEXT("ActorLockedText", "(Locked)"))
					.ToolTipText(LOCTEXT("ActorLockedToolTipText", "This actor has locked movement so it will not be updated based on camera position"))
					.Visibility(this, &SActorLockedViewportToolbar::GetLockedTextVisibility)
				]
			]
		);
		ToolbarBuilder.EndSection();

		ChildSlot
		[
			SNew( SBorder )
			.BorderImage( FAppStyle::GetBrush("NoBorder") )
			.Padding(FMargin(4.f, 0.f))
			// Color and opacity is changed based on whether or not the mouse cursor is hovering over the toolbar area
			.ColorAndOpacity( this, &SViewportToolBar::OnGetColorAndOpacity )
			[
				ToolbarBuilder.MakeWidget()
			]
		];
	}

private:

	/** The viewport that we are in */
	TWeakPtr<SSimpleEdViewport> Viewport;
};

#undef LOCTEXT_NAMESPACE
