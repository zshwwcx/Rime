#pragma once

#include "CoreMinimal.h"
#include "KGBasicManager.h"
#include "C7UIInputProcessorManager.generated.h"

class C7InputProcessor;

DECLARE_DYNAMIC_DELEGATE_RetVal_TwoParams(bool, FKeyEventNotify, FName, KeyName, EInputEvent, KeyEvent);
DECLARE_DYNAMIC_DELEGATE_RetVal_OneParam(bool, FMouseEventNotify, FPointerEvent, MouseEvent);

UCLASS(BlueprintType, Blueprintable)
class C7_API UC7UIInputProcessorManager : public UKGBasicManager
{
	GENERATED_BODY()
	
public:
	virtual void NativeInit() override;

	virtual void NativeUninit() override;

	virtual EManagerType GetManagerType() override { return EManagerType::EMT_C7UIInputProcessorManager; }

	UC7UIInputProcessorManager(const FObjectInitializer& ObjectInitializer);
	virtual ~UC7UIInputProcessorManager() override;
	
	UFUNCTION(Blueprintable)
	void BindKeyDownEvent(FName KeyName);

	UFUNCTION(Blueprintable)
	void UnBindKeyDownEvent(FName KeyName);

	UFUNCTION(Blueprintable)
	void BindKeyUpEvent(FName KeyName);

	UFUNCTION(Blueprintable)
	void UnBindKeyUpEvent(FName KeyName);

	UFUNCTION(Blueprintable)
	void UnBindAllKeyEvents();

	UFUNCTION(Blueprintable)
	void BindMouseButtonDownEvent();

	UFUNCTION(Blueprintable)
	void UnBindMouseButtonDownEvent();

	UFUNCTION(Blueprintable)
	void BindMouseButtonUpEvent();

	UFUNCTION(Blueprintable)
	void UnBindMouseButtonUpEvent();

	UFUNCTION(Blueprintable)
	void UnBindAllMouseEvents();
	
	// 回调代理 
	UPROPERTY()
	FKeyEventNotify OnGetKeyEventDelegate;

	UPROPERTY()
	FMouseEventNotify OnGetMouseButtonDownDelegate;

	UPROPERTY()
	FMouseEventNotify OnGetMouseButtonUpDelegate;
	
private:
	TSharedPtr<C7InputProcessor> InputPreprocessor = nullptr;
	
	TSet<FName> ReleasedKeyMaps;
	TSet<FName> PressedKeyMaps;
	bool bListenMouseDown;
	bool bListenMouseUp;

	bool InputKeyNotify(FName KeyName, EInputEvent Event) const;
	bool InputMouseNotify(const FPointerEvent& MouseEvent, bool bIsDown) const;
};

