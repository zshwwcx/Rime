// Copyright 2020 T, Inc. All Rights Reserved.
#pragma once

#include "CoreMinimal.h"
#include "Widgets/SPanel.h"
#include "Layout/Children.h"
#include "Input/DragAndDrop.h"
#include "Widgets/DeclarativeSyntaxSupport.h"

class STrackWidget;
class FLocalNodeDrageDropOp;

class ISelectable
{
public:
	void ToggleSelect()
	{
		if (!CanBeSelected()) return;

		if (IsSelected())
		{
			OnDeselect();
			bIsSelected = false;
		}
		else
		{
			OnSelect();
			bIsSelected = true;
		}
	}

	FORCEINLINE bool IsSelected() const { return bIsSelected; }
	FORCEINLINE void Select()
	{
		if (!IsSelected()) ToggleSelect();
	}

	FORCEINLINE void Deselect()
	{
		if (IsSelected()) ToggleSelect();
	}

protected:
	virtual bool CanBeSelected() = 0;
	virtual void OnSelect() = 0;
	virtual void OnDeselect() = 0;

private:
	bool bIsSelected = false;
};

DECLARE_DELEGATE_RetVal_OneParam( bool, FOnBuildContextMenu, FMenuBuilder&)

/*********************************************************/
// STrackNodeWidget
/*********************************************************/
class STrackNodeWidget : public SCompoundWidget, public ISelectable
{
public:
	DECLARE_DELEGATE_OneParam( FOnSelectionChanged, bool /*bSelected*/ )
	DECLARE_DELEGATE_OneParam( FOnDataPositionChanged, float /*DataPosition*/ )

public:
	SLATE_BEGIN_ARGS( STrackNodeWidget ) 
		: _Content()
		, _NodeName()
		, _NodeColor(FLinearColor::Gray)
		, _SelectedNodeColor(FLinearColor::Green)
		, _NodeStartPos()
		, _NodeBlockLength()
		, _NodeBlockHeight()
		, _DataLength()
		, _AllowDrag(true)
		, _bDataLengthAsNodeLength(false)
		, _OnSelectionChanged()
		, _OnDataPositionChanged()
		, _OnBuildNodeContextMenu()
	{}
		SLATE_DEFAULT_SLOT( FArguments, Content )
		SLATE_ATTRIBUTE( FName, NodeName )
		SLATE_ATTRIBUTE( FLinearColor, NodeColor )
		SLATE_ATTRIBUTE( FLinearColor, SelectedNodeColor )
		SLATE_ATTRIBUTE( float, NodeStartPos )
		SLATE_ATTRIBUTE( float, NodeBlockLength )
		SLATE_ATTRIBUTE( float, NodeBlockHeight )
		SLATE_ATTRIBUTE( float, DataLength)
		SLATE_ATTRIBUTE( bool, AllowDrag )
		SLATE_ARGUMENT( bool, bDataLengthAsNodeLength )
		SLATE_EVENT( FOnSelectionChanged, OnSelectionChanged )
		SLATE_EVENT( FOnDataPositionChanged, OnDataPositionChanged )
		SLATE_EVENT( FOnBuildContextMenu, OnBuildNodeContextMenu )
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs);

	virtual FText GetNodeText() const;
	virtual FLinearColor GetNodeColor() const;
	FSlateColor GetNodeSlateColor() const
	{
		return GetNodeColor();
	}

	/** Relative Size to parent track */
	FVector2D GetTrackNodeSize(const STrackWidget* Parent, const FGeometry& AllottedGeometry) const;

	/** Relative offset to parent track */
	FVector2D GetTrackNodeOffset(const STrackWidget* Parent, const FGeometry& AllottedGeometry) const;

	// FVector2D ComputeDesiredSize(float) const override;

	//~ Begin: Mouse Interface
	FReply OnMouseButtonUp( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent ) override;
	FReply OnMouseButtonDown( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent ) override;
	FReply OnDragDetected( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent ) override;
	//~ End: Mouse Interface

	/** Drop node */
	void OnDropNode(const FPointerEvent& MouseEvent);

	/** CreateDragDropOperation */
	virtual TSharedRef<FDragDropOperation> CreateDragDropOperation(const FGeometry& MyGeometry, const FPointerEvent& MouseEvent);
	virtual bool IsAllowDrag() { return bAllowDrag.Get(); }
	virtual bool ShouldHideWhenDrag() { return true; }

	/** Make node move to data position */
	void SnapNodeToDataPosition(float DataPosition);
protected:
	//~ Begin: ISelectable
	void OnSelect() override;
	bool CanBeSelected() override { return true; }
	void OnDeselect() override;
	//~ End: ISelectable

	TSharedPtr<SWidget> SummonNodeContextMenu(const FGeometry& MyGeometry, const FPointerEvent& MouseEvent);
public:
	/** if node is under dragging */
	bool						bOnDragging;

protected:
	FSlateFontInfo				DrawFont;
	/** Node Name */
	TAttribute<FName> 			NodeName;
	/** Node base color */
	TAttribute<FLinearColor>	NodeColor;
	/** Node color when selected */
	TAttribute<FLinearColor>	SelectedNodeColor;

	/** data pos that node start at */
	TAttribute<float> 			NodeStartPos;
	/** data length of the node */
	TAttribute<float> 			NodeBlockLength;
	/** data height of the node */
	TAttribute<float> 			NodeBlockHeight;
	TAttribute<float> 			DateLength;
	bool						bDataLengthAsNodeLength;
	/** Node can be drage */
	TAttribute<bool> 			bAllowDrag;

	/** notified when node selected or deselected */
	FOnSelectionChanged			OnSelectionChanged;
	FOnDataPositionChanged		OnDataPositionChanged;
	FOnBuildContextMenu			OnBuildNodeContextMenu;
};

/*********************************************************/
// STrackWidget
/*********************************************************/
class STrackWidget : public SPanel
{
	DECLARE_DELEGATE_TwoParams( FOnTrackDragDrop, TSharedPtr<FDragDropOperation>, float )

	friend class STrackNodeWidget;
public:
	SLATE_BEGIN_ARGS( STrackWidget ) 
		: _ViewInputMin()
		, _ViewInputMax()
		, _CursorColor(FLinearColor::Red)
		, _CursorPosition()
		, _TrackColor(FLinearColor::White)
		, _OnBuildContextMenu()
		, _OnTrackDragDrop()
	{}
		SLATE_ATTRIBUTE( float, ViewInputMin )
		SLATE_ATTRIBUTE( float, ViewInputMax )
		SLATE_ATTRIBUTE( FLinearColor, CursorColor )
		SLATE_ATTRIBUTE( float, CursorPosition )
		SLATE_ATTRIBUTE( FLinearColor, TrackColor )
		SLATE_EVENT( FOnBuildContextMenu, OnBuildContextMenu )
		SLATE_EVENT( FOnTrackDragDrop, OnTrackDragDrop )
	SLATE_END_ARGS()

	STrackWidget();
	void Construct(const FArguments& InArgs);
	//~ Begin: SPanel
	void OnArrangeChildren(const FGeometry& AllottedGeometry, FArrangedChildren& ArrangedChildren) const override;
	FVector2D ComputeDesiredSize(float) const override;
	int32 OnPaint(const FPaintArgs& Args, const FGeometry& AllottedGeometry, const FSlateRect& MyCullingRect, FSlateWindowElementList& OutDrawElements, int32 LayerId, const FWidgetStyle& InWidgetStyle, bool bParentEnabled) const override;
	FChildren* GetChildren() override;

	/** Mouse Event*/
	FReply OnMouseButtonUp( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent ) override;
	FReply OnMouseButtonDown( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent ) override;

	void OnMouseEnter( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent ) override;
	FReply OnMouseMove( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent ) override;
	void OnMouseLeave( const FPointerEvent& MouseEvent ) override;
	/** Drage Event */
	FReply OnDragDetected( const FGeometry& MyGeometry, const FPointerEvent& MouseEvent ) override;
	FReply OnDragOver( const FGeometry& MyGeometry, const FDragDropEvent& DragDropEvent ) override;
	FReply OnDrop( const FGeometry& MyGeometry, const FDragDropEvent& DragDropEvent ) override;
	//~ End: SPanel

	void AddTrackNode( TSharedRef<STrackNodeWidget> Node );
	void ClearTrack();
protected:
	/** Context menu when right button click */
	virtual TSharedPtr<SWidget> SummonContextMenu(const FGeometry& MyGeometry, const FPointerEvent& MouseEvent);

	/** When tracknode drage over, update node position */
	void OnTrackNodeDrageOver(const FGeometry& MyGeometry, const FDragDropEvent& DragDropEvent, TSharedPtr<FLocalNodeDrageDropOp> NodeDrageDropOp);

private:
	/** returns local cordinate X with track data (time, etc.) */
	float DataToLocalX(float Data, const FGeometry& MyGeometry) const;

	/** returns track data (time, etc.) with local cordinate X*/
	float LocalXToData(float LocalX, const FGeometry& MyGeometry) const;

	/** update the node under dragging */
	void UpdateDraggingNode(const FGeometry& MyGeometry, const FVector2D& CursorScreenPos);

public:
	/** Mosue click at time */
	float									LastClickTime;

private:
	TAttribute<float>						ViewInputMin;
	TAttribute<float>						ViewInputMax;

	/** Track background color */
	TAttribute<FLinearColor>				TrackColor;
	/** Track nodes*/
	TSlotlessChildren<STrackNodeWidget> 	TrackNodes;

	/** Time position of the cursor */
	TAttribute<float>						CursorPosition;
	TAttribute<FLinearColor>				CursorColor;

	/** Command actions for context menu */
	TSharedPtr<FUICommandList> 				TrackActions;

	/** Hook to extend track context menu */
	FOnBuildContextMenu						OnBuildContextMenu;

	/** On drage to track */
	FOnTrackDragDrop						OnTrackDragDrop;
};