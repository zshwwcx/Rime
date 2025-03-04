// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Commandlets/ResavePackagesCommandlet.h"
#include "Blueprint/UserWidget.h"
#include "WidgetBlueprint.h"
#include "UICollectCommandlet.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogUICollectCommandlet, All, All);
/**
 * 
 */

UCLASS()
class UUICollectCommandlet : public UResavePackagesCommandlet
{
	GENERATED_BODY()

public:
	virtual int32 Main(const FString& InCommandline) override;

private:
	void CountUObjectNum(UWidgetBlueprint* WidgetBlueprint, int32& Counter);
};
