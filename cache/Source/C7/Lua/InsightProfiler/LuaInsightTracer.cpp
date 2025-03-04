#if !UE_BUILD_SHIPPING

#include "LuaInsightTracer.h"
#include "GenericPlatform/GenericPlatformFile.h"
#include "HAL/PlatformFile.h"
#include "HAL/PlatformMisc.h"

#include <string>
#include <time.h>
#include <chrono>
#include <list>

#if ENABLE_LOW_LEVEL_MEM_TRACKER
LLM_DEFINE_TAG(C7LuaMem);
#endif

using namespace C7;

// 简易对象缓存池
template<typename T>
class SimpleObjectCache 
{
protected:
	int CacheSize = 0;
	int CacheIncrCount = 1000;
	int CacheFree = -1;
	T** Objects = nullptr;
public:
	static SimpleObjectCache& GetInstance()
	{
		static SimpleObjectCache inst;
		return inst;
	}
	T* New()
	{
		if (CacheFree < 0)
		{
			return new T();
		}
		auto ret = Objects[CacheFree];
		ret->OnNew();
		CacheFree--;
		return ret;
	}
	void Free(T* obj)
	{
		obj->OnFree();
		if (CacheFree >= CacheSize || CacheSize == 0)
		{
			int newCount = CacheSize + CacheIncrCount;
			T** newObj = new T*[newCount];
			FMemory::Memcpy(newObj, Objects, CacheSize);
			CacheSize = newCount;
			delete Objects;
			Objects = newObj;
		}
		CacheFree++;
		Objects[CacheFree] = obj;
	}
	void ResetAll()
	{
		for (int i = 0;i <= CacheFree; ++i)
		{
			delete Objects[i];
		}
		CacheSize = 0;
		CacheFree = -1;
		if (Objects != nullptr) delete Objects;
		Objects = nullptr;
	}
};

void LuaInsightTraceNode::OnCall()
{
#if CPUPROFILERTRACE_ENABLED
	const auto EventName = FString::Printf(TEXT("[C7LUA] %s [%s:%d]"), FunctionName.Len() > 0 ? *FunctionName : TEXT("N/A"), *SourceInfo, LineNumber);
	FCpuProfilerTrace::OutputBeginDynamicEvent(*EventName);
#endif
#if ENABLE_LOW_LEVEL_MEM_TRACKER
	if (LLMTracer == nullptr)
	{
		LLMTracer = new FLLMScope(C7LUAMEM_TAG, false, ELLMTagSet::None, ELLMTracker::Default);
	}
#endif
}
void LuaInsightTraceNode::OnRet()
{
#if ENABLE_LOW_LEVEL_MEM_TRACKER
	if (LLMTracer != nullptr)
	{
		delete LLMTracer;
		LLMTracer = nullptr;
	}
#endif
#if CPUPROFILERTRACE_ENABLED
	FCpuProfilerTrace::OutputEndEvent();
#endif
}
void LuaInsightTraceNode::OnNew()
{
	ParentNode = nullptr;
	FunctionAddress = nullptr;
	// FunctionName;
	// SourceInfo;
	LineNumber = 0;

#if ENABLE_LOW_LEVEL_MEM_TRACKER
	LLMTracer = nullptr;
#endif

	bTailCall = false;
}
void LuaInsightTraceNode::OnFree()
{
	
}
void LuaInsightTraceNode::OnMalloc(void* Ptr, int nSize)
{
	
}

void LuaInsightTraceNode::ResetObject()
{
	// 重置，可能放入对象池，把自己的tracker也清空一下，这个不能用对象池，因为依赖于析构去调用底层函数
#if ENABLE_LOW_LEVEL_MEM_TRACKER
	if (LLMTracer != nullptr)
	{
		delete LLMTracer;
		LLMTracer = nullptr;
	}
#endif
#if CPUPROFILERTRACE_ENABLED
	FCpuProfilerTrace::OutputEndEvent();
#endif
}

////////////////////// LuaTrace begin
void LuaInsightTracer::Init()
{
	RootNode = new LuaInsightTraceNode();
	CurrentNode = RootNode;
}

void LuaInsightTracer::DeInit()
{
	while (CurrentNode != RootNode && CurrentNode != nullptr)
	{
		auto node = CurrentNode;
		CurrentNode = CurrentNode->GetParent();
		node->ResetObject();
		delete node;
	}
	delete RootNode;
	RootNode = nullptr;
	CurrentNode = nullptr;
	SimpleObjectCache<LuaInsightTraceNode>::GetInstance().ResetAll();
}

void LuaInsightTracer::NextFrame()
{
	// 释放一下内存
	while (CurrentNode != RootNode && CurrentNode != nullptr)
	{
		auto node = CurrentNode;
		CurrentNode = CurrentNode->GetParent();
		node->ResetObject();
		SimpleObjectCache<LuaInsightTraceNode>::GetInstance().Free(node);
	}
}

void LuaInsightTracer::OnMalloc(void* Ptr, int nSize)
{
	if (CurrentNode)
	{
		CurrentNode->OnMalloc(Ptr, nSize);
	}
}

void LuaInsightTracer::OnHookCall(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* ar)
{
	using namespace NS_SLUA;
	lua_getinfo(L, "f", ar);
	void* fun_ptr = const_cast<void*>(lua_topointer(L, -1));
	lua_pop(L, 1);
	
	lua_getinfo(L, "nStl", ar);
	
	auto what_flag = ar->what[0];

	FString SourceInfo;
	int LineNo = -1;

	if (what_flag == 'C')
	{
		SourceInfo = "CCode";
	}
	else
	{
		LineNo = ar->currentline;
		SourceInfo.Append(ar->short_src).Append(":").AppendInt(ar->linedefined);
	}

	FString FunctionName("Name?");
	if (ar->name)
	{
		FunctionName = ar->name;
	}

	if (fun_ptr == nullptr
		|| FunctionName == "ProfileCPUBegin"
		|| FunctionName == "ProfileCPUEnd")
	{
		return;
	}

	LuaInsightTraceNode* Node = SimpleObjectCache<LuaInsightTraceNode>::GetInstance().New();
	Node->SetParent(CurrentNode);
	Node->SetFun(fun_ptr);
	Node->SetInfo(FunctionName, SourceInfo, LineNo);
	if (ar->event == LUA_HOOKTAILCALL)
	{
		Node->bTailCall = true;
	}

	CurrentNode = Node;
	CurrentNode->OnCall();
}

void LuaInsightTracer::OnHookReturn(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* ar)
{
	using namespace NS_SLUA;
	lua_getinfo(L, "f", ar);
	void* fun_ptr = const_cast<void*>(lua_topointer(L, -1));
	lua_pop(L, 1);

	if (fun_ptr == nullptr)
	{
		return;
	}

	check(CurrentNode);
	if (CurrentNode->GetFun() != fun_ptr)
	{
		return;
	}
	
	if (CurrentNode->bTailCall)
	{
		while (CurrentNode != RootNode)
		{
			bool bTail = CurrentNode->bTailCall;

			CurrentNode->OnRet();
			auto node = CurrentNode;
			CurrentNode = CurrentNode->GetParent();
			SimpleObjectCache<LuaInsightTraceNode>::GetInstance().Free(node);

			if (bTail == false)
			{
				break;
			}
		}
	}
	else
	{
		CurrentNode->OnRet();
		auto node = CurrentNode;
		CurrentNode = CurrentNode->GetParent();
		SimpleObjectCache<LuaInsightTraceNode>::GetInstance().Free(node);
	}
}
void LuaInsightTracer::OnHookSampling(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* ar)
{

}
#endif

