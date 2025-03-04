#pragma once

#include "Widgets/SCompoundWidget.h"

class SNPCGeneratorEdModeWidget : public SCompoundWidget
{
public:
	SNPCGeneratorEdModeWidget();

	SLATE_BEGIN_ARGS(SNPCGeneratorEdModeWidget) {}
	SLATE_END_ARGS();

	void Construct(const FArguments& InArgs);
	
	class FNPCGeneratorEdMode* GetEdMode() const;

	FReply OnAddNPC();
	bool CanAddNPC() const;
	FReply OnRemoveNPC();
	bool CanRemoveNPC() const;

private:
	FText OnGetNPCTemplateText() const;
	void OnSelectNPCTemplate(TSharedPtr<FString>  NewSelection, ESelectInfo::Type SelectInfo);

private:
	int32 SelectIndex = 0;
	TArray<TSharedPtr<FString>> CharacterDatas;
	TWeakObjectPtr<UDataTable> TemplateTable = nullptr;
};