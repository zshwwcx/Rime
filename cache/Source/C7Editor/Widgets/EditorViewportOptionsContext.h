// Copyright 2021 T, Inc. All Rights Reserved.
#pragma once

#include "CoreMinimal.h"
#include "EditorViewportOptionsContext.generated.h"

UCLASS()
class UEditorViewportOptionsMenuContext : public UObject
{
	GENERATED_BODY()
public:

	TWeakPtr<const class SEditorViewportOptionsMenu> EditorViewportOptionsMenu;
};
