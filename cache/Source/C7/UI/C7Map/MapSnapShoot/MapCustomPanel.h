#if WITH_EDITOR
#pragma once

#include "CoreMinimal.h"
#include "Widgets/SCompoundWidget.h"

class SWindow;
class AMapShoot;
class FLevelEditorViewportClient;

class C7_API SMapCustomPanel : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SMapCustomPanel) {}
	SLATE_ARGUMENT(TObjectPtr<AMapShoot>, MapShoot)
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs);

	void LockToMapShootActor();

	TObjectPtr<AMapShoot> MyMapShoot;
	FReply OnTakeScreenShoot();

	//FLevelEditorViewportClient* ViewportClient;
	static TWeakPtr<class SWindow> OpenDialog(TObjectPtr<AMapShoot> MapShoot);
	static TWeakPtr<SWindow> CurrentWindow;
	static TWeakPtr<SMapCustomPanel> CurrentDialog;
	static FLevelEditorViewportClient* ViewportClient;
	static bool bMaskVisualizationWasEnabled;
	static void WindowClosedHandler(const TSharedRef<SWindow>& InWindow);


	TSharedPtr<SWidget> ConstructViewMode();
	TSharedPtr<SWidget> ConstructShowFlags();
	TSharedPtr<SWidget> ConstructScreenShoot();
	
private:
	void ResetMapShowFlags();
	void OnNavMeshEdgesCheckBoxStateChanged(ECheckBoxState NewCheckedState);
	void OnCameraEdgesCheckBoxStateChanged(ECheckBoxState NewCheckedState);
};
#endif