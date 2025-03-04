#include "NPCGeneratorEdModeTool.h"
#include "C7Editor/C7Editor.h"
#include "NPCGeneratorEdMode.h"
#include "Styling/SlateStyle.h"
#include "Styling/SlateStyleRegistry.h"
#include "IPlacementModeModule.h"

#define IMAGE_BRUSH(RelativePath, ...) FSlateImageBrush(StyleSet->RootToContentDir(RelativePath, TEXT(".png")), __VA_ARGS__)

#define LOCTEXT_NAMESPACE "C7NPCGeneratorEdModeTool"

TSharedPtr<FSlateStyleSet> NPCGeneratorEdModeTool::StyleSet = nullptr;

namespace NPCGeneratorEditorStyle
{
	const FVector2D Icon20x20(20.0f, 20.0f);

	const FVector2D Icon40x40(40.0f, 40.0f);
}

void NPCGeneratorEdModeTool::OnStartupModule()
{
	// Register editor category
	FModuleManager::Get().OnModulesChanged().AddLambda([](FName InModuleName, EModuleChangeReason InReason)
	{
		// TODO(shijingzhe): 删除旧逻辑
		if (InReason == EModuleChangeReason::ModuleLoaded && InModuleName == "PlacementMode")
		{
			int Priority = 42;
			FPlacementCategoryInfo Info(LOCTEXT("C7Actors", "C7 Actors"), FSlateIcon(FAppStyle::GetAppStyleSetName(), "PlacementBrowser.Icons.Testing"),
			                            "C7Actors", TEXT("C7Actors"), Priority);
			IPlacementModeModule::Get().RegisterPlacementCategory(Info);

			// UBlueprint* Spawner = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Game/Template/NPCTemplate/NpcSpawner.NpcSpawner")).TryLoad());
			// if (Spawner)
			// {
			// 	IPlacementModeModule::Get().RegisterPlaceableItem(Info.UniqueHandle, MakeShareable(new FPlaceableItem(
			// 		*UActorFactory::StaticClass(),
			// 		FAssetData(Spawner, true),
			// 		FName("ClassThumbnail.Sphere"),
			// 		NAME_None,
			// 		TOptional<FLinearColor>(),
			// 		TOptional<int32>(),
			// 		NSLOCTEXT("PlacementMode", "Npc Spawner", "Npc Spawner")
			// 	                                                  )));
			// }

			UBlueprint* Spawner = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Game/Blueprint/SceneActor/BP_LandScapeSpline.BP_LandScapeSpline")).TryLoad());
			if (Spawner)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(Info.UniqueHandle, MakeShareable(new FPlaceableItem(
					                                                  *UActorFactory::StaticClass(),
					                                                  FAssetData(Spawner, true),
					                                                  FName("ClassThumbnail.Sphere"),
					                                                  NAME_None,
					                                                  TOptional<FLinearColor>(),
					                                                  TOptional<int32>(),
					                                                  NSLOCTEXT("PlacementMode", "Land ScapeSpline Gen", "Land ScapeSpline Gen")
				                                                  )));
			}
		}

		// TODO(shijingzhe): 文件重命名
		if (InReason == EModuleChangeReason::ModuleLoaded && InModuleName == "PlacementMode")
		{
			int Priority = 33;
			FPlacementCategoryInfo Info(
				LOCTEXT("LogicActor", "Logic Actor"),
				FSlateIcon(FAppStyle::GetAppStyleSetName(), "PlacementBrowser.Icons.Testing"),
				"LogicActor",
				TEXT("LogicActor"),
				Priority);
			IPlacementModeModule::Get().RegisterPlacementCategory(Info);

			UBlueprint* NpcSpawner = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_NpcSpawner.BP_NpcSpawner'")).TryLoad());
			if (NpcSpawner)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(NpcSpawner, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "Npc Spawner", "Npc Spawner"))));
			}

			UBlueprint* NpcSingleSpawner = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_NpcSingleSpawner.BP_NpcSingleSpawner'")).TryLoad());
			if (NpcSingleSpawner)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(NpcSingleSpawner, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "Npc Single Spawner", "Npc Single Spawner"))));
			}

			UBlueprint* LevelPortal = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_LevelPortal.BP_LevelPortal'")).TryLoad());
			if (LevelPortal)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(LevelPortal, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "Level Portal", "Level Portal"))));
			}

			UBlueprint* MagicWall = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_MagicWall.BP_MagicWall'")).TryLoad());
			if (MagicWall)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(MagicWall, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "Magic Wall", "Magic Wall"))));
			}

			UBlueprint* MeshCarrier = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_MeshCarrier.BP_MeshCarrier'")).TryLoad());
			if (MeshCarrier)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(MeshCarrier, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "Mesh Carrier", "Mesh Carrier"))));
			}

			UBlueprint* RespawnPoint = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_RespawnPoint.BP_RespawnPoint'")).TryLoad());
			if (RespawnPoint)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(RespawnPoint, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "Respawn Point", "Respawn Point"))));
			}

			UBlueprint* SquareTrigger = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_SquareTrigger.BP_SquareTrigger'")).TryLoad());
			if (SquareTrigger)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(SquareTrigger, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "Square Trigger", "Square Trigger"))));
			}

			UBlueprint* WayPoint = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_WayPoint_V2.BP_WayPoint_V2'")).TryLoad());
			if (WayPoint)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(WayPoint, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "Way Point", "Way Point"))));
			}

			UBlueprint* TeleportPoint = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_TeleportPoint_V2.BP_TeleportPoint_V2'")).TryLoad());
			if (TeleportPoint)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(TeleportPoint, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "Teleport Point", "Teleport Point"))));
			}

			UBlueprint* NiagaraCarrier = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_NiagaraCarrier.BP_NiagaraCarrier'")).TryLoad());
			if (NiagaraCarrier)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(NiagaraCarrier, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "NiagaraCarrier", "NiagaraCarrier"))));
			}

			UBlueprint* BattleZone = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_BattleZone.BP_BattleZone'")).TryLoad());
			if (BattleZone)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(BattleZone, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "BattleZone", "BattleZone"))));
			}

			UBlueprint* PrivateLevelFlow = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_PrivateLevelFlow.BP_PrivateLevelFlow'")).TryLoad());
			if (PrivateLevelFlow)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(PrivateLevelFlow, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "PrivateLevelFlow", "PrivateLevelFlow"))));
			}

			UBlueprint* ShapeTrigger = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_ShapeTrigger.BP_ShapeTrigger'")).TryLoad());
			if (ShapeTrigger)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(ShapeTrigger, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "ShapeTrigger", "ShapeTrigger"))));
			}

			UBlueprint* CameraControlVolume = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_CameraControlVolume.BP_CameraControlVolume'")).TryLoad());
			if (CameraControlVolume)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(CameraControlVolume, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "CameraControlVolume", "CameraControlVolume"))));
			}

			UBlueprint* AreaSoundEmitter = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_AreaSoundEmitter.BP_AreaSoundEmitter'")).TryLoad());
			if (AreaSoundEmitter)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(AreaSoundEmitter, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "AreaSoundEmitter", "AreaSoundEmitter"))));
			}

			UBlueprint* AkSoundBox = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_AkSoundBox.BP_AkSoundBox'")).TryLoad());
			if (AkSoundBox)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(AkSoundBox, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "AkSoundBox", "AkSoundBox"))));
			}
			
			UBlueprint* InteractorSpawner = Cast<UBlueprint>(FSoftObjectPath(TEXT("/Script/Engine.Blueprint'/Game/Blueprint/LogicActor/BP_InteractorSpawner.BP_InteractorSpawner'")).TryLoad());
			if (InteractorSpawner)
			{
				IPlacementModeModule::Get().RegisterPlaceableItem(
					Info.UniqueHandle,
					MakeShareable(new FPlaceableItem(
						*UActorFactory::StaticClass(),
						FAssetData(InteractorSpawner, true),
						FName("ClassThumbnail.Sphere"),
						NAME_None,
						TOptional<FLinearColor>(),
						TOptional<int32>(),
						NSLOCTEXT("PlacementMode", "Interactor Spawner", "Interactor Spawner"))));
			}
		}
	});
}

void NPCGeneratorEdModeTool::OnShutdownModule()
{
	// Unregister editor category
	if (IPlacementModeModule::IsAvailable())
	{
		IPlacementModeModule::Get().UnregisterPlacementCategory("C7Actors");
	}
}

void NPCGeneratorEdModeTool::RegisterStyleSet()
{
}

void NPCGeneratorEdModeTool::UnregisterStyleSet()
{
}

void NPCGeneratorEdModeTool::RegisterEditorMode()
{
}

void NPCGeneratorEdModeTool::UnregisterEditorMode()
{
}
#undef LOCTEXT_NAMESPACE
#undef IMAGE_BRUSH
