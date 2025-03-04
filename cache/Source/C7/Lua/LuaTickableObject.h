// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/NoExportTypes.h"
#include "Tickable.h"
#include "LuaTickableObject.generated.h"


DECLARE_DYNAMIC_DELEGATE_ThreeParams(FOnLuaTick, float, DeltaTime, double, timeSeconds, double, realTimeSeconds);

/**
 * 
 */
UCLASS()
class C7_API ULuaTickableObject : public UObject, public FTickableGameObject
{
	GENERATED_BODY()

public:

	UPROPERTY()
	FOnLuaTick OnLuaTick;

public:
	virtual void Tick(float DeltaTime) override;
	bool IsTickable() const
	{
		return (HasAnyFlags(RF_ClassDefaultObject) == false);
	}


	virtual TStatId GetStatId() const override;

private:
	double timeSeconds = 0;
	double realTimeSeconds = 0;
};
