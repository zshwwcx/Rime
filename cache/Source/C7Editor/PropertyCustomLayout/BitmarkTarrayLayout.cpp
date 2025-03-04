#include "BitmarkTarrayLayout.h"
#include "Widgets/SCompoundWidget.h"
#include "DetailWidgetRow.h"
#include "PropertyHandle.h"

#define LOCTEXT_NAMESPACE "BitmarkTarrayLayout"

class SPropertyEditorBitArray : public SCompoundWidget
{
public:

	SLATE_BEGIN_ARGS(SPropertyEditorBitArray)
	{}
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs, TSharedRef<IPropertyHandle>  _PropertyHandle)
	{
		bIsUsingSlider = false;
		FSlateFontInfo _Font = FAppStyle::GetFontStyle(TEXT("PropertyWindow.NormalFont"));
		PropertyHandle = _PropertyHandle;

		const FProperty* Property = _PropertyHandle->GetProperty();

		if (Property->HasMetaData(TEXT("Bitmask")))
		{
			auto CreateBitmaskFlagsArray = [](const FProperty* Prop)
			{
				const int32 BitmaskBitCount = sizeof(int32) << 3;

				TArray<FBitmaskFlagInfo> Result;
				Result.Empty(BitmaskBitCount);

				const UEnum* BitmaskEnum = nullptr;
				const FString& BitmaskEnumName = Prop->GetMetaData(TEXT("BitmaskEnum"));
				if (!BitmaskEnumName.IsEmpty())
				{
					// @TODO: Potentially replace this with a parameter passed in from a member variable on the FProperty (e.g. FByteProperty::Enum)
					BitmaskEnum = FindObject<UEnum>(nullptr, *BitmaskEnumName);
				}

				if (BitmaskEnum)
				{
					const bool bUseEnumValuessAsMaskValues = BitmaskEnum->GetBoolMetaData(TEXT("UseEnumValuesAsMaskValuesInEditor"));
					auto AddNewBitmaskFlagLambda = [BitmaskEnum, &Result](int32 InEnumIndex, int32 InFlagValue)
					{
						Result.Emplace();
						FBitmaskFlagInfo* BitmaskFlag = &Result.Last();

						BitmaskFlag->Value = InEnumIndex;
						BitmaskFlag->DisplayName = BitmaskEnum->GetDisplayNameTextByIndex(InEnumIndex);
						BitmaskFlag->ToolTipText = BitmaskEnum->GetToolTipTextByIndex(InEnumIndex);
						if (BitmaskFlag->ToolTipText.IsEmpty())
						{
							BitmaskFlag->ToolTipText = FText::Format(LOCTEXT("BitmaskDefaultFlagToolTipText", "Toggle {0} on/off"), BitmaskFlag->DisplayName);
						}
					};

					// Note: This loop doesn't include (BitflagsEnum->NumEnums() - 1) in order to skip the implicit "MAX" value that gets added to the enum type at compile time.
					for (int32 BitmaskEnumIndex = 0; BitmaskEnumIndex < BitmaskEnum->NumEnums() - 1; ++BitmaskEnumIndex)
					{
						const int64 EnumValue = BitmaskEnum->GetValueByIndex(BitmaskEnumIndex);
						const bool bIsHidden = BitmaskEnum->HasMetaData(TEXT("Hidden"), BitmaskEnumIndex);
						if (EnumValue >= 0 && !bIsHidden)
						{
							if (bUseEnumValuessAsMaskValues)
							{
								if (EnumValue < MAX_int32 && FMath::IsPowerOfTwo(EnumValue))
								{
									AddNewBitmaskFlagLambda(BitmaskEnumIndex, static_cast<int32>(EnumValue));
								}
							}
							else if (EnumValue < BitmaskBitCount)
							{
								AddNewBitmaskFlagLambda(BitmaskEnumIndex, TBitmaskValueHelpers::LeftShift(1, EnumValue));
							}
						}
					}
				}
				else
				{
					for (int32 BitmaskFlagIndex = 0; BitmaskFlagIndex < BitmaskBitCount; ++BitmaskFlagIndex)
					{
						Result.Emplace();
						FBitmaskFlagInfo* BitmaskFlag = &Result.Last();

						BitmaskFlag->Value = TBitmaskValueHelpers::LeftShift(1, BitmaskFlagIndex);
						BitmaskFlag->DisplayName = FText::Format(LOCTEXT("BitmaskDefaultFlagDisplayName", "Flag {0}"), FText::AsNumber(BitmaskFlagIndex + 1));
						BitmaskFlag->ToolTipText = FText::Format(LOCTEXT("BitmaskDefaultFlagToolTipText", "Toggle {0} on/off"), BitmaskFlag->DisplayName);
					}
				}

				return Result;
			};

			const FComboBoxStyle& ComboBoxStyle = FCoreStyle::Get().GetWidgetStyle< FComboBoxStyle >("ComboBox");

			const auto& GetComboButtonText = [this, CreateBitmaskFlagsArray, Property]() -> FText
			{
				FBitmarkArray* BitArray = GetRawStructData(PropertyHandle);
				if (BitArray && BitArray->BitArray.Num() <= 1)
				{
					if (BitArray->BitArray.Num() == 1)
					{
						TArray<FBitmaskFlagInfo> BitmaskFlags = CreateBitmaskFlagsArray(Property);
						for (int i = 0; i < BitmaskFlags.Num(); ++i)
						{
							if (BitArray->BitArray[0] == BitmaskFlags[i].Value)
							{
								return BitmaskFlags[i].DisplayName;
							}
						}
					}

					return LOCTEXT("BitmaskButtonContentNoFlagsSet", "(No Flags Set)");
				}
				else
				{
					return LOCTEXT("MultipleValues", "Multiple Values");
				}
			};

			// Constructs the UI for bitmask property editing.
			SAssignNew(PrimaryWidget, SComboButton)
				.ComboButtonStyle(&ComboBoxStyle.ComboButtonStyle)
				.ContentPadding(FMargin(4.0, 2.0))
				.ToolTipText_Lambda([this, CreateBitmaskFlagsArray, Property]
					{
						FBitmarkArray* BitArray = GetRawStructData(PropertyHandle);
						if (BitArray)
						{
							TArray<FBitmaskFlagInfo> BitmaskFlags = CreateBitmaskFlagsArray(Property);

							TArray<FText> SetFlags;
							SetFlags.Reserve(BitmaskFlags.Num());

							for (const FBitmaskFlagInfo& FlagInfo : BitmaskFlags)
							{
								if (BitArray->BitArray.Find(FlagInfo.Value))
								{
									SetFlags.Add(FlagInfo.DisplayName);
								}
							}

							return FText::Join(FText::FromString(" | "), SetFlags);
						}

						return FText::GetEmpty();
					})
				.ButtonContent()
						[
							SNew(STextBlock)
							.Font(_Font)
						.Text_Lambda(GetComboButtonText)
						]
					.OnGetMenuContent_Lambda([this, CreateBitmaskFlagsArray, Property]()
						{
							FMenuBuilder MenuBuilder(false, nullptr);

							TArray<FBitmaskFlagInfo> BitmaskFlags = CreateBitmaskFlagsArray(Property);
							for (int i = 0; i < BitmaskFlags.Num(); ++i)
							{
								MenuBuilder.AddMenuEntry(
									BitmaskFlags[i].DisplayName,
									BitmaskFlags[i].ToolTipText,
									FSlateIcon(),
									FUIAction
									(
										FExecuteAction::CreateLambda([this, i, BitmaskFlags]()
											{
												{
													OnValueCommitted(BitmaskFlags[i].Value);
												}
											}),
										FCanExecuteAction(),
												FIsActionChecked::CreateLambda([this, i, BitmaskFlags]() -> bool
													{
														FBitmarkArray* BitArray = GetRawStructData(PropertyHandle);
														if (BitArray)
														{
															return BitArray->BitArray.Contains(BitmaskFlags[i].Value);
														}

														return false;
													})
												),
									NAME_None,
														EUserInterfaceActionType::Check);
							}

							return MenuBuilder.MakeWidget();
						});

					ChildSlot.AttachWidget(PrimaryWidget.ToSharedRef());
		}

		SetEnabled(TAttribute<bool>(this, &SPropertyEditorBitArray::CanEdit));
	}

private:

	void OnValueCommitted(int32 NewValue)
	{
		FBitmarkArray* BitArray = GetRawStructData(PropertyHandle);
		if (BitArray)
		{
			if (BitArray->BitArray.Contains(NewValue))
			{
				BitArray->BitArray.Remove(NewValue);
			}
			else
			{
				BitArray->BitArray.AddUnique(NewValue);
			}
		}
	}

	bool CanEdit() const
	{
		return true;
	}

	struct TBitmaskValueHelpers
	{
		static int32 BitwiseAND(int32 Base, int32 Mask) { return Base & Mask; }
		static int32 BitwiseXOR(int32 Base, int32 Mask) { return Base ^ Mask; }
		static int32 LeftShift(int32 Base, int32 Shift) { return Base << Shift; }
	};

	struct FBitmaskFlagInfo
	{
		int32 Value;
		FText DisplayName;
		FText ToolTipText;
	};

private:

	FBitmarkArray* GetRawStructData(TWeakPtr<IPropertyHandle> _PropertyHandle)
	{
		void* RawData = nullptr;
		PropertyHandle.Pin().Get()->GetValueData(RawData);
		if (RawData)
		{
			return static_cast<FBitmarkArray*>(RawData);

		}

		return nullptr;
	}

	TWeakPtr<IPropertyHandle> PropertyHandle;

	TSharedPtr< class SWidget > PrimaryWidget;

	/** True if the slider is being used to change the value of the property */
	bool bIsUsingSlider;
};

void FBitmarkTarrayLayout::CustomizeHeader(TSharedRef<IPropertyHandle> InPropertyHandle, FDetailWidgetRow& HeaderRow, IPropertyTypeCustomizationUtils& CustomizationUtils)
{
	PropertyHandle = InPropertyHandle;

	FBitmarkArray* BitArray = GetRawStructData(InPropertyHandle);
	if (BitArray)
	{
		InPropertyHandle->MarkResetToDefaultCustomized(true);

		HeaderRow
			.NameContent()
			[
				InPropertyHandle->CreatePropertyNameWidget()
			]
		.ValueContent()
			.MinDesiredWidth(400)
			[
				SNew(SPropertyEditorBitArray, InPropertyHandle)
			];
	}
}

void FBitmarkTarrayLayout::CustomizeChildren(
	TSharedRef<IPropertyHandle> InPropertyHandle,
	IDetailChildrenBuilder& ChildBuilder,
	IPropertyTypeCustomizationUtils& CustomizationUtils)
{

}

FBitmarkArray* FBitmarkTarrayLayout::GetRawStructData(TSharedRef<IPropertyHandle> InPropertyHandle)
{
	void* RawData = nullptr;
	PropertyHandle->GetValueData(RawData);
	if (RawData)
	{
		return static_cast<FBitmarkArray*>(RawData);

	}

	return nullptr;
}

#undef LOCTEXT_NAMESPACE