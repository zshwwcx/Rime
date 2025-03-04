// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "OptSceneObserver.generated.h"

UCLASS()
class C7_API AOptSceneObserver : public AActor
{
	GENERATED_BODY()
	
public:	
	// Sets default values for this actor's properties
	AOptSceneObserver();

protected:
	// Called when the game starts or when spawned
	virtual void BeginPlay() override;

public:	
	// Called every frame
	virtual void Tick(float DeltaTime) override;

	UPROPERTY(EditAnywhere)
	TMap<FString, TSoftObjectPtr<AActor>> ActorMaps;	

	UPROPERTY(EditAnywhere)
	TArray<TSoftObjectPtr<AActor>> ActorList;	
};
