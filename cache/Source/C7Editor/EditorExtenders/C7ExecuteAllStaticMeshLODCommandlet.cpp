// Fill out your copyright notice in the Description page of Project Settings.


#include "C7ExecuteAllStaticMeshLODCommandlet.h"

#include "ToolsLibrary.h"
#include "AssetRegistry/AssetRegistryModule.h"

int32 UC7ExecuteAllStaticMeshLODCommandlet::Main(const FString& InCommandline)
{
	TArray<FString> Tokens;
	TArray<FString> InSwitches;
	TMap<FString, FString> ParamsMap;
	ParseCommandLine(*InCommandline, Tokens, InSwitches, ParamsMap);

	if(!ParamsMap.Find("Path"))
	{
		UE_LOG(LogTemp, Error, TEXT("Missing Path argument"));
	}
	
	UE_LOG(LogTemp, Display, TEXT("UC7ExecuteAllStaticMeshLODCommandlet Start Load All Assets!"))
	FAssetRegistryModule& AssetRegistryModule = FModuleManager::GetModuleChecked<FAssetRegistryModule>("AssetRegistry");
	AssetRegistryModule.Get().SearchAllAssets(/*bSynchronousSearch =*/true);
	UE_LOG(LogTemp, Display, TEXT("UC7ExecuteAllStaticMeshLODCommandlet Finish Load All Assets!"))
	
	FToolsLibrary::ExecuteAllStaticMeshLOD(ParamsMap["Path"], true);
	return 0;
}
