#pragma once

#include "CoreMinimal.h"
#include "Framework/Application/IInputProcessor.h"

DECLARE_DELEGATE_RetVal_TwoParams(bool, FInputKeyNotify, FName, EInputEvent);
DECLARE_DELEGATE_RetVal_TwoParams(bool, FInputMouseNotify, const FPointerEvent&, bool);

class C7InputProcessor: public IInputProcessor
{
public:
	//~ Begin IInputProcessor interface
	virtual void Tick(const float DeltaTime, FSlateApplication& SlateApp, TSharedRef<ICursor> Cursor) override;
	virtual bool HandleKeyDownEvent(FSlateApplication& SlateApp, const FKeyEvent& InKeyEvent) override;
	virtual bool HandleKeyUpEvent(FSlateApplication& SlateApp, const FKeyEvent& InKeyEvent) override;
	// virtual bool HandleAnalogInputEvent(FSlateApplication& SlateApp, const FAnalogInputEvent& InAnalogInputEvent) override;
	// virtual bool HandleMouseMoveEvent(FSlateApplication& SlateApp, const FPointerEvent& MouseEvent) override;
	virtual bool HandleMouseButtonDownEvent( FSlateApplication& SlateApp, const FPointerEvent& MouseEvent) override;
	virtual bool HandleMouseButtonUpEvent( FSlateApplication& SlateApp, const FPointerEvent& MouseEvent) override;
	// virtual bool HandleMouseButtonDoubleClickEvent(FSlateApplication& SlateApp, const FPointerEvent& MouseEvent) override;
	// virtual bool HandleMouseWheelOrGestureEvent(FSlateApplication& SlateApp, const FPointerEvent& InWheelEvent, const FPointerEvent* InGestureEvent) override;
	virtual const TCHAR* GetDebugName() const { return TEXT("C7InputProcessor"); }
	//~ End IInputProcessor interface

	FInputKeyNotify InputKeyDelegate;
	FInputMouseNotify InputMouseDelegate;
};

