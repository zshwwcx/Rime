// Copyright Epic Games, Inc. All Rights Reserved.

#include "C7LuaTemplateCreateCommands.h"

#define LOCTEXT_NAMESPACE "FC7LuaTemplateCreateModule"

void FC7LuaTemplateCreateCommands::RegisterCommands()
{
	UI_COMMAND(OpenPluginWindow, "C7LuaTemplateCreate", "Create Lua Template File", EUserInterfaceActionType::Button, FInputChord());
}

#undef LOCTEXT_NAMESPACE
