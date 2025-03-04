#include "GMEController.h"
#include "Serialization/JsonTypes.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#ifdef DISABLE_GME
#else
#include "../../../Plugins/GMESDK/Source/GMESDK/Public/GMESDK/av_type.h"
#include "../../../Plugins/GMESDK/Source/GMESDK/Public/GMESDK/tmg_sdk.h"
#endif


DEFINE_LOG_CATEGORY(LogGMEController);

UGMEController::UGMEController(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{

}

UGMEController::~UGMEController()
{
}

void UGMEController::UninitGME()
{
#ifdef DISABLE_GME
#else
	for (auto It = ITMGContextMap.CreateIterator(); It; ++It)
	{
		ITMGContext* Context = It.Value();
		Context->Uninit();
		ITMGContextGetInstance()->DestroySubInstance(Context);
	}
	ITMGContextMap.Empty();
	ITMGContextGetInstance()->Uninit();
#endif
}

// 初始化GME
int32 UGMEController::InitGME(FString SdkAppId, FString SdkAppKey, FString InUserId) {

#ifdef DISABLE_GME
	return 0;
#else
	ITMGContextGetInstance()->SetAdvanceParams("StringOpenID", "1");
	int32 nAppid = FCString::Atoi(*SdkAppId);
	int32 ret = ITMGContextGetInstance()->Init(TCHAR_TO_UTF8(*SdkAppId), TCHAR_TO_UTF8(*InUserId));
	UE_LOG(LogGMEController, Display, TEXT("InitGME retcode = %d"), ret);
	ITMGContextGetInstance()->SetTMGDelegate(this);

	int32 RetCode = (int32)ITMGContextGetInstance()->CheckMicPermission();
	UE_LOG(LogGMEController, Display, TEXT("Check Mic Permission retcode = %d"), RetCode);

	AppId = SdkAppId;
	AppKey = SdkAppKey;
	UserId = InUserId;

	int userSigLen = 1024;
	unsigned char userSig[1024] = { 0 };
	userSigLen = QAVSDK_AuthBuffer_GenAuthBuffer(nAppid, NULL, TCHAR_TO_UTF8(*UserId), TCHAR_TO_UTF8(*AppKey), userSig, userSigLen);
	uint32 authRet = ITMGContextGetInstance()->GetPTT()->ApplyPTTAuthbuffer((const char*)userSig, userSigLen);
	UE_LOG(LogGMEController, Display, TEXT("ApplyPTTAuthbuffer retcode = %d userSigLen = %d"), authRet, userSigLen);
	return ret;
#endif
}

void UGMEController::Tick()
{
#ifdef DISABLE_GME
#else
	ITMGContextGetInstance()->Poll();
	for (auto It = ITMGContextMap.CreateIterator(); It; ++It)
	{
		ITMGContext* Context = It.Value();
		Context->Poll();
	}
#endif
}

void UGMEController::EnterRoom(FString RoomID, int32 RoomType, int32 ChannelType) {
#ifdef DISABLE_GME
#else
	int32 nAppid = FCString::Atoi(*AppId);

	unsigned char strSig[1024] = { 0 };
	uint32 nLength = 1024;
	nLength = QAVSDK_AuthBuffer_GenAuthBuffer(nAppid, TCHAR_TO_UTF8(*RoomID), TCHAR_TO_UTF8(*UserId), TCHAR_TO_UTF8(*AppKey), strSig, nLength);
	UE_LOG(LogGMEController, Display, TEXT("OnEnterRoom"));
	ITMGContext* channelTMGContext = GetChannelContext(ChannelType, true);
	channelTMGContext->EnterRoom(TCHAR_TO_UTF8(*RoomID), (ITMG_ROOM_TYPE)RoomType, (const char*)strSig, nLength);
#endif
}

// 退出房间
int32 UGMEController::ExitRoom(int32 ChannelType)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* channelTMGContext = GetChannelContext(ChannelType);
	if (channelTMGContext != nullptr)
		return channelTMGContext->ExitRoom();
	else
		return 0;
#endif
}

#ifdef DISABLE_GME
#else
void UGMEController::OnEvent(ITMG_MAIN_EVENT_TYPE eventType, const char* data)
{
#ifdef DISABLE_GME
#else
	FString jsonData = FString(UTF8_TO_TCHAR(data));
	TSharedPtr<FJsonObject> JsonObject;
	TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(FString(UTF8_TO_TCHAR(data)));
	FJsonSerializer::Deserialize(Reader, JsonObject);

	switch (eventType)
	{
	case ITMG_MAIN_EVENT_TYPE_ENTER_ROOM:
	{
		int32 result = JsonObject->GetIntegerField(TEXT("result"));
		FString error_info = JsonObject->GetStringField(TEXT("error_info"));
		if (result == 0) {
			UE_LOG(LogGMEController, Display, TEXT("Enter room success"))
		}
		else {
			UE_LOG(LogGMEController, Display, TEXT("Enter room failed. result= %d, info = %ls"), result, *error_info)
		}
		OnEnterRoomCompleted(result, error_info);
		break;
	}
	case ITMG_MAIN_EVENT_TYPE_CHANGE_ROOM_TYPE:
	{
		int32 nResult = JsonObject->GetIntegerField(TEXT("result"));
		FString error_info = JsonObject->GetStringField(TEXT("error_info"));
		int32 nSubEventType = JsonObject->GetIntegerField(TEXT("sub_event_type"));
		int32 nNewType = JsonObject->GetIntegerField(TEXT("new_room_type"));

		FString msg("CHANGE_ROOM_TYPE");
		// switch (nSubEventType) {
		// case ITMG_ROOM_CHANGE_EVENT_ENTERROOM:
		// 	msg = FString::Printf(TEXT("onRoomTypeChanged ITMG_ROOM_CHANGE_EVENT_ENTERROOM nNewType=%d"), nNewType);
		// 	break;
		// case ITMG_ROOM_CHANGE_EVENT_COMPLETE:
		// 	msg = FString::Printf(TEXT("onRoomTypeChanged ITMG_ROOM_CHANGE_EVENT_COMPLETE nNewType=%d"), nNewType);
		// 	break;
		// }
		UE_LOG(LogGMEController, Display, TEXT("%s"), *msg)
			break;
	}
	case ITMG_MAIN_EVENT_TYPE_EXIT_ROOM:
	{
		FString error_info = JsonObject->GetStringField(TEXT("error_info"));
		UE_LOG(LogGMEController, Display, TEXT("Exit room success"));
		OnExitRoomCompleted(0, error_info);
		break;
	}
	case ITMG_MAIN_EVENT_TYPE_ROOM_DISCONNECT:
	{
		int32 result = JsonObject->GetIntegerField(TEXT("result"));
		FString error_info = JsonObject->GetStringField(TEXT("error_info"));
		OnExitRoomCompleted(result, error_info);
		break;
	}
	case ITMG_MAIN_EVENT_TYPE_USER_UPDATE:
	{
		int32 eventId = JsonObject->GetIntegerField(TEXT("event_id"));
		TArray<TSharedPtr<FJsonValue>> UserList = JsonObject->GetArrayField(TEXT("user_list"));
		for (int32 i = 0; i < UserList.Num(); i++) {
			FString identifier = UserList.operator[](i)->AsString();
			OnEndpointsUpdateInfo(eventId, identifier);
		}
		break;
	}
	case ITMG_MAIN_EVENT_TYPE_PTT_RECORD_COMPLETE:
	{
		int32 result = JsonObject->GetIntegerField(TEXT("result"));
		FString filepath = JsonObject->GetStringField(TEXT("file_path"));

		auto path = StringCast<UTF8CHAR>(*filepath);

		int32 duration = 0;
		int32 filesize = 0;
		if (result == 0) {
			duration = ITMGContextGetInstance()->GetPTT()->GetVoiceFileDuration((ANSICHAR*)path.Get());
			filesize = ITMGContextGetInstance()->GetPTT()->GetFileSize((ANSICHAR*)path.Get());
		}

		OnPttRecordFileCompleted(result, filepath, duration, filesize);
		break;
	}
	case ITMG_MAIN_EVENT_TYPE_PTT_UPLOAD_COMPLETE:
	{
		int32 result = JsonObject->GetIntegerField(TEXT("result"));
		FString filepath = JsonObject->GetStringField(TEXT("file_path"));
		FString fileid = JsonObject->GetStringField(TEXT("file_id"));
		OnPttUploadFileCompleted(result, filepath, fileid);
		break;
	}
	case ITMG_MAIN_EVENT_TYPE_PTT_DOWNLOAD_COMPLETE:
	{
		int32 result = JsonObject->GetIntegerField(TEXT("result"));
		FString filepath = JsonObject->GetStringField(TEXT("file_path"));
		FString fileid = JsonObject->GetStringField(TEXT("file_id"));
		OnPttDownloadFileCompleted(result, filepath, fileid);
		break;
	}
	case ITMG_MAIN_EVENT_TYPE_PTT_PLAY_COMPLETE:
	{
		int32 result = JsonObject->GetIntegerField(TEXT("result"));
		FString filepath = JsonObject->GetStringField(TEXT("file_path"));
		OnPttPlayFileCompleted(result, filepath);
		break;
	}
	case ITMG_MAIN_EVENT_TYPE_PTT_SPEECH2TEXT_COMPLETE:
	{
		int32 result = JsonObject->GetIntegerField(TEXT("result"));
		FString text = JsonObject->GetStringField(TEXT("text"));
		FString fileid = JsonObject->GetStringField(TEXT("file_id"));
		OnPttSpeech2TextCompleted(result, fileid, text);
		break;
	}
	case ITMG_MAIN_EVENT_TYPE_PTT_STREAMINGRECOGNITION_COMPLETE:
	{
		int32 nResult = JsonObject->GetIntegerField(TEXT("result"));
		FString text = JsonObject->GetStringField(TEXT("text"));
		FString fileid = JsonObject->GetStringField(TEXT("file_id"));
		FString file_path = JsonObject->GetStringField(TEXT("file_path"));
		OnPttStreamRecognitionCompleted(nResult, file_path, fileid, text);
		break;
	}
	case ITMG_MAIN_EVENT_TYPE_PTT_STREAMINGRECOGNITION_IS_RUNNING:
	{
		int32 nResult = JsonObject->GetIntegerField(TEXT("result"));
		FString text = JsonObject->GetStringField(TEXT("text"));
		FString fileid = TEXT("STREAMINGRECOGNITION_IS_RUNNING");
		FString file_path = JsonObject->GetStringField(TEXT("file_path"));
		OnPttStreamRecognitionisRunning(nResult, file_path, fileid, text);
		break;
	}
	}
#endif
}
#endif

// 设置应用场景
int32 UGMEController::SetScene(int32 scene, int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->SetScene((ITMG_APP_SCENE)scene);
	else
		UE_LOG(LogGMEController, Display, TEXT("SetScene Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

//切换场景
int32 UGMEController::SetAudioRole(int32 role, int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->SetAudioRole((ITMG_AUDIO_MEMBER_ROLE)role);
	else
		UE_LOG(LogGMEController, Display, TEXT("SetAudioRole Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}


//切换场景
int32 UGMEController::SetAdvanceParams(FString key, FString value, int ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->SetAdvanceParams(TCHAR_TO_UTF8(*key), TCHAR_TO_UTF8(*value));
	else
		UE_LOG(LogGMEController, Display, TEXT("SetAdvanceParams Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}


// 打开或关闭麦克风
int32 UGMEController::EnableMic(bool Enable, int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->GetAudioCtrl()->EnableMic(Enable);
	else
		UE_LOG(LogGMEController, Display, TEXT("EnableMic Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

// 打开或关闭麦克风
int32 UGMEController::GetMicState(int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->GetAudioCtrl()->GetMicState();
	else
		UE_LOG(LogGMEController, Display, TEXT("GetMicState Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

// 打开或关闭扬声器
int32 UGMEController::EnableSpeaker(bool Enable, int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->GetAudioCtrl()->EnableSpeaker(Enable);
	else
		UE_LOG(LogGMEController, Display, TEXT("EnableSpeaker Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

// 设置声音类型
int32 UGMEController::SetVoiceType(int32 VoiceType, int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->GetAudioEffectCtrl()->SetVoiceType((ITMG_VOICE_TYPE)VoiceType);
	else
		UE_LOG(LogGMEController, Display, TEXT("SetVoiceType Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

// 开始录音
int32 UGMEController::StartRecording(FString filePath)
{
#ifdef DISABLE_GME
	return 0;
#else
	const FString FullPath = IFileManager::Get().ConvertToAbsolutePathForExternalAppForWrite(*filePath);
	return ITMGContextGetInstance()->GetPTT()->StartRecording(TCHAR_TO_UTF8(*FullPath));
#endif
}

// 开始录音转文字
int32 UGMEController::StartRecordingWithStreamingRecognition(FString filePath)
{
#ifdef DISABLE_GME
	return 0;
#else
	const FString FullPath = IFileManager::Get().ConvertToAbsolutePathForExternalAppForWrite(*filePath);
	return ITMGContextGetInstance()->GetPTT()->StartRecordingWithStreamingRecognition(TCHAR_TO_UTF8(*FullPath));
#endif
}

//停止录音
int32 UGMEController::StopRecording()
{
#ifdef DISABLE_GME
	return 0;
#else
	return ITMGContextGetInstance()->GetPTT()->StopRecording();
#endif
}

//取消录音
int32 UGMEController::CancelRecording()
{
#ifdef DISABLE_GME
	return 0;
#else
	return ITMGContextGetInstance()->GetPTT()->CancelRecording();
#endif
}

//上传录音文件
int32 UGMEController::UploadRecordedFile(FString filePath)
{
#ifdef DISABLE_GME
	return 0;
#else
	const FString FullPath = IFileManager::Get().ConvertToAbsolutePathForExternalAppForWrite(*filePath);
	return ITMGContextGetInstance()->GetPTT()->UploadRecordedFile(TCHAR_TO_UTF8(*FullPath));
#endif
}

//下载录音文件
int32 UGMEController::DownloadRecordedFile(FString fileId, FString filePath)
{
#ifdef DISABLE_GME
	return 0;
#else
	const FString FullPath = IFileManager::Get().ConvertToAbsolutePathForExternalAppForWrite(*filePath);
	return ITMGContextGetInstance()->GetPTT()->DownloadRecordedFile(TCHAR_TO_UTF8(*fileId), TCHAR_TO_UTF8(*FullPath));
#endif
}

//播放录音文件
int32 UGMEController::PlayRecordedFile(FString filePath)
{
#ifdef DISABLE_GME
	return 0;
#else
	const FString FullPath = IFileManager::Get().ConvertToAbsolutePathForExternalAppForWrite(*filePath);
	return ITMGContextGetInstance()->GetPTT()->PlayRecordedFile(TCHAR_TO_UTF8(*FullPath));
#endif
}

//播放录音文件
//int32 PlayRecordedFile(FString filePath, int32 voiceType)
//{
//	return ITMGContextGetInstance()->GetPTT()->PlayRecordedFile(TCHAR_TO_UTF8(*filePath),(ITMG_VOICE_TYPE)voiceType);
//}

//停止播放录音文件
int32 UGMEController::StopPlayFile()
{
#ifdef DISABLE_GME
	return 0;
#else
	return ITMGContextGetInstance()->GetPTT()->StopPlayFile();
#endif
}

//获取录音文件长度
int32 UGMEController::GetVoiceFileDuration(FString filePath)
{
#ifdef DISABLE_GME
	return 0;
#else
	const FString FullPath = IFileManager::Get().ConvertToAbsolutePathForExternalAppForWrite(*filePath);
	return ITMGContextGetInstance()->GetPTT()->GetVoiceFileDuration(TCHAR_TO_UTF8(*FullPath));
#endif
}

//设置录音长度
int32 UGMEController::SetMaxMessageLength(int32 msTime)
{
#ifdef DISABLE_GME
	return 0;
#else
	return ITMGContextGetInstance()->GetPTT()->SetMaxMessageLength(msTime);
#endif
}

//获取speaker level 大小
int32 UGMEController::GetSpeakerLevel(int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->GetAudioCtrl()->GetSpeakerLevel();
	else
		UE_LOG(LogGMEController, Display, TEXT("GetSpeakerLevel Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

//设置speaker volume 大小
int32 UGMEController::SetSpeakerVolume(int32 SpeakerVolumne, int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->GetAudioCtrl()->SetSpeakerVolume(SpeakerVolumne);
	else
		UE_LOG(LogGMEController, Display, TEXT("SetSpeakerVolume Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

//获取speaker volume 大小
int32 UGMEController::GetSpeakerVolume(int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->GetAudioCtrl()->GetSpeakerVolume();
	else
		UE_LOG(LogGMEController, Display, TEXT("GetSpeakerVolume Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

//获取mic level 大小
int32 UGMEController::GetMicLevel(int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->GetAudioCtrl()->GetMicLevel();
	else
		UE_LOG(LogGMEController, Display, TEXT("GetMicLevel Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

//获取mic volume 大小
int32 UGMEController::GetMicVolume(int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->GetAudioCtrl()->GetMicVolume();
	else
		UE_LOG(LogGMEController, Display, TEXT("GetMicVolume Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

//设置speaker volume 大小
int32 UGMEController::SetMicVolume(int32 micVolumne, int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->GetAudioCtrl()->SetMicVolume(micVolumne);
	else
		UE_LOG(LogGMEController, Display, TEXT("SetMicVolume Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

//设置speaker volume 大小
int32 UGMEController::AddAudioBlackList(FString OpenID, int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->GetAudioCtrl()->AddAudioBlackList(TCHAR_TO_UTF8(*OpenID));
	else
		UE_LOG(LogGMEController, Display, TEXT("AddAudioBlackList Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

int32 UGMEController::RemoveAudioBlackList(FString OpenID, int32 ChannelType = 0)
{
#ifdef DISABLE_GME
	return 0;
#else
	ITMGContext* tmgContext = GetChannelContext(ChannelType);
	if (tmgContext != nullptr)
		return tmgContext->GetAudioCtrl()->RemoveAudioBlackList(TCHAR_TO_UTF8(*OpenID));
	else
		UE_LOG(LogGMEController, Display, TEXT("RemoveAudioBlackList Failed ChannelType = %d"), ChannelType);
	return 0;
#endif
}

void UGMEController::OnPttStreamRecognitionCompleted_Implementation(int32 result, FString& filePath, FString& fileID, FString& text)
{

}

void UGMEController::OnEnterRoomCompleted_Implementation(int32 result, FString& errInfo)
{

}


void UGMEController::OnExitRoomCompleted_Implementation(int32 result, FString& errInfo)
{

}


void UGMEController::OnEndpointsUpdateInfo_Implementation(int32 eventID, FString& identifier)
{

}


void UGMEController::OnPttRecordFileCompleted_Implementation(int32 result, FString& filePath, int32 duration, int32 filesize)
{

}


void UGMEController::OnPttPlayFileCompleted_Implementation(int32 result, FString& filePath)
{

}


void UGMEController::OnPttUploadFileCompleted_Implementation(int32 result, FString& filePath, FString& fileID)
{

}


void UGMEController::OnPttDownloadFileCompleted_Implementation(int32 result, FString& filePath, FString& fileID)
{

}


void UGMEController::OnPttSpeech2TextCompleted_Implementation(int32 result, FString& fileID, FString& text)
{

}

void UGMEController::OnPttStreamRecognitionisRunning_Implementation(int32 result, FString& filePath, FString& fileID, FString& text)
{

}

#ifdef DISABLE_GME
	
#else
ITMGContext* UGMEController::GetChannelContext(int32 ChannelType = 0, bool NeedCreate)
{
	if (ChannelType == 0)
		return ITMGContextGetInstance();
	else
		if (NeedCreate)
			CreateChannelContext(ChannelType);
	if (ITMGContextMap.Contains(ChannelType))
		return ITMGContextMap[ChannelType];
	else
		return nullptr;
}
#endif	

int32 UGMEController::CreateChannelContext(int32 ChannelType)
{
#ifdef DISABLE_GME
	return 0;
#else
	if (ITMGContextMap.Contains(ChannelType))
		return 0;
	ITMGContext* newTMGContext = nullptr;
	if (ChannelType != 0)
		newTMGContext = ITMGContextGetInstance()->CreateSubInstance();

	newTMGContext->SetAdvanceParams("StringOpenID", "1");
	int32 ret = newTMGContext->Init(TCHAR_TO_UTF8(*AppId), TCHAR_TO_UTF8(*UserId));
	UE_LOG(LogGMEController, Display, TEXT("InitGME retcode = %d"), ret);
	newTMGContext->SetTMGDelegate(this);

	int32 RetCode = (int32)newTMGContext->CheckMicPermission();
	UE_LOG(LogGMEController, Display, TEXT("Check Mic Permission retcode = %d"), RetCode);

	int userSigLen = 1024;
	unsigned char userSig[1024] = { 0 };
	int32 nAppid = FCString::Atoi(*AppId);
	userSigLen = QAVSDK_AuthBuffer_GenAuthBuffer(nAppid, NULL, TCHAR_TO_UTF8(*UserId), TCHAR_TO_UTF8(*AppKey), userSig, userSigLen);
	uint32 authRet = newTMGContext->GetPTT()->ApplyPTTAuthbuffer((const char*)userSig, userSigLen);
	UE_LOG(LogGMEController, Display, TEXT("ApplyPTTAuthbuffer retcode = %d userSigLen = %d"), authRet, userSigLen);
	ITMGContextMap.Add(ChannelType, newTMGContext);
	return 1;
#endif	
}


void UGMEController::DestroyChannelContext(int32 ChannelType)
{
#ifdef DISABLE_GME
	return;
#else
	if (!ITMGContextMap.Contains(ChannelType))
		return;
	if (ChannelType != 0) {
		ITMGContextMap[ChannelType]->Uninit();
		ITMGContextGetInstance()->DestroySubInstance(ITMGContextMap[ChannelType]);
		ITMGContextMap.Remove(ChannelType);
		UE_LOG(LogGMEController, Display, TEXT("DestroyChannelContext ChannelType = %d"), ChannelType);
	}
#endif	
}

void UGMEController::PauseContext(int32 ChannelType)
{
#ifdef DISABLE_GME
	return;
#else
	if (!ITMGContextMap.Contains(ChannelType))
		return;
	if (ChannelType != 0) {
		ITMGContextMap[ChannelType]->Pause();
	}
#endif	
}

void UGMEController::ResumeContext(int32 ChannelType)
{
#ifdef DISABLE_GME
	return;
#else
	if (!ITMGContextMap.Contains(ChannelType))
		return;
	if (ChannelType != 0) {
		ITMGContextMap[ChannelType]->Resume();
	}
#endif	
}
