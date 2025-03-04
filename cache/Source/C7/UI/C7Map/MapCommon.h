// Fill out your copyright notice in the Description page of Project Settings.

#pragma once
#include "Components/SlateWrapperTypes.h"
#include "CoreMinimal.h"
#include "MapCommon.generated.h"

UENUM(BlueprintType)
enum EMiniMapUpdateRule
{
	//静态
	PLAYER_FACE_UPWARD =0 ,
	//跟随目标
	UPWARD_NORTH = 1,
};


UENUM(BlueprintType)
enum ETagFollowType
{
	//无效，不显示
	INVALID =0,
	//静态
	STATIC =1 ,
	//跟随目标
	FOLLOW_ACTOR = 2,
	//如果有Follow则跟随目标，否则就显示目标点
	BOTH = 3,
};


UENUM(BlueprintType)
enum EMapEdgeMode
{
	//限制在画布边缘
	CONSTRAIN_IN_CANVAS,
	//限制在圆圈对
	CONSTRAIN_IN_CIRCLE
};

UENUM(BlueprintType)
enum EKeepOnEdgeType
{
	//不显示在边缘
	NONE,
	//始终显示在边缘
	ALWAYS,
	//被追踪时显示在边缘
	ON_TRACE,
	//被选中时显示在边缘
	ON_SELECTED,
	//被追踪或被选中时显示在边缘
	ON_TRACE_OR_SELECTED
};

UENUM(BlueprintType)
enum ESizeOverrideType
{
	//直接覆盖widget大小
	WIDGET_SIZE,
	//根据场景大小换算
	WORD_SIZE,
}; 


UENUM(BlueprintType)
enum class EMapTagPanelType : uint8
{
	//基础动画
	Common,
	Minimap,
	SubWayMap,
};

UENUM(BlueprintType)
enum EMapDisplayMode
{
	//根据比例缩放
	SCALE_RATIO,
	//画布大小即是地图大小，总是显示完整的地图
	MATCH_MAP_SIZE,
}; 




USTRUCT(BlueprintType)
struct FTagDisplayConfig
{
	GENERATED_BODY()
	//在边缘时包裹框路径
	UPROPERTY(BlueprintReadWrite)
	FName EdgeWidgetPath = "";
	//选中时框体路径
	UPROPERTY(BlueprintReadWrite)
	FName SelectionWidgetPath = "";

	//在地图放到到一定比例时显示
	UPROPERTY(BlueprintReadWrite)
	float ShowRatio = 0;
	//在地图放到到一定比例时隐藏
	UPROPERTY(BlueprintReadWrite)
	float HideRatio = 1;
	//距离玩家多远显示
	UPROPERTY(BlueprintReadWrite)
	float ShowDistance = -1;
	//距离玩家多远隐藏
	UPROPERTY(BlueprintReadWrite)
	float HideDistance = -1;
	
	//缩放比例
	UPROPERTY(BlueprintReadWrite)
	FVector2D Scale = FVector2D(1,1);
	//层级
	UPROPERTY(BlueprintReadWrite)
	int32 Zorder = 0;

	//显示在边缘条件
	UPROPERTY(BlueprintReadWrite)
	TEnumAsByte<EKeepOnEdgeType> KeepOnEdgeType = EKeepOnEdgeType::NONE;


	//可见性
	UPROPERTY(BlueprintReadWrite)
	ESlateVisibility Visibility = ESlateVisibility::SelfHitTestInvisible;
};


USTRUCT(BlueprintType)
struct FMapTagBasicData
{
	GENERATED_BODY()
	
	UPROPERTY(BlueprintReadWrite)
	int32 MapID = -1;
	UPROPERTY(BlueprintReadWrite)
	int32 PlaneID = 0;
	UPROPERTY(BlueprintReadWrite)
	FName LDName;

	
	//标签ID
	UPROPERTY(BlueprintReadWrite)
	int32 TagID = -1;

	UPROPERTY(BlueprintReadWrite)
	int32 TagType = -1;
	
	//跟随类型
	UPROPERTY(BlueprintReadWrite)
	int32 FollowType = ETagFollowType::INVALID;


	//静态标签： 位置
	UPROPERTY(BlueprintReadWrite)
	bool bWorldLocValid = false;
	//静态标签： 位置
	UPROPERTY(BlueprintReadWrite)
	FVector  WorldLoc =FVector(0,0,0) ;

	// //是否自动计算层级ID
	// UPROPERTY(BlueprintReadWrite)
	// bool bAutoCalcLayerID = false;


	
	//跟随Actor标签： 位置
	UPROPERTY(BlueprintReadWrite)
	TWeakObjectPtr<AActor> FollowActor = nullptr;
	//跟随Actor标签： 是否随Actor旋转
	UPROPERTY(BlueprintReadWrite)
	bool bRotateWithActor = false;
	//标签位置在屏幕上偏移
	UPROPERTY(BlueprintReadWrite)
	FVector2D WidgetPositionOffset = FVector2D(0,0);


	UPROPERTY(BlueprintReadWrite)
	FName TagWidgetPath = "";

	//显示的名称
	UPROPERTY(BlueprintReadWrite)
	FString TagName = "";
	//图标路径
	UPROPERTY(BlueprintReadWrite)
	FName TagIconPath = "";
	//Icon资源
	UPROPERTY(BlueprintReadWrite)
	TSoftObjectPtr<UObject> IconObj;
	//图标染色
	UPROPERTY(BlueprintReadWrite)
	FSlateColor IconTintColor = FColor::White;

	//是否调整大小
	float ShowDistance = -1;
	//是否调整大小
	float HideDistance = -1;
	//是否调整大小
	UPROPERTY(BlueprintReadWrite)
	bool bOverrideSize = false;
	//调整大小
	UPROPERTY(BlueprintReadWrite)
	FVector2D SizeOverride = FVector2D(36,36);
	//是否随地图大小缩放
	UPROPERTY(BlueprintReadWrite)
	int32 SizeOverrideType = ESizeOverrideType::WIDGET_SIZE;
	UPROPERTY(BlueprintReadWrite)
	bool bScaleWithMapScale = false;

};


struct FMapTagsData
{
	int32 MapID;
	TMap<int32,FMapTagBasicData> Tags;
};

class UWidget;
USTRUCT(BlueprintType)
struct FMapTagRunningData
{
	GENERATED_BODY()
	
	UPROPERTY(BlueprintReadWrite)
	FMapTagBasicData TagData;
	UPROPERTY(BlueprintReadWrite)
	FTagDisplayConfig DisplayData;


	FVector2D WidgetLoc;
	FVector2D WidgetScreenLoc;
	FVector2D WidgetCoord;
	
	bool bWidgetLocValid = false;
	bool bValidScreenLoc = false;
	bool bSelected = false;
	bool bTraced = false;
	int LayerID = 0;

	TWeakObjectPtr<UWidget> TagWidget;
	TWeakObjectPtr<UWidget> EdgeWidget;
	TWeakObjectPtr<UWidget> SelectionWidget;
};