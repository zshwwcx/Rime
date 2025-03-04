// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "LevelSequence.h"
#include "NavMesh/NavMeshPath.h"
#include "NavMesh/RecastNavMesh.h"
#include "Interfaces/IHttpRequest.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "Kismet/KismetSystemLibrary.h"

#include "KGWorldPartitionProfilerSubSystem.h"
#include "PhysicsEngine/PhysicsAsset.h"

#include "C7FunctionLibrary.generated.h"

class UMovieSceneSequencePlayer;
/**
 * 
 */

USTRUCT(BlueprintType)
struct FMovieSceneBindingTagTemplate
{
	GENERATED_BODY()

	FMovieSceneBindingTagTemplate()
		:BindingObject(nullptr)
	{
	}

	FMovieSceneBindingTagTemplate(FName Tag, FMovieSceneObjectBindingID ID, UObject* Object)
		:BindingTag(Tag), BindingID(ID), BindingObject(Object)
	{
	}

	UPROPERTY()
	FName BindingTag;

	UPROPERTY()
	FMovieSceneObjectBindingID BindingID;
	
	UPROPERTY()
	TObjectPtr<UObject> BindingObject;
};

UCLASS()
class C7_API UC7FunctionLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	DECLARE_DYNAMIC_DELEGATE_TwoParams(FHttpCallback, bool, Result ,const FString&, InContext);

	UFUNCTION()
	static TArray<FName> GetBindingTags(ULevelSequence* Sequence);

	UFUNCTION()
	static void GetAllSpawnableObjectTemplate(UMovieSceneSequence* Sequence, UMovieSceneSequencePlayer* SequencePlayer, TArray<FMovieSceneBindingTagTemplate>& OutSpawnableObjectTemplates); 
	
	UFUNCTION()
	static FString GetMachineId();

	UFUNCTION()
	static FString GetCurrentLevelName(const UObject* WorldContext);
	
	UFUNCTION()
	static bool MainWorldLoadComplete(UObject* World);

	UFUNCTION()
	static void GetLoadingSubLevels(TArray<FString>& SubLevels,UObject* World);

	UFUNCTION()
	static float GetLoadingProgress(const FString& PackageName,UObject* World);

	UFUNCTION()
	static FString ConvertToPIEPackageName(const FString& PackageName,UObject* WorldContext);

	UFUNCTION()
	static FString StripPIEPackageName(const FString& PackageName,UObject* WorldContext);

	// UFUNCTION()
	// 	static void RenameToPIEWorld(UObject* WorldContext);

	UFUNCTION()
	static void SetPauseLoadingAtMidpoint(UObject* WorldContext,bool InbSopAtMidPoint);

	// UFUNCTION()
	// static FString GetLevelData(const FString& Filename);
	
	UFUNCTION()
	static void CompressAndUploadSaved(const FString& URL);
	
	UFUNCTION()
	static void GetViewportScreenshot(const FString& ImgPath,bool bShowUI = true);

	UFUNCTION()
	static void QAFeedbackPost(const FString& Url, TMap<FString, FString> Content, bool bIsBug, bool bAutoScreenshot, FString PicturePath);

	UFUNCTION()
	static void HttpPost(const FString& Url, TMap<FString, FString> Heads, const FString& Content, FHttpCallback Callback);

	static void OnResponseHttpHead(FHttpRequestPtr InRequest, FHttpResponsePtr InResponse, bool bWasSuccessful);

	UFUNCTION()
	static void AddSubLevel(UWorld* InWorld, FString NewMap, FTransform& Transform);

	UFUNCTION()
	static bool HasActiveWiFiConnection();

	UFUNCTION()
	static void QuitC7Game(const UObject* WorldContextObject);

	UFUNCTION()
	static void GC();

	UFUNCTION()
	static bool IsC7Editor();

	UFUNCTION()
	static bool IsBuildShipping();
	
	UFUNCTION()
	static bool ShowMessageBox(FString Message, FString Title);

	UFUNCTION()
	static bool FindNearstVaildPosition(UObject* WorldContextObject,const FVector& InPos, const FVector& SearchRange,FVector& OutPos);

	UFUNCTION()
	static void CutSceneJumpToFrame(class UMovieSceneSequencePlayer* SequencePlayer, int32 Frame);
	
	UFUNCTION()
	static void LevelSequenceJumpToStart(class UMovieSceneSequencePlayer* SequencePlayer);

	UFUNCTION()
	static void LevelSequenceJumpToFrame(class UMovieSceneSequencePlayer* SequencePlayer, int32 Frame);
	
	UFUNCTION()
	static void LevelSequenceJumpToMark(class UMovieSceneSequencePlayer* SequencePlayer, const FString& InMarkedFrame);
	
	UFUNCTION()
	static void LevelSequencePlayToFrame(class UMovieSceneSequencePlayer* SequencePlayer, int32 Frame);
	
	UFUNCTION()
	static void LevelSequencePlayToMark(class UMovieSceneSequencePlayer* SequencePlayer, const FString& InMarkedFrame);
	
	UFUNCTION()
	static void LevelSequencePlayToEnd(class UMovieSceneSequencePlayer* SequencePlayer);

	UFUNCTION()
	static void TestMalloc(int InSize);

	UFUNCTION()
	static void TestSpawnActors(const UObject* WorldContext, int InNum);

	UFUNCTION()
	static  ETraceTypeQuery ConvertToTraceType(ECollisionChannel CollisionChannel);
	
	UFUNCTION()
	static	EObjectTypeQuery ConvertToObjectType(ECollisionChannel CollisionChannel);
	
	UFUNCTION(BlueprintCallable)
	static bool LineTraceMultiForObjects(const UObject* WorldContextObject, const FVector Start, const FVector End, const TArray<int32>& ObjectTypes, bool bTraceComplex, const TArray<AActor*>& ActorsToIgnore, EDrawDebugTrace::Type DrawDebugType, TArray<FHitResult>& OutHits, TArray<AActor*>& OutActors, bool bIgnoreSelf, FLinearColor TraceColor = FLinearColor::Red, FLinearColor TraceHitColor = FLinearColor::Green, float DrawTime = 5.0f);
	
	UFUNCTION()
	static FString PathCombine(FString& PathA, FString& PathB);

	/*
 * 获取一个UClass的名称
 */
	UFUNCTION()
	static FString GetClassName(UClass* Class);

	/*
	 * 计算一个MeshComponent的3D包围盒
	 */
	UFUNCTION()
	static FVector GetMeshCompBoundBox(UMeshComponent* Component);


	UFUNCTION(BlueprintCallable)
	static	bool GetBoneTransform(const UAnimSequence* Anim, int32 Frame,FName BoneName,USkeletalMeshComponent* Mesh,FTransform& OutTrans);

	UFUNCTION(BlueprintCallable)
	static FVector GetBoneLocation(class USkeletalMeshComponent* MeshComponent, FName BoneName, EBoneSpaces::Type Space = EBoneSpaces::WorldSpace);

	UFUNCTION(BlueprintCallable)
	static float PlayMontageWithInfiniteLoop(UAnimInstance* Anim, UAnimMontage* MontageToPlay, float InPlayRate = 1.f, EMontagePlayReturnType ReturnValueType = EMontagePlayReturnType::MontageLength, float InTimeToStartMontageAt = 0.f, bool bStopAllMontages = true);

	UFUNCTION(BlueprintCallable)
	static bool BreakPlayingMontageInfiniteLoop(UAnimInstance* AnimIns, UAnimMontage* MontagePlaying);

	UFUNCTION(BlueprintCallable)
	static void SetPhysicsAssetForSkeletalMesh(USkeletalMesh* InSkeletalMesh, UPhysicsAsset* InPhysicsAsset);

	UFUNCTION(BlueprintCallable)
	static void SetShadowPhysicsAssetForSkeletalMesh(USkeletalMesh* InSkeletalMesh, UPhysicsAsset* InPhysicsAsset);
	
	UFUNCTION(BlueprintCallable)
	static bool Is_ES3_1_FeatureLevel(UObject* InWorld);

	//Actor是否在当前平台和Scalability中生效
	UFUNCTION(BlueprintCallable)
	static bool Is_Actor_Platform_Active(AActor* Actor);

	//运行时新建自定义AVolume类型IndirectLightOverwriteVolume
	UFUNCTION(BlueprintCallable)
	static void SpawnIndirectLightOverwriteVolume(UObject* WorldContextObject);

	UFUNCTION(BlueprintCallable)
	static void EmptyMeshOverrideMaterials(UMeshComponent* MeshComponent);

	//获取动作枚举EAnimLib_NpcAnimType的Description, just for editor only
	UFUNCTION(BlueprintCallable)
	static FString GetAnimTypeEnumDescription(const FString& EnumName);

	//获取动作枚举EAnimLib_NpcAnimType的EnumName, just for editor only
	UFUNCTION(BlueprintCallable)
	static FString GetAnimTypeEnumNameByDescription(const FString& EnumDescription);

	UFUNCTION(BlueprintCallable)
	FMinimalViewInfo GetCameraPOV(APlayerCameraManager* CM);

	UFUNCTION(BlueprintCallable)
	bool SetApplicationScale(float Scale);

	UFUNCTION(BlueprintCallable)
	FIntPoint GetViewportSize();

#if WITH_EDITOR
	UFUNCTION(BlueprintCallable)
	static bool GetViewportLocationAndRotation(FVector& Location, FRotator& Rotation);
#endif
	
#pragma region Performance
	// 获取热力图 Key Value 类型的性能数据
	UFUNCTION(BlueprintCallable)
	static FString GetHotMapPerformanceData();

	UFUNCTION(BlueprintCallable)
	static FString GetStatUnitData();

	UFUNCTION(BlueprintCallable)
	static void BeginSampleWorld();

	UFUNCTION(BlueprintCallable)
	static void EndSampleWorld();

	// 初始化 Stat 数据列表
	UFUNCTION(BlueprintCallable)
	static void InitWorldProfilerStatList(TArray<FName> StatList);

	UFUNCTION(BlueprintCallable)
	static FString GetWorldProfilerLastStatValueByName(FName name);

	// 获取当前场景所有 Stat 数据
	UFUNCTION(BlueprintCallable)
	static FString GetWorldProfilerLastStatValueList();
	
	static void DumpWorldProfilerData(const FString& FilePath, UKGWorldPartitionProfilerSubSystem* WorldPartitionProfilerSubSystem, TMap<int64,TMap<FName,double>> PerCellStats);

	UFUNCTION(BlueprintCallable)
	static void DumpWorldProfilerAllData();

	static UWorld* GetGameWorld();

	UFUNCTION(BlueprintCallable)
	static bool CheckWorldPartitionSteamingReady();

	UFUNCTION(BlueprintCallable)
	static FString DumpWorldPartitionSteamingInfo();

	UFUNCTION(BlueprintCallable)
	static void CheckSteamingWhenJumpToNextPoint();

	UFUNCTION(BlueprintCallable)
	static FString DumpWorldPartitionCellMemoryInfo();

	UFUNCTION(BlueprintCallable)
	//获取指定 Key 的 WorldPartitionCell的内存信息
	static FString GetWorldPartitionCellMemoryInfo(const FString& Key);

#pragma endregion Performance

#pragma region 3C
public:
	// 根据起始点和终止点，返回一个寻路坐标点列表
	//AdjustToGroundInterval:是否要将NavMesh寻路的点在Ground采样，默认需要且采样间隔为10，设置为0即不采样。
	UFUNCTION(BlueprintCallable)
	static TArray<FVector> FindPathPointList(UObject* WorldContext, const FVector& InStart, const FVector& InEnd, float MaxPathLength = 5000.0f, float MaxMergeLength = 0.0f, float EdgeOffset = 0.0f, float GroundFlowOffset = 0, bool UseWayPoint = true, float AdjustToGroundInterval = 10.0f);

	UFUNCTION(BlueprintCallable)
	static bool FindPathPointListV2(UObject* WorldContext, const FVector& InStart, const FVector& InDest, bool UseWayPoint, float EdgeOffset, bool bRequireNavigableEndLocation, TArray<FVector>& OutPathPoints);

	UFUNCTION(BlueprintCallable)
	static bool GetNearestNaviPoint(UObject* WorldContext, const FVector& Point, const FVector& Extent, FVector& OutPoint);

	//获取地面高度
	UFUNCTION(BlueprintCallable)
	static bool GetWalkableFloorPos(FVector StartPos, FVector EndPos, FVector& OutPos, UObject* WorldContextObject);

	UFUNCTION(BlueprintCallable)
	static bool NavMeshRaycast(UObject* WorldContext, const FVector& InStart, const FVector& InDest, FVector& OutPos);
	
private:
	static const ARecastNavMesh* GetNavMesh(UWorld* World);
	static TArray<FVector> OffsetFromEdge(TSharedPtr<FNavMeshPath> Path, float MaxMergeLength, float EdgeOffset);
	static TArray<FVector> AdjustPathPointToGround(const TArray<FVector>& PathPoints, const ARecastNavMesh* NavMesh, float SampleDistance = 50.0f);

#pragma endregion 3C

#pragma region CrashReport

public:
public:
	UFUNCTION(BlueprintCallable)
	static void UpdateCrashReportValue(const FString& Key, const FString& Value);
	
	UFUNCTION(BlueprintCallable)
	static void InitCrashReport();

private:
	UFUNCTION()
	void OnPreUpdateResult(int32 InErrorCode);

public:
	UFUNCTION()
	static void TestCrash();
	
	UFUNCTION()
	static void TestError();

	UFUNCTION()
	static void TestException();

#pragma endregion CrashReport

};
