#include "KGMapTraceWidget.h"
#include "SKGMapTraceWidget.h"

UKGMapTraceWidget::UKGMapTraceWidget(const FObjectInitializer& ObjectInitializer)
    : Super(ObjectInitializer)
{}

TSharedRef<SWidget> UKGMapTraceWidget::RebuildWidget()
{
    MyTraceWidget = SNew(SKGMapTraceWidget).DesiredSizeOverride(DesiredSizeOverride).
        PointSizeOverride(PointSizeOverride).TracePoints(&TracePoints).TraceImage(&Brush)
        .PointDistanceOverride(PointDistanceOverride);
    return MyTraceWidget.ToSharedRef();
}

C7_API void UKGMapTraceWidget::ReleaseSlateResources(bool bReleaseChildren)
{
    Super::ReleaseSlateResources(bReleaseChildren);
    MyTraceWidget.Reset();
}


void UKGMapTraceWidget::SetTracePointIndex(const int32 Index)
{
    TracePointIndex = Index;
    if (MyTraceWidget.IsValid())
    {
        MyTraceWidget->SetTracePointIndex(Index);
    }
}

void UKGMapTraceWidget::SetDesiredSizeOverride(const FVector2f& DesiredSize)
{
    DesiredSizeOverride = DesiredSize;
    if (MyTraceWidget.IsValid())
    {
        MyTraceWidget->SetDesiredSizeOverride(DesiredSizeOverride);
    }
}