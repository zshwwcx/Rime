// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "MapCommon.h"
#include "C7MapTagBase.h"
#include "C7MapTagEdgeWidget.h"
#include "Components/CanvasPanel.h"
#include "C7MapTagLayer.generated.h"


class UWidget;
class UCanvasPanel;

#define MAP_TAG_SELECTION_Z_ORDER 100

DECLARE_CYCLE_STAT(TEXT("MapTagCenter Tick"),STAT_MapTickCenterTick,STATGROUP_Game);


DECLARE_DYNAMIC_DELEGATE_TwoParams(FOnTagClicked, int32,TaskID,TArray<int32>,NearByTags);
DECLARE_DYNAMIC_DELEGATE_OneParam(FOnEdgeTagClicked, int32,TaskID);


USTRUCT(BlueprintType)
struct FMapTagPool
{
	GENERATED_BODY()
public:
	UWidget* GetWidgetFromPool(const FName& WidgetName)
	{
		TArray<int32>* Keys = KeyMaps.Find(WidgetName);
		if (!Keys)
		{
			KeyMaps.Add(WidgetName,TArray<int32>());
		}
	
		Keys = KeyMaps.Find(WidgetName);

		UWidget* Widget = nullptr;
		if (Keys && Keys->Num() > 0)
		{
			const int32 Key = Keys->Pop();
			UWidget** WidgetPtrPtr = WidgetRefPools.Find(Key);
			if (WidgetPtrPtr!= nullptr)
			{
				Widget = *WidgetPtrPtr;
			}
			
			WidgetRefPools.Remove(Key);
		}
		
		return Widget;
	}

	void ReturnWidgetToPool(const FName& WidgetName,UWidget* InWidget)
	{
		InWidget->RemoveFromParent();

		TArray<int32>* Keys = KeyMaps.Find(WidgetName);
		if (Keys)
		{
			Keys->Add(++NextAutoIncrementKey);
			WidgetRefPools.Add(NextAutoIncrementKey,InWidget);
		}
	}

	void ClearUp()
	{
		WidgetRefPools.Reset();
		KeyMaps.Reset();
		NextAutoIncrementKey = 0;
	}
	
	uint32 NextAutoIncrementKey = 0;
	TMap<FName,TArray<int32>> KeyMaps;
	
	UPROPERTY(BlueprintReadWrite)
	TMap<int32,UWidget*> WidgetRefPools;
};




struct FMapTagBasicData;
struct FTagDisplayConfig;

DECLARE_DYNAMIC_DELEGATE_RetVal_TwoParams(TArray<FMapTagRunningData>,FGenerateRunningData,TArray<int32>,TagIDs,int32,TagDisplayMode);
DECLARE_DYNAMIC_DELEGATE_RetVal_OneParam(TArray<int32>,FGetMapTags,int32,MapID);

DEFINE_LOG_CATEGORY_STATIC(LogMapTag, Log, All);

UCLASS()
class C7_API UC7MapTagLayer : public UCanvasPanel,public FTickableGameObject
{
	GENERATED_BODY()
	
public:
	UFUNCTION(BlueprintCallable)
	void Init(int32 InTagDisplayMode);
	
	UFUNCTION(BlueprintCallable)
	void SetConstrainInCanvasMode(FVector4& InEdgePadding);
	
	UFUNCTION(BlueprintCallable)
	void SetConstrainInCircleMode(float Radius);
	
	UFUNCTION(BlueprintCallable)
	void Uninit();
	
	UFUNCTION(BlueprintCallable)
	void ClearMap();
	
	UFUNCTION(BlueprintCallable)
	void SetMap(
		int32 MapID,
		int32 PlaneID,
		const FVector CameraLoc,
		const FRotator CameraRot,
		const FVector2D& NewMapWorldSize,
		float InWorldSizeToWidgetSizeRatio,
		float MapMaxScale,
		float MapMinScale,
		TArray<FVector>& InLayerData,
		TSet<FName>& LDNames);
	
	UFUNCTION(BlueprintCallable)
	void AddMapTask(int32 TaskID);
	
	UFUNCTION(BlueprintCallable)
	void AddMapTasks(TArray<int32> Tasks);
	
	UFUNCTION(BlueprintCallable)
	void RemoveMapTask(int32 TaskID);
	
	UFUNCTION(BlueprintCallable)
	void OnViewScreenChanged(const FVector2D& ScreenCenterOnWidgetLoc,float NewMapScale,float MapCenterRotation = 0,float ScreenCenterRotation = 0);

	UFUNCTION(BlueprintCallable)
	void OnViewScreenChangedByWorldLoc(const FVector& WorldLoc,float NewMapScale,float MapCenterRotation = 0,float ScreenCenterRotation = 0);
	
	UPROPERTY(BlueprintReadWrite)
	FOnTagClicked OnTagClickedEvent;
	
	UPROPERTY(BlueprintReadWrite)
	FOnEdgeTagClicked OnEdgeTagClickedEvent;
	
	UFUNCTION(BlueprintCallable)
	FVector2D WorldLocToWidgetLocRaw(const FVector& InWorldLoc);

	UFUNCTION(BlueprintCallable)
	void WorldLocToWidgetLocRaw_XY(const FVector& InWorldLoc,float& X, float& Y);
	
	UFUNCTION(BlueprintCallable)
	FVector2D GetTagWidgetLocationByID(const int32 TaskID);

	UFUNCTION(BlueprintCallable)
	void SetTaskSelection(int32 TaskID,bool bSelected);
	
	UFUNCTION(BlueprintCallable)
	void SetTaskTrace(int32 TaskID,bool bTrace);

	UFUNCTION(BlueprintCallable)
	void SetCurrentLayer(int32 InLayerID);


	UFUNCTION(BlueprintCallable)
	void RepositionTag(int32 TaskID,const FVector& NewWorldLoc,int32 NewMapID,int32 NewPlaneID);

	UFUNCTION(BlueprintCallable)
	void RepositionTagByActor(int32 TaskID, AActor* Actor);

	UFUNCTION(BlueprintCallable)
	void SetTagVisibility(int32 TaskID,ESlateVisibility NewVisibility);
	
	UFUNCTION(BlueprintCallable)
	void UpdateMiniMap(UWidget* MapWidget, UWidget* PlayerWidget,UWidget* SightConeWidget, EMiniMapUpdateRule UpdateRule,float Scale);
	
	UFUNCTION(BlueprintCallable)
	static void SetWidgetRotationByActorRot(UWidget* Widget,AActor * Actor,float InitialRotDelta );

	UFUNCTION(BlueprintCallable)
	int32 GetLayerID(FVector& Location);
	
	UFUNCTION(BlueprintCallable)
	void GetNearByTags(FVector2D& ScreenLocation,float ToleranceDist,bool ClickableOnly,TArray<int32>& OutArray);
	
	TSharedPtr<FMapTagRunningData> GetTaskById(const int32 ID);
	
	void OnTagClicked(int32 TaskID);
	void OnEdgeTagClicked(int32 TaskID);

public:
	//边缘限制模式
	UPROPERTY(BlueprintReadWrite)
	TEnumAsByte<EMapEdgeMode> EdgeMode = EMapEdgeMode::CONSTRAIN_IN_CANVAS;

	UPROPERTY(BlueprintReadWrite)
	float ToleranceScale = 1.2;

	UPROPERTY(BlueprintReadWrite)
	FVector4 EdgePadding = FVector4(0,0,0,0);
	
	//限制在圆圈内 半径
	UPROPERTY(BlueprintReadWrite)
	float ConstrainRadius;

	UPROPERTY(BlueprintReadWrite)
	FGenerateRunningData GenerateRunningDataDelegate;
	
	UPROPERTY(BlueprintReadWrite)
	FGetMapTags GetMapTagsDelegate;

	UPROPERTY(BlueprintReadWrite)
	TArray<FVector> LayerData;

	UPROPERTY(BlueprintReadWrite)
	float ClickToleranceDist = 200;  //点击判断周围标签的范围
	

	//Tickable Object Override
	virtual void Tick(float DeltaTime) override;
	virtual TStatId GetStatId() const override;
	virtual bool IsTickable() const override;

	//处理待处理队列
	void ProcessPendingTasks();
	
	//Tag位置计算
	void UpdateTagScreenLocation(TSharedPtr<FMapTagRunningData> Task,bool bUpdateStatic);
	FVector2D GetProjectOnEdgeLoc(const FVector2D& WidgetLoc,const FVector2D& WidgetSize);
	
	//对象池
	UWidget* GetWidgetFromPool(const FName& WidgetName);
	void ReturnWidgetToPool(const FName& WidgetName,UWidget* InWidget);
	void ActiveTagWidget(TSharedPtr<FMapTagRunningData> InTask,UWidget* Widget);
	void ReturnEdgeTaskWidget(UC7MapTagEdgeWidget* EdgeTagWiget);

	

	//更新任意标签
	void UpdateTags(const TArray<TSharedPtr<FMapTagRunningData>>& MapTagTasks);
	void UpdateTasksScreenLoc(const TArray<TSharedPtr<FMapTagRunningData>>& MapTasks);
	
	//普通Tag更新
	void InnerUpdateTagTask(TSharedPtr<FMapTagRunningData> Task,UWidget* TagWidget,bool bUpdateLoc);
	void UpdateTagTasks(const TArray<TSharedPtr<FMapTagRunningData>>& MapTasks);

	//边缘Tag更新
	void InnerUpdateEdgeTask(TSharedPtr<FMapTagRunningData> Task,UWidget* EdgeWidget);
	void UpdateEdgeTasks(const TArray<TSharedPtr<FMapTagRunningData>>& MapTasks);

	//选中Tag更新
	void InnerUpdateSelectionTask(TSharedPtr<FMapTagRunningData> Task,UWidget* TagWiget,bool bUpdateLoc);
	void UpdateSelectionTasks(const TArray<TSharedPtr<FMapTagRunningData>>& MapTasks);

	//显示判定
	inline bool IsInConstrainCircle(const FVector2D& WidgetLoc);
	inline bool IsInConstrainSquare(const FVector2D& WidgetLoc,bool bUsePadding,const FVector2D& WidgetSize);
	inline bool IsInConstrainArea(const TSharedPtr<FMapTagRunningData> Task,bool UsePadding);
	inline bool ShouldShow(const TSharedPtr<FMapTagRunningData> Task,bool UsePadding);
	inline bool ShouldKeepOnEdge(const TSharedPtr<FMapTagRunningData> Task);
	inline bool IsInSameMap(const TSharedPtr<FMapTagRunningData> Task);
	void ClearTagWidgets();

	//对象池
	UPROPERTY(BlueprintReadWrite, Transient)
	FMapTagPool MapTagPool;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TEnumAsByte<EMapDisplayMode> MapDisplayMode = EMapDisplayMode::SCALE_RATIO;
	

	FVector2D PanelSize;
	FVector2D PanelTolerancePadding;
	
	//地形图信息
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	int32 CurrentMapID = -1;
	int32 CurrentPlaneID = 0;
	int32 CurrentLayerID = 0;
	TSet<FName> CurrentLDNames;
	
	bool bForceRefreshNextTick = true;
	
	int32 TagDisplayMode = -1;
	
	FVector CameraLocation;
	FRotator CameraRotation;
	FVector2D MapWorldCenter;
	FVector2D MapWorldSize;
	FVector2D MapWidgetSizeRaw;
	float WorldSizeToWidgetSizeRatio;
	float MapMaxScale;
	float MapMinScale;
	float CurrentMapScale;
	float CurrentScaleRatio;
	FVector2D CurrentScreenCenterLoc;
	float CurrentMapCenterRoation = 0;
	float CurrentScreenCenterRotation = 0;
	
	TMap<int32,TSharedPtr<FMapTagRunningData>> MapStaticTasks;
	TMap<int32,TSharedPtr<FMapTagRunningData>> MapTickTasks;

	
	
	TArray<int32> PendingMapTasks;
};



