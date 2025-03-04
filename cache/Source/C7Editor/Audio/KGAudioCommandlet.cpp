// Fill out your copyright notice in the Description page of Project Settings.


#include "KGAudioCommandlet.h"

#include "AkAudioBank.h"
#include "AkAudioEvent.h"
#include "ASASkillAsset.h"
#include "StateTreeExecutionTypes.h"
#include "Animation/AnimComposite.h"
#include "AssetRegistry/AssetRegistryModule.h"

int32 UKGAudioCommandlet::Main(const FString& Params)
{
	UE_LOG(LogTemp, Log, TEXT("UKGAudioCommandlet::Main"));
	Super::Main(Params);

	// 刷一遍资产
	IAssetRegistry& AssetRegistry = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry").Get();
	AssetRegistry.SearchAllAssets(true);

	// 没有任何bank引用的event
	TArray<FString> ProblemEvents;
	ProcessEventInfo(ProblemEvents);

	// 没挂任何event的bank
	TArray<FString> ProblemBanks;
	ProcessBankInfo(ProblemBanks);
	
	ProcessSkillDependingEvent();
	
	ProcessAnimDependingEvent();

	// 写入问题告警信息
	FString ProblemLogContent;

	if (!ProblemEvents.IsEmpty())
	{
		ProblemLogContent += "AkAudioEvent\n";
		for (auto& ProblemEvent : ProblemEvents)
		{
			ProblemLogContent += ProblemEvent + "\n";
		}	
	}

	if (!ProblemBanks.IsEmpty())
	{
		ProblemLogContent += "AkAudioBank\n";
		for (auto& ProblemBank : ProblemBanks)
		{
			ProblemLogContent += ProblemBank + "\n";
		}
	}
	
	const FString& ProblemLogFileName = FPaths::Combine(FPaths::ProjectSavedDir(), TEXT("AudioResourceInfo/ProblemLog.txt"));
	FFileHelper::SaveStringToFile(ProblemLogContent, *ProblemLogFileName, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_EvenIfReadOnly);

	return 0;
}

void UKGAudioCommandlet::ProcessEventInfo(TArray<FString>& OutProblemEvents)
{
	IAssetRegistry& AssetRegistry = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry").Get();

	// event到bank的映射
	TMap<FString, FString> Event2RequiredBank;
	// event最大时长映射
	TMap<FString, float> Event2MaxDuration;
	
	// Event
	FARFilter EventFilter;
	EventFilter.PackagePaths.Add("/Game/Arts/Audio/Events");
	EventFilter.ClassPaths.Add(UAkAudioEvent::StaticClass()->GetClassPathName());
	EventFilter.bRecursivePaths = true;
	EventFilter.bRecursiveClasses = true;

	TArray<FAssetData> EventAssetDataList;
	AssetRegistry.GetAssets(EventFilter, EventAssetDataList);

	for (auto& EventAssetData : EventAssetDataList)
	{
		if (UAkAudioEvent* AkAudioEvent = Cast<UAkAudioEvent>(EventAssetData.GetAsset()))
		{
			AkAudioEvent->UpdateRequiredBanks();
			if (!AkAudioEvent->RequiredBank)
			{
				OutProblemEvents.AddUnique(AkAudioEvent->GetName());
			}
			else
			{
				Event2RequiredBank.Add(AkAudioEvent->GetName(), AkAudioEvent->RequiredBank->LoadedBankName);
				Event2MaxDuration.Add(AkAudioEvent->GetName(), AkAudioEvent->GetMaximumDuration());
			}
		}
	}
	
	// 写入映射关系文件
	FString Event2RequiredBankContent;
	for (auto& Elem : Event2RequiredBank)
	{
		Event2RequiredBankContent += FString::Printf(TEXT("%s,%s\n"), *Elem.Key, *Elem.Value);
	}
	
	const FString& Event2RequiredBankFileName = FPaths::Combine(FPaths::ProjectSavedDir(), TEXT("AudioResourceInfo/Event2RequiredBank.txt"));
	FFileHelper::SaveStringToFile(Event2RequiredBankContent, *Event2RequiredBankFileName, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_EvenIfReadOnly);

	// 写入event时长文件
	FString Event2MaxDurationContent;
	for (auto& Elem : Event2MaxDuration)
	{
		Event2MaxDurationContent += FString::Printf(TEXT("%s,%f\n"), *Elem.Key, Elem.Value);
	}
	
	const FString& Event2MaxDurationFileName = FPaths::Combine(FPaths::ProjectSavedDir(), TEXT("AudioResourceInfo/Event2MaxDuration.txt"));
	FFileHelper::SaveStringToFile(Event2MaxDurationContent, *Event2MaxDurationFileName, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_EvenIfReadOnly);
}

void UKGAudioCommandlet::ProcessBankInfo(TArray<FString>& OutProblemBanks)
{
	IAssetRegistry& AssetRegistry = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry").Get();
	
	// Bank
	FARFilter BankFilter;
	BankFilter.PackagePaths.Add("/Game/Arts/Audio/SoundBanks");
	BankFilter.ClassPaths.Add(UAkAudioBank::StaticClass()->GetClassPathName());
	BankFilter.bRecursivePaths = true;
	BankFilter.bRecursiveClasses = true;

	TArray<FAssetData> BankAssetDataList;
	AssetRegistry.GetAssets(BankFilter, BankAssetDataList);

	for (auto& BankAssetData : BankAssetDataList)
	{
		if (UAkAudioBank* AkAudioBank = Cast<UAkAudioBank>(BankAssetData.GetAsset()))
		{
			if (AkAudioBank->LinkedAkEvents.IsEmpty() && !AkAudioBank->LoadedBankName.Equals("Init"))
			{
				OutProblemBanks.AddUnique(AkAudioBank->LoadedBankName);
			}
		}
	}
}

void UKGAudioCommandlet::ProcessSkillDependingEvent()
{
	IAssetRegistry& AssetRegistry = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry").Get();
	
	// 技能资产引用关系
	TMap<FString, FString> SkillDependingEvent;
	
	FARFilter SkillFilter;
	SkillFilter.PackagePaths.Add("/Game/EditorTemplate");
	SkillFilter.ClassPaths.Add(UASAAsset::StaticClass()->GetClassPathName());
	SkillFilter.bRecursivePaths = true;
	SkillFilter.bRecursiveClasses = true;
	
	TArray<FAssetData> SkillAssetDataList;
	AssetRegistry.GetAssets(SkillFilter, SkillAssetDataList);

	for (auto& SkillAssetData : SkillAssetDataList)
	{
		TArray<FName> DependingAssetList;
		AssetRegistry.GetDependencies(SkillAssetData.PackageName, DependingAssetList);

		FString DependingEvents;
		for (auto& DependingAssetName : DependingAssetList)
		{
			if (DependingAssetName.ToString().StartsWith("/Game/Arts/Audio/Events"))
			{
				DependingEvents += FPackageName::GetLongPackageAssetName(DependingAssetName.ToString()) + TEXT(",");
			}
		}
		
		if (!DependingEvents.IsEmpty())
		{
			SkillDependingEvent.Add(SkillAssetData.AssetName.ToString(), DependingEvents);
		}
	}

	// 写入技能引用关系文件
	FString Skill2DependingEventContent = TEXT("SkillID,DependingEvents\n");
	for (auto& Elem : SkillDependingEvent)
	{
		Skill2DependingEventContent += FString::Printf(TEXT("%s,%s\n"), *Elem.Key, *Elem.Value);
	}

	const FString& Skill2DependingEventFileName = FPaths::Combine(FPaths::ProjectSavedDir(), TEXT("AudioResourceInfo/Skill2DependingEvent.csv"));
	FFileHelper::SaveStringToFile(Skill2DependingEventContent, *Skill2DependingEventFileName, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_EvenIfReadOnly);
}

void UKGAudioCommandlet::ProcessAnimDependingEvent()
{
	IAssetRegistry& AssetRegistry = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry").Get();
	
	// 动作资产引用关系
	TMap<FString, FString> AnimDependingEvent;
	
	FARFilter AnimFilter;
	AnimFilter.PackagePaths.Add("/Game/Arts");
	AnimFilter.ClassPaths.Add(UAnimSequenceBase::StaticClass()->GetClassPathName());
	AnimFilter.ClassPaths.Add(UAnimCompositeBase::StaticClass()->GetClassPathName());
	AnimFilter.bRecursivePaths = true;
	AnimFilter.bRecursiveClasses = true;
	
	TArray<FAssetData> AnimAssetDataList;
	AssetRegistry.GetAssets(AnimFilter, AnimAssetDataList);

	for (auto& AnimAssetData : AnimAssetDataList)
	{
		TArray<FName> DependingAssetList;
		AssetRegistry.GetDependencies(AnimAssetData.PackageName, DependingAssetList);

		FString DependingEvents;
		for (auto& DependingAssetName : DependingAssetList)
		{
			if (DependingAssetName.ToString().StartsWith("/Game/Arts/Audio/Events"))
			{
				DependingEvents += FPackageName::GetLongPackageAssetName(DependingAssetName.ToString()) + TEXT(",");
			}
		}

		if (!DependingEvents.IsEmpty())
		{
			AnimDependingEvent.Add(AnimAssetData.AssetName.ToString(), DependingEvents);
		}
	}

	// 写入动作引用关系文件
	FString Anim2DependingEventContent = TEXT("AnimAssetName,DependingEvents\n");
	for (auto& Elem : AnimDependingEvent)
	{
		Anim2DependingEventContent += FString::Printf(TEXT("%s,%s\n"), *Elem.Key, *Elem.Value);
	}

	const FString& Anim2DependingEventFileName = FPaths::Combine(FPaths::ProjectSavedDir(), TEXT("AudioResourceInfo/Anim2DependingEvent.csv"));
	FFileHelper::SaveStringToFile(Anim2DependingEventContent, *Anim2DependingEventFileName, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_EvenIfReadOnly);
}
