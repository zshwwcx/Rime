#include "AkAudioVolume.h"
#include "Components/BrushComponent.h"
#include "Kismet/GameplayStatics.h"
#include "AkAudio/Classes/AkGameplayStatics.h"
#include "Character/BaseCharacter.h"
#include "GameFramework/Character.h"


AAkAudioVolume::AAkAudioVolume(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	static const FName ComponentName = TEXT("AkAudioComponent0");
	AkComponent = ObjectInitializer.CreateDefaultSubobject<UAkComponent>(this, ComponentName);
	//AkComponent->AttachToComponent(RootComponent, FAttachmentTransformRules::KeepRelativeTransform);
	//AddInstanceComponent(AkComponent);
	PrimaryActorTick.bCanEverTick = true;
}

void AAkAudioVolume::BeginPlay()
{
	Super::BeginPlay();

	GetBrushComponent()->OnComponentBeginOverlap.AddDynamic(this, &AAkAudioVolume::EnterOverLap);
	GetBrushComponent()->OnComponentEndOverlap.AddDynamic(this, &AAkAudioVolume::LeaveOverLap);

	if (AkComponent.IsValid())
	{
		AkComponent->PostAkEvent(AkEventEmitter, 0, FOnAkPostEventCallback(), TArray<FAkExternalSourceInfo>(), "");
	}

	GetWorldTimerManager().SetTimer(SpawnerHandle, this, &AAkAudioVolume::UpdateEmitterSlowly, 1.f, true);

	// 激活时强制更新碰撞信息以避免MainPlayer先于自己创建的情况
	GetBrushComponent()->UpdateOverlaps();
}

void AAkAudioVolume::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (const ACharacter* MainPlayerCharacter = UGameplayStatics::GetPlayerCharacter(GetWorld(), 0))
	{
		TArray<AActor*> OverlappingActors;
		GetBrushComponent()->GetOverlappingActors(OverlappingActors, ACharacter::StaticClass());
		for (const auto OverlappingActor : OverlappingActors)
		{
			if (ACharacter* OverlappingCharacter = Cast<ACharacter>(OverlappingActor))
			{
				if (OverlappingCharacter == MainPlayerCharacter)
				{
					LeaveOverLap(nullptr, OverlappingCharacter, nullptr, 0);
					break;
				}
			}
		}	
	}

	UBrushComponent* TheBrushComponent = GetBrushComponent();
	if(IsValid(TheBrushComponent))
	{
		if(TheBrushComponent->OnComponentBeginOverlap.IsBound())
		{
			TheBrushComponent->OnComponentBeginOverlap.RemoveDynamic(this, &AAkAudioVolume::EnterOverLap);
		}
		if(TheBrushComponent->OnComponentEndOverlap.IsBound())
		{
			TheBrushComponent->OnComponentEndOverlap.RemoveDynamic(this, &AAkAudioVolume::LeaveOverLap);
		}
	}

	if(SpawnerHandle.IsValid())
	{
		GetWorldTimerManager().ClearTimer(SpawnerHandle);
	}
	
	Super::EndPlay(EndPlayReason);
}

void AAkAudioVolume::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	if (bIsLazy)
	{
		SetActorTickEnabled(false);
	}
	else
	{
		CalculateDistanceAndSetRTPC();
	}
}

void AAkAudioVolume::UpdateEmitterSlowly()
{
	if (bIsLazy)
	{
		CalculateDistanceAndSetRTPC();
	}
	else
	{
		SetActorTickEnabled(true);
	}
}

void AAkAudioVolume::CalculateDistanceAndSetRTPC()
{
	const UWorld* World = GetWorld();
	if(!World)
	{
		return;
	}
	const ACharacter* MainPlayerCharacter = UGameplayStatics::GetPlayerCharacter(World, 0);
	if (!MainPlayerCharacter) return;

	const FVector PlayerPos = MainPlayerCharacter->GetActorLocation();
	GetBrushComponent()->GetClosestPointOnCollision(PlayerPos, ClosestPoint);
	const float Distance = FVector::Distance(ClosestPoint, PlayerPos);
	if (!RTPCParamName.IsEmpty() && AkComponent.IsValid())
	{
		AkComponent->SetRTPCValue(nullptr, FMath::Clamp(Distance, 0.f, MaxRangeFadeDistance), 0, RTPCParamName);
	}
	if (Distance > MaxRangeFadeDistance + 1000.f)
	{
		bIsLazy = true;
	}
	else
	{
		bIsLazy = false;
	}
}

void AAkAudioVolume::EnterOverLap(UPrimitiveComponent* OverlappedComp, AActor* Other, UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult)
{
	const ACharacter* MainPlayerCharacter = UGameplayStatics::GetPlayerCharacter(GetWorld(), 0);
	if (!MainPlayerCharacter) return;
	const ACharacter* OtherCharacter = Cast<ACharacter>(Other);
	if (!OtherCharacter) return;
	if (MainPlayerCharacter != OtherCharacter) return;

	for (int32 i = 0; i < StateGroups.Num(); ++i)
	{
		UAkGameplayStatics::SetState(nullptr, StateGroups[i].StateGroup, StateGroups[i].StateInside);
	}
}

void AAkAudioVolume::LeaveOverLap(UPrimitiveComponent* OverlappedComp, AActor* Other, UPrimitiveComponent* OtherComp, int32 OtherBodyIndex)
{
	const ACharacter* MainPlayerCharacter = UGameplayStatics::GetPlayerCharacter(GetWorld(), 0);
	if (!MainPlayerCharacter) return;
	const ACharacter* OtherCharacter = Cast<ACharacter>(Other);
	if (!OtherCharacter) return;
	if (MainPlayerCharacter != OtherCharacter) return;

	for (int32 i = 0; i < StateGroups.Num(); ++i)
	{
		UAkGameplayStatics::SetState(nullptr, StateGroups[i].StateGroup, StateGroups[i].StateOutside);
	}
}
