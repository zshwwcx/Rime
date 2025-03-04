// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "LogicActor.h"
#include "LightActorBase.generated.h"

UCLASS()
class C7_API ALightActorBase : public AActor, public ILuaOverriderInterface
{
	GENERATED_BODY()
public:
	ALightActorBase();
	
	virtual void BeginPlay() override;

	UFUNCTION(BlueprintImplementableEvent)
	void LightActorInit();
};
