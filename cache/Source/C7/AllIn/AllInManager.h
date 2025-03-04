#pragma once

#include "CoreMinimal.h"
#include "LuaOverriderInterface.h"
#include "AllInManager.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogAllInManager, All, All);

UCLASS(BlueprintType, Blueprintable)
class C7_API UAllInManager : public UObject
			, public ILuaOverriderInterface
{
	GENERATED_BODY()

public:

	UAllInManager(const FObjectInitializer& ObjectInitializer);
	virtual ~UAllInManager();

	UFUNCTION(BlueprintCallable)
	void RegisterCallbackEvent();

	UFUNCTION(BlueprintCallable)
	void UnregisterCallbackEvent();

	UFUNCTION(BlueprintImplementableEvent)
	void ReceiveAllInSDKMessage(const FString& jsonString);

	UFUNCTION(BlueprintCallable)
	static bool IsAllInSDKEnabled();

	FString GetLuaFilePath_Implementation() const override { return TEXT("Framework/AllInSDK/AllInManager"); }

	UFUNCTION(BlueprintCallable)
	void TrackAllInSDKReceiveProxyMessage(const FString& ModuleName, const FString& FuncName, const FString& Parameters);



#if PLATFORM_WINDOWS && !WITH_EDITOR
private:
	//记录游戏运行状态的mutex ,用于和Launcher之间的通信,目前Launcher会通过该值判断游戏是否存活
	void* GameProductMutexHandle = nullptr;
#endif


};

