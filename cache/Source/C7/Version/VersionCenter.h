// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/NoExportTypes.h"
#include "VersionCenter.generated.h"

/**
 * 
 */
UCLASS(config=Version, defaultconfig)
class C7_API UVersionCenter : public UObject
{
	GENERATED_BODY()
	
public:

	UFUNCTION()
	static FString GetVersionString();
	
	UFUNCTION()
	static FString GetAppVersionString();
	
public:

	UPROPERTY(config, EditAnywhere)
	FString VersionString;

	UPROPERTY(config, EditAnywhere)
	FString IOSVersionString;

	UPROPERTY(config, EditAnywhere)
	FString WindowsVersionString;

	UPROPERTY(config, EditAnywhere)
	FString AndroidVersionString;
};
