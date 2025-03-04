#pragma once

#if !UE_BUILD_SHIPPING 
#include "HAL/LowLevelMemTracker.h"

// 仅在开启tracker时候创建
#if ENABLE_LOW_LEVEL_MEM_TRACKER
LLM_DECLARE_TAG(C7LuaMem);
#define C7LUAMEM_TAG PREPROCESSOR_JOIN(LLMTagDeclaration_, C7LuaMem).GetUniqueName()
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"


namespace C7
{
	class LuaInsightTraceNode
	{
	protected:
		LuaInsightTraceNode* ParentNode = nullptr;

		void* FunctionAddress = nullptr;
		FString FunctionName;
		FString SourceInfo;
		int LineNumber = 0;

#if ENABLE_LOW_LEVEL_MEM_TRACKER
		FLLMScope* LLMTracer = nullptr;
#endif

	public:
		bool bTailCall = false;
		LuaInsightTraceNode()
		{
		}

		void SetInfo(const FString& InFuncitonName, const FString& InSourceInfo, int InLineNo)
		{
			FunctionName = InFuncitonName;
			SourceInfo = InSourceInfo;

			// FunctionName += "|" + SourceInfo;
			LineNumber = InLineNo;
		}

		void SetFun(void* InFun)
		{
			FunctionAddress = InFun;
		}

		LuaInsightTraceNode* GetParent() const { return ParentNode; }
		void SetParent(LuaInsightTraceNode* p) { ParentNode = p; }
		void* GetFun() const { return FunctionAddress; }

		void OnCall();
		void OnRet();
		void OnMalloc(void* Ptr, int nSize);

		// 对象缓存
		void OnNew();
		void OnFree();

		// 重置
		void ResetObject();
	};

	// 配合UE的UnrealInsights的简易profiler，后续可以看看怎么扩展？
	class LuaInsightTracer
	{
	protected:
		LuaInsightTraceNode* RootNode = nullptr;
		LuaInsightTraceNode* CurrentNode = nullptr;

	public:
		void Init();
		void DeInit();

		void NextFrame();

		void OnHookCall(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* ar);
		void OnHookReturn(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* ar);
		void OnHookSampling(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* ar);
		void OnMalloc(void* Ptr, int nSize);
	};
	
}

#endif