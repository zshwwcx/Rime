#include "MapShotDebugDrawComponent.h"
#include "NavigationSystem.h"
#include "NavMesh/RecastNavMesh.h"
#include "MapShoot.h"
#include "Camera/CameraComponent.h"

bool LineInCorrectDistance(const FVector& Start, const FVector& End, const FSceneView* View, FVector::FReal CorrectDistance = -1.)
{
	const FVector::FReal MaxDistanceSq = (CorrectDistance > 0.) ? FMath::Square(CorrectDistance) : ARecastNavMesh::GetDrawDistanceSq();
	return	FVector::DistSquaredXY(Start, View->ViewMatrices.GetViewOrigin()) < MaxDistanceSq &&
			FVector::DistSquaredXY(End, View->ViewMatrices.GetViewOrigin()) < MaxDistanceSq;
}

FPrimitiveViewRelevance FMapShotDebugRenderSceneProxy::GetViewRelevance(const FSceneView* View) const
{
	FPrimitiveViewRelevance Result;
	Result.bDrawRelevance = IsShown(View);
	Result.bDynamicRelevance = true;
	Result.bShadowRelevance = false;
	Result.bEditorPrimitiveRelevance = UseEditorCompositing(View);
	return Result;
}

void FMapShotDebugRenderSceneProxy::GetDynamicMeshElements(const TArray<const FSceneView*>& Views,
                                                           const FSceneViewFamily& ViewFamily, uint32 VisibilityMap, FMeshElementCollector& Collector) const
{
	FDebugRenderSceneProxy::GetDynamicMeshElements(Views, ViewFamily, VisibilityMap, Collector);

	for (int32 ViewIndex = 0; ViewIndex < Views.Num(); ViewIndex++)
	{
		if (VisibilityMap & (1 << ViewIndex))
		{
			const FSceneView* View = Views[ViewIndex];
			FPrimitiveDrawInterface* PDI = Collector.GetPDI(ViewIndex);
			int32 Num = NavMeshEdgeLines.Num();
			PDI->AddReserveLines(SDPG_World, Num, false, false);
			PDI->AddReserveLines(SDPG_Foreground, Num, false, true);
			for (int32 Index = 0; Index < Num; ++Index)
			{
				const FDebugLine &Line = NavMeshEdgeLines[Index];
				if (LineInCorrectDistance(Line.Start, Line.End, View))
				{
					PDI->DrawLine(Line.Start, Line.End, Line.Color, SDPG_World, 1.5f, 0, true);
				}
				else
				{
					PDI->DrawLine(Line.Start, Line.End, Line.Color, SDPG_World, 1.5f, 0, true);
				}
			}

			Num = CameraEdgeLines.Num();
			PDI->AddReserveLines(SDPG_World, Num, false, false);
			PDI->AddReserveLines(SDPG_Foreground, Num, false, true);
			for (int32 Index = 0; Index < Num; ++Index)
			{
				const FDebugLine& Line = CameraEdgeLines[Index];
				if (LineInCorrectDistance(Line.Start, Line.End, View))
				{
					PDI->DrawLine(Line.Start, Line.End, Line.Color, SDPG_World, 1.5f, 0, true);
				}
				else
				{
					PDI->DrawLine(Line.Start, Line.End, Line.Color, SDPG_World, 1.5f, 0, true);
				}
			}
		}
	}
}
#if UE_ENABLE_DEBUG_DRAWING
FDebugRenderSceneProxy* UMapShotDebugDrawComponent::CreateDebugSceneProxy()
{
#if WITH_RECAST
	FMapShotDebugRenderSceneProxy* MapShotDebugSceneProxy = new FMapShotDebugRenderSceneProxy(this);
	UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(GetWorld());
	if (NavSys)
	{
		ARecastNavMesh* NavMesh = Cast<ARecastNavMesh>(NavSys->GetDefaultNavDataInstance(FNavigationSystem::DontCreate));
		TArray<FVector> Vertices;
		if (NavMesh && bDrawNavMeshEdges)
		{
			FRecastDebugGeometry NavMeshGeometry;
			NavMeshGeometry.bGatherNavMeshEdges = -1;
			NavMesh->GetDebugGeometryForTile(NavMeshGeometry, INDEX_NONE);
			constexpr FColor EdgesColor(255,0,0);
			const TArray<FVector>& NavMeshEdgeVerts = NavMeshGeometry.NavMeshEdges;
			for (int32 Idx = 0; Idx < NavMeshEdgeVerts.Num(); Idx += 2)
			{
				MapShotDebugSceneProxy->NavMeshEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(NavMeshEdgeVerts[Idx], NavMeshEdgeVerts[Idx + 1], EdgesColor));
			}
		}
	}

	if(bDrawCameraEdges)
	{
		AMapShoot* MapShoot = Cast<AMapShoot>(this->GetOwner());
		UCameraComponent* CameraComponent = MapShoot->GetCameraComponent();
		const FVector camera_position = MapShoot->GetActorLocation();
		const FVector camera_forward = MapShoot->GetActorForwardVector();
		const float viewport_width = CameraComponent->OrthoWidth;
		const float viewport_height = viewport_width / CameraComponent->AspectRatio;

		const float near_clipping_plane_distance = CameraComponent->OrthoNearClipPlane;
		const float far_clipping_plane_distance = CameraComponent->OrthoFarClipPlane;

		const FVector camera_right = MapShoot->GetActorRightVector();
		const FVector camera_up = MapShoot->GetActorUpVector();

		const FVector camera_look_at = camera_position + camera_forward * far_clipping_plane_distance;
		const FVector left = camera_right * viewport_width / 2.0f;
		const FVector top = camera_up * viewport_height / 2.0f;

		const FVector left_top = camera_look_at - left + top;
		const FVector left_bottom = camera_look_at - left - top;
		const FVector right_top = camera_look_at + left + top;
		const FVector right_bottom = camera_look_at + left - top;
		constexpr FColor EdgesColor(158, 255, 55);
		MapShotDebugSceneProxy->CameraEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(left_top, left_bottom, EdgesColor));
		MapShotDebugSceneProxy->CameraEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(left_bottom, right_bottom, EdgesColor));
		MapShotDebugSceneProxy->CameraEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(right_bottom, right_top, EdgesColor));
		MapShotDebugSceneProxy->CameraEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(right_top, left_top, EdgesColor));

		const FVector camera_look_at_near = camera_position + camera_forward * near_clipping_plane_distance;

		const FVector left_top_near = camera_look_at_near - left + top;
		const FVector left_bottom_near = camera_look_at_near - left - top;
		const FVector right_top_near = camera_look_at_near + left + top;
		const FVector right_bottom_near = camera_look_at_near + left - top;
		MapShotDebugSceneProxy->CameraEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(left_top_near, left_bottom_near, EdgesColor));
		MapShotDebugSceneProxy->CameraEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(left_bottom_near, right_bottom_near, EdgesColor));
		MapShotDebugSceneProxy->CameraEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(right_bottom_near, right_top_near, EdgesColor));
		MapShotDebugSceneProxy->CameraEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(right_top_near, left_top_near, EdgesColor));

		MapShotDebugSceneProxy->CameraEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(left_top_near, left_top, EdgesColor));
		MapShotDebugSceneProxy->CameraEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(left_bottom_near, left_bottom, EdgesColor));
		MapShotDebugSceneProxy->CameraEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(right_top_near, right_top, EdgesColor));
		MapShotDebugSceneProxy->CameraEdgeLines.Add(FDebugRenderSceneProxy::FDebugLine(right_bottom_near, right_bottom, EdgesColor));
	}
	
	return MapShotDebugSceneProxy;
#else
	return nullptr;
#endif 
}
#endif
FBoxSphereBounds UMapShotDebugDrawComponent::CalcBounds(const FTransform& LocalToWorld) const
{
	FBox BoundingBox(ForceInit);
#if WITH_RECAST
	UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(GetWorld());
	if (NavSys)
	{
		if (const ARecastNavMesh* NavMesh = Cast<ARecastNavMesh>(NavSys->GetDefaultNavDataInstance(FNavigationSystem::DontCreate)))
		{
			BoundingBox = NavMesh->GetNavMeshBounds();
			if (NavMesh->bDrawOctree)
			{
				if (const FNavigationOctree* NavOctree = NavSys ? NavSys->GetNavOctree() : nullptr)
				{
					BoundingBox += NavOctree->GetRootBounds().GetBox();
				}
			}
		}
	}

	AMapShoot* MapShoot = Cast<AMapShoot>(this->GetOwner());
	UCameraComponent* CameraComponent = MapShoot->GetCameraComponent();
	const FVector camera_position = MapShoot->GetActorLocation();
	const FVector camera_forward = MapShoot->GetActorForwardVector();
	const float viewport_width = CameraComponent->OrthoWidth;
	const float viewport_height = viewport_width / CameraComponent->AspectRatio;

	const float near_clipping_plane_distance = CameraComponent->OrthoNearClipPlane;
	const float far_clipping_plane_distance = CameraComponent->OrthoFarClipPlane;

	const FVector camera_right = MapShoot->GetActorRightVector();
	const FVector camera_up = MapShoot->GetActorUpVector();

	const FVector camera_look_at = camera_position + camera_forward * far_clipping_plane_distance;
	const FVector camera_center = camera_position + camera_forward * ((far_clipping_plane_distance + near_clipping_plane_distance) / 2.0f);
	const FVector left = camera_right * viewport_width / 2.0f;
	const FVector top = camera_up * viewport_height / 2.0f;

	const FVector left_top = camera_look_at - left + top;
	const FVector left_bottom = camera_look_at - left - top;
	const FVector right_top = camera_look_at + left + top;
	const FVector right_bottom = camera_look_at + left - top;
	if(left_bottom.X < BoundingBox.Min.X)
	{
		BoundingBox.Min.X = left_bottom.X;
	}
	if (left_bottom.Y < BoundingBox.Min.Y)
	{
		BoundingBox.Min.Y = left_bottom.Y;
	}
	if (right_top.X > BoundingBox.Max.X)
	{
		BoundingBox.Max.X = right_top.X;
	}
	if (right_top.Y > BoundingBox.Max.Y)
	{
		BoundingBox.Max.Y = right_top.Y;
	}
#endif
	return FBoxSphereBounds(BoundingBox);
}
