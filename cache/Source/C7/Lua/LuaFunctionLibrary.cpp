// Fill out your copyright notice in the Description page of Project Settings.


#include "Lua/LuaFunctionLibrary.h"
#include "GenericPlatform/GenericPlatformOutputDevices.h"
#include "Misc/FileHelper.h"
#include "HAL/FileManager.h"
#include "Kismet/KismetSystemLibrary.h"
#include "GameFramework/InputSettings.h"
#include "DeviceProfiles/DeviceProfile.h"
#include "DeviceProfiles/DeviceProfileManager.h"
#include "HAL/IConsoleManager.h"
#include "Misc/AES.h"
#include "Serialization/ArchiveSaveCompressedProxy.h"
#include "Serialization/ArchiveLoadCompressedProxy.h"
// #if PLATFORM_IOS
//#include "IXcodeGPUDebuggerPlugin.h"
#include "XcodeGPUDebuggerPluginModule.h"
// #endif


#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#if PLATFORM_WINDOWS || PLATFORM_MAC
#include "DesktopPlatformModule.h"
#include "IDesktopPlatform.h"
#endif
#include "HttpModule.h"
#include "Interfaces/IHttpResponse.h"

DEFINE_LOG_CATEGORY_STATIC(LogLuaFunction, Log, All);

FString ULuaFunctionLibrary::GetScriptRootPath()
{
	const FString SourceMainFile = FPaths::ProjectContentDir() / FString("Script") / FString("Gameplay/GameInit/Main.lua");
	if (IFileManager::Get().FileExists(*SourceMainFile))
		return  FPaths::ConvertRelativePathToFull(FPaths::ProjectContentDir() + TEXT("Script/"));
	else
		return FPaths::ConvertRelativePathToFull(FPaths::ProjectContentDir() + TEXT("ScriptOPCode/"));
}

bool ULuaFunctionLibrary::IsEditorFromUGS()
{
#if WITH_EDITOR
	FString BuildVersionFilePath = FPaths::EngineDir() / TEXT("Build/Build.version");
	if (IFileManager::Get().FileExists(*BuildVersionFilePath))
	{
		FString JsonString;
		if (FFileHelper::LoadFileToString(JsonString, *BuildVersionFilePath))
		{
			TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonString);
			TSharedPtr<FJsonObject> JsonObject;
			if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
			{
				int32 Changelist = JsonObject->GetIntegerField(TEXT("Changelist"));
				int32 CompatibleChangelist = JsonObject->GetIntegerField(TEXT("CompatibleChangelist"));
				if (Changelist > 0 && CompatibleChangelist > 0 && Changelist > CompatibleChangelist)
				{
					return true;
				}
			}
		}
	}
#endif

	return false;
}

bool ULuaFunctionLibrary::IsLuaByteCodeMode()
{
#if LUA_BYTE_CODE_MODE
	return true;
#else
	return false;	
#endif
}

FString ULuaFunctionLibrary::LoadFileUnderScript(const FString& RelativePath)
{
	const FString ContentDir = FPaths::ProjectContentDir();

#if WITH_EDITOR
	const FString SourceFullPath = FPaths::Combine(ContentDir, TEXT("Script"), RelativePath);
	if (IFileManager::Get().FileExists(*SourceFullPath))
	{
		FString Result;
		FFileHelper::LoadFileToString(Result, *SourceFullPath);
		UE_LOG(LogTemp, Log, TEXT("Load Lua File Succ. File=%s. Content.Num=%d"), *SourceFullPath, Result.Len());		
		return Result;
	}
#else
	const FString SourceFullPath = FPaths::Combine(FPaths::ProjectPersistentDownloadDir(), TEXT("Script"), RelativePath);
	if (IFileManager::Get().FileExists(*SourceFullPath))
	{
		FString Result;
		FFileHelper::LoadFileToString(Result, *SourceFullPath);
		UE_LOG(LogTemp, Log, TEXT("Load Lua File Succ. File=%s. Content.Num=%d"), *SourceFullPath, Result.Len());		
		return Result;
	}
#endif
	
	const FString FullPath = FPaths::Combine(ContentDir, TEXT("ScriptOPCode"), RelativePath);
	if (IFileManager::Get().FileExists(*FullPath))
	{
		FString Result;
		FFileHelper::LoadFileToString(Result, *FullPath);
		UE_LOG(LogTemp, Log, TEXT("Load Lua File Succ. File=%s. Content.Num=%d"), *FullPath, Result.Len());		
		return Result;
	}
	UE_LOG(LogTemp, Log, TEXT("Load Lua File Failed. File=%s"), *FullPath);
	return FString();
}

TArray<uint8> ULuaFunctionLibrary::LoadBinaryUnderScript(const FString& RelativePath)
{
	TArray<uint8> Ret;
	const FString ContentDir = FPaths::ProjectContentDir();
#if WITH_EDITOR
	const FString SourceFullPath = FPaths::Combine(ContentDir, TEXT("Script"), RelativePath);
	if (IFileManager::Get().FileExists(*SourceFullPath))
	{
		TArray<uint8> BinData;
		FFileHelper::LoadFileToArray(BinData, *SourceFullPath);
		Ret = BinData;		
		UE_LOG(LogTemp, Log, TEXT("Load Lua File Succ. File=%s. Content.Num=%d"), *SourceFullPath, Ret.Num());		
		return Ret;
	}
#endif
	
	const FString FullPath = FPaths::Combine(ContentDir, TEXT("ScriptOPCode"), RelativePath);
	if (IFileManager::Get().FileExists(*FullPath))
	{
		TArray<uint8> BinData;
		FFileHelper::LoadFileToArray(BinData, *FullPath);
		Ret = BinData;		
		UE_LOG(LogTemp, Log, TEXT("Load Lua File Succ. File=%s. Content.Num=%d"), *FullPath, Ret.Num());		
		return Ret;
	}
	UE_LOG(LogTemp, Log, TEXT("Load Lua File Failed. File=%s"), *FullPath);
	return Ret;
}

FString ULuaFunctionLibrary::LoadFile(const FString& FullPath)
{
	if (IFileManager::Get().FileExists(*FullPath))
	{
		FString Result;
		FFileHelper::LoadFileToString(Result, *FullPath);
		return Result;
	}
	return FString();
}

bool ULuaFunctionLibrary::FindFiles(const FString& Directory, TArray<FString>& FoundFiles)
{
	IFileManager::Get().FindFiles(FoundFiles, *Directory);

	return FoundFiles.Num() > 0;
}

bool ULuaFunctionLibrary::FindDirectories(const FString& Directory, TArray<FString>& FoundDirectories)
{
	IFileManager::Get().FindFiles(FoundDirectories, *(Directory / TEXT("*")), false, true);
	return FoundDirectories.Num() > 0;
}


void ULuaFunctionLibrary::RunLuaFile(const FString& Filename)
{
	// bool bCreate = false;
	// {
	// 	lua_State* L = UnLua::GetState();
	// 	bCreate = !L;
	// }


	//if (FLuaContext* LuaContext = FLuaContext::Create())
	//{
	//	if (bCreate)
	//	{
	//		LuaContext->SetEnable(true);
	//	}
	//	lua_State* L = UnLua::GetState();
	//	//dofile path not working
	//	//luaL_dofile(L, TCHAR_TO_ANSI(*Filename));
	//	//lua_pushstring(L, "require");
	//	{
	//		FLuaAutoStack AutoStack;
	//		lua_getglobal(L, "require");
	//		lua_pushstring(L, TCHAR_TO_ANSI(*Filename));
	//		lua_pcall(L, 1, LUA_MULTRET, 0);
	//	}
	//	if (bCreate)
	//	{
	//		LuaContext->SetEnable(false);
	//	}
	//}
}

int ULuaFunctionLibrary::GetFileLineCountUnderScript(const FString& RelativePath)
{
	const FString ContentDir = FPaths::ProjectContentDir();
#if WITH_EDITOR
	const FString SourceFullPath = FPaths::Combine(ContentDir, TEXT("Script"), RelativePath);
	if (IFileManager::Get().FileExists(*SourceFullPath))
	{
		FString Result;
		TArray<FString> FileContents;
		FFileHelper::LoadFileToStringArray(FileContents, *SourceFullPath);
		return FileContents.Num();
	}
#endif
	const FString FullPath = FPaths::Combine(ContentDir, TEXT("ScriptOPCode"), RelativePath);
	if (IFileManager::Get().FileExists(*FullPath))
	{
		FString Result;
		TArray<FString> FileContents;
		FFileHelper::LoadFileToStringArray(FileContents, *FullPath);
		return FileContents.Num();
	}
	return 0;
}


UClass* ULuaFunctionLibrary::GetSuperClass(UClass* Class)
{
	if (Class)
	{
		return Class->GetSuperClass();
	}
	return nullptr; 
}

void ULuaFunctionLibrary::SaveStringToFile(const FString Content)
{
	FString FileName = FPaths::Combine(FPaths::ProjectSavedDir(), TEXT("BattleLog/BattleLog.txt"));
	FFileHelper::SaveStringToFile(Content, *FileName, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(),FILEWRITE_Append);
}

FString ULuaFunctionLibrary::GetFilePath(const FString& RelativePath)
{
	FString FullPath = FPaths::ConvertRelativePathToFull(RelativePath);
	return FullPath;
}

bool ULuaFunctionLibrary::ScriptFileExists(const FString& RelativePath)
{
	FString Path = RelativePath.Replace(TEXT("."), TEXT("/"));
#if WITH_EDITOR
	const FString FileOfSource = FPaths::Combine(FPaths::ProjectContentDir(), TEXT("Script"), Path) + FString(".lua");
	if (IFileManager::Get().FileExists(*FileOfSource))
	{
		return true;
	}
#else
	// Cooking模式下优先判断PersistentDownloadDir目录有没有脚本,
	const FString FileOfDownload = FPaths::Combine(FPaths::ProjectPersistentDownloadDir(), TEXT("Script"), Path) + FString(".lua");
	if (IFileManager::Get().FileExists(*FileOfDownload))
	{
		return true;
	}
#endif
	
	const FString FileOfOPCode = FPaths::Combine(FPaths::ProjectContentDir(), TEXT("ScriptOPCode"), Path) + FString(".luac");
	if (!IFileManager::Get().FileExists(*FileOfOPCode))
	{
		return false;
	}
	return true;
}


bool ULuaFunctionLibrary::DirectoryExists(const FString& InDirectory)
{
	return IFileManager::Get().DirectoryExists(*InDirectory);
}

bool ULuaFunctionLibrary::MakeDirectory(const FString& Path, bool Tree)
{
	return IFileManager::Get().MakeDirectory(*Path, Tree);
}


FString ULuaFunctionLibrary::ConvertToAbsolutePathForExternalAppForRead(const FString& RelativePath)
{
	IPlatformFile& PlatformFile = FPlatformFileManager::Get().GetPlatformFile();
	FString AbsPath = PlatformFile.ConvertToAbsolutePathForExternalAppForRead(*RelativePath);
	return AbsPath;
}

FString ULuaFunctionLibrary::GetAbsoluteLogFilename()
{
	return FGenericPlatformOutputDevices::GetAbsoluteLogFilename();
}

void ULuaFunctionLibrary::GetActorLocation(AActor* actor, float& X, float& Y, float& Z)
{
	if (actor != nullptr)
	{
		const FVector Location = actor->K2_GetActorLocation();
		X = Location.X;
		Y = Location.Y;
		Z = Location.Z;	
	}
	else
	{
		X = 0.0f;
     	Y = 0.0f;
     	Z = 0.0f;	
	}
	
}

void ULuaFunctionLibrary::GetActorRotation(AActor* actor, float& Pitch, float& Yaw, float& Roll)
{
	if (actor != nullptr)
	{
		const FRotator Rotation = actor->K2_GetActorRotation();
		Pitch = Rotation.Pitch;
		Yaw = Rotation.Yaw;
		Roll = Rotation.Roll;	
	}
	else
	{
		Pitch = 0.0f;
        Yaw = 0.0f;
        Roll = 0.0f;	
	}
	
}

void ULuaFunctionLibrary::GetActorForwardVector(AActor* actor, float& X, float& Y, float& Z)
{
	if(actor !=nullptr)
	{
		const FRotator Rotation = actor->K2_GetActorRotation();
		FQuat QuatRotation = FQuat(Rotation);
		FVector Fwd = QuatRotation.GetForwardVector();
		X = Fwd.X;
		Y = Fwd.Y;
		Z = Fwd.Z;	
	}
	else
	{
		X = 0.0f;
		Y = 0.0f;
		Z = 0.0f;	
	}
	
}

void ULuaFunctionLibrary::IOSGPUCaptureFrame()
{
#if PLATFORM_IOS || PLATFORM_TVOS
	UE_LOG(LogTemp, Log, TEXT("[ULuaFunctionLibrary] IOSGPUCaptureFrame Start"));
    FXcodeGPUDebuggerPluginModule& PluginModule = FModuleManager::GetModuleChecked<FXcodeGPUDebuggerPluginModule>("KGGPUFrameCapturePlugin");
	PluginModule.CaptureFrame(nullptr, IRenderCaptureProvider::ECaptureFlags_Launch, FString());
	UE_LOG(LogTemp, Log, TEXT("[ULuaFunctionLibrary] IOSGPUCaptureFrame End"));
#endif
}

void ULuaFunctionLibrary::BeginIOSGPUCapture()
{
	UE_LOG(LogTemp, Log, TEXT("[ULuaFunctionLibrary] BeginIOSGPUCapture Start"));
	FXcodeGPUDebuggerPluginModule& PluginModule = FModuleManager::GetModuleChecked<FXcodeGPUDebuggerPluginModule>("KGGPUFrameCapturePlugin");
	ENQUEUE_RENDER_COMMAND(IOSGPUCaptureRenderCommand)(
		[&PluginModule](FRHICommandListImmediate& RHICmdList)
		{
			// Use RHICmdList to perform rendering operations
			FString InFileName = FDateTime::Now().ToString();
			PluginModule.BeginCapture(&RHICmdList,IRenderCaptureProvider::ECaptureFlags_Launch, InFileName);
		});
	UE_LOG(LogTemp, Log, TEXT("[ULuaFunctionLibrary] BeginIOSGPUCapture End"));
}

void ULuaFunctionLibrary::EndIOSGPUCapture()
{
	UE_LOG(LogTemp, Log, TEXT("[ULuaFunctionLibrary] EndIOSGPUCapture Start"));
	FXcodeGPUDebuggerPluginModule& PluginModule = FModuleManager::GetModuleChecked<FXcodeGPUDebuggerPluginModule>("KGGPUFrameCapturePlugin");
	ENQUEUE_RENDER_COMMAND(IOSGPUCaptureRenderCommand)(
		[&PluginModule](FRHICommandListImmediate& RHICmdList)
		{
			// Use RHICmdList to perform rendering operations
			PluginModule.EndCapture(&RHICmdList);
		});
	UE_LOG(LogTemp, Log, TEXT("[ULuaFunctionLibrary] EndIOSGPUCapture End"));
}

int32 ULuaFunctionLibrary::GetEngineObjectArrayCapacity()
{
	return GUObjectArray.GetObjectArrayCapacity();
}

int32 ULuaFunctionLibrary::GetEngineObjectArrayNum()
{
	return GUObjectArray.GetObjectArrayNum();
}

void ULuaFunctionLibrary::ChangeUseMouseForTouchSetting(bool value)
{
	UInputSettings* Setting = UInputSettings::GetInputSettings();
	Setting->bUseMouseForTouch = value;
	FSlateApplication::Get().SetGameIsFakingTouchEvents(value);
}

void ULuaFunctionLibrary::ChangeConsoleVariableOfInt(FString ValueName, int Value)
{
	IConsoleVariable* CVar = IConsoleManager::Get().FindConsoleVariable(*ValueName);
	if(CVar)
	{
		CVar->Set(Value);
	}
}


FString ULuaFunctionLibrary::OpenFileDialog() {
#if PLATFORM_WINDOWS || PLATFORM_MAC
	IDesktopPlatform* DesktopPlatform = FDesktopPlatformModule::Get();
	if (DesktopPlatform) {
		TArray<FString> OutFileNames;
		const FString FileTypes = TEXT("Image Files (*.jpg;*.jpeg;*.png;*.bmp)|*.jpg;*.jpeg;*.png;*.bmp");
		const FString Title = TEXT("Select an Image File");
		DesktopPlatform->OpenFileDialog(
			nullptr,
			Title,
			FString(),
			FString(),
			FileTypes,
			EFileDialogFlags::None,
			OutFileNames
		);

		if (OutFileNames.Num() > 0) {
			FString ResultFilePath = OutFileNames[0];
			if (!FPaths::IsRelative(ResultFilePath)) {
				return ResultFilePath;
			}
			else {
				FString AbsolutePath = FPaths::ConvertRelativePathToFull(ResultFilePath);
				return AbsolutePath;
			}
		}
		else {
			return FString();
		}
	}
#endif
	return FString();
}


int32 ULuaFunctionLibrary::GetDeviceDefaultProfileCVar(const FString& CVarName)
{
	UDeviceProfile* ActiveProfile = UDeviceProfileManager::Get().GetActiveProfile();
	if (ActiveProfile == nullptr)
	{
		return 0;
	}

	// 实现来自 UDeviceProfile::GetCVarValue(const FString& CVarName)
	if (ActiveProfile->CVars.Num() != 0)
	{
		auto Index = ActiveProfile->CVars.IndexOfByPredicate(
			[&CVarName](const FString& CVar) {
				FString Name;
				CVar.Split(TEXT("="), &Name, NULL);
				return Name == CVarName;
			});

		if (Index != INDEX_NONE)
		{
			FString Value;
			ActiveProfile->CVars[Index].Split(TEXT("="), NULL, &Value);
			return FCString::Atoi(*Value);
		}
	}

	// ActiveProfile没有CVars就用ParentProfile的CVar
	// 由于部分平台上配置层级不只两层，需要一直递归直到：
	// 1. CVar不为空，返回推荐配置
	// 2. ParentProfile为NULL，返回0，报错
	// 3. 超出递归上限，返回0，报错
	const int32 PROFILE_RECUR_MAX = 10;
	int32 CurrentRecur = 0;
	UDeviceProfile* ParentProfileActive = ActiveProfile->GetParentProfile();
	while (ParentProfileActive!= nullptr && CurrentRecur < PROFILE_RECUR_MAX)
	{
		if (ParentProfileActive->CVars.Num() != 0)
		{
			auto Index = ParentProfileActive->CVars.IndexOfByPredicate(
			[&CVarName](const FString& CVar) {
				FString Name;
				CVar.Split(TEXT("="), &Name, NULL);
				return Name == CVarName;
			});
			if (Index != INDEX_NONE)
			{
				FString Value;
				ParentProfileActive->CVars[Index].Split(TEXT("="), NULL, &Value);
				return FCString::Atoi(*Value);
			}
		}
		// CVar为空，继续递归
		ParentProfileActive = ParentProfileActive->GetParentProfile();
		CurrentRecur++;
	}
	if (CurrentRecur >= PROFILE_RECUR_MAX)
	{
		UE_LOG(LogTemp, Error, TEXT("Exceeded maximum recursion depth while searching for CVar %s."), *CVarName);
	}
	else
	{
		UE_LOG(LogTemp,
			Error,
			TEXT("Unable to find the default graphics profile CVar %s, are we missing the configuration for this device?"),
			*CVarName);
	}
	return 0;
}

void ULuaFunctionLibrary::DownloadImage(const FString& Url, const FString& SavePath)
{
	// 获取 HTTP 模块
	FHttpModule* Http = &FHttpModule::Get();

	// 创建 HTTP 请求
	TSharedRef<IHttpRequest, ESPMode::ThreadSafe> HttpRequest = Http->CreateRequest();
	HttpRequest->SetURL(Url);
	HttpRequest->SetVerb(TEXT("GET"));

	// 设置响应处理回调
	HttpRequest->OnProcessRequestComplete().BindLambda([SavePath](FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful)
		{
			if (bWasSuccessful && Response.IsValid())
			{
				// 获取响应数据
				const TArray<uint8>& ImageData = Response->GetContent();

				// 将数据保存到本地文件
				if (FFileHelper::SaveArrayToFile(ImageData, *SavePath))
				{
					UE_LOG(LogLuaFunction, Log, TEXT("Image saved successfully to %s"), *SavePath);
				}
				else
				{
					UE_LOG(LogLuaFunction, Warning, TEXT("Failed to save image to %s"), *SavePath);
				}
			}
			else
			{
				UE_LOG(LogLuaFunction, Warning, TEXT("Failed to download image from %s"), *Request->GetURL());
			}
		});

	// 发送请求
	HttpRequest->ProcessRequest();
}

// 获取当前设备的抗锯齿模式
int32 ULuaFunctionLibrary::GetAntiAliasingMode(bool bPcMode)
{
	static IConsoleVariable* CVar;
	if (bPcMode)
	{
		CVar = IConsoleManager::Get().FindConsoleVariable(TEXT("r.AntiAliasingMethod"));
		if (CVar)
		{
			return CVar->GetInt();
		}
	}
	else // 移动端使用不同的参数
	{
		CVar = IConsoleManager::Get().FindConsoleVariable(TEXT("r.Mobile.AntiAliasing"));
		if (CVar)
		{
			return CVar->GetInt();
		}
	}
	return EAntiAliasingMethod::AAM_None;
}


FString ULuaFunctionLibrary::EncryptText(const FString& OriginalText)
{

	// 将文本转换为字节数组
	TArray<uint8> ByteArray;
	FTCHARToUTF8 Convert(*OriginalText);
	ByteArray.Append((uint8*)Convert.Get(), Convert.Length());

	// 创建一个 AES 密钥
	FAES::FAESKey Key;
	// 为密钥分配 16 字节的值（128 位）
	FMemory::Memset(Key.Key, 0x00, sizeof(Key.Key));
	Key.Key[0] = 0x01; // 示例：设置密钥的第一个字节

	// 填充字节数组到16字节的倍数
	int32 Padding = FAES::AESBlockSize - (ByteArray.Num() % FAES::AESBlockSize);
	ByteArray.AddZeroed(Padding);

	// 加密
	FAES::EncryptData(ByteArray.GetData(), ByteArray.Num(), Key);

	// 解密
	//FAES::DecryptData(ByteArray.GetData(), ByteArray.Num(), Key);

	// 将字节数组转换回文本
	//FString DecryptedText = FString(UTF8_TO_TCHAR(ByteArray.GetData()));
	FString DecryptedText = FBase64::Encode(ByteArray.GetData(), ByteArray.Num());
	// 输出结果
	UE_LOG(LogLuaFunction, Log, TEXT("Original Text: %s"), *OriginalText);
	UE_LOG(LogLuaFunction, Log, TEXT("Decrypted Text: %s"), *DecryptedText);

	return DecryptedText;
}

FString ULuaFunctionLibrary::DecryptText(const FString& OriginalText)
{

	// 将文本转换为字节数组
	TArray<uint8> ByteArray;

	// 解码 Base64 字符串
	bool bSuccess = FBase64::Decode(OriginalText, ByteArray);
	if (bSuccess)
	{
		// 解码成功，ByteArray 现在包含原始的字节数据
		UE_LOG(LogLuaFunction, Log, TEXT("解码成功！字节数组大小为: %d"), ByteArray.Num());
	}
	else
	{
		// 解码失败
		UE_LOG(LogLuaFunction, Error, TEXT("Base64 解码失败！"));
		return "";
	}
	// 创建一个 AES 密钥
	FAES::FAESKey Key;
	// 为密钥分配 16 字节的值（128 位）
	FMemory::Memset(Key.Key, 0x00, sizeof(Key.Key));
	Key.Key[0] = 0x01; // 示例：设置密钥的第一个字节

	// 解密
	FAES::DecryptData(ByteArray.GetData(), ByteArray.Num(), Key);

	// 将字节数组转换回文本
	FString DecryptedText = FString(UTF8_TO_TCHAR(ByteArray.GetData()));

	// 输出结果
	UE_LOG(LogLuaFunction, Log, TEXT("Original Text: %s"), *OriginalText);
	UE_LOG(LogLuaFunction, Log, TEXT("Decrypted Text: %s"), *DecryptedText);
	return DecryptedText;
}