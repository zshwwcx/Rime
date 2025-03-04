// Fill out your copyright notice in the Description page of Project Settings.


#include "AutoBuildPathsCommandlet.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "EditorBuildUtils.h"
#include "FileHelpers.h"
#include "LevelEditorActions.h"
#include "LightingBuildOptions.h"
#include "UnrealEdGlobals.h"
#include "NavigationSystem.h"
#include "Developer/AssetTools/Public/AssetToolsModule.h"
#include "Engine/MapBuildDataRegistry.h"
#include "GameFramework/WorldSettings.h"
#include "Editor/UnrealEdEngine.h"

DEFINE_LOG_CATEGORY_STATIC(LogAutoBuildPaths, Log, All);

UAutoBuildPathsCommandlet::UAutoBuildPathsCommandlet()
{
	
}

int32 UAutoBuildPathsCommandlet::Main(const FString& Params)
{
	UE_LOG(LogAutoBuildPaths, Display, TEXT("Cmd Build Path"));
	
	TArray<FString> Tokens;
	TArray<FString> Switches;
	TMap<FString, FString> ParamsMap;
	ParseCommandLine(*Params, Tokens, Switches, ParamsMap);
	
	TArray<FString> MapPaths;
	ParamsMap["paths"].ParseIntoArray(MapPaths, TEXT(";"), true);
	for (FString MapPath : MapPaths)
	{
		FString LPName;
		FPackageName::TryConvertFilenameToLongPackageName(MapPath,LPName);
		FString MapObjectPath = LPName.Replace(TEXT("Client/Content"),TEXT("/Game"));
		if(UWorld* AssetWorld = UEditorLoadingAndSavingUtils::LoadMap(MapObjectPath))
		{
			if(!AssetWorld->PersistentLevel->MapBuildData)
			{
				AssetWorld->PersistentLevel->GetOrCreateMapBuildData();
			}

			//Build Paths
			AssetWorld->WorldType = EWorldType::Editor;
			FNavigationSystem::AddNavigationSystemToWorld(*AssetWorld, FNavigationSystemRunMode::EditorMode);
			UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(AssetWorld);
			if (NavSys && NavSys->IsThereAnywhereToBuildNavigation())
			{
				FString MapName = AssetWorld->GetMapName();
				UE_LOG(LogAutoBuildPaths, Display, TEXT("CurrBuildPathMap: %s"), *MapName);
				
				NavSys->Build();
			}

			//Precompute Static Visibility
			if (AssetWorld->GetWorldSettings()->bPrecomputeVisibility)
			{
				UE_LOG(LogAutoBuildPaths, Display, TEXT("Precompute Visibility"));
		
				BuildLightingOnly_VisibilityOnly_Execute(AssetWorld);
			}

			//Build Texture Streaming
			FEditorBuildUtils::EditorBuildTextureStreaming(AssetWorld);

			//Save
			SaveBuildData(AssetWorld);
		}
	}
	// auto& AssetRegistryModule = FModuleManager::Get().LoadModuleChecked<FAssetRegistryModule>(TEXT("AssetRegistry"));
	// auto& AssetRegistry = AssetRegistryModule.Get();
	// TArray<FAssetData> AssetDatas;
	// UClass* TargetClass = UWorld::StaticClass();
	// AssetRegistry.GetAssetsByClass(TargetClass->GetFName(), AssetDatas, true);
	// for (const FAssetData& Asset : AssetDatas)
	// {
	// 	
	// 	if(UWorld* AssetWorld = UEditorLoadingAndSavingUtils::LoadMap(Asset.ObjectPath.ToString()))
	// 	{
	// 		if(!AssetWorld->PersistentLevel->MapBuildData)
	// 		{
	// 			AssetWorld->PersistentLevel->GetOrCreateMapBuildData();
	// 		}
	// 		
	// 		AssetWorld->WorldType = EWorldType::Editor;
	// 		FNavigationSystem::AddNavigationSystemToWorld(*AssetWorld, FNavigationSystemRunMode::EditorMode);
	// 		UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(AssetWorld);
	// 		if (NavSys && NavSys->IsThereAnywhereToBuildNavigation())
	// 		{
	// 			FString MapName = AssetWorld->GetMapName();
	// 			UE_LOG(LogAutoBuildPaths, Display, TEXT("CurrBuildPathMap: %s"), *MapName);
	// 			NavSys->Build();
	// 		
	// 			SaveBuildData(AssetWorld);
	// 		}
	// 	}
	// }
	
	return 0;
}

void UAutoBuildPathsCommandlet::BuildLightingOnly_VisibilityOnly_Execute(UWorld* WorldToSave)
{
	// Configure build options
	FLightingBuildOptions LightingBuildOptions;
	LightingBuildOptions.bOnlyBuildVisibility = true;
	FLevelEditorActionCallbacks::ConfigureLightingBuildOptions( LightingBuildOptions );
	
	GUnrealEd->BuildLighting(LightingBuildOptions);

	// Reset build options
	FLevelEditorActionCallbacks::ConfigureLightingBuildOptions( FLightingBuildOptions() );
}

void UAutoBuildPathsCommandlet::SaveBuildData(UWorld* WorldToSave)
{
	if (!WorldToSave)
	{
		return;
	}
	
	TArray<UPackage*> PackagesToSave;
	UPackage* WorldPackage = WorldToSave->GetOutermost();
	ULevel* Level = WorldToSave->PersistentLevel;
	if (Level->MapBuildData)
	{
		UPackage* BuiltDataPackage = Level->MapBuildData->GetOutermost();
		if (BuiltDataPackage != WorldPackage)
		{
			PackagesToSave.Add(BuiltDataPackage);
		}
	}
	UEditorLoadingAndSavingUtils::SavePackages(PackagesToSave, false);
}

