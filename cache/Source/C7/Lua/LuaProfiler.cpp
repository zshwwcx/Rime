#include "Lua/LuaProfiler.h"
#include "Misc/FileHelper.h"
#include "HAL/PlatformMisc.h"
#include "HAL/FileManager.h"
#include "Kismet/KismetSystemLibrary.h"

#if !UE_BUILD_SHIPPING
#include "LuaTraceData.h"



#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "slua.h"


extern  SLUA_UNREAL_API void (*GLuaMallocCallBack)(void* InAddr, int InSize);


LuaTrace* LT = nullptr;
LuaMemoryTrace* LMT = nullptr;

void LuaMallocCallBack(void* InAddr, int InSize)
{
    if (LMT)
    {
        LMT->OnMalloc(InAddr, InSize);
    }

}

#endif

#if !UE_BUILD_SHIPPING
static void SignalHandlerHookSwitch(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* par)
{
    switch (par->event)
    {
    case LUA_HOOKCALL:
    case LUA_HOOKTAILCALL:
    {
        LT->OnHookCall(L, par);
        break;
    }
    case LUA_HOOKRET:
    {
        LT->OnHookReturn(L, par);
        break;
    }
    case LUA_HOOKCOUNT:
    {
        LT->OnHookSampling(L, par);
        break;
    }
    default:
        break;
    }
}
#endif




void ULuaProfiler::Start()
{
#if !UE_BUILD_SHIPPING
    if (bRunning == false)
    {
        bRunning = true;

        LuaTracer = new LuaTrace;
        LuaTracer->Init();

        LT = LuaTracer;

        SetHook(true);

        FCoreDelegates::OnBeginFrame.AddUObject(this, &ULuaProfiler::OnFrameBegin);
    }
#endif
}


void ULuaProfiler::Stop(int InNum)
{
#if !UE_BUILD_SHIPPING
    if (bRunning == true)
    {
        bRunning = false;

        FCoreDelegates::OnBeginFrame.RemoveAll(this);

        SetHook(false);

        if (InNum <= 0)
        {
            InNum = 50;
        }

        Report(InNum);

        LuaTracer->DeInit();
        delete LuaTracer;
        LuaTracer = nullptr;
    }
#endif

}



void ULuaProfiler::Report(int InNum)
{
#if !UE_BUILD_SHIPPING
    FString TimeString = FPlatformTime::StrTimestamp();
    TimeString.ReplaceCharInline(' ', '_');
    TimeString.ReplaceCharInline('\\', '_');
    TimeString.ReplaceCharInline('/', '_');
    TimeString.ReplaceCharInline(':', '_');

    FString PathToSave = FPaths::ProfilingDir() + FString::Printf(TEXT("lua_profile_%s.log"), *TimeString);

    FArchive* Writer = IFileManager::Get().CreateFileWriter(*PathToSave, EFileWrite::FILEWRITE_EvenIfReadOnly);
    if (Writer == nullptr)
    {
        UE_LOG(LogTemp, Warning, TEXT("Can not create file :%s"), *PathToSave);
        return;
    }

    LuaTracer->SaveData(Writer, InNum);

    Writer->Close();
    delete Writer;
#endif


}


void ULuaProfiler::OnFrameBegin()
{
#if !UE_BUILD_SHIPPING
    if (bRunning)
    {
        LuaTracer->NewFrame();
    }
#endif
}

void ULuaProfiler::SetHook(bool bOn)
{
    using namespace NS_SLUA;
 #if !UE_BUILD_SHIPPING
    NS_SLUA::lua_State* L = GetLuaState();

     if (bOn)
     {
        if (L)
        {
            lua_sethook(L, SignalHandlerHookSwitch, LUA_MASKCALL | LUA_MASKRET, 0);
        }
     }
     else
     {
        if (L)
        {
            lua_sethook(L, 0, 0, 0);
        }
     }

     bHook = bOn;
 #endif

}

void ULuaProfiler::StartHookLuaMemoryAllcation()
{
 #if !UE_BUILD_SHIPPING
    GLuaMallocCallBack = &LuaMallocCallBack;

     if (LMT == nullptr)
     {
         LMT = new LuaMemoryTrace(GetLuaState());
     }
 #endif

}

void ULuaProfiler::StopHookLuaMemoryAllcation(int InNum)
{
 #if !UE_BUILD_SHIPPING
    GLuaMallocCallBack = nullptr;

     if (LMT)
     {
         DumpLuaMemoryAllocationReport(InNum);
         LMT->Reset();
         delete LMT;
         LMT = nullptr;
     }

 #endif

}

NS_SLUA::lua_State* ULuaProfiler::GetLuaState()
{
    UGameInstance* GI = NS_SLUA::LuaState::getObjectGameInstance(this);
    if (GI)
    {
        NS_SLUA::LuaState* LS = NS_SLUA::LuaState::get(GI);
        if (LS)
        {
            return LS->getLuaState();
        }
    }

    return nullptr;
}

#if !UE_BUILD_SHIPPING
static void writeFile(FString InPathToSave, std::unordered_map<uint64, LuaMemoryNode*> InMallocList, int InNum)
{
	FArchive* Writer = IFileManager::Get().CreateFileWriter(*InPathToSave, EFileWrite::FILEWRITE_EvenIfReadOnly);
	if (Writer == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("Can not create file :%s"), *InPathToSave);
		return;
	}

	LMT->SaveData(Writer, InNum, InMallocList);

	Writer->Close();
	delete Writer;
}
#endif

void ULuaProfiler::DumpLuaMemoryAllocationReport(int InNum)
{
#if !UE_BUILD_SHIPPING
    if (LMT)
    {
        FString TimeString = FPlatformTime::StrTimestamp();
        TimeString.ReplaceCharInline(' ', '_');
        TimeString.ReplaceCharInline('\\', '_');
        TimeString.ReplaceCharInline('/', '_');
        TimeString.ReplaceCharInline(':', '_');

    	writeFile(FPaths::ProfilingDir() + FString::Printf(TEXT("lua_memory_%s.csv"), *TimeString), LMT->MallocList, InNum);
    	writeFile(FPaths::ProfilingDir() + FString::Printf(TEXT("lua_memory_traceback_%s.csv"), *TimeString), LMT->TracebackMallocList, InNum);

    }

#endif

}


void ULuaProfiler::DumpObjectGraph(int InTopNum)
{
#if !UE_BUILD_SHIPPING

    FObjectsCollector* NOCollector = new FObjectsCollector();

    FString TimeString = FPlatformTime::StrTimestamp();
    TimeString.ReplaceCharInline(' ', '_');
    TimeString.ReplaceCharInline('\\', '_');
    TimeString.ReplaceCharInline('/', '_');
    TimeString.ReplaceCharInline(':', '_');

    FString PathToSave = FPaths::ProfilingDir() + FString::Printf(TEXT("ObjectCreationInfo_%s.csv"), *TimeString);

    FArchive* Writer = IFileManager::Get().CreateFileWriter(*PathToSave, EFileWrite::FILEWRITE_EvenIfReadOnly);
    if (Writer == nullptr)
    {
        UE_LOG(LogTemp, Warning, TEXT("Can not create file :%s"), *PathToSave);

        NOCollector->Clean();

        delete NOCollector;
        NOCollector = nullptr;

        return;
    }

    NOCollector->Dump(Writer, InTopNum);

    Writer->Close();
    delete Writer;

    NOCollector->Clean();

    delete NOCollector;
    NOCollector = nullptr;
#endif


}
