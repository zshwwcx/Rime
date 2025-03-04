// Copyright Epic Games, Inc. All Rights Reserved.

#include "PlatformActorWorldSubsystem.h"

#include "Components/LightComponent.h"
#include "Engine/PostProcessVolume.h"
#include "Engine/World.h"
#include "GameFramework/ActorPlatformSetUtilities.h"

#define LOCTEXT_NAMESPACE "PlatformActorWorldSubsystem"

void UPlatformActorWorldSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	
	Scalability::OnScalabilitySettingsChanged.AddUObject(this, &UPlatformActorWorldSubsystem::OnScalabilitySettingsChanged);
	FActorPlatformSetUtilities::OnActorRegisteredEvent.AddUObject(this, &UPlatformActorWorldSubsystem::OnActorRegistered);
#if WITH_EDITOR
	FActorPlatformSetUtilities::OnActorPlatformPostChangedEvent.AddUObject(this, &UPlatformActorWorldSubsystem::OnActorPlatformPostChanged);
	if (GEditor)
	{
		UEditorEngine* EditorEngine = CastChecked<UEditorEngine>(GEngine);
		EditorEngine->OnPreviewPlatformChanged().AddUObject(this, &UPlatformActorWorldSubsystem::OnPreviewPlatformChanged);
	}
#endif
}

void UPlatformActorWorldSubsystem::Deinitialize()
{
#if WITH_EDITOR
	FActorPlatformSetUtilities::OnActorPlatformPostChangedEvent.RemoveAll(this);
	if (GEditor)
	{
		UEditorEngine* EditorEngine = CastChecked<UEditorEngine>(GEngine);
		EditorEngine->OnPreviewPlatformChanged().RemoveAll(this);
	}
#endif
	PlatformActors.Empty();
	FActorPlatformSetUtilities::OnActorRegisteredEvent.RemoveAll(this);
	Scalability::OnScalabilitySettingsChanged.RemoveAll(this);
	Super::Deinitialize();
}

void UPlatformActorWorldSubsystem::OnScalabilitySettingsChanged(const Scalability::FQualityLevels& QualityLevels)
{
	for(TWeakObjectPtr<AActor> Actor: PlatformActors)
	{
		if(Actor.IsValid())
		{
			EnableActor(Actor.Get(), Actor->Platforms.IsActive());
		}
	}
}

void UPlatformActorWorldSubsystem::EnableActor(AActor* Actor, bool bIsEnabled)
{
#if WITH_EDITOR
	const UWorld* World = Actor->GetWorld();
	if(World->WorldType == EWorldType::Editor)
	{
		Actor->SetIsTemporarilyHiddenInEditor(!bIsEnabled);
	}
	else
#endif
	{
		Actor->SetActorHiddenInGame(!bIsEnabled);
		Actor->SetActorEnableCollision(bIsEnabled);
		Actor->SetActorTickEnabled(bIsEnabled);
		if(APostProcessVolume* PostProcessVolume = Cast<APostProcessVolume>(Actor))
		{
			PostProcessVolume->bEnabled = bIsEnabled;
		}
		// else
		// {
		// 	TArray<ULightComponent*> ComponentArray;
		// 	Actor->GetComponents(ComponentArray);
		// 	for(ULightComponent* LightComponent: ComponentArray)
		// 	{
		// 		LightComponent->bAffectsWorld = bIsEnabled;
		// 	}
		// }
	}
}

void UPlatformActorWorldSubsystem::Tick(float DeltaTime)
{
#if WITH_EDITOR
	const UWorld* World = GetWorld();
	if(World->WorldType == EWorldType::Editor)
	{
		return;
	}
	for(TWeakObjectPtr<AActor> Actor: PlatformActors)
	{
		if(Actor.IsValid())
		{
			const bool bEnabled = Actor->Platforms.IsActive();
			if(Actor->IsHidden() == bEnabled)
			{
				UE_LOG(LogTemp, Warning, TEXT("Platform Actor Need Set To Active:%d, Actor Lable: %s"), bEnabled, *Actor->GetActorLabel())
				Actor->SetActorHiddenInGame(!bEnabled);
				Actor->SetActorEnableCollision(bEnabled);
				Actor->SetActorTickEnabled(bEnabled);
			}
		}
	}
#endif
}

bool UPlatformActorWorldSubsystem::IsTickable() const
{
#if WITH_EDITOR
	return true;
#else
	return false;
#endif
}

void UPlatformActorWorldSubsystem::OnActorRegistered(AActor& Actor)
{
	const UWorld* World = GetWorld();
	if(World && World == Actor.GetWorld())
	{
		EnableActor(&Actor, Actor.Platforms.IsActive());
		if(PlatformActors.Find(&Actor) == INDEX_NONE)
		{
			PlatformActors.Add(&Actor);
		}
	}
}

#if WITH_EDITOR
void UPlatformActorWorldSubsystem::OnActorPlatformPostChanged(AActor& Actor)
{
	const UWorld* World = GetWorld();
	if(World && World == Actor.GetWorld())
	{
		EnableActor(&Actor, Actor.Platforms.IsActive());
	}
	if(!FActorPlatformSetUtilities::IsValidPlatformProperty(&Actor.Platforms) && PlatformActors.Find(&Actor) != INDEX_NONE)
	{
		PlatformActors.Remove(&Actor);
	}
}

void UPlatformActorWorldSubsystem::OnPreviewPlatformChanged()
{
	for(TWeakObjectPtr<AActor> Actor: PlatformActors)
	{
		if(Actor.IsValid())
		{
			EnableActor(Actor.Get(), Actor->Platforms.IsActive());
		}
	}
}
#endif

#undef LOCTEXT_NAMESPACE
