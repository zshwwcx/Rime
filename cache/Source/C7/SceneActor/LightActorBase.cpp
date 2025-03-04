#include "LightActorBase.h"

ALightActorBase::ALightActorBase()
{
	PrimaryActorTick.bCanEverTick = true;
}

void ALightActorBase::BeginPlay()
{
	Super::BeginPlay();
	LightActorInit();
}