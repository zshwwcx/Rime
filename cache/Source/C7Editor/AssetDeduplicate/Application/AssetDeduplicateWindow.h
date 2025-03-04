#pragma once
#include "Widgets/Docking/SDockTab.h"

class FAssetDeduplicateManager;

class SAssetDeduplicateWindow : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SAssetDeduplicateWindow){}
	SLATE_END_ARGS()

	void Construct( const FArguments& InArgs );
	FReply OnStartClicked();
	FReply OnReferenceClicked();
	FReply OnFilterClicked() const;

	TSharedPtr<FAssetDeduplicateManager> Manager;
};
