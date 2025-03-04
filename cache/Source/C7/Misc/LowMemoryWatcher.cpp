#include "LowMemoryWatcher.h"
#include "C7GameInstance.h"
#include "Kismet/KismetSystemLibrary.h"


#if !(UE_BUILD_SHIPPING || UE_BUILD_TEST)
static TAutoConsoleVariable<bool> CVarListObjWhileMemoryLow(
	TEXT("Debug.OOMMemReport"),
	1,
	TEXT("If set to 1, obj list will print to log when memory is low"));
#endif

static TAutoConsoleVariable<bool> CVarWatchPcMemory(
	TEXT("mem.watchpc"),
	1,
	TEXT("If set to 1, obj list will print to log when memory is low"),
	ECVF_Default);

static TAutoConsoleVariable<int> CVarWatchPcMemoryMaxValue(
	TEXT("mem.watchpc.max"),
	20480,
	TEXT("If set to 1, obj list will print to log when memory is low"),
	ECVF_Default);

//memory low warning begin
ENGINE_API extern void (*GGameMemoryWarningHandler)(const FGenericMemoryWarningContext& Context);
uint32 MemoryWarningCount = 0;
uint32 MemoryWarningHandleCount = 0;

// maybe not in game thread, so handle it in game thread tick
void C7MemoryWarningHandler(const FGenericMemoryWarningContext& Context)
{
	UE_LOG(LogTemp, Warning, TEXT("###### OnC7MemoryWarningHandler"));
	if (!MemoryWarningCount)
	{
		UE_LOG(LogTemp, Warning, TEXT("Uploading MemReport for First Memory Warning"));
		GEngine->Exec(nullptr, TEXT("memreport -log -report=MemoryWarning"));
	}
	MemoryWarningCount++;
}
// memory low warning end


void ULowMemoryWatcher::Init(UC7GameInstance* InGI)
{
	GI = InGI;
	MemoryWarningCount = MemoryWarningHandleCount = 0;
	GGameMemoryWarningHandler = C7MemoryWarningHandler;
}

void ULowMemoryWatcher::Uninit()
{
	GGameMemoryWarningHandler = nullptr;
	GI = nullptr;

}

void ULowMemoryWatcher::Tick(float DeltaTime)
{
	if (MemoryWarningCount != MemoryWarningHandleCount && GI)
	{
		MemoryWarningHandleCount = MemoryWarningCount;

		//GI->OnLuaMemoryLowWarning();
	}

#if !WITH_EDITOR && PLATFORM_WINDOWS 
	// 如果是PC版本，那么检查内存
	// 逻辑是：数量超过N后，再次触发就是N+M，如果60s内没有触发，又回归
	if(CVarWatchPcMemory.GetValueOnGameThread())
	{
		const int WatchMemory = CVarWatchPcMemoryMaxValue.GetValueOnGameThread();
		const int WatchMemoryStep = 512;
		const int WatchDelayTime = 61; // GC的频率
		
		if(WatchMemoryMaxValue == 0)
		{
			WatchMemoryMaxValue = WatchMemory;
		}

		FPlatformMemoryStats Stats = FPlatformMemory::GetStats();
		float UsedMemory = Stats.UsedPhysical / 1048576.0f;
		if(UsedMemory > WatchMemoryMaxValue)
		{
			WatchMemoryMaxValue = WatchMemoryMaxValue + WatchMemoryStep;
			WatchMemoryDelayTime = WatchDelayTime;
			UE_LOG(LogTemp, Error, TEXT("Call@liubo11, Mem used: %.2f MB. Expected=%d MB"), UsedMemory, WatchMemoryMaxValue-WatchMemoryStep);
			UKismetSystemLibrary::ExecuteConsoleCommand(this, TEXT("memreport -log -report=MemoryWarning"), nullptr);
		}
		else
		{
			if(WatchMemoryDelayTime > 0)
			{
				WatchMemoryDelayTime -= DeltaTime;
				if(WatchMemoryDelayTime <= 0)
				{
					WatchMemoryMaxValue = WatchMemory;						
				}
			}
		}		
	}
#endif
}