#include "AssetManager/C7PrimaryAssetLabel.h"
#include "AssetManager/C7AssetManager.h"
#include "AssetRegistry/IAssetRegistry.h"
#include "Engine/AssetManager.h"

#if WITH_EDITOR
#include "Settings/ProjectPackagingSettings.h"
#include "JsonUtilities.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#endif

#include "Misc/ConfigCacheIni.h"
#include "Internationalization/Regex.h"

const FName UC7PrimaryAssetLabel::TableAndLuaReferencedBundle = FName("TableAndLuaReferenced");
const FName UC7PrimaryAssetLabel::AlwaysCookBundle = FName("AlwaysCook");
const FName UC7PrimaryAssetLabel::CompositionLevelBundle = FName("CompositionLevel");
const FName UC7PrimaryAssetLabel::ExplicitDirectoryBundle = FName("ExplicitDirectory");
const FName UC7PrimaryAssetLabel::ExplicitAssetBundle = FName("Explicit");

UC7PrimaryAssetLabel::UC7PrimaryAssetLabel()
{
	bLabelAssetsReferencedInTableAndLua = false;
	bLabelAlwaysCookDirectories = false;
	bLableWorldCompositionLevel = false;
}

#if WITH_EDITOR

// Blueprint
void UC7PrimaryAssetLabel::CheckUpdateAssetBundleData()
{
	UpdateAssetBundleData();
}

#endif

#if WITH_EDITORONLY_DATA

void UC7PrimaryAssetLabel::Lua()
{
	if (UAssetManager* Manager = UAssetManager::GetIfInitialized())
	{
		if (UC7AssetManager* AssetManager = Cast<UC7AssetManager>(Manager))
		{
			TArray<FName> Packages;
			AssetManager->GetLuaReferencedAssets(Packages, ChunkName);
			IAssetRegistry& AssetRegistry = AssetManager->GetAssetRegistry();
			TArray<FTopLevelAssetPath> NewPaths;
			for (const FName Package : Packages)
			{
				const FString PackagePath = FPaths::SetExtension(Package.ToString(), TEXT(""));
				TArray<FAssetData> Assets;
				AssetRegistry.GetAssetsByPackageName(*PackagePath, Assets, true);
				for (const FAssetData& AssetData : Assets)
				{
					NewPaths.Add(FTopLevelAssetPath(AssetData.PackageName, AssetData.AssetName));
				}
			}
			AssetBundleData.SetBundleAssets(TableAndLuaReferencedBundle, MoveTemp(NewPaths));
		}
	}
}
void UC7PrimaryAssetLabel::AlwaysCook()
{
	if (UAssetManager* Manager = UAssetManager::GetIfInitialized())
	{
		TArray<FTopLevelAssetPath> NewPaths;

		FConfigFile GameConfig;
		FConfigCacheIni::LoadLocalIniFile(GameConfig, TEXT("Game"), true);

		FString CurrentChangelist;
		TArray<FString> CookFilePaths;
		GameConfig.GetArray(TEXT("/Script/UnrealEd.ProjectPackagingSettings"), TEXT("DirectoriesToAlwaysCook"), CookFilePaths);

		for (int i = 0; i < CookFilePaths.Num(); ++i)
		{
			TArray<FAssetData> DirectoryAssets;
			FString CookPath = CookFilePaths[i].Right(CookFilePaths[i].Len() - 7);
			CookPath = CookPath.Left(CookPath.Len() - 2);
			Manager->GetAssetRegistry().GetAssetsByPath(*CookPath, DirectoryAssets, true, true);
			for (const FAssetData& AssetData : DirectoryAssets)
			{
				NewPaths.Add(FTopLevelAssetPath(AssetData.PackageName, AssetData.AssetName));
			}
		}
		AssetBundleData.SetBundleAssets(AlwaysCookBundle, MoveTemp(NewPaths));
	}
}

void UC7PrimaryAssetLabel::Update()
{
	if (UAssetManager* Manager = UAssetManager::GetIfInitialized())
	{
		if (bLabelAssetsReferencedInTableAndLua)
		{
			if (UC7AssetManager* AssetManager = Cast<UC7AssetManager>(Manager))
			{
				TArray<FName> Packages;
				AssetManager->GetLuaReferencedAssets(Packages, ChunkName);
				IAssetRegistry& AssetRegistry = AssetManager->GetAssetRegistry();
				TArray<FTopLevelAssetPath> NewPaths;
				for (const FName Package : Packages)
				{
					const FString PackagePath = FPaths::SetExtension(Package.ToString(), TEXT(""));
					TArray<FAssetData> Assets;
					AssetRegistry.GetAssetsByPackageName(*PackagePath, Assets, true);
					for (const FAssetData& AssetData : Assets)
					{
						NewPaths.Add(FTopLevelAssetPath(AssetData.PackageName, AssetData.AssetName));
					}
				}
				AssetBundleData.SetBundleAssets(TableAndLuaReferencedBundle, MoveTemp(NewPaths));
			}
		}

		if (bLabelAlwaysCookDirectories)
		{
			TArray<FTopLevelAssetPath> NewPaths;

			FConfigFile GameConfig;
			FConfigCacheIni::LoadLocalIniFile(GameConfig, TEXT("Game"), true);

			FString CurrentChangelist;
			TArray<FString> CookFilePaths;
			GameConfig.GetArray(TEXT("/Script/UnrealEd.ProjectPackagingSettings"), TEXT("DirectoriesToAlwaysCook"), CookFilePaths);

			for (int i = 0; i < CookFilePaths.Num(); ++i)
			{
				TArray<FAssetData> DirectoryAssets;
				FString CookPath = CookFilePaths[i].Mid(CookFilePaths[i].Len() - 7);
				CookPath = CookPath.Left(CookPath.Len() - 2);
				Manager->GetAssetRegistry().GetAssetsByPath(*CookPath, DirectoryAssets, true, true);
				for (const FAssetData& AssetData : DirectoryAssets)
				{
					NewPaths.Add(FTopLevelAssetPath(AssetData.PackageName, AssetData.AssetName));
				}
			}
			AssetBundleData.SetBundleAssets(AlwaysCookBundle, MoveTemp(NewPaths));
		}

		if (bLableWorldCompositionLevel)
		{
			for (TSoftObjectPtr<UObject> Asset : ExplicitAssets)
			{
				const FString PackageName = Asset.GetLongPackageName();
				FName PackagePath;
				TArray<FAssetData> AssetDatas;
				Manager->GetAssetRegistry().GetAssetsByPackageName(*PackageName, AssetDatas, true);
				for (const FAssetData& AssetData : AssetDatas)
				{
					if (AssetData.AssetClassPath.GetAssetName() == "World" || AssetData.AssetClassPath.GetAssetName() == "Level")
					{
						PackagePath = AssetData.PackagePath;
						break;
					}
				}

				if (PackagePath == NAME_None)
				{
					continue;
				}

				TArray<FAssetData> DirectoryAssets;
				Manager->GetAssetRegistry().GetAssetsByPath(PackagePath, DirectoryAssets, true, true);
				TArray<FTopLevelAssetPath> NewPaths;
				for (const FAssetData& AssetData : DirectoryAssets)
				{
					if (AssetData.AssetClassPath.GetAssetName() == "World" || AssetData.AssetClassPath.GetAssetName() == "Level")
					{
						NewPaths.Add(FTopLevelAssetPath(AssetData.PackageName, AssetData.AssetName));
					}
				}
				AssetBundleData.SetBundleAssets(CompositionLevelBundle, MoveTemp(NewPaths));
			}

			for (const FSoftObjectPath& Asset : C7ExplicitAssets)
			{
				const FString PackageName = Asset.GetLongPackageName();
				FName PackagePath;
				TArray<FAssetData> AssetDatas;
				Manager->GetAssetRegistry().GetAssetsByPackageName(*PackageName, AssetDatas, true);
				for (const FAssetData& AssetData : AssetDatas)
				{
					if (AssetData.AssetClassPath.GetAssetName() == "World" || AssetData.AssetClassPath.GetAssetName() == "Level")
					{
						PackagePath = AssetData.PackagePath;
						break;
					}
				}

				if (PackagePath == NAME_None)
				{
					continue;
				}

				TArray<FAssetData> DirectoryAssets;
				Manager->GetAssetRegistry().GetAssetsByPath(PackagePath, DirectoryAssets, true, true);
				TArray<FTopLevelAssetPath> NewPaths;
				for (const FAssetData& AssetData : DirectoryAssets)
				{
					if (AssetData.AssetClassPath.GetAssetName() == "World" || AssetData.AssetClassPath.GetAssetName() == "Level")
					{
						NewPaths.Add(FTopLevelAssetPath(AssetData.PackageName, AssetData.AssetName));
					}
				}
				AssetBundleData.SetBundleAssets(CompositionLevelBundle, MoveTemp(NewPaths));
			}
		}
	}
}
void UC7PrimaryAssetLabel::UpdateAssetBundleData()
{
	bool bSuccess = false;
	if (ConfigFrom == EConfigFrom::JSON)
	{
		bSuccess = UpdateByJson();
	}
	if (!bSuccess)
	{
		UE_LOG(LogTemp, Display, TEXT("ChunkName = %s, read setting by ChunkLabel."), *ChunkName);
		Super::UpdateAssetBundleData();
		Update();
		if (UAssetManager* Manager = UAssetManager::GetIfInitialized())
		{
			TArray<FTopLevelAssetPath> NewPaths;
			for (const FDirectoryPath& Directory : ExplicitDirectories)
			{
				TArray<FAssetData> DirectoryAssets;
				Manager->GetAssetRegistry().GetAssetsByPath(*Directory.Path, DirectoryAssets, true, true);
				for (const FAssetData& AssetData : DirectoryAssets)
				{
					NewPaths.Add(FTopLevelAssetPath(AssetData.PackageName, AssetData.AssetName));
				}
			}
			if (NewPaths.Num() > 0)
			{
				AssetBundleData.SetBundleAssets(ExplicitDirectoryBundle, MoveTemp(NewPaths));
			}
		}

		if (C7ExplicitAssets.Num() > 0)
		{
			TArray<FTopLevelAssetPath> NewPaths;
			for (auto& C7ExplicitAsset : C7ExplicitAssets)
			{
				NewPaths.Add(C7ExplicitAsset.GetAssetPath());
			}
			AssetBundleData.SetBundleAssets(ExplicitAssetBundle, MoveTemp(NewPaths));
		}
	}
}

void UC7PrimaryAssetLabel::CollectAssetPaths(const FString& InAssetPath, TArray<FTopLevelAssetPath>& OutPaths)
{
	FSoftObjectPath SOP(InAssetPath);

	//map path format: /Game/A/B
	// the other asset format is : /Game/A/B.B

	int32 idx = -1;
	if (InAssetPath.FindChar('.', idx) == false)
	{
		FString PackageName = FPackageName::GetShortName(InAssetPath);
		FString FullPathName = InAssetPath + FString(TEXT(".")) + PackageName;
		SOP = FSoftObjectPath(FullPathName);
	}

	FTopLevelAssetPath TLAP = SOP.GetAssetPath();
	OutPaths.Add(TLAP);
}

void UC7PrimaryAssetLabel::AddAsset(TArray<TSharedPtr<FJsonValue>> Assetes, TArray<FTopLevelAssetPath>& NewAssetPaths)
{
	TSet<FString> AssetList;
	for (auto& Asset : Assetes)
	{
		FString OutString = TEXT("");
		if (Asset->TryGetString(OutString))
		{
			AssetList.Add(OutString);
		}
	}
			
	for (const FString& Asset : AssetList)
	{
		CollectAssetPaths(Asset, NewAssetPaths);
	}
}

void UC7PrimaryAssetLabel::AddDirectory(TArray<TSharedPtr<FJsonValue>> Directories,TArray<FTopLevelAssetPath>& NewDirectoryPaths)
{
	TSet<FString> DirectoryList;
	for (auto& Directory : Directories)
	{
		FString OutString = TEXT("");
		if (Directory->TryGetString(OutString))
		{
			DirectoryList.Add(OutString);
		}
	}
			
	if (UAssetManager* Manager = UAssetManager::GetIfInitialized())
	{
		for (const FString& Directory : DirectoryList)
		{
			TArray<FAssetData> DirectoryAssets;
			Manager->GetAssetRegistry().GetAssetsByPath(*Directory, DirectoryAssets, true, true);
			for (const FAssetData& AssetData : DirectoryAssets)
			{
				NewDirectoryPaths.Add(FTopLevelAssetPath(AssetData.PackageName, AssetData.AssetName));
			}
		}
	}
}

bool UC7PrimaryAssetLabel::UpdateByJson()
{
	FString JsonConfigPath = FPaths::SourceConfigDir() / JSON_CONFIG;
	if (!FPaths::FileExists(JsonConfigPath))
	{
		return false;
	}

	
	FString JsonString;
	if (!FFileHelper::LoadFileToString(JsonString, *JsonConfigPath))
	{
		return false;
	}
	TSharedPtr<FJsonObject> JsonObject;
	TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonString);
	if (!FJsonSerializer::Deserialize(Reader, JsonObject) || !JsonObject.IsValid())
	{
		return false;
	}   

	Super::UpdateAssetBundleData();
	AssetBundleData.Reset();

	const FString Section = ChunkName;
	if(JsonObject->HasField(Section))
	{
		TSharedPtr<FJsonObject> ChunkObject = JsonObject->GetObjectField(Section);
		if (ChunkObject.IsValid())
		{
#if WITH_EDITOR
			UE_LOG(LogTemp, Display, TEXT("ChunkName = %s, read setting by JSON."), *ChunkName);
#endif
			AssetBundleData.Reset();

			TArray<TSharedPtr<FJsonValue>> BaseAssetes = ChunkObject->GetArrayField(TEXT("Asset"));
			TArray<TSharedPtr<FJsonValue>> BaseDirectories = ChunkObject->GetArrayField(TEXT("Directory"));
			TArray<TSharedPtr<FJsonValue>> Builds = ChunkObject->GetArrayField(TEXT("Build"));


			TArray<FTopLevelAssetPath> NewAssetPaths;
			TArray<FTopLevelAssetPath> NewDirectoryPaths;
		
			AddAsset(BaseAssetes, NewAssetPaths);
			AddDirectory(BaseDirectories, NewDirectoryPaths);

			// BEGIN MODIFY BY wangwenfeng05@kuaishou.com : Cook Filter Platform Assets  
			FString Platform = FPlatformProperties::PlatformName();
			if(Platform == "WindowsEditor")
			{
				Platform = "Windows";
			}


			// BEGIN MODIFY BY  guoyi06@kuaishou.com : Update by guoyi06@kuaishou.com 目前获取的平台有问题，比如windows平台 cook了 Android_ASTC ,目前获取的机制有问题，或得到固定的windows ，从而造成问题
			FString TargetPlatForm = Platform;
			FString CookPlatformName;
			if (FParse::Value(FCommandLine::Get(), TEXT("TargetPlatform="), CookPlatformName))
			{
				UE_LOG(LogTemp, Display, TEXT("[UC7PrimaryAssetLabel::UpdateByJson] Current cook platform: %s"), *CookPlatformName);
				TargetPlatForm = CookPlatformName;

				//注意: 目前Android在cook的时候，引擎会加上 Android_ASTC等拼接情况，需要去掉_前的platform名称
				if (CookPlatformName.Contains(TEXT("_")))
				{
					TargetPlatForm = CookPlatformName.Left(CookPlatformName.Find(TEXT("_")));
					UE_LOG(LogTemp, Display, TEXT("[UC7PrimaryAssetLabel::UpdateByJson]   Convert  oriPlatformName : %s to  tarPlatFormName:  %s "), *CookPlatformName, *TargetPlatForm);
				}
			}
			else
			{
				UE_LOG(LogTemp, Display, TEXT("[UC7PrimaryAssetLabel::UpdateByJson] No TargetPlatform specified in command line"));
			}




			UE_LOG(LogTemp, Display, TEXT("CookPlatform=%s"), *TargetPlatForm);
			if(ChunkObject->HasField(TargetPlatForm))
			{
				TSharedPtr<FJsonObject> PlatformObject = ChunkObject->GetObjectField(TargetPlatForm);
				TArray<TSharedPtr<FJsonValue>> PlatformAssetes = PlatformObject->GetArrayField(TEXT("Asset"));
				TArray<TSharedPtr<FJsonValue>> PlatformDirectories = PlatformObject->GetArrayField(TEXT("Directory"));
				AddAsset(PlatformAssetes, NewAssetPaths);
				AddDirectory(PlatformDirectories, NewDirectoryPaths);
			}			

			TSet<FString> BuildTag;
			for (auto& Build : Builds)
			{
				FString OutString = TEXT("");
				if (Build->TryGetString(OutString))
				{
					BuildTag.Add(OutString);
				}
			}
			AssetBundleData.SetBundleAssets(ExplicitAssetBundle, MoveTemp(NewAssetPaths));
			AssetBundleData.SetBundleAssets(ExplicitDirectoryBundle, MoveTemp(NewDirectoryPaths));

			//BuildTag
			if (BuildTag.Contains(TEXT("lua")))
			{
				Lua();
			}

			if (BuildTag.Contains(TEXT("alwayscook")))
			{
				AlwaysCook(); 
			}
		}
	}
	else
	{
		return false;
	}
	return true;
}



#endif
