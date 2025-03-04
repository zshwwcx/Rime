// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "LuaGameMode.h"
#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "C7GameMode.generated.h"


UCLASS(minimalapi)
class AC7GameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	AC7GameMode();

	virtual bool CanServerTravel(const FString& URL, bool bAbsolute);

	virtual void GetSeamlessTravelActorList(bool bToTransition, TArray<AActor*>& ActorList);


	UFUNCTION(BlueprintImplementableEvent)
	TArray<AActor*> GetExtraSeamlessTravelActorList();

	/**
 * Handles reinitializing players that remained through a seamless level transition
 * called from C++ for players that finished loading after the server
 * @param C the Controller to handle
 */
	virtual void HandleSeamlessTravelPlayer(AController*& C);

	/** Handles initializing a seamless travel player, handles logic similar to InitNewPlayer */
	virtual void InitSeamlessTravelPlayer(AController* NewController);

	virtual void RestartPlayerAtPlayerStart(AController* NewPlayer, AActor* StartSpot);

	void UpdatePlayerStartPoint(AController* Player);


public:
	UPROPERTY(BlueprintReadWrite, Transient)
	uint32 bTravelReplacePlayer : 1;
};



