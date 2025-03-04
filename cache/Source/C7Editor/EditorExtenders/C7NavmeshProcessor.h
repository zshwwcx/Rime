// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/NoExportTypes.h"
#include "C7NavmeshProcessor.generated.h"

/**
 * 
 */
UCLASS(Config = Editor, DefaultConfig)
class C7EDITOR_API UC7NavmeshProcessor : public UObject
{
	GENERATED_BODY()

public:
	// Nav变更
	UFUNCTION()
	void OnNavGenFin(ANavigationData* NavData);

	UFUNCTION()
	void OnNavigationInitDone();

private:
	int GetSearchStartPoint(TArray<FVector>& OutList);
};
