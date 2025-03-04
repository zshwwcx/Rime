// Add By Masou 2023.11.23 MiscCommand

#include "C7MiscCommand.h"

#include "Engine/AssetManager.h"
#include "AssetRegistry/IAssetRegistry.h"

#include "Misc/FileHelper.h"  
#include "HAL/PlatformFileManager.h"

#include "HttpManager.h"
#include "Http.h"

DEFINE_LOG_CATEGORY(LogC7MiscCommandlet)

UC7MiscCommandlet::UC7MiscCommandlet()
{
}
int32 UC7MiscCommandlet::RunCommandlet()
{
	/*GetParams*/
	for (int32 Index = 0; Index < Switches.Num(); Index++)
	{
		TArray<FString> Switch;
		Switches[Index].ParseIntoArray(Switch, TEXT("="),true);
		if (Switch.Num() > 1)
		{
			Params.FindOrAdd(Switch[0].ToUpper()) = Switch[1].TrimQuotes();
		}
		else
		{
			Params.FindOrAdd(Switch[0]) = TEXT("None");
		}		
	}
	/*RunCommandlet*/
	FString Run = GetParamAsString("Run");
	FString Command = GetParamAsString("Command");
	if (Run != TEXT("") && Command != TEXT(""))
	{
#if WITH_EDITOR
		//地图检查
		if (Command == TEXT("PakFileCheck"))
		{
			uint32 Token = 0;
			if (HasParam(TEXT("Map")))
			{
				Token |= EPakFileCheck::MAP;
			}
			return PakFileCheck(Token);
		}
		//贴图Guid定期扫描
		if (Command == TEXT("GuidTextureScan"))
		{
			if (HasParam(TEXT("branch")))
			{
				return GuidTextureScan(GetParamAsString("branch","Demo"));
			}
		}
#endif
	}
	return 1;
}

bool UC7MiscCommandlet::HasSwitch(const FString& InSwitch) const
{
	const FString* Switch = Switches.FindByPredicate([&InSwitch](const FString& InValue) {
		return InSwitch.Equals(InValue, ESearchCase::IgnoreCase);
		});

	return (Switch != nullptr);
}
bool UC7MiscCommandlet::HasParam(const FString& InParamName) const
{
	const FString* Value = Params.Find(InParamName.ToUpper());
	return (Value != nullptr);
}
FString UC7MiscCommandlet::GetParamAsString(const FString& InParamName, const FString& InDefaultValue /*= TEXT("")*/) const
{
	const FString* Value = Params.Find(InParamName.ToUpper());
	return Value ? *Value : InDefaultValue;
}
int32 UC7MiscCommandlet::GetParamAsInt(const FString& InParamName, int32 InDefaultValue /*= 0*/) const
{
	const FString* Value = Params.Find(InParamName.ToUpper());
	return Value ? FCString::Atoi(**Value) : InDefaultValue;
}
#if WITH_EDITOR
int32 UC7MiscCommandlet::PakFileCheck(uint32 Token)
{
	UE_LOG(LogC7MiscCommandlet, Display, TEXT("[C7MiscCommand|PakFileCheck] PakFileCheck Start"));
	TSharedRef<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
	if (UAssetManager* Manager = UAssetManager::GetIfInitialized())
	{
		IAssetRegistry& AssetRegistry = Manager->GetAssetRegistry();
		if (Token & EPakFileCheck::MAP)
		{
			TArray<FAssetData> AssetData;
			FARFilter Filter;
			Filter.ClassPaths.Add(UWorld::StaticClass()->GetClassPathName());
			AssetRegistry.GetAssets(Filter,AssetData);
			UAssetManager::Get().UpdateManagementDatabase(true);
			for (auto& Asset : AssetData)
			{
				TArray<int32> FoundChunks;
				UAssetManager::Get().GetPackageChunkIds(Asset.PackageName, nullptr, Asset.GetChunkIDs(), FoundChunks); 
				int32 NowChunk = -1;
				for (int32 Chunk : FoundChunks)
				{
					if (Chunk == 0)
					{
						NowChunk = Chunk;
						break;
					}
					if (NowChunk < Chunk)
					{
						NowChunk = Chunk;
					}
				}
				JsonObject->SetStringField(Asset.PackageName.ToString(), FString::FromInt(NowChunk));
			}
		}
	}

	FString ProjectDir = FPaths::ProjectDir();
	ProjectDir = FPaths::Combine(ProjectDir, "Saved", "MiscFile"); 
	if (!FPaths::DirectoryExists(ProjectDir))
	{
		UE_LOG(LogC7MiscCommandlet, Display, TEXT("[C7MiscCommand] CraeteDirectory in : %s"), *ProjectDir);
		IPlatformFile& PlatformFile = FPlatformFileManager::Get().GetPlatformFile();
		PlatformFile.CreateDirectory(*ProjectDir);
	}
	FString JsonString;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonString);
	if (FJsonSerializer::Serialize(JsonObject, Writer))
	{
		Writer->Close();
		FString JsonPath = FPaths::Combine(ProjectDir, "PakFileCheck.json");
		bool bSave = FFileHelper::SaveStringToFile(JsonString, *JsonPath);
		if(!bSave)
		{
			UE_LOG(LogC7MiscCommandlet, Display, TEXT("[C7MiscCommand|PakFileCheck] save json error!"));
			return 1;
		}
	}
	else
	{
		UE_LOG(LogC7MiscCommandlet, Display, TEXT("[C7MiscCommand|PakFileCheck] Serialize json file error!"));
		return 1;
	}
	UE_LOG(LogC7MiscCommandlet, Display, TEXT("[C7MiscCommand|PakFileCheck] success"));
	return 0;
}

/*==== GuidTextureScan ====*/

int32 UC7MiscCommandlet::GuidTextureScan(const FString Branch)
{
	UE_LOG(LogC7MiscCommandlet, Display, TEXT("[C7MiscCommand|GuidTextureScan] GuidTextureScan Start"));
	FAssetRegistryModule& AssetRegistryModule = FModuleManager::LoadModuleChecked<FAssetRegistryModule>(TEXT("AssetRegistry"));
	TArray<FString> ContentPaths;
	ContentPaths.Add(TEXT("/Game/"));

	AssetRegistryModule.Get().ScanPathsSynchronous(ContentPaths, true);

	TArray<FAssetData> Texture2DAssetDataList;
	FARFilter Filter;
	Filter.ClassPaths.Add(UTexture2D::StaticClass()->GetClassPathName());
	AssetRegistryModule.Get().GetAssets(Filter, Texture2DAssetDataList);
		
	//检查重复资源
	TMap<FGuid, FString> GuidToPathName;
	TMap<FGuid, TArray<FString>> GuidRepeatMap;
	for (auto& Texture2DAssetData : Texture2DAssetDataList)
	{
		if (UTexture2D* Texture2D = Cast<UTexture2D>(Texture2DAssetData.GetAsset()))
		{
			FGuid Guid = Texture2D->GetLightingGuid();
			FString PathName = Texture2DAssetData.GetSoftObjectPath().ToString();
			if (!GuidToPathName.Contains(Guid))
			{
				GuidToPathName.FindOrAdd(Guid) = PathName;
			}
			else
			{
				GuidRepeatMap.FindOrAdd(Guid).Add(PathName);
			}
		}	
	}
	for (auto& KeyValue : GuidRepeatMap)
	{
		auto& Guid = KeyValue.Key;
		auto& GuidRepeatSet = KeyValue.Value;
		if (GuidToPathName.Contains(Guid))
		{
			GuidRepeatSet.Add(GuidToPathName[Guid]);
		}
	}

	TSharedPtr<FJsonObject> RepeatJsonObject = MakeShareable(new FJsonObject);
	FString RepeatOutputString;
	TSharedRef<TJsonWriter<>> RepeatJsonWriter = TJsonWriterFactory<>::Create(&RepeatOutputString);

	if (GuidRepeatMap.Num() > 0)
	{
		for (auto& KeyValue : GuidRepeatMap)
		{
			auto& Guid = KeyValue.Key;
			auto& GuidRepeatSet = KeyValue.Value;
			TArray<TSharedPtr<FJsonValue>> PathList;
			for (auto& Path : GuidRepeatSet)
			{
				PathList.Add(MakeShareable(new FJsonValueString(Path)));
			}
			RepeatJsonObject->SetArrayField(Guid.ToString(), PathList);
		}
		FJsonSerializer::Serialize(RepeatJsonObject.ToSharedRef(), RepeatJsonWriter);
		IPlatformFile& PlatformFile = FPlatformFileManager::Get().GetPlatformFile();
		FString ProjectSaveCommandletPath = FPaths::Combine(FPaths::ProjectSavedDir(), TEXT("Commandlet"));
		if (!FPaths::DirectoryExists(ProjectSaveCommandletPath))
		{
			PlatformFile.CreateDirectoryTree(*ProjectSaveCommandletPath);
		}
		FString OutputJsonPath = FPaths::Combine(ProjectSaveCommandletPath, TEXT("GuidTextureScan.json"));
		FFileHelper::SaveStringToFile(RepeatOutputString, *OutputJsonPath);
	}
		
	FString ProjectName = FApp::GetProjectName();
	FString BranchName = Branch;
	FJsonSerializer::Serialize(RepeatJsonObject.ToSharedRef(), RepeatJsonWriter);

	//Clear
	TSharedPtr<FJsonObject> SubmitJsonObject = MakeShareable(new FJsonObject);
	FString OutputString;
	TSharedRef<TJsonWriter<>> JsonWriter = TJsonWriterFactory<>::Create(&OutputString);
	SubmitJsonObject->SetStringField("Project", ProjectName);
	SubmitJsonObject->SetStringField("Branch", BranchName);

	FJsonSerializer::Serialize(SubmitJsonObject.ToSharedRef(), JsonWriter);
	TSharedRef<IHttpRequest> Request = FHttpModule::Get().CreateRequest();
	Request->SetURL("https://ueguid-c7.staging.kuaishou.com/v1/guid/clear");
	Request->SetVerb("POST");
	Request->SetHeader(TEXT("accept"), TEXT("application/json"));
	Request->SetHeader(TEXT("x-access-token"), TEXT("ueguidserver"));
	Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
	Request->SetContentAsString(OutputString);

	bool bClearSuccess = false;
	Request->OnProcessRequestComplete().BindLambda([&bClearSuccess](FHttpRequestPtr InRequest, FHttpResponsePtr InResponse, bool bWasSuccessful)
	{
		if (bWasSuccessful && InResponse.IsValid() && InResponse->GetResponseCode() == 200)
		{
			bClearSuccess = true;
		}
	});
	Request->ProcessRequest();
	while (Request->GetStatus() == EHttpRequestStatus::Processing)
	{
		FPlatformProcess::Sleep(0.01);
		FHttpModule::Get().GetHttpManager().Tick(0.01);
	}
	if (bClearSuccess)
	{
		UE_LOG(LogC7MiscCommandlet, Display, TEXT("[C7MiscCommand|GuidTextureScan] clear success."));
		int32 Index = 0;
		int32 TaskNum = 30;
		int32 GroupNum = Texture2DAssetDataList.Num() / TaskNum + 1;
		int32 GroupId = 1;

		TArray<FSubmitGuidGroup> SubmitGuidGroupPackage;
		for (auto& Texture2DAssetData : Texture2DAssetDataList)
		{
			if (UTexture2D* Texture2D = Cast<UTexture2D>(Texture2DAssetData.GetAsset()))
			{
				FSubmitGuidGroup SubmitGuidGroup;
				SubmitGuidGroup.Guid = Texture2D->GetLightingGuid();
				SubmitGuidGroup.Texture2DPath = Texture2DAssetData.GetSoftObjectPath().ToString();

				SubmitGuidGroupPackage.Add(SubmitGuidGroup);
				if (SubmitGuidGroupPackage.Num() >= GroupNum)
				{
					if (!SubmitGuidGroupTask(GroupId, SubmitGuidGroupPackage, Index, ProjectName, BranchName))
					{
						return 1;
					}
					SubmitGuidGroupPackage.Empty();
					Index += GroupNum;
					GroupId += 1;
				}
			}	
		}
		if (SubmitGuidGroupPackage.Num() > 0)
		{
			if (!SubmitGuidGroupTask(GroupId, SubmitGuidGroupPackage, Index, ProjectName, BranchName))
			{
				return 1;
			}
			SubmitGuidGroupPackage.Empty();
		}
	}
	else
	{
		UE_LOG(LogC7MiscCommandlet, Display, TEXT("[C7MiscCommand|GuidTextureScan] clear failed."));
		return 1;
	}
	UE_LOG(LogC7MiscCommandlet, Display, TEXT("[C7MiscCommand|GuidTextureScan] success."));
	return 0;
}

bool UC7MiscCommandlet::SubmitGuidGroupTask(int32 GroupId, TArray<FSubmitGuidGroup> SubmitList, int32 StartIdIndex, FString ProjectName, FString BranchName)
{
	UE_LOG(LogC7MiscCommandlet, Display, TEXT("[C7MiscCommand|GuidTextureScan] Start Submit Group %d to Guid Redis."), GroupId);
	bool bAddSuccess = false;
	TSharedPtr<FJsonObject> SubmitJsonObject = MakeShareable(new FJsonObject);
	FString OutputString;
	TSharedRef<TJsonWriter<>> JsonWriter = TJsonWriterFactory<>::Create(&OutputString);
	SubmitJsonObject->SetStringField("Project", ProjectName);
	SubmitJsonObject->SetStringField("Branch", BranchName);
	int32 Index = StartIdIndex;
	TArray<TSharedPtr<FJsonValue>> SubmitDataList;
	for (auto& SubmitGroup : SubmitList)
	{
		Index += 1;
		TSharedPtr<FJsonObject> NewJsonObject = MakeShareable(new FJsonObject);
		NewJsonObject->SetStringField("guid", SubmitGroup.Guid.ToString());
		NewJsonObject->SetStringField("path", SubmitGroup.Texture2DPath);
		NewJsonObject->SetNumberField("id", Index);

		SubmitDataList.Add(MakeShareable(new FJsonValueObject(NewJsonObject)));
	}
	SubmitJsonObject->SetArrayField("Data", SubmitDataList);

	FJsonSerializer::Serialize(SubmitJsonObject.ToSharedRef(), JsonWriter);
	TSharedRef<IHttpRequest> Request = FHttpModule::Get().CreateRequest();
	Request->SetURL("https://ueguid-c7.staging.kuaishou.com/v1/guid/add");
	Request->SetVerb("POST");
	Request->SetHeader(TEXT("accept"), TEXT("application/json"));
	Request->SetHeader(TEXT("X-Access-Token"), TEXT("ueguidserver"));
	Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));

	Request->SetContentAsString(OutputString);
	Request->OnProcessRequestComplete().BindLambda([&bAddSuccess](FHttpRequestPtr InRequest, FHttpResponsePtr InResponse, bool bWasSuccessful)
		{
			if (bWasSuccessful && InResponse.IsValid() && InResponse->GetResponseCode() == 200)
			{
				bAddSuccess = true;
			}
		});
	Request->ProcessRequest();
	while (Request->GetStatus() == EHttpRequestStatus::Processing)
	{
		FPlatformProcess::Sleep(0.01);
		FHttpModule::Get().GetHttpManager().Tick(0.01);
	}
	if (bAddSuccess)
	{
		UE_LOG(LogC7MiscCommandlet, Display, TEXT("[C7MiscCommand|GuidTextureScan] Add Group %d to Guid Redis Success."), GroupId);
	}
	else
	{
		UE_LOG(LogC7MiscCommandlet, Display, TEXT("[C7MiscCommand|GuidTextureScan] Add Group %d to Guid Redis Failed."), GroupId);
	}
	return bAddSuccess;
}

/*==== GuidTextureScan ====*/
#endif

int32 UC7MiscCommandlet::Main(const FString& InCommandline)
{
	ParseCommandLine(*InCommandline,Tokens,Switches);
	return RunCommandlet();;
}