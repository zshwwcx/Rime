using System;
using System.IO;
using EpicGames.Core;
using UnrealBuildTool;

public class C7Editor : ModuleRules
{
	private void LinkLibLua()
	{
		var externalLib = Path.Combine(ModuleDirectory, "../../Plugins/slua_unreal/Library");
		System.Console.WriteLine("[C7Editor] LinkLibLua externalLib path is " + externalLib);
        
		if (Target.Platform == UnrealTargetPlatform.IOS)
		{
			PublicAdditionalLibraries.Add(Path.Combine(externalLib, "iOS/liblua.a"));
		}
		else if (Target.Platform == UnrealTargetPlatform.Android)
		{
#if UE_4_24_OR_LATER
			PublicAdditionalLibraries.Add(Path.Combine(externalLib, "Android/armeabi-v7a/liblua.a"));
			PublicAdditionalLibraries.Add(Path.Combine(externalLib, "Android/armeabi-arm64/liblua.a"));
			PublicAdditionalLibraries.Add(Path.Combine(externalLib, "Android/x86/liblua.a"));
#else
            PublicLibraryPaths.Add(Path.Combine(externalLib, "Android/armeabi-arm64"));
            PublicLibraryPaths.Add(Path.Combine(externalLib, "Android/armeabi-v7a"));
            PublicLibraryPaths.Add(Path.Combine(externalLib, "Android/x86"));
            PublicAdditionalLibraries.Add("lua");
#endif
		}
#if UE_5_00_OR_LATER
        else if (Target.Platform == UnrealTargetPlatform.Win32 )
        {
            PublicAdditionalLibraries.Add(Path.Combine(externalLib, "Win32/lua.lib"));
        }
#endif
		else if (Target.Platform == UnrealTargetPlatform.Win64)
		{
			PublicAdditionalLibraries.Add(Path.Combine(externalLib, "Win64/lua.lib"));
		}
		else if (Target.Platform == UnrealTargetPlatform.Mac)
		{
			PublicAdditionalLibraries.Add(Path.Combine(externalLib, "Mac/liblua.a"));
		}
		else if (Target.Platform == UnrealTargetPlatform.Linux)
		{
			PublicAdditionalLibraries.Add(Path.Combine(externalLib, "Linux/liblua.a"));
		}
	}
	
	public C7Editor(ReadOnlyTargetRules Target) : base(Target)
	{
		if (Target.Configuration != UnrealTargetConfiguration.Shipping)
		{
			OptimizeCode = CodeOptimization.Never;
		}
		
		PCHUsage = ModuleRules.PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicIncludePaths.AddRange(
            new string[] {
		 		"C7Editor/LevelEditor/ExtendEdModes/Public",
			    Path.Combine(EngineDirectory, "Source/Editor/DataLayerEditor/Private"),
			    Path.Combine(EngineDirectory, "Source/Developer/AssetTools/Private"),
			}
            );


        PrivateIncludePaths.AddRange
		(
			new string[] 
			{
				"C7",
				"C7Editor",
		 	}
		 );


		PublicDependencyModuleNames.AddRange
		(
			new string[] 
			{
				"Core",
				"CoreUObject",
				"Engine",
				"TargetPlatform",

				"AIModule",
				"GameplayTags",
				"AssetRegistry",

				"Niagara",
				"NiagaraCore",

                "ChaosCaching",

                "KGCore",
                "KGCoreEditor",
                "KGCharacter",
                "KGCharacterEditor",
                "KGScene",
                "KGSceneEditor",
                "KGLevelFlow",
                "KGLevelFlowEditor",
                "KGStoryLine",
                "KGStoryLineEditor",
                "KGBattleSystem",
                "KGBattleSystemEditor",
                "KGUI",
                "KGUIEditor",

                "HTTP",
                "Json",
                "JsonUtilities",
                "KGAbilitySystemEditor",
                "LevelSequence",
				"Python3",
				"PythonScriptPlugin",
			}
		);


		PrivateDependencyModuleNames.AddRange
		(
			new string[] 
			{
				"Slate",
				"SlateCore",
                "ClassViewer",
                "ApplicationCore",
				"InputCore",
				"UnrealEd",
				"AssetRegistry",
				"Json",
				"JsonUtilities",
				"CollectionManager",
				"ContentBrowser",
				"WorkspaceMenuStructure",
				"EditorStyle",
				"AssetTools",
				"PropertyEditor",
				"GraphEditor",
				"BlueprintGraph",
				"KismetCompiler",
				"LevelEditor",
				"SandboxFile",
				"EditorWidgets",
				"TreeMap",
				"ToolMenus",
				"Landscape",

				"Kismet",
				"KismetWidgets",
				"TimeManagement",
				"AdvancedPreviewScene",
				"EngineSettings",
				"DeveloperSettings",
				"SourceControl",

				"AdvancedPreviewScene",
				"Persona",

				"SequencerCore",
				"SequencerWidgets",

				"EngineSettings",
				"EditorSubsystem",
				"GraphEditor",
				"ApplicationCore",
				"PropertyEditor",
				"BlueprintGraph",
				"Blutility",
                "RHI",


				"PlacementMode",

				// For level-flow editor
				"AIGraph",
				"ToolMenus",
				"DetailCustomizations",
				"AppFramework",
				"EditorFramework",

				"C7",
				"slua_unreal",
				"slua_profile",
				"Json",
				"JsonUtilities",
				"AkAudio",

				"NavigationSystem",
				"Navmesh",
				"BSPUtils",

                "ModelViewViewModel",
				"UMGEditor",
                "ModelViewViewModelBlueprint",

                "DoraSDK",

				"AVEncoder",
				"GameplayMediaEncoder",
				"Paper2D",
                "KAutoOptimizer",
                "StaticMeshEditorExtender",

                "MovieSceneTools",
                "MovieSceneTracks",
                "MovieScene",
                "Sequencer", 
                "DataLayerEditor",
                "ToolWidgets", 
                
                "SpineEditorPlugin", 
                "SpineEditorPlugin",
                "DirectoryWatcher",
                
                "PhysicsUtilities", 
                "Foliage",
                "SceneInspection",
				
				"RenderCore", 
				"BuildingToolsEditorPlugin",
				"SceneInspectionEditor",
				
				"SceneTools",
				"SceneToolsEditor",
                "InteractiveToolsFramework",
                "EditorInteractiveToolsFramework",
                "SceneOutliner",
				"KGCore",
				"RecastTool",
				"NiagaraEditor",
				"DesktopPlatform",
				"GeometryProcessingInterfaces", 
				"BuildingGeneratorPlugin",
				"StaticMeshDescription",
				"MeshDescription",
				"EditorScriptingUtilities",
				"WorldPartitionHLODUtilities",
				"Sockets",
				"Perforce",
				"WayPointSystem",
				"ImageCore",
				"KGResourceManager",
				"KGSourceControlEditor",
			}
		);
		
		AddEngineThirdPartyPrivateStaticDependencies(Target, "Perforce");
		
		PrivateIncludePathModuleNames.AddRange(new string[] { "slua_unreal" });
		PublicIncludePathModuleNames.AddRange(new string[] { "slua_unreal","slua_profile" });
		
		//slua support add by sk
#if UE_4_21_OR_LATER
		PublicDefinitions.Add("ENABLE_PROFILER");
#else
        Definitions.Add("ENABLE_PROFILER");
#endif

		LinkLibLua();

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
