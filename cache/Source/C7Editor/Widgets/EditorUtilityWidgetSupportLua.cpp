// Fill out your copyright notice in the Description page of Project Settings.


#include "Widgets/EditorUtilityWidgetSupportLua.h"
#include "Modules/ModuleManager.h"
#include "C7Editor.h"
#include "DoraSDK.h"
#include "KGLua.h"

void UEditorUtilityWidgetSupportLua::NativeConstruct()
{
	InitLuaEnvironment();
	
	Super::NativeConstruct();
}

void UEditorUtilityWidgetSupportLua::NativeDestruct()
{
	Super::NativeDestruct();

	UnInitLuaEnvironment();
}

void UEditorUtilityWidgetSupportLua::InitLuaEnvironment()
{
	if (KGLuaPtr == nullptr)
	{
		KGLuaPtr = new FKGEditorLua();
		KGLuaPtr->CreateLuaStateWithoutWorld();
	}
}


void UEditorUtilityWidgetSupportLua::UnInitLuaEnvironment()
{
	if (KGLuaPtr)
	{
		KGLuaPtr->CloseLuaState();
		delete KGLuaPtr;
		KGLuaPtr = nullptr;
	}
}
