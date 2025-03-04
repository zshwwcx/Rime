// Fill out your copyright notice in the Description page of Project Settings.


#include "KGPharamcistLineWidget.h"
#include "Components/Image.h"


TSharedRef<SWidget> UKGPharamcistLineWidget::RebuildWidget()
{
	CurrentWidget = SNew(SKGPharamcistLineWidget).LinkPoints(&LinkPoints).LineThickness(LineThickness).bAntialias(bAntialias).LineColor(LineColor).bEnableCoupeLink(bEnableCoupeLink);
	return CurrentWidget.ToSharedRef();
}

void UKGPharamcistLineWidget::SynchronizeProperties()
{
	Super::SynchronizeProperties();
	
	if (CurrentWidget.IsValid())
	{
		// 是否采用抗锯齿一般不会在runtime动态变化，所以这里就不处理bAntialias的更新了，省一次调用
		CurrentWidget->UpdateLinkPoints(&LinkPoints);
		CurrentWidget->UpdateLineThickness(LineThickness);
		CurrentWidget->UpdateLineColor(LineColor);
		CurrentWidget->UpdateCoupeLink(bEnableCoupeLink);
	}
}

void UKGPharamcistLineWidget::ReleaseSlateResources(bool bReleaseChildren)
{
	Super::ReleaseSlateResources(bReleaseChildren);
	CurrentWidget.Reset();
}

void UKGPharamcistLineWidget::ResetWidget()
{
	LinkPoints.Empty();
	LineThickness = 1.0f;
	bAntialias = true;
	LineColor = FLinearColor::White;
	bEnableCoupeLink = false;
}

bool UKGPharamcistLineWidget::UpdateFirstNodePos(float X, float Y)
{
	if (LinkPoints.Num() > 0)
	{
		LinkPoints[0].X = X;
		LinkPoints[0].Y = Y;
		SynchronizeProperties();
		return true;
	}
	return false;
}
