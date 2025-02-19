// Fill out your copyright notice in the Description page of Project Settings.

#include "UIAutomationProfile.h"

#include "CoreMinimal.h"
#include "FStatsThreadStateOverlay.h"
#include "LuaState.h"
#include "SluaUtil.h"
#include "PaperSprite.h"
#include "CoreMinimal.h"
#include "PaperSpriteAtlas.h"
#include "SceneInterface.h"
#include "AssetRegistry/AssetData.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Blueprint/UserWidget.h"
#include "Kismet/KismetSystemLibrary.h"
#include "Blueprint/WidgetTree.h"
#include "Engine/Engine.h"
#include "HAL/PlatformFileManager.h"
#include "UMG/Components/KGImage.h"
#include "Materials/Material.h"
#include "Misc/FileHelper.h"
#include "UnrealClient.h"
#include "Misc/Paths.h"

DEFINE_LOG_CATEGORY(LogUIAutomationProfile);

#if STATS
static struct FSlateStatDumpAverage* SlateStatDumpAverage = nullptr;

struct FSlateStatDumpAverage
{
	FStatsThreadState& Stats;
	int32 NumFrames;
	FRawStatStackNode* Stack;
	FDelegateHandle NewFrameDelegateHandle;
	TArray<FString> SlateStatNameArray;
	TArray<FStatMessage> NonStackStats;
	TMap<FString, TPair<FString, double>> SlateStatValueArray;
	TMap<FString, TPair<FString, double>> TempSlateStatValueArray;

	FSlateStatDumpAverage(const TArray<FString> SlateStatNameArray)
		: Stats(FStatsThreadState::GetLocalState())
		, NumFrames(0)
		, Stack(nullptr)
		, SlateStatNameArray(SlateStatNameArray)
	{
		StatsPrimaryEnableAdd();
		SlateStatValueArray.Empty();
		NewFrameDelegateHandle = Stats.NewFrameDelegate.AddRaw(this, &FSlateStatDumpAverage::NewFrame);
	}

	~FSlateStatDumpAverage()
	{
	}

	void CollectData(TMap<FString, TPair<FString, double>>& OutValue)
	{
		OutValue = SlateStatValueArray;
		delete Stack;
		Stack = nullptr;
		Stats.NewFrameDelegate.Remove(NewFrameDelegateHandle);
		StatsPrimaryEnableSubtract();
		SlateStatDumpAverage = nullptr;
	}

	void NewFrame(int64 TargetFrame)
	{
		FSlateFilter Filter;
		TempSlateStatValueArray.Empty();
		NonStackStats.Empty();
		if (!Stack)
		{
			Stack = new FRawStatStackNode();
			Stats.UncondenseStackStats(TargetFrame, *Stack, nullptr, &NonStackStats);
			DumpStatStackNode(Stack);
			for (auto Stat : NonStackStats)
			{
				for (auto StatName : SlateStatNameArray)
				{
					if (Stat.NameAndInfo.GetRawName().ToString().Contains(StatName))
					{
						ProcessStatValue(Stat);
					}
				}
			}
			SlateStatValueArray = TempSlateStatValueArray;
		}
		else
		{
			FRawStatStackNode FrameStack;
			Stats.UncondenseStackStats(TargetFrame, FrameStack, nullptr, &NonStackStats);
			DumpStatStackNode(&FrameStack);
			for (auto Stat : NonStackStats)
			{
				for (auto StatName : SlateStatNameArray)
				{
					if (Stat.NameAndInfo.GetRawName().ToString().Contains(StatName))
					{
						ProcessStatValue(Stat);
					}
				}
			}
			MergeAdd(SlateStatValueArray, TempSlateStatValueArray);
			//Stack->MergeAdd(FrameStack);
		}
		NumFrames++;
	}

	void DumpStatStackNode(FRawStatStackNode* Root)
	{
		static int64 MinPrint = -1;
		if (Root && Root->Children.Num())
		{
			TArray<FRawStatStackNode*> ChildArray;
			Root->Children.GenerateValueArray(ChildArray);
			ChildArray.Sort( FStatDurationComparer<FRawStatStackNode>() );
			for (int32 Index = 0; Index < ChildArray.Num(); Index++)
			{
				if (ChildArray[Index]->Meta.GetValue_Duration() < MinPrint)
				{
					break;
				}
				for (auto StatName : SlateStatNameArray)
				{
					if (ChildArray[Index]->Meta.NameAndInfo.GetRawName().ToString().Contains(StatName))
					{
						ProcessStatValue(ChildArray[Index]->Meta);
					}
				}
				DumpStatStackNode(ChildArray[Index]);
			}
		}
	}

	void ProcessStatValue(FStatMessage Item)
	{
		const FString ShortName = Item.NameAndInfo.GetShortName().ToString();
		const FString Description = Item.NameAndInfo.GetDescription();
		switch (Item.NameAndInfo.GetField<EStatDataType>())
		{
		case EStatDataType::ST_int64:
			if (Item.NameAndInfo.GetFlag(EStatMetaFlags::IsPackedCCAndDuration))
			{
				float Duration = FPlatformTime::ToMilliseconds(FromPackedCallCountDuration_Duration(Item.GetValue_int64()));
				if (!TempSlateStatValueArray.Contains(ShortName))
				{
					TempSlateStatValueArray.Add(ShortName, MakeTuple(Description,Duration));
				}
			}
			else if (Item.NameAndInfo.GetFlag(EStatMetaFlags::IsCycle))
			{
				float Duration = FPlatformTime::ToMilliseconds64(Item.GetValue_int64());
				if (!TempSlateStatValueArray.Contains(ShortName))
				{
					TempSlateStatValueArray.Add(ShortName, MakeTuple(Description,Duration));
				}
			}
			else if (Item.NameAndInfo.GetFlag(EStatMetaFlags::IsMemory))
			{
				double Memory = (double)Item.GetValue_int64() / 1024.0 / 1024.0;
				if (!TempSlateStatValueArray.Contains(ShortName))
				{
					TempSlateStatValueArray.Add(ShortName, MakeTuple(Description, Memory));
				}
			}
			else
			{
				if (!TempSlateStatValueArray.Contains(ShortName))
				{
					TempSlateStatValueArray.Add(ShortName, MakeTuple(Description, (double)Item.GetValue_int64()));
				}
			}
			break;
		case EStatDataType::ST_double:
			if (!TempSlateStatValueArray.Contains(ShortName))
			{
				TempSlateStatValueArray.Add(ShortName, MakeTuple(Description, (double)Item.GetValue_int64()));
			}
			break;
		default:
			break;
		}
	}

	static void MergeAdd(TMap<FString, TPair<FString, double>>& OutValue, TMap<FString, TPair<FString, double>> InValue)
	{
		for (auto& Item : InValue)
		{
			if (OutValue.Contains(Item.Key))
			{
				OutValue[Item.Key].Value = (OutValue[Item.Key].Value + Item.Value.Value) / 2;
			}
			else
			{
				OutValue.Add(Item);
			}
		}
	}
};

#endif

void UUIAutomationProfile::Init()
{
	SlateStatNameArray.Empty();
	SlateStatNameArray.Add("STAT_SlateRenderingRTTime");
	SlateStatNameArray.Add("STAT_SlateRTDrawBatches");
	SlateStatNameArray.Add("STAT_SlateDrawWindowTime");
	SlateStatNameArray.Add("STAT_ViewportPaintTime");
	SlateStatNameArray.Add("STAT_SlateTickWidgets");
	SlateStatNameArray.Add("STAT_SlatePrepass");
	SlateStatNameArray.Add("STAT_SlateNumBatches");
	SlateStatNameArray.Add("STAT_SlateVertexCount");
	StatsPrimaryEnableAdd();
	UIProfileDataArray.Empty();
	IPlatformFile& PlatformFile = FPlatformFileManager::Get().GetPlatformFile();
	FString DirectoryPath = GetDefault<UEngine>()->GameScreenshotSaveDirectory.Path;
	if (!PlatformFile.DirectoryExists(*DirectoryPath))
	{
		UE_LOG(LogUIAutomationProfile, Warning, TEXT("Directory does not exist: %s"), *DirectoryPath);
		return;
	}
	TArray<FString> FilesToDelete;
	PlatformFile.FindFilesRecursively(FilesToDelete, *DirectoryPath, TEXT("*"));
	for (const FString& File : FilesToDelete)
	{
		if (!PlatformFile.DeleteFile(*File))
		{
			UE_LOG(LogUIAutomationProfile, Warning, TEXT("Failed to delete file: %s"), *File);
		}
	}
}

void UUIAutomationProfile::StartSingleUIProfile(FString& UIName, float LuaMemory)
{
	UIProfileDataArray.Add(TempUIProfileData);
	TempUIProfileData.Name = FName(UIName);
	TempUIProfileData.Error = "";
	TempUIProfileData.Time = 0;
	TempUIProfileData.UObjectNum = 0;
	TempUIProfileData.TotalTrackedMemoryBefore = 0;
	TempUIProfileData.TotalTrackedMemoryOnShow = 0;
	TempUIProfileData.TotalTrackedMemoryOnClose = 0;
	TempUIProfileData.LuaMemoryBefore = 0;
	TempUIProfileData.LuaMemoryOnShow = 0;
	TempUIProfileData.LuaMemoryOnClose = 0;
	TempUIProfileData.DependenceAtlasSet.Empty();
	TempUIProfileData.DependenceTextureSet.Empty();
	TempUIProfileData.SlateStatValueArray.Empty();
	TempUIProfileData.ScreenShotPath = "";
	TempUIProfileData.UObjectsLuaBefore.Empty();
	TempUIProfileData.UObjectsLuaAdd.Empty();
	StartTime = FPlatformTime::Seconds();

	CurTestUIName = UIName;
#if ENABLE_LOW_LEVEL_MEM_TRACKER
	if (FLowLevelMemTracker::Get().IsEnabled())
	{
		FLowLevelMemTracker::Get().UpdateStatsPerFrame();
		TempUIProfileData.TotalTrackedMemoryBefore = static_cast<float>(FLowLevelMemTracker::Get().GetTotalTrackedMemory(ELLMTracker::Default)) * InvToMb;
		const auto UITextMemory = FLowLevelMemTracker::Get().GetTagAmountForTracker(ELLMTracker::Default, FName("UI_Text"), ELLMTagSet::None) * InvToMb;
		TempUIProfileData.UIMemoryBefore = static_cast<float>(FLowLevelMemTracker::Get().GetTagAmountForTracker(ELLMTracker::Default, ELLMTag::UI)) * InvToMb - UITextMemory;
		TempUIProfileData.UObjectMemoryBefore = static_cast<float>(FLowLevelMemTracker::Get().GetTagAmountForTracker(ELLMTracker::Default, ELLMTag::UObject)) * InvToMb;
		TempUIProfileData.TextureMemoryBefore = static_cast<float>(FLowLevelMemTracker::Get().GetTagAmountForTracker(ELLMTracker::Default, ELLMTag::Textures)) * InvToMb;
		//FLowLevelMemTracker::Get().DumpToLog();
	}
#endif
	TempUIProfileData.LuaMemoryBefore = LuaMemory * 1024 * InvToMb;
	UE_LOG(LogUIAutomationProfile, Display, TEXT("StartSingleUIProfile"));
	dumpUObjectsLuaBefore();
	
	// GetKGMemoryStatisticsTreeAnalyserBeforeUIOpen();
}

void UUIAutomationProfile::OnSingleUIOpened(UUserWidget* Widget, FString WbpName, float LuaMemory, int OpenTimeMS)
{
	TRACE_BOOKMARK(TEXT("UIOpened: %s"), *TempUIProfileData.Name.ToString());

#if ENABLE_LOW_LEVEL_MEM_TRACKER
	if (FLowLevelMemTracker::Get().IsEnabled())
	{
		FLowLevelMemTracker::Get().UpdateStatsPerFrame();
		TempUIProfileData.TotalTrackedMemoryOnShow = static_cast<float>(FLowLevelMemTracker::Get().GetTotalTrackedMemory(ELLMTracker::Default)) * InvToMb;
		const auto UITextMemory = FLowLevelMemTracker::Get().GetTagAmountForTracker(ELLMTracker::Default, FName("UI_Text"), ELLMTagSet::None) * InvToMb;
		TempUIProfileData.UIMemoryOnShow = static_cast<float>(FLowLevelMemTracker::Get().GetTagAmountForTracker(ELLMTracker::Default, ELLMTag::UI)) * InvToMb - UITextMemory;
		TempUIProfileData.UObjectMemoryOnShow = static_cast<float>(FLowLevelMemTracker::Get().GetTagAmountForTracker(ELLMTracker::Default, ELLMTag::UObject)) * InvToMb;
		TempUIProfileData.TextureMemoryOnShow = static_cast<float>(FLowLevelMemTracker::Get().GetTagAmountForTracker(ELLMTracker::Default, ELLMTag::Textures)) * InvToMb;
		//FLowLevelMemTracker::Get().DumpToLog();
	}
#endif
	TempUIProfileData.LuaMemoryOnShow = LuaMemory * 1024 * InvToMb;
	TempUIProfileData.Time = OpenTimeMS;
	UE_LOG(LogUIAutomationProfile, Display, TEXT("OnSingleUIOpened Time:%lf"), TempUIProfileData.Time);
	UE_LOG(LogUIAutomationProfile, Display, TEXT("TotalTrackedMemory Before: %lf Now:%lf Increase:%lf"), TempUIProfileData.TotalTrackedMemoryBefore, TempUIProfileData.TotalTrackedMemoryOnShow, TempUIProfileData.TotalTrackedMemoryOnShow - TempUIProfileData.TotalTrackedMemoryBefore);
	UE_LOG(LogUIAutomationProfile, Display, TEXT("LuaMemory Before: %lf Now:%lf Increase:%lf"), TempUIProfileData.LuaMemoryBefore, TempUIProfileData.LuaMemoryOnShow, TempUIProfileData.LuaMemoryOnShow - TempUIProfileData.LuaMemoryBefore);
#if WITH_EDITOR
	FAssetRegistryModule& AssetRegistryModule = FModuleManager::LoadModuleChecked<FAssetRegistryModule>(TEXT("AssetRegistry"));
	TArray<FName> AssetsDependencies;
	if (Widget && Widget->WidgetGeneratedBy.IsValid())
	{
		AssetRegistryModule.Get().GetDependencies(Widget->WidgetGeneratedBy->GetPackage()->GetFName(), AssetsDependencies, UE::AssetRegistry::EDependencyCategory::All);
	}
	for (const auto& PackageName : AssetsDependencies)
	{
		TArray<FAssetData> OutAssetData;
		AssetRegistryModule.Get().GetAssetsByPackageName(PackageName, OutAssetData);
		if (!OutAssetData.IsEmpty())
		{
			UObject* AssetInPackage = OutAssetData[0].GetAsset();
			if(UPaperSprite* Sprite = Cast<UPaperSprite>(AssetInPackage))
			{
				AddDependenceAtlas(Sprite);
			}
			else if(UTexture* Texture = Cast<UTexture>(AssetInPackage))
			{
				AddDependenceTexture(Texture);
			}
		}
	}
#endif
	GetKGMemoryStatisticsTreeAnalyser(WbpName);
}

void UUIAutomationProfile::OnSingleUIClosed(float LuaMemory)
{
	TRACE_BOOKMARK(TEXT("UIClosed: %s"), *TempUIProfileData.Name.ToString());

#if ENABLE_LOW_LEVEL_MEM_TRACKER
	if (FLowLevelMemTracker::Get().IsEnabled())
	{
		FLowLevelMemTracker::Get().UpdateStatsPerFrame();
		TempUIProfileData.TotalTrackedMemoryOnClose = static_cast<float>(FLowLevelMemTracker::Get().GetTotalTrackedMemory(ELLMTracker::Default)) * InvToMb;
		const auto UITextMemory = FLowLevelMemTracker::Get().GetTagAmountForTracker(ELLMTracker::Default, FName("UI_Text"), ELLMTagSet::None) * InvToMb;
		TempUIProfileData.UIMemoryOnClose = static_cast<float>(FLowLevelMemTracker::Get().GetTagAmountForTracker(ELLMTracker::Default, ELLMTag::UI)) * InvToMb - UITextMemory;
		TempUIProfileData.UObjectMemoryOnClose = static_cast<float>(FLowLevelMemTracker::Get().GetTagAmountForTracker(ELLMTracker::Default, ELLMTag::UObject)) * InvToMb;
		TempUIProfileData.TextureMemoryOnClose = static_cast<float>(FLowLevelMemTracker::Get().GetTagAmountForTracker(ELLMTracker::Default, ELLMTag::Textures)) * InvToMb;
		//FLowLevelMemTracker::Get().DumpToLog();
	}
#endif
	TempUIProfileData.LuaMemoryOnClose = LuaMemory * 1024 * InvToMb;
	UE_LOG(LogUIAutomationProfile, Display, TEXT("OnSingleUIClosed TotalTrackedMemory Now:%lf Decrease:%lf"), TempUIProfileData.TotalTrackedMemoryOnClose, TempUIProfileData.TotalTrackedMemoryOnShow - TempUIProfileData.TotalTrackedMemoryOnClose);
	for(auto Atlas : TempUIProfileData.DependenceAtlasSet)
	{
		UE_LOG(LogUIAutomationProfile, Display, TEXT("Atlas:%s"), *Atlas);
	}
	for(auto Texture : TempUIProfileData.DependenceTextureSet)
	{
		UE_LOG(LogUIAutomationProfile, Display, TEXT("Texture:%s"), *Texture);
	}
	for (auto [StatName, StatValue] : TempUIProfileData.SlateStatValueArray)
	{
		UE_LOG(LogUIAutomationProfile, Display, TEXT("StatName:%s StatValue:%lf"), *StatValue.Key, StatValue.Value);
	}
	dumpUObjectsLuaAdd();
}

void UUIAutomationProfile::AddDependenceAtlas(UPaperSprite* PaperSprite)
{
#if WITH_EDITOR
	const UPaperSpriteAtlas* PaperSpriteAtlas = PaperSprite->GetAtlasGroup();
	if (PaperSpriteAtlas)
	{
		TempUIProfileData.DependenceAtlasSet.Add(PaperSpriteAtlas->GetName());
	}
#endif
}

void UUIAutomationProfile::AddDependenceTexture(UTexture* Texture)
{
	TempUIProfileData.DependenceTextureSet.Add(Texture->GetName());
}

void UUIAutomationProfile::AddDependenceAtlasName(FString AtlasName)
{
	TempUIProfileData.DependenceAtlasSet.Add(AtlasName);
}

void UUIAutomationProfile::AddDependenceTextureName(FString TextureName)
{
	TempUIProfileData.DependenceTextureSet.Add(TextureName);
}

void UUIAutomationProfile::StartCollectSlateStatData()
{
	//SlateStatDumpAverage = new FSlateStatDumpAverage(SlateStatNameArray);
}

void UUIAutomationProfile::StopCollectSlateStatData()
{
#if STATS
	// FRawStatStackNode* Stack = nullptr;
	// TArray<FStatMessage> NonStackStats;
	// SlateStatDumpAverage->CollectData(TempUIProfileData.SlateStatValueArray);
	FStatsThreadStateOverlay& Stats = static_cast<FStatsThreadStateOverlay&>(FStatsThreadState::GetLocalState());
	int64 LastGoodGameFrame = Stats.GetLastFullFrameProcessed();
	if (Stats.IsFrameValid(LastGoodGameFrame) == false)
	{
		return;
	}
	FName GroupName = FName(TEXT("STATGROUP_Slate"));
	TArray<FName> GroupItems;
	Stats.Groups.MultiFind(GroupName, GroupItems);
	TSet<FName> EnabledItems;
	for (const FName& ShortName : GroupItems)
	{
		EnabledItems.Add(ShortName);
		if (FStatMessage const* LongName = Stats.ShortNameToLongName.Find(ShortName))
		{
			EnabledItems.Add(LongName->NameAndInfo.GetRawName());
		}
	}
	FSlateGroupFilter Filter(EnabledItems);
	FRawStatStackNode HierarchyInclusive;
	TArray<FStatMessage> NonStackStats;
	Stats.UncondenseStackStats(LastGoodGameFrame, HierarchyInclusive, &Filter, &NonStackStats);
	for (auto Stat : NonStackStats)
	{
		for (auto StatName : SlateStatNameArray)
		{
			if (Stat.NameAndInfo.GetRawName().ToString().Contains(StatName))
			{
				ProcessStatValue(Stat);
			}
		}
	}
	DumpStatStackNode(&HierarchyInclusive);	
	//HierarchyInclusive.DebugPrint(TEXT("STATGROUP_Slate"));
#endif
}

#if STATS

void UUIAutomationProfile::DumpStatStackNode(FRawStatStackNode* Root)
{
	static int64 MinPrint = -1;
	if (Root && Root->Children.Num())
	{
		TArray<FRawStatStackNode*> ChildArray;
		Root->Children.GenerateValueArray(ChildArray);
		ChildArray.Sort( FStatDurationComparer<FRawStatStackNode>() );
		for (int32 Index = 0; Index < ChildArray.Num(); Index++)
		{
			if (ChildArray[Index]->Meta.GetValue_Duration() < MinPrint)
			{
				break;
			}
			for (auto StatName : SlateStatNameArray)
			{
				if (ChildArray[Index]->Meta.NameAndInfo.GetRawName().ToString().Contains(StatName))
				{
					ProcessStatValue(ChildArray[Index]->Meta);
				}
			}
			DumpStatStackNode(ChildArray[Index]);
		}
	}
}

void UUIAutomationProfile::ProcessStatValue(FStatMessage Item)
{
	const FString ShortName = Item.NameAndInfo.GetShortName().ToString();
	const FString Description = Item.NameAndInfo.GetDescription();
	switch (Item.NameAndInfo.GetField<EStatDataType>())
	{
	case EStatDataType::ST_int64:
		if (Item.NameAndInfo.GetFlag(EStatMetaFlags::IsPackedCCAndDuration))
		{
			float Duration = FPlatformTime::ToMilliseconds(FromPackedCallCountDuration_Duration(Item.GetValue_int64()));
			if (!TempUIProfileData.SlateStatValueArray.Contains(ShortName))
			{
				TempUIProfileData.SlateStatValueArray.Add(ShortName, MakeTuple(Description,Duration));
			}
		}
		else if (Item.NameAndInfo.GetFlag(EStatMetaFlags::IsCycle))
		{
			float Duration = FPlatformTime::ToMilliseconds64(Item.GetValue_int64());
			if (!TempUIProfileData.SlateStatValueArray.Contains(ShortName))
			{
				TempUIProfileData.SlateStatValueArray.Add(ShortName, MakeTuple(Description,Duration));
			}
		}
		else if (Item.NameAndInfo.GetFlag(EStatMetaFlags::IsMemory))
		{
			double Memory = (double)Item.GetValue_int64() / 1024.0 / 1024.0;
			if (!TempUIProfileData.SlateStatValueArray.Contains(ShortName))
			{
				TempUIProfileData.SlateStatValueArray.Add(ShortName, MakeTuple(Description, Memory));
			}
		}
		else
		{
			if (!TempUIProfileData.SlateStatValueArray.Contains(ShortName))
			{
				TempUIProfileData.SlateStatValueArray.Add(ShortName, MakeTuple(Description, (double)Item.GetValue_int64()));
			}
		}
		break;
	case EStatDataType::ST_double:
		if (!TempUIProfileData.SlateStatValueArray.Contains(ShortName))
		{
			TempUIProfileData.SlateStatValueArray.Add(ShortName, MakeTuple(Description, (double)Item.GetValue_int64()));
		}
		break;
	default:
		break;
	}
}

#endif

void UUIAutomationProfile::TakeSnapShot()
{
	FScreenshotRequest::RequestScreenshot(TempUIProfileData.Name.ToString(), true, false, false);
	TempUIProfileData.ScreenShotPath = FPaths::ConvertRelativePathToFull(FScreenshotRequest::GetFilename());
}

void UUIAutomationProfile::TakeSnapShotOverdraw()
{
	GEngine->Exec(GetWorld(), TEXT("slate.showviewportoverdraw 1"));
	const auto OverDrawScreenShot = TempUIProfileData.Name.ToString() + "_OverDraw";
	FScreenshotRequest::RequestScreenshot(OverDrawScreenShot, true, false, false);
	TempUIProfileData.OverdrawScreenShotPath = FPaths::ConvertRelativePathToFull(FScreenshotRequest::GetFilename());
}

void UUIAutomationProfile::GetOverDrawData()
{
	TempUIProfileData.SlateOverDrawAvg = GetWorld()->Scene->SlateOverDrawAvg;
	TempUIProfileData.SlateMaxOverDrawCount = GetWorld()->Scene->SlateMaxOverDrawCount;
}

void UUIAutomationProfile::CollapseMaterialForOverDrawCheck(UUserWidget* Widget)
{
	TObjectPtr<UWidgetTree> WBPWidgetTree = Widget->WidgetTree;
	TArray<UWidget*> Widgets;
	if (WBPWidgetTree)
	{
		WBPWidgetTree->GetAllWidgets(Widgets);
		for (int32 Index = 0; Index < Widgets.Num(); ++Index)
		{
			UWidget* CWidget = Widgets[Index];
			if (CWidget == nullptr)
			{
				continue;
			}
			if (UUserWidget* UserWidget = Cast<UUserWidget>(CWidget))
			{
				CollapseMaterialForOverDrawCheck(UserWidget);
			}

			if (UKGImage* Image = Cast<UKGImage>(CWidget))
			{
				if (Image->GetBrush().GetResourceObject() && Image->GetBrush().GetResourceObject()->IsA(UMaterialInterface::StaticClass()))
				{
					Image->SetVisibility(ESlateVisibility::Collapsed);	
				}
			}
		}
	}
	GEngine->Exec(GetWorld(), TEXT("slate.showviewportoverdraw 1"));
}

void UUIAutomationProfile::GetOverDrawDataWithOutMaterial()
{
	TempUIProfileData.SlateOverDrawWithoutMTAvg = GetWorld()->Scene->SlateOverDrawAvg;
	TempUIProfileData.SlateMaxOverDrawWithoutMTCount = GetWorld()->Scene->SlateMaxOverDrawCount;
}

void UUIAutomationProfile::GetKGMemoryStatisticsTreeAnalyserBeforeUIOpen()
{
	auto RootObject = UGameViewportSubsystem::Get(GWorld->GetWorld());
	auto Tree = FKGUMGMemorySnapshot::GenerateMemoryStatisticsTree(RootObject);
	FKGMemoryStatisticsTreeAnalyser Analyser(Tree);
	TempUIProfileData.AnalyserBeforeOpen = Analyser;
}

void UUIAutomationProfile::GetKGMemoryStatisticsTreeAnalyser(FString WbpName)
{
	auto RootObject = FindFirstObject<UObject>(*WbpName);
	auto Tree = FKGUMGMemorySnapshot::GenerateMemoryStatisticsTree(RootObject);
	FKGMemoryStatisticsTreeAnalyser Analyser(Tree);
	TempUIProfileData.Analyser = Analyser;
}

void UUIAutomationProfile::ReportError(FString Error)
{
	Error.ReplaceCharInline(TEXT(','), TEXT(' '));
	TempUIProfileData.Error = "\"" + Error + "\"";
}

void UUIAutomationProfile::ExportCSV()
{
	UIProfileDataArray.Add(TempUIProfileData);
	StatsPrimaryEnableSubtract();
	FString CSVContent;
	CSVContent += "UIName,ScreenShot,OpenTime,UObjectNum,TotalMemoryIncreaseOnOpen,TotalMemoryDecreaseOnClose,LuaMemoryIncreaseOnOpen,"
				"LuaMemoryDecreaseOnClose,UIMemoryIncreaseOnOpen,UIMemoryDecreaseOnClose,UObjectMemoryIncreaseOnOpen,UObjectMemoryDecreaseOnClose,UObjectsIncreaseRefByLua,"
				"TextureMemoryIncreaseOnOpen,TextureMemoryDecreaseOnOpen,AtlasNum,Atlas(Count;Size),TextureNum,Texture,Error,"
				"Slate RT: Rendering,Slate RT: Draw Batches,Draw Window And Children Time,Game UI Paint,Tick Widgets,SlatePrepass,Num Batches,Num Vertices,Overdraw,"
				"SlateOverDrawAvg,SlateMaxOverDrawCount,SlateOverDrawWithoutMTAvg,SlateMaxOverDrawWithoutMTCount,"
				"Font Asset Count(KGUI),Font Asset Memory/Mib(KGUI) , Font Texture Count(KGUI), Font Texture Memory/Mib(KGUI), "
				"Static Atlas Count(KGUI), Static Atlas Memory/Mib(KGUI),  Dynamic Atlas Count(KGUI), Dynamic Atlas Memory/Mib(KGUI),  Unpacked Texture Count(KGUI), Unpacked Texture Memory/Mib(KGUI)";
	CSVContent += "\n";
	UIProfileDataArray.RemoveAt(0);
	for (const FUIProfileData& Data : UIProfileDataArray)
	{
		FString CSVString;
		CSVString += Data.Name.ToString() + TEXT(","); // UIName
		CSVString += Data.ScreenShotPath + TEXT(",");  // ScreenShot
		CSVString += FString::Printf(TEXT("%f,"), Data.Time);  // OpenTime
		CSVString += FString::Printf(TEXT("%d,"), Data.Analyser.GetObjectCountForAutomationProfile());  // UObjectNum - From KG Memory Analyzer.
		CSVString += FString::Printf(TEXT("%f,"), Data.TotalTrackedMemoryOnShow - Data.TotalTrackedMemoryBefore); // TotalMemoryIncreaseOnOpen
		CSVString += FString::Printf(TEXT("%f,"), Data.TotalTrackedMemoryOnShow - Data.TotalTrackedMemoryOnClose); // TotalMemoryDecreaseOnClose
		CSVString += FString::Printf(TEXT("%f,"), Data.LuaMemoryOnShow - Data.LuaMemoryBefore); // LuaMemoryIncreaseOnOpen
		CSVString += FString::Printf(TEXT("%f,"), Data.LuaMemoryOnShow - Data.LuaMemoryOnClose); // LuaMemoryDecreaseOnClose
		CSVString += FString::Printf(TEXT("%f,"), Data.UIMemoryOnShow - Data.UIMemoryBefore);  // UIMemoryIncreaseOnOpen
		CSVString += FString::Printf(TEXT("%f,"), Data.UIMemoryOnShow - Data.UIMemoryOnClose); // UIMemoryDecreaseOnClose
		CSVString += FString::Printf(TEXT("%f,"), Data.UObjectMemoryOnShow - Data.UObjectMemoryBefore);  // UObjectMemoryIncreaseOnOpen
		CSVString += FString::Printf(TEXT("%f,"), Data.UObjectMemoryOnShow - Data.UObjectMemoryOnClose); // UObjectMemoryDecreaseOnClose
		for (auto UObject : Data.UObjectsLuaAdd)
		{
			CSVString += UObject + TEXT(";"); // UObjectsIncreaseRefByLua
		}
		CSVString += TEXT(",");
		CSVString += FString::Printf(TEXT("%f,"), Data.TextureMemoryOnShow - Data.TextureMemoryBefore); // TextureMemoryIncreaseOnOpen
		CSVString += FString::Printf(TEXT("%f,"), Data.TextureMemoryOnShow - Data.TextureMemoryOnClose); // TextureMemoryDecreaseOnOpen
		CSVString += FString::Printf(TEXT("%d,"), Data.DependenceAtlasSet.Num()); // AtlasNum
		CSVString += TEXT("\"");
		for (auto Atlas : Data.DependenceAtlasSet)
		{
			CSVString += Atlas + TEXT(";"); // Atlas(Count;Size)
		}
		CSVString += TEXT("\",");
		CSVString += FString::Printf(TEXT("%d,"), Data.DependenceTextureSet.Num()); // TextureNum
		for (auto Texture : Data.DependenceTextureSet)
		{
			CSVString += Texture + TEXT(";"); // Texture
		}
		CSVString += TEXT(",");
		CSVString += Data.Error + TEXT(","); // Error
		for (auto Title : SlateStatNameArray)
		{
			if (Data.SlateStatValueArray.Contains(Title))
			{
				CSVString += FString::Printf(TEXT("%f,"), Data.SlateStatValueArray[Title].Value); // Slate RT: Rendering,Slate RT: Draw Batches,Draw Window And Children Time,Game UI Paint,Tick Widgets,SlatePrepass,Num Batches,Num Vertices
			}
			else
			{
				CSVString += TEXT("0,");
			}
		}
		CSVString += Data.OverdrawScreenShotPath + TEXT(","); // Overdraw
		CSVString +=  FString::Printf(TEXT("%f,"), Data.SlateOverDrawAvg); // SlateOverDrawAvg
		CSVString += FString::Printf(TEXT("%f,"), Data.SlateMaxOverDrawCount); // SlateMaxOverDrawCount
		CSVString += FString::Printf(TEXT("%f,"), Data.SlateOverDrawWithoutMTAvg); // SlateOverDrawWithoutMTAvg
		CSVString += FString::Printf(TEXT("%f,"), Data.SlateMaxOverDrawWithoutMTCount); // SlateMaxOverDrawWithoutMTCount
		CSVString += FString::Printf(TEXT("%d,"),Data.Analyser.GetFontAsset().Count); // Font Asset Count(KGUI)
		CSVString += FString::Printf(TEXT("%f,"),Data.Analyser.GetFontAsset().Memory * InvToMb); // Font Asset Memory(KGUI)
		CSVString += FString::Printf(TEXT("%d,"),Data.Analyser.GetFontTexture().Count); // Font Texture Count(KGUI)
		CSVString += FString::Printf(TEXT("%f,"),Data.Analyser.GetFontTexture().Memory * InvToMb); // Font Texture Memory(KGUI)
		CSVString += FString::Printf(TEXT("%d,"), Data.Analyser.GetStaticAtlas().Count); // Static Atlas Count(KGUI)
		CSVString += FString::Printf(TEXT("%f,"),Data.Analyser.GetStaticAtlas().Memory * InvToMb); // Static Atlas Memory(KGUI)
		CSVString += FString::Printf(TEXT("%d,"), Data.Analyser.GetDynamicAtlas().Count); // Dynamic Atlas Count(KGUI)
		CSVString += FString::Printf(TEXT("%f,"),Data.Analyser.GetDynamicAtlas().Memory * InvToMb); // Dynamic Atlas Memory(KGUI)
		CSVString += FString::Printf(TEXT("%d,"), Data.Analyser.GetUnpackedTexture().Count); // Unpacked Texture Count(KGUI)
		CSVString += FString::Printf(TEXT("%f,"),Data.Analyser.GetUnpackedTexture().Memory * InvToMb); // Unpacked Texture Memory(KGUI)
		CSVContent += CSVString + TEXT("\n");
	}
	const FString FilePath = FPaths::ProjectSavedDir() / TEXT("UIProfile.csv");
	FFileHelper::SaveStringToFile(CSVContent, *FilePath);

	if (GetWorld())
	{
		if (APlayerController* PlayerController = GetWorld()->GetFirstPlayerController())
		{
			UKismetSystemLibrary::QuitGame(
				GetWorld(),
				PlayerController,
				EQuitPreference::Quit,
				true
			);
		}
	}
}

void UUIAutomationProfile::ForceGarbageCollection()
{
	GEngine->ForceGarbageCollection(true);
}

void UUIAutomationProfile::dumpUObjectsLuaBefore() {
	auto state = slua::LuaState::get();
	if (!state) return;
	auto& map = state->cacheSet();
	for (auto& it : map) {
		TempUIProfileData.UObjectsLuaBefore.Add(slua::getUObjName(it.Key));
	}
}

void UUIAutomationProfile::dumpUObjectsLuaAdd()
{
	auto state = slua::LuaState::get();
	if (!state) return;
	auto& map = state->cacheSet();
	for (auto& it : map) {
		if (!TempUIProfileData.UObjectsLuaBefore.Contains(slua::getUObjName(it.Key)))
		{
			TempUIProfileData.UObjectsLuaAdd.Add(slua::getUObjName(it.Key));
		}
	}
	for (auto& it : TempUIProfileData.UObjectsLuaAdd)
	{
		UE_LOG(LogUIAutomationProfile, Log, TEXT("Increase UObject Ref by Lua: %s"), *it);
	}
}
