#pragma once

#include "CoreMinimal.h"
#include "UObject/NoExportTypes.h"
#include "Tickable.h"
#include "LowMemoryWatcher.generated.h"


UCLASS()
class C7_API ULowMemoryWatcher : public UObject, public FTickableGameObject
{
	GENERATED_BODY()

public:
	ULowMemoryWatcher()
	{

	}
	void Init(class UC7GameInstance* InGI);
	void Uninit();

	virtual void Tick(float DeltaTime) override;
	bool IsTickable() const
	{
		return (HasAnyFlags(RF_ClassDefaultObject) == false);
	}
	virtual TStatId GetStatId() const override
	{
		return GetStatID();
	}
	
private:
	UPROPERTY(transient)
	class UC7GameInstance* GI = nullptr;

	float WatchMemoryDelayTime = 0;
	int WatchMemoryMaxValue = 0;
};
