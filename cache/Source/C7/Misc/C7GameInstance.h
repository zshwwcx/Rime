// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "HAL/Platform.h"
#include "Misc/KGGameInstanceBase.h"
#include "Kismet/BlueprintPlatformLibrary.h"
#include "Misc/KGLua.h"
#include "GameFramework/GameUserSettings.h"

#include "C7GameInstance.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FPreGameInstanceEnd);


UCLASS(Abstract, BlueprintType, Blueprintable)
class C7_API UC7GameInstance : public UKGGameInstanceBase
{
	GENERATED_BODY()

public:
	UC7GameInstance();
	/** virtual function to allow custom GameInstances an opportunity to do cleanup when shutting down */
	virtual void Shutdown();

	virtual void OnStart();

	virtual void StartGameInstance() override;

	virtual void Init() override;

	virtual void OnObjectCountNearlyExceed(int32 CurrentObjectCount) override;

#if WITH_EDITOR
	void OnPostPIEStarted(bool bIsSimulating);
#endif

	void OnGameplayInit();

	void OnGameplayUnInit();

public:
	UFUNCTION(BlueprintCallable)
	void K2_OnApplicationWillEnterBackground();
	UFUNCTION(BlueprintCallable)
	void K2_OnApplicationHasEnteredForeground();

public:
	UFUNCTION(BlueprintCallable)
	void NativeOpenMap(const FString& InMapName);

	UFUNCTION(BlueprintCallable)
    void BeginLoadingScreen(const FString& MoviePath, bool bPlayUntilStopped=false, float PlayTime=0);
    
	UFUNCTION(BlueprintCallable)
	void EndLoadingScreen();
	
	UFUNCTION(Exec)
	void GM();
	
	UFUNCTION(Exec)
	void ExecGM(FString& Cmd);
	
	UFUNCTION(Exec)
	void C7Cmd(FString& Cmd);

	UFUNCTION(BlueprintCallable)
	bool IsPIE();

	UFUNCTION(BlueprintCallable)
	void HotPatchFlowEnd(int32 InMapId);

	UFUNCTION(BlueprintCallable)
	void EngineExec(FString Cmd);

	UFUNCTION(BlueprintCallable)
	void ConsoleCommand(FString Cmd);

public:

	UPROPERTY(Transient)
	class ULowMemoryWatcher* LowMemoryWatcher = nullptr;

	UPROPERTY(BlueprintAssignable)
	FPreGameInstanceEnd PreGIEnd;

	UPROPERTY(Transient)
	class UDoraSDK* DoraSDK = nullptr;
	
	// Trace相关指令支持
	UFUNCTION(Exec)
	void ToggleTraceChannel(FString InChannel, bool InEnable);

private:
	void OnPostLoadMapWithWorld(UWorld* World);
	void OnWorldTick(UWorld*, ELevelTick, float);
	void OnLoadMapFailure(UWorld* InWorld, ETravelFailure::Type FailureType, const FString& ErrorString);

	void OnLevelChanged(ULevel*, UWorld*, bool);

	void RegisterForeAndBackGroundEvent();
	void UnRegisterForeAndBackGroundEvent();
	
#if PLATFORM_WINDOWS
	void OnWindowDeactivatedEvent();
	void OnWindowActivatedEvent();
	void OnViewportResized(FViewport*, uint32);
#endif
	
	
	FDelegateHandle OnMapLoadedDelegateHandle;
	FDelegateHandle OnMapLoadFailureDelegateHandle;

	bool bGameplayInit = false;
	
	UPROPERTY(Transient)
	TMap<UWorld*, int> TrackWorldLoadState;
	
protected:
	//// lua related
	FKGLua* KGLua = nullptr;
	UPROPERTY(Transient)
	ULuaGameInstance* LuaGameInstance = nullptr;

	void CreateKGLua();
	void DeleteKGLua();
};
