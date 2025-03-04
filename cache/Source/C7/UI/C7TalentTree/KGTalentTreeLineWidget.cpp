#include "KGTalentTreeLineWidget.h"
#include "SKGTalentTreeLineWidget.h"

UKGTalentTreeLineWidget::UKGTalentTreeLineWidget(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{}

TSharedRef<SWidget> UKGTalentTreeLineWidget::RebuildWidget()
{
	CurrentLineWidget = SNew(SKGTalentTreeLineWidget).DesiredSizeOverride(DesiredSizeOverride).
		TracePoints(&TracePoints).BezierDirections(&BezierDirections).LineSize(LineSize).
		UseActiveColors(&UseActiveColors).ColorTint(ColorTint).ColorTintInactive(ColorTintInactive);
	return CurrentLineWidget.ToSharedRef();
}

C7_API void UKGTalentTreeLineWidget::ReleaseSlateResources(bool bReleaseChildren)
{
	Super::ReleaseSlateResources(bReleaseChildren);
	CurrentLineWidget.Reset();
}

void UKGTalentTreeLineWidget::SetDesiredSizeOverride(const FVector2f& DesiredSize)
{
	DesiredSizeOverride = DesiredSize;
	if (CurrentLineWidget.IsValid())
	{
		CurrentLineWidget->SetDesiredSizeOverride(DesiredSizeOverride);
	}
}

void UKGTalentTreeLineWidget::SetActiveColor(FLinearColor Color)
{
	if (CurrentLineWidget.IsValid())
	{
		CurrentLineWidget->SetActiveColor(Color);
	}
}

void UKGTalentTreeLineWidget::SetInactiveColor(FLinearColor Color)
{
	if (CurrentLineWidget.IsValid())
	{
		CurrentLineWidget->SetInactiveColor(Color);
	}
}