// Fill out your copyright notice in the Description page of Project Settings.


#include "Misc/C7FunctionLibrary.h"
#include "Engine/LevelStreaming.h"
#include "Kismet/GameplayStatics.h"
#include <Misc/FileHelper.h>
#include "HttpModule.h"
#if WITH_EDITOR
#include "LevelEditorViewport.h"
#endif
#include "Interfaces/IHttpResponse.h"
// #include "Engine/LevelStreamingKismet.h"
#include "Kismet/KismetSystemLibrary.h"

#include "NavigationPath.h"
#include "NavigationSystem.h"
#include "NavFilters/NavigationQueryFilter.h"

#include "MovieSceneSequencePlayer.h"
#include "Misc/FrameTime.h"
#include "Misc/FrameNumber.h"
#include "LevelSystem/LogicActor.h"
#include "GenericPlatform/GenericPlatformOutputDevices.h"

#include "NavMeshWayPointSystem/WayPointSystem.h"
#include "Character/BaseCharacter.h"
#include "Engine/UserInterfaceSettings.h"

#include "Engine/IndirectLightOverwriteVolume.h"

#if STATS
#include "CoreMinimal.h"
#include "Stats/StatsData.h"
#include "Engine/Engine.h"
#include "Stats/Stats.h"
#endif

#include "LuaState.h"
#include "Engine/LevelStreamingDynamic.h"
#include "Misc/CrashCollector.h"
#include "Slate/SceneViewport.h"
#include "Misc/ObjCrashCollector.h"
#include "Opt/OptFunctionLibrary.h"
#include "JsonObjectConverter.h"
#include "EngineUtils.h"
#include "PakUpdateSubsystem.h"
#include "ComplexDetection/ScreenActorCounter.h"
#include "ProfilingDebugging/C7FrameStatsFile.h"

TArray<FName> UC7FunctionLibrary::GetBindingTags(ULevelSequence* Sequence)
{
	TArray<FName> Tags;
	Sequence->GetMovieScene()->AllTaggedBindings().GetKeys(Tags);
	return Tags;
}

void UC7FunctionLibrary::GetAllSpawnableObjectTemplate(UMovieSceneSequence* Sequence, UMovieSceneSequencePlayer* SequencePlayer, TArray<FMovieSceneBindingTagTemplate>& OutSpawnableObjectTemplates)
{
	if (!Sequence || !SequencePlayer)
	{
		return;
	}
	if (UMovieScene* MovieScene = Sequence->GetMovieScene())
	{
		const TMap<FName, FMovieSceneObjectBindingIDs>& BindingGroups = MovieScene->AllTaggedBindings();
		for (auto[Tag, Bindings] : BindingGroups)
		{
			for (FMovieSceneObjectBindingID Binding : Bindings.IDs)
			{
				if (Binding.IsValid())
				{
					if (SequencePlayer)
					{
						FMovieSceneSequenceID SequenceID = Binding.ResolveSequenceID(MovieSceneSequenceID::Root, *SequencePlayer);
						if (UMovieSceneSequence* SubSequence = SequencePlayer->State.FindSequence(SequenceID))
						{
							if (UMovieScene* SubMovieScene = SubSequence->GetMovieScene())
							{
								if (FMovieSceneSpawnable* Spawnable = SubMovieScene->FindSpawnable(Binding.GetGuid()))
								{
									UObject* Template = Spawnable->GetObjectTemplate();
									FMovieSceneBindingTagTemplate BindingTemplate(Tag, Binding, Template);
									OutSpawnableObjectTemplates.Add(BindingTemplate);
								}
							}
						}
					}
				}
			}
		}
	}
}

FString UC7FunctionLibrary::GetMachineId()
{
	return FPlatformMisc::GetLoginId();
	// return FString();
}

FString UC7FunctionLibrary::GetCurrentLevelName(const UObject* WorldContext)
{
	if (WorldContext)
	{
		if (UWorld* World = WorldContext->GetWorld())
		{
			return World->GetMapName();
		}
	}
	return FString();
}

void UC7FunctionLibrary::GetLoadingSubLevels(TArray<FString>& SubLevels, UObject* WorldContext)
{
	if (WorldContext != nullptr)
	{
		UWorld* World = GEngine->GetWorldFromContextObject(WorldContext, EGetWorldErrorMode::LogAndReturnNull);
		if (World)
		{
			FSeamlessTravelHandler& SeamlessTravelHandler = GEngine->SeamlessTravelHandlerForWorld(World);
			const UWorld* loadedWorld = SeamlessTravelHandler.GetLoadedWorld();
			if (loadedWorld)
			{
				auto StreamingLevels = loadedWorld->GetStreamingLevels();
				for (ULevelStreaming* LevelStreaming : StreamingLevels)
				{
					if (LevelStreaming && LevelStreaming->ShouldBeAlwaysLoaded())
					{
						FString PkgName = LevelStreaming->GetWorldAssetPackageName();
						// UE_LOG(LogTemp,Warning,TEXT("LevelStreaming->GetWorldAssetPackageName(); %s"),*PkgName)
						SubLevels.Add(PkgName);
					}
				}
			}
		}
	}
}

bool UC7FunctionLibrary::MainWorldLoadComplete(UObject* WorldContext)
{
	if (WorldContext != nullptr)
	{
		UWorld* World = GEngine->GetWorldFromContextObject(WorldContext, EGetWorldErrorMode::LogAndReturnNull);
		if (World)
		{
			FSeamlessTravelHandler& SeamlessTravelHandler = GEngine->SeamlessTravelHandlerForWorld(World);
			const UWorld* loadedWolrd = SeamlessTravelHandler.GetLoadedWorld();
			return loadedWolrd != nullptr;
		}
	}
	return false;
}


float UC7FunctionLibrary::GetLoadingProgress(const FString& PackageName, UObject* WorldContext)
{
	// FURL TravelURL(&GEngine->LastURLFromWorld(world), *SeamlessTravelURL,  TRAVEL_Absolute );

	if (WorldContext != nullptr)
	{
		UWorld* World = GEngine->GetWorldFromContextObject(WorldContext, EGetWorldErrorMode::LogAndReturnNull);
		if (World)
		{
#if WITH_EDITOR
			FWorldContext& Context = GEngine->GetWorldContextFromWorldChecked(World);
			if (GIsEditor)
			{
				int32 PIEInstanceID = Context.PIEInstance;
				FString PIEPackageName = UWorld::ConvertToPIEPackageName(PackageName, PIEInstanceID);
				return GetAsyncLoadPercentage(FName(PIEPackageName));
			}
#endif

			return GetAsyncLoadPercentage(FName(PackageName));
		}
	}
	return -1;
}


FString UC7FunctionLibrary::ConvertToPIEPackageName(const FString& PackageName, UObject* WorldContext)
{
	UWorld* World = GEngine->GetWorldFromContextObject(WorldContext, EGetWorldErrorMode::LogAndReturnNull);
	if (World)
	{
#if WITH_EDITOR
		FWorldContext& Context = GEngine->GetWorldContextFromWorldChecked(World);
		if (GIsEditor)
		{
			int32 PIEInstanceID = Context.PIEInstance;
			FString PIEPackageName = UWorld::ConvertToPIEPackageName(PackageName, PIEInstanceID);
			return PIEPackageName;
		}
#endif
	}
	return PackageName;
}


FString UC7FunctionLibrary::StripPIEPackageName(const FString& PackageName, UObject* WorldContext)
{
	UWorld* World = GEngine->GetWorldFromContextObject(WorldContext, EGetWorldErrorMode::LogAndReturnNull);
	if (World)
	{
#if WITH_EDITOR
		FWorldContext& Context = GEngine->GetWorldContextFromWorldChecked(World);
		if (GIsEditor)
		{
			int32 PIEInstanceID = Context.PIEInstance;
			FString PIEPackageName = UWorld::StripPIEPrefixFromPackageName(PackageName, UWorld::BuildPIEPackagePrefix(PIEInstanceID));
			return PIEPackageName;
		}
#endif
	}
	return PackageName;
}


// void UC7FunctionLibrary::RenameToPIEWorld(UObject* WorldContext)
// {
// 	UWorld* World = GEngine->GetWorldFromContextObject(WorldContext, EGetWorldErrorMode::LogAndReturnNull);
// 	if (World)
// 	{
// 		
// 		if (World->WorldComposition!= nullptr)
// 		{
// 			FWorldContext &Context = GEngine->GetWorldContextFromWorldChecked(World);
// 			int32 PIEInstanceID = Context.PIEInstance;
// 			// World->WorldComposition->ReinitializeForPIE();
// 			World->RenameToPIEWorld(PIEInstanceID);
// 			// World->PersistentLevel->FixupForPIE(PIEInstanceID);
// 		}
// 	}
// }


void UC7FunctionLibrary::SetPauseLoadingAtMidpoint(UObject* WorldContext, bool bNowPaused)
{
	UWorld* World = GEngine->GetWorldFromContextObject(WorldContext, EGetWorldErrorMode::LogAndReturnNull);
	if (World)
	{
		World->SetSeamlessTravelMidpointPause(bNowPaused);
	}
}

// FString UC7FunctionLibrary::GetLevelData(const FString& Filename)
// {
// 	FString JsonStr = "";
// 	FString AbsFileName = FPaths::ProjectContentDir() / TEXT("Script/Config/MapData/") / Filename;
// 	FFileHelper::LoadFileToString(JsonStr, *AbsFileName);
//
// 	return JsonStr;
// }

static TArray<FString> UploadFileNames;
static bool isUploading;
static FString UploadUrl;
void UC7FunctionLibrary::CompressAndUploadSaved(const FString& URL)
{
	if (isUploading)
	{
		return;
	}
	UploadUrl = URL + "&MachineId=" + GetMachineId();
	UploadFileNames.Empty();
	FString SavedFullPath = IFileManager::Get().ConvertToAbsolutePathForExternalAppForRead(*FPaths::ProjectSavedDir());
	FString LogsDirPath = SavedFullPath / TEXT("Logs");
	IFileManager::Get().FindFilesRecursive(UploadFileNames, ToCStr(LogsDirPath), TEXT("*"), true, false, false);
	FString CrashesDirPath = SavedFullPath / TEXT("Crashes");
	IFileManager::Get().FindFilesRecursive(UploadFileNames, ToCStr(CrashesDirPath), TEXT("*"), true, false, false);
	FString ProfilingDirPath = SavedFullPath / TEXT("Profiling");
	IFileManager::Get().FindFilesRecursive(UploadFileNames, ToCStr(ProfilingDirPath), TEXT("*"), true, false, false);

	if (!UploadFileNames.IsEmpty())
	{
		const auto HttpRequest = FHttpModule::Get().CreateRequest();
		HttpRequest->SetHeader(TEXT("Content-Type"), TEXT("application/octet-stream"));
		HttpRequest->SetVerb("POST");

		const int32& SavedFilePrefixIndex = UploadFileNames[0].Find("Saved");
		FString UploadName = "&UploadName=" + UploadFileNames[0].Mid(SavedFilePrefixIndex + 5, UploadFileNames[0].Len() - 1);
		HttpRequest->SetURL(UploadUrl + UploadName);
		bool result = HttpRequest->SetContentAsStreamedFile(UploadFileNames[0]);
		if (!result)
		{
			UE_LOG(LogTemp, Log, TEXT("load file failed %s"), *(UploadFileNames[0]));
			HttpRequest->SetContentAsString("");
		}
		HttpRequest->OnProcessRequestComplete().BindLambda([](FHttpRequestPtr InRequest, FHttpResponsePtr InResponse, bool bWasSuccessful)
		{
			OnResponseHttpHead(InRequest, InResponse, bWasSuccessful);
		});
		HttpRequest->ProcessRequest();
		isUploading = true;
	}
}

void UC7FunctionLibrary::GetViewportScreenshot(const FString& ImgPath, bool bShowUI)
{
	FScreenshotRequest::RequestScreenshot(ImgPath, bShowUI, false);
}

void UC7FunctionLibrary::QAFeedbackPost(const FString& Url, TMap<FString, FString> Contents,bool bIsBug, bool bAutoScreenshot,FString PicturePath)
{
	TSharedRef<IHttpRequest> HttpRequest = FHttpModule::Get().CreateRequest();
	HttpRequest->SetURL(Url);
	FString Boundary = "------------QAFeedbackPost" + FString::FromInt(FDateTime::Now().GetTicks());
	HttpRequest->SetHeader(TEXT("Content-Type"), TEXT("multipart/form-data; boundary=" + Boundary));
	HttpRequest->SetVerb(TEXT("POST"));
	TArray<uint8> RequestContent;
	FString BeginBoundry = "\r\n--" + Boundary + "\r\n";
	for (TPair<FString,FString> Item:Contents)
	{
		TArray<uint8> FileContent;
		RequestContent.Append((uint8*)TCHAR_TO_ANSI(*BeginBoundry), BeginBoundry.Len());
		FString FileHeader = FString::Printf(TEXT("Content-Disposition: form-data; name=\"%s\"\r\n\r\n%s"),*Item.Key,*Item.Value);
		FTCHARToUTF8 Convert(*FileHeader);
		TArray<uint8> output(reinterpret_cast<const uint8*>(Convert.Get()), Convert.Length());	
		RequestContent.Append(output);
	}
	if(bIsBug)
	{
		if(IFileHandle* FileHandle = FPlatformFileManager::Get().GetPlatformFile().OpenRead(*Contents["clog_path"],true))
		{
			RequestContent.Append((uint8*)TCHAR_TO_ANSI(*BeginBoundry), BeginBoundry.Len());
			int64 size = FileHandle->Size();
			int64 offset = size > 10 * 1024 * 1024 ? size - 10 * 1024 * 1024 : 0;
			FileHandle->Seek(offset);
			FString FileHeader = "Content-Disposition: form-data; name=\"C7.log\"; filename=\"C7.log\"\r\nContent-Type: text/plain\r\n\r\n";
			RequestContent.Append((uint8*)TCHAR_TO_ANSI(*FileHeader), FileHeader.Len());
			TArray<uint8> tempData;
			int32 FileSize = size - offset;
			uint8* FileBuffer = (uint8*)FMemory::Malloc(FileSize);
			FileHandle->Read(FileBuffer, FileSize);
			RequestContent.Append(FileBuffer,FileSize);
			FMemory::Free(FileBuffer);
		}
	}
	if(bAutoScreenshot)
	{
		TArray<uint8> FileContent;
		if (FFileHelper::LoadFileToArray(FileContent, *PicturePath))
		{
        	RequestContent.Append((uint8*)TCHAR_TO_ANSI(*BeginBoundry), BeginBoundry.Len());
			FString FileHeader = "Content-Disposition: form-data; name=\"qafeedback.png\"; filename=\"qafeedback.png\"\r\nContent-Type: image/png\r\n\r\n";
			RequestContent.Append((uint8*)TCHAR_TO_ANSI(*FileHeader), FileHeader.Len());
			RequestContent.Append(FileContent);			
		}
	}
	FString EndBoundary = "\r\n--" + Boundary + "--\r\n";
	RequestContent.Append((uint8*)TCHAR_TO_ANSI(*EndBoundary), EndBoundary.Len());
	HttpRequest->OnProcessRequestComplete().BindLambda([](FHttpRequestPtr HttpRequest, FHttpResponsePtr HttpResponse, bool bSucceeded) {
		if(bSucceeded && HttpResponse->GetResponseCode() == 200)
		{
			TSharedPtr<FJsonObject> RootObject;
			TSharedRef<TJsonReader<TCHAR>> Reader = TJsonReaderFactory<TCHAR>::Create(HttpResponse->GetContentAsString());
			if (FJsonSerializer::Deserialize(Reader, RootObject))
			{
				if(RootObject->GetIntegerField(TEXT("success")) == 1)
				{
					GEngine->AddOnScreenDebugMessage(-1, 4, FColor::Green, TEXT("Feedback success"));
					return;
				}
			}
		}
		GEngine->AddOnScreenDebugMessage(-1, 4, FColor::Yellow, TEXT("Feedback failure"));
	});
	HttpRequest->SetContent(RequestContent);
	HttpRequest->ProcessRequest();
}

void UC7FunctionLibrary::HttpPost(const FString& Url, TMap<FString, FString> Heads, const FString& Content, FHttpCallback Callback)
{
	TSharedRef<IHttpRequest> HttpRequest = FHttpModule::Get().CreateRequest();
	HttpRequest->SetURL(Url);
	HttpRequest->SetVerb(TEXT("POST"));
	TArray<uint8> RequestContent;
	FTCHARToUTF8 Convert(*Content);
	RequestContent.Append(reinterpret_cast<const uint8*>(Convert.Get()), Convert.Length());
	HttpRequest->SetContent(RequestContent);
	for (TPair<FString, FString> Item:Heads)
	{
		HttpRequest->SetHeader(*Item.Key, *Item.Value);
	}
	HttpRequest->OnProcessRequestComplete().BindLambda([Callback](FHttpRequestPtr HttpRequest, FHttpResponsePtr HttpResponse, bool bSucceeded) {
		Callback.ExecuteIfBound(bSucceeded && HttpResponse->GetResponseCode() == 200, HttpResponse->GetContentAsString());
	});
	HttpRequest->SetContent(RequestContent);
	HttpRequest->ProcessRequest();
}

void UC7FunctionLibrary::OnResponseHttpHead(FHttpRequestPtr InRequest, FHttpResponsePtr InResponse, bool bWasSuccessful)
{
	const int32& ResponseCode = InResponse->GetResponseCode();

	if (!UploadFileNames.IsEmpty())
	{
		if (bWasSuccessful)
		{
			UploadFileNames.RemoveAt(0);
			if (!UploadFileNames.IsEmpty())
			{
				const auto HttpRequest = FHttpModule::Get().CreateRequest();
				HttpRequest->SetHeader(TEXT("Content-Type"), TEXT("application/octet-stream"));
				HttpRequest->SetVerb("POST");

				const int32& SavedFilePrefixIndex = UploadFileNames[0].Find("Saved");
				FString UploadName = "&UploadName=" + UploadFileNames[0].Mid(SavedFilePrefixIndex + 5, UploadFileNames[0].Len() - 1);
				HttpRequest->SetURL(UploadUrl + UploadName);
				bool result = HttpRequest->SetContentAsStreamedFile(UploadFileNames[0]);
				if (!result)
				{
					UE_LOG(LogTemp, Log, TEXT("load file failed %s"), *(UploadFileNames[0]));
					HttpRequest->SetContentAsString("");
				}
				HttpRequest->OnProcessRequestComplete().BindLambda([](FHttpRequestPtr InRequest, FHttpResponsePtr InResponse, bool bWasSuccessful)
					{
						OnResponseHttpHead(InRequest, InResponse, bWasSuccessful);
					});
				HttpRequest->ProcessRequest();
			}
			else
			{
				const auto HttpRequest = FHttpModule::Get().CreateRequest();
				HttpRequest->SetHeader(TEXT("Content-Type"), TEXT("application/octet-stream"));
				HttpRequest->SetVerb("POST");

				HttpRequest->SetURL(UploadUrl);
				HttpRequest->SetContentAsString("");
				HttpRequest->OnProcessRequestComplete().BindLambda([](FHttpRequestPtr InRequest, FHttpResponsePtr InResponse, bool bWasSuccessful)
					{
						OnResponseHttpHead(InRequest, InResponse, bWasSuccessful);
					});
				HttpRequest->ProcessRequest();
			}
		}
		else
		{
			isUploading = false;
			UploadFileNames.Empty();
			UE_LOG(LogTemp, Error, TEXT("upload file failed, code=%d"), ResponseCode);
		}
	}
	else
	{
		isUploading = false;
		if (bWasSuccessful)
		{
			UE_LOG(LogTemp, Log, TEXT("upload all success, code=%d"), ResponseCode);
		}
		else
		{
			UE_LOG(LogTemp, Error, TEXT("upload failed, code=%d"), ResponseCode);
		}
	}
}

void UC7FunctionLibrary::AddSubLevel(UWorld* InWorld, FString LongPackageName, FTransform& Transform)
{
	const FString ShortPackageName = FPackageName::GetShortName(LongPackageName);
	const FString PackagePath = FPackageName::GetLongPackagePath(LongPackageName);
	FString UniqueLevelPackageName = PackagePath + TEXT("/") + InWorld->StreamingLevelsPrefix + ShortPackageName;
	// Setup streaming level object that will load specified map
	ULevelStreamingDynamic* StreamingLevel = NewObject<ULevelStreamingDynamic>(InWorld, ULevelStreamingDynamic::StaticClass(), NAME_None, RF_Transient, NULL);
	StreamingLevel->SetWorldAssetByPackageName(FName(*UniqueLevelPackageName));
	StreamingLevel->LevelColor = FColor::MakeRandomColor();
	StreamingLevel->LevelTransform = Transform;
	// Map to Load
	StreamingLevel->PackageNameToLoad = FName(*LongPackageName);
	InWorld->AddStreamingLevel(StreamingLevel);

	UGameplayStatics::LoadStreamLevel(InWorld, FName(*LongPackageName), true, true, FLatentActionInfo());
}



bool UC7FunctionLibrary::HasActiveWiFiConnection()
{
	return FPlatformMisc::HasActiveWiFiConnection();
}

void UC7FunctionLibrary::QuitC7Game(const UObject* WorldContextObject)
{
	UKismetSystemLibrary::QuitGame(WorldContextObject, nullptr, EQuitPreference::Quit, true);
}

void UC7FunctionLibrary::GC()
{
	CollectGarbage(RF_NoFlags);
	CollectGarbage(GARBAGE_COLLECTION_KEEPFLAGS);
	CollectGarbage(GARBAGE_COLLECTION_KEEPFLAGS, true);
	GEngine->Exec(nullptr, TEXT("obj gc"));
}

bool UC7FunctionLibrary::IsC7Editor()
{
#if WITH_EDITOR
	return true;
#else
	return false;
#endif
}

bool UC7FunctionLibrary::IsBuildShipping()
{
#if UE_BUILD_SHIPPING
	return true;
#else
	return false;
#endif
}

bool UC7FunctionLibrary::ShowMessageBox(FString Message, FString Title)
{
	FPlatformMisc::MessageBoxExt(EAppMsgType::Ok, *Message, *Title);

	return true;
}

bool UC7FunctionLibrary::FindNearstVaildPosition(UObject* WorldContextObject, const FVector& InPos, const FVector& SearchRange, FVector& OutPos)
{
	// if (UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(WorldContextObject->GetWorld()))
	// {
	// 	FNavLocation OutNavLocation;
	// 	if (NavSys->ProjectPointToNavigation(InPos, OutNavLocation, SearchRange))
	// 	{
	// 		OutPos = OutNavLocation.Location;
	// 		return true;
	// 	}
	// }

	UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(WorldContextObject->GetWorld());
	if (NavSys == nullptr || NavSys->GetDefaultNavDataInstance() == nullptr)
		return false;

	ANavigationData* NavigationData = Cast<ANavigationData>(NavSys->GetMainNavData());
	if (!NavigationData)
		return false;

	const ARecastNavMesh* NavMesh = Cast<ARecastNavMesh>(NavigationData);
	if (!NavMesh)
		return false;

	NavNodeRef OriginPolyID = NavMesh->FindNearestPoly(InPos, SearchRange);
	if (OriginPolyID == INVALID_NAVNODEREF)
		return false;

	NavMesh->GetClosestPointOnPoly(OriginPolyID, InPos, OutPos);
	return true;
}

void UC7FunctionLibrary::CutSceneJumpToFrame(UMovieSceneSequencePlayer* SequencePlayer, int32 Frame)
{
	if (SequencePlayer)
	{
		SequencePlayer->SetPlaybackPosition(FMovieSceneSequencePlaybackParams(FFrameTime(Frame), EUpdatePositionMethod::Jump));
	}
}

void UC7FunctionLibrary::LevelSequenceJumpToFrame(UMovieSceneSequencePlayer* SequencePlayer, int32 Frame)
{
	SequencePlayer->SetPlaybackPosition(FMovieSceneSequencePlaybackParams(FFrameTime(Frame), EUpdatePositionMethod::Jump));
}

void UC7FunctionLibrary::LevelSequenceJumpToStart(UMovieSceneSequencePlayer* SequencePlayer)
{
	const FFrameTime StatTime = SequencePlayer->GetStartTime().Time;
	SequencePlayer->SetPlaybackPosition(FMovieSceneSequencePlaybackParams(StatTime, EUpdatePositionMethod::Jump));
}

void UC7FunctionLibrary::LevelSequenceJumpToMark(UMovieSceneSequencePlayer* SequencePlayer, const FString& InMarkedFrame)
{
	SequencePlayer->SetPlaybackPosition(FMovieSceneSequencePlaybackParams(InMarkedFrame, EUpdatePositionMethod::Jump));
}

void UC7FunctionLibrary::LevelSequencePlayToFrame(UMovieSceneSequencePlayer* SequencePlayer, int32 Frame)
{
	SequencePlayer->PlayTo(FMovieSceneSequencePlaybackParams(FFrameTime(Frame), EUpdatePositionMethod::Play), FMovieSceneSequencePlayToParams());
}

void UC7FunctionLibrary::LevelSequencePlayToMark(UMovieSceneSequencePlayer* SequencePlayer, const FString& InMarkedFrame)
{
	SequencePlayer->PlayTo(FMovieSceneSequencePlaybackParams(InMarkedFrame, EUpdatePositionMethod::Play), FMovieSceneSequencePlayToParams());
}

void UC7FunctionLibrary::LevelSequencePlayToEnd(UMovieSceneSequencePlayer* SequencePlayer)
{
	const FFrameTime EndTime = SequencePlayer->GetEndTime().Time;
	SequencePlayer->PlayTo(FMovieSceneSequencePlaybackParams(EndTime, EUpdatePositionMethod::Play), FMovieSceneSequencePlayToParams());
}

void UC7FunctionLibrary::TestMalloc(int InSize)
{
#if !UE_BUILD_SHIPPING

	if (InSize <= 0)
	{
		return;
	}

	char* Test = new char[InSize];
	FMemory::Memzero(Test, InSize);
#endif

}

void UC7FunctionLibrary::TestSpawnActors(const UObject* WorldContext, int InNum)
{
#if !UE_BUILD_SHIPPING
	if (WorldContext == nullptr || InNum <= 0)
	{
		return;
	}

	UWorld* CW = WorldContext->GetWorld();
	AActor* NewActor = nullptr;
	if (CW)
	{
		for (int i = 0; i < InNum; ++i)
		{
			NewActor = CW->SpawnActor<AActor>();
		}
	}
#endif
}

ETraceTypeQuery UC7FunctionLibrary::ConvertToTraceType(ECollisionChannel CollisionChannel)
{
	return UEngineTypes::ConvertToTraceType(CollisionChannel);
}

EObjectTypeQuery UC7FunctionLibrary::ConvertToObjectType(ECollisionChannel CollisionChannel)
{
	return UEngineTypes::ConvertToObjectType(CollisionChannel);
}

bool UC7FunctionLibrary::LineTraceMultiForObjects(const UObject* WorldContextObject, const FVector Start, const FVector End, const TArray<int32>& InObjectTypes, bool bTraceComplex, const TArray<AActor*>& ActorsToIgnore, EDrawDebugTrace::Type DrawDebugType, TArray<FHitResult>& OutHits, TArray<AActor*>& OutActors, bool bIgnoreSelf, FLinearColor TraceColor, FLinearColor TraceHitColor, float DrawTime)
{
	TArray<TEnumAsByte<EObjectTypeQuery> > ObjectTypes;
	for (auto& Elem : InObjectTypes)
	{
		ObjectTypes.Push(TEnumAsByte<EObjectTypeQuery>(Elem));
	}

	bool Result = UKismetSystemLibrary::LineTraceMultiForObjects(WorldContextObject, Start, End, ObjectTypes, bTraceComplex, ActorsToIgnore, DrawDebugType, OutHits, bIgnoreSelf, TraceColor, TraceHitColor, DrawTime);

	for(auto Hit : OutHits)
	{
		OutActors.Add(Hit.GetActor());
	}
	
	return Result;
}

FString UC7FunctionLibrary::PathCombine(FString& PathA, FString& PathB)
{
	return FPaths::Combine(PathA, PathB);
}

FString UC7FunctionLibrary::GetClassName(UClass* Class)
{
	if (!IsValid(Class))
	{
		return FString();
	}
	else
	{
		return Class->GetName();
	}
}

FVector UC7FunctionLibrary::GetMeshCompBoundBox(UMeshComponent* Component)
{
	if (!Component)
	{
		return FVector();
	}

	return Component->GetLocalBounds().BoxExtent;
}

template<typename T>
TArray<T> Range(T End)
{
	TArray<T> Result;
	Result.SetNum(End);
	for (uint32 i = 0; i < End; i++)
	{
		Result[i] = i;
	}
	return Result;
}

bool UC7FunctionLibrary::GetBoneTransform(const UAnimSequence* Anim, int32 Frame,FName BoneName,USkeletalMeshComponent* Mesh,FTransform& OutTrans)
{
	if ( !IsValid(Anim)||!IsValid(Mesh))
	{
		return false;
	}
	USkeletalMesh* Skeleton = Mesh->GetSkeletalMeshAsset();
	if(Skeleton == nullptr)
	{
		return false;
	}

	
	const FReferenceSkeleton& ReferenceSkeleton = Mesh->GetSkeletalMeshAsset()->GetRefSkeleton();
	const int32 NumBones = ReferenceSkeleton.GetNum();
	TArray<uint16> BoneIndices = Range<uint16>(NumBones);
	
	//获取Pose信息
	FMemMark Mark(FMemStack::Get());
	FBoneContainer BoneContainer;
	FCompactPose OutPose;
	FBlendedCurve OutCurve;
	BoneContainer.SetUseRAWData(true);
	BoneContainer.InitializeTo(BoneIndices, UE::Anim::FCurveFilterSettings(), *Skeleton);
	OutPose.SetBoneContainer(&BoneContainer);
	OutPose.InitBones(NumBones);
	OutCurve.InitFrom(BoneContainer);
	UE::Anim::FStackAttributeContainer TempAttributes;
	const double Time = FMath::Clamp(Anim->GetSamplingFrameRate().AsSeconds(Frame), 0., (double)Anim->GetPlayLength());
	FAnimExtractContext ExtractionContext(Time);
	FAnimationPoseData AnimationPoseData(OutPose, OutCurve, TempAttributes);
	Anim->GetAnimationPose(AnimationPoseData, ExtractionContext);


	//获取骨骼关系信息
	int32 TargetBoneIdex = INDEX_NONE;
	TArray<int32> ParentBoneIndices;
	TArray<FName> BoneNames;
	TArray<int32> Indices;
	for (const FBoneIndexType BoneIndex : BoneContainer.GetBoneIndicesArray())
    {			
    	const FCompactPoseBoneIndex CompactIndex(BoneIndex);
    	const FCompactPoseBoneIndex CompactParentIndex = BoneContainer.GetParentBoneIndex(CompactIndex);

    	const int32 SkeletonBoneIndex = BoneContainer.GetSkeletonIndex(CompactIndex);
    	if (SkeletonBoneIndex != INDEX_NONE)
    	{
    		const int32 ParentBoneIndex = CompactParentIndex.GetInt() != INDEX_NONE ? BoneContainer.GetSkeletonIndex(CompactParentIndex) : INDEX_NONE;

    		Indices.Add(SkeletonBoneIndex);
    		ParentBoneIndices.Add(ParentBoneIndex);
    		if (ReferenceSkeleton.GetBoneName(BoneIndex) == BoneName)
    		{
    			TargetBoneIdex = SkeletonBoneIndex;
    		}
    		BoneNames.Add(ReferenceSkeleton.GetBoneName(BoneIndex));
    	}
    }

	
	if(TargetBoneIdex == INDEX_NONE)
	{
		return false;
	}

	//计算骨骼WorldSpace位置
	TArray<FTransform> LocalSpacePoses;
	LocalSpacePoses.SetNum(BoneNames.Num());
	for (const FCompactPoseBoneIndex BoneIndex : OutPose.ForEachBoneIndex())
	{
		const int32 SkeletonBoneIndex = BoneContainer.GetSkeletonIndex(BoneIndex);
		const int32 BoneIdx = Indices.IndexOfByKey(SkeletonBoneIndex);
		if (BoneIdx!= INDEX_NONE)
		{
			LocalSpacePoses[BoneIdx] = OutPose[BoneIndex];
		}
	}
	TArray<FTransform> WorldSpacePoses;
	TArray<bool> Processed;
	Processed.SetNumZeroed(BoneNames.Num());
	WorldSpacePoses.SetNum(BoneNames.Num());
	for (int32 EntryIndex = 0; EntryIndex <BoneNames.Num(); ++EntryIndex)
	{
		const int32 ParentIndex = ParentBoneIndices[EntryIndex];
		const int32 TransformIndex =  Indices.IndexOfByKey(ParentIndex);
		if (TransformIndex != INDEX_NONE)
		{
			ensure(Processed[TransformIndex]);
			WorldSpacePoses[EntryIndex] = LocalSpacePoses[EntryIndex] * WorldSpacePoses[TransformIndex];
		}
		else
		{
			WorldSpacePoses[EntryIndex] = LocalSpacePoses[EntryIndex];
		}
		
		Processed[EntryIndex] = true;
	}

	
	if (TargetBoneIdex != INDEX_NONE && Indices.IndexOfByKey(TargetBoneIdex))
	{
		OutTrans = 	WorldSpacePoses[Indices.IndexOfByKey(TargetBoneIdex)];
		return true;
	}
	
	return false;
}

FVector UC7FunctionLibrary::GetBoneLocation(class USkeletalMeshComponent* MeshComponent, FName BoneName, EBoneSpaces::Type Space /*= EBoneSpaces::WorldSpace*/)
{
	if( MeshComponent == nullptr) 
		return FVector::ZeroVector;
	return MeshComponent->GetBoneLocation(BoneName, Space);

}

float UC7FunctionLibrary::PlayMontageWithInfiniteLoop(UAnimInstance* AnimIns,UAnimMontage* MontageToPlay, float InPlayRate, EMontagePlayReturnType ReturnValueType, float InTimeToStartMontageAt, bool bStopAllMontages )
{
	if (AnimIns)
	{
		float PlayDuration = AnimIns->Montage_Play( MontageToPlay,  InPlayRate,  ReturnValueType ,  InTimeToStartMontageAt,  bStopAllMontages );
		FAnimMontageInstance* MontIns = AnimIns->GetActiveInstanceForMontage( MontageToPlay);
		if (MontIns)
		{
			MontIns->SetNextSectionName("Default","Default");
		}
		
		return PlayDuration;
	}
	return 0;
}

bool UC7FunctionLibrary::BreakPlayingMontageInfiniteLoop(UAnimInstance* AnimIns,UAnimMontage* MontagePlaying)
{
	c7_obj_check(AnimIns)
	c7_obj_check(MontagePlaying)
	if (AnimIns != nullptr && MontagePlaying != nullptr)
	{
		FAnimMontageInstance* MontIns =AnimIns->GetActiveInstanceForMontage(MontagePlaying);
		if (MontIns)
		{
			MontIns->SetNextSectionName("Default","");
			return true;
		}
	}
	return false;
}

void UC7FunctionLibrary::SetPhysicsAssetForSkeletalMesh(USkeletalMesh* InSkeletalMesh, UPhysicsAsset* InPhysicsAsset)
{
	// TBT2上的崩溃处理，在Lua高频设置入口都加上判定 #90951 【Bug】悬空指针崩溃规避
	c7_obj_check(InSkeletalMesh);
	c7_obj_check((UObject*)InPhysicsAsset);
	InSkeletalMesh->SetPhysicsAsset(InPhysicsAsset);
}

void UC7FunctionLibrary::SetShadowPhysicsAssetForSkeletalMesh(USkeletalMesh* InSkeletalMesh, UPhysicsAsset* InPhysicsAsset)
{
	// TBT2上的崩溃处理，在Lua高频设置入口都加上判定
	c7_obj_check(InSkeletalMesh);
	c7_obj_check((UObject*)InPhysicsAsset);
	InSkeletalMesh->SetShadowPhysicsAsset(InPhysicsAsset);
}

bool UC7FunctionLibrary::Is_ES3_1_FeatureLevel(UObject* InWorld)
{
	if(InWorld)
	{
		if (UWorld* World =  InWorld->GetWorld())
		{
			return World->GetFeatureLevel() == ERHIFeatureLevel::Type::ES3_1;
		}
	}
	return false;
}

bool UC7FunctionLibrary::Is_Actor_Platform_Active(AActor* Actor)
{
	if (Actor) 
	{
		return Actor->Platforms.IsActive();
	}
	return false;
}

void UC7FunctionLibrary::SpawnIndirectLightOverwriteVolume(UObject* WorldContextObject)
{
	FActorSpawnParameters SpawnInfo;
	FTransform NewActorTransform = FTransform::Identity;

	UClass* VolumeClass = AIndirectLightOverwriteVolume::StaticClass();
	AIndirectLightOverwriteVolume* NewVolume = UGameplayStatics::GetPlayerController(WorldContextObject, 0)->GetWorld()->SpawnActor<AIndirectLightOverwriteVolume>(VolumeClass, FVector(0, 0, 0), FRotator(0, 0, 0));
	NewVolume->bUnbound = true;
}

void UC7FunctionLibrary::EmptyMeshOverrideMaterials(UMeshComponent* MeshComponent)
{
	if (MeshComponent && MeshComponent->GetNumOverrideMaterials() > 0)
	{
		MeshComponent->EmptyOverrideMaterials();
	}
}
#define EAnimLib_NpcAnimType_Path TEXT("/Game/Blueprint/3C/Animation/AnimTemplate/AnimLib/EAnimLib_NpcAnimType")
FString UC7FunctionLibrary::GetAnimTypeEnumDescription(const FString& EnumName)
{
#if WITH_EDITOR			
	FSoftObjectPath AssetRef;
	AssetRef.SetPath(FTopLevelAssetPath(EAnimLib_NpcAnimType_Path, TEXT("EAnimLib_NpcAnimType")));
	UObject* Obj = AssetRef.ResolveObject();
	if (Obj == nullptr)
	{
		Obj = AssetRef.TryLoad();
	}

	if (Obj != nullptr)
	{
		UEnum* Enum = Cast<UEnum>(Obj);
		if (Enum != nullptr)
		{
			int32 Num = Enum->NumEnums();
			for (int32 i(0); i < Num - 1; ++i)
			{
				FString Name = Enum->GetDisplayNameTextByIndex(i).ToString();
				if(Name == EnumName)
					return Enum->GetToolTipTextByIndex(i).ToString();
			}
		}
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("GetAnimTypeEnumDescription can not find EAnimLib_NpcAnimType, path in invalid %s"), *AssetRef.ToString());
	}
	return FString(TEXT(""));
#else
	return FString(TEXT(""));
#endif
}


FString UC7FunctionLibrary::GetAnimTypeEnumNameByDescription(const FString& EnumDescription)
{
#if WITH_EDITOR			
	FSoftObjectPath AssetRef;
	AssetRef.SetPath(FTopLevelAssetPath(EAnimLib_NpcAnimType_Path, TEXT("EAnimLib_NpcAnimType")));
	UObject* Obj = AssetRef.ResolveObject();
	if (Obj == nullptr)
	{
		Obj = AssetRef.TryLoad();
	}

	if (Obj != nullptr)
	{
		UEnum* Enum = Cast<UEnum>(Obj);
		if (Enum != nullptr)
		{
			int32 Num = Enum->NumEnums();
			for (int32 i(0); i < Num - 1; ++i)
			{
				FString Name = Enum->GetDisplayNameTextByIndex(i).ToString();
				FString ToolTip = Enum->GetToolTipTextByIndex(i).ToString();
				if (ToolTip == EnumDescription || Name == EnumDescription)
				//如果填写的是坐下这种汉字，则对比Tooltips，也支持直接填写Name，如SitDown
					return Name;
			}
		}
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("GetAnimTypeEnumNameByDescription can not find EAnimLib_NpcAnimType, path in invalid %s"), *AssetRef.ToString());
	}
	return FString(TEXT(""));
#else
	return FString(TEXT(""));
#endif
}

FMinimalViewInfo UC7FunctionLibrary::GetCameraPOV(APlayerCameraManager* CM)
{
	if (CM)
	{
		return CM->GetCameraCacheView();
	}
	return FMinimalViewInfo();
}

#if WITH_EDITOR
bool UC7FunctionLibrary::GetViewportLocationAndRotation(FVector& Location,FRotator& Rotation)
{
	if(GCurrentLevelEditingViewportClient)
	{
		Location = GCurrentLevelEditingViewportClient->GetViewLocation();
		Rotation = GCurrentLevelEditingViewportClient->GetViewRotation();
		return true;
	}
	return false;
}
#endif

#pragma region Performance

#if STATS

class C7_API FStatsThreadStateOverlayForHotMap : public FStatsThreadState
{
public:
	int64 GetLastFullFrameProcessed()
	{
		return LastFullFrameProcessed;
	}
};
struct FGroupFilterForHotMap : public IItemFilter
{
	TSet<FName> const& EnabledItems;

	FGroupFilterForHotMap(TSet<FName> const& InEnabledItems)
		: EnabledItems(InEnabledItems)
	{

	}

	virtual bool Keep(FStatMessage const& Item)
	{
		// 先不过滤，让业务测决定
		return true;
		//const FName MessageName = Item.NameAndInfo.GetRawName();
		//return EnabledItems.Contains(MessageName);
	}
};




static FString FormatStatValueFloat(const float Value)
{
	const float QuantizedValue = FMath::RoundToFloat(Value * 100.0f) / 100.0f;
	const float Frac = FMath::Frac(QuantizedValue);
	const int32 Integer = FMath::FloorToInt(QuantizedValue);
	const FString IntString = FString::FormatAsNumber(Integer);
	const FString FracString = FString::Printf(TEXT("%0.2f"), Frac);
	FString Result = FString::Printf(TEXT("%s.%s"), *IntString, *FracString.Mid(2));
	UE_LOG(LogTemp, Log, TEXT("FormatStatValueDouble Result: %s"), *Result);

	return Result;
}

static FString FormatStatValueInt64(const int64 Value)
{
	FString IntString = FString::FormatAsNumber((int32)Value);
	UE_LOG(LogTemp, Log, TEXT("FormatStatValueInt64: %s"), *IntString);
	return IntString;
}

static void ReadStatInfo2Json(FStatMessage& Stat, TSharedPtr<FJsonObject>& JsonObject, TArray<FString>& HotMapStatNameArray)
{

	const FString ShortName = Stat.NameAndInfo.GetShortName().ToString();
	if (!HotMapStatNameArray.Contains(ShortName) && false)
	{
		// 舍弃不关心的数据
		return;
	}

	const FString Description = Stat.NameAndInfo.GetDescription();
	UE_LOG(LogTemp, Log, TEXT("Received Stat: name: %s , desc: %s, rawName: %s"), *ShortName, *Description, *(Stat.NameAndInfo.GetRawName().ToString()));

	int64 iVal = 0;
	double dVal = 0;

	switch (Stat.NameAndInfo.GetField<EStatDataType>())
	{
	case EStatDataType::ST_int64:
		iVal = Stat.GetValue_int64();
		UE_LOG(LogTemp, Log, TEXT("Value int64: %lld"), iVal);
		
		if (Stat.NameAndInfo.GetFlag(EStatMetaFlags::IsPackedCCAndDuration))
		{
			float Duration = FPlatformTime::ToMilliseconds(FromPackedCallCountDuration_Duration(iVal)); // 毫秒

			UE_LOG(LogTemp, Log, TEXT("EStatMetaFlags::IsPackedCCAndDuration, FromPackedCallCountDuration_Duration ToMilliseconds: %f"), Duration);
			JsonObject->SetStringField(ShortName, FormatStatValueFloat(Duration));
		}
		else if (Stat.NameAndInfo.GetFlag(EStatMetaFlags::IsCycle))
		{
			float Duration = FPlatformTime::ToMilliseconds64(iVal); // 毫秒
			UE_LOG(LogTemp, Log, TEXT("EStatMetaFlags::IsCycle ToMilliseconds: %f"), Duration);
			JsonObject->SetStringField(ShortName, FormatStatValueFloat(Duration));
		}
		else if (Stat.NameAndInfo.GetFlag(EStatMetaFlags::IsMemory))
		{
			float Memory = (double)iVal / 1024.0 / 1024.0; // MB
			UE_LOG(LogTemp, Log, TEXT("EStatMetaFlags::IsMemory %f"), Memory);
			JsonObject->SetStringField(ShortName, FormatStatValueFloat(Memory));
		}
		else
		{
			JsonObject->SetStringField(ShortName, FormatStatValueInt64(iVal));
		}
		break;
	case EStatDataType::ST_double:
		dVal = Stat.GetValue_double();
		UE_LOG(LogTemp, Log, TEXT("Value double: %f"), dVal);
		JsonObject->SetStringField(ShortName, FormatStatValueInt64(dVal));
		break;
	default:
		break;
	}
}

static void DumpStatStackNode(FRawStatStackNode* Root, TSharedPtr<FJsonObject>& JsonObject, TArray<FString>& HotMapStatNameArray)
{
	static int64 MinPrint = -1;
	if (Root && Root->Children.Num())
	{
		TArray<FRawStatStackNode*> ChildArray;
		Root->Children.GenerateValueArray(ChildArray);
		ChildArray.Sort(FStatDurationComparer<FRawStatStackNode>());
		for (int32 Index = 0; Index < ChildArray.Num(); Index++)
		{
			if (ChildArray[Index]->Meta.GetValue_Duration() < MinPrint)
			{
				break;
			}

			ReadStatInfo2Json(ChildArray[Index]->Meta, JsonObject, HotMapStatNameArray);
 			DumpStatStackNode(ChildArray[Index], JsonObject, HotMapStatNameArray);
		}
	}
}

#endif

FString UC7FunctionLibrary::GetHotMapPerformanceData()
{

#if !STATS
	return FString();
#else
	// 默认获取所有指标
	TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject());

	// 获取游戏线程时间
	float GameThreadTime = FPlatformTime::ToMilliseconds(GGameThreadTime);
	UE_LOG(LogTemp, Log, TEXT("Game Thread Time: %f ms"), GameThreadTime);

	JsonObject->SetStringField(TEXT("GameThreadTime"), FormatStatValueFloat(GameThreadTime));

	// 获取渲染线程时间
	float RenderThreadTime = FPlatformTime::ToMilliseconds(GRenderThreadTime);
	UE_LOG(LogTemp, Log, TEXT("Render Thread Time: %f ms"), RenderThreadTime);
	JsonObject->SetStringField(TEXT("RenderThreadTime"), FormatStatValueFloat(RenderThreadTime));

	// 获取 GPU 时间
	float GPUFrameTime = FPlatformTime::ToMilliseconds(GGPUFrameTime);
	UE_LOG(LogTemp, Log, TEXT("GPU Frame Time: %f ms"), GPUFrameTime);
	JsonObject->SetStringField(TEXT("GPUFrameTime"), FormatStatValueFloat(GPUFrameTime));	

	auto World = GetGameWorld();
	// 获取 Actor
	TArray<UClass*> ActorClasses;
	for (TActorIterator<AActor> ActorIter(World); ActorIter; ++ActorIter)
	{
		AActor* Actor = *ActorIter;
		if (Actor)
		{
			UClass* ActorClass = Actor->GetClass();
			if (ActorClass)
			{
				ActorClasses.Add(ActorClass);
			}
		}
	}
	TMap<FString, int32> VisibleActorCount = UScreenActorCounter::GetVisibleActorCount(World, ActorClasses);
	for (auto KV : VisibleActorCount)
	{
		FString ActorTypeKey = TEXT("ActorType.") + KV.Key;
		JsonObject->SetNumberField(ActorTypeKey, KV.Value);
	}

	FString OutputString;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&OutputString);
	FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);

	UE_LOG(LogTemp, Log, TEXT("GetHotMapPerformanceData ：%s"), *OutputString);

	return OutputString;
#endif
}

FString UC7FunctionLibrary::GetStatUnitData()
{
#if C7_FRAME_STAT
	FC7FrameState FrameState;
	if (GWorld->GetGameViewport() && GWorld->GetGameViewport()->GetStatUnitData())
	{
		const FStatUnitData* StatUnitData = GWorld->GetGameViewport()->GetStatUnitData();
		FrameState.Timestamp = (FDateTime::Now() - FDateTime(1970, 1, 1)).GetTotalSeconds();
		FrameState.FrameTime = StatUnitData->FrameTime;
		FrameState.GameThreadTime = StatUnitData->GameThreadTime;
		FrameState.RenderThreadTime = StatUnitData->RenderThreadTime;
		FrameState.GPUTime = StatUnitData->GPUFrameTime[0];
		FrameState.RHITime = StatUnitData->RHITTime;
		FrameState.Draws = GNumDrawCallsRHI[0];
		FrameState.Prims = GNumPrimitivesDrawnRHI[0] / 1000.0f;
	}
	return FrameState.GetReportString();
#else
	return FString();
#endif
}


void UC7FunctionLibrary::BeginSampleWorld()
{
	auto World = GetGameWorld();
	if (!World)
	{
		UE_LOG(LogTemp, Error, TEXT("BeginSampleWorldPartition failed, World is null"));
		return;
	}
	UKGWorldPartitionProfilerSubSystem* WorldPartitionProfilerSubSystem = World->GetSubsystem<UKGWorldPartitionProfilerSubSystem>();
	if (WorldPartitionProfilerSubSystem)
	{
		if (WorldPartitionProfilerSubSystem->GetEnableProfile())
		{
			UE_LOG(LogTemp, Error, TEXT("BeginSampleWorldPartition failed, already in sampling"));
			return;
		}
		WorldPartitionProfilerSubSystem->EnableProfile();
	}
}

void UC7FunctionLibrary::EndSampleWorld()
{
	auto World = GetGameWorld();
	if (!World)
	{
		UE_LOG(LogTemp, Error, TEXT("EndSampleWorldPartition failed, World is null"));
		return;
	}
	UKGWorldPartitionProfilerSubSystem* WorldPartitionProfilerSubSystem = World->GetSubsystem<UKGWorldPartitionProfilerSubSystem>();
	if (WorldPartitionProfilerSubSystem)
	{
		if (WorldPartitionProfilerSubSystem->GetEnableProfile())
		{
			WorldPartitionProfilerSubSystem->DisableProfile();
		}
	}
}

void UC7FunctionLibrary::InitWorldProfilerStatList(TArray<FName> StatList)
{
	auto World = GetGameWorld();
	if (!World)
	{
		UE_LOG(LogTemp, Error, TEXT("InitWorldPartitionProfilerStatList failed, World is null"));
		return;
	}
	UKGWorldPartitionProfilerSubSystem* WorldPartitionProfilerSubSystem = World->GetSubsystem<UKGWorldPartitionProfilerSubSystem>();
	if (WorldPartitionProfilerSubSystem)
	{
		WorldPartitionProfilerSubSystem->ClearStatsShortNames();
		for (FName StatName : StatList)
		{
			UE_LOG(LogTemp, Log, TEXT("InitWorldPartitionProfilerStatList AddStatName: %s"), *StatName.ToString());
			WorldPartitionProfilerSubSystem->AddStatsShortName(StatName);
		}
	}
}

FString UC7FunctionLibrary::GetWorldProfilerLastStatValueByName(FName name)
{
	auto World = GetGameWorld();
	if (!World)
	{
		UE_LOG(LogTemp, Error, TEXT("GetWorldPartitionProfilerLastStatValueByName failed, World is null"));
		return FString();
	}
	UKGWorldPartitionProfilerSubSystem* WorldPartitionProfilerSubSystem = World->GetSubsystem<UKGWorldPartitionProfilerSubSystem>();
	if (WorldPartitionProfilerSubSystem)
	{
		auto data = WorldPartitionProfilerSubSystem->GetLastFrameStatsData();
		if (data.Contains(name))
		{
			return FString::Printf(TEXT("%f"), data[name]);
		}
	}

	return FString();
}

FString UC7FunctionLibrary::GetWorldProfilerLastStatValueList()
{
	auto World = GetGameWorld();
	if(!World)
	{
		UE_LOG(LogTemp, Error, TEXT("GetWorldPartitionProfilerLastStatValueList failed, World is null"));
		return FString();
	}
	UKGWorldPartitionProfilerSubSystem* WorldPartitionProfilerSubSystem = World->GetSubsystem<UKGWorldPartitionProfilerSubSystem>();
	if (WorldPartitionProfilerSubSystem)
	{
		auto data = WorldPartitionProfilerSubSystem->GetLastFrameStatsData();
		FString ret;
		for (auto& Elem : data)
		{
			ret += FString::Printf(TEXT("%s:%f\n"), *Elem.Key.ToString(), Elem.Value);
		}
		// 去掉最后一个换行符
		if (ret.Len() > 0)
		{
			ret.RemoveAt(ret.Len() - 1);
		}
		return ret;
	}

	return FString();
}

void UC7FunctionLibrary::DumpWorldProfilerAllData()
{
	auto World = GetGameWorld();
	if (!World)
	{
		UE_LOG(LogTemp, Error, TEXT("DumpWorldPartitionProfilerAllData failed, World is null"));
		return;
	}
	UKGWorldPartitionProfilerSubSystem* WorldPartitionProfilerSubSystem = World->GetSubsystem<UKGWorldPartitionProfilerSubSystem>();

	if(!WorldPartitionProfilerSubSystem)
	{
		return;
	}

	//在 Save 目录新增一个子目录专门存放 Dump log 文件
	FString SaveDir = FPaths::ProjectSavedDir();
	FString SubDirPath = FPaths::Combine(SaveDir, TEXT("WorldPartitionProfilerData"));
	if (!FPaths::DirectoryExists(SubDirPath))
	{
		FPlatformFileManager::Get().GetPlatformFile().CreateDirectoryTree(*SubDirPath);
	}
	
	FString FileName = FString::Printf(TEXT("WorldPartitionProfilerData_%s.log"), *FDateTime::Now().ToString());
	FString FilePath = FPaths::Combine(SubDirPath, FileName);

	// 如果文件存在，删除
	if (FPaths::FileExists(FilePath))
	{
		IFileManager::Get().Delete(*FilePath);
	}

	auto PerCellStatsMax = WorldPartitionProfilerSubSystem->GetPerCellStatsData(EStatsType::Max);
	FFileHelper::SaveStringToFile(TEXT("WP.DumpProfile Dump PerCellStatsStats Max Start"), *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_Append);
	DumpWorldProfilerData(FilePath, WorldPartitionProfilerSubSystem, PerCellStatsMax);
	FFileHelper::SaveStringToFile(TEXT("WP.DumpProfile Dump PerCellStatsStats Max End"), *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_Append);

	auto PerCellStatsAve = WorldPartitionProfilerSubSystem->GetPerCellStatsData(EStatsType::Ave);
	FFileHelper::SaveStringToFile(TEXT("WP.DumpProfile Dump PerCellStatsStats Ave Start"), *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_Append);
	DumpWorldProfilerData(FilePath, WorldPartitionProfilerSubSystem, PerCellStatsAve);
	FFileHelper::SaveStringToFile(TEXT("WP.DumpProfile Dump PerCellStatsStats Ave End"), *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_Append);


	auto UnitedCellStatsMax = WorldPartitionProfilerSubSystem->GetUnitedCellStatsData(EStatsType::Max);
	FFileHelper::SaveStringToFile(TEXT("WP.DumpProfile Dump UnitedCellStats Max Start"), *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_Append);
	DumpWorldProfilerData(FilePath, WorldPartitionProfilerSubSystem, UnitedCellStatsMax);
	FFileHelper::SaveStringToFile(TEXT("WP.DumpProfile Dump UnitedCellStats Max End"), *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_Append);

	auto UnitedCellStatsAve = WorldPartitionProfilerSubSystem->GetUnitedCellStatsData(EStatsType::Ave);
	FFileHelper::SaveStringToFile(TEXT("WP.DumpProfile Dump UnitedCellStats Ave Start"), *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_Append);
	DumpWorldProfilerData(FilePath, WorldPartitionProfilerSubSystem, UnitedCellStatsAve);
	FFileHelper::SaveStringToFile(TEXT("WP.DumpProfile Dump UnitedCellStats Ave End"), *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_Append);
};

UWorld* UC7FunctionLibrary::GetGameWorld()
{
#if WITH_EDITOR
	if (GEditor)
	{
		FWorldContext* PIEWorldContext = GEditor->GetPIEWorldContext();

		if (PIEWorldContext)
		{
			return PIEWorldContext->World();
		}
	}

	if (GWorld && (GWorld->WorldType == EWorldType::Game
		|| GWorld->WorldType == EWorldType::PIE))
	{
		return GWorld;
	}

#endif

	for (const FWorldContext& WorldContext : GEngine->GetWorldContexts())
	{
		if (WorldContext.WorldType == EWorldType::Game)
		{
			return WorldContext.World();
		}
	}

	return nullptr;
}



void UC7FunctionLibrary::DumpWorldProfilerData(const FString& FilePath, UKGWorldPartitionProfilerSubSystem* WorldPartitionProfilerSubSystem, TMap<int64,TMap<FName,double>> PerCellStats)
{
	for (auto& CellPair : PerCellStats)
	{
		FBox2D Bounds = WorldPartitionProfilerSubSystem->GetCellBoundsByCoordIndex(CellPair.Key);
		FString CellData = FString::Printf(TEXT("CellCoordKey:%lld,CellBounds.Min=%f,%f,CellBounds.Max=%f,%f\n"), CellPair.Key, Bounds.Min.X, Bounds.Min.Y, Bounds.Max.X, Bounds.Max.Y);
		FFileHelper::SaveStringToFile(CellData, *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_Append);
		
		for (auto& StatPair : CellPair.Value)
		{
			FString StatData = FString::Printf(TEXT("    -StatName:%s  Value:%lf\n"), *StatPair.Key.ToString(), StatPair.Value);
			FFileHelper::SaveStringToFile(StatData, *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_Append);
		}
	}
}

bool UC7FunctionLibrary::CheckWorldPartitionSteamingReady()
{
	// 通过 OptFuncionLibrary 获取 map 状态
	bool loaded = UOptFunctionLibrary::HasAllLevelLoaded();
	UE_LOG(LogTemp, Log, TEXT("CheckWorldPartitionSteamingReady: %d"), loaded);
	return loaded;
}

FString UC7FunctionLibrary::DumpWorldPartitionSteamingInfo()
{
	// 如果没有 CheckWoldPartitionStreamingReady，直接返回空字符串
	if (!UC7FunctionLibrary::CheckWorldPartitionSteamingReady())
	{
		UE_LOG(LogTemp, Log, TEXT("Try DumpWorldPartitionSteamingInfo but CheckWorldPartitionSteamingReady is false"));
		return FString();
	}

	auto StreamState = UOptFunctionLibrary::GetStreamingState();

	// 将 result 中的 key value 转换为 json 字符串
	TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject());
	for (auto& Elem : StreamState)
	{
		JsonObject->SetStringField(Elem.Key, Elem.Value);
	}
	
	// 将 JsonObject 转换为字符串
	FString StreamStateString;
	TSharedRef<TJsonWriter<>> StreamStateWriter = TJsonWriterFactory<>::Create(&StreamStateString);
	FJsonSerializer::Serialize(JsonObject.ToSharedRef(), StreamStateWriter);

	UE_LOG(LogTemp, Log, TEXT("StreamingState: %s"), *StreamStateString);


	auto memoryInfo = UOptFunctionLibrary::GetMapDetailMemoryInfo();

	FString DetailMemoryInfoString;
	FJsonObjectConverter::UStructToJsonObjectString(memoryInfo, DetailMemoryInfoString);

	UE_LOG(LogTemp, Log, TEXT("DetailMemoryInfo: %s"), *DetailMemoryInfoString);
	auto playerCellNames = UOptFunctionLibrary::GetPlayerCellName();

	// 将 playerCellNames 转换为字符串
	FString PlayerCellNamesString;
	for (auto& Elem : playerCellNames)
	{
		PlayerCellNamesString += Elem + TEXT(";");
	}
	PlayerCellNamesString = PlayerCellNamesString.LeftChop(1); // 去掉最后一个分号

	UE_LOG(LogTemp, Log, TEXT("PlayerCellNames: %s"), *PlayerCellNamesString);

	// 将 PlayerCellNamesString 转换为 json 字符串
	TSharedPtr<FJsonObject> PlayerCellNamesJsonObject = MakeShareable(new FJsonObject());
	PlayerCellNamesJsonObject->SetStringField(TEXT("PlayerCellNames"), PlayerCellNamesString);

	auto playerCellDetailMemoryInfo = UOptFunctionLibrary::GetPlayerCellDetailMemoryInfo();
	
	// 将 playerCellDetailMemoryInfo 转换为字符串
	TArray<TSharedPtr<FJsonValue>> JsonArray;
	for (const FLevelMemoryInfo& LevelMemoryInfo : playerCellDetailMemoryInfo)
	{
		JsonObject = FJsonObjectConverter::UStructToJsonObject(LevelMemoryInfo);
		JsonArray.Add(MakeShareable(new FJsonValueObject(JsonObject)));
	}

	FString PlayerCellDetailMemoryInfoString;
	TSharedRef<TJsonWriter<>> PlayerCellDetailMemoryInfoWriter = TJsonWriterFactory<>::Create(&PlayerCellDetailMemoryInfoString);
	FJsonSerializer::Serialize(JsonArray, PlayerCellDetailMemoryInfoWriter);

	UE_LOG(LogTemp, Log, TEXT("PlayerCellDetailMemoryInfo: %s"), *PlayerCellDetailMemoryInfoString);

	TSharedPtr<FJsonObject> ResultJsonObject = MakeShareable(new FJsonObject());
	ResultJsonObject->SetStringField(TEXT("StreamState"), StreamStateString);
	ResultJsonObject->SetStringField(TEXT("DetailMemoryInfo"), DetailMemoryInfoString);
	ResultJsonObject->SetStringField(TEXT("PlayerCellNames"), PlayerCellNamesString);
	ResultJsonObject->SetStringField(TEXT("PlayerCellDetailMemoryInfo"), PlayerCellDetailMemoryInfoString);

	FString OutputString;
	TSharedRef<TJsonWriter<>> ResultWriter = TJsonWriterFactory<>::Create(&OutputString);
	FJsonSerializer::Serialize(ResultJsonObject.ToSharedRef(), ResultWriter);

	return OutputString;
}

void UC7FunctionLibrary::CheckSteamingWhenJumpToNextPoint()
{
	// 通过 OptFuncionLibrary 获取 map 状态
	bool loaded = UOptFunctionLibrary::HasAllLevelLoaded();
	UE_LOG(LogTemp, Log, TEXT("CheckSteamingWhenJumpToNextPoint: %d"), loaded);
}

FString UC7FunctionLibrary::DumpWorldPartitionCellMemoryInfo()
{
	auto memoryInfo = UOptFunctionLibrary::GetMapDetailMemoryInfo();

	FString DetailMemoryInfoString;
	FJsonObjectConverter::UStructToJsonObjectString(memoryInfo, DetailMemoryInfoString);

	UE_LOG(LogTemp, Log, TEXT("DetailMemoryInfo: %s"), *DetailMemoryInfoString);
	return DetailMemoryInfoString;
}

FString UC7FunctionLibrary::GetWorldPartitionCellMemoryInfo(const FString& Key)
{

	auto totalInfo = UOptFunctionLibrary::GetMapDetailMemoryInfo().MapTotalInfo;

	FString DetailMemoryInfoString;

	FString JsonString;
	FJsonObjectConverter::UStructToJsonObjectString(totalInfo, JsonString);

	TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject());
	TSharedRef<TJsonReader<>> JsonReader = TJsonReaderFactory<>::Create(JsonString);

	if (FJsonSerializer::Deserialize(JsonReader, JsonObject) && JsonObject.IsValid())
	{
		// 在 JsonObject 中查找 Key 对应的值
		if (JsonObject->HasField(Key))
		{
			DetailMemoryInfoString = JsonObject->GetStringField(Key);
			return DetailMemoryInfoString;
		}
	}

	return FString();
}

#pragma endregion Performance

#pragma region 3C
#define DRAW_FIND_PATH_DEBUG 0
TArray<FVector> UC7FunctionLibrary::OffsetFromEdge(TSharedPtr<FNavMeshPath> Path, float MaxMergeLength, float EdgeOffset) {
	TArray<FVector> PathPoints;
	TArray<FNavPathPoint>& OriginPoints = Path->GetPathPoints();
	const ARecastNavMesh* NavMesh = Cast<ARecastNavMesh>(Path->GetNavigationDataUsed());
	if (NavMesh == NULL || FMath::IsNearlyZero(EdgeOffset, KINDA_SMALL_NUMBER) || OriginPoints.Num() <= 1)
	{
		for (const FNavPathPoint& point : OriginPoints) {
			PathPoints.Add(point.Location);
		}
		return PathPoints;
	}

	if (OriginPoints.Num() == 2) {
		// 如果只有起点和终点，向里面加一个中点，主要是为了能应用上EdgeOffset，即使会额外绕一个弯
		FNavLocation centerLoc;
		bool succ = NavMesh->ProjectPoint((OriginPoints[0].Location + OriginPoints[1].Location) / 2.0, centerLoc, NavMesh->GetDefaultQueryExtent());
		if (succ) {
			OriginPoints.Insert(FNavPathPoint(centerLoc, centerLoc.NodeRef), 1);
			Path->OnPathCorridorUpdated();
		}
	}
	Path->OffsetFromCorners(0.5); // 往poly顶点里面偏移一点，避免恰好在poly边界上，导致后续射线检测失败 

	// 左右检测的探测角度，一般来说，至少需要一个90°，其余的看情况增加。
	// 增加越多越精确，但是开销越大
	const static float DetectAngleInDegrees[] = { 45, 90, 135 };
	TArray<FNavigationRaycastWork> raycastWorks;
	PathPoints.Add(OriginPoints[0].Location);
	for (int i = 1; i < OriginPoints.Num() - 1; i++) {
		// 向左右做射线，查看边界距离
		int detectSize = sizeof(DetectAngleInDegrees) / sizeof(float);
		FVector pointDir = (OriginPoints[i + 1].Location - OriginPoints[i].Location).GetSafeNormal();
		FVector desireAdjustVector = FVector::ZeroVector; // 期望修正调整的移动
#if DRAW_FIND_PATH_DEBUG
		DrawDebugLine(NavMesh->GetWorld(), OriginPoints[i].Location, OriginPoints[i + 1].Location, FColor::White, true, -1, 0, 10.0f);
#endif
		for (int j = 0; j < detectSize; j++) {
			// 计算出检测方向（配置方向和中心对称的方向）
			FVector checkDir1 = pointDir.RotateAngleAxis(DetectAngleInDegrees[j], FVector::UpVector).GetSafeNormal2D();
			FVector checkDir2 = pointDir.RotateAngleAxis(DetectAngleInDegrees[j] + 180, FVector::UpVector).GetSafeNormal2D();
			FVector raycastEnd1 = OriginPoints[i].Location + checkDir1 * EdgeOffset * 2;
			FVector raycastEnd2 = OriginPoints[i].Location + checkDir2 * EdgeOffset * 2;
			raycastWorks.Empty(2);
#if DRAW_FIND_PATH_DEBUG
			DrawDebugLine(NavMesh->GetWorld(), OriginPoints[i].Location, raycastEnd1, FColor::Yellow, true, -1, 0, 10.0f);
			DrawDebugLine(NavMesh->GetWorld(), OriginPoints[i].Location, raycastEnd2, FColor::Yellow, true, -1, 0, 10.0f);
#endif
			FNavigationRaycastWork& raycastWork1 = raycastWorks.Add_GetRef(FNavigationRaycastWork(OriginPoints[i].Location, raycastEnd1));
			FNavigationRaycastWork& raycastWork2 = raycastWorks.Add_GetRef(FNavigationRaycastWork(OriginPoints[i].Location, raycastEnd2));
			NavMesh->BatchRaycast(raycastWorks, NULL);
#if DRAW_FIND_PATH_DEBUG
			DrawDebugPoint(NavMesh->GetWorld(), raycastWork1.HitLocation.Location, 10, FColor::Red, true);
			DrawDebugPoint(NavMesh->GetWorld(), raycastWork2.HitLocation.Location, 10, FColor::Blue, true);
#endif
			if (!raycastWork1.bDidHit && !raycastWork2.bDidHit) {
				// 两边方向都没hit到，说明两边都有空位，这个方向就不需要调整了
				continue;
			}
			double spareRoom1 = EdgeOffset - (raycastWork1.HitLocation.Location - OriginPoints[i]).Size(); // 该方向是否有余量，>0表示没有余量，距离EdgeOffset的差距
			double spareRoom2 = EdgeOffset - (raycastWork2.HitLocation.Location - OriginPoints[i]).Size();
			if (spareRoom1 * spareRoom2 > 0) // 两边有空位或者两边都没有空位，都不需要进行调整
				continue;
			if (spareRoom1 > 0) {
				desireAdjustVector += spareRoom1 * checkDir2;
			}
			else if (spareRoom2 > 0) { // 需要用else if,因为有=0的情况，这种情况也不需要调整
				desireAdjustVector += spareRoom2 * checkDir1;
			}
		}

		if (!desireAdjustVector.IsNearlyZero()) {
			// 如果有调整需求
			FVector hitPosition;
			FVector endPosition = OriginPoints[i].Location + (desireAdjustVector / detectSize).GetClampedToMaxSize(EdgeOffset);
			const FVector& NavExtent = NavMesh->GetModifiedQueryExtent(NavMesh->GetDefaultQueryExtent());
			FNavLocation endLoc;
			if (NavMesh->ProjectPoint(endPosition, endLoc, NavExtent))
				endPosition = endLoc.Location;
			NavMesh->Raycast(OriginPoints[i].Location, endPosition, hitPosition, NULL);
			if ((OriginPoints[i].Location - OriginPoints[i - 1].Location).Size() <= MaxMergeLength) {
				hitPosition = (PathPoints[PathPoints.Num() - 1] + hitPosition) / 2.0;
				PathPoints[PathPoints.Num() - 1] = hitPosition; // 合并离的近的点
#if DRAW_FIND_PATH_DEBUG
				DrawDebugPoint(NavMesh->GetWorld(), hitPosition, 10, FColor::Green, true);
#endif
			}
			else {
#if DRAW_FIND_PATH_DEBUG
				DrawDebugPoint(NavMesh->GetWorld(), hitPosition, 10, FColor::Green, true);
#endif
				PathPoints.Add(hitPosition);
			}
		}
		else {
#if DRAW_FIND_PATH_DEBUG
			DrawDebugSphere(NavMesh->GetWorld(), OriginPoints[i].Location, 10, 8, FColor::Green, true);
#endif
			PathPoints.Add(OriginPoints[i].Location);
		}
	}
	PathPoints.Add(OriginPoints[OriginPoints.Num() - 1].Location);
	return PathPoints;
}

TArray<FVector> UC7FunctionLibrary::AdjustPathPointToGround(const TArray<FVector>& PathPoints, const ARecastNavMesh* NavMesh, float SampleDistance)
{
	const FVector& NavExtent = NavMesh->GetModifiedQueryExtent(NavMesh->GetDefaultQueryExtent());
	FNavLocation Location;
	TArray<FVector> ResultPoints;
	if (PathPoints.Num() <= 0)
		return ResultPoints;
	ResultPoints.Add(PathPoints[0]);
	if (PathPoints.Num() == 1)
		return ResultPoints;
	if (SampleDistance <= 10)
		SampleDistance = 10;
	for (int i = 1; i < PathPoints.Num(); i++) {
		FVector line = PathPoints[i] - PathPoints[i - 1];
		float size = line.Size();
		FVector dir = line.GetSafeNormal();
		if (size > SampleDistance) {
			float dis = SampleDistance;
			while (dis < size) {
				if (NavMesh->ProjectPoint(PathPoints[i - 1] + dir * dis, Location, NavExtent)) {
					ResultPoints.Add(Location.Location);
				}
				dis += SampleDistance;
			}
		}
		if (NavMesh->ProjectPoint(PathPoints[i], Location, NavExtent)) {
			ResultPoints.Add(Location.Location);
		}
		else {
			ResultPoints.Add(PathPoints[i]);
		}
	}
	return ResultPoints;
}

TArray<FVector> UC7FunctionLibrary::FindPathPointList(UObject* WorldContext, const FVector& InStart, const FVector& InEnd, float MaxPathLength, float MaxMergeLength, float EdgeOffset, float GroundFlowOffset,bool UseWayPoint, float AdjustToGroundInterval)
{
	TArray<FVector> PathPoints;

	if (!WorldContext || !WorldContext->GetWorld())
		return PathPoints;
#if DRAW_FIND_PATH_DEBUG
	FlushPersistentDebugLines(WorldContext->GetWorld());
#endif
	UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(WorldContext->GetWorld());
	if (NavSys == nullptr || NavSys->GetDefaultNavDataInstance() == nullptr)
		return PathPoints;

	ANavigationData* NavigationData = Cast<ANavigationData>(NavSys->GetMainNavData());
	if (!NavigationData)
		return PathPoints;

	const ARecastNavMesh* NavMesh = Cast<ARecastNavMesh>(NavigationData);
	if (!NavMesh)
		return PathPoints;
	const FVector Extent(500, 500, 250);
	FVector RealStart = InStart;

	TArray<FVector> OutPathPoints;
	bool bWayPointSystem = false;
	if (UseWayPoint)
	{
		TArray<AActor*> OutActors;
		UGameplayStatics::GetAllActorsOfClass(WorldContext->GetWorld(), AWayPointSystem::StaticClass(), OutActors);
		
		if (OutActors.Num() > 0)
		{
			AWayPointSystem* System = Cast<AWayPointSystem>(OutActors[0]);
			bWayPointSystem = System->FindNearestPath(RealStart, InEnd, OutPathPoints);
		}
	}

	if(!bWayPointSystem)
	{

		NavNodeRef OriginPolyID = NavMesh->FindNearestPoly(InStart, Extent);
		if (OriginPolyID == INVALID_NAVNODEREF)
		{
			return PathPoints;
		}
		else 
		{
			NavMesh->GetClosestPointOnPoly(OriginPolyID, InStart, RealStart);
		}
		
		OutPathPoints.Empty();
		UNavigationPath* PathResult = UNavigationSystemV1::FindPathToLocationSynchronously(WorldContext, RealStart, InEnd);
		if (IsValid(PathResult) && PathResult->PathPoints.Num() > 1)
		{
			TSharedPtr<FNavMeshPath> Path = StaticCastSharedPtr<FNavMeshPath>(PathResult->GetPath());
			// 如果路径长度小于最大长度，则根据路径做射线碰撞，查询路径上是否有阻挡
			float PathLength = Path->GetTotalPathLength();
			if (PathLength <= MaxPathLength)
			{
				// 先对路径上比较靠近的点进行合并
				
				OutPathPoints = OffsetFromEdge(Path, MaxMergeLength, EdgeOffset);
			}
		}
	}
	if(OutPathPoints.Num() > 0)
	{
		PathPoints.Add(OutPathPoints[0]);

		int32 MergeST = 0;
		float MergeLengthTotal = 0.0f;

		for (int32 i = 1; i < OutPathPoints.Num(); ++i)
		{
			MergeLengthTotal += (OutPathPoints[i] - PathPoints[PathPoints.Num() - 1]).Size();
			if (MergeLengthTotal > MaxMergeLength)
			{
				if (MergeST == 0)
				{
					MergeST = i;
					MergeLengthTotal = 0.0f;
				}
				else
				{
					FVector MergePoint = FVector::ZeroVector;
					for (int32 j = MergeST; j < i; j++)
					{
						MergePoint += OutPathPoints[j];
					}
					MergePoint = MergePoint / (i - MergeST);
					PathPoints.Add(MergePoint);
				
					MergeST = i;
					MergeLengthTotal = 0.0f;
				}
			}
		}
		PathPoints.Add(OutPathPoints[OutPathPoints.Num() - 1]);
		
		if (AdjustToGroundInterval > 0.0f)
		{//如果需要调整至Ground，则采样
			TArray<FVector> GroundPoints = AdjustPathPointToGround(PathPoints, NavMesh, AdjustToGroundInterval);
			for (FVector& point : GroundPoints)
			{
				point.Z += GroundFlowOffset;
			}
			return GroundPoints;
		}
		return PathPoints;

	}
	return PathPoints;
}

bool UC7FunctionLibrary::FindPathPointListV2(UObject* WorldContext, const FVector& InStart, const FVector& InDest, bool UseWayPoint, float EdgeOffset, bool bRequireNavigableEndLocation, TArray<FVector>& OutPathPoints)
{
	OutPathPoints.Empty();
	if (!WorldContext || !WorldContext->GetWorld())
	{
		return false;
	}
	const ARecastNavMesh* NavMesh = GetNavMesh(WorldContext->GetWorld());
	if (!NavMesh)
	{
		return false;
	}

	if (UseWayPoint)
	{
		TArray<AActor*> OutActors;
		UGameplayStatics::GetAllActorsOfClass(WorldContext->GetWorld(), AWayPointSystem::StaticClass(), OutActors);

		if (OutActors.Num() > 0)
		{
			AWayPointSystem* System = Cast<AWayPointSystem>(OutActors[0]);
			if (System->FindNearestPath(InStart, InDest, OutPathPoints))
			{
				return true;
			}
		}
	}

	OutPathPoints.Empty();
	const FPathFindingQuery Query(NULL, *NavMesh, InStart, InDest, UNavigationQueryFilter::GetQueryFilter(*NavMesh, NULL, NULL), NULL, TNumericLimits<FVector::FReal>::Max(), bRequireNavigableEndLocation);
	const FPathFindingResult Result = NavMesh->FindPath(Query.NavAgentProperties, Query);
	if (!Result.IsSuccessful())
	{
		return false;
	}

	TSharedPtr<FNavMeshPath> Path = StaticCastSharedPtr<FNavMeshPath>(Result.Path);
	if (!Path || Path->GetPathPoints().Num() == 0)
	{
		return false;
	}

	if (!FMath::IsNearlyZero(EdgeOffset, KINDA_SMALL_NUMBER))
	{
		Path->OffsetFromCorners(EdgeOffset);
	}
	OutPathPoints.Reset(Path->GetPathPoints().Num());
	for (const auto& PathPoint : Path->GetPathPoints())
	{
		OutPathPoints.Add(PathPoint.Location);
	}

	return true;
}

bool UC7FunctionLibrary::GetNearestNaviPoint(UObject* WorldContext, const FVector& Point, const FVector& Extent, FVector& OutPoint)
{
	if (!WorldContext || !WorldContext->GetWorld())
	{
		return false;
	}
	const ARecastNavMesh* NavMesh = GetNavMesh(WorldContext->GetWorld());
	if (!NavMesh)
	{
		return false;
	}
	NavNodeRef OriginPolyID = NavMesh->FindNearestPoly(Point, Extent);
	if (OriginPolyID == INVALID_NAVNODEREF)
	{
		return false;
	}
	NavMesh->GetClosestPointOnPoly(OriginPolyID, Point, OutPoint);
	return true;
}

const ARecastNavMesh* UC7FunctionLibrary::GetNavMesh(UWorld* World)
{
	if (!World)
	{
		return nullptr;
	}
	UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(World);
	if (!NavSys || !NavSys->GetDefaultNavDataInstance())
	{
		return nullptr;
	}
	ANavigationData* NavigationData = Cast<ANavigationData>(NavSys->GetMainNavData());
	if (!NavigationData)
	{
		return nullptr;
	}
	const ARecastNavMesh* NavMesh = Cast<ARecastNavMesh>(NavigationData);
	return NavMesh;
}

bool UC7FunctionLibrary::GetWalkableFloorPos(FVector StartPos, FVector EndPos, FVector& OutPos, UObject* WorldContextObject)
{
	if (!UKismetSystemLibrary::IsValid(WorldContextObject))
		return false;

	FVector WalkableSearchRange(50, 50, 50);
	
	TArray<AActor*> IgnoredActors;
	TArray<FHitResult> OutHits;
	
	if (bool bHit = UKismetSystemLibrary::LineTraceMulti(
		WorldContextObject,
		StartPos,
		EndPos,
		ETraceTypeQuery::TraceTypeQuery1,
		false,
		IgnoredActors,
		EDrawDebugTrace::Type::None,
		OutHits,
		true
		))
	{
		const auto& Elem = OutHits.Last();
		if (Elem.HitObjectHandle.FetchActor()
			&& (Elem.HitObjectHandle.FetchActor()->IsA<ABaseCharacter>() || Elem.HitObjectHandle.FetchActor()->IsA<
				ALogicActor>()))
		{
			return false;
		}

		OutPos = Elem.ImpactPoint;
		if (UC7FunctionLibrary::FindNearstVaildPosition(WorldContextObject, Elem.ImpactPoint, WalkableSearchRange, OutPos))
		{
			return true;
		}
	}
	return false;
}

bool UC7FunctionLibrary::NavMeshRaycast(UObject* WorldContext, const FVector& InStart, const FVector& InDest, FVector& OutPos)
{
	if (!WorldContext || !WorldContext->GetWorld())
	{
		return false;
	}
	const ARecastNavMesh* NavMesh = GetNavMesh(WorldContext->GetWorld());
	if (!NavMesh)
	{
		return false;
	}
	return NavMesh->NavMeshRaycast(NavMesh, InStart, InDest, OutPos, NavMesh->GetDefaultQueryFilter());
}

#pragma endregion 3C

bool UC7FunctionLibrary::SetApplicationScale(float Scale)
{

	FString PlatformName = FPlatformProperties::IniPlatformName();
	if (PlatformName == "Windows")
	{
		const UUserInterfaceSettings* Settings = GetDefault<UUserInterfaceSettings>();
		UUserInterfaceSettings* MutableUISettings = const_cast<UUserInterfaceSettings*>(Settings);
		MutableUISettings->ApplicationScale = Scale;
	}

	return true;
}

FIntPoint UC7FunctionLibrary::GetViewportSize()
{
	if(GEngine == nullptr) return FIntPoint::ZeroValue;
	TObjectPtr<class UGameViewportClient> GameViewport = GEngine->GameViewport;
	if(GameViewport == nullptr) return FIntPoint::ZeroValue;
	FViewport* Viewport = GameViewport->Viewport;
	if(Viewport ==nullptr) return FIntPoint::ZeroValue;
	return Viewport->GetSizeXY();
}

#pragma region CrashReport

void UC7FunctionLibrary::UpdateCrashReportValue(const FString& Key, const FString& Value)
{
	FCrashCollector::UpdateValue(*Key, *Value);
}

static FString GetAppVersion()
{
	FString AppVersion;
#if !WITH_EDITOR
	FString Changelist, Branch;
	GConfig->GetString(TEXT("/Script/EngineSettings.GeneralProjectSettings"), TEXT("Changelist"), Changelist, GGameIni);
	GConfig->GetString(TEXT("/Script/EngineSettings.GeneralProjectSettings"), TEXT("ProjectBranchName"), Branch,
		GGameIni);
	int32 PatchVersion = GEngine->GetEngineSubsystem<UPakUpdateSubsystem>()->GetLocalP4Version();
#	if defined(C7_ENABLE_ASAN) || defined(__SANITIZE_ADDRESS__) || USING_ADDRESS_SANITISER
	if (Changelist.IsEmpty()) Changelist = FString::FromInt(PatchVersion);
	Branch = Branch.IsEmpty() ? FString(TEXT("Asan")) : TEXT("Asan_") + Branch;
#	endif
	AppVersion = FString::Printf(TEXT("%s.%d"), *Changelist, PatchVersion);
	if (!Branch.IsEmpty())
	{
		AppVersion += TEXT(".") + Branch;
	}
#endif
	return AppVersion;
}

static void UpdateAppVersion()
{
#if !WITH_EDITOR
	FCrashCollector::UpdateValue(TEXT("AppVersion"), *GetAppVersion());
#endif
}

void UC7FunctionLibrary::InitCrashReport()
{
#if !WITH_EDITOR
	UpdateAppVersion();
	GEngine->GetEngineSubsystem<UPakUpdateSubsystem>()->OnPreUpdateResultEvent.AddDynamic(
		GetMutableDefault<UC7FunctionLibrary>(), &UC7FunctionLibrary::OnPreUpdateResult);
#endif
}

void UC7FunctionLibrary::OnPreUpdateResult(int32 InErrorCode)
{
	if (InErrorCode) return;
	UpdateAppVersion();
}
void UC7FunctionLibrary::TestCrash()
{
#if !UE_BUILD_SHIPPING
	char* TestCrash = (char*)1;
	TestCrash[0] = 0;
#endif
}

void UC7FunctionLibrary::TestError()
{
#if !UE_BUILD_SHIPPING
	UE_LOG(LogTemp, Display, TEXT("Test Error"));
#endif	
}

void UC7FunctionLibrary::TestException()
{
#if !UE_BUILD_SHIPPING
	UE_LOG(LogTemp, Display, TEXT("Test Exception"));
#endif
}

FAutoConsoleCommand C7CrashInvalidAddressWrite(TEXT("c7.crash.InvalidAddressWrite"), TEXT("Test Crash for Invalid Address Writing"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		int64 Address = 0;
		if (Args.Num() > 0 && Args[0].IsNumeric())
		{
			Address = FCString::Atoi64(*Args[0]);
		}
		UE_LOG(LogTemp, Warning, TEXT("Test crash for 0x%llx set with a byte of zero"), Address)
		*(uint8*)Address = 0;
	}));

static void TestCrashMessage(int32 Type, const TArray<FString>& Args)
{
	const TCHAR* TypeStr = TEXT("LogFatal");
	if (Type == 1) TypeStr = TEXT("check");
	else if (Type == 2) TypeStr = TEXT("ensure");
	FString LogMessage = FString::Printf(TEXT("Test crash for %s"), TypeStr);
	if (Args.Num())
	{
		LogMessage += TEXT(":");
		for (auto& Arg : Args)
		{
			LogMessage += TEXT(" ") + Arg;
		}
	}
	switch (Type)
	{
	case 1:
		checkf(false, TEXT("%s"), *LogMessage);
		break;
	case 2:
		ensureMsgf(false, TEXT("%s"), *LogMessage);
		break;
	default:
		UE_LOG(LogTemp, Fatal, TEXT("%s"), *LogMessage);
		break;
	}
}

FAutoConsoleCommand C7CrashLogFatal(TEXT("c7.crash.LogFatal"), TEXT("Test Crash for LogFatal"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		TestCrashMessage(0, Args);
	}));

FAutoConsoleCommand C7CrashCheck(TEXT("c7.crash.check"), TEXT("Test Crash for check"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		TestCrashMessage(1, Args);
	}));

FAutoConsoleCommand C7CrashEnsure(TEXT("c7.crash.ensure"), TEXT("Test Crash for ensure"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		TestCrashMessage(2, Args);
	}));

FAutoConsoleCommand C7CrashDirtyObject(TEXT("c7.crash.DirtyObject"), TEXT("Test Crash for DirtyObject"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		UC7FunctionLibrary::GC();
		UObject* DirtyObject = NewObject<UC7FunctionLibrary>(GetTransientPackage(), "TestDirty");
		UC7FunctionLibrary::GC();
		if (!FObjCrashCollector::IsValid(DirtyObject))
		{
			UC7FunctionLibrary::TestCrash();
		}
	}));

FAutoConsoleCommand C7CrashTestLua(TEXT("c7.crash.TestCrashFromLua"), TEXT("Test Crash from lua"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		if (NS_SLUA::LuaState* L = NS_SLUA::LuaState::get())
		{
			L->call("DebugTestCrash");
		}
	}));

FAutoConsoleCommand C7ErrorTestLua(TEXT("c7.crash.TestErrorFromLua"), TEXT("Test Crash from lua"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		if (NS_SLUA::LuaState* L = NS_SLUA::LuaState::get())
		{
			L->call("DebugTestError");
		}
	}));

FAutoConsoleCommand C7ExceptionTestLua(TEXT("c7.crash.TestExceptionFromLua"), TEXT("Test exception from lua"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		if (NS_SLUA::LuaState* L = NS_SLUA::LuaState::get())
		{
			L->call("DebugTestException");
		}
	}));

static int LuaErrorTestFunc(NS_SLUA::lua_State *L)
{
	using namespace NS_SLUA;
	UE_LOG(LogTemp, Display, TEXT("Before calling luaL_error"));
	luaL_error(L, "luaL_error called");
	UE_LOG(LogTemp, Warning, TEXT("After luaL_error called"));
	return 0;
}

FAutoConsoleCommand C7TestLuaError(TEXT("c7.crash.TestLuaError"), TEXT("Test lua error"), FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
{
	using namespace NS_SLUA;
	if (LuaState* Ls = LuaState::get())
	{
		const ANSICHAR* FuncName = "_LuaErrorTestFunc";
		lua_pushcfunction(Ls->getLuaState(), &LuaErrorTestFunc);
		lua_setglobal(Ls->getLuaState(), FuncName);
		check(!lua_gettop(Ls->getLuaState()));
		Ls->call(FuncName);
	}
}));

FAutoConsoleCommand C7TestFatalLogRenderThread(TEXT("c7.crash.TestFatalLogRenderThread"), TEXT("Test Fatal Log in RenderThread"), FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
{
	ENQUEUE_RENDER_COMMAND(C7TestFatalLogRenderThread)([](FRHICommandListImmediate&)
	{
		UE_LOG(LogTemp, Fatal, TEXT("Test Fatal Log in RenderThread"))
	});
}));

#if PLATFORM_WINDOWS
FAutoConsoleCommand C7CrashWindowsBinnedAllocFromOS(TEXT("c7.crash.Windows.BinnedAllocFromOS"),
	TEXT("Test Crash for BinnedAllocFromOS of Windows"), FConsoleCommandWithArgsDelegate::CreateLambda(
		[](const TArray<FString>& Args)
	{
		void* Ptr = FWindowsPlatformMemory::BinnedAllocFromOS((SIZE_T)-1);
		if (!Ptr)
		{
			UC7FunctionLibrary::TestCrash();
		}
	}));
#endif

#pragma endregion CrashReport
