// Fill out your copyright notice in the Description page of Project Settings.


#include "UICollectCommandlet.h"
#include "Components/PanelWidget.h"
#include "Blueprint/WidgetTree.h"
#include "Misc/FileHelper.h"
#include "EditorExtenders/ToolsLibrary.h"
#include "ISourceControlOperation.h"
#include "ISourceControlModule.h"
#include "ISourceControlProvider.h"
#include "SourceControlOperations.h"
#include "Kismet/KismetSystemLibrary.h"
#include "Components/RichTextBlock.h"



DEFINE_LOG_CATEGORY(LogUICollectCommandlet);
int32 UUICollectCommandlet::Main(const FString& InCommandline)
{
	UE_LOG(LogUICollectCommandlet, Display, TEXT("UICollectCommandlet start."))

	TArray<FString> UIFiles;
	auto RootPath = FPaths::Combine(FPaths::ProjectContentDir(), TEXT("Arts/UI_2/Blueprint/"));
	IFileManager::Get().FindFilesRecursive(UIFiles, *RootPath, TEXT("*.uasset"), true, false, false);
	FString Game = FString::Printf(TEXT("/Game/"));
	TMap<FString, int32> FileNums;
	for (auto It : UIFiles)
	{
		// 替换成资源路径
		auto ResourcePath = It.Replace(*FPaths::ProjectContentDir(), *Game);
		FString name = FPaths::GetCleanFilename(It);
		FString baseName = FPaths::GetBaseFilename(ResourcePath);
		TArray<FStringFormatArg> args;
		ResourcePath.RemoveFromEnd(name);
		args.Add(ResourcePath);
		args.Add(baseName);
		auto path = FString::Format(TEXT("{0}{1}.{1}"), args);
		UWidgetBlueprint* WidgetClass = LoadObject<UWidgetBlueprint>(NULL, *path);
		if(!WidgetClass)
		{
			//UE_LOG(LogUICollectCommandlet, Warning, TEXT("Load UI Failed. UI=%s"), *path);
			continue;
		}

		
		int32 Counter = 0;
		CountUObjectNum(WidgetClass, Counter);
		//UE_LOG(LogUICollectCommandlet, Log, TEXT("Process UI=%s num=%d"), *path, Counter);
		FileNums.Emplace(path, Counter);
	}
	auto ConfigFile = FPaths::Combine(FPaths::ProjectContentDir(), TEXT("Script/Data/Config/UI/WBPConfig.lua"));
	bool Changed = false;
	if(FPaths::FileExists(ConfigFile))
	{
		TArray<FString> Lines;
		FFileHelper::LoadFileToStringArray(Lines, *ConfigFile);
		auto OldCnt = Lines.Num() - 3;
		if(FileNums.Num() == OldCnt)
		{
			for (int i = 1; i < Lines.Num() - 2; i++)
			{
				FString Line = Lines[i];
				TArray<FString> Arr;
				Line.ParseIntoArray(Arr, TEXT("="), true);
				int32* Ptr = FileNums.Find(Arr[0]);
				if(Ptr == nullptr || *Ptr != FCString::Atoi(*Arr[1]))
				{
					Changed = true;
					break;
				}
			}
		}
		else
		{
			Changed = true;
		}
	}
	if(Changed)
	{
		TArray<FString> Lines;
		Lines.Emplace(TEXT("local WBPConfig = {"));
		for(auto& It:FileNums)
		{	
			Lines.Emplace(FString::Printf(TEXT("['%s'] = % d,"), *It.Key, It.Value));
		}
		Lines.Emplace(TEXT("}"));
		Lines.Emplace(TEXT("return WBPConfig"));

		bool saveStatus = FFileHelper::SaveStringToFile(FString::Join(Lines, TEXT("\n")), *ConfigFile, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM);
		if (!saveStatus)
		{
			UE_LOG(LogUICollectCommandlet, Warning, TEXT("SaveStringToFile %s error"), *ConfigFile);
			return 0;
		}

		//ISourceControlProvider& SourceControlProvider = ISourceControlModule::Get().GetProvider();
		//FSourceControlStatePtr SourceControlState = SourceControlProvider.GetState(ConfigFile, EStateCacheUsage::ForceUpdate);
		//if (SourceControlState.IsValid())
		//{
		//	FToolsLibrary::CheckoutFile(ConfigFile, true, false);
		//	bool saveStatus = FFileHelper::SaveStringToFile(FString::Join(Lines, TEXT("\n")), *ConfigFile, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM);
		//	if (!saveStatus)
		//	{
		//		UE_LOG(LogUICollectCommandlet, Warning, TEXT("SaveStringToFile %s error"), *ConfigFile);
		//		return 0;
		//	}
		//	auto Operation = ISourceControlOperation::Create<FCheckIn>();
		//	Operation->SetDescription(FText::FromString(TEXT("[BuildMachine] Update UI wbpconfig for Teamcity BuildMachine #10000 TeamCity Task")));
		//	if(SourceControlProvider.Execute(Operation, *ConfigFile) == ECommandResult::Succeeded)
		//	{
		//		//UE_LOG(LogUICollectCommandlet, Display, TEXT("[REPORT] %s Submit successfully"), *ConfigFile);
		//	}
		//	else
		//	{
		//		UE_LOG(LogUICollectCommandlet, Warning, TEXT("[REPORT] %s Submit failed!"), *ConfigFile);
		//	}
		//}
	}
	return 0;
}

void UUICollectCommandlet::CountUObjectNum(UWidgetBlueprint* WidgetBlueprint, int32& Counter)
{
	TArray<UWidget*> Widgets;
	WidgetBlueprint->WidgetTree->GetAllWidgets(Widgets);
	Counter += Widgets.Num() + 2;
	for (int32 i = 0; i < Widgets.Num(); ++i)
	{
		UWidget* Widget = Widgets[i];
		UClass* WidgetsClass = Widget->GetClass();
		if (!WidgetsClass) {
			return;
		}
		if (Widget->IsA<UUserWidget>())
		{
			if (UUserWidget* NewUserWidget = Cast<UUserWidget>(Widget))
			{
				FString WidgetsClassPath = UKismetSystemLibrary::GetPathName(WidgetsClass);
				WidgetsClassPath.RemoveFromEnd("_C");
				UWidgetBlueprint* WidgetObject = LoadObject<UWidgetBlueprint>(NULL, *WidgetsClassPath);
				CountUObjectNum(WidgetObject, Counter);
			}
		}
		else if(Widget->IsA<UPanelWidget>())
		{
			if (UPanelWidget* PanelWidget = Cast<UPanelWidget>(Widget))
			{
				Counter += PanelWidget->GetSlots().Num();
			}
		}
		if (URichTextBlock* RichTextBlock = Cast<URichTextBlock>(Widgets[i]))
		{
			Counter += 3;
		}
	}
}
