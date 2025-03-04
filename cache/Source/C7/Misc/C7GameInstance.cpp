// Fill out your copyright notice in the Description page of Project Settings.


#include "Misc/C7GameInstance.h"

#include "Misc/Log.h"
#include "Framework/Application/SlateApplication.h"
#include "UI/C7Navigation/C7NavigationConfig.h"
#include "Kismet/GameplayStatics.h"
#include "DoraSDK.h"
#include "AI/NavigationSystemBase.h"

#if WITH_EDITOR
#include "Engine/LocalPlayer.h"
#include "GameFramework/GameModeBase.h"
#include "Settings/LevelEditorPlaySettings.h"
#include "Editor/EditorEngine.h"
#endif

#include "Localization/LocalizationManager.h"
#include "RoleComposite/RoleCompositeManager.h"


#include "C7FunctionLibrary.h"
#include "AkAudioDevice.h"

#include "EngineUtils.h"

#include "LowMemoryWatcher.h"
//#include "Lua/InsightProfiler/LuaInsightProfiler.h"
#include "MoviePlayer.h"
#include "WorldPartition/WorldPartitionLevelStreamingDynamic.h"

#include "3C/Character/BaseCharacter.h"
#include "GameFramework/Character.h"
#include "RoleMovementComponent.h"
#include "3C/SyncProtocol/NetSyncManager.h"
#include "Opt/OptCmdMgr.h"
#include "WorldPartition/WorldPartitionRuntimeSpatialHash.h"

#if UE_TRACE_ENABLED
#include "Trace/Trace.h"
#endif


UC7GameInstance::UC7GameInstance()
{
	bGameplayInit = false;
}

static void SLuaEnvCheck()
{
	// 如果没有Main.lua，那么八成就是没有"Script"文件夹！！
#if WITH_EDITOR
	const FString SourceMainFile = FPaths::ProjectContentDir() / FString("Script") / FString("Gameplay/GameInit/Main.lua");
	if (IFileManager::Get().FileExists(*SourceMainFile))
		return;
#endif

	const FString MainFile = FPaths::ProjectContentDir() / FString("ScriptOPCode") / FString("Gameplay/GameInit/Main.luac");
	if (!IFileManager::Get().FileExists(*MainFile))
	{
#if WITH_EDITOR
		UE_LOG(LogTemp, Error, TEXT("call@liubo11. SLua!! Can't Find:%s"), *MainFile);
#else
		UE_LOG(LogTemp, Fatal, TEXT("call@liubo11. SLua!! Can't Find:%s"), *MainFile);
#endif
	}
}

void UC7GameInstance::Init()
{
	ULoger::Init();

	CreateKGLua();
	//start patch
	LuaGameInstance->OnLuaPatchBegin(this);

	// SLuaEnvCheck();

	//ToDo: 暂时这样子，等调试完CrashSight启动问题后会删除
	UC7FunctionLibrary::InitCrashReport();
	
	Super::Init();

	//if (UC7VersionSubsystem* VersionSubsystem = UC7FunctionLibrary::GetC7VersionSubsystem())
	//{
	//	VersionSubsystem->OnTaskMounted.AddDynamic(this, &UC7GameInstance::OnHotPatchFlowEnd);
	//}

	OnMapLoadedDelegateHandle = FCoreUObjectDelegates::PostLoadMapWithWorld.AddUObject(this, &UC7GameInstance::OnPostLoadMapWithWorld);
	FWorldDelegates::OnWorldTickStart.AddUObject(this, &UC7GameInstance::OnWorldTick);

	OnMapLoadFailureDelegateHandle = GEngine->OnTravelFailure().AddUObject(this, &UC7GameInstance::OnLoadMapFailure);

#if WITH_EDITOR
	FEditorDelegates::PostPIEStarted.AddUObject(this, &UC7GameInstance::OnPostPIEStarted);
#endif

#if PLATFORM_WINDOWS
	// 监听Viewport变化事件，调整状态栏的位置
	FViewport::ViewportResizedEvent.AddUObject(this, &UC7GameInstance::OnViewportResized);
#endif
	//移除Streaming时loading UI
	if (GEngine)
	{
		GEngine->RegisterBeginStreamingPauseRenderingDelegate(nullptr);
		GEngine->RegisterEndStreamingPauseRenderingDelegate(nullptr);
	}

	//C7Navigation
	FSlateApplication::Get().SetNavigationConfig(MakeShared<FC7NavigationConfig>());
	FWorldDelegates::LevelAddedToWorld.AddUObject(this, &UC7GameInstance::OnLevelChanged, true);
	FWorldDelegates::PreLevelRemovedFromWorld.AddUObject(this, &UC7GameInstance::OnLevelChanged, false);
}

void UC7GameInstance::Shutdown()
{
	FWorldDelegates::LevelAddedToWorld.RemoveAll(this);
	FWorldDelegates::PreLevelRemovedFromWorld.RemoveAll(this);
#if WITH_EDITOR
	FSlateApplication::Get().SetNavigationConfig(MakeShared<FNavigationConfig>());
#endif
#if WITH_EDITOR
	FEditorDelegates::PostPIEStarted.RemoveAll(this);
#endif

	FCoreUObjectDelegates::PostLoadMapWithWorld.Remove(OnMapLoadedDelegateHandle);
	FWorldDelegates::OnWorldTickStart.RemoveAll(this);

	GEngine->OnTravelFailure().Remove(OnMapLoadFailureDelegateHandle);

	OnGameplayUnInit();

	DeleteKGLua();

	if (DoraSDK)
	{
		DoraSDK->Uninit();
		DoraSDK->RemoveFromRoot();
		DoraSDK = nullptr;
	}

	ULoger::UnInit();

	//引擎层的关闭需要最后执行，不然game instance里的worldcontext等内容会被清理
	Super::Shutdown();
}

void UC7GameInstance::OnStart()
{
	Super::OnStart();
}

void UC7GameInstance::StartGameInstance()
{
	Super::StartGameInstance();
}

void UC7GameInstance::OnObjectCountNearlyExceed(int32 CurrentObjectCount)
{
	Super::OnObjectCountNearlyExceed(CurrentObjectCount);
	LuaGameInstance->OnObjectCountNearlyExceed(CurrentObjectCount);
}

void UC7GameInstance::OnGameplayInit()
{
	if (bGameplayInit)
	{
		return;
	}

	bGameplayInit = true;

	RegisterForeAndBackGroundEvent();
	DoraSDK = NewObject<UDoraSDK>(this, UDoraSDK::StaticClass());
	DoraSDK->Init(KGLua->GetLuaState());
	DoraSDK->SetSceneMessageCallback(UNetSyncManager::DispatchSceneMessage);
	
	LowMemoryWatcher = NewObject<ULowMemoryWatcher>(this);
	if (LowMemoryWatcher)
	{
		LowMemoryWatcher->Init(this);
	}


	// lua init
	LuaGameInstance->BeginPlay(this);

	DoraSDK->InitRunScript();
}

void UC7GameInstance::OnGameplayUnInit()
{
	if (bGameplayInit == false)
	{
		return;
	}

	bGameplayInit = false;
	UnRegisterForeAndBackGroundEvent();
	// lua uninit
	LuaGameInstance->EndPlay();

	if (LowMemoryWatcher)
	{
		LowMemoryWatcher->Uninit();
		LowMemoryWatcher = nullptr;
	}

}

void UC7GameInstance::OnPostLoadMapWithWorld(UWorld* World)
{
	check(World);

	// UE_LOG(LogTemp, Log, TEXT("liubo, opt, LoadMap Done!! Map=%s"), *World->GetMapName());

	LuaGameInstance->OnLuaMapLoaded(World->GetMapName());
	FOptHelper::PostLoadMap(World);

	int& V = TrackWorldLoadState.FindOrAdd(World);
	V = 0;
}

void UC7GameInstance::OnWorldTick(UWorld* World, ELevelTick, float)
{
	TRACE_CPUPROFILER_EVENT_SCOPE(UC7GameInstance::OnWorldTick);

	if (World && TrackWorldLoadState.Contains(World))
	{
		TrackWorldLoadState[World]++;
		if (TrackWorldLoadState[World] < 5)
		{
			// FPlatformProcess::Sleep(0.005f);

			// UE_LOG(LogTemp, Log, TEXT("liubo, opt, GI TickCount=%d"), TrackWorldLoadState[World]);

			// 引擎没有提供接口，所有hack一下
			// 第一帧要准备渲染内容，可能会导致占用时间很长。
			// 第二次tick的时候，地图确认已经完全加载好了
			if (TrackWorldLoadState[World] == 2)
			{
				LuaGameInstance->OnLuaMapReady(World, World->GetMapName());
			}
		}
		else
		{
			// UE_LOG(LogTemp, Log, TEXT("liubo, opt, Destroy GI TickCount=%d"), TrackWorldLoadState[World]);
			TrackWorldLoadState.Remove(World);
		}
	}
}

void UC7GameInstance::OnLoadMapFailure(UWorld* InWorld, ETravelFailure::Type FailureType, const FString& ErrorString)
{
	FString MSG = FString::Printf(TEXT("Travel Failure: [%s]: %s"), ETravelFailure::ToString(FailureType), *ErrorString);

	UE_LOG(LogC7, Warning, TEXT("%s"), *MSG);

	LuaGameInstance->OnLuaLoadMapError(MSG);
}

namespace c7gameplay
{
	struct FSimpleGridInfo
	{
		FName GridName = NAME_None;
		FVector Origin = FVector::Zero();
		int32 CellSize = 0;
	};	
}
static int GetCellLevel(int Size)
{
	// 0->0, 1->1, 2->2, 4->3, 8->4, 16->5
	if(Size < 0)
	{
		return 0;
	}
	else if(Size <= 2)
	{
		return Size;
	}
	
	return FMath::CeilToInt(FMath::Log2((float)Size)) + 1;
}
static bool GetCellCoord(FIntVector& Out, const TMap<FName, c7gameplay::FSimpleGridInfo>& DataSet, FName GridName, const FBox& CellBound)
{
	auto Ptr = DataSet.Find(GridName);
	if(Ptr)
	{
		auto Pos = CellBound.GetCenter() - Ptr->Origin;
		Out.Z = GetCellLevel(CellBound.GetExtent().X / Ptr->CellSize);
		Out.X = Pos.X / (Ptr->CellSize * FMath::Pow((float)2, Out.Z));
		Out.Y = Pos.Y / (Ptr->CellSize * FMath::Pow((float)2, Out.Z));
		return true;
	}
	return false;
}

void UC7GameInstance::OnLevelChanged(ULevel* Level, UWorld* World, bool Added)
{
	if(!LuaGameInstance)
	{
		return;
	}
	
	if (Level && World)
	{
		if (World->IsPartitionedWorld())
		{
			bool bFind = false;
			auto Levels = World->GetStreamingLevels();
			for (auto StreamingLevel : Levels)
			{
				if (StreamingLevel && StreamingLevel->GetLoadedLevel() == Level)
				{
					bFind = true;
					UWorldPartitionLevelStreamingDynamic* WpStreaming = Cast<UWorldPartitionLevelStreamingDynamic>(StreamingLevel);
					if (WpStreaming && WpStreaming->GetWorldPartitionRuntimeCell())
					{
						if (!WpStreaming->GetWorldPartitionRuntimeCell()->GetIsHLOD())
						{
							TMap<FName, c7gameplay::FSimpleGridInfo> GridMap;
							UWorldPartitionRuntimeHash* RuntimeHash = World->GetWorldPartition()->RuntimeHash;
							const UWorldPartitionRuntimeSpatialHash* RuntimeSpatialHash = Cast<UWorldPartitionRuntimeSpatialHash>(RuntimeHash);
							if(RuntimeSpatialHash)
							{
								RuntimeSpatialHash->ForEachStreamingGrid([&GridMap](const FSpatialHashStreamingGrid& GridInfo)
								{
									c7gameplay::FSimpleGridInfo One;
									One.Origin = GridInfo.Origin;
									One.CellSize = GridInfo.CellSize;
									One.GridName = GridInfo.GridName;
									GridMap.Add(GridInfo.GridName, One);
									return;
								});								
							}

							auto Cell = WpStreaming->GetWorldPartitionRuntimeCell();
							FBox Bounds(ForceInit);
							Bounds = Cell->GetCellBounds();

							FName GridName = Cell->RuntimeCellData ? Cell->RuntimeCellData->GridName : NAME_None;
							auto CellDebugName = Cell->RuntimeCellData ? Cell->RuntimeCellData->GetDebugName() : TEXT("None");

							FIntVector Coord;
							if(GetCellCoord(Coord, GridMap, GridName, Bounds))
							{
								int Lv = Coord.Z;
								int X = Coord.X;
								int Y = Coord.Y;
								UE_LOG(LogTemp, Log, TEXT("[WP action] OnWpCellLoaded:%s. L=%d, X=%d, Y=%d"), 
									*CellDebugName,
									Lv, X, Y);
								if(GridName == "MainGrid")
								{
									LuaGameInstance->OnLuaWpCellLoaded(World, Added, X, Y, Lv, Bounds);									
								}									
							}
							else
							{
								UE_LOG(LogTemp, Error, TEXT("[WP action] Not Valid Name:%s, GridName=%s, Level=%s"),
									*CellDebugName, 
									*GridName.ToString(),
									*Level->GetPathName());
							}							
						}
					}
					else
					{
						UE_LOG(LogTemp, Warning, TEXT("[WP action] Not Wp Streaming! 2"));
					}
					break;
				}
			}
			if (!bFind)
			{
				UE_LOG(LogTemp, Warning, TEXT("[WP action] Not Find Level! %s"), *Level->GetFullName());
			}
		}
		else
		{
			// UE_LOG(LogTemp, Log, TEXT("[WP action] Not WP!"));
		}
	}
	else
	{
		// UE_LOG(LogTemp, Log, TEXT("[WP action] Not Valid Level Or World!"));
	}
}

void UC7GameInstance::RegisterForeAndBackGroundEvent()
{
#if PLATFORM_ANDROID || PLATFORM_IOS
	FCoreDelegates::ApplicationWillEnterBackgroundDelegate.AddUObject(LuaGameInstance, &ULuaGameInstance::ApplicationWillEnterBackground);
	FCoreDelegates::ApplicationHasEnteredForegroundDelegate.AddUObject(LuaGameInstance, &ULuaGameInstance::ApplicationHasEnteredForeground);
#elif PLATFORM_WINDOWS 
	if (GEngine && GEngine->GameViewport)
	{
		if (const TSharedPtr<SWindow> Window = GEngine->GameViewport->GetWindow(); Window && Window.IsValid())
		{
			Window.Get()->GetOnWindowActivatedEvent().AddUObject(this, &UC7GameInstance::OnWindowActivatedEvent);
			Window.Get()->GetOnWindowDeactivatedEvent().AddUObject(this, &UC7GameInstance::OnWindowDeactivatedEvent);
		}
	}
#endif
}

void UC7GameInstance::UnRegisterForeAndBackGroundEvent()
{
#if PLATFORM_ANDROID || PLATFORM_IOS
	FCoreDelegates::ApplicationWillEnterBackgroundDelegate.RemoveAll(LuaGameInstance);
	FCoreDelegates::ApplicationHasEnteredForegroundDelegate.RemoveAll(LuaGameInstance);
#elif PLATFORM_WINDOWS
	if (GEngine && GEngine->GameViewport)
	{
		if (const TSharedPtr<SWindow> Window = GEngine->GameViewport->GetWindow(); Window && Window.IsValid())
		{
			Window.Get()->GetOnWindowActivatedEvent().RemoveAll(this);
			Window.Get()->GetOnWindowDeactivatedEvent().RemoveAll(this);
		}
	}
#endif
}

#if PLATFORM_WINDOWS
void UC7GameInstance::OnViewportResized(FViewport* Viewport, uint32 Unused)
{
	if (Viewport && GEngine && GEngine->GetGameUserSettings())
	{
		//在窗口化PC包体中检查窗口高度和屏幕高度，在窗口高度超出时自动下移出任务栏的高度
		EWindowMode::Type currentWindowMode = GEngine->GetGameUserSettings()->GetFullscreenMode();
		if (currentWindowMode == EWindowMode::Windowed)
		{
			// Make sure the viewport reference is valid
			if (GEngine->GameViewport)
			{
				// Reference of the viewport
				TSharedPtr<SWindow> Window = GEngine->GameViewport->GetWindow();
				if (!Window.IsValid())
				{
					return;
				}
				// Get the native window for platform-specific details
				TSharedPtr<FGenericWindow> NativeWindow = Window->GetNativeWindow();
				if (!NativeWindow.IsValid())
				{
					return;
				}
				// Only change if the new height is equal or larger than the screen's max height resolution
				int32 ScreenHeight = GEngine->GetGameUserSettings()->GetDesktopResolution().Y;
				if (Viewport->GetSizeXY().Y < ScreenHeight)
				{
					return;
				}
				FVector2D Offset = FVector2D::ZeroVector;
				int32 CurrentScreenPosition = Window->GetPositionInScreen().X;
				// Shift the window down for the distance of title + border
				Offset.X = CurrentScreenPosition;
				Offset.Y = NativeWindow->GetWindowTitleBarSize() + NativeWindow->GetWindowBorderSize();
				Window->MoveWindowTo(Offset);
			}
		}
	}
}
#endif

#if PLATFORM_WINDOWS
void UC7GameInstance::OnWindowActivatedEvent()
{
	if (LuaGameInstance)
	{
		LuaGameInstance->OnWindowForceChanged(false, false);
	}
}

void UC7GameInstance::OnWindowDeactivatedEvent()
{
	if (LuaGameInstance)
	{
		bool bWindowMinimized = false;
		if (GEngine && GEngine->GameViewport)
		{
			if (const TSharedPtr<SWindow> Window = GEngine->GameViewport->GetWindow(); Window && Window.IsValid())
			{
				bWindowMinimized = Window->IsWindowMinimized();
			}
		}
		LuaGameInstance->OnWindowForceChanged(true, bWindowMinimized);
	}
}
#endif

void UC7GameInstance::HotPatchFlowEnd(int32 InMapId)
{
	UE_LOG(LogC7, Warning, TEXT("OnHotPatchFlowEnd %d"), InMapId);


	OnGameplayInit();
}

void UC7GameInstance::EngineExec(FString Cmd)
{
	if (GEngine)
	{
		GEngine->Exec(NULL, *Cmd);
	}
}

void UC7GameInstance::ConsoleCommand(FString Cmd)
{
	APlayerController* PC = GetFirstLocalPlayerController();
	if (PC)
	{
		PC->ConsoleCommand(Cmd);
	}
}

#if WITH_EDITOR
void UC7GameInstance::OnPostPIEStarted(bool bIsSimulating)
{
	UEditorEngine* EditorEngine = Cast<UEditorEngine>(GEngine);
	if (EditorEngine)
	{
		OnPostLoadMapWithWorld(EditorEngine->PlayWorld);
	}
}

#endif

void UC7GameInstance::K2_OnApplicationWillEnterBackground()
{
	if (FAkAudioDevice* Device = FAkAudioDevice::Get())
	{
		Device->Suspend();
	}

}
void UC7GameInstance::K2_OnApplicationHasEnteredForeground()
{
	if (FAkAudioDevice* Device = FAkAudioDevice::Get())
	{
		Device->WakeupFromSuspend();
	}
}

void UC7GameInstance::BeginLoadingScreen(const FString& MoviePath, bool bPlayUntilStopped, float PlayTime)
{
	FLoadingScreenAttributes LoadingScreen;
	LoadingScreen.bAutoCompleteWhenLoadingCompletes = !bPlayUntilStopped;
	LoadingScreen.bWaitForManualStop = bPlayUntilStopped;
	LoadingScreen.bAllowEngineTick = bPlayUntilStopped;
	LoadingScreen.MinimumLoadingScreenDisplayTime = PlayTime;
	LoadingScreen.PlaybackType = EMoviePlaybackType::MT_Looped;
	LoadingScreen.bUseServerTravel = true;
	LoadingScreen.MoviePaths.Add(MoviePath);
	GetMoviePlayer()->SetupLoadingScreen(LoadingScreen);
	GetMoviePlayer()->PlayMovie();
}

void UC7GameInstance::EndLoadingScreen()
{
	GetMoviePlayer()->OnServerTravelEnd();
}

void UC7GameInstance::NativeOpenMap(const FString& InMapName)
{
	UWorld* CW = GetWorld();
	check(CW);

	GetWorld()->ServerTravel(InMapName);
}



void UC7GameInstance::GM()
{
	LuaGameInstance->OnLuaShowGM();
}

void UC7GameInstance::ExecGM(FString& Cmd)
{
	LuaGameInstance->OnLuaExecGM(Cmd);
}
void UC7GameInstance::C7Cmd(FString& Cmd)
{
	const TCHAR* pCmd = *Cmd;

	if (FParse::Command(&pCmd, TEXT("OptCollisionDump")))
	{
		for (FActorIterator ActorIt(GetWorld()); ActorIt; ++ActorIt)
		{
			ActorIt->ForEachComponent<UPrimitiveComponent>(false, [ActorIt](UPrimitiveComponent* Comp)
				{
					if (Comp && Comp->IsPhysicsStateCreated() && Comp->GetBodySetup())
					{
#if WITH_EDITOR
						UE_LOG(LogTemp, Log, TEXT("Dump Phys, Actor=%s, CompName=%s, CompType=%s"), *ActorIt->GetActorLabel(), *Comp->GetName(), *Comp->GetClass()->GetName());
#else
						UE_LOG(LogTemp, Log, TEXT("Dump Phys, Actor=%s, CompName=%s, CompType=%s"), *ActorIt->GetName(), *Comp->GetName(), *Comp->GetClass()->GetName());
#endif
					}
				});
		}
		return;
	}
	if (FParse::Command(&pCmd, TEXT("OptCollisionDisable")))
	{
		for (FActorIterator ActorIt(GetWorld()); ActorIt; ++ActorIt)
		{
			ActorIt->ForEachComponent<UStaticMeshComponent>(false, [ActorIt](UStaticMeshComponent* Comp)
				{
					if (Comp && Comp->IsPhysicsStateCreated() && Comp->GetBodySetup())
					{
						Comp->SetCollisionProfileName("NoCollision");
#if WITH_EDITOR
						UE_LOG(LogTemp, Log, TEXT("222 Dump Phys, Actor=%s, CompName=%s, CompType=%s"), *ActorIt->GetActorLabel(), *Comp->GetName(), *Comp->GetClass()->GetName());
#else
						UE_LOG(LogTemp, Log, TEXT("222 Dump Phys, Actor=%s, CompName=%s, CompType=%s"), *ActorIt->GetName(), *Comp->GetName(), *Comp->GetClass()->GetName());
#endif
					}
				});
		}
		return;
	}

	UE_LOG(LogTemp, Error, TEXT("Unknow Cmd"), *Cmd);
}

bool UC7GameInstance::IsPIE()
{
	const FWorldContext* WC = GetWorldContext();
	if (WC && WC->WorldType == EWorldType::Type::PIE)
	{
		return true;
	}
	else
	{
		return false;
	}
}

void UC7GameInstance::ToggleTraceChannel(FString InChannel, bool InEnable)
{
#if UE_TRACE_ENABLED
	UE::Trace::ToggleChannel(*InChannel, InEnable);
#endif
}


void UC7GameInstance::CreateKGLua()
{
	check(KGLua == nullptr);

	KGLua = new FKGLua();

	KGLua->CreateLuaState(this);

	this->LuaGameInstance = KGLua->GetLuaGameInstance();
}

void UC7GameInstance::DeleteKGLua()
{
	check(KGLua);
	KGLua->CloseLuaState();
	delete KGLua;
	KGLua = nullptr;
}