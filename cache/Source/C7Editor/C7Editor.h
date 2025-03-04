#pragma once

#include "CoreMinimal.h"
#include "ComponentVisualizer.h"
#include "EditorExtenders/ContentMenuExtender.h"
#include "Templates/UniquePtr.h"
#include "UObject/ObjectSaveContext.h"
#include "C7Editor/IC7EditorModuleInterface.h"


class FC7EditorModule : public IC7EditorModuleInterface
{
public: 
	//~BEGIN: IModuleInterface interface
	virtual void StartupModule() override;
	virtual void ShutdownModule() override;
	//~END: IModuleInterface interface

	FC7EditorModule();
	~FC7EditorModule();

private:
	void PreScanBlueprintAsset();

public:
	virtual void AddModuleListeners() override;

	static inline FC7EditorModule& Get()
	{
		return FModuleManager::LoadModuleChecked< FC7EditorModule >("C7Editor");
	}

#pragma region SplitBP
	void AddLevelViewportMenuExtender(FName ModuleName);
	void RemoveLevelViewportMenuExtender();

	TSharedRef<FExtender> GetLevelViewportContextMenuExtender(const TSharedRef<FUICommandList> CommandList, const TArray<AActor*> InActors);

	void SplitBPToSeperatedActor(const TArray<AActor*> InActors);
	void RestoreSeperatedActorToBP(const TArray<AActor*> InActors);

	FDelegateHandle ModuleLoadedDelegateHandle;
	FDelegateHandle LevelViewportExtenderHandle;
#pragma endregion SplitBP

	void OnLevelSwitchStart(UWorld* InWorld, const FString& LevelName);

private:
	TSharedPtr<FContentMenuExtender> ContentMenuExtender;

	// Graph node factory
	TSharedPtr<struct FGraphPanelNodeFactory> LevelFlowGraphNodeFactory;

	TSharedPtr<struct FGraphPanelNodeFactory> EpisodeGraphNodeFactory;

	TSharedPtr<class FMVVMExtend> MVVMExtend;

	TSharedPtr<class C7NavmeshExtend> NavmeshExtend;

	TSharedPtr<class FC7LuaTemplateCreate> LuaTemplateCreate;
public:
	//场景编辑器视图操作扩展
	TSharedPtr<class FLevelEditorViewExtend> LevelEditorViewExtend;

	// LevelFlowEditorContainer
	TSharedPtr<class FLevelFlowEditorContainer> LevelFlowEditorContainer;

	// Editor信息上报
	TSharedPtr<class FEditorTracker> EditorTracker;


#pragma region UnLua
public:
	void TryStartUnLua();

	void TryFinishUnLua();

	void GetLuaEnvConflictedEditorNum(int& EditingNum, int& UnSavedNum);
	
	void TryCloseLuaEnvConflictedEditors();

public:
	int32 UnLuaRefrenceCount = 0;

#pragma endregion UnLua

#pragma region CutScene
private:
	FDelegateHandle MovieSceneQTETrackEditorHandler;
	FDelegateHandle MovieSceneCustomTrackEditorHandler;
#pragma endregion CutScene
};
