#include "EditorTracker.h"

#include "HttpManager.h"
#include "HttpModule.h"
#include "SocketSubsystem.h"
#include "Developer/SourceControl/Private/SourceControlModule.h"
#include "Framework/Notifications/NotificationManager.h"
#include "HAL/PlatformProcess.h"
#include "Interfaces/IHttpRequest.h"
#include "Interfaces/IHttpResponse.h"
#include "Misc/CrashCollector.h"
#include "Widgets/Notifications/SNotificationList.h"


DEFINE_LOG_CATEGORY(LogEditorTracker)

#define LOCTEXT_NAMESPACE "FEditorTracker"

FString FEditorTracker::EditorTrackGetURL(TEXT("https://c7-editor-track.game.kuaishou.com/C7/info/api/get_ver"));
FString FEditorTracker::EditorTrackPostURL(TEXT("https://c7-editor-track.game.kuaishou.com/C7/editor_track/api/report"));
FString FEditorTracker::UserAgent(TEXT("Apifox/1.0.0 (https://apifox.com)"));
FString FEditorTracker::SecretCode(TEXT("zero1510"));

void FEditorTracker::OnStartupModule()
{
	if (!IsRunningCommandlet())
	{
		PostEngineInitHandle = FCoreDelegates::OnPostEngineInit.AddRaw(this, &FEditorTracker::OnPostEngineInit);
		EnginePreExitHandle = FCoreDelegates::OnEnginePreExit.AddRaw(this, &FEditorTracker::OnEnginePreExit);
	}
}

void FEditorTracker::OnShutdownModule()
{
}

void FEditorTracker::OnPostEngineInit()
{
	const int32 MinimumVersion = GetMinimumVersion();
	TMap<FString, FString> EditorInfo;
	GetEditorInfo(EditorInfo);
	int32 CurrentVersion = 0;
	if (EditorInfo.Contains("Ver"))
	{
		CurrentVersion = FCString::Atoi(*EditorInfo["Ver"]);
	}
	if (MinimumVersion != INDEX_NONE && CurrentVersion != 0 && CurrentVersion < MinimumVersion)
	{
		FPlatformMisc::MessageBoxExt(EAppMsgType::Ok, *LOCTEXT("LowerEditorVersionInfo", "The Editor Version Is Lower, Please Update!!!").ToString(), TEXT("Lower Editor Version"));
		FPlatformMisc::RequestExit(true);
		return;
	}

	const FString Action = "open";
	EditorInfo.Add("action", Action);
	PostEditorInfo(EditorInfo);

	CheckProcessConflict();
}

void FEditorTracker::CheckProcessConflict()
{
	const UEditorTrackerSettings* Settings = GetDefault<UEditorTrackerSettings>();
	for (const FString& ProcessName : Settings->ConflictProcessNames)
	{
		if (FPlatformProcess::IsApplicationRunning(*ProcessName))
		{
			ConflictedProcess += ProcessName + ", ";
		}
	}
	if (!ConflictedProcess.IsEmpty())
	{
		const FText Message = FText::Format(LOCTEXT("ProcessConflictMessage", "The process is conflict, Please close the process: {0}!!!"), FText::FromString(ConflictedProcess));
		if (Settings->ConflictMessageType == EConflictMessageType::WeakHint)
		{
			EditorInitializedHandle = FEditorDelegates::OnEditorInitialized.AddRaw(this, &FEditorTracker::OnEditorInitialized);
			FCrashCollector::UpdateValue(TEXT("ConflictedProcess"), *ConflictedProcess);
		}
		else
		{
			FPlatformMisc::MessageBoxExt(EAppMsgType::Ok, *Message.ToString(), TEXT("Process Conflict"));
			if (Settings->ConflictMessageType == EConflictMessageType::PopUpWindowAndExit)
			{
				FPlatformMisc::RequestExit(true);
			}
		}
		FCrashCollector::UpdateValue(TEXT("ConflictedProcess"), *ConflictedProcess);
	}
}

void FEditorTracker::OnEditorInitialized(const double Duration)
{
	const FSimpleDelegate OnUpdateProjectConfirm = FSimpleDelegate::CreateLambda([this]()
	{
		if (NotificationPtr.IsValid())
		{
			NotificationPtr.Pin()->SetCompletionState(SNotificationItem::CS_Success);
			NotificationPtr.Pin()->ExpireAndFadeout();
			NotificationPtr.Reset();
		}
	});
	const FText Message = FText::Format(LOCTEXT("ProcessConflictMessage", "The process is conflict, Please close the process: {0}!!!"), FText::FromString(ConflictedProcess));
	const FText ConflictProcessConfirmText = LOCTEXT("ConflictProcessConfirm", "Ok");
	FNotificationInfo Info(Message);
	Info.ExpireDuration = 20;
	Info.bFireAndForget = true;
	Info.bUseLargeFont = false;
	Info.bUseThrobber = false;
	Info.bUseSuccessFailIcons = false;
	Info.ButtonDetails.Add(FNotificationButtonInfo(ConflictProcessConfirmText, FText(), OnUpdateProjectConfirm));
	NotificationPtr = FSlateNotificationManager::Get().AddNotification(Info);
	if (NotificationPtr.IsValid())
	{
		NotificationPtr.Pin()->SetCompletionState(SNotificationItem::CS_Pending);
	}
}

void FEditorTracker::OnEnginePreExit()
{
	TMap<FString, FString> EditorInfo;
	GetEditorInfo(EditorInfo);
	const FString Action = "close";
	EditorInfo.Add("action", Action);
	PostEditorInfo(EditorInfo);

	FCoreDelegates::OnPostEngineInit.Remove(PostEngineInitHandle);
	FCoreDelegates::OnPostEngineInit.Remove(EnginePreExitHandle);
	FEditorDelegates::OnEditorInitialized.Remove(EditorInitializedHandle);
	PostEngineInitHandle.Reset();
	EnginePreExitHandle.Reset();
	EditorInitializedHandle.Reset();
}

static int32 GetChangeListID()
{
	FString FileContent;
	const FString ChangeListFilePath = FPaths::Combine(FPaths::EngineDir(), "Build/Build.version");
	if (FPaths::FileExists(ChangeListFilePath))
	{
		if (FFileHelper::LoadFileToString(FileContent, *ChangeListFilePath))
		{
			const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(FileContent);
			TSharedPtr<FJsonObject> JsonObject;
			if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
			{
				if (JsonObject->HasField(TEXT("Changelist")))
				{
					return JsonObject->GetIntegerField(TEXT("Changelist"));
				}
			}
		}
	}

	return 0;
}

void FEditorTracker::GetEditorInfo(TMap<FString, FString>& OutEditorInfo)
{
	const FString LocalHostName = FString(FPlatformProcess::ComputerName()).ToLower();
	const FString LocalUserName = FString(FPlatformProcess::UserName()).ToLower();

	// 暂时不需要Mac地址
	// PRAGMA_DISABLE_DEPRECATION_WARNINGS
	// const FString MACAddress = FPlatformMisc::GetMacAddressString();
	// PRAGMA_ENABLE_DEPRECATION_WARNINGS

	bool bCanBind;
	const TSharedRef<FInternetAddr> LocalIPAddress = ISocketSubsystem::Get(PLATFORM_SOCKETSUBSYSTEM)->GetLocalHostAddr(*GLog, bCanBind);
	FString LocalIP = LocalIPAddress->ToString(false);

	if (LocalIP.IsEmpty() || LocalIP.Equals("0"))
	{
		LocalIP = "0.0.0.0";
	}

	// 先尝试从p4 config中直接拿p4用户名，再尝试从UE配置里面拿
#if 0
	ClientApi TestP4;
	FString PerforceUserName = ANSI_TO_TCHAR(TestP4.GetUser().Text());
#else
	FString PerforceUserName;
#endif
	const FSourceControlModule& SourceControlModule = FSourceControlModule::Get();
	const ISourceControlProvider& SourceControlProvider = SourceControlModule.GetProvider();
	if (SourceControlProvider.IsEnabled())
	{
		FString WorkSpaceUserName = SourceControlProvider.GetWorkSpaceUserName();
		if (PerforceUserName.IsEmpty())
		{
			PerforceUserName = WorkSpaceUserName;
		}
	}

	// 使用changelist编号作为编辑器版本号
	const FString ChangeListStr = FString::FromInt(GetChangeListID());

	// 当前编辑器启动路径
	FString ApplicationCurrentWorkingDir = FPlatformProcess::GetCurrentWorkingDirectory();

	OutEditorInfo.Add("ip", LocalIP);
	OutEditorInfo.Add("p4", PerforceUserName);
	OutEditorInfo.Add("user", LocalUserName);
	OutEditorInfo.Add("ver", ChangeListStr);
	const FString SecStr = LocalIP + PerforceUserName + LocalUserName + ChangeListStr + SecretCode;
	const FString MD5 = FMD5::HashAnsiString(*SecStr);
	OutEditorInfo.Add("secret_key", MD5);
}

int32 FEditorTracker::GetMinimumVersion()
{
	bool bWait = true;
	int32 Version = INDEX_NONE;
	auto OnGetMinimumVersionComplete = [&](FHttpRequestPtr HttpRequest, const FHttpResponsePtr& HttpResponse, bool bSucceeded)
	{
		if (EHttpResponseCodes::IsOk(HttpResponse->GetResponseCode()))
		{
			const FString Content = HttpResponse->GetContentAsString();
			const TSharedRef<TJsonReader<TCHAR>> JsonReader = TJsonReaderFactory<TCHAR>::Create(Content);
			TSharedPtr<FJsonObject> JsonObject;
			if (FJsonSerializer::Deserialize(JsonReader, JsonObject))
			{
				TSharedPtr<FJsonObject> Datas = JsonObject->GetObjectField(TEXT("data"));
				if (Datas.IsValid() && Datas->HasField(TEXT("data")))
				{
					const FString VersionStr = Datas->GetStringField(TEXT("data"));
					if (!VersionStr.IsEmpty() && VersionStr.IsNumeric())
					{
						Version = FCString::Atoi(*VersionStr);
						UE_LOG(LogEditorTracker, Display, TEXT("Get Minimum Version Success, The Version Is : %s"), *VersionStr)
					}
				}
			}
		}
		bWait = false;
	};

	const TSharedRef<IHttpRequest> Request = FHttpModule::Get().CreateRequest();
	Request->SetURL(EditorTrackGetURL);
	Request->SetVerb("GET");
	Request.Get().SetHeader(TEXT("User-Agent"), UserAgent);
	Request->OnProcessRequestComplete().BindLambda(OnGetMinimumVersionComplete);
	Request->ProcessRequest();
	// 加一个最大等待时间，防止网络问题导致编辑器打不开
	const double StartTime = FPlatformTime::Seconds();
	constexpr float MaxDurationToWait = 5.f;
	const double MaxTimeToWait = StartTime + MaxDurationToWait;
	while (bWait)
	{
		FPlatformProcess::Sleep(0.01f);
		const double CurrentTime = FPlatformTime::Seconds();
		if (CurrentTime > MaxTimeToWait)
		{
			UE_LOG(LogEditorTracker, Warning, TEXT("Can not get the minimum version!"))
			break;
		}
		FHttpModule::Get().GetHttpManager().Tick(0.01);
	}
	return Version;
}

void FEditorTracker::PostEditorInfo(const TMap<FString, FString>& InEditorInfo)
{
	auto OnPostEditorInfoComplete = [&](FHttpRequestPtr HttpRequest, const FHttpResponsePtr& HttpResponse, bool bSucceeded)
	{
		if (EHttpResponseCodes::IsOk(HttpResponse->GetResponseCode()))
		{
			UE_LOG(LogEditorTracker, Display, TEXT("PostEditorInfo Success"))
		}
	};

	const TSharedPtr<FJsonObject> SearchJsonObject = MakeShareable(new FJsonObject);
	FString OutputString;
	const TSharedRef<TJsonWriter<>> JsonWriter = TJsonWriterFactory<>::Create(&OutputString);
	for (auto Info : InEditorInfo)
	{
		SearchJsonObject->SetStringField(Info.Key, Info.Value);
	}

	// 获取运行路径
	const TSharedPtr<FJsonObject> InfoObject = MakeShareable(new FJsonObject);
	const FString ApplicationCurrentWorkingDir = FPlatformProcess::GetCurrentWorkingDirectory();
	InfoObject->SetStringField("dir", ApplicationCurrentWorkingDir);
	SearchJsonObject->SetObjectField("info", InfoObject);
	FJsonSerializer::Serialize(SearchJsonObject.ToSharedRef(), JsonWriter);
	UE_LOG(LogEditorTracker, Display, TEXT("PostEditorInfo: %s"), *OutputString)
	
	FCrashCollector::UpdateValue(TEXT("EditorStartInfo"), *OutputString);

	const TSharedRef<IHttpRequest> Request = FHttpModule::Get().CreateRequest();
	Request->SetURL(EditorTrackPostURL);
	Request->SetVerb("POST");
	Request->SetHeader(TEXT("User-Agent"), UserAgent);
	Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
	Request->SetContentAsString(OutputString);
	Request->OnProcessRequestComplete().BindLambda(OnPostEditorInfoComplete);
	Request->ProcessRequest();
}

#undef LOCTEXT_NAMESPACE
