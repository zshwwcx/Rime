#pragma once

#include "CoreMinimal.h"
#ifdef DISABLE_GME
#else
#include "tmg_sdk.h"
#endif
#include "LuaOverriderInterface.h"
#include "GMEController.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogGMEController, All, All);

UCLASS(BlueprintType, Blueprintable)
class C7_API UGMEController : public UObject
#ifdef DISABLE_GME
#else
	, public ITMGDelegate
#endif
	, public ILuaOverriderInterface
{
	GENERATED_BODY()
public:
	virtual FString GetLuaFilePath_Implementation() const override { return TEXT("Gameplay/LogicSystem/Chat/System/GMEController"); };

public:
	UGMEController(const FObjectInitializer& ObjectInitializer);
	virtual ~UGMEController();

#ifdef DISABLE_GME
#else
	virtual void OnEvent(ITMG_MAIN_EVENT_TYPE eventType, const char* data);
#endif

	UFUNCTION(BlueprintCallable)
	int32 InitGME(FString SdkAppId, FString SdkAppKey, FString InUserId);

	UFUNCTION(BlueprintCallable)
	void UninitGME();

	UFUNCTION(BlueprintCallable)
	void Tick();

	UFUNCTION(BlueprintCallable)
	void EnterRoom(FString RoomID, int32 RoomType, int32 ChannelType = 1);

	UFUNCTION(BlueprintCallable)
	int32 ExitRoom(int32 ChannelType = 1);

	UFUNCTION(BlueprintCallable)
	int32 SetVoiceType(int32 VoiceType, int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 EnableMic(bool Enable, int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 SetScene(int32 scene, int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 SetAudioRole(int32 role, int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 SetAdvanceParams(FString key, FString value, int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 GetMicState(int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 EnableSpeaker(bool Enable, int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 StartRecording(FString filePath);

	UFUNCTION(BlueprintCallable)
	int32 StartRecordingWithStreamingRecognition(FString filePath);

	UFUNCTION(BlueprintCallable)
	int32 StopRecording();

	UFUNCTION(BlueprintCallable)
	int32 CancelRecording();

	UFUNCTION(BlueprintCallable)
	int32 UploadRecordedFile(FString filePath);

	UFUNCTION(BlueprintCallable)
	int32 DownloadRecordedFile(FString fileId, FString filePath);

	UFUNCTION(BlueprintCallable)
	int32 PlayRecordedFile(FString filePath);

	//UFUNCTION(BlueprintCallable)
	//int32 PlayRecordedFile(FString filePath, int32 voiceType);

	UFUNCTION(BlueprintCallable)
	int32 StopPlayFile();

	UFUNCTION(BlueprintCallable)
	int32 GetVoiceFileDuration(FString filePath);

	UFUNCTION(BlueprintCallable)
	int32 SetMaxMessageLength(int32 msTime);

	UFUNCTION(BlueprintCallable)
	int32 GetMicLevel(int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 GetMicVolume(int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 GetSpeakerLevel(int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 GetSpeakerVolume(int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 SetMicVolume(int32 volumn, int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 SetSpeakerVolume(int32 volumn, int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 AddAudioBlackList(FString OpenID, int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 RemoveAudioBlackList(FString OpenID, int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	int32 CreateChannelContext(int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	void DestroyChannelContext(int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	void PauseContext(int32 ChannelType);

	UFUNCTION(BlueprintCallable)
	void ResumeContext(int32 ChannelType);

	UFUNCTION(BlueprintCallable, BlueprintNativeEvent)
	void OnEnterRoomCompleted(int32 result, FString& errInfo);

	UFUNCTION(BlueprintCallable, BlueprintNativeEvent)
	void OnExitRoomCompleted(int32 result, FString& errInfo);

	UFUNCTION(BlueprintCallable, BlueprintNativeEvent)
	void OnEndpointsUpdateInfo(int32 eventID, FString& identifier);

	UFUNCTION(BlueprintCallable, BlueprintNativeEvent)
	void OnPttRecordFileCompleted(int32 result, FString& filePath, int32 duration, int32 filesize);

	UFUNCTION(BlueprintCallable, BlueprintNativeEvent)
	void OnPttPlayFileCompleted(int32 result, FString& filePath);

	UFUNCTION(BlueprintCallable, BlueprintNativeEvent)
	void OnPttUploadFileCompleted(int32 result, FString& filePath, FString& fileID);

	UFUNCTION(BlueprintCallable, BlueprintNativeEvent)
	void OnPttDownloadFileCompleted(int32 result, FString& filePath, FString& fileID);

	UFUNCTION(BlueprintCallable, BlueprintNativeEvent)
	void OnPttSpeech2TextCompleted(int32 result, FString& fileID, FString& text);

	UFUNCTION(BlueprintCallable, BlueprintNativeEvent)
	void OnPttStreamRecognitionCompleted(int32 result, FString& filePath, FString& fileID, FString& text);

	UFUNCTION(BlueprintCallable, BlueprintNativeEvent)
	void OnPttStreamRecognitionisRunning(int32 result, FString& filePath, FString& fileID, FString& text);

private:
	UPROPERTY()
	FString AppId;

	UPROPERTY()
	FString AppKey;

	UPROPERTY()
	FString UserId;

#ifdef DISABLE_GME
#else
	ITMGContext* GetChannelContext(int32 ChannelType, bool NeedCreate = false);
	TMap<int32, ITMGContext*> ITMGContextMap;
#endif

};

