#pragma once

#include "CoreMinimal.h"
#include "Engine/PrimaryAssetLabel.h"
#include "C7PrimaryAssetLabel.generated.h"

#define JSON_CONFIG TEXT("Pak")/TEXT("Pak.json")  

struct LMapData
{
	bool NeedPackage;
	FString LevelPath;
	LMapData()
	{
		NeedPackage = false;
		LevelPath = "";
	}
}; 

UENUM()
enum class EConfigFrom : uint8
{
	ChunkLabel,
	JSON
};


UCLASS()
class C7_API UC7PrimaryAssetLabel : public UPrimaryAssetLabel
{
	GENERATED_BODY()

public:
	static const FName TableAndLuaReferencedBundle;
	static const FName AlwaysCookBundle;
	static const FName CompositionLevelBundle;
	static const FName ExplicitDirectoryBundle;
	static const FName ExplicitAssetBundle;

	UC7PrimaryAssetLabel();
#if WITH_EDITOR
	UFUNCTION(CallInEditor, Category = Base)
	void CheckUpdateAssetBundleData();

#endif

#if WITH_EDITORONLY_DATA

	void Lua();
	void AlwaysCook();

	void Update();

	virtual void UpdateAssetBundleData() override;
	void AddAsset(TArray<TSharedPtr<FJsonValue>> Assetes, TArray<FTopLevelAssetPath>& NewAssetPaths);
	void AddDirectory(TArray<TSharedPtr<FJsonValue>> Directories,TArray<FTopLevelAssetPath>& NewDirectoryPaths);
	bool UpdateByJson();

	void CollectAssetPaths(const FString& InAssetPath, TArray<FTopLevelAssetPath>& OutPaths);

	
#endif

	UPROPERTY(EditAnywhere, Category = PrimaryAssetLabel)
	bool bLabelAssetsReferencedInTableAndLua = false;

	UPROPERTY(EditAnywhere, Category = PrimaryAssetLabel)
	bool bLabelAlwaysCookDirectories = false;

	UPROPERTY(EditAnywhere, Category = PrimaryAssetLabel)
	bool bLableWorldCompositionLevel = false;

	UPROPERTY(EditAnywhere, Category = PrimaryAssetLabel, meta = (LongPackageName))
	TArray<FDirectoryPath> ExplicitDirectories;

	UPROPERTY(EditAnywhere, Category = Chunk)
	FString ChunkName;

	UPROPERTY(EditAnywhere, Category = Chunk)

	bool bIsCoreChunk = false;

	UPROPERTY(EditAnywhere, Category = Chunk)
	bool bIsBaseChunk = false;

	//Add by Masou 2024.4.29
	UPROPERTY(EditAnywhere, Category = Base)
	EConfigFrom ConfigFrom = EConfigFrom::JSON;

	UPROPERTY(EditAnywhere, Category = PrimaryAssetLabel)
	TArray<FSoftObjectPath> C7ExplicitAssets;

};
