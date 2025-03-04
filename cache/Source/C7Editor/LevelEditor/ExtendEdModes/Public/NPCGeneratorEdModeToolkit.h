#pragma once

#include "Toolkits/BaseToolkit.h"
#include "NPCGeneratorEdMode.h"
#include "SNPCGeneratorEdModeWidget.h"
#include "EditorModeManager.h"

class FNPCGeneratorEdModeToolkit: public FModeToolkit
{
public:

	FNPCGeneratorEdModeToolkit()
	{
		SAssignNew(NPCGeneratorEdModeWidget, SNPCGeneratorEdModeWidget);
	}

	virtual FName GetToolkitFName() const override { return FName("NPCGeneratorEdMode"); }
	virtual FText GetBaseToolkitName() const override { return NSLOCTEXT("BuilderModeToolkit", "DisplayName", "Builder"); }
	virtual class FEdMode* GetEditorMode() const override { return GLevelEditorModeTools().GetActiveMode(FNPCGeneratorEdMode::EM_NPCGenerator); }
	virtual TSharedPtr<class SWidget> GetInlineContent() const override { return NPCGeneratorEdModeWidget; }

private:
	TSharedPtr<SNPCGeneratorEdModeWidget> NPCGeneratorEdModeWidget;
};
