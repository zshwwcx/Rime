using System;
using System.IO;
using EpicGames.Core;
using UnrealBuildTool;
using Microsoft.Extensions.Logging;

public class C7 : ModuleRules
{
	public C7(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

		if (IsEnableAsan(Target))
		{
			OptimizeCode = CodeOptimization.Never;
		}

		
        PublicDependencyModuleNames.AddRange
		(
			new string[] 
			{ 
				"Core", 
				"CoreUObject", 
				"Engine", 
				"InputCore", 
				"HeadMountedDisplay",
				"DeveloperSettings",

                "Navmesh",
                "GameplayTasks",
				"AIModule",
				"Landscape",
				"NavigationSystem",
                "GameplayTags",
				"Niagara",
				"NiagaraCore",
				"MovieScene",
				"ProceduralMeshComponent",

				"SignificanceManager",
                "SpinePlugin",
                "Slate", 
                "SlateCore", 
                "RenderCore",
                "ChaosCaching",
				"KGCore",
				"KGCharacter",
				"KGLevelFlow",
				"MoviePlayer",
				"ApplicationCore",
                "BinkMediaPlayer",
                "KGGPUFrameCapturePlugin",
                "AnimToTexture",
                "KGUI",
                "C7MassNPC"
            }
		);

		PrivateDependencyModuleNames.AddRange
		(
			new string[] 
			{ 
				"slua_unreal", 
				"slua_profile" ,
				"UMG",
				"SlateCore",
				"AkAudio",
				"DoraSDK",
				"Slate",
				"Paper2D",
				"EngineSettings",
				"Json",
				"JsonUtilities",
				"HTTP",
                "ModelViewViewModel",
                "Slate", 
                "SlateCore", 
                "RenderCore",
                "TraceLog",
                "SceneTools",
                "WayPointSystem",
				"KGCore", 
				"Chaos",
				"PhysicsCore",
				"TypedElementFramework",
                "LevelSequence",
                "KGWorldPartitionProfiler",
				"RHI", 
				"PakUpdate",
			}
		);

		PrivateIncludePaths.AddRange
		(
			new string[] 
			{
				"C7",
                "C7/Misc",
			}
		);

		// 开启UWA的条件： Develop版本+安卓/windows
		var bGlobalUwa = C7Target.bGlobalUWA;
		if (bGlobalUwa)
		{
			if (Target.Configuration == UnrealTargetConfiguration.Development)
			{
				if (Target.Platform == UnrealTargetPlatform.Win64
				    || Target.Platform == UnrealTargetPlatform.Android)
				{
					PublicDependencyModuleNames.Add("UWAGOT");
				}
			}			
		}
		Console.WriteLine($"2 Use UWA={bGlobalUwa}");
		
		var DisableAllInSdk = C7Target.DisableAllInSdk;

		if (!DisableAllInSdk)
		{
			PublicDependencyModuleNames.Add("AllInSDK");
		}
		else
		{
			PublicDefinitions.Add("DISABLE_ALLIN_SDK");
		}

        var DisableGME = C7Target.DisableGME;
        if (!DisableGME)
        {
			PublicDependencyModuleNames.Add("GMESDK");
		}
        else
        {
            PublicDefinitions.Add("DISABLE_GME");
        }

        if (Target.Type == TargetType.Editor)
		{
			PrivateDependencyModuleNames.AddRange(new string[] {
				"UnrealEd",
                "LevelEditor",
                "ToolMenus",
				"CommonMenuExtensions",
				"ToolWidgets"
            });
        }

		if (Target.Platform == UnrealTargetPlatform.Android)
		{
			PrivateDependencyModuleNames.Add("Launch");
		}

		if (Target.Platform == UnrealTargetPlatform.Android)
		{
			if (Target.AndroidPlatform.bEnableHWAddressSanitizer)
			{
				PublicDefinitions.Add("C7_ENABLE_ASAN");
			}
			Console.WriteLine($"ASan bEnableAddressSanitizer:{Target.AndroidPlatform.bEnableHWAddressSanitizer}, Target.Type={Target.Type}, Target.Platform={Target.Platform}");
		}
		if (Target.Platform == UnrealTargetPlatform.IOS)
		{
			if (Target.IOSPlatform.bEnableAddressSanitizer)
			{
				PublicDefinitions.Add("C7_ENABLE_ASAN");
			}
			Console.WriteLine($"ASan bEnableAddressSanitizer:{Target.IOSPlatform.bEnableAddressSanitizer}, Target.Type={Target.Type}, Target.Platform={Target.Platform}");
			
			PublicDependencyModuleNames.AddRange(
				new string[] {
					"KGGPUFrameCapturePlugin",
				}
			);
		}
		if (Target.Platform == UnrealTargetPlatform.Win64)
		{
			if (Target.WindowsPlatform.bEnableAddressSanitizer)
			{
				PublicDefinitions.Add("C7_ENABLE_ASAN");
			}
			Console.WriteLine($"ASan bEnableAddressSanitizer:{Target.WindowsPlatform.bEnableAddressSanitizer}, Target.Type={Target.Type}, Target.Platform={Target.Platform}");
		}
		

		//var ConfigUGSFilePath = Target.ProjectFile.Directory + "/Config/DefaultUnrealGameSyncEditor.ini";
        //var ConfigUGSFileReference = new FileReference(ConfigUGSFilePath);
        //var ConfigUGSFile = FileReference.Exists(ConfigUGSFileReference) ? new ConfigFile(ConfigUGSFileReference) : new ConfigFile();
        //var ConfigUGS = new ConfigHierarchy(new[] { ConfigUGSFile });
        //const string SectionUGS = "/Script/UnrealGameSyncEditor.UnrealGameSyncEditorSettings";

        //Action<string, string, bool> LoadBoolConfigUGS = (key, macro, defaultValue) =>
        //{
        //    bool flag;
        //    if (!ConfigUGS.GetBool(SectionUGS, key, out flag))
        //        flag = defaultValue;
        //    PublicDefinitions.Add(string.Format("{0}={1}", macro, (flag ? "1" : "0")));
        //};

        //LoadBoolConfigUGS("bWithUnrealGameSyncEditor", "WITH_UNREAL_GAME_SYNC_EDITOR", false);
        //PublicDefinitions.Add("LUA_USE_OPCODE=1");
    }
}
