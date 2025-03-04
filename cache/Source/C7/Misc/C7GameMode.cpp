// Copyright Epic Games, Inc. All Rights Reserved.

#include "C7GameMode.h"
#include "UObject/ConstructorHelpers.h"
#include "GameFramework/GameStateBase.h"
#include "GameFramework/GameSession.h"
#include "GameFramework/PlayerState.h"
#include "3C/Controller/BasePlayerController.h"


AC7GameMode::AC7GameMode()
	:bTravelReplacePlayer(false)
{
	// set default pawn class to our Blueprinted character
	//static ConstructorHelpers::FClassFinder<APawn> PlayerPawnBPClass(TEXT("/Game/Blueprint/3C/BP_Character"));
	//if (PlayerPawnBPClass.Class != NULL)
	//{
	//	DefaultPawnClass = PlayerPawnBPClass.Class;
	//}
}

bool AC7GameMode::CanServerTravel(const FString& FURL, bool bAbsolute)
{
	UWorld* World = GetWorld();

	check(World);

	// NOTE - This is a temp check while we work on a long term fix
	// There are a few issues with seamless travel using single process PIE, so we're disabling that for now while working on a fix
	if (World->WorldType == EWorldType::PIE && bUseSeamlessTravel && !FParse::Param(FCommandLine::Get(), TEXT("MultiprocessOSS")))
	{
		UE_LOG(LogGameMode, Warning, TEXT("CanServerTravel: Seamless travel currently NOT supported in single process PIE."));
		//return false;
	}

	if (FURL.Contains(TEXT("%")))
	{
		UE_LOG(LogGameMode, Error, TEXT("CanServerTravel: FURL %s Contains illegal character '%%'."), *FURL);
		return false;
	}

	if (FURL.Contains(TEXT(":")) || FURL.Contains(TEXT("\\")))
	{
		UE_LOG(LogGameMode, Error, TEXT("CanServerTravel: FURL %s blocked, contains : or \\"), *FURL);
		return false;
	}

	FString MapName;
	int32 OptionStart = FURL.Find(TEXT("?"));
	if (OptionStart == INDEX_NONE)
	{
		MapName = FURL;
	}
	else
	{
		MapName = FURL.Left(OptionStart);
	}

	// Check for invalid package names.
	FText InvalidPackageError;
	if (MapName.StartsWith(TEXT("/")) && !FPackageName::IsValidLongPackageName(MapName, true, &InvalidPackageError))
	{
		UE_LOG(LogGameMode, Log, TEXT("CanServerTravel: FURL %s blocked (%s)"), *FURL, *InvalidPackageError.ToString());
		return false;
	}

	return true;
}


void AC7GameMode::GetSeamlessTravelActorList(bool bToTransition, TArray<AActor*>& ActorList)
{
	//Super::GetSeamlessTravelActorList(bToTransition, ActorList);

	// Get allocations for the elements we're going to add handled in one go
	const int32 ActorsToAddCount = GameState->PlayerArray.Num() + (bToTransition ? 3 : 0);
	ActorList.Reserve(ActorsToAddCount);

	// Always keep PlayerStates, so that after we restart we can keep players on the same team, etc
	ActorList.Append(GameState->PlayerArray);

	ActorList.Add(this);
	ActorList.Add(GameState);
	ActorList.Add(GameSession);

	ActorList.Append(GetExtraSeamlessTravelActorList());

	if (bToTransition)
	{
		// Keep ourselves until we transition to the final destination
		
		// Keep general game state until we transition to the final destination
		//ActorList.Add(GameState);
		// Keep the game session state until we transition to the final destination
	//	ActorList.Add(GameSession);

		// If adding in this section best to increase the literal above for the ActorsToAddCount
	}
}



void AC7GameMode::HandleSeamlessTravelPlayer(AController*& C)
{
	// Default behavior is to spawn new controllers and copy data
	APlayerController* PC = Cast<APlayerController>(C);
	if (PC && PC->Player && bTravelReplacePlayer)
	{
		// We need to spawn a new PlayerController to replace the old one
		UClass* PCClassToSpawn = GetPlayerControllerClassToSpawnForSeamlessTravel(PC);
		APlayerController* const NewPC = SpawnPlayerControllerCommon(PC->IsLocalPlayerController() ? ROLE_SimulatedProxy : ROLE_AutonomousProxy, PC->GetFocalLocation(), PC->GetControlRotation(), PCClassToSpawn);
		if (NewPC)
		{
			PC->SeamlessTravelTo(NewPC);
			NewPC->SeamlessTravelFrom(PC);
			SwapPlayerControllers(PC, NewPC);
			PC = NewPC;
			C = NewPC;
		}
		else
		{
			UE_LOG(LogGameMode, Warning, TEXT("HandleSeamlessTravelPlayer: Failed to spawn new PlayerController for %s (old class %s)"), *PC->GetHumanReadableName(), *PC->GetClass()->GetName());
			PC->Destroy();
			return;
		}
	}

	InitSeamlessTravelPlayer(C);

	//// Initialize hud and other player details, shared with PostLogin
	GenericPlayerInitialization(C);

	if (PC)
	{
		// This may spawn the player pawn if the game is in progress
		HandleStartingNewPlayer(PC);
	}
}



void AC7GameMode::InitSeamlessTravelPlayer(AController* NewController)
{
	APlayerController* NewPC = Cast<APlayerController>(NewController);

	UpdatePlayerStartPoint(NewController);

	if (NewPC != nullptr)
	{
		NewPC->PostSeamlessTravel();
	}
}

void AC7GameMode::UpdatePlayerStartPoint(AController* Player)
{
	FVector SpawnLocation;
	FRotator SpawnRotation;

	ABasePlayerController* C = Cast<ABasePlayerController>(Player);
	check(C);
	C->GetSpawnPoint(SpawnLocation, SpawnRotation);
	SpawnRotation.Pitch = SpawnRotation.Roll = 0;

	Player->SetInitialLocationAndRotation(SpawnLocation, SpawnRotation);
}



void AC7GameMode::RestartPlayerAtPlayerStart(AController* NewPlayer, AActor* StartSpot)
{
	if (NewPlayer == nullptr || NewPlayer->IsPendingKillPending())
	{
		return;
	}

	if (!StartSpot)
	{
		UE_LOG(LogGameMode, Warning, TEXT("RestartPlayerAtPlayerStart: Player start not found"));
		return;
	}

	FRotator SpawnRotation = StartSpot->GetActorRotation();
	FVector SpawnLocation = StartSpot->GetActorLocation();

	UE_LOG(LogGameMode, Verbose, TEXT("RestartPlayerAtPlayerStart %s"), (NewPlayer && NewPlayer->PlayerState) ? *NewPlayer->PlayerState->GetPlayerName() : TEXT("Unknown"));

	if (MustSpectate(Cast<APlayerController>(NewPlayer)))
	{
		UE_LOG(LogGameMode, Verbose, TEXT("RestartPlayerAtPlayerStart: Tried to restart a spectator-only player!"));
		return;
	}

	if (NewPlayer->GetPawn() != nullptr)
	{
		// If we have an existing pawn, just use it's rotation
		SpawnRotation = NewPlayer->GetPawn()->GetActorRotation();
	}
	else if (GetDefaultPawnClassForController(NewPlayer) != nullptr)
	{
		// Try to create a pawn to use of the default class for this player
		APawn* NewPawn = SpawnDefaultPawnFor(NewPlayer, StartSpot);
		if (IsValid(NewPawn))
		{
			NewPlayer->SetPawn(NewPawn);
		}
	}

	if (!IsValid(NewPlayer->GetPawn()))
	{
		FailedToRestartPlayer(NewPlayer);
	}
	else
	{
		ABasePlayerController* C = Cast<ABasePlayerController>(NewPlayer);
		check(C);

		C->GetSpawnPoint(SpawnLocation, SpawnRotation);


		// Tell the start spot it was used
		InitStartSpot(StartSpot, NewPlayer);

		if (NewPlayer->GetPawn())
		{
			NewPlayer->GetPawn()->SetActorLocation(SpawnLocation);
		}

		FinishRestartPlayer(NewPlayer, SpawnRotation);
	}
}

