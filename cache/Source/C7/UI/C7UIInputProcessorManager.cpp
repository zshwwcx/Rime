#include "C7UIInputProcessorManager.h"

#include "C7InputProcessor.h"

UC7UIInputProcessorManager::UC7UIInputProcessorManager(const FObjectInitializer& ObjectInitializer):
	bListenMouseDown(false), bListenMouseUp(false)
{
}

UC7UIInputProcessorManager::~UC7UIInputProcessorManager()
{
}

void UC7UIInputProcessorManager::NativeUninit()
{
	Super::NativeUninit();
	UnBindAllKeyEvents();
	UnBindAllMouseEvents();
}

void UC7UIInputProcessorManager::NativeInit()
{
	Super::NativeInit();

	if (ensure(FSlateApplication::IsInitialized()))
	{
		InputPreprocessor = MakeShared<C7InputProcessor>();
		FSlateApplication::Get().RegisterInputPreProcessor(InputPreprocessor);

		InputPreprocessor->InputKeyDelegate.BindUObject(this, &UC7UIInputProcessorManager::InputKeyNotify);
		InputPreprocessor->InputMouseDelegate.BindUObject(this, &UC7UIInputProcessorManager::InputMouseNotify);
	}
}

void UC7UIInputProcessorManager::BindKeyDownEvent(FName KeyName)
{
	PressedKeyMaps.Emplace(KeyName);
}

void UC7UIInputProcessorManager::BindKeyUpEvent(FName KeyName)
{
	ReleasedKeyMaps.Emplace(KeyName);
}

void UC7UIInputProcessorManager::UnBindKeyDownEvent(FName KeyName)
{
	PressedKeyMaps.Remove(KeyName);
}

void UC7UIInputProcessorManager::UnBindKeyUpEvent(FName KeyName)
{
	ReleasedKeyMaps.Remove(KeyName);
}

void UC7UIInputProcessorManager::UnBindAllKeyEvents()
{
	PressedKeyMaps.Empty();
	ReleasedKeyMaps.Empty();
}

void UC7UIInputProcessorManager::BindMouseButtonDownEvent()
{
	bListenMouseDown = true;
}

void UC7UIInputProcessorManager::UnBindMouseButtonDownEvent()
{
	bListenMouseDown = false;
}

void UC7UIInputProcessorManager::BindMouseButtonUpEvent()
{
	bListenMouseUp = true;
}

void UC7UIInputProcessorManager::UnBindMouseButtonUpEvent()
{
	bListenMouseUp = false;
}

void UC7UIInputProcessorManager::UnBindAllMouseEvents()
{
	bListenMouseDown = false;
	bListenMouseUp = false;
}

bool UC7UIInputProcessorManager::InputKeyNotify(FName KeyName, EInputEvent Event) const
{
	if (Event == IE_Pressed && PressedKeyMaps.Contains(KeyName) && OnGetKeyEventDelegate.IsBound())
	{
		return OnGetKeyEventDelegate.Execute(KeyName, Event);
	} 
	if(Event == IE_Released && ReleasedKeyMaps.Contains(KeyName) && OnGetKeyEventDelegate.IsBound())
	{ 
		return OnGetKeyEventDelegate.Execute(KeyName, Event);
	}
	return false;
}

bool UC7UIInputProcessorManager::InputMouseNotify(const FPointerEvent& MouseEvent, bool bIsDown) const
{
	if(bIsDown && bListenMouseDown && OnGetMouseButtonDownDelegate.IsBound())
	{
		return OnGetMouseButtonDownDelegate.Execute(MouseEvent);
	}
	if(!bIsDown && bListenMouseUp && OnGetMouseButtonUpDelegate.IsBound())
	{
		return OnGetMouseButtonUpDelegate.Execute(MouseEvent);
	}
	return false;
}
