#pragma once

#include "CoreMinimal.h"
#include "Misc/Attribute.h"
#include "Widgets/SLeafWidget.h"



class SKGMapTraceWidget : public SLeafWidget
{
	SLATE_DECLARE_WIDGET_API(SKGMapTraceWidget, SLeafWidget, C7_API)
	
public:
	SLATE_BEGIN_ARGS(SKGMapTraceWidget) //:
		/*_TraceImage(FCoreStyle::Get().GetDefaultBrush())*/{}
		SLATE_ATTRIBUTE(const FSlateBrush*, TraceImage)
		SLATE_ATTRIBUTE(TArray<FVector2f>*, TracePoints)
		SLATE_ATTRIBUTE(FVector2f, DesiredSizeOverride)
		SLATE_ATTRIBUTE(FVector2f, PointSizeOverride)
		SLATE_ATTRIBUTE(float, PointDistanceOverride)
		SLATE_ATTRIBUTE(int32, TracePointIndex)
	SLATE_END_ARGS()

private:
	TSlateAttribute<const FSlateBrush*> TraceImageAttribute;
	TSlateAttribute<TArray<FVector2f>*> TracePoints;
	TSlateAttribute<FVector2f> DesiredSizeOverride;
	TSlateAttribute<FVector2f> PointSizeOverride;
	TSlateAttribute<float> PointDistanceOverride;
	TSlateAttribute<int32> TracePointIndex;

public:
	void SetTracePointIndex(const int32 TraceIndex);
	void SetDesiredSizeOverride(const FVector2f& _DesiredSize);

	C7_API SKGMapTraceWidget();

	C7_API void Construct(const FArguments& InArgs);

protected:
	C7_API virtual FVector2D ComputeDesiredSize(float) const override;

public:
	C7_API virtual int32 OnPaint(const FPaintArgs& Args, const FGeometry& AllottedGeometry, const FSlateRect& MyCullingRect, FSlateWindowElementList& OutDrawElements, int32 LayerId, const FWidgetStyle& InWidgetStyle, bool bParentEnabled) const override;
};