// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "LODMaterialHelper.generated.h"

/**
 * 
 */
UCLASS()
class C7EDITOR_API ULODMaterialHelper : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()
	
public:
	UFUNCTION(BlueprintCallable, Category = "LODMaterialHelper")
	static UMaterialInterface* CreateLodMaterial(FString suffix, UMaterialInterface* LodMaterialParent, UMaterialInstance* ParamMaterialInstance);

	UFUNCTION(BlueprintCallable, Category = "LODMaterialHelper")
	static void UpdateLodMaterial(UMaterialInterface* LodMaterialParent, UMaterialInstance* ParamMaterialInstance, UMaterialInstanceConstant* MIC);

	UFUNCTION(BlueprintCallable, Category = "LODMaterialHelper")
	static bool SetMeshLodSectionMaterialIndex(int32 LODIndex, UStaticMesh* StaticMeshAsset, TArray<int32> StaticMaterialIndexArray);

	UFUNCTION(BlueprintCallable, Category = "LODMaterialHelper")
	static bool SetSkeletalMeshLodSectionMaterialIndex(int32 LODIndex, USkeletalMesh* SkeletalMeshAsset, TArray<int32> StaticMaterialIndexArray);

	UFUNCTION(BlueprintCallable, Category = "LODMaterialHelper")
	static TArray<int32> GetSkeletalMeshSectionMaterials(USkeletalMesh* SkeletalMeshAsset, int32 LODIndex);

	UFUNCTION(BlueprintCallable, Category = "LODMaterialHelper")
	static void MakeMeshDirty(UStaticMesh* StaticMeshAsset);

	UFUNCTION(BlueprintCallable, Category = "LODMaterialHelper")
	static void MakeSkeletalMeshDirty(USkeletalMesh* SkeletalMeshAsset);

	UFUNCTION(BlueprintCallable, Category = "LODMaterialHelper")
	static bool SetMaterialInstanceScalarParameterEditor(UMaterialInstanceConstant* MIC, FString ScalarParameterName, float Value);

	UFUNCTION(BlueprintCallable, Category = "LODMaterialHelper")
	static bool SetMaterialInstanceVectorParameterEditor(UMaterialInstanceConstant* MIC, FString ParameterName, FLinearColor LinearColor);

	UFUNCTION(BlueprintCallable, Category = "LODMaterialHelper")
	static bool ForceUpdateTexture2DArray(UTexture2DArray* Tex2DArray);

private:
	static void CreateUniqueAssetName(const FString& InBasePackageName, const FString& InSuffix, FString& OutPackageName, FString& OutAssetName);
};
