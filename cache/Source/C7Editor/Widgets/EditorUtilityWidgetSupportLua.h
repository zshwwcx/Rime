// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "EditorUtilityWidget.h"
#include "EditorUtilityWidgetSupportLua.generated.h"

/**
 * 
 */
UCLASS()
class C7EDITOR_API UEditorUtilityWidgetSupportLua : public UEditorUtilityWidget
{
	GENERATED_BODY()
	
protected:
	virtual void NativeConstruct() override;
	virtual void NativeDestruct() override;

	void InitLuaEnvironment();
	void UnInitLuaEnvironment();
	class FKGEditorLua* KGLuaPtr = nullptr;
};
