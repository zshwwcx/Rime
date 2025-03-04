#pragma once

#include "CoreMinimal.h"
#include "Detour/DetourNavMesh.h"
#include "Recast/Recast.h"
#include "Navmesh/RecastNavMesh.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "C7ExportNavDataLibrary.generated.h"

/**
 *
 */
UCLASS()
class UC7ExportNavDataLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()
public:
	static bool ExportRecastNavMesh(const FString& SavePath);

	static bool ExportRecastNavData(const FString& InFilePath);

	static dtNavMesh* GetdtNavMeshInsByWorld(UWorld* InWorld);
	static ARecastNavMesh* GetRecastNavMeshInsByWorld(UWorld* InWorld);

	static rcHeightfield* ExportHeightfiledByWorld(UWorld* InWorld);
	static void ExportHeightfiledByWorldTiled(UWorld* InWorld);
};
