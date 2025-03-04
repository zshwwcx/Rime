// Fill out your copyright notice in the Description page of Project Settings.


#include "UIOptimize/UISpriteSheetHelper.h"
#include <AssetRegistry/AssetRegistryModule.h>
#include <WidgetBlueprint.h>
#include <FileHelpers.h>
#include <UMG.h>
#include <PaperSprite.h>
#include <Blueprint/UserWidget.h>
#include <AssetToolsModule.h>
#include <ContentBrowserModule.h>
#include "IContentBrowserSingleton.h"
#include "Engine/Selection.h"
#include "EditorViewportClient.h"
#include "DesktopPlatformModule.h"
#include "EditorDirectories.h"

TArray<FAssetData> SpriteAssets;

void UUISpriteSheetHelper::WidgetImageReplaceToSprite(UBlueprint* Blueprint, const FString& endWith)
{
	FAssetRegistryModule& AssetRegistryModule = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry");

	const UClass* SpriteClass = UPaperSprite::StaticClass();
	AssetRegistryModule.Get().GetAssetsByClass(SpriteClass->GetClassPathName(), SpriteAssets);

	//TArray<FAssetData> assetDatas;
	//const UClass* BlueprintWidgetClass = UWidgetBlueprint::StaticClass();
	//AssetRegistryModule.Get().GetAssetsByClass(BlueprintWidgetClass->GetFName(), assetDatas);
	Blueprint->Modify();

	TArray<UPackage*> savePackages;
	UBaseWidgetBlueprint* widget = Cast<UBaseWidgetBlueprint>(Blueprint);
	if (widget == NULL)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUISpriteSheetHelper::WidgetImageReplaceToSprite widget is null."));
		return;
	}

	if (widget->WidgetTree == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUISpriteSheetHelper::WidgetImageReplaceToSprite => WidgetTree is nullptr"));
		return;
	}

	TArray<UWidget*> childs;

	widget->WidgetTree->GetAllWidgets(childs);

	bool isModify = false;
	for (int j = 0; j < childs.Num(); j++)
	{
		if(childs[j] == nullptr)
		{
			continue;
		}
		if (UImage* image = Cast<UImage>(childs[j]))
		{
			FSlateBrush brush = image->GetBrush();
			UE_LOG(LogTemp, Log, TEXT("1"));
			if (SetSpriteBrush(brush, endWith))
			{
				image->SetBrush(brush);
				isModify = true;
			}
		}
		else if (UBorder* border = Cast<UBorder>(childs[j]))
		{
			FSlateBrush brush = border->Background;
			if (SetSpriteBrush(brush, endWith))
			{
				border->SetBrush(brush);
				isModify = true;
			}
		}
		else if (UButton* button = Cast<UButton>(childs[j]))
		{
			FButtonStyle style = button->WidgetStyle;
			FSlateBrush normal = style.Normal;
			if (SetSpriteBrush(normal, endWith))
			{
				style.SetNormal(normal);
				isModify = true;
			}
			FSlateBrush pressed = style.Pressed;
			if (SetSpriteBrush(pressed, endWith))
			{
				style.SetPressed(pressed);
				isModify = true;
			}
			FSlateBrush hovered = style.Hovered;
			if (SetSpriteBrush(hovered, endWith))
			{
				style.SetHovered(hovered);
				isModify = true;
			}
			FSlateBrush disabled = style.Disabled;
			if (SetSpriteBrush(disabled, endWith))
			{
				style.SetDisabled(disabled);
				isModify = true;
			}
			button->SetStyle(style);

		}
	}
	if (isModify)
	{
		UPackage* Package = widget->GetOutermost();
		savePackages.Add(Package);
	}

	/*
	for (int i = 0; i < assetDatas.Num(); i++)
	{
		UObject* widgetObject = assetDatas[i].GetAsset();

		UWidgetBlueprint* widget = Cast<UWidgetBlueprint>(widgetObject);
		if (widget == NULL)
			continue;

		TArray<UWidget*> childs;
		widget->WidgetTree->GetAllWidgets(childs);

		isModify = false;
		for (int j = 0; j < childs.Num(); j++)
		{

			if (UImage* image = Cast<UImage>(childs[j]))
			{
				FSlateBrush brush = image->Brush;

				if (SetSpriteBrush(brush))
				{
					image->SetBrush(brush);
					isModify = true;
				}
			}
			else if (UBorder* border = Cast<UBorder>(childs[j]))
			{
				FSlateBrush brush = border->Background;
				if (SetSpriteBrush(brush))
				{
					border->SetBrush(brush);
					isModify = true;
				}
			}
			else if (UButton* button = Cast<UButton>(childs[j]))
			{
				FButtonStyle style = button->WidgetStyle;
				FSlateBrush normal = style.Normal;
				if (SetSpriteBrush(normal))
				{
					style.SetNormal(normal);
					isModify = true;
				}
				FSlateBrush pressed = style.Pressed;
				if (SetSpriteBrush(pressed))
				{
					style.SetPressed(pressed);
					isModify = true;
				}
				FSlateBrush hovered = style.Hovered;
				if (SetSpriteBrush(hovered))
				{
					style.SetHovered(hovered);
					isModify = true;
				}
				FSlateBrush disabled = style.Disabled;
				if (SetSpriteBrush(disabled))
				{
					style.SetDisabled(disabled);
					isModify = true;
				}
				button->SetStyle(style);

			}
		}
		if (isModify)
		{
			UPackage* Package = widget->GetOutermost();
			savePackages.Add(Package);
		}
	}
	*/
	UEditorLoadingAndSavingUtils::SavePackagesWithDialog(savePackages, false);
}

void UUISpriteSheetHelper::ExportSelectedImage() 
{
	TArray<UObject*> ObjectsToExport;
	
	TArray<FAssetData> SelectedAssets;
	FContentBrowserModule& ContentBrowserModule = FModuleManager::LoadModuleChecked<FContentBrowserModule>("ContentBrowser");
	ContentBrowserModule.Get().GetSelectedAssets(SelectedAssets);

	for (const FAssetData& AssetData : SelectedAssets) 
	{
		FString AssetClassName = AssetData.GetClass()->GetName();
		if (AssetClassName != "Texture2D")
			continue;
		UObject* obj = AssetData.GetAsset();
		ObjectsToExport.Add(obj);
	}

	if (ObjectsToExport.Num() > 0)
	{
		FAssetToolsModule& AssetToolsModule = FModuleManager::GetModuleChecked<FAssetToolsModule>("AssetTools");

		AssetToolsModule.Get().ExportAssetsWithDialog(ObjectsToExport, false);
	}
}

TArray<UWidgetBlueprint*> UUISpriteSheetHelper::GetSelectedWidget() 
{
	TArray<UWidgetBlueprint*> SelectedWidgetBlueprints;

	TArray<FAssetData> SelectedAssets;
	FContentBrowserModule& ContentBrowserModule = FModuleManager::LoadModuleChecked<FContentBrowserModule>("ContentBrowser");
	ContentBrowserModule.Get().GetSelectedAssets(SelectedAssets);

	for (const FAssetData& AssetData : SelectedAssets)
	{
		FString AssetClassName = AssetData.GetClass()->GetName();
		if (AssetClassName == "WidgetBlueprint")
		{
			UWidgetBlueprint* WidgetBlueprint = Cast<UWidgetBlueprint>(AssetData.GetAsset());
			if (WidgetBlueprint)
			{
				SelectedWidgetBlueprints.Add(WidgetBlueprint);
			}
		}
	}

	return SelectedWidgetBlueprints;
}

bool UUISpriteSheetHelper::SetSpriteBrush(FSlateBrush& brush, const FString& endWith)
{
	auto resourceObj = brush.GetResourceObject();
	if (resourceObj == NULL)
		return false;
	const FName originName = resourceObj->GetFName();
	FAssetData findAssert = GetAssertByName(originName, endWith);
	if (findAssert == NULL)
		return false;
	brush.SetResourceObject(findAssert.GetAsset());
	return true;
}


FAssetData UUISpriteSheetHelper::GetAssertByName(const FName imageName, const FString& endWith)
{
	FString resouceName = imageName.ToString() + endWith;
	for (int i = 0; i < SpriteAssets.Num(); i++)
	{
		if (SpriteAssets[i].AssetName.ToString().Equals(resouceName))
			return SpriteAssets[i];
	}
	return NULL;
}

// ִ��bat
void UUISpriteSheetHelper::RunSpriteSheetPacking(const FString& TPLocation, const FString& FolderPath, const FString& SpriteSheetPath, const FString& AltasName)
{
	FString ProjectPath = FPaths::IsProjectFilePathSet() ? FPaths::ConvertRelativePathToFull(FPaths::ProjectDir()) : FPaths::RootDir() / FApp::GetProjectName();
	FString OutputPath = FString::Printf(TEXT("%ls%s/%s"), *ProjectPath, *SpriteSheetPath, *AltasName);

	FString ImagePath = FolderPath.Replace(TEXT("/"), TEXT("\\"));
	OutputPath = OutputPath.Replace(TEXT("/"), TEXT("\\"));

	FString BatPath = FPaths::ProjectDir() + "Content/ArtsTest/TA/zhaoxiaoqi03/UITools/TextureToSpriteEditor/PackSpriteSheet.bat";
	FString BatchFileContent;

	UE_LOG(LogTemp, Log, TEXT("OutputPath:%s"), *OutputPath);

	FString Command = FString::Printf(TEXT("\"%s\" \"%s\""), *ImagePath, *OutputPath);

	//if (FFileHelper::LoadFileToString(BatchFileContent, *BatPath))
	//{
		 //UE_LOG(LogTemp, Warning, TEXT("Batch File Content: %s"), *BatchFileContent);
	//}
	//FPlatformProcess::CreateProc(*BatPath, *Params, true, false, false, nullptr, 0, nullptr, nullptr);
	int32 ResultCode;
	FString StdOut;
	FString StdErr;
	bool bResult = FPlatformProcess::ExecProcess(*BatPath, *Command, &ResultCode, &StdOut, &StdErr);
	UE_LOG(LogTemp, Log, TEXT("ResultCode:%d\nStdOut:%s\nStdErr:%s"), ResultCode, *StdOut, *StdErr);
	if (bResult) {
		FMessageDialog::Open(EAppMsgType::Ok, FText::FromString("[[SUCCESS]] to ExportSpriteSheet"));
	}
}

FString UUISpriteSheetHelper::OpenAndReadDirectory()
{
	// ���ļ���ѡ��Ի���
	FString SelectedDirectory;
	FString SelectedDirectoryPath;
	IDesktopPlatform* DesktopPlatform = FDesktopPlatformModule::Get();
	if (DesktopPlatform)
	{
		const bool bFolderSelected = DesktopPlatform->OpenDirectoryDialog(
			nullptr, // �����ھ�������Ϊnullptr����Ի�����ʾ����Ļ����
			TEXT("Select UI directory"), // �Ի������
			TEXT(""), // ��ʼĿ¼
			SelectedDirectory // ���ڴ洢��ѡĿ¼���ַ���
		);
		if (!bFolderSelected)
		{
			// �û�ȡ����ѡ��
			UE_LOG(LogTemp, Log, TEXT("FolderClosed"));
			return TEXT("");
		}
	}
	UE_LOG(LogTemp, Log, TEXT("selectedDirPath : %s"),*SelectedDirectory);
	return SelectedDirectory;
	//// ��¼��ѡ�ļ��а������������ļ���
	//IFileManager& FileManager = IFileManager::Get();
	//TArray<FString> SubDirectories;
	//FileManager.IterateDirectory(*SelectedDirectory, [&](const FString& FilePath, bool bIsDirectory) -> bool {
	//	if (bIsDirectory && FilePath != SelectedDirectory) // �����һ��Ŀ¼�Ҳ�����ѡĿ¼����
	//	{
	//		SubDirectories.Add(FilePath); // ��ӵ�������
	//	}
	//	return true;
	//	});

	//return SubDirectories;
}
