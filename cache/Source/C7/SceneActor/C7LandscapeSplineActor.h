#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Components/SplineComponent.h"
#include "LandscapeProxy.h"

#include "C7LandscapeSplineActor.generated.h"

class USplineComponent;

UCLASS()
class AC7LandscapeSplineActor : public AActor
{
	GENERATED_BODY()

public:
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Components")
	TArray<USplineComponent*> SplineComponents;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Landscape")
	TSoftObjectPtr<ALandscapeProxy> Landscape;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Landscape")
	FName ExcludeLayer = "NotExport";

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Landscape")
	bool bWithWorldPartition = false;

	AC7LandscapeSplineActor();

private:
	UFUNCTION(CallInEditor, Category = "Landscape")
	void GenerateSpline();

	void AddSplineComponent(FString name);

	void CalControlPointGroup();
};