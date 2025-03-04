// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Commandlets/ResavePackagesCommandlet.h"
#include "C7ExecuteAllTextureDuplicateGuid.generated.h"

/**
 * 
 */
UCLASS()
class C7EDITOR_API UC7ExecuteAllTextureDuplicateGuidCommandlet : public UResavePackagesCommandlet
{
	GENERATED_BODY()

public:
	UC7ExecuteAllTextureDuplicateGuidCommandlet();

	virtual int32 Main(const FString& InCommandline) override;
};
