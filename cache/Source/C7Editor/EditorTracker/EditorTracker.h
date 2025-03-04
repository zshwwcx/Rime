#pragma once

#include "CoreMinimal.h"

// #if !PLATFORM_MAC
// THIRD_PARTY_INCLUDES_START
// // used to retrieve the swarm url from p4
// #include <p4/clientapi.h>
// THIRD_PARTY_INCLUDES_END
// #endif

#include "EditorTracker.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogEditorTracker, All, All);

class FEditorTracker: public TSharedFromThis<FEditorTracker>
{
public:
	void OnStartupModule();
	void OnShutdownModule();

	void OnPostEngineInit();
	void OnEnginePreExit();

	void OnEditorInitialized(const double Duration);
	
	static void GetEditorInfo(TMap<FString, FString>& OutEditorInfo);

	static int32 GetMinimumVersion();

	void CheckProcessConflict();

	static void PostEditorInfo(const TMap<FString, FString>& InEditorInfo);

	FDelegateHandle PostEngineInitHandle;
	FDelegateHandle EnginePreExitHandle;
	FDelegateHandle EditorInitializedHandle;

	static FString EditorTrackGetURL;
	static FString EditorTrackPostURL;
	static FString UserAgent;
	static FString SecretCode;

	TWeakPtr<class SNotificationItem> NotificationPtr;
	FString ConflictedProcess;
};

UENUM()
enum class EConflictMessageType : uint8
{
	WeakHint UMETA(DisplayName="右下角提示"),

	PopUpWindow UMETA(DisplayName="阻塞弹窗"),
	
	PopUpWindowAndExit UMETA(DisplayName="阻塞弹窗并退出"),
};

UCLASS(Config = Editor, meta = (DisplayName = "KGEditorTrackerSettings"), DefaultConfig)
class UEditorTrackerSettings : public UDeveloperSettings
{
	GENERATED_BODY()
public:

	// 不允许同时运行的进程列表
	UPROPERTY(EditAnywhere, Config)
	TArray<FString> ConflictProcessNames;

	// 进程冲突时提示方式
	UPROPERTY(EditAnywhere, Config)
	EConflictMessageType ConflictMessageType;
};