#pragma once

#include "CoreMinimal.h"
#include "LuaOverriderInterface.h"
#include "Engine/TriggerVolume.h"
#include "AkComponent.h"
#include "AkAudioEvent.h"
#include "AkAudioVolume.generated.h"


USTRUCT(BlueprintType)
struct FStateGroup
{
	GENERATED_USTRUCT_BODY()

public:
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FName StateGroup;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FName StateInside;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FName StateOutside;
};

UCLASS(BlueprintType, Blueprintable)
class C7_API AAkAudioVolume : public ATriggerVolume
{
	GENERATED_BODY()

public:
	AAkAudioVolume(const FObjectInitializer& ObjectInitializer);

	virtual void Tick(float DeltaSeconds) override;

	void UpdateEmitterSlowly();

	void CalculateDistanceAndSetRTPC();

protected:
	//EnterOverLap
	UFUNCTION()
	virtual void EnterOverLap(UPrimitiveComponent* OverlappedComp, AActor* Other, UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult);

	//LeaveOverLap
	UFUNCTION()
	void LeaveOverLap(UPrimitiveComponent* OverlappedComp, AActor* Other, UPrimitiveComponent* OtherComp, int32 OtherBodyIndex);

	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	TWeakObjectPtr<UAkComponent> AkComponent;

	FVector ClosestPoint;

	bool bIsLazy;
	
	FTimerHandle SpawnerHandle;

public:
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	UAkAudioEvent* AkEventEmitter = nullptr;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TArray<FStateGroup> StateGroups;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FString RTPCParamName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	float MaxRangeFadeDistance;
};

