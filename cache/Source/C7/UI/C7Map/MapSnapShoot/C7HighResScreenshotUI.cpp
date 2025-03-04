#if WITH_EDITOR
#include "C7HighresScreenshotUI.h"
#include "Framework/Application/SlateApplication.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Layout/SGridPanel.h"
#include "Widgets/Input/SButton.h"
#include "Widgets/Layout/SSeparator.h"
#include "Widgets/Input/SSpinBox.h"
#include "Widgets/Input/SCheckBox.h"
#include "Widgets/Text/STextBlock.h"
#include "SWarningOrErrorBox.h"
#include "Styling/AppStyle.h"
#include "Kismet/KismetSystemLibrary.h"

SHighResScreenshotDialog::SHighResScreenshotDialog()
: Config(GetHighResScreenshotConfig())
{
}

void SHighResScreenshotDialog::Construct( const FArguments& InArgs )
{
	OnTakeScreenShoot = InArgs._OnTakeScreenShoot;
	FMargin GridPadding(6.f, 3.f);
	this->ChildSlot
	.Padding(0.f)
	[
		SNew(SBorder)
		.Padding(0.f)
		.BorderImage(FAppStyle::Get().GetBrush("ToolPanel.GroupBorder"))
		[
			SNew(SVerticalBox)
			+SVerticalBox::Slot()
			.AutoHeight()
			[
				SNew(SSeparator)
				.Thickness(1.f)
				.SeparatorImage(FAppStyle::Get().GetBrush("Brushes.Background"))
			]

			+SVerticalBox::Slot()
			.Padding(6.0)
			.HAlign(HAlign_Fill)
			[
				// Row/Column
				SNew(SGridPanel) 
				.FillColumn(1, 1.0f)

				+SGridPanel::Slot(0, 0)
				.Padding(GridPadding)
				.VAlign(VAlign_Center)
				[
					SNew( STextBlock )
					.Text( NSLOCTEXT("HighResScreenshot", "ScreenshotSizeMultiplier", "Screenshot Size Multiplier") )
				]
				+SGridPanel::Slot(0, 1)
				.Padding(GridPadding)
				[
					SNew( STextBlock )
					.Text( NSLOCTEXT("HighResScreenshot", "UseDateTimeAsImageName", "Use Date & Timestamp as Image name") )
				]
				+ SGridPanel::Slot(0, 2)
				.Padding(GridPadding)
				[
					SNew(STextBlock)
					.Text(NSLOCTEXT("HighResScreenshot", "IncludeBufferVisTargets", "Include Buffer Visualization Targets"))
				]
				+ SGridPanel::Slot(0, 3)
				.Padding(GridPadding)
				[
					SAssignNew(HDRLabel, STextBlock)
					.Text(NSLOCTEXT("HighResScreenshot", "CaptureHDR", "Write HDR format visualization targets"))
				]
				+SGridPanel::Slot(0, 4)
				.Padding(GridPadding)
				[
					SAssignNew(Force128BitRenderingLabel, STextBlock)
					.Text(NSLOCTEXT("HighResScreenshot", "Force128BitPipeline", "Force 128-bit buffers for rendering pipeline"))
				]
				+SGridPanel::Slot(0, 5)
				.Padding(GridPadding)
				[
					SNew( STextBlock )
					.Text( NSLOCTEXT("HighResScreenshot", "UseCustomDepth", "Use custom depth as mask") )
				]

				+SGridPanel::Slot(1, 0)
				.Padding(GridPadding)
				.HAlign(HAlign_Fill)
				[
						SNew( SSpinBox<float> )
						.MinValue(FHighResScreenshotConfig::MinResolutionMultipler)
						.MaxValue(FHighResScreenshotConfig::MaxResolutionMultipler)
						.Delta(1.0f)
						.Value(this, &SHighResScreenshotDialog::GetResolutionMultiplierSlider)
						.OnValueChanged(this, &SHighResScreenshotDialog::OnResolutionMultiplierSliderChanged)
				]
				+ SGridPanel::Slot(1, 1)
				.Padding(GridPadding)
				[
					SNew(SCheckBox)
					.OnCheckStateChanged(this, &SHighResScreenshotDialog::OnDateTimeBasedNamingEnabledChanged)
					.IsChecked(this, &SHighResScreenshotDialog::GetDateTimeBasedNamingEnabled)
				]
				+SGridPanel::Slot(1, 2)
				.Padding(GridPadding)
				[
					SNew( SCheckBox )
					.OnCheckStateChanged(this, &SHighResScreenshotDialog::OnBufferVisualizationDumpEnabledChanged)
					.IsChecked(this, &SHighResScreenshotDialog::GetBufferVisualizationDumpEnabled)
				]
				+ SGridPanel::Slot(1, 3)
				.Padding(GridPadding)
				[
					SAssignNew(HDRCheckBox, SCheckBox)
					.OnCheckStateChanged(this, &SHighResScreenshotDialog::OnHDREnabledChanged)
					.IsChecked(this, &SHighResScreenshotDialog::GetHDRCheckboxUIState)
				]
				+ SGridPanel::Slot(1, 4)
				.Padding(GridPadding)
				[
					SAssignNew(Force128BitRenderingCheckBox, SCheckBox)
					.OnCheckStateChanged(this, &SHighResScreenshotDialog::OnForce128BitRenderingChanged)
					.IsChecked(this, &SHighResScreenshotDialog::GetForce128BitRenderingCheckboxUIState)
				]
				+SGridPanel::Slot(1, 5)
				.Padding(GridPadding)
				[
					SNew( SCheckBox )
					.OnCheckStateChanged(this, &SHighResScreenshotDialog::OnMaskEnabledChanged)
					.IsChecked(this, &SHighResScreenshotDialog::GetMaskEnabled)
				]
			]

			+SVerticalBox::Slot()
			.AutoHeight()
			.Padding(16.f)
			[

				SNew(SHorizontalBox)
				+SHorizontalBox::Slot()
				[
					SNew(SWarningOrErrorBox)
					.Padding(FMargin(16.f, 13.f, 16.f, 13.f))
					.Message( NSLOCTEXT("HighResScreenshot", "CaptureWarningText", "Large multipliers may cause the graphics driver to crash.  Please try using a lower multiplier.") )
					.Visibility_Lambda( [this] () { return Config.ResolutionMultiplier >= 3. ? EVisibility::Visible : EVisibility::Hidden; })
				]

				+SHorizontalBox::Slot()
				.VAlign(VAlign_Bottom)
				.HAlign(HAlign_Right)
				.AutoWidth()
				.Padding(FMargin(24.f, 0.f, 0.f, 0.f))
				[
					SNew( SButton )
					.ButtonStyle(&FAppStyle::Get().GetWidgetStyle<FButtonStyle>("PrimaryButton"))
					.ToolTipText(NSLOCTEXT("HighResScreenshot", "ScreenshotCaptureTooltop", "Take a screenshot") )
					.OnClicked(this, &SHighResScreenshotDialog::OnCaptureClicked )
					.Text(NSLOCTEXT("HighResScreenshot", "CaptureCommit", "Capture"))
				]
			]
		]
	];

	SetHDRUIEnableState(Config.bDumpBufferVisualizationTargets);
	SetForce128BitRenderingState(Config.bDumpBufferVisualizationTargets);
	//bCaptureRegionControlsVisible = false;
}


FReply SHighResScreenshotDialog::OnCaptureClicked()
{
	if (!GIsHighResScreenshot)
	{
		auto ConfigViewport = Config.TargetViewport.Pin();
		if (ConfigViewport.IsValid())
		{
			GScreenshotResolutionX = ConfigViewport->GetRenderTargetTextureSizeXY().X * Config.ResolutionMultiplier;
			GScreenshotResolutionY = ConfigViewport->GetRenderTargetTextureSizeXY().Y * Config.ResolutionMultiplier;
			FIntRect ScaledCaptureRegion = Config.UnscaledCaptureRegion;

			if (ScaledCaptureRegion.Area() > 0)
			{
				ScaledCaptureRegion.Clip(FIntRect(FIntPoint::ZeroValue, ConfigViewport->GetRenderTargetTextureSizeXY()));
				ScaledCaptureRegion *= Config.ResolutionMultiplier;
			}

			Config.CaptureRegion = ScaledCaptureRegion;

			// Trigger the screenshot on the owning viewport
			ConfigViewport->TakeHighResScreenShot();
			if (OnTakeScreenShoot.IsBound())
			{
				OnTakeScreenShoot.Execute();
			}
		}
	}

	return FReply::Handled();
}

#endif