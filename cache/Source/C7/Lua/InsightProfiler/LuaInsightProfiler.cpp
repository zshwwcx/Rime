#include "LuaInsightProfiler.h"

#include "Misc/FileHelper.h"
#include "HAL/PlatformMisc.h"
#include "HAL/FileManager.h"
#include "Kismet/KismetSystemLibrary.h"

#if !UE_BUILD_SHIPPING
#include "LuaInsightTracer.h"
#endif

//extern "C"
//{
	#include "lua.h"
	#include "lualib.h"
	#include "lauxlib.h"
//}

extern SLUA_UNREAL_API void (*GLuaMallocCallBack)(void* InAddr, int InSize);
#if !UE_BUILD_SHIPPING
C7::LuaInsightTracer* C7Profiler = nullptr;
void SLuaMallocCallBack(void* InAddr, int InSize)
{
    if (C7Profiler)
    {
        C7Profiler->OnMalloc(InAddr, InSize);
    }
}
#endif

static void SLuaHooker(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* par)
{
#if !UE_BUILD_SHIPPING
    switch (par->event)
    {
    case LUA_HOOKCALL:
    case LUA_HOOKTAILCALL:
    {
        C7Profiler->OnHookCall(L, par);
        break;
    }
    case LUA_HOOKRET:
    {
        C7Profiler->OnHookReturn(L, par);
        break;
    }
    case LUA_HOOKCOUNT:
    {
        C7Profiler->OnHookSampling(L, par);
        break;
    }
    default:
        break;
    }
#endif
}

static void SLuaGCHooker(NS_SLUA::lua_State* L, int gcstate, char bStart)
{
#if CPUPROFILERTRACE_ENABLED
    if (bStart)
    {
        const auto EventName = FString::Printf(TEXT("[C7LUA] lua_gc [gcstate:%d]"), gcstate);
        FCpuProfilerTrace::OutputBeginDynamicEvent(*EventName);
    }
    else
    {
        FCpuProfilerTrace::OutputEndEvent();
    }
#endif
}

void ULuaInsightProfiler::Start()
{
#if !UE_BUILD_SHIPPING
    if (bRunning == false)
    {
        bRunning = true;

        C7Profiler = new C7::LuaInsightTracer();
        C7Profiler->Init();

        SetHook();
    }
#endif
}

void ULuaInsightProfiler::Stop()
{
#if !UE_BUILD_SHIPPING
    if (bRunning == true)
    {
        bRunning = false;

        ResetHook();

        C7Profiler->DeInit();
        delete C7Profiler;
        C7Profiler = nullptr;
    }
#endif
}

void ULuaInsightProfiler::Tick(float DeltaTime) 
{
#if !UE_BUILD_SHIPPING
    if (bRunning)
    {
        C7Profiler->NextFrame();
    }
#endif

}

void ULuaInsightProfiler::SetHook()
{
#if !UE_BUILD_SHIPPING
    if (!bHook)
    {
	    if(NS_SLUA::LuaState* State = GetLuaState())
    	{
    		NS_SLUA::lua_State* L = State->getLuaState();
    		check(L);
    		lua_sethook(L, SLuaHooker, LUA_MASKCALL | LUA_MASKRET, 0);
    		lua_setgchook(L, SLuaGCHooker);
    		GLuaMallocCallBack = &SLuaMallocCallBack;
    		bHook = true;
    	}
    }
#endif
}

void ULuaInsightProfiler::ResetHook()
{
#if !UE_BUILD_SHIPPING
    if (bHook)
    {
    	if(NS_SLUA::LuaState* State = GetLuaState())
    	{
    		NS_SLUA::lua_State* L = State->getLuaState();
    		check(L);
    		lua_sethook(L, 0, 0, 0);
    		lua_setgchook(L,0);
    	}
    }
    GLuaMallocCallBack = nullptr;
    bHook = false;
#endif
}

NS_SLUA::LuaState* ULuaInsightProfiler::GetLuaState() const
{
	NS_SLUA::LuaState* State = nullptr;
	UGameInstance* GI = NS_SLUA::LuaState::getObjectGameInstance(this);
	if (GI && NS_SLUA::LuaState::get(GI))
	{
		State = NS_SLUA::LuaState::get(GI);
	}
	else
	{
		State = NS_SLUA::LuaState::get();
	}
	return State;
}
