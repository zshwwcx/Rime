#include "EditorExtenders/ContentMenuExtender.h"
#include "EditorExtenders/ContentMenuCommands.h"

#include "ToolMenus.h"
#include "Toolkits/AssetEditorToolkitMenuContext.h"
#include "ContentBrowserMenuContexts.h"
#include "Modules/ModuleManager.h"

#include "ContentBrowserModule.h"
#include "ContentBrowserDelegates.h"

#include "KGEditorStyle.h"

#include "EditorExtenders/ToolsLibrary.h"
#include "Kismet2/DebuggerCommands.h"
#include "InputCoreTypes.h"
#include "KGUISettings.h"
#include "GenericPlatform/GenericApplication.h"
#include "LevelEditor/LevelFlowSerializeHelper/LevelFlowSerializeHelper.h"
#include "OptScene/OptSceneEdTools.h"

#include "LevelEditor.h"
#include "LevelEditorToolbarExtender.h"
#include "Audio/KGAudioUtils.h"
#include "KGSceneEditor/Public/FileAsset/GPEditorAssetHelper.h"
#include "Tools/KGSceneTools.h"
#include "IAssetViewport.h"
#include "SLevelViewport.h"
#include "Blueprint/GameViewportSubsystem.h"
#include "Slate/SceneViewport.h"
#include "UI/UIRoot.h"

#define LOCTEXT_NAMESPACE "FContentMenuExtender"


void FContentMenuExtender::Startup()
{
	if (IsRunningCommandlet() || IsRunningGame() || !FSlateApplication::IsInitialized())
	{
		return;
	}

	FKGEditorStyle::Initialize();
	FKGEditorStyle::ReloadTextures();

	BindCommands();

	UToolMenus::RegisterStartupCallback(FSimpleMulticastDelegate::FDelegate::CreateRaw(this, &FContentMenuExtender::RegisterMenus));

	FLevelEditorModule& LevelEditorModule = FModuleManager::LoadModuleChecked<FLevelEditorModule>("LevelEditor");
	LevelEditorModule.OnLevelEditorCreated().AddLambda([this](TSharedPtr<ILevelEditor> editor)
	{
		// TWeakPtr<class ILevelEditor> LevelEditorInstance = LevelEditorModule.GetLevelEditorInstance();
		TArray<TSharedPtr<SLevelViewport>> LevelViewports = editor->GetViewports();
		ViewportResizeHandles.Empty();
		for (TSharedPtr<SLevelViewport> LevelViewport : LevelViewports)
		{
			FViewport* Viewport = LevelViewport->GetActiveViewport();
			if (Viewport)
			{
				ViewportResizeHandles.Add(Viewport, Viewport->ViewportResizedEvent.AddStatic(&FContentMenuExtender::OnViewportResized));
			}
		}
	});
}


void FContentMenuExtender::Shutdown()
{
	if (IsRunningCommandlet() || IsRunningGame() || IsRunningDedicatedServer())
	{
		return;
	}

	FKGEditorStyle::Shutdown();

	UnExtendContentPathMenu();

	UnExtendContentAssetMenu();

	UnExtendToobarMenu();

	// 只注销必然存在得Viewport当中得DelegateHandler即可
	FLevelEditorModule& LevelEditorModule = FModuleManager::LoadModuleChecked<FLevelEditorModule>("LevelEditor");
	TWeakPtr<class ILevelEditor> LevelEditorInstance = LevelEditorModule.GetLevelEditorInstance();
	if (LevelEditorInstance.IsValid())
	{
		TArray<TSharedPtr<SLevelViewport>> LevelViewports = LevelEditorInstance.Pin()->GetViewports();
		for (TSharedPtr<SLevelViewport> LevelViewport : LevelViewports)
		{
			FViewport* Viewport = LevelViewport->GetActiveViewport();
			if (ViewportResizeHandles.Contains(Viewport))
			{
				const FDelegateHandle& DelegateHandle = ViewportResizeHandles.FindRef(Viewport);
				Viewport->ViewportResizedEvent.Remove(DelegateHandle);
			}
		}
	}
}


void FContentMenuExtender::RegisterMenus()
{
	ExtendContentPathMenu();

	ExtendContentAssetMenu();

	ExtendToobarMenu();

}

/// ////////////////////////////////////////////////Contend Asset Selection Extendion ///////////////////////////////////////////////////////
void FContentMenuExtender::ExtendContentAssetMenu()
{
	if (UToolMenu* Menu = UToolMenus::Get()->ExtendMenu("ContentBrowser.AssetContextMenu"))
	{
		FToolMenuSection& Section = Menu->FindOrAddSection("C7Operation");
	}

	// Register content browser hook
	FContentBrowserModule& ContentBrowserModule = FModuleManager::LoadModuleChecked<FContentBrowserModule>(TEXT("ContentBrowser"));
	TArray<FContentBrowserMenuExtender_SelectedAssets>& CBAssetMenuExtenderDelegates = ContentBrowserModule.GetAllAssetViewContextMenuExtenders();

	CBAssetMenuExtenderDelegates.Add(FContentBrowserMenuExtender_SelectedAssets::CreateRaw(this, &FContentMenuExtender::OnExtendContentBrowserAssetSelectionMenu));
	ContentBrowserAssetExtenderDelegateHandle = CBAssetMenuExtenderDelegates.Last().GetHandle();

	{
		UToolMenu* Menu = UToolMenus::Get()->ExtendMenu("ContentBrowser.AssetContextMenu.AssetActionsSubMenu");
		FToolMenuSection& Section = Menu->FindOrAddSection("AssetContextAdvancedActions");
		Section.AddMenuEntry(
			"SplitTexture",
			LOCTEXT("SplitTextureTitle", "Split Texture"),
			LOCTEXT("SplitTextureTooltipText", "Split Texture."),
			FSlateIcon(),
			FToolMenuExecuteAction::CreateLambda([this](const FToolMenuContext& InContext)
				{
					if (UContentBrowserAssetContextMenuContext* Context = InContext.FindContext<UContentBrowserAssetContextMenuContext>())
					{
						for (int32 i = 0; i < Context->SelectedAssets.Num(); ++i)
						{
							if(UTexture* Texture = Cast<UTexture>(Context->SelectedAssets[i].GetAsset()))
							{
								FToolsLibrary::SplitTexture(Texture);
							}
						}
					}
				})
		);
	}
}

void FContentMenuExtender::UnExtendContentAssetMenu()
{
	FContentBrowserModule* ContentBrowserModule = FModuleManager::GetModulePtr<FContentBrowserModule>(TEXT("ContentBrowser"));
	if (ContentBrowserModule)
	{
		TArray<FContentBrowserMenuExtender_SelectedAssets>& CBMenuExtenderDelegates = ContentBrowserModule->GetAllAssetViewContextMenuExtenders();
		CBMenuExtenderDelegates.RemoveAll([this](const FContentBrowserMenuExtender_SelectedAssets& Delegate) { return Delegate.GetHandle() == ContentBrowserAssetExtenderDelegateHandle; });
	}

	// remove menu extension
	UToolMenus::UnregisterOwner(this);

}


TSharedRef<FExtender> FContentMenuExtender::OnExtendContentBrowserAssetSelectionMenu(const TArray<FAssetData>& SelectedAssets)
{
	TSharedRef<FExtender> Extender(new FExtender());

	//Extender->AddMenuExtension(
	//	"AssetContextAdvancedActions",
	//	EExtensionHook::After,
	//	nullptr,
	//	FMenuExtensionDelegate::CreateRaw(this, &FDataValidationModule::CreateDataValidationContentBrowserAssetMenu, SelectedAssets));

	return Extender;

}

void FContentMenuExtender::CreateC7ContentBrowserAssetMenu(FMenuBuilder& MenuBuilder, TArray<FAssetData> SelectedAssets)
{

}

/// ////////////////////////////////////////////////Content Folder Selection Extendion ///////////////////////////////////////////////////////
void FContentMenuExtender::ExtendContentPathMenu()
{
	if (UToolMenu* Menu = UToolMenus::Get()->ExtendMenu("ContentBrowser.FolderContextMenu"))
	{
		FToolMenuSection& Section = Menu->FindOrAddSection("C7Operation");
	}

	// Register content browser hook
	FContentBrowserModule& ContentBrowserModule = FModuleManager::LoadModuleChecked<FContentBrowserModule>(TEXT("ContentBrowser"));


	TArray<FContentBrowserMenuExtender_SelectedPaths>& CBFolderMenuExtenderDelegates = ContentBrowserModule.GetAllPathViewContextMenuExtenders();

	CBFolderMenuExtenderDelegates.Add(FContentBrowserMenuExtender_SelectedPaths::CreateRaw(this, &FContentMenuExtender::OnExtendContentBrowserPathSelectionMenu));
	ContentBrowserPathExtenderDelegateHandle = CBFolderMenuExtenderDelegates.Last().GetHandle();
}
void FContentMenuExtender::UnExtendContentPathMenu()
{
	FContentBrowserModule* ContentBrowserModule = FModuleManager::GetModulePtr<FContentBrowserModule>(TEXT("ContentBrowser"));
	if (ContentBrowserModule)
	{
		TArray<FContentBrowserMenuExtender_SelectedPaths>& CBMenuExtenderDelegates = ContentBrowserModule->GetAllPathViewContextMenuExtenders();
		CBMenuExtenderDelegates.RemoveAll([this](const FContentBrowserMenuExtender_SelectedPaths& Delegate) { return Delegate.GetHandle() == ContentBrowserPathExtenderDelegateHandle; });
	}

	// remove menu extension
	UToolMenus::UnregisterOwner(this);
}





TSharedRef<FExtender> FContentMenuExtender::OnExtendContentBrowserPathSelectionMenu(const TArray<FString>& SelectedPaths)
{
	TSharedRef<FExtender> Extender(new FExtender());

	Extender->AddMenuExtension(
		"C7Operation",
		EExtensionHook::After,
		nullptr,
		FMenuExtensionDelegate::CreateRaw(this, &FContentMenuExtender::CreateC7ContentBrowserPathMenu, SelectedPaths));

	return Extender;

}




void FContentMenuExtender::CreateC7ContentBrowserPathMenu(FMenuBuilder& MenuBuilder, TArray<FString> SelectedPaths)
{
	if (SelectedPaths.Num() == 1 && SelectedPaths[0].ToUpper().Contains(TEXT("ARTTEST")) || 1)
	{
		MenuBuilder.AddMenuEntry
		(
			LOCTEXT("FixArtTestAssetsReferenceTabTitle", "Fix ArtTest Assets Reference"),
			LOCTEXT("FixArtTestAssetsReferenceTooltipText", "Fix ArtTest Assets Reference"),
			FSlateIcon(),
			FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::FixArtTestAssetsReference, SelectedPaths))
		);
	}


	MenuBuilder.AddMenuEntry
	(
		LOCTEXT("CleanCustomizePkgHead", "Clean Customize Pkg Head"),
		LOCTEXT("CleanCustomizePkgHeadTooltipText", "Clean Customize Pkg Head"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::CleanCustomizePkgHead, SelectedPaths))
	);

}


/// ////////////////////////////////////////////////Level Editor Toolbar Extendion ///////////////////////////////////////////////////////
void FContentMenuExtender::ExtendToobarMenu()
{
	FLevelEditorToolbarExtender::GetInstance();
	
	//UToolMenu* LevelEditorToolbar = UToolMenus::Get()->ExtendMenu("LevelEditor.LevelEditorToolBar");
	UToolMenu* LevelEditorToolbar = UToolMenus::Get()->ExtendMenu("LevelEditor.LevelEditorToolBar.User");
	FToolMenuSection& RootSection = LevelEditorToolbar->AddSection("C7Tools");
	RootSection.AddEntry(FToolMenuEntry::InitComboButton(
		"C7Tools",
		FUIAction(),
		FOnGetContent::CreateRaw(this, &FContentMenuExtender::GenerateGameToolsMenu),
		LOCTEXT("Tools", "Tools"),
		LOCTEXT("Tools", "Tools"),
		FSlateIcon(FKGEditorStyle::GetStyleSetName(), TEXT("C7Editor.C7"))
	));
	
	UToolMenu* C7Toolbar = UToolMenus::Get()->ExtendMenu("LevelEditor.LevelEditorToolBar.C7Tools");
	FToolMenuSection& ExportSection = C7Toolbar->AddSection("ExportTools");

	ExportSection.AddMenuEntry(
		"Export Navigation",
		LOCTEXT("Export Navigation", "Export Navigation"),
		LOCTEXT("Export Navigation", "Export Navigation"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ExportNavigation), FCanExecuteAction())
		);
	
	ExportSection.AddMenuEntry(
		"Load All Region",
		LOCTEXT("Load All Region", "Load All Region"),
		LOCTEXT("Load All Region", "Load All Region"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::LoadAllRegion), FCanExecuteAction())
	);
	
	ExportSection.AddMenuEntry(
		"DumpNavMesh",
		LOCTEXT("DumpNavMesh", "DumpNavMesh"),
		LOCTEXT("DumpNavMesh", "DumpNavMesh"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::DumpNavMesh), FCanExecuteAction())
		);

		
	ExportSection.AddMenuEntry(
		"DeleteNavDataActor",
		LOCTEXT("DeleteNavDataActor", "DeleteNavDataActor"),
		LOCTEXT("DeleteNavDataActor", "DeleteNavDataActor"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::DeleteNavDataActor), FCanExecuteAction())
		);

	ExportSection.AddMenuEntry(
		"ExportGamePlaySceneActorData",
		LOCTEXT("ExportGamePlaySceneActorData", "ExportGamePlaySceneActorData"),
		LOCTEXT("ExportGamePlaySceneActorData", "ExportGamePlaySceneActorData"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&GPEditorAssetHelper::ExportSceneActorDataNew), FCanExecuteAction())
	);

	/*
	ExportSection.AddMenuEntry(
	"Export Level Gameplay Data",
	LOCTEXT("Export Level Gameplay Data", "Export Level Gameplay Data"),
	LOCTEXT("Export Level Gameplay Data", "Export Level Gameplay Data"),
	FSlateIcon(),
	FUIAction(FExecuteAction::CreateStatic(&FExportLevelGameplayData::ButtonExportLevelGameplayData), FCanExecuteAction()));

	ExportSection.AddMenuEntry(
	"Export Logic Actor Mapping Data",
	LOCTEXT("Export Logic Actor Mapping Data", "Export Logic Actor Mapping Data"),
	LOCTEXT("Export Logic Actor Mapping Data", "Export Logic Actor Mapping Data"),
	FSlateIcon(),
	FUIAction(FExecuteAction::CreateStatic(&ULevelEditorLuaObj::ExportLogicActorMappingData), FCanExecuteAction()));

	ExportSection.AddMenuEntry(
	"LF_DeserializeLevelFlow",
	LOCTEXT("LF_DeserializeLevelFlow", "LF_DeserializeLevelFlow"),
	LOCTEXT("LF_DeserializeLevelFlow", "LF_DeserializeLevelFlow"),
	FSlateIcon(),
	FUIAction(FExecuteAction::CreateStatic(&FLevelFlowSerializeHelper::ButtonDeserializeLevelFlow), FCanExecuteAction()));
	*/
	
	FToolMenuSection& VoxelSection = C7Toolbar->AddSection("Voxel Section");

	VoxelSection.AddMenuEntry(
		"Voxel Operation - Export Voxel",
		LOCTEXT("Export Voxel", "Export Voxel"),
		LOCTEXT("Export Voxel", "Export Voxel"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ExportVoxData), FCanExecuteAction())
	);

	VoxelSection.AddMenuEntry(
		"Voxel Operation - Export Voxel Tiled",
		LOCTEXT("Export Voxel Tiled", "Export Voxel Tiled"),
		LOCTEXT("Export Voxel Tiled", "Export Voxel Tiled"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ExportVoxDataTiled), FCanExecuteAction())
	);

	VoxelSection.AddMenuEntry(
		"Voxel Operation - Show Runtime Vox From Server",
		LOCTEXT("Show Runtime Vox From Server", "Show Runtime Vox From Server"),
		LOCTEXT("Show Runtime Vox From Server", "Show Runtime Vox From Server"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ShowRuntimeVoxFromServer), FCanExecuteAction())
	);

	VoxelSection.AddMenuEntry(
		"Voxel Operation - Show Runtime Vox From Local",
		LOCTEXT("Show Runtime Vox From Local", "Show Runtime Vox From Local"),
		LOCTEXT("Show Runtime Vox From Local", "Show Runtime Vox From Local"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ShowRuntimeVoxFromLocal), FCanExecuteAction())
	);

	VoxelSection.AddMenuEntry(
		"Voxel Operation - Clear Vox Preview Mesh",
		LOCTEXT("Clear Vox Preview Mesh", "Clear Vox Preview Mesh"),
		LOCTEXT("Clear Vox Preview Mesh", "Clear Vox Preview Mesh"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ClearVoxPreviewMesh), FCanExecuteAction())
	);
	
	VoxelSection.AddMenuEntry(
		"Voxel Operation - Import Voxel",
		LOCTEXT("Import Voxel", "Import Voxel"),
		LOCTEXT("Import Voxel", "Import Voxel"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ImportVoxData), FCanExecuteAction())
	);

	VoxelSection.AddMenuEntry(
		"Voxel Operation - Show Voxel Preview mesh",
		LOCTEXT("Show Voxel Preview mesh", "Show Voxel Preview mesh"),
		LOCTEXT("Show Voxel Preview mesh", "Show Voxel Preview mesh"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ShowVoxelPreviewMesh), FCanExecuteAction())
	);

	VoxelSection.AddMenuEntry(
		"Voxel Operation - Export Test Vox",
		LOCTEXT("Export Test Vox", "ExportTestVox"),
		LOCTEXT("Export Test Vox", "ExportTestVox"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ExportTestVoxData), FCanExecuteAction())
	);

#pragma region BuildingContext
	VoxelSection.AddMenuEntry(
		"Recast - Export Navmesh",
		LOCTEXT("Recast - Export Navmesh", "Recast - Export Navmesh"),
		LOCTEXT("Recast - Export Navmesh", "Recast - Export Navmesh"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ExportNavmesh), FCanExecuteAction())
	);

	VoxelSection.AddMenuEntry(
		"Recast - Export Voxel",
		LOCTEXT("Recast - Export Voxel", "Recast - Export Voxel"),
		LOCTEXT("Recast - Export Voxel", "Recast - Export Voxel"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ExportVoxel), FCanExecuteAction())
	);

	VoxelSection.AddMenuEntry(
		"Recast - Enable Voxel Display",
		LOCTEXT("Recast - Enable Voxel Display", "Recast - Enable Voxel Display"),
		LOCTEXT("Recast - Enable Voxel Display", "Recast - Enable Voxel Display"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::EnableVoxelDisplay), FCanExecuteAction())
	);

	VoxelSection.AddMenuEntry(
		"Recast - Disable Voxel Display",
		LOCTEXT("Recast - Disable Voxel Display", "Recast - Disable Voxel Display"),
		LOCTEXT("Recast - Disable Voxel Display", "Recast - Disable Voxel Display"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::DisableVoxelDisplay), FCanExecuteAction())
	);
#pragma endregion

	FToolMenuSection& ProfileSection = C7Toolbar->AddSection("ProfileTools");

	ProfileSection.AddMenuEntry(
		"Show Performance",
		LOCTEXT("Show Performance", "Show Performance"),
		LOCTEXT("Show Performance", "Show Performance"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ShowPerformance), FCanExecuteAction())
	);

	FToolMenuSection& NavTestSection = C7Toolbar->AddSection("Nav Test Section");

	NavTestSection.AddMenuEntry(
		"Test Navigation And Voxel",
		LOCTEXT("Test Nav", "Test Nav"),
		LOCTEXT("Test Nav", "Test Nav"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::TestNavAndVoxel), FCanExecuteAction())
	);

	FToolMenuSection& HoudiniSection = C7Toolbar->AddSection("HoudiniSection");

	HoudiniSection.AddMenuEntry(
		"Setup HoudiniEnv",
		LOCTEXT("Setup HoudiniEnv", "Setup HoudiniEnv"),
		LOCTEXT("Setup HoudiniEnv", "Setup HoudiniEnv"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::SetupHoudiniEnv), FCanExecuteAction())
	);



	


	FToolMenuSection& CopyTools = C7Toolbar->AddSection("CopyTools");

	FToolMenuSection& PrecomputedVisibilityVolumeExport = C7Toolbar->AddSection("PrecomputedVisibilityVolume Export");

	PrecomputedVisibilityVolumeExport.AddMenuEntry(
		"PrecomputedVisibilityVolume Export",
		LOCTEXT("PrecomputedVisibilityVolume Export", "PrecomputedVisibilityVolume Export"),
		LOCTEXT("PrecomputedVisibilityVolume Export", "PrecomputedVisibilityVolume Export"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::PrecomputedVisibilityVolumeExport), FCanExecuteAction())
	);





	FToolMenuSection& BSSection = C7Toolbar->AddSection("BattleSystem Section");

	BSSection.AddMenuEntry(
		"BS Operation",
		LOCTEXT("Export BSEnum", "Export BSEnum"),
		LOCTEXT("Export BSEnum", "Export BSEnum"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ExportBSEnum), FCanExecuteAction())
	);

	FToolMenuSection& VMSection = C7Toolbar->AddSection("MVVM Section");

	VMSection.AddMenuEntry(
		"VM Operation",
		LOCTEXT("Export VM Blueprint", "Export VM Blueprint"),
		LOCTEXT("Export VM Blueprint", "Export VM Blueprint"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ExportVMBlueprint), FCanExecuteAction())
	);

	VMSection.AddMenuEntry(
		"VM Operation",
		LOCTEXT("Export VM Widget Utils", "Export VM Widget Utils"),
		LOCTEXT("Export VM Widget Utils", "Export VM Widget Utils"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ExportVMWidgetUtils), FCanExecuteAction())
	);

	FToolMenuSection& KAutoSection = C7Toolbar->AddSection("KAuto Section");

	KAutoSection.AddMenuEntry(
		"Replace Material",
		LOCTEXT("Replace Material", "Replace Material"),
		LOCTEXT("Replace Material", "Replace Material"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ReplaceAllMaterial), FCanExecuteAction())
	);

	KAutoSection.AddMenuEntry(
		"Compile All Assets",
		LOCTEXT("Compile All Assets", "Compile All Assets"),
		LOCTEXT("Compile All Assets", "Compile All Assets"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::CompileAllAssets), FCanExecuteAction())
	);

	KAutoSection.AddMenuEntry(
		"KAuto Operation",
		LOCTEXT("Split Collision Spline Mesh", "Split Collision Spline Mesh"),
		LOCTEXT("Split Collision Spline Mesh", "Split Collision Spline Mesh"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::SplitSplineMeshComponent), FCanExecuteAction())
	);

	FToolMenuSection& SceneInspectionSection = C7Toolbar->AddSection("Scene Inspection Section");
	
	SceneInspectionSection.AddMenuEntry(
			"Export Navmesh Sample Data",
			LOCTEXT("Export Navmesh Sample Data", "Export Navmesh Sample Data"),
			LOCTEXT("Export Navmesh Sample Data", "Export Navmesh Sample Data"),
			FSlateIcon(),
			FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ExportNavmeshSampleData), FCanExecuteAction())
		);
	
	SceneInspectionSection.AddMenuEntry(
		"Scene Inspection Operation",
		LOCTEXT("Scene Inspection", "Scene Inspection"),
		LOCTEXT("Scene Inspection", "Scene Inspection"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::StartSceneInspection), FCanExecuteAction())
	);

	SceneInspectionSection.AddMenuEntry(
		"Copy Spline",
		LOCTEXT("Copy Spline", "Copy Spline"),
		LOCTEXT("Copy Spline", "Copy Spline"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::CopySpline), FCanExecuteAction())
	);
	
	SceneInspectionSection.AddMenuEntry(
		"Execute All Texture",
		LOCTEXT("Execute All Texture", "Execute All Texture"),
		LOCTEXT("Execute All Texture", "Execute All Texture"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ExecuteAllTexture, false, true), FCanExecuteAction())
	);

	FString DefaultExecutePath = "/Game/Arts";
	SceneInspectionSection.AddMenuEntry(
		"Execute All StaticMeshLOD",
		LOCTEXT("Execute All StaticMeshLOD", "Execute All StaticMeshLOD"),
		LOCTEXT("Execute All StaticMeshLOD", "Execute All StaticMeshLOD"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::ExecuteAllStaticMeshLODAdapter, DefaultExecutePath, false), FCanExecuteAction())
	);
	
	SceneInspectionSection.AddMenuEntry(
		"Fix All Static Mesh LOD Screen Size",
		LOCTEXT("Fix All Static Mesh LOD Screen Size", "Fix All Static Mesh LOD Screen Size"),
		LOCTEXT("Fix All Static Mesh LOD Screen Size", "Fix All Static Mesh LOD Screen Size"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::FixAllStaticMeshLODScreenSize, false), FCanExecuteAction())
	);

	SceneInspectionSection.AddMenuEntry(
		"BatchReplaceCollisionProfile_SceneStatic",
		LOCTEXT("BatchReplaceCollisionProfile_SceneStatic", "BatchReplaceCollisionProfile_SceneStatic"),
		LOCTEXT("BatchReplaceCollisionProfile_SceneStatic", "BatchReplaceCollisionProfile_SceneStatic"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FKGSceneTools::BatchReplaceCollisionProfile_SceneStatic), FCanExecuteAction())
	);

	SceneInspectionSection.AddMenuEntry(
		"BatchMigrateSceneData",
		LOCTEXT("BatchMigrateSceneData", "BatchMigrateSceneData"),
		LOCTEXT("BatchMigrateSceneData", "BatchMigrateSceneData"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FKGSceneTools::BatchMigrateSceneData), FCanExecuteAction())
	);

	SceneInspectionSection.AddMenuEntry(
		"BatchMigrateDataLayer",
		LOCTEXT("BatchMigrateDataLayer", "BatchMigrateDataLayer"),
		LOCTEXT("BatchMigrateDataLayer", "BatchMigrateDataLayer"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FKGSceneTools::BatchMigrateDataLayer), FCanExecuteAction())
	);

#pragma region BatchAudioActorProcess

	SceneInspectionSection.AddMenuEntry(
		"BatchAudioActorProcessInCurrentLevel",
		LOCTEXT("BatchAudioActorProcessInCurrentLevel", "音频Actor批处理__只处理当前打开的关卡"),
		LOCTEXT("BatchAudioActorProcessInCurrentLevel", "音频Actor批处理__只处理当前打开的关卡"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&KGAudioUtils::BatchAudioActorProcess_InCurrentLevel), FCanExecuteAction())
	);
	
	SceneInspectionSection.AddMenuEntry(
		"BatchAudioActorProcessInAllSoundLevel",
		LOCTEXT("BatchAudioActorProcessInAllSoundLevel", "音频Actor批处理__处理所有_Sound子关卡"),
		LOCTEXT("BatchAudioActorProcessInAllSoundLevel", "音频Actor批处理__处理所有_Sound子关卡"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&KGAudioUtils::BatchAudioActorProcess_InAllSoundLevel), FCanExecuteAction())
	);
	
#pragma endregion BatchAudioActorProcess

	// Play Button
	FToolMenuSection& GameSection = LevelEditorToolbar->FindOrAddSection("Game");


	

	FToolMenuEntry& GameLoopEntry = GameSection.AddEntry(FToolMenuEntry::InitToolBarButton(
		FContentMenuCommands::Get().GameLoopCommands,
		LOCTEXT("GameLoop", "GameLoop"),
		LOCTEXT("GameLoop", "GameLoop"),
		FSlateIcon(FKGEditorStyle::GetStyleSetName(), TEXT("C7Editor.GameLoop")) // @todo change icon
	));

	GameLoopEntry.SetCommandList(CommandList);
	
	GameLoopEntry.InsertPosition.Position = EToolMenuInsertType::First;

	UToolMenu* ToolbarMenu = UToolMenus::Get()->ExtendMenu("LevelEditor.LevelEditorToolBar.PlayToolBar");
	{
		FToolMenuSection& Section = ToolbarMenu->FindOrAddSection("LevelPreviewSection");
		{
			FToolMenuEntry& PreviewEntry = Section.AddEntry(FToolMenuEntry::InitToolBarButton(
				"LevelPreview",
				FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::StartPIEFromPreview), FCanExecuteAction()),
				LOCTEXT("LevelPreview", "LevelPreview"),
				LOCTEXT("LevelPreview", "LevelPreview"),
				FSlateIcon(FKGEditorStyle::GetStyleSetName(), TEXT("C7Editor.LevelPreview"))
			));

			//PreviewEntry.InsertPosition.Position = EToolMenuInsertType::After;
		}
		
		FToolMenuSection& UISection = ToolbarMenu->FindOrAddSection("KGUISection");
		{
			// PC是否走Scale（0.85）
			FToolMenuEntry& pcScaleEntry = UISection.AddEntry(FToolMenuEntry::InitToolBarButton(
				"bPCScale",
				FUIAction(  
					FExecuteAction::CreateStatic(&FToolsLibrary::TogglePCScale),
					FCanExecuteAction(),
					FIsActionChecked::CreateStatic(&FToolsLibrary::IsPCScaleEnable)
				),  
				LOCTEXT("bPCScale", "PC缩放"),
				LOCTEXT("bPCScale", "是否开启PC缩放"),
				FSlateIcon(FKGEditorStyle::GetStyleSetName(), TEXT("C7Editor.bPCScale")),
				EUserInterfaceActionType::ToggleButton
			));
			UISection.AddEntry(pcScaleEntry);
			// 刘海屏的图片显式
			FToolMenuEntry& safeAreaEntry = UISection.AddEntry(FToolMenuEntry::InitToolBarButton(
				"bUseSafeArea",
				FUIAction(  
					FExecuteAction::CreateStatic(&FToolsLibrary::ToggleSafeAreaVisible),
					FCanExecuteAction(),
					FIsActionChecked::CreateStatic(&FToolsLibrary::IsSafeAreaVisible)
				),  
				LOCTEXT("bUseSafeArea", "刘海屏"),
				LOCTEXT("bUseSafeAreaTips", "显式刘海屏到UMG最上层"),
				FSlateIcon(FKGEditorStyle::GetStyleSetName(), TEXT("C7Editor.bUseSafeArea")),
				EUserInterfaceActionType::ToggleButton
			));
			UISection.AddEntry(safeAreaEntry);
			// 显式下拉菜单，多个分辨率（在Settings中配置）可选
			FToolMenuEntry resolutionComboButtonEntry = FToolMenuEntry::InitComboButton(
					"ResolutionComboButton",
					FUIAction(),	// 留空，逻辑在下拉选项
					FOnGetContent::CreateRaw(this, &FContentMenuExtender::GenerateResolutionMenu),
					LOCTEXT("ResolutionComboButton", "（请选择）"),
					LOCTEXT("ResolutionComboButtonTips", "预览分辨率选择"),
					FSlateIcon(FAppStyle::GetAppStyleSetName(), "Icons.Settings"),
					true
				);
			UISection.AddEntry(resolutionComboButtonEntry);
		}
	}

	FToolMenuSection& MapShoot = C7Toolbar->AddSection("MapShootTools");
	
	MapShoot.AddMenuEntry(
		"Capture Map Screen Shoot As MapShoot",
		LOCTEXT("Capture Map Screen Shoot As MapShoot", "Capture Map Screen Shoot As MapShoot"),
		LOCTEXT("Capture Map Screen Shoot As MapShoot", "Capture Map Screen Shoot As MapShoot"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::CaptureMapShoot), FCanExecuteAction())
	);

	MapShoot.AddMenuEntry(
		"Get Last Capture MapShoot And Caculate WayPoint",
		LOCTEXT("Get Last Capture MapShoot And Caculate WayPoint", "Get Last Capture MapShoot And Caculate WayPoint"),
		LOCTEXT("Get Last Capture MapShoot And Caculate WayPoint", "Get Last Capture MapShoot And Caculate WayPoint"),
		FSlateIcon(),
		FUIAction(FExecuteAction::CreateStatic(&FToolsLibrary::GetLastCaptureMapShootAndCaculateWayPoint), FCanExecuteAction())
	);
	

}
void FContentMenuExtender::UnExtendToobarMenu()
{

}
struct FCallbackRecursiveWatcher 
{
	int* ValuePtr;
	FCallbackRecursiveWatcher(int* ptr)
	{
		ValuePtr = ptr;
		(*ValuePtr)++;
	}
	~FCallbackRecursiveWatcher()
	{
		(*ValuePtr)--;
	}
};
bool IsNearlyEqual(const FIntPoint& A, const FIntPoint& B)
{
	if (FMath::Abs(A.X - B.X) > 1)
	{
		return false;
	}
	if (FMath::Abs(A.Y - B.Y) > 1)
	{
		return false;
	}
	return true;
}

void FContentMenuExtender::RefreshViewportResolution()
{
	// 如果引擎退出，则不用处理了
	if (IsEngineExitRequested())
	{
		return;
	}
	
	UKGUISettings* mutableUISettings = GetMutableDefault<UKGUISettings>();
	if (mutableUISettings->bEnableUIEditorPreview == false)
	{
		return;
	}
	if (mutableUISettings->CurrentResolutionIndex < 0 || mutableUISettings->CurrentResolutionIndex >= mutableUISettings->ResolutionList.Num())
	{
		return;
	}

	// 确保不循环回调
	static int CallbackDepth = 0;
	if (CallbackDepth > 0)
	{
		return;
	}
	FCallbackRecursiveWatcher Watcher(&CallbackDepth);
	
	const FKGUIResolution& resolution = mutableUISettings->ResolutionList[mutableUISettings->CurrentResolutionIndex];

	// 设置分辨率
	FLevelEditorModule& LevelEditorModule = FModuleManager::GetModuleChecked<FLevelEditorModule>(TEXT("LevelEditor"));
	TSharedPtr<IAssetViewport> ActiveLevelViewport = LevelEditorModule.GetFirstActiveViewport();

	// 强制分辨率尝试
	// SLevelViewport
	// FSceneViewport
	auto SceneViewport = ActiveLevelViewport->GetSharedActiveViewport();
	TSharedPtr<SWidget> Window = ActiveLevelViewport->AsWidget();
	if (SceneViewport.IsValid() && Window.IsValid())
	{
		// 先拿到裸的物理分辨率
		const FGeometry& CachedGeometry = Window->GetCachedGeometry();
		auto PhysicalLocalSizeXY = CachedGeometry.GetDrawSize();
		FIntPoint PhysicalSizeXY;
		PhysicalSizeXY.X = FMath::RoundToInt(PhysicalLocalSizeXY.X);
		PhysicalSizeXY.Y = FMath::RoundToInt(PhysicalLocalSizeXY.Y);

		// 只有发生改变才真得去刷新
		bool changed = false;
		auto PrevSizeXY = SceneViewport->GetSize();

		if (resolution.ResX > 0 && resolution.ResY > 0)
		{
			// 走高度填满逻辑
			double resolutionScale = (double)resolution.ResX / resolution.ResY;
			double desiredX = PhysicalSizeXY.Y * resolutionScale;
			if (desiredX > PhysicalSizeXY.X)
			{
				PhysicalSizeXY.Y = PhysicalSizeXY.X/resolutionScale;
			}
			else
			{
				PhysicalSizeXY.X = desiredX;
			}
			
			if (!SceneViewport->HasFixedSize() || !IsNearlyEqual(PrevSizeXY, PhysicalSizeXY))
			{
				changed = true;
				SceneViewport->SetFixedViewportSize(PhysicalSizeXY.X, PhysicalSizeXY.Y);
			}	
		}
		else
		{
			// 设置回去；执行两次，一次设置Size、一次设置bForceViewportSize
			if (SceneViewport->HasFixedSize() || !IsNearlyEqual(PrevSizeXY, PhysicalSizeXY))
			{
				changed = true;
				SceneViewport->SetFixedViewportSize(PhysicalSizeXY.X, PhysicalSizeXY.Y);
				// 参数是uint32，不能为负数
				SceneViewport->SetFixedViewportSize(0, 0);
			}
		}

		// 更新预览窗口
		if (changed)
		{
			auto GameViewportSubsystem = UGameViewportSubsystem::Get(GWorld->GetWorld());
			for (auto KeyValuePair : GameViewportSubsystem->GetViewportWidgets())
			{
				// 挨个都设置下得了
				UUIRoot* uiRoot = Cast<UUIRoot>(KeyValuePair.Key.ResolveObjectPtr());
				if (uiRoot != nullptr)
				{
					uiRoot->UpdateViewport(SceneViewport.Get());
				}
			}
		}
	}
}
void FContentMenuExtender::OnViewportResized(FViewport*, uint32)
{
	RefreshViewportResolution();
}
void FContentMenuExtender::OnResolutionChosen(int idx)
{
	UKGUISettings* mutableUISettings = GetMutableDefault<UKGUISettings>();
	if (mutableUISettings->CurrentResolutionIndex != idx)
	{
		if (idx < 0 || idx >= mutableUISettings->ResolutionList.Num())
		{
			UE_LOG(LogTemp, Error, TEXT("Invalid resolution index: %d, max: %d"), idx, mutableUISettings->ResolutionList.Num());
			return;
		}
		mutableUISettings->CurrentResolutionIndex = idx;
		mutableUISettings->PostEditChange();
		mutableUISettings->SaveConfig();
		
		RefreshViewportResolution();

		// 粗暴刷新下下拉菜单（一点不好用这傻逼控件）
		UToolMenu* Menu = UToolMenus::Get()->FindMenu("LevelEditor.LevelEditorToolBar.PlayToolBar");
		if (Menu)
		{
			FToolMenuSection* section = Menu->FindSection("KGUISection");
			if (section == nullptr)
			{
				return;
			}
			FToolMenuEntry* foundEntry = section->FindEntry("ResolutionComboButton");
			if (foundEntry == nullptr)
			{
				return;
			}
			
			const FKGUIResolution& resolution = mutableUISettings->ResolutionList[mutableUISettings->CurrentResolutionIndex];
			foundEntry->Label = FText::FromString(resolution.Name);

			UToolMenus::Get()->RefreshAllWidgets();
		}
	}
}
TSharedRef<SWidget> FContentMenuExtender::GenerateResolutionMenu()
{
	FMenuBuilder menuBuilder(true, nullptr);
	// 属性读取
	const UKGUISettings *Settings = GetDefault<UKGUISettings>();
	if (!Settings)
	{
		return menuBuilder.MakeWidget();
	}

	// 添加选项
	for (int i = 0;i < Settings->ResolutionList.Num();i ++)	
	{
		const FKGUIResolution& Item = Settings->ResolutionList[i];
		FString name = Item.Name;
		if (i == Settings->CurrentResolutionIndex)
		{
			name = FString::Printf(TEXT("√%s"), *name);
		}
		else
		{
			name = FString::Printf(TEXT(" %s"), *name);
		}
		menuBuilder.AddMenuEntry(
			FText::FromString(name),
			LOCTEXT("ResolutionMenuTips", "选择用于预览的分辨率"),
			FSlateIcon(),
			FUIAction(
				FExecuteAction::CreateStatic(&FContentMenuExtender::OnResolutionChosen, i)
			)
		);
	}
	return menuBuilder.MakeWidget();
}

TSharedRef<SWidget> FContentMenuExtender::GenerateGameToolsMenu()
{
	TSharedPtr<FUICommandList> InCommandList = nullptr;
	TSharedPtr<FExtender> MenuExtender = nullptr;

	FToolMenuContext MenuContext(InCommandList, MenuExtender);
	return UToolMenus::Get()->GenerateWidget("LevelEditor.LevelEditorToolBar.C7Tools", MenuContext);

}


void FContentMenuExtender::BindCommands()
{
	FContentMenuCommands::Register();
	const auto& Commands = FContentMenuCommands::Get();
	
	FLevelEditorModule& LevelEditorModule = FModuleManager::LoadModuleChecked<FLevelEditorModule>("LevelEditor");
	CommandList = LevelEditorModule.GetGlobalLevelEditorActions();
	CommandList->MapAction(Commands.GameLoopCommands, FExecuteAction::CreateStatic(&FToolsLibrary::StartPIEFromLogin));
}


#undef LOCTEXT_NAMESPACE
