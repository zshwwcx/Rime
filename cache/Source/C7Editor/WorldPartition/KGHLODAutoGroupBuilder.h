// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "WorldPartition/WorldPartitionBuilder.h"
#include "Engine/DeveloperSettings.h"
#include "KGHLODAutoGroupBuilder.generated.h"

class FSourceControlHelper;

UENUM()
enum class EMatchMode : uint8
{
	ByName,
	ByMaterial,
};

USTRUCT()
struct FHLODGroupRule
{
	GENERATED_BODY()

#if WITH_EDITORONLY_DATA
	UPROPERTY(EditAnywhere)
	TSoftObjectPtr<UHLODLayer> HLODLayer;
#endif

	UPROPERTY(EditAnywhere)
	EMatchMode MatchMode;
	
	UPROPERTY(EditAnywhere, meta = (EditCondition = "MatchMode == EMatchMode::ByName"))
	TArray<FString> RegexList;

	UPROPERTY(EditAnywhere, meta = (EditCondition = "MatchMode == EMatchMode::ByMaterial"))
	TArray<UMaterialInterface*> MaterialList;
};

USTRUCT()
struct FGridGroupRule
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere)
	FName GridName;

	UPROPERTY(EditAnywhere)
	EMatchMode MatchMode;
	
	UPROPERTY(EditAnywhere, meta = (EditCondition = "MatchMode == EMatchMode::ByName"))
	TArray<FString> RegexList;

	UPROPERTY(EditAnywhere, meta = (EditCondition = "MatchMode == EMatchMode::ByMaterial"))
	TArray<UMaterialInterface*> MaterialList;
};

UCLASS()
class C7EDITOR_API UKGHLODAutoGroupBuilder : public UWorldPartitionBuilder
{
	GENERATED_BODY()

	public:
	// UWorldPartitionBuilder interface begin
	virtual bool RequiresCommandletRendering() const override {return false;};
	virtual ELoadingMode GetLoadingMode() const override { return ELoadingMode::Custom; }

protected:
	virtual bool RunInternal(UWorld* World, const FCellInfo& InCellInfo, FPackageSourceControlHelper& PackageHelper) override;
	virtual bool CanProcessNonPartitionedWorlds() const override { return false; }
	// UWorldPartitionBuilder interface end
private:
	// UWorld* World;
	// UWorldPartition* WorldPartition;
	FSourceControlHelper* SourceControlHelper;
};

USTRUCT()
struct FSceneAutoGroupSettings
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere)
	TArray<FString> LevelNames;
	
	UPROPERTY(EditAnywhere)
	TArray<FHLODGroupRule> HLODGroups;

	UPROPERTY(EditAnywhere)
	TArray<FGridGroupRule> GridGroups;
};

UCLASS(Config = Editor, DefaultConfig, meta = (DisplayName = "KG Auto HLOD Group Builder Settings"))
class UKGHLODAutoGroupBuilderSettings : public UDeveloperSettings
{
	GENERATED_BODY()

public:
	UPROPERTY(Config, EditAnywhere)
	TArray<FSceneAutoGroupSettings> SceneAutoGroupSettings;
};
