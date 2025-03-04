//Add By wangwenfeng05 2023.12.4 C7Misc
#pragma once

#include "CoreMinimal.h"
#include "DeviceProfiles/DeviceProfile.h"
#include "C7Misc.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogC7Misc, All, All);

UCLASS()
class C7_API UC7Misc : public UObject
{
	GENERATED_BODY()
public:
	UFUNCTION(BlueprintCallable, Category = "C7Misc") 
	static FString GetBaseProfileName(); 
	UFUNCTION(BlueprintCallable, Category = "C7Misc")
	static TArray<FString> GetUObjectChildren();
};
