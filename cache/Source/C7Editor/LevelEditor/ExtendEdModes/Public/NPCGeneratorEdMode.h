#pragma once

#include "EdMode.h"

struct HNPCGeneratorPointProxy : public HHitProxy
{
	DECLARE_HIT_PROXY();

	HNPCGeneratorPointProxy(UObject* InRefObject, int32 InIndex)
		: HHitProxy(HPP_UI), RefObject(InRefObject), Index(InIndex)
	{}

	UObject* RefObject;
	int32 Index;
};

class ANPCActor;

class FNPCGeneratorEdMode : public FEdMode
{
public:

	const static FEditorModeID EM_NPCGenerator;

	// FEdMode interface
	virtual void Enter() override;
	virtual void Exit() override;
	virtual void Render(const FSceneView* View, FViewport* Viewport, FPrimitiveDrawInterface* PDI) override;
	virtual bool HandleClick(FEditorViewportClient* InViewportClient, HHitProxy *HitProxy, const FViewportClick &Click) override;
	virtual bool InputDelta(FEditorViewportClient* InViewportClient, FViewport* InViewport, FVector& InDrag, FRotator& InRot, FVector& InScale) override;
	virtual bool InputKey(FEditorViewportClient* ViewportClient, FViewport* Viewport, FKey Key, EInputEvent Event) override;
	virtual bool ShowModeWidgets() const override;
	virtual bool ShouldDrawWidget() const override;
	virtual bool UsesTransformWidget() const override;
	virtual FVector GetWidgetLocation() const override;
	// End of FEdMode interface

	FNPCGeneratorEdMode();
	~FNPCGeneratorEdMode();

	void AddNPC();
	bool CanAddNPC() const;
	void RemoveNPC();
	bool CanRemoveNPC() const;
	bool HasValidSelection() const;
	void SetNPCTemplate(FString Path);

	TSharedPtr<FUICommandList> NPCGeneratorEdModeActions = nullptr;
	void MapCommands();

private:
	FString TemplatePath = "";
};