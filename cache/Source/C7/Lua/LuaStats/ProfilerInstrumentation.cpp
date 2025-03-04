#include "ProfilerInstrumentation.h"

#if STATS

DECLARE_STATS_GROUP(TEXT("LuaInstrumentation"), STATGROUP_LuaInstrumentation, STATCAT_Advanced);

class FLuaCycleCounter : FCycleCounter
{
	TStatId StatId;
	bool bStart;

public:
	uint64 StartTime;

	FORCEINLINE_STATS FLuaCycleCounter(TStatId InStatId)
		: StatId(InStatId.GetRawPointer())
		  , bStart(false), StartTime(0)
	{
	}

	~FLuaCycleCounter()
	{
		Stop();
	}

	void Start()
	{
		if (!bStart)
		{
			bStart = true;
			StartTime = FPlatformTime::Cycles64();
			FCycleCounter::Start(StatId);
		}
	}

	void Stop()
	{
		if (bStart)
		{
			bStart = false;
			FCycleCounter::Stop();
		}
	}

	void Set(const uint32 Cycles) const
	{
		if (FThreadStats::IsCollectingData())
		{
			FThreadStats::AddMessage(StatId.GetName(), EStatOperation::Set, static_cast<int64>(Cycles), true);
		}
	}

	TStatId GetStatId() const
	{
		return StatId;
	}
};

class FLuaSimpleMillisecondStat
{
public:
	FLuaSimpleMillisecondStat(TStatId InStatId, double InScale = 1.0)
		: bStart(false)
		  , StartTime(0)
		  , StatId(InStatId)
		  , Scale(InScale)
	{
	}

	~FLuaSimpleMillisecondStat()
	{
		double TimeResult = 0;
		Stop(TimeResult);
	}

	void Start()
	{
		bStart = true;
		StartTime = FPlatformTime::Cycles64();
	}

	void Stop(double& TimeResult)
	{
		if (bStart)
		{
			bStart = false;
			const double TotalTime = (FPlatformTime::Cycles64() - StartTime) * Scale;
			TimeResult = FPlatformTime::ToMilliseconds64(TotalTime);
			FThreadStats::AddMessage(StatId.GetName(), EStatOperation::Set, TimeResult);
		}
	}

	bool IsStart() const
	{
		return bStart;
	}

private:
	bool bStart;
	double StartTime;
	TStatId StatId;
	double Scale;
};

class FLuaStats
{
private:
	TSparseArray<FLuaCycleCounter> CycleCounters;
	TMap<FName, int32> NameToCycleCounter;
	TMap<TStatIdData const*, int32> PtrToCycleCounter;
	TArray<int32> CycleCounterStack;

	TSparseArray<FLuaSimpleMillisecondStat> SimpleMillisecondStats;
	TMap<FName, int32> NameToMillisecondStat;
	TMap<TStatIdData const*, int32> PtrToMillisecondStat;

	TMap<FName, TStatIdData const*> Int64Stats;
	TMap<FName, TStatIdData const*> DoubleStats;
	TMap<FName, TStatIdData const*> MemoryStats;

	static TStatId CreateStatId(FName StatName, const TCHAR* StatDesc, bool bShouldClearEveryFrame,
	                            EStatDataType::Type InStatType, bool bCycleStat,
	                            FPlatformMemory::EMemoryCounterRegion MemRegion = FPlatformMemory::MCR_Invalid);

	void StartCycleCounterInternal(int32 Index);
	void SetCycleCounterInternal(int32 Index, const uint32 Cycles);
	void StartSimpleMillisecondInternal(int32 Index);
	void StopSimpleMillisecondInternal(int32 Index, double& TimeResult);

public:
	TStatIdData const* CreateCycleCounter(FName StatName, const TCHAR* StatDesc = nullptr);
	TStatIdData const* CreateSimpleMillisecond(FName StatName, const TCHAR* StatDesc = nullptr, double InScale = 1.0);
	TStatIdData const* CreateInt64Counter(FName StatName, const TCHAR* StatDesc = nullptr);
	TStatIdData const* CreateInt64Accumulator(FName StatName, const TCHAR* StatDesc = nullptr);
	TStatIdData const* CreateDoubleCounter(FName StatName, const TCHAR* StatDesc = nullptr);
	TStatIdData const* CreateDoubleAccumulator(FName StatName, const TCHAR* StatDesc = nullptr);
	TStatIdData const* CreateMemoryStat(FName StatName, const TCHAR* StatDesc = nullptr);

	bool StartCycleCounter(FName StatName);
	bool StartCycleCounter(TStatIdData const* StatIdPtr);
	bool StopCycleCounter(double& Duration);
	bool SetCycleCounter(FName StatName, const uint32 Cycles);
	bool SetCycleCounter(TStatIdData const* StatIdPtr, const uint32 Cycles);

	bool StartSimpleMillisecond(FName StatName);
	bool StartSimpleMillisecond(TStatIdData const* StatIdPtr);
	bool StopSimpleMillisecond(FName StatName, double& TimeResult);
	bool StopSimpleMillisecond(TStatIdData const* StatIdPtr, double& TimeResult);

	bool AddInt64Stat(FName StatName, int64 Value) const;
	bool AddInt64Stat(TStatIdData const* StatIdPtr, int64 Value) const;
	bool SubtractInt64Stat(FName StatName, int64 Value) const;
	bool SubtractInt64Stat(TStatIdData const* StatIdPtr, int64 Value) const;
	bool SetInt64Stat(FName StatName, int64 Value) const;
	bool SetInt64Stat(TStatIdData const* StatIdPtr, int64 Value) const;

	bool AddMemoryStat(FName StatName, int64 Value) const;
	bool AddMemoryStat(TStatIdData const* StatIdPtr, int64 Value) const;
	bool SubtractMemoryStat(FName StatNam, int64 Value) const;
	bool SubtractMemoryStat(TStatIdData const* StatIdPtr, int64 Value) const;
	bool SetMemoryStat(FName StatName, int64 Value) const;
	bool SetMemoryStat(TStatIdData const* StatIdPtr, int64 Value) const;

	bool AddDoubleStat(FName StatName, double Value) const;
	bool AddDoubleStat(TStatIdData const* StatIdPtr, double Value) const;
	bool SubtractDoubleStat(FName StatName, double Value) const;
	bool SubtractDoubleStat(TStatIdData const* StatIdPtr, double Value) const;
	bool SetDoubleStat(FName StatName, double Value) const;
	bool SetDoubleStat(TStatIdData const* StatIdPtr, double Value) const;

	void SetFNameStat(FName StatName, FName Value) const;
	bool SetFNameStat(TStatIdData const* StatIdPtr, const char* Value) const;

	void StopAllCycle();
};

bool FLuaStats::AddInt64Stat(TStatIdData const* StatIdPtr, int64 Value) const
{
	const FName StatName = MinimalNameToName(StatIdPtr->Name);
	if (Value != 0 && Int64Stats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Add, Value);
		TRACE_STAT_ADD(StatName, Value);
		return true;
	}
	return false;
}

bool FLuaStats::AddInt64Stat(FName StatName, int64 Value) const
{
	if (Value != 0 && Int64Stats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Add, Value);
		TRACE_STAT_ADD(StatName, Value);
		return true;
	}
	return false;
}

bool FLuaStats::SubtractInt64Stat(FName StatName, int64 Value) const
{
	if (Value != 0 && Int64Stats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Subtract, Value);
		TRACE_STAT_ADD(StatName, -Value);
		return true;
	}
	return false;
}

bool FLuaStats::SubtractInt64Stat(TStatIdData const* StatIdPtr, int64 Value) const
{
	const FName StatName = MinimalNameToName(StatIdPtr->Name);
	if (Value != 0 && Int64Stats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Subtract, Value);
		TRACE_STAT_ADD(StatName, -Value);
		return true;
	}
	return false;
}

bool FLuaStats::SetInt64Stat(FName StatName, int64 Value) const
{
	if (Value != 0 && Int64Stats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Set, Value);
		TRACE_STAT_SET(StatName, Value);
		return true;
	}
	return false;
}

bool FLuaStats::SetInt64Stat(TStatIdData const* StatIdPtr, int64 Value) const
{
	const FName StatName = MinimalNameToName(StatIdPtr->Name);
	if (Value != 0 && Int64Stats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Set, Value);
		TRACE_STAT_SET(StatName, Value);
		return true;
	}
	return false;
}

bool FLuaStats::AddMemoryStat(FName StatName, int64 Value) const
{
	if (Value != 0 && MemoryStats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Add, Value);
		TRACE_STAT_ADD(StatName, Value);
		return true;
	}
	return false;
}

bool FLuaStats::AddMemoryStat(TStatIdData const* StatIdPtr, int64 Value) const
{
	const FName StatName = MinimalNameToName(StatIdPtr->Name);
	if (Value != 0 && MemoryStats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Add, Value);
		TRACE_STAT_ADD(StatName, Value);
		return true;
	}
	return false;
}

bool FLuaStats::SubtractMemoryStat(FName StatName, int64 Value) const
{
	if (Value != 0 && MemoryStats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Subtract, Value);
		TRACE_STAT_ADD(StatName, -Value);
		return true;
	}
	return false;
}

bool FLuaStats::SubtractMemoryStat(TStatIdData const* StatIdPtr, int64 Value) const
{
	const FName StatName = MinimalNameToName(StatIdPtr->Name);
	if (Value != 0 && MemoryStats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Subtract, Value);
		TRACE_STAT_ADD(StatName, -Value);
		return true;
	}
	return false;
}

bool FLuaStats::SetMemoryStat(FName StatName, int64 Value) const
{
	if (Value != 0 && MemoryStats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Set, Value);
		TRACE_STAT_SET(StatName, Value);
		return true;
	}
	return false;
}

bool FLuaStats::SetMemoryStat(TStatIdData const* StatIdPtr, int64 Value) const
{
	const FName StatName = MinimalNameToName(StatIdPtr->Name);
	if (Value != 0 && MemoryStats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Set, Value);
		TRACE_STAT_SET(StatName, Value);
		return true;
	}
	return false;
}

bool FLuaStats::AddDoubleStat(FName StatName, double Value) const
{
	if (Value != 0 && DoubleStats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Add, Value);
		TRACE_STAT_ADD(StatName, Value);
		return true;
	}
	return false;
}

bool FLuaStats::AddDoubleStat(TStatIdData const* StatIdPtr, double Value) const
{
	const FName StatName = MinimalNameToName(StatIdPtr->Name);
	if (Value != 0 && DoubleStats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Add, Value);
		TRACE_STAT_ADD(StatName, Value);
		return true;
	}
	return false;
}

bool FLuaStats::SubtractDoubleStat(FName StatName, double Value) const
{
	if (Value != 0 && DoubleStats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Subtract, Value);
		TRACE_STAT_ADD(StatName, -Value);
		return true;
	}
	return false;
}

bool FLuaStats::SubtractDoubleStat(TStatIdData const* StatIdPtr, double Value) const
{
	const FName StatName = MinimalNameToName(StatIdPtr->Name);
	if (Value != 0 && DoubleStats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Subtract, Value);
		TRACE_STAT_ADD(StatName, -Value);
		return true;
	}
	return false;
}

bool FLuaStats::SetDoubleStat(FName StatName, double Value) const
{
	if (Value != 0 && DoubleStats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Set, Value);
		TRACE_STAT_SET(StatName, Value);
		return true;
	}
	return false;
}

bool FLuaStats::SetDoubleStat(TStatIdData const* StatIdPtr, double Value) const
{
	const FName StatName = MinimalNameToName(StatIdPtr->Name);
	if (Value != 0 && Int64Stats.Contains(StatName) && FThreadStats::IsCollectingData())
	{
		FThreadStats::AddMessage(StatName, EStatOperation::Set, Value);
		TRACE_STAT_SET(StatName, Value);
		return true;
	}
	return false;
}

void FLuaStats::SetFNameStat(FName StatName, FName Value) const
{
	FThreadStats::AddMessage(StatName, EStatOperation::SpecialMessageMarker, Value);
}

bool FLuaStats::SetFNameStat(TStatIdData const* StatIdPtr, const char* Value) const
{
	const FName StatName = MinimalNameToName(StatIdPtr->Name);
	if (Value != nullptr)
	{
		FThreadStats::AddMessage(StatName, EStatOperation::SpecialMessageMarker, FName(Value));
		return true;
	}
	return false;
}

void FLuaStats::StopAllCycle()
{
	while (CycleCounterStack.Num() > 0)
	{
		const auto Index = CycleCounterStack.Pop();
		check(CycleCounters.IsValidIndex(Index));
		CycleCounters[Index].Stop();
	}
	if (SimpleMillisecondStats.Num() > 0)
	{
		for (int32 Index = 0; Index < SimpleMillisecondStats.Num(); Index++)
		{
			if (SimpleMillisecondStats[Index].IsStart())
			{
				double TimerResult;
				SimpleMillisecondStats[Index].Stop(TimerResult);
			}
		}
	}
}

TStatId FLuaStats::CreateStatId(FName StatName, const TCHAR* StatDesc, bool bShouldClearEveryFrame,
                                EStatDataType::Type InStatType, bool bCycleStat,
                                FPlatformMemory::EMemoryCounterRegion MemRegion)
{
	FStartupMessages::Get().AddMetadata(StatName, StatDesc,
	                                    FStatGroup_STATGROUP_LuaInstrumentation::GetGroupName(),
	                                    FStatGroup_STATGROUP_LuaInstrumentation::GetGroupCategory(),
	                                    FStatGroup_STATGROUP_LuaInstrumentation::GetDescription(),
	                                    bShouldClearEveryFrame,
	                                    InStatType, bCycleStat,
	                                    FStatGroup_STATGROUP_LuaInstrumentation::GetSortByName(), MemRegion);

	const TStatId StatID = IStatGroupEnableManager::Get().GetHighPerformanceEnableForStat(StatName,
		FStatGroup_STATGROUP_LuaInstrumentation::GetGroupName(),
		FStatGroup_STATGROUP_LuaInstrumentation::GetGroupCategory(),
		FStatGroup_STATGROUP_LuaInstrumentation::IsDefaultEnabled(),
		bShouldClearEveryFrame, InStatType,
		StatDesc, bCycleStat,
		FStatGroup_STATGROUP_LuaInstrumentation::GetSortByName(), MemRegion);
	return StatID;
}

TStatIdData const* FLuaStats::CreateCycleCounter(FName StatName, const TCHAR* StatDesc)
{
	if (NameToCycleCounter.Contains(StatName))
	{
		return nullptr;
	}
	TStatId Result = CreateStatId(StatName, StatDesc, true, EStatDataType::ST_int64, true);
	int32 Index = CycleCounters.Emplace(Result);
	NameToCycleCounter.Emplace(StatName, Index);
	PtrToCycleCounter.Emplace(Result.GetRawPointer(), Index);
	return Result.GetRawPointer();
}

void FLuaStats::StartCycleCounterInternal(int32 Index)
{
	check(CycleCounters.IsValidIndex(Index));
	CycleCounterStack.Push(Index);
	CycleCounters[Index].Start();
}

void FLuaStats::SetCycleCounterInternal(int32 Index, const uint32 Cycles)
{
	check(CycleCounters.IsValidIndex(Index));
	CycleCounters[Index].Set(Cycles);
}

bool FLuaStats::StartCycleCounter(FName StatName)
{
	if (const auto Result = NameToCycleCounter.Find(StatName))
	{
		StartCycleCounterInternal(*Result);
		return true;
	}
	return false;
}

bool FLuaStats::StartCycleCounter(TStatIdData const* StatIdPtr)
{
	if (const auto Result = PtrToCycleCounter.Find(StatIdPtr))
	{
		StartCycleCounterInternal(*Result);
		return true;
	}
	return false;
}

bool FLuaStats::StopCycleCounter(double& Duration)
{
	if (CycleCounterStack.Num() == 0)
	{
		return false;
	}
	const auto Index = CycleCounterStack.Pop();
	check(CycleCounters.IsValidIndex(Index));
	CycleCounters[Index].Stop();
	Duration = FPlatformTime::ToMilliseconds64(FPlatformTime::Cycles64() - CycleCounters[Index].StartTime);
	return true;
}

bool FLuaStats::SetCycleCounter(FName StatName, const uint32 Cycles)
{
	if (const auto Result = NameToCycleCounter.Find(StatName))
	{
		SetCycleCounterInternal(*Result, Cycles);
		return true;
	}
	return false;
}

bool FLuaStats::SetCycleCounter(TStatIdData const* StatIdPtr, const uint32 Cycles)
{
	if (const auto Result = PtrToCycleCounter.Find(StatIdPtr))
	{
		SetCycleCounterInternal(*Result, Cycles);
		return true;
	}
	return false;
}

TStatIdData const* FLuaStats::CreateSimpleMillisecond(FName StatName, const TCHAR* StatDesc, double InScale)
{
	if (NameToMillisecondStat.Contains(StatName))
	{
		return nullptr;
	}
	const TStatId StatId = CreateDoubleCounter(StatName, StatDesc);
	auto Index = SimpleMillisecondStats.Emplace(StatId, InScale);
	NameToMillisecondStat.Emplace(StatName, Index);
	PtrToMillisecondStat.Emplace(StatId.GetRawPointer(), Index);
	return StatId.GetRawPointer();
}

void FLuaStats::StartSimpleMillisecondInternal(int32 Index)
{
	check(SimpleMillisecondStats.IsValidIndex(Index));
	SimpleMillisecondStats[Index].Start();
}

void FLuaStats::StopSimpleMillisecondInternal(int32 Index, double& TimeResult)
{
	check(SimpleMillisecondStats.IsValidIndex(Index));
	SimpleMillisecondStats[Index].Stop(TimeResult);
}

bool FLuaStats::StartSimpleMillisecond(FName StatName)
{
	if (const auto Result = NameToMillisecondStat.Find(StatName))
	{
		StartSimpleMillisecondInternal(*Result);
		return true;
	}
	return false;
}

bool FLuaStats::StartSimpleMillisecond(TStatIdData const* StatIdPtr)
{
	if (const auto Result = PtrToMillisecondStat.Find(StatIdPtr))
	{
		StartSimpleMillisecondInternal(*Result);
		return true;
	}
	return false;
}

bool FLuaStats::StopSimpleMillisecond(FName StatName, double& TimeResult)
{
	if (const auto Result = NameToMillisecondStat.Find(StatName))
	{
		StopSimpleMillisecondInternal(*Result, TimeResult);
		return true;
	}
	return false;
}

bool FLuaStats::StopSimpleMillisecond(TStatIdData const* StatIdPtr, double& TimeResult)
{
	if (const auto Result = PtrToMillisecondStat.Find(StatIdPtr))
	{
		StopSimpleMillisecondInternal(*Result, TimeResult);
		return true;
	}
	return false;
}

TStatIdData const* FLuaStats::CreateInt64Counter(FName StatName, const TCHAR* StatDesc)
{
	if (Int64Stats.Contains(StatName))
	{
		return nullptr;
	}
	const TStatId StatId = CreateStatId(StatName, StatDesc, true, EStatDataType::ST_int64, false);
	Int64Stats.Emplace(StatName, StatId.GetRawPointer());
	return StatId.GetRawPointer();
}

TStatIdData const* FLuaStats::CreateInt64Accumulator(FName StatName, const TCHAR* StatDesc)
{
	if (Int64Stats.Contains(StatName))
	{
		return nullptr;
	}
	const TStatId StatId = CreateStatId(StatName, StatDesc, false, EStatDataType::ST_int64, false);
	Int64Stats.Emplace(StatName, StatId.GetRawPointer());
	return StatId.GetRawPointer();
}

TStatIdData const* FLuaStats::CreateDoubleCounter(FName StatName, const TCHAR* StatDesc)
{
	if (DoubleStats.Contains(StatName))
	{
		return nullptr;
	}
	const TStatId StatId = CreateStatId(StatName, StatDesc, true, EStatDataType::ST_double, false);
	DoubleStats.Emplace(StatName, StatId.GetRawPointer());
	return StatId.GetRawPointer();
}

TStatIdData const* FLuaStats::CreateDoubleAccumulator(FName StatName, const TCHAR* StatDesc)
{
	if (DoubleStats.Contains(StatName))
	{
		return nullptr;
	}
	const TStatId StatId = CreateStatId(StatName, StatDesc, false, EStatDataType::ST_double, false);
	DoubleStats.Emplace(StatName, StatId.GetRawPointer());
	return StatId.GetRawPointer();
}

TStatIdData const* FLuaStats::CreateMemoryStat(FName StatName, const TCHAR* StatDesc)
{
	if (MemoryStats.Contains(StatName))
	{
		return nullptr;
	}
	const TStatId StatId = CreateStatId(StatName, StatDesc, false, EStatDataType::ST_int64, false,
	                                    FPlatformMemory::MCR_Physical);
	MemoryStats.Emplace(StatName, StatId.GetRawPointer());
	return StatId.GetRawPointer();
}

FLuaStats GLuaStats;

bool UProfilerInstrumentation::CycleCounterCreate(FName StatName, FString StatDesc)
{
	const auto StatIdPtr = GLuaStats.CreateCycleCounter(StatName, StatDesc.IsEmpty() ? nullptr : *StatDesc);
	return StatIdPtr != nullptr;
}

bool UProfilerInstrumentation::CycleCounterStart(FName StatName)
{
	return GLuaStats.StartCycleCounter(StatName);
}

bool UProfilerInstrumentation::CycleCounterStop(double& Duration)
{
	return GLuaStats.StopCycleCounter(Duration);
}

bool UProfilerInstrumentation::CycleCounterSet(FName StatName)
{
	return GLuaStats.StartCycleCounter(StatName);
}

bool UProfilerInstrumentation::SimpleMillisecondCreate(FName StatName, FString StatDesc, double Scale)
{
	const auto StatIdPtr = GLuaStats.CreateSimpleMillisecond(StatName, StatDesc.IsEmpty() ? nullptr : *StatDesc, Scale);
	return StatIdPtr != nullptr;
}

bool UProfilerInstrumentation::SimpleMillisecondStart(FName StatName)
{
	return GLuaStats.StartSimpleMillisecond(StatName);
}

bool UProfilerInstrumentation::SimpleMillisecondStop(FName StatName, double& Duration)
{
	return GLuaStats.StopSimpleMillisecond(StatName, Duration);
}

bool UProfilerInstrumentation::Int64StatCreate(FName StatName, FString StatDesc, bool bCounter)
{
	const auto StatIdPtr = GLuaStats.CreateInt64Counter(StatName, StatDesc.IsEmpty() ? nullptr : *StatDesc);
	return StatIdPtr != nullptr;
}

bool UProfilerInstrumentation::Int64StatAdd(FName StatName, int64 Value)
{
	return GLuaStats.AddInt64Stat(StatName, Value);
}

bool UProfilerInstrumentation::Int64StatSubtract(FName StatName, int64 Value)
{
	return GLuaStats.SubtractInt64Stat(StatName, Value);
}

bool UProfilerInstrumentation::Int64StatSet(FName StatName, int64 Value)
{
	return GLuaStats.SetInt64Stat(StatName, Value);
}

bool UProfilerInstrumentation::DoubleStatCreate(FName StatName, FString StatDesc)
{
	const auto StatIdPtr = GLuaStats.CreateDoubleCounter(StatName, StatDesc.IsEmpty() ? nullptr : *StatDesc);
	return StatIdPtr != nullptr;
}

bool UProfilerInstrumentation::DoubleStatAdd(FName StatName, double Value)
{
	return GLuaStats.AddDoubleStat(StatName, Value);
}

bool UProfilerInstrumentation::DoubleStatSubtract(FName StatName, double Value)
{
	return GLuaStats.SubtractDoubleStat(StatName, Value);
}

bool UProfilerInstrumentation::DoubleStatSet(FName StatName, double Value)
{
	return GLuaStats.SetDoubleStat(StatName, Value);
}

void UProfilerInstrumentation::FNameStatSet(FName StatName, FName Value)
{
	GLuaStats.SetFNameStat(StatName, Value);
}

bool UProfilerInstrumentation::MemoryStatCreate(FName StatName, FString StatDesc)
{
	const auto StatIdPtr = GLuaStats.CreateMemoryStat(StatName, StatDesc.IsEmpty() ? nullptr : *StatDesc);
	return StatIdPtr != nullptr;
}

bool UProfilerInstrumentation::MemoryStatAdd(FName StatName, int64 Value)
{
	return GLuaStats.AddMemoryStat(StatName, Value);
}

bool UProfilerInstrumentation::MemoryStatSubtract(FName StatName, int64 Value)
{
	return GLuaStats.SubtractMemoryStat(StatName, Value);
}

bool UProfilerInstrumentation::MemoryStatSet(FName StatName, int64 Value)
{
	return GLuaStats.SetMemoryStat(StatName, Value);
}

void UProfilerInstrumentation::AllCounterStop()
{
	GLuaStats.StopAllCycle();
}

#else

bool UProfilerInstrumentation::CycleCounterCreate(FName StatName, FString StatDesc)
{
	return false;
}

bool UProfilerInstrumentation::CycleCounterStart(FName StatName)
{
	return false;
}

bool UProfilerInstrumentation::CycleCounterStop(double& Duration)
{
	return false;
}

bool UProfilerInstrumentation::CycleCounterSet(FName StatName)
{
	return false;
}

bool UProfilerInstrumentation::SimpleMillisecondCreate(FName StatName, FString StatDesc, double Scale)
{
	return false;
}

bool UProfilerInstrumentation::SimpleMillisecondStart(FName StatName)
{
	return false;
}

bool UProfilerInstrumentation::SimpleMillisecondStop(FName StatName, double& Duration)
{
	return false;
}

bool UProfilerInstrumentation::Int64StatCreate(FName StatName, FString StatDesc, bool bCounter)
{
	return false;
}

bool UProfilerInstrumentation::Int64StatAdd(FName StatName, int64 Value)
{
	return false;
}

bool UProfilerInstrumentation::Int64StatSubtract(FName StatName, int64 Value)
{
	return false;
}

bool UProfilerInstrumentation::Int64StatSet(FName StatName, int64 Value)
{
	return false;
}

bool UProfilerInstrumentation::DoubleStatCreate(FName StatName, FString StatDesc)
{
	return false;
}

bool UProfilerInstrumentation::DoubleStatAdd(FName StatName, double Value)
{
	return false;
}

bool UProfilerInstrumentation::DoubleStatSubtract(FName StatName, double Value)
{
	return false;
}

bool UProfilerInstrumentation::DoubleStatSet(FName StatName, double Value)
{
	return false;
}

void UProfilerInstrumentation::FNameStatSet(FName StatName, FName Value){}

bool UProfilerInstrumentation::MemoryStatCreate(FName StatName, FString StatDesc)
{
	return false;
}

bool UProfilerInstrumentation::MemoryStatAdd(FName StatName, int64 Value)
{
	return false;
}

bool UProfilerInstrumentation::MemoryStatSubtract(FName StatName, int64 Value)
{
	return false;
}

bool UProfilerInstrumentation::MemoryStatSet(FName StatName, int64 Value)
{
	return false;
}

void UProfilerInstrumentation::AllCounterStop()
{
}

#endif

FString UProfilerInstrumentation::GetDeviceProfileName()
{
	return FPlatformMisc::GetDefaultDeviceProfileName();
}

FString UProfilerInstrumentation::GetCPUInfo()
{
	return FPlatformMisc::GetCPUBrand();
}