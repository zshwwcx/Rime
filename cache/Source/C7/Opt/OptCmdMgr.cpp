
#include "Opt/OptCmdMgr.h"

#include "JsonObjectConverter.h"
#include "KgCoreUtils.h"
#include "KismetTraceUtils.h"
#include "LandscapeComponent.h"
#include "NiagaraComponent.h"
#include "NiagaraSystem.h"
#include "VirtualShadowMapDefinitions.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Blueprint/WidgetTree.h"
#include "Chaos/TriangleMeshImplicitObject.h"
#include "Components/CanvasPanel.h"
#include "Components/CapsuleComponent.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/SplineComponent.h"
#include "Elements/Framework/TypedElementRegistry.h"
#include "GameFramework/GameUserSettings.h"
#include "Materials/MaterialInstance.h"
#include "Engine/LevelStreaming.h"
#include "Engine/TextureCube.h"
#include "Engine/TextureRenderTarget2D.h"
#include "Engine/VolumeTexture.h"
#include "GameFramework/Character.h"
#include "Kismet/GameplayStatics.h"
#include "ProfilingDebugging/HealthSnapshot.h"
#include "GameFramework/SaveGame.h"
#include "HAL/FileManagerGeneric.h"
#include "Misc/ArchiveMD5.h"
#include "Misc/OutputDeviceArchiveWrapper.h"
#include "Misc/OutputDeviceFile.h"
#include "PhysicsEngine/BodySetup.h"
#include "WorldPartition/WorldPartitionLevelStreamingDynamic.h"
#include "WorldPartition/WorldPartitionRuntimeLevelStreamingCell.h"
#include "WorldPartition/HLOD/HLODActor.h"

DEFINE_LOG_CATEGORY(LogOptCmd);

UWorld* FOptHelper::GetGameWorld()
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

FAutoConsoleCommand Opt4(TEXT("opt.opt4"), TEXT("opt.opt4"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
{
	UE_LOG(LogOptCmd, Warning, TEXT("opt4 Cmd"));	
}));

FString FOptHelper::GetTab(int Depth)
{
	FString Ret;
	while(Depth > 0)
	{
		Depth--;
		Ret += "    ";
	}
	return Ret;
}

void FOptHelper::DumpWidgetTree(UWidget* Widget, int Depth)
{
	if(Widget == nullptr)
	{
		return;
	}

	if(Widget->GetClass() && Widget->GetClass()->GetPackage())
	{		
		UE_LOG(LogOptCmd, Log, TEXT("%sUUserWidget, Obj=%s, Visibility=%d"), *GetTab(Depth), *Widget->GetName(), 
			Widget->GetVisibility());	
	}
	else
	{
		return;
	}
	
	UPanelWidget* pNewUPanelWidget = Cast<UPanelWidget>(Widget);
	if(pNewUPanelWidget)
	{							
		for (int i = 0; i < pNewUPanelWidget->GetChildrenCount(); ++i)
		{
			UWidget* pChildUWidget = pNewUPanelWidget->GetChildAt(i);
			DumpWidgetTree(pChildUWidget, Depth+1);
		}
	}

	UUserWidget* UserWidget = Cast<UUserWidget>(Widget);
	if(UserWidget)
	{
		UserWidget->WidgetTree->ForEachWidget([Depth](UWidget* W)
		{
			DumpWidgetTree(W, Depth+1);
		});
	}
}

void FOptHelper::PostLoadMap(UWorld* World)
{
	FString MapName;
	if(World)
	{
		MapName = World->GetMapName();	
	}
	
	if(!MapName.IsEmpty())
	{
		// 自动执行一些命令		
		FString Section("C7GameCmd");

		// 如果GameUserSettings中没有，那么自动添加一下
		static bool bEntered = false;
		if(!bEntered)
		{		
			bEntered = true;
			bool bDirty = false;
			TArray<FString> SectionNames;
			GConfig->GetSectionNames(GEngineIni, SectionNames);
			for(const auto& It : SectionNames)
			{
				if(It.StartsWith("C7GameCmd"))
				{
					// 写入到usersetting中					
					TArray<FString> TempCmdList;
					GConfig->GetArray(*It, TEXT("Cmd"), TempCmdList, GGameUserSettingsIni);
					if(TempCmdList.Num() == 0)
					{
						GConfig->GetArray(*It, TEXT("Cmd"), TempCmdList, GEngineIni);
						if(TempCmdList.Num() > 0)
						{
							GConfig->SetArray(*It, TEXT("Cmd"), TempCmdList, GGameUserSettingsIni);
							bDirty = true;
							UE_LOG(LogTemp, Log, TEXT("liubo, copy Engine.ini to GameUserSettings.ini, Section=%s"), *It);
						}
					}
				}
			}
			if(bDirty)
			{
				GConfig->Flush(false, GGameUserSettingsIni);			
			}
		}
		
		Section += "@" + MapName;
		TArray<FString> CmdList;
		GConfig->GetArray(*Section, TEXT("Cmd"), CmdList, GGameUserSettingsIni);
		if (CmdList.Num() == 0)
		{
			GConfig->GetArray(*Section, TEXT("Cmd"), CmdList, GEngineIni);
		}
		for(const auto& Cmd : CmdList)
		{
			UE_LOG(LogTemp, Log, TEXT("liubo, auto Cmd, PostLoadMap, Section=%s, Cmd=%s"), *Section, *Cmd);
			GEngine->Exec(nullptr, *Cmd);
		}
	}
}

void FOptHelper::DumpConsoleValue(const TCHAR* ConsoleName)
{

	IConsoleVariable* ConsoleVariablePtr = IConsoleManager::Get().FindConsoleVariable(ConsoleName);
	FString Msg("");
	if(ConsoleVariablePtr)
	{
		FString Value("UnknownValue");
		if(ConsoleVariablePtr->IsVariableInt())
		{
			Value = FString::FromInt(ConsoleVariablePtr->GetInt());
		}
		else if(ConsoleVariablePtr->IsVariableFloat())
		{
			Value = FString::Printf(TEXT("%f"), ConsoleVariablePtr->GetFloat());
		}
		else if(ConsoleVariablePtr->IsVariableBool())
		{
			Value = ConsoleVariablePtr->GetBool() ? TEXT("True") : TEXT("False");
		}
		else if(ConsoleVariablePtr->IsVariableString())
		{
			Value = ConsoleVariablePtr->GetString();
		}
		
		Msg = FString::Printf(TEXT("%s=%s"), ConsoleName, *Value);
	}
	else
	{
		Msg = FString::Printf(TEXT("%s Not Found!!!"), ConsoleName);		
	}
	GEngine->AddOnScreenDebugMessage(-1, 5, FColor::Red, Msg);
	UE_LOG(LogTemp, Log, TEXT("DumpConsoleValue:%s"), *Msg);	
}

// dump ui的层级结构
FAutoConsoleCommand OptDumpUI(TEXT("opt.dumpUI2"), TEXT("opt.dumpUI"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
{
	UE_LOG(LogOptCmd, Warning, TEXT("opt dumpUI2"));
	
	auto World = FOptHelper::GetGameWorld();
	if(World != nullptr)
	{	
		for (FThreadSafeObjectIterator Iter(UUserWidget::StaticClass()); Iter; ++Iter)
		{
			UUserWidget* UserWidget = Cast<UUserWidget>(*Iter);
			if(Iter->GetWorld() == World && UserWidget)
			{
				if(Iter->GetClass() && Iter->GetClass()->GetPackage())
				{
					UPackage* Package = Iter->GetClass()->GetPackage();
					FString Name = FPackageName::GetShortName(Package->GetName());;
				
					UE_LOG(LogOptCmd, Log, TEXT("UUserWidget, Obj=%s, Package=%s, Visible=%d, Visibility=%d"), *Iter->GetName(), *Name,
						UserWidget->IsInViewport(),
						UserWidget->GetVisibility());	
				}
								
			}			
		}
		
		for (FThreadSafeObjectIterator Iter(UUserWidget::StaticClass()); Iter; ++Iter)
		{
			UUserWidget* UserWidget = Cast<UUserWidget>(*Iter);
			if(Iter->GetWorld() == World && UserWidget)
			{
				if(Iter->GetClass() && Iter->GetClass()->GetPackage())
				{
					UPackage* Package = Iter->GetClass()->GetPackage();
					FString Name = FPackageName::GetShortName(Package->GetName());;
				
					if(UserWidget->IsVisible())
					{
						FOptHelper::DumpWidgetTree(UserWidget, 0);
					}
				}
								
			}			
		}
	}
}));

/// toggle ui。显示、隐藏所有的UI
FAutoConsoleCommand OptToggleUI(TEXT("opt.toggleUI"), TEXT("opt.toggleUI"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
{
	UE_LOG(LogOptCmd, Warning, TEXT("opt toggleUI"));
	
	auto World = FOptHelper::GetGameWorld();
	if(World != nullptr)
	{	
		for (FThreadSafeObjectIterator Iter(UUserWidget::StaticClass()); Iter; ++Iter)
		{
			UUserWidget* UserWidget = Cast<UUserWidget>(*Iter);
			if(Iter->GetWorld() == World && UserWidget)
			{
				if(Iter->GetClass() && Iter->GetClass()->GetPackage())
				{
					if(UserWidget->IsInViewport())
					{
						UPackage* Package = Iter->GetClass()->GetPackage();
						FString Name = FPackageName::GetShortName(Package->GetName());;
					
						UE_LOG(LogOptCmd, Log, TEXT("UUserWidget, Obj=%s, Package=%s, Visible=%d, Visibility=%d"), *Iter->GetName(), *Name,
							UserWidget->IsInViewport(),
							UserWidget->GetVisibility());
						
						if(UserWidget->GetVisibility() == ESlateVisibility::Hidden)
						{
							UserWidget->SetVisibility(ESlateVisibility::SelfHitTestInvisible);			
						}
						else
						{			
							UserWidget->SetVisibility(ESlateVisibility::Hidden);								
						}
					}	
				}
								
			}			
		}
	}
}));

bool FOptHelper::MaybeIsMat(UMaterialInterface* Mat, const FString& MatName)
{
	if(!Mat || MatName.Len() == 0)
	{
		return false;
	}
	
	if(Mat->GetName().Contains(*MatName))
	{
		return true;
	}

	if(Mat->IsA<UMaterialInstance>())
	{
		return MaybeIsMat(Cast<UMaterialInstance>(Mat)->Parent, MatName);
	}
	
	return false;
}

FString FOptHelper::MakeMeshKey(UStaticMeshComponent* Comp)
{
	if(Comp == nullptr || Comp->GetStaticMesh() == nullptr)
	{
		return "";
	}

	TArray<FString> PathList;
	PathList.Add(Comp->GetStaticMesh()->GetPackage()->GetFName().ToString());
	for(int i=0; i<Comp->GetNumMaterials(); i++)
	{
		UMaterialInterface* Mat = Comp->GetMaterial(i);
		if(Mat)
		{
			PathList.Add(Mat->GetPackage()->GetFName().ToString());
		}
	}
	PathList.Sort();
	return FString::Join(PathList, TEXT(";"));
}


/// 打印当前的scability的情况
FAutoConsoleCommand OptDumpScalability(TEXT("opt.scalability"), TEXT("opt.scalability"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		// 设备分辨率，当前分辨率，场景分辨率
		// 设备分辨率，引擎没有提供API。从日志中，能查到，搜索 screenWidth screenHeight
		{
			FString FinalDisplayString;
			if (GEngine && GEngine->GameViewport )
			{
				FVector2D ViewSize;
				GEngine->GameViewport->GetViewportSize(ViewSize);
				FinalDisplayString += FString::Printf(TEXT("\n Viewport=%dx%d"), (int)ViewSize.X, (int)ViewSize.Y);
			}
			
			UGameUserSettings* UserSettings = GEngine->GetGameUserSettings();
			if (UserSettings )
			{
				auto ViewSize = UserSettings->GetScreenResolution();
				FinalDisplayString += FString::Printf(TEXT("\n ScreenResolution=%dx%d. SystemResolution=%dx%d"),
					ViewSize.X, ViewSize.Y,
					GSystemResolution.ResX, GSystemResolution.ResY);
			}

			{				
				const auto MobileContentScaleFactor = IConsoleManager::Get().FindConsoleVariable(TEXT("r.MobileContentScaleFactor"))->GetFloat();
				const auto ScreenPercentage = IConsoleManager::Get().FindConsoleVariable(TEXT("r.ScreenPercentage"))->GetFloat();
				const auto SecondaryScreenPercentage = IConsoleManager::Get().FindConsoleVariable(TEXT("r.SecondaryScreenPercentage.GameViewport"))->GetFloat();
				
				const auto DesiredResX = IConsoleManager::Get().FindConsoleVariable(TEXT("r.Mobile.DesiredResX"))->GetInt();
				const auto DesiredResY = IConsoleManager::Get().FindConsoleVariable(TEXT("r.Mobile.DesiredResY"))->GetInt();
				
				FinalDisplayString += FString::Printf(TEXT("\n MobileContentScaleFactor=%.2f, DesiredResX=%d, DesiredResY=%d"
											   "\n ScreenPercentage=%.2f, r.SecondaryScreenPercentage=%.2f"),
					MobileContentScaleFactor, DesiredResX, DesiredResY,
					ScreenPercentage, SecondaryScreenPercentage);
			}
			
			GEngine->AddOnScreenDebugMessage(-1, 5, FColor::Red, FinalDisplayString);
			UE_LOG(LogOptCmd, Log, TEXT("%s"), *FinalDisplayString);
		}

		// 其他配置
		{
			auto Quality = Scalability::GetQualityLevels();		
			
			FString FinalDisplayString = FString::Printf(TEXT("ResolutionQuality=%.2f, ViewDistanceQuality=%d, AntiAliasingQuality=%d"
				"\nShadowQuality=%d, GlobalIlluminationQuality=%d, ReflectionQuality=%d"
				"\nPostProcessQuality=%d, TextureQuality=%d, EffectsQuality=%d"
				"\nFoliageQuality=%d, ShadingQuality=%d"),
				Quality.ResolutionQuality,
				Quality.ViewDistanceQuality,
				Quality.AntiAliasingQuality,
				Quality.ShadowQuality,
				Quality.GlobalIlluminationQuality,
				Quality.ReflectionQuality,
				Quality.PostProcessQuality,
				Quality.TextureQuality,
				Quality.EffectsQuality,
				Quality.FoliageQuality,
				Quality.ShadingQuality);		
			GEngine->AddOnScreenDebugMessage(-1, 5, FColor::Red, FinalDisplayString);
			UE_LOG(LogOptCmd, Log, TEXT("%s"), *FinalDisplayString);
		}
	}));

/// 打印当前的scability的情况
FAutoConsoleCommand OptDumpLevelInfo(TEXT("opt.dumplevel"), TEXT("opt.dumplevel"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		UWorld* World = FOptHelper::GetGameWorld();
		if(World)
		{
			TArray<ULevelStreaming*> Levels = World->GetStreamingLevels();
			int LoadedLevelCount = 0;
			
			for (auto Level : Levels)
			{
				if(Level)
				{
					if(Level->IsLevelLoaded())
					{
						LoadedLevelCount++;
					}
				}
				UE_LOG(LogOptCmd, Log, TEXT("LevelName=%s"), *Level->PackageNameToLoad.ToString());
			}
			
			UE_LOG(LogOptCmd, Log, TEXT("LevelCount=%d, Loaded=%d"), Levels.Num(), LoadedLevelCount);
		}
	}));


/// 打印当前的scability的情况
FAutoConsoleCommand OptDumpBigMem(TEXT("bigmem"), TEXT("bigmem"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		// 单位是M
		int Cnt = 32;
		if(Args.Num() > 0)
		{
			Cnt = FCString::Atoi(*Args[0]);
		}

		const auto Ptr = GMalloc->Malloc(Cnt * 1024 * 1024);
		GMalloc->Free(Ptr);
	}));

/// 打印当前的scability的情况
FAutoConsoleCommand OptDumpHealth(TEXT("opt.dumphealth"), TEXT("opt.dumphealth"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		FString SnapshotTitle("C7");
		bool bResetStats = true;

		if(Args.Num() > 0)
		{
			SnapshotTitle = Args[0];
		}
		if(Args.Num() > 1)
		{
			bResetStats = FCString::Atoi(*Args[0]) > 0;
		}
		
		UHealthSnapshotBlueprintLibrary::LogPerformanceSnapshot(SnapshotTitle, bResetStats);
	}));

/// 测试SaveGame
FAutoConsoleCommand OptTestSaveGame(TEXT("opt.savegame"), TEXT("opt.savegame"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		FString TestSaveGameSlot("liubo");
		if(Args.Num() > 0)
		{
			TestSaveGameSlot = Args[0];
		}
		
		UClass* GeneratedClass = Cast<UClass>(StaticLoadObject(
			UClass::StaticClass(), nullptr,
			TEXT(
				"/Game/Blueprint/Chat/BP_ChatHistory.BP_ChatHistory_C"),
			nullptr, LOAD_None, nullptr));
		if(GeneratedClass)
		{			
			auto SaveGameInstance = UGameplayStatics::CreateSaveGameObject(
				GeneratedClass);
#if WITH_EDITORONLY_DATA
								  SaveGameInstance->PostEditChange();
#endif
			
			UGameplayStatics::SaveGameToSlot(SaveGameInstance, TestSaveGameSlot, 0);
		}		
	}));
FAutoConsoleCommand OptTestLoadSaveGame(TEXT("opt.loadgame"), TEXT("opt.savegame"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		FString TestSaveGameSlot("liubo");
		if(Args.Num() > 0)
		{
			TestSaveGameSlot = Args[0];
		}
		
		USaveGame* SaveGameInstance = nullptr;
		if (UGameplayStatics::DoesSaveGameExist(TestSaveGameSlot, 0))
		{
			SaveGameInstance =
				UGameplayStatics::LoadGameFromSlot(TestSaveGameSlot, 0);
		}
		if(SaveGameInstance)
		{
			TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
			FJsonObjectConverter::UStructToJsonObject(
				SaveGameInstance->GetClass(), SaveGameInstance,
				JsonObject.ToSharedRef(), 0, 0);
			FString JsonString;
			TSharedRef<TJsonWriter<>> JsonWriter = TJsonWriterFactory<>::Create(
				&JsonString);
			FJsonSerializer::Serialize(JsonObject.ToSharedRef(), JsonWriter);
			
			UE_LOG(LogTemp, Log, TEXT("Load Obj Succ. Content=%s"), *JsonString);
		}
	}));

FAutoConsoleCommand OptC7LoadObj(TEXT("c7.loadobj"), TEXT("c7.loadobj"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		FString ObjFileName("");
		if(Args.Num() > 0)
		{
			ObjFileName = Args[0];
		}

		// UWorld* World = LoadObject<UWorld>(nullptr, TEXT("/Game/Arts/Maps/Ruierbibo_Blockout/Ruierbibo_Navmesh.Ruierbibo_Navmesh"));
		auto Obj = LoadObject<UObject>(nullptr, *ObjFileName);
		UE_LOG(LogTemp, Log, TEXT("LoadObj, Path=%s, Obj=%s"), *ObjFileName, *Obj->GetFullName());
	}));

FAutoConsoleCommand OptC7LoadPackage(TEXT("c7.loadPackage"), TEXT("c7.loadPackage"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		FString PackagePath("");
		if(Args.Num() > 0)
		{
			PackagePath = Args[0];
		}

		auto GetExternalPackageName = [](const FString& InObjectPath)
		{
			FString ObjectPath = InObjectPath.ToLower();

			FArchiveMD5 ArMD5;
			ArMD5 << ObjectPath;

			FGuid PackageGuid = ArMD5.GetGuidFromHash();
			check(PackageGuid.IsValid());

			FString GuidBase36 = PackageGuid.ToString(EGuidFormats::Base36Encoded);
			check(GuidBase36.Len());
			return GuidBase36;
		};

		if(UPackage* OutPackage = LoadPackage(nullptr, *PackagePath, LOAD_None))
		{
			bool HasMap = OutPackage->ContainsMap();
			ForEachObjectWithPackage(OutPackage, [GetExternalPackageName, HasMap](UObject* InnerObject)
			{
				if (HasMap)
				{
					FString GuidBase36 = GetExternalPackageName(InnerObject->GetPathName());
					UE_LOG(LogTemp, Log, TEXT("LoadPackage, Guid=%s, Obj=%s"), *GuidBase36, *InnerObject->GetFullName());
				}
				else
				{
					UE_LOG(LogTemp, Log, TEXT("LoadPackage, Obj=%s"), *InnerObject->GetFullName());
				}
				return true;
			}, true);
		}
	}));


FAutoConsoleCommand OptC7TestThread(TEXT("c7.thread.test"), TEXT("c7.thread.test"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		FString ObjFileName("liubo");
		if(Args.Num() > 0)
		{
			ObjFileName = Args[0];
		}
		AsyncTask(ENamedThreads::AnyBackgroundThreadNormalTask, [ObjFileName]
		{
			for(int i=0; i<1000; i++)
			{
				UE_LOG(LogTemp, Log, TEXT("C7 Thread Test. Tag=%s, i=%d"), *ObjFileName, i);
				FPlatformProcess::Sleep(1);
			}
		});
	}));
namespace c7opt
{
	class FPrimInfo
	{
	public:
		TSet<TWeakObjectPtr<AActor>> ActorSet;
		TSet<TWeakObjectPtr<UPrimitiveComponent>> PrimCompSet;
		int MatCount = 0;
	};	
}

FAutoConsoleCommand OptC7SceneDumpMesh(TEXT("c7.opt.dumpmesh"), TEXT("c7.opt.dumpmesh"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		TMap<AActor*, TArray<UPrimitiveComponent*>> VisiblePrimitives;
		int MatCount = 0;
		int MeshCount = 0;
		TSet<UStaticMesh*> UsedMeshSet;
		TSet<USkinnedAsset*> UsedSkinnedMeshSet;
		TMap<UClass*, c7opt::FPrimInfo> PrimMap;
		
		auto World = FOptHelper::GetGameWorld();
		for(FActorIterator It(World); It; ++It)
		{
			AActor* Actor = *It;
			if(Actor && !Actor->IsHidden())
			{
				TArray<UPrimitiveComponent*> Components;
				Actor->GetComponents<UPrimitiveComponent>(Components);
				for (auto Component : Components)
				{
					bool bValid = false;
					if(Component->IsVisible())
					{
						auto& One = PrimMap.FindOrAdd(Component->GetClass());
						One.ActorSet.Add(Actor);
						One.PrimCompSet.Add(Component);
						One.MatCount += Component->GetNumMaterials();
						
						bValid = true;
						// 如果是StaticMesh，检查有效性
						if(Component->IsA<UStaticMeshComponent>())
						{
							if(!Cast<UStaticMeshComponent>(Component)->GetStaticMesh())
							{
								bValid = false;
							}
							else
							{
								MeshCount++;
								UsedMeshSet.Add(Cast<UStaticMeshComponent>(Component)->GetStaticMesh());
							}							
						}						
						else if(Component->IsA<USkeletalMeshComponent>())
						{
							if(!Cast<USkeletalMeshComponent>(Component)->GetSkeletalMeshAsset())
							{
								bValid = false;
							}
							else
							{
								MeshCount++;
								UsedSkinnedMeshSet.Add(Cast<USkeletalMeshComponent>(Component)->GetSkeletalMeshAsset());
							}
						}
						if(bValid)
						{
							if(Component->GetNumMaterials() == 0)
							{
								bValid = false;
							}
							MatCount += Component->GetNumMaterials();
						}
					}
					if(bValid)
					{
						VisiblePrimitives.FindOrAdd(Actor).Add(Component);
					}
				}
			}
		}

		for (auto VisiblePrimitive : VisiblePrimitives)
		{
			TStringBuilder<2048> Sb;
			Sb.Append(VisiblePrimitive.Key->GetFullName());
			Sb.Append(FString::Printf(TEXT(", Comps.Num=%d"), VisiblePrimitive.Value.Num()));
			int ShadowCount = 0;
			for (auto Jt : VisiblePrimitive.Value)
			{
				if(Jt->CastShadow)
				{
					ShadowCount++;
				}
				Sb.Append(", Comp:");
				Sb.Append(Jt->GetClass()->GetName());
				Sb.Append(".");
				Sb.Append(Jt->GetName());
				Sb.Append(FString::Printf(TEXT(", Prims.Num=%d"), Jt->GetNumMaterials()));				
			}
			UE_LOG(LogTemp, Log, TEXT("liubo, Dump Scene, ShadowCount:%d, WorldActor:%s"), ShadowCount, Sb.ToString());
		}
		
		// 分类展示
		for(const auto& It : PrimMap)
		{
			UE_LOG(LogTemp, Log, TEXT("liubo, Dump Scene, Cls:%s, ActorCount=%d, CompCount=%d, MatCount=%d"),
				*It.Key->GetPathName(),
				It.Value.ActorSet.Num(),
				It.Value.PrimCompSet.Num(),
				It.Value.MatCount);
			
			for(const auto& Jt : It.Value.PrimCompSet)
			{
				UE_LOG(LogTemp, Log, TEXT("liubo, Dump Scene, PrimComp:%s, MatCount=%d"), *Jt->GetFullName(), Jt->GetNumMaterials());
			}
		}
		
		// dump非法的数据
		auto IsStatic = [](USceneComponent* Comp)
		{
			if(!Comp || !Comp->GetOwner())
			{
				return true;
			}
			
			if(Comp->Mobility != EComponentMobility::Static)
			{
				return false;
			}

			if(!Comp->GetOwner()->GetRootComponent())
			{
				return true;
			}
			
			if(Comp->GetOwner()->GetRootComponent()->Mobility != EComponentMobility::Static)
			{
				return false;
			}
			auto Parent = Comp->GetOwner()->GetRootComponent()->GetAttachParent();
			int Count = 10;
			while(Parent != nullptr && Count > 0)
			{
				if(Parent->Mobility != EComponentMobility::Static)
				{
					return false;
				}
				Parent = Parent->GetAttachParent();
				Count--;
			}			
			return Count > 0;
		};
		for(const auto& It : PrimMap)
		{			
			for(const auto& Jt : It.Value.PrimCompSet)
			{
				if(!IsStatic(Jt.Get()))
				{
					UE_LOG(LogTemp, Log, TEXT("liubo, Dump Scene, PrimIsNotStatic! Prim=%s"), *Jt->GetFullName());					
				}
			}
		}

		// dump能合并的staticmesh
		
		for(const auto& It : PrimMap)
		{
			if(It.Key == UStaticMeshComponent::StaticClass())
			{
				// 是否可以合并
				TMap<UStaticMesh*, TSet<TWeakObjectPtr<UStaticMeshComponent>>> Batched;
				for(auto Comp : It.Value.PrimCompSet)
				{
					auto SmComp = Cast<UStaticMeshComponent>(Comp.Get());
					auto& Set = Batched.FindOrAdd(SmComp->GetStaticMesh());
					Set.Add(SmComp);
				}
				// todo..
				for(const auto& Kv : Batched)
				{
					if(Kv.Value.Num() > 1)
					{
						for(const auto& VV : Kv.Value)
						{
							UE_LOG(LogTemp, Log, TEXT("liubo, Dump Scene, NeedBatch, Mesh=%s, CompCount=%d, Comp=%s"),
								*Kv.Key->GetPathName(),
								Kv.Value.Num(),
								*VV->GetFullName());
							break;							
						}						
					}
				}				
				break;
			}
		}
		

		// 使用的模型
		for(auto It : UsedMeshSet)
		{
			UE_LOG(LogTemp, Log, TEXT("liubo, Dump Scene, MeshAsset:%s"), *It->GetPathName());			
		}
		for(auto It : UsedSkinnedMeshSet)
		{
			UE_LOG(LogTemp, Log, TEXT("liubo, Dump Scene, SkinnedMeshAsset:%s"), *It->GetPathName());			
		}

		// 使用的贴图, todo.
#if WITH_EDITOR		
		for (auto VisiblePrimitive : VisiblePrimitives)
		{
			UE_LOG(LogTemp, Log, TEXT("liubo, Dump Scene, Hierachy:%s/%s, %s"), *VisiblePrimitive.Key->GetFolderPath().ToString(), *VisiblePrimitive.Key->GetActorLabel(), *VisiblePrimitive.Key->GetName());
		}


		// dump远视角的内容
		{
			
			FVector Location = FVector::Zero();
			FRotator Rotation = FRotator::ZeroRotator;
			APlayerController* PlayerController = UGameplayStatics::GetPlayerController(World, 0);
			if (PlayerController)
			{
				PlayerController->GetPlayerViewPoint(Location, Rotation);
			}
			
			Location.Z = 0;
			FVector Radius(12800, 12800, 0);
			FBox MyViewBox(Location - Radius, Location + Radius);
			
			TArray<AActor*> DumpActorBound;
			for (auto VisiblePrimitive : VisiblePrimitives)
			{
				FVector OriginA;
				FVector BoundA;
				VisiblePrimitive.Key->GetActorBounds(false, OriginA, BoundA, true);
				OriginA.Z = 0;
				BoundA.Z = 0;
				FBox BoxA(OriginA - BoundA, OriginA + BoundA);
				
				if(BoxA.Intersect(MyViewBox)
					|| MyViewBox.IsInside(BoxA)
					|| BoxA.IsInside(MyViewBox))
				{
					continue;
				}
				
				DumpActorBound.Add(VisiblePrimitive.Key);
			}
			DumpActorBound.Sort([](const AActor& A, const AActor& B)
			{
				FVector OriginA;
				FVector BoundA;
				A.GetActorBounds(false, OriginA, BoundA, true);
				
				FVector OriginB;
				FVector BoundB;
				B.GetActorBounds(false, OriginB, BoundB, true);				
								
				return BoundA.Size() < BoundB.Size();
			});
			
			for (auto VisiblePrimitive : DumpActorBound)
			{
				FVector OriginA;
				FVector BoundA;
				VisiblePrimitive->GetActorBounds(false, OriginA, BoundA, true);
				UE_LOG(LogTemp, Log, TEXT("liubo, Dump Bound, Hierachy:%s/%s, %s, bound=%f"),
					*VisiblePrimitive->GetFolderPath().ToString(),
					*VisiblePrimitive->GetActorLabel(),
					*VisiblePrimitive->GetName(),
					BoundA.Size());
			}			
		}
#endif
		
		UE_LOG(LogTemp, Log, TEXT("liubo, Dump Scene, MeshCount=%d, MatCount=%d, MeshAssetCount=%d, SkinnedMeshAssetCount=%d"),
				MeshCount, MatCount,
				UsedMeshSet.Num(),
				UsedSkinnedMeshSet.Num());
	}));


// 设置static
FAutoConsoleCommand OptC7SceneSetStatic(TEXT("c7.opt.setstatic"), TEXT("c7.opt.setstatic"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR
		
		UWorld* World = GEditor->GetEditorWorldContext().World();
		if(World == nullptr || World->WorldType == EWorldType::PIE)
		{
			return;
		}
		TArray<FString> MatchKeys;
		if(Args.Num() == 1)
		{
			Args[0].ParseIntoArray(MatchKeys, TEXT(";"));
		}
		if(MatchKeys.Num() == 0)
		{
			MatchKeys.Add("HISMA");
			// InstancedFoliageActor
			MatchKeys.Add("InstancedFoliageActor");
			MatchKeys.Add("PCG");
			MatchKeys.Add("SM_Building");
		}
		MatchKeys.RemoveAll([](const FString& Msg) {return Msg.TrimEnd().TrimStart().Len() == 0;});
		
		auto IsMatch = [MatchKeys](const FString& LabelName)
		{
			for (auto MatchKey : MatchKeys)
			{
				if(MatchKey == "*" || LabelName.Contains(MatchKey))
				{
					return true;
				}
			}
			return false;
		};

		// 只处理静态模型的
		TFunction<void(AActor* Actor, USceneComponent* Comp)> SetCompStatic = nullptr;
		TFunction<void(AActor* Actor, USceneComponent* Comp)> SetParentCompStatic = nullptr;
		SetCompStatic = [&SetParentCompStatic](AActor* Actor, USceneComponent* Comp)
		{
			// 只处理staticmesh和scenecomp
			if(Comp->GetClass() == USceneComponent::StaticClass()
				|| Comp->IsA<UStaticMeshComponent>())
			{
				
			}
			else
			{
				return;
			}
			
			if(Comp == Actor->GetRootComponent())
			{
				if(Comp->Mobility != EComponentMobility::Static)
				{
					Comp->Mobility = EComponentMobility::Static;
				}
				return;	
			}
			
			if(Comp->GetAttachParent() && Comp->GetAttachParent()->Mobility != EComponentMobility::Static)
			{
				if(SetParentCompStatic)
				{
					SetParentCompStatic(Actor, Comp->GetAttachParent());					
				}
			}
			
			if(Comp->GetAttachParent() && Comp->GetAttachParent()->Mobility == EComponentMobility::Static)
			{
				Comp->Mobility = EComponentMobility::Static;
			}
		};
		SetParentCompStatic = SetCompStatic;
		
		// 只处理editor场景
		for(FActorIterator It(World); It; ++It)
		{
			AActor* Actor = *It;
			if(Actor->IsEditorOnly())
			{
				continue;
			}

			if(!IsMatch(Actor->GetActorLabel()))
			{
				continue;
			}

			TArray<UStaticMeshComponent*> PrimitiveComponents;
			Actor->GetComponents<UStaticMeshComponent>(PrimitiveComponents);
			int DirtyCount = 0;
			for (auto PrimComp : PrimitiveComponents)
			{
				if(!PrimComp)
				{
					continue;
				}
				if(PrimComp->IsEditorOnly())
				{
					continue;
				}

				// 应该计算父节点是否是static，先这样吧
				if(PrimComp->Mobility != EComponentMobility::Static)
				{
					SetCompStatic(Actor, PrimComp);
					if(PrimComp->Mobility == EComponentMobility::Static)
					{
						DirtyCount++;	
					}
					
				}
			}
			
			if(DirtyCount)
			{
				Actor->MarkPackageDirty();
				UE_LOG(LogTemp, Log, TEXT("liubo, Set Mobility:%s"), *Actor->GetActorLabel());
			}
		}
#endif
	}));


// editoronly的component
FAutoConsoleCommand OptC7OptEditorOnly(TEXT("c7.opt.editoronly"), TEXT("c7.opt.editoronly"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR
		
		UWorld* World = GEditor->GetEditorWorldContext().World();
		if(World == nullptr || World->WorldType == EWorldType::PIE)
		{
			return;
		}

		// 只处理editor场景
		for(FActorIterator It(World); It; ++It)
		{
			AActor* Actor = *It;
			if(Actor->IsEditorOnly())
			{
				continue;
			}

			TArray<UPrimitiveComponent*> PrimitiveComponents;
			Actor->GetComponents<UPrimitiveComponent>(PrimitiveComponents);
			int DirtyCount = 0;
			// 至少有一个是MeshComponent
			int MeshCompCount = 0;
			for (auto PrimComp : PrimitiveComponents)
			{
				if(!PrimComp)
				{
					continue;
				}
				if(PrimComp->IsEditorOnly())
				{
					DirtyCount++;
				}
				if(PrimComp->IsA<UMeshComponent>())
				{
					MeshCompCount++;
				}
			}

			// 如果都是EditorOnly的，那么久把父节点也设置上！！
			if(MeshCompCount > 0
				&& DirtyCount > 0
				&& DirtyCount == PrimitiveComponents.Num())
			{
				Actor->bIsEditorOnlyActor = true;
				Actor->MarkPackageDirty();
				UE_LOG(LogTemp, Log, TEXT("liubo, Set Mobility:%s"), *Actor->GetActorLabel());
			}
		}
#endif
	}));

static void DeleteArtMeshActor(bool bRollback)
{
#if WITH_EDITOR
	static FName TempDeleteArt("LIUBO_TempDeleteArt");
	UWorld* World = GEditor->GetEditorWorldContext().World();
	if(World == nullptr || World->WorldType == EWorldType::PIE)
	{
		return;
	}

	TArray<FString> FilterFolders;
	FilterFolders.Add("*");
	
	auto IsInFilterFolder = [FilterFolders](const FString& ActorFolderPath)
	{
		// 没有名字的，跳过
		if(ActorFolderPath.Len() == 0 || ActorFolderPath == "None")
		{
			return false;
		}
		
		bool bInFilterFolder = false;
		for (int32 i = 0; i < FilterFolders.Num(); ++i)
		{
			if(FilterFolders[i] == "*")
			{
				bInFilterFolder = true;
				break;							
			}
							
			if (ActorFolderPath.Contains(FilterFolders[i]))
			{
				bInFilterFolder = true;
				break;
			}
		}
		return bInFilterFolder;			
	};
		
	// 只处理editor场景
	for(FActorIterator It(World); It; ++It)
	{
		AActor* Actor = *It;

		if(!bRollback)
		{
			// 不处理美术同学自己标记的editor的内容
			if(Actor->IsEditorOnly())
			{
				continue;
			}			
		}
		
		FString ActorFolderPath = Actor->GetFolderPath().ToString();
		if(!IsInFilterFolder(ActorFolderPath))
		{
			continue;
		}

		bool bHlodActor = Actor->IsA<AWorldPartitionHLOD>();

		if (!bHlodActor)
		{
			// 地形的
			FString ActorName = Actor->GetActorLabel();
			if (ActorName.Contains("landscape"))
			{
				continue;
			}

			// bound2d超过6400
			float CellSize = 6400;
			FVector OriginA;
			FVector BoundA;
			Actor->GetActorBounds(false, OriginA, BoundA, true);
			if (BoundA.Size2D() > CellSize)
			{
				continue;
			}
		}



		TArray<UPrimitiveComponent*> PrimitiveComponents;
		Actor->GetComponents<UPrimitiveComponent>(PrimitiveComponents);

		// 只处理全是static的
		bool bAllStatic = true;
		for (auto PrimComp : PrimitiveComponents)
		{
			if(PrimComp->Mobility != EComponentMobility::Static)
			{
				bAllStatic = false;
				break;
			}			
		}
		if(!bAllStatic)
		{
			continue;
		}
		
		// 包含spline的
		bool bBlack = false;
		for (auto PrimComp : PrimitiveComponents)
		{
			if(PrimComp->IsA(USplineComponent::StaticClass()))
			{
				bBlack = true;
				break;
			}
			if(PrimComp->IsA(ULandscapeComponent::StaticClass()))
			{
				bBlack = true;
				break;
			}
		}
		if(bBlack)
		{
			continue;
		}

		TArray<UStaticMeshComponent*> MeshComponents;
		Actor->GetComponents<UStaticMeshComponent>(MeshComponents);
		int DirtyCount = 0;
		
		for (auto PrimComp : MeshComponents)
		{
			if(!PrimComp)
			{
				continue;
			}

			if(bRollback)
			{	
				if(PrimComp->ComponentEditorTags.Contains(TempDeleteArt))
				{
					PrimComp->bIsEditorOnly = false;
					PrimComp->ComponentEditorTags.Remove(TempDeleteArt);
					DirtyCount++;
				}		
			}
			else
			{
				if(PrimComp->IsEditorOnly())
				{
					continue;
				}

				// 特殊tag
				PrimComp->ComponentEditorTags.Add(TempDeleteArt);
				PrimComp->bIsEditorOnly = true;
				DirtyCount++;					
			}
		}
			
		if(DirtyCount > 0)
		{
			if(bRollback)
			{
				if(Actor->EditorTags.Contains(TempDeleteArt))
				{
					Actor->EditorTags.Remove(TempDeleteArt);
					Actor->bIsEditorOnlyActor = false;	
				}
			}
			else
			{
				Actor->EditorTags.Add(TempDeleteArt);
				Actor->bIsEditorOnlyActor = true;
			}
			Actor->MarkPackageDirty();
			
			UE_LOG(LogTemp, Log, TEXT("liubo, del art=%s/%s, %s"),
				*Actor->GetFolderPath().ToString(),
				*Actor->GetActorLabel(),
				*Actor->GetName());				
		}
	}
#endif	
	
}

// 删掉所有美术的内容
FAutoConsoleCommand OptC7OptDeleteArtMesh(TEXT("c7.opt.delartmesh"), TEXT("c7.opt.delartmesh"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		// SM，且是static的
		DeleteArtMeshActor(false);
	}));
FAutoConsoleCommand OptC7OptDeleteArtMeshRollback(TEXT("c7.opt.delartmesh.rollback"), TEXT("c7.opt.delartmesh.rollback"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		// SM，且是static的	
		DeleteArtMeshActor(true);	
	}));

static void DeleteShadow(bool bRollback)
{
#if WITH_EDITOR
	static FName TempDeleteArt("LIUBO_TempDeleteShadow");
	UWorld* World = GEditor->GetEditorWorldContext().World();
	if(World == nullptr || World->WorldType == EWorldType::PIE)
	{
		return;
	}

	TArray<FString> FilterFolders;
	FilterFolders.Add("*");
	
	auto IsInFilterFolder = [FilterFolders](const FString& ActorFolderPath)
	{
		// 没有文件夹的，跳过
		if(ActorFolderPath.Len() == 0 || ActorFolderPath == "None")
		{
			return false;
		}
		
		bool bInFilterFolder = false;
		for (int32 i = 0; i < FilterFolders.Num(); ++i)
		{
			if(FilterFolders[i] == "*")
			{
				bInFilterFolder = true;
				break;							
			}
							
			if (ActorFolderPath.Contains(FilterFolders[i]))
			{
				bInFilterFolder = true;
				break;
			}
		}
		return bInFilterFolder;			
	};
		
	// 只处理editor场景
	for(FActorIterator It(World); It; ++It)
	{
		AActor* Actor = *It;

		// 不处理editoronly的
		if(Actor->IsEditorOnly())
		{
			continue;
		}	
		
		FString ActorFolderPath = Actor->GetFolderPath().ToString();
		if(!IsInFilterFolder(ActorFolderPath))
		{
			continue;
		}

		// 地形的
		FString ActorName = Actor->GetActorLabel();
		if(ActorName.Contains("landscape"))
		{
			continue;
		}

		// bound2d超过6400
		float CellSize = 6400;
		FVector OriginA;
		FVector BoundA;
		Actor->GetActorBounds(false, OriginA, BoundA, true);
		if(BoundA.Size2D() > CellSize)
		{
			continue;
		}

		TArray<UPrimitiveComponent*> PrimitiveComponents;
		Actor->GetComponents<UPrimitiveComponent>(PrimitiveComponents);

		// 只处理全是static的
		bool bAllStatic = true;
		for (auto PrimComp : PrimitiveComponents)
		{
			if(PrimComp->Mobility != EComponentMobility::Static)
			{
				bAllStatic = false;
				break;
			}			
		}
		if(!bAllStatic)
		{
			continue;
		}
		
		// 包含spline的
		bool bBlack = false;
		for (auto PrimComp : PrimitiveComponents)
		{
			if(PrimComp->IsA(USplineComponent::StaticClass()))
			{
				bBlack = true;
				break;
			}
			if(PrimComp->IsA(ULandscapeComponent::StaticClass()))
			{
				bBlack = true;
				break;
			}

			// 跳过阴影体
			if(PrimComp->GetName().Contains("ShadowProxy"))
			{
				bBlack = true;
				break;				
			}
		}
		if(bBlack)
		{	
			continue;
		}

		TArray<UStaticMeshComponent*> MeshComponents;
		Actor->GetComponents<UStaticMeshComponent>(MeshComponents);
		int DirtyCount = 0;
		
		for (auto PrimComp : MeshComponents)
		{
			if(!PrimComp)
			{
				continue;
			}

			if(bRollback)
			{	
				if(PrimComp->ComponentEditorTags.Contains(TempDeleteArt))
				{
					PrimComp->CastShadow = true;
					DirtyCount++;
				}		
			}
			else
			{
				if(PrimComp->IsEditorOnly())
				{
					continue;
				}
				if(!PrimComp->CastShadow)
				{
					continue;
				}
				if(PrimComp->Mobility != EComponentMobility::Static)
				{
					continue;
				}
				
				// 特殊tag
				PrimComp->ComponentEditorTags.Add(TempDeleteArt);
				PrimComp->CastShadow = false;
				DirtyCount++;					
			}
		}
			
		if(DirtyCount > 0)
		{
			if(bRollback)
			{
				if(Actor->EditorTags.Contains(TempDeleteArt))
				{
					Actor->EditorTags.Remove(TempDeleteArt);
				}
			}
			else
			{
				Actor->EditorTags.Add(TempDeleteArt);
			}
			Actor->MarkPackageDirty();
			
			UE_LOG(LogTemp, Log, TEXT("liubo, del shadow=%s/%s, %s"),
				*Actor->GetFolderPath().ToString(),
				*Actor->GetActorLabel(),
				*Actor->GetName());				
		}
	}
#endif	
	
}
// 删掉所有的阴影
FAutoConsoleCommand OptC7OptDeleteShadow(TEXT("c7.opt.delshadow"), TEXT("c7.opt.delshadow"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		// SM，且是static的
		DeleteShadow(false);
	}));
FAutoConsoleCommand OptC7OptDeleteShadowRollback(TEXT("c7.opt.delshadow.rollback"), TEXT("c7.opt.delshadow.rollback"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		// SM，且是static的	
		DeleteShadow(true);	
	}));

// 运行时，关掉static的阴影
static void C7DumpShadowInfo()
{
	auto World = FOptHelper::GetGameWorld();
	int ShadowProxyTotalCount = 0;
	for(FActorIterator It(World); It; ++It)
	{
		AActor* Actor = *It;
		if(Actor && !Actor->IsHidden())
		{
			TArray<UStaticMeshComponent*> StaticMeshComponents;
			Actor->GetComponents<UStaticMeshComponent>(StaticMeshComponents);
			StaticMeshComponents.RemoveAll([](UStaticMeshComponent* MeshComp)
			{
				if(!MeshComp->IsVisible())
				{
					if(MeshComp->bCastHiddenShadow)
					{
						return false;
					}
					else
					{
						return true;
					}
				}
				
				// 不产生阴影的，非静态的
				return (!MeshComp->CastShadow
					|| MeshComp->Mobility != EComponentMobility::Static);
			});

			if(StaticMeshComponents.Num() > 0)
			{
				TSet<FString> TypeSet;
				int ShadowProxyCnt = 0;
				for(auto Sm : StaticMeshComponents)
				{
					TypeSet.Add(Sm->GetClass()->GetFullName());
					if(Sm->GetStaticMesh() && Sm->GetStaticMesh()->GetFullName().Contains("ShadowProxy"))
					{
						ShadowProxyCnt++;
						ShadowProxyTotalCount++;
					}
				}
				FString TypeMsg = FString::Join(TypeSet, TEXT(";"));
				
				UE_LOG(LogTemp, Log, TEXT("liubo, shadow actor:%s, cnt=%d, shadowproxy=%d, type=%s"), *Actor->GetFullName(),
					StaticMeshComponents.Num(),
					ShadowProxyCnt, *TypeMsg);
			}
		}		
	}
	UE_LOG(LogTemp, Log, TEXT("liubo, shadow proxy cnt=%d"), ShadowProxyTotalCount);
}

// 关掉静态的，且是非shadowproxy的
static void C7EnableShadow(bool b, UClass* FilterCls = nullptr)
{
	static FString ShadowProxyKeyword("ShadowProxy");
	static FName TagRuntimeCtrlShadow("RuntimeCtrlShadow");
	
	auto World = FOptHelper::GetGameWorld();
	for(FActorIterator It(World); It; ++It)
	{
		AActor* Actor = *It;
		if(Actor && !Actor->IsHidden())
		{
			TArray<UStaticMeshComponent*> StaticMeshComponents;
			Actor->GetComponents<UStaticMeshComponent>(StaticMeshComponents);
			StaticMeshComponents.RemoveAll([](UStaticMeshComponent* MeshComp)
			{
				if(!MeshComp->IsVisible())
				{
					if(MeshComp->bCastHiddenShadow)
					{
						return false;
					}
					else
					{
						return true;
					}
				}
				
				// 不产生阴影的，非静态的
				return (!MeshComp->IsVisible()
					|| MeshComp->Mobility != EComponentMobility::Static);
			});
			
			if(FilterCls)
			{
				// 只保留FilterCls
				StaticMeshComponents.RemoveAll([FilterCls](UStaticMeshComponent* MeshComp)
				{
					return !MeshComp->IsA(FilterCls);
				});
			}

			int DirtyCount = 0;
			if(StaticMeshComponents.Num() > 0)
			{
				if(!b)
				{
					// 关掉阴影
					for(auto MeshComp : StaticMeshComponents)
					{
						if(!MeshComp->CastShadow)
						{
							continue;
						}
						
						if(MeshComp->GetName().Contains(ShadowProxyKeyword))
						{
									
						}
						else if(MeshComp->GetStaticMesh() && MeshComp->GetStaticMesh()->GetFullName().Contains(ShadowProxyKeyword))
						{
							
						}
						else
						{
							MeshComp->SetCastShadow(false);
							MeshComp->ComponentTags.Add(TagRuntimeCtrlShadow);
							DirtyCount++;
						}
					}
				}
				else
				{
					// 还原
					for(auto MeshComp : StaticMeshComponents)
					{
						if(MeshComp->ComponentTags.Contains(TagRuntimeCtrlShadow))
						{
							MeshComp->ComponentTags.Remove(TagRuntimeCtrlShadow);
							MeshComp->SetCastShadow(true);
							DirtyCount++;
						}
					}					
				}
			}

			if(DirtyCount > 0)
			{
				UE_LOG(LogTemp, Log, TEXT("liubo, C7EnableShadow, b=%d, Actor=%s"), b, *Actor->GetFullName());
			}
		}
	}	
}

// 删掉所有的阴影
FAutoConsoleCommand OptC7OptShadowEnable(TEXT("c7.opt.shadow.enable"), TEXT("c7.opt.shadow.enable"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		C7EnableShadow(true);
	}));
FAutoConsoleCommand OptC7OptShadowDisable(TEXT("c7.opt.shadow.disable"), TEXT("c7.opt.shadow.disable"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		C7EnableShadow(false);	
	}));
FAutoConsoleCommand OptC7OptShadowEnable2(TEXT("c7.opt.shadow.enable2"), TEXT("c7.opt.shadow.enable2"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		C7EnableShadow(true, UInstancedStaticMeshComponent::StaticClass());
	}));
FAutoConsoleCommand OptC7OptShadowDisable2(TEXT("c7.opt.shadow.disable2"), TEXT("c7.opt.shadow.disable2"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		C7EnableShadow(false, UInstancedStaticMeshComponent::StaticClass());
	}));
FAutoConsoleCommand OptC7OptShadowDump(TEXT("c7.opt.shadow.dump"), TEXT("c7.opt.shadow.dump"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		C7DumpShadowInfo();	
	}));

// 强制GC
FAutoConsoleCommand OptC7EditorGC(TEXT("c7.editor.gc"), TEXT("c7.editor.gc"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		if(!IsInGameThread())
		{
			UE_LOG(LogTemp, Error, TEXT("C7 force GC Failed. GC Must in GameThread..."));
			return;			
		}
		
		EObjectFlags Mode = RF_NoFlags;
		if(Args.Num() == 1)
		{
			// editor模式，允许保留没有引用关系的资产
			if(Args[0] == "2")
			{
				Mode = GARBAGE_COLLECTION_KEEPFLAGS;				
			}
		}
				
		UTypedElementRegistry* Registry = UTypedElementRegistry::GetInstance();
		UTypedElementRegistry::FDisableElementDestructionOnGC GCGuard(Registry);
		FAssetRegistryModule::TickAssetRegistry(-1.0f);
		// CollectGarbage(GARBAGE_COLLECTION_KEEPFLAGS);
		// CollectGarbage(RF_NoFlags);
		CollectGarbage(Mode);
		if (IsIncrementalPurgePending())
		{
			IncrementalPurgeGarbage(false);
		}
		FMemory::Trim();
		UE_LOG(LogTemp, Log, TEXT("C7 force GC done...Flags=%d"), (int)Mode);
	}));

static void C7SaveLocalConfig(bool bLog, const FString& Folder, const FString& FileName,
	const FString& SectionName, const FString& Key, const FString NewValue)
{
	const FString ConfigFilePath = FPaths::GeneratedConfigDir() / Folder / FileName;	
	GConfig->SetString(*SectionName, *Key, *NewValue, ConfigFilePath);
	GConfig->Flush(false, ConfigFilePath);
	
	if(bLog)
	{
		UE_LOG(LogTemp, Log, TEXT("C7.SaveLocalConfig, Section=%s, Key=%s, V=%s, File=%s"), *SectionName, *Key, *NewValue, *ConfigFilePath);
	}
}

// NormalizeConfigIniPath, FindOrLoadPlatformConfig
static void C7SaveEmbedConfig(bool bLog, const FString& EmbedName,
	const FString& SectionName, const FString& Key, const FString NewValue)
{	
	GConfig->SetString(*SectionName, *Key, *NewValue, EmbedName);
	GConfig->Flush(false, EmbedName);
	
	if(bLog)
	{
		UE_LOG(LogTemp, Log, TEXT("C7.SaveLocalConfig, Section=%s, Key=%s, V=%s, File=%s"), *SectionName, *Key, *NewValue, *EmbedName);
	}
}
static TArray<FString> GetEmbedConfigList()
{
	TArray<FString> EmbedConfigList;
	EmbedConfigList.Add(GEngineIni);
	EmbedConfigList.Add(GGameIni);
	EmbedConfigList.Add(GInputIni);
	EmbedConfigList.Add(GDeviceProfilesIni);
	EmbedConfigList.Add(GGameUserSettingsIni);
	EmbedConfigList.Add(GScalabilityIni);
	EmbedConfigList.Add(GRuntimeOptionsIni);
	EmbedConfigList.Add(GInstallBundleIni);
	EmbedConfigList.Add(GHardwareIni);
	EmbedConfigList.Add(GGameplayTagsIni);
	
	EmbedConfigList.Add(GCompatIni);
	EmbedConfigList.Add(GLightmassIni);
	EmbedConfigList.Add(GGameplayTagsIni);
	
	EmbedConfigList.Add(GEditorLayoutIni);
	EmbedConfigList.Add(GEditorKeyBindingsIni);
	EmbedConfigList.Add(GEditorSettingsIni);
	EmbedConfigList.Add(GEditorIni);
	EmbedConfigList.Add(GEditorPerProjectIni);

	return EmbedConfigList;
}
static void C7SaveEmbedConfigUseIdx(bool bLog, int Idx,
	const FString& SectionName, const FString& Key, const FString NewValue)
{
	const auto& EmbedConfigList = GetEmbedConfigList();

	if(Idx >= 0 && Idx < EmbedConfigList.Num())
	{
		C7SaveEmbedConfig(bLog, EmbedConfigList[Idx], SectionName, Key, NewValue);
	}
}

// 面向CVar的
FAutoConsoleCommand OptC7SaveLocalConfigCVar(TEXT("c7.cfg.savelocal.cvar"), TEXT("c7.cfg.savelocal.cvar"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		if(Args.Num() != 2)
		{
			return;
		}
		// C7SaveLocalConfig(true, TEXT("WindowsEditor"), TEXT("Engine.ini"), "ConsoleVariables", Args[0], Args[1]);
		GConfig->SetString(TEXT("ConsoleVariables"), *Args[0], *Args[1], GEngineIni);
		GConfig->Flush(false, GEngineIni);
	}));

// 面向Editor的
FAutoConsoleCommand OptC7SaveLocalConfigEditor(TEXT("c7.cfg.savelocal.editor"), TEXT("c7.cfg.savelocal.editor"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		if(Args.Num() != 4)
		{
			return;
		}
		C7SaveLocalConfig(true, TEXT("WindowsEditor"), Args[0], Args[1], Args[2], Args[3]);
	}));

// 通用的
FAutoConsoleCommand OptC7SaveLocalConfig(TEXT("c7.cfg.savelocal"), TEXT("c7.cfg.savelocal"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		if(Args.Num() != 5)
		{
			return;
		}
		C7SaveLocalConfig(true, Args[0], Args[1], Args[2], Args[3], Args[4]);
	}));
FAutoConsoleCommand OptC7SaveEmbedConfig(TEXT("c7.cfg.save"), TEXT("c7.cfg.save"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		if(Args.Num() != 4)
		{
			return;
		}
		const int Idx = FCString::Atoi(*Args[0]);
		C7SaveEmbedConfigUseIdx(true, Idx, Args[1], Args[2], Args[3]);
	}));


FAutoConsoleCommand OptC7HeroTrace(TEXT("c7.hero.trace"), TEXT("c7.hero.trace"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		float RadiusScale = 1;
		if(Args.Num() > 0)
		{
			RadiusScale = FCString::Atof(*Args[0]);
		}
		auto World = FOptHelper::GetGameWorld();
		if(!World)
		{
			return;
		}
		auto LocalPlayer = World->GetFirstLocalPlayerFromController();
		if(!LocalPlayer->GetPlayerController(0))
		{
			return;
		}
		auto Pawn = Cast<ACharacter>(LocalPlayer->GetPlayerController(0)->GetPawn());
		if(!Pawn)
		{
			return;
		}
		auto CapsuleComp = Pawn->GetCapsuleComponent();
		if(!CapsuleComp)
		{
			return;
		}

		TArray<TEnumAsByte<EObjectTypeQuery>> Queries;
		Queries.Add(ObjectTypeQuery1);
		Queries.Add(ObjectTypeQuery2);
		TArray<AActor*> Actors;
		Actors.Add(Pawn);

		TArray<UPrimitiveComponent*> Hits;
		FVector Loc = CapsuleComp->GetComponentLocation();
		FVector End = Loc + CapsuleComp->GetForwardVector() * CapsuleComp->GetScaledCapsuleRadius() * RadiusScale;
		UKismetSystemLibrary::CapsuleOverlapComponents(Pawn, End,
			CapsuleComp->GetScaledCapsuleRadius(),
			CapsuleComp->GetScaledCapsuleHalfHeight(), Queries,
			nullptr, Actors, Hits);

		FLinearColor TraceColor = FLinearColor::Red, TraceHitColor = FLinearColor::Red;
		FHitResult HitTemp;
#if ENABLE_DRAW_DEBUG
		DrawDebugLineTraceSingle(World, Loc, End, EDrawDebugTrace::ForDuration,
			false, HitTemp, TraceColor, TraceHitColor, 1);
#endif
		
		UE_LOG(LogTemp, Log, TEXT("liubo, hit result.Num=%d"), Hits.Num());
		
		for(auto Hit : Hits)
		{
			UE_LOG(LogTemp, Log, TEXT("liubo, hit:%s"), *Hit->GetFullName());
		}		
	}));


FAutoConsoleCommand OptC7ActorCollision(TEXT("c7.col.actor"), TEXT("c7.col.actor"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		FString ActorName;
		bool bEnable = false;
		if(Args.Num() > 0)
		{
			ActorName = Args[0];
		}
		if(Args.Num() > 1)
		{
			bEnable = FCString::Atoi(*Args[1]) > 0;
		}
		
		auto World = FOptHelper::GetGameWorld();
		if(!World)
		{
			return;
		}

		for(FActorIterator It(World); It; ++It)
		{
			if(It->GetName() == ActorName)
			{
				It->SetActorEnableCollision(bEnable);				
				UE_LOG(LogTemp, Log, TEXT("liubo, hit:%s, bEnable=%d"), *It->GetFullName(), bEnable);
				break;
			}
		}		
	}));

FAutoConsoleCommand OptC7OptHideActor(TEXT("c7.opt.hideactor"), TEXT("c7.opt.hideactor"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		auto Cls = USkeletalMeshComponent::StaticClass();
		bool bVisible = false;
		int Dist = 0;

		if(Args.Num() > 0)
		{
			bVisible = FCString::Atoi(*Args[0]) > 0;
		}
		
		if(Args.Num() > 1)
		{
			int ClsIdx = FCString::Atoi(*Args[1]);
			TArray<UClass*> ClsList(
				{
					USkeletalMeshComponent::StaticClass(),
					UNiagaraComponent::StaticClass(),
			});
			if(ClsList.IsValidIndex(ClsIdx))
			{
				Cls = ClsList[ClsIdx];
			}
		}
		
		if(Args.Num() > 2)
		{
			Dist = FCString::Atoi(*Args[2]) * 100;
		}
		
		auto World = FOptHelper::GetGameWorld();
		
		FVector PlayerLoc = FVector::Zero();		
		if(Dist > 0)
		{
			auto LocalPlayer = World->GetFirstLocalPlayerFromController();
			if(LocalPlayer->GetPlayerController(0))
			{
				auto Pawn = Cast<ACharacter>(LocalPlayer->GetPlayerController(0)->GetPawn());
				if(Pawn && Pawn->GetCapsuleComponent())
				{
					PlayerLoc = Pawn->GetCapsuleComponent()->GetComponentLocation();
				}
				else
				{
					Dist = 0;
				}
			}
			else
			{
				Dist = 0;
			}
		}
		
		for(FActorIterator It(World); It; ++It)
		{
			AActor* Actor = *It;
			Actor->ForEachComponent<UPrimitiveComponent>(false, [Cls, bVisible, Dist, PlayerLoc](UPrimitiveComponent* Prim)
			{
				if(Dist > 0)
				{
					auto DistDiff = FVector::Dist2D(PlayerLoc, Prim->GetComponentLocation());
					if(DistDiff < Dist)
					{
						return;
					}
				}
				
				if(Prim->IsA(Cls))
				{
					if(Cls->IsChildOf(UNiagaraComponent::StaticClass()))
					{
						auto NiaComp = Cast<UNiagaraComponent>(Prim);
						if(bVisible)
						{
							NiaComp->Activate();
						}
						else
						{
							NiaComp->Deactivate();
						}
					}
					else
					{
						Prim->SetVisibility(bVisible);						
					}
				}
			});
		}		
	}));

// 测下来，效果不明显
FAutoConsoleCommand OptC7OptMaxDrawDist(TEXT("c7.opt.maxdrawdist"), TEXT("c7.opt.maxdrawdist"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		int Dist = 0;
		auto Cls = UNiagaraComponent::StaticClass();
		
		if(Args.Num() > 0)
		{
			Dist = FCString::Atoi(*Args[0]) * 100;
		}
		
		if(Args.Num() > 1)
		{
			int ClsIdx = FCString::Atoi(*Args[1]);
			TArray<UClass*> ClsList(
				{
					UStaticMeshComponent::StaticClass(),
					UNiagaraComponent::StaticClass(),
					UInstancedStaticMeshComponent::StaticClass(),
					USkeletalMeshComponent::StaticClass(),
			});
			if(ClsList.IsValidIndex(ClsIdx))
			{
				Cls = ClsList[ClsIdx];
			}
		}
		
		auto World = FOptHelper::GetGameWorld();		
		
		for(FActorIterator It(World); It; ++It)
		{
			AActor* Actor = *It;
			Actor->ForEachComponent<UPrimitiveComponent>(false, [Cls, Dist](UPrimitiveComponent* Prim)
			{				
				if(Prim->IsA(Cls))
				{
					Prim->SetCullDistance(Dist);
				}
			});
		}		
	}));

FAutoConsoleCommand OptC7OptHideShadow(TEXT("c7.opt.hlod2.shadow"), TEXT("c7.opt.hlod2.shadow"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		bool bVisible = false;

		if(Args.Num() > 0)
		{
			bVisible = FCString::Atoi(*Args[0]) > 0;
		}
		
		auto World = FOptHelper::GetGameWorld();		
		for(FActorIterator It(World); It; ++It)
		{
			AActor* Actor = *It;
			if(!Actor->IsA<AWorldPartitionHLOD>())
			{
				return;
			}
			
			Actor->ForEachComponent<UStaticMeshComponent>(false, [bVisible](UStaticMeshComponent* Prim)
			{
				Prim->SetCastShadow(bVisible);
			});
		}		
	}));

FAutoConsoleCommand OptC7TestDumpOuter(TEXT("c7.test.dump.actor.outer"), TEXT("c7.test.dump.actor.outer"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		int Cnt = 10;

		if(Args.Num() > 0)
		{
			Cnt = FCString::Atoi(*Args[0]);
		}
		
		auto World = FOptHelper::GetGameWorld();		
		for(FActorIterator It(World); It; ++It)
		{
			AActor* Actor = *It;
			if(Actor->GetTypedOuter<UWorld>() != World)
			{
				UE_LOG(LogTemp, Log, TEXT("liubo, actor=%s\n\t\t outer=%s\n\t\t world=%s"),
					*Actor->GetFullName(), *Actor->GetTypedOuter<UWorld>()->GetFullName(), *World->GetFullName());
				Cnt--;
			}
			if(Cnt < 0)
			{
				break;
			}
		}		
	}));

// dump streaming信息
FAutoConsoleCommand OptC7WpDumpCell(TEXT("c7.wp.dump.streaming"), TEXT("c7.wp.dump.streaming"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		bool bFull = false;
		if(Args.Num() > 0)
		{
			bFull = FCString::Atoi(*Args[0]) > 0;
		}
		auto World = FOptHelper::GetGameWorld();
		TArray<UWorldPartitionRuntimeLevelStreamingCell*> Cells;
		TSet<ULevelStreamingDynamic*> StreamingSet;
		for(TObjectIterator<UWorldPartitionRuntimeLevelStreamingCell> It; It; ++It)
		{
			if(It->GetOuterWorld() == World)
			{
				Cells.Add(*It);
			}
			if(It->GetLevelStreaming())
			{
				StreamingSet.Add(It->GetLevelStreaming());
			}
		}
		Cells.Sort([](const UWorldPartitionRuntimeLevelStreamingCell& A, const UWorldPartitionRuntimeLevelStreamingCell& B)
		{
			if(A.GetCurrentState() == B.GetCurrentState())
			{
				return (int)A.GetIsHLOD() < (int)B.GetIsHLOD();
			}
			return A.GetCurrentState() > B.GetCurrentState();
		});
		
		for(auto It : Cells)
		{
			if(!bFull)
			{
				if(It->GetCurrentState() == EWorldPartitionRuntimeCellState::Unloaded)
				{
					continue;
				}
			}
			UE_LOG(LogTemp, Log, TEXT("liubo, wp.streaming, cell=%s, DebugName=%s, IsHlod=%d, CellState=%s, LevelState=%s, CellBound=Center=(%s);Size=(%s)"),
				*It->GetLevelPackageName().ToString(),
				*It->GetDebugName(),
				It->GetIsHLOD(),
				*UEnum::GetValueAsString(It->GetCurrentState()),
				It->GetLevelStreaming() ? EnumToString(It->GetLevelStreaming()->GetLevelStreamingState()) : TEXT("None"),
				*It->GetCellBounds().GetCenter().ToString(),
				*It->GetCellBounds().GetSize().ToString());
		}
		
		// 打印非Cell的
		for(TObjectIterator<ULevelStreamingDynamic> It; It; ++It)
		{
			if(It->GetOuterUWorld() == World)
			{
				if(!StreamingSet.Contains(*It))
				{
					UE_LOG(LogTemp, Log, TEXT("liubo, wp.streaming, NoCellInfo. LevelStreaming=%s, LevelState=%s"),
						*It->GetWorldAssetPackageName(),
						EnumToString(It->GetLevelStreamingState()));
				}
			}
		}
	}));


FAutoConsoleCommand OptC7Cmd(TEXT("c7.cmd"), TEXT("c7.cmd"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		FString Idx;
		if(Args.Num() > 0)
		{
			Idx = Args[0];
		}
		FString Section("C7GameCmd");
		if(!Idx.IsEmpty())
		{
			Section += "@" + Idx;
		}
		TArray<FString> CmdList;
		GConfig->GetArray(*Section, TEXT("Cmd"), CmdList, GGameUserSettingsIni);
		if (CmdList.Num() == 0)
		{
			GConfig->GetArray(*Section, TEXT("Cmd"), CmdList, GEngineIni);
		}
		for(const auto& Cmd : CmdList)
		{
			UE_LOG(LogTemp, Log, TEXT("liubo, auto Cmd, Section=%s, Cmd=%s"), *Section, *Cmd);
			GEngine->Exec(nullptr, *Cmd);
		}
	}));

#if !UE_BUILD_SHIPPING
static FAutoConsoleCommand DumpTextureDetailInfosCmd(
	TEXT("c7.opt.dumptextureinfo"),
	TEXT("Dump All Texture Detail Info"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		auto World = FOptHelper::GetGameWorld();
		const FString FileName = FString::Printf(TEXT("%s_RuntimeTextureInfo_%s.csv"), World ? *World->GetMapName() : TEXT("None"), *FDateTime::Now().ToString());
		const FString FilePath = FPaths::ProjectLogDir() / FileName;
		TStringBuilder<1024> TextureInfos;
		TextureInfos << TEXT("Cooked/OnDisk: Width x Height,Cooked Size(KB), Current/InMem: Width x Height, Size (KB), Format, Name, VT, NumMips, Uncompressed") << TEXT("\n");

		for (TObjectIterator<UTexture> It; It; ++It)
		{
			UTexture* Texture = *It;
			UTexture2D* Texture2D = Cast<UTexture2D>(Texture);
			UTextureCube* TextureCube = Cast<UTextureCube>(Texture);
			UVolumeTexture* Texture3D = Cast<UVolumeTexture>(Texture);
			UTextureRenderTarget2D* RenderTexture = Cast<UTextureRenderTarget2D>(Texture);

			int32 NumMips = 1;
			int32 MaxResLODBias = Texture->GetCachedLODBias();;
			int32 MaxAllowedSizeX = FMath::Max<int32>(static_cast<int32>(Texture->GetSurfaceWidth()) >> MaxResLODBias, 1);
			int32 MaxAllowedSizeY = FMath::Max<int32>(static_cast<int32>(Texture->GetSurfaceHeight()) >> MaxResLODBias, 1);
			EPixelFormat Format = PF_Unknown;
			int32 DroppedMips = MaxResLODBias;
			int32 CurSizeX = FMath::Max<int32>(static_cast<int32>(Texture->GetSurfaceWidth()) >> DroppedMips, 1);
			int32 CurSizeY = FMath::Max<int32>(static_cast<int32>(Texture->GetSurfaceHeight()) >> DroppedMips, 1);
			int32 MaxAllowedSize = Texture->CalcTextureMemorySizeEnum(TMC_AllMipsBiased);
			int32 CurrentSize = Texture->CalcTextureMemorySizeEnum(TMC_ResidentMips);
			bool bIsVirtual = Texture->IsCurrentlyVirtualTextured();
			bool bIsUncompressed = Texture->IsUncompressed();

			if (Texture2D != nullptr)
			{
				NumMips = Texture2D->GetNumMips();
				MaxResLODBias = NumMips - Texture2D->GetNumMipsAllowed(false);
				MaxAllowedSizeX = FMath::Max<int32>(Texture2D->GetSizeX() >> MaxResLODBias, 1);
				MaxAllowedSizeY = FMath::Max<int32>(Texture2D->GetSizeY() >> MaxResLODBias, 1);
				Format = Texture2D->GetPixelFormat();
				DroppedMips = Texture2D->GetNumMips() - Texture2D->GetNumResidentMips();
				CurSizeX = FMath::Max<int32>(Texture2D->GetSizeX() >> DroppedMips, 1);
				CurSizeY = FMath::Max<int32>(Texture2D->GetSizeY() >> DroppedMips, 1);
			}
			else if (TextureCube != nullptr)
			{
				NumMips = TextureCube->GetNumMips();
				Format = TextureCube->GetPixelFormat();
			}
			else if (Texture3D != nullptr)
			{
				NumMips = Texture3D->GetNumMips();
				Format = Texture3D->GetPixelFormat();
			}
			else if (RenderTexture != nullptr)
			{
				NumMips = RenderTexture->GetNumMips();
				Format = RenderTexture->GetFormat();
			}

			const int32 CalcCurrentSize = (CurrentSize + 512) / 1024;
			//constexpr int32 MaxTextureSize = 100;
			//if(CalcCurrentSize > MaxTextureSize || CalcCurrentSize == 0)
			{
				FString OutMsg = FString::Printf(TEXT("%ix%i ,%i, %ix%i, %i, %s, %s,  %s, %d, %s"),
													 MaxAllowedSizeX, MaxAllowedSizeY, (MaxAllowedSize + 512) / 1024,
													 CurSizeX, CurSizeY, CalcCurrentSize,
													 GetPixelFormatString(Format),
													 *Texture->GetPathName(),
													 bIsVirtual ? TEXT("YES") : TEXT("NO"),
													 NumMips,
													 bIsUncompressed ? TEXT("YES") : TEXT("NO"));
				
				TextureInfos << OutMsg << TEXT("\n");
			}
		}

		if (FFileHelper::SaveStringToFile(TextureInfos.ToString(), *FilePath))
		{
			UE_LOG(LogTemp, Log, TEXT("Dump All Texture Detail Info to %s"), *FilePath);
		}
	}));
#endif



FAutoConsoleCommand KGDumpLLM(TEXT("kg.DumpLLM"), TEXT("Logs out the current and peak sizes of all tracked LLM tags"), FConsoleCommandWithWorldArgsAndOutputDeviceDelegate::CreateLambda([](const TArray<FString>& Args, UWorld* InWorld, FOutputDevice& Ar)
{
	FString Command = FString::Join(Args, TEXT(" "));


	bool bSaveFile = FParse::Param(*Command, TEXT("save"));
	if (bSaveFile)
	{
		IFileManager& FileManager = FFileManagerGeneric::Get();
		FString Folder = FPaths::ProfilingDir() / FString("LLM");
		FString FilePath = Folder / FDateTime::Now().ToString(TEXT("LLM-%Y%m%d_%H%M%S"));
		FString MapName = InWorld->GetMapName();
		if(MapName.Len() > 0)
		{
			FilePath += FString("-") + MapName;
		}
		FilePath += FString(".csv");
		
		FileManager.MakeDirectory(*Folder, true);

		TUniquePtr<FArchive> FileAr = TUniquePtr<FArchive>(IFileManager::Get().CreateFileWriter(*FilePath));
		FOutputDeviceArchiveWrapper FileArWrapper(FileAr.Get());
		FKgCoreUtils::DumpLLM(Args, &FileArWrapper);
		GEngine->AddOnScreenDebugMessage(-1, 5, FColor::Red, TEXT("Dump LLM csv Done!"));
	}
	else
	{
		FKgCoreUtils::DumpLLM(Args, &Ar);
		GEngine->AddOnScreenDebugMessage(-1, 5, FColor::Red, TEXT("Dump LLM Done!"));
	}
}));


FAutoConsoleCommand C7OptQAMemEnv(TEXT("c7.OptQAMemEnv"), TEXT("c7.OptQAMemEnv"),
	FConsoleCommandWithWorldArgsAndOutputDeviceDelegate::CreateLambda([](const TArray<FString>& Args, UWorld* InWorld, FOutputDevice& Ar)
{
		UE_LOG(LogTemp, Log, TEXT("OptQAMemEnv Args:%s"), *FString::Join(Args, TEXT(",")));

		{		
			const FString SectionName("SectionsToSave");
			TArray<FString> OldValues;
			GConfig->GetArray(*SectionName, TEXT("Section"), OldValues, GEngineIni);
			OldValues.AddUnique("ConsoleVariables");
			OldValues.AddUnique("SectionsToSave");
			GConfig->SetArray(*SectionName, TEXT("Section"), OldValues, GEngineIni);
			GConfig->Flush(false, GEngineIni);	
		}
		
		// 设置关闭野指针工具。如果以后需求多，再改成配置的
		{		
			const FString SectionName("ConsoleVariables");	
		
			GConfig->SetString(*SectionName, TEXT("kg.crashcollector.enable"), TEXT("0"), GEngineIni);
			GConfig->SetString(*SectionName, TEXT("kg.objcrashcollector.enable"), TEXT("0"), GEngineIni);
			GConfig->Flush(false, GEngineIni);	
		}

		// 关闭野指针工具
		{
			GEngine->Exec(InWorld, TEXT("kg.crashcollector.enable 0"), *GLog);
			GEngine->Exec(InWorld, TEXT("kg.objcrashcollector.enable 0"), *GLog);
		}
}));

FAutoConsoleCommand C7OptQAMemEnvView(TEXT("c7.OptQAMemEnvView"), TEXT("c7.OptQAMemEnvView"),
	FConsoleCommandWithWorldArgsAndOutputDeviceDelegate::CreateLambda([](const TArray<FString>& Args, UWorld* InWorld, FOutputDevice& Ar)
{
		UE_LOG(LogTemp, Log, TEXT("OptQAMemEnvView Args:%s"), *FString::Join(Args, TEXT(",")));
		
		FOptHelper::DumpConsoleValue(TEXT("kg.crashcollector.enable"));
		FOptHelper::DumpConsoleValue(TEXT("kg.objcrashcollector.enable"));	
}));

FAutoConsoleCommand C7DumpIni(TEXT("c7.dumpini"), TEXT("c7.dumpini"),
	FConsoleCommandWithWorldArgsAndOutputDeviceDelegate::CreateLambda([](const TArray<FString>& Args, UWorld* InWorld, FOutputDevice& Ar)
{
		FString IniFile = GEngineIni;
		FString SectionName("ConsoleVariables");
		if(Args.Num() == 2)
		{
			// 支持传索引和传字符串，两种形式
			int Idx = FCString::Atoi(*Args[0]);
			if(Idx == 0)
			{
				IniFile = Args[0];	
			}
			else
			{
				const auto& EmbedConfigList = GetEmbedConfigList();
				if(EmbedConfigList.IsValidIndex(Idx-1))
				{
					IniFile = EmbedConfigList[Idx-1];	
				}					
			}
			
			SectionName = Args[1];
		}
		
		if(const FConfigSection* Section = GConfig->GetSection(*SectionName, false, IniFile))
		{
			for(FConfigSectionMap::TConstIterator It(*Section); It; ++It)
			{
				const FString& KeyString = It.Key().GetPlainNameString(); 
				const FString& ValueString = It.Value().GetValue();
				UE_LOG(LogTemp, Log, TEXT("DumpIni: %s.ini, [%s], %s=%s"), *IniFile, *SectionName, *KeyString, *ValueString);
			}
		}
}));