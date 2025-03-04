// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "ProfilerInstrumentation.generated.h"

/**
 * 
 */
UCLASS()
class C7_API UProfilerInstrumentation : public UObject
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintCallable)
	static bool CycleCounterCreate(FName StatName, FString StatDesc = "");
	UFUNCTION(BlueprintCallable)
	static bool CycleCounterStart(FName StatName);
	UFUNCTION(BlueprintCallable)
	static bool CycleCounterStop(double& Duration);
	UFUNCTION(BlueprintCallable)
	static bool CycleCounterSet(FName StatName);
	UFUNCTION(BlueprintCallable)
	static bool SimpleMillisecondCreate(FName StatName, FString StatDesc = "", double InScale = 1);
	UFUNCTION(BlueprintCallable)
	static bool SimpleMillisecondStart(FName StatName);
	UFUNCTION(BlueprintCallable)
	static bool SimpleMillisecondStop(FName StatName, double& Duration);
	UFUNCTION(BlueprintCallable)
	static bool Int64StatCreate(FName StatName, FString StatDesc = "", bool bCounter = true);
	UFUNCTION(BlueprintCallable)
	static bool Int64StatAdd(FName StatName, int64 Value);
	UFUNCTION(BlueprintCallable)
	static bool Int64StatSubtract(FName StatName, int64 Value);
	UFUNCTION(BlueprintCallable)
	static bool Int64StatSet(FName StatName, int64 Value);
	UFUNCTION(BlueprintCallable)
	static bool DoubleStatCreate(FName StatName, FString StatDesc = "");
	UFUNCTION(BlueprintCallable)
	static bool DoubleStatAdd(FName StatName, double Value);
	UFUNCTION(BlueprintCallable)
	static bool DoubleStatSubtract(FName StatName, double Value);
	UFUNCTION(BlueprintCallable)
	static bool DoubleStatSet(FName StatName, double Value);
	UFUNCTION(BlueprintCallable)
	static void FNameStatSet(FName StatName, FName Value);
	UFUNCTION(BlueprintCallable)
	static bool MemoryStatCreate(FName StatName, FString StatDesc = "");
	UFUNCTION(BlueprintCallable)
	static bool MemoryStatAdd(FName StatName, int64 Value);
	UFUNCTION(BlueprintCallable)
	static bool MemoryStatSubtract(FName StatName, int64 Value);
	UFUNCTION(BlueprintCallable)
	static bool MemoryStatSet(FName StatName, int64 Value);
	UFUNCTION(BlueprintCallable)
	static void AllCounterStop();

	UFUNCTION(BlueprintCallable)
	static FString GetDeviceProfileName();
	UFUNCTION(BlueprintCallable)
	static FString GetCPUInfo();
};
