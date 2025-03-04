// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UI/C7Map/C7MapTagBase.h"
#include "C7MapTagEdgeWidget.generated.h"

struct FMapTagRunningData;
class UC7MapTagLayer;

/**
 * 
 */
UCLASS()
class C7_API UC7MapTagEdgeWidget : public UC7MapTagBase
{
	GENERATED_BODY()

public:
	virtual void InitTagWidget() override;
	
	UFUNCTION(BlueprintImplementableEvent)
	UPanelWidget* FetchContentPanel();
	

	UFUNCTION(BlueprintImplementableEvent)
	UWidget* FetchArrowWidget();
	
	void SetContentWidget(UWidget* InWidget);

	UWidget* GetContentWidget();
	
	UWidget* ReturnContentWidget();

	void SetArrowRotation(float Angle);

	UFUNCTION(BlueprintCallable)
	void OnEdgeTagClicked();


	bool HasContentPanel() const;

private:
	TWeakObjectPtr<UPanelWidget> ContentPanel;
	TWeakObjectPtr<UWidget> ArrowWidget;
	TWeakObjectPtr<UWidget> ContentWidget;
};
