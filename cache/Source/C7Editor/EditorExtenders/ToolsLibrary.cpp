#include "EditorExtenders/ToolsLibrary.h"
#include "UObject/UObjectGlobals.h"
#include "UObject/ConstructorHelpers.h"
#include "Misc/ScopedSlowTask.h"
#include "AssetRegistry/IAssetRegistry.h"

#include <EngineGlobals.h>
#include <Runtime/Engine/Classes/Engine/Engine.h>
#include <Runtime/Engine/Public/EngineUtils.h>

#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/StructuredArchive.h"
#include "Serialization/Formatters/JsonArchiveOutputFormatter.h"
#include "Serialization/MemoryWriter.h"
#include "Serialization/ArchiveUObjectFromStructuredArchive.h"
#include "Serialization/StructuredArchiveFormatter.h"

#include <EditorViewportClient.h>
#include <LevelEditorViewport.h>
#include <NavMesh/RecastNavMesh.h>
#include <Kismet/KismetSystemLibrary.h>
#include <AI/NavDataGenerator.h>
#include <Widgets/Notifications/SNotificationList.h>
#include "Framework/Notifications/NotificationManager.h"
#include "LevelEditor/ExportNavigation/C7ExportNavDataLibrary.h"
#include <Components/BoxComponent.h>
#include "BattleSystemEditor/BSEditorFunctionLibrary.h"

#include "StaticMeshEditorExtenderManager.h"

#include "BSPOps.h"

#include "DoraSDK.h"

#include "SceneActor/C7VoxelActor.h"
#include "FileHelpers.h"
#include <NavMesh/NavMeshBoundsVolume.h>
#include <Lightmass/PrecomputedVisibilityVolume.h>
#include <Engine/BrushBuilder.h>
#include <Runtime/Engine/Classes/Kismet/GameplayStatics.h>
#include <Builders/CubeBuilder.h>
#include "Components/BrushComponent.h"
#include "Engine/Polys.h"
#include "LevelEditor.h"
#include "IAssetViewport.h"
#include "UnrealEdGlobals.h"
#include "Editor/UnrealEdEngine.h"
#include "GameMapsSettings.h"
#include "C7Editor.h"
#include "Misc/FileHelper.h"
#include "Misc/DefaultValueHelper.h"

#include "HAL/FileManagerGeneric.h"
#include "GameFramework/PlayerStart.h"
#include "Components/CapsuleComponent.h"
#include "../C7EditorSettings.h"
#include "Misc/MessageDialog.h"
#include "RHIDefinitions.h"
#include "WorldPartition/WorldPartitionEditorLoaderAdapter.h"
#include "WorldPartition/DataLayer/DataLayerSubsystem.h"
#include "WorldPartition/LoaderAdapter/LoaderAdapterShape.h"
//#include "Editor/UnrealEd/Public/BSPOps.h"
#include <string>

#include "WorldPartition/WorldPartition.h"
#include "Kismet/KismetSystemLibrary.h"
#include "Detour/DetourNavMesh.h"
#include "WorldPartition/NavigationData/NavigationDataChunkActor.h"
#include "PackageSourceControlHelper.h"
#include <NavMesh/RecastNavMesh.h>

#include "AssetToolsModule.h"
#include "AssetViewUtils.h"
#include "ContentBrowserModule.h"
#include "IContentBrowserSingleton.h"
#include "IMeshMergeUtilities.h"
#include "ISourceControlModule.h"
#include "PackageHelperFunctions.h"
#include "SceneInspection.h"
#include "SceneInspectionActor.h"
#include "SceneInspectionEditor.h"
#include "SourceControlOperations.h"
#include "Components/SplineMeshComponent.h"

#include "Landscape.h"
#include "LandscapeProxy.h"
#include "LandscapeSplinesComponent.h"
#include "LandscapeSplineControlPoint.h"
#include "LandscapeSplineSegment.h"
#include "LandscapeSplineActor.h"
#include "Subsystems/EditorActorSubsystem.h"
#include "Selection.h"

#include "MeshMergeModule.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Engine/SplineMeshActor.h"
#include "Engine/StaticMeshActor.h"
#include "UObject/SavePackage.h"
#include "WorldPartition/WorldPartitionEditorHash.h"
#include "WorldPartition/WorldPartitionRuntimeSpatialHash.h"

#include "RecastApi.h"
#include "Editor.h"
#include "EditorAssetLibrary.h"
#include "EditorModeManager.h"
#include "EditorUtilitySubsystem.h"
#include "EditorUtilityWidgetBlueprint.h"
#include "KAutoOptimizerModule.h"
#include "StaticMeshEditorExtender.h"
#include "Engine/Texture2DArray.h"
#include "Materials/MaterialInstanceConstant.h"
#include "Dialogue/DialogueCommon.h"
#include "KGStoryLineEditorModule.h"
#include "DataDrivenShaderPlatformInfo.h"
#include "ImageUtils.h"

//ResourceCheck
#include "KGUISettings.h"
#include "ResourceCheckSubsystem.h"
#include "Blueprint/GameViewportSubsystem.h"
#include "Engine/UserInterfaceSettings.h"
#include "Slate/SceneViewport.h"
#include "UI/UIRoot.h"


//////////////////////////////// EXPORT TOOLS BEGIN //////////////////////////////
#define LOCTEXT_NAMESPACE "FContentMenuExportNavigation"


void FToolsLibrary::ExportNavigation()
{
	UWorld* World = GEditor->GetEditorWorldContext().World();
	if (!UC7ExportNavDataLibrary::GetdtNavMeshInsByWorld(World))
	{
		FMessageDialog::Open(EAppMsgType::Ok, FText::Format(
			LOCTEXT("Not Found Valid Nav", "Not found any valid Navigation data in {0} Map!"),
			FText::FromString(World->GetMapName())
		));

		return;
	}

	IDesktopPlatform* DesktopPlatform = FDesktopPlatformModule::Get();
	if (DesktopPlatform)
	{
		FString OutPath;
		FString ProjectSavedDir = FPaths::ConvertRelativePathToFull(FPaths::ProjectSavedDir());
		const bool bOpened = DesktopPlatform->OpenDirectoryDialog(
			nullptr,
			LOCTEXT("SaveNav", "Save Recast Navigation NavMesh & NavData").ToString(),
			ProjectSavedDir,
			OutPath
		);

		if (!OutPath.IsEmpty() && FPaths::DirectoryExists(OutPath))
		{
			FString CurrentTime = FDateTime::Now().ToString();
			FString MapName = World->GetMapName();

			FString NavMeshFile = FPaths::Combine(OutPath, MapName + TEXT("-NavMesh-") + CurrentTime + TEXT(".obj"));
			UC7ExportNavDataLibrary::ExportRecastNavMesh(NavMeshFile);
			UE_LOG(LogTemp, Log, TEXT("Successd to Export the NavMesh."));

			FString NavDataFile = FPaths::Combine(OutPath, MapName + TEXT("-NavData-") + CurrentTime + TEXT(".bin"));
			UC7ExportNavDataLibrary::ExportRecastNavData(NavDataFile);
			UE_LOG(LogTemp, Log, TEXT("Successd to Export the NavData."));


			//FString GridDataFile = FPaths::Combine(OutPath, MapName + TEXT("-GridData-") + CurrentTime + TEXT(".bin"));
			//FSceneVoxelization::ExportSceneGridData(*GridDataFile);


		}
	}
}


#undef LOCTEXT_NAMESPACE

void FToolsLibrary::ExportVoxData()
{
}

void FToolsLibrary::ExportVoxDataTiled()
{
}

void FToolsLibrary::ShowRuntimeVoxFromServer()
{
}

void FToolsLibrary::ShowRuntimeVoxFromLocal()
{
}

void FToolsLibrary::ClearVoxPreviewMesh()
{
}

void FToolsLibrary::ExportTestVoxData()
{
}

void FToolsLibrary::ImportVoxData()
{
}

void FToolsLibrary::ShowVoxelPreviewMesh()
{
}

void FToolsLibrary::TestNavAndVoxel() {
}


/////////////////////////////// assets modify tools ////////////////////////
UObject* CustomLoadObject(UClass* ObjectClass, UObject* InObjectPackage, const TCHAR* OrigInName, bool& needToSave, const TCHAR* FolderName = nullptr, uint32 LoadFlags = LOAD_None, UPackageMap* Sandbox = nullptr, bool bAllowObjectReconciliation = true, const FLinkerInstancingContext* InstancingContext = nullptr);
bool CustomResolveName(UObject*& InPackage, FString& InOutName, FString& FolderName, bool& needToSave, bool Create, bool Throw, uint32 LoadFlags = LOAD_None, const FLinkerInstancingContext* InstancingContext = nullptr);
UObject* CustomStaticFindObject(UClass* ObjectClass, UObject* Outer, const TCHAR* Name, bool& needToSave, const TCHAR* FolderName = nullptr, bool ExactClass = false);

template< class T >
inline T* CustomFindObject(UObject* Outer, const TCHAR* Name, const TCHAR* FolderName, bool& needToSave, bool ExactClass = false)
{
	return (T*)CustomStaticFindObject(T::StaticClass(), Outer, Name, needToSave, FolderName, ExactClass);
}

UObject* CustomStaticFindObject(UClass* ObjectClass, UObject* InObjectPackage, const TCHAR* OrigInName, bool& needToSave, const TCHAR* FolderName, bool ExactClass)
{
	const bool bAnyPackage = InObjectPackage == nullptr;
	UObject* ObjectPackage = bAnyPackage ? nullptr : InObjectPackage;
	UObject* MatchingObject = nullptr;
	FName ObjectName;
	FString folderName = FolderName;

	if (!bAnyPackage)
	{
		FString TempName = OrigInName;
		CustomResolveName(ObjectPackage, TempName, folderName, needToSave, false, false);
		ObjectName = FName(*TempName, FNAME_Add);
	}

	return StaticFindObjectFast(ObjectClass, ObjectPackage, ObjectName, ExactClass);
}

bool ShouldReportProgress()
{
	return GIsEditor && IsInGameThread() && !IsRunningCommandlet() && !IsAsyncLoading();
}

bool ShouldCreateThrottledSlowTask()
{
	return ShouldReportProgress() && FSlowTask::ShouldCreateThrottledSlowTask();
}
static int32 GGameThreadLoadCounter = 0;

bool CustomResolveName(UObject*& InPackage, FString& InOutName, FString& FolderName, bool& needToSave, bool Create, bool Throw, uint32 LoadFlags, const FLinkerInstancingContext* InstancingContext)
{
	ConstructorHelpers::StripObjectClass(InOutName);

	bool bSubobjectPath = false;

	int32 DotIndex = INDEX_NONE;
	InOutName.ReplaceInline(SUBOBJECT_DELIMITER, TEXT(".."), ESearchCase::CaseSensitive);
	while ((DotIndex = InOutName.Find(TEXT("."), ESearchCase::CaseSensitive)) != INDEX_NONE)
	{
		FString PartialName = InOutName.Left(DotIndex);

		//SomePackage.SomeGroup.SomeObject..Subobject
		if (InOutName.IsValidIndex(DotIndex + 1) && InOutName[DotIndex + 1] == TEXT('.'))
		{
			InOutName.RemoveAt(DotIndex, 1, false);
			bSubobjectPath = true;
			Create = false;
}

		FName* ScriptPackageName = nullptr;
		if (!bSubobjectPath)
		{
			ScriptPackageName = FPackageName::FindScriptPackageName(*PartialName);
			if (ScriptPackageName)
			{
				PartialName = ScriptPackageName->ToString();
			}
		}

		if (!Create)
		{
			UObject* NewPackage = FindObject<UPackage>(InPackage, *PartialName);

			if (!NewPackage)
			{
				NewPackage = FindObject<UObject>(InPackage == NULL ? nullptr : InPackage, *PartialName);
				if (!NewPackage)
				{
					return bSubobjectPath;
				}
			}
			InPackage = NewPackage;

		}
		else if (!FPackageName::IsShortPackageName(PartialName))
		{
			InPackage = StaticFindObjectFast(UPackage::StaticClass(), InPackage, *PartialName);

			if (!ScriptPackageName && !InPackage)
			{

				UPackage* Result = nullptr;
				FString FileToLoad = PartialName;
				FString DiffFileToLoad;

				TGuardValue<ITransaction*> SuppressTransaction(GUndo, nullptr);
				TGuardValue<bool> IsEditorLoadingPackage(GIsEditorLoadingPackage, GIsEditor || GIsEditorLoadingPackage);

				TOptional<FScopedSlowTask> SlowTask;
				if (ShouldCreateThrottledSlowTask())
				{
					static const FTextFormat LoadingPackageTextFormat = NSLOCTEXT("Core", "LoadingPackage_Scope", "Loading Package '{0}'");
					SlowTask.Emplace(100, FText::Format(LoadingPackageTextFormat, FText::FromString(FileToLoad)));
					SlowTask->Visibility = ESlowTaskVisibility::Invisible;
					SlowTask->EnterProgressFrame(10);
				}

				if (FCoreDelegates::OnSyncLoadPackage.IsBound())
				{
					FCoreDelegates::OnSyncLoadPackage.Broadcast(FileToLoad);
				}
				TRefCountPtr<FUObjectSerializeContext> LoadContext = FUObjectThreadContext::Get().GetSerializeContext();

				// Try to load.
				BeginLoad(LoadContext, *FileToLoad);

				bool bFullyLoadSkipped = false;
				if (SlowTask)
				{
					SlowTask->EnterProgressFrame(30);
				}

				FLinkerLoad* Linker = nullptr;
				const double StartTime = FPlatformTime::Seconds();

				FUObjectSerializeContext* InOutLoadContext = LoadContext;

				UPackage* CreatedPackage = nullptr;
				FString PackageNameToCreate = FileToLoad;
				FString PackageNameToLoad = PackageNameToCreate;
				Linker = GetPackageLinker(Cast<UPackage>(InPackage), FPackagePath::FromPackageNameChecked(*FileToLoad), LoadFlags, nullptr, nullptr, &InOutLoadContext, nullptr, InstancingContext);
				if (InOutLoadContext != LoadContext && InOutLoadContext)
				{
					// The linker already existed and was associated with another context
					LoadContext->DecrementBeginLoadCount();
					LoadContext = InOutLoadContext;
					LoadContext->IncrementBeginLoadCount();
				}
				if (!Linker)
				{
					EndLoad(LoadContext);
					return false;
			}
				Result = Linker->LinkerRoot;

				auto EndLoadAndCopyLocalizationGatherFlag = [&]
					{
						EndLoad(Linker->GetSerializeContext());
						Result->ThisRequiresLocalizationGather(Linker->RequiresLocalizationGather());
					};

				Result->SetLoadedByEditorPropertiesOnly(false);

				FString LongPackageFilename;
				FPackageName::TryConvertFilenameToLongPackageName(FileToLoad, LongPackageFilename);
				//Result->FileName = FName(*LongPackageFilename);

				Result->SetLoadedPath(FPackagePath::FromPackageNameChecked(*LongPackageFilename));

				if (SlowTask)
				{
					SlowTask->EnterProgressFrame(30);
				}
				uint32 DoNotLoadExportsFlags = LOAD_Verify;
#if USE_CIRCULAR_DEPENDENCY_LOAD_DEFERRING
				DoNotLoadExportsFlags |= LOAD_DeferDependencyLoads;
#endif 

				if ((LoadFlags & DoNotLoadExportsFlags) == 0)
				{

					if (Linker->ImportMap.Num() > 0)
					{
						for (auto& eachIM : Linker->ImportMap)
						{
							FString objName = eachIM.ObjectName.ToString();
							if (objName.StartsWith("/Game/", ESearchCase::CaseSensitive))
							{
								FString left, right;
								objName.Split("Game", &left, &right, ESearchCase::CaseSensitive, ESearchDir::FromStart);

								if (!right.StartsWith("/ArtsTest", ESearchCase::CaseSensitive))
								{
									needToSave = true;
									FString newPackageName = FolderName + right;
									eachIM.ObjectName = FName(newPackageName);
								}
							}

							FString classPKGName = eachIM.ClassPackage.ToString();
							if (classPKGName.StartsWith("/Game/", ESearchCase::CaseSensitive))
							{
								FString leftC, rightC;
								classPKGName.Split("Game", &leftC, &rightC, ESearchCase::CaseSensitive, ESearchDir::FromStart);
								//
								if (!rightC.StartsWith("/ArtsTest", ESearchCase::CaseSensitive))
								{
									needToSave = true;
									FString newClassPKGName = FolderName + rightC;
									eachIM.ClassPackage = FName(newClassPKGName);
								}
							}

						}
					} // end of ImportMap editing

					FSerializedPropertyScope SerializedProperty(*Linker, Linker->GetSerializedProperty());
					Linker->LoadAllObjects(GEventDrivenLoaderEnabled);

					if (Linker->ImportMap.Num() > 0)
					{
						for (auto& eachIM : Linker->ImportMap)
						{
							if ((eachIM.XObject) || (*eachIM.ObjectName.ToString() == nullptr))
							{
							}
							else
							{
								eachIM.XObject = CustomLoadObject(UObject::StaticClass(), nullptr, *eachIM.ObjectName.ToString(), needToSave, *FolderName, LoadFlags);
							}
						}
					}
						}

				if (SlowTask)
				{
					SlowTask->EnterProgressFrame(30);
				}

				EndLoadAndCopyLocalizationGatherFlag();

				GIsEditorLoadingPackage = *IsEditorLoadingPackage;
				if (Result && !LoadContext->HasLoadedObjects() && !(LoadFlags & LOAD_Verify))
				{
					Result->SetLoadTime(FPlatformTime::Seconds() - StartTime);
				}
				Linker->Flush();

				if (!FPlatformProperties::RequiresCookedData())
				{
					Linker->FlushCache();
				}

				if (!bFullyLoadSkipped)
				{
					// Mark package as loaded.
					Result->SetFlags(RF_WasLoaded);
				}

					}
			if (!InPackage)
			{
				FString InName = PartialName;

				UObject* Outer = nullptr;
				CustomResolveName(Outer, InName, FolderName, needToSave, true, false);

				UPackage* Result = NULL;
				if (InName != TEXT("None"))
				{
					Result = CustomFindObject<UPackage>(nullptr, *InName, *FolderName, needToSave);
				}
				if (Result == NULL)
				{
					FName NewPackageName(*InName, FNAME_Add);
					Result = NewObject<UPackage>(nullptr, NewPackageName, RF_Public);

				}
				InPackage = Result;
			}

		}
		InOutName.RemoveAt(0, DotIndex + 1, false);
			}
	return true;
				}


UObject* CustomLoadObject(UClass* ObjectClass, UObject* InOuter, const TCHAR* InName, bool& needToSave, const TCHAR* FolderName, uint32 LoadFlags, UPackageMap* Sandbox, bool bAllowObjectReconciliation, const FLinkerInstancingContext* InstancingContext)
{
	FString folderName = FolderName;
	FString StrName = InName;
	UObject* Result = nullptr;
	const bool bContainsObjectName = !!FCString::Strstr(InName, TEXT("."));

	CustomResolveName(InOuter, StrName, folderName, needToSave, true, true, LoadFlags & (LOAD_EditorOnly | LOAD_NoVerify | LOAD_Quiet | LOAD_NoWarn | LOAD_DeferDependencyLoads), InstancingContext);

	if (InOuter)
	{
		if (bAllowObjectReconciliation && (bContainsObjectName || GIsImportingT3D))
		{
			Result = StaticFindObjectFast(ObjectClass, InOuter, *StrName);
		}
	}

	if (!Result && !bContainsObjectName)
	{
		StrName = InName;
		StrName += TEXT(".");
		StrName += FPackageName::GetShortName(InName);
		Result = CustomLoadObject(ObjectClass, InOuter, *StrName, needToSave, FolderName, LoadFlags, Sandbox, bAllowObjectReconciliation, InstancingContext);
	}
	else if (Result && !(LoadFlags & LOAD_EditorOnly))
	{
		Result->GetOutermost()->SetLoadedByEditorPropertiesOnly(false);
	}

	return Result;
}

void FToolsLibrary::FixArtTestAssetsReference(TArray<FString> SelectedFolders)
{
	for (size_t i = 0; i < SelectedFolders.Num(); i++)
	{
		if (SelectedFolders[i].Contains("/ArtsTest/"))
		{
			IAssetRegistry* assetRgs = IAssetRegistry::Get();
			TArray<FAssetData> allAssets;
			assetRgs->GetAssetsByPath(FName(SelectedFolders[i]), allAssets, true, false);
			if (allAssets.Num() > 0)
			{
				for (auto& eachAsset : allAssets)
				{
					bool needToSave = true;
					UObject* obj = nullptr;
					FString assetPath = eachAsset.GetSoftObjectPath().ToString();
					obj = CustomLoadObject(UObject::StaticClass(), obj, *assetPath, needToSave, *SelectedFolders[i]);
					if (needToSave)
					{
						UPackage* pack = obj->GetPackage();

						FString curPackagePath = eachAsset.PackageName.ToString();
						FString savingPath = FPaths::ProjectContentDir();

						FString leftPart, rightPart;
						curPackagePath.Split("/Game/", &leftPart, &rightPart, ESearchCase::CaseSensitive, ESearchDir::FromStart);
						savingPath = savingPath + rightPart;
						FString extension = (eachAsset.AssetClassPath.GetAssetName().ToString() == "World") ? FPackageName::GetMapPackageExtension() : FPackageName::GetAssetPackageExtension();

						FSavePackageArgs SaveArgs;
						{
							SaveArgs.TopLevelFlags = RF_Public | RF_Standalone;
							SaveArgs.SaveFlags = SAVE_NoError;
							SaveArgs.Error = GError;
							SaveArgs.bForceByteSwapping = true;
							SaveArgs.bWarnOfLongFilename = true;
						}
						UPackage::SavePackage(pack, obj, *(savingPath + extension), SaveArgs);

						//UPackage::SavePackage(pack, obj, EObjectFlags::RF_Public | EObjectFlags::RF_Standalone, *(savingPath + extension), GError, nullptr, true, true, SAVE_NoError);
					}


				}
			}
		}
		else
		{
			UE_LOG(LogTemp, Warning, TEXT("Folder %s does not belong to ArtsTest"), *SelectedFolders[i]);
		}

	}
}



void FToolsLibrary::CleanCustomizePkgHead(TArray<FString> SelectedFolders)
{
	TArray<UPackage*> PackagesToSave;

	for (size_t i = 0; i < SelectedFolders.Num(); i++)
	{
		IAssetRegistry* assetRgs = IAssetRegistry::Get();
		TArray<FAssetData> allAssets;
		assetRgs->GetAssetsByPath(FName(SelectedFolders[i]), allAssets, true, false);
		if (allAssets.Num() > 0)
		{
			for (auto& eachAsset : allAssets)
			{
				bool needToSave = true;
				UObject* obj = nullptr;
				FString assetPath = eachAsset.GetSoftObjectPath().ToString();

				UPackage* P = eachAsset.GetPackage();
				if (P == nullptr)
				{
					continue;
				}

				if (P->HasAnyPackageFlags(PKG_CustomizePackageHead))
				{
					P->MarkPackageDirty();
					PackagesToSave.Add(P);
				}
			}
		}

		FEditorFileUtils::PromptForCheckoutAndSave(PackagesToSave, true, true);
		}


	}




////////////////////////////////// OTHER TOOLS BEGIN////////////////////////////////////////

void FToolsLibrary::ShowPerformance()
{
	GEngine->Exec(nullptr, TEXT("stat unit"));
	GEngine->Exec(nullptr, TEXT("stat fps"));
}

void CreateBrushForVolumeActor(AVolume* NewActor, UBrushBuilder* BrushBuilder)
{
	if (NewActor != NULL)
	{
		// this code builds a brush for the new actor
		NewActor->PreEditChange(NULL);

		// Use the same object flags as the owner volume
		EObjectFlags ObjectFlags = NewActor->GetFlags() & (RF_Transient | RF_Transactional);

		NewActor->PolyFlags = 0;
		NewActor->Brush = NewObject<UModel>(NewActor, NAME_None, ObjectFlags);
		NewActor->Brush->Initialize(nullptr, true);
		NewActor->Brush->Polys = NewObject<UPolys>(NewActor->Brush, NAME_None, ObjectFlags);
		NewActor->GetBrushComponent()->Brush = NewActor->Brush;
		if (BrushBuilder != nullptr)
		{
			NewActor->BrushBuilder = DuplicateObject<UBrushBuilder>(BrushBuilder, NewActor);
		}

		BrushBuilder->Build(NewActor->GetWorld(), NewActor);

		FBSPOps::csgPrepMovingBrush(NewActor);

		// Set the texture on all polys to NULL.  This stops invisible textures
		// dependencies from being formed on volumes.
		if (NewActor->Brush)
		{
			for (int32 poly = 0; poly < NewActor->Brush->Polys->Element.Num(); ++poly)
			{
				FPoly* Poly = &(NewActor->Brush->Polys->Element[poly]);
				Poly->Material = NULL;
			}
		}
		NewActor->PostEditChange();
	}
}

void FToolsLibrary::PrecomputedVisibilityVolumeExport()
{
	UWorld* World = LoadObject<UWorld>(nullptr, TEXT("/Game/Arts/Maps/Ruierbibo_Blockout/Ruierbibo_Navmesh.Ruierbibo_Navmesh"));
	//UWorld* World = LoadedObject->GetWorld();
	TArray<AActor*> VisibilityVolumes;
	UGameplayStatics::GetAllActorsOfClass(World, APrecomputedVisibilityVolume::StaticClass(), VisibilityVolumes);
	for (AActor* a : VisibilityVolumes) {
		a->Destroy();
	}
	for (TActorIterator<AActor> It(World, ANavMeshBoundsVolume::StaticClass()); It; ++It)
	{
		if (ANavMeshBoundsVolume* Actor = Cast<ANavMeshBoundsVolume>(*It))
		{
			UCubeBuilder* Builder = NewObject<UCubeBuilder>();
			APrecomputedVisibilityVolume* NewActor = World->SpawnActor<APrecomputedVisibilityVolume>(APrecomputedVisibilityVolume::StaticClass(), Actor->GetTransform());
			NewActor->AttachToActor(Actor, FAttachmentTransformRules::KeepWorldTransform);
			CreateBrushForVolumeActor(NewActor, Builder);
		}
	}
	UEditorLoadingAndSavingUtils::SaveMap(World, TEXT("/Game/Arts/Maps/Ruierbibo_Blockout/Ruierbibo_Navmesh")/*, false*/);
}

void FToolsLibrary::ToggleSafeAreaVisible()
{
	UKGUISettings* mutableDefault = GetMutableDefault<UKGUISettings>();
	bool v = mutableDefault->bUseSafeArea;
	mutableDefault->bUseSafeArea = !v;
	mutableDefault->PostEditChange();
	mutableDefault->SaveConfig();

	// 更新预览窗口
	{
		auto GameViewportSubsystem = UGameViewportSubsystem::Get(GWorld->GetWorld());
		for (auto KeyValuePair : GameViewportSubsystem->GetViewportWidgets())
		{
			// 挨个都设置下得了
			UUIRoot* uiRoot = Cast<UUIRoot>(KeyValuePair.Key.ResolveObjectPtr());
			if (uiRoot != nullptr)
			{
				uiRoot->UpdateSafeAreaEnabled();
			}
		}
	}
}
bool FToolsLibrary::IsSafeAreaVisible()
{
	return GetDefault<UKGUISettings>()->bUseSafeArea;
}

void FToolsLibrary::TogglePCScale()
{
	UKGUISettings* mutableDefault = GetMutableDefault<UKGUISettings>();
	bool v = mutableDefault->bPCScale;
	mutableDefault->bPCScale = !v;
	mutableDefault->PostEditChange();
	mutableDefault->SaveConfig();

	// 更新预览窗口
	FString PlatformName = FPlatformProperties::IniPlatformName();
	if (PlatformName == "Windows")
	{
		const UUserInterfaceSettings* Settings = GetDefault<UUserInterfaceSettings>();
		UUserInterfaceSettings* MutableUISettings = const_cast<UUserInterfaceSettings*>(Settings);
		MutableUISettings->ApplicationScale = mutableDefault->bPCScale ? 0.85f : 1.0f;	// 这里没有做更合理的设计，暂时先给交互可用
	}
}
bool FToolsLibrary::IsPCScaleEnable()
{
	return GetDefault<UKGUISettings>()->bPCScale;
}

void FToolsLibrary::StartPIEFromLogin()
{
	//if (UGameLoopEditorSettings* Settings = GetMutableDefault<UGameLoopEditorSettings>())
	//{
	//	Settings->PlayMode = EEditorPlayMode::GameLoop;
	//	// simulate input
	//	FPlayWorldCommands::GlobalPlayWorldActions->ProcessCommandBindings(EKeys::P, FModifierKeysState(false, false, false, false, true, true, false, false, false), false);
	//}

	FLevelEditorModule& LevelEditorModule = FModuleManager::GetModuleChecked<FLevelEditorModule>(TEXT("LevelEditor"));

	if (GLevelEditorModeTools().IsModeActive("EM_GamePlayEditorMode"))
	{
		FText Message = FText::FromString(TEXT("场景编辑模式下, 无法运行游戏"));
		FMessageDialog::Open(EAppMsgType::Ok, Message);
		return;
	}
	if (FBehaviorActorSelector::IsDialogueEditorOpen())
	{
		FText Message = FText::FromString(TEXT("请先关闭对话编辑器, 再运行游戏"));
		FMessageDialog::Open(EAppMsgType::Ok, Message);
		return;
	}

	FKGStoryLineEditorModule& KGStoryLineEditorModule = FModuleManager::LoadModuleChecked<FKGStoryLineEditorModule>("KGStoryLineEditor");
	if (KGStoryLineEditorModule.IsSequencerEditorOpen())
	{
		FText Message = FText::FromString(TEXT("请先关闭Sequencer编辑器, 再运行游戏"));
		FMessageDialog::Open(EAppMsgType::Ok, Message);
		return;
	}
	///** Set PlayInViewPort as the last executed play command */
	//const FPlayWorldCommands& Commands = FPlayWorldCommands::Get();

	//SetLastExecutedPlayMode(PlayMode_InViewPort);

	//RecordLastExecutedPlayMode();

	//ULevelEditorPlaySettings::StaticClass()->GetDefaultObject<ULevelEditorPlaySettings>()->UseMouseForTouch = true;
	//UInputSettings::StaticClass()->GetDefaultObject<UInputSettings>()->bUseMouseForTouch = true;

	TSharedPtr<IAssetViewport> ActiveLevelViewport = LevelEditorModule.GetFirstActiveViewport();

	//const bool bAtPlayerStart = (GetPlayModeLocation() == PlayLocation_DefaultPlayerStart);

	FRequestPlaySessionParams SessionParams;

	const UGameMapsSettings* GameMapsSettings = GetDefault<UGameMapsSettings>();

	SessionParams.GlobalMapOverride = GameMapsSettings->GetGameDefaultMap();

	//UWorld* World = GEditor->GetEditorWorldContext().World();
	//check(World);

	//SessionParams.FeatureLevelOverride = World->FeatureLevel;

		//FString(TEXT("/Game/Arts/Maps/Login/LV_Login"));
		// 
	// Make sure we can find a path to the view port.  This will fail in cases where the view port widget
	// is in a backgrounded tab, etc.  We can't currently support starting PIE in a backgrounded tab
	// due to how PIE manages focus and requires event forwarding from the application.
	if (ActiveLevelViewport.IsValid() && FSlateApplication::Get().FindWidgetWindow(ActiveLevelViewport->AsWidget()).IsValid())
	{
		SessionParams.DestinationSlateViewport = ActiveLevelViewport;
		//if (!bAtPlayerStart)
		{
			// Start the player where the camera is if not forcing from player start
			//SessionParams.StartLocation = ActiveLevelViewport->GetAssetViewportClient().GetViewLocation();
			//SessionParams.StartRotation = ActiveLevelViewport->GetAssetViewportClient().GetViewRotation();
			SessionParams.StartLocation = FVector::Zero();
			SessionParams.StartRotation = FRotator::ZeroRotator;
		}
	}

	

	//if (GEditor->PlayWorld)
	{
		// If there is an active level view port, play the game in it, otherwise make a new window.
		GUnrealEd->RequestPlaySession(SessionParams);
	}
	//else
	{
		//// There is already a play world active which means simulate in editor is happening
		//// Toggle to PIE
		//check(!GIsPlayInEditorWorld);
		//GUnrealEd->RequestToggleBetweenPIEandSIE();
	}
}


void FToolsLibrary::SetupHoudiniEnv()
{
	FString ContentDir = FPaths::ProjectContentDir() + FString(TEXT("houdini_project/otls;&"));
	ContentDir = FPaths::ConvertRelativePathToFull(ContentDir);
	//FPlatformMisc::SetEnvironmentVar(TEXT("HOUDINI_OTLSCAN_PATH"), *ContentDir);

	FString HDir = FPlatformProcess::UserDir();

	IFileManager& FileManager = FFileManagerGeneric::Get();

	TArray<FString> FilesNames;

	FileManager.FindFilesRecursive(FilesNames, *HDir, TEXT("houdini.env"), true, false, true);


	for (size_t i = 0; i < FilesNames.Num(); i++)
	{
		FString& FN = FilesNames[i];

		FArchive* FileReader = FileManager.CreateFileReader(*FN);
		check(FileReader);

		int32 FileSize = FileReader->TotalSize();
		char* FileContext = new char[FileSize + 1];
		FileContext[FileSize] = 0;
		FileReader->Seek(0);
		FileReader->Serialize(FileContext, FileSize);
		FileReader->Close();
		delete FileReader;

		FString Text = UTF8_TO_TCHAR(FileContext);

		delete[] FileContext;

		TArray<FString> Lines;

		int32 n = Text.ParseIntoArrayLines(Lines);

		bool bFound = false;

		FString InsertLine = FString("\nHOUDINI_OTLSCAN_PATH = ") + ContentDir;

		for (size_t j = 0; j < Lines.Num(); j++)
		{
			int32 idx = Lines[j].Find(TEXT("HOUDINI_OTLSCAN_PATH"));
			if (idx != -1)
			{
				bFound = true;

				Lines[j] = InsertLine;
			}
		}

		if (bFound == false)
		{
			Lines.Add(InsertLine);
		}

		FString NewText;
		for (size_t j = 0; j < Lines.Num(); j++)
		{
			NewText += Lines[j] + TEXT("\n");
		}

		std::string NewContent = TCHAR_TO_UTF8(*NewText);
		int len = NewContent.length();

		FArchive* FileW = FileManager.CreateFileWriter(*FN);
		check(FileW);
		FileW->Seek(0);
		FileW->Serialize((void*)NewContent.c_str(), len);
		FileW->Close();
		delete FileW;
	}




	//void FindFilesRecursive(TArray<FString>&FileNames, const TCHAR * StartDirectory, const TCHAR * Filename, bool Files, bool Directories, bool bClearFileNames = true) override;




}





void FToolsLibrary::ExportBSEnum()
{
	UBSEditorFunctionLibrary::ExportEnum();
}

void FToolsLibrary::ExportVMBlueprint()
{
	// 尝试启动UnLua
	FModuleManager::LoadModuleChecked<FC7EditorModule>("C7Editor").TryStartUnLua();
	// 尝试关闭UnLua
	FModuleManager::LoadModuleChecked<FC7EditorModule>("C7Editor").TryFinishUnLua();
}

void FToolsLibrary::ExportVMWidgetUtils()
{
	// 尝试启动UnLua
	FModuleManager::LoadModuleChecked<FC7EditorModule>("C7Editor").TryStartUnLua();
	// 尝试关闭UnLua
	FModuleManager::LoadModuleChecked<FC7EditorModule>("C7Editor").TryFinishUnLua();
}

void FToolsLibrary::StartSceneInspection()
{
	FWorldContext* WorldContext = GEditor->GetPIEWorldContext(0);
	if (WorldContext)
	{
		ASceneInspectionActor* InspectionActor = Cast<ASceneInspectionActor>(FSceneInspection::StartSceneInspection(WorldContext->World()));
		InspectionActor->OnInspectionFinishedEvent.AddStatic(FToolsLibrary::OnInspectionFinished);
	}
}

void FToolsLibrary::CopySpline()
{
	UWorld* World = GEditor->GetEditorWorldContext().World();

	USelection* SelectedActors = GEditor->GetSelectedActors();

	// main refer to LandscapeEdModeSplineTools.cpp BeginTool function
	if (!World->IsPartitionedWorld())
	{
		if (SelectedActors->Num() > 2)
		{
			FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(TEXT("选择的Actor数量大于2.")));
			return;
		}
		else if (SelectedActors->Num() < 2)
		{
			FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(TEXT("选择的Actor数量小于2.")));
			return;
		}
		UObject* SelectedObject1 = SelectedActors->GetSelectedObject(0);
		UObject* SelectedObject2 = SelectedActors->GetSelectedObject(1);

		if (!SelectedObject1 || !SelectedObject2)
		{
			UE_LOG(LogTemp, Error, TEXT("请确认你选中了两个Actor."));
			FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(TEXT("请确认你选中了两个Actor.")));
			return;
		}

		ALandscapeProxy* SplineOwner = Cast<ALandscapeProxy>(SelectedObject1);
		if (!SplineOwner)
		{
			FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(TEXT("第一个选中的 Actor 需要为 Landscape")));
			return;
		}
		ALandscapeProxy* DestinateSplineOwner = Cast<ALandscapeProxy>(SelectedObject2);
		if (!DestinateSplineOwner)
		{
			FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(TEXT("第二个选中的 Actor 需要为 Landscape")));
			return;
		}

		ULandscapeSplinesComponent* SplinesComp = SplineOwner->GetSplinesComponent();
		if (!SplinesComp)
		{
			FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(TEXT("第一个选中的 Landscape 必须要有 LandscapeSpline 才行.")));
			return;
		}

		ULandscapeSplinesComponent* DestinateSplinesComp = DestinateSplineOwner->GetSplinesComponent();
		if (!DestinateSplinesComp)
		{
			DestinateSplineOwner->CreateSplineComponent();
			DestinateSplinesComp = DestinateSplineOwner->GetSplinesComponent();
			check(DestinateSplinesComp);
		}

		TMap<const TObjectPtr<ULandscapeSplineControlPoint>, TObjectPtr<ULandscapeSplineControlPoint>> ControlPointMap;
		DestinateSplinesComp->Modify();
		for (const auto& ControlPoint : SplinesComp->ControlPoints)
		{
			ULandscapeSplineControlPoint* NewControlPoint = NewObject<ULandscapeSplineControlPoint>(DestinateSplinesComp, NAME_None, RF_Transactional);
			DestinateSplinesComp->ControlPoints.Add(NewControlPoint);

			NewControlPoint->Location = ControlPoint->Location;
			NewControlPoint->Rotation = ControlPoint->Rotation;

			NewControlPoint->UpdateSplinePoints();

			ControlPointMap.Add(ControlPoint, NewControlPoint);
		}

		for (const auto& Segment : SplinesComp->Segments)
		{
			ULandscapeSplineSegment* NewSegment = DuplicateObject<ULandscapeSplineSegment>(Segment, DestinateSplinesComp);

			NewSegment->Connections[0].ControlPoint = ControlPointMap[Segment->Connections[0].ControlPoint];
			NewSegment->Connections[1].ControlPoint = ControlPointMap[Segment->Connections[1].ControlPoint];

			NewSegment->Connections[0].ControlPoint->ConnectedSegments.Add(FLandscapeSplineConnection(NewSegment, 0));
			NewSegment->Connections[1].ControlPoint->ConnectedSegments.Add(FLandscapeSplineConnection(NewSegment, 1));

			DestinateSplinesComp->Segments.Add(NewSegment);
		}

		if (!DestinateSplinesComp->IsRegistered())
		{
			DestinateSplinesComp->RegisterComponent();
		}
		else
		{
			DestinateSplinesComp->MarkRenderStateDirty();
		}
	}
	else
	{
		int32 SelectedNum = SelectedActors->Num();

		for (int32 i = 0; i < SelectedNum - 1; i++)
		{
			ALandscapeSplineActor* CurSplineActor = Cast<ALandscapeSplineActor>(SelectedActors->GetSelectedObject(i));
			if (!CurSplineActor)
			{
				FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(TEXT("前面选中的 Actor 需要为 LandscapeSplineActor")));
				return;
			}
		}

		ALandscape* DestinateLandscape = Cast<ALandscape>(SelectedActors->GetSelectedObject(SelectedNum - 1));
		if (!DestinateLandscape)
		{
			FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(TEXT("最后一个选中的 Actor 需要为 Landscape")));
			return;
		}

		UEditorActorSubsystem* EditorActorSubsystem = GEditor->GetEditorSubsystem<UEditorActorSubsystem>();
		for (int32 i = 0; i < SelectedNum - 1; i++)
		{
			ALandscapeSplineActor* SplineActor = Cast<ALandscapeSplineActor>(SelectedActors->GetSelectedObject(i));

			// 需要在Select模式下使用，否则返回空
			ALandscapeSplineActor* NewSplineActor = Cast<ALandscapeSplineActor>(EditorActorSubsystem->DuplicateActor(SplineActor, World));
			if (!NewSplineActor)
			{
				FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(TEXT("请确认编辑器在Select模式")));
				return;
			}
			if (NewSplineActor)
			{
				// 参考 ULandscapeInfo::CreateSplineActor
				// 需要取消注册与注册，否则在landscape模式下会有问题
				NewSplineActor->GetLandscapeInfo()->UnregisterSplineActor(NewSplineActor);
				NewSplineActor->GetSharedProperties(DestinateLandscape->GetLandscapeInfo());
				NewSplineActor->SetIsSpatiallyLoaded(DestinateLandscape->GetLandscapeInfo()->AreNewLandscapeActorsSpatiallyLoaded());
				FActorLabelUtilities::SetActorLabelUnique(NewSplineActor, ALandscapeSplineActor::StaticClass()->GetName());
				DestinateLandscape->GetLandscapeInfo()->RegisterSplineActor(NewSplineActor);
			}
		}
	}
}

namespace Utils
{
	// Modified from FEditorFileUtils::CheckoutPackages
	// 去掉了弹窗，方便后续CI流程
	ECommandResult::Type CheckoutPackages(const TArray<UPackage*>& PkgsToCheckOut, TArray<UPackage*>* OutPackagesCheckedOut, const bool bErrorIfAlreadyCheckedOut, TMap<FString, FString>& CheckOutUsers)
	{
		TRACE_CPUPROFILER_EVENT_SCOPE(FEditorFileUtils_CheckoutPackages);

		ECommandResult::Type CheckOutResult = ECommandResult::Succeeded;
		FString PkgsWhichFailedCheckout;

		ISourceControlProvider& SourceControlProvider = ISourceControlModule::Get().GetProvider();

		TArray<UPackage*> FinalPackageCheckoutList;
		TArray<UPackage*> FinalPackageMarkForAddList;

		// Source control may have been enabled in the package checkout dialog.
		// Ensure the status is up to date
		if (PkgsToCheckOut.Num() > 0)
		{
			CheckOutResult = SourceControlProvider.Execute(ISourceControlOperation::Create<FUpdateStatus>(), PkgsToCheckOut);
		}

		if (CheckOutResult != ECommandResult::Cancelled)
		{
			// Print out all the packages and set the check out result
			auto FailedIntermediateOperations = [&CheckOutResult, &PkgsWhichFailedCheckout, &PkgsToCheckOut]()
				{
					for (auto PkgsToCheckOutIter = PkgsToCheckOut.CreateConstIterator(); PkgsToCheckOutIter; ++PkgsToCheckOutIter)
					{
						UPackage* PackageToCheckOut = *PkgsToCheckOutIter;
						const FString PackageToCheckOutName = PackageToCheckOut->GetName();
						PkgsWhichFailedCheckout += FString::Printf(TEXT("\n%s"), *PackageToCheckOutName);
					}
					CheckOutResult = ECommandResult::Failed;
				};

			// Get States as a single operation
			TArray<FSourceControlStateRef> SourceControlStates;
			ECommandResult::Type IntermediateResult = SourceControlProvider.GetState(PkgsToCheckOut, SourceControlStates, EStateCacheUsage::Use);
			if (IntermediateResult == ECommandResult::Succeeded)
			{
				TArray<UPackage*> PkgsToRevert;
				PkgsToRevert.Reserve(PkgsToCheckOut.Num());
				for (int Index = 0; Index < SourceControlStates.Num(); ++Index)
				{
					const FSourceControlStateRef& SourceControlState = SourceControlStates[Index];
					if (SourceControlState->IsDeleted())
					{
						PkgsToRevert.Add(PkgsToCheckOut[Index]);
					}
				}

				if (PkgsToRevert.Num() > 0)
				{
					IntermediateResult = SourceControlProvider.Execute(ISourceControlOperation::Create<FRevert>(), PkgsToRevert);
					if (IntermediateResult == ECommandResult::Succeeded)
					{
						// Force update all states to checkout
						IntermediateResult = SourceControlProvider.GetState(PkgsToCheckOut, SourceControlStates, EStateCacheUsage::ForceUpdate);
					}
				}

				// In case we called GetState after a revert 
				if (IntermediateResult == ECommandResult::Succeeded)
				{
					// Assemble a final list of packages to check out
					for (int32 Index = 0; Index < PkgsToCheckOut.Num(); ++Index)
					{
						UPackage* PackageToCheckOut = PkgsToCheckOut[Index];
						const FSourceControlStateRef& SourceControlState = SourceControlStates[Index];

						FString CheckOutUser;
						if (SourceControlState->IsCheckedOutOther(&CheckOutUser))
						{
							CheckOutUsers.Add(PackageToCheckOut->GetName(), CheckOutUser);
						}

						// Mark the package for check out if possible
						bool bShowCheckoutError = true;
						if (SourceControlState->CanCheckout())
						{
							bShowCheckoutError = false;
							FinalPackageCheckoutList.Add(PackageToCheckOut);
						}
						else if (SourceControlState->CanAdd())
						{
							// Cannot add unsaved packages to source control
							FString Filename;
							if (FPackageName::DoesPackageExist(PackageToCheckOut->GetName(), &Filename))
							{
								bShowCheckoutError = false;
								FinalPackageMarkForAddList.Add(PackageToCheckOut);
							}
							else
							{
								// Silently skip package that has not been saved yet
								// Expected when called by InternalCheckoutAndSavePackages before packages saved
								bShowCheckoutError = false;
							}
						}
						else if (SourceControlState->IsAdded())
						{
							if (!bErrorIfAlreadyCheckedOut)
							{
								bShowCheckoutError = false;
							}
						}
						else if (!bErrorIfAlreadyCheckedOut && SourceControlState->IsCheckedOut() && !SourceControlState->IsCheckedOutOther())
						{
							bShowCheckoutError = false;
						}

						// If the package couldn't be checked out, log it so the list of failures can be displayed afterwards
						if (bShowCheckoutError)
						{
							const FString PackageToCheckOutName = PackageToCheckOut->GetName();
							PkgsWhichFailedCheckout += FString::Printf(TEXT("\n%s"), *PackageToCheckOutName);
							CheckOutResult = ECommandResult::Failed;
						}
					}
				}
			}

			if (IntermediateResult != ECommandResult::Succeeded)
			{
				FailedIntermediateOperations();
			}
		}

		// Attempt to check out each package the user specified to be checked out that is not read only
		if (FinalPackageCheckoutList.Num() > 0)
		{
			FScopedSlowTask SlowTask(static_cast<float>(FinalPackageCheckoutList.Num()), NSLOCTEXT("ToolsLibrary", "CheckingOutPackages", "Checking out packages..."));
			SlowTask.MakeDialog();
			CheckOutResult = SourceControlProvider.Execute(ISourceControlOperation::Create<FCheckOut>(), FinalPackageCheckoutList);
			SlowTask.EnterProgressFrame(static_cast<float>(FinalPackageCheckoutList.Num()));
		}

		// Attempt to mark for add each package the user specified that is not already tracked by source control
		ECommandResult::Type MarkForAddResult = ECommandResult::Cancelled;
		if (FinalPackageMarkForAddList.Num() > 0)
		{
			MarkForAddResult = SourceControlProvider.Execute(ISourceControlOperation::Create<FMarkForAdd>(), FinalPackageMarkForAddList);
		}

		TArray<UPackage*> CombinedPackageList = FinalPackageCheckoutList;
		CombinedPackageList.Append(FinalPackageMarkForAddList);

		if (CombinedPackageList.Num() > 0)
		{
			{
				// Checked out some or all files successfully, so check their state
				for (int32 i = 0; i < CombinedPackageList.Num(); ++i)
				{
					const bool bCheckedOut = (i < FinalPackageCheckoutList.Num()) && (CheckOutResult != ECommandResult::Cancelled);
					const bool bMarkedForAdd = (i >= FinalPackageMarkForAddList.Num()) && (MarkForAddResult != ECommandResult::Cancelled);
					if (!(bCheckedOut || bMarkedForAdd))
					{
						continue;
					}

					UPackage* CurPackage = CombinedPackageList[i];

					FSourceControlStatePtr SourceControlState = SourceControlProvider.GetState(CurPackage, EStateCacheUsage::Use);
					if (SourceControlState.IsValid() && (SourceControlState->IsCheckedOut() || SourceControlState->IsAdded()))
					{
						if (OutPackagesCheckedOut)
						{
							OutPackagesCheckedOut->Add(CurPackage);
						}
					}
					else
					{
						CheckOutResult = ECommandResult::Failed;
					}
				}
			}
		}

		return CheckOutResult;
	}

	bool AutoCheckoutObjWithSave(UObject* ObjToCheckOut, FString* CheckOutUser = nullptr)
	{
		// save
		UPackage* Package = ObjToCheckOut->GetPackage();
		TMap<FString, FString> CheckOutUsers;
		ECommandResult::Type CheckoutRes = Utils::CheckoutPackages({ Package }, NULL, false, CheckOutUsers);
		if (CheckoutRes == ECommandResult::Succeeded)
		{
			const FString PackageName = Package->GetName();
			FString PackageExtension = FPackageName::GetAssetPackageExtension();
			if (Package->ContainsMap())
			{
				PackageExtension = FPackageName::GetMapPackageExtension();
			}
			const FString PackageFileName = FPackageName::LongPackageNameToFilename(PackageName, PackageExtension);
			FSavePackageArgs SaveArgs;
			{
				SaveArgs.TopLevelFlags = RF_Public | RF_Standalone;
				SaveArgs.SaveFlags = SAVE_NoError;
			}
			const bool bSucceeded = UPackage::SavePackage(Package, nullptr, *PackageFileName, SaveArgs);
			return true;
		}
		if (CheckOutUser)
		{
			for (auto Username : CheckOutUsers)
			{
				*CheckOutUser += "," + Username.Value;
			}
		}
		UE_LOG(LogTemp, Display, TEXT("Failed to check out: %s"), *ObjToCheckOut->GetPathName());
		return false;
	}
}

void FToolsLibrary::ExecuteAllTexture(bool bAutoCheckOut, bool bShowDialog)
{
	FAssetRegistryModule* const AssetRegistryModule = FModuleManager::Get().GetModulePtr<FAssetRegistryModule>("AssetRegistry");
	if (!AssetRegistryModule)
	{
		return;
	}
	const IAssetRegistry& AssetRegistry = AssetRegistryModule->Get();

	// 暂时去除掉特效贴图
	FARFilter Filter;
	Filter.PackagePaths.Add("/Game/Arts");
	Filter.ClassPaths.Add(UTexture::StaticClass()->GetClassPathName());
	Filter.bRecursivePaths = true;
	Filter.bRecursiveClasses = true;
	TArray<FAssetData> TextureAssets;
	AssetRegistry.GetAssets(Filter, TextureAssets);

	int32 Count = 0;
	UResourceCheckSubsystem* Subsystem = GEditor->GetEditorSubsystem<UResourceCheckSubsystem>();
	Subsystem->CheckAssetsByFunction(TextureAssets, ERMCheckRuleRange::ResourceCheck);
	Subsystem->RepairCheckedAssets();
	for (auto& TextureAsset : TextureAssets)
	{
		FString Path = TextureAsset.GetObjectPathString();
		UObject* TextureObj = LoadObject<UObject>(nullptr, *Path);
		UPackage* TexturePackage = TextureAsset.GetPackage();
		if (TextureObj && TexturePackage && bAutoCheckOut)
		{
			if(TexturePackage->IsDirty())
			{
				Count += 1;
				Utils::AutoCheckoutObjWithSave(TextureObj);
			}
		}
	}
	if(bShowDialog)
	{
		FString Dialog = FString::Printf(TEXT("Successfully handle %d Textures"), Count);
		FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(Dialog));
	}
}

void FToolsLibrary::ExecuteAllDuplicateGuid(bool bAutoCheckOut)
{
	FAssetRegistryModule* const AssetRegistryModule = FModuleManager::Get().GetModulePtr<FAssetRegistryModule>("AssetRegistry");
	if (!AssetRegistryModule)
	{
		return;
	}
	const IAssetRegistry& AssetRegistry = AssetRegistryModule->Get();

	FARFilter Filter;
	Filter.PackagePaths.Add("/Game");
	Filter.ClassPaths.Add(UTexture::StaticClass()->GetClassPathName());
	Filter.bRecursivePaths = true;
	Filter.bRecursiveClasses = true;
	TArray<FAssetData> TextureAssets;
	AssetRegistry.GetAssets(Filter, TextureAssets);
	TSet<FGuid> Guids;
	for (auto TextureAsset : TextureAssets) {
		if (auto Texture = Cast<UTexture>(TextureAsset.GetAsset()))
		{
			if (!Guids.Contains(Texture->GetLightingGuid()))
			{
				Guids.Add(Texture->GetLightingGuid());
			}
			else
			{
				Texture->Modify();
				while (Guids.Contains(Texture->GetLightingGuid()))
				{
					Texture->SetLightingGuid();
				}
				Texture->MarkPackageDirty();
				Guids.Add(Texture->GetLightingGuid());
				if (bAutoCheckOut)
				{
					Utils::AutoCheckoutObjWithSave(Texture);
				}
			}
		}
	}
}

void FToolsLibrary::ExecuteAllStaticMeshLODAdapter(FString ExecutePaths, bool bAutoCheckOut)
{
	ExecuteAllStaticMeshLOD(ExecutePaths, bAutoCheckOut);
}

void FToolsLibrary::ExecuteAllStaticMeshLOD(const FString& ExecutePaths, bool bAutoCheckOut)
{
	FStaticMeshEditorExtenderModule* const StaticMeshExtenderModule = FModuleManager::Get().GetModulePtr<FStaticMeshEditorExtenderModule>("StaticMeshEditorExtender");
	TSharedPtr<FStaticMeshEditorExtenderManager> StaticMeshExtenderMgr = StaticMeshExtenderModule->Manager;
	if (!StaticMeshExtenderMgr || !StaticMeshExtenderMgr->ReadConfig())
	{
		UE_LOG(LogTemp, Error, TEXT("Can't Get StaticMeshExtenderManager."));
		return;
	}

	FAssetRegistryModule* const AssetRegistryModule = FModuleManager::Get().GetModulePtr<FAssetRegistryModule>("AssetRegistry");
	if (!AssetRegistryModule)
	{
		return;
	}
	const IAssetRegistry& AssetRegistry = AssetRegistryModule->Get();

	TArray<FString> Paths;
	ExecutePaths.ParseIntoArray(Paths, TEXT("|"));

	FARFilter Filter;
	for (auto& Path : Paths)
	{
		Filter.PackagePaths.Add(*Path);
	}
	Filter.ClassPaths.Add(UStaticMesh::StaticClass()->GetClassPathName());
	Filter.bRecursivePaths = true;
	Filter.bRecursiveClasses = true;
	TArray<FAssetData> StaticMeshAssets;
	AssetRegistry.GetAssets(Filter, StaticMeshAssets);

	int32 Count = 0;
	UResourceCheckSubsystem* Subsystem = GEditor->GetEditorSubsystem<UResourceCheckSubsystem>();
	Subsystem->CheckAssetsByFunction(StaticMeshAssets, ERMCheckRuleRange::ResourceCheck);
	TMap<FAssetData, TArray<FResourceCheckLogInfo>> LogInfosDict;
	Subsystem->GetAssetDataLogInfo(LogInfosDict);
	TArray<FAssetData> LODAssetDatas;
	for(auto KV : LogInfosDict)
	{
		auto AssetData = KV.Key;
		auto& LogInfos = KV.Value;
		if(LogInfos.Num() > 0)
		{
			LODAssetDatas.Add(AssetData);
		}
	}					
	
	int32 Total = LODAssetDatas.Num();
#if WITH_EDITOR
	GWarn->BeginSlowTask(INVTEXT("Fixing staticmesh LOD"), true);
#endif

	TArray<FString> CheckoutFailurePaths;

	for (auto& StaticMeshAsset : LODAssetDatas)
	{
		FString Path = StaticMeshAsset.GetObjectPathString();
		CheckoutFailurePaths.Add(Path);
		UObject* SMObj = LoadObject<UObject>(nullptr, *Path);
		if (SMObj)
		{
			auto StaticMeshObj = StaticCast<UStaticMesh*>(SMObj);

			if (!StaticMeshObj)
			{
				UE_LOG(LogTemp, Error, TEXT("Static mesh cast failed."));
				continue;
			}

			StaticMeshExtenderMgr->AutoFix(StaticMeshObj, false, false);

			if (bAutoCheckOut)
			{
				if (!Utils::AutoCheckoutObjWithSave(StaticMeshObj))
				{
					CheckoutFailurePaths.Add(Path);
				}
			}
			
			UE_LOG(LogTemp, Display, TEXT("Asset:%s fixed"), *StaticMeshObj->GetName());
			Count++;
#if WITH_EDITOR
			GWarn->UpdateProgress(Count, Total);
#endif
		}
	}
#if WITH_EDITOR
	GWarn->EndSlowTask();
#endif
	FString FailurePathsFile = FPaths::ProjectSavedDir() + "/Tools/StaticMeshAutoFixFailurePaths.csv";
	FFileHelper::SaveStringArrayToFile(CheckoutFailurePaths, *FailurePathsFile);
}

void FToolsLibrary::FixAllStaticMeshLODScreenSize(bool bAutoCheckOut)
{
	FAssetRegistryModule* const AssetRegistryModule = FModuleManager::Get().GetModulePtr<FAssetRegistryModule>("AssetRegistry");
	if (!AssetRegistryModule)
	{
		return;
	}
	const IAssetRegistry& AssetRegistry = AssetRegistryModule->Get();

	UClass* BlueprintClass = LoadClass<UEditorUtilityWidgetBlueprint>(NULL, TEXT("WidgetBlueprint'/Game/Editor/ModelEditor/Tools/Tools.Tools_C'"));
	UObject* Blueprint = UEditorAssetLibrary::LoadAsset(FString(TEXT("/Script/Blutility.EditorUtilityWidgetBlueprint'/Game/Editor/ModelEditor/Tools/Tools.Tools'")));
	if (IsValid(Blueprint))
	{
		UEditorUtilityWidgetBlueprint* EditorWidget = Cast<UEditorUtilityWidgetBlueprint>(Blueprint);
		if (IsValid(EditorWidget))
		{
			if (!EditorWidget->GetCreatedWidget())
			{
				EditorWidget->CreateUtilityWidget();
			}

			if (EditorWidget->GetCreatedWidget())
			{
				// 处理所有 StaticMesh
				TArray<FAssetData> StaticMeshAssetDatas;
				FARFilter Filter;
				Filter.PackagePaths.Add("/Game/Arts");
				Filter.ClassPaths.Add(UStaticMesh::StaticClass()->GetClassPathName());
				Filter.bRecursivePaths = true;
				Filter.bRecursiveClasses = true;
				StaticMeshAssetDatas.Empty();
				AssetRegistry.GetAssets(Filter, StaticMeshAssetDatas);
				
				if(UResourceCheckSubsystem* Subsystem = GEditor->GetEditorSubsystem<UResourceCheckSubsystem>())
				{
					Subsystem->CheckAssetsByFunction(StaticMeshAssetDatas, ERMCheckRuleRange::ResourceCheck);
					TMap<FAssetData, TArray<FResourceCheckLogInfo>> LogInfosDict;
					Subsystem->GetAssetDataLogInfo(LogInfosDict);
					TArray<FAssetData> LODAssetDatas;
					for(auto KV : LogInfosDict)
					{
						auto AssetData = KV.Key;
						auto& LogInfos = KV.Value;
						for(auto LogInfo : LogInfos)
						{
							if(LogInfo.Tag == TEXT("LODScreenSize"))
							{
								LODAssetDatas.Add(AssetData);
							}
						}
					}
					
					if (!LODAssetDatas.IsEmpty())
					{
						UFunction* Func = EditorWidget->GetCreatedWidget()->FindFunction(FName("SetAssetsLODScreenSize"));
						if (Func)
						{
							struct FuncParams
							{
								TArray<UObject*> Assets;
								void GetAssets(TArray<FAssetData> InAssetDatas)
								{
									for(auto AssetData : InAssetDatas)
									{
										if(auto Asset = AssetData.GetAsset())
										{
											Assets.Add(Asset);
										}
									}
								}
							};
							FuncParams Params;
							
							Params.GetAssets(LODAssetDatas);
							EditorWidget->GetCreatedWidget()->ProcessEvent(Func, &Params);
						}
					}
				}
			}
		}
	}
}

void FToolsLibrary::OnInspectionFinished(ASceneInspectionActor* SceneInspectionActor)
{
	FSceneInspectionEditorModule& SceneInspectionModule = FModuleManager::GetModuleChecked<FSceneInspectionEditorModule>("SceneInspectionEditor");
	SceneInspectionModule.OpenSceneInspection(SceneInspectionActor);
}

void FToolsLibrary::ExportNavmeshSampleData()
{
	FSceneInspection::ExportNavmeshSampleData(GEditor->GetEditorWorldContext().World());
}

void FToolsLibrary::CompileAllAssets()
{
	 
}

UTexture2D* GenerateTexture(const FString& PackageName, const FString& TextureAssetName, int32 Width, int32 Height, const TArray<FColor>& Colors, UTexture2D* OldTexture)
{
	UPackage* Package = CreatePackage(*PackageName);
	check(Package);
	Package->FullyLoad();
	Package->Modify();

	UTexture2D* Texture = NewObject<UTexture2D>(Package, *TextureAssetName, RF_Public | RF_Standalone);
	//Source 
	Texture->MipGenSettings = TextureMipGenSettings::TMGS_NoMipmaps;
	Texture->Source.Init(Width, Height, 1, 1, ETextureSourceFormat::TSF_BGRA8);
	uint8* SourceData = Texture->Source.LockMip(0);
	FMemory::Memcpy(SourceData, Colors.GetData(), sizeof(FColor) * Colors.Num());
	Texture->Source.UnlockMip(0);

	//PlatformData
	FTexturePlatformData* PlatformData = new FTexturePlatformData();
	Texture->SetPlatformData(PlatformData);
	PlatformData->SizeX = Width;
	PlatformData->SizeY = Height;
	PlatformData->PixelFormat = EPixelFormat::PF_B8G8R8A8;
	FTexture2DMipMap* NewMipMap = new FTexture2DMipMap();
	PlatformData->Mips.Add(NewMipMap);
	NewMipMap->SizeX = Width;
	NewMipMap->SizeY = Height;

	Texture->GetPlatformData()->Mips[0].BulkData.Lock(LOCK_READ_WRITE);
	uint8* NewMipData = (uint8*)Texture->GetPlatformData()->Mips[0].BulkData.Realloc(sizeof(FColor) * Width * Height);
	FMemory::Memcpy(NewMipData, Colors.GetData(), sizeof(FColor) * Colors.Num());
	Texture->GetPlatformData()->Mips[0].BulkData.Unlock();

	Texture->CompressionSettings = OldTexture->CompressionSettings;
	Texture->MipGenSettings = OldTexture->MipGenSettings;
	Texture->SRGB = OldTexture->SRGB;
	Texture->LODGroup = OldTexture->LODGroup;

	Texture->UpdateResource();
	Package->MarkPackageDirty();
	ISourceControlProvider& SourceControlProvider = ISourceControlModule::Get().GetProvider();
	Utils::AutoCheckoutObjWithSave(Texture);
	auto MarkForAddResult = SourceControlProvider.Execute(ISourceControlOperation::Create<FMarkForAdd>(), Package);
	return Texture;
}

void FToolsLibrary::SplitTexture(UTexture* InTexture)
{
	if (UTexture2D* OldTexture = Cast<UTexture2D>(InTexture))
	{
		OldTexture->PreEditChange(nullptr);

		const FString OldTexturePackageName = OldTexture->GetPackage()->GetName();
		FString NewTexturePackagePath = FPackageName::GetLongPackagePath(OldTexturePackageName);
		FString OldTextureName = OldTexture->GetName();
		int32 LastCharIndex;
		OldTextureName.FindLastChar('_', LastCharIndex);
		if (LastCharIndex != INDEX_NONE)
		{
			OldTextureName = OldTextureName.Left(LastCharIndex);
		}
		FString NormalMapTextureAssetName = OldTextureName + TEXT("_N");
		FString MixMapTextureAssetName = OldTextureName + TEXT("_M");

		UPackage* TextureAPackage = CreatePackage(*(NewTexturePackagePath / NormalMapTextureAssetName));
		TextureAPackage->FullyLoad();
		if (UObject* Object = StaticFindObject(nullptr, TextureAPackage, *NormalMapTextureAssetName))
		{
			FText message = FText::FromString(TEXT("拆分失败，贴图已经存在!"));
			FMessageDialog::Open(EAppMsgType::Ok, message);
			OldTexture->PostEditUndo();
			OldTexture->GetPackage()->SetDirtyFlag(false);
			return;
		}

		UPackage* TextureBPackage = CreatePackage(*(NewTexturePackagePath / MixMapTextureAssetName));
		TextureAPackage->FullyLoad();
		if (UObject* Object = StaticFindObject(nullptr, TextureBPackage, *MixMapTextureAssetName))
		{
			FText message = FText::FromString(TEXT("拆分失败，贴图已经存在!"));
			FMessageDialog::Open(EAppMsgType::Ok, message);
			OldTexture->PostEditUndo();
			OldTexture->GetPackage()->SetDirtyFlag(false);
			return;
		}

		FString NormalMapPackageName = FPaths::Combine(NewTexturePackagePath, NormalMapTextureAssetName);
		FString MixMapPackageName = FPaths::Combine(NewTexturePackagePath, MixMapTextureAssetName);

		auto OldCompressionSettings = OldTexture->CompressionSettings;
		auto OldMipGenSettings = OldTexture->MipGenSettings;
		auto OldSRGB = OldTexture->SRGB;

		OldTexture->CompressionSettings = TC_VectorDisplacementmap;
		OldTexture->MipGenSettings = TMGS_NoMipmaps;
		OldTexture->SRGB = false;
		OldTexture->UpdateResource();
		FTexture2DMipMap& OldMipMap = OldTexture->GetPlatformData()->Mips[0];
		uint8* OldMipData = (uint8*)OldMipMap.BulkData.Lock(LOCK_READ_ONLY);

		if (!OldMipData)
		{
			UE_LOG(LogTemp, Warning, TEXT("Get SourceMipData Failed, The Texture Is %s"), *OldTexturePackageName)
				return;
		}
		FColor* OldColorData = (FColor*)OldMipData;
		const int32 Width = OldTexture->GetPlatformData()->Mips[0].SizeX;
		const int32 Height = OldTexture->GetPlatformData()->Mips[0].SizeY;

		TArray<FColor> SourceNormalMapColors;
		SourceNormalMapColors.Init(FColor::White, Width * Height);
		for (int32 Y = 0; Y < Height; ++Y)
		{
			for (int32 X = 0; X < Width; ++X)
			{
				// 将R通道的值设置为1
				uint8 R = OldColorData[Y * Width + X].R;
				uint8 G = OldColorData[Y * Width + X].G;
				float FloatR = FColor::DequantizeUNorm8ToFloat(R);
				float FloatG = FColor::DequantizeUNorm8ToFloat(G);
				float TempR = (FloatR - 0.5f) * 2.f;
				float TempG = (FloatG - 0.5f) * 2.f;
				float TempB = FMath::Sqrt(1.f - FMath::Clamp(TempR * TempR + TempG * TempG, 0.f, 1.f));
				SourceNormalMapColors[Y * Width + X].R = R;
				SourceNormalMapColors[Y * Width + X].G = G;
				SourceNormalMapColors[Y * Width + X].B = FColor::QuantizeUNormFloatTo8((TempB + 1.f) * 0.5);
				SourceNormalMapColors[Y * Width + X].A = 255;
			}
		}

		bool bIsMixWhite = true;
		TArray<FColor> SourceMixMapColors;
		SourceMixMapColors.Init(FColor::White, Width * Height);
		for (int32 Y = 0; Y < Height; ++Y)
		{
			for (int32 X = 0; X < Width; ++X)
			{
				// 将R通道的值设置为1
				SourceMixMapColors[Y * Width + X].R = 255;
				SourceMixMapColors[Y * Width + X].G = OldColorData[Y * Width + X].B;
				SourceMixMapColors[Y * Width + X].B = OldColorData[Y * Width + X].A;
				SourceMixMapColors[Y * Width + X].A = 255;
				if (bIsMixWhite && (SourceMixMapColors[Y * Width + X].G != 255 || SourceMixMapColors[Y * Width + X].B != 255))
				{
					bIsMixWhite = false;
				}
			}
		}

		OldMipMap.BulkData.Unlock();
		OldTexture->CompressionSettings = OldCompressionSettings;
		OldTexture->MipGenSettings = OldMipGenSettings;
		OldTexture->SRGB = OldSRGB;
		OldTexture->PostEditUndo();

		UTexture2D* NormalTexture = GenerateTexture(NormalMapPackageName, NormalMapTextureAssetName, Width, Height, SourceNormalMapColors, OldTexture);
		NormalTexture->PreEditChange(nullptr);
		NormalTexture->CompressionSettings = TC_Normalmap;
		Utils::AutoCheckoutObjWithSave(NormalTexture);

		UTexture2D* MixTexture = GenerateTexture(MixMapPackageName, MixMapTextureAssetName, Width, Height, SourceMixMapColors, OldTexture);
		MixTexture->LODGroup = TEXTUREGROUP_WorldSpecular;
		Utils::AutoCheckoutObjWithSave(MixTexture);

		OldTexture->GetPackage()->SetDirtyFlag(false);
	}
}

FColor* GetColorData(UTexture2D* InTexture, int32& OutWidth, int32& OutHeight)
{
	auto OldCompressionSettings = InTexture->CompressionSettings;
	auto OldMipGenSettings = InTexture->MipGenSettings;
	auto OldSRGB = InTexture->SRGB;

	InTexture->CompressionSettings = TC_VectorDisplacementmap;
	InTexture->MipGenSettings = TMGS_NoMipmaps;
	InTexture->SRGB = false;
	InTexture->UpdateResource();
	FTexture2DMipMap& OldMipMap = InTexture->GetPlatformData()->Mips[0];
	uint8* OldMipData = (uint8*)OldMipMap.BulkData.Lock(LOCK_READ_ONLY);

	if (!OldMipData)
	{
		return nullptr;
	}
	FColor* OutColorData = (FColor*)OldMipData;
	OutWidth = InTexture->GetPlatformData()->Mips[0].SizeX;
	OutHeight = InTexture->GetPlatformData()->Mips[0].SizeY;

	OldMipMap.BulkData.Unlock();
	InTexture->CompressionSettings = OldCompressionSettings;
	InTexture->MipGenSettings = OldMipGenSettings;
	InTexture->SRGB = OldSRGB;
	InTexture->PostEditUndo();
	InTexture->GetPackage()->SetDirtyFlag(false);
	return OutColorData;
}

void FToolsLibrary::ReplaceLandscapeTexture(UTexture2DArray* InDArray, UTexture2DArray* InNRHArray)
{
	if (InDArray->SourceTextures.Num() != InNRHArray->SourceTextures.Num())
	{
		return;
	}
	const int32 TextureNum = InDArray->SourceTextures.Num();

	TMap<int32, int32> DuplicateMap;

	for (int32 i = 0; i < TextureNum; ++i)
	{
		UTexture2D* DTexture = InDArray->SourceTextures[i];
		UTexture2D* NRHTexture = InNRHArray->SourceTextures[i];
		bool bDuplicateD = InDArray->SourceTextures.Find(DTexture) != i;
		bool bDuplicateNRH = InNRHArray->SourceTextures.Find(NRHTexture) != i;
		// 如果重复的话，判断下是否两边都重复
		if (bDuplicateD && bDuplicateNRH)
		{
			DuplicateMap.Add(i, InDArray->SourceTextures.Find(DTexture));
			continue;
		}
		if (bDuplicateD || bDuplicateNRH)
		{
			FText message = FText::FromString(TEXT("Texture Array存在重复贴图，替换失败!"));
			FMessageDialog::Open(EAppMsgType::Ok, message);
			return;
		}
		if (InNRHArray->SourceTextures.Find(DTexture) != INDEX_NONE || InDArray->SourceTextures.Find(NRHTexture) != INDEX_NONE)
		{
			FText message = FText::FromString(TEXT("Texture Array存在重复贴图，替换失败!"));
			FMessageDialog::Open(EAppMsgType::Ok, message);
			return;
		}
	}

	TArray<TObjectPtr<UTexture2D>> SourceColorTextures;
	TArray<TObjectPtr<UTexture2D>> SourceNormalTextures;

	// 生成新的Normal和Color Texture
	for (int32 i = 0; i < TextureNum; ++i)
	{
		if (DuplicateMap.Contains(i))
		{
			TObjectPtr<UTexture2D> DuplicateColorTexture = SourceColorTextures[DuplicateMap[i]];
			TObjectPtr<UTexture2D> DuplicateNormalTexture = SourceNormalTextures[DuplicateMap[i]];
			SourceColorTextures.Add(DuplicateColorTexture);
			SourceNormalTextures.Add(DuplicateNormalTexture);
			continue;
		}
		UTexture2D* DTexture = InDArray->SourceTextures[i];
		UTexture2D* NRHTexture = InNRHArray->SourceTextures[i];

		DTexture->PreEditChange(nullptr);

		const FString DTexturePackageName = DTexture->GetPackage()->GetName();
		FString DTexturePackagePath = FPackageName::GetLongPackagePath(DTexturePackageName);
		FString DTextureName = DTexture->GetName();
		FString ColorTextureAssetName = TEXT("New_") + DTextureName;

		UPackage* TextureAPackage = CreatePackage(*(DTexturePackagePath / ColorTextureAssetName));
		TextureAPackage->FullyLoad();
		FString ColorPackageName = FPaths::Combine(DTexturePackagePath, ColorTextureAssetName);
		if (UObject* Object = StaticFindObject(nullptr, TextureAPackage, *ColorTextureAssetName))
		{
			FText message = FText::FromString(FString::Format(TEXT("拆分失败，贴图已经存在! {0}"), { ColorPackageName }));
			FMessageDialog::Open(EAppMsgType::Ok, message);
			DTexture->PostEditUndo();
			DTexture->GetPackage()->SetDirtyFlag(false);
			return;
		}

		NRHTexture->PreEditChange(nullptr);

		const FString NRHTexturePackageName = NRHTexture->GetPackage()->GetName();
		FString NRHTexturePackagePath = FPackageName::GetLongPackagePath(NRHTexturePackageName);
		FString NRHTextureName = NRHTexture->GetName();

		FString NormalTextureAssetName = TEXT("New_") + NRHTextureName;

		UPackage* TextureBPackage = CreatePackage(*(NRHTexturePackagePath / NormalTextureAssetName));
		TextureBPackage->FullyLoad();
		FString NormalPackageName = FPaths::Combine(NRHTexturePackagePath, NormalTextureAssetName);
		if (UObject* Object = StaticFindObject(nullptr, TextureBPackage, *NormalTextureAssetName))
		{
			FText message = FText::FromString(FString::Format(TEXT("拆分失败，贴图已经存在! {0}"), { NormalPackageName }));
			FMessageDialog::Open(EAppMsgType::Ok, message);
			DTexture->PostEditUndo();
			DTexture->GetPackage()->SetDirtyFlag(false);
			NRHTexture->PostEditUndo();
			NRHTexture->GetPackage()->SetDirtyFlag(false);
			return;
		}

		int32 DWidth, DHeight, NRHWidth, NRHHeight;
		FColor* DColorData = GetColorData(DTexture, DWidth, DHeight);
		FColor* NRHColorData = GetColorData(NRHTexture, NRHWidth, NRHHeight);

		if (DWidth != NRHWidth || DHeight != NRHHeight)
		{
			FText message = FText::FromString(FString::Format(TEXT("拆分失败，贴图大小不一致! {0}, {1}"), { DTextureName, NRHTextureName }));
			FMessageDialog::Open(EAppMsgType::Ok, message);
			DTexture->PostEditUndo();
			DTexture->GetPackage()->SetDirtyFlag(false);
			NRHTexture->PostEditUndo();
			NRHTexture->GetPackage()->SetDirtyFlag(false);
			return;
		}

		TArray<FColor> SourceNormalColors, SourceColorColors;
		SourceNormalColors.Init(FColor::White, DWidth * DHeight);
		SourceColorColors.Init(FColor::White, DWidth * DHeight);
		for (int32 Y = 0; Y < DHeight; ++Y)
		{
			for (int32 X = 0; X < DWidth; ++X)
			{
				SourceNormalColors[Y * DWidth + X].R = NRHColorData[Y * DWidth + X].R;
				SourceNormalColors[Y * DWidth + X].G = NRHColorData[Y * DWidth + X].G;
				SourceNormalColors[Y * DWidth + X].B = 255;
				SourceNormalColors[Y * DWidth + X].A = DColorData[Y * DWidth + X].A;

				SourceColorColors[Y * DWidth + X].R = DColorData[Y * DWidth + X].R;
				SourceColorColors[Y * DWidth + X].G = DColorData[Y * DWidth + X].G;
				SourceColorColors[Y * DWidth + X].B = DColorData[Y * DWidth + X].B;
				SourceColorColors[Y * DWidth + X].A = NRHColorData[Y * DWidth + X].B;
			}
		}

		UTexture2D* NormalTexture = GenerateTexture(NormalPackageName, NormalTextureAssetName, DWidth, DHeight, SourceNormalColors, NRHTexture);
		Utils::AutoCheckoutObjWithSave(NormalTexture);

		UTexture2D* ColorTexture = GenerateTexture(ColorPackageName, ColorTextureAssetName, DWidth, DHeight, SourceColorColors, DTexture);
		Utils::AutoCheckoutObjWithSave(ColorTexture);

		SourceColorTextures.Add(ColorTexture);
		SourceNormalTextures.Add(NormalTexture);
	}

	// 组合成新的Texture Array
	FString SourceDName = InDArray->GetName();
	FString PackagePath = FPackageName::GetLongPackagePath(InDArray->GetPackage()->GetName());
	FString AssetName = TEXT("New_") + SourceDName;
	FAssetToolsModule& AssetToolsModule = FModuleManager::Get().LoadModuleChecked<FAssetToolsModule>("AssetTools");
	UObject* DuplicatedObject = AssetToolsModule.Get().DuplicateAsset(AssetName, PackagePath, InDArray);
	UTexture2DArray* Texture2DArray = Cast<UTexture2DArray>(DuplicatedObject);
	Texture2DArray->SourceTextures = SourceColorTextures;
	Utils::AutoCheckoutObjWithSave(DuplicatedObject);

	FString SourceNRHName = InNRHArray->GetName();
	PackagePath = FPackageName::GetLongPackagePath(InNRHArray->GetPackage()->GetName());
	AssetName = TEXT("New_") + SourceNRHName;
	DuplicatedObject = AssetToolsModule.Get().DuplicateAsset(AssetName, PackagePath, InNRHArray);
	Texture2DArray = Cast<UTexture2DArray>(DuplicatedObject);
	Texture2DArray->SourceTextures = SourceNormalTextures;
	Texture2DArray->CompressionNoAlpha = 0;
	Texture2DArray->CompressionSettings = TC_Default;
	Utils::AutoCheckoutObjWithSave(DuplicatedObject);
}

void ReplaceMaterial(UMaterialInterface* InSrcMaterial, UMaterialInterface* InDestMaterial, FName InTextureParameterName)
{
	// 1.先查找所有引用了该Material的Material Instance
	// 2.根据Normal的参数名，找到当前Instance使用的normal贴图，拆分成两张贴图
	// 3.备份Material Instance
	// 4.创建新的Material Instance,并设置新的Material的贴图参数
	// 5.移动旧的贴图
	// 6.移动旧的母材质

	// 1.查找Material Instance
	const FName& Name = InSrcMaterial->GetPackage()->GetFName();
	TArray<UMaterialInstanceConstant*> MaterialInstances;
	const FAssetRegistryModule& AssetRegistryModule = FModuleManager::GetModuleChecked<FAssetRegistryModule>("AssetRegistry");
	TArray<FName> AssetReferencers;
	AssetRegistryModule.Get().GetReferencers(Name, AssetReferencers, UE::AssetRegistry::EDependencyCategory::All);
	for (int32 i = 0; i < AssetReferencers.Num(); ++i)
	{
		TArray<FAssetData> OutAssetData;
		AssetRegistryModule.Get().GetAssetsByPackageName(AssetReferencers[i], OutAssetData);
		if (!OutAssetData.IsEmpty())
		{
			if (UMaterialInstanceConstant* MI = Cast<UMaterialInstanceConstant>(OutAssetData[0].GetAsset()))
			{
				MaterialInstances.Add(MI);
			}
		}
	}

	FAssetToolsModule& AssetToolsModule = FModuleManager::Get().LoadModuleChecked<FAssetToolsModule>("AssetTools");

	// 先把旧贴图存起来，统一处理
	TArray<UTexture2D*> DeprecatedTextures;

	for (int32 i = 0; i < MaterialInstances.Num(); ++i)
	{
		// 2.拆分贴图
		UMaterialInstanceConstant* SourceMaterialInstance = MaterialInstances[i];

		UTexture* OutTexture;
		SourceMaterialInstance->GetTextureParameterValue(InTextureParameterName, OutTexture);

		UTexture2D* NormalTexture = nullptr;
		UTexture2D* MixTexture = nullptr;

		if (OutTexture)
		{
			UTexture2D* OldTexture = Cast<UTexture2D>(OutTexture);
			OldTexture->PreEditChange(nullptr);

			FString OldTexturePackageName = OldTexture->GetPackage()->GetName();
			FString NewTexturePackagePath = FPackageName::GetLongPackagePath(OldTexturePackageName);
			FString OldTextureName = OldTexture->GetName();
			int32 LastCharIndex;
			OldTextureName.FindLastChar('_', LastCharIndex);
			if (LastCharIndex != INDEX_NONE)
			{
				OldTextureName = OldTextureName.Left(LastCharIndex);
			}
			FString NormalMapTextureAssetName = OldTextureName + TEXT("_Split_N");
			FString MixMapTextureAssetName = OldTextureName + TEXT("_Split_M");

			// 如果使用的是Engine目录下的贴图，则将拆分出来的贴图和材质实例放在一个路径下
			if (NewTexturePackagePath.StartsWith(TEXT("/Engine")))
			{
				NewTexturePackagePath = FPackageName::GetLongPackagePath(SourceMaterialInstance->GetPackage()->GetName());
			}

			UPackage* TextureAPackage = CreatePackage(*(NewTexturePackagePath / NormalMapTextureAssetName));
			TextureAPackage->FullyLoad();
			if (UObject* Object = StaticFindObject(nullptr, TextureAPackage, *NormalMapTextureAssetName))
			{
				NormalTexture = Cast<UTexture2D>(Object);
			}

			UPackage* TextureBPackage = CreatePackage(*(NewTexturePackagePath / MixMapTextureAssetName));
			TextureBPackage->FullyLoad();
			if (UObject* Object = StaticFindObject(nullptr, TextureBPackage, *MixMapTextureAssetName))
			{
				MixTexture = Cast<UTexture2D>(Object);
			}

			if (!NormalTexture)
			{
				FString NormalMapPackageName = FPaths::Combine(NewTexturePackagePath, NormalMapTextureAssetName);
				FString MixMapPackageName = FPaths::Combine(NewTexturePackagePath, MixMapTextureAssetName);

				auto OldCompressionSettings = OldTexture->CompressionSettings;
				auto OldMipGenSettings = OldTexture->MipGenSettings;
				auto OldSRGB = OldTexture->SRGB;

				OldTexture->CompressionSettings = TC_VectorDisplacementmap;
				OldTexture->MipGenSettings = TMGS_NoMipmaps;
				OldTexture->SRGB = false;
				OldTexture->UpdateResource();
				FTexture2DMipMap& OldMipMap = OldTexture->GetPlatformData()->Mips[0];
				uint8* OldMipData = (uint8*)OldMipMap.BulkData.Lock(LOCK_READ_ONLY);

				if (!OldMipData)
				{
					UE_LOG(LogTemp, Warning, TEXT("Get SourceMipData Failed, The Texture Is %s"), *OldTexturePackageName)
						continue;
				}
				FColor* OldColorData = (FColor*)OldMipData;
				const int32 Width = OldTexture->GetPlatformData()->Mips[0].SizeX;
				const int32 Height = OldTexture->GetPlatformData()->Mips[0].SizeY;

				TArray<FColor> SourceNormalMapColors;
				SourceNormalMapColors.Init(FColor::White, Width * Height);
				for (int32 Y = 0; Y < Height; ++Y)
				{
					for (int32 X = 0; X < Width; ++X)
					{
						// 将R通道的值设置为1
						uint8 R = OldColorData[Y * Width + X].R;
						uint8 G = OldColorData[Y * Width + X].G;
						float FloatR = FColor::DequantizeUNorm8ToFloat(R);
						float FloatG = FColor::DequantizeUNorm8ToFloat(G);
						float TempR = (FloatR - 0.5f) * 2.f;
						float TempG = (FloatG - 0.5f) * 2.f;
						float TempB = FMath::Sqrt(1.f - FMath::Clamp(TempR * TempR + TempG * TempG, 0.f, 1.f));
						SourceNormalMapColors[Y * Width + X].R = R;
						SourceNormalMapColors[Y * Width + X].G = G;
						SourceNormalMapColors[Y * Width + X].B = FColor::QuantizeUNormFloatTo8((TempB + 1.f) * 0.5);
						SourceNormalMapColors[Y * Width + X].A = 255;
					}
				}

				bool bIsMixWhite = true;
				TArray<FColor> SourceMixMapColors;
				SourceMixMapColors.Init(FColor::White, Width * Height);
				for (int32 Y = 0; Y < Height; ++Y)
				{
					for (int32 X = 0; X < Width; ++X)
					{
						// 将R通道的值设置为1
						SourceMixMapColors[Y * Width + X].R = 255;
						SourceMixMapColors[Y * Width + X].G = OldColorData[Y * Width + X].B;
						SourceMixMapColors[Y * Width + X].B = OldColorData[Y * Width + X].A;
						SourceMixMapColors[Y * Width + X].A = 255;
						if (bIsMixWhite && (SourceMixMapColors[Y * Width + X].G != 255 || SourceMixMapColors[Y * Width + X].B != 255))
						{
							bIsMixWhite = false;
						}
					}
				}

				OldMipMap.BulkData.Unlock();

				OldTexture->CompressionSettings = OldCompressionSettings;
				OldTexture->MipGenSettings = OldMipGenSettings;
				OldTexture->SRGB = OldSRGB;

				OldTexture->PostEditUndo();

				NormalTexture = GenerateTexture(NormalMapPackageName, NormalMapTextureAssetName, Width, Height, SourceNormalMapColors, OldTexture);
				NormalTexture->PreEditChange(nullptr);
				NormalTexture->CompressionSettings = TC_Normalmap;
				Utils::AutoCheckoutObjWithSave(NormalTexture);

				MixTexture = GenerateTexture(MixMapPackageName, MixMapTextureAssetName, Width, Height, SourceMixMapColors, OldTexture);
				MixTexture->LODGroup = TEXTUREGROUP_WorldSpecular;
				Utils::AutoCheckoutObjWithSave(MixTexture);

				// 如果是纯白的Mix，需要记录一下
				if (bIsMixWhite)
				{
					FString Message = MixMapPackageName + "\n";
					FString MessageFileName = FPaths::ProjectDir() + TEXT("Intermediate/MaterialReplace/WhiteMixMap.txt");
					FFileHelper::SaveStringToFile(Message, *MessageFileName, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_Append);
				}
			}
			if (DeprecatedTextures.Find(OldTexture) == INDEX_NONE)
			{
				DeprecatedTextures.Add(OldTexture);
			}
		}

		// 3.拷贝材质实例
		UPackage* SourcePackage = SourceMaterialInstance->GetPackage();

		FString SourceMIName = SourcePackage->GetName();
		FString PackagePath = TEXT("/Game/Arts/MaterialLibrary/MaterialDeprecated/OldInstance");
		FString AssetName = FPackageName::GetLongPackageAssetName(SourceMIName) + TEXT("_Old");
		FString OldPath = FPackageName::GetLongPackagePath(SourceMIName);
		// 材质实例可能会有重名
		FString LongPackageName = PackagePath / AssetName;
		UPackage* Package = CreatePackage(*LongPackageName);
		Package->FullyLoad();
		while (StaticFindObject(nullptr, Package, *AssetName))
		{
			AssetName = FPackageName::GetLongPackageAssetName(OldPath) + TEXT("_") + AssetName;
			LongPackageName = PackagePath / AssetName;
			Package = CreatePackage(*LongPackageName);
			OldPath = FPackageName::GetLongPackagePath(OldPath);
		}

		UObject* DuplicatedObject = AssetToolsModule.Get().DuplicateAsset(AssetName, PackagePath, SourceMaterialInstance);
		Utils::AutoCheckoutObjWithSave(DuplicatedObject);

		// 4.替换材质实例的母材质
		SourceMaterialInstance->Parent = InDestMaterial;
		if (NormalTexture)
		{
			SourceMaterialInstance->SetTextureParameterValueEditorOnly(FName("Normal Map"), NormalTexture);
			SourceMaterialInstance->SetTextureParameterValueEditorOnly(FName("Mix Map"), MixTexture);
		}

		// Dirty the material
		SourceMaterialInstance->MarkPackageDirty();

		// Update the material instance
		SourceMaterialInstance->InitStaticPermutation();
		SourceMaterialInstance->PreEditChange(nullptr);
		SourceMaterialInstance->PostEditChange();

		//保存材质实例
		Utils::AutoCheckoutObjWithSave(SourceMaterialInstance);
	}

	auto FixupReferencers = [&AssetRegistryModule, &AssetToolsModule](const FString& AssetPackagePath, const FString& AssetName)
		{
			// Form a filter from the paths
			FARFilter Filter;
			Filter.bRecursivePaths = true;

			Filter.PackagePaths.Emplace(*AssetPackagePath);

			Filter.ClassPaths.Add(UObjectRedirector::StaticClass()->GetClassPathName());

			// Query for a list of assets in the selected paths
			TArray<FAssetData> AssetList;
			AssetRegistryModule.Get().GetAssets(Filter, AssetList);
			if (AssetList.IsEmpty())
				return;

			TArray<FString> ObjectPaths;
			for (const FAssetData& Asset : AssetList)
			{
				ObjectPaths.Add(Asset.GetObjectPathString());
			}

			TArray<UObject*> Objects;
			AssetViewUtils::FLoadAssetsSettings Settings{
				.bFollowRedirectors = true,
				.bLoadWorldPartitionMaps = false,
				.bLoadAllExternalObjects = false,
			};
			if (AssetViewUtils::LoadAssetsIfNeeded(ObjectPaths, Objects, Settings) == AssetViewUtils::ELoadAssetsResult::Success)
			{
				// Transform Objects array to ObjectRedirectors array
				TArray<UObjectRedirector*> Redirectors;
				for (UObject* Object : Objects)
				{
					if (Object->GetName().StartsWith(AssetName))
					{
						Redirectors.Add(CastChecked<UObjectRedirector>(Object));
					}
				}

				// Load the asset tools module
				AssetToolsModule.Get().FixupReferencers(Redirectors, false);
			}
		};

	// 5.统一移动旧的贴图
	FString DeprecatedTexturePath = TEXT("/Game/Arts/MaterialLibrary/MaterialDeprecated/OldTextures");
	for (int32 i = 0; i < DeprecatedTextures.Num(); ++i)
	{
		UTexture2D* Texture = DeprecatedTextures[i];
		Texture->GetPackage()->SetDirtyFlag(false);
		// if(Texture->GetPackage()->GetName().StartsWith(TEXT("/Engine")))
		// {
		// 	Texture->GetPackage()->SetDirtyFlag(false);
		// }
		// else
		// {
		// 	TArray<FAssetRenameData> AssetsToRename;
		// 	FString NewName = Texture->GetName();
		// 	FString LongPackageName = DeprecatedTexturePath / NewName;
		// 	UPackage* Package = CreatePackage(*LongPackageName);
		// 	while(StaticFindObject( nullptr, Package, *NewName))
		// 	{
		// 		NewName += TEXT("_Old");
		// 		LongPackageName = DeprecatedTexturePath / NewName;
		// 		Package = CreatePackage(*LongPackageName);
		// 	}
		// 	AssetsToRename.Add(FAssetRenameData(Texture, DeprecatedTexturePath, NewName));
		// 	AssetToolsModule.Get().RenameAssets(AssetsToRename);
		// 	// Utils::AutoCheckoutObjWithSave(Texture);
		// }
	}


	// 6.移动旧的母材质
	FString SrcMaterialPackagePath = FPackageName::GetLongPackagePath(InSrcMaterial->GetPackage()->GetName());
	FString SrcMaterialName = FPackageName::GetLongPackageAssetName(InSrcMaterial->GetPackage()->GetName());
	TArray<FAssetRenameData> AssetsToRename;
	FString NewPath = TEXT("/Game/Arts/MaterialLibrary/MaterialDeprecated/OldMasterMaterial");
	FString NewName = InSrcMaterial->GetName() + TEXT("_Old");
	AssetsToRename.Add(FAssetRenameData(InSrcMaterial, NewPath, NewName));
	bool Result = AssetToolsModule.Get().RenameAssets(AssetsToRename);
	Utils::AutoCheckoutObjWithSave(InSrcMaterial);
	// FixupReferencers(SrcMaterialPackagePath, SrcMaterialName);
}

void FToolsLibrary::ReplaceParentMaterial(const FString& InSrcMaterialPath, const FString& InDestMaterialPath, const FName& InTextureParameterName, UObject* InDataAsset)
{
	FString SrcMaterialPath = InSrcMaterialPath;
	if (SrcMaterialPath.Find(".") == INDEX_NONE)
	{
		int32 LastCharIndex;
		SrcMaterialPath.FindLastChar('/', LastCharIndex);
		SrcMaterialPath = SrcMaterialPath + "." + SrcMaterialPath.Right(SrcMaterialPath.Len() - LastCharIndex - 1);
	}
	FString DestMaterialPath = InDestMaterialPath;
	if (DestMaterialPath.Find(".") == INDEX_NONE)
	{
		int32 LastCharIndex;
		DestMaterialPath.FindLastChar('/', LastCharIndex);
		DestMaterialPath = DestMaterialPath + "." + DestMaterialPath.Right(DestMaterialPath.Len() - LastCharIndex - 1);
	}
	if (UMaterialInterface* SrcMaterial = LoadObject<UMaterialInterface>(nullptr, *SrcMaterialPath))
	{
		UMaterialInterface* DestMaterial = LoadObject<UMaterialInterface>(nullptr, *DestMaterialPath);
		ReplaceMaterial(SrcMaterial, DestMaterial, InTextureParameterName);
		Utils::AutoCheckoutObjWithSave(InDataAsset);
	}
}

void FToolsLibrary::ReplaceAllMaterial()
{
	UObject* Blueprint = UEditorAssetLibrary::LoadAsset(FString(TEXT("/Script/UMGEditor.WidgetBlueprint'/Game/Editor/MaterialReplace/Tools.Tools'")));
	if (IsValid(Blueprint)) {
		UEditorUtilityWidgetBlueprint* EditorWidget = Cast<UEditorUtilityWidgetBlueprint>(Blueprint);
		if (IsValid(EditorWidget)) {
			UEditorUtilitySubsystem* EditorUtilitySubsystem = GEditor->GetEditorSubsystem<UEditorUtilitySubsystem>();
			EditorUtilitySubsystem->SpawnAndRegisterTab(EditorWidget);
		}
	}
}

void FToolsLibrary::MergeStaticMeshComponents(TArray<UPrimitiveComponent*> AllComponents, FString SavePathName)
{
	UWorld* World = GEditor->GetEditorWorldContext().World();
	TArray<UObject*>CreatedAssets;
	FVector MergedActorLocation;
	const IMeshMergeUtilities& MeshMergeUtilities = FModuleManager::Get().LoadModuleChecked<IMeshMergeModule>("MeshMergeUtilities").GetUtilities();
	FMeshMergingSettings MergeSettings;
	const float ScreenAreaSize = TNumericLimits<float>::Max();
	MergeSettings.bMergePhysicsData = 1;
	MeshMergeUtilities.MergeComponentsToStaticMesh(AllComponents, World, MergeSettings, nullptr, nullptr, SavePathName, CreatedAssets, MergedActorLocation, ScreenAreaSize, true);

	if (CreatedAssets.Num())
	{
		FAssetRegistryModule& AssetRegistry = FModuleManager::Get().LoadModuleChecked<FAssetRegistryModule>("AssetRegistry");
		int32 AssetCount = CreatedAssets.Num();
		for (int32 AssetIndex = 0; AssetIndex < AssetCount; AssetIndex++)
		{
			AssetRegistry.AssetCreated(CreatedAssets[AssetIndex]);
			GEditor->BroadcastObjectReimported(CreatedAssets[AssetIndex]);
		}

		FContentBrowserModule& ContentBrowserModule = FModuleManager::Get().LoadModuleChecked<FContentBrowserModule>("ContentBrowser");
		ContentBrowserModule.Get().SyncBrowserToAssets(CreatedAssets, true);

		UStaticMesh* MergedMesh = nullptr;
		if (CreatedAssets.FindItemByClass(&MergedMesh))
		{
			FActorSpawnParameters Params;
			FRotator MergedActorRotation(ForceInit);
			AStaticMeshActor* MergedActor = World->SpawnActor<AStaticMeshActor>(MergedActorLocation, MergedActorRotation, Params);
			FName NewPath = TEXT("CollisionGenerate");

			MergedActor->SetFolderPath(NewPath);
			MergedActor->GetStaticMeshComponent()->SetStaticMesh(MergedMesh);
			MergedActor->GetStaticMeshComponent()->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
			MergedActor->SetActorLabel(MergedMesh->GetName());
			MergedActor->SetActorHiddenInGame(true);
			World->UpdateCullDistanceVolumes(MergedActor, MergedActor->GetStaticMeshComponent());
		}
	}
}

void FToolsLibrary::SplitSBBTVActor(AActor* SBBTVActor)
{
	UWorld* World = GEditor->GetEditorWorldContext().World();
	UWorldPartition* WorldPartition = World->GetWorldPartition();

	TArray<USplineMeshComponent*> SplineMeshComponents;
	SBBTVActor->GetComponents<USplineMeshComponent>(SplineMeshComponents);
	FString ActorLabel = SBBTVActor->GetActorLabel();
	FVector StartLocation = SBBTVActor->GetActorLocation();
	FRotator StartRotation = SBBTVActor->GetActorRotation();

	TArray<ASplineMeshActor*> SplineMeshActors;
	for (auto SourceSplineMeshComponent : SplineMeshComponents)
	{
		FActorSpawnParameters Params;
		ASplineMeshActor* DestinationActor = World->SpawnActor<ASplineMeshActor>(StartLocation + SourceSplineMeshComponent->GetStartPosition(), StartRotation, Params);
		SplineMeshActors.Add(DestinationActor);
		FString NewActorName = ActorLabel + TEXT("_") + SourceSplineMeshComponent->GetName();
		DestinationActor->SetActorLabel(NewActorName);
		USplineMeshComponent* SplineMeshComponent = DestinationActor->GetSplineMeshComponent();
		SplineMeshComponent->SetStaticMesh(SourceSplineMeshComponent->GetStaticMesh());
		SplineMeshComponent->SetStartPosition(FVector::Zero());
		SplineMeshComponent->SetEndPosition(SourceSplineMeshComponent->GetEndPosition() - SourceSplineMeshComponent->GetStartPosition());
		SplineMeshComponent->SetStartOffset(SourceSplineMeshComponent->GetStartOffset());
		SplineMeshComponent->SetEndOffset(SourceSplineMeshComponent->GetEndOffset());
		SplineMeshComponent->SetStartRoll(SourceSplineMeshComponent->GetStartRoll());
		SplineMeshComponent->SetEndRoll(SourceSplineMeshComponent->GetEndRoll());
		SplineMeshComponent->SetStartScale(SourceSplineMeshComponent->GetStartScale());
		SplineMeshComponent->SetEndScale(SourceSplineMeshComponent->GetEndScale());
		SplineMeshComponent->SetStartTangent(SourceSplineMeshComponent->GetStartTangent());
		SplineMeshComponent->SetEndTangent(SourceSplineMeshComponent->GetEndTangent());
		SplineMeshComponent->SetSplineUpDir(SourceSplineMeshComponent->GetSplineUpDir());
		SplineMeshComponent->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
	}
	SBBTVActor->bIsEditorOnlyActor = true;
	SBBTVActor->MarkPackageDirty();

	TArray<UPrimitiveComponent*> AllComponents;

	TArray<ASplineMeshActor*> SingledActors;
	TMap<int32, TArray<ASplineMeshActor*>> MergedActors;
	UWorldPartitionRuntimeHash* RuntimeHash = WorldPartition->RuntimeHash;

	UWorldPartitionRuntimeSpatialHash* RuntimeSpatialHash = Cast<UWorldPartitionRuntimeSpatialHash>(RuntimeHash);
	const TArray<FSpatialHashRuntimeGrid>& SpatialGrids = RuntimeSpatialHash->GetGrids();
	int32 CellSize = SpatialGrids[0].CellSize;

	for (ASplineMeshActor* Actor : SplineMeshActors)
	{
		AllComponents.Add(Actor->GetSplineMeshComponent());
		FWorldPartitionActorDesc* NewActorDesc = Actor->CreateActorDesc().Release();
		FBox Bounds = NewActorDesc->GetEditorBounds();
		int32 MinCellCoordX = FMath::FloorToInt(Bounds.Min.X / CellSize);
		int32 MinCellCoordY = FMath::FloorToInt(Bounds.Min.Y / CellSize);
		int32 MaxCellCoordX = FMath::FloorToInt(Bounds.Max.X / CellSize);
		int32 MaxCellCoordY = FMath::FloorToInt(Bounds.Max.Y / CellSize);
		if (MinCellCoordX != MaxCellCoordX || MinCellCoordY != MaxCellCoordY)
		{
			SingledActors.Add(Actor);
		}
		else
		{
			int32 Index = MinCellCoordX * CellSize + MinCellCoordY;
			if (!MergedActors.Contains(Index))
			{
				MergedActors.Add(Index, TArray<ASplineMeshActor*>());
			}
			MergedActors[Index].Add(Actor);
		}
	}

	for (auto Iter = MergedActors.CreateIterator(); Iter; ++Iter)
	{
		TArray<UPrimitiveComponent*> MergedComponents;
		for (ASplineMeshActor* Actor : Iter->Value)
		{
			MergedComponents.Add(Actor->GetSplineMeshComponent());
		}
		FString PackageName = FString::Printf(TEXT("/Game/SBBTV/StaticMeshes/%s/%s_%d_%d"), *World->GetName(), *ActorLabel, Iter->Key / CellSize, Iter->Key % CellSize);

		if (MergedComponents.Num() > 1)
		{
			MergeStaticMeshComponents(MergedComponents, PackageName);
			for (AActor* Actor : Iter->Value)
			{
				Actor->Destroy();
			}
		}
		else
		{
			ASplineMeshActor* Actor = Iter->Value[0];
			FName NewPath = TEXT("CollisionGenerate");
			Actor->SetFolderPath(NewPath);
			FString MergedActorName = FString::Printf(TEXT("%s_%d_%d"), *ActorLabel, Iter->Key / CellSize, Iter->Key % CellSize);
			Actor->SetActorLabel(MergedActorName);
			Actor->SetActorHiddenInGame(true);
		}
	}

	for (ASplineMeshActor* SplineMeshActor : SingledActors)
	{
		FName NewPath = TEXT("CollisionGenerate");
		SplineMeshActor->SetFolderPath(NewPath);
		SplineMeshActor->SetActorHiddenInGame(true);
	}
}

void FToolsLibrary::SplitSplineMeshComponent()
{
	UWorld* World = GEditor->GetEditorWorldContext().World();
	UWorldPartition* WorldPartition = World->GetWorldPartition();
	if (!WorldPartition)
		return;
	// 1.清理场景中生成过的Actor
	TArray<AActor*> SplineMergedActorGet;
	UGameplayStatics::GetAllActorsOfClass(World, AStaticMeshActor::StaticClass(), SplineMergedActorGet);

	for (AActor* Actor : SplineMergedActorGet)
	{
		if (Actor->GetFolderPath() == TEXT("CollisionGenerate"))
		{
			Actor->Destroy();
		}
	}

	TArray<AActor*> SplineMeshActorsGet;
	UGameplayStatics::GetAllActorsOfClass(World, ASplineMeshActor::StaticClass(), SplineMeshActorsGet);
	for (AActor* Actor : SplineMeshActorsGet)
	{
		if (Actor->GetFolderPath() == TEXT("CollisionGenerate"))
		{
			Actor->Destroy();
		}
	}

	// 2.清理生成过的staticmesh资源
	FString AssetPath = FString::Printf(TEXT("/Game/SBBTV/StaticMeshes/%s"), *World->GetName());
	FAssetRegistryModule& AssetRegistryModule = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry");

	// 获取资源注册表
	IAssetRegistry& AssetRegistry = AssetRegistryModule.Get();
	// 获取要删除的资源的资产标识符
	TArray<FAssetData> AssetDataList;
	AssetRegistry.GetAssetsByPath(FName(*AssetPath), AssetDataList);
	// 使用资产工具接口删除资产
	for (auto Asset : AssetDataList)
	{
		FAssetRegistryModule::AssetDeleted(Asset.GetAsset());
	}

	// 3.按照分区合并spline mesh
	TArray<AActor*> ActorsGet;
	UGameplayStatics::GetAllActorsOfClass(World, AActor::StaticClass(), ActorsGet);
	for (auto Actor : ActorsGet)
	{
		auto Name = Actor->GetClass()->GetName();
		if (Name == TEXT("BP_SBBTV_SplineVolume_C"))
		{
			SplitSBBTVActor(Actor);
		}
	}
}

void FToolsLibrary::StartPIEFromPreview()
{
	//FLevelEditorModule& LevelEditorModule = FModuleManager::GetModuleChecked<FLevelEditorModule>(TEXT("LevelEditor"));

	//TSharedPtr<IAssetViewport> ActiveLevelViewport = LevelEditorModule.GetFirstActiveViewport();

	//FRequestPlaySessionParams SessionParams;

	//const UGameMapsSettings* GameMapsSettings = GetDefault<UGameMapsSettings>();

	//SessionParams.GlobalMapOverride = GameMapsSettings->GetGameDefaultMap();

	////SessionParams.GameModeOverride = 

	//if (ActiveLevelViewport.IsValid() && FSlateApplication::Get().FindWidgetWindow(ActiveLevelViewport->AsWidget()).IsValid())
	//{
	//	SessionParams.DestinationSlateViewport = ActiveLevelViewport;
	//	//if (!bAtPlayerStart)
	//	{
	//		// Start the player where the camera is if not forcing from player start
	//		//SessionParams.StartLocation = ActiveLevelViewport->GetAssetViewportClient().GetViewLocation();
	//		//SessionParams.StartRotation = ActiveLevelViewport->GetAssetViewportClient().GetViewRotation();
	//		SessionParams.StartLocation = FVector::Zero();
	//		SessionParams.StartRotation = FRotator::ZeroRotator;
	//	}
	//}
	//	
	//GUnrealEd->RequestPlaySession(SessionParams);

	if (GLevelEditorModeTools().IsModeActive("EM_GamePlayEditorMode"))
	{
		FText Message = FText::FromString(TEXT("场景编辑模式下, 无法运行游戏"));
		FMessageDialog::Open(EAppMsgType::Ok, Message);
		return;
	}
	if (FBehaviorActorSelector::IsDialogueEditorOpen())
	{
		FText Message = FText::FromString(TEXT("请先关闭对话编辑器, 再运行游戏"));
		FMessageDialog::Open(EAppMsgType::Ok, Message);
		return;
	}
	//ULevelEditorPlaySettings::StaticClass()->GetDefaultObject<ULevelEditorPlaySettings>()->UseMouseForTouch = false;
	//UInputSettings::StaticClass()->GetDefaultObject<UInputSettings>()->bUseMouseForTouch = false;

	FName CurPlatformName;
	GEngine->GetPreviewPlatformName(CurPlatformName);
	ERHIFeatureLevel::Type CurFeatureLevel = GEngine->GetDefaultWorldFeatureLevel();
	FName EsName("AndroidES31_Preview");
	FName EsPlatform("Android");
	if (CurPlatformName != EsPlatform)
	{
		FText DialogText = FText::FromString(FString("Preview Render Level Switch ES3_1"));
		EAppReturnType::Type ReturnType = FMessageDialog::Open(EAppMsgType::OkCancel, DialogText);
		if (ReturnType == EAppReturnType::Ok)
		{
			int32 ItemIndex(-1);
			const TArray<FPreviewPlatformMenuItem>& MenuItems = FDataDrivenPlatformInfoRegistry::GetAllPreviewPlatformMenuItems();
			for (int32 Index(0); Index < MenuItems.Num(); ++Index)
			{
				const FPreviewPlatformMenuItem& Item = MenuItems[Index];
				if (Item.PreviewShaderPlatformName == EsName)
				{
					ItemIndex = Index;
				}
			}
			if (ItemIndex >= 0)
			{
				const FPreviewPlatformMenuItem& Item = MenuItems[ItemIndex];
				EShaderPlatform ShaderPlatform = FDataDrivenShaderPlatformInfo::GetShaderPlatformFromName(Item.PreviewShaderPlatformName);

				if (ShaderPlatform < SP_NumPlatforms)
				{
					ERHIFeatureLevel::Type FeatureLevel = GetMaxSupportedFeatureLevel(ShaderPlatform);

					const bool IsDefaultActive = FDataDrivenShaderPlatformInfo::GetPreviewShaderPlatformParent(ShaderPlatform) == GMaxRHIShaderPlatform;
					const bool AllowPreview = !IsDefaultActive;


					FPreviewPlatformInfo PreviewFeatureLevelInfo(FeatureLevel, (EShaderPlatform)ShaderPlatform, IsDefaultActive ? NAME_None : Item.PlatformName, IsDefaultActive ? NAME_None : Item.ShaderFormat, IsDefaultActive ? NAME_None : Item.DeviceProfileName, AllowPreview, Item.PreviewShaderPlatformName);

					GEditor->SetPreviewPlatform(PreviewFeatureLevelInfo, true);
				}

			}



		}
	}


	UClass* const PlayerStartClass = GUnrealEd->PlayFromHerePlayerStartClass ? (UClass*)GUnrealEd->PlayFromHerePlayerStartClass : APlayerStart::StaticClass();
	UCapsuleComponent* DefaultCollisionComponent = CastChecked<UCapsuleComponent>(PlayerStartClass->GetDefaultObject<AActor>()->GetRootComponent());
	FVector	CollisionExtent = FVector(DefaultCollisionComponent->GetScaledCapsuleRadius(), DefaultCollisionComponent->GetScaledCapsuleRadius(), DefaultCollisionComponent->GetScaledCapsuleHalfHeight());
	FVector StartLocation = GEditor->UnsnappedClickLocation + GEditor->ClickPlane * (FVector::BoxPushOut(GEditor->ClickPlane, CollisionExtent) + 0.1f);
	TOptional<FRotator> StartRotation;
	FLevelEditorModule& LevelEditorModule = FModuleManager::GetModuleChecked<FLevelEditorModule>("LevelEditor");

	TSharedPtr<IAssetViewport> ActiveLevelViewport = LevelEditorModule.GetFirstActiveViewport();

	if (ActiveLevelViewport.IsValid() && ActiveLevelViewport->GetAssetViewportClient().IsPerspective())
	{
		StartRotation = ActiveLevelViewport->GetAssetViewportClient().GetViewRotation();
	}

	if (GUnrealEd->PlayWorld != NULL)
	{
		GUnrealEd->EndPlayMap();
	}

	FRequestPlaySessionParams SessionParams;
	SessionParams.StartLocation = StartLocation;
	SessionParams.StartRotation = StartRotation;

	if (ActiveLevelViewport.IsValid() && ActiveLevelViewport->GetAssetViewportClient().IsPerspective())
	{
		// If there is no level viewport, a new window will be spawned to play in.
		SessionParams.DestinationSlateViewport = ActiveLevelViewport;
	}

	if (const UC7EditorSettings* EditorSettings = GetDefault<UC7EditorSettings>())
	{
		SessionParams.GameModeOverride = EditorSettings->PreviewGameMode;
		SessionParams.GameInstanceClass = EditorSettings->PreviewGameInstance;
	}


	GUnrealEd->RequestPlaySession(SessionParams);

}

void FToolsLibrary::LoadAllRegion()
{
	UWorld* World = GEditor->GetEditorWorldContext().World();
	if (!World || !World->IsPartitionedWorld())
	{
		UE_LOG(LogTemp, Warning, TEXT("Not Partition World. Abort!"));
		return;
	}

	UDataLayerSubsystem* DataLayerSubsystem = UWorld::GetSubsystem<UDataLayerSubsystem>(World);

	// 设置各个区域的状态
	bool bUpdateEditorCells = false;
	UDataLayerManager* DataLayerManager = UDataLayerManager::GetDataLayerManager(World);
	if (DataLayerManager)
	{
		DataLayerManager->ForEachDataLayerInstance([&bUpdateEditorCells](UDataLayerInstance* DataLayer)
			{
				const FName DataLayerShortName(DataLayer->GetDataLayerShortName());
				bool bLoadedInEditor = true;

				if (!DataLayer->IsLoadedInEditor())
				{
					bUpdateEditorCells = true;
					DataLayer->SetIsLoadedInEditor(bLoadedInEditor, /*bFromUserChange*/false);
					if (bLoadedInEditor)
					{
						DataLayer->SetIsInitiallyVisible(true);
					}
				}

				UE_LOG(LogTemp, Display, TEXT("DataLayer '%s' Loaded: %d"), *UDataLayerInstance::GetDataLayerText(DataLayer).ToString(), bLoadedInEditor ? 1 : 0);

				return true;
			});
	}

	if (bUpdateEditorCells)
	{
		FDataLayersEditorBroadcast::StaticOnActorDataLayersEditorLoadingStateChanged(false);
	}

	// 加载整个世界
	auto Bounds = FBox(FVector(-HALF_WORLD_MAX, -HALF_WORLD_MAX, -HALF_WORLD_MAX), FVector(HALF_WORLD_MAX, HALF_WORLD_MAX, HALF_WORLD_MAX));
	auto WorldPartition = World->GetWorldPartition();
	UWorldPartitionEditorLoaderAdapter* EditorLoaderAdapter = WorldPartition->CreateEditorLoaderAdapter<FLoaderAdapterShape>(World, Bounds, TEXT("Loaded Region"));
	EditorLoaderAdapter->GetLoaderAdapter()->Load();

}
void FToolsLibrary::DumpNavMesh()
{
	// 显示NavMesh信息：NavDataActor数量、Tile数量、stat信息等等

	auto World = GEditor->GetEditorWorldContext().World();
	auto NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(World);
	if (!NavSys)
	{
		return;
	}

	// dump navmesh的情况
	int ChunkActorCount = 0;
	for (TActorIterator<ANavigationDataChunkActor> It(World); It; ++It)
	{
		ANavigationDataChunkActor* One = *It;
		if (One != nullptr)
		{
			ChunkActorCount++;
		}
	}
	UE_LOG(LogTemp, Log, TEXT("Chunk Actor Count=%d"), ChunkActorCount);

	{
		int maxTiles = 0;
		int totalTiles = 0;
		int totalTriangles = 0;
		int totalVertics = 0;
		int totalTileSize = 0;
		ANavigationData* MainNavDataIns = NavSys->GetDefaultNavDataInstance();
		const ARecastNavMesh* RecastNavMeshIns = Cast<ARecastNavMesh>(MainNavDataIns);

		if (RecastNavMeshIns && UKismetSystemLibrary::IsValid(RecastNavMeshIns))
		{
			const dtNavMesh* navMesh = RecastNavMeshIns->GetRecastMesh();
			maxTiles = navMesh->getMaxTiles();
			for (int i = 0; i < maxTiles; i++)
			{
				const dtMeshTile* tile = navMesh->getTile(i);
				if (tile != nullptr && tile->header != nullptr)
				{
					FDetourTileLayout TileLayout(*tile);
					totalTileSize += TileLayout.TileSize;
					totalVertics += tile->header->vertCount;
					totalTriangles += tile->header->polyCount;
					totalTiles++;
				}
			}
		}
		UE_LOG(LogTemp, Log, TEXT("MaxTile=%d"), maxTiles);
		UE_LOG(LogTemp, Log, TEXT("totalTiles=%d"), totalTiles);
		UE_LOG(LogTemp, Log, TEXT("totalTriangles=%d"), totalTriangles);
		UE_LOG(LogTemp, Log, TEXT("totalVertics=%d"), totalVertics);
		UE_LOG(LogTemp, Log, TEXT("totalTileSize=%d"), totalTileSize);
	}
}

void FToolsLibrary::DeleteNavDataActor()
{
	auto World = GEditor->GetEditorWorldContext().World();
	auto NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(World);
	if (!NavSys)
	{
		return;
	}

	TArray<ANavigationDataChunkActor*> NavDataList;
	TArray<UPackage*> NavigationDataChunkActorPackages;
	for (TActorIterator<ANavigationDataChunkActor> ItActor(World); ItActor; ++ItActor)
	{
		NavDataList.Add(*ItActor);
		NavigationDataChunkActorPackages.Add(ItActor->GetPackage());
	}

	for (auto It : NavDataList)
	{
		World->EditorDestroyActor(It, true);
	}

	const FPackageSourceControlHelper Helper;
	Helper.Delete(NavigationDataChunkActorPackages);
}

bool FToolsLibrary::CheckoutFile(const FString& Filename, bool bAddFile, bool bIgnoreAlreadyCheckedOut)
{
	if (!IFileManager::Get().FileExists(*Filename))
	{
		return false;
	}

	bool bIsReadOnly = IFileManager::Get().IsReadOnly(*Filename);
	if (!bIsReadOnly && !bAddFile)
	{
		return true;
	}

	ISourceControlProvider& SourceControlProvider = ISourceControlModule::Get().GetProvider();
	FSourceControlStatePtr SourceControlState = SourceControlProvider.GetState(*Filename, EStateCacheUsage::ForceUpdate);
	if (SourceControlState.IsValid())
	{
		// Already checked out/added this file
		if (SourceControlState->IsCheckedOut() || SourceControlState->IsAdded())
		{
			return true;
		}
		else if (!SourceControlState->IsSourceControlled())
		{
			if (bAddFile)
			{
				if (SourceControlProvider.Execute(ISourceControlOperation::Create<FMarkForAdd>(), *Filename) == ECommandResult::Succeeded)
				{
					UE_LOG(LogTemp, Display, TEXT("[REPORT] %s successfully added"), *Filename);
					return true;
				}
				else
				{
					if (!bIgnoreAlreadyCheckedOut)
					{
						UE_LOG(LogTemp, Error, TEXT("[REPORT] %s could not be added!"), *Filename);
					}
					else
					{
						UE_LOG(LogTemp, Warning, TEXT("[REPORT] %s could not be added!"), *Filename);
					}
				}
			}
		}
		else if (!SourceControlState->IsCurrent())
		{
			if (!bIgnoreAlreadyCheckedOut)
			{
				UE_LOG(LogTemp, Error, TEXT("[REPORT] %s is not synced to head, can not submit"), *Filename);
			}
			else
			{
				UE_LOG(LogTemp, Warning, TEXT("[REPORT] %s is not synced to head, can not submit"), *Filename);
			}
		}
		else if (!SourceControlState->CanCheckout())
		{
			FString CurrentlyCheckedOutUser;
			if (SourceControlState->IsCheckedOutOther(&CurrentlyCheckedOutUser))
			{
				if (!bIgnoreAlreadyCheckedOut)
				{
					UE_LOG(LogTemp, Error, TEXT("[REPORT] %s level is already checked out by someone else (%s), can not submit!"), *Filename, *CurrentlyCheckedOutUser);
				}
				else
				{
					UE_LOG(LogTemp, Warning, TEXT("[REPORT] %s level is already checked out by someone else (%s), can not submit!"), *Filename, *CurrentlyCheckedOutUser);
				}
			}
			else
			{
				UE_LOG(LogTemp, Error, TEXT("[REPORT] Unable to checkout %s, can not submit"), *Filename);
			}
		}
		else
		{
			if (SourceControlProvider.Execute(ISourceControlOperation::Create<FCheckOut>(), *Filename) == ECommandResult::Succeeded)
			{
				UE_LOG(LogTemp, Display, TEXT("[REPORT] %s Checked out successfully"), *Filename);
				return true;
			}
			else
			{
				UE_LOG(LogTemp, Warning, TEXT("[REPORT] %s could not be checked out!"), *Filename);
			}
		}
	}
	return false;
}
void FToolsLibrary::DoSavePackage(UPackage* Package)
{
	if (!Package)
	{
		return;
	}
	Package->MarkPackageDirty();

	FString PackageFilename;
	if (FPackageName::TryConvertLongPackageNameToFilename(Package->GetName(), PackageFilename,
		Package->ContainsMap()
		? FPackageName::GetMapPackageExtension()
		: FPackageName::GetAssetPackageExtension()))
	{
		ISourceControlProvider& SourceControlProvider = ISourceControlModule::Get().GetProvider();
		FSourceControlStatePtr SourceControlState = SourceControlProvider.GetState(Package, EStateCacheUsage::ForceUpdate);
		if (SourceControlState.IsValid())
		{
			CheckoutFile(PackageFilename, true, false);
		}

		// 强制清理readonly
		if (IFileManager::Get().IsReadOnly(*PackageFilename))
		{
			FPlatformFileManager::Get().GetPlatformFile().SetReadOnly(*PackageFilename, false);
		}

		if (!SavePackageHelper(Package, PackageFilename))
		{
			UE_LOG(LogTemp, Error, TEXT("SaveAction. Failed to save existing package %s. Path=%s"),
				*PackageFilename, *Package->GetFullName());
		}
		else
		{
			UE_LOG(LogTemp, Log, TEXT("SaveAction. Save Package: %s. Path=%s"), *PackageFilename, *Package->GetFullName());
		}
	}
}

void FToolsLibrary::ExportNavmesh()
{
	RecastExportNavmesh();
}

void FToolsLibrary::ExportVoxel()
{
	RecastExportVoxel();
}

void FToolsLibrary::EnableVoxelDisplay()
{
	RecastEnableVoxelDisplay();
}

void FToolsLibrary::DisableVoxelDisplay()
{
	RecastDisableVoxelDisplay();
}


#define LOCTEXT_NAMESPACE "FToolsLibraryMapShoot"
#include "UI/C7Map/MapSnapShoot/MapShoot.h"
#include "Layers/LayersSubsystem.h"
#include "SLevelViewport.h"
#include "Slate/SceneViewport.h"
#include "NavMeshWayPointSystem/WayPointSystem.h"
#define MAP_JSON TEXT("Build")/TEXT("BatchFiles")/TEXT("Config")/TEXT("Map.json")
#define SCREENSHOT_PATH TEXT("ScreenShots")/TEXT("WindowsEditor")
#define OUTPUT_JSON TEXT("ScreenShots")/TEXT("WindowsEditor")/TEXT("CaptureMapShootData.json")
void FToolsLibrary::CaptureMapShoot()
{
	UWorld* World = GEditor->GetEditorWorldContext().World();
	
	FString JsonConfigPath = FPaths::ProjectDir() / MAP_JSON;
	
	FVector Location = FVector::Zero();
	FRotator Rotator = FRotator(-90.0f, 0.0f ,0.0f);
	float OrthoWidth = 0.0f;
	float AspectRatio = 1.0f;

	for(TActorIterator<AActor> It(World); It; ++It)
	{
		AActor* Actor = *It;
		if(AMapShoot* DeleteMapShoot = Cast<AMapShoot>(Actor))
		{
			World->DestroyActor(DeleteMapShoot);
		}
	}
	
	if (FPaths::FileExists(JsonConfigPath))
	{
		FString JsonString;
		if (FFileHelper::LoadFileToString(JsonString, *JsonConfigPath))
		{
			TSharedPtr<FJsonObject> JsonObject;
			TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonString);
			if (FJsonSerializer::Deserialize(Reader, JsonObject) || !JsonObject.IsValid())
			{
				for(auto KV : JsonObject->Values)
				{
					FString Key = KV.Key;
					TSharedPtr<FJsonValue> Value = KV.Value;
					TSharedPtr<FJsonObject> MapObject = Value->AsObject();
					UE_LOG(LogTemp, Display, TEXT("%s"), *World->GetCurrentLevel()->GetPathName());
					if(World->GetCurrentLevel()->GetPathName().StartsWith(Key))
					{
						if(MapObject->Values.Contains("CamLocX"))
						{
							Location.X = MapObject->Values["CamLocX"]->AsNumber();
						}
						if(MapObject->Values.Contains("CamLocY"))
						{
							Location.Y = MapObject->Values["CamLocY"]->AsNumber();
						}
						if(MapObject->Values.Contains("CamLocZ"))
						{
							Location.Z = MapObject->Values["CamLocZ"]->AsNumber();
						}
						if(MapObject->Values.Contains("CamRotX"))
						{
							Rotator.Pitch = MapObject->Values["CamRotX"]->AsNumber();
						}
						if(MapObject->Values.Contains("CamRotY"))
						{
							Rotator.Yaw = MapObject->Values["CamRotY"]->AsNumber();
						}
						if(MapObject->Values.Contains("CamRotZ"))
						{
							Rotator.Roll = MapObject->Values["CamRotZ"]->AsNumber();
						}
						if(MapObject->Values.Contains("CamOrthoWidth"))
						{
							OrthoWidth = MapObject->Values["CamOrthoWidth"]->AsNumber();
						}
						if(MapObject->Values.Contains("CamAspectRatio"))
						{
							AspectRatio = MapObject->Values["CamAspectRatio"]->AsNumber();
						}
					}
				}				
			}
		}
	}
	
	AMapShoot* MapShoot = Cast<AMapShoot>(World->SpawnActor(AMapShoot::StaticClass()));
	MapShoot->SetActorLocation(Location);
	MapShoot->SetActorRotation(Rotator);
	UCameraComponent* CameraComponent = Cast<UCameraComponent>(MapShoot->GetComponentByClass(UCameraComponent::StaticClass()));
	CameraComponent->ProjectionMode = ECameraProjectionMode::Orthographic;
	CameraComponent->OrthoWidth = OrthoWidth;
	CameraComponent->SetConstraintAspectRatio(true);
	CameraComponent->AspectRatio = AspectRatio;


	UWorldPartition* WorldPartition = World->GetWorldPartition();
	if(WorldPartition)
	{
		auto Bounds = FBox(FVector(-HALF_WORLD_MAX, -HALF_WORLD_MAX, -HALF_WORLD_MAX), FVector(HALF_WORLD_MAX, HALF_WORLD_MAX, HALF_WORLD_MAX));
		UWorldPartitionEditorLoaderAdapter* EditorLoaderAdapter = WorldPartition->CreateEditorLoaderAdapter<FLoaderAdapterShape>(World, Bounds, TEXT("Navigable World"));
		EditorLoaderAdapter->GetLoaderAdapter()->SetUserCreated(false);
		EditorLoaderAdapter->GetLoaderAdapter()->Load();
	}
	
	FLevelEditorViewportClient* ViewportClient = GCurrentLevelEditingViewportClient;
	if (ViewportClient)
	{

		const EViewModeIndex CachedViewMode = ViewportClient->GetViewMode();
		
		//LockMapShootActor
		TSharedPtr<SLevelViewport> LevelViewport = StaticCastSharedPtr<SLevelViewport>(ViewportClient->GetEditorViewportWidget());
		AActor* Actor = Cast<AActor>(MapShoot);
		LevelViewport->OnActorLockToggleFromMenu(Actor);

		//ResetMapShowFlags
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

		FSceneViewport* Viewport = static_cast<FSceneViewport*>(ViewportClient->Viewport);
		if (Viewport)
		{
			Viewport->TakeHighResScreenShot();
		}
		int32 AxisTransform = int32(Rotator.Yaw + Rotator.Roll + 360.0f) % 360;
		double MinX = Location.X - OrthoWidth / 2;
		double MaxX = Location.X + OrthoWidth / 2;
		double MinY = Location.Y - OrthoWidth / AspectRatio / 2;
		double MaxY = Location.Y + OrthoWidth / AspectRatio / 2;
		double X2X = 0.0f, Y2X = 0.0f, X2Y = 0.0f, Y2Y = 0.0f;
		if(FMath::Abs(AxisTransform) < 5)
		{
			// 0 1  ->  0 1
			// 1 0  ->  1 0
			X2X = 0;
			Y2X = 1;
			X2Y = 1;
			Y2Y = 0;
		}
		else if(FMath::Abs(AxisTransform - 90) < 5)
		{
			// -1 0 -> -1 0
			//	0 1 ->  0 1
			X2X = -1;
			Y2X = 0;
			X2Y = 0;
			Y2Y = 1;
		}
		else if(FMath::Abs(AxisTransform - 180) < 5)
		{
			// 0 -1 -> 0 -1
			// -1 0 -> -1 0
			X2X = 0;
			Y2X = -1;
			X2Y = -1;
			Y2Y = 0;
		}
		else if(FMath::Abs(AxisTransform - 270) < 5)
		{
			// 1  0 -> 1  0
			// 0 -1 -> 0 -1
			X2X = 1;
			Y2X = 0;
			X2Y = 0;
			Y2Y = -1;
		}

		TSharedPtr<FJsonObject> WriteJsonObject = MakeShareable(new FJsonObject());
		WriteJsonObject->SetStringField("Path", World->GetCurrentLevel()->GetPathName());
		WriteJsonObject->SetNumberField("BaseLocationX", Location.X);
		WriteJsonObject->SetNumberField("BaseLocationY", Location.Y);
		WriteJsonObject->SetNumberField("BaseLocationZ", Location.Z);
		WriteJsonObject->SetNumberField("MinX", MinX);
		WriteJsonObject->SetNumberField("MinY", MinY);
		WriteJsonObject->SetNumberField("MaxX", MaxX);
		WriteJsonObject->SetNumberField("MaxY", MaxY);
		TArray<TSharedPtr<FJsonValue>> MiniMap2WorldRect;
		MiniMap2WorldRect.Add(MakeShareable(new FJsonValueNumber(X2X)));
		MiniMap2WorldRect.Add(MakeShareable(new FJsonValueNumber(Y2X)));
		MiniMap2WorldRect.Add(MakeShareable(new FJsonValueNumber(X2Y)));
		MiniMap2WorldRect.Add(MakeShareable(new FJsonValueNumber(Y2Y)));
		WriteJsonObject->SetArrayField("Rect", MiniMap2WorldRect);
		
		FString JsonString;
		FString JsonPath = FPaths::ProjectSavedDir() / OUTPUT_JSON;
		TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonString);
		FJsonSerializer::Serialize(WriteJsonObject.ToSharedRef(), Writer);
		Writer->Close();
		FFileHelper::SaveStringToFile(JsonString,  *JsonPath);
	}
}
void FToolsLibrary::GetLastCaptureMapShootAndCaculateWayPoint()
{
	FString ScreenPath = FPaths::ProjectSavedDir() / SCREENSHOT_PATH;
	if(FPaths::DirectoryExists(ScreenPath))
	{
		IFileManager& FileManager = IFileManager::Get();
		TArray<FString> JsonFileNames;
		FileManager.FindFiles(JsonFileNames, *ScreenPath, TEXT(".json"));
		
		TArray<FString> PNGFileNames;
		FileManager.FindFiles(PNGFileNames, *ScreenPath, TEXT(".png"));

		FString JsonPath = TEXT("");
		for(FString JsonFileName : JsonFileNames)
		{
			if(JsonFileName == TEXT("CaptureMapShootData.json"))
			{
				JsonPath = ScreenPath / JsonFileName;
			}
		}
		FString PNGPath = TEXT("");
		FDateTime LastTime = FDateTime::MinValue();
		for(FString PNGFileName : PNGFileNames)
		{
			FString TemporaryPNGPath = ScreenPath / PNGFileName;
			FFileStatData FileStatData = FileManager.GetStatData(*TemporaryPNGPath);
			if(FileStatData.CreationTime > LastTime)
			{
				LastTime = FileStatData.CreationTime;
				PNGPath = TemporaryPNGPath;
			}
		}
		if(JsonPath != TEXT("") && PNGPath != TEXT(""))
		{

			UWorld* World = GEditor->GetEditorWorldContext().World();
			FImage Image;			
			TArray64<uint8> Buffer;
			if (FFileHelper::LoadFileToArray(Buffer, *PNGPath))
			{
				FImageUtils::DecompressImage(Buffer.GetData(),Buffer.Num(), Image);
			}
			
			int32 ImageSizeX = Image.SizeX;
			int32 ImageSizeY = Image.SizeY;

			FString JsonString;
			double MinX = 0;
			double MinY = 0;
			double MaxX = 0;
			double MaxY = 0;
			double BaseLocationX = 0;
			double BaseLocationY = 0;
			TArray<double> Rect;
			FString MapPath = TEXT("");
			TSharedPtr<FJsonObject> ReadWriteJsonObject;
			if (FFileHelper::LoadFileToString(JsonString, *JsonPath))
			{				
				TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonString);
				if (FJsonSerializer::Deserialize(Reader, ReadWriteJsonObject) || !ReadWriteJsonObject.IsValid())
				{
					MinX = ReadWriteJsonObject->GetNumberField(TEXT("MinX"));
					MinY = ReadWriteJsonObject->GetNumberField(TEXT("MinY"));
					MaxX = ReadWriteJsonObject->GetNumberField(TEXT("MaxX"));
					MaxY = ReadWriteJsonObject->GetNumberField(TEXT("MaxY"));
					MapPath = ReadWriteJsonObject->GetStringField(TEXT("Path"));
					BaseLocationX = ReadWriteJsonObject->GetNumberField(TEXT("BaseLocationX"));
					BaseLocationY = ReadWriteJsonObject->GetNumberField(TEXT("BaseLocationY"));
					TArray<TSharedPtr<FJsonValue>> RectValues;
					RectValues = ReadWriteJsonObject->GetArrayField(TEXT("Rect"));
					for(auto RectValue : RectValues)
					{
						Rect.Add(RectValue->AsNumber());
					}
				}
			}
			
			if(MapPath == World->GetCurrentLevel()->GetPathName())
			{
				double ScaleX = (MaxX - MinX) / ImageSizeX;
				double ScaleY = (MaxY - MinY) / ImageSizeY;

				ReadWriteJsonObject->SetNumberField(TEXT("ScaleX"), ScaleX);
				ReadWriteJsonObject->SetNumberField(TEXT("ScaleY"), ScaleY);


				//WayPoint

				FVector2d LocationXY = FVector2d(BaseLocationX, BaseLocationY);
				
				TArray<AActor*> OutActors;
				UGameplayStatics::GetAllActorsOfClass(World, AWayPointSystem::StaticClass(), OutActors);
				if(OutActors.Num() > 0)
				{
					AWayPointSystem* System = Cast<AWayPointSystem>(OutActors[0]);
					TArray<FVector> WayPointAxises;

					System->GenerateWayPointNet();
					System->GetWayPointAxises(WayPointAxises);
					TArray<TSharedPtr<FJsonValue>> WayPointXYs;
					TArray<TSharedPtr<FJsonValue>> ImageXYs;
					for(FVector WayPointAxis : WayPointAxises)
					{
						FVector2d WayPointXY = FVector2d(WayPointAxis.X, WayPointAxis.Y);
						FVector2d OffsetXY = WayPointXY - LocationXY;
						//X2X:0 Y2X:1 X2Y:2 Y2Y:3
						FVector2d ImageXY = FVector2d((OffsetXY.X * Rect[0] + OffsetXY.Y * Rect[1]) / ScaleX + ImageSizeX / 2,
													-(OffsetXY.X * Rect[2] + OffsetXY.Y * Rect[3]) / ScaleY + ImageSizeY / 2);
						TSharedRef<FJsonObject> WayPointXYObject = MakeShared<FJsonObject>();
						WayPointXYObject->SetNumberField(TEXT("X"), WayPointXY.X);
						WayPointXYObject->SetNumberField(TEXT("Y"), WayPointXY.Y);
						WayPointXYs.Add(MakeShared<FJsonValueObject>(WayPointXYObject));

						TSharedRef<FJsonObject> ImageXYObject = MakeShared<FJsonObject>();
						ImageXYObject->SetNumberField(TEXT("X"), ImageXY.X);
						ImageXYObject->SetNumberField(TEXT("Y"), ImageXY.Y);
						ImageXYs.Add(MakeShared<FJsonValueObject>(ImageXYObject));
					}
					ReadWriteJsonObject->SetArrayField(TEXT("WayPoint"), WayPointXYs);
					ReadWriteJsonObject->SetArrayField(TEXT("ImagePoint"), ImageXYs);
				}
				else
				{
					UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(World);
					if (NavSys == nullptr || NavSys->GetDefaultNavDataInstance() == nullptr)
					{
						return;						
					}
					if (ANavigationData* NavigationData = Cast<ANavigationData>(NavSys->GetMainNavData()))
					{
						if(const ARecastNavMesh* NavMesh = Cast<ARecastNavMesh>(NavigationData))
						{

							TArray<FVector2d> PolyCenters;
							
							TMap<NavNodeRef, NavNodeRef> CombineSet;
							TMap<NavNodeRef, int32> Rank;
							auto CheckParent = [&](NavNodeRef Node)
							{
								TArray<NavNodeRef> RetNodes;
								while(CombineSet[Node] != Node)
								{
									RetNodes.Add(Node);
									Node = CombineSet[Node]; 
								}
								for(auto RetNode : RetNodes)
								{
									CombineSet[RetNode] = Node;
								}
							};
							auto Combine = [&](NavNodeRef NodeA, NavNodeRef NodeB)
							{
								CheckParent(NodeA);
								CheckParent(NodeB);
								NodeA = CombineSet[NodeA];
								NodeB = CombineSet[NodeB];
								if(NodeA != NodeB)
								{
									if(Rank[NodeA] < Rank[NodeB])
									{
										CombineSet[NodeA] = NodeB;
									}
									else if(Rank[NodeA] > Rank[NodeB])
									{
										CombineSet[NodeB] = NodeA;
									}
									else if(Rank[NodeA] == Rank[NodeB])
									{
										CombineSet[NodeB] = NodeA;
										Rank[NodeA] += 1;
									}
								}
							};
							
							for(int32 Index = 0; Index < NavMesh->GetNavMeshTilesCount(); Index++)
							{
								TArray<FNavPoly> NavPolys;
								NavMesh->GetPolysInTile(Index, NavPolys);
								for(auto NavPoly : NavPolys)
								{
									CombineSet.FindOrAdd(NavPoly.Ref) = NavPoly.Ref;
									Rank.FindOrAdd(NavPoly.Ref) = 0;
								}
							}
							for(auto& KV : CombineSet)
							{
								NavNodeRef& Key = KV.Key;
								NavNodeRef& Value = KV.Value;
								TArray<NavNodeRef> Neighbors;
								NavMesh->GetPolyNeighbors(Key, Neighbors);
								for(auto& Neighbor : Neighbors)
								{
									Combine(Key,Neighbor);
								}
							}
							TMap<NavNodeRef, int32> PolyCount;
							for(auto& KV : CombineSet)
							{
								CheckParent(KV.Key);
								PolyCount.FindOrAdd(KV.Value) += 1;
							}
							TArray<NavNodeRef> MaxCountPolyRef;
							int32 MaxCount = 50;
							for(auto& KV : PolyCount)
							{
								if(KV.Value >= MaxCount)
								{
									MaxCountPolyRef.Add(KV.Key);
								}
							}

							TArray<TSharedPtr<FJsonValue>> OutVectorXYs;
							TArray<TSharedPtr<FJsonValue>> ImageXYs;
							for(auto& KV : CombineSet)
							{
								if(MaxCountPolyRef.Contains(KV.Value))
								{
									FVector OutVector;
									NavMesh->GetPolyCenter(KV.Key, OutVector);
									FVector2d OutVectorXY = FVector2d(OutVector.X, OutVector.Y);
									FVector2d OffsetXY = OutVectorXY - LocationXY;
									//X2X:0 Y2X:1 X2Y:2 Y2Y:3
									FVector2d ImageXY = FVector2d((OffsetXY.X * Rect[0] + OffsetXY.Y * Rect[1]) / ScaleX + ImageSizeX / 2,
																-(OffsetXY.X * Rect[2] + OffsetXY.Y * Rect[3]) / ScaleY + ImageSizeY / 2);
									TSharedRef<FJsonObject> OutVectorXYObject = MakeShared<FJsonObject>();
									OutVectorXYObject->SetNumberField(TEXT("X"), OutVectorXY.X);
									OutVectorXYObject->SetNumberField(TEXT("Y"), OutVectorXY.Y);
									OutVectorXYs.Add(MakeShared<FJsonValueObject>(OutVectorXYObject));

									TSharedRef<FJsonObject> ImageXYObject = MakeShared<FJsonObject>();
									ImageXYObject->SetNumberField(TEXT("X"), ImageXY.X);
									ImageXYObject->SetNumberField(TEXT("Y"), ImageXY.Y);
									ImageXYs.Add(MakeShared<FJsonValueObject>(ImageXYObject));
								}
							}
							ReadWriteJsonObject->SetArrayField(TEXT("WayPoint"), OutVectorXYs);
							ReadWriteJsonObject->SetArrayField(TEXT("ImagePoint"), ImageXYs);
						}
					}
				}
				FString OutJsonString = TEXT("");
				TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&OutJsonString);
				FJsonSerializer::Serialize(ReadWriteJsonObject.ToSharedRef(), Writer);
				Writer->Close();
				FString OutJsonPath = FPaths::ProjectSavedDir() / OUTPUT_JSON;
				FFileHelper::SaveStringToFile(OutJsonString,  *OutJsonPath);				
			}			
		}
	}
}
#undef LOCTEXT_NAMESPACE  