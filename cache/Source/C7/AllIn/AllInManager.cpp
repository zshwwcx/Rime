#include "AllInManager.h"
#if !defined DISABLE_ALLIN_SDK
#include "AllInSDK.h"
#endif

#include "PakUpdateSubsystem.h"

#if PLATFORM_WINDOWS && !WITH_EDITOR
#include "Windows/WindowsHWrapper.h"
#endif

DEFINE_LOG_CATEGORY(LogAllInManager);

UAllInManager::UAllInManager(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	
}

UAllInManager::~UAllInManager()
{
	
}

void UAllInManager::RegisterCallbackEvent()
{
#if !defined DISABLE_ALLIN_SDK
	FAllInSDKModule::OnRecieveAllInSDKMessageEvent.AddUObject(this, &UAllInManager::ReceiveAllInSDKMessage);
#endif

	
	UPakUpdateSubsystem* Sub = GEngine->GetEngineSubsystem<UPakUpdateSubsystem>();
	if (Sub != nullptr)
	{
		Sub->FOnTrackToAllSDKReceiveProxyMessageEvent.AddDynamic(this, &UAllInManager::TrackAllInSDKReceiveProxyMessage);
	}


#if PLATFORM_WINDOWS && !WITH_EDITOR
	//创建mutex ,外部和Launcher之间通信用
	if(GConfig)
	{
		FString ProjectId;
		FString ProjectName;

		GConfig->GetString(TEXT("/Script/EngineSettings.GeneralProjectSettings"), TEXT("ProjectID"), ProjectId, GGameIni);
		GConfig->GetString(TEXT("/Script/EngineSettings.GeneralProjectSettings"), TEXT("ProjectName"), ProjectName, GGameIni);

		FString MutexName = FString::Printf(TEXT("%s?%s"), *ProjectName, *ProjectId);
		GameProductMutexHandle = CreateMutex(nullptr, true, *MutexName);

		if (GameProductMutexHandle && GetLastError() == ERROR_ALREADY_EXISTS)
		{
			// 如果互斥体已经存在，则说明另一个进程正在运行
			CloseHandle(GameProductMutexHandle);
			GameProductMutexHandle = nullptr;
		}else
		{
			UE_LOG(LogAllInManager, Log, TEXT("Create GameProductMutex '%s'"), *MutexName);
		}
	}
#endif
}


void UAllInManager::TrackAllInSDKReceiveProxyMessage(const FString& ModuleName, const FString& FuncName, const FString& Parameters)
{
	FGenericAllInPtr GenericAllInPtr = FAllInSDKModule::Get().GetAllIn();
	if(GenericAllInPtr.IsValid())
	{
		GenericAllInPtr->ReceiveProxyMessage(ModuleName, FuncName, Parameters);
	}
}


void UAllInManager::UnregisterCallbackEvent()
{
#if !defined DISABLE_ALLIN_SDK
	FAllInSDKModule::OnRecieveAllInSDKMessageEvent.RemoveAll(this);
#endif


	UPakUpdateSubsystem* Sub = GEngine->GetEngineSubsystem<UPakUpdateSubsystem>();
	if(Sub != nullptr)
	{
		Sub->FOnTrackToAllSDKReceiveProxyMessageEvent.RemoveDynamic(this, &UAllInManager::TrackAllInSDKReceiveProxyMessage);
	}

#if PLATFORM_WINDOWS && !WITH_EDITOR
	if (GameProductMutexHandle != nullptr)
	{
		ReleaseMutex(GameProductMutexHandle);
		CloseHandle(GameProductMutexHandle);
		GameProductMutexHandle = nullptr;
	}
#endif



}

bool UAllInManager::IsAllInSDKEnabled()
{
#if defined DISABLE_ALLIN_SDK
	return false;
#else
	return true;
#endif
}
