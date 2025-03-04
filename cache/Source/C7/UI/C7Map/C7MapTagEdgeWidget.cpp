// Fill out your copyright notice in the Description page of Project Settings.


#include "UI/C7Map/C7MapTagEdgeWidget.h"

#include "C7MapTagLayer.h"
#include "C7MapTagWidget.h"
#include "Components/PanelWidget.h"

void UC7MapTagEdgeWidget::InitTagWidget()
{
	Super::InitTagWidget();
	ContentPanel = FetchContentPanel();
	ArrowWidget = FetchArrowWidget();

}

void UC7MapTagEdgeWidget::SetContentWidget(UWidget* InWidget)
{
	if(ContentPanel.IsValid() && InWidget != nullptr)
	{
		ContentPanel->ClearChildren();
		ContentPanel->AddChild(InWidget);
		if (UC7MapTagWidget* TagWidget = Cast<UC7MapTagWidget>(InWidget))
		{
			TagWidget->OnEnterEdgeWrap(true);
		}
		ContentWidget = InWidget;
	}
}

bool UC7MapTagEdgeWidget::HasContentPanel() const
{
	return ContentPanel.IsValid();
}


UWidget* UC7MapTagEdgeWidget::GetContentWidget()
{
	return ContentWidget.Get();
}

UWidget* UC7MapTagEdgeWidget::ReturnContentWidget()
{
	if (ContentWidget.IsValid())
	{
		ContentWidget->RemoveFromParent();

		if (UC7MapTagWidget* TagWidget = Cast<UC7MapTagWidget>(ContentWidget))
		{
			TagWidget->OnEnterEdgeWrap(false);
		}
	}
	
	return ContentWidget.Get();
}

void UC7MapTagEdgeWidget::SetArrowRotation(float Angle)
{
	if(ArrowWidget.IsValid())
	{
		ArrowWidget->SetRenderTransformAngle(Angle);
	} 
}

void UC7MapTagEdgeWidget::OnEdgeTagClicked()
{
	if(OnClicked.IsBound())
	{
		OnClicked.Execute(CurrentTagTaskID);
	}
}
