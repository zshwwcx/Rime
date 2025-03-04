#include "C7ExportNavDataLibrary.h"
#include "C7RecastUtils.h"
#include "C7RecastNavMeshGenetator.h"
#include <NavigationSystem.h>
#include <Kismet/KismetSystemLibrary.h>
#include <Widgets/Notifications/SNotificationList.h>
#include <Framework/Notifications/NotificationManager.h>

bool UC7ExportNavDataLibrary::ExportRecastNavMesh(const FString& SaveFile)
{
	UWorld* World = GEditor->GetEditorWorldContext().World();
	if (World && World->GetNavigationSystem())
	{
		if (ANavigationData* NavData = Cast<ANavigationData>(World->GetNavigationSystem()->GetMainNavData()))
		{
			if (FC7RecastNavMeshGenerator* Generator = static_cast<FC7RecastNavMeshGenerator*>(NavData->GetGenerator()))
			{
				FString CurSaveFile = SaveFile;
				if (SaveFile.IsEmpty())
				{
					const FString Name = NavData->GetName();
					CurSaveFile = FPaths::Combine(FPaths::ProjectSavedDir(), Name);
				}
				Generator->C7ExportNavigationData(CurSaveFile);

				return true;
			}
		}
	}

	return false;
}

bool UC7ExportNavDataLibrary::ExportRecastNavData(const FString& InFilePath)
{
	UWorld* World = GEditor->GetEditorWorldContext().World();
	if (!World) return false;

	//if (dtNavMesh* RecastdtNavMesh = UC7ExportNavDataLibrary::GetdtNavMeshInsByWorld(World))
	//{
	//	C7RecastUtils::SerializedtNavMesh(TCHAR_TO_ANSI(*InFilePath), RecastdtNavMesh);
	//	return true;
	//}
		
	if (ARecastNavMesh* RecastNavMesh = UC7ExportNavDataLibrary::GetRecastNavMeshInsByWorld(World)) {
		C7RecastUtils::SerializeRecastNavMesh(TCHAR_TO_ANSI(*InFilePath), RecastNavMesh);
		return true;
	}
	return false;
}

dtNavMesh* UC7ExportNavDataLibrary::GetdtNavMeshInsByWorld(UWorld* InWorld)
{
	UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(InWorld);
	check(NavSys);
	ANavigationData* MainNavDataIns = NavSys->GetDefaultNavDataInstance();
	ARecastNavMesh* RecastNavMeshIns = Cast<ARecastNavMesh>(MainNavDataIns);
	if (RecastNavMeshIns && UKismetSystemLibrary::IsValid(RecastNavMeshIns))
	{
		dtNavMesh* RecastdtNavMesh = RecastNavMeshIns->GetRecastMesh();
		return RecastdtNavMesh;
	}

	return nullptr;
}

ARecastNavMesh* UC7ExportNavDataLibrary::GetRecastNavMeshInsByWorld(UWorld* InWorld)
{
	UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(InWorld);
	check(NavSys);
	ANavigationData* MainNavDataIns = NavSys->GetDefaultNavDataInstance();
	ARecastNavMesh* RecastNavMeshIns = Cast<ARecastNavMesh>(MainNavDataIns);
	if (RecastNavMeshIns && UKismetSystemLibrary::IsValid(RecastNavMeshIns))
	{
		
		return RecastNavMeshIns;
	}

	return nullptr;
}

rcHeightfield* UC7ExportNavDataLibrary::ExportHeightfiledByWorld(UWorld* InWorld)
{
	if (InWorld && InWorld->GetNavigationSystem())
	{
		if (ANavigationData* NavData = Cast<ANavigationData>(InWorld->GetNavigationSystem()->GetMainNavData()))
		{
			if (FC7RecastNavMeshGenerator* Generator = static_cast<FC7RecastNavMeshGenerator*>(NavData->GetGenerator()))
			{
				return Generator->C7ExportHeightfield();
			}
		}
	}

	return nullptr;
}

void UC7ExportNavDataLibrary::ExportHeightfiledByWorldTiled(UWorld* InWorld)
{
	if (InWorld && InWorld->GetNavigationSystem())
	{
		if (ANavigationData* NavData = Cast<ANavigationData>(InWorld->GetNavigationSystem()->GetMainNavData()))
		{
			if (FC7RecastNavMeshGenerator* Generator = static_cast<FC7RecastNavMeshGenerator*>(NavData->GetGenerator()))
			{
				Generator->C7ExportHeightfieldToVoxelActorWithTiles();
				return;
			}
		}
	}
}
