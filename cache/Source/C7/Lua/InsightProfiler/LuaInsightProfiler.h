#pragma once

#include "CoreMinimal.h"
#include "LuaState.h"
#include "UObject/NoExportTypes.h"
#include "Tickable.h"
#include "LuaInsightProfiler.generated.h"

// C++自动创建一份
UCLASS()
class C7_API ULuaInsightProfiler : public UObject, public FTickableGameObject
{
	GENERATED_BODY()
	
public:
	UFUNCTION()
	void Start();
	
	UFUNCTION()
	void Stop();
	
	UFUNCTION()
	void C7AddToRoot() { this->AddToRoot(); }

	UFUNCTION()
	void C7RemoveFromRoot() { this->RemoveFromRoot(); }

	virtual void Tick(float DeltaTime) override;
	bool IsTickable() const
	{
		return (HasAnyFlags(RF_ClassDefaultObject) == false);
	}

	virtual TStatId GetStatId() const override
	{
		return GetStatID();
	}

protected:
	void SetHook();
	void ResetHook();

private:
	NS_SLUA::LuaState* GetLuaState() const;

protected:
	bool bRunning = false;
	bool bHook = false;
};
