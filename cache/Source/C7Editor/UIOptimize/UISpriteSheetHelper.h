// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include <AssetRegistry/AssetRegistryModule.h>
#include <FileHelpers.h>
#include <UMG.h>
#include <Blueprint/UserWidget.h>
#include "UISpriteSheetHelper.generated.h"

/**
 * 
 */
UCLASS()
class C7EDITOR_API UUISpriteSheetHelper : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()
	
public:
	UFUNCTION(BlueprintCallable, Category = "UIOptimize")
	static void WidgetImageReplaceToSprite(UBlueprint* Blueprint, const FString& endWith);

	UFUNCTION(BlueprintCallable, Category = "UIOptimize")
	static void ExportSelectedImage();

	UFUNCTION(BlueprintCallable, Category = "UIOptimize")
	static TArray<UWidgetBlueprint*> GetSelectedWidget();

	UFUNCTION(BlueprintCallable, Category = "UIOptimize")
	static void	RunSpriteSheetPacking(const FString& TPLocation, const FString& FolderPath, const FString& SpriteSheetPath, const FString& AltasName);

	UFUNCTION(BlueprintCallable, Category = "UIOptimize")
	static FString OpenAndReadDirectory();

private:
	static bool SetSpriteBrush(FSlateBrush& brush, const FString& endWith);

	static FAssetData GetAssertByName(const FName imageName, const FString& endWith);

};
