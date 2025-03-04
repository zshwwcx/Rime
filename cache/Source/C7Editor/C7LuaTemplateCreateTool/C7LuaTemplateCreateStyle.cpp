// Copyright Epic Games, Inc. All Rights Reserved.

#include "C7LuaTemplateCreateStyle.h"
#include "Styling/SlateStyleRegistry.h"
#include "Framework/Application/SlateApplication.h"
#include "Slate/SlateGameResources.h"
#include "Styling/SlateStyleMacros.h"

#define RootToContentDir Style->RootToContentDir

TSharedPtr<FSlateStyleSet> FC7LuaTemplateCreateStyle::StyleInstance = nullptr;

void FC7LuaTemplateCreateStyle::Initialize()
{
	if (!StyleInstance.IsValid())
	{
		StyleInstance = Create();
		FSlateStyleRegistry::RegisterSlateStyle(*StyleInstance);
	}
}

void FC7LuaTemplateCreateStyle::Shutdown()
{
	FSlateStyleRegistry::UnRegisterSlateStyle(*StyleInstance);
	ensure(StyleInstance.IsUnique());
	StyleInstance.Reset();
}

FName FC7LuaTemplateCreateStyle::GetStyleSetName()
{
	static FName StyleSetName(TEXT("C7LuaTemplateCreateStyle"));
	return StyleSetName;
}

const FVector2D Icon20x20(20.0f, 20.0f);

TSharedRef< FSlateStyleSet > FC7LuaTemplateCreateStyle::Create()
{
	TSharedRef< FSlateStyleSet > Style = MakeShareable(new FSlateStyleSet("C7LuaTemplateCreateStyle"));

	Style->SetContentRoot( FPaths::EngineContentDir() / TEXT("Editor/Slate") );
	Style->Set("C7LuaTemplateCreate.OpenPluginWindow", new IMAGE_BRUSH(TEXT("Icons/wrench_16x"), Icon20x20));

	return Style;
}

void FC7LuaTemplateCreateStyle::ReloadTextures()
{
	if (FSlateApplication::IsInitialized())
	{
		FSlateApplication::Get().GetRenderer()->ReloadTextureResources();
	}
}

const ISlateStyle& FC7LuaTemplateCreateStyle::Get()
{
	return *StyleInstance;
}
