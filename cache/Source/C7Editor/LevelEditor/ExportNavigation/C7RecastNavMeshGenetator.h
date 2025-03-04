#pragma once

#include "CoreMinimal.h"
#include "Navmesh/RecastNavMeshGenerator.h"
#include "./SceneActor/C7VoxelActor.h"

struct FC7RecastGeometryCache
{
	struct FHeader
	{
		FNavigationRelevantData::FCollisionDataHeader Validation;

		int32 NumVerts;
		int32 NumFaces;
		struct FWalkableSlopeOverride SlopeOverride;

		static uint32 StaticMagicNumber;
	};
	rcHeightfield* a;

	FHeader Header;
	FVector::FReal* Verts;
	int32* Indices;

	FC7RecastGeometryCache() {}
	FC7RecastGeometryCache(const uint8* Memory);

	static bool IsValid(const uint8* Memory, int32 MemorySize);
};

class FC7RecastNavMeshGenerator : public FRecastNavMeshGenerator
{
public:
	void C7ExportNavigationData(const FString& FileName) const;
	rcHeightfield* C7ExportHeightfield() const;
	void C7ExportHeightfieldToVoxelActorWithTiles();

	void ExportGeomToOBJFile(const FString& InFileName, const TNavStatArray<FVector::FReal>& GeomCoords, const TNavStatArray<int32>& GeomFaces, const FString& AdditionalData) const;

	void GrowConvexHull(const float ExpandBy, const TArray<FVector>& Verts, TArray<FVector>& OutResult) const;
	void TransformVertexSoupToRecast(const TArray<FVector>& VertexSoup, TNavStatArray<FVector>& Verts, TNavStatArray<int32>& Faces) const;
};
