// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "C7LuaTemplateCreateStyle.h"
#include "Framework/Commands/Commands.h"

class FC7LuaTemplateCreateCommands : public TCommands<FC7LuaTemplateCreateCommands>
{
public:

	FC7LuaTemplateCreateCommands()
		: TCommands<FC7LuaTemplateCreateCommands>(TEXT("C7LuaTemplateCreate"), NSLOCTEXT("Contexts", "C7LuaTemplateCreate", "Lua Template Create Plugin"), NAME_None, FC7LuaTemplateCreateStyle::GetStyleSetName())
	{
	}

	// TCommands<> interface
	virtual void RegisterCommands() override;

public:
	TSharedPtr< FUICommandInfo > OpenPluginWindow;
};