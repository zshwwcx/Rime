// Copyright Epic Games, Inc. All Rights Reserved.

using UnrealBuildTool;
using System.Collections.Generic;

public class C7EditorTarget : TargetRules
{
	public C7EditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.Add("C7Editor");
        this.WindowsPlatform.bStrictPreprocessorConformance = true;//add by tangzhangpeng[cpphotfix]
    }
}
