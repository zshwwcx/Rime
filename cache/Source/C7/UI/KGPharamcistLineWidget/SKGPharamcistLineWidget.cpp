// Fill out your copyright notice in the Description page of Project Settings.


#include "SKGPharamcistLineWidget.h"

#include "SlateOptMacros.h"

SLATE_IMPLEMENT_WIDGET(SKGPharamcistLineWidget)
void SKGPharamcistLineWidget::PrivateRegisterAttributes(FSlateAttributeInitializer& AttributeInitializer)
{
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "LinkPoints", LinkPoints, EInvalidateWidgetReason::Paint);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "LineThickness", LineThickness, EInvalidateWidgetReason::Paint);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "bAntialias", bAntialias, EInvalidateWidgetReason::Paint);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "LineColor", LineColor, EInvalidateWidgetReason::Paint);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "DesiredSizeOverride", DesiredSizeOverride, EInvalidateWidgetReason::Layout);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "bEnableCoupeLink", bEnableCoupeLink, EInvalidateWidgetReason::Paint);
}

void SKGPharamcistLineWidget::Construct(const FArguments& InArgs)
{
	LinkPoints.Assign(*this, InArgs._LinkPoints);
	LineThickness.Assign(*this, InArgs._LineThickness);
	bAntialias.Assign(*this, InArgs._bAntialias);
	LineColor.Assign(*this, InArgs._LineColor);
}

SKGPharamcistLineWidget::SKGPharamcistLineWidget()
	: LinkPoints(*this)
	, LineThickness(*this, 1.0f)
	, bAntialias(*this, true)
	, LineColor(*this , FLinearColor::White)
	, DesiredSizeOverride(*this, FVector2f(1.0f, 1.0f))
	, bEnableCoupeLink(*this, false)
{
	SetCanTick(false);
	bCanSupportFocus = false;
}


FVector2D SKGPharamcistLineWidget::ComputeDesiredSize(float) const
{
	return FVector2D(DesiredSizeOverride.Get());
}

void SKGPharamcistLineWidget::UpdateLinkPoints(TArray<FVector2f>* InLinkPoints)
{
	LinkPoints.Assign(*this, InLinkPoints);
}

void SKGPharamcistLineWidget::UpdateLineThickness(float InLineThickness)
{
	LineThickness.Assign(*this, InLineThickness);
}

void SKGPharamcistLineWidget::UpdateLineColor(FLinearColor InLineColor)
{
	LineColor.Assign(*this, InLineColor);
}

void SKGPharamcistLineWidget::UpdateCoupeLink(bool InEnableCoupeLink)
{
	bEnableCoupeLink.Assign(*this, InEnableCoupeLink);
}

int32 SKGPharamcistLineWidget::OnPaint(const FPaintArgs& Args, const FGeometry& AllottedGeometry, const FSlateRect& MyCullingRect,
	FSlateWindowElementList& OutDrawElements, int32 LayerId, const FWidgetStyle& InWidgetStyle, bool bParentEnabled) const
{
	if (!bEnableCoupeLink.Get())
	{
		FSlateDrawElement::MakeLines(
			OutDrawElements,
			LayerId,
			AllottedGeometry.ToPaintGeometry(),
			*LinkPoints.Get(),
			ESlateDrawEffect::None,
			LineColor.Get(),
			bAntialias.Get(),
			LineThickness.Get()
		);	
	}
	else
	{
		int index = 0;
		TArray<FVector2f> Array;
		while (index + 1 < LinkPoints.Get()->Num())
		{
			Array.Empty();
			Array.Add((*LinkPoints.Get())[index]);
			Array.Add((*LinkPoints.Get())[index + 1]);

			FSlateDrawElement::MakeLines(
				OutDrawElements,
				LayerId,
				AllottedGeometry.ToPaintGeometry(),
				Array,
				ESlateDrawEffect::None,
				LineColor.Get(),
				bAntialias.Get(),
				LineThickness.Get()
			);
			
			index = index + 2;
		}
	}
	

	return LayerId;
}

