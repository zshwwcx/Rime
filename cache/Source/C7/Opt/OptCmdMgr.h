
#pragma once

#include "CoreMinimal.h"
#include "Containers/Array.h"
#include "Containers/Map.h"
#include "Containers/UnrealString.h"
#include "CoreTypes.h"
#include "HAL/CriticalSection.h"
#include <EngineGlobals.h>
#include <Runtime/Engine/Classes/Engine/Engine.h>
#include <Runtime/Engine/Public/EngineUtils.h>

DECLARE_LOG_CATEGORY_EXTERN(LogOptCmd, Log, All)

class C7_API FOptHelper
{
public:
	static UWorld* GetGameWorld();
	static bool MaybeIsMat(class UMaterialInterface* Mat, const FString& MatName);
	static FString MakeMeshKey(class UStaticMeshComponent* Comp);
	static FString GetTab(int Depth);
	static void DumpWidgetTree(class UWidget* Widget, int Depth);
	
	template<typename T>
	static T* GetActor(UWorld* World) 
	{
		for(TActorIterator<T> It(World); It; ++It)
		{
			AActor* One = *It;
			if(One->GetWorld() == World)
			{
				return (T*)One;
			}
		}
		
		return nullptr;
	}

	static void PostLoadMap(UWorld* World);
	static void DumpConsoleValue(const TCHAR* ConsoleName);
};