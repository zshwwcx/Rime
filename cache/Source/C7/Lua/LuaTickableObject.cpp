// Fill out your copyright notice in the Description page of Project Settings.


#include "Lua/LuaTickableObject.h"


DECLARE_CYCLE_STAT(TEXT("LuaTickable Tick"), STAT_LuaTickableTick, STATGROUP_Game);


void ULuaTickableObject::Tick(float DeltaTime)
{
	SCOPE_CYCLE_COUNTER(STAT_LuaTickableTick);
	if (UWorld* World = GetWorld())
	{
		timeSeconds = World->GetTimeSeconds();
		realTimeSeconds = World->GetRealTimeSeconds();
	}
	OnLuaTick.ExecuteIfBound(DeltaTime,timeSeconds,realTimeSeconds);
}

TStatId ULuaTickableObject::GetStatId() const
{
	return GetStatID();
}
