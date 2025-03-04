#include "LevelEditorViewExtend.h"
#include "Modules/ModuleManager.h"
#include "Editor.h"
#include "KGSceneEditorModule.h"
#include "GamePlayEditorModeHandler.h"
#include "EditorProxy/LevelLuaEditorProxy.h"

#define LOCTEXT_NAMESPACE "LevelEditorViewExtend"

FLevelEditorViewExtend::FLevelEditorViewExtend()
{
}

FLevelEditorViewExtend::~FLevelEditorViewExtend()
{
}

void FLevelEditorViewExtend::OnStartupModule()
{
}

void FLevelEditorViewExtend::OnShutdownModule()
{
}

FLevelLuaEditorProxy* FLevelEditorViewExtend::GetLevelLuaEditorProxy()
{
	if (FKGSceneEditorModule::Get().GamePlayEditorModeHandler.IsValid())
	{
		return FKGSceneEditorModule::Get().GamePlayEditorModeHandler->GetLevelLuaEditorProxy();
	}
	return nullptr;
}

#undef LOCTEXT_NAMESPACE
