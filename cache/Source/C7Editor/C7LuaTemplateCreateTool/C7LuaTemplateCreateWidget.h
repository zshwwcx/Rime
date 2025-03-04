// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "C7LuaTemplateWidgetData.h"
#include "Interfaces/IHttpRequest.h"
#include "Widgets/SCompoundWidget.h"
#include "Widgets/Layout/SGridPanel.h"
#include "C7LuaTemplateCreateWidget.generated.h"

UCLASS(Blueprintable, config = Editor)
class UC7LuaTemplateCreateConfig : public UObject
{
	GENERATED_BODY()

public:
	UC7LuaTemplateCreateConfig();

	void LoadCustomConfig();
	void SaveCustomConfig();
	
	UPROPERTY(Config)
	FString Author;
	UPROPERTY(Config)
	FString RedmineToken;

private:
	FString ConfigPath;
};

class SC7LuaTemplateCreateWidget : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SC7LuaTemplateCreateWidget)
	{}
	SLATE_END_ARGS()

	/** Constructs this widget with InArgs */
	void Construct(const FArguments& InArgs);

private:
	void SelectPathWidget();
	void SelectTemplateTypeWidget();
	void CreateHotfixBasePanelWidget();
	void CreateHotfixComponentPanelWidget();
	void CreateSystemPanelWidget();
	void CreateGenerateWidget() const;
	void CreateRedmineTokenWidget();
	void ChangeTemplatePanel() const;
	
	void OnSelectFolder();
	void OnSelectTemplateTypeChange(TSharedPtr<FString> NewValue, ESelectInfo::Type Info);
	void OnAuthorEditableTextCommit(const FText& InText, ETextCommit::Type InCommitTyp);
	void OnRedmineEditableTextCommit(const FText& InText, ETextCommit::Type InCommitTyp);
	void OnSelectRedmineIssueChange(TSharedPtr<FString> NewValue, ESelectInfo::Type Info);
	void OnComponentEditableTextCommit(const FText& InText, ETextCommit::Type InCommitTyp);
	void OnFunctionEditableTextCommit(const FText& InText, ETextCommit::Type InCommitTyp);
	void OnSystemEditableTextCommit(const FText& InText, ETextCommit::Type InCommitTyp);
	void OnRedmineTokenEditableTextCommit(const FText& InText, ETextCommit::Type InCommitTyp);
	FText GetCurTemplateType() const;
	void OnGenerateFile() const;
	void GenerateNormalHotfix(const FString& TemplateFilePath) const;
	void GenerateComponentHotfixFile() const;
	void GenerateSystemFile() const;
	void SaveAuthor() const;
	void GetSavedAuthor() const;
	static void ShowNotification(const FString& Content);
	void OnHttpResponse(FHttpRequestPtr HttpRequest, FHttpResponsePtr HttpResponse, bool bSucceeded);
	void GetRedmineIssues();
	
private:
	enum ETemplateType
	{
		NormalHotfix = 0,
		ComponentHotfix = 1,
		WebHotfix = 2,
		GamePlaySystem = 3,
	};

	TSharedPtr<SVerticalBox> VerticalBox;
	TSharedPtr<SGridPanel> PathWidgetBox;
	TSharedPtr<SBorder> CurTemplatePanel;
	TSharedPtr<SGridPanel> HotfixBasePanel;
	TSharedPtr<SVerticalBox> HotfixComponentPanel;
	TSharedPtr<SGridPanel> SystemPanel;
	FC7LuaTemplateWidgetData WidgetData;
	
	TObjectPtr<UC7LuaTemplateCreateConfig> LuaTemplateCreateConfig = nullptr;
};