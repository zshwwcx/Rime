// 主要从HighresScreenshotUI复制过来，因为这是个私有类
#if WITH_EDITOR
#pragma once

#include "CoreMinimal.h"
#include "Layout/Visibility.h"
#include "Input/Reply.h"
#include "ViewportClient.h"
#include "Widgets/DeclarativeSyntaxSupport.h"
#include "ShowFlags.h"
#include "Widgets/SCompoundWidget.h"
#include "Styling/SlateTypes.h"
#include "Slate/SceneViewport.h"
#include "HighResScreenshot.h"

class SButton;
class SCheckBox;
class STextBlock;

class C7_API SHighResScreenshotDialog : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SHighResScreenshotDialog) {}
		SLATE_EVENT(FOnClicked, OnTakeScreenShoot)
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs);

	SHighResScreenshotDialog();

	FHighResScreenshotConfig& GetConfig()
	{
		return Config;
	}

private:

	FReply OnCaptureClicked();

	void OnResolutionMultiplierSliderChanged(float NewValue)
	{
		Config.ResolutionMultiplier = NewValue;

		// scale needs to be [0, 1.0]
		Config.ResolutionMultiplierScale = (NewValue - FHighResScreenshotConfig::MinResolutionMultipler) / (FHighResScreenshotConfig::MaxResolutionMultipler - FHighResScreenshotConfig::MinResolutionMultipler);
	}

	void OnMaskEnabledChanged(ECheckBoxState NewValue)
	{
		Config.bMaskEnabled = (NewValue == ECheckBoxState::Checked);
		auto ConfigViewport = Config.TargetViewport.Pin();
		if (ConfigViewport.IsValid())
		{
			ConfigViewport->GetClient()->GetEngineShowFlags()->SetHighResScreenshotMask(Config.bMaskEnabled);
			ConfigViewport->Invalidate();
		}
	}

	void OnHDREnabledChanged(ECheckBoxState NewValue)
	{
		Config.SetHDRCapture(NewValue == ECheckBoxState::Checked);
		auto ConfigViewport = Config.TargetViewport.Pin();
		if (ConfigViewport.IsValid())
		{
			ConfigViewport->Invalidate();
		}
	}

	void OnForce128BitRenderingChanged(ECheckBoxState NewValue)
	{
		Config.SetForce128BitRendering(NewValue == ECheckBoxState::Checked);
		auto ConfigViewport = Config.TargetViewport.Pin();
		if (ConfigViewport.IsValid())
		{
			ConfigViewport->Invalidate();
		}
	}

	void OnDateTimeBasedNamingEnabledChanged(ECheckBoxState NewValue)
	{
		bool bEnabled = (NewValue == ECheckBoxState::Checked);
		Config.bDateTimeBasedNaming = bEnabled;
	}

	void OnBufferVisualizationDumpEnabledChanged(ECheckBoxState NewValue)
	{
		bool bEnabled = (NewValue == ECheckBoxState::Checked);
		Config.bDumpBufferVisualizationTargets = bEnabled;
		SetHDRUIEnableState(bEnabled);
		SetForce128BitRenderingState(bEnabled);
	}

	float GetResolutionMultiplierSlider() const
	{
		return Config.ResolutionMultiplier;
	}

	ECheckBoxState GetMaskEnabled() const
	{
		return Config.bMaskEnabled ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
	}

	ECheckBoxState GetHDRCheckboxUIState() const
	{
		return Config.bCaptureHDR ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
	}

	ECheckBoxState GetForce128BitRenderingCheckboxUIState() const
	{
		return Config.bForce128BitRendering ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
	}

	ECheckBoxState GetBufferVisualizationDumpEnabled() const
	{
		return Config.bDumpBufferVisualizationTargets ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
	}

	ECheckBoxState GetDateTimeBasedNamingEnabled() const
	{
		return Config.bDateTimeBasedNaming ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
	}


	void SetHDRUIEnableState(bool bEnable)
	{
		HDRCheckBox->SetEnabled(bEnable);
		HDRLabel->SetEnabled(bEnable);
	}

	void SetForce128BitRenderingState(bool bEnable)
	{
		Force128BitRenderingCheckBox->SetEnabled(bEnable);
		Force128BitRenderingLabel->SetEnabled(bEnable);
	}

	TSharedPtr<SCheckBox> HDRCheckBox;
	TSharedPtr<STextBlock> HDRLabel;
	TSharedPtr<SCheckBox> Force128BitRenderingCheckBox;
	TSharedPtr<STextBlock> Force128BitRenderingLabel;

	FOnClicked OnTakeScreenShoot;

	FHighResScreenshotConfig& Config;
};

#endif
