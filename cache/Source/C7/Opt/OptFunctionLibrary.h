// Copyright KuaiShou Games, Inc. All Rights Reserved.
// Author: liubo11@kuaishou.com
/**
 * Auth :   liubo
 * Date :   2024-11-11 02:07 
 * Comment: Opt工具，提供给lua的接口
 */

#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "OptFunctionLibrary.generated.h"

USTRUCT(BlueprintType)
struct FLevelMemoryInfoKv
{
	GENERATED_BODY()
	
	UPROPERTY(VisibleAnywhere)
	FString Key;

	// string, int64, float 
	UPROPERTY(VisibleAnywhere)
	FString ValueType;
	
	UPROPERTY(VisibleAnywhere)
	FString Value;
};

// 贴图信息
USTRUCT(BlueprintType)
struct FPrTextureInfo
{
	GENERATED_BODY()

	UPROPERTY(VisibleAnywhere)
	FString Path;

	UPROPERTY(VisibleAnywhere)
	FString TextureGroup;
	
	UPROPERTY(VisibleAnywhere)
	TArray<FString> Tags;	
	

	UPROPERTY(VisibleAnywhere)
	int32 CurSizeX = 0;
	
	UPROPERTY(VisibleAnywhere)
	int32 CurSizeY = 0;
	
	UPROPERTY(VisibleAnywhere)
	int32 CurrentMemSize = 0;

	
	UPROPERTY(VisibleAnywhere)
	int32 MaxAllowedSizeX = 0;
	
	UPROPERTY(VisibleAnywhere)
	int32 MaxAllowedSizeY = 0;
	
	UPROPERTY(VisibleAnywhere)
	int32 MaxAllowedMemSize = 0;	
};

USTRUCT(BlueprintType)
struct FLevelTextureInfo
{
	GENERATED_BODY()

	UPROPERTY(VisibleAnywhere)
	FString PathName;
	
	UPROPERTY(VisibleAnywhere)
	FString CellName;

	// Persistent, AlwaysLoad, Streaming
	UPROPERTY(VisibleAnywhere)
	FString StreamingType;

	UPROPERTY(VisibleAnywhere)
	int TextureCount = 0;
	
	UPROPERTY(VisibleAnywhere)
	int64 TextureMemorySize = 0;
	
	UPROPERTY(VisibleAnywhere)
	TArray<FPrTextureInfo> TextureInfos;
};

USTRUCT(BlueprintType)
struct FLevelMemoryInfo
{
	GENERATED_BODY()

	UPROPERTY(VisibleAnywhere)
	FString PathName;
	
	UPROPERTY(VisibleAnywhere)
	FString CellName;

	// Persistent, AlwaysLoad, Streaming
	UPROPERTY(VisibleAnywhere)
	FString StreamingType;

	UPROPERTY(VisibleAnywhere)
	int TextureCount = 0;
	
	UPROPERTY(VisibleAnywhere)
	int64 TextureMemorySize = 0;
	
	UPROPERTY(VisibleAnywhere)
	int StaticMeshCount = 0;
	
	UPROPERTY(VisibleAnywhere)
	int64 StaticMeshMemorySize = 0;
	
	UPROPERTY(VisibleAnywhere)
	int SkeletalMeshCount = 0;
	
	UPROPERTY(VisibleAnywhere)
	int64 SkeletalMeshMemorySize = 0;
	
	UPROPERTY(VisibleAnywhere)
	int ActorCount = 0;
	
	UPROPERTY(VisibleAnywhere)
	int PrimitiveCount = 0;

	UPROPERTY(VisibleAnywhere)
	TArray<FLevelMemoryInfoKv> AllKvs;	
};

USTRUCT(BlueprintType)
struct FMapMemoryInfo
{
	GENERATED_BODY()

	// 细分Cell的信息
	UPROPERTY(VisibleAnywhere)
	TArray<FLevelMemoryInfo> Levels;

	// 世界的信息（Cell之间有重用的贴图，所以单独提供一个汇总的）
	UPROPERTY(VisibleAnywhere)
	FLevelMemoryInfo MapTotalInfo;

	// 玩家的信息，非大世界情况下，返回是空的
	UPROPERTY(VisibleAnywhere)
	TArray<FLevelMemoryInfo> PlayerCellInfo;
};

USTRUCT(BlueprintType)
struct FMapTextureInfo
{
	GENERATED_BODY()

	// 细分Cell的信息
	UPROPERTY(VisibleAnywhere)
	TArray<FLevelTextureInfo> Levels;

	// 世界的信息（Cell之间有重用的贴图，所以单独提供一个汇总的）
	UPROPERTY(VisibleAnywhere)
	FLevelTextureInfo MapTotalInfo;

	// UI贴图信息	
	UPROPERTY(VisibleAnywhere)
	TArray<FPrTextureInfo> UITextureInfos;

	// 玩家的信息，非大世界情况下，返回是空的
	UPROPERTY(VisibleAnywhere)
	TArray<FLevelTextureInfo> PlayerCellInfo;
};

// 信息合集
USTRUCT(BlueprintType)
struct FPrMapInfoAll
{
	GENERATED_BODY()

	UPROPERTY(VisibleAnywhere)
	FMapTextureInfo MapTexture;

	UPROPERTY(VisibleAnywhere)
	FMapMemoryInfo MapMemoryInfo;
};

/**
 * 
 */
UCLASS()
class C7_API UOptFunctionLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	// 地图是否全部加载、卸载完毕
	UFUNCTION(BlueprintPure, Category="OptUtils")
	static bool HasAllLevelLoaded();

	// dump场景状态	
	UFUNCTION(BlueprintCallable, Category="OptUtils")
	static TArray<FLevelMemoryInfoKv> GetStreamingState();

	// 获取当前地图的信息
	UFUNCTION(BlueprintCallable, Category="OptUtils")
	static FMapMemoryInfo GetMapDetailMemoryInfo();

	// 获取玩家所在的Cell的名字
	static TArray<FString> GetPlayerCellName();

	// 获取玩家所在的Cell的信息（只返回第0层的Cell），如果是“非大世界”，那么返回空的
	UFUNCTION(BlueprintCallable, Category="OptUtils")
	static TArray<FLevelMemoryInfo> GetPlayerCellDetailMemoryInfo();
	
	// 获取当前地图的贴图信息
	UFUNCTION(BlueprintCallable, Category="OptUtils")
	static FMapTextureInfo GetMapDetailTextureInfo();
	
	// 获取玩家所在的Cell的信息（只返回第0层的Cell），如果是“非大世界”，那么返回空的
	UFUNCTION(BlueprintCallable, Category="OptUtils")
	static TArray<FLevelTextureInfo> GetPlayerCellDetailTextureInfo();
	
	// 获取当前地图的信息（比较全）
	UFUNCTION(BlueprintCallable, Category="OptUtils")
	static FPrMapInfoAll GetMapDetailInfoAll();
};
