/**
 * Auth :   liubo
 * Date :   2023-09-08 14:25
 * Comment: 处理大世界的NavMesh
 */

#pragma once

#include "CoreMinimal.h"
#include "Commandlets/Commandlet.h"
#include "Commandlets/ResavePackagesCommandlet.h"
#include "C7PartitionNavmeshBuildCommandlet.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogC7PartitionNavmeshBuildCommandlet, All, All);

DECLARE_DELEGATE_TwoParams(FSavePackageFunction, UPackage*, TArray<FString>&)

UCLASS()
class UC7PartitionNavmeshBuildCommandlet : public UResavePackagesCommandlet
{
	GENERATED_BODY()

public:
	UC7PartitionNavmeshBuildCommandlet();

	virtual int32 Main(const FString& InCommandline) override;

	
	static int32 DoAction(UWorld* World, FSavePackageFunction Callback);
	static int32 OldFlow(UWorld* World, FSavePackageFunction Callback);
	static void SetFixedTilePoolSize(bool save, bool bFixedTilePoolSize, bool bIsWorldPartitioned);
};
