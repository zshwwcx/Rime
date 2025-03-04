#pragma once

#include "CoreMinimal.h"
#include "Framework/Application/NavigationConfig.h" // from Slate

class C7_API FC7NavigationConfig : public FNavigationConfig
{
public:
	FC7NavigationConfig();
 
	// virtual EUINavigation GetNavigationDirectionFromAnalog(const FAnalogInputEvent& InAnalogEvent) override;
 
	virtual EUINavigationAction GetNavigationActionForKey(const FKey& InKey) const override;
};