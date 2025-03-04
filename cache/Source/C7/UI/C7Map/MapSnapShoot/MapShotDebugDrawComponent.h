// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Components/PrimitiveComponent.h"
#include "Debug/DebugDrawComponent.h"
#include "MapShotDebugDrawComponent.generated.h"

class FMapShotDebugRenderSceneProxy : public FDebugRenderSceneProxy
{
	
public:
	FMapShotDebugRenderSceneProxy(const UPrimitiveComponent* InComponent)
		: FDebugRenderSceneProxy(InComponent)
	{
	}
	
	virtual FPrimitiveViewRelevance GetViewRelevance(const FSceneView* View) const override;

	virtual void GetDynamicMeshElements(const TArray<const FSceneView*>& Views, const FSceneViewFamily& ViewFamily, uint32 VisibilityMap, FMeshElementCollector& Collector) const override;

	TArray<FDebugLine> NavMeshEdgeLines;
	TArray<FDebugLine> CameraEdgeLines;
};

UCLASS(editinlinenew, ClassGroup = Debug)
class C7_API UMapShotDebugDrawComponent : public UDebugDrawComponent
{
	GENERATED_BODY()

public:
#if UE_ENABLE_DEBUG_DRAWING
	virtual FDebugRenderSceneProxy* CreateDebugSceneProxy() override;
#endif
	virtual FBoxSphereBounds CalcBounds(const FTransform &LocalToWorld) const override;

	virtual bool ShouldRecreateProxyOnUpdateTransform() const override { return true; }

	bool bDrawNavMeshEdges = false;

	bool bDrawCameraEdges = false;
};
