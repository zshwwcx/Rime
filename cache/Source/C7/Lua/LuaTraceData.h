#pragma once

#if !UE_BUILD_SHIPPING

#include "CoreMinimal.h"
#include "GenericPlatform/GenericPlatformFile.h"
#include "HAL/PlatformFile.h"
#include "HAL/PlatformMisc.h"

#include <list>
#include <string>
#include <unordered_map>


#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"


class LuaTrace;


struct LuaTraceTimeNode
{
	uint64 CallTime = 0;
	uint64 CostTime = 0;
	int CallCount = 0;

	LuaTraceTimeNode()
	{
		CallTime = 0;
		CostTime = 0;
		CallCount = 0;
	}
};

class LuaTraceNode
{
public:

	LuaTrace* LT = nullptr;

	LuaTraceNode* ParentNode = nullptr;

	LuaTraceTimeNode* CurrentFrameNode = nullptr;

	void* FunctionAddress = nullptr;

	std::string FunctionName;
	std::string SourceInfo;
	int CurrentFrameID = -1;

	int MallocSize = 0;
	int MallocCount = 0;
	int FreeSize = 0;

	// key : frame id
	std::unordered_map<int, LuaTraceTimeNode*> TimeOfFrames;

	std::unordered_map<void*, LuaTraceNode*> Children;


public:

	bool bTailCall = false;

	LuaTraceNode(LuaTraceNode* InParentNode)
	{
		ParentNode = InParentNode;
	}

	LuaTraceNode(const char* InFuncitonName, const char* InSourceInfo, int InFrameID)
	{
		FunctionName = std::string(InFuncitonName);
		SourceInfo = std::string(InSourceInfo);
	}

	LuaTraceNode* GetChild(void* InFun);
	LuaTraceNode* GetOrAddChild(void* InFun);

	LuaTraceTimeNode* GetTimeNode() { return CurrentFrameNode; }

	void SetInfo(std::string& InFuncitonName, std::string& InSourceInfo)
	{
		FunctionName = InFuncitonName;
		SourceInfo = InSourceInfo;

		FunctionName += "|" + SourceInfo;
	}

	void SetFun(void* InFun)
	{
		FunctionAddress = InFun;
	}

	LuaTraceNode* GetParent() { return ParentNode; }


	void* GetFun() { return FunctionAddress; }


	void SetFrame(int InFrameID);
	LuaTraceTimeNode* GetFrame(int InFrameID);

	void OnCall();
	void OnRet();

	void OnMalloc(void* Ptr, int nSize);

	void Clean();

	void SavePath(FArchive* InWriter, std::string& InPath, int InFrameID);
};


class LuaTrace
{
	LuaTraceNode* RootNode = nullptr;
	LuaTraceNode* CurrentNode = nullptr;
	int CurrentFrame = 0;

public:
	void Init();
	void DeInit();

	void NewFrame()
	{
		CurrentFrame++;
		RootNode->SetFrame(CurrentFrame);
	}
	int GetFrame();

	void SaveData(FArchive* InWriter, int InNum);


	void OnHookCall(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* ar);
	void OnHookReturn(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* ar);
	void OnHookSampling(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* ar);

};


struct LuaMallocNode
{
	void* Addr = nullptr;
	int16 Size;

	LuaMallocNode(void* InAddr, int16 InSize)
	{
		Addr = InAddr;
		Size = InSize;
	}
};

struct LuaMemoryNode
{
	FName Key;
	int RemainSize = 0;
	int MallocSize = 0;
	int MallocCount = 0;
	int FreeSize = 0;
	int FreeCount = 0;

	std::list<LuaMallocNode> MallocNodeList;

	LuaMemoryNode(FName InKey)
	{
		Key = InKey;
	}

	void Add(void* InAddr, int16 InSize)
	{
		LuaMallocNode Node(InAddr, InSize);
		MallocNodeList.push_back(Node);
		MallocSize += InSize;
		MallocCount++;
	}
};

class LuaMemoryTrace
{
public:
	std::unordered_map<uint64, LuaMemoryNode*> MallocList;
	std::unordered_map<uint64, LuaMemoryNode*> TracebackMallocList;
	std::unordered_map<void*, void*> FreeList;

	LuaMemoryTrace(NS_SLUA::lua_State* InL);

	void Reset();
	void SaveData(FArchive* InWriter, int InNum, std::unordered_map<uint64, LuaMemoryNode*> InMallocList);
	void OnMalloc(void* ptr, int nsize);

private:
	NS_SLUA::lua_State* L = nullptr;
	void fillMemInfo(int i, slua::lua_Debug& ar, void* ptr, int nsize);

};


/// <summary>
/// //////////////
/// </summary>
/// 

struct FObjPath
{
	TArray<FString> OutPath;
	TArray<int32> Num;

	int32 TotalNum = 0;
	FString ClassName;

	FObjPath() {}
	FObjPath(FString& InItem, FString InClassName);
	void AddNew(FString& InItem);
};


struct FPackageNode
{
	FString PackName;
	TArray<FString> TypeList;
	TArray<int32> TypeNum;
	TArray<FString> ObjList;

	FPackageNode(const UPackage* InPKG);
	void AddOrUpdate(const UObject* InOBJ);
};

class FObjectsCollector
{
public:

	FObjectsCollector() {}


	void Dump(FArchive* InWriter, int InTopNum);
	void Clean();

private:
	std::unordered_map<void*, FObjPath*> ObjCreationMap;
	std::unordered_map<void*, FPackageNode*> PackagesMap;

	void CollectObject(const UObject* InObject);





};


#endif
