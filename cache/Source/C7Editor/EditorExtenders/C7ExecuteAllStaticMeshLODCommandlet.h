// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Commandlets/ResavePackagesCommandlet.h"
#include "C7ExecuteAllStaticMeshLODCommandlet.generated.h"

/**
 * 
 */
DECLARE_LOG_CATEGORY_EXTERN(LogC7ExecuteAllStaticMeshCommandlet, All, All);

UCLASS()
class UC7ExecuteAllStaticMeshLODCommandlet : public UResavePackagesCommandlet
{
	GENERATED_BODY()

	virtual int32 Main(const FString& InCommandline) override;
};
