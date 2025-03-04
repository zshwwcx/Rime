#pragma once

#include "CoreMinimal.h"

class FKGAssetDeduplicate
{
public:
	static void StartupModule();
	static void ShutdownModule();
private:
	static void RegisterMenus();
	static TSharedRef<class SDockTab> OnSpawnPluginTab(const class FSpawnTabArgs& SpawnTabArgs);
};
