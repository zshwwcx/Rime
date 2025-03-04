// Copyright Epic Games, Inc. All Rights Reserved.

#include "C7.h"

#include "Blueprint/UserWidget.h"
#include "Modules/ModuleManager.h"

IMPLEMENT_PRIMARY_GAME_MODULE(FDefaultGameModuleImpl, C7, "C7");


void FC7Module::StartupModule()
{
#if WITH_EDITOR
#else
#if defined(C7_ENABLE_ASAN) || defined(__SANITIZE_ADDRESS__) || USING_ADDRESS_SANITISER
	UE_LOG(LogTemp, Log, TEXT("ASan. Enabled=1"));	
#else
	UE_LOG(LogTemp, Log, TEXT("ASan. Enabled=0"));		
#endif
#endif
}

void FC7Module::ShutdownModule()
{

}