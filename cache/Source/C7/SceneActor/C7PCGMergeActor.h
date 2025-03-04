// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "C7PCGMergeActor.generated.h"

USTRUCT(BlueprintType)
struct FPCGComponentInfo
{
	GENERATED_BODY()

	FPCGComponentInfo() {};

	FPCGComponentInfo(const FTransform& InTransform, bool InState)	:
		Transform(InTransform),
		bIsValid(InState)
	{}

	UPROPERTY(VisibleAnywhere)
	FTransform Transform;

	UPROPERTY(VisibleAnywhere)
	bool bIsValid = false;
};

UCLASS(BlueprintType, Blueprintable)
class C7_API AC7PCGMergeActor : public AActor
{
	GENERATED_BODY()
	
public:	
	// Sets default values for this actor's properties
	AC7PCGMergeActor();

protected:
	// Called when the game starts or when spawned
	virtual void BeginPlay() override;

public:	
	// Called every frame
	virtual void Tick(float DeltaTime) override;

	void SplitActorPOIToStaticMesh();

	void CopyComponentProperty(class UActorComponent* SourceComponent, class UActorComponent* TargetComponent, class AActor* SourceActor);

	void RestoreComponents();

#if WITH_EDITOR
	virtual bool ShouldTickIfViewportsOnly()const override
	{
		return true;
	}
	virtual void PostEditChangeChainProperty(FPropertyChangedChainEvent& PropertyChangedEvent) override;
#endif

	UPROPERTY(BlueprintReadWrite, EditAnywhere)
	class UBoxComponent* BoxComponent;

#if WITH_EDITORONLY_DATA
	UPROPERTY(VisibleAnywhere)
	TArray<AActor*> ReferenceActors;

	UPROPERTY(VisibleAnywhere)
	TMap<FName, FPCGComponentInfo> CachedComponentInfo;

	UPROPERTY(VisibleAnywhere)
	TSubclassOf<AC7PCGMergeActor> ClassType;

	UPROPERTY(VisibleAnywhere)
	FString FolderName;

	UPROPERTY(BlueprintReadWrite, EditAnywhere)
	bool bToggleBPSplit;
#endif
};



