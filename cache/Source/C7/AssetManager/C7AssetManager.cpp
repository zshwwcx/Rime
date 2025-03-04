#include "AssetManager/C7AssetManager.h"
#include "AssetRegistry/IAssetRegistry.h"
#include "Engine/AssetManagerSettings.h"
#include "Engine/StreamableManager.h"
#include "HAL/CriticalSection.h"
#include "HAL/PlatformFile.h"
#include "Misc/CommandLine.h"
#include "Misc/FileHelper.h"
#include "Misc/PackageName.h"
#include "Misc/Paths.h"
#include "Misc/RedirectCollector.h"
#include "UObject/Package.h"
#include "UObject/SoftObjectPath.h"
#include "AssetManager/C7PrimaryAssetLabel.h"
#include "Misc/PathViews.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"

DEFINE_LOG_CATEGORY_STATIC(LogC7AssetManager, Log, All);

const FPrimaryAssetType UC7AssetManager::C7PrimaryAssetLabelType = FName(TEXT("C7PrimaryAssetLabel"));

#if WITH_EDITOR
class FRedirectCollectorPublicBreaker
{
public:
	struct FSoftObjectPathProperty
	{
		FSoftObjectPathProperty(FName InAssetPathName, FName InProperty, bool bInReferencedByEditorOnlyProperty)
			: AssetPathName(InAssetPathName)
			, PropertyName(InProperty)
			, bReferencedByEditorOnlyProperty(bInReferencedByEditorOnlyProperty)
		{}

		bool operator==(const FSoftObjectPathProperty& Other) const
		{
			return AssetPathName == Other.AssetPathName &&
				PropertyName == Other.PropertyName &&
				bReferencedByEditorOnlyProperty == Other.bReferencedByEditorOnlyProperty;
		}

		friend inline uint32 GetTypeHash(const FSoftObjectPathProperty& Key)
		{
			uint32 Hash = 0;
			Hash = HashCombine(Hash, GetTypeHash(Key.AssetPathName));
			Hash = HashCombine(Hash, GetTypeHash(Key.PropertyName));
			Hash = HashCombine(Hash, (uint32)Key.bReferencedByEditorOnlyProperty);
			return Hash;
		}

		const FName& GetAssetPathName() const
		{
			return AssetPathName;
		}

		const FName& GetPropertyName() const
		{
			return PropertyName;
		}

		bool GetReferencedByEditorOnlyProperty() const
		{
			return bReferencedByEditorOnlyProperty;
		}

	public:
		FName AssetPathName;
		FName PropertyName;
		bool bReferencedByEditorOnlyProperty;
	};

	typedef TSet<FSoftObjectPathProperty> FSoftObjectPathPropertySet;
	typedef TMap<FName, FSoftObjectPathPropertySet> FSoftObjectPathMap;
	FSoftObjectPathMap SoftObjectPathMap;
	TMap<FName, FName> AssetPathRedirectionMap;
	FCriticalSection CriticalSection;
};
#endif

UC7AssetManager::UC7AssetManager()
{
}

void UC7AssetManager::FinishInitialLoading()
{
	Super::FinishInitialLoading();

#if WITH_EDITOR
	StartupSoftPackages.Empty();
	StartupPackages.Empty();

	//FRedirectCollectorPublicBreaker* SoftPathCollector = (FRedirectCollectorPublicBreaker*)(&GRedirectCollector);
	//if (SoftPathCollector)
	//{
	//	for (const FRedirectCollectorPublicBreaker::FSoftObjectPathMap::ElementType& Pair : SoftPathCollector->SoftObjectPathMap)
	//	{
	//		for (const FRedirectCollectorPublicBreaker::FSoftObjectPathProperty& SoftObjectPathProperty : Pair.Value)
	//		{
	//			if (SoftObjectPathProperty.bReferencedByEditorOnlyProperty)
	//			{
	//				continue;
	//			}

	//			if (SoftObjectPathProperty.AssetPathName == NAME_NONE || !SoftObjectPathProperty.AssetPathName.IsValid() || !SoftObjectPathProperty.AssetPathName.GetComparisonIndex())
	//			{
	//				continue;
	//			}

	//			const FString AssetPathName = SoftObjectPathProperty.AssetPathName.ToString();
	//			if (AssetPathName.StartsWith(TEXT("/Engine")) || AssetPathName.StartsWith(TEXT("/Script")))
	//			{
	//				continue;
	//			}

	//			StartupSoftPackages.Add(*FPaths::SetExtension(AssetPathName, TEXT("")), SoftObjectPathProperty.AssetPathName);
	//		}
	//	}
	//}

	int32 EnginePackage = 0;
	int32 ScriptPackage = 0;
	int32 PluginPackage = 0;
	int32 GamePackage = 0;
	for (TObjectIterator<UPackage> It; It; ++It)
	{
		if ((*It) != GetTransientPackage())
		{
			StartupPackages.Add(It->GetFName(), true);

			const FString PackageName = It->GetFName().ToString();
			if (PackageName.StartsWith(TEXT("/Engine")))
			{
				++EnginePackage;
			}
			else if (PackageName.StartsWith(TEXT("/Script")))
			{
				++ScriptPackage;
			}
			else if (PackageName.StartsWith(TEXT("/Game")))
			{
				++GamePackage;
			}
			else
			{
				++PluginPackage;
			}
		}
	}

	UE_LOG(LogC7AssetManager, Display, TEXT("Startup packages count: %d(Engine: %d, Script: %d, Plugin: %d, Game: %d), soft referencd package count: %d."), StartupPackages.Num(), EnginePackage, ScriptPackage, PluginPackage, GamePackage, StartupSoftPackages.Num());
#endif
}

#if WITH_EDITOR
void UC7AssetManager::ApplyPrimaryAssetLabels()
{
	Super::ApplyPrimaryAssetLabels();

	FSoftObjectPathSerializationScope SerializationScope(NAME_None, NAME_None, ESoftObjectPathCollectType::NeverCollect, ESoftObjectPathSerializeType::AlwaysSerialize);
	TSharedPtr<FStreamableHandle> Handle = LoadPrimaryAssetsWithType(C7PrimaryAssetLabelType);
	if (Handle.IsValid())
	{
		Handle->WaitUntilComplete();
	}

	ChunkNameMap.Empty();
	TArray<FAssetData> C7PrimaryAssetDatas;
	GetPrimaryAssetDataList(C7PrimaryAssetLabelType, C7PrimaryAssetDatas);
	for (const FAssetData& Data : C7PrimaryAssetDatas)
	{
		if (UC7PrimaryAssetLabel* Label = Cast<UC7PrimaryAssetLabel>(Data.FastGetAsset(true)))
		{
			if (Label->bIsCoreChunk)
			{
				CoreChunkId = Label->Rules.ChunkId;
			}

			if (Label->bIsBaseChunk)
			{
				BaseChunkId = Label->Rules.ChunkId;
			}

			if (!Label->ChunkName.IsEmpty())
			{
				ChunkNameMap.Add(Label->Rules.ChunkId, Label->ChunkName);
			}
		}
	}
}

void UC7AssetManager::ScanPrimaryAssetRulesFromConfig()
{
	const UAssetManagerSettings& Settings = GetSettings();
	for (const FPrimaryAssetRulesOverride& Override : Settings.PrimaryAssetRules)
	{
		if (Override.PrimaryAssetId.PrimaryAssetType == PrimaryAssetLabelType || Override.PrimaryAssetId.PrimaryAssetType == C7PrimaryAssetLabelType)
		{
			continue;
		}
		SetPrimaryAssetRules(Override.PrimaryAssetId, Override.Rules);
	}

	for (const FPrimaryAssetRulesCustomOverride& Override : Settings.CustomPrimaryAssetRules)
	{
		ApplyCustomPrimaryAssetRulesOverride(Override);
	}
}

bool UC7AssetManager::GetPackageChunkIds(FName PackageName, const class ITargetPlatform* TargetPlatform, TArrayView<const int32> ExistingChunkList, TArray<int32>& OutChunkList, TArray<int32>* OutOverrideChunkList /*= nullptr*/) const
{
	const bool bResult = Super::GetPackageChunkIds(PackageName, TargetPlatform, ExistingChunkList, OutChunkList, OutOverrideChunkList);

	if (IsMapPackage(PackageName))
	{
		return bResult;
	}

	const FString OldChunkList = FString::JoinBy(OutChunkList, TEXT(", "), [](int32 Id) { return FString::Printf(TEXT("%d"), Id); });
	if (IsStartupPackage(PackageName) && !OutChunkList.Contains(CoreChunkId))
	{
		OutChunkList.Empty();
		OutChunkList.Add(CoreChunkId);
	}
	else if (IsSoftReferencedByStartupPackage(PackageName) && !OutChunkList.Contains(CoreChunkId))
	{
		OutChunkList.Empty();
		OutChunkList.Add(CoreChunkId);
	}
	else
	{
		if (OutChunkList.Num() > 1)
		{
			if (OutChunkList.Contains(BaseChunkId))
			{
				OutChunkList.Empty();
				OutChunkList.Add(BaseChunkId);
			}
			else
			{

				OutChunkList.Sort();

				int32 FinalSharedChunk = -1;
				int32 FinalChunk = 0;
				for(auto& OutChunk : OutChunkList)
				{
					int32 SharedChunk = int(OutChunk / 1000) * 1000;
					FinalChunk = OutChunk;
					if(FinalSharedChunk != SharedChunk)
					{
						FinalSharedChunk = SharedChunk;
					}
					else
					{
						FinalChunk = FinalSharedChunk;
					}
				}
				OutChunkList.Empty();
				OutChunkList.Add(FinalChunk);
			}
		}
	}

	return bResult;
}

void UC7AssetManager::ModifyCook(TConstArrayView<const ITargetPlatform*> TargetPlatforms, TArray<FName>& PackagesToCook, TArray<FName>& PackagesToNeverCook)
{
	Super::ModifyCook(TargetPlatforms, PackagesToCook, PackagesToNeverCook);

	GetLuaReferencedAssets(PackagesToCook);
}

FString UC7AssetManager::OverrideChunkName(int32 PakchunkIndex, int32 SubChunkIndex) const
{
	if (const FString* ChunkName = ChunkNameMap.Find(PakchunkIndex))
	{
		return (SubChunkIndex > 0) ? FString::Printf(TEXT("%s_s%d"), **ChunkName, SubChunkIndex) : *ChunkName;
	}
	else
	{
		return TEXT("");
	}
}

void UC7AssetManager::GetLuaReferencedAssets(TArray<FName>& OutReferencedAssets,FString ChunkName)
{
	IPlatformFile& PhysicalPlatformFile = IPlatformFile::GetPlatformPhysical();
	TArray<FString> Assets;
	const FString LuaReferencedAssetListFile = FPaths::RootDir() / TEXT("Client") / TEXT("Config") /  TEXT("Pak") / TEXT("LuaAssetList.json");
	if (PhysicalPlatformFile.FileExists(*LuaReferencedAssetListFile))
	{
		TArray<FString> LuaAssets;

		FString JsonString;
		if (FFileHelper::LoadFileToString(JsonString, *LuaReferencedAssetListFile))
		{
			TSharedPtr<FJsonObject> JsonObject;
			TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonString);
			if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
			{
				if (ChunkName == TEXT("None"))
				{
					for (auto& Pair : JsonObject->Values)
					{
						TArray<TSharedPtr<FJsonValue>> PakChunkAssetObjectArray = JsonObject->GetArrayField(Pair.Key);
						for (auto& PakChunkAssetObject : PakChunkAssetObjectArray)
						{
							LuaAssets.Add(PakChunkAssetObject->AsString()); 
						}
					}
				}
				else
				{
					if (JsonObject->HasField(ChunkName))
					{
						TArray<TSharedPtr<FJsonValue>> PakChunkAssetObjectArray = JsonObject->GetArrayField(ChunkName);
						for (auto& PakChunkAssetObject : PakChunkAssetObjectArray)
						{
							LuaAssets.Add(PakChunkAssetObject->AsString());
						}
					}
				}
			}
		}

		Assets += LuaAssets;
	}
	else
	{
		UE_LOG(LogC7AssetManager, Warning, TEXT("Lua referenced asset list file not found! %s"), *LuaReferencedAssetListFile);
	}
	int32 AddCount = 0;
	TSet<FString> UniqueAssets(Assets);
	for (const FString& Asset : UniqueAssets)
	{
		FString OutFilename;
		FString OutLongPackageName;

		FString PackageName;
		FText Reason;
		bool ContainExtension = false;
		FString AssetForUE5 = GetAssetForUnreal5(Asset, ContainExtension);
		if (ContainExtension)
		{
			AssetForUE5 = GetAssetForUnreal5(AssetForUE5, ContainExtension);
		}
		if (!FPackageName::TryConvertFilenameToLongPackageName(AssetForUE5, PackageName))
		{
			verify(!FPackageName::IsValidLongPackageName(AssetForUE5, true, &Reason));
			continue;
		}
		if (!FPackageName::IsValidLongPackageName(PackageName, true, &Reason))
		{
			continue;
		}

		FPackageName::SearchForPackageOnDisk(*AssetForUE5, &OutLongPackageName, &OutFilename);
		if (!FPaths::FileExists(OutFilename))
		{
			continue;
		}

		const FName PackagePath = *FPaths::SetExtension(OutLongPackageName, TEXT(""));
		if (WorldPackages.Find(PackagePath))
		{
			continue;
		}

		OutReferencedAssets.Add(FName(*OutLongPackageName));
		++AddCount;
	}
}

bool UC7AssetManager::IsSoftReferencedByStartupPackage(FName PackageName) const
{
	const FName* StartupPackageName = StartupSoftPackages.Find(PackageName);

	return StartupPackageName ? true : false;
}

bool UC7AssetManager::IsStartupPackage(FName PackageName) const
{
	const bool* StartupPackageName = StartupPackages.Find(PackageName);

	return StartupPackageName ? true : false;
}

bool UC7AssetManager::IsMapPackage(FName PackageName) const
{
	return WorldPackages.Find(PackageName) ? true : false;
}

FString UC7AssetManager::GetAssetForUnreal5(FString NormalPath, bool& ContainExtension)
{
	FStringView SplitOutPath;
	FStringView SplitOutName;
	FStringView SplitOutExtension;
	FStringView Result;
	FPathViews::Split(NormalPath, SplitOutPath, SplitOutName, SplitOutExtension);

	if (!SplitOutName.IsEmpty() || SplitOutExtension.IsEmpty())
	{
		Result = FStringView(SplitOutPath.GetData(), UE_PTRDIFF_TO_INT32(SplitOutName.GetData() + SplitOutName.Len() - SplitOutPath.GetData()));
	}

	FString AssetPath = FString::Printf(TEXT("%.*s"), Result.Len(), Result.GetData());
	ContainExtension = AssetPath.Contains(".");

	return AssetPath;
}

#endif // WITH_EDITOR

void UC7AssetManager::StartInitialLoading()
{
	Super::StartInitialLoading();
}
