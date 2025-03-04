// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Templates/SharedPointer.h"
#include "EditorExtenders/C7NavmeshProcessor.h"

/**
 * C7Navmesh扩展
 */

class C7NavmeshExtend : public TSharedFromThis<C7NavmeshExtend>
{
public:
	C7NavmeshExtend();
	~C7NavmeshExtend();

	void OnStartupModule();

private:
	/** World instance we are currently representing/mirroring in the panel */
	TWeakObjectPtr<UWorld> CurrentWorld;

	UC7NavmeshProcessor* Processor;

	void RegisterNavCB(UWorld* InWorld);
	void UnRegisterNavCB(UWorld* InWorld);

protected:
	/** Broadcast event delegates */
	// 场景切换
	void OnMapChanged(UWorld* InWorld, EMapChangeType MapChangeType);

	// Nav变更
	//void OnNavGenFin(ANavigationData* NavData);
};
