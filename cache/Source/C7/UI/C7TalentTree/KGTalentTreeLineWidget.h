#pragma once

#include "CoreMinimal.h"
#include "UObject/UObjectGlobals.h"
#include "UObject/ObjectMacros.h"
#include "Misc/Attribute.h"
#include "Styling/SlateBrush.h"
#include "Components/Widget.h"
#include "KGTalentTreeLineWidget.generated.h"

class SKGTalentTreeLineWidget;

// Line drawer widget for talent trees

UCLASS()
class UKGTalentTreeLineWidget : public UWidget
{
	GENERATED_UCLASS_BODY()

public:
	// Size of the Canvas Panel of the TalentTree
	// 目前没有开裁剪，控件大小暂时设置为0
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FVector2f DesiredSizeOverride;

	// Points that defines the line
	// Every two points forms one line
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TArray<FVector2f> TracePoints;

	// Vectors that defines the Bezier Direction
	// Every two points forms one line's direction
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TArray<FVector2f> BezierDirections;

	// Array of Booleans that indicates whether the corresponding line is using active color
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TArray<bool> UseActiveColors;
	
	// Size of the line that defines the line
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	float LineSize;

	// LineColor
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FLinearColor ColorTint;

	// LineColor Inactive
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FLinearColor ColorTintInactive;
	
protected:
	// Reference of the Slate
	TSharedPtr<SKGTalentTreeLineWidget> CurrentLineWidget;

	C7_API virtual TSharedRef<SWidget> RebuildWidget() override;

public:
	C7_API virtual void ReleaseSlateResources(bool bReleaseChildren) override;

	// Set canvas panel size
	UFUNCTION(BlueprintCallable)
	void SetDesiredSizeOverride(const FVector2f& DesiredSize);

	// Set Active Color
	UFUNCTION(BlueprintCallable)
	void SetActiveColor(FLinearColor Color);
	
	// Ser Inactive Color
	UFUNCTION(BlueprintCallable)
	void SetInactiveColor(FLinearColor Color);
};