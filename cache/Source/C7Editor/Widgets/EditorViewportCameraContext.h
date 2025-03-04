// Copyright 2021 T, Inc. All Rights Reserved.
#pragma once

#include "CoreMinimal.h"
#include "EditorViewportCameraContext.generated.h"

UCLASS()
class UEditorViewportCameraMenuContext : public UObject
{
	GENERATED_BODY()
public:

	TWeakPtr<const class SEditorViewportCameraMenu> EditorViewporCameraMenu;
};
