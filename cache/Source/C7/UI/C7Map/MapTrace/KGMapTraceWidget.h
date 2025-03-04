#pragma once

#include "CoreMinimal.h"
#include "UObject/UObjectGlobals.h"
#include "UObject/ObjectMacros.h"
#include "Misc/Attribute.h"
#include "Styling/SlateBrush.h"
#include "Components/Widget.h"
#include "KGMapTraceWidget.generated.h"

class SKGMapTraceWidget;

UCLASS()
class UKGMapTraceWidget : public UWidget
{
	GENERATED_UCLASS_BODY()

public:
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FSlateBrush Brush;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FVector2f DesiredSizeOverride;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FVector2f PointSizeOverride;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	float PointDistanceOverride;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TArray<FVector2f> TracePoints;

	int32 TracePointIndex = 0;

protected:
	TSharedPtr<SKGMapTraceWidget> MyTraceWidget;

	C7_API virtual TSharedRef<SWidget> RebuildWidget() override;

public:
	C7_API virtual void ReleaseSlateResources(bool bReleaseChildren) override;

	UFUNCTION(BlueprintCallable)
	void SetTracePointIndex(const int32 Index);
	
	UFUNCTION(BlueprintCallable)
	void SetDesiredSizeOverride(const FVector2f& DesiredSize);
};