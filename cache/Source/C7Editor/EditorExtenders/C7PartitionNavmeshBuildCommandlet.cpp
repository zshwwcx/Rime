#include "C7PartitionNavmeshBuildCommandlet.h"
#include "LevelEditorSubsystem.h"
#include "Engine/ObjectLibrary.h"
#include "EditorExtenders/ToolsLibrary.h"
#include "Navmesh/RecastNavMeshGenerator.h"
#include "EngineUtils.h"
#include "NavigationData.h"
#include "Engine/MapBuildDataRegistry.h"
#include "AssetToolsModule.h"
#include "DirectoryWatcherModule.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "ISourceControlModule.h"
#include "ISourceControlProvider.h"
#include "Misc/ScopedSlowTask.h"
#include "WorldPartition/WorldPartition.h"
#include "WorldPartition/WorldPartitionEditorLoaderAdapter.h"
#include "WorldPartition/LoaderAdapter/LoaderAdapterShape.h"
#include "FileHelpers.h"
#include "IDirectoryWatcher.h"

#include "HAL/Platform.h"

#if PLATFORM_WINDOWS
#include "Windows/AllowWindowsPlatformTypes.h"
#include "Windows/PreWindowsApi.h"
#include <windows.h>
#include "Windows/PostWindowsApi.h"
#include "Windows/HideWindowsPlatformTypes.h"
#endif

#include "PackageHelperFunctions.h"
#include "AI/NavigationSystemBase.h"
#include "Kismet/KismetSystemLibrary.h"
#include "Detour/DetourNavMesh.h"
#include "WorldPartition/NavigationData/NavigationDataChunkActor.h"
#include <NavMesh/RecastNavMesh.h>

#include "SourceControlOperations.h"
#include "ToolsLibrary.h"
#include "Misc/FileHelper.h"

DEFINE_LOG_CATEGORY(LogC7PartitionNavmeshBuildCommandlet);
#define LOCTEXT_NAMESPACE "EditorBuildUtils"

UC7PartitionNavmeshBuildCommandlet::UC7PartitionNavmeshBuildCommandlet()
{
}

int32 UC7PartitionNavmeshBuildCommandlet::Main(const FString& InCommandline)
{
	UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Display, TEXT("commandlet start."))

#if PLATFORM_WINDOWS
	if (false && ::MessageBoxA(NULL, "123", "123", MB_OK) != 1)
	{
		return 0;
	}
#endif

	TArray<FString> Tokens;
	TArray<FString> Switches1;
	TMap<FString, FString> Params;
	ParseCommandLine(*InCommandline, Tokens, Switches1, Params);

	auto mapName = Params.Find("MapName");
	if (mapName == nullptr)
	{
		UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Error, TEXT("Invalid Args. no MapName"));
		return 0;
	}
	bool cleanPackages = Tokens.Find("CleanPackages") >= 0;

	auto MapFolder = "Arts/Maps";
	auto objLibrary = UObjectLibrary::CreateLibrary(UWorld::StaticClass(), false, true);
	objLibrary->LoadAssetDataFromPath(TEXT("/Game/Arts/Maps"));

	TArray<FString> MapFiles;
	auto RootPath = FPaths::Combine(FPaths::ProjectContentDir(), MapFolder);
	IFileManager::Get().FindFilesRecursive(MapFiles, *RootPath, TEXT("*.umap"), true, false, false);
	FString FileFullPath;
	for (auto It : MapFiles)
	{
		auto ShortFileName = FPaths::GetBaseFilename(It);
		if (ShortFileName == *mapName)
		{
			FileFullPath = It;
			break;
		}
	}
	if (FileFullPath.Len() == 0)
	{
		UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Error, TEXT("Can't Find Map, Name=%s"), **mapName);
		return 0;
	}

	UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Log, TEXT("Process Map=%s"), *FileFullPath);

	// 替换成资源路径
	auto ResourcePath = FileFullPath.Replace(*FPaths::ProjectContentDir(), *FString::Printf(TEXT("/Game/")));

	UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Log, TEXT("Load Map=%s"), *ResourcePath);

	if (!GEditor->GetEditorSubsystem<ULevelEditorSubsystem>()->LoadLevel(ResourcePath))
	{
		UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Error, TEXT("Load Map Failed. Map=%s"), *FileFullPath);
		return 0;
	}

	auto World = GEditor->GetEditorWorldContext().World();

	auto one = FSavePackageFunction::CreateLambda([this](UPackage* Package, TArray<FString>& SublevelFilenames)
	{
		this->CheckoutAndSavePackage(Package, SublevelFilenames, this->bSkipCheckedOutFiles);
	});
	
	UC7PartitionNavmeshBuildCommandlet::DoAction(World, one);
	
	return 0;
}

int32 UC7PartitionNavmeshBuildCommandlet::DoAction(UWorld* World, FSavePackageFunction CheckoutAndSavePackageFunc)
{
	if (World == nullptr)
	{
		UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Error, TEXT("Invalid!"));
		return -1;
	}
	if (!World->IsPartitionedWorld())
	{
		UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Log, TEXT("Not Partition World!"));
		return -1;
	}

	auto NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(World);
	if (NavSys == nullptr)
	{
		UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Error, TEXT("No NavSys!"));
		return -1;
	}

	ARecastNavMesh* NavMesh = nullptr;
	for (TActorIterator<ARecastNavMesh> It(World); It; ++It)
	{
		if (It)
		{
			NavMesh = *It;
		}
	}
	if (NavMesh == nullptr)
	{
		UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Error, TEXT("No NavSys!"));
		return -1;
	}

	if (!NavMesh->bIsWorldPartitioned)
	{
		UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Log, TEXT("Not Partition NavMesh!"));
		return 0;
	}

	// 构建，参考：FEditorBuildUtils::WorldPartitionBuildNavigation
	if (true)
	{
		FString InLongPackageName = GetNameSafe(World->GetPackage());

		FProcHandle ProcessHandle;
		bool bCancelled = false;

		// 启动进程前，先清理下，防止本进程占用太多内存
		World = UEditorLoadingAndSavingUtils::NewBlankMap(false);
		
		// Task scope
		{
			bool bVerbose = false;
			bool bCleanPackages = false;

			FScopedSlowTask SlowTask(0, LOCTEXT("WorldPartitionBuildNavigationProgress", "Building navigation..."));
			SlowTask.MakeDialog(true);

			const FString CurrentExecutableName = FPlatformProcess::ExecutablePath();

			// Try to provide complete Path, if we can't try with project name
			const FString ProjectPath = FPaths::IsProjectFilePathSet()
				                            ? FPaths::GetProjectFilePath()
				                            : FApp::GetProjectName();

			uint32 ProcessID;

			ISourceControlProvider& SCCProvider = ISourceControlModule::Get().GetProvider();

			FString OldName(SCCProvider.GetName().ToString());
			
			ISourceControlModule::Get().SetProvider(TEXT("None"));

			const FString Arguments = FString::Printf(
				TEXT("\"%s\" -run=WorldPartitionBuilderCommandlet %s %s -SCCProvider=%s %s %s"),
				*ProjectPath,
				*InLongPackageName,
				TEXT(
					" -AllowCommandletRendering -Builder=WorldPartitionNavigationDataBuilder -log=WPNavigationBuilderLog.txt"),
				*OldName,
				bVerbose ? TEXT("-Verbose") : TEXT(""),
				bCleanPackages ? TEXT("-CleanPackages") : TEXT(""));

			ProcessHandle = FPlatformProcess::CreateProc(*CurrentExecutableName, *Arguments, true, false, false,
			                                             &ProcessID, 0, nullptr, nullptr);


			int Cnt = 0;
			while (FPlatformProcess::IsProcRunning(ProcessHandle))
			{
				// 如果等待1小时以上，那么直接退出掉
				if (SlowTask.ShouldCancel() || Cnt > (30*60*10))
				{
					bCancelled = true;
					FPlatformProcess::TerminateProc(ProcessHandle);
					break;
				}

				SlowTask.EnterProgressFrame(0);
				FPlatformProcess::Sleep(0.1);
				Cnt++;
			}

			// 恢复旧的SCM
			ISourceControlModule::Get().SetProvider(*OldName);
		}

		int32 Result = -1;
		if (!bCancelled && FPlatformProcess::GetProcReturnCode(ProcessHandle, &Result))
		{
			// Force a directory watcher tick for the asset registry to get notified of the changes
			FDirectoryWatcherModule& DirectoryWatcherModule = FModuleManager::Get().LoadModuleChecked<
				FDirectoryWatcherModule>(TEXT("DirectoryWatcher"));
			DirectoryWatcherModule.Get()->Tick(-1.0f);

			// Unload any loaded map
			if (!UEditorLoadingAndSavingUtils::NewBlankMap(/*bSaveExistingMap*/false))
			{
				UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Error, TEXT("New Map Failed!"));
				return -1;
			}

			// Force registry update before loading converted map
			const FAssetRegistryModule& AssetRegistryModule = FModuleManager::LoadModuleChecked<FAssetRegistryModule>(
				"AssetRegistry");
			IAssetRegistry& AssetRegistry = AssetRegistryModule.Get();

			FString MapToLoad = InLongPackageName;

			AssetRegistry.ScanModifiedAssetFiles({MapToLoad});
			AssetRegistry.ScanPathsSynchronous(ULevel::GetExternalObjectsPaths(MapToLoad), true);

			FEditorFileUtils::LoadMap(MapToLoad);
			World = GEditor->GetEditorWorldContext().World();			

			UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Log, TEXT("Done. Reload Map=%s"), *MapToLoad);
		}
		else
		{
			UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Error, TEXT("Child Process Failed!"));
			return Result;
		}
	}

	// dump navmesh的情况。需要先加载，然后再dump，否则是错误的
	FToolsLibrary::LoadAllRegion();
	FToolsLibrary::DumpNavMesh();


	// 保存文件
	ULevel* Level = World->PersistentLevel;
	TArray<FString> CheckedOutPackagesFilenames;
	if (Level && Level->IsValidLowLevel() && false)	// 上一步自动保存了，所以不处理了
	{
		// Check dirtiness if the level is using external objects, no need to save it needlessly
		bool bCheckDirty = Level->IsUsingExternalObjects();

		TArray<UPackage*> PackagesToSave;

		UPackage* LevelPackage = Level->GetPackage();
		// Get Packages to save
		if (!bCheckDirty || LevelPackage->IsDirty() || LevelPackage->HasAnyPackageFlags(PKG_NewlyCreated))
		{
			PackagesToSave.Add(LevelPackage);
		}

		auto& SCCProvider = ISourceControlModule::Get().GetProvider();
		bool bScmValid = SCCProvider.GetName().ToString() != FString("None");
		// Get External Packages to save
		const TArray<UPackage*> ExternalPackages = Level->GetLoadedExternalObjectPackages();
		for (UPackage* ExternalPackage : ExternalPackages)
		{
			UObject* FoundAsset = nullptr;
			ForEachObjectWithPackage(ExternalPackage, [&FoundAsset](UObject* InnerObject)
			{
				if (InnerObject->IsAsset())
				{
					if (FAssetData::IsUAsset(InnerObject))
					{
						// If we found the primary asset, use it
						FoundAsset = InnerObject;
						return false;
					}
					// Otherwise, keep the first found asset but keep looking for a primary asset
					if (!FoundAsset)
					{
						FoundAsset = InnerObject;
					}
				}
				return true;
			}, /*bIncludeNestedObjects*/ false);

			FName AssetName;
			if (FoundAsset)
			{
				FAssetToolsModule& AssetToolsModule = FModuleManager::LoadModuleChecked<FAssetToolsModule>(
					TEXT("AssetTools"));
				TWeakPtr<IAssetTypeActions> AssetTypeActions = AssetToolsModule.Get().GetAssetTypeActionsForClass(
					FoundAsset->GetClass());
				if (AssetTypeActions.IsValid())
				{
					AssetName = *AssetTypeActions.Pin()->GetObjectDisplayName(FoundAsset);
				}
				else
				{
					AssetName = FoundAsset->GetFName();
				}
			}
			bool bNavData = (AssetName.ToString().Find("NavDataChunkActor") != -1 || AssetName.ToString().Find("RecastNavMesh") != -1); 
			if (bNavData)
			{
				PackagesToSave.Add(ExternalPackage);

				FString PackageFilename;
				auto Package = ExternalPackage;
				if (FPackageName::TryConvertLongPackageNameToFilename(Package->GetName(), PackageFilename,
				                                                      Package->ContainsMap()
					                                                      ? FPackageName::GetMapPackageExtension()
					                                                      : FPackageName::GetAssetPackageExtension()))
				{
					ISourceControlProvider& SourceControlProvider = ISourceControlModule::Get().GetProvider();
					if (bScmValid)
					{
						CheckoutAndSavePackageFunc.ExecuteIfBound(ExternalPackage, CheckedOutPackagesFilenames);	
						UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Log, TEXT("SaveAction. Checkout: %s. Path=%s"), *AssetName.ToString(), *ExternalPackage->GetFullName());					
					}
					else if (!SavePackageHelper(Package, PackageFilename))
					{
						UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Error, TEXT("SaveAction. Failed to save existing package %s. Path=%s"),
						       *AssetName.ToString(), *ExternalPackage->GetFullName());
					}
					else
					{
						UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Log, TEXT("SaveAction. Save Package: %s. Path=%s"), *AssetName.ToString(), *ExternalPackage->GetFullName());
					}
				}
			}
			else
			{
				UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Log, TEXT("SaveAction. AssetName: %s. Path=%s"), *AssetName.ToString(), *ExternalPackage->GetFullName());
			}
		}
	}

	// 0表示正常结束
	return 0;
}
DECLARE_DELEGATE_RetVal_OneParam(bool, FDumpFilterFunction, FString);
static void DumpNavActor(const FString& FileName, FDumpFilterFunction Func)
{
	UWorld* World = GEditor->GetEditorWorldContext().World(); 
	ULevel* Level = World->PersistentLevel;
	TArray<FString> CheckedOutPackagesFilenames;
	TMap<FString, FString> Dict;
	if (Level && Level->IsValidLowLevel())
	{
		// Check dirtiness if the level is using external objects, no need to save it needlessly
		bool bCheckDirty = Level->IsUsingExternalObjects();


		TArray<UPackage*> PackagesToSave;

		UPackage* LevelPackage = Level->GetPackage();
		// Get Packages to save
		if (!bCheckDirty || LevelPackage->IsDirty() || LevelPackage->HasAnyPackageFlags(PKG_NewlyCreated))
		{
			PackagesToSave.Add(LevelPackage);
		}

		// Get External Packages to save
		const TArray<UPackage*> ExternalPackages = Level->GetLoadedExternalObjectPackages();
		for (UPackage* ExternalPackage : ExternalPackages)
		{
			UObject* FoundAsset = nullptr;
			ForEachObjectWithPackage(ExternalPackage, [&FoundAsset](UObject* InnerObject)
			{
				if (InnerObject->IsAsset())
				{
					if (FAssetData::IsUAsset(InnerObject))
					{
						// If we found the primary asset, use it
						FoundAsset = InnerObject;
						return false;
					}
					// Otherwise, keep the first found asset but keep looking for a primary asset
					if (!FoundAsset)
					{
						FoundAsset = InnerObject;
					}
				}
				return true;
			}, /*bIncludeNestedObjects*/ false);

			FName AssetName;
			if (FoundAsset)
			{
				FAssetToolsModule& AssetToolsModule = FModuleManager::LoadModuleChecked<FAssetToolsModule>(
					TEXT("AssetTools"));
				TWeakPtr<IAssetTypeActions> AssetTypeActions = AssetToolsModule.Get().GetAssetTypeActionsForClass(
					FoundAsset->GetClass());
				if (AssetTypeActions.IsValid())
				{
					AssetName = *AssetTypeActions.Pin()->GetObjectDisplayName(FoundAsset);
				}
				else
				{
					AssetName = FoundAsset->GetFName();
				}
			}
			bool bValid = Func.Execute(AssetName.ToString()); 
			if (bValid)
			{
				PackagesToSave.Add(ExternalPackage);

				FString PackageFilename;
				auto Package = ExternalPackage;
				if (FPackageName::TryConvertLongPackageNameToFilename(Package->GetName(), PackageFilename,
																	  Package->ContainsMap()
																		  ? FPackageName::GetMapPackageExtension()
																		  : FPackageName::GetAssetPackageExtension()))
				{
					Dict.Add(Package->GetName(), AssetName.ToString());
				}
			}
		}
	}

	TArray<FString> Content;
	for(auto It : Dict)
	{
		Content.Add(FString::Printf(TEXT("%s, %s"), *It.Value, *It.Key));
	}
	Content.Sort();

	FFileHelper::SaveStringArrayToFile(Content, *FPaths::Combine(FPaths::ProjectSavedDir(), FileName));
}
static void DumpNavActor(const FString& FileName)
{
	auto One = FDumpFilterFunction::CreateLambda([](FString AssetName)
	{
		bool bNavData = (AssetName.Find("NavDataChunkActor") != -1 || AssetName.Find("RecastNavMesh") != -1);
		return bNavData;
	});
	DumpNavActor(FileName, One);
}
static void DumpAllActor(const FString& FileName)
{
	auto One = FDumpFilterFunction::CreateLambda([](FString AssetName)
	{
		return true;
	});
	DumpNavActor(FileName, One);
}

/// 如果有相同Map的其他类型的文件修改，那么再重新Build地图
static bool IsValidBuild(UWorld* World)
{
	FString InLongPackageName = GetNameSafe(World->GetPackage());

	// 裁剪掉/Game。譬如/Game/Arts/Maps/Tiengen/LV_Tiengen_P -> /Arts/Maps/Tiengen/LV_Tiengen_P 
	FString BaseFolder = InLongPackageName.Mid(5);
	
	// 检查，是否合理
	const FString FullGameContentDir = FPaths::ConvertRelativePathToFull(FPaths::Combine(FPaths::ProjectContentDir(), "../", "../"));
	auto FilePath = FPaths::Combine(FullGameContentDir, "changelog.txt");
	
	UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Error, TEXT("WorkDir=%s"), *FullGameContentDir);

	TArray<FString> Lines;
	if(IFileManager::Get().FileExists(*FilePath))
	{
		FFileHelper::LoadFileToStringArray(Lines, *FilePath);			
	}

	// 如果没有，或者文件是空的，那么认为可以执行
	if(Lines.Num() == 0)
	{
		return true;
	}

	// 如果有umap文件，那么也返回真
	FString MapFilePath = BaseFolder + TEXT(".umap"); 
	auto mapEle = Lines.FindByPredicate([MapFilePath](const FString& X)
	{
		return X.Find(MapFilePath) >= 0;
	});
	if(mapEle != nullptr)
	{
		return true;
	}	
	
	// 加载所有
	FToolsLibrary::LoadAllRegion();
	// DumpNavActor(TEXT("nav-1.txt"));
	
	ULevel* Level = World->PersistentLevel;
	TArray<FString> CheckedOutPackagesFilenames;
	TMap<FString, FString> Dict;
	if (Level && Level->IsValidLowLevel())
	{
		// Check dirtiness if the level is using external objects, no need to save it needlessly
		bool bCheckDirty = Level->IsUsingExternalObjects();


		TArray<UPackage*> PackagesToSave;

		UPackage* LevelPackage = Level->GetPackage();
		// Get Packages to save
		if (!bCheckDirty || LevelPackage->IsDirty() || LevelPackage->HasAnyPackageFlags(PKG_NewlyCreated))
		{
			PackagesToSave.Add(LevelPackage);
		}

		// Get External Packages to save
		const TArray<UPackage*> ExternalPackages = Level->GetLoadedExternalObjectPackages();
		for (UPackage* ExternalPackage : ExternalPackages)
		{
			UObject* FoundAsset = nullptr;
			ForEachObjectWithPackage(ExternalPackage, [&FoundAsset](UObject* InnerObject)
			{
				if (InnerObject->IsAsset())
				{
					if (FAssetData::IsUAsset(InnerObject))
					{
						// If we found the primary asset, use it
						FoundAsset = InnerObject;
						return false;
					}
					// Otherwise, keep the first found asset but keep looking for a primary asset
					if (!FoundAsset)
					{
						FoundAsset = InnerObject;
					}
				}
				return true;
			}, /*bIncludeNestedObjects*/ false);

			FName AssetName;
			if (FoundAsset)
			{
				FAssetToolsModule& AssetToolsModule = FModuleManager::LoadModuleChecked<FAssetToolsModule>(
					TEXT("AssetTools"));
				TWeakPtr<IAssetTypeActions> AssetTypeActions = AssetToolsModule.Get().GetAssetTypeActionsForClass(
					FoundAsset->GetClass());
				if (AssetTypeActions.IsValid())
				{
					AssetName = *AssetTypeActions.Pin()->GetObjectDisplayName(FoundAsset);
				}
				else
				{
					AssetName = FoundAsset->GetFName();
				}
			}
			bool bNavData = (AssetName.ToString().Find("NavDataChunkActor") != -1 || AssetName.ToString().Find("RecastNavMesh") != -1); 
			if (true)
			{
				PackagesToSave.Add(ExternalPackage);

				FString PackageFilename;
				auto Package = ExternalPackage;
				if (FPackageName::TryConvertLongPackageNameToFilename(Package->GetName(), PackageFilename,
																	  Package->ContainsMap()
																		  ? FPackageName::GetMapPackageExtension()
																		  : FPackageName::GetAssetPackageExtension()))
				{
					FString RelativeShortName = Package->GetName();
					auto idx = RelativeShortName.Find(BaseFolder);
					if(idx > 0)
					{
						Dict.Add(RelativeShortName.Mid(idx), AssetName.ToString());						
					}
				}
			}
		}
	}

	// 格式化数据
	TArray<FString> ContentChangeList;
	FString Key1("Client/Content/");
	for(auto It : Lines)
	{
		int idx = It.Find(BaseFolder);
		
		if(idx > 0)
		{
			auto Short = It.Mid(idx);
			idx = Short.Find(".uasset");
			if(idx >= 0)
			{
				Short = Short.Mid(0, idx);
				ContentChangeList.Add(Short);
			}
		}
	}

	// Dump信息
	{
		TArray<FString> FileContent;
		for(auto It : ContentChangeList)
		{
			auto Obj = Dict.Find(It);
			FileContent.Add(FString::Printf(TEXT("%s, %s"), *It, Obj ? **Obj : TEXT("Unknown")));
		}
		FString DumpFilePath = FPaths::ProjectSavedDir() / FString("changelist-asset.txt");
		FFileHelper::SaveStringArrayToFile(FileContent, *DumpFilePath);
	}
	
	TMap<FString, FString> OtherAssets;
	for(auto It : ContentChangeList)
	{
		auto Obj = Dict.Find(It);
		if(Obj)
		{
			if(Obj->Find("NavDataChunkActor") || Obj->Find("RecastNavMesh"))
			{
				
			}
			else
			{
				OtherAssets.Add(It, *Obj);
			}
		}
		else
		{
			UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Warning, TEXT("Unknown Assets:%s"), *It);			
		}
	}

	for(auto It : OtherAssets)
	{
		UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Log, TEXT("Dirty Assets, File=%s, Actor=%s"), *It.Key, *It.Value);		
	}

	// 有其他文件变化，才允许
	if(OtherAssets.Num() > 0)
	{
		return true;
	}
	
	return false;
}


int32 UC7PartitionNavmeshBuildCommandlet::OldFlow(UWorld* World, FSavePackageFunction Callback)
{
	if(!World)
	{
		return -1;
	}
	
	if(!IsValidBuild(World))
	{
		UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Warning, TEXT("Nothing Changed! Skip Build!"));		
		return 0;
	}
	
	UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(World);
	
	ARecastNavMesh* NavMesh = nullptr;
	for (TActorIterator<ARecastNavMesh> It(World); It; ++It)
	{
		if (It)
		{
			NavMesh = *It;
		}
	}
	
	if(!NavMesh || !NavSys)
	{
		return -1;
	}

	bool OldFixSize = NavMesh->bFixedTilePoolSize > 0;
	bool OldPartition = NavMesh->bIsWorldPartitioned > 0;
	bool OldValue = OldFixSize || OldPartition;
	
			
	// worldpartition需要先把范围内的actor load进来
	if (World->IsPartitionedWorld())
	{
		UWorldPartition* WorldPartition = World->GetWorldPartition();
		check(WorldPartition);

		const FBox Bounds = NavSys->GetNavigableWorldBounds();
		UWorldPartitionEditorLoaderAdapter* EditorLoaderAdapter = WorldPartition->CreateEditorLoaderAdapter<FLoaderAdapterShape>(World, Bounds, TEXT("Navigable World"));
		EditorLoaderAdapter->GetLoaderAdapter()->SetUserCreated(false);
		EditorLoaderAdapter->GetLoaderAdapter()->Load();

		World->BlockTillLevelStreamingCompleted();
		WorldPartition->SetEnableStreaming(false);
	}

	const double BuildStartTime = FPlatformTime::Seconds();

	const double TickInterval = 0.1f;
	double MaxLoadingTime = 30.0f;
	while (MaxLoadingTime > 0) {
		GEditor->EngineLoop->Tick();
		FPlatformProcess::Sleep(0.0f);	// 让出cpu
		if (FPlatformTime::Seconds() - BuildStartTime >= MaxLoadingTime) {
			break;
		}
	}

	// 如果是大世界，那么改成非大世界，再打NavMesh
	if(OldValue)
	{
		UC7PartitionNavmeshBuildCommandlet::SetFixedTilePoolSize(false, false, false);				
	}
	
	FNavigationSystem::Build(*World);
						
	FToolsLibrary::ExportVoxData();

	///////////////////////// 以上是旧流程，需要导出Vox ///////////////////////////////////////////

	// 还原回来
	if(OldValue)
	{
		UC7PartitionNavmeshBuildCommandlet::SetFixedTilePoolSize(true, OldFixSize, OldPartition);				
	}

	// 安全起见，重新打开一下
	FString InLongPackageName = GetNameSafe(World->GetPackage());
	UEditorLoadingAndSavingUtils::NewBlankMap(false);
	
	FEditorFileUtils::LoadMap(InLongPackageName);
	World = GEditor->GetEditorWorldContext().World();
	
	int Ret = UC7PartitionNavmeshBuildCommandlet::DoAction(World, Callback);
	// DumpAllActor(TEXT("actor.txt"));	
	// DumpNavActor(TEXT("nav-2.txt"));
	if(Ret != 0)
	{
		UE_LOG(LogC7PartitionNavmeshBuildCommandlet, Error, TEXT("Failed! Build Partition NavMesh! Result=%d"), Ret);		
	}
	
	return Ret;
}

void UC7PartitionNavmeshBuildCommandlet::SetFixedTilePoolSize(bool save, bool bFixedTilePoolSize, bool bIsWorldPartitioned)
{
	auto World = GEditor->GetEditorWorldContext().World();
	ARecastNavMesh* NavMesh = nullptr;
	for (TActorIterator<ARecastNavMesh> It(World); It; ++It)
	{
		if (It)
		{
			NavMesh = *It;
		}
	}
	if(NavMesh)
	{
		NavMesh->bFixedTilePoolSize = bFixedTilePoolSize;
		NavMesh->bIsWorldPartitioned = bIsWorldPartitioned;
		if(save)
		{
			FToolsLibrary::DoSavePackage(NavMesh->GetPackage());			
		}
	}	
}

#undef LOCTEXT_NAMESPACE
