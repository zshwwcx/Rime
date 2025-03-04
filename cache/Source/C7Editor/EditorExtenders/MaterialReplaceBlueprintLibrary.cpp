// Fill out your copyright notice in the Description page of Project Settings.

#include "MaterialReplaceBlueprintLibrary.h"

#include "EditorUtilityLibrary.h"
#include "ToolsLibrary.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Engine/Texture2DArray.h"
#include "Kismet/GameplayStatics.h"

void UMaterialReplaceBlueprintLibrary::ReplaceOne(const FString& InSrcMaterialPath, const FString& InDestMaterialPath, const FName& InTextureParameterName)
{

	UDataAsset* DA = LoadObject<UDataAsset>(nullptr, TEXT("/Script/C7Editor.MaterialReplaceProcessed'/Game/Editor/MaterialReplace/MRDataAsset.MRDataAsset'"));
	if(UMaterialReplaceProcessed* MaterialReplaceProcessed = Cast<UMaterialReplaceProcessed>(DA))
	{
		TArray<FString>& Processed = MaterialReplaceProcessed->Processed;
		if(Processed.Find(InSrcMaterialPath) == INDEX_NONE)
		{
			Processed.Add(InSrcMaterialPath);
			FToolsLibrary::ReplaceParentMaterial(InSrcMaterialPath, InDestMaterialPath, InTextureParameterName, DA);
		}
	}
}

void UMaterialReplaceBlueprintLibrary::SetTranslucencyPassToBefore(UMaterial* InMaterial)
{
	if(InMaterial->TranslucencyPass != MTP_BeforeDOF)
	{
		InMaterial->TranslucencyPass = MTP_BeforeDOF;
		InMaterial->MarkPackageDirty();

		// Update the material instance
		InMaterial->PreEditChange(nullptr);
		InMaterial->PostEditChange();
	}
}

void UMaterialReplaceBlueprintLibrary::OptimizeAllMaterialTranslucencyPass()
{
	FAssetRegistryModule& AssetRegistryModule = FModuleManager::GetModuleChecked<FAssetRegistryModule>("AssetRegistry");
	TMap<FString, TArray<FAssetData>> AssetDataMap;
	FARFilter Filter;
	Filter.bRecursivePaths = true;
	Filter.bRecursiveClasses = true;
	Filter.PackagePaths.Add("/Game");

	auto AddAssets = [&Filter, &AssetDataMap, &AssetRegistryModule](const UClass* ParentClass)
	{
		TArray<FAssetData> AssetData;
		Filter.ClassPaths.Empty();
		Filter.ClassPaths.Add(ParentClass->GetClassPathName());
		AssetRegistryModule.Get().GetAssets(Filter, AssetData);
		AssetDataMap.Add(ParentClass->GetName(), AssetData);
	};

	AddAssets(UMaterial::StaticClass());

	for(TMap<FString, TArray<FAssetData>>::TIterator ItrMap(AssetDataMap); ItrMap; ++ItrMap)
	{
		for (int32 i = 0; i < ItrMap.Value().Num(); ++i)
		{
			FString Path = ItrMap.Value()[i].GetObjectPathString();
			UObject* pObject = LoadObject<UObject>(nullptr, *Path);
			if (pObject)
			{
				if(UMaterial* Material = Cast<UMaterial>(pObject))
				{
					SetTranslucencyPassToBefore(Material);
				}
			}
		}
	}
}

void UMaterialReplaceBlueprintLibrary::TextureReplace()
{
	TArray<UObject*> SelectedAssets = UEditorUtilityLibrary::GetSelectedAssets();
	for(const auto Asset:SelectedAssets)
	{
		if(const UMaterialInstance* MaterialInstance = Cast<UMaterialInstance>(Asset))
		{
			UTexture* DArrayTexture;
			FName DArrayParameterName("D Array");
			MaterialInstance->GetTextureParameterValue(DArrayParameterName, DArrayTexture);

			UTexture* NRHArrayTexture;
			FName NRHArrayParameterName("NRH Array");
			MaterialInstance->GetTextureParameterValue(NRHArrayParameterName, NRHArrayTexture);

			UTexture2DArray* DArray = Cast<UTexture2DArray>(DArrayTexture);
			UTexture2DArray* NRHArray = Cast<UTexture2DArray>(NRHArrayTexture);
			if(DArray && NRHArray)
			{
				FToolsLibrary::ReplaceLandscapeTexture(DArray, NRHArray);
			}
		}
	}
}