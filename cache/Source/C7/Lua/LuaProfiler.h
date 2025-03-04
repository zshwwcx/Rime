#pragma once

#include "CoreMinimal.h"
#include "UObject/NoExportTypes.h"
#include "Tickable.h"
#include "Misc/CoreDelegates.h"
#include "LuaProfiler.generated.h"

#define MAX_FRAMES_CAPTURE 18000

namespace NS_SLUA
{
	struct lua_State;
}


UCLASS()
class C7_API ULuaProfiler : public UObject
{
	GENERATED_BODY()

public:
	UFUNCTION()
	void Start();

	UFUNCTION()
	void Stop(int InNum = 50);

	UFUNCTION()
	void Report(int InNum);

	UFUNCTION()
	void StartHookLuaMemoryAllcation();

	UFUNCTION()
	void StopHookLuaMemoryAllcation(int InNum = 500);


	UFUNCTION()
		void C7AddToRoot() { this->AddToRoot(); }

	UFUNCTION()
		void C7RemoveFromRoot() { this->RemoveFromRoot(); }

	void OnFrameBegin();

	//统计对象信息
	UFUNCTION()
		void DumpObjectGraph(int InTopNum = 300);


private:
	void SetHook(bool bOn);

	void DumpLuaMemoryAllocationReport(int InNum = 100);

	NS_SLUA::lua_State* GetLuaState();

	bool bRunning = false;

	bool bHook = false;

	class LuaTrace* LuaTracer = nullptr;
};
