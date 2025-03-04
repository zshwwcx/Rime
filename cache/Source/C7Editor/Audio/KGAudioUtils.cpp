#include "KGAudioUtils.h"

#include "AssetViewUtils.h"
#include "C7ShapeCollisionComponent.h"
#include "FileHelpers.h"
#include "KGAkAudioManager.h"
#include "LevelEditorSubsystem.h"
#include "PackageHelperFunctions.h"
#include "SourceControlHelpers.h"
#include "Audio/C7AkAudioVolume.h"
#include "Kismet/GameplayStatics.h"

void KGAudioUtils::BatchAudioActorProcess_InCurrentLevel()
{
	ProcessInCurrentLevel<AC7AkAudioVolume>(SelfDefinedFunc);
}

void KGAudioUtils::BatchAudioActorProcess_InAllSoundLevel()
{
	ProcessInAllSoundLevels<AC7AkAudioVolume>(SelfDefinedFunc);
}

void KGAudioUtils::SelfDefinedFunc(AActor* Actor)
{
	// 处理AudioVolume
	if (AC7AkAudioVolume* Volume = Cast<AC7AkAudioVolume>(Actor))
	{
		// FKGGroupState GroupState;
		// for (auto It : Volume->GroupStateOnEnter)
		// {
		// 	GroupState.Group = It.Key;
		// 	GroupState.State = It.Value;
		// 	Volume->GroupState.Add(GroupState);
		// }

		// if (UC7ShapeCollisionComponent* ShapeCollision = Volume->GetComponentByClass<UC7ShapeCollisionComponent>())
		// {
		// 	if (Volume->Shape == EC7AkAudioVolumeShape::Box)
		// 	{
		// 		ShapeCollision->InitCollisionAsBox(Volume->BoxExtent);
		// 	}
		// 	else
		// 	{
		// 		ShapeCollision->InitCollisionAsSphere(Volume->Radius);
		// 	}
		// }
		//
		// Volume->Modify();
		// if (!Volume->MarkPackageDirty())
		// {
		// 	UE_LOG(LogTemp,Error, TEXT("KGAudioUtils::SelfDefinedFunc %s MarkPackageDirty failed"), *Volume->GetName());
		// }
	}
}

template <class T>
void KGAudioUtils::ProcessInAllSoundLevels(TFunction<void(AActor* Actor)> Func)
{
	TArray<FString> MapPackageNames;

	TArray<FString> AllFileNames;
	FEditorFileUtils::FindAllPackageFiles(AllFileNames);
	const FString EngineContent = "Engine/Content";
	for (int32 Idx = 0; Idx < AllFileNames.Num(); ++Idx)
	{
		FString FileName = AllFileNames[Idx];
		if (FPaths::GetExtension(FileName, true) == FPackageName::GetMapPackageExtension() && !FileName.Contains(EngineContent) && FileName.EndsWith("_Sound.umap"))
		{
			const FString MapPackageName = FPackageName::FilenameToLongPackageName(FileName);
			MapPackageNames.AddUnique(MapPackageName);
		}
	}

	for (int32 Idx = 0; Idx < MapPackageNames.Num(); ++Idx)
	{
		FString MapPackageName = MapPackageNames[Idx];
		if (!GEditor->GetEditorSubsystem<ULevelEditorSubsystem>()->LoadLevel(MapPackageName))
		{
			UE_LOG(LogTemp, Error, TEXT("%s, %s load failed"), *FString(__FUNCTION__), *MapPackageName);
			continue;
		}

		UWorld* World = GEditor->GetEditorWorldContext().World();
		check(World);

		if (World->IsPartitionedWorld())
		{
			continue;
		}

		TArray<AActor*> OutActors;
		UGameplayStatics::GetAllActorsOfClass(World, T::StaticClass(), OutActors);

		for (AActor* Actor : OutActors)
		{
			Func(Actor);
		}
		
		if (OutActors.Num() > 0)
		{
			World->Modify();
			SourceControlHelpers::CheckOutFile(MapPackageName);
			FEditorFileUtils::SaveCurrentLevel();
		}
	}
}

template <class T>
void KGAudioUtils::ProcessInCurrentLevel(TFunction<void(AActor* Actor)> Func)
{
	UWorld* World = GEditor->GetEditorWorldContext().World();
	if (!World)
	{
		return;
	}

	TArray<AActor*> OutActors;
	UGameplayStatics::GetAllActorsOfClass(World, T::StaticClass(), OutActors);

	for (AActor* Actor : OutActors)
	{
		Func(Actor);
	}
}
