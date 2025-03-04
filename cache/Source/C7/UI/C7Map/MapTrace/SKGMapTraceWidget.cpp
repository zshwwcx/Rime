#include "SKGMapTraceWidget.h"


SLATE_IMPLEMENT_WIDGET(SKGMapTraceWidget)
void SKGMapTraceWidget::PrivateRegisterAttributes(FSlateAttributeInitializer& AttributeInitializer)
{
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "TraceImageAttribute", TraceImageAttribute, EInvalidateWidgetReason::Paint);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "TracePoints", TracePoints, EInvalidateWidgetReason::Paint);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "DesiredSizeOverride", DesiredSizeOverride, EInvalidateWidgetReason::Layout);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "PointSizeOverride", PointSizeOverride, EInvalidateWidgetReason::Layout);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "PointDistanceOverride", PointDistanceOverride, EInvalidateWidgetReason::Layout);
	SLATE_ADD_MEMBER_ATTRIBUTE_DEFINITION_WITH_NAME(AttributeInitializer, "TracePointIndex", TracePointIndex, EInvalidateWidgetReason::Layout);
}


void SKGMapTraceWidget::Construct(const FArguments& InArgs)
{
	TraceImageAttribute.Assign(*this, InArgs._TraceImage);
	TracePoints.Assign(*this, InArgs._TracePoints);
	DesiredSizeOverride.Assign(*this, InArgs._DesiredSizeOverride);
	PointSizeOverride.Assign(*this, InArgs._PointSizeOverride);
	PointDistanceOverride.Assign(*this, InArgs._PointDistanceOverride);
	TracePointIndex.Assign(*this, InArgs._TracePointIndex);
}

FVector2D SKGMapTraceWidget::ComputeDesiredSize(float) const
{
	return FVector2D(DesiredSizeOverride.Get());
}

void SKGMapTraceWidget::SetTracePointIndex(const int32 TraceIndex)
{
	TracePointIndex.Set(*this, TraceIndex);
}

void SKGMapTraceWidget::SetDesiredSizeOverride(const FVector2f& _DesiredSize)
{
	DesiredSizeOverride.Set(*this, _DesiredSize);
}

int32 SKGMapTraceWidget::OnPaint(const FPaintArgs& Args, const FGeometry& AllottedGeometry, const FSlateRect& MyCullingRect,
	FSlateWindowElementList& OutDrawElements, int32 LayerId, const FWidgetStyle& InWidgetStyle, bool bParentEnabled) const
{
	if (FMath::IsNearlyZero(PointDistanceOverride.Get()) || DesiredSizeOverride.Get().X == 0 || DesiredSizeOverride.Get().Y == 0)
	{
		return LayerId;
	}
	const FSlateBrush* ImageBrush = TraceImageAttribute.Get();
	const TArray<FVector2f>& Points = *TracePoints.Get();
	if ((ImageBrush != nullptr) && (ImageBrush->DrawAs != ESlateBrushDrawType::NoDrawType))
	{
		int32 Index = TracePointIndex.Get();
		float Slide = .0f;//当前走过的步长
		float CurrentRatio = .0f;//走到了Index到Index + 1的什么位置, 0代表在Index位置, 1代表在Index + 1位置
		while (Index < Points.Num() - 1)
		{
			FVector2f OrientationVec(-Points[Index + 1].X + Points[Index].X, -Points[Index + 1].Y + Points[Index].Y);
			OrientationVec.Normalize();
			FVector2f OriginVec(.0f, 1.0f);
			float Angle = FMath::Acos(FVector2f::DotProduct(OrientationVec, OriginVec));
			float Distance = (Points[Index + 1] - Points[Index]).Size();
			if (Distance * (1 - CurrentRatio) + Slide > PointDistanceOverride.Get())
			{
				CurrentRatio += (PointDistanceOverride.Get() - Slide) / Distance;
				Slide = .0f;
				FVector2f Pos = Points[Index + 1] * CurrentRatio + Points[Index] * (1 - CurrentRatio);
				FGeometry Geometry(FVector2f(0.0f), AllottedGeometry.AbsolutePosition + Pos * AllottedGeometry.Scale * AllottedGeometry.Size / DesiredSizeOverride.Get()
					, PointSizeOverride.Get(), AllottedGeometry.Scale);
				FSlateDrawElement::MakeRotatedBox(
					OutDrawElements, LayerId, Geometry.ToPaintGeometry(), ImageBrush, ESlateDrawEffect::None, Angle
				);
			}
			else
			{
				Slide += Distance * (1 - CurrentRatio);
				Index += 1;
				CurrentRatio = .0f;
			}
		}
	}
	return LayerId;
}

SKGMapTraceWidget::SKGMapTraceWidget()
	: TraceImageAttribute(*this)
	, TracePoints(*this)
	, DesiredSizeOverride(*this, FVector2f())
	, PointSizeOverride(*this, FVector2f())
	, PointDistanceOverride(*this)
	, TracePointIndex(*this)
{
	SetCanTick(false);
	bCanSupportFocus = false;
}