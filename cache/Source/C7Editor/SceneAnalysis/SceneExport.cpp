// Copyright KuaiShou Games, Inc. All Rights Reserved.
// Author: zonghua03@kuaishou.com

#include "FileHelpers.h"
#include "MeshDescription.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Materials/MaterialInstance.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/SCS_Node.h"
#include "Engine/SimpleConstructionScript.h"
#include "Engine/StaticMeshActor.h"
#include "Kismet2/BlueprintEditorUtils.h"
#include "WorldPartition/WorldPartitionRuntimeSpatialHash.h"
#include "WorldPartition/WorldPartitionHelpers.h"

#if WITH_EDITOR
namespace SceneExport
{
	FAutoConsoleCommand SetBPAssetToStatic(TEXT("SceneExport.SetBPAssetToStatic"), TEXT("SceneExport.SetBPAssetToStatic"),
		FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
		{
			FString DirectoryPath = Args[0];

			FAssetRegistryModule& AssetRegistryModule = FModuleManager::LoadModuleChecked<FAssetRegistryModule>(TEXT("AssetRegistry"));
			IAssetRegistry& AssetRegistry = AssetRegistryModule.Get();

			FARFilter Filter;
			Filter.PackagePaths.Add(FName(*DirectoryPath));
			Filter.bRecursivePaths = true;
			Filter.bRecursiveClasses = true;

			TArray<FAssetData> AssetList;
			AssetRegistry.GetAssets(Filter, AssetList);

			for (const FAssetData& AssetData : AssetList)
			{
				if(AssetData.AssetClassPath != UBlueprint::StaticClass()->GetClassPathName())
				{
					continue;
				}

				UBlueprint* Blueprint = Cast<UBlueprint>(StaticLoadObject(UBlueprint::StaticClass(), nullptr, *AssetData.GetObjectPathString()));

				if(!Blueprint)
				{
					UE_LOG(LogTemp, Error, TEXT("Failed to load blueprint: %s"), *AssetData.GetObjectPathString());
					continue;
				}

				USimpleConstructionScript* SCS = Blueprint->SimpleConstructionScript;
				if (SCS)
				{
					const TArray<USCS_Node*>& Nodes = SCS->GetAllNodes();
					for (USCS_Node* Node : Nodes)
					{
						if (Node)
						{
							UActorComponent* ComponentTemplate = Node->ComponentTemplate;
							if (UPrimitiveComponent* PrimitiveComponent = Cast<UPrimitiveComponent>(ComponentTemplate))
							{
								PrimitiveComponent->SetMobility(EComponentMobility::Static);
							}
						}
					}
				}

				FBlueprintEditorUtils::MarkBlueprintAsModified(Blueprint);
			}

			FEditorFileUtils::SaveDirtyPackages(false, true, true, false);
		}));
}
#endif