// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "Misc/C7GameInstance.h"
#include "C7Hud.generated.h"

/**
 * 
 */
UCLASS()
class C7_API AC7Hud : public AHUD
{
	GENERATED_BODY()

public:
	/** Overridable native event for when play begins for this actor. */
	virtual void BeginPlay()
	{
		Super::BeginPlay();

		//UC7GameInstanceSubsystem* TmpGI = UC7GameInstanceSubsystem::GetGIS(this);
		//check(TmpGI);
		//TmpGI->OnInit();
	}

	
};
