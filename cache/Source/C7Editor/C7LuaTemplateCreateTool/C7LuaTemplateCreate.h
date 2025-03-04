// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"

class FC7LuaTemplateCreate: public TSharedFromThis<FC7LuaTemplateCreate>
{
public:
	FC7LuaTemplateCreate();
	~FC7LuaTemplateCreate();

public:
	void OnStartupModule();
	void OnShutdownModule();

private:
	void RegisterMenus();
	void PluginButtonClicked();
	TSharedRef<class SDockTab> OnSpawnPluginTab(const class FSpawnTabArgs& SpawnTabArgs);
private:
	TSharedPtr<class FUICommandList> PluginCommands;
};
