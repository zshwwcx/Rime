// Fill out your copyright notice in the Description page of Project Settings.


#include "C7ExecuteAllTextureDuplicateGuid.h"

#include "ToolsLibrary.h"
#include "AssetRegistry/AssetRegistryModule.h"

UC7ExecuteAllTextureDuplicateGuidCommandlet::UC7ExecuteAllTextureDuplicateGuidCommandlet()
{
}

int32 UC7ExecuteAllTextureDuplicateGuidCommandlet::Main(const FString& InCommandline)
{
	UE_LOG(LogTemp, Display, TEXT("C7ExecuteAllTextureDuplicateGuid Start Load All Assets!"))
	FAssetRegistryModule& AssetRegistryModule = FModuleManager::GetModuleChecked<FAssetRegistryModule>("AssetRegistry");
	AssetRegistryModule.Get().SearchAllAssets(/*bSynchronousSearch =*/true);
	UE_LOG(LogTemp, Display, TEXT("C7ExecuteAllTextureDuplicateGuid Finish Load All Assets!"))
	FToolsLibrary::ExecuteAllDuplicateGuid(true);
	return 0;
}
