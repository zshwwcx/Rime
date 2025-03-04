// Fill out your copyright notice in the Description page of Project Settings.


#include "LODMaterialEditor/LODMaterialHelper.h"
#include <AssetTools.h>
#include <AnimationEditorUtils.h>
#include <Materials/MaterialInstanceConstant.h>
#include <Factories/MaterialInstanceConstantFactoryNew.h>
#include "AssetRegistry/AssetRegistryModule.h"
#include "Engine/StaticMesh.h"
#include "MeshDescription.h"
#include "StaticMeshAttributes.h"
#include "Engine/Texture2DArray.h"
#include "Rendering/SkeletalMeshRenderData.h"


UMaterialInterface* ULODMaterialHelper::CreateLodMaterial(FString suffix, UMaterialInterface* LodMaterialParent, UMaterialInstance* ParamMaterialInstance)
{
	FString DefaultSuffix = suffix.IsEmpty() ? TEXT("_LOD") : suffix;
	auto Object = LodMaterialParent->GetMaterial();
	UMaterialInterface* CreatedMaterialInterface = nullptr;
	if (Object && ParamMaterialInstance != nullptr)
	{
		// Create an appropriate and unique name 
		FString Name;
		FString PackageName;
		CreateUniqueAssetName(ParamMaterialInstance->GetOutermost()->GetName(), DefaultSuffix, PackageName, Name);

		UMaterialInstanceConstantFactoryNew* Factory = NewObject<UMaterialInstanceConstantFactoryNew>();
		Factory->InitialParent = Object;

		UPackage* Package = CreatePackage(*PackageName);
		UMaterialInstanceConstant* CreatedMIC = Cast<UMaterialInstanceConstant>(Factory->FactoryCreateNew(UMaterialInstanceConstant::StaticClass(), Package, *Name, RF_Standalone | RF_Public, NULL, GWarn));
		CreatedMaterialInterface = CreatedMIC;


		TArray<FMaterialParameterInfo> ParameterInfos;
		TArray<FGuid> ParameterGuids;

		//texture
		CreatedMIC->GetAllParameterInfoOfType(EMaterialParameterType::Texture, ParameterInfos, ParameterGuids);
		for (FTextureParameterValue ReferenceTexture : ParamMaterialInstance->TextureParameterValues)
		{
			if (ReferenceTexture.ParameterValue)
			{
				for (int32 i = 0; i < ParameterInfos.Num(); ++i)
				{
					if (ParameterInfos[i].Name == ReferenceTexture.ParameterInfo.Name)
					{
						CreatedMIC->SetTextureParameterValueEditorOnly(ParameterInfos[i], ReferenceTexture.ParameterValue);
						break;
					}
				}
			}
		}
		ParameterInfos.Empty();
		ParameterGuids.Empty();

		//vector
		CreatedMIC->GetAllParameterInfoOfType(EMaterialParameterType::Vector, ParameterInfos, ParameterGuids);
		for (FVectorParameterValue ReferenceVector : ParamMaterialInstance->VectorParameterValues)
		{
			for (int32 i = 0; i < ParameterInfos.Num(); ++i)
			{
				if (ParameterInfos[i].Name == ReferenceVector.ParameterInfo.Name)
				{
					CreatedMIC->SetVectorParameterValueEditorOnly(ParameterInfos[i], ReferenceVector.ParameterValue);
					break;
				}
			}
		}
		ParameterInfos.Empty();
		ParameterGuids.Empty();

		//scalar
		CreatedMIC->GetAllParameterInfoOfType(EMaterialParameterType::Scalar, ParameterInfos, ParameterGuids);
		for (FScalarParameterValue ReferenceScalar : ParamMaterialInstance->ScalarParameterValues)
		{
			for (int32 i = 0; i < ParameterInfos.Num(); ++i)
			{
				if (ParameterInfos[i].Name == ReferenceScalar.ParameterInfo.Name)
				{
					CreatedMIC->SetScalarParameterValueEditorOnly(ParameterInfos[i], ReferenceScalar.ParameterValue);
					break;
				}
			}
		}
		ParameterInfos.Empty();
		ParameterGuids.Empty();

		//static switch
		CreatedMIC->GetAllParameterInfoOfType(EMaterialParameterType::StaticSwitch, ParameterInfos, ParameterGuids);
		TArray<FMaterialParameterInfo> StaticSwitchParameterInfos;
		TArray<FGuid> StaticSwitchParameterGuids;
		ParamMaterialInstance->GetAllStaticSwitchParameterInfo(StaticSwitchParameterInfos, StaticSwitchParameterGuids);
		for (FMaterialParameterInfo StaticSwitchParamInfo : StaticSwitchParameterInfos)
		{
			for (int32 i = 0; i < ParameterInfos.Num(); ++i)
			{
				if (ParameterInfos[i].Name == StaticSwitchParamInfo.Name)
				{
					bool targetValue;
					FGuid targetGuid;
					if (ParamMaterialInstance->GetStaticSwitchParameterValue(StaticSwitchParamInfo, targetValue, targetGuid)) {
						CreatedMIC->SetStaticSwitchParameterValueEditorOnly(ParameterInfos[i], targetValue);
					}
					break;
				}
			}
		}
		ParameterInfos.Empty();
		ParameterGuids.Empty();

		//there is no set static component mask parametervalue???, abandon
		//CreatedMIC->GetAllParameterInfoOfType(EMaterialParameterType::StaticComponentMask, ParameterInfos, ParameterGuids);
		//TArray<FMaterialParameterInfo> StaticComponentMaskParameterInfos;
		//TArray<FGuid> StaticComponentMaskParameterGuids;
		//ParamMaterialInstance->GetAllStaticComponentMaskParameterInfo(StaticComponentMaskParameterInfos, StaticComponentMaskParameterGuids);
		//for (FMaterialParameterInfo StaticComponentMaskParamInfo : StaticComponentMaskParameterInfos)
		//{
		//	for (int32 i = 0; i < ParameterInfos.Num(); ++i)
		//	{
		//		if (ParameterInfos[i].Name == StaticComponentMaskParamInfo.Name)
		//		{
		//			bool R,G,B,A;
		//			FGuid targetGuid;
		//			if (ParamMaterialInstance->GetStaticComponentMaskParameterValue(StaticComponentMaskParamInfo, R,G,B,A, targetGuid)) {
		//				//CreatedMIC->SetStaticcComponentMaskParameterValueEditorOnly(ParameterInfos[i], R,G,B,A);
		//			}
		//			break;
		//		}
		//	}
		//}
		//ParameterInfos.Empty();
		//ParameterGuids.Empty();

		//General
		CreatedMIC->PhysMaterial = ParamMaterialInstance->PhysMaterial;

		//lightmass setting no need

		//material property override
		CreatedMIC->BasePropertyOverrides = ParamMaterialInstance->BasePropertyOverrides;
		/*CreatedMIC->TwoSided = ParamMaterialInstance->IsTwoSided();
		CreatedMIC->OpacityMaskClipValue = ParamMaterialInstance->GetOpacityMaskClipValue();
		CreatedMIC->BlendMode = ParamMaterialInstance->GetBlendMode();
		CreatedMIC->ShadingModels = ParamMaterialInstance->GetShadingModels();
		CreatedMIC->DitheredLODTransition = ParamMaterialInstance->IsDitheredLODTransition();
		CreatedMIC->bOutputTranslucentVelocity = ParamMaterialInstance->bOutputTranslucentVelocity;
		CreatedMIC->NaniteOverrideMaterial = ParamMaterialInstance->NaniteOverrideMaterial;*/

		CreatedMaterialInterface->PostEditChange();
		// Notify the asset registry
		FAssetRegistryModule::AssetCreated(CreatedMaterialInterface);

		Package->SetDirtyFlag(true);

		CreatedMaterialInterface->ForceRecompileForRendering();
	}
	return CreatedMaterialInterface;
}

void ULODMaterialHelper::UpdateLodMaterial(UMaterialInterface* LodMaterialParent, UMaterialInstance* ParamMaterialInstance, UMaterialInstanceConstant* MIC)
{
	if (LodMaterialParent!=nullptr && ParamMaterialInstance != nullptr && MIC != nullptr)
	{
		MIC->SetParentEditorOnly(LodMaterialParent);

		TArray<FMaterialParameterInfo> ParameterInfos;
		TArray<FGuid> ParameterGuids;

		//texture
		MIC->GetAllParameterInfoOfType(EMaterialParameterType::Texture, ParameterInfos, ParameterGuids);
		for (FTextureParameterValue ReferenceTexture : ParamMaterialInstance->TextureParameterValues)
		{
			if (ReferenceTexture.ParameterValue)
			{
				for (int32 i = 0; i < ParameterInfos.Num(); ++i)
				{
					if (ParameterInfos[i].Name == ReferenceTexture.ParameterInfo.Name)
					{
						MIC->SetTextureParameterValueEditorOnly(ParameterInfos[i], ReferenceTexture.ParameterValue);
						break;
					}
				}
			}
		}
		ParameterInfos.Empty();
		ParameterGuids.Empty();

		//vector
		MIC->GetAllParameterInfoOfType(EMaterialParameterType::Vector, ParameterInfos, ParameterGuids);
		for (FVectorParameterValue ReferenceVector : ParamMaterialInstance->VectorParameterValues)
		{
			for (int32 i = 0; i < ParameterInfos.Num(); ++i)
			{
				if (ParameterInfos[i].Name == ReferenceVector.ParameterInfo.Name)
				{
					MIC->SetVectorParameterValueEditorOnly(ParameterInfos[i], ReferenceVector.ParameterValue);
					break;
				}
			}
		}
		ParameterInfos.Empty();
		ParameterGuids.Empty();

		//scalar
		MIC->GetAllParameterInfoOfType(EMaterialParameterType::Scalar, ParameterInfos, ParameterGuids);
		for (FScalarParameterValue ReferenceScalar : ParamMaterialInstance->ScalarParameterValues)
		{
			for (int32 i = 0; i < ParameterInfos.Num(); ++i)
			{
				if (ParameterInfos[i].Name == ReferenceScalar.ParameterInfo.Name)
				{
					MIC->SetScalarParameterValueEditorOnly(ParameterInfos[i], ReferenceScalar.ParameterValue);
					break;
				}
			}
		}
		ParameterInfos.Empty();
		ParameterGuids.Empty();

		//static switch
		MIC->GetAllParameterInfoOfType(EMaterialParameterType::StaticSwitch, ParameterInfos, ParameterGuids);
		TArray<FMaterialParameterInfo> StaticSwitchParameterInfos;
		TArray<FGuid> StaticSwitchParameterGuids;
		ParamMaterialInstance->GetAllStaticSwitchParameterInfo(StaticSwitchParameterInfos, StaticSwitchParameterGuids);
		for (FMaterialParameterInfo StaticSwitchParamInfo : StaticSwitchParameterInfos)
		{
			for (int32 i = 0; i < ParameterInfos.Num(); ++i)
			{
				if (ParameterInfos[i].Name == StaticSwitchParamInfo.Name)
				{
					bool targetValue;
					FGuid targetGuid;
					if (ParamMaterialInstance->GetStaticSwitchParameterValue(StaticSwitchParamInfo, targetValue, targetGuid)) {
						MIC->SetStaticSwitchParameterValueEditorOnly(ParameterInfos[i], targetValue);
					}
					break;
				}
			}
		}
		ParameterInfos.Empty();
		ParameterGuids.Empty();

		//there is no set static component mask parametervalue???, abandon
		//CreatedMIC->GetAllParameterInfoOfType(EMaterialParameterType::StaticComponentMask, ParameterInfos, ParameterGuids);
		//TArray<FMaterialParameterInfo> StaticComponentMaskParameterInfos;
		//TArray<FGuid> StaticComponentMaskParameterGuids;
		//ParamMaterialInstance->GetAllStaticComponentMaskParameterInfo(StaticComponentMaskParameterInfos, StaticComponentMaskParameterGuids);
		//for (FMaterialParameterInfo StaticComponentMaskParamInfo : StaticComponentMaskParameterInfos)
		//{
		//	for (int32 i = 0; i < ParameterInfos.Num(); ++i)
		//	{
		//		if (ParameterInfos[i].Name == StaticComponentMaskParamInfo.Name)
		//		{
		//			bool R,G,B,A;
		//			FGuid targetGuid;
		//			if (ParamMaterialInstance->GetStaticComponentMaskParameterValue(StaticComponentMaskParamInfo, R,G,B,A, targetGuid)) {
		//				//CreatedMIC->SetStaticcComponentMaskParameterValueEditorOnly(ParameterInfos[i], R,G,B,A);
		//			}
		//			break;
		//		}
		//	}
		//}
		//ParameterInfos.Empty();
		//ParameterGuids.Empty();

		//General
		MIC->PhysMaterial = ParamMaterialInstance->PhysMaterial;

		//lightmass setting no need

		//material property override
		MIC->BasePropertyOverrides = ParamMaterialInstance->BasePropertyOverrides;
		/*CreatedMIC->TwoSided = ParamMaterialInstance->IsTwoSided();
		CreatedMIC->OpacityMaskClipValue = ParamMaterialInstance->GetOpacityMaskClipValue();
		CreatedMIC->BlendMode = ParamMaterialInstance->GetBlendMode();
		CreatedMIC->ShadingModels = ParamMaterialInstance->GetShadingModels();
		CreatedMIC->DitheredLODTransition = ParamMaterialInstance->IsDitheredLODTransition();
		CreatedMIC->bOutputTranslucentVelocity = ParamMaterialInstance->bOutputTranslucentVelocity;
		CreatedMIC->NaniteOverrideMaterial = ParamMaterialInstance->NaniteOverrideMaterial;*/

		MIC->PostEditChange();
		MIC->MarkPackageDirty();
		MIC->ForceRecompileForRendering();
	}
}

bool ULODMaterialHelper::SetMeshLodSectionMaterialIndex(int32 LODIndex, UStaticMesh* StaticMeshAsset, TArray<int32> StaticMaterialIndexArray)
{
	if (!StaticMeshAsset)
	{
		return false;
	}

#if WITH_EDITOR
	if (StaticMeshAsset->IsSourceModelValid(LODIndex) == false)
	{
		return false;
	}

	FMeshSectionInfoMap& SectionInfoMap = StaticMeshAsset->GetSectionInfoMap();
	int32 NumSections = SectionInfoMap.GetSectionNumber(LODIndex);

	int32 MaterialIndexArrayIndex = 0;
	for (int32 SectionIndex = 0; SectionIndex < NumSections; ++SectionIndex)
	{
		if (SectionInfoMap.IsValidSection(LODIndex, SectionIndex)) 
		{
			FMeshSectionInfo SectionInfo = SectionInfoMap.Get(LODIndex, SectionIndex);
			if (StaticMaterialIndexArray.Num() > MaterialIndexArrayIndex && StaticMeshAsset->GetStaticMaterials().IsValidIndex(MaterialIndexArrayIndex))
			{
				SectionInfo.MaterialIndex = StaticMaterialIndexArray[MaterialIndexArrayIndex];
				StaticMeshAsset->GetSectionInfoMap().Set(LODIndex, SectionIndex, SectionInfo);
				StaticMeshAsset->GetOriginalSectionInfoMap().Set(LODIndex, SectionIndex, SectionInfo);
				UE_LOG(LogTemp, Warning, TEXT("LODHelper:: SetSectionInfoMap(lodIndex = %d,sectionIndex = %d),materialIndex = %d"), LODIndex, SectionIndex, SectionInfo.MaterialIndex);
				MaterialIndexArrayIndex++;
			}
		}
	}
	StaticMeshAsset->MarkPackageDirty();

	return true;
#else
	return false
#endif
}

bool ULODMaterialHelper::SetSkeletalMeshLodSectionMaterialIndex(int32 LODIndex, USkeletalMesh* SkeletalMeshAsset, TArray<int32> StaticMaterialIndexArray)
{
	if (!SkeletalMeshAsset)
	{
		return false;
	}

#if WITH_EDITOR
	if (!SkeletalMeshAsset->GetImportedModel())
	{
		return false;
	}

	if (!SkeletalMeshAsset->IsValidLODIndex(LODIndex))
	{
		return false;
	}

	int NumSections = SkeletalMeshAsset->GetResourceForRendering()->LODRenderData[LODIndex].RenderSections.Num();

	int32 MaterialIndexArrayIndex = 0;
	auto LODMaterialMap = SkeletalMeshAsset->GetLODInfo(LODIndex)->LODMaterialMap;
	LODMaterialMap.Reset();
	for (int32 SectionIndex = 0; SectionIndex < NumSections; ++SectionIndex)
	{
		int MaterialIndex = StaticMaterialIndexArray[MaterialIndexArrayIndex];
		if (StaticMaterialIndexArray.Num() > MaterialIndexArrayIndex && SkeletalMeshAsset->IsValidMaterialIndex(MaterialIndex))
		{
			SkeletalMeshAsset->GetLODInfo(LODIndex)->LODMaterialMap.Add(MaterialIndex);
			SkeletalMeshAsset->GetResourceForRendering()->LODRenderData[LODIndex].RenderSections[SectionIndex].MaterialIndex = MaterialIndex;
			UE_LOG(LogTemp, Warning, TEXT("LODHelper:: SetSkeletMeshLODRenderData.RenderSection(lodIndex = %d,sectionIndex = %d),materialIndex = %d"), LODIndex, SectionIndex, MaterialIndex);
			MaterialIndexArrayIndex++;
		}
	}
	SkeletalMeshAsset->ValidateAllLodMaterialIndexes();
	SkeletalMeshAsset->MarkPackageDirty();

	return true;
#else
	return false
#endif
}

TArray<int32> ULODMaterialHelper::GetSkeletalMeshSectionMaterials(USkeletalMesh* SkeletalMeshAsset, int32 LODIndex)
{
	TArray<int32> MaterialArray;
	MaterialArray.Empty();
	if(SkeletalMeshAsset->IsValidLODIndex(LODIndex))
	{
		int NumSections = SkeletalMeshAsset->GetResourceForRendering()->LODRenderData[LODIndex].RenderSections.Num();
		for (int32 SectionIndex = 0; SectionIndex < NumSections; ++SectionIndex)
		{
			MaterialArray.Add(SkeletalMeshAsset->GetResourceForRendering()->LODRenderData[LODIndex].RenderSections[SectionIndex].MaterialIndex);
		}
	}
	return MaterialArray;
}

void ULODMaterialHelper::MakeMeshDirty(UStaticMesh* StaticMeshAsset) 
{
	StaticMeshAsset->MarkPackageDirty();
}

void ULODMaterialHelper::MakeSkeletalMeshDirty(USkeletalMesh* SkeletalMeshAsset)
{
	SkeletalMeshAsset->MarkPackageDirty();
}

bool ULODMaterialHelper::SetMaterialInstanceScalarParameterEditor(UMaterialInstanceConstant* MIC, FString ParameterName, float Value)
{
	if (MIC == nullptr) {
		return false;
	}
	TArray<FMaterialParameterInfo> ParameterInfos;
	TArray<FGuid> ParameterGuids;
	MIC->GetAllParameterInfoOfType(EMaterialParameterType::Scalar, ParameterInfos, ParameterGuids);
	for (int32 i = 0; i < ParameterInfos.Num(); ++i)
	{
		if (ParameterInfos[i].Name == ParameterName)
		{
			MIC->SetScalarParameterValueEditorOnly(ParameterInfos[i], Value);
			MIC->PostEditChange();
			MIC->MarkPackageDirty();
			return true;
		}
	}
	return false;
}

bool ULODMaterialHelper::SetMaterialInstanceVectorParameterEditor(UMaterialInstanceConstant* MIC, FString ParameterName, FLinearColor LinearColor)
{
	if (MIC == nullptr) {
		return false;
	}
	TArray<FMaterialParameterInfo> ParameterInfos;
	TArray<FGuid> ParameterGuids;
	MIC->GetAllParameterInfoOfType(EMaterialParameterType::Vector, ParameterInfos, ParameterGuids);
	for (int32 i = 0; i < ParameterInfos.Num(); ++i)
	{
		if (ParameterInfos[i].Name == ParameterName)
		{
			MIC->SetVectorParameterValueEditorOnly(ParameterInfos[i], LinearColor);
			MIC->PostEditChange();
			MIC->MarkPackageDirty();
			return true;
		}
	}
	return false;
}

bool ULODMaterialHelper::ForceUpdateTexture2DArray(UTexture2DArray* Tex2DArray)
{
	return Tex2DArray->UpdateSourceFromSourceTextures(false);
}

void ULODMaterialHelper::CreateUniqueAssetName(const FString& InBasePackageName, const FString& InSuffix, FString& OutPackageName, FString& OutAssetName)
{
	FAssetToolsModule& AssetToolsModule = FModuleManager::Get().LoadModuleChecked<FAssetToolsModule>("AssetTools");
	AssetToolsModule.Get().CreateUniqueAssetName(InBasePackageName, InSuffix, OutPackageName, OutAssetName);
}
