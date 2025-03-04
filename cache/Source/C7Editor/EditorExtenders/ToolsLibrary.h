#pragma once

#include "CoreMinimal.h"
//#include "Utilities/RecastNavMeshExporter.h"
#include "NavigationSystem.h"
#include "DesktopPlatformModule.h"
#include <Detour/DetourNavMesh.h>

class FToolsLibrary
{
public:
	static void ExportNavigation();

	static void ExportVoxData();
	static void ExportVoxDataTiled();

	// 运行时体素显示,可区分显示本地/服务端的
	static void ClearVoxPreviewMesh();
	static void ShowRuntimeVoxFromLocal();
	static void ShowRuntimeVoxFromServer();
	
	static void ImportVoxData();
	static void ShowVoxelPreviewMesh();
	static void ExportTestVoxData();

	static void ExportBSEnum();

	static void ExportVMBlueprint();

	static void ExportVMWidgetUtils();
	static void TestNavAndVoxel();

	static void StartSceneInspection();

	static void CopySpline();

	static void ExecuteAllTexture(bool bAutoCheckOut = false, bool bShowDialog = true);

	static void ExecuteAllDuplicateGuid(bool bAutoCheckOut = false);
	
	static void ExecuteAllStaticMeshLODAdapter(FString ExecutePaths, bool bAutoCheckOut = false);
	
	static void ExecuteAllStaticMeshLOD(const FString &ExecutePaths, bool bAutoCheckOut = false);
	
	static void FixAllStaticMeshLODScreenSize(bool bAutoCheckOut = false);

	static void OnInspectionFinished(class ASceneInspectionActor* SceneInspectionActor);

	static void ExportNavmeshSampleData();

	static void CompileAllAssets();

	static void SplitSBBTVActor(AActor* SBBTVActor);

	static void SplitSplineMeshComponent();

	static void MergeStaticMeshComponents(TArray<UPrimitiveComponent*> AllComponents, FString SavePathName);

	static void SplitTexture(UTexture* InTexture);

	static void ReplaceLandscapeTexture(UTexture2DArray* InDArray, UTexture2DArray* InNRHArray);

	static void ReplaceParentMaterial(const FString& InSrcMaterialPath, const FString& InDestMaterialPath, const FName& InTextureParameterName, UObject* InDataAsset);

	static void ReplaceAllMaterial();

	static void ExportNavmesh();

	static void ExportVoxel();

	static void EnableVoxelDisplay();

	static void DisableVoxelDisplay();

	///////////////////////// assets modify tools ////////////////////////
public:
	static void FixArtTestAssetsReference(TArray<FString> SelectedFolders);

	static void CleanCustomizePkgHead(TArray<FString> SelectedFolders);

	static void ShowPerformance();

	static void PrecomputedVisibilityVolumeExport();
	
	static void StartPIEFromLogin();

	static void SetupHoudiniEnv();

	//PIE预览关卡
	static void StartPIEFromPreview();
	
	static void LoadAllRegion();

	static void DumpNavMesh();

	static void DeleteNavDataActor();

	//UMG预览
	static void ToggleSafeAreaVisible();
	static bool IsSafeAreaVisible();

	//PC是否比例缩放
	static void TogglePCScale();
	static bool IsPCScaleEnable();

	// 工具
	static bool CheckoutFile(const FString& Filename, bool bAddFile, bool bIgnoreAlreadyCheckedOut);
	static void DoSavePackage(UPackage* Package);

	// MapShoot
	static void CaptureMapShoot();
	static void GetLastCaptureMapShootAndCaculateWayPoint();
};

DECLARE_DELEGATE(FScopeFunction)
class FScopeKeepValue
{
public:
	FScopeKeepValue(FScopeFunction Enter, FScopeFunction Exist)
	{
		Enter.ExecuteIfBound();
		Callback = Exist;
	}
	~FScopeKeepValue()
	{
		Callback.ExecuteIfBound();
	}
	
	FScopeFunction Callback;
};
