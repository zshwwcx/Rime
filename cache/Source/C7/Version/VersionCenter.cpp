// Fill out your copyright notice in the Description page of Project Settings.


#include "Version/VersionCenter.h"
#if PLATFORM_ANDROID
#include "Android/AndroidJNI.h"
#include "Android/AndroidApplication.h"
#include "Android/AndroidJavaEnv.h"
#endif

FString UVersionCenter::GetVersionString()
{
#if WITH_EDITOR
	return FString(TEXT("0.0.0.0"));
#else
	if (const UVersionCenter* Center = GetDefault<UVersionCenter>())
	{
		return Center->VersionString;
	}
	return FString();
#endif
}

FString UVersionCenter::GetAppVersionString()
{
#if PLATFORM_ANDROID
	if (JNIEnv* JEnv = AndroidJavaEnv::GetJavaEnv())
	{
		jclass GameActivityClass = AndroidJavaEnv::FindJavaClassGlobalRef("com/epicgames/unreal/GameActivity");
		jfieldID VersionName = FJavaWrapper::FindField(JEnv, GameActivityClass, "VersionName","Ljava/lang/String;",false);
		FString Version = FJavaHelper::FStringFromLocalRef(JEnv, (jstring)JEnv->GetObjectField(AndroidJavaEnv::GetGameActivityThis(), VersionName));
		JEnv->DeleteGlobalRef(GameActivityClass);
		return Version;
	}
	else
	{
		return TEXT("1.0.0");
	}
#elif PLATFORM_IOS
	return FIOSPlatformMisc::GetProjectVersion();
#elif PLATFORM_WINDOWS
#if WITH_EDITOR
	FString ConfigFilePath = FPaths::Combine(FPaths::ProjectPluginsDir(), TEXT("AllInSDK/Source/ThirdParty/AllInSDKLibrary/x64/allin_config/config.ini"));
#else
	FString ConfigFilePath = FPaths::Combine(FPaths::ProjectDir(), TEXT("Binaries/Win64/allin_config/config.ini"));
#endif
	FString Version;
	GConfig->GetString(TEXT("App"),TEXT("game_version"),Version,ConfigFilePath);
	return Version;
#else
	return TEXT("1.0.0");
#endif
}
