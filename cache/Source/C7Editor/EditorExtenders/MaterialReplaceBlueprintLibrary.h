// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "MaterialReplaceBlueprintLibrary.generated.h"

UCLASS()
class UMaterialReplaceBlueprintLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

	UFUNCTION(BlueprintCallable, Category = "C7MaterialReplace")
	static void ReplaceOne(const FString& InSrcMaterialPath, const FString& InDestMaterialPath, const FName& InTextureParameterName);

	UFUNCTION(BlueprintCallable, Category = "C7MaterialReplace")
	static void SetTranslucencyPassToBefore(UMaterial* InMaterial);

	
	UFUNCTION(BlueprintCallable, Category = "C7MaterialReplace")
	static void OptimizeAllMaterialTranslucencyPass();

	UFUNCTION(BlueprintCallable, Category = "C7MaterialReplace")
	static void TextureReplace();
};

UCLASS(BlueprintType, Blueprintable)
class UMaterialReplaceProcessed : public UDataAsset
{
	GENERATED_BODY()

public:
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	TArray<FString> Processed;
};
