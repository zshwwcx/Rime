#pragma once

#include "C7Editor/IC7EditorModuleInterface.h"

class NPCGeneratorEdModeTool : public IC7EditorModuleListenerInterface
{
public:
	virtual void OnStartupModule() override;
	virtual void OnShutdownModule() override;

	virtual ~NPCGeneratorEdModeTool() {}

private:
	static TSharedPtr< class FSlateStyleSet > StyleSet;

	void RegisterStyleSet();
	void UnregisterStyleSet();

	void RegisterEditorMode();
	void UnregisterEditorMode();
};