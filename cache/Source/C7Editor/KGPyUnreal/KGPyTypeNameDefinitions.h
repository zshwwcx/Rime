#pragma once

#include "pybind11/unreal.h"

template <typename T>
struct ::pybind11::unreal::type_name<T, std::enable_if_t<::pybind11::detail::is_unreal_base_structure<T>::value>>
{
	static std::string get() { return TCHAR_TO_UTF8(*TBaseStructure<T>::Get()->GetName()); }
};

template <typename T>
struct ::pybind11::unreal::type_name<T, std::enable_if_t<::pybind11::detail::is_unreal_object_type<T>::value>>
{
	static std::string get() { return TCHAR_TO_UTF8(*T::StaticClass()->GetName()); }
};

template <typename T>
struct ::pybind11::unreal::type_name<TObjectPtr<T>>
{
	static std::string get() { return std::string("TObjectPtr<") + ::pybind11::unreal::type_name<T>::get() + std::string(">"); }
};

template <typename T>
struct ::pybind11::unreal::type_name<TWeakObjectPtr<T>>
{
	static std::string get() { return std::string("TWeakObjectPtr<") + ::pybind11::unreal::type_name<T>::get() + std::string(">"); }
};

template <typename T>
struct ::pybind11::unreal::type_name<TOptional<T>>
{
	static std::string get() { return std::string("TOptional<") + ::pybind11::unreal::type_name<T>::get() + std::string(">"); }
};

template <typename T>
struct ::pybind11::unreal::type_name<TAttribute<T>>
{
	static std::string get() { return std::string("TAttribute<") + ::pybind11::unreal::type_name<T>::get() + std::string(">"); }
};

template <typename T>
struct ::pybind11::unreal::type_name<TSharedPtr<T>>
{
	static std::string get() { return std::string("TSharedPtr<") + ::pybind11::unreal::type_name<T>::get() + std::string(">"); }
};

template <typename T>
struct ::pybind11::unreal::type_name<const T*>
{
	static std::string get() { return std::string("const ") + ::pybind11::unreal::type_name<T>::get() + std::string(" *"); }
};

#pragma region String

PYBIND11_UNREAL_REGISTER_TYPE_NAME(FString);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(FText);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(FName);

#pragma endregion

#pragma region Math

PYBIND11_UNREAL_REGISTER_TYPE_NAME(FVector2f);

#pragma endregion

PYBIND11_UNREAL_REGISTER_TYPE_NAME(TDelegate<void()>);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(TDelegate<int(int)>);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(TMulticastDelegate<void(int)>);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(TDelegate<FReply()>);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(TDelegate<FReply(const FGeometry&, const FPointerEvent&)>);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(TDelegate<void(const FGeometry&, const FPointerEvent&)>);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(TDelegate<void(const FPointerEvent&)>);

PYBIND11_UNREAL_REGISTER_TYPE_NAME(EWindowType);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EVisibility);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EWidgetUpdateFlags);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EInvalidateWidgetReason);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EMouseCursor::Type);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EWindowActivationPolicy);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EHorizontalAlignment);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EVerticalAlignment);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EButtonClickMethod::Type);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EButtonTouchMethod::Type);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EButtonPressMethod::Type);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EOrientation);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EWidgetClipping);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EWidgetPixelSnapping);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EFlowDirectionPreference);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(EFocusCause);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(ETextTransformPolicy);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(ETextFlowDirection);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(ETextShapingMethod);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(ETextJustify::Type);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(ETextOverflowPolicy);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(ETextWrappingPolicy);

PYBIND11_UNREAL_REGISTER_TYPE_NAME(FSlateApplication);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(FReply);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(FSlateWidgetPersistentState);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(FWidgetProxyHandle);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(FSlateRect);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(FSlotBase);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(FArrangedChildren);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(FChildren);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(FSlateClippingState);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(FSlateRenderTransform);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(FTextLayout::FLineView);

PYBIND11_UNREAL_REGISTER_TYPE_NAME(IToolTip);

PYBIND11_UNREAL_REGISTER_TYPE_NAME(STableViewBase);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(SCompoundWidget);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(SWidget);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(SHorizontalBox);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(SHorizontalBox::FArguments);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(SHorizontalBox::FScopedWidgetSlotArguments);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(SHorizontalBox::FSlot);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(SButton);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(SButton::FArguments);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(SBorder);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(SBorder::FArguments);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(STextBlock);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(STextBlock::FArguments);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(SWindow);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(SWindow::FArguments);