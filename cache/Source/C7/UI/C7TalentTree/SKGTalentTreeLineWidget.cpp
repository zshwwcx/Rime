#include "SKGTalentTreeLineWidget.h"

SLATE_IMPLEMENT_WIDGET(SKGTalentTreeLineWidget)
void SKGTalentTreeLineWidget::PrivateRegisterAttributes(FSlateAttributeInitializer& AttributeInitializer)
{
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "TracePoints", TracePoints, EInvalidateWidgetReason::Paint);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "BezierDirections", BezierDirections, EInvalidateWidgetReason::Paint);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "DesiredSizeOverride", DesiredSizeOverride, EInvalidateWidgetReason::Layout);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "LineSize", LineSize, EInvalidateWidgetReason::Layout);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "UseActiveColors", UseActiveColors, EInvalidateWidgetReason::Layout);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "ColorTint", ColorTint, EInvalidateWidgetReason::Layout);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "ColorTintInactive", ColorTintInactive, EInvalidateWidgetReason::Layout);
}

void SKGTalentTreeLineWidget::Construct(const FArguments& InArgs)
{
	TracePoints.Assign(*this, InArgs._TracePoints);
	BezierDirections.Assign(*this, InArgs._BezierDirections);
	DesiredSizeOverride.Assign(*this, InArgs._DesiredSizeOverride);
	LineSize.Assign(*this, InArgs._LineSize);
	UseActiveColors.Assign(*this, InArgs._UseActiveColors);
	ColorTint.Assign(*this, InArgs._ColorTint);
	ColorTintInactive.Assign(*this, InArgs._ColorTintInactive);
}

SKGTalentTreeLineWidget::SKGTalentTreeLineWidget()
	: TracePoints(*this)
	, BezierDirections(*this)
	, DesiredSizeOverride(*this, FVector2f(1.0f,1.0f))
	, LineSize(*this, 1)
	, UseActiveColors(*this)
	, ColorTint(*this, FLinearColor::White)
	, ColorTintInactive(*this, FLinearColor::Black)
{
	SetCanTick(false);
	bCanSupportFocus = false;
}

void SKGTalentTreeLineWidget::SetActiveColor(FLinearColor Color)
{
	ColorTint.Set(*this, Color);
}

void SKGTalentTreeLineWidget::SetInactiveColor(FLinearColor Color)
{
	ColorTintInactive.Set(*this, Color);
}

void SKGTalentTreeLineWidget::SetDesiredSizeOverride(const FVector2f& _DesiredSize)
{
	DesiredSizeOverride.Set(*this, _DesiredSize);
}

FVector2D SKGTalentTreeLineWidget::ComputeDesiredSize(float) const
{
	return FVector2D(DesiredSizeOverride.Get());
}

int32 SKGTalentTreeLineWidget::OnPaint(const FPaintArgs& Args, const FGeometry& AllottedGeometry, const FSlateRect& MyCullingRect,
	FSlateWindowElementList& OutDrawElements, int32 LayerId, const FWidgetStyle& InWidgetStyle, bool bParentEnabled) const
{
	if (DesiredSizeOverride.Get().X == 0 || DesiredSizeOverride.Get().Y == 0)
	{
		return LayerId;
	}
	
	FGeometry Geometry(FVector2f(0.0f),
		AllottedGeometry.AbsolutePosition + AllottedGeometry.Scale * AllottedGeometry.Size / DesiredSizeOverride.Get(),
		DesiredSizeOverride.Get(), 
		AllottedGeometry.Scale);
	
	// Iterate through every pair of points and draw Bezier lines
	const TArray<FVector2f>& Points = *TracePoints.Get();
	const TArray<FVector2f>& Directions = *BezierDirections.Get();
	const TArray<bool>& ColorSelectionArray = *UseActiveColors.Get();
	FLinearColor ColorSelection = ColorTint.Get();
	
	if (Points.Num() % 2 != 0 || Points.Num() < 2 || Points.Num() < Directions.Num())
	{
		return LayerId;
	}
	
	// 目标点和控制点两两一组控制一条线的绘制
	int lineIndex = 0;
	for (int32 i = 0; i < Points.Num() - 1; i += 2)
	{
		// 因为暂时取消了画曲线的需求，改为绘制直线
		/*
		if (i >= Directions.Num() || i + 1 >= Directions.Num()  )
		{
			// 控制点数量不够的时候画直线
			FSlateDrawElement::MakeCubicBezierSpline(OutDrawElements, LayerId, Geometry.ToPaintGeometry(),
			Points[i],
			Points[i],
			Points[i + 1],
			Points[i + 1],
			LineSize.Get(), ESlateDrawEffect::None, ColorTint.Get());
		}
		else
		{
			FSlateDrawElement::MakeCubicBezierSpline(OutDrawElements, LayerId, Geometry.ToPaintGeometry(),
			Points[i],
			Directions[i],
			Directions[i + 1],
			Points[i + 1],
			LineSize.Get(), ESlateDrawEffect::None, ColorTint.Get());
		}
		*/
		// 如果线条总数超出了规定范围或者为False则绘制不激活状态下的颜色
		if (lineIndex >= ColorSelectionArray.Num() || !ColorSelectionArray[lineIndex])
		{
			FSlateDrawElement::MakeCubicBezierSpline(OutDrawElements, LayerId, Geometry.ToPaintGeometry(),
			Points[i],
			Points[i],
			Points[i + 1],
			Points[i + 1],
			LineSize.Get(), ESlateDrawEffect::None, ColorTintInactive.Get());
		}
		else
		{
			FSlateDrawElement::MakeCubicBezierSpline(OutDrawElements, LayerId, Geometry.ToPaintGeometry(),
			Points[i],
			Points[i],
			Points[i + 1],
			Points[i + 1],
			LineSize.Get(), ESlateDrawEffect::None, ColorTint.Get());
		}
		lineIndex ++;
	}
	return LayerId;
}