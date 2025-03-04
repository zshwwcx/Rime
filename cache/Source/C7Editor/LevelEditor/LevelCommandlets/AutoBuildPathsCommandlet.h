// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Commandlets/Commandlet.h"
#include "AutoBuildPathsCommandlet.generated.h"

/**
 * 
 */
UCLASS()
class UAutoBuildPathsCommandlet : public UCommandlet
{
	GENERATED_BODY()
public:
	UAutoBuildPathsCommandlet();
	
	virtual int32 Main(const FString& Params) override;

protected:
	void SaveBuildData(UWorld* WorldToSave);

	void BuildLightingOnly_VisibilityOnly_Execute(UWorld* WorldToSave);
};
