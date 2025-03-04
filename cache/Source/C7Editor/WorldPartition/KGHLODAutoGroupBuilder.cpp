// Fill out your copyright notice in the Description page of Project Settings.


#include "KGHLODAutoGroupBuilder.h"

#include "LandscapeProxy.h"
#include "UObject/SavePackage.h"
#include "WorldPartition/ActorDescContainerCollection.h"
#include "WorldPartition/WorldPartition.h"
#include "WorldPartition/WorldPartitionHelpers.h"
#include "WorldPartition/HLOD/HLODLayer.h"
#include "WorldPartition/HLOD/HLODActor.h"

DEFINE_LOG_CATEGORY_STATIC(LogWorldPartitionHLODAutoGroupBuilder, All, All);

static bool FilterByNameRegex(FWorldPartitionReference& ActorReference, const TArray<FString>& RegexList, TFunction<void(AActor*)> MatchedJob)
{
	if (MatchedJob == nullptr)
	{
		return true;
	}

	AActor* Actor = ActorReference.GetActor();
	if (!Actor)
	{
		return true;
	}
	
	auto ActorName = Actor->GetActorLabel();
	for (auto PatternString : RegexList)
	{
		if (PatternString.Len() <= 2)
		{
			UE_LOG(LogWorldPartitionHLODAutoGroupBuilder, Warning, TEXT("bad regex:%s, regex string length must > 2"), *PatternString);
			continue;
		}
		FRegexPattern Pattern(PatternString);
		FRegexMatcher Matcher(Pattern, ActorName);
		if (Matcher.FindNext())
		{
			UE_LOG(LogWorldPartitionHLODAutoGroupBuilder, Display, TEXT("found match actor %s with regex:%s"), *ActorName, *PatternString);
			MatchedJob(Actor);
			return true;
		}
	}
	return false;
}

static bool FilterByMaterial(FWorldPartitionReference& ActorReference, const TArray<UMaterialInterface*>& MaterialList, TFunction<void(AActor*)> MatchedJob)
{
	if (MatchedJob == nullptr)
	{
		return true;
	}

	AActor* Actor = ActorReference.GetActor();
	if (!Actor)
	{
		return true;
	}

	TArray<UPrimitiveComponent*> PrimitiveComponents;
	Actor->GetComponents(PrimitiveComponents);
	if (PrimitiveComponents.IsEmpty())
	{
		return true;
	}

	

	for (int32 PrimitiveIndex = 0; PrimitiveIndex < PrimitiveComponents.Num(); ++PrimitiveIndex)
	{
		UPrimitiveComponent* PrimitiveComponent = PrimitiveComponents[PrimitiveIndex];
		for (int32 MaterialIndex = 0; MaterialIndex < PrimitiveComponent->GetNumMaterials(); ++MaterialIndex)
		{
			UMaterialInterface* MaterialInterface = PrimitiveComponent->GetMaterial(MaterialIndex);
			if (MaterialInterface == nullptr)
			{
				continue;
			}

			UMaterialInterface* ParentMaterial = MaterialInterface;

			while (ParentMaterial != nullptr)
			{
				if (MaterialList.Contains(ParentMaterial))
				{
					MatchedJob(Actor);
					return true;
				}

				UMaterialInstance* MaterialInstance = Cast<UMaterialInstance>(ParentMaterial);
				if (MaterialInstance == nullptr)
				{
					break;
				}

				ParentMaterial = MaterialInstance->Parent;
			}
		}
	}
	

	return false;
}

bool UKGHLODAutoGroupBuilder::RunInternal(UWorld* World, const FCellInfo& InCellInfo,
                                          FPackageSourceControlHelper& PackageHelper)
{
	auto CheckoutAndSave = [&PackageHelper](UPackage* ModifyPackage)
	{
		FString PackageFileName = SourceControlHelpers::PackageFilename(ModifyPackage);
		if (FPlatformFileManager::Get().GetPlatformFile().FileExists(*PackageFileName))
		{
			if (!PackageHelper.Checkout(ModifyPackage))
			{
				return false;
			}
		}
		
		FSavePackageArgs SaveArgs;
		SaveArgs.TopLevelFlags = RF_Standalone;
		SaveArgs.SaveFlags = ESaveFlags::SAVE_Async;
		return UPackage::SavePackage(ModifyPackage, nullptr, *PackageFileName, SaveArgs);
	};
	
	UE_LOG(LogWorldPartitionHLODAutoGroupBuilder, Display, TEXT("UKGHLODAutoGroupBuilder Start Run"));
	const UKGHLODAutoGroupBuilderSettings* Setting = GetDefault<UKGHLODAutoGroupBuilderSettings>();
	if (Setting->SceneAutoGroupSettings.IsEmpty())
	{
		UE_LOG(LogWorldPartitionHLODAutoGroupBuilder, Error, TEXT("No SceneAutoGroupSettings found in UKGHLODAutoGroupBuilderSettings, please add at least one."));
		return false;
	}
	
	auto WorldPartition = World->GetWorldPartition();
	TArray<FGuid> ActorGuids;

	FSceneAutoGroupSettings SceneAutoGroupSettings;
	bool bFoundSettings = false;
	for (auto SceneSetting : Setting->SceneAutoGroupSettings)
	{
		if (SceneSetting.LevelNames.Contains(World->GetName()))
		{
			SceneAutoGroupSettings = SceneSetting;
			bFoundSettings = true;
			break;
		}
	}

	if (!bFoundSettings)
	{
		UE_LOG(LogWorldPartitionHLODAutoGroupBuilder, Warning, TEXT("No setting found for world %s, Use default setting at index 0"), *World->GetName());
		SceneAutoGroupSettings = Setting->SceneAutoGroupSettings[0];
	}
	
	for (FActorDescContainerInstanceCollection::TIterator<> ActorDescIterator(WorldPartition); ActorDescIterator; ++ActorDescIterator)
	{		
		FWorldPartitionReference ActorReference(WorldPartition, ActorDescIterator->GetGuid());
		AActor* Actor = ActorReference.GetActor();
		if(!Actor)
		{
			continue;
		}

		// Terrain HLOD is not very meaningful, disable it.
		bool bIsLandScape = Cast<ALandscapeProxy>(Actor) != nullptr;

		bool bNeedSave = false;
		bool IsMatched=false;
		for (auto HLODGroup : SceneAutoGroupSettings.HLODGroups)
		{
			if (bIsLandScape)
			{
				break;
			}
			
			auto HLODLayer = HLODGroup.HLODLayer.Get();
			if (!HLODLayer)
			{
				HLODLayer = LoadObject<UHLODLayer>(nullptr,*HLODGroup.HLODLayer.ToString());
			}

			if (HLODGroup.MatchMode == EMatchMode::ByName)
			{
				IsMatched = FilterByNameRegex(ActorReference, HLODGroup.RegexList, [HLODLayer, &bNeedSave](AActor* Actor)
				{
					if (Actor->GetHLODLayer() != HLODLayer || !Actor->bEnableAutoLODGeneration)
					{
						Actor->SetHLODLayer(HLODLayer);
						Actor->bEnableAutoLODGeneration = true;
						bNeedSave = true;
					}
				});
			}
			else if (HLODGroup.MatchMode == EMatchMode::ByMaterial)
			{
				IsMatched = FilterByMaterial(ActorReference, HLODGroup.MaterialList, [HLODLayer, &bNeedSave](AActor* Actor)
				{
					if (Actor->GetHLODLayer() != HLODLayer || !Actor->bEnableAutoLODGeneration)
					{
						Actor->SetHLODLayer(HLODLayer);
						Actor->bEnableAutoLODGeneration = true;
						bNeedSave = true;
					}
				});
			}
			
			if (IsMatched)
			{
				break;
			}
		}

		if (!IsMatched || bIsLandScape)
		{
			if (Actor->GetHLODLayer() != nullptr || Actor->bEnableAutoLODGeneration)
			{
				Actor->SetHLODLayer(nullptr);
				Actor->bEnableAutoLODGeneration = false;
				bNeedSave = true;
			}
		}
		
		//set actor grids
		IsMatched = false;
		for (auto GridGroup : SceneAutoGroupSettings.GridGroups)
		{
			if (GridGroup.MatchMode == EMatchMode::ByName)
			{
				IsMatched = FilterByNameRegex(ActorReference, GridGroup.RegexList, [GridGroup, &bNeedSave](AActor* Actor)
				{
					if (Actor->GetRuntimeGrid() != GridGroup.GridName)
					{
						Actor->SetRuntimeGrid(GridGroup.GridName);
						bNeedSave = true;
					}
				});
			}
			else if (GridGroup.MatchMode == EMatchMode::ByMaterial)
			{
				IsMatched = FilterByMaterial(ActorReference, GridGroup.MaterialList, [GridGroup, &bNeedSave](AActor* Actor)
				{
					if (Actor->GetRuntimeGrid() != GridGroup.GridName)
					{
						Actor->SetRuntimeGrid(GridGroup.GridName);
						bNeedSave = true;
					}
				});
			}
			
			if (IsMatched)
			{
				break;
			}
		}

		if (!IsMatched)
		{
			if (!Actor->GetRuntimeGrid().IsNone())
			{
				Actor->SetRuntimeGrid(NAME_None);
				bNeedSave = true;
			}
		}

		if (bNeedSave)
		{
			if (Actor->IsPackageExternal())
			{
				CheckoutAndSave(Actor->GetPackage());
			}
			else
			{
				Actor->MarkPackageDirty();
			}
		}
		
		if (FWorldPartitionHelpers::ShouldCollectGarbage())
		{
			FWorldPartitionHelpers::DoCollectGarbage();
		}
	}

	UPackage::WaitForAsyncFileWrites();
	
	return true;
}
