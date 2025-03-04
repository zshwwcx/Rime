// Fill out your copyright notice in the Description page of Project Settings.


#include "UI/C7DPICustomScalingRule.h"
#include "Engine/UserInterfaceSettings.h"
#include "KGUIPlatformCustomSetting.h"

inline float InnerGetDPIScaleBasedOnSize(const EUIScalingRule& ScalingRule,const FRuntimeFloatCurve& ScalingCurve,FIntPoint& Size)
{
	int32 EvalPoint = 0;
	switch (ScalingRule)
	{
	case EUIScalingRule::ShortestSide:
		EvalPoint = FMath::Min(Size.X, Size.Y);
		break;
	case EUIScalingRule::LongestSide:
		EvalPoint = FMath::Max(Size.X, Size.Y);
		break;
	case EUIScalingRule::Horizontal:
		EvalPoint = Size.X;
		break;
	case EUIScalingRule::Vertical:
		EvalPoint = Size.Y;
		break;
	case EUIScalingRule::ScaleToFit:
		const UUserInterfaceSettings* Settings = GetDefault<UUserInterfaceSettings>();
		if (Settings)
		{
			return Settings->DesignScreenSize.X > 0 && Settings->DesignScreenSize.Y > 0 ? FMath::Min((float)(Size.X) / Settings->DesignScreenSize.X, (float)(Size.Y) / Settings->DesignScreenSize.Y) : 1.f;
		}
	}

	const FRichCurve* DPICurve = ScalingCurve.GetRichCurveConst();
	return DPICurve->Eval((float)EvalPoint, 1.0f);
}

float UC7DPICustomScalingRule::GetDPIScaleBasedOnSize(FIntPoint Size) const
{
	const UKGUIPlatformCustomSetting* C7DPISettings = GetDefault<UKGUIPlatformCustomSetting>();
	if (C7DPISettings!= nullptr)
	{
#if WITH_EDITOR
		switch (C7DPISettings->EditorPreviewPlatform)
		{
		case EDPIScalePreviewPlatforms::PC:
			return 	InnerGetDPIScaleBasedOnSize(C7DPISettings->PCScaleRule,C7DPISettings->PCScalingCurve,Size);
		case EDPIScalePreviewPlatforms::Android:
			return 	InnerGetDPIScaleBasedOnSize(C7DPISettings->AndroidScaleRule,C7DPISettings->AndroidScalingCurve,Size);
		case EDPIScalePreviewPlatforms::IOS:
			return 	InnerGetDPIScaleBasedOnSize(C7DPISettings->IOSScaleRule,C7DPISettings->IOSScalingCurve,Size);
		}
#elif PLATFORM_ANDROID
		return 	InnerGetDPIScaleBasedOnSize(C7DPISettings->AndroidScaleRule,C7DPISettings->AndroidScalingCurve,Size);
#elif PLATFORM_IOS
		return 	InnerGetDPIScaleBasedOnSize(C7DPISettings->IOSScaleRule,C7DPISettings->IOSScalingCurve,Size);
#elif PLATFORM_WINDOWS || PLATFORM_MAC
		return 	InnerGetDPIScaleBasedOnSize(C7DPISettings->PCScaleRule,C7DPISettings->PCScalingCurve,Size);
#endif
	}
	return 1;
}
