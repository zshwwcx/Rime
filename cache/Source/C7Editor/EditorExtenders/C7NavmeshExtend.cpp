// Fill out your copyright notice in the Description page of Project Settings.

#include "EditorExtenders/C7NavmeshExtend.h"
#include "LevelEditor.h"
#include <NavigationSystem.h>

#pragma optimize("", off)

C7NavmeshExtend::C7NavmeshExtend()
{
	CurrentWorld = nullptr;
	Processor = nullptr;
}

C7NavmeshExtend::~C7NavmeshExtend()
{
	CurrentWorld = nullptr;
	Processor = nullptr;
}

void C7NavmeshExtend::OnStartupModule()
{
	FLevelEditorModule& LevelEditorModule = FModuleManager::LoadModuleChecked<FLevelEditorModule>("LevelEditor");
	LevelEditorModule.OnMapChanged().AddSP(this, &C7NavmeshExtend::OnMapChanged);
}

void C7NavmeshExtend::RegisterNavCB(UWorld* InWorld)
{
	if (InWorld != nullptr) {
		UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(InWorld);

		if (NavSys) {
			if (!IsValid(Processor)) {
				Processor = NewObject<UC7NavmeshProcessor>();
				Processor->AddToRoot();
			}

			if (NavSys->IsInitialized() == false)
			{
				NavSys->OnNavigationInitDone.AddUObject(Processor, &UC7NavmeshProcessor::OnNavigationInitDone);
			}
			else
			{
				NavSys->OnNavigationGenerationFinishedDelegate.AddUniqueDynamic(Processor, &UC7NavmeshProcessor::OnNavGenFin);
			}
		}
	}
}

void C7NavmeshExtend::UnRegisterNavCB(UWorld* InWorld)
{
	if (InWorld != nullptr) {
		UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(InWorld);

		if (NavSys) {
			if (IsValid(Processor)) {
				NavSys->OnNavigationGenerationFinishedDelegate.RemoveAll(Processor);

				Processor->RemoveFromRoot();
			}
		}
	}
	Processor = nullptr;
}

void C7NavmeshExtend::OnMapChanged(UWorld* InWorld, EMapChangeType MapChangeType)
{
	if (InWorld != CurrentWorld) {
		CurrentWorld = InWorld;
	}

	if (MapChangeType == EMapChangeType::LoadMap) {
		// 开启新Nav监听
		RegisterNavCB(InWorld);
	}
	else if (MapChangeType == EMapChangeType::TearDownWorld) {
		// 结束旧Nav监听
		UnRegisterNavCB(InWorld);
	}
}

#pragma optimize("", on)