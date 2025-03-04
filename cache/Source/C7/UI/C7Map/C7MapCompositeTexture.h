// Fill out your copyright notice in the Description page of Project Settings.
#pragma once

#include "Engine/CanvasRenderTarget2D.h"
#include "C7MapCompositeTexture.generated.h"

///@brief Class for merging multiple textures into one to reduce texture samples and simplify shaders.
///Layers can be changed at any time, however after changing them UpdateResource must be called to finalize the changes.
UCLASS(Blueprintable)
class UC7MapCompositeTexture : public UCanvasRenderTarget2D
{
	GENERATED_BODY()

	UC7MapCompositeTexture();

	UFUNCTION(BlueprintCallable)
	void PerformMerge(UCanvas* Canvas, int32 Width, int32 Height);

public:

	///@brief Texture layers
	UPROPERTY(EditAnywhere, Category = "Textrues")
	TArray<UTexture2D*> Textures;
	
	UPROPERTY(EditAnywhere, Category = "Textrues")
	FVector2D TextureSizeEach;

	UPROPERTY(EditAnywhere, Category = "Textrues")
	int8 RowNum;

	UPROPERTY(EditAnywhere, Category = "Textrues")
	int8 ColumnNum;

	// TSharedPtr<FStreamableHandle> StreamingHandle;
	// TArray<FSoftObjectPath>& LoadPaths;
	
	///@brief Tint applied to texture layers
	// UPROPERTY(EditAnywhere, Category = "Layers")
	// TArray<FColor> LayerTints;

	///@brief Creates a layered texture and updates it based on the passed in layers.
	UFUNCTION(BlueprintCallable)
	static UC7MapCompositeTexture* Create(UObject* WorldContextObject, const TArray<UTexture2D*>&InTextures,const FVector2D& InTextureSize,int32 InRowNum,int32 InColumnNum);

	UFUNCTION(BlueprintCallable)
	void Update(const TArray<UTexture2D*>& InTextures,const FVector2D& InTextureSize,int32 InRowNum,int32 InColumnNum);

	///@brief Creates a layered texture and updates it like the other version. Also applies tint to layers.
	// static UC7MapCompositeTexture* Create(UObject* WorldContextObject, const TArray<UTexture2D*>& Layers, const TArray<FColor>& LayerTints);

	virtual uint32 CalcTextureMemorySizeEnum(ETextureMipCount Enum) const override;
	
	// static UC7MapCompositeTexture* Update(UObject* WorldContextObject, const TArray<UTexture2D*>& Textures, const TArray<FColor>& LayerTints);
};
