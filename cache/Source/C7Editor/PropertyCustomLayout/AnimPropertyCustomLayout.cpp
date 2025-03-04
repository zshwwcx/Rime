#include "AnimPropertyCustomLayout.h"

#include "Widgets/Layout/SBox.h"
#include "DetailWidgetRow.h"
#include "PropertyCustomizationHelpers.h"
#include "DetailLayoutBuilder.h"


//FAnimAssetID
 
class SAnimAssetIDList : public SCompoundWidget
{
public:
	DECLARE_DELEGATE_OneParam(FOnSelectedEvent, FString);

public:
	SLATE_BEGIN_ARGS(SAnimAssetIDList) : _AssetID(nullptr) {}
		SLATE_ARGUMENT(FAnimAssetID*, AssetID)
		SLATE_EVENT(FOnSelectedEvent, OnSelectID)
	SLATE_END_ARGS()

public:
	void Construct(const FArguments& InArgs)
	{
		this->AssetID = InArgs._AssetID;
		this->SelectedEvent = InArgs._OnSelectID;

		CurrentSelectedSubjectName = MakeShareable(new FString((this->AssetID ? this->AssetID->GetID() : "")));

		this->ChildSlot
			[
				SAssignNew(SubjectNameComboBox, SComboBox<TSharedPtr<FString>>)
				.OptionsSource(&SubjectNames)
				.OnGenerateWidget(this, &SAnimAssetIDList::MakeItemWidget)
				.OnSelectionChanged(this, &SAnimAssetIDList::OnSelectionChanged)
				.OnComboBoxOpening(this, &SAnimAssetIDList::OnSubjectNameComboBoxOpened)
				[
					SNew(STextBlock)
					.Text(this, &SAnimAssetIDList::GetSelectedSubjectName)
				]
			];
	}


	void OnSubjectNameComboBoxOpened()
	{
		SubjectNames.Reset();

		TArray<FString> NameList;
		
		FAnimAssetID::GetAnimAssetNameList(AssetID->AssetCategory, NameList);

		for (FString SubjectName : NameList)
		{
			SubjectNames.Add(MakeShareable(new FString(SubjectName)));
		}
	}

	TSharedRef<SWidget> MakeItemWidget(TSharedPtr<FString> StringItem)
	{
		return SNew(STextBlock).Text(FText::FromString(*StringItem));
	}

	void OnSelectionChanged(TSharedPtr<FString> StringItem, ESelectInfo::Type SelectInfo)
	{
		if (StringItem.IsValid())
		{
			CurrentSelectedSubjectName = MakeShareable(new FString(*StringItem));

			SelectedEvent.ExecuteIfBound(*StringItem);
		}
	}

	FText GetSelectedSubjectName() const
	{
		return CurrentSelectedSubjectName.IsValid() ? FText::FromString(*CurrentSelectedSubjectName) : FText();
	}

protected:

	TSharedPtr<FString> CurrentSelectedSubjectName;

	TSharedPtr<SComboBox<TSharedPtr<FString>>> SubjectNameComboBox;

	FOnSelectedEvent SelectedEvent;

	FAnimAssetID* AssetID = nullptr;
	TArray<TSharedPtr<FString>> SubjectNames;
};


FAnimAssetID* FAnimAssetIDCustomLayout::GetPropertyID(TSharedRef<IPropertyHandle> InPropertyHandle)
{
	void* RawData = NULL;
	InPropertyHandle->GetValueData(RawData);

	if (RawData)
		return static_cast<FAnimAssetID*>(RawData);

	return NULL;
}

void FAnimAssetIDCustomLayout::SetAssetID(FString InAssetID)
{
	FAnimAssetID* AsstIDPtr = GetPropertyID(PropertyHandle.ToSharedRef());
	if (AsstIDPtr && AsstIDPtr->GetID() != InAssetID)
	{
		PropertyHandle->NotifyPreChange();
		AsstIDPtr->AssetID = InAssetID;
		PropertyHandle->NotifyPostChange(EPropertyChangeType::ValueSet);
	}
}

void FAnimAssetIDCustomLayout::CustomizeHeader(TSharedRef<IPropertyHandle> InPropertyHandle, FDetailWidgetRow& HeaderRow, IPropertyTypeCustomizationUtils& CustomizationUtils)
{
	PropertyHandle = InPropertyHandle;
	HeaderRow
		.NameContent()
		[
			PropertyHandle->CreatePropertyNameWidget()
		]
		.ValueContent()
		[
			SNew(SAnimAssetIDList)
			.OnSelectID(this, &FAnimAssetIDCustomLayout::SetAssetID)
			.AssetID(GetPropertyID(InPropertyHandle))
		];

	HeaderRow.ValueWidget.MaxDesiredWidth(200);
}

//FAnimNodeAssetID

class SAnimNodeAssetIDList : public SCompoundWidget
{
public:
	DECLARE_DELEGATE_OneParam(FOnSelectedEvent, FString);

public:
	SLATE_BEGIN_ARGS(SAnimNodeAssetIDList) : _AssetID(nullptr) {}
	SLATE_ARGUMENT(FAnimNodeAssetID*, AssetID)
	SLATE_EVENT(FOnSelectedEvent, OnSelectID)
	SLATE_END_ARGS()

public:
	void Construct(const FArguments& InArgs)
	{
		this->AssetID = InArgs._AssetID;
		this->SelectedEvent = InArgs._OnSelectID;

		CurrentSelectedSubjectName = MakeShareable(new FString((this->AssetID ? this->AssetID->GetID() : "")));

		this->ChildSlot
			[
				SAssignNew(SubjectNameComboBox, SComboBox<TSharedPtr<FString>>)
				.OptionsSource(&SubjectNames)
				.OnGenerateWidget(this, &SAnimNodeAssetIDList::MakeItemWidget)
				.OnSelectionChanged(this, &SAnimNodeAssetIDList::OnSelectionChanged)
				.OnComboBoxOpening(this, &SAnimNodeAssetIDList::OnSubjectNameComboBoxOpened)
				[
					SNew(STextBlock)
					.Text(this, &SAnimNodeAssetIDList::GetSelectedSubjectName)
				]
			];
	}


	void OnSubjectNameComboBoxOpened()
	{
		SubjectNames.Reset();

		TArray<FString> NameList;

		if (AssetID)
		{
			FAnimAssetID::GetAnimAssetNameList(AssetID->AnimCategory, NameList);
		}
		else
		{
			FAnimAssetID::GetAnimAssetNameList(0, NameList);
		}
		

		for (FString SubjectName : NameList)
		{
			SubjectNames.Add(MakeShareable(new FString(SubjectName)));
		}
	}

	TSharedRef<SWidget> MakeItemWidget(TSharedPtr<FString> StringItem)
	{
		return SNew(STextBlock).Text(FText::FromString(*StringItem));
	}

	void OnSelectionChanged(TSharedPtr<FString> StringItem, ESelectInfo::Type SelectInfo)
	{
		if (StringItem.IsValid())
		{
			CurrentSelectedSubjectName = MakeShareable(new FString(*StringItem));

			SelectedEvent.ExecuteIfBound(*StringItem);
		}
	}

	FText GetSelectedSubjectName() const
	{
		return CurrentSelectedSubjectName.IsValid() ? FText::FromString(*CurrentSelectedSubjectName) : FText();
	}

protected:

	TSharedPtr<FString> CurrentSelectedSubjectName;

	TSharedPtr<SComboBox<TSharedPtr<FString>>> SubjectNameComboBox;

	FOnSelectedEvent SelectedEvent;

	FAnimNodeAssetID* AssetID = nullptr;
	TArray<TSharedPtr<FString>> SubjectNames;
};

class SAnimAnimCategoryList : public SCompoundWidget
{
public:
	DECLARE_DELEGATE_OneParam(FOnSelectedEvent, int32);

public:
	SLATE_BEGIN_ARGS(SAnimAnimCategoryList) : _AssetID(nullptr) {}
		SLATE_ARGUMENT(FAnimNodeAssetID*, AssetID)
		SLATE_EVENT(FOnSelectedEvent, OnSelectID)
	SLATE_END_ARGS()

public:
	void Construct(const FArguments& InArgs)
	{
		this->AssetID = InArgs._AssetID;
		this->SelectedEvent = InArgs._OnSelectID;

		OnSubjectNameComboBoxOpened();

		int32 CateNum = SubjectNames.Num();
		for (int32 i(0); i < CateNum; ++i)
		{
			if (i == this->AssetID->AnimCategory)
			{
				CurrentSelectedSubjectName = MakeShareable(new FString(*SubjectNames[i]));
				break;
			}
		}

		this->ChildSlot
			[
				SAssignNew(SubjectNameComboBox, SComboBox<TSharedPtr<FString>>)
					.OptionsSource(&SubjectNames)
					.OnGenerateWidget(this, &SAnimAnimCategoryList::MakeItemWidget)
					.OnSelectionChanged(this, &SAnimAnimCategoryList::OnSelectionChanged)
					.OnComboBoxOpening(this, &SAnimAnimCategoryList::OnSubjectNameComboBoxOpened)
					[
						SNew(STextBlock)
							.Text(this, &SAnimAnimCategoryList::GetSelectedSubjectName)
					]
			];
	}

	void OnSubjectNameComboBoxOpened()
	{
		SubjectNames.Reset();

		TArray<FString> NameList;

		FAnimAssetID::GetAnimCategoryList(NameList);

		for (FString SubjectName : NameList)
		{
			SubjectNames.Add(MakeShareable(new FString(SubjectName)));
		}
	}

	TSharedRef<SWidget> MakeItemWidget(TSharedPtr<FString> StringItem)
	{
		return SNew(STextBlock).Text(FText::FromString(*StringItem));
	}

	void OnSelectionChanged(TSharedPtr<FString> StringItem, ESelectInfo::Type SelectInfo)
	{
		if (StringItem.IsValid())
		{
			CurrentSelectedSubjectName = MakeShareable(new FString(*StringItem));
			 
			int32 Index(0);

			int32 CateNum = SubjectNames.Num();
			for (int32 i(0); i < CateNum; ++i)
			{
				if (*SubjectNames[i] == *StringItem)
				{
					Index = i;
					break;
				}
			}

			SelectedEvent.ExecuteIfBound(Index);
		}
	}

	FText GetSelectedSubjectName() const
	{
		return CurrentSelectedSubjectName.IsValid() ? FText::FromString(*CurrentSelectedSubjectName) : FText();
	}

protected:

	TSharedPtr<FString> CurrentSelectedSubjectName;

	TSharedPtr<SComboBox<TSharedPtr<FString>>> SubjectNameComboBox;

	FOnSelectedEvent SelectedEvent;

	FAnimNodeAssetID* AssetID = nullptr;
	TArray<TSharedPtr<FString>> SubjectNames;
};


FAnimNodeAssetID* FAnimNodeAssetIDCustomLayout::GetPropertyID(TSharedRef<IPropertyHandle> InPropertyHandle)
{
	void* RawData = NULL;
	InPropertyHandle->GetValueData(RawData);

	if (RawData)
		return static_cast<FAnimNodeAssetID*>(RawData);

	return NULL;
}

void FAnimNodeAssetIDCustomLayout::SetAssetID(FString InAssetID)
{
	FAnimNodeAssetID* AsstIDPtr = GetPropertyID(PropertyHandle.ToSharedRef());
	if (AsstIDPtr && AsstIDPtr->GetID() != InAssetID)
	{
		PropertyHandle->NotifyPreChange();
		AsstIDPtr->AssetID = InAssetID;
		PropertyHandle->NotifyPostChange(EPropertyChangeType::ValueSet);
	}
}

void FAnimNodeAssetIDCustomLayout::SetCategoryID(int32 InCategoryID)
{
	FAnimNodeAssetID* AsstIDPtr = GetPropertyID(PropertyHandle.ToSharedRef());
	if (AsstIDPtr && AsstIDPtr->AnimCategory != InCategoryID)
	{
		PropertyHandle->NotifyPreChange();
		AsstIDPtr->AnimCategory = InCategoryID;
		PropertyHandle->NotifyPostChange(EPropertyChangeType::ValueSet);
	}
}

void FAnimNodeAssetIDCustomLayout::CustomizeHeader(TSharedRef<IPropertyHandle> InPropertyHandle, FDetailWidgetRow& HeaderRow, IPropertyTypeCustomizationUtils& CustomizationUtils)
{
	PropertyHandle = InPropertyHandle;
	HeaderRow
		.NameContent()
		[
			PropertyHandle->CreatePropertyNameWidget()
		]
	.ValueContent()
	[
		SNew(SHorizontalBox)
			+ SHorizontalBox::Slot()
			.AutoWidth()
			[
				SNew(SAnimNodeAssetIDList)
					.OnSelectID(this, &FAnimNodeAssetIDCustomLayout::SetAssetID)
					.AssetID(GetPropertyID(InPropertyHandle))
			]
			+ SHorizontalBox::Slot()
			.AutoWidth()
			[
				SNew(SAnimAnimCategoryList)
					.OnSelectID(this, &FAnimNodeAssetIDCustomLayout::SetCategoryID)
					.AssetID(GetPropertyID(InPropertyHandle))
			]
	];

	//.ValueContent()
	//	[
	//		SNew(SAnimNodeAssetIDList)
	//		.OnSelectID(this, &FAnimNodeAssetIDCustomLayout::SetAssetID)
	//		.AssetID(GetPropertyID(InPropertyHandle))
	//	]
	//.ExtensionContent()
	//	[
	//		SNew(SAnimAnimCategoryList)
	//			.OnSelectID(this, &FAnimNodeAssetIDCustomLayout::SetCategoryID)
	//			.AssetID(GetPropertyID(InPropertyHandle))
	//	];

	HeaderRow.ValueWidget.MaxDesiredWidth(200);
}
