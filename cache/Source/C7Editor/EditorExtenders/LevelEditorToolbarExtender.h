// Copyright KuaiShou Games, Inc. All Rights Reserved.
// Author: liuruilin@kuaishou.com

#pragma once
#include "CoreMinimal.h"

/**
 * 扩展 Level Editor 的 Toolbar 上
 */
class FLevelEditorToolbarExtender
{
public:
	static FLevelEditorToolbarExtender* GetInstance();
	
private:
	FLevelEditorToolbarExtender();
	static TSharedPtr<FLevelEditorToolbarExtender> Instance;
	void Initialize();

	/** 增加一个Menu菜单, 用于切换 Preview Platform / Feature Level. @wangchenguang03 */
	void RegisterPlatformToolbar();
	TSharedRef<SWidget> GeneratePlatformMenuContent();
	void GenerateSubPlatformMenu(FMenuBuilder& MenuBuilder, FPreviewPlatformInfo NewPreviewPlatform);
	bool IsPreviewPlatformChecked(FPreviewPlatformInfo NewPreviewPlatform);
	static ECheckBoxState IsActorQualityChecked(EMaterialQualityLevel::Type QualityLevel);
	static void SetActorQuality(FPreviewPlatformInfo NewPreviewPlatform, EMaterialQualityLevel::Type QualityLevel);
	static void SetMaterialAndPreviewPlatform(FPreviewPlatformInfo NewPreviewPlatform, EMaterialQualityLevel::Type QualityLevel);
	FText GetMaterialQualityLevelLabel();
	FText GetPlatformToolTip();
	FSlateIcon GetPlatformIcon();
	void TryRemoveOldPlatformMenu();
	bool OldMenuRemoved = false;
	TArray<FName> MaterialQualityLevelNames;
	
	static void SetScalabilityQuality(int Quality);
	static ECheckBoxState IsSetScalabilityQualityChecked(int Quality);
	
	FName MyGetMaterialQualityLevelFName(EMaterialQualityLevel::Type InQualityLevel) const;
};
