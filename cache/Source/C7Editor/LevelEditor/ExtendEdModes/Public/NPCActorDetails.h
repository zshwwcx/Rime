#pragma once

#include "DetailLayoutBuilder.h"
#include "IDetailCustomization.h"

class FNPCActorDetails : public IDetailCustomization
{
public:
	FNPCActorDetails();
	static TSharedRef<IDetailCustomization> MakeInstance();

	virtual void CustomizeDetails(IDetailLayoutBuilder& DetailLayout) override;

protected:
	// comment by shijingzhe: delete deprecated ALTNpcSpawner
	// ECheckBoxState IsModeRadioChecked(ALTNpcSpawner* Actor, int OptionIndex) const;
	// void OnModeRadioChanged(ECheckBoxState CheckType, ALTNpcSpawner* Actor, int OptionIndex);

private:
	FText OnGetNPCTemplateText() const;
	void OnSelectNPCTemplate(TSharedPtr<FString>  NewSelection, ESelectInfo::Type SelectInfo);

private:
	int32 SelectIndex = 0;
	TArray<TSharedPtr<FString>> CharacterDatas;
	// UDataTable* TemplateTable = nullptr;
};