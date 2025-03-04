// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Components/Widget.h"
#include "SKGPharamcistLineWidget.h"
#include "KGPharamcistLineWidget.generated.h"

/** 药师玩法画线Widget，用于从起始点(药剂图标)开始，连接每个中继点，一直到终点停止，画出多段直线。
 *  LinkPoints:(A, B, C, D)， 画线连接关系为:A -> B -> C -> D
 */
UCLASS()
class UKGPharamcistLineWidget : public UWidget
{
	GENERATED_BODY()

public:
	// 线段连接点，用于MakeLines
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TArray<FVector2f> LinkPoints;

	// // 起始点
	// UPROPERTY(EditAnywhere, BlueprintReadWrite)
	// TSoftObjectPtr<UWidget*> StartWidget;

	// 线段粗细，默认1.0f
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	float LineThickness = 1.0f;

	// 线段是否使用抗锯齿，默认true
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	bool bAntialias = true;

	// 线段颜色，默认白色
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FLinearColor LineColor = FLinearColor::White;

	// 是否支持两两连线
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	bool bEnableCoupeLink = false;
	
	virtual void SynchronizeProperties() override;

protected:
	TSharedPtr<SKGPharamcistLineWidget> CurrentWidget;

	virtual TSharedRef<SWidget> RebuildWidget() override;

public:
	virtual void ReleaseSlateResources(bool bReleaseChildren) override;

	UFUNCTION()
	void ResetWidget();

	UFUNCTION()
	bool UpdateFirstNodePos(float X, float Y);
};
