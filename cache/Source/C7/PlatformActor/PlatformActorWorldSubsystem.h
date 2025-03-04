// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "Subsystems/WorldSubsystem.h"
#include "PlatformActorWorldSubsystem.generated.h"

/**
 * World subsystem that for Actor Platform.
 */
UCLASS()
class UPlatformActorWorldSubsystem : public UTickableWorldSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	void OnScalabilitySettingsChanged(const Scalability::FQualityLevels& QualityLevels);
	void OnActorRegistered(AActor& Actor);
	virtual TStatId GetStatId() const override
    {
    	RETURN_QUICK_DECLARE_CYCLE_STAT(UPlatformActorWorldSubsystem, STATGROUP_Tickables);
    }
    
	virtual void Tick(float DeltaTime) override;
	virtual bool IsTickable() const override;

#if WITH_EDITOR
	void OnActorPlatformPostChanged(AActor& Actor);
	void OnPreviewPlatformChanged();
#endif

	static void EnableActor(AActor* Actor, bool bIsEnabled);

protected:
	TArray<TWeakObjectPtr<AActor>> PlatformActors;
};
