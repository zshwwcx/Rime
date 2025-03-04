#pragma once

#include "CoreMinimal.h"
#include "Engine/AssetManager.h"
#include "C7AssetManager.generated.h"

UCLASS()
class C7_API UC7AssetManager : public UAssetManager
{
	GENERATED_BODY()

public:
	UC7AssetManager();

	static const FPrimaryAssetType C7PrimaryAssetLabelType;

	virtual void FinishInitialLoading() override;

#if WITH_EDITOR
	// Begin override UAssetManager interfaces
	virtual void ApplyPrimaryAssetLabels() override;
	virtual void ScanPrimaryAssetRulesFromConfig() override;
	virtual void ModifyCook(TConstArrayView<const ITargetPlatform*> TargetPlatforms, TArray<FName>& PackagesToCook, TArray<FName>& PackagesToNeverCook) override;
	virtual FString OverrideChunkName(int32 PakchunkIndex, int32 SubChunkIndex) const override;
	virtual bool GetPackageChunkIds(FName PackageName, const class ITargetPlatform* TargetPlatform, TArrayView<const int32> ExistingChunkList, TArray<int32>& OutChunkList, TArray<int32>* OutOverrideChunkList = nullptr) const override;
	// End override UAssetManager interfaces

	void GetLuaReferencedAssets(TArray<FName>& OutReferencedAssets, FString ChunkName = "None");
	bool IsSoftReferencedByStartupPackage(FName PackageName) const;
	bool IsStartupPackage(FName PackageName) const;
	bool IsMapPackage(FName PackageName) const;

	FString GetAssetForUnreal5(FString NormalPath, bool& ContainExtension);
#endif // WITH_EDITOR

	virtual void StartInitialLoading() override;

protected:
#if WITH_EDITOR
	TMap<FName, bool> WorldPackages;
	TMap<FName, FName> StartupSoftPackages;
	TMap<FName, bool> StartupPackages;
	TMap<int32, FString> ChunkNameMap;
	int32 CoreChunkId = 0;
	int32 BaseChunkId = 0;
#endif // WITH_EDITOR
};
