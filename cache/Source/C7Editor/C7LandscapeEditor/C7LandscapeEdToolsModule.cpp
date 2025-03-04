// Copyright KuaiShou Games, Inc. All Rights Reserved.
// Author: liubo11@kuaishou.com

#include "C7LandscapeEdToolsModule.h"

#include "AssetToolsModule.h"
#include "CoreTypes.h"
#include "ContentBrowserModule.h"
#include "EditorAssetLibrary.h"
#include "Engine.h"
#include "IContentBrowserSingleton.h"
#include "ILandscapeEdToolsModule.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "UObject/SavePackage.h"

// IMPLEMENT_MODULE( FC7LandscapeEdToolsModule, LandscapeEdToolsModule);

UObject* FKgLandscapeEdToolsModule::CreateAsset(UClass* ObjClass, const FString& PackageFullPath)
{
	const FAssetToolsModule& AssetToolsModule = FModuleManager::LoadModuleChecked<FAssetToolsModule>("AssetTools");
	FString UniquePackageName;
	FString UniqueAssetName;
	AssetToolsModule.Get().CreateUniqueAssetName(PackageFullPath, TEXT(""), UniquePackageName, UniqueAssetName);

	if (UniquePackageName.EndsWith(UniqueAssetName))
	{
		UniquePackageName = UniquePackageName.LeftChop(UniqueAssetName.Len() + 1);
	}

	// PackagePath指的是Package所在的目录；
	// PackageName = UniquePackageName / UniqueAssetName
	UObject* NewObj = Cast<UObject>(AssetToolsModule.Get().CreateAsset(UniqueAssetName, UniquePackageName, ObjClass, nullptr));
	
	SaveAsset(NewObj);
		
	return NewObj;
}

void FKgLandscapeEdToolsModule::SaveAsset(UObject* NewTexture)
{
	if(!NewTexture)
	{
		return;
	}
	
	TArray<UObject*> Assets = { NewTexture };
	{
		UEditorAssetLibrary::SaveLoadedAssets(Assets, false);
		auto AssetsToSync = Assets;
		FAssetRegistryModule& AssetRegistry = FModuleManager::Get().LoadModuleChecked<FAssetRegistryModule>("AssetRegistry");
		int32 AssetCount = AssetsToSync.Num();
		for (int32 AssetIndex = 0; AssetIndex < AssetCount; AssetIndex++)
		{
			AssetRegistry.AssetCreated(AssetsToSync[AssetIndex]);
				
			if(!IsRunningCommandlet())
			{
				GEditor->BroadcastObjectReimported(AssetsToSync[AssetIndex]);					
			}
		}

		if(!IsRunningCommandlet())
		{
			//Also notify the content browser that the new assets exists
			FContentBrowserModule& ContentBrowserModule = FModuleManager::Get().LoadModuleChecked<FContentBrowserModule>("ContentBrowser");
			ContentBrowserModule.Get().SyncBrowserToAssets(AssetsToSync, true);				
		}
	}	
}

UObject* FKgLandscapeEdToolsModule::SaveAssetAs(UObject* OldAsset, const FString& PackageName)
{
	if(!OldAsset)
	{
		return nullptr;
	}

	const FAssetToolsModule& AssetToolsModule = FModuleManager::LoadModuleChecked<FAssetToolsModule>("AssetTools");
	FString UniquePackageName;
	FString UniqueAssetName;
	AssetToolsModule.Get().CreateUniqueAssetName(PackageName, TEXT(""), UniquePackageName, UniqueAssetName);

	if (UniquePackageName.EndsWith(UniqueAssetName))
	{
		UniquePackageName = UniquePackageName.LeftChop(UniqueAssetName.Len() + 1);
	}
	UObject* DuplicatedObject = AssetToolsModule.Get().DuplicateAsset(UniqueAssetName, UniquePackageName, OldAsset);
	
	return DuplicatedObject;
}
