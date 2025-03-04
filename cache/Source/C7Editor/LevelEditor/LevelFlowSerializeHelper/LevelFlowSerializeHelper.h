#pragma once
#include "LevelFlowGraphNode.h"
#include "LevelFlow/LevelFlowTypes.h"



class FLevelFlowSerializeHelper
{
public:
	static void ButtonSerializeLevelFlow() { SerializeLevelFlow(nullptr, "", "", ""); }
	static void ButtonDeserializeLevelFlow() { DeserializeLevelFlow(nullptr, "", "", ""); }

#pragma region Serialize

	// 序列化当前关卡指定的LevelFlow
	static void SerializeLevelFlow(ULevelFlow* LevelFlow, const FString LevelName, const FString GroupName, const FString TemplateName);
	static TSharedPtr<FJsonValue> SerializeOneNode(ULevelFlowActionNode* Node);
	static TSharedPtr<FJsonValue> SerializeTrigger(ULevelFlowTriggerNode* TriggerNode);
	static TSharedPtr<FJsonValue> SerializeCondition(ULevelFlowActionNode* ActionNode);
	static TSharedPtr<FJsonValue> SerializeAction(ULevelFlowActionNode* ActionNode);
	static TSharedPtr<FJsonValue> SerializeNextNodes(ULevelFlowActionNode* ActionNode);
	static TSharedPtr<FJsonValue> SerializeGraphNode(UEdGraphNode* GraphNode);
	static TSharedPtr<FJsonValue> SerializeCommentNodes(UEdGraph* Graph);

#pragma endregion Serialize

#pragma region Deserialize

	// 反序列化LevelFlow
	static void DeserializeLevelFlow(ULevelFlow* LevelFlow, const FString LevelName, const FString GroupName, const FString TemplateName);
	static UObject* DeserializeOneNode(NS_SLUA::lua_State* L, const FString& NodeID, UObject* Outer = nullptr);
	static void DeserializeRootNode(NS_SLUA::lua_State* L, ULevelFlowRootNode* RootNode);

#pragma endregion Deserialize

private:
	// 带_OLD后缀的不导出
	static bool NeedExport(FProperty* Property);
	// 是否需要额外导出
	static bool NeedExExport(FProperty* Property, void* Address);
	// 特殊导出Light和Camera, todo:临时处理
	static TSharedPtr<FJsonValue> ExportExObjectProperty(FProperty* Property, void* Address);

	static bool IsLuaTableNotEmpty(NS_SLUA::lua_State* L);
};
