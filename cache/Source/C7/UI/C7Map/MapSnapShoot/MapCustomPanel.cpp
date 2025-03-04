#if WITH_EDITOR
#include "MapCustomPanel.h"
#include "Widgets/SWindow.h"
#include "LevelEditorViewport.h"
#include "Framework/MultiBox/MultiBoxBuilder.h"
#include "EditorViewportCommands.h"
#include "ShowFlagMenuCommands.h"
#include "LevelViewportActions.h"
#include "SLevelViewport.h"
#include "Widgets/Layout/SSplitter.h"
#include "C7HighresScreenshotUI.h"
#include "MapShoot.h"
#include "Kismet/KismetSystemLibrary.h"
#include "UnrealEdGlobals.h"
#include "Editor/UnrealEdEngine.h"
#include "Layers/LayersSubsystem.h"
#include "EditorSupportDelegates.h"
#include "MapShotDebugDrawComponent.h"

#define LOCTEXT_NAMESPACE "C7MapShot" 

TWeakPtr<class SWindow> SMapCustomPanel::CurrentWindow = NULL;
TWeakPtr<class SMapCustomPanel> SMapCustomPanel::CurrentDialog = NULL;
bool SMapCustomPanel::bMaskVisualizationWasEnabled = false;
FLevelEditorViewportClient* SMapCustomPanel::ViewportClient = NULL;

TWeakPtr<class SWindow> SMapCustomPanel::OpenDialog(TObjectPtr<AMapShoot> MapShoot)
{
	auto CurrentWindowPinned = CurrentWindow.Pin();

	if (!CurrentWindow.IsValid())
	{
		ViewportClient = GCurrentLevelEditingViewportClient;
		TSharedRef<SMapCustomPanel> Dialog = SNew(SMapCustomPanel).MapShoot(MapShoot);
		TSharedRef<SWindow> Window = SNew(SWindow)
			.Title(FText::FromString("Custom Map Screen Shoot Panel"))
			.ClientSize(FVector2D(960, 604))
			.SupportsMaximize(false).SupportsMinimize(false).FocusWhenFirstShown(true)
			[
				Dialog
			];
		Window->SetOnWindowClosed(FOnWindowClosed::CreateStatic(&WindowClosedHandler));
		TSharedPtr<SWindow> ParentWindow = FGlobalTabmanager::Get()->GetRootWindow();
		
		if (ParentWindow.IsValid())
		{
			FSlateApplication::Get().AddWindowAsNativeChild(Window, ParentWindow.ToSharedRef());
		}
		else
		{
			FSlateApplication::Get().AddWindow(Window);
		}
		CurrentWindow = TWeakPtr<SWindow>(Window);
		CurrentDialog = TWeakPtr< SMapCustomPanel>(Dialog);
		FHighResScreenshotConfig& Config = GetHighResScreenshotConfig();
		TSharedPtr<SLevelViewport> LevelViewport = StaticCastSharedPtr<SLevelViewport>(ViewportClient->GetEditorViewportWidget());
		bMaskVisualizationWasEnabled = LevelViewport->GetSceneViewport()->GetClient()->GetEngineShowFlags()->HighResScreenshotMask;
		LevelViewport->GetSceneViewport()->GetClient()->GetEngineShowFlags()->SetHighResScreenshotMask(Config.bMaskEnabled);
	}
	return CurrentWindow;
}

void SMapCustomPanel::WindowClosedHandler(const TSharedRef<SWindow>& InWindow)
{
	FHighResScreenshotConfig& Config = GetHighResScreenshotConfig();
	Config.bDisplayCaptureRegion = false;//����������������������ã�����Ϊ�˱����UEԭ�������Config�ĵط�������ͻ���ڽ���رպ�������
	Config.ChangeViewport(TWeakPtr<FSceneViewport>());//�򿪵�ʱ�����õ���GCurrentViewportClient��Viewport�ϣ��رյ�ʱ��ԭ
	if (ViewportClient)
	{
		UKismetSystemLibrary::ExecuteConsoleCommand(ViewportClient->GetWorld(), TEXT("r.ResetRenderTargetsExtent"), nullptr);
		TSharedPtr<SLevelViewport> LevelViewport = StaticCastSharedPtr<SLevelViewport>(ViewportClient->GetEditorViewportWidget());
		LevelViewport->GetSceneViewport()->GetClient()->GetEngineShowFlags()->SetHighResScreenshotMask(bMaskVisualizationWasEnabled);//��ԭ����֮ǰ��״̬
	}
	bMaskVisualizationWasEnabled = false;
	CurrentWindow.Reset();
	CurrentDialog.Reset();
}

void SMapCustomPanel::Construct(const FArguments& InArgs)
{
	MyMapShoot = InArgs._MapShoot;
	if (MyMapShoot == nullptr)
	{
		return;
	}
	ChildSlot[
		SNew(SSplitter) + SSplitter::Slot()[
			ConstructViewMode().ToSharedRef()
		] + SSplitter::Slot()[
			ConstructShowFlags().ToSharedRef()
		] + SSplitter::Slot()[
			ConstructScreenShoot().ToSharedRef()
		]
	]; 
}

void SMapCustomPanel::LockToMapShootActor()
{
	if (ViewportClient)
	{
		TSharedPtr<SLevelViewport> LevelViewport = StaticCastSharedPtr<SLevelViewport>(ViewportClient->GetEditorViewportWidget());
		AActor* Actor = Cast<AActor>(MyMapShoot);
		LevelViewport->OnActorLockToggleFromMenu(Actor);
	}
}


TSharedPtr<SWidget> SMapCustomPanel::ConstructViewMode() 
{
	if (ViewportClient && ViewportClient->GetEditorViewportWidget())
	{
		const FEditorViewportCommands& BaseViewportActions = FEditorViewportCommands::Get();
		TSharedPtr<FUICommandList> CommandList = ViewportClient->GetEditorViewportWidget()->GetCommandList();
		FMenuBuilder MenuBuilder(true, CommandList);// , FMultiBoxCustomization::None);
		MenuBuilder.BeginSection("ViewMode");
		MenuBuilder.AddMenuEntry(BaseViewportActions.LitMode);
		MenuBuilder.AddMenuEntry(BaseViewportActions.UnlitMode);
		MenuBuilder.AddMenuEntry(BaseViewportActions.WireframeMode);
		MenuBuilder.AddMenuEntry(BaseViewportActions.DetailLightingMode);
		MenuBuilder.AddMenuEntry(BaseViewportActions.LightingOnlyMode);
		MenuBuilder.AddMenuEntry(BaseViewportActions.ReflectionOverrideMode);
		MenuBuilder.AddMenuEntry(BaseViewportActions.CollisionPawn);
		MenuBuilder.AddMenuEntry(BaseViewportActions.CollisionVisibility);
		MenuBuilder.AddMenuEntry(BaseViewportActions.VisualizeLumenMode);
		MenuBuilder.EndSection();
		return MenuBuilder.MakeWidget();
	}
	return SNew(STextBlock).Text(FText::FromString("Error"));
}

TSharedPtr<SWidget> SMapCustomPanel::ConstructShowFlags()
{
	if (ViewportClient && ViewportClient->GetEditorViewportWidget())
	{
		const FShowFlagMenuCommands& BaseViewportActions = FShowFlagMenuCommands::Get();
		UToolMenu* MyMenu = UToolMenus::Get()->ExtendMenu("MapShootFlagMenu");
		TSharedPtr<FUICommandList> CommandList = ViewportClient->GetEditorViewportWidget()->GetCommandList();
		MyMenu->Context = FToolMenuContext(CommandList);
		FShowFlagMenuCommands::Get().BuildShowFlagsMenu(MyMenu, FShowFlagFilter(FShowFlagFilter::EDefaultMode::IncludeAllFlagsByDefault));
		return UToolMenus::Get()->GenerateWidget(MyMenu);
	}
	return SNew(STextBlock).Text(FText::FromString("Error"));
}

TSharedPtr<SWidget> SMapCustomPanel::ConstructScreenShoot()
{
	if (ViewportClient && ViewportClient->GetEditorViewportWidget())
	{
		const FLevelViewportCommands& ViewportActions = FLevelViewportCommands::Get();
		TSharedPtr<FUICommandList> CommandList = ViewportClient->GetEditorViewportWidget()->GetCommandList();
		FMenuBuilder MenuBuilder(true, CommandList);// , FMultiBoxCustomization::None);
		
		FUIAction Action(
			FExecuteAction::CreateSP(this, &SMapCustomPanel::LockToMapShootActor)
		);
		MenuBuilder.AddMenuEntry(Action, SNew(STextBlock).Text(FText::FromString("LockCamera")));

		Action = FExecuteAction::CreateSP(this, &SMapCustomPanel::ResetMapShowFlags);
		MenuBuilder.AddMenuEntry(Action, SNew(STextBlock).Text(FText::FromString("ResetMapShowFlags")));
		
		TSharedRef<SWidget> NavMeshEdgesCheckBox = SNew(SBox)
		[
			SNew(SCheckBox)
				.IsChecked(MyMapShoot->DebugDrawComponent->bDrawNavMeshEdges ? ECheckBoxState::Checked : ECheckBoxState::Unchecked)
				.OnCheckStateChanged(this, &SMapCustomPanel::OnNavMeshEdgesCheckBoxStateChanged)
				.Style(FAppStyle::Get(), "Menu.CheckBox")
				.ToolTipText(LOCTEXT("NavMeshEdgesTips", "Toggle visibility of NavMesh edges."))
				.Content()
				[
					SNew(SHorizontalBox)
					+SHorizontalBox::Slot()
					.Padding(2.0f, 0.0f, 0.0f, 0.0f)
					[
						SNew(STextBlock)
							.Text(LOCTEXT("NavMeshEdges", "NavMesh Edges"))
					]
				]
		];
		MenuBuilder.AddMenuEntry(FUIAction(), NavMeshEdgesCheckBox);

		TSharedRef<SWidget> CameraEdgesCheckBox = SNew(SBox)
			[
				SNew(SCheckBox)
					.IsChecked(MyMapShoot->DebugDrawComponent->bDrawCameraEdges ? ECheckBoxState::Checked : ECheckBoxState::Unchecked)
					.OnCheckStateChanged(this, &SMapCustomPanel::OnCameraEdgesCheckBoxStateChanged)
					.Style(FAppStyle::Get(), "Menu.CheckBox")
					.ToolTipText(LOCTEXT("CameraEdgesTips", "Toggle visibility of Camera edges."))
					.Content()
					[
						SNew(SHorizontalBox)
							+ SHorizontalBox::Slot()
							.Padding(2.0f, 0.0f, 0.0f, 0.0f)
							[
								SNew(STextBlock)
									.Text(LOCTEXT("CameraEdges", "Camera Edges"))
							]
					]
			];
		MenuBuilder.AddMenuEntry(FUIAction(), CameraEdgesCheckBox);

		MenuBuilder.EndSection();
		TSharedPtr<SHighResScreenshotDialog> Widget = SNew(SHighResScreenshotDialog).OnTakeScreenShoot_Raw(this, &SMapCustomPanel::OnTakeScreenShoot);
		TSharedPtr<SLevelViewport> LevelViewport = StaticCastSharedPtr<SLevelViewport>(ViewportClient->GetEditorViewportWidget());
		Widget->GetConfig().ChangeViewport(LevelViewport->GetSceneViewport());
		return SNew(SScrollBox) + SScrollBox::Slot().AutoSize()[MenuBuilder.MakeWidget()]
			+ SScrollBox::Slot().AutoSize()[Widget.ToSharedRef()];
	}
	return SNew(STextBlock).Text(FText::FromString("Error"));
}

void SMapCustomPanel::ResetMapShowFlags()
{
	const EViewModeIndex CachedViewMode = ViewportClient->GetViewMode();
	ViewportClient->SetGameView(false);

	// Get default save flags
	FEngineShowFlags EditorShowFlags(ESFIM_Editor);
	FEngineShowFlags GameShowFlags(ESFIM_Game);

	EditorShowFlags.SetFromString(TEXT("Splines=0"));
	GameShowFlags.SetFromString(TEXT("Splines=0"));
	
	// this trashes the current viewmode!
	ViewportClient->EngineShowFlags = EditorShowFlags;
	// Restore the state of SelectionOutline based on user settings
	ViewportClient->EngineShowFlags.SetSelectionOutline(false);
	ViewportClient->LastEngineShowFlags = GameShowFlags;

	// re-apply the cached viewmode, as it was trashed with FEngineShowFlags()
	ApplyViewMode(CachedViewMode, ViewportClient->IsPerspective(), ViewportClient->EngineShowFlags);
	ApplyViewMode(CachedViewMode, ViewportClient->IsPerspective(), ViewportClient->LastEngineShowFlags);

	// set volume / sprite visibility hide
	ViewportClient->InitializeVisibilityFlags();
	ULayersSubsystem* Layers = GEditor->GetEditorSubsystem<ULayersSubsystem>();
	Layers->UpdatePerViewVisibility(ViewportClient);
	ViewportClient->SetAllSpriteCategoryVisibility(false);
	ViewportClient->Invalidate();

	ViewportClient->VolumeActorVisibility.Init(false, ViewportClient->VolumeActorVisibility.Num());
	GUnrealEd->UpdateVolumeActorVisibility(nullptr, ViewportClient);
}

void SMapCustomPanel::OnNavMeshEdgesCheckBoxStateChanged(ECheckBoxState NewCheckedState)
{
	MyMapShoot->DebugDrawComponent->bDrawNavMeshEdges = NewCheckedState == ECheckBoxState::Checked;
	MyMapShoot->DebugDrawComponent->MarkRenderStateDirty();
	FEditorSupportDelegates::RedrawAllViewports.Broadcast();
}

void SMapCustomPanel::OnCameraEdgesCheckBoxStateChanged(ECheckBoxState NewCheckedState)
{
	MyMapShoot->DebugDrawComponent->bDrawCameraEdges = NewCheckedState == ECheckBoxState::Checked;
	MyMapShoot->DebugDrawComponent->MarkRenderStateDirty();
	FEditorSupportDelegates::RedrawAllViewports.Broadcast();
}

FReply SMapCustomPanel::OnTakeScreenShoot()
{
	if (MyMapShoot)
	{
		FString Info = "return {\n";
		UCameraComponent* CameraComponent = MyMapShoot->GetCameraComponent();
		const FVector camera_position = MyMapShoot->GetActorLocation();
		const FVector camera_forward = MyMapShoot->GetActorForwardVector();
		{
			Info += FString::Printf(TEXT("Location = {X = %.3f, Y = %.3f, Z = %.3f},\n"), camera_position.X, camera_position.Y, camera_position.Z);
			Info += FString::Printf(TEXT("Rotation = {Pitch = %.3f, Yaw = %.3f, Roll = %.3f},\n"), MyMapShoot->GetActorRotation().Pitch, MyMapShoot->GetActorRotation().Yaw, MyMapShoot->GetActorRotation().Roll);
		}
		{
			Info += CameraComponent->ProjectionMode == ECameraProjectionMode::Orthographic ? "ProjectionMode = import(\"ECameraProjectionMode\").Orthographic,\n"
				: CameraComponent->ProjectionMode == ECameraProjectionMode::Perspective ? "ProjectionMode = import(\"ECameraProjectionMode\").Perspective,\n"
				: "ProjectionMode = import(\"ECameraProjectionMode\").ECameraProjectionMode_MAX,\n";
		}
		{
			Info += "bConstrainAspectRatio = ";
			Info += CameraComponent->bConstrainAspectRatio == 0 ? "true,\n" : "false,\n";
			Info += FString::Printf(TEXT("AspectRatio = %.3f,\n"), CameraComponent->AspectRatio);
		}
		{
			Info += FString::Printf(TEXT("FieldOfView = %.3f,\n"), CameraComponent->FieldOfView);
		}
		{
			Info += FString::Printf(TEXT("OrthoNearClipPlane = %.3f,\n"), CameraComponent->OrthoNearClipPlane);
			Info += FString::Printf(TEXT("OrthoFarClipPlane = %.3f,\n"), CameraComponent->OrthoFarClipPlane);
			Info += FString::Printf(TEXT("OrthoWidth = %.3f,\n"), CameraComponent->OrthoWidth);
		}
		{
			const float viewport_width = CameraComponent->OrthoWidth;
			const float viewport_height = viewport_width / CameraComponent->AspectRatio;

			const float near_clipping_plane_distance = CameraComponent->OrthoNearClipPlane;
			const float far_clipping_plane_distance = CameraComponent->OrthoFarClipPlane;

			const FVector camera_right = MyMapShoot->GetActorRightVector();
			const FVector camera_up = MyMapShoot->GetActorUpVector();

			const FVector camera_look_at = camera_position + camera_forward * far_clipping_plane_distance;
			const FVector camera_center = camera_position + camera_forward * ((far_clipping_plane_distance + near_clipping_plane_distance) / 2.0f);
			//Info += FString::Printf(TEXT("camera_forward = {X = %.3f, Y = %.3f, Z = %.3f},\n"), camera_forward.X, camera_forward.Y, camera_forward.Z);
			//Info += FString::Printf(TEXT("camera_right = {X = %.3f, Y = %.3f, Z = %.3f},\n"), camera_right.X, camera_right.Y, camera_right.Z);
			//Info += FString::Printf(TEXT("camera_up = {X = %.3f, Y = %.3f, Z = %.3f},\n"), camera_up.X, camera_up.Y, camera_up.Z);
			const FVector left = camera_right * viewport_width / 2.0f;
			const FVector top = camera_up * viewport_height / 2.0f;

			const FVector left_top = camera_look_at - left + top;
			const FVector left_bottom = camera_look_at - left - top;
			const FVector right_top = camera_look_at + left + top;
			const FVector right_bottom = camera_look_at + left - top;
			
			Info += FString::Printf(TEXT("left_top = {X = %.3f, Y = %.3f, Z = %.3f},\n"), left_top.X, left_top.Y, left_top.Z);
			Info += FString::Printf(TEXT("right_bottom = {X = %.3f, Y = %.3f, Z = %.3f},\n"), right_bottom.X, right_bottom.Y, right_bottom.Z);
			//Info += FString::Printf(TEXT("left_bottom = {X = %.3f, Y = %.3f, Z = %.3f},\n"), left_bottom.X, left_bottom.Y, left_bottom.Z);
			//Info += FString::Printf(TEXT("right_top = {X = %.3f, Y = %.3f, Z = %.3f},\n"), right_top.X, right_top.Y, right_top.Z);
		}
		Info += "}";
		FString Path = UKismetSystemLibrary::GetProjectSavedDirectory() + "/ScreenShots/WindowsEditor/CameraeInfos.lua";
		FFileHelper::SaveStringToFile(Info, *Path, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM);
	}
	return FReply::Unhandled();
}
#undef LOCTEXT_NAMESPACE
#endif