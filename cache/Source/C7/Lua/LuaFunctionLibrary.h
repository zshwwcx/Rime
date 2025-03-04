// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "LuaFunctionLibrary.generated.h"

/**
 * 
 */
UCLASS()
class C7_API ULuaFunctionLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:

	UFUNCTION()
	static FString GetScriptRootPath();

	UFUNCTION()
	static bool IsEditorFromUGS();
	
	UFUNCTION()
	static bool IsLuaByteCodeMode();

	UFUNCTION()
	static FString LoadFileUnderScript(const FString& RelativePath);

	UFUNCTION()
	static TArray<uint8> LoadBinaryUnderScript(const FString& RelativePath);

	UFUNCTION()
	static FString LoadFile(const FString& FullPath);

	UFUNCTION()
	static bool FindFiles(const FString& Directory, TArray<FString>& FoundFiles);

	UFUNCTION()
	static bool FindDirectories(const FString& Directory, TArray<FString>& FoundDirectories);

	UFUNCTION()
	static int GetFileLineCountUnderScript(const FString& RelativePath);

	UFUNCTION(BlueprintCallable, CallInEditor)
	static void RunLuaFile(const FString& Filename);

	UFUNCTION()
	static UClass* GetSuperClass(UClass* Class);

	UFUNCTION()
	static void SaveStringToFile(const FString Content);

	UFUNCTION()
	static FString GetFilePath(const FString& RelativePath);

	UFUNCTION()
	static bool ScriptFileExists(const FString& RelativePath);

	UFUNCTION()
	static bool DirectoryExists(const FString& InDirectory);

	UFUNCTION()
	static bool MakeDirectory(const FString& Path, bool Tree = false);

	UFUNCTION()
	static FString ConvertToAbsolutePathForExternalAppForRead(const FString& RelativePath);

	UFUNCTION()
	static FString GetAbsoluteLogFilename();

	UFUNCTION()
	static void GetActorLocation(AActor* actor, float& X, float& Y, float& Z);
	
	UFUNCTION()
	static void GetActorRotation(AActor* actor, float& Pitch, float& Yaw, float& Roll);
	
	UFUNCTION()
	static void GetActorForwardVector(AActor* actor,float& X, float& Y, float& Z);
	
	UFUNCTION()
	static void IOSGPUCaptureFrame();
	
	UFUNCTION()
	static void BeginIOSGPUCapture();

	UFUNCTION()
	static void EndIOSGPUCapture();

	UFUNCTION()
    static int32 GetEngineObjectArrayCapacity();
    
    UFUNCTION()
    static int32 GetEngineObjectArrayNum();
	
	UFUNCTION()
	static void ChangeUseMouseForTouchSetting(bool value);

	UFUNCTION()
	static void ChangeConsoleVariableOfInt(FString ValueName, int Value);

	UFUNCTION()
	static FString OpenFileDialog();

	UFUNCTION()
	static int32 GetDeviceDefaultProfileCVar(const FString& CVarName);

	UFUNCTION()
	static void DownloadImage(const FString& Url, const FString& SavePath);

	UFUNCTION()
	static int32 GetAntiAliasingMode(bool bPcMode);

	UFUNCTION()
	static FString EncryptText(const FString& OriginalText);

	UFUNCTION()
	static FString DecryptText(const FString& OriginalText);

};
