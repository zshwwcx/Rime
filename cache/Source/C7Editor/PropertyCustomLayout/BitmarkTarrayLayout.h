#pragma once

#include "CoreMinimal.h"
#include "IPropertyTypeCustomization.h"
#include "Misc/C7Define.h"
#include "Templates/SharedPointer.h"


class FDetailWidgetRow;
class IPropertyHandle;

class FBitmarkTarrayLayout : public IPropertyTypeCustomization
{
public:
	static TSharedRef<IPropertyTypeCustomization> MakeInstance()
	{
		return MakeShareable(new FBitmarkTarrayLayout());
	}

	// IPropertyTypeCustomization interface
	virtual void CustomizeHeader(TSharedRef<IPropertyHandle> InPropertyHandle, FDetailWidgetRow& HeaderRow, IPropertyTypeCustomizationUtils& CustomizationUtils);
	virtual void CustomizeChildren(TSharedRef<IPropertyHandle> InPropertyHandle, IDetailChildrenBuilder& ChildBuilder, IPropertyTypeCustomizationUtils& CustomizationUtils);
	// End of IPropertyTypeCustomization interface

	FBitmarkArray* GetRawStructData(TSharedRef<IPropertyHandle> InPropertyHandle);

private:
	TSharedPtr<class IPropertyHandle> PropertyHandle;
};
