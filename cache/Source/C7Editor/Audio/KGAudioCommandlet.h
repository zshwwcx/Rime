// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Commandlets/Commandlet.h"
#include "UObject/Object.h"
#include "KGAudioCommandlet.generated.h"

/**
 * 
 */
UCLASS()
class C7EDITOR_API UKGAudioCommandlet : public UCommandlet
{
	GENERATED_BODY()

public:
	virtual int32 Main(const FString& Params) override;

private:
	static void ProcessEventInfo(TArray<FString>& OutProblemEvents);
	static void ProcessBankInfo(TArray<FString>& OutProblemBanks);
	static void ProcessSkillDependingEvent();
	static void ProcessAnimDependingEvent();
};
