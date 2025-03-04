// dump 各种开关的信息

#include "OptFunctionLibrary.h"
#include "Misc/OutputDeviceArchiveWrapper.h"
#include "Opt/OptCmdMgr.h"

static FString GetConsoleValue(IConsoleObject* ConsoleVariablePtr)
{
	FString Value("");
	if(ConsoleVariablePtr)
	{
		if(ConsoleVariablePtr->IsVariableInt())
		{
			Value = FString::FromInt(ConsoleVariablePtr->AsVariable()->GetInt());
		}
		else if(ConsoleVariablePtr->IsVariableFloat())
		{
			Value = FString::Printf(TEXT("%f"), ConsoleVariablePtr->AsVariable()->GetFloat());
		}
		else if(ConsoleVariablePtr->IsVariableBool())
		{
			Value = ConsoleVariablePtr->AsVariable()->GetBool() ? TEXT("True") : TEXT("False");
		}
		else if(ConsoleVariablePtr->IsVariableString())
		{
			Value = ConsoleVariablePtr->AsVariable()->GetString();
		}
	}
	return Value;
}

FAutoConsoleCommand C7DumpCfgAll(TEXT("c7.dumpcfg.all"), TEXT("c7.dumpcfg.all"),
	FConsoleCommandWithWorldArgsAndOutputDeviceDelegate::CreateLambda([](const TArray<FString>& Args, UWorld* InWorld, FOutputDevice& Ar)
{
		// auto IniInfo = DumpIni(GEngineIni);
		{		
			FString FilePath = FPaths::ProjectSavedDir() / FString("ConfigInfo.txt");
			TUniquePtr<FArchive> FileAr = TUniquePtr<FArchive>(IFileManager::Get().CreateFileWriter(*FilePath));
			FOutputDeviceArchiveWrapper FileArWrapper(FileAr.Get());		
			GConfig->Dump(FileArWrapper);	
		}

		{
			TArray<FString> ConsoleResults;
			IConsoleManager::Get().ForEachConsoleObjectThatStartsWith(FConsoleObjectVisitor::CreateLambda(
				[&ConsoleResults] (const TCHAR* Key, IConsoleObject* ConsoleObject)
				{
					if (!ConsoleObject || ConsoleObject->TestFlags(ECVF_Unregistered))
					{
						return;
					}
					const auto V = GetConsoleValue(ConsoleObject);
					if(!V.IsEmpty())
					{
						ConsoleResults.Add(FString::Printf(TEXT("%s=%s"), Key, *V));						
					}
				}),
				TEXT(""));
			FString FilePath = FPaths::ProjectSavedDir() / FString("ConsoleInfo.txt");
			FFileHelper::SaveStringArrayToFile(ConsoleResults, *FilePath);
		}
}));
