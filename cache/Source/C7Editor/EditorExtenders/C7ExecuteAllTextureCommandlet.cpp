#include "C7ExecuteAllTextureCommandlet.h"
#include "ToolsLibrary.h"
#include "Misc/FileHelper.h"
#include "Engine/AssetManager.h"

DEFINE_LOG_CATEGORY(LogC7ExecuteAllTextureCommandlet);

UC7ExecuteAllTextureCommandlet::UC7ExecuteAllTextureCommandlet()
{
}

int32 UC7ExecuteAllTextureCommandlet::Main(const FString& InCommandline)
{
	UE_LOG(LogTemp, Display, TEXT("C7ExecuteAllTextureCommandlet Start Load All Assets!"))
	FAssetRegistryModule& AssetRegistryModule = FModuleManager::GetModuleChecked<FAssetRegistryModule>("AssetRegistry");
	AssetRegistryModule.Get().SearchAllAssets(/*bSynchronousSearch =*/true);
	UE_LOG(LogTemp, Display, TEXT("C7ExecuteAllTextureCommandlet Finish Load All Assets!"))
	FToolsLibrary::ExecuteAllTexture(true, false);
	return 0;
}