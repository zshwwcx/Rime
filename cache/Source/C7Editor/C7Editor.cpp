#include "C7Editor.h"
#include "Modules/ModuleManager.h"

#include "IAssetTools.h"
#include "AssetToolsModule.h"
#include "IAssetTypeActions.h"
#include "AssetTypeCategories.h"

//#include "UnLua/Public/UnLuaBase.h"
#include "LevelEditor.h"

#include "LevelFlow/LevelFlowTypes.h"
#include "LevelFlowEditor/SceneActorPickerCustomLayout.h"

#include "LevelFlowEditor/LevelFlowGraphPanelNodeFactory.h"
#include "OptionGraphNodeFactory.h"

#include "EditorModeRegistry.h"
#include "LevelFlowEditor/LevelFlowMode.h"
#include "EdGraphUtilities.h"
#include "AssetRegistry/AssetRegistryModule.h"

#include "C7EditorSettings.h"
#include "PropertyCustomLayout/BitmarkTarrayLayout.h"

#include "DialogueEditorAssetTypeActions.h"

#include "LevelEditor/LevelEditorView/LevelEditorViewExtend.h"
#include "3C/Animation/AnimationGraphNode/CustomAnimNodeDefine.h"
#include "PropertyCustomLayout/AnimPropertyCustomLayout.h"
#include "EditorExtenders/ToolsLibrary.h"
#include "EditorExtenders/C7NavmeshExtend.h"

#include "ModelEditor/Asset/ModelAssetActions.h"
#include "DialogueEditor/Graph/EpisodeGraphNodeFactory.h"

#include "SceneActor/C7PCGMergeActor.h"
#include "LevelEditor.h"

#include "ISequencerModule.h"
#include "CutScene/MovieSceneQTETrackEditor.h"
#include "AnimLibEditor/CustomLayout/AnimLibAssetID_CustomLayout.h"
#include "AnimLibEditor/Asset/AnimAssetActions.h"
#include "ModelEditor/CustomLayout/RoleConfigID_CustomLayout.h"
#include "ModelEditor/CustomLayout/SkeletalMeshParamsComponentDetails.h"
#include "AnimLibEditor/Asset/AnimLibAsset.h"
#include "LevelLuaEditorProxyBase.h"
#include "Selection.h"

#include "C7LuaTemplateCreateTool/C7LuaTemplateCreate.h"
#include "LevelEditor/LevelFlowSerializeHelper/LevelFlowSerializeHelper.h"
#include "LevelFlowEditorContainer.h"
#include "EditorExtenders/ActorPlatformSetCustomLayout.h"
#include "GameFramework/ActorPlatformSet.h"
#include "KGSceneEditorModule.h"
#include "MovieSceneCustomTrackEditor.h"
#include "AnimLibEditor/CustomLayout/AnimLibAnimData_CustomLayout.h"
#include "AnimLibEditor/CustomLayout/FAnimLibTagCombinations_CustomLayout.h"
#include "AssetDeduplicate/KGAssetDeduplicate.h"
#include "C7LandscapeEditor/C7LandscapeEdToolsModule.h"
#include "EditorProxy/LevelLuaEditorProxy.h"
#include "EditorTracker/EditorTracker.h"
#include "KGAbilitySystemEditor/Public/KGAbilitySystemEditor/AbilityEditor/Widgets/Custom/BlackBoardSelectorLayout.h"

#include "KGPyUnreal/KGPyUnreal.h"

IMPLEMENT_MODULE(FC7EditorModule, C7Editor)

#define LOCTEXT_NAMESPACE "FC7EditorModule"

#define REG_CUSTOM_PROP_LAYOUT_GENERIC(StructType, CustomLayout) \
PropertyModule.RegisterCustomPropertyTypeLayout(StructType::StaticStruct()->GetFName(), \
	FOnGetPropertyTypeCustomizationInstance::CreateStatic(&CustomLayout::MakeInstance));



FC7EditorModule::FC7EditorModule()
{
	//ContentMenuExtender = new FContentMenuExtender();
}

FC7EditorModule::~FC7EditorModule()
{
	//delete ContentMenuExtender;
}

void FC7EditorModule::StartupModule()
{
	kg_module::IKgModuleMgr::Get()->RegModule<FKgLandscapeEdToolsModule>("KgLandscapeEdTools");
	FKgCoreDelegates::OnKgCoreTest1.BindLambda([](const FString&)
	{
		UE_LOG(LogTemp, Log, TEXT("test Delegate!"));
		return false;
	});
	FKgCoreDelegates::OnKgCoreTest2.AddLambda([](const FString&, int& Out)
	{
		Out = 0;
		UE_LOG(LogTemp, Log, TEXT("test MultiDelegate!"));
	});
	
	PreScanBlueprintAsset();

	//update houdini env
	if (!IsRunningCommandlet())
	{
		FToolsLibrary::SetupHoudiniEnv();
	}

	ContentMenuExtender = MakeShareable(new FContentMenuExtender);

	ContentMenuExtender->Startup();

	// 注册Core的编辑器回调函数
	FLevelLuaEditorProxyBase::GetRoleConfigData.BindStatic(&ULevelEditorLuaObj::ExportRoleConfigDate);
	FLevelLuaEditorProxyBase::StartUnlua.BindRaw(this, &FC7EditorModule::TryStartUnLua);
	FLevelLuaEditorProxyBase::StopUnlua.BindRaw(this, &FC7EditorModule::TryFinishUnLua);
	FLevelLuaEditorProxyBase::GetLuaEnvConflictedEditorNum.BindRaw(this, &FC7EditorModule::GetLuaEnvConflictedEditorNum);
	FLevelLuaEditorProxyBase::CloseUnluaConflictedEditor.BindRaw(this, &FC7EditorModule::TryCloseLuaEnvConflictedEditors);
	FLevelLuaEditorProxyBase::JsonStrToLuaStr.BindStatic(&ULevelEditorLuaObj::ExportJsonStrToLuaStr);
	FLevelLuaEditorProxyBase::GetLevelFlowStringPropValueNew.BindStatic(&ULevelEditorLuaObj::GetLevelFlowStringPropValueFunc);
	FLevelLuaEditorProxyBase::GetLevelFlowArrayPropValueNew.BindStatic(&ULevelEditorLuaObj::GetLevelFlowArrayPropValueFunc);
	FLevelLuaEditorProxyBase::GetLevelFlowMapPropValueNew.BindStatic(&ULevelEditorLuaObj::GetLevelFlowMapPropValueFunc);
	FLevelLuaEditorProxyBase::SerializeLevelFlow.BindStatic(&FLevelFlowSerializeHelper::SerializeLevelFlow);
	FLevelLuaEditorProxyBase::DeserializeLevelFlow.BindStatic(&FLevelFlowSerializeHelper::DeserializeLevelFlow);

	// TODO： 各个类型添加到数组里，然后进行批量注册和反注册
	IAssetTools& AssetToolsModule = FModuleManager::LoadModuleChecked<FAssetToolsModule>("AssetTools").Get();
	EAssetTypeCategories::Type CurrentAssetCategory = EAssetTypeCategories::Type::Gameplay;
	// 注册角色模板资源
	//注册 外观部件库资源
	AssetToolsModule.RegisterAssetTypeActions(MakeShareable(new FAssetTypeActions_UGeneralNPCPartLib(CurrentAssetCategory)));
	AssetToolsModule.RegisterAssetTypeActions(MakeShareable(new FAssetTypeActions_UGeneralNPCSuitLib(CurrentAssetCategory)));
	AssetToolsModule.RegisterAssetTypeActions(MakeShareable(new FAssetTypeActions_AnimLib_NPC(CurrentAssetCategory)));
	
	// Register graph node factory
	LevelFlowGraphNodeFactory = MakeShareable(new FLevelFlowGraphPanelNodeFactory);
	FEdGraphUtilities::RegisterVisualNodeFactory(LevelFlowGraphNodeFactory);

	// Register Dialogue Episode graph node factory
	EpisodeGraphNodeFactory = MakeShareable(new FEpisodeGraphNodeFactory);
	FEdGraphUtilities::RegisterVisualNodeFactory(EpisodeGraphNodeFactory);

	FEdGraphUtilities::RegisterVisualNodeFactory(MakeShareable(new FOptionGraphNodeFactory()));

	// bind map change event in pie
	FWorldDelegates::OnSeamlessTravelStart.AddRaw(this, &FC7EditorModule::OnLevelSwitchStart);
	
	// Custom Layout
	FPropertyEditorModule& PropertyModule = FModuleManager::LoadModuleChecked<FPropertyEditorModule>("PropertyEditor");
	REG_CUSTOM_PROP_LAYOUT_GENERIC(FC7ActorPicker, FC7ActorPickerPropCustomLayout);
	REG_CUSTOM_PROP_LAYOUT_GENERIC(FBitmarkArray, FBitmarkTarrayLayout);
	
	REG_CUSTOM_PROP_LAYOUT_GENERIC(FAnimNodeAssetID, FAnimNodeAssetIDCustomLayout);
	REG_CUSTOM_PROP_LAYOUT_GENERIC(FAnimLibAssetID, FAnimLibAssetIDCustomLayout);
	REG_CUSTOM_PROP_LAYOUT_GENERIC(FAnimLibAnimData, FAnimLibAnimDataCustomLayout);
	REG_CUSTOM_PROP_LAYOUT_GENERIC(FAnimLibTagCombinations, FAnimLibTagCombinationsCustomLayout);
	REG_CUSTOM_PROP_LAYOUT_GENERIC(FRoleConfigID, FRoleConfigID_CustomLayout);
	REG_CUSTOM_PROP_LAYOUT_GENERIC(FBlackBoardDataSelector, FBlackBoardDataSelectorLayout);
	REG_CUSTOM_PROP_LAYOUT_GENERIC(FActorPlatformSet, FActorPlatformSetCustomLayout);
	
	PropertyModule.RegisterCustomClassLayout("SkeletalMeshParamsComponent", FOnGetDetailCustomizationInstance::CreateStatic(&FSkeletalMeshParamsComponentDetails::MakeInstance));

	LevelEditorViewExtend = MakeShared<class FLevelEditorViewExtend>();
	LevelEditorViewExtend->OnStartupModule();

	LevelFlowEditorContainer = MakeShared<class FLevelFlowEditorContainer>();
	LevelFlowEditorContainer->Initialize();

	FKGSceneEditorModule::Get().GamePlayEditorModeHandler->SetFLevelFlowEditorContainer(LevelFlowEditorContainer);

	// Navmesh扩展
	NavmeshExtend = MakeShared<class C7NavmeshExtend>();
	NavmeshExtend->OnStartupModule();

	IC7EditorModuleInterface::StartupModule();

	AddLevelViewportMenuExtender("LevelEditor");


	ISequencerModule& SequencerModule = FModuleManager::LoadModuleChecked<ISequencerModule>("Sequencer");
	MovieSceneQTETrackEditorHandler = SequencerModule.RegisterTrackEditor(FOnCreateTrackEditor::CreateStatic(&FMovieSceneQTETrackEditor::CreateTrackEditor));
	MovieSceneCustomTrackEditorHandler = SequencerModule.RegisterTrackEditor(FOnCreateTrackEditor::CreateStatic(&FMovieSceneCustomTrackEditor::CreateTrackEditor));

	LuaTemplateCreate = MakeShared<class FC7LuaTemplateCreate>();
	LuaTemplateCreate->OnStartupModule();

	FKGAssetDeduplicate::StartupModule();

	EditorTracker = MakeShared<FEditorTracker>();
	EditorTracker->OnStartupModule();

	KGPyUnreal::Initialize();
}

void FC7EditorModule::ShutdownModule()
{
	kg_module::IKgModuleMgr::Get()->UnregModule("KgLandscapeEdTools");

	if (LevelEditorViewExtend)
	{
		LevelEditorViewExtend->OnShutdownModule();
		LevelEditorViewExtend.Reset();
	}

	ContentMenuExtender->Shutdown();
	ContentMenuExtender.Reset();

	IC7EditorModuleInterface::ShutdownModule();

	FModuleManager::Get().OnModulesChanged().Remove(ModuleLoadedDelegateHandle);
	RemoveLevelViewportMenuExtender();

	ISequencerModule& SequencerModule = FModuleManager::LoadModuleChecked<ISequencerModule>("Sequencer");
	SequencerModule.UnRegisterTrackEditor(MovieSceneQTETrackEditorHandler);
	SequencerModule.UnRegisterTrackEditor(MovieSceneCustomTrackEditorHandler);
	
	FPropertyEditorModule& PropertyModule = FModuleManager::LoadModuleChecked<FPropertyEditorModule>("PropertyEditor");
	PropertyModule.UnregisterCustomClassLayout("SkeletalMeshParamsComponent");

	FWorldDelegates::OnSeamlessTravelStart.RemoveAll(this);
	
	//C7EditorStyle::Shutdown();

	//UnregisterTabSpawner();

	//if (FModuleManager::Get().IsModuleLoaded("AssetTools"))
	//{
	//	IAssetTools& AssetTools = FModuleManager::GetModuleChecked<FAssetToolsModule>("AssetTools").Get();
	//	for (TSharedPtr<IAssetTypeActions>& Action : CreatedAssetTypeActions)
	//	{
	//		AssetTools.UnregisterAssetTypeActions(Action.ToSharedRef());
	//	}
	//}
	//CreatedAssetTypeActions.Empty();

	//UnregisterSequenceEditor();

	//RemoveEditorToolbalExtensions();

	//if (LevelFlowGraphNodeFactory.IsValid())
	//{
	//	FEdGraphUtilities::UnregisterVisualNodeFactory(LevelFlowGraphNodeFactory);
	//	LevelFlowGraphNodeFactory.Reset();
	//}

	//if (PlotDialogueGraphNodeFactory.IsValid())
	//{
	//	FEdGraphUtilities::UnregisterVisualNodeFactory(PlotDialogueGraphNodeFactory);
	//	PlotDialogueGraphNodeFactory.Reset();
	//}

	//// Unhook delegates
	//FCoreDelegates::OnPostEngineInit.Remove(OnPostEngineInitHandle);
	//FEditorDelegates::OnNewActorsDropped.Remove(OnNewActorsHandle);

	////游戏调试工具卸载
	//if (GamePlayDebugToolsPtr.IsValid())
	//{
	//	GamePlayDebugToolsPtr->OnShutdownModule();
	//	GamePlayDebugToolsPtr.Reset();
	//}

	//if (BehaviorTreeEditorExtendPtr)
	//{
	//	BehaviorTreeEditorExtendPtr->OnShutdownModule();
	//	BehaviorTreeEditorExtendPtr.Reset();
	//}
	FLevelLuaEditorProxyBase::GetRoleConfigData.Unbind();
	FLevelLuaEditorProxyBase::StartUnlua.Unbind();
	FLevelLuaEditorProxyBase::StopUnlua.Unbind();
	FLevelLuaEditorProxyBase::GetLuaEnvConflictedEditorNum.Unbind();
	FLevelLuaEditorProxyBase::CloseUnluaConflictedEditor.Unbind();
	FLevelLuaEditorProxyBase::JsonStrToLuaStr.Unbind();
	
	FKGAssetDeduplicate::ShutdownModule();

	if (EditorTracker)
	{
		EditorTracker->OnShutdownModule();
		EditorTracker.Reset();
	}
}

void FC7EditorModule::PreScanBlueprintAsset()
{

	const UC7EditorSettings* EditorSettings = GetDefault<UC7EditorSettings>();
	if (EditorSettings->PreScanPaths.Num() > 0)
	{
		FAssetRegistryModule& AssetRegistryModule = FModuleManager::LoadModuleChecked<FAssetRegistryModule>(TEXT("AssetRegistry"));
		IAssetRegistry& AssetRegistry = AssetRegistryModule.Get();
		AssetRegistry.OnFilesLoaded().RemoveAll(this);
		if (!AssetRegistry.IsLoadingAssets())
		{
			FARFilter Filter;
			Filter.ClassPaths.Add(UBlueprint::StaticClass()->GetClassPathName());
			for (const FDirectoryPath& DirectoryPath : EditorSettings->PreScanPaths)
			{
				FString Path = DirectoryPath.Path;
				Path = "/Game/" + Path;
				Filter.PackagePaths.Add(*Path);
			}
			Filter.bRecursivePaths = true;
			TArray< FAssetData > AssetList;
			AssetRegistry.GetAssets(Filter, AssetList);

			for (FAssetData Asset : AssetList)
			{
				Asset.GetAsset();
				//if (UBlueprint* Obj = Cast<UBlueprint>(Asset.GetAsset()))
				//{
				//	UClass* Class = Obj->GeneratedClass;
				//	bool bIsSkeletonClass = FKismetEditorUtilities::IsClassABlueprintSkeleton(Class);
				//}
			}
		}
		else
		{
			AssetRegistry.OnFilesLoaded().AddRaw(this, &FC7EditorModule::PreScanBlueprintAsset);
		}
	}
}


#pragma region SplitBP
void FC7EditorModule::SplitBPToSeperatedActor(const TArray<AActor*> InActors)
{
	for (auto Iter : InActors)
	{
		 if (AC7PCGMergeActor* C7BPSplitActor = Cast<AC7PCGMergeActor>(Iter))
		 {
			 C7BPSplitActor->SplitActorPOIToStaticMesh();
		 }
	}
}

void FC7EditorModule::RestoreSeperatedActorToBP(const TArray<AActor*> InActors)
{
	 for (auto Iter : InActors)
	 {
	 	if (AC7PCGMergeActor* C7BPSplitActor = Cast<AC7PCGMergeActor>(Iter))
	 	{
			C7BPSplitActor->RestoreComponents();
	 	}
	 }
}

void FC7EditorModule::OnLevelSwitchStart(UWorld* InWorld, const FString& LevelName)
{
	if (USelection* Selection = GEditor->GetSelectedActors())
	{
		Selection->DeselectAll();
		Selection->NoteSelectionChanged();
	}
}

void FC7EditorModule::AddLevelViewportMenuExtender(FName ModuleName)
{
	FLevelEditorModule& LevelEditorModule = FModuleManager::Get().LoadModuleChecked<FLevelEditorModule>("LevelEditor");
	auto& MenuExtenders = LevelEditorModule.GetAllLevelViewportContextMenuExtenders();

	MenuExtenders.Add(FLevelEditorModule::FLevelViewportMenuExtender_SelectedActors::CreateRaw(this, &FC7EditorModule::GetLevelViewportContextMenuExtender));
	LevelViewportExtenderHandle = MenuExtenders.Last().GetHandle();
}

void FC7EditorModule::RemoveLevelViewportMenuExtender()
{
	if (LevelViewportExtenderHandle.IsValid())
	{
		FLevelEditorModule* LevelEditorModule = FModuleManager::Get().GetModulePtr<FLevelEditorModule>("LevelEditor");
		if (LevelEditorModule)
		{
			typedef FLevelEditorModule::FLevelViewportMenuExtender_SelectedActors DelegateType;
			LevelEditorModule->GetAllLevelViewportContextMenuExtenders().RemoveAll([=,this](const DelegateType& In) { return In.GetHandle() == LevelViewportExtenderHandle; });
		}
	}
}

TSharedRef<FExtender> FC7EditorModule::GetLevelViewportContextMenuExtender(const TSharedRef<FUICommandList> CommandList, const TArray<AActor*> InActors)
{
	TSharedRef<FExtender> Extender = MakeShareable(new FExtender);

	if (InActors.Num() > 0)
	{
		TArray<UActorComponent*> Components;
		for (AActor* Actor : InActors)
		{
			TInlineComponentArray<UActorComponent*> ActorComponents(Actor);
			for (UActorComponent* ActorComponent : ActorComponents)
			{
				Components.AddUnique(ActorComponent);
			}
		}

		if (Components.Num() > 0)
		{
			FText ActorName = InActors.Num() == 1 ? FText::Format(LOCTEXT("ActorNameSingular", "\"{0}\""), FText::FromString(InActors[0]->GetActorLabel())) : LOCTEXT("ActorNamePlural", "Actors");

			FLevelEditorModule& LevelEditor = FModuleManager::GetModuleChecked<FLevelEditorModule>(TEXT("LevelEditor"));
			TSharedRef<FUICommandList> LevelEditorCommandBindings = LevelEditor.GetGlobalLevelEditorActions();

			Extender->AddMenuExtension("ActorControl", EExtensionHook::After, LevelEditorCommandBindings, FMenuExtensionDelegate::CreateLambda(
				[this, ActorName, InActors](FMenuBuilder& MenuBuilder) {

					MenuBuilder.AddMenuEntry(
						FText::Format(LOCTEXT("SplitBPToSeperatedActorText", "Split BP {0} To Seperated Actor Group"), ActorName),
						LOCTEXT("SplitBPToSeperatedActorTooltip", "Split BP POI To StaticMesh or single actors that can interact."),
						FSlateIcon(),
						FUIAction(FExecuteAction::CreateRaw(this, &FC7EditorModule::SplitBPToSeperatedActor, InActors))
					);
				})
			);

			Extender->AddMenuExtension("ActorControl", EExtensionHook::After, LevelEditorCommandBindings, FMenuExtensionDelegate::CreateLambda(
				[this, ActorName, InActors](FMenuBuilder& MenuBuilder) {

					MenuBuilder.AddMenuEntry(
						FText::Format(LOCTEXT("RestoreSeperatedActorToBP", "Restore Seperated Actors To BP"), ActorName),
						LOCTEXT("RestoreSeperatedActorToBPToolTip", "Restore Seperated Actors To BP."),
						FSlateIcon(),
						FUIAction(FExecuteAction::CreateRaw(this, &FC7EditorModule::RestoreSeperatedActorToBP, InActors))
					);
				})
			);
		}
	}

	return Extender;
}
#pragma endregion SplitBP



#pragma region UnLua
void FC7EditorModule::TryStartUnLua()
{
	/*
	* TODO: 支持升级slua add by sk
	if (UnLuaRefrenceCount == 0)
	{
		UnLua::Startup();
	}

	++UnLuaRefrenceCount;
	*/
}

void FC7EditorModule::TryFinishUnLua()
{
	/*
	* TODO: 支持升级slua add by sk
	--UnLuaRefrenceCount;

	const bool bIsInPIEOrSimulate = GEditor->PlayWorld != NULL || GEditor->bIsSimulatingInEditor;
	if (UnLuaRefrenceCount <= 0 && !bIsInPIEOrSimulate)
	{
		UnLua::Shutdown();
	}
	*/
}

void FC7EditorModule::GetLuaEnvConflictedEditorNum(int& EditingNum, int& UnSavedNum)
{
	EditingNum = 0;
	UnSavedNum = 0;
	TArray<UObject*> AllEditedAssets = GEditor->GetEditorSubsystem<UAssetEditorSubsystem>()->GetAllEditedAssets();
	for (UObject* EditedAsset : AllEditedAssets)
	{
		if (Cast<UAnimLib_AssetNPC>(EditedAsset))
		{
			EditingNum++;
			if (EditedAsset->GetPackage() && EditedAsset->GetPackage()->IsDirty())
			{
				UnSavedNum++;
			}
		}
	} 
}

void FC7EditorModule::TryCloseLuaEnvConflictedEditors()
{
	TArray<UObject*> AllEditedAssets = GEditor->GetEditorSubsystem<UAssetEditorSubsystem>()->GetAllEditedAssets();
	TArray<UObject*> ToEndEditAssets;
	for (UObject* EditedAsset : AllEditedAssets)
	{
		if (Cast<UAnimLib_AssetNPC>(EditedAsset))
		{
			ToEndEditAssets.Add(EditedAsset);
		}
	}
		
	for (UObject* EditedAsset : ToEndEditAssets)
	{
		TArray<IAssetEditorInstance*> AssetEditors = GEditor->GetEditorSubsystem<UAssetEditorSubsystem>()->FindEditorsForAsset(EditedAsset);
		for (IAssetEditorInstance* ExistingEditor : AssetEditors)
		{
			ExistingEditor->CloseWindow(EAssetEditorCloseReason::CloseAllEditorsForAsset);
		}
	}
}

#pragma endregion UnLua

void FC7EditorModule::AddModuleListeners()
{
	
}

#undef LOCTEXT_NAMESPACE
