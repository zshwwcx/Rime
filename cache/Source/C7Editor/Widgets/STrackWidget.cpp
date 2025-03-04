
#include "STrackWidget.h"
#include "Widgets/SUserWidget.h"
#include "Rendering/DrawElements.h"
#include "Widgets/Layout/SBorder.h"
#include "Framework/MultiBox/MultiBoxBuilder.h"
#include "Framework/Application/SlateApplication.h"
#include "Styling/CoreStyle.h"
#include "Input/DragAndDrop.h"
#include "Fonts/FontMeasure.h"
#include "EditorStyleSet.h"
#include "SCurveEditor.h"

const float TRACK_DEFAULT_HEIGHT = 30.0f;
const float TRACK_NODE_DEFAULT_HEIGHT = 20.f;
const float TRACK_NODE_MINIMAL_WIDTH = 40.f;

class FLocalNodeDrageDropOp : public FDragDropOperation
{
public:
	DRAG_DROP_OPERATOR_TYPE(FLocalNodeDrageDropOp, FDragDropOperation)

	virtual void OnDrop( bool bDropWasHandled, const FPointerEvent& MouseEvent ) override
	{
		if (!bDropWasHandled)
		{
			if (OriginalTrackNode.IsValid())
			{
				OriginalTrackNode.Pin()->OnDropNode(MouseEvent);
			}
		}

		return FDragDropOperation::OnDrop(bDropWasHandled, MouseEvent);
	}

	virtual void OnDragged( const class FDragDropEvent& DragDropEvent ) override
	{
		FVector2D pos;
		pos.X = (DragDropEvent.GetScreenSpacePosition() + Offset).X;
		pos.Y = StartingScreenPos.Y;

		CursorDecoratorWindow->MoveWindowTo(pos);
	}

	static TSharedRef<FLocalNodeDrageDropOp> New(TSharedRef<STrackNodeWidget> TrackNode, const FVector2D &CursorPosition, const FVector2D &ScreenPositionOfNode)
	{
		TSharedRef<FLocalNodeDrageDropOp> Operation = MakeShareable(new FLocalNodeDrageDropOp);
		Operation->OriginalTrackNode = TrackNode;

		Operation->Offset = ScreenPositionOfNode - CursorPosition;
		Operation->StartingScreenPos = ScreenPositionOfNode;

		Operation->Construct();

		return Operation;
	}

	/** Gets the widget that will serve as the decorator unless overridden. If you do not override, you will have no decorator */
	virtual TSharedPtr<SWidget> GetDefaultDecorator() const
	{
		return OriginalTrackNode.Pin();
	}
protected:

	/** The window that shows hover text */
	FVector2D								Offset;
	FVector2D								StartingScreenPos;
	TWeakPtr<class STrackNodeWidget>		OriginalTrackNode;
	TWeakPtr<class STrackWidget>			OriginalTrack;

	FString GetHoverText() const
	{
		FString HoverText = TEXT("Invalid");
		return HoverText;
	}

	friend class STrackWidget;
	friend class STrackNodeWidget;
};

/*********************************************************/
// STrackNodeWidget
/*********************************************************/
void STrackNodeWidget::Construct(const FArguments& InArgs)
{
	// Init Members
	NodeName = InArgs._NodeName;
	NodeColor = InArgs._NodeColor;
	NodeStartPos = InArgs._NodeStartPos;
	NodeBlockLength = InArgs._NodeBlockLength;
	DateLength = InArgs._DataLength;
	bDataLengthAsNodeLength = InArgs._bDataLengthAsNodeLength;
	SelectedNodeColor = InArgs._SelectedNodeColor;
	OnSelectionChanged = InArgs._OnSelectionChanged;
	OnDataPositionChanged = InArgs._OnDataPositionChanged;
	bAllowDrag = InArgs._AllowDrag;
	OnBuildNodeContextMenu = InArgs._OnBuildNodeContextMenu;

	// Create UI
	DrawFont = FCoreStyle::GetDefaultFontStyle("Regular"/*Font Name*/, 10 /*Font Size*/);
	const FSlateBrush* StyleInfo = FAppStyle::GetBrush("ProgressBar.Background");

	TSharedPtr<SWidget> Content = InArgs._Content.Widget;
	if (InArgs._Content.Widget == SNullWidget::NullWidget)
	{
		SAssignNew(Content, STextBlock)
			.Font(DrawFont)
			.Text(this, &STrackNodeWidget::GetNodeText);

	}

	this->ChildSlot
	[
		SNew(SBorder)
		.BorderImage(StyleInfo)
		.ForegroundColor(FLinearColor::Black)
		.BorderBackgroundColor(this, &STrackNodeWidget::GetNodeSlateColor)
		.Content()
		[
			Content.ToSharedRef()
		]
	];
}

FText STrackNodeWidget::GetNodeText() const
{
	return FText::FromName(NodeName.Get());
}

FLinearColor STrackNodeWidget::GetNodeColor() const
{
	return IsSelected() ? SelectedNodeColor.Get() : NodeColor.Get();
}

void STrackNodeWidget::OnSelect()
{
	if (OnSelectionChanged.IsBound())
	{
		OnSelectionChanged.ExecuteIfBound(true);
	}
}

void STrackNodeWidget::OnDeselect()
{
	if (OnSelectionChanged.IsBound())
	{
		OnSelectionChanged.ExecuteIfBound(false);
	}
}

// FVector2D STrackNodeWidget::ComputeDesiredSize(float) const
// {
// 	return FVector2D(0.f, 0.f);
// }

FVector2D STrackNodeWidget::GetTrackNodeSize(const STrackWidget* Parent, const FGeometry& AllottedGeometry) const
{
	float NodeWidth, NodeHeight;

	// custom length
	if (NodeBlockLength.Get() > 0.f)
	{
		if (bDataLengthAsNodeLength)
		{
			NodeWidth = Parent->DataToLocalX(Parent->ViewInputMin.Get() + DateLength.Get(), AllottedGeometry);
		}
		else
		{
			NodeWidth = NodeBlockHeight.Get();
		}
		//return FVector2D(Parent->DataToLocalX(Parent->ViewInputMin.Get() + NodeBlockLength.Get(), AllottedGeometry), TRACK_DEFAULT_HEIGHT);
	}
	// full track size
	else if (NodeBlockLength.Get() == -1.f)
	{
		NodeWidth = Parent->DataToLocalX(Parent->ViewInputMax.Get(), AllottedGeometry);
		return FVector2D(Parent->DataToLocalX(Parent->ViewInputMax.Get(), AllottedGeometry), TRACK_DEFAULT_HEIGHT);
	}
	// minimal size
	else
	{

		const TSharedRef< FSlateFontMeasure > FontMeasureService = FSlateApplication::Get().GetRenderer()->GetFontMeasureService();
		FVector2D TextSize = FontMeasureService->Measure(NodeName.Get().ToString(), DrawFont) + FVector2D(5, 5)/*Font Padding*/;
		NodeWidth = FMath::Max(TRACK_NODE_MINIMAL_WIDTH, TextSize.X);
	}

	// custom height
	if (NodeBlockHeight.Get() > 0.f)
	{
		NodeHeight = NodeBlockHeight.Get();
	}
	// full track size
	else if (NodeBlockHeight.Get() == -1.f)
	{
		NodeHeight = TRACK_DEFAULT_HEIGHT;
	}
	else
	{
		NodeHeight = TRACK_NODE_DEFAULT_HEIGHT;
	}

	return FVector2D(NodeWidth, NodeHeight);
}

FVector2D STrackNodeWidget::GetTrackNodeOffset(const STrackWidget* Parent, const FGeometry& AllottedGeometry) const
{
	return FVector2D(Parent->DataToLocalX(NodeStartPos.Get(), AllottedGeometry), (AllottedGeometry.GetLocalSize().Y - GetTrackNodeSize(Parent, AllottedGeometry).Y) / 2);
}

TSharedPtr<SWidget> STrackNodeWidget::SummonNodeContextMenu(const FGeometry& MyGeometry, const FPointerEvent& MouseEvent)
{
	const bool bInShouldCloseWindowAfterMenuSelection = true;
	FMenuBuilder MenuBuilder(bInShouldCloseWindowAfterMenuSelection, nullptr);

	FVector2D MousePosition = MouseEvent.GetScreenSpacePosition();

	bool bSummonedContextMenu = false;

	if (OnBuildNodeContextMenu.IsBound())
	{
		if (OnBuildNodeContextMenu.Execute(MenuBuilder))
		{
			bSummonedContextMenu = true;
		}
	}

	TSharedPtr<SWidget> MenuWidget;
	if (bSummonedContextMenu)
	{
		MenuWidget = MenuBuilder.MakeWidget();	

		FWidgetPath WidgetPath = MouseEvent.GetEventPath() != nullptr ? *MouseEvent.GetEventPath() : FWidgetPath();
		FSlateApplication::Get().PushMenu(SharedThis(this), WidgetPath, MenuWidget.ToSharedRef(), MousePosition, FPopupTransitionEffect(FPopupTransitionEffect::ContextMenu));
	}

	return MenuWidget;	
}

FReply STrackNodeWidget::OnMouseButtonUp( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent )
{
	if (MouseEvent.GetEffectingButton() == EKeys::LeftMouseButton)
	{
		if (CanBeSelected()) Select();
	}
	else if (MouseEvent.GetEffectingButton() == EKeys::RightMouseButton)
	{
		auto ContextMenuWidget = SummonNodeContextMenu(MyGeometry, MouseEvent);
		return (ContextMenuWidget.IsValid())
			? FReply::Handled().ReleaseMouseCapture().SetUserFocus( ContextMenuWidget.ToSharedRef(), EFocusCause::SetDirectly )
			: FReply::Handled().ReleaseMouseCapture();	
	}

	return FReply::Unhandled();
}

FReply STrackNodeWidget::OnMouseButtonDown( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent )
{
	if (MouseEvent.GetEffectingButton() == EKeys::LeftMouseButton)
	{
		return FReply::Handled().DetectDrag(SharedThis(this), EKeys::LeftMouseButton);
	}

	return FReply::Unhandled();
}

FReply STrackNodeWidget::OnDragDetected( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent )
{
	if (MouseEvent.IsMouseButtonDown(EKeys::LeftMouseButton))
	{
		if (IsAllowDrag())
		{
			bOnDragging = true;

			// begin drage
			Select();

			return FReply::Handled().BeginDragDrop(CreateDragDropOperation(MyGeometry, MouseEvent));
		}
	}

	return FReply::Unhandled();
}

TSharedRef<FDragDropOperation> STrackNodeWidget::CreateDragDropOperation(const FGeometry& MyGeometry, const FPointerEvent& MouseEvent)
{
	FVector2D ScreenCurPos = MouseEvent.GetScreenSpacePosition();
	FVector2D ScreenNodePosition(MyGeometry.AbsolutePosition);

	return FLocalNodeDrageDropOp::New(SharedThis(this), ScreenCurPos, ScreenNodePosition);
}

void STrackNodeWidget::OnDropNode(const FPointerEvent& MouseEvent)
{
	bOnDragging = false;
}

void STrackNodeWidget::SnapNodeToDataPosition(float DataPosition)
{
	OnDataPositionChanged.ExecuteIfBound(DataPosition);
}

/*********************************************************/
// STrackWidget
/*********************************************************/
STrackWidget::STrackWidget()
	: TrackNodes(this)
{}

void STrackWidget::Construct(const FArguments& InArgs)
{
	// initialize with arguments
	ViewInputMin = InArgs._ViewInputMin;
	ViewInputMax = InArgs._ViewInputMax;
	TrackColor = InArgs._TrackColor;
	CursorColor = InArgs._CursorColor;
	CursorPosition = InArgs._CursorPosition;
	OnBuildContextMenu = InArgs._OnBuildContextMenu;
	OnTrackDragDrop = InArgs._OnTrackDragDrop;

	SetClipping(EWidgetClipping::ClipToBounds);
}

void STrackWidget::OnArrangeChildren( const FGeometry& AllottedGeometry, FArrangedChildren& ArrangedChildren ) const
{
	for (int32 Index = 0; Index < TrackNodes.Num(); ++Index)
	{
		TSharedRef<STrackNodeWidget> TrackNode = TrackNodes[Index];
		// Handled when node is under dragging
		if (TrackNode->ShouldHideWhenDrag() && TrackNode->bOnDragging)
			continue;

		// Arrange Children
		FVector2D NodeOffset = TrackNode->GetTrackNodeOffset(this, AllottedGeometry);
		FVector2D NodeSize = TrackNode->GetTrackNodeSize(this, AllottedGeometry);
		ArrangedChildren.AddWidget(AllottedGeometry.MakeChild(TrackNode, NodeOffset, NodeSize));
	}
}

int32 STrackWidget::OnPaint( const FPaintArgs& Args, const FGeometry& AllottedGeometry, const FSlateRect& MyCullingRect, FSlateWindowElementList& OutDrawElements, int32 LayerId, const FWidgetStyle& InWidgetStyle, bool bParentEnabled ) const
{
	int32 CustomLayerId = LayerId + 1;
	FPaintGeometry MyGeometry = AllottedGeometry.ToPaintGeometry();

	// Background
	FSlateDrawElement::MakeBox(
		OutDrawElements,
		CustomLayerId++,
		MyGeometry, 
		FAppStyle::GetBrush(TEXT("Graph.Node.NodeBackground")),
		ESlateDrawEffect::None,
		TrackColor.Get()
	);


	CustomLayerId = SPanel::OnPaint( Args, AllottedGeometry, MyCullingRect, OutDrawElements, CustomLayerId, InWidgetStyle, bParentEnabled ); 

	// Draw cursor on the top layer
	float Position = FMath::Clamp(CursorPosition.Get(), ViewInputMin.Get(), ViewInputMax.Get());
	if (Position >= 0.f)
	{
		float XPositiion = DataToLocalX(Position, AllottedGeometry);
		TArray<FVector2D> LinePoints = { FVector2D(XPositiion, 0.f), FVector2D(XPositiion, AllottedGeometry.Size.Y) };
		FSlateDrawElement::MakeLines(
			OutDrawElements,
			CustomLayerId++,
			MyGeometry,
			LinePoints,
			ESlateDrawEffect::None,
			CursorColor.Get(),
			true/*bAntialias*/, 
			2.0f/*Thickness*/
		);
	}

	return CustomLayerId;
}

FVector2D STrackWidget::ComputeDesiredSize(float) const
{
	FVector2D Size;
	Size.X = 5000;	// fill width
	Size.Y = TRACK_DEFAULT_HEIGHT;
	return Size;
}

FChildren* STrackWidget::GetChildren()
{
	return &TrackNodes;
}

FReply STrackWidget::OnDragDetected( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent )
{
	return FReply::Unhandled();
}

FReply STrackWidget::OnDragOver( const FGeometry& MyGeometry, const FDragDropEvent& DragDropEvent )
{
	TSharedPtr<FLocalNodeDrageDropOp> DragDropOp = DragDropEvent.GetOperationAs<FLocalNodeDrageDropOp>();
	if (DragDropOp.IsValid())
	{
		OnTrackNodeDrageOver(MyGeometry, DragDropEvent, DragDropOp);
	}

	return FReply::Unhandled();
}

FReply STrackWidget::OnDrop( const FGeometry& MyGeometry, const FDragDropEvent& DragDropEvent )
{
	FVector2D CursorPos = MyGeometry.AbsoluteToLocal(DragDropEvent.GetScreenSpacePosition());
	float CursorDataPos = LocalXToData(CursorPos.X, MyGeometry);

	TSharedPtr<FLocalNodeDrageDropOp> DragDropOp = DragDropEvent.GetOperationAs<FLocalNodeDrageDropOp>();
	if (DragDropOp.IsValid())
	{
		OnTrackNodeDrageOver(MyGeometry, DragDropEvent, DragDropOp);
	}

	if (OnTrackDragDrop.IsBound())
	{
		OnTrackDragDrop.ExecuteIfBound(DragDropEvent.GetOperation(), CursorDataPos);
	}

	return FReply::Unhandled();
}

void STrackWidget::OnTrackNodeDrageOver(const FGeometry& MyGeometry, const FDragDropEvent& DragDropEvent, TSharedPtr<FLocalNodeDrageDropOp> NodeDrageDropOp)
{
	TSharedPtr<STrackNodeWidget> Node = NodeDrageDropOp->OriginalTrackNode.Pin();
	// update node position
	if (Node.IsValid())
	{
		FVector2D DragDropPos = DragDropEvent.GetScreenSpacePosition() + NodeDrageDropOp->Offset;
		FVector2D CursorPos = MyGeometry.AbsoluteToLocal(DragDropPos);
		float DataPos = LocalXToData(CursorPos.X, MyGeometry);
		Node->SnapNodeToDataPosition(DataPos);
	}
}

FReply STrackWidget::OnMouseButtonDown( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent )
{
	// if (MouseEvent.GetEffectingButton() == EKeys::LeftMouseButton)
	// {
	// 	if (!bDragging)
	// 	{
	// 		return FReply::Handled().DetectDrag(SharedThis(this), EKeys::LeftMouseButton);
	// 	}
	// }

	return FReply::Unhandled();
}

FReply STrackWidget::OnMouseButtonUp( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent )
{
	bool bRightMouseButton = MouseEvent.GetEffectingButton() == EKeys::RightMouseButton;
	bool bLeftMouseButton = MouseEvent.GetEffectingButton() == EKeys::LeftMouseButton;
	if (bRightMouseButton)
	{
		auto ContextMenuWidget = SummonContextMenu(MyGeometry, MouseEvent);
		return (ContextMenuWidget.IsValid())
			? FReply::Handled().ReleaseMouseCapture().SetUserFocus( ContextMenuWidget.ToSharedRef(), EFocusCause::SetDirectly )
			: FReply::Handled().ReleaseMouseCapture();
	}
	else if (bLeftMouseButton)
	{
	/*
		//TODO: check if under drag
		// =>> STrack.cpp
		bool bUndderDragging = bDragging;
		if (bUndderDragging)
		{
			// TODO: on drop
		}
		else
		{
			// TODO: on click
		}

		bDragging = false;
		bDraggingNode = false;
		DraggingNodePtr = nullptr;
	*/
	}

	return FReply::Unhandled();
}

void STrackWidget::OnMouseEnter( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent )
{
}

FReply STrackWidget::OnMouseMove( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent )
{
	return FReply::Unhandled();
}

void STrackWidget::OnMouseLeave( const FPointerEvent& MouseEvent )
{
}

float STrackWidget::DataToLocalX(float Time, const FGeometry& MyGeometry) const
{
	FTrackScaleInfo ScaleInfo(ViewInputMin.Get(), ViewInputMax.Get(), 0, 0, MyGeometry.GetLocalSize());
	return ScaleInfo.InputToLocalX(Time);
}

float STrackWidget::LocalXToData(float LocalX, const FGeometry& MyGeometry) const
{
	FTrackScaleInfo ScaleInfo(ViewInputMin.Get(), ViewInputMax.Get(), 0, 0, MyGeometry.GetLocalSize());
	return ScaleInfo.LocalXToInput(LocalX);
}

TSharedPtr<SWidget> STrackWidget::SummonContextMenu(const FGeometry& MyGeometry, const FPointerEvent& MouseEvent)
{
	const bool bInShouldCloseWindowAfterMenuSelection = true;
	FMenuBuilder MenuBuilder(bInShouldCloseWindowAfterMenuSelection, TrackActions);

	FVector2D MousePosition = MouseEvent.GetScreenSpacePosition();
	LastClickTime = LocalXToData(MyGeometry.AbsoluteToLocal(MousePosition).X, MyGeometry);

	bool bSummonedContextMenu = false;
	// ContextMenu for node

	// ContextMenu for track
	if (OnBuildContextMenu.IsBound())
	{
		if (OnBuildContextMenu.Execute(MenuBuilder))
		{
			bSummonedContextMenu = true;
		}
	}

	TSharedPtr<SWidget> MenuWidget;
	if (bSummonedContextMenu)
	{
		MenuWidget = MenuBuilder.MakeWidget();	

		FWidgetPath WidgetPath = MouseEvent.GetEventPath() != nullptr ? *MouseEvent.GetEventPath() : FWidgetPath();
		FSlateApplication::Get().PushMenu(SharedThis(this), WidgetPath, MenuWidget.ToSharedRef(), MousePosition, FPopupTransitionEffect(FPopupTransitionEffect::ContextMenu));
	}

	return MenuWidget;
}

void STrackWidget::UpdateDraggingNode(const FGeometry& MyGeometry, const FVector2D& CursorScreenPos)
{
	FVector2D CursorPos = MyGeometry.AbsoluteToLocal(CursorScreenPos);
	for (int32 Index = 0; Index < TrackNodes.Num(); Index++ )
	{
		TSharedRef<STrackNodeWidget> NodePtr = TrackNodes[Index];
		if (FMath::Abs(NodePtr->GetTrackNodeOffset(this, MyGeometry).X - CursorPos.X) < 5)
		{
			break;
		}
	}
}

void STrackWidget::AddTrackNode( TSharedRef<STrackNodeWidget> Node )
{
	TrackNodes.Add(Node);
}

void STrackWidget::ClearTrack()
{
	TrackNodes.Empty();
}