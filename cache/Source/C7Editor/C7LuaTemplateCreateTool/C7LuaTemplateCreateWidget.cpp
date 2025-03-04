// Fill out your copyright notice in the Description page of Project Settings.


#include "C7LuaTemplateCreateWidget.h"

#include "DesktopPlatformModule.h"
#include "HttpModule.h"
#include "IDesktopPlatform.h"
#include "SlateOptMacros.h"
#include "Framework/Notifications/NotificationManager.h"
#include "Interfaces/IHttpRequest.h"
#include "Interfaces/IHttpResponse.h"
#include "Misc/FileHelper.h"
#include "Widgets/Notifications/SNotificationList.h"

#define LOCTEXT_NAMESPACE "FC7LuaTemplateCreate"

BEGIN_SLATE_FUNCTION_BUILD_OPTIMIZATION

void SC7LuaTemplateCreateWidget::Construct(const FArguments& InArgs)
{
	LuaTemplateCreateConfig = NewObject<UC7LuaTemplateCreateConfig>();
	GetSavedAuthor();
	WidgetData.InitAuthor(LuaTemplateCreateConfig.Get()->Author, LuaTemplateCreateConfig.Get()->RedmineToken);
	GetRedmineIssues();
	VerticalBox = SNew(SVerticalBox);
	PathWidgetBox = SNew(SGridPanel).FillColumn(2, 1.0f);
	CurTemplatePanel = SNew(SBorder);
	CreateHotfixBasePanelWidget();
	CreateHotfixComponentPanelWidget();
	CreateSystemPanelWidget();
	this->ChildSlot
	[
		SNew(SBorder).BorderImage(FAppStyle::Get().GetBrush("ToolPanel.GroupBorder"))
		[
			VerticalBox.ToSharedRef()
		]
	];

	SelectPathWidget();
	VerticalBox->AddSlot().HAlign(HAlign_Fill).AutoHeight()[
		PathWidgetBox.ToSharedRef()
	];
	SelectTemplateTypeWidget();
	ChangeTemplatePanel();
	VerticalBox->AddSlot().Padding(8.0f, 20.0f, 4.0f, 4.0f).HAlign(HAlign_Fill).AutoHeight()[
		CurTemplatePanel.ToSharedRef()
	];
	CreateGenerateWidget();
	CreateRedmineTokenWidget();
}

void SC7LuaTemplateCreateWidget::SelectPathWidget()
{
	PathWidgetBox->AddSlot(0, 0).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(STextBlock).Font(FAppStyle::Get().GetFontStyle("LargeFont"))
		                .ColorAndOpacity(FAppStyle::Get().GetSlateColor("Colors.White")).Text(
			                FText::FromString("Path:"))
	];
	PathWidgetBox->AddSlot(1, 0).Padding(30.0f, 4.0f, 4.0f, 4.0f).VAlign(VAlign_Center).HAlign(HAlign_Left)[
		SNew(STextBlock).Font(FAppStyle::Get().GetFontStyle("NormalFontBold"))
		                .ColorAndOpacity(FAppStyle::Get().GetSlateColor("Colors.White")).Text(
			                WidgetData.GetFilePath())
	];
	PathWidgetBox->AddSlot(2, 0).Padding(3.0f, 4.0f, 3.0f, 4.0f).VAlign(VAlign_Center).HAlign(HAlign_Right)[
		SNew(SButton).ButtonStyle(&FAppStyle::Get().GetWidgetStyle<FButtonStyle>("PrimaryButton"))
		             .TextStyle(&FAppStyle::Get().GetWidgetStyle<FTextBlockStyle>("ButtonText")).
		             OnClicked_Lambda([&]()
		             {
			             OnSelectFolder();
			             return FReply::Handled();
		             })[
			SNew(SBox).HeightOverride(16.0f)[
				SNew(SHorizontalBox) +
				SHorizontalBox::Slot()
				.VAlign(VAlign_Center).Padding(8.0f, 0.5f, 0.0f, 0.0f).AutoWidth()[
					SNew(STextBlock).TextStyle(&FAppStyle::Get().GetWidgetStyle<FTextBlockStyle>("ButtonText"))
					                .Justification(ETextJustify::Center).Text(FText::FromString("SelectFolder"))
				]
			]
		]
	];
}

void SC7LuaTemplateCreateWidget::SelectTemplateTypeWidget()
{
	VerticalBox->AddSlot().Padding(3.0f).HAlign(HAlign_Left).AutoHeight()[
		SNew(SComboBox<TSharedPtr<FString>>)
			.OptionsSource(&WidgetData.TemplateTypeList)
			.OnSelectionChanged(this, &SC7LuaTemplateCreateWidget::OnSelectTemplateTypeChange)
			.OnGenerateWidget_Lambda([](TSharedPtr<FString> Value)-> TSharedRef<SWidget>
		                                    {
			                                    return SNew(STextBlock).Text(FText::FromString(*Value)); // 下拉项
		                                    })
		[
			SNew(STextBlock).Text(this, &SC7LuaTemplateCreateWidget::GetCurTemplateType) // 选中项
		]
	];
}

void SC7LuaTemplateCreateWidget::CreateHotfixBasePanelWidget()
{
	HotfixBasePanel = SNew(SGridPanel).FillColumn(2, 1.0f);
	HotfixBasePanel->AddSlot(0, 0).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(STextBlock).Font(FAppStyle::Get().GetFontStyle("LargeFont"))
		                .ColorAndOpacity(FAppStyle::Get().GetSlateColor("Colors.White")).Text(
			                FText::FromString("Author:"))
	];
	HotfixBasePanel->AddSlot(1, 0).Padding(30.0f, 4.0f, 4.0f, 4.0f).VAlign(VAlign_Center).HAlign(HAlign_Left)[
		SNew(SEditableTextBox).Font(FAppStyle::Get().GetFontStyle("NormalFontBold")).Text(
			                       FText::FromString(LuaTemplateCreateConfig.Get()->Author)).
		                       MinDesiredWidth(200.0f).OnTextCommitted(
			                       this, &SC7LuaTemplateCreateWidget::OnAuthorEditableTextCommit)
	];
	HotfixBasePanel->AddSlot(2, 0).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(SCheckBox)
	.IsChecked_Lambda([this]()
		               {
			               return WidgetData.bSaveAuthor ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
		               }).OnCheckStateChanged_Lambda([this](ECheckBoxState CheckState)
		               {
			               WidgetData.bSaveAuthor = CheckState == ECheckBoxState::Checked;
		               })
		[SNew(STextBlock).Text(FText::FromString("SaveAuthor"))]
	];

	HotfixBasePanel->AddSlot(0, 1).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(STextBlock).Font(FAppStyle::Get().GetFontStyle("LargeFont"))
		                .ColorAndOpacity(FAppStyle::Get().GetSlateColor("Colors.White")).Text(
			                FText::FromString("RedmineIssue:"))
	];
	HotfixBasePanel->AddSlot(1, 1).Padding(30.0f, 4.0f, 4.0f, 4.0f).VAlign(VAlign_Center).HAlign(HAlign_Left)[
		SNew(SEditableTextBox).Font(FAppStyle::Get().GetFontStyle("NormalFontBold")).Text(WidgetData.GetRedmineIssue()).
		                       MinDesiredWidth(200.0f).OnTextCommitted(
			                       this, &SC7LuaTemplateCreateWidget::OnRedmineEditableTextCommit)
	];
	HotfixBasePanel->AddSlot(2,1).Padding(30.0f, 4.0f, 4.0f, 4.0f).VAlign(VAlign_Center).HAlign(HAlign_Left)[
    	SNew(SComboBox<TSharedPtr<FString>>)
    		.OptionsSource(&WidgetData.IssuesList)
    		.OnSelectionChanged(this, &SC7LuaTemplateCreateWidget::OnSelectRedmineIssueChange)
    		.OnGenerateWidget_Lambda([](TSharedPtr<FString> Value)-> TSharedRef<SWidget>
    	                                    {
    		                                    return SNew(STextBlock).Text(FText::FromString(*Value)); // 下拉项
    	                                    })
    	[
    		SNew(STextBlock).Text(FText::FromString("Select Redmine Issue"))
    	]
    ];
}

void SC7LuaTemplateCreateWidget::CreateHotfixComponentPanelWidget()
{
	HotfixComponentPanel = SNew(SVerticalBox);
	HotfixComponentPanel->AddSlot().HAlign(HAlign_Fill).AutoHeight()[
		HotfixBasePanel.ToSharedRef()
	];
	TSharedPtr<SGridPanel> TempGridPanel = SNew(SGridPanel);
	TempGridPanel->AddSlot(0, 0).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(STextBlock).Font(FAppStyle::Get().GetFontStyle("LargeFont"))
		                .ColorAndOpacity(FAppStyle::Get().GetSlateColor("Colors.White")).Text(
			                FText::FromString("Component"))
	];
	TempGridPanel->AddSlot(1, 0).Padding(50.0f, 4.0f, 4.0f, 4.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(SEditableTextBox).Font(FAppStyle::Get().GetFontStyle("NormalFontBold")).Text(FText::FromString(TEXT(""))).
		                       MinDesiredWidth(200.0f).OnTextCommitted(
			                       this, &SC7LuaTemplateCreateWidget::OnComponentEditableTextCommit)
	];
	TempGridPanel->AddSlot(0, 1).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(STextBlock).Font(FAppStyle::Get().GetFontStyle("LargeFont"))
		                .ColorAndOpacity(FAppStyle::Get().GetSlateColor("Colors.White")).Text(
			                FText::FromString("Function"))
	];
	TempGridPanel->AddSlot(1, 1).Padding(50.0f, 4.0f, 4.0f, 4.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(SEditableTextBox).Font(FAppStyle::Get().GetFontStyle("NormalFontBold")).Text(FText::FromString(TEXT(""))).
		                       MinDesiredWidth(200.0f).OnTextCommitted(
			                       this, &SC7LuaTemplateCreateWidget::OnFunctionEditableTextCommit)
	];

	TempGridPanel->AddSlot(0, 2).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
	SNew(SCheckBox)
		.IsChecked_Lambda([this]()
				   {
					   return WidgetData.bIsNormalFunction ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
				   }).OnCheckStateChanged_Lambda([this](ECheckBoxState CheckState)
				   {
					   WidgetData.bIsNormalFunction = CheckState == ECheckBoxState::Checked;
				   })
		[SNew(STextBlock).Text(FText::FromString("Normal Function"))]
	];
	TempGridPanel->AddSlot(1, 2).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
	SNew(SCheckBox)
		.IsChecked_Lambda([this]()
				   {
					   return WidgetData.bIsNormalFunction ? ECheckBoxState::Unchecked : ECheckBoxState::Checked;
				   }).OnCheckStateChanged_Lambda([this](ECheckBoxState CheckState)
				   {
					   WidgetData.bIsNormalFunction = CheckState != ECheckBoxState::Checked;
				   })
		[SNew(STextBlock).Text(FText::FromString("__component_xxx__ Function"))]
	];
	

	HotfixComponentPanel->AddSlot().HAlign(HAlign_Fill).AutoHeight()[
		TempGridPanel.ToSharedRef()
	];
}

void SC7LuaTemplateCreateWidget::CreateSystemPanelWidget()
{
	SystemPanel = SNew(SGridPanel).FillColumn(2, 1.0f);
	SystemPanel->AddSlot(0, 0).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(STextBlock).Font(FAppStyle::Get().GetFontStyle("LargeFont"))
		                .ColorAndOpacity(FAppStyle::Get().GetSlateColor("Colors.White")).Text(
			                FText::FromString("SystemName:"))
	];
	SystemPanel->AddSlot(1, 0).Padding(10.0f, 4.0f, 4.0f, 4.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(SEditableTextBox).Font(FAppStyle::Get().GetFontStyle("NormalFontBold")).Text(FText::FromString(TEXT(""))).
		                       MinDesiredWidth(200.0f).OnTextCommitted(
			                       this, &SC7LuaTemplateCreateWidget::OnSystemEditableTextCommit)
	];
	SystemPanel->AddSlot(0, 1).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(SCheckBox)
	.IsChecked_Lambda([this]()
		               {
			               return WidgetData.bNeedDataModule ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
		               }).OnCheckStateChanged_Lambda([this](ECheckBoxState CheckState)
		               {
			               WidgetData.bNeedDataModule = CheckState == ECheckBoxState::Checked;
		               })
		[SNew(STextBlock).Text(FText::FromString("NeedDataModule"))]
	];
	SystemPanel->AddSlot(1, 1).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(SCheckBox)
		.IsEnabled_Lambda([this]() { return WidgetData.bNeedDataModule; })
		.IsChecked_Lambda([this]()
		               {
			               return WidgetData.bDisConnectExecuteInit
				                      ? ECheckBoxState::Checked
				                      : ECheckBoxState::Unchecked;
		               }).OnCheckStateChanged_Lambda([this](ECheckBoxState CheckState)
		               {
			               WidgetData.bDisConnectExecuteInit = CheckState == ECheckBoxState::Checked;
		               })
		[SNew(STextBlock).Text(FText::FromString(TEXT("断线时执行Clear")))]
	];
	SystemPanel->AddSlot(2, 1).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(SCheckBox)
		.IsEnabled_Lambda([this]() { return WidgetData.bNeedDataModule; })
		.IsChecked_Lambda([this]()
		               {
			               return WidgetData.bLogoutExecuteInit ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
		               }).OnCheckStateChanged_Lambda([this](ECheckBoxState CheckState)
		               {
			               WidgetData.bLogoutExecuteInit = CheckState == ECheckBoxState::Checked;
		               })
		[SNew(STextBlock).Text(FText::FromString(TEXT("登出或切换角色时执行Clear")))]
	];
	SystemPanel->AddSlot(0, 2).Padding(8.0f).HAlign(HAlign_Left).VAlign(VAlign_Center)[
		SNew(SCheckBox)
	.IsChecked_Lambda([this]()
		               {
			               return WidgetData.bNeedSenderModule ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
		               }).OnCheckStateChanged_Lambda([this](ECheckBoxState CheckState)
		               {
			               WidgetData.bNeedSenderModule = CheckState == ECheckBoxState::Checked;
		               })
		[SNew(STextBlock).Text(FText::FromString("NeedSenderModule"))]
	];
}

void SC7LuaTemplateCreateWidget::CreateGenerateWidget() const
{
	VerticalBox->AddSlot().HAlign(HAlign_Left).AutoHeight().Padding(8.0f, 20.0f, 4.0f, 4.0f)[
		SNew(SButton).ButtonStyle(&FAppStyle::Get().GetWidgetStyle<FButtonStyle>("PrimaryButton"))
		             .TextStyle(&FAppStyle::Get().GetWidgetStyle<FTextBlockStyle>("ButtonText")).
		             OnClicked_Lambda([&]()
		             {
			             OnGenerateFile();
			             return FReply::Handled();
		             })[
			SNew(SBox).HeightOverride(16.0f)[
				SNew(SHorizontalBox) +
				SHorizontalBox::Slot()
				.VAlign(VAlign_Center).Padding(8.0f, 0.5f, 0.0f, 0.0f).AutoWidth()[
					SNew(STextBlock).TextStyle(&FAppStyle::Get().GetWidgetStyle<FTextBlockStyle>("ButtonText"))
					                .Justification(ETextJustify::Center).Text(FText::FromString("GenerateFile"))
				]
			]
		]
	];
}

void SC7LuaTemplateCreateWidget::CreateRedmineTokenWidget()
{
	VerticalBox->AddSlot().VAlign(VAlign_Bottom).FillHeight(1)[
		SNew(SHorizontalBox) + SHorizontalBox::Slot()
		.HAlign(HAlign_Right)
		[
			SNew(STextBlock).Font(FAppStyle::Get().GetFontStyle("LargeFont"))
			                .ColorAndOpacity(FAppStyle::Get().GetSlateColor("Colors.White")).Text(
				                FText::FromString("RedmineToken"))
		]
		+ SHorizontalBox::Slot()
		  .HAlign(HAlign_Right)
		  .AutoWidth()
		[
			SNew(SEditableTextBox).Font(FAppStyle::Get().GetFontStyle("NormalFontBold")).Text(
				                       FText::FromString(LuaTemplateCreateConfig.Get()->RedmineToken)).
			                       MinDesiredWidth(200.0f).OnTextCommitted(
				                       this, &SC7LuaTemplateCreateWidget::OnRedmineTokenEditableTextCommit)
		]

	];
}


void SC7LuaTemplateCreateWidget::ChangeTemplatePanel() const
{
	CurTemplatePanel->ClearContent();
	switch (WidgetData.CurrentTemplateTypeIndex)
	{
	case ETemplateType::NormalHotfix:
	case ETemplateType::WebHotfix:
		CurTemplatePanel->SetContent(HotfixBasePanel.ToSharedRef());
		break;
	case ETemplateType::ComponentHotfix:
		CurTemplatePanel->SetContent(HotfixComponentPanel.ToSharedRef());
		break;
	case ETemplateType::GamePlaySystem:
		CurTemplatePanel->SetContent(SystemPanel.ToSharedRef());
		break;
	default: ;
	}
}

void SC7LuaTemplateCreateWidget::OnSelectFolder()
{
	FString Extension = TEXT("*.*");
	IDesktopPlatform* DesktopPlatform = FDesktopPlatformModule::Get();
	DesktopPlatform->OpenDirectoryDialog(nullptr, TEXT("File Manager"),
	                                     FPaths::ConvertRelativePathToFull(FPaths::ProjectContentDir() + "Script/"),
	                                     Extension);
	if (Extension != "*.*")
	{
		WidgetData.SetFilePath(FText::FromString(Extension));
	}
}

void SC7LuaTemplateCreateWidget::OnSelectTemplateTypeChange(TSharedPtr<FString> NewValue, ESelectInfo::Type Info)
{
	WidgetData.CurrentTemplateTypeIndex = WidgetData.TemplateTypeList.Find(NewValue);
	ChangeTemplatePanel();
}

void SC7LuaTemplateCreateWidget::OnAuthorEditableTextCommit(const FText& InText, ETextCommit::Type InCommitTyp)
{
	WidgetData.AuthorValue = InText;
}

void SC7LuaTemplateCreateWidget::OnRedmineEditableTextCommit(const FText& InText, ETextCommit::Type InCommitTyp)
{
	WidgetData.SetRedmineIssue(InText);
}

void SC7LuaTemplateCreateWidget::OnSelectRedmineIssueChange(TSharedPtr<FString> NewValue, ESelectInfo::Type Info)
{
	WidgetData.SetRedmineIssue(FText::FromString(*NewValue));
}

void SC7LuaTemplateCreateWidget::OnComponentEditableTextCommit(const FText& InText, ETextCommit::Type InCommitTyp)
{
	WidgetData.ComponentValue = InText;
}

void SC7LuaTemplateCreateWidget::OnFunctionEditableTextCommit(const FText& InText, ETextCommit::Type InCommitTyp)
{
	WidgetData.FunctionValue = InText;
}

void SC7LuaTemplateCreateWidget::OnSystemEditableTextCommit(const FText& InText, ETextCommit::Type InCommitTyp)
{
	WidgetData.SystemNameValue = InText;
}

void SC7LuaTemplateCreateWidget::OnRedmineTokenEditableTextCommit(const FText& InText, ETextCommit::Type InCommitTyp)
{
	if(WidgetData.RedmineTokenValue.CompareTo(InText) != 0)
	{	
		WidgetData.RedmineTokenValue = InText;
		GetRedmineIssues();
		LuaTemplateCreateConfig.Get()->RedmineToken = WidgetData.RedmineTokenValue.ToString();
		LuaTemplateCreateConfig.Get()->SaveCustomConfig();
	}
}

FText SC7LuaTemplateCreateWidget::GetCurTemplateType() const
{
	return FText::FromString(*WidgetData.TemplateTypeList[WidgetData.CurrentTemplateTypeIndex]);
}

void SC7LuaTemplateCreateWidget::OnGenerateFile() const
{
	switch (WidgetData.CurrentTemplateTypeIndex)
	{
	case ETemplateType::NormalHotfix:
		GenerateNormalHotfix(WidgetData.NormalHotfixFilePath);
		break;
	case ETemplateType::WebHotfix:
		GenerateNormalHotfix(WidgetData.WebHotfixFilePath);
		break;
	case ETemplateType::ComponentHotfix:
		GenerateComponentHotfixFile();
		break;
	case ETemplateType::GamePlaySystem:
		GenerateSystemFile();
		break;
	default: ;
	}
}

void SC7LuaTemplateCreateWidget::GenerateNormalHotfix(const FString& TemplateFilePath) const
{
	if (WidgetData.AuthorValue.IsEmpty() || WidgetData.GetRedmineIssue().Get().IsEmpty())
	{
		FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(TEXT("Author||RedmineIssue不能为空")));
		return;
	}
	FString TemplateContent = "";
	FFileHelper::LoadFileToString(TemplateContent, *TemplateFilePath);
	FString FileName = (WidgetData.AuthorValue.ToString() + "_" + WidgetData.GetRedmineIssue().Get().ToString()).Replace(
		TEXT(" "),TEXT("_"));
	FString HotfixName = "#" + FileName;
	FString FilePath = FPaths::Combine(WidgetData.GetFilePath().Get().ToString(), FileName + ".lua");
	int32 ScriptPathPos = FilePath.Find(TEXT("Content/Script/"),ESearchCase::CaseSensitive);
	FString ScriptPath;
	if(ScriptPathPos != INDEX_NONE)
	{
		ScriptPathPos += 15;
		ScriptPath = FilePath.Mid(ScriptPathPos);
	}
	FString FileContent = TemplateContent.Replace(TEXT("${HotfixName}"), *HotfixName).Replace(
			TEXT("${FilePath}"), *ScriptPath);

	if (FFileHelper::SaveStringToFile(FileContent, *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM))
	{
		SaveAuthor();
		ShowNotification(TEXT("Hotfix创建成功:\n") + FilePath);
	}
}

void SC7LuaTemplateCreateWidget::GenerateComponentHotfixFile() const
{
	if (WidgetData.AuthorValue.IsEmpty() || WidgetData.GetRedmineIssue().Get().IsEmpty() || WidgetData.ComponentValue.
		IsEmpty() || WidgetData.FunctionValue.IsEmpty())
	{
		FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(TEXT("Author||RedmineIssue||Component||Function不能为空")));
		return;
	}
	FString TemplateContent = "";
	FFileHelper::LoadFileToString(TemplateContent, *WidgetData.ComponentFuncHotfixFilePath);
	FString FileName = (WidgetData.AuthorValue.ToString() + "_" + WidgetData.GetRedmineIssue().Get().ToString()).Replace(
		TEXT(" "),TEXT("_"));
	FString HotfixName = "#" + FileName;
	FString FilePath = FPaths::Combine(WidgetData.GetFilePath().Get().ToString(), FileName + ".lua");
	FString FunctionName = WidgetData.bIsNormalFunction ? *WidgetData.FunctionValue.ToString() : FString::Printf(TEXT("__component_%s__"), *WidgetData.FunctionValue.ToString());
	int32 ScriptPathPos = FilePath.Find(TEXT("Content/Script/"),ESearchCase::CaseSensitive);
	FString ScriptPath;
	if(ScriptPathPos != INDEX_NONE)
	{
		ScriptPathPos += 15;
		ScriptPath = FilePath.Mid(ScriptPathPos);
	}
	
	FString FileContent = TemplateContent.Replace(TEXT("${HotfixName}"), *HotfixName).Replace(
		TEXT("${ComponentName}"), *WidgetData.ComponentValue.ToString()).Replace(
		TEXT("${FunctionName}"), *FunctionName).Replace(
			TEXT("${FilePath}"), *ScriptPath);
	if (FFileHelper::SaveStringToFile(FileContent, *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM))
	{
		SaveAuthor();
		ShowNotification(TEXT("Hotfix创建成功:\n") + FilePath);
	}
}

void SC7LuaTemplateCreateWidget::GenerateSystemFile() const
{
	if (WidgetData.SystemNameValue.IsEmpty())
	{
		FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(TEXT("SystemName不能为空")));
		return;
	}
	FString TemplateContent = "";
	const FString SystemName = WidgetData.SystemNameValue.ToString();
	FString RootPath = WidgetData.GetFilePath().Get().ToString() + "/";
	FString ModuleContent = "";
	FString ModuleContentOnCtor = "";
	const FString RequirePath = RootPath.Mid(RootPath.Find("/Script/") + 8).Replace(TEXT("/"),TEXT("."));
	if (WidgetData.bNeedDataModule)
	{
		FFileHelper::LoadFileToString(TemplateContent, *WidgetData.ModelFilePath);
		const FString FilePath = FPaths::Combine(RootPath, SystemName + "Model.lua");
		FString ClearContent = (WidgetData.bDisConnectExecuteInit || WidgetData.bLogoutExecuteInit)?
		FString::Printf(TEXT("\nfunction %sModel:clear()\n\nend\n"),*SystemName)
		:TEXT("");
		const FString FileContent = TemplateContent.Replace(TEXT("${SystemName}"), *SystemName).Replace(TEXT("${Clear}"),*ClearContent);
		if (FFileHelper::SaveStringToFile(FileContent, *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM))
		{
			ShowNotification(TEXT("Model创建成功:\n") + FilePath);
			ModuleContent += FString::Printf(
				TEXT("    ---@type %sModel\n    self.model = require(\"%s%sModel\").new(%s, %s)"), *SystemName, *RequirePath, *SystemName,
				*(WidgetData.bDisConnectExecuteInit ? FString("true") : FString("false")),
				*(WidgetData.bLogoutExecuteInit ? FString("true") : FString("false")));
			ModuleContentOnCtor += TEXT("    self.model = nil");
		}
	}
	if (WidgetData.bNeedSenderModule)
	{
		FFileHelper::LoadFileToString(TemplateContent, *WidgetData.SenderFilePath);
		const FString FilePath = FPaths::Combine(RootPath, SystemName + "Sender.lua");
		const FString FileContent = TemplateContent.Replace(TEXT("${SystemName}"), *SystemName);
		if (FFileHelper::SaveStringToFile(FileContent, *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM))
		{
			ShowNotification(TEXT("Sender创建成功:\n") + FilePath);
			ModuleContent = ModuleContent + (WidgetData.bNeedDataModule ? "\n    " : "    ") + FString::Printf(
				TEXT("---@type %sSender\n    self.sender = require(\"%s%sSender\").new()"), *SystemName, *RequirePath, *SystemName);
			ModuleContentOnCtor = ModuleContentOnCtor + (WidgetData.bNeedDataModule ? "\n    " : "    ") + TEXT("self.sender = nil");
		}
	}
	FFileHelper::LoadFileToString(TemplateContent, *WidgetData.SystemFilePath);
	const FString FilePath = FPaths::Combine(RootPath, SystemName + "System.lua");
	FString FileContent = TemplateContent.Replace(TEXT("${SystemName}"), *SystemName);
	
	FileContent = FileContent.Replace(TEXT("${CtorModule}"), *ModuleContentOnCtor);
	FileContent = FileContent.Replace(TEXT("${Module}"), *ModuleContent);
	if (FFileHelper::SaveStringToFile(FileContent, *FilePath, FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM))
	{
		ShowNotification(TEXT("System创建成功:\n") + FilePath);
		TArray<FString> Lines;
		FFileHelper::LoadFileToStringArray(Lines, *WidgetData.SystemConfigFilePath);
		int32 InsertIndex = Lines.Num() - 3;
		int32 AnnotationIndex = 1;
		for (int32 i = 0; i < Lines.Num(); ++i)
		{
			if (Lines[i].StartsWith(TEXT("---@field")) && (i == Lines.Num() - 1 || !Lines[i + 1].StartsWith(
				TEXT("---@field"))))
			{
				AnnotationIndex = i + 1;
			}
			if (Lines[i].Contains(TEXT("return SystemConfig")))
			{
				InsertIndex = i - 1;
				break;
			}
		}
		Lines.Insert(FString::Printf(TEXT("---@field %sSystem %sSystem"), *SystemName, *SystemName), AnnotationIndex);
		Lines.Insert(FString::Printf(TEXT("		{\"%sSystem\", \"%s%sSystem\"},"), *SystemName, *RequirePath, *SystemName),
		             InsertIndex);
		if (FFileHelper::SaveStringArrayToFile(Lines, *WidgetData.SystemConfigFilePath))
		{
			ShowNotification(TEXT("SystemConfig更新成功"));
		}
	}
}

void SC7LuaTemplateCreateWidget::SaveAuthor() const
{
	LuaTemplateCreateConfig.Get()->Author = WidgetData.bSaveAuthor ? WidgetData.AuthorValue.ToString() : "";
	LuaTemplateCreateConfig.Get()->SaveCustomConfig();
}

void SC7LuaTemplateCreateWidget::GetSavedAuthor() const
{
	LuaTemplateCreateConfig.Get()->LoadCustomConfig();
}

void SC7LuaTemplateCreateWidget::ShowNotification(const FString& Content)
{
	FNotificationInfo Info(FText::FromString(Content));
	Info.ExpireDuration = 3;
	FSlateNotificationManager::Get().AddNotification(Info);
}

void SC7LuaTemplateCreateWidget::OnHttpResponse(FHttpRequestPtr HttpRequest, FHttpResponsePtr HttpResponse, bool bSucceeded)
{
	if(bSucceeded && HttpResponse->GetResponseCode() == 200)
	{
		WidgetData.IssuesList.Empty();	
		TSharedPtr<FJsonObject> RootObject;
		TSharedRef<TJsonReader<TCHAR>> Reader = TJsonReaderFactory<TCHAR>::Create(HttpResponse->GetContentAsString());
		if (FJsonSerializer::Deserialize(Reader, RootObject))
		{
			const TArray<TSharedPtr<FJsonValue>>* DataList;
			if(RootObject->TryGetArrayField(TEXT("issues"),DataList))
			{
				for (TSharedPtr<FJsonValue> Issue:*DataList)
				{
					TSharedPtr<FJsonObject> IssueObj = Issue->AsObject();
					FString IssueStr = FString::Printf(TEXT("#%d %s"),IssueObj->GetIntegerField(StringCast<TCHAR>("id")),*IssueObj->GetStringField(StringCast<TCHAR>("subject")))
					.Replace(TEXT("\\"),TEXT("_"))
					.Replace(TEXT("/"),TEXT("_"))
					.Replace(TEXT(":"),TEXT("_"))
					.Replace(TEXT("*"),TEXT("_"))
					.Replace(TEXT("?"),TEXT("_"))
					.Replace(TEXT("\""),TEXT("_"))
					.Replace(TEXT("\""),TEXT("_"))
					.Replace(TEXT("<"),TEXT("_"))
					.Replace(TEXT(">"),TEXT("_"))
					.Replace(TEXT("|"),TEXT("_"))
					.Mid(0,60);
					WidgetData.IssuesList.Add(MakeShared<FString>(IssueStr));
				}
			}
		}
		
	}
}

void SC7LuaTemplateCreateWidget::GetRedmineIssues()
{
	if(!WidgetData.RedmineTokenValue.IsEmpty())
	{
		TSharedRef<IHttpRequest> Request = FHttpModule::Get().CreateRequest();
		Request->SetVerb("GET");
		Request->AppendToHeader("X-Redmine-API-Key",WidgetData.RedmineTokenValue.ToString());
		Request->AppendToHeader("Accept","*/*");
		Request->AppendToHeader("Accept-Encoding","gzip, deflate, br");
		Request->AppendToHeader("Connection","keep-alive");
		Request->OnProcessRequestComplete().BindRaw(this, &SC7LuaTemplateCreateWidget::OnHttpResponse);
		Request->SetTimeout(3);
		Request->SetURL(WidgetData.RedmineUrl);
		Request->ProcessRequest();
	}
}

END_SLATE_FUNCTION_BUILD_OPTIMIZATION

UC7LuaTemplateCreateConfig::UC7LuaTemplateCreateConfig()
{
	ConfigPath = FPaths::Combine(*FPaths::GeneratedConfigDir(), TEXT("WindowsEditor/LuaTemplateCreateConfig.ini"));
}

void UC7LuaTemplateCreateConfig::LoadCustomConfig()
{
	GConfig->Flush(true, ConfigPath);
	ReloadConfig(this->GetClass(), *ConfigPath);
}

void UC7LuaTemplateCreateConfig::SaveCustomConfig()
{
	SaveConfig(CPF_Config, *ConfigPath);
	GConfig->Flush(false, ConfigPath);
}

#undef LOCTEXT_NAMESPACE