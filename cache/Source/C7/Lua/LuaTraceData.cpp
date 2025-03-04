
#if !UE_BUILD_SHIPPING

#include "LuaTraceData.h"

#include "GenericPlatform/GenericPlatformFile.h"
#include "HAL/PlatformFile.h"
#include "HAL/PlatformMisc.h"


#include <time.h>
#include <chrono>
#include <list>

// #include "LuaEnv.h"



static void DebugDumpStack(NS_SLUA::lua_State* L)
{
	using namespace NS_SLUA;
	std::string OutStack;
	int top = lua_gettop(L);
	for (int i = 1; i <= top; i++)
	{
		//printf("%d\t%s\t", i, luaL_typename(L, i));
		OutStack = std::to_string(i) + "\t" + luaL_typename(L, i) + "\t";
		UE_LOG(LogTemp, Log, TEXT("%s\r\n"), UTF8_TO_TCHAR(OutStack.c_str()));
		switch (lua_type(L, i))
		{
		case LUA_TNUMBER:
		{
			//printf("%g\n", lua_tonumber(L, i));
			OutStack = std::to_string(lua_tonumber(L, i));
			UE_LOG(LogTemp, Log, TEXT("%s\r\n"), UTF8_TO_TCHAR(OutStack.c_str()));
			break;
		}
		case LUA_TSTRING:
			//printf("%s\n", lua_tostring(L, i));
			OutStack = std::string(lua_tostring(L, i));
			UE_LOG(LogTemp, Log, TEXT("%s\r\n"), UTF8_TO_TCHAR(OutStack.c_str()));
			break;
		case LUA_TBOOLEAN:
			//printf("%s\n", (lua_toboolean(L, i) ? "true" : "false"));
			OutStack = std::string(lua_toboolean(L, i) ? "true" : "false");
			UE_LOG(LogTemp, Log, TEXT("%s\r\n"), UTF8_TO_TCHAR(OutStack.c_str()));
			break;
		case LUA_TNIL:
			//printf("%s\n", "nil");
			OutStack = "nil\r\n";
			UE_LOG(LogTemp, Log, TEXT("%s\r\n"), UTF8_TO_TCHAR(OutStack.c_str()));
			break;
		default:
			//printf("%p\n", lua_topointer(L, i));
			OutStack = std::to_string(int64(lua_topointer(L, i)));
			UE_LOG(LogTemp, Log, TEXT("%s\r\n"), UTF8_TO_TCHAR(OutStack.c_str()));
			break;
		}
	}
}

static double GetTimeMs() { return std::chrono::high_resolution_clock::now().time_since_epoch().count() * 0.000001; }

void LuaTraceNode::SetFrame(int InFrameID)
{
	if (InFrameID > CurrentFrameID)
	{
		CurrentFrameNode = new LuaTraceTimeNode();
		TimeOfFrames.emplace(InFrameID, CurrentFrameNode);

		CurrentFrameID = InFrameID;
	}
}

LuaTraceTimeNode* LuaTraceNode::GetFrame(int InFrameID)
{
	std::unordered_map<int, LuaTraceTimeNode*>::iterator it = TimeOfFrames.find(InFrameID);
	if (it == TimeOfFrames.end())
	{
		return nullptr;
	}
	else
	{
		return it->second;
	}
}



void LuaTraceNode::Clean()
{
	std::list<LuaTraceNode*> ToDelList;

	std::unordered_map<void*, LuaTraceNode*>::iterator it = Children.begin();
	for (; it != Children.end(); ++it)
	{
		LuaTraceNode* node = it->second;

		if (node->Children.size() == 0)
		{
			delete node;
		}
		else
		{
			node->Clean();
		}
	}

	Children.clear();
}

LuaTraceNode* LuaTraceNode::GetChild(void* InFun)
{
	check(InFun);

	std::unordered_map<void*, LuaTraceNode*>::iterator it = Children.find(InFun);
	if (it == Children.end())
	{
		return nullptr;
	}
	else
	{
		return it->second;
	}
}

LuaTraceNode* LuaTraceNode::GetOrAddChild(void* InFun)
{
	check(InFun);

	std::unordered_map<void*, LuaTraceNode*>::iterator it = Children.find(InFun);
	if (it == Children.end())
	{
		LuaTraceNode* Node = new LuaTraceNode(this);
		Node->SetFun(InFun);
		Children.emplace(InFun, Node);
		return Node;
	}
	else
	{
		return it->second;
	}
}

void LuaTraceNode::SavePath(class FArchive* InWriter, std::string& InOutPath, int InFrameID)
{

	LuaTraceTimeNode* TNode = GetFrame(InFrameID);
	if (TNode == nullptr)
	{
		return;
	}

	std::string NewPath = InOutPath + FunctionName + "[" + std::to_string(TNode->CallCount) + "]";

	uint64 t = uint64(FPlatformTime::ToSeconds64(TNode->CostTime) * 1e6);

	std::string ToSavePath = NewPath + " " + std::to_string(t) + "\r\n";

	InWriter->Serialize((void*)ToSavePath.c_str(), ToSavePath.length());

	NewPath += ";";

	std::unordered_map<void*, LuaTraceNode*>::iterator it = Children.begin();
	for (; it != Children.end(); it++)
	{
		it->second->SavePath(InWriter, NewPath, InFrameID);
	}
}


////////////////////// LuaTrace begin
void LuaTrace::Init()
{
	RootNode = new LuaTraceNode(nullptr);

	CurrentNode = RootNode;
}

void LuaTrace::DeInit()
{
	RootNode->Clean();
	delete RootNode;
	RootNode = nullptr;
}


void LuaTrace::OnHookCall(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* ar)
{
	using namespace NS_SLUA;
	uint64 NowCycle = FPlatformTime::Cycles64();

	//FPlatformProcess::Sleep(1);

	//uint64 NowCycle1 = FPlatformTime::Cycles64();

	//uint64 de = uint64(FPlatformTime::ToSeconds64(NowCycle1 - NowCycle) * 1e6);
	

	lua_getinfo(L, "f", ar);
	void* fun_ptr = const_cast<void*>(lua_topointer(L, -1));
	lua_pop(L, 1);


	//UE_LOG(LogTemp, Warning, TEXT("OnHookCall:%lld %d"), int64(fun_ptr), (ar->event == LUA_HOOKTAILCALL));


	lua_getinfo(L, "nSt", ar);


	auto what_flag = ar->what[0];

	std::string SourceInfo;

	if (what_flag == 'C')
	{
		SourceInfo = "CCode";
	}
	else
	{
		SourceInfo.append(ar->short_src).append(":").append(std::to_string(ar->linedefined));
	}



	std::string FunctionName("Name?");
	if (ar->name)
	{
		FunctionName = ar->name;
	}

	//UE_LOG(LogTemp, Warning, TEXT("OnHookCall addr[%lld] bTail[%d] Func[%s] SourceInfo :%s"), int64(fun_ptr), (ar->event == LUA_HOOKTAILCALL), UTF8_TO_TCHAR(FunctionName.c_str()), UTF8_TO_TCHAR(SourceInfo.c_str()));


	if (fun_ptr == NULL)
	{
		return;
	}

	LuaTraceNode* Node = CurrentNode->GetChild(fun_ptr);
	if (Node == nullptr)
	{
		Node = CurrentNode->GetOrAddChild(fun_ptr);
		check(Node);

		if (ar->event == LUA_HOOKTAILCALL)
		{
			Node->bTailCall = true;
		}

		Node->SetInfo(FunctionName, SourceInfo);
	}

	CurrentNode = Node;
	CurrentNode->SetFrame(CurrentFrame);

	CurrentNode->GetTimeNode()->CallTime = NowCycle;
}

void LuaTrace::OnHookReturn(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* ar)
{
	uint64 NowCycle = FPlatformTime::Cycles64();

	lua_getinfo(L, "f", ar);
	void* fun_ptr = const_cast<void*>(lua_topointer(L, -1));
	lua_pop(L, 1);

	//UE_LOG(LogTemp, Warning, TEXT("OnHookRet SourceInfo :%s"), UTF8_TO_TCHAR(SourceInfo.c_str()));
	//UE_LOG(LogTemp, Warning, TEXT("OnHookRet addr[%lld] bTail[%d] Func[%s] SourceInfo :%s"), int64(fun_ptr), (ar->event == LUA_HOOKTAILCALL), UTF8_TO_TCHAR(FunctionName.c_str()), UTF8_TO_TCHAR(SourceInfo.c_str()));

	if (fun_ptr == NULL)
	{
		return;
	}

	check(CurrentNode);
	if (CurrentNode->GetFun() != fun_ptr)
	{
		return;
	}
	//check(CurrentNode->GetFun() == fun_ptr);

	if (CurrentNode->bTailCall)
	{
		while (CurrentNode != RootNode)
		{
			LuaTraceTimeNode* TN = CurrentNode->GetTimeNode();
			TN->CostTime += (NowCycle - TN->CallTime);
			TN->CallCount++;

			bool bTail = CurrentNode->bTailCall;

			CurrentNode = CurrentNode->GetParent();

			if (bTail == false)
			{
				break;
			}
		}
	}
	else
	{
		LuaTraceTimeNode* TN = CurrentNode->GetTimeNode();
		TN->CostTime += (NowCycle - TN->CallTime);
		TN->CallCount++;
		CurrentNode = CurrentNode->GetParent();
	}
}
void LuaTrace::OnHookSampling(NS_SLUA::lua_State* L, NS_SLUA::lua_Debug* ar)
{

}


struct LTFrameNode
{
	int FrameID;
	double FrameCost;
	LTFrameNode(int InF, double InC)
	{
		FrameID = InF;
		FrameCost = InC;
	}

	bool operator < (LTFrameNode* b)
	{
		return this->FrameCost > b->FrameCost;
	}

	bool operator > (LTFrameNode* b)
	{
		return this->FrameCost < b->FrameCost;
	}

};

bool LTCompare(LTFrameNode* InA, LTFrameNode* InB)
{
	if (InA->FrameCost > InB->FrameCost)
	{
		return true;
	}
	else
	{
		return false;
	}
}



void LuaTrace::SaveData(FArchive* InWriter, int InNum)
{
	std::list<LTFrameNode*> FrameCostList;

	// calc frame cost time
	for (size_t i = 1; i < CurrentFrame + 1; i++)
	{
		LuaTraceTimeNode* RootTimeNode = RootNode->GetFrame(i);
		check(RootTimeNode);

		std::unordered_map<void*, LuaTraceNode*>::iterator it = RootNode->Children.begin();
		for (; it != RootNode->Children.end(); it++)
		{
			LuaTraceNode* CallStackRoot = it->second;
			check(CallStackRoot);

			LuaTraceTimeNode* TimeNode = CallStackRoot->GetFrame(i);
			if (TimeNode)
			{
				RootTimeNode->CostTime += TimeNode->CostTime;
			}
		}

		LTFrameNode* Node = new LTFrameNode(i, RootTimeNode->CostTime);

		FrameCostList.push_back(Node);
	}

	FrameCostList.sort([](LTFrameNode*& a, LTFrameNode*& b) {
		return a->FrameCost > b->FrameCost;
	});


	int i = 1;
	for (std::list<LTFrameNode*>::iterator it1 = FrameCostList.begin(); it1 != FrameCostList.end(); ++it1, i++)
	{
		if (i > 50)
		{
			break;
		}

		int FID = (*it1)->FrameID;

		LuaTraceTimeNode* RootTimeNode = RootNode->GetFrame(FID);
		check(RootTimeNode);

		std::string Path = "Frame_" + std::to_string(FID);

		uint64 t = uint64(FPlatformTime::ToSeconds64(RootTimeNode->CostTime) * 1e6);

		std::string ToSavePath = Path + " " + std::to_string(t) + "\r\n";
		InWriter->Serialize((void*)ToSavePath.c_str(), ToSavePath.length());


		Path += ";";
		std::unordered_map<void*, LuaTraceNode*>::iterator it2 = RootNode->Children.begin();
		for (; it2 != RootNode->Children.end(); it2++)
		{
			LuaTraceNode* CallStackRoot = it2->second;
			check(CallStackRoot);

			CallStackRoot->SavePath(InWriter, Path, FID);
		}
	}

	for (std::list<LTFrameNode*>::iterator it2 = FrameCostList.begin(); it2 != FrameCostList.end(); ++it2)
	{
		delete (*it2);
	}

	FrameCostList.clear();

}

void LuaMemoryTrace::Reset()
{
	for (std::unordered_map<uint64, LuaMemoryNode*>::iterator i = MallocList.begin(); i != MallocList.end() ; i++)
	{
		delete i->second;
	}

	for (std::unordered_map<uint64, LuaMemoryNode*>::iterator i = TracebackMallocList.begin(); i != TracebackMallocList.end() ; i++)
	{
		delete i->second;
	}

	MallocList.clear();

	TracebackMallocList.clear();

	FreeList.clear();
}

LuaMemoryTrace::LuaMemoryTrace(NS_SLUA::lua_State* InL)
{
	L = InL;
}

void LuaMemoryTrace::SaveData(FArchive* InWriter, int InNum, std::unordered_map<uint64, LuaMemoryNode*> InMallocList)
{
	check(InWriter);

	std::list<LuaMemoryNode*> NodeList;
	for (std::unordered_map<uint64, LuaMemoryNode*>::iterator i = InMallocList.begin(); i != InMallocList.end(); i++)
	{
		LuaMemoryNode* node = i->second;

		for (std::list<LuaMallocNode>::iterator i2 = node->MallocNodeList.begin(); i2 != node->MallocNodeList.end(); i2++)
		{
			LuaMallocNode* node2 = &(*i2);
			if (FreeList.find(node2->Addr) != FreeList.end())
			{
				node->FreeCount++;
				node->FreeSize += node2->Size;
			}
		}

		node->RemainSize = node->MallocSize - node->FreeSize;

		NodeList.push_back(i->second);
	}

	NodeList.sort([](LuaMemoryNode*& a, LuaMemoryNode*& b) {
		return a->MallocSize > b->MallocSize;
	});

	if (InNum <= 0)
	{
		InNum = 500;
	}

	FString ToSaveInfo;
	for (size_t i = 0; i < InNum; i++)
	{
		if (NodeList.size() == 0)
		{
			return;
		}
		LuaMemoryNode* node = NodeList.front();

		ToSaveInfo.Reserve(300);
		ToSaveInfo = FString::Printf(TEXT("%s, MallocSize[%d], MallocCount[%d], FreeSize[%d], FreeCount[%d], RemainSize[%d]\r\n"),
			*(node->Key.ToString()), node->MallocSize, node->MallocCount,
			node->FreeSize,node->FreeCount,
			node->RemainSize);
		InWriter->Serialize((void*)(*ToSaveInfo), ToSaveInfo.Len() * 2);

		NodeList.pop_front();
	}
}

static NS_SLUA::lua_State* CL = nullptr;

static int32 GMemoryTrackMaxStackNum = 5;
FAutoConsoleVariableRef CVarLuaProfilerMemoryTrackMaxStackNum(
	TEXT("luaProfiler.MemoryTrackMaxStackNum"),
	GMemoryTrackMaxStackNum,
	TEXT("Max stack number for lua memory trace.\n"),
	ECVF_Default);

void LuaMemoryTrace::fillMemInfo(int i, slua::lua_Debug& ar, void* ptr, int nsize)
{
	std::string Key("\"");
	for (int j = 0; j < GMemoryTrackMaxStackNum; ++j)
	{
		if (lua_getstack(L, i + j, &ar) != 0 && lua_getinfo(L, "Sln", &ar))
		{
			if (j > 0) Key += "\r\n";
			Key += std::string(ar.name == nullptr ? "NName" : ar.name) + std::string("_") + std::string(ar.source) + std::string("_") + std::to_string(ar.currentline);
		}
		else break;
	}
	Key +="\"";
	FName NameKey = FName(UTF8_TO_TCHAR(Key.c_str()));
	uint64 ikey = NameKey.ToUnstableInt();

	std::unordered_map<uint64, LuaMemoryNode*>::iterator it = TracebackMallocList.find(ikey);
	if (it == TracebackMallocList.end())
	{
		LuaMemoryNode* Node = new LuaMemoryNode(NameKey);
		Node->Add(ptr, nsize);
		TracebackMallocList.emplace(ikey, Node);
	}
	else
	{
		LuaMemoryNode* Node = it->second;
		Node->Add(ptr, nsize);
	}
}

void LuaMemoryTrace::OnMalloc(void* ptr, int nsize)
{
	using namespace NS_SLUA;
	if (L == nullptr)
	{
		return;
	}

	 lua_Debug ar;
	 int level = 0;
	
	 // free
	 if (nsize == 0)
	 {
	 	if (FreeList.find(ptr) == FreeList.end())
	 	{
	 		FreeList.emplace(ptr, ptr);
	 	}
	 }
	 else
	 {
	 	std::string Key("None");
	
	 	while (lua_getstack(L, level, &ar) != 0)
	 	{
	 		level++;
	 		lua_getinfo(L, "Sln", &ar);
	
	 		// the first time
	 		if (level == 1)
	 		{
	 			Key = std::string(ar.name == 0 ? "None" : ar.name) + std::string("_");
	 		}
	
	 		if (ar.currentline != -1)
	 		{
	 			if (level == 1)
	 			{
	 				Key = std::string(ar.name == 0 ? "NName" : ar.name) + std::string("_") + std::string(ar.short_src == 0 ? "NSrc" : ar.short_src) + std::string("_") + std::to_string(ar.currentline) + std::string("#");
	 			}
	 			else
	 			{
	 				Key += std::string(ar.name == 0 ? "NName" : ar.name) + std::string("_") + std::string(ar.short_src == 0 ? "NSrc" : ar.short_src) + std::string("_") + std::to_string(ar.currentline) + std::string("#");
	 			}
	
	 			if (ar.namewhat && strcmp(ar.namewhat, "metamethod") == 0)
	 			{
	 				check(true);
	 			}
	 			else
	 			{
	 				if (strcmp(ar.what, "Lua") == 0 || strcmp(ar.what, "main") == 0)
	 				{
	 					fillMemInfo(level - 1, ar, ptr, nsize);
	 				}
	 				break;
	 			}
	 		}
	 		else
	 		{
	 			if (level == 1)
	 			{
	 				Key = std::string(ar.name == 0 ? "NName" : ar.name) + std::string("_") + std::string(ar.short_src == 0 ? "NSrc" : ar.short_src) + std::string("#");
	 			}
	 			else
	 			{
	 				Key += std::string(ar.name == 0 ? "NName" : ar.name) + std::string("_") + std::string(ar.short_src == 0 ? "NSrc" : ar.short_src) + std::string("#");
	 			}
	
	 		}
	 	}
	
	
	 	FName NameKey = FName(UTF8_TO_TCHAR(Key.c_str()));
	 	uint64 ikey = NameKey.ToUnstableInt();
	 	std::unordered_map<uint64, LuaMemoryNode*>::iterator it = MallocList.find(ikey);
	
	 	if (it == MallocList.end())
	 	{
	 		LuaMemoryNode* Node = new LuaMemoryNode(NameKey);
	 		Node->Add(ptr, nsize);
	 		MallocList.emplace(ikey, Node);
	 	}
	 	else
	 	{
	 		LuaMemoryNode* Node = it->second;
	 		Node->Add(ptr, nsize);
	 	}
	
	 }
}

/////////////////////////////////////////////////// begin
//



FObjPath::FObjPath(FString& InItem, FString InClassName)
{
	ClassName = InClassName;
	AddNew(InItem);

}

void FObjPath::AddNew(FString& InItem)
{
	int idx = OutPath.Find(InItem);
	if (idx == -1)
	{
		idx = OutPath.Add(InItem);
		Num.AddZeroed();
		Num[idx] += 1;
	}
	else
	{
		Num[idx] += 1;
	}
	TotalNum += 1;
}

FPackageNode::FPackageNode(const UPackage* InPKG)
{
	PackName = InPKG->GetPathName();

	TypeList.Reserve(1000);
	TypeNum.Reserve(1000);
	ObjList.Reserve(1000);
}

void FPackageNode::AddOrUpdate(const UObject* InOBJ)
{
	FString TypeName = InOBJ->GetClass()->GetName();
	int idx = TypeList.Find(TypeName);
	if (idx == -1)
	{
		idx = TypeList.Add(TypeName);
		TypeNum.AddZeroed();
	}

	TypeNum[idx] += 1;


	ObjList.Add(InOBJ->GetPathName());
}


void FObjectsCollector::CollectObject(const UObject* InObject)
{
	if (InObject == nullptr)
	{
		return;
	}

	const UClass* UC = InObject->GetClass();
	if (UC == nullptr)
	{
		return;
	}

	UObject* OT = InObject->GetOuter();
	FString NewOutPath = OT->GetFullName();
	//NewOutPath.Reserve(300);
	//while (OT)
	//{
	//	NewOutPath += OT->GetPathName() + FString(TEXT("@"));
	//	OT = OT->GetOuter();
	//}

	std::unordered_map<void*, FObjPath*>::iterator it = ObjCreationMap.find((void*)UC);
	if (it == ObjCreationMap.end())
	{
		FObjPath* NewPath = new FObjPath(NewOutPath, UC->GetName());
		ObjCreationMap.emplace((void*)UC, NewPath);
	}
	else
	{
		it->second->AddNew(NewOutPath);
	}


	UPackage* pkg = InObject->GetPackage();
	std::unordered_map<void*, FPackageNode*>::iterator it2 = PackagesMap.find(pkg);
	if (it2 == PackagesMap.end())
	{
		FPackageNode* PN = new FPackageNode(pkg);
		PN->AddOrUpdate(InObject);
		PackagesMap.emplace(pkg, PN);
	}
	else
	{
		it2->second->AddOrUpdate(InObject);
	}
}

void FObjectsCollector::Clean()
{
	for (std::unordered_map<void*, FObjPath*>::iterator i = ObjCreationMap.begin(); i != ObjCreationMap.end(); i++)
	{
		delete i->second;
	}

	ObjCreationMap.clear();

	for (std::unordered_map<void*, FPackageNode*>::iterator i = PackagesMap.begin(); i != PackagesMap.end(); i++)
	{
		delete i->second;
	}

	PackagesMap.clear();
}


void FObjectsCollector::Dump(FArchive* InWriter, int InTopNum)
{
	for (TObjectIterator<UObject> It; It; ++It)
	{
		CollectObject(*It);
	}


	std::list<FObjPath*> NodeList;
	for (std::unordered_map<void*, FObjPath*>::iterator i = ObjCreationMap.begin(); i != ObjCreationMap.end(); i++)
	{
		FObjPath* OP = i->second;
		NodeList.push_back(OP);
	}

	NodeList.sort([](FObjPath*& a, FObjPath*& b) {
		return a->TotalNum > b->TotalNum;
	});


	int nCount = InTopNum;
	while (NodeList.empty() == false && nCount > 0)
	{
		FObjPath* OP = NodeList.front();
		FString TypeInfo = FString::Printf(TEXT("%s, %d, , , , , , , \t\r"), *(OP->ClassName), OP->TotalNum);
		InWriter->Serialize((void*)*TypeInfo, sizeof(TCHAR) * TypeInfo.Len());
		for (int i = 0; i < OP->OutPath.Num(); ++i)
		{
			FString ItemInfo = OP->OutPath[i].Replace(TEXT("@"), TEXT(","));
			ItemInfo = FString::Printf(TEXT(", ,%d, %s\t\r"), OP->Num[i], *ItemInfo);
			InWriter->Serialize((void*)*ItemInfo, sizeof(TCHAR) * ItemInfo.Len());
		}

		NodeList.pop_front();
		nCount -= 1;
	}


	std::list<FPackageNode*> NodeList2;
	for (std::unordered_map<void*, FPackageNode*>::iterator i = PackagesMap.begin(); i != PackagesMap.end(); i++)
	{
		FPackageNode* OP = i->second;
		NodeList2.push_back(OP);
	}

	NodeList2.sort([](FPackageNode*& a, FPackageNode*& b) {
		return a->ObjList.Num() > b->ObjList.Num();
	});

	FString NewLine;
	NewLine.Reserve(1000);
	NewLine = FString(TEXT("Package Infos:, , , \t\r"));
	nCount = InTopNum;
	while (NodeList2.empty() == false && nCount > 0)
	{
		FPackageNode* PN = NodeList2.front();
		NewLine = FString::Printf(TEXT(", PKG Name %s, ObjCount:%d, ClassCount:%d\t\r"), *(PN->PackName), PN->ObjList.Num(), PN->TypeList.Num());
		InWriter->Serialize((void*)*NewLine, sizeof(TCHAR) * NewLine.Len());

		NewLine = FString::Printf(TEXT(", ClassInfo:\t\r"));
		InWriter->Serialize((void*)*NewLine, sizeof(TCHAR) * NewLine.Len());
		for (size_t i = 0; i < PN->TypeList.Num(); i++)
		{
			NewLine = FString::Printf(TEXT(", , Class:%s, Num:%d\t\r"), *(PN->TypeList[i]), PN->TypeNum[i]);
			InWriter->Serialize((void*)*NewLine, sizeof(TCHAR) * NewLine.Len());
		}

		NewLine = FString::Printf(TEXT(", ObjInfo:\t\r"));
		InWriter->Serialize((void*)*NewLine, sizeof(TCHAR) * NewLine.Len());
		for (size_t i = 0; i < PN->ObjList.Num(); i++)
		{
			NewLine = FString::Printf(TEXT(", , %s\t\r"), *(PN->ObjList[i]));
			InWriter->Serialize((void*)*NewLine, sizeof(TCHAR) * NewLine.Len());
		}

		NodeList2.pop_front();
		nCount -= 1;
	}


}



#endif

