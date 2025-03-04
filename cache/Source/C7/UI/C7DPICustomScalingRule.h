// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Engine/DPICustomScalingRule.h"
#include "C7DPICustomScalingRule.generated.h"



/**
 *
 */
UCLASS(config = Game,defaultconfig, meta=(DisplayName="User Interface"))
class C7_API UC7DPICustomScalingRule : public UDPICustomScalingRule
{
	GENERATED_BODY()
	
	virtual float GetDPIScaleBasedOnSize(FIntPoint Size) const override;
};
