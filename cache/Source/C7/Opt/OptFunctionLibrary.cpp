// Fill out your copyright notice in the Description page of Project Settings.


#include "Opt/OptFunctionLibrary.h"

#include "BaseCharacter.h"
#include "JsonObjectConverter.h"
#include "OptCmdMgr.h"
#include "WorldPartition/WorldPartitionSubsystem.h"
#include "WorldPartition/WorldPartitionRuntimeLevelStreamingCell.h"
#include "WorldPartition/WorldPartitionRuntimeSpatialHash.h"


bool UOptFunctionLibrary::HasAllLevelLoaded()
{
	UWorld* World = FOptHelper::GetGameWorld();
	if(!World)
	{
		return false;
	}

	if(World->IsPartitionedWorld())
	{
		if (UWorldPartitionSubsystem* WorldPartitionSubsystem = UWorld::GetSubsystem<UWorldPartitionSubsystem>(World))
		{
			for (IWorldPartitionStreamingSourceProvider* StreamingSourceProvider : WorldPartitionSubsystem->GetStreamingSourceProviders())
			{
				if(!WorldPartitionSubsystem->IsStreamingCompleted(StreamingSourceProvider))
				{
					return false;
				}
			}
			return true;
		}
	}
	else if(World->GetStreamingLevels().Num() > 0)
	{
		// 检查是否有loading的状态！
		auto Levels = World->GetStreamingLevels();
		for(auto Level : Levels)
		{
			ELevelStreamingState CurrentStreamingState = Level->GetLevelStreamingState();
			if(CurrentStreamingState == ELevelStreamingState::FailedToLoad)
			{
				continue;
			}
			
			if(Level->ShouldBeVisible())
			{
				if(CurrentStreamingState == ELevelStreamingState::LoadedVisible)
				{

				}
				else
				{
					return false;
				}
			}
			else
			{
				// 不可见，但是需要加载
				if(Level->ShouldBeLoaded())
				{					
					if(CurrentStreamingState == ELevelStreamingState::LoadedNotVisible)
					{

					}
					else
					{
						return false;
					}
				}
				else
				{
					if(CurrentStreamingState == ELevelStreamingState::Unloaded
						|| CurrentStreamingState == ELevelStreamingState::Removed)
					{

					}
					else
					{
						return false;
					}					
				}
			}
		}
		
		return true;
	}
	
	return false;
}

TArray<FLevelMemoryInfoKv> UOptFunctionLibrary::GetStreamingState()
{
	TArray<FLevelMemoryInfoKv> Ret;
	UWorld* World = FOptHelper::GetGameWorld();
	if(!World)
	{
		return Ret;
	}
	
	auto Levels = World->GetStreamingLevels();
	for(auto Level : Levels)
	{
		ELevelStreamingState CurrentStreamingState = Level->GetLevelStreamingState();
		if(Level->ShouldBeVisible() || Level->ShouldBeLoaded())
		{
			FLevelMemoryInfoKv Kv;
			Kv.Key = Level->GetPathName();
			Kv.Value = EnumToString(CurrentStreamingState);
			Kv.ValueType = "string";
			
			Ret.Add(Kv);
		}
	}

	return Ret;
}

namespace c7_mem
{
	extern void BpCollectMapMemoryInfo(FMapMemoryInfo& MapMemoryInfo);
	extern void BpCollectMapTextureInfo(FMapTextureInfo& OutMapMemoryInfo);
}

FMapMemoryInfo UOptFunctionLibrary::GetMapDetailMemoryInfo()
{
	FMapMemoryInfo Ret;

	c7_mem::BpCollectMapMemoryInfo(Ret);

	auto CellNameList = GetPlayerCellName();
	for(auto CellName : CellNameList)
	{
		for(auto It : Ret.Levels)
		{
			if(It.CellName == CellName)
			{
				Ret.PlayerCellInfo.Add(It);
				break;
			}
		}		
	}
	
	return Ret;
}

TArray<FString> UOptFunctionLibrary::GetPlayerCellName()
{
	TArray<FString> Ret;
	UWorld* World = FOptHelper::GetGameWorld();
	if(!World)
	{
		return Ret;
	}
	if(!World->IsPartitionedWorld())
	{
		return Ret;
	}

	ABaseCharacter* MainPlayer = nullptr;
	for(TActorIterator<ABaseCharacter> It(World); It; ++It)
	{
		if(It->bMainPlayer)
		{
			MainPlayer = *It;			
			break;
		}
	}

	FVector Loc = FVector::Zero();
	
	if(MainPlayer)
	{
		Loc = MainPlayer->GetActorLocation();
	}
	else
	{
		// 尝试继续找！
		TArray<FVector> LocList;
		if (UWorldPartitionSubsystem* WorldPartitionSubsystem = UWorld::GetSubsystem<UWorldPartitionSubsystem>(World))
		{
			for (IWorldPartitionStreamingSourceProvider* StreamingSourceProvider : WorldPartitionSubsystem->GetStreamingSourceProviders())
			{
				TArray<FWorldPartitionStreamingSource> OutValue;
				if(StreamingSourceProvider->GetStreamingSources(OutValue))
				{
					for(auto V : OutValue)
					{
						LocList.Add(V.Location);
					}
				}
			}
		}
		if(LocList.Num() == 0)
		{
			return Ret;
		}
		else
		{
			Loc = LocList[0];
		}
	}
	
	{
		TArray<FString> CellList;
		for (TObjectIterator<UWorldPartitionRuntimeSpatialHash> It; It; ++It)
		{
			if(It->GetWorld() != World)
			{
				continue;
			}
			const UWorldPartitionRuntimeSpatialHash* CIt = *It;
			CIt->ForEachStreamingGrid([&CellList, Loc](const FSpatialHashStreamingGrid& Grid)
			{
				int CellSize = Grid.CellSize;
				Grid.ForEachRuntimeCell([&CellList, Loc, CellSize](const UWorldPartitionRuntimeCell* Cell)
				{
					if(!Cell->GetIsHLOD()
						&& FMath::IsNearlyEqual(Cell->GetCellBounds().GetSize().X, CellSize))
					{
						if(Cell->GetCellBounds().IsInsideOrOnXY(Loc))
						{
							CellList.Add(Cell->GetDebugName());
							return false;								
						}
					}			
					return true;		
				});
			});
		}
		Ret = CellList;
		return Ret;
	}
}

TArray<FLevelMemoryInfo> UOptFunctionLibrary::GetPlayerCellDetailMemoryInfo()
{
	FMapMemoryInfo Ret = GetMapDetailMemoryInfo();
	return Ret.PlayerCellInfo;
}

FMapTextureInfo UOptFunctionLibrary::GetMapDetailTextureInfo()
{
	FMapTextureInfo Ret;

	c7_mem::BpCollectMapTextureInfo(Ret);

	auto CellNameList = GetPlayerCellName();
	for(auto CellName : CellNameList)
	{
		for(auto It : Ret.Levels)
		{
			if(It.CellName == CellName)
			{
				Ret.PlayerCellInfo.Add(It);
				break;
			}
		}		
	}
	
	return Ret;
}

TArray<FLevelTextureInfo> UOptFunctionLibrary::GetPlayerCellDetailTextureInfo()
{	
	auto Ret = GetMapDetailTextureInfo();
	return Ret.PlayerCellInfo;
}

FPrMapInfoAll UOptFunctionLibrary::GetMapDetailInfoAll()
{
	FPrMapInfoAll Ret;

	// 贴图情况
	{
		c7_mem::BpCollectMapTextureInfo(Ret.MapTexture);

		auto CellNameList = GetPlayerCellName();
		for(auto CellName : CellNameList)
		{
			for(auto It : Ret.MapTexture.Levels)
			{
				if(It.CellName == CellName)
				{
					Ret.MapTexture.PlayerCellInfo.Add(It);
					break;
				}
			}		
		}		
	}

	// 内存概况
	{	
		c7_mem::BpCollectMapMemoryInfo(Ret.MapMemoryInfo);
		
		auto CellNameList = GetPlayerCellName();
		for(auto CellName : CellNameList)
		{
			for(auto It : Ret.MapMemoryInfo.Levels)
			{
				if(It.CellName == CellName)
				{
					Ret.MapMemoryInfo.PlayerCellInfo.Add(It);
					break;
				}
			}		
		}
	}

	return Ret;
}


namespace c7_opt
{	
	class FJsonUtils
	{
	public:
		template<class T>
		static void BuildJson(FStringBuilderBase& Sb, const T& Data)
		{
			FString TempArrayString;
			FJsonObjectConverter::UStructToFormattedJsonObjectString<TCHAR, TPrettyJsonPrintPolicy>(T::StaticStruct(), &Data, TempArrayString, 0, 0);
			Sb.Append(TempArrayString);
		}
		template<class T>
		static void BuildJson(FStringBuilderBase& Sb, const TArray<T>& Datas)
		{
			Sb.Append("[");
			for(int i=0; i<Datas.Num(); i++)
			{
				if(i != 0)
				{
					Sb.Append(",");
				}
				FString TempArrayString;
				FJsonObjectConverter::UStructToFormattedJsonObjectString<TCHAR, TPrettyJsonPrintPolicy>(T::StaticStruct(), &Datas[i], TempArrayString, 0, 0);
				Sb.Append(TempArrayString);
			}
			Sb.Append("]");
		}
		template<>
		void BuildJson(FStringBuilderBase& Sb, const TArray<FString>& Datas)
		{
			Sb.Append("[");
			for(int i=0; i<Datas.Num(); i++)
			{
				if(i != 0)
				{
					Sb.Append(",");
				}
				Sb.Append(Datas[i]);
			}
			Sb.Append("]");		
		}
		template<>
		void BuildJson(FStringBuilderBase& Sb, const bool& B)
		{
			Sb.Append(FString::FromInt(B ? 1 : 0));
		}
	};
	
	class FFunctionHolderBase
	{
	public:
		virtual ~FFunctionHolderBase() {}
		virtual FString Call()
		{
			return "";
		}
	};
	template<class FuncType>	
	class FFunctionHolder : public FFunctionHolderBase
	{
	public:
		FFunctionHolder(FuncType InFunc) : Func(InFunc) {}
		virtual FString Call() override
		{
			const auto& Ret = Func();
			FStringBuilderBase Sb;
			FJsonUtils::BuildJson(Sb, Ret);
			return Sb.ToString();
		}
		FuncType Func;
	};
	template<class FuncType>
	class FFunctionHolderVoid : public FFunctionHolderBase
	{
	public:
		FFunctionHolderVoid(FuncType InFunc) : Func(InFunc) {}
		virtual FString Call() override
		{
			Func();
			return "";
		}
		FuncType Func;
	};
	
}

FAutoConsoleCommand OptC7OptFuncTest(TEXT("c7.optfunc.test"), TEXT("c7.optfunc.test"), FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
{
	using namespace c7_opt;
	
	if(Args.Num() == 0)
	{
		return;
	}
	auto Func = Args[0];

	TMap<FString, TSharedPtr<FFunctionHolderBase>> Functions;
	Functions.Add("HasAllLevelLoaded", MakeShareable(new FFunctionHolder(UOptFunctionLibrary::HasAllLevelLoaded)));
	Functions.Add("GetStreamingState", MakeShareable(new FFunctionHolder(UOptFunctionLibrary::GetStreamingState)));
	Functions.Add("GetMapDetailMemoryInfo", MakeShareable(new FFunctionHolder(UOptFunctionLibrary::GetMapDetailMemoryInfo)));
	Functions.Add("GetPlayerCellName", MakeShareable(new FFunctionHolder(UOptFunctionLibrary::GetPlayerCellName)));
	Functions.Add("GetPlayerCellDetailMemoryInfo", MakeShareable(new FFunctionHolder(UOptFunctionLibrary::GetPlayerCellDetailMemoryInfo)));
	Functions.Add("GetMapDetailTextureInfo", MakeShareable(new FFunctionHolder(UOptFunctionLibrary::GetMapDetailTextureInfo)));
	Functions.Add("GetPlayerCellDetailTextureInfo", MakeShareable(new FFunctionHolder(UOptFunctionLibrary::GetPlayerCellDetailTextureInfo)));
	
	auto Ptr = Functions.Find(Func);
	if(Ptr != nullptr && Ptr->IsValid())
	{
		FString Ret = (*Ptr)->Call();
		UE_LOG(LogTemp, Log, TEXT("liubo, TestFunc=%s, Result=%s"), *Func, *Ret);
	}
	else
	{
		UE_LOG(LogTemp, Log, TEXT("liubo, TestFunc=%s, Unknown Func!"), *Func);		
	}
	
}));