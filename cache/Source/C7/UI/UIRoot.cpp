// Fill out your copyright notice in the Description page of Project Settings.


#include "UI/UIRoot.h"

#include "KGUISettings.h"
#include "Blueprint/GameViewportSubsystem.h"
#include "Components/CanvasPanel.h"
#include "Blueprint/WidgetTree.h"
#include "Components/CanvasPanelSlot.h"
#include "Components/Image.h"
#include "Components/InvalidationBox.h"

bool UUIRoot::Init()
{
	if (GEngine)
	{
		GEngine->GameViewport->Viewport->ViewportResizedEvent.AddUObject(this, &UUIRoot::OnViewportResized);
	}

	const auto Root = GetRootWidget();

	if (Root != nullptr || RootCanvas != nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::Initialize => Root is already exist"));
		return false;
	}

	if(WidgetTree == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::Initialize => WidgetTree is nullptr"));
		return false;
	}
	RootCanvas = WidgetTree->ConstructWidget<UCanvasPanel>(UCanvasPanel::StaticClass());

	if (RootCanvas == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::Initialize => RootCanvas is nullptr"));
		return false;
	}

	RootCanvas->SetVisibility(ESlateVisibility::SelfHitTestInvisible);

	WidgetTree->RootWidget = RootCanvas;

	// 增加刘海屏的预览处理
#if WITH_EDITOR
	{
		UCanvasPanel* safeAreaPanel = WidgetTree->ConstructWidget<UCanvasPanel>(UCanvasPanel::StaticClass());
		UCanvasPanelSlot* safeAreaPanelSlot = RootCanvas->AddChildToCanvas(safeAreaPanel);
		if (!safeAreaPanelSlot)
		{
			UE_LOG(LogTemp, Error, TEXT("UUIRoot::Initialize => Failed to add safe area panel to root canvas"));
		}
		else
		{
			safeAreaPanel->SetVisibility(ESlateVisibility::HitTestInvisible);
			// 确保在最上面
			safeAreaPanelSlot->SetZOrder(999999999);
			safeAreaPanelSlot->SetAnchors(FAnchors(0, 0, 1, 1));
			safeAreaPanelSlot->SetOffsets(FMargin());

			// 添加全屏的图片
			SafeAreaImage = WidgetTree->ConstructWidget<UImage>(UImage::StaticClass());
			if (!SafeAreaImage)
			{
				UE_LOG(LogTemp, Error, TEXT("UUIRoot::Initialize => Failed to create image"));
			}
			else
			{
				FSlateBrush brush;
				// 固定创建，根据属性动态调整
				UTexture2D* tex = GetDefault<UKGUISettings>()->SafeAreaTextureRef.LoadSynchronous();
				if (tex == nullptr)
				{
					brush.SetResourceObject(nullptr);
					UE_LOG(LogTemp, Error, TEXT("UUIRoot::Initialize => Please set SafeAreaTexture in KGUISettings"));
				}
				else
				{
					brush.SetResourceObject(tex);
				}
				SafeAreaImage->SetBrush(brush);
				UCanvasPanelSlot* imageSlot = safeAreaPanel->AddChildToCanvas(SafeAreaImage);
				if (!imageSlot)
				{
					UE_LOG(LogTemp, Error, TEXT("UUIRoot::Initialize => Failed to add image to safe area panel"));
				}
				else
				{
					imageSlot->SetAnchors(FAnchors(0.f, 0.f, 1.f, 1.f));
					imageSlot->SetOffsets(FMargin(0.f));
				}

				// 固定设置，默认看不到
				if (GetDefault<UKGUISettings>()->bUseSafeArea && GetDefault<UKGUISettings>()->bEnableUIEditorPreview)
				{
					SafeAreaImage->SetVisibility(ESlateVisibility::HitTestInvisible);
				}
				else
				{
					SafeAreaImage->SetVisibility(ESlateVisibility::Hidden);
				}
			}
		}
	}
#endif
	
	return true;
}
#if WITH_EDITOR
void UUIRoot::UpdateSafeAreaEnabled()
{
	if (SafeAreaImage == nullptr)
	{
		return;
	}
	if (GetDefault<UKGUISettings>()->bUseSafeArea && GetDefault<UKGUISettings>()->bEnableUIEditorPreview)
	{
		SafeAreaImage->SetVisibility(ESlateVisibility::HitTestInvisible);
	}
	else
	{
		SafeAreaImage->SetVisibility(ESlateVisibility::Hidden);
	}
}
void UUIRoot::UpdateViewport(FViewport* Viewport)
{
	this->OnViewportResized(Viewport, 0);
}
#endif

void UUIRoot::DontAutoRemoveWithWorld()
{
	UGameViewportSubsystem* Subsystem = GEngine->GetEngineSubsystem<UGameViewportSubsystem>();
	if(Subsystem)
	{
		auto GameViewportWidgetSlot = Subsystem->GetWidgetSlot(this);
		GameViewportWidgetSlot.bAutoRemoveOnWorldRemoved = false;
		Subsystem->SetWidgetSlot(this, GameViewportWidgetSlot);
	}
}

bool UUIRoot::AddChildToLayer(int32 Layer, UWidget* Widget, bool BInvalidationBox)
{
	if (Widget == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::AddChild => UserWidget is nullptr"));
		return false;
	}

	if (!CanvasPanels.Contains(Layer))
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::AddChild => Layer:%d is not exist"), Layer);
		return false;
	}

	UCanvasPanel* CanvasPanel = CanvasPanels.FindRef(Layer);

	if (CanvasPanel == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::AddChild => CanvasPanel is nullptr"));
		return false;
	}

	if(BInvalidationBox)
	{
		const FName& WidgetName = Widget->GetFName();
		FName InvalidationBoxName = *FString::Printf(TEXT("%s_IB"), *WidgetName.ToString());
		UInvalidationBox* Box = WidgetTree->ConstructWidget<UInvalidationBox>(UInvalidationBox::StaticClass(), InvalidationBoxName);

		if (Box == nullptr)
		{
			UE_LOG(LogTemp, Warning, TEXT("UUIRoot::AddChild => Box is nullptr"));
			return false;
		}
		UCanvasPanelSlot* CanvasPanelSlot = CanvasPanel->AddChildToCanvas(Box);
		if (CanvasPanelSlot == nullptr)
		{
			UE_LOG(LogTemp, Warning, TEXT("UUIRoot::AddChild => CanvasPanelSlot is nullptr"));
			return false;
		}

		CanvasPanelSlot->SetAnchors(FAnchors(0, 0, 1, 1));

		CanvasPanelSlot->SetOffsets(FMargin());

		Box->SetVisibility(ESlateVisibility::SelfHitTestInvisible);
		Widget->SetVisibility(ESlateVisibility::SelfHitTestInvisible);

		UPanelSlot* PanelSlot = Box->SetContent(Widget);
	}
	else
	{
		UCanvasPanelSlot* CanvasPanelSlot = CanvasPanel->AddChildToCanvas(Widget);
		if (CanvasPanelSlot == nullptr)
		{
			UE_LOG(LogTemp, Warning, TEXT("UUIRoot::AddChild => CanvasPanelSlot is nullptr"));
			return false;
		}

		CanvasPanelSlot->SetAnchors(FAnchors(0, 0, 1, 1));

		CanvasPanelSlot->SetOffsets(FMargin());

		Widget->SetVisibility(ESlateVisibility::SelfHitTestInvisible);
	}

	return true;
}

UCanvasPanel* UUIRoot::CreateCanvas(int32 Layer)
{
	if (CanvasPanels.Contains(Layer))
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::CreateCanvas => CanvasPanels already contains Layer:%d"), Layer);
		return nullptr;
	}

	if (WidgetTree == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::CreateCanvas => WidgetTree is nullptr"));
		return nullptr;
	}

	if (RootCanvas == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::CreateCanvas => RootCanvas is nullptr"));
		return nullptr;
	}

	UCanvasPanel* CanvasPanel = WidgetTree->ConstructWidget<UCanvasPanel>(UCanvasPanel::StaticClass());

	if (CanvasPanel == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::CreateCanvas => CanvasPanel is nullptr"));
		return nullptr;
	}

	CanvasPanels.Add(Layer, CanvasPanel);

	CanvasPanel->SetVisibility(ESlateVisibility::SelfHitTestInvisible);

	UCanvasPanelSlot* CanvasPanelSlot = RootCanvas->AddChildToCanvas(CanvasPanel);

	if (CanvasPanelSlot == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::CreateCanvas => CanvasPanelSlot is nullptr"));
		return nullptr;
	}

	CanvasPanelSlot->SetZOrder(Layer);

	CanvasPanelSlot->SetAnchors(FAnchors(0, 0, 1, 1));

	CanvasPanelSlot->SetOffsets(FMargin());

	// ZOrderCounters.Add(Layer, 0);

	return CanvasPanel;


	/*UInvalidationBox* Box = WidgetTree->ConstructWidget< UInvalidationBox>(UInvalidationBox::StaticClass());
	if(Box == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::CreateCanvas => Box is nullptr"));
		return nullptr;
	}
	UCanvasPanelSlot* CanvasPanelSlot = RootCanvas->AddChildToCanvas(Box);
	if (CanvasPanelSlot == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::CreateCanvas => CanvasPanelSlot is nullptr"));
		return nullptr;
	}

	CanvasPanelSlot->SetZOrder(Layer * 100);

	CanvasPanelSlot->SetAnchors(FAnchors(0, 0, 1, 1));

	CanvasPanelSlot->SetOffsets(FMargin());

	UCanvasPanel* CanvasPanel = WidgetTree->ConstructWidget<UCanvasPanel>(UCanvasPanel::StaticClass());

	if (CanvasPanel == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::CreateCanvas => CanvasPanel is nullptr"));
		return nullptr;
	}

	CanvasPanels.Add(Layer, CanvasPanel);

	CanvasPanel->SetVisibility(ESlateVisibility::SelfHitTestInvisible);

	UPanelSlot* PanelSlot = Box->SetContent(CanvasPanel);
	
	return CanvasPanel;*/
}

bool UUIRoot::RemoveCanvas(int32 Layer)
{
	if (UCanvasPanel* LayerCanvasPanel =  CanvasPanels.FindRef(Layer))
	{
		if (LayerCanvasPanel == nullptr)
		{
			UE_LOG(LogTemp, Warning, TEXT("UUIRoot::RemoveCanvas => LayerCanvasPanel is nullptr"));
			return false;
		}
		LayerCanvasPanel->RemoveFromParent();	
		CanvasPanels.Remove(Layer);
		return true;
	}
	return false;
}

bool UUIRoot::MoveToLayer(int32 FromLayer,int32 ToLayer)
{
	if (FromLayer == ToLayer)
	{
		return true;
	}
	if (CanvasPanels.Contains(ToLayer))
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::MoveToLayer => TargetLayer Already Contains A Cavnas"));
		return false;
	}
	if (UCanvasPanel* LayerCanvasPanel =  CanvasPanels.FindRef(FromLayer))
	{
		if (LayerCanvasPanel == nullptr)
		{
			UE_LOG(LogTemp, Warning, TEXT("UUIRoot::MoveToLayer => LayerCanvasPanel is nullptr"));
			return false;
		}
		UPanelWidget* Parent = LayerCanvasPanel->GetParent();
		if(Parent)
		{
			if (UCanvasPanelSlot* CPSlot = Cast<UCanvasPanelSlot>(Parent->Slot))
			{
				CPSlot->SetZOrder(ToLayer*100);
			}
		}
		
		CanvasPanels.Remove(FromLayer);
		CanvasPanels.Add(ToLayer,LayerCanvasPanel);
		return true;
	}

	UE_LOG(LogTemp, Warning, TEXT("UUIRoot::MoveToLayer => Target Layer Is Empty"));
	return false;
}


bool UUIRoot::RemoveChildFromLayer(int32 Layer, UWidget* Widget)
{
	if (Widget == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::RemoveChild => UserWidget is nullptr"));
		return false;
	}

	if (!CanvasPanels.Contains(Layer))
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::RemoveChild => Layer:%d is not exist"), Layer);
		return false;
	}

	UCanvasPanel* CanvasPanel = CanvasPanels.FindRef(Layer);

	if (CanvasPanel == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("UUIRoot::AddChild => CanvasPanel is nullptr"));
		return false;
	}

	return CanvasPanel->RemoveChild(Widget);

	/*if (CanvasPanel->GetChildrenCount() == 0)
	{
		ZOrderCounters[Layer] = 0;
	}*/

}

void UUIRoot::OnViewportResized(FViewport* Viewport, uint32 Res)
{
	if(ViewportResizedEvent.IsBound())
	{
		FIntPoint Resolution = Viewport->GetSizeXY();
		ViewportResizedEvent.Execute(Resolution.X, Resolution.Y);
	}
}
