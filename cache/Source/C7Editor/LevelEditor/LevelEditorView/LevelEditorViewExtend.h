#pragma once

#include "CoreMinimal.h"
#include "Templates/SharedPointer.h"
#include "UObject/ObjectMacros.h"

class FToolBarBuilder;

class FLevelEditorViewExtend
	: public TSharedFromThis<FLevelEditorViewExtend>
{
public:
	FLevelEditorViewExtend();
	virtual ~FLevelEditorViewExtend();

public:
	void OnStartupModule();
	void OnShutdownModule();

	class FLevelLuaEditorProxy* GetLevelLuaEditorProxy();
};
