// Fill out your copyright notice in the Description page of Project Settings.


#include "Opt/OptSceneObserver.h"

#include "OptCmdMgr.h"
#include "Internationalization/Regex.h"


static void OptSceneSetVisibile(const TArray<FString>& Args, bool b)
{
	auto World = FOptHelper::GetGameWorld();
	if(World == nullptr)
	{
		return;
	}
	AOptSceneObserver* OptSceneObserver = FOptHelper::GetActor<AOptSceneObserver>(World);
	if(!OptSceneObserver)
	{
		return;
	}
        
	if(Args.Num() == 1)
	{
		TSoftObjectPtr<AActor> Ptr;
		const FRegexPattern Pattern("^[0-9]+$");
		FRegexMatcher Matcher(Pattern, Args[0]);
		if(Matcher.FindNext())
		{
			int Idx = FCString::Atoi(*Args[0]);
			if(Idx >= 0 && Idx < OptSceneObserver->ActorList.Num())
			{
				Ptr = OptSceneObserver->ActorList[Idx];
			}
		}
		else
		{
			Ptr = OptSceneObserver->ActorMaps.FindRef(Args[0]);
		}

		if(Ptr.Get())
		{
			Ptr.Get()->SetActorHiddenInGame(!b);
		}
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("Invalide Command"));	
	}    
}

FAutoConsoleCommand OptSceneHide(TEXT("opt.scene.hide"), TEXT("opt.scene.hide"),
    FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
    {
    	OptSceneSetVisibile(Args, false);
    }));
FAutoConsoleCommand OptSceneShow(TEXT("opt.scene.show"), TEXT("opt.scene.show"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		OptSceneSetVisibile(Args, true);
	}));


// Sets default values
AOptSceneObserver::AOptSceneObserver()
{
 	// Set this actor to call Tick() every frame.  You can turn this off to improve performance if you don't need it.
	PrimaryActorTick.bCanEverTick = false;

}

// Called when the game starts or when spawned
void AOptSceneObserver::BeginPlay()
{
	Super::BeginPlay();
	
}

// Called every frame
void AOptSceneObserver::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);

}

