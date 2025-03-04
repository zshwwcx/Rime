#include "C7NavmeshAndVoxBuildCommandlet.h"
#include "LevelEditorSubsystem.h"
#include "Engine/ObjectLibrary.h"
#include "EditorExtenders/ToolsLibrary.h"
#include "Navmesh/RecastNavMeshGenerator.h"
#include "EngineUtils.h"
#include "NavigationData.h"
#include "Engine/MapBuildDataRegistry.h"
#include "AssetToolsModule.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "ISourceControlModule.h"
#include "ISourceControlProvider.h"
#include "WorldPartition/WorldPartition.h"
#include "WorldPartition/WorldPartitionEditorLoaderAdapter.h"
#include "WorldPartition/LoaderAdapter/LoaderAdapterShape.h"
#include "FileAsset/GPEditorAssetHelper.h"
#include "C7PartitionNavmeshBuildCommandlet.h"
#include "FileHelpers.h"


DEFINE_LOG_CATEGORY(LogC7NavmeshAndVoxBuildCommandlet);

UC7NavmeshAndVoxBuildCommandlet::UC7NavmeshAndVoxBuildCommandlet()
{
}

int32 UC7NavmeshAndVoxBuildCommandlet::Main(const FString& InCommandline)
{
	UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Display, TEXT("commandlet start."))
		ParseCommandLine(*InCommandline, Tokens, Switches);

	for (int32 SwitchIdx = Switches.Num() - 1; SwitchIdx >= 0; --SwitchIdx)
	{
		FString& Switch = Switches[SwitchIdx];
		TArray<FString> SplitSwitch;
		if (2 == Switch.ParseIntoArray(SplitSwitch, TEXT("="), true))
		{
			Params.Add(SplitSwitch[0].ToUpper(), SplitSwitch[1].TrimQuotes());
			Switches.RemoveAt(SwitchIdx);
		}
	}
	FString ValidCmdResult;
	if (!ValidParams({ MAP_NAME }, ValidCmdResult))
	{
		UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Warning, TEXT("parse commandlet failed! [%s]"), *ValidCmdResult);
		return -1;
	}
	auto ObjectLibrary = UObjectLibrary::CreateLibrary(UWorld::StaticClass(), false, true);
	ObjectLibrary->LoadAssetDataFromPath(TEXT("/Game/Arts/Maps"));
	TArray<FString> MapFiles;
	FString SubPath = TEXT("Arts/Maps");
	FString FullPath = FPaths::Combine(FPaths::ProjectContentDir(), SubPath);
	IFileManager::Get().FindFilesRecursive(MapFiles, *FullPath, TEXT("*.umap"), true, false, false);
	TMap<FString, TSet<FString>> AllMaps;
	for (int32 i = 0; i < MapFiles.Num(); i++)
	{
		int32 lastSlashIndex = -1;
		FString FullMapFile = MapFiles[i];
		if (FullMapFile.FindLastChar('/', lastSlashIndex))
		{
			FString pureMapName;

			// length - 5 because of the ".umap" suffix
			for (int32 j = lastSlashIndex + 1; j < FullMapFile.Len() - 5; j++)
			{
				pureMapName.AppendChar(FullMapFile[j]);
			}
			int32 mapsIndex = -1;
			mapsIndex = FullMapFile.Find(SubPath);
			FString pureMapPath;
			for (int32 j = mapsIndex + SubPath.Len() + 1; j < FullMapFile.Len() - 5; j++)
			{
				pureMapPath.AppendChar(FullMapFile[j]);
			}
			AllMaps.FindOrAdd(pureMapName).Add(pureMapPath);
		}
	}
	const FString MapName = GetParamAsString(MAP_NAME);
	int total = 0;
	int succ = 0;
	if (!AllMaps.Contains(MapName)) {
		UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Warning, TEXT("MapName[%s] not found!!!"), *MapName);
		return 0;
	}
	else {
		total = AllMaps.Find(MapName)->Num();
		UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Display, TEXT("MapName[%s] found [%d] numbers!!!"), *MapName, total);
	}
	for (FString& FullName : *AllMaps.Find(MapName))
	{
		FString LevelAssetPath = FPaths::Combine(TEXT("/Game/Arts/Maps/"), FullName);
		UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Display, TEXT("The Map's Full Path Is [%s] "), *LevelAssetPath);
		if (!GEditor->GetEditorSubsystem<ULevelEditorSubsystem>()->LoadLevel(LevelAssetPath))
		{
			UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Warning, TEXT("MAP[%s] LevelAssetPath load Failed!!!"), *LevelAssetPath);
			continue;
		}

		UWorld* World = GEditor->GetEditorWorldContext().World();
		if (!World)
		{
			UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Warning, TEXT("MAP[%s] Build Navigation Failed!!! The World Is None!!!"), *LevelAssetPath);
			continue;
		}

		// 如果p4没连接的话，需要重新连接一下
		ISourceControlProvider& SourceControlProvider = ISourceControlModule::Get().GetProvider();
		if (TEXT("Perforce") != SourceControlProvider.GetName())
		{
			ISourceControlModule::Get().SetProvider(TEXT("Perforce"));
		}

		bAutoCheckOut = true;

		// 新的大世界NavMesh制作流程
		bool UseBigWorldNavMesh = false;
		bool OldValue = false;
		if (World->IsPartitionedWorld())
		{
			ARecastNavMesh* NavMesh = nullptr;
			for (TActorIterator<ARecastNavMesh> It(World); It; ++It)
			{
				if (It)
				{
					NavMesh = *It;
				}
			}

			if (NavMesh && NavMesh->bIsWorldPartitioned)
			{
				UseBigWorldNavMesh = true;
			}
		}
		else
		{
			World->LoadSecondaryLevels(true, nullptr);
		}

		UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(World);
		if (!NavSys)
		{
			UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Warning,
				TEXT("MAP[%s] Build Navigation Failed!!! NavigationSystem Is None!!!"), *LevelAssetPath);
			continue;
		}

		// 暂时先关闭。这块数值配置的不是很合理，合理后再开启此功能
		if (UseBigWorldNavMesh && false)
		{
			auto one = FSavePackageFunction::CreateLambda([this](UPackage* Package, TArray<FString>& SublevelFilenames)
				{
					this->CheckoutAndSavePackage(Package, SublevelFilenames, this->bSkipCheckedOutFiles);
				});

			// 大世界的NavMesh流程
			if (UC7PartitionNavmeshBuildCommandlet::OldFlow(World, one) == 0) {
				succ++;
			}
			continue;
		}

		// worldpartition需要先把范围内的actor load进来
		if (World->IsPartitionedWorld())
		{
			UWorldPartition* WorldPartition = World->GetWorldPartition();
			check(WorldPartition);

			const FBox Bounds = NavSys->GetNavigableWorldBounds();
			UWorldPartitionEditorLoaderAdapter* EditorLoaderAdapter = WorldPartition->CreateEditorLoaderAdapter<
				FLoaderAdapterShape>(World, Bounds, TEXT("Navigable World"));
			EditorLoaderAdapter->GetLoaderAdapter()->SetUserCreated(false);
			EditorLoaderAdapter->GetLoaderAdapter()->Load();

			World->BlockTillLevelStreamingCompleted();
			WorldPartition->SetEnableStreaming(false);
		}

		const double BuildStartTime = FPlatformTime::Seconds();

		const double TickInterval = 0.1f;
		double MaxLoadingTime = 30.0f;
		while (MaxLoadingTime > 0)
		{
			GEditor->EngineLoop->Tick();
			FPlatformProcess::Sleep(0.0f); // 让出cpu
			if (FPlatformTime::Seconds() - BuildStartTime >= MaxLoadingTime)
			{
				break;
			}
		}

		FNavigationSystem::Build(*World);

		UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Display, TEXT("MAP[%s] Build Navigation Success"), *LevelAssetPath);

		bool bBuildAndCheckOutNavmesh = false;

		if (World->IsPartitionedWorld())
		{
			FAssetToolsModule& AssetToolsModule = FModuleManager::LoadModuleChecked<FAssetToolsModule>(
				TEXT("AssetTools"));
			if (ULevel* Level = World->PersistentLevel)
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
				bool bFoundRecastNavMesh = false;
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
						TWeakPtr<IAssetTypeActions> AssetTypeActions = AssetToolsModule.Get().
							GetAssetTypeActionsForClass(FoundAsset->GetClass());
						if (AssetTypeActions.IsValid())
						{
							AssetName = *AssetTypeActions.Pin()->GetObjectDisplayName(FoundAsset);
						}
						else
						{
							AssetName = FoundAsset->GetFName();
						}
					}
					if (AssetName.ToString().Find("RecastNavMesh") != INDEX_NONE)
					{
						bFoundRecastNavMesh = true;
						if (ExternalPackage->IsDirty())
						{
							if (UEditorLoadingAndSavingUtils::SavePackages({ ExternalPackage }, true))
							{
								UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Display, TEXT("Check Out Recast NavMesh Suc: %s"), *ExternalPackage->GetName())
									bBuildAndCheckOutNavmesh = true;
							}
							else
							{
								UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Error, TEXT("Check Out Recast NavMesh Failed: %s"), *ExternalPackage->GetName())
							}
						}
						else
						{
							UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Error, TEXT("Check Out Recast NavMesh Failed, Navmesh is not dirty: %s"), *ExternalPackage->GetName())
						}
					}
				}
				if (!bFoundRecastNavMesh)
				{
					UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Error, TEXT("Can not find recast navmesh actor!!"));
				}
			}
			else
			{
				UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Error, TEXT("PersistentLevel is null!!"))
			}
		}
		else
		{
			FString WorldPackageName;
			if (FPackageName::DoesPackageExist(World->GetOutermost()->GetName(), &WorldPackageName))
			{
				TArray<FString> CheckedOutPackagesFilenames;
				UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Display, TEXT("MAP[%s] Get WorldPackageName: %s"), *LevelAssetPath, *WorldPackageName);
				FString LeftStr;
				FString RightStr;
				WorldPackageName.Split("_P.umap", &LeftStr, &RightStr);
				FString NavMeshUMap = LeftStr + "_NavMesh.umap";
				TArray<FString> ParseResults;
				NavMeshUMap.ParseIntoArray(ParseResults, TEXT("/"));
				FString NavMeshName;
				ParseResults.Last().Split(".umap", &NavMeshName, &RightStr);

				// 找到Navmesh对应的umap并保存
				for (ULevelStreaming* StreamingLevel : World->GetStreamingLevels())
				{
					if (!StreamingLevel)
					{
						continue;
					}
					FString PackageName = StreamingLevel->GetWorldAssetPackageName();
					PackageName.ParseIntoArray(ParseResults, TEXT("/"));
					UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Display, TEXT("MAP[%s] PackageName[%s], NavMeshName[%s], LastName[%s]"), *LevelAssetPath, *PackageName, *NavMeshName, *ParseResults.Last());
					// TODO: 改进这里的报错日志
					if (NavMeshName == ParseResults.Last())
					{
						UPackage* Package = FindPackage(nullptr, *PackageName);
						if (!Package)
						{
							Package = LoadPackage(nullptr, *PackageName, LOAD_None);
						}
						if (Package)
						{
							if (CheckoutFile(NavMeshName))
							{
								CheckoutAndSavePackage(Package, CheckedOutPackagesFilenames, bSkipCheckedOutFiles);
								bBuildAndCheckOutNavmesh = true;

								UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Display, TEXT("MAP[%s] Export navmesh succeed, the path is : %s"), *LevelAssetPath, *NavMeshName);
							}
							else
							{
								UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Error, TEXT("MAP[%s] Check out navmesh failed, the path is : %s"), *LevelAssetPath, *NavMeshName);
							}
						}
						else
						{
							UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Error, TEXT("MAP[%s] Can not load Package: %s"), *LevelAssetPath, *PackageName);
						}
						break;
					}
				}
			}
			else
			{
				UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Error, TEXT("MAP[%s] Package is not existed: %s"), *LevelAssetPath, *World->GetOutermost()->GetName());
			}
		}
		if (bBuildAndCheckOutNavmesh)
		{
			if (ANavigationData* NavData = Cast<ANavigationData>(NavSys->GetMainNavData()))
			{
				FToolsLibrary::ExportVoxel();
				FToolsLibrary::ExportNavmesh();
				UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Display, TEXT("MAP[%s] GenerateVox Succeed!!!"), *LevelAssetPath);

				GPEditorAssetHelper::ExportSceneActorDataNew();
				succ++;
			}
			else
			{
				UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Warning, TEXT("MAP[%s] GenerateVox Failed!!! Nav Data Is None!!!"), *LevelAssetPath)
			}
		}
		else
		{
			UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Warning, TEXT("MAP[%s] GenerateVox Failed!!! Build Navmesh or Check Out Nav Failed!!!"), *LevelAssetPath)
		}
	}

	UE_LOG(LogC7NavmeshAndVoxBuildCommandlet, Display, TEXT("GenerateVox finish, total %d, succ %d"), total, succ);
	return total == succ ? 0 : -1;
}

bool UC7NavmeshAndVoxBuildCommandlet::ValidParams(const TArray<FString>& InParamArray, FString& ErrorMessage)
{
	bool bValid = true;
	ErrorMessage = TEXT("");

	TArray<FString> MissingParams;
	for (const FString& ParamName : InParamArray)
	{
		if (!HasParam(ParamName))
		{
			MissingParams.Add(FString::Printf(TEXT("-%s"), *ParamName));
			bValid = false;
		}
	}

	if (!bValid)
	{
		ErrorMessage = FString::Printf(
			TEXT("Commandline invalid! Missing params in command line[%s]!"), *FString::Join(MissingParams, TEXT(" ")));
	}

	return bValid;
}

bool UC7NavmeshAndVoxBuildCommandlet::HasParam(const FString& InParamName) const
{
	const FString* Value = Params.Find(InParamName.ToUpper());
	return (Value != nullptr);
}

FString UC7NavmeshAndVoxBuildCommandlet::GetParamAsString(const FString& InParamName,
                                                          const FString& InDefaultValue /*= TEXT("")*/) const
{
	const FString* Value = Params.Find(InParamName.ToUpper());
	return Value ? *Value : InDefaultValue;
}
