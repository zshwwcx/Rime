#include "LevelEditorToolbarExtender.h"

#include "DataDrivenShaderPlatformInfo.h"
#include "LevelEditorActions.h"

#define LOCTEXT_NAMESPACE "FLevelEditorToolbarExtender"

TSharedPtr<FLevelEditorToolbarExtender> FLevelEditorToolbarExtender::Instance;

FLevelEditorToolbarExtender* FLevelEditorToolbarExtender::GetInstance()
{
	if (!Instance.IsValid())
	{
		Instance = MakeShareable(new FLevelEditorToolbarExtender());
	}

	return Instance.Get();
}

FLevelEditorToolbarExtender::FLevelEditorToolbarExtender()
{
	Initialize();
}

void FLevelEditorToolbarExtender::Initialize()
{
	RegisterPlatformToolbar();
}

void FLevelEditorToolbarExtender::RegisterPlatformToolbar()
{
	MaterialQualityLevelNames = TArray
	{
		FName(TEXT("Low")),
		FName(TEXT("High")),
		FName(TEXT("Medium")),
		FName(TEXT("Epic")),
		FName(TEXT("Num"))
	};
	UToolMenu* PlayToolBar = UToolMenus::Get()->RegisterMenu("LevelEditor.LevelEditorToolBar.PlayToolBar", NAME_None, EMultiBoxType::SlimHorizontalToolBar, false);
	FToolMenuSection& PlaySection = PlayToolBar->AddSection("Play");
	PlaySection.AddSeparator(NAME_None);
	PlaySection.AddEntry(FToolMenuEntry::InitComboButton(
		"AdvancePlatformMenu",
		FUIAction(),
		FOnGetContent::CreateRaw(this, &FLevelEditorToolbarExtender::GeneratePlatformMenuContent),
		TAttribute<FText>::Create(TAttribute<FText>::FGetter::CreateRaw(this, &FLevelEditorToolbarExtender::GetMaterialQualityLevelLabel)),
		TAttribute<FText>::Create(TAttribute<FText>::FGetter::CreateRaw(this, &FLevelEditorToolbarExtender::GetPlatformToolTip)),
		TAttribute<FSlateIcon>::Create(TAttribute<FSlateIcon>::FGetter::CreateRaw(this, &FLevelEditorToolbarExtender::GetPlatformIcon))
	));
}

TSharedRef<SWidget> FLevelEditorToolbarExtender::GeneratePlatformMenuContent()
{
	FMenuBuilder MenuBuilder(true, nullptr);

	MenuBuilder.BeginSection("EditorPreviewMode", LOCTEXT("EditorPreviewModeDevices", "Preview Devices"));

	const TArray<FPreviewPlatformMenuItem>& MenuItems = FDataDrivenPlatformInfoRegistry::GetAllPreviewPlatformMenuItems();
	const TArray<TSharedPtr<FUICommandInfo>>& FuiCommandInfos = FLevelEditorCommands::Get().PreviewPlatformOverrides;
	for (int32 Index = 0; Index < MenuItems.Num(); Index++)
	{
		const FPreviewPlatformMenuItem& Item = MenuItems[Index];
		const EShaderPlatform ShaderPlatform = FDataDrivenShaderPlatformInfo::GetShaderPlatformFromName(Item.PreviewShaderPlatformName);

		if (ShaderPlatform < SP_NumPlatforms)
		{
			const ERHIFeatureLevel::Type FeatureLevel = GetMaxSupportedFeatureLevel(ShaderPlatform);

			const bool bIsDefaultShaderPlatform = FDataDrivenShaderPlatformInfo::GetPreviewShaderPlatformParent(ShaderPlatform) == GMaxRHIShaderPlatform;

			FPreviewPlatformInfo PreviewFeatureLevelInfo(bIsDefaultShaderPlatform ? GMaxRHIFeatureLevel : FeatureLevel,
				bIsDefaultShaderPlatform ? GMaxRHIShaderPlatform : static_cast<EShaderPlatform>(ShaderPlatform),
				bIsDefaultShaderPlatform ? NAME_None : Item.PlatformName, bIsDefaultShaderPlatform ? NAME_None : Item.ShaderFormat,
				bIsDefaultShaderPlatform ? NAME_None : Item.DeviceProfileName, true, bIsDefaultShaderPlatform ? NAME_None : Item.PreviewShaderPlatformName);
			const TSharedPtr<FUICommandInfo>& CommandInfo = FuiCommandInfos[Index];

			MenuBuilder.AddSubMenu(
				CommandInfo->GetLabel(),
				FText::GetEmpty(),
				FNewMenuDelegate::CreateRaw(this, &FLevelEditorToolbarExtender::GenerateSubPlatformMenu, PreviewFeatureLevelInfo),
				FUIAction(
					FExecuteAction(),
					bIsDefaultShaderPlatform ? FCanExecuteAction() : FCanExecuteAction::CreateStatic(&FLevelEditorActionCallbacks::CanExecutePreviewPlatform, PreviewFeatureLevelInfo),
					FIsActionChecked::CreateRaw(this, &FLevelEditorToolbarExtender::IsPreviewPlatformChecked, PreviewFeatureLevelInfo)
				),
				NAME_None,
				!GEditor->IsFeatureLevelPreviewActive() && FLevelEditorActionCallbacks::IsPreviewPlatformChecked(PreviewFeatureLevelInfo)
					? EUserInterfaceActionType::RadioButton : EUserInterfaceActionType::Check
			);
		}
	}
	
	MenuBuilder.EndSection();
	
	MenuBuilder.BeginSection("EditorPreviewMode", LOCTEXT("EditorPreviewModeToggle", "Toggle Preview"));
	
	MenuBuilder.AddMenuEntry(FText::FromString("Toggle Preview"), FText::GetEmpty(), FSlateIcon(), FUIAction(
		FExecuteAction::CreateLambda([](){GEditor->ToggleFeatureLevelPreview();}),
		FCanExecuteAction(),
		FIsActionChecked::CreateLambda([](){return GEditor->IsFeatureLevelPreviewActive();})
	), NAME_None, EUserInterfaceActionType::ToggleButton);
	MenuBuilder.EndSection();
	return MenuBuilder.MakeWidget();
}

void FLevelEditorToolbarExtender::GenerateSubPlatformMenu(FMenuBuilder& MenuBuilder, FPreviewPlatformInfo NewPreviewPlatform)
{
	// EMaterialQualityLevel 顺序太抽象了
	TArray<EMaterialQualityLevel::Type> Types = TArray{EMaterialQualityLevel::Type::Low, EMaterialQualityLevel::Type::Medium,
		EMaterialQualityLevel::Type::High, EMaterialQualityLevel::Type::Epic};

	MenuBuilder.BeginSection(TEXT("ActorQualities"), LOCTEXT("ActorQualitiesSectionLabel", "Actor Quality: Effect+Material"));
	for (int i = 0; i < Types.Num(); i++)
	{
		MenuBuilder.AddMenuEntry(FText::FromName(MyGetMaterialQualityLevelFName(Types[i])), FText::GetEmpty(), FSlateIcon(), FUIAction(
		FExecuteAction::CreateStatic(&FLevelEditorToolbarExtender::SetActorQuality, NewPreviewPlatform, Types[i]),
			FCanExecuteAction(),
			FGetActionCheckState::CreateStatic(&FLevelEditorToolbarExtender::IsActorQualityChecked, Types[i])
		), NAME_None, EUserInterfaceActionType::ToggleButton);
	}
	MenuBuilder.EndSection();
	
	MenuBuilder.BeginSection(TEXT("MaterialQualities"), LOCTEXT("MaterialQualitiesSectionLabel", "Material Quality"));
	for (int i = 0; i < Types.Num(); i++)
	{
		MenuBuilder.AddMenuEntry(FText::FromName(MyGetMaterialQualityLevelFName(Types[i])), FText::GetEmpty(), FSlateIcon(), FUIAction(
		FExecuteAction::CreateStatic(&FLevelEditorToolbarExtender::SetMaterialAndPreviewPlatform, NewPreviewPlatform, Types[i]),
			FCanExecuteAction(),
			FIsActionChecked::CreateStatic(&FLevelEditorActionCallbacks::IsMaterialQualityLevelChecked, Types[i])
		), NAME_None, EUserInterfaceActionType::Check);
	}
	MenuBuilder.EndSection();
	
	const FText NamesLow(LOCTEXT("QualityLowLabel", "Low"));
	const FText NamesMedium(LOCTEXT("QualityMediumLabel", "Medium"));
	const FText NamesHigh(LOCTEXT("QualityHighLabel", "High"));
	const FText NamesEpic(LOCTEXT("QualityEpicLabel", "Epic"));
	const FText NamesCine(LOCTEXT("QualityCineLabel", "Cinematic"));
	const FText FiveNames[5] = { NamesLow, NamesMedium, NamesHigh, NamesEpic, NamesCine };

	MenuBuilder.BeginSection(TEXT("ScalabilitySection"), LOCTEXT("ScalabilitySectionLabel", "Scalability"));
	for (int i = 0; i < 5; i++)
	{
		MenuBuilder.AddMenuEntry(FiveNames[i], FText::GetEmpty(), FSlateIcon(), FUIAction(
		FExecuteAction::CreateStatic(&FLevelEditorToolbarExtender::SetScalabilityQuality, i),
			FCanExecuteAction(),
			FGetActionCheckState::CreateStatic(&FLevelEditorToolbarExtender::IsSetScalabilityQualityChecked, i)
		), NAME_None, EUserInterfaceActionType::ToggleButton);
	}
	MenuBuilder.EndSection();
}

bool FLevelEditorToolbarExtender::IsPreviewPlatformChecked(FPreviewPlatformInfo NewPreviewPlatform)
{
	if (FLevelEditorActionCallbacks::IsPreviewPlatformChecked(NewPreviewPlatform))
	{
		return GEditor->IsFeatureLevelPreviewActive();
	}
	return false;
}

ECheckBoxState FLevelEditorToolbarExtender::IsActorQualityChecked(EMaterialQualityLevel::Type QualityLevel)
{
	bool bIsMaterialQualityLevelChecked = FLevelEditorActionCallbacks::IsMaterialQualityLevelChecked(QualityLevel);

	const Scalability::FQualityLevels QualityLevels = Scalability::GetQualityLevels();
	int32 EffectQualityLevel = 0;
	switch (QualityLevel)
	{
	case EMaterialQualityLevel::Low:
		EffectQualityLevel = 0;
		break;
	case EMaterialQualityLevel::Medium:
		EffectQualityLevel = 1;
		break;
	case EMaterialQualityLevel::High:
		EffectQualityLevel = 2;
		break;
	case EMaterialQualityLevel::Epic:
		EffectQualityLevel = 3;
		break;
	case EMaterialQualityLevel::Num:
		break;
	} 
	bool bIsEffectChecked = QualityLevels.EffectsQuality == EffectQualityLevel;

	if (bIsMaterialQualityLevelChecked && bIsEffectChecked)
		return ECheckBoxState::Checked;
	if (bIsMaterialQualityLevelChecked || bIsEffectChecked)
		return ECheckBoxState::Undetermined;
	return ECheckBoxState::Unchecked;
}

void FLevelEditorToolbarExtender::SetActorQuality(FPreviewPlatformInfo NewPreviewPlatform, EMaterialQualityLevel::Type QualityLevel)
{
	FLevelEditorActionCallbacks::SetPreviewPlatform(NewPreviewPlatform);

	// EffectsQuality 中已经包含了材质质量的配置. 只设置 EffectsQuality 就好啦
	int32 EffectQualityLevel = 0;
	switch (QualityLevel)
	{
	case EMaterialQualityLevel::Low:
		EffectQualityLevel = 0;
		break;
	case EMaterialQualityLevel::Medium:
		EffectQualityLevel = 1;
		break;
	case EMaterialQualityLevel::High:
		EffectQualityLevel = 2;
		break;
	case EMaterialQualityLevel::Epic:
		EffectQualityLevel = 3;
		break;
	case EMaterialQualityLevel::Num:
		break;
	} 
	Scalability::FQualityLevels QualityLevels = Scalability::GetQualityLevels();
	QualityLevels.SetEffectsQuality(EffectQualityLevel);
	Scalability::SetQualityLevels(QualityLevels);
}

void FLevelEditorToolbarExtender::SetMaterialAndPreviewPlatform(FPreviewPlatformInfo NewPreviewPlatform, EMaterialQualityLevel::Type QualityLevel)
{
	FLevelEditorActionCallbacks::SetPreviewPlatform(NewPreviewPlatform);
	FLevelEditorActionCallbacks::SetMaterialQualityLevel(QualityLevel);
}

FText FLevelEditorToolbarExtender::GetMaterialQualityLevelLabel()
{
	static const auto MaterialQualityLevelVar = IConsoleManager::Get().FindTConsoleVariableDataInt(TEXT("r.MaterialQualityLevel"));
	const EMaterialQualityLevel::Type MaterialQualityLevel = static_cast<EMaterialQualityLevel::Type>(
		FMath::Clamp(MaterialQualityLevelVar->GetValueOnGameThread(), 0, static_cast<int32>(EMaterialQualityLevel::Num) - 1));
	return FText::FromName(MyGetMaterialQualityLevelFName(MaterialQualityLevel));
}

FText FLevelEditorToolbarExtender::GetPlatformToolTip()
{
	const EShaderPlatform PreviewShaderPlatform = GEditor->PreviewPlatform.PreviewShaderPlatformName != NAME_None ?
	                                              FDataDrivenShaderPlatformInfo::GetShaderPlatformFromName(GEditor->PreviewPlatform.PreviewShaderPlatformName) :
	                                              GetFeatureLevelShaderPlatform(GEditor->PreviewPlatform.PreviewFeatureLevel);

	const EShaderPlatform MaxRHIFeatureLevelPlatform = GetFeatureLevelShaderPlatform(GMaxRHIFeatureLevel);
	const FText MaterialQualityLevelLabel = this->GetMaterialQualityLevelLabel();
	const FText& RenderingAsPlatformName = FDataDrivenShaderPlatformInfo::GetFriendlyName(GEditor->PreviewPlatform.bPreviewFeatureLevelActive ? PreviewShaderPlatform : MaxRHIFeatureLevelPlatform);
	if (PreviewShaderPlatform == MaxRHIFeatureLevelPlatform)
	{
		return FText::Format(LOCTEXT("PreviewModeViewingAs", "Viewing {0} ({1})."), RenderingAsPlatformName, MaterialQualityLevelLabel);
	}
	if (GWorld->GetFeatureLevel() == GMaxRHIFeatureLevel)
	{
		return FText::Format(LOCTEXT("PreviewModeViewingAsSwitchTo", "Viewing {0} ({1})."), RenderingAsPlatformName, MaterialQualityLevelLabel);
	}
	return FText::Format(LOCTEXT("PreviewModePreviewingAsSwitchTo", "Previewing {0} ({1})."), RenderingAsPlatformName, MaterialQualityLevelLabel);
}

FSlateIcon FLevelEditorToolbarExtender::GetPlatformIcon()
{
	if (!OldMenuRemoved)
	{
		TryRemoveOldPlatformMenu();
	}
	
	const FPreviewPlatformMenuItem* Item = FDataDrivenPlatformInfoRegistry::GetAllPreviewPlatformMenuItems().FindByPredicate([](const FPreviewPlatformMenuItem& TestItem)
		{
			return GEditor->PreviewPlatform.PreviewPlatformName == TestItem.PlatformName && GEditor->PreviewPlatform.PreviewShaderFormatName == TestItem.ShaderFormat && GEditor->PreviewPlatform.PreviewShaderPlatformName == TestItem.PreviewShaderPlatformName;
		});
	if (Item)
	{
		if (Item->ActiveIconName != NAME_None)
			return FSlateIcon(FAppStyle::GetAppStyleSetName(), GEditor->IsFeatureLevelPreviewActive() ? Item->ActiveIconName : Item->InactiveIconName);
		else
			return FSlateIcon(FAppStyle::GetAppStyleSetName(), "MultiBox.GenericToolBarIcon");
	}

	EShaderPlatform ShaderPlatform = FDataDrivenShaderPlatformInfo::GetShaderPlatformFromName(GEditor->PreviewPlatform.PreviewShaderPlatformName);

	if (ShaderPlatform == SP_NumPlatforms)
	{
		ShaderPlatform = GetFeatureLevelShaderPlatform(GEditor->PreviewPlatform.PreviewFeatureLevel);
	}
	switch (GEditor->PreviewPlatform.PreviewFeatureLevel)
	{
	case ERHIFeatureLevel::ES3_1:
		{
			return FSlateIcon(FAppStyle::GetAppStyleSetName(), GEditor->IsFeatureLevelPreviewActive() ? "LevelEditor.PreviewMode.Enabled" : "LevelEditor.PreviewMode.Disabled");
		}
	default:
		{
			return FSlateIcon(FAppStyle::GetAppStyleSetName(), GEditor->IsFeatureLevelPreviewActive() ? "LevelEditor.PreviewMode.Enabled" : "LevelEditor.PreviewMode.Disabled");
		}
	}
}

void FLevelEditorToolbarExtender::TryRemoveOldPlatformMenu()
{
	UToolMenus* ToolMenus = UToolMenus::Get();
	if (ToolMenus != nullptr)
	{
		UToolMenu* ToolMenu = ToolMenus->FindMenu("LevelEditor.LevelEditorToolBar.PlayToolBar");
		FToolMenuSection* Section = ToolMenu->FindSection("Play");

		if (Section->FindEntry("ToggleFeatureLevelPreview") != nullptr)
		{
			ToolMenus->RemoveEntry("LevelEditor.LevelEditorToolBar.PlayToolBar", "Play", "ToggleFeatureLevelPreview");
			OldMenuRemoved = true;
		}
	}
}

void FLevelEditorToolbarExtender::SetScalabilityQuality(int Quality)
{
	Scalability::FQualityLevels QualityLevels = Scalability::GetQualityLevels();
	QualityLevels.SetViewDistanceQuality(Quality);
    QualityLevels.SetAntiAliasingQuality(Quality);
    QualityLevels.SetShadowQuality(Quality);
    QualityLevels.SetGlobalIlluminationQuality(Quality);
    QualityLevels.SetReflectionQuality(Quality);
    QualityLevels.SetPostProcessQuality(Quality);
    QualityLevels.SetTextureQuality(Quality);
    QualityLevels.SetEffectsQuality(Quality);
    QualityLevels.SetFoliageQuality(Quality);
    QualityLevels.SetShadingQuality(Quality);
    QualityLevels.SetLandscapeQuality(Quality);
	Scalability::SetQualityLevels(QualityLevels);
}

ECheckBoxState FLevelEditorToolbarExtender::IsSetScalabilityQualityChecked(int Quality)
{
	Scalability::FQualityLevels QualityLevels = Scalability::GetQualityLevels();
	bool bContainsAny = false;
	bool bContainsAll = true;
	bContainsAny |= QualityLevels.ViewDistanceQuality == Quality;
	bContainsAny |= QualityLevels.AntiAliasingQuality == Quality;
	bContainsAny |= QualityLevels.ShadowQuality == Quality;
	bContainsAny |= QualityLevels.GlobalIlluminationQuality == Quality;
	bContainsAny |= QualityLevels.ReflectionQuality == Quality;
	bContainsAny |= QualityLevels.PostProcessQuality == Quality;
	bContainsAny |= QualityLevels.TextureQuality == Quality;
	bContainsAny |= QualityLevels.EffectsQuality == Quality;
	bContainsAny |= QualityLevels.FoliageQuality == Quality;
	bContainsAny |= QualityLevels.ShadingQuality == Quality;
	bContainsAny |= QualityLevels.LandscapeQuality == Quality;

	// 展开第三条宏调用
	bContainsAll &= QualityLevels.ViewDistanceQuality == Quality;
	bContainsAll &= QualityLevels.AntiAliasingQuality == Quality;
	bContainsAll &= QualityLevels.ShadowQuality == Quality;
	bContainsAll &= QualityLevels.GlobalIlluminationQuality == Quality;
	bContainsAll &= QualityLevels.ReflectionQuality == Quality;
	bContainsAll &= QualityLevels.PostProcessQuality == Quality;
	bContainsAll &= QualityLevels.TextureQuality == Quality;
	bContainsAll &= QualityLevels.EffectsQuality == Quality;
	bContainsAll &= QualityLevels.FoliageQuality == Quality;
	bContainsAll &= QualityLevels.ShadingQuality == Quality;
	bContainsAll &= QualityLevels.LandscapeQuality == Quality;
	if (bContainsAll)
		return ECheckBoxState::Checked;
	if (bContainsAny)
		return ECheckBoxState::Undetermined;
	return ECheckBoxState::Unchecked;
}

FName FLevelEditorToolbarExtender::MyGetMaterialQualityLevelFName(EMaterialQualityLevel::Type InQualityLevel) const
{
	return MaterialQualityLevelNames[static_cast<int32>(InQualityLevel)];
}

#undef LOCTEXT_NAMESPACE
