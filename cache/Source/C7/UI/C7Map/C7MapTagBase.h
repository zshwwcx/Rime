// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UMG/Blueprint/KGUserWidget.h"
#include "MapCommon.h"
#include "C7MapTagBase.generated.h"


/**
 * 
 */

DECLARE_DELEGATE_OneParam(FTagBaseOnTagClicked, int32);

UCLASS()
class C7_API UC7MapTagBase : public UKGUserWidget
{
	GENERATED_BODY()
public:
	virtual void InitTagWidget();

	virtual void UnInitTagWidget();
	
	virtual void SetTask(TSharedPtr<FMapTagRunningData> InTask);

	int32 GetCurrentTagTaskID() const {return CurrentTagTaskID;}

	FTagBaseOnTagClicked OnClicked;
protected:
	int32 CurrentTagTaskID;
	
};
