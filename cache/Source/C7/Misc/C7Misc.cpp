// Add By wangwenfeng05 2023.12.4 C7Misc 

#include "C7Misc.h"
#include "DeviceProfiles/DeviceProfileManager.h"


FString UC7Misc::GetBaseProfileName()
{
	UDeviceProfile* DeviceProfile = UDeviceProfileManager::Get().GetActiveProfile();
	check(DeviceProfile)
		return DeviceProfile->BaseProfileName;
}
TArray<FString> UC7Misc::GetUObjectChildren()
{
	TArray<UClass*> ClassUObject;
	GetDerivedClasses(UObject::StaticClass(), ClassUObject, true);
	TArray<FString> ClassNames;
	for (int32 Index = 0; Index < ClassUObject.Num(); Index++)
	{
		ClassNames.Add(ClassUObject[Index]->GetName());
	}
	return ClassNames;
}
	