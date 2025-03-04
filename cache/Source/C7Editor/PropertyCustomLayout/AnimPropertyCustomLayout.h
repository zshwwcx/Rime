#pragma once

#include "CoreMinimal.h"
#include "IPropertyTypeCustomization.h"

#include "3C/Animation/AnimCommon.h"
#include "3C/Animation/AnimationGraphNode/CustomAnimNodeDefine.h"

/**
 * 动画相关属性编辑自定义布局
 */
  
//FAnimAssetID
class FAnimAssetIDCustomLayout : public IPropertyTypeCustomization
{
public:
	static TSharedRef<IPropertyTypeCustomization> MakeInstance()
	{
		return MakeShareable(new FAnimAssetIDCustomLayout());
	}

	virtual void CustomizeHeader(TSharedRef<IPropertyHandle> InPropertyHandle, FDetailWidgetRow& HeaderRow, IPropertyTypeCustomizationUtils& CustomizationUtils);
	virtual void CustomizeChildren(TSharedRef<IPropertyHandle> InPropertyHandle, IDetailChildrenBuilder& ChildBuilder, IPropertyTypeCustomizationUtils& CustomizationUtils){};

	FAnimAssetID* GetPropertyID(TSharedRef<IPropertyHandle> InPropertyHandle);
	void SetAssetID(FString InAssetID);


protected:
	TSharedPtr<IPropertyHandle> PropertyHandle;

};


class FAnimNodeAssetIDCustomLayout : public IPropertyTypeCustomization
{
public:
	static TSharedRef<IPropertyTypeCustomization> MakeInstance()
	{
		return MakeShareable(new FAnimNodeAssetIDCustomLayout());
	}

	virtual void CustomizeHeader(TSharedRef<IPropertyHandle> InPropertyHandle, FDetailWidgetRow& HeaderRow, IPropertyTypeCustomizationUtils& CustomizationUtils);
	virtual void CustomizeChildren(TSharedRef<IPropertyHandle> InPropertyHandle, IDetailChildrenBuilder& ChildBuilder, IPropertyTypeCustomizationUtils& CustomizationUtils) {};

	FAnimNodeAssetID* GetPropertyID(TSharedRef<IPropertyHandle> InPropertyHandle);
	void SetAssetID(FString InAssetID);

	void SetCategoryID(int32 InCategoryID);

protected:
	TSharedPtr<IPropertyHandle> PropertyHandle;

};

