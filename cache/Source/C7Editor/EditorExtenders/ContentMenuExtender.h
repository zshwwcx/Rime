#pragma once


class FContentMenuExtender : public TSharedFromThis<FContentMenuExtender>
{
public:
	void Startup();
	void Shutdown();

private:
	void RegisterMenus();

protected:
	void BindCommands();
	TSharedPtr<FUICommandList> CommandList;

/// <summary>
/// Contend browser asset selection related menu extendion
/// </summary>
private:
	void ExtendContentAssetMenu();
	void UnExtendContentAssetMenu();

	TSharedRef<FExtender> OnExtendContentBrowserAssetSelectionMenu(const TArray<FAssetData>& SelectedAssets);
	void CreateC7ContentBrowserAssetMenu(FMenuBuilder& MenuBuilder, TArray<FAssetData> SelectedAssets);
	FDelegateHandle ContentBrowserAssetExtenderDelegateHandle;


/// <summary>
/// Contend browser folder selection related menu extendion
/// </summary>
private:
	void ExtendContentPathMenu();
	void UnExtendContentPathMenu();

	TSharedRef<FExtender> OnExtendContentBrowserPathSelectionMenu(const TArray<FString>& SelectedPaths);
	void CreateC7ContentBrowserPathMenu(FMenuBuilder& MenuBuilder, TArray<FString> SelectedPaths);

	FDelegateHandle ContentBrowserPathExtenderDelegateHandle;


/// <summary>
/// level editor toolbar related extendion
/// </summary>
private:
	void ExtendToobarMenu();
	void UnExtendToobarMenu();

	TSharedRef<SWidget> GenerateGameToolsMenu();

	// 编辑器选择手机分辨率
	TSharedRef<SWidget> GenerateResolutionMenu();
	TMap<FViewport*, FDelegateHandle> ViewportResizeHandles;

	static void RefreshViewportResolution();
	static void OnResolutionChosen(int idx);
	// 监听分辨率变化自动刷新
	static void OnViewportResized(FViewport*, uint32);
};


