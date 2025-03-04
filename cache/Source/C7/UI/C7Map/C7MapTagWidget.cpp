// Fill out your copyright notice in the Description page of Project Settings.


#include "UI/C7Map/C7MapTagWidget.h"

#include "C7MapTagLayer.h"
#include "PaperSprite.h"
#include "Components/Image.h"
#include "Materials/MaterialInterface.h"
#include "Engine/Texture2D.h"
#include "Widgets/DeclarativeSyntaxSupport.h"
#include "Engine/AssetManager.h"
#include "Widgets/Images/SImage.h"


void UC7MapTagWidget::InitTagWidget()
{
	Super::InitTagWidget();
	TextWidget = FetchTextWidget();
	IconWidget = FetchIconWidget();
	RotatePanel = FetchRotateWidget();
}

void UC7MapTagWidget::SetTask(TSharedPtr<FMapTagRunningData> InTask)
{
	Super::SetTask(InTask);
	if (InTask.IsValid())
	{
		SetTextLabel(InTask->TagData.TagName);
		SetTraced(InTask->bTraced);
		SetSelected(InTask->bSelected);
		SetIconTintColor(InTask->TagData.IconTintColor);
		AsyncSetIcon(InTask->TagData.IconObj);
	}

	
}


void UC7MapTagWidget::SetTextLabel(FString InText)
{
	if (auto TextBlock = Cast<UTextBlock>(TextWidget))
	{
		TextBlock->SetText(FText::AsCultureInvariant(InText));
	}
	
}


void UC7MapTagWidget::SetIcon(UObject* IconObj)
{
	if (auto Img = Cast<UImage>(IconWidget)){
		if (UTexture2D* Tex = Cast<UTexture2D>(IconObj))
		{
			Img->SetBrushFromTexture(Tex);
			Img->SetVisibility(ESlateVisibility::SelfHitTestInvisible);
		}
		else if (UPaperSprite* Sprite = Cast<UPaperSprite>(IconObj))
		{
			Img->SetBrushFromAtlasInterface(Sprite);
			Img->SetVisibility(ESlateVisibility::SelfHitTestInvisible);
		}
	}
	
}

void UC7MapTagWidget::SetIconTintColor(FSlateColor Color)
{
	if (auto Img = Cast<UImage>(IconWidget))
	{
		Img->SetBrushTintColor(Color);
	}
}




void UC7MapTagWidget::SetTraced(bool bTraced)
{
	OnTraced(bTraced);
}

void UC7MapTagWidget::SetSelected(bool bSelected)
{
	SetSelectionState(bSelected);
}


void UC7MapTagWidget::OnTagClicked()
{
	if(OnClicked.IsBound())
	{
		OnClicked.Execute(CurrentTagTaskID);
	}
}

void UC7MapTagWidget::SetRotationAngle(float DegAngle)
{
	if (RotatePanel.IsValid())
	{
		RotatePanel->SetRenderTransformAngle(DegAngle);
	}
}




void UC7MapTagWidget::CancelImageStreaming()
{
	if (StreamingHandle.IsValid())
	{
		StreamingHandle->CancelHandle();
		StreamingHandle.Reset();
	}

	StreamingObjectPath.Reset();
}


void UC7MapTagWidget::AsyncSetIcon(TSoftObjectPtr<UObject> SoftObject)
{
	CancelImageStreaming();

	if (!SoftObject.ToSoftObjectPath().IsValid())
	{
		//图片不合法
		return;
	}


	if (auto Img = Cast<UImage>(IconWidget))
    {
    	Img->SetVisibility(ESlateVisibility::Hidden);
    }
	else
    {
		//没有可设置image的widget
	    return;
    }

	if (UObject* StrongObject = SoftObject.Get())
	{
		SetIcon(StrongObject );
		return;  
	}
	
	TWeakObjectPtr<UC7MapTagWidget> WeakThis(this);
	StreamingObjectPath = SoftObject.ToSoftObjectPath();
	StreamingHandle = UAssetManager::GetStreamableManager().RequestAsyncLoad(
		StreamingObjectPath,
		[WeakThis, SoftObject]() {
			if (UC7MapTagWidget* StrongThis = WeakThis.Get())
			{
				// If the object paths don't match, then this delegate was interrupted, but had already been queued for a callback
				// so ignore everything and abort.
				if (StrongThis->StreamingObjectPath != SoftObject.ToSoftObjectPath())
				{
					return; // Abort!
				}
				StrongThis->SetIcon(SoftObject.Get());
				
			}
		},
		FStreamableManager::AsyncLoadHighPriority);
}



