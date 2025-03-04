#pragma once

#include "CoreMinimal.h"
#include "Misc/Attribute.h"
#include "Widgets/SLeafWidget.h"

// Line drawing Slate for UKGTalentTreeLineWidget
class SKGTalentTreeLineWidget : public SLeafWidget
{
	SLATE_DECLARE_WIDGET_API(SKGTalentTreeLineWidget, SLeafWidget, C7_API)

public:
	SLATE_BEGIN_ARGS(SKGTalentTreeLineWidget) {}
		SLATE_ATTRIBUTE(TArray<FVector2f>*, TracePoints)
		SLATE_ATTRIBUTE(TArray<FVector2f>*, BezierDirections)
		SLATE_ATTRIBUTE(FVector2f, DesiredSizeOverride)
		SLATE_ATTRIBUTE(float, LineSize)
		SLATE_ATTRIBUTE(TArray<bool>*, UseActiveColors)
		SLATE_ATTRIBUTE(FLinearColor, ColorTint)
		SLATE_ATTRIBUTE(FLinearColor, ColorTintInactive)
	SLATE_END_ARGS()

private:
	TSlateAttribute<TArray<FVector2f>*> TracePoints;
	TSlateAttribute<TArray<FVector2f>*> BezierDirections;
	TSlateAttribute<FVector2f> DesiredSizeOverride;
	TSlateAttribute<float> LineSize;
	TSlateAttribute<TArray<bool>*> UseActiveColors;
	TSlateAttribute<FLinearColor> ColorTint;
	TSlateAttribute<FLinearColor> ColorTintInactive;

public:
	void SetDesiredSizeOverride(const FVector2f& _DesiredSize);
	void SetActiveColor(FLinearColor Color);
	void SetInactiveColor(FLinearColor Color);
	
	C7_API SKGTalentTreeLineWidget();
	C7_API void Construct(const FArguments& InArgs);

protected:
	C7_API virtual FVector2D ComputeDesiredSize(float) const override;

public:
	C7_API virtual int32 OnPaint(const FPaintArgs& Args, const FGeometry& AllottedGeometry,
		const FSlateRect& MyCullingRect, FSlateWindowElementList& OutDrawElements, int32 LayerId,
		const FWidgetStyle& InWidgetStyle, bool bParentEnabled) const override;
};