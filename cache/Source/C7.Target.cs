// Copyright Epic Games, Inc. All Rights Reserved.

using System;
using UnrealBuildTool;
using System.Collections.Generic;
using Microsoft.Extensions.Logging;

public class C7Target : TargetRules
{
	public static bool bGlobalUWA = false;
	public static bool DisableAllInSdk = false;
    public static bool DisableGME = false;

    public C7Target(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;

		if (Configuration == UnrealTargetConfiguration.Shipping)
		{
			bUseLoggingInShipping = true;
		}
		
		// liubo, asan
		// 打包命令，加上-UbtArgs="-EnableHWASan"
		if (Environment.CommandLine.Contains("-EnableASan", StringComparison.CurrentCultureIgnoreCase)
		    || Environment.CommandLine.Contains("-EnableHWASan", StringComparison.CurrentCultureIgnoreCase)
		    || Environment.CommandLine.Contains("-C7Asan", StringComparison.CurrentCultureIgnoreCase))
		{
			this.Logger.LogInformation("liubo, enable asan!!!");
			if (this.Type == UnrealBuildTool.TargetType.Game)
			{
				this.WindowsPlatform.bEnableAddressSanitizer = true;
				if (Environment.CommandLine.Contains("-EnableHWASan", StringComparison.CurrentCultureIgnoreCase)
				    || Environment.CommandLine.Contains("-C7Asan", StringComparison.CurrentCultureIgnoreCase))
				{
					this.AndroidPlatform.bEnableHWAddressSanitizer = true;
				}
				else
				{
					this.AndroidPlatform.bEnableAddressSanitizer = true;
				}
				// this.IOSPlatform.bEnableAddressSanitizer = true;
			}
			GlobalDefinitions.Add("FORCE_ANSI_ALLOCATOR=1");
			GlobalDefinitions.Add("ENABLE_NAN_DIAGNOSTIC=1");
		}
		else
		{
			this.Logger.LogInformation("liubo, disable asan.");
		}

		DefaultBuildSettings = BuildSettingsVersion.Latest;
        ExtraModuleNames.Add("C7");
        
		bool UseUWA = false;

		if (bGlobalUWA)
		{
			if (Target.Configuration == UnrealTargetConfiguration.Development)
			{
				if (Target.Platform == UnrealTargetPlatform.Win64
				    || Target.Platform == UnrealTargetPlatform.Android)
				{
					UseUWA = true;
				}
			}	        
		}
        
		Console.WriteLine($"1 Use UWA={bGlobalUWA}");
		
		if (!UseUWA)
		{
			DisablePlugins.Add("UWAGOT");
		}

		// 打包时，禁用掉一些插件
		if (!bBuildEditor)
		{
            DisablePlugins.Add("Cinematographer");
        }

		// IOS上暂时先试用ANSI内存
        if (Target.Platform == UnrealTargetPlatform.IOS)
        {
            GlobalDefinitions.Add("FORCE_ANSI_ALLOCATOR=1");
        }

        if (Target.Platform != UnrealTargetPlatform.Android && Target.Platform != UnrealTargetPlatform.IOS && !bBuildEditor)
        {
	        DisablePlugins.Add("BlobShadow");
        }

        //GlobalDefinitions.Add("UE_DEPRECATED_PROFILER_ENABLED=1");
        //BuildEnvironment = TargetBuildEnvironment.Unique;
        this.WindowsPlatform.bStrictPreprocessorConformance = true;//add by tangzhangpeng[cpphotfix]
    }
}
