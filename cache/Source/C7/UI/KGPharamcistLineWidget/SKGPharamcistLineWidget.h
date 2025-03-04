// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Misc/Attribute.h"
#include "Widgets/SLeafWidget.h"

/**
 * 
 */
class SKGPharamcistLineWidget : public SLeafWidget
{
	SLATE_DECLARE_WIDGET_API(SKGPharamcistLineWidget, SLeafWidget, C7_API)
	
public:
	SLATE_BEGIN_ARGS(SKGPharamcistLineWidget) {}
		SLATE_ATTRIBUTE(TArray<FVector2f>*, LinkPoints)
		SLATE_ATTRIBUTE(float, LineThickness)
		SLATE_ATTRIBUTE(bool, bAntialias)
		SLATE_ATTRIBUTE(FLinearColor, LineColor)
		SLATE_ATTRIBUTE(FVector2f, DesiredSizeOverride)
		SLATE_ATTRIBUTE(bool, bEnableCoupeLink)
	SLATE_END_ARGS()

private:
	TSlateAttribute<TArray<FVector2f>*> LinkPoints;
	TSlateAttribute<float> LineThickness;
	TSlateAttribute<bool> bAntialias;
	TSlateAttribute<FLinearColor> LineColor;
	TSlateAttribute<FVector2f> DesiredSizeOverride;
	TSlateAttribute<bool> bEnableCoupeLink;

public:
	C7_API SKGPharamcistLineWidget();
	C7_API void Construct(const FArguments& InArgs);

	// SWidget SynchronizeProperties
	C7_API void UpdateLinkPoints(TArray<FVector2f>* InLinkPoints);
	C7_API void UpdateLineThickness(float InLineThickness);
	C7_API void UpdateLineColor(FLinearColor InLineColor);
	C7_API void UpdateCoupeLink(bool InEnableCoupeLink);

protected:
	C7_API virtual FVector2D ComputeDesiredSize(float) const override;

private:
	C7_API virtual int32 OnPaint(const FPaintArgs& Args, const FGeometry& AllottedGeometry,
		const FSlateRect& MyCullingRect, FSlateWindowElementList& OutDrawElements, int32 LayerId,
		const FWidgetStyle& InWidgetStyle, bool bParentEnabled) const override;
};
