#include "C7InputProcessor.h"

void C7InputProcessor::Tick(const float DeltaTime, FSlateApplication& SlateApp, TSharedRef<ICursor> Cursor)
{
}

bool C7InputProcessor::HandleKeyDownEvent(FSlateApplication& SlateApp, const FKeyEvent& InKeyEvent)
{
	if(InputKeyDelegate.IsBound())
	{
		return InputKeyDelegate.Execute(InKeyEvent.GetKey().GetFName(), IE_Pressed);
	}
	return IInputProcessor::HandleKeyDownEvent(SlateApp, InKeyEvent);
}

bool C7InputProcessor::HandleKeyUpEvent(FSlateApplication& SlateApp, const FKeyEvent& InKeyEvent)
{
	if(InputKeyDelegate.IsBound())
	{
		return InputKeyDelegate.Execute(InKeyEvent.GetKey().GetFName(), IE_Released);
	}
	return IInputProcessor::HandleKeyUpEvent(SlateApp, InKeyEvent);
}

bool C7InputProcessor::HandleMouseButtonDownEvent(FSlateApplication& SlateApp, const FPointerEvent& MouseEvent)
{
	if(InputMouseDelegate.IsBound())
	{
		return InputMouseDelegate.Execute(MouseEvent, true);
	}
	return IInputProcessor::HandleMouseButtonDownEvent(SlateApp, MouseEvent);
}

bool C7InputProcessor::HandleMouseButtonUpEvent(FSlateApplication& SlateApp, const FPointerEvent& MouseEvent)
{
	if(InputMouseDelegate.IsBound())
	{
		return InputMouseDelegate.Execute(MouseEvent, false);
	}
	return IInputProcessor::HandleMouseButtonUpEvent(SlateApp, MouseEvent);
}

