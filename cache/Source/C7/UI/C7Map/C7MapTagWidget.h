// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Components/Image.h"
#include "Components/TextBlock.h"
#include "UI/C7Map/C7MapTagBase.h"

#include "C7MapTagWidget.generated.h"

/**
 * 
 */

UCLASS()
class C7_API UC7MapTagWidget : public UC7MapTagBase
{
	GENERATED_BODY()
	
public:
	virtual void InitTagWidget() override;
	virtual void  SetTask(TSharedPtr<FMapTagRunningData> InTask) override;
	
	UFUNCTION(BlueprintImplementableEvent)
	UWidget* FetchTextWidget();

	UFUNCTION(BlueprintImplementableEvent)
	UWidget* FetchIconWidget();

	UFUNCTION(BlueprintImplementableEvent)
	UWidget* FetchRotateWidget();

	UFUNCTION(BlueprintImplementableEvent)
	void SetSelectionState(bool bSelected);
	
	UFUNCTION(BlueprintImplementableEvent)
	void PlaySelectionAnim(bool bSelected);

	UFUNCTION(BlueprintImplementableEvent)
	void OnEnterEdgeWrap(bool bIsEnter);
	
	UFUNCTION(BlueprintImplementableEvent)
	void OnTraced(bool bSelected);

	UFUNCTION(BlueprintCallable)
	void OnTagClicked();
	
	void SetRotationAngle(float Angle);
	void SetTextLabel(FString InText);
	void SetIcon(UObject* IconObj);
	void SetIconTintColor(FSlateColor Color);
	void SetTraced(bool bTraced);
	void SetSelected(bool bSelected);

protected:
	TWeakObjectPtr<UWidget> TextWidget;
	TWeakObjectPtr<UWidget> IconWidget;
	TWeakObjectPtr<UWidget> RotatePanel;


	virtual void CancelImageStreaming();
	void AsyncSetIcon(TSoftObjectPtr<UObject> SoftObjec);
	
	TSharedPtr<FStreamableHandle> StreamingHandle;
	FSoftObjectPath StreamingObjectPath;
};


