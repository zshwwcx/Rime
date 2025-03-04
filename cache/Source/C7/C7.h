// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "Modules/ModuleManager.h"


class FC7Module : public IModuleInterface
{
public:
	//~BEGIN: IModuleInterface interface
	virtual void StartupModule() override;
	virtual void ShutdownModule() override;
	//~END: IModuleInterface interface

};
