// Fill out your copyright notice in the Description page of Project Settings.


#include "EditorExtenders/C7NavmeshProcessor.h"
#include <NavigationSystem.h>
#include "Navmesh/RecastNavMeshGenerator.h"
#include "GameFramework/PlayerStart.h"
#include "LevelSystem/LogicActor.h"

#pragma optimize("", off)

int UC7NavmeshProcessor::GetSearchStartPoint(TArray<FVector>& OutList)
{
	UWorld* World = GEditor->GetEditorWorldContext().World();
	if (!World) {
		return 0;
	}

	const TArray<class ULevel*>  Levels = World->GetLevels();
	for (int i = 0; i < Levels.Num(); ++i) {
		if (Levels[i] == nullptr) {
			continue;
		}

		for (int j = 0; j < Levels[i]->Actors.Num(); ++j) {
			AActor* pActor = Levels[i]->Actors[j];
			if (pActor == nullptr) {
				continue;
			}

			APlayerStart* tPSActor = Cast<APlayerStart>(pActor);
			if (tPSActor) {
				FVector Point = tPSActor->GetActorLocation();
				OutList.Add(Point);
				continue;
			}

			ALogicActor* tALActor = Cast<ALogicActor>(pActor);
			if (tALActor && tALActor->GetClass()->GetName().Equals("BP_RespawnPoint_C"))
			{
				FVector Point = tALActor->GetActorLocation();
				OutList.Add(Point);
				continue;
			}
		}
	}

	return OutList.Num();
}

void UC7NavmeshProcessor::OnNavGenFin(ANavigationData* InNavData)
{
	const uint8 ForbiddenFlag = 2;

	UE_LOG(LogTemp, Display, TEXT("UC7NavmeshProcessor::OnNavGenFin"));
	UWorld* World = GEditor->GetEditorWorldContext().World();
	if (World == nullptr || InNavData == nullptr) {
		return;
	}
	
	TArray<FVector> StartPointList;
	if (GetSearchStartPoint(StartPointList) == 0) {
		UE_LOG(LogTemp, Warning, TEXT("UC7NavmeshProcessor no legal StartPoint"));
		return;
	}

	ARecastNavMesh* NavData = Cast<ARecastNavMesh>(InNavData);
	if (NavData == nullptr) {
		return;
	}

	dtNavMesh* NavMesh = NavData->GetRecastMesh();
	if (NavMesh == nullptr) {
		return;
	}

	NavData->SetDefaultForbiddenFlags(0);

	// 反设所有poly
	for (int i = 0; i < NavMesh->getMaxTiles(); ++i)
	{
		const dtMeshTile* Tile = ((const dtNavMesh*)NavMesh)->getTile(i);

		const int32 MaxPolys = Tile && Tile->header ? Tile->header->offMeshBase : 0;
		if (MaxPolys > 0)
		{
			// only ground type polys
			dtPoly* Poly = Tile->polys;
			for (int32 j = 0; j < MaxPolys; j++, Poly++)
			{
				if (Poly->flags == 1) {
					Poly->flags |= ForbiddenFlag;
				}
			}
		}
	}

	// 从每个点开启广搜
	for (size_t PointIndex = 0; PointIndex < StartPointList.Num(); PointIndex++)
	{
		FVector ValidPos = StartPointList[PointIndex];
		const FVector NavExtent(600, 600, 2000);
		NavNodeRef PolyRef = NavData->FindNearestPoly(ValidPos, NavExtent);

		TArray<NavNodeRef> openList;
		openList.Add(PolyRef);

		while (openList.Num() > 0) {
			const NavNodeRef ref = openList.Pop();
			const dtMeshTile* NavTile = 0;
			const dtPoly* NavPoly = 0;

			dtStatus Status = NavMesh->getTileAndPolyByRef(ref, &NavTile, &NavPoly);
			if (dtStatusSucceed(Status)) {
				// Visit linked polygons.
				for (unsigned int i = NavPoly->firstLink; i != DT_NULL_LINK; i = NavTile->links[i].next)
				{
					const dtPolyRef neiRef = NavTile->links[i].ref;
					// Skip invalid and already visited.
					if (!neiRef)
						continue;
					
					uint16 PolyFlags = 0;
					dtStatus NeiStatus = NavMesh->getPolyFlags(neiRef, &PolyFlags);
					if (!dtStatusSucceed(Status))
						continue;

					// Skip already visited.
					if (!(PolyFlags & ForbiddenFlag))
						continue;
					// Mark as visited
					NavMesh->setPolyFlags(neiRef, 1);
					// Visit neighbours
					openList.Add(neiRef);
				}
			}
		}
	}

	NavData->SetDefaultForbiddenFlags(ForbiddenFlag);
	NavData->bDrawMarkedForbiddenPolys = 1;
	NavData->UpdateDrawing();
}

void UC7NavmeshProcessor::OnNavigationInitDone()
{
	UWorld* World = GEditor->GetEditorWorldContext().World();
	if (World) {
		UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(World);
		check(NavSys);
		NavSys->OnNavigationInitDone.RemoveAll(this);
		NavSys->OnNavigationGenerationFinishedDelegate.AddUniqueDynamic(this, &UC7NavmeshProcessor::OnNavGenFin);
	}
}

#pragma optimize("", on)

