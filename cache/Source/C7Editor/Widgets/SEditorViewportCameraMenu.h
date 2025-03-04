// Copyright 2021 T, Inc. All Rights Reserved.

#include "EditorViewportCameraContext.h"
#include "EditorViewportCommands.h"
#include "SEditorViewportViewMenu.h"
#include "Camera/CameraActor.h"
#include "ToolMenus.h"
#include "Engine/World.h"
#include "SSimpleEdViewport.h"
#include "EngineUtils.h"

#define LOCTEXT_NAMESPACE "SEditorViewportCameraMenu"

class SEditorViewportCameraMenu : public SEditorViewportToolbarMenu
{
public:
	DECLARE_DELEGATE_OneParam(FOnActorLockToggleHandler, AActor*);
	DECLARE_DELEGATE_RetVal_OneParam(bool, FIsActorLockerHandler, const TWeakObjectPtr<AActor>);

	SLATE_BEGIN_ARGS(SEditorViewportCameraMenu) 
	{}
		SLATE_ATTRIBUTE( FText, MenuLabel )
		SLATE_ATTRIBUTE( const FSlateBrush*, MenuIcon)
		SLATE_ARGUMENT( UWorld*, World)
		SLATE_EVENT( FOnActorLockToggleHandler, OnActorToggleHandler )
		SLATE_EVENT( FIsActorLockerHandler, IsActorLockerHandler )
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs, TSharedRef<SEditorViewport> InViewport, TSharedRef<class SViewportToolBar> InParentToolBar)
	{
		Viewport = InViewport;
		MenuLabel = InArgs._MenuLabel;
		MenuIcon = InArgs._MenuIcon;
		World = InArgs._World;
		OnActorToggleHandler = InArgs._OnActorToggleHandler;
		IsActorLockerHandler = InArgs._IsActorLockerHandler;

		SEditorViewportToolbarMenu::Construct
		(
			SEditorViewportToolbarMenu::FArguments()
				.ParentToolBar( InParentToolBar)
				.Cursor( EMouseCursor::Default )
				.Label(this, &SEditorViewportCameraMenu::GetCameraMenuLabel)
				.LabelIcon(this, &SEditorViewportCameraMenu::GetCameraMenuLabelIcon)
				.OnGetMenuContent( this, &SEditorViewportCameraMenu::GenerateCameraMenu )
		);
	}

public:
	FText GetCameraMenuLabel() const
	{
		if (MenuLabel.IsSet())
		{
			return MenuLabel.Get();
		}

		return LOCTEXT("CameraMenuTitle_Default", "Camera");
	}
	const FSlateBrush* GetCameraMenuLabelIcon() const
	{
		if (MenuIcon.IsSet())
		{
			return MenuIcon.Get();
		}
		return FAppStyle::GetBrush(NAME_None);
	}

	TSharedRef<SWidget> GenerateCameraMenu() const
	{
		static const FName CameraMenuName("Editor.EditorViewportToolBar.Camera");
		if (!UToolMenus::Get()->IsMenuRegistered(CameraMenuName))
		{
			UToolMenu* Menu = UToolMenus::Get()->RegisterMenu(CameraMenuName);
			Menu->AddDynamicSection("DynamicSection", FNewToolMenuDelegate::CreateLambda([](UToolMenu* InMenu)
			{
				if (UEditorViewportCameraMenuContext* Context = InMenu->FindContext<UEditorViewportCameraMenuContext>())
				{
					Context->EditorViewporCameraMenu.Pin()->FillCameraMenu(InMenu);
				}
			}));
		}

		UEditorViewportCameraMenuContext* ContextObject = NewObject<UEditorViewportCameraMenuContext>();
		ContextObject->EditorViewporCameraMenu = SharedThis(this);

		FToolMenuContext MenuContext(Viewport.Pin()->GetCommandList(), TSharedPtr<FExtender>(), ContextObject);
		return UToolMenus::Get()->GenerateWidget(CameraMenuName, MenuContext);
	}

	void FillCameraMenu(UToolMenu* Menu) const
	{
		{
			FToolMenuSection& Section = Menu->AddSection("CameraTypes");
			Section.AddMenuEntry(FEditorViewportCommands::Get().Perspective);
		}

		{
			FToolMenuSection& Section = Menu->AddSection("LevelViewportCameraType_Ortho", LOCTEXT("CameraTypeHeader_Ortho", "Orthographic"));
			Section.AddMenuEntry(FEditorViewportCommands::Get().Top);
			Section.AddMenuEntry(FEditorViewportCommands::Get().Bottom);
			Section.AddMenuEntry(FEditorViewportCommands::Get().Left);
			Section.AddMenuEntry(FEditorViewportCommands::Get().Right);
			Section.AddMenuEntry(FEditorViewportCommands::Get().Front);
			Section.AddMenuEntry(FEditorViewportCommands::Get().Back);
		}

		TArray<ACameraActor*> Cameras;

		for( TActorIterator<ACameraActor> It(World.Get()); It; ++It )
		{
			Cameras.Add( *It );
		}

		FText CameraActorsHeading = LOCTEXT("CameraActorsHeading", "Placed Cameras");

		// Don't add too many cameras to the top level menu or else it becomes too large
		const uint32 MaxCamerasInTopLevelMenu = 10;
		if( Cameras.Num() > MaxCamerasInTopLevelMenu )
		{
			FToolMenuSection& Section = Menu->AddSection("CameraActors");
			Section.AddSubMenu("CameraActors", CameraActorsHeading, LOCTEXT("LookThroughPlacedCameras_ToolTip", "Look through and pilot placed cameras"), FNewToolMenuDelegate::CreateSP(this, &SEditorViewportCameraMenu::GeneratePlacedCameraMenuEntries, Cameras ) );
		}
		else
		{
			FToolMenuSection& Section = Menu->AddSection("CameraActors", CameraActorsHeading);
			GeneratePlacedCameraMenuEntries(Section, Cameras);
		}
	}

	void GeneratePlacedCameraMenuEntries(UToolMenu* Menu, TArray<ACameraActor*> Cameras) const
	{
		FToolMenuSection& Section = Menu->AddSection("Section");
		GeneratePlacedCameraMenuEntries(Section, Cameras);
	}

	void GeneratePlacedCameraMenuEntries(FToolMenuSection& Section, TArray<ACameraActor*> Cameras) const
	{
		FSlateIcon CameraIcon( FAppStyle::GetAppStyleSetName(), "ClassIcon.CameraComponent" );

		for( ACameraActor* CameraActor : Cameras )
		{
			// Needed for the delegate hookup to work below
			AActor* GenericActor = CameraActor;

			FText ActorDisplayName = FText::FromString(CameraActor->GetActorLabel());
			SEditorViewportCameraMenu* MutableThis = const_cast<SEditorViewportCameraMenu*>(this);
			FUIAction LookThroughCameraAction(
				FExecuteAction::CreateSP(MutableThis, &SEditorViewportCameraMenu::OnActorLockToggle, GenericActor),
				FCanExecuteAction(),
				FIsActionChecked::CreateSP(this, &SEditorViewportCameraMenu::IsActorLocked, MakeWeakObjectPtr(GenericActor))
				);

			Section.AddMenuEntry( NAME_None, ActorDisplayName, FText::Format(LOCTEXT("LookThroughCameraActor_ToolTip", "Look through and pilot {0}"), ActorDisplayName), 
				CameraIcon, LookThroughCameraAction, EUserInterfaceActionType::RadioButton );
		}
	}

	void OnActorLockToggle(AActor* LockActor)
	{
		OnActorToggleHandler.ExecuteIfBound(LockActor);
	}

	bool IsActorLocked(const TWeakObjectPtr<AActor> TestActor) const
	{
		if (IsActorLockerHandler.IsBound())
		{
			return IsActorLockerHandler.Execute(TestActor);
		}

		return false;
	}

private:
	TWeakPtr<SEditorViewport> Viewport;
	TAttribute<FText> MenuLabel;
	TAttribute<const FSlateBrush*> MenuIcon;
	TWeakObjectPtr<UWorld> World;

	FOnActorLockToggleHandler OnActorToggleHandler;
	FIsActorLockerHandler IsActorLockerHandler;
};

#undef LOCTEXT_NAMESPACE
