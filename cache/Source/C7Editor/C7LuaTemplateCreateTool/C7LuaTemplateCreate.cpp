// Fill out your copyright notice in the Description page of Project Settings.

#include "C7LuaTemplateCreateTool/C7LuaTemplateCreate.h"

#include "C7LuaTemplateCreateCommands.h"
#include "C7LuaTemplateCreateStyle.h"
#include "C7LuaTemplateCreateWidget.h"
#include "DesktopPlatformModule.h"
#include "IDesktopPlatform.h"
#include "Widgets/Layout/SGridPanel.h"

static const FName C7LuaTemplateCreateTabName("C7LuaTemplateCreate");
#define LOCTEXT_NAMESPACE "FC7LuaTemplateCreate"

FC7LuaTemplateCreate::FC7LuaTemplateCreate()
{
}

FC7LuaTemplateCreate::~FC7LuaTemplateCreate()
{
}

void FC7LuaTemplateCreate::OnStartupModule()
{
	FC7LuaTemplateCreateStyle::Initialize();
	FC7LuaTemplateCreateStyle::ReloadTextures();

	FC7LuaTemplateCreateCommands::Register();
	PluginCommands = MakeShareable(new FUICommandList);

	PluginCommands->MapAction(
		FC7LuaTemplateCreateCommands::Get().OpenPluginWindow,
		FExecuteAction::CreateRaw(this, &FC7LuaTemplateCreate::PluginButtonClicked),
		FCanExecuteAction());

	UToolMenus::RegisterStartupCallback(
		FSimpleMulticastDelegate::FDelegate::CreateRaw(this, &FC7LuaTemplateCreate::RegisterMenus));
	FGlobalTabmanager::Get()->RegisterNomadTabSpawner(C7LuaTemplateCreateTabName,
	                                                  FOnSpawnTab::CreateRaw(
		                                                  this, &FC7LuaTemplateCreate::OnSpawnPluginTab))
	                        .SetDisplayName(LOCTEXT("FC7LuaTemplateCreateTabTitle", "C7LuaTemplateCreate"))
	                        .SetMenuType(ETabSpawnerMenuType::Hidden);
}

void FC7LuaTemplateCreate::OnShutdownModule()
{
	UToolMenus::UnRegisterStartupCallback(this);
	UToolMenus::UnregisterOwner(this);
	FC7LuaTemplateCreateStyle::Shutdown();
	FC7LuaTemplateCreateCommands::Unregister();
	FGlobalTabmanager::Get()->UnregisterNomadTabSpawner(C7LuaTemplateCreateTabName);
}

void FC7LuaTemplateCreate::RegisterMenus()
{
	FToolMenuOwnerScoped OwnerScoped(this);
	{
		UToolMenu* Menu = UToolMenus::Get()->ExtendMenu("LevelEditor.MainMenu.Window");
		{
			FToolMenuSection& Section = Menu->FindOrAddSection("C7LuaTemplateCreateWindowLayout");
			Section.AddMenuEntryWithCommandList(FC7LuaTemplateCreateCommands::Get().OpenPluginWindow, PluginCommands);
		}
	}
}

void FC7LuaTemplateCreate::PluginButtonClicked()
{
	FGlobalTabmanager::Get()->TryInvokeTab(C7LuaTemplateCreateTabName);
}


TSharedRef<SDockTab> FC7LuaTemplateCreate::OnSpawnPluginTab(const FSpawnTabArgs& SpawnTabArgs)
{
	return SNew(SDockTab)
		.TabRole(ETabRole::NomadTab)
		[
			SNew(SC7LuaTemplateCreateWidget)
		];
}

#undef LOCTEXT_NAMESPACE