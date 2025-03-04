// Copyright KuaiShou Games, Inc. All Rights Reserved.
// Author: zonghua03@kuaishou.com

#include "MeshDescription.h"
#include "Materials/MaterialInstance.h"
#include "Components/StaticMeshComponent.h"
#include "WorldPartition/WorldPartitionRuntimeSpatialHash.h"
#include "WorldPartition/WorldPartitionHelpers.h"

#if WITH_EDITOR
namespace SceneAnalysis
{
	static bool ParseVector3f(FString Arg, FVector3f& Result)
	{
		if(Arg.StartsWith("(") && Arg.EndsWith(")"))
		{
			TArray<FString> ParsedStrings;
			Arg = Arg.Mid(1, Arg.Len() - 2);
			Arg.ParseIntoArray(ParsedStrings, TEXT(","), true);
			if(ParsedStrings.Num() != 3) return false;

			Result.X = FCString::Atof(*ParsedStrings[0]);
			Result.Y = FCString::Atof(*ParsedStrings[1]);
			Result.Z = FCString::Atof(*ParsedStrings[2]);
			return true;
		}
		return false;
	}
	
	struct FTextureInfo
	{
		FString Name;
		FString PathName;
		int SizeX;
		int SizeY;
		int ReferenceCount;
		FTextureInfo()
			: SizeX(0)
			, SizeY(0)
			, ReferenceCount(0)
		{
		}
	};

	static bool SaveTextureInfo(const FString& SaveDir, const FString& Filename, const TArray<FTextureInfo>& TextureInfos)
	{
		if (!IFileManager::Get().MakeDirectory(*SaveDir, true))
		{
			UE_LOG(LogTemp, Error, TEXT("Failed to create directory: %s"), *SaveDir);
			return false;
		}

		TArray<FString> CSVLines;
		// Add the CSV's head
		CSVLines.Add(TEXT("Name,SizeX,SizeY,RefCount,PathName"));

		for(const FTextureInfo& TextureInfo : TextureInfos)
		{
			FString Line = FString::Printf(TEXT("%s,%i,%i,%i,%s"),
				*TextureInfo.Name,
				TextureInfo.SizeX,
				TextureInfo.SizeY,
				TextureInfo.ReferenceCount,
				*TextureInfo.PathName);

			CSVLines.Add(MoveTemp(Line));
		}

		const FString CSVContent = FString::Join(CSVLines, TEXT("\n"));
		
		const FString FilePath = SaveDir / Filename;
		if (!FFileHelper::SaveStringToFile(CSVContent, *FilePath))
		{
			UE_LOG(LogTemp, Error, TEXT("Failed to save CSV file: %s"), *FilePath);
			return false;
		}
		return true;
	}

	FAutoConsoleCommand SceneAnalysisTexture(TEXT("SceneAnalysis.Texture"), TEXT("SceneAnalysis.Texture (MinX, MinY, Minz) (MaxX, MaxY, MaxZ)"),
		FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
		{
			FVector3f BoundsMin, BoundsMax;
			if (Args.Num() != 2
				|| !ParseVector3f(Args[0], BoundsMin)
				|| !ParseVector3f(Args[1], BoundsMax))
			{
				UE_LOG(LogTemp, Error, TEXT("Usage: SceneAnalysis.Texture (MinX, MinY, Minz) (MaxX, MaxY, MaxZ)"));
				return;
			}

			FBox Bounds(BoundsMin, BoundsMax);
			if(!Bounds.IsValid)
			{
				UE_LOG(LogTemp, Error, TEXT("SceneAnalysis.Texture: given bounds is invalid"));
				return;
			}

			UWorld* World =  GWorld;

			if(World == nullptr || !World->IsPartitionedWorld())
			{
				UE_LOG(LogTemp, Error, TEXT("SceneAnalysis.Texture only supports partitioned worlds now"));
				return;
			}

			UWorldPartition* WorldPartition = World->GetWorldPartition();
			TArray<FGuid> ActorGuids;
			auto CollectActorGuidFunc = [&ActorGuids](const FWorldPartitionActorDescInstance* WorldPartitionActorDescInstance)
			{
				// Only process grid0
				if (WorldPartitionActorDescInstance->GetRuntimeGrid().IsNone()
					&& !WorldPartitionActorDescInstance->GetActorIsEditorOnly())
				{
					ActorGuids.Add(WorldPartitionActorDescInstance->GetGuid());
				}
				return true;
			};
			FWorldPartitionHelpers::ForEachIntersectingActorDescInstance(WorldPartition, Bounds, CollectActorGuidFunc);

			FWorldPartitionHelpers::FForEachActorWithLoadingParams ForEachActorWithLoadingParams;
			ForEachActorWithLoadingParams.ActorClasses = { AActor::StaticClass() };
			ForEachActorWithLoadingParams.ActorGuids = ActorGuids;

			
			TMap<FString, FTextureInfo> TextureInfoMap;
			auto CollectActorTexture = [&TextureInfoMap](const FWorldPartitionActorDescInstance* WorldPartitionActorDescInstance)
			{
				AActor* Actor = WorldPartitionActorDescInstance->GetActor();
				if(Actor == nullptr) return true;

				TArray<UPrimitiveComponent*> PrimitiveComponents;
				Actor->GetComponents(UPrimitiveComponent::StaticClass(), PrimitiveComponents, false);
				for(UPrimitiveComponent* PrimitiveComponent : PrimitiveComponents)
				{
					FStreamingTextureLevelContext LevelContext(EMaterialQualityLevel::Num, PrimitiveComponent);
					TArray<FStreamingRenderAssetPrimitiveInfo> StreamingTextures;
					PrimitiveComponent->GetStreamingRenderAssetInfo(LevelContext, StreamingTextures);

					// Increase usage count for all referenced textures
					for (int32 TextureIndex = 0; TextureIndex < StreamingTextures.Num(); TextureIndex++)
					{
						UTexture* Texture = Cast<UTexture>(StreamingTextures[TextureIndex].RenderAsset);
						if (Texture)
						{
							FString Key = Texture->GetPathName();
							if(!TextureInfoMap.Contains(Key))
							{
								// Init Texture Info
								FTextureInfo TextureInfo;
								TextureInfo.Name = Texture->GetName();
								TextureInfo.PathName = Texture->GetPathName();
								TextureInfo.ReferenceCount = 1;
								
								if(UTexture2D* Texture2D = Cast<UTexture2D>(Texture))
								{
									TextureInfo.SizeX = Texture2D->GetSizeX();
									TextureInfo.SizeY = Texture2D->GetSizeY();
								}

								TextureInfoMap.Add(Key, TextureInfo);
							}
							else
							{
								TextureInfoMap[Key].ReferenceCount++;
							}
						}
					}
				}
				return true;
			};
			FWorldPartitionHelpers::ForEachActorWithLoading(WorldPartition, CollectActorTexture, ForEachActorWithLoadingParams);

			// Save Texture Info
			FString SaveDir = FPaths::ProjectSavedDir()/TEXT("SceneAnalysis");
			
			TArray<FTextureInfo> TextureInfos;
			TextureInfos.Reserve(TextureInfoMap.Num());
			for(const auto& Pair : TextureInfoMap)
			{
				TextureInfos.Add(Pair.Value);
				// const FTextureInfo& TextureInfo = Pair.Value;
				// UE_LOG(LogTemp, Display, TEXT("%s %s %i %i %i"), *TextureInfo.Name, *TextureInfo.PathName, TextureInfo.ReferenceCount, TextureInfo.SizeX, TextureInfo.SizeY);
			}
			
			SaveTextureInfo(SaveDir, "SceneAnalysisTexture.csv", TextureInfos);
		}));
}
#endif
