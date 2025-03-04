// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "UIRoot.generated.h"


class UCanvasPanel;

DECLARE_DYNAMIC_DELEGATE_TwoParams(FOnViewportResized, int32, ResX, int32, ResY);

/**
 * 
 */
UCLASS()
class C7_API UUIRoot : public UUserWidget
{
	GENERATED_BODY()
	

public:

	UFUNCTION()
	bool Init();

	UFUNCTION()
	void DontAutoRemoveWithWorld();

	UFUNCTION()
	UCanvasPanel* CreateCanvas(int32 Layer);
	UFUNCTION()
	bool RemoveCanvas(int32 Layer);
	UFUNCTION()
	bool MoveToLayer(int32 FromLayer,int32 ToLayer);

	UFUNCTION()
	bool AddChildToLayer(int32 Layer, UWidget* Widget, bool BInvalidationBox = false);

	UFUNCTION()
	bool RemoveChildFromLayer(int32 Layer, UWidget* Widget);

	UPROPERTY(Transient)
	FOnViewportResized ViewportResizedEvent;

#if WITH_EDITOR
	void UpdateSafeAreaEnabled();
	void UpdateViewport(FViewport* Viewport);
#endif
	
#if WITH_EDITORONLY_DATA
	UPROPERTY(Transient)
	class UImage* SafeAreaImage;
#endif
private:

	UPROPERTY()
	UCanvasPanel* RootCanvas;

	UPROPERTY()
	TMap<int32, UCanvasPanel*> CanvasPanels;

	void OnViewportResized(FViewport*, uint32);

	/*struct FZOrderRange
	{
		FZOrderRange()
			:Max(0), Min(0)


		int32 Max;
		int32 Min;
	};

	TMap<int32, FZOrderRange> ZOrderCounters;*/

};
