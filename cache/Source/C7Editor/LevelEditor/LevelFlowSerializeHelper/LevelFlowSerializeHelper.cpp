#include "LevelFlowSerializeHelper.h"

#include "EdGraphNode_Comment.h"
#include "LevelFlowGraph.h"
#include "LevelFlowGraphSchema.h"
#include "LevelLuaEditorProxyBase.h"

#include "SLevelFlowEditor.h"
#include "SourceControlHelpers.h"
#include "Camera/CameraActor.h"
#include "Dom/JsonObject.h"
#include "Engine/Light.h"
#include "FileAsset/LuaSerializeHelper.h"
#include "EditorProxy/LevelLuaEditorProxy.h"
#include "C7Editor.h"
#include "LevelEditor/LevelEditorView/LevelEditorViewExtend.h"

#include "lua/lua.hpp"
#include "LuaState.h"



#pragma region Serialize

void FLevelFlowSerializeHelper::SerializeLevelFlow(ULevelFlow* LevelFlow, const FString LevelName, const FString GroupName, const FString TemplateName)
{
	if (!TemplateName.IsEmpty())
	{
		return;
	}
	// 初始化LevelFlow,转化数据和建立结点映射关系
	// TSharedPtr<FLevelFlowToolKit> LevelFlowToolKit = MakeShareable(new FLevelFlowToolKit);
	// LevelFlowToolKit->Init("", "");
	//
	// if (!LevelFlow)
	// {
	// 	LevelFlow = FLevelFlowExportHelper::GetExportedLevelFlow();
	// }

	if (!LevelFlow)
	{
		UE_LOG(LogTemp, Error, TEXT("%s GetExportedLevelFlow failed"), *FString(__FUNCTION__));
		return;
	}

	TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject());

	// 排序
	// LevelFlow->FlowNodes.Sort();

	// 序列化业务结点
	TSharedPtr<FJsonObject> NodeListJsonObject = MakeShareable(new FJsonObject());
	for (auto Node : LevelFlow->FlowNodes)
	{
		FString NodeName = Node->IsA(ULevelFlowRootNode::StaticClass()) ? "Root" : Node->GetName();
		NodeListJsonObject->SetField(NodeName, SerializeOneNode(Node));
	}
	
	// 排序
	NodeListJsonObject->Values.KeySort([](const FString& A, const FString& B)
	{
		return A < B;
	});
	
	JsonObject->SetField("FlowNodes", MakeShareable(new FJsonValueObject(NodeListJsonObject)));

	// 序列化注释结点
	JsonObject->SetField("Comments", SerializeCommentNodes(LevelFlow->FlowGraph));

	// 转化为Lua
	const FString ResultLua = "return {\n" + FLuaSerializeHelper::JsonValueToLua_Implementation(JsonObject) + "}\n";

	// 写文件 + CheckOut
	// const UWorld* World = GEditor->GetEditorWorldContext().World();
	// const FString FileName = World->GetCurrentLevel()->GetOuter()->GetName();
	// const FString FilePath = FPaths::ProjectContentDir() + "Script/Data/Config/LevelFlowData/" + LevelName + "/LF_" + FileName + ".lua";
	const FString FilePath = FPaths::ProjectContentDir() + "Script/Data/Config/LevelFlowData/" + LevelName + "/LF_" + GroupName + ".lua";
	const FString AbsFilePath = FPaths::ConvertRelativePathToFull(FilePath);
	FFileHelper::SaveStringToFile(ResultLua, *AbsFilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM, &IFileManager::Get(), FILEWRITE_EvenIfReadOnly);
	FText ErrorMessage;
	SourceControlHelpers::CheckoutOrMarkForAdd(AbsFilePath, FText::FromString(AbsFilePath), nullptr, ErrorMessage);
	SourceControlHelpers::RevertUnchangedFile(AbsFilePath);

	// 检查配表合法性
	FString Result = ULevelEditorLuaObj::CheckLevelFlowData();
	if (!Result.IsEmpty())
	{
		FText Message = FText::FromString(TEXT("结点参数配置有误, 请检查下方结点所配参数是否和Excel表格中的数据匹配/n") + Result);
		FMessageDialog::Open(EAppMsgType::Ok, Message);
	}
}

TSharedPtr<FJsonValue> FLevelFlowSerializeHelper::SerializeOneNode(ULevelFlowActionNode* Node)
{
	const TSharedPtr<FJsonObject> JsonObject = MakeShared<FJsonObject>();
	JsonObject->SetField("TriggerInfo", SerializeTrigger(Node->TriggerNode));
	JsonObject->SetField("ConditionsInfo", SerializeCondition(Node));
	JsonObject->SetField("ActionInfo", SerializeAction(Node));
	JsonObject->SetField("NextNodes", SerializeNextNodes(Node));
	JsonObject->SetField("GraphInfo", SerializeGraphNode(Node->GraphNode.Get()));
	return MakeShareable(new FJsonValueObject(JsonObject));
}

TSharedPtr<FJsonValue> FLevelFlowSerializeHelper::SerializeTrigger(ULevelFlowTriggerNode* TriggerNode)
{
	const TSharedPtr<FJsonObject> JsonObject = MakeShared<FJsonObject>();
	if (TriggerNode)
	{
		FString TriggerNodeID = TriggerNode->GetName();
		FString TriggerType = TriggerNode->GetClass()->GetName();
		TriggerType = TriggerType.Mid(0, TriggerType.Len() - 2);
		JsonObject->SetField("TriggerNodeID", MakeShared<FJsonValueString>(TriggerNodeID));
		JsonObject->SetField("TriggerType", MakeShared<FJsonValueString>(TriggerType));
		JsonObject->SetField("BPClass", MakeShared<FJsonValueString>(TriggerNode->GetClass()->GetPathName()));
		JsonObject->SetField("bIsLoop", MakeShared<FJsonValueBoolean>(TriggerNode->bIsLoop));
		for (FProperty* Property : TFieldRange<FProperty>(TriggerNode->GetClass(), EFieldIteratorFlags::ExcludeSuper))
		{
			if (!NeedExport(Property))
			{
				continue;
			}
			void* Address = Property->ContainerPtrToValuePtr<void>(TriggerNode);
			JsonObject->SetField(Property->GetName(), FLuaSerializeHelper::ExportFProperty(Property, Address));
		}
	}
	return MakeShareable(new FJsonValueObject(JsonObject));
}

TSharedPtr<FJsonValue> FLevelFlowSerializeHelper::SerializeCondition(ULevelFlowActionNode* ActionNode)
{
	TArray<FLevelFlowConditionInfo> ConditionInfos;
	if (ActionNode->DefaultCondition)
	{
		ConditionInfos.Add(FLevelFlowConditionInfo(ELFCondLogic::AND, ActionNode->DefaultCondition));
		for (auto ConditionInfo : ActionNode->ConditionInfos)
		{
			ConditionInfos.Add(FLevelFlowConditionInfo(ConditionInfo.Logic, ConditionInfo.Condition));
		}
	}

	TArray<TSharedPtr<FJsonValue>> JsonArray;
	for (auto ConditionInfo : ConditionInfos)
	{
		const TSharedPtr<FJsonObject> JsonObject = MakeShared<FJsonObject>();
		FString ConditionNodeID = ConditionInfo.Condition->GetName();
		FString ConditionType = ConditionInfo.Condition->GetClass()->GetName();
		ConditionType = ConditionType.Mid(0, ConditionType.Len() - 2);
		const UEnum* EnumType = StaticEnum<ELFCondLogic>();
		FString Logic = *EnumType->GetDisplayNameTextByValue(static_cast<uint8>(ConditionInfo.Logic)).ToString();

		JsonObject->SetField("ConditionNodeID", MakeShared<FJsonValueString>(ConditionNodeID));
		JsonObject->SetField("ConditionType", MakeShared<FJsonValueString>(ConditionType));
		JsonObject->SetField("BPClass", MakeShared<FJsonValueString>(ConditionInfo.Condition->GetClass()->GetPathName()));
		JsonObject->SetField("Logic", MakeShared<FJsonValueString>(Logic));
		if (ConditionInfo.Condition->SingleLogic == ELFCondSingleLogic::Default)
		{
			JsonObject->SetField("SingleLogic", MakeShared<FJsonValueBoolean>(true));
		}
		else
		{
			JsonObject->SetField("SingleLogic", MakeShared<FJsonValueBoolean>(false));	
		}

		for (FProperty* Property : TFieldRange<FProperty>(ConditionInfo.Condition->GetClass(), EFieldIteratorFlags::ExcludeSuper))
		{
			if (!NeedExport(Property))
			{
				continue;
			}

			void* Address = Property->ContainerPtrToValuePtr<void>(ConditionInfo.Condition);
			JsonObject->SetField(Property->GetName(), FLuaSerializeHelper::ExportFProperty(Property, Address));
		}

		JsonArray.Add(MakeShareable(new FJsonValueObject(JsonObject)));
	}
	return MakeShareable(new FJsonValueArray(JsonArray));
}

TSharedPtr<FJsonValue> FLevelFlowSerializeHelper::SerializeAction(ULevelFlowActionNode* ActionNode)
{
	const TSharedPtr<FJsonObject> JsonObject = MakeShared<FJsonObject>();
	if (ActionNode)
	{
		FString ActionNodeID = ActionNode->GetName();
		FString ActionType = ActionNode->GetClass()->GetName();
		ActionType = ActionType.Mid(0, ActionType.Len() - 2);
		JsonObject->SetField("ActionNodeID", MakeShared<FJsonValueString>(ActionNodeID));
		JsonObject->SetField("ActionType", MakeShared<FJsonValueString>(ActionType));
		JsonObject->SetField("BPClass", MakeShared<FJsonValueString>(ActionNode->GetClass()->GetPathName()));
		for (FProperty* Property : TFieldRange<FProperty>(ActionNode->GetClass(), EFieldIteratorFlags::ExcludeSuper))
		{
			if (!NeedExport(Property))
			{
				continue;
			}

			void* Address = Property->ContainerPtrToValuePtr<void>(ActionNode);
			if (NeedExExport(Property, Address))
			{
				JsonObject->SetField(Property->GetName(), ExportExObjectProperty(Property, Address));
			}
			else
			{
				JsonObject->SetField(Property->GetName(), FLuaSerializeHelper::ExportFProperty(Property, Address));
			}
		}
	}
	return MakeShareable(new FJsonValueObject(JsonObject));
}

TSharedPtr<FJsonValue> FLevelFlowSerializeHelper::SerializeNextNodes(ULevelFlowActionNode* ActionNode)
{
	TArray<TSharedPtr<FJsonValue>> JsonArray;
	for (auto NextNode : ActionNode->NextNodes)
	{
		if (IsValid(NextNode))
		{
			JsonArray.Add(MakeShareable(new FJsonValueString(NextNode->GetName())));	
		}
		else
		{
			UE_LOG(LogTemp, Error, TEXT("%s %s next node not valid"), *FString(__FUNCTION__), *ActionNode->GetName());
		}
	}
	return MakeShared<FJsonValueArray>(JsonArray);
}

TSharedPtr<FJsonValue> FLevelFlowSerializeHelper::SerializeGraphNode(UEdGraphNode* GraphNode)
{
	const TSharedPtr<FJsonObject> JsonObject = MakeShared<FJsonObject>();
	if (GraphNode)
	{
		JsonObject->SetField("GraphX", MakeShareable(new FJsonValueNumber(GraphNode->NodePosX)));
		JsonObject->SetField("GraphY", MakeShareable(new FJsonValueNumber(GraphNode->NodePosY)));
	}
	return MakeShareable(new FJsonValueObject(JsonObject));
}

bool FLevelFlowSerializeHelper::NeedExport(FProperty* Property)
{
	if (Property->GetName().EndsWith("_OLD"))
	{
		return false;
	}

	return true;
}

bool FLevelFlowSerializeHelper::NeedExExport(FProperty* Property, void* Address)
{
	if (FObjectProperty* ObjectProperty = CastField<FObjectProperty>(Property))
	{
		if (UObject* Object = ObjectProperty->GetObjectPropertyValue(Address))
		{
			if (Object->IsA(ALight::StaticClass()) || Object->IsA(ACameraActor::StaticClass()))
			{
				return true;
			}
		}
	}

	return false;
}

TSharedPtr<FJsonValue> FLevelFlowSerializeHelper::ExportExObjectProperty(FProperty* Property, void* Address)
{
	const TSharedPtr<FJsonObject> JsonObject = MakeShared<FJsonObject>();
	if (FObjectProperty* ObjectProperty = CastField<FObjectProperty>(Property))
	{
		if (UObject* Object = ObjectProperty->GetObjectPropertyValue(Address))
		{
			if (Object->IsA(ALight::StaticClass()) || Object->IsA(ACameraActor::StaticClass()))
			{
				return MakeShareable(new FJsonValueString(Object->GetName()));
			}
		}
	}

	return MakeShareable(new FJsonValueString(""));
}

TSharedPtr<FJsonValue> FLevelFlowSerializeHelper::SerializeCommentNodes(UEdGraph* Graph)
{
	TArray<TSharedPtr<FJsonValue>> JsonArray;
	for (auto GraphNode : Graph->Nodes)
	{
		if (UEdGraphNode_Comment* CommentNode = Cast<UEdGraphNode_Comment>(GraphNode))
		{
			const TSharedPtr<FJsonObject> JsonObject = MakeShared<FJsonObject>();
			JsonObject->SetField("GraphX", MakeShareable(new FJsonValueNumber(CommentNode->NodePosX)));
			JsonObject->SetField("GraphY", MakeShareable(new FJsonValueNumber(CommentNode->NodePosY)));
			JsonObject->SetField("GraphWidth", MakeShareable(new FJsonValueNumber(CommentNode->NodeWidth)));
			JsonObject->SetField("GraphHeight", MakeShareable(new FJsonValueNumber(CommentNode->NodeHeight)));
			JsonObject->SetField("Comment", MakeShareable(new FJsonValueString(CommentNode->NodeComment)));
			JsonArray.Add(MakeShareable(new FJsonValueObject(JsonObject)));
		}
	}
	return MakeShareable(new FJsonValueArray(JsonArray));
}

#pragma endregion Serialize

#pragma region Deserialize

void FLevelFlowSerializeHelper::DeserializeLevelFlow(ULevelFlow* LevelFlow, const FString LevelName, const FString GroupName, const FString TemplateName)
{
	if (!FC7EditorModule::Get().LevelEditorViewExtend.IsValid())
		return ;

	FLevelLuaEditorProxy* Proxy = FC7EditorModule::Get().LevelEditorViewExtend->GetLevelLuaEditorProxy();

	NS_SLUA::lua_State* L = Proxy->GetLuaState();

	if (!L)
	{
		UE_LOG(LogTemp, Warning, TEXT("%s get Lua State failed"), *FString(__FUNCTION__));
		FText Message = FText::FromString(TEXT("环境错误, 请关闭其他编辑器"));
		FMessageDialog::Open(EAppMsgType::Ok, Message);
		return;
	}

	// const FString FilePath = FPaths::ProjectContentDir() + "Script/Data/Config/LevelFlowData/LF_LV_Factory_LD02.lua";

	FString LuaStr;
	if (TemplateName.IsEmpty())
	{
		const FString FilePath = FPaths::ProjectContentDir() + "Script/Data/Config/LevelFlowData/" + LevelName + "/LF_" + GroupName + ".lua";
		FFileHelper::LoadFileToString(LuaStr, *FilePath);
	}
	else
	{
		TArray<FString> TempFilePath;
		IFileManager::Get().FindFiles(TempFilePath, *(FPaths::ProjectContentDir() + "Script/Data/Config/LevelFlowData/Template/" + TemplateName));
		
		if (TempFilePath.Num() == 0)
		{
			UE_LOG(LogTemp, Warning, TEXT("%s get levelflow template data not found"), *TemplateName);
			FText Message = FText::FromString(TEXT("模板levelflow数据未找到"));
			FMessageDialog::Open(EAppMsgType::Ok, Message);
			return;
		}
		const FString FilePath = FPaths::ProjectContentDir() + "Script/Data/Config/LevelFlowData/Template/" + TemplateName + "/" + TempFilePath[0];
		FFileHelper::LoadFileToString(LuaStr, *FilePath);
	}

	if (LuaStr.IsEmpty())
	{
		UE_LOG(LogTemp, Warning, TEXT("%s no target file or file empty"), *FString(__FUNCTION__));
		return;
	}
	
	if (!FLuaSerializeHelper::PushLuaStr(L, LuaStr))
	{
		UE_LOG(LogTemp, Error, TEXT("%s PushLuaStr failed"), *FString(__FUNCTION__));
		return;
	}

	if (!lua_istable(L, -1))
	{
		UE_LOG(LogTemp, Error, TEXT("%s Lua Str not return a table"), *FString(__FUNCTION__));
		return;
	}

	// 反序列化结点
	TMap<FString, ULevelFlowActionNode*> LevelFlowActionNodesMap;
	TMap<FString, TArray<FString>> NextNodesMap;
	struct FGraphInfo
	{
		int X;
		int Y;
	};
	TMap<FString, FGraphInfo> GraphInfos;
	struct FCommentInfo
	{
		int X;
		int Y;
		int Width;
		int Height;
		// FString Comment;
	};
	TMap<int, FCommentInfo> CommentInfos;

	NS_SLUA::lua_getfield(L, -1, "FlowNodes");
	NS_SLUA::lua_pushnil(L);
	while (lua_next(L, -2))
	{
		FString NodeID = NS_SLUA::lua_tostring(L, -2);
		ULevelFlowActionNode* ActionNode = nullptr;

		// action 最先创建, 作为trigger和condition的outer
		NS_SLUA::lua_getfield(L, -1, "ActionInfo");
		if (lua_istable(L, -1))
		{
			NS_SLUA::lua_getfield(L, -1, "ActionNodeID");
			const FString ActionNodeID = NS_SLUA::lua_tostring(L, -1);
			NS_SLUA::lua_pop(L, 1);
			UObject* ActionObj = DeserializeOneNode(L, ActionNodeID, LevelFlow);
			ActionNode = Cast<ULevelFlowActionNode>(ActionObj);
		}
		NS_SLUA::lua_pop(L, 1);

		// trigger
		NS_SLUA::lua_getfield(L, -1, "TriggerInfo");
		if (lua_istable(L, -1) && IsLuaTableNotEmpty(L))
		{
			NS_SLUA::lua_getfield(L, -1, "bIsLoop");
			int IsLoop = NS_SLUA::lua_toboolean(L, -1);
			NS_SLUA::lua_pop(L, 1);
			
			NS_SLUA::lua_getfield(L, -1, "TriggerNodeID");
			const FString TriggerNodeID = NS_SLUA::lua_tostring(L, -1);
			NS_SLUA::lua_pop(L, 1);
			UObject* TriggerObj = DeserializeOneNode(L, TriggerNodeID, ActionNode);
			ULevelFlowTriggerNode* LevelFlowTriggerNode = Cast<ULevelFlowTriggerNode>(TriggerObj);
			LevelFlowTriggerNode->bIsLoop = IsLoop ? true : false;
			ActionNode->TriggerNode = LevelFlowTriggerNode;
		}
		NS_SLUA::lua_pop(L, 1);

		// conditions
		NS_SLUA::lua_getfield(L, -1, "ConditionsInfo");
		if (lua_istable(L, -1) && IsLuaTableNotEmpty(L))
		{
			TArray<ULevelFlowConditionNode*> ConditionNodes;
			TArray<FString> LogicList;
			NS_SLUA::lua_pushnil(L);
			while (lua_next(L, -2))
			{
				NS_SLUA::lua_getfield(L, -1, "Logic");
				const FString Logic = NS_SLUA::lua_tostring(L, -1);
				LogicList.Add(Logic);
				NS_SLUA::lua_pop(L, 1);

				NS_SLUA::lua_getfield(L, -1, "SingleLogic");
				int SingleLogic = NS_SLUA::lua_toboolean(L, -1);
				NS_SLUA::lua_pop(L, 1);

				NS_SLUA::lua_getfield(L, -1, "ConditionNodeID");
				const FString ConditionNodeID = NS_SLUA::lua_tostring(L, -1);
				NS_SLUA::lua_pop(L, 1);
				UObject* ConditionObj = DeserializeOneNode(L, ConditionNodeID, ActionNode);
				ULevelFlowConditionNode* LevelFlowConditionNode = Cast<ULevelFlowConditionNode>(ConditionObj);
				LevelFlowConditionNode->SingleLogic = SingleLogic ? ELFCondSingleLogic::Default : ELFCondSingleLogic::NOT;
				ConditionNodes.Add(LevelFlowConditionNode);
				NS_SLUA::lua_pop(L, 1);
			}

			for (int32 Idx = 0; Idx < ConditionNodes.Num(); ++Idx)
			{
				if (Idx == 0)
				{
					ActionNode->DefaultCondition = ConditionNodes[Idx];
				}
				else
				{
					ELFCondLogic Logic = LogicList[Idx].Equals("AND") ? ELFCondLogic::AND : ELFCondLogic::OR;
					ActionNode->ConditionInfos.Add(FLevelFlowConditionInfo(Logic, ConditionNodes[Idx]));
				}
			}
		}
		NS_SLUA::lua_pop(L, 1);

		LevelFlowActionNodesMap.Add(NodeID, ActionNode);

		// NextNodes
		TArray<FString> NextNodeIDs;
		NS_SLUA::lua_getfield(L, -1, "NextNodes");
		NS_SLUA::lua_pushnil(L);
		while (NS_SLUA::lua_next(L, -2))
		{
			NextNodeIDs.Add(NS_SLUA::lua_tostring(L, -1));
			NS_SLUA::lua_pop(L, 1);
		}
		NextNodesMap.Add(NodeID, NextNodeIDs);
		NS_SLUA::lua_pop(L, 1);

		// GraphInfo
		FGraphInfo GraphInfo;
		NS_SLUA::lua_getfield(L, -1, "GraphInfo");
		NS_SLUA::lua_getfield(L, -1, "GraphX");
		GraphInfo.X = NS_SLUA::lua_tonumberx(L, -1, nullptr);
		NS_SLUA::lua_pop(L, 1);
		NS_SLUA::lua_getfield(L, -1, "GraphY");
		GraphInfo.Y = NS_SLUA::lua_tonumberx(L, -1, nullptr);
		NS_SLUA::lua_pop(L, 1);
		GraphInfos.Add(NodeID, GraphInfo);
		NS_SLUA::lua_pop(L, 1);

		// for lua_next
		NS_SLUA::lua_pop(L, 1);
	}
	NS_SLUA::lua_pop(L, 1);

	NS_SLUA::lua_getfield(L, -1, "Comments");
	NS_SLUA::lua_pushnil(L);
	while (NS_SLUA::lua_next(L, -2))
	{
		int CommentIdx = NS_SLUA::lua_tonumberx(L, -2, nullptr);
		
		FCommentInfo CommentInfo;
		NS_SLUA::lua_getfield(L, -1, "GraphX");
		CommentInfo.X = NS_SLUA::lua_tonumberx(L, -1, nullptr);
		NS_SLUA::lua_pop(L, 1);
		NS_SLUA::lua_getfield(L, -1, "GraphY");
		CommentInfo.Y = NS_SLUA::lua_tonumberx(L, -1, nullptr);
		NS_SLUA::lua_pop(L, 1);
		NS_SLUA::lua_getfield(L, -1, "GraphWidth");
		CommentInfo.Width = NS_SLUA::lua_tonumberx(L, -1, nullptr);
		NS_SLUA::lua_pop(L, 1);
		NS_SLUA::lua_getfield(L, -1, "GraphHeight");
		CommentInfo.Height = NS_SLUA::lua_tonumberx(L, -1, nullptr);
		NS_SLUA::lua_pop(L, 1);
		
		// lua_getfield(L, -1, "Comment");
		// CommentInfo.Comment = lua_tostring(L, -1);
		// lua_pop(L, 1);
		
		CommentInfos.Add(CommentIdx, CommentInfo);

		// for lua_next
		NS_SLUA::lua_pop(L, 1);
	}
	NS_SLUA::lua_pop(L, 1);

	// 建立引用关系
	for (auto It : NextNodesMap)
	{
		FString NodeID = It.Key;
		TArray<FString> NextNodes = It.Value;

		ULevelFlowActionNode* LevelFlowActionNode = LevelFlowActionNodesMap[NodeID];
		NextNodes.Sort();
		for (auto NextNodeID : NextNodes)
		{
			ULevelFlowActionNode* NextNode = LevelFlowActionNodesMap[NextNodeID];
			LevelFlowActionNode->NextNodes.Add(NextNode);
		}
	}

	// 构建图表
	LevelFlow->FlowGraph = FBlueprintEditorUtils::CreateNewGraph(LevelFlow, TEXT("Level Flow Graph"), ULevelFlowGraph::StaticClass(), ULevelFlowGraphSchema::StaticClass());
	ULevelFlowGraph* LevelFlowGraph = Cast<ULevelFlowGraph>(LevelFlow->FlowGraph);
	const UEdGraphSchema* Schema = LevelFlowGraph->GetSchema();
	Schema->CreateDefaultNodesForGraph(*LevelFlowGraph);

	// 加锁
	LevelFlowGraph->bIsPendingDeserialize = true;

	// 排序
	LevelFlowActionNodesMap.KeySort([](const FString& A, const FString& B)
	{
		return A < B;
	});

	TMap<FString, ULevelFlowGraphActionNode*> LevelFlowGraphActionNodeMap;
	for (auto It : LevelFlowActionNodesMap)
	{
		ULevelFlowActionNode* LevelFlowActionNode = It.Value;

		// action
		ULevelFlowGraphActionNode* GraphActionNode;
		if (It.Key.Equals("Root"))
		{
			GraphActionNode = Cast<ULevelFlowGraphActionNode>(LevelFlowGraph->RootNode.Get());
		}
		else
		{
			GraphActionNode = NewObject<ULevelFlowGraphActionNode>(LevelFlow->FlowGraph);
		}
		GraphActionNode->Node = LevelFlowActionNode;

		// trigger
		if (LevelFlowActionNode->TriggerNode)
		{
			UClass* NodeClass = ULevelFlowGraphTriggerNode::StaticClass();
			FSchemaAction_NewCondNode NewNodeAction(FText::GetEmpty(), NodeClass->GetDisplayNameText(), NodeClass->GetToolTipText(), 0);
			NewNodeAction.ParentNode = GraphActionNode;
			ULevelFlowGraphTriggerNode* Template = NewObject<ULevelFlowGraphTriggerNode>(GraphActionNode);
			Template->Node = LevelFlowActionNode->TriggerNode;
			NewNodeAction.NodeTemplate = Template;
			ULevelFlowGraphTriggerNode* NewGraphNode = (ULevelFlowGraphTriggerNode*)NewNodeAction.PerformAction(LevelFlow->FlowGraph, nullptr, FVector2D::ZeroVector);
			GraphActionNode->Trigger = NewGraphNode;
		}

		// conditions
		if (LevelFlowActionNode->DefaultCondition)
		{
			UClass* NodeClass = ULevelFlowGraphConditionNode::StaticClass();
			FSchemaAction_NewCondNode NewNodeAction(FText::GetEmpty(), NodeClass->GetDisplayNameText(), NodeClass->GetToolTipText(), 0);
			NewNodeAction.ParentNode = GraphActionNode;
			ULevelFlowGraphConditionNode* Template = NewObject<ULevelFlowGraphConditionNode>(GraphActionNode);
			Template->Node = LevelFlowActionNode->DefaultCondition;
			NewNodeAction.NodeTemplate = Template;
			ULevelFlowGraphConditionNode* NewGraphNode = (ULevelFlowGraphConditionNode*)NewNodeAction.PerformAction(LevelFlow->FlowGraph, nullptr, FVector2D::ZeroVector);
			GraphActionNode->Conditions.Add(NewGraphNode);
			
			for (auto ConditionInfo : LevelFlowActionNode->ConditionInfos)
			{
				FSchemaAction_NewCondNode InnerNewNodeAction(FText::GetEmpty(), NodeClass->GetDisplayNameText(), NodeClass->GetToolTipText(), 0);
				InnerNewNodeAction.ParentNode = GraphActionNode;
				ULevelFlowGraphConditionNode* InnerTemplate = NewObject<ULevelFlowGraphConditionNode>(GraphActionNode);
				InnerTemplate->Node = ConditionInfo.Condition;
				InnerNewNodeAction.NodeTemplate = InnerTemplate;
				ULevelFlowGraphConditionNode* InnerNewGraphNode = (ULevelFlowGraphConditionNode*)InnerNewNodeAction.PerformAction(LevelFlow->FlowGraph, nullptr, FVector2D::ZeroVector);
				GraphActionNode->Conditions.Add(InnerNewGraphNode);
			}
		}

		FString NodeID = LevelFlowActionNode->IsA(ULevelFlowRootNode::StaticClass()) ? "Root" : LevelFlowActionNode->GetName();
		LevelFlowGraphActionNodeMap.Add(NodeID, GraphActionNode);

		LevelFlow->FlowGraph->AddNode(GraphActionNode);
		GraphActionNode->CreateNewGuid();
		GraphActionNode->PostPlacedNewNode();
		GraphActionNode->AllocateDefaultPins();

		FGraphInfo GraphInfo = GraphInfos[NodeID];
		GraphActionNode->NodePosX = GraphInfo.X;
		GraphActionNode->NodePosY = GraphInfo.Y;

		// root
		if (It.Key.Equals("Root"))
		{
			LevelFlow->RootNode = LevelFlowActionNode;
			LevelFlowGraph->RootNode = GraphActionNode;
		}

		LevelFlow->FlowNodes.Add(LevelFlowActionNode);
	}

	// 构建图形化结点链接
	for (auto GraphNode : LevelFlow->FlowGraph->Nodes)
	{
		if (ULevelFlowGraphActionNode* GraphActionNode = Cast<ULevelFlowGraphActionNode>(GraphNode.Get()))
		{
			UEdGraphPin* OutputPin = GraphActionNode->GetOutputPin();
			for (ULevelFlowActionNode* NextNode : GraphActionNode->Node->NextNodes)
			{
				ULevelFlowGraphActionNode* NextGraphNode = LevelFlowGraphActionNodeMap[NextNode->GetName()];
				UEdGraphPin* InputPin = NextGraphNode->GetInputPin();
				OutputPin->MakeLinkTo(InputPin);
			}
		}
	}

	// 画注释结点
	for (auto It : CommentInfos)
	{
		//FCommentInfo& CommentInfo = It.Value;
		//FString Comment = ULevelEditorLuaObj::GetLevelFlowCommentFromLua(LuaStr, It.Key);
		//if (Comment.IsEmpty())
		//{
		//	UE_LOG(LogTemp, Warning, TEXT("%s get empty comment"), *FString(__FUNCTION__));
		//}
		//
		//UEdGraphNode_Comment* GraphNode_Comment = NewObject<UEdGraphNode_Comment>(LevelFlowGraph);
		//GraphNode_Comment->NodePosX = CommentInfo.X;
		//GraphNode_Comment->NodePosY = CommentInfo.Y;
		//GraphNode_Comment->NodeHeight = CommentInfo.Height;
		//GraphNode_Comment->NodeWidth = CommentInfo.Width;
		//GraphNode_Comment->NodeComment = Comment;
		//LevelFlowGraph->AddNode(GraphNode_Comment);
	}

	// 解锁
	LevelFlowGraph->bIsPendingDeserialize = false;

	UE_LOG(LogTemp, Log, TEXT("%s end"), *FString(__FUNCTION__));
	
}

UObject* FLevelFlowSerializeHelper::DeserializeOneNode(NS_SLUA::lua_State* L, const FString& NodeID, UObject* Outer /* = nullptr */)
{
	Outer = Outer ? Outer : GetTransientPackage();
	NS_SLUA::lua_getfield(L, -1, "BPClass");
	const FString NodeClassPath = NS_SLUA::lua_tostring(L, -1);
	NS_SLUA::lua_pop(L, 1);

	const UClass* NodeClass = LoadClass<UObject>(nullptr, *NodeClassPath);
	UObject* NodeObj = NewObject<UObject>(Outer, NodeClass);
	NodeObj->Rename(*NodeID);

	for (FProperty* Property : TFieldRange<FProperty>(NodeObj->GetClass(), EFieldIteratorFlags::ExcludeSuper))
	{
		void* Address = Property->ContainerPtrToValuePtr<void>(NodeObj);
		const FString PropertyName = FLuaSerializeHelper::GetPropertyDisPlayName(Property, false);
		if (PropertyName.EndsWith("_OLD"))
		{
			continue;
		}

		NS_SLUA::lua_getfield(L, -1, TCHAR_TO_ANSI(*PropertyName));
		FLuaSerializeHelper::FillFProperty(Property, Address, L, -1, NodeObj);
		NS_SLUA::lua_pop(L, 1);
	}

	return NodeObj;
}

void FLevelFlowSerializeHelper::DeserializeRootNode(NS_SLUA::lua_State* L, ULevelFlowRootNode* RootNode)
{
}

bool FLevelFlowSerializeHelper::IsLuaTableNotEmpty(NS_SLUA::lua_State* L)
{
	NS_SLUA::lua_pushnil(L);
	if (NS_SLUA::lua_next(L, -2))
	{
		NS_SLUA::lua_pop(L, 2);
		return true;
	}
	return false;
}

#pragma endregion Deserialize
