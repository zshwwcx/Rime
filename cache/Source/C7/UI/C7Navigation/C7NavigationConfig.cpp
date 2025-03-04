#include "C7NavigationConfig.h"
#include "GameFramework/InputSettings.h" // from Engine
 
// based on the engine's FNavigationConfig code:
// Engine/Source/Runtime/Slate/Public/Framework/Application/NavigationConfig.cpp
 
FC7NavigationConfig::FC7NavigationConfig()
{

}

EUINavigationAction FC7NavigationConfig::GetNavigationActionForKey(const FKey& InKey) const
{
	//空格不触发Accept
	if (InKey == EKeys::Enter || InKey == EKeys::Virtual_Accept)
	{
		// By default, enter, space, and gamepad accept are all counted as accept
		return EUINavigationAction::Accept;
	}
	else if (InKey == EKeys::Escape || InKey == EKeys::Virtual_Back)
	{
		// By default, escape and gamepad back count as leaving current scope
		return EUINavigationAction::Back;
	}

	return EUINavigationAction::Invalid;
}