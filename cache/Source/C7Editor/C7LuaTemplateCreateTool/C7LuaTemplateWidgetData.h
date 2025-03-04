// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"

/**
 * 
 */
class FC7LuaTemplateWidgetData
{
public:
	FC7LuaTemplateWidgetData()
	{
		const FString ContentDir = FPaths::ConvertRelativePathToFull(FPaths::ProjectContentDir());
		SystemConfigFilePath = ContentDir + "Script/Data/Config/System/SystemConfig.lua";
		SystemFilePath = ContentDir + "Editor/LuaTemplate/System.lua";
		ModelFilePath = ContentDir + "Editor/LuaTemplate/Model.lua";
		SenderFilePath = ContentDir + "Editor/LuaTemplate/Sender.lua";
		NormalHotfixFilePath = ContentDir + "Editor/LuaTemplate/NormalHotfix.lua";
		ComponentFuncHotfixFilePath = ContentDir + "Editor/LuaTemplate/ComponentFuncHotfix.lua";
		WebHotfixFilePath = ContentDir + "Editor/LuaTemplate/WebHotfix.lua";
		FilePathValue = FText::FromString(FPaths::ConvertRelativePathToFull(FPaths::ProjectContentDir() + "Script"));
		FilePath.BindRaw(this, &FC7LuaTemplateWidgetData::GetFilePathValue);
		RedmineIssue.BindRaw(this, &FC7LuaTemplateWidgetData::GetRedmineIssueValue);
		TemplateTypeList.Add(MakeShared<FString>("NormalHotfix"));
		TemplateTypeList.Add(MakeShared<FString>("ComponentHotfix"));
		TemplateTypeList.Add(MakeShared<FString>("WebHotfix"));
		TemplateTypeList.Add(MakeShared<FString>("GamePlaySystem"));
		CurrentTemplateTypeIndex = 0;
		RedmineUrl = FString(TEXT("https://c7-game-redmine.corp.kuaishou.com/issues.json?assigned_to_id=me&status_id=open&limit=1000"));
	}
	TAttribute<FText> GetFilePath() const {
		return FilePath;
	}
	TAttribute<FText> GetRedmineIssue() const {
		return RedmineIssue;
	}
	void SetFilePath(const FText& Val)
	{
		FilePathValue = Val;
	}
	void SetRedmineIssue(const FText& Val)
	{
		RedmineIssueValue = Val;
	}

	void InitAuthor(const FString& SavedAuthor,const FString& RedmineToken)
	{
		bSaveAuthor = !SavedAuthor.IsEmpty();
		bIsNormalFunction = true;
        AuthorValue = FText::FromString(SavedAuthor);
		RedmineTokenValue = FText::FromString(RedmineToken);
	}
	
public:
	TArray<TSharedPtr<FString>> TemplateTypeList;
	TArray<TSharedPtr<FString>> IssuesList;
	int32 CurrentTemplateTypeIndex = 0;
	FText AuthorValue;
	FText RedmineTokenValue;
	bool bSaveAuthor;
	FText ComponentValue;
	FText FunctionValue;
	bool bIsNormalFunction;
	FText SystemNameValue;
	bool bNeedDataModule = true;
	bool bDisConnectExecuteInit = false;
	bool bLogoutExecuteInit = false;
	bool bNeedSenderModule = true;
	FString SystemConfigFilePath;
	FString RedmineUrl;
	FString SystemFilePath;
	FString ModelFilePath;
	FString SenderFilePath;
	FString ComponentFuncHotfixFilePath;
	FString NormalHotfixFilePath;
	FString WebHotfixFilePath;

private:
	FText GetFilePathValue() const {
		return FilePathValue;
	}
	
	FText GetRedmineIssueValue() const {
		return RedmineIssueValue;
	}

private:
	FText FilePathValue;
	TAttribute<FText> FilePath;
	FText RedmineIssueValue;
	TAttribute<FText> RedmineIssue;
};
