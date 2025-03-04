#include "KGPyUnreal.h"

namespace UE::Python::Internal
{
	class SUserWidget : public SCompoundWidget
	{
		SLATE_DECLARE_WIDGET(SUserWidget, SCompoundWidget)

	public:
		SLATE_BEGIN_ARGS(SUserWidget) {}
			SLATE_ARGUMENT(py::object, Object)
		SLATE_END_ARGS()

		void Construct(const FArguments& Arguments)
		{
		}

		void SetContent(TSharedRef<SWidget> InContent)
		{
			ChildSlot[InContent];
		}
	};

	SLATE_IMPLEMENT_WIDGET(SUserWidget)
	void SUserWidget::PrivateRegisterAttributes(FSlateAttributeInitializer& AttributeInitializer)
	{
	}

	class FPythonObject : public TSharedFromThis<FPythonObject>
	{
	public:
		FPythonObject()
		{
		}

		FPythonObject(const py::object& InObject) : Object(InObject)
		{
		}

		py::object GetObject() const { return Object; }

	private:
		py::object Object;
	};

	class SPythonListView : public SListView<TSharedRef<FPythonObject>>
	{
	public:
		using Super = SListView<TSharedRef<FPythonObject>>;
		using ItemType = TSharedRef<FPythonObject>;

		void Construct(const typename SListView<ItemType>::FArguments& InArgs)
		{
			const_cast<SListView<ItemType>::FArguments&>(InArgs).ListItemsSource(&PythonItemsSourceCache);
			Super::Construct(InArgs);
		}

		void SetItemsSource(py::list InPythonItemsSource)
		{
			PythonItemsSource = InPythonItemsSource;
			MigrateCache();
		}

		virtual void RequestListRefresh() override
		{
			MigrateCache();
			Super::RequestListRefresh();
		}

	private:
		void MigrateCache()
		{
			PythonItemsSourceCache.Empty();
			for (auto& Item : PythonItemsSource)
			{
				PythonItemsSourceCache.Add(MakeShared<FPythonObject>(Item.cast<py::object>()));
			}
			Super::SetItemsSource(&PythonItemsSourceCache);
		}

		py::list PythonItemsSource;
		TArray<ItemType> PythonItemsSourceCache;
	};

	class SPythonTableRow : public STableRow<TSharedRef<FPythonObject>>
	{
	public:
		void Construct(const typename SPythonTableRow::FArguments& InArgs, const TSharedRef<STableViewBase>& InOwnerTableView)
		{
			STableRow<TSharedRef<FPythonObject>>::Construct(InArgs, InOwnerTableView);
		}
	};

	struct FOnGenerateRowLambda
	{
		FOnGenerateRowLambda(py::object InTableRowType, py::function InFunction)
			: Function(InFunction)
			, TableRowType(InTableRowType)
		{
		}

		TSharedRef<ITableRow> operator()(TSharedRef<FPythonObject> Item, const TSharedRef<STableViewBase>& TableViewBase)
		{
			FKGPythonScriptSubModuleHelper::FPyScopedGIL GIL;
			pybind11::object result;
			try
			{
				result = Function(Item->GetObject(), StaticCastSharedRef<SPythonListView>(TableViewBase));
			}
			catch (...)
			{
				pybind11::detail::try_translate_exceptions();
			}
			if (result.ptr() == nullptr || result.is_none() || !py::isinstance(result, TableRowType))
			{
				return SNew(SPythonTableRow, TableViewBase)
					.Content()
					[
						SNew(STextBlock)
						.Text(FText::FromString(TEXT("The return value of the on_generate_row function needs to be of type STableRow.")))
					];
			}
			else
			{
				auto TableRow = py::cast<TSharedPtr<SPythonTableRow>>(result);
				return StaticCastSharedRef<ITableRow>(TableRow.ToSharedRef());
			}
		}

		py::function Function;
		py::object TableRowType;
	};
}

PYBIND11_UNREAL_REGISTER_TYPE_NAME(UE::Python::Internal::SUserWidget);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(UE::Python::Internal::SUserWidget::FArguments);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(UE::Python::Internal::SPythonListView);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(UE::Python::Internal::SPythonListView::FArguments);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(UE::Python::Internal::SPythonTableRow);
PYBIND11_UNREAL_REGISTER_TYPE_NAME(UE::Python::Internal::SPythonTableRow::FArguments);

PYBIND11_NAMESPACE_BEGIN(PYBIND11_NAMESPACE)
namespace detail
{
	template <> struct is_copy_constructible<SHorizontalBox::FArguments> : std::false_type {};
	template <> struct is_copy_constructible<SVerticalBox::FArguments> : std::false_type {};
}
PYBIND11_NAMESPACE_END(PYBIND11_NAMESPACE)

using namespace UE::Python::Internal;

PRAGMA_DISABLE_DEPRECATION_WARNINGS

void KGPyUnreal::Initialize_Slate(py::module_& Module)
{
	py::unreal_class<FReply>(Module, "Reply")
		.def_static_auto_naming(FReply, Handled)
		.def_static_auto_naming(FReply, Unhandled);

	py::unreal_delegate<FSimpleDelegate>(Module, "SimpleDelegate");
	py::unreal_delegate<FOnClicked>(Module, "OnClicked");

	#pragma region FSlateApplication
	py::unreal_class<FSlateApplication>(Module, "SlateApplication")
		.def_static_auto_naming(FSlateApplication, Get, py::return_value_policy::reference)
		.def_auto_naming(FSlateApplication, AddWindow, py::arg(), py::arg("bShowImmediately") = true);
	#pragma endregion

	#pragma region SWidget
	py::unreal_class<SWidget, TSharedPtr<SWidget>>(Module, "SWidget")
		.def_auto_naming(SWidget, NeedsPrepass)
		.def_overloaded_auto_naming(SWidget, SlatePrepass, void(SWidget::*)())
		.def_overloaded_auto_naming(SWidget, SlatePrepass, void(SWidget::*)(float))
		.def_auto_naming(SWidget, SetCanTick)
		.def_auto_naming(SWidget, GetCanTick)
		.def_auto_naming(SWidget, HasRegisteredSlateAttribute)
		.def_auto_naming(SWidget, IsAttributesUpdatesEnabled)
		.def_auto_naming(SWidget, GetPersistentState)
		.def_auto_naming(SWidget, GetProxyHandle)
		.def_auto_naming(SWidget, GetDesiredSize)
		.def_auto_naming(SWidget, AssignParentWidget)
		.def_auto_naming(SWidget, ConditionallyDetatchParentWidget)
		.def_auto_naming(SWidget, ValidatePathToChild)
		.def_auto_naming(SWidget, IsParentValid)
		.def_auto_naming(SWidget, GetParentWidget)
		.def_auto_naming(SWidget, Advanced_GetPaintParentWidget)
		.def_auto_naming(SWidget, CalculateCullingAndClippingRules)
		.def_auto_naming(SWidget, HasAnyUpdateFlags)
		.def_overloaded_auto_naming(SWidget, GetRelativeLayoutScale, float(SWidget::*)(const int32, float)const)
		.def_overloaded_auto_naming(SWidget, GetRelativeLayoutScale, float(SWidget::*)(const FSlotBase&, float)const)
		.def_auto_naming(SWidget, ArrangeChildren)
		.def_auto_naming(SWidget, GetChildren)
		.def_auto_naming(SWidget, GetAllChildren)
		.def_auto_naming(SWidget, SupportsKeyboardFocus)
		.def_auto_naming(SWidget, HasKeyboardFocus)
		.def_auto_naming(SWidget, HasUserFocus)
		.def_auto_naming(SWidget, HasAnyUserFocus)
		.def_auto_naming(SWidget, HasUserFocusedDescendants)
		.def_auto_naming(SWidget, HasFocusedDescendants)
		.def_auto_naming(SWidget, HasAnyUserFocusOrFocusedDescendants)
		.def_auto_naming(SWidget, HasMouseCapture)
		.def_auto_naming(SWidget, HasMouseCaptureByUser)
		.def_auto_naming(SWidget, SetEnabled)
		.def_auto_naming(SWidget, IsEnabled)
		.def_auto_naming(SWidget, IsInteractable)
		.def_auto_naming(SWidget, GetToolTip)
		.def_auto_naming(SWidget, EnableToolTipForceField)
		.def_auto_naming(SWidget, HasToolTipForceField)
		.def_auto_naming(SWidget, IsHovered)
		.def_auto_naming(SWidget, IsDirectlyHovered)
		.def_auto_naming(SWidget, GetVisibility)
		.def_auto_naming(SWidget, SetVisibility)
		.def_auto_naming(SWidget, IsFastPathVisible)
		.def_auto_naming(SWidget, IsVolatile)
		.def_auto_naming(SWidget, IsVolatileIndirectly)
		.def_auto_naming(SWidget, ForceVolatile)
		.def_auto_naming(SWidget, ShouldInvalidatePrepassDueToVolatility)
		.def_auto_naming(SWidget, Invalidate)
		.def_auto_naming(SWidget, CacheVolatility)
		.def_auto_naming(SWidget, InvalidatePrepass)
		.def_auto_naming(SWidget, MarkPrepassAsDirty)
		.def_auto_naming(SWidget, GetRenderOpacity)
		.def_auto_naming(SWidget, SetRenderOpacity)
		.def_auto_naming(SWidget, SetTag)
		.def_auto_naming(SWidget, GetRenderTransform)
		.def_auto_naming(SWidget, GetRenderTransformWithRespectToFlowDirection)
		.def_auto_naming(SWidget, GetRenderTransformPivotWithRespectToFlowDirection)
		.def_auto_naming(SWidget, SetRenderTransform)
		.def_auto_naming(SWidget, GetRenderTransformPivot)
		.def_auto_naming(SWidget, SetRenderTransformPivot)
		.def_auto_naming(SWidget, SetClipping)
		.def_auto_naming(SWidget, GetClipping)
		.def_auto_naming(SWidget, SetPixelSnapping)
		.def_auto_naming(SWidget, GetPixelSnapping)
		.def_auto_naming(SWidget, SetCullingBoundsExtension)
		.def_auto_naming(SWidget, GetCullingBoundsExtension)
		.def_auto_naming(SWidget, SetFlowDirectionPreference)
		.def_auto_naming(SWidget, GetFlowDirectionPreference)
		.def_overloaded_auto_naming(SWidget, SetToolTipText, void(SWidget::*)(const TAttribute<FText>&))
		.def_overloaded_auto_naming(SWidget, SetToolTipText, void(SWidget::*)(const FText&))
		.def_auto_naming(SWidget, SetToolTip)
		.def_auto_naming(SWidget, SetCursor)
		.def_auto_naming(SWidget, SetOnMouseButtonDown)
		.def_auto_naming(SWidget, SetOnMouseButtonUp)
		.def_auto_naming(SWidget, SetOnMouseMove)
		.def_auto_naming(SWidget, SetOnMouseDoubleClick)
		.def_auto_naming(SWidget, SetOnMouseEnter)
		.def_auto_naming(SWidget, SetOnMouseLeave)
		.def_auto_naming(SWidget, ToString)
		.def_auto_naming(SWidget, GetTypeAsString)
		.def_auto_naming(SWidget, GetType)
		.def_auto_naming(SWidget, GetReadableLocation)
		.def_auto_naming(SWidget, GetCreatedInLocation)
		.def_auto_naming(SWidget, GetTag)
		.def_auto_naming(SWidget, GetForegroundColor)
		.def_auto_naming(SWidget, GetDisabledForegroundColor)
		.def_auto_naming(SWidget, GetCachedGeometry)
		.def_auto_naming(SWidget, GetTickSpaceGeometry)
		.def_auto_naming(SWidget, GetPaintSpaceGeometry)
		.def_auto_naming(SWidget, GetCurrentClippingState)
		.def_auto_naming(SWidget, Advanced_IsWindow)
		.def_auto_naming(SWidget, Advanced_IsInvalidationRoot)
		;

	#pragma endregion

	#pragma region SCompoundWidget
	py::unreal_class<SCompoundWidget, SWidget, TSharedPtr<SCompoundWidget>>(Module, "SCompoundWidget");
	#pragma endregion

	#pragma region SUserWidget
	py::unreal_slate_widget_class<UE::Python::Internal::SUserWidget, SCompoundWidget>(Module, "SUserWidget")
		.def_content()
		.def_auto_naming(UE::Python::Internal::SUserWidget, SetContent)
		;
	#pragma endregion

	#pragma region SWindow
		py::unreal_slate_widget_class<SWindow, SCompoundWidget>(Module, "SWindow")
		.def_property_readonly_auto_naming(SWindow, ActivationPolicy)
		.def_auto_naming(SWindow, SetContent)
		.def_auto_naming(SWindow, RequestDestroyWindow)
		.def_argument_auto_naming(SWindow::FArguments, Type)
		.def_argument_auto_naming(SWindow::FArguments, ClientSize);
	#pragma endregion

	#pragma region STextBlock
	py::unreal_slate_widget_class<STextBlock>(Module, "STextBlock")
		.def_argument_auto_naming(STextBlock::FArguments, Text)
		.def_argument_auto_naming(STextBlock::FArguments, TextStyle)
		.def_argument_auto_naming(STextBlock::FArguments, Font)
		.def_argument_auto_naming(STextBlock::FArguments, StrikeBrush)
		.def_argument_auto_naming(STextBlock::FArguments, ColorAndOpacity)
		.def_argument_auto_naming(STextBlock::FArguments, ShadowOffset)
		.def_argument_auto_naming(STextBlock::FArguments, ShadowColorAndOpacity)
		.def_argument_auto_naming(STextBlock::FArguments, HighlightColor)
		.def_argument_auto_naming(STextBlock::FArguments, HighlightShape)
		.def_argument_auto_naming(STextBlock::FArguments, HighlightText)
		.def_argument_auto_naming(STextBlock::FArguments, WrapTextAt)
		.def_argument_auto_naming(STextBlock::FArguments, AutoWrapText)
		.def_argument_auto_naming(STextBlock::FArguments, WrappingPolicy)
		.def_argument_auto_naming(STextBlock::FArguments, TransformPolicy)
		.def_argument_auto_naming(STextBlock::FArguments, Margin)
		.def_argument_auto_naming(STextBlock::FArguments, LineHeightPercentage)
		.def_argument_auto_naming(STextBlock::FArguments, ApplyLineHeightToBottomLine)
		.def_argument_auto_naming(STextBlock::FArguments, Justification)
		.def_argument_auto_naming(STextBlock::FArguments, MinDesiredWidth)
		.def_argument_auto_naming(STextBlock::FArguments, TextShapingMethod)
		.def_argument_auto_naming(STextBlock::FArguments, TextFlowDirection)
		.def_argument_auto_naming(STextBlock::FArguments, OverflowPolicy)
		.def_argument_auto_naming(STextBlock::FArguments, SimpleTextMode)
		.def_argument_auto_naming(STextBlock::FArguments, OnDoubleClicked)
		.def_auto_naming(STextBlock, GetText)
		.def_auto_naming(STextBlock, SetText)
		.def_auto_naming(STextBlock, SetHighlightText)
		.def_auto_naming(STextBlock, SetFont)
		.def_auto_naming(STextBlock, SetStrikeBrush)
		.def_auto_naming(STextBlock, SetColorAndOpacity)
		.def_auto_naming(STextBlock, SetTextStyle)
		.def_auto_naming(STextBlock, SetTextShapingMethod)
		.def_auto_naming(STextBlock, SetTextFlowDirection)
		.def_auto_naming(STextBlock, SetWrapTextAt)
		.def_auto_naming(STextBlock, SetAutoWrapText)
		.def_auto_naming(STextBlock, SetWrappingPolicy)
		.def_auto_naming(STextBlock, SetTransformPolicy)
		.def_auto_naming(STextBlock, GetTransformPolicy)
		.def_auto_naming(STextBlock, SetOverflowPolicy)
		.def_auto_naming(STextBlock, SetShadowOffset)
		.def_auto_naming(STextBlock, SetShadowColorAndOpacity)
		.def_auto_naming(STextBlock, SetHighlightColor)
		.def_auto_naming(STextBlock, SetHighlightShape)
		.def_auto_naming(STextBlock, SetMinDesiredWidth)
		.def_auto_naming(STextBlock, SetLineHeightPercentage)
		.def_auto_naming(STextBlock, SetApplyLineHeightToBottomLine)
		.def_auto_naming(STextBlock, SetMargin)
		.def_auto_naming(STextBlock, SetJustification)
		.def_auto_naming(STextBlock, GetColorAndOpacity)
		.def_auto_naming(STextBlock, GetColorAndOpacityRef)
		.def_auto_naming(STextBlock, GetFont)
		.def_auto_naming(STextBlock, GetFontRef)
		.def_auto_naming(STextBlock, GetStrikeBrush)
		.def_auto_naming(STextBlock, GetTransformPolicyImpl)
		.def_auto_naming(STextBlock, GetShadowOffset)
		.def_auto_naming(STextBlock, GetShadowColorAndOpacity)
		.def_auto_naming(STextBlock, GetShadowColorAndOpacityRef)
		.def_auto_naming(STextBlock, GetHighlightColor)
		.def_auto_naming(STextBlock, GetHighlightShape)
		.def_auto_naming(STextBlock, GetMargin)
		.def_auto_naming(STextBlock, GetMinDesiredWidth)
		.def_auto_naming(STextBlock, GetTextLayoutSize)
		.def_auto_naming(STextBlock, SetAdaptiveOffset)
		.def_auto_naming(STextBlock, GetLineModelNum)
		.def_auto_naming(STextBlock, GetLineViewsSize)
		.def_auto_naming(STextBlock, GetLayoutLineView)
		;
	#pragma endregion

	#pragma region SBorder
	py::unreal_slate_widget_class<SBorder, SCompoundWidget>(Module, "SBorder")
		.def_content()
		.def_argument_auto_naming(SBorder::FArguments, HAlign)
		.def_argument_auto_naming(SBorder::FArguments, VAlign)
		.def_argument_auto_naming(SBorder::FArguments, OnMouseButtonDown)
		.def_argument_auto_naming(SBorder::FArguments, OnMouseButtonUp)
		.def_argument_auto_naming(SBorder::FArguments, OnMouseMove)
		.def_argument_auto_naming(SBorder::FArguments, OnMouseDoubleClick)
		.def_argument_auto_naming(SBorder::FArguments, BorderImage)
		.def_argument_auto_naming(SBorder::FArguments, ContentScale)
		.def_argument_auto_naming(SBorder::FArguments, DesiredSizeScale)
		.def_argument_auto_naming(SBorder::FArguments, ColorAndOpacity)
		.def_argument_auto_naming(SBorder::FArguments, BorderBackgroundColor)
		.def_argument_auto_naming(SBorder::FArguments, ForegroundColor)
		.def_argument_auto_naming(SBorder::FArguments, ShowEffectWhenDisabled)
		.def_argument_auto_naming(SBorder::FArguments, FlipForRightToLeftFlowDirection)
		.def_auto_naming(SBorder, SetContent)
		.def_auto_naming(SBorder, GetContent)
		.def_auto_naming(SBorder, ClearContent)
		.def_auto_naming(SBorder, SetBorderBackgroundColor)
		.def_auto_naming(SBorder, GetBorderBackgroundColor)
		.def_auto_naming(SBorder, SetDesiredSizeScale)
		.def_auto_naming(SBorder, SetHAlign)
		.def_auto_naming(SBorder, SetVAlign)
		.def_auto_naming(SBorder, SetPadding)
		.def_auto_naming(SBorder, SetShowEffectWhenDisabled)
		.def_auto_naming(SBorder, SetBorderImage)
		.def_auto_naming(SBorder, GetBorderImage)
		;
	#pragma endregion

	#pragma region SButton
	py::unreal_slate_widget_class<SButton, SBorder>(Module, "SButton")
		.def_content()
		.def_argument_auto_naming(SButton::FArguments, ButtonStyle)
		.def_argument_auto_naming(SButton::FArguments, TextStyle)
		.def_argument_auto_naming(SButton::FArguments, HAlign)
		.def_argument_auto_naming(SButton::FArguments, VAlign)
		.def_argument_auto_naming(SButton::FArguments, ContentPadding)
		.def_argument_auto_naming(SButton::FArguments, Text)
		.def_argument_auto_naming(SButton::FArguments, OnClicked)
		.def_argument_auto_naming(SButton::FArguments, OnPressed)
		.def_argument_auto_naming(SButton::FArguments, OnReleased)
		.def_argument_auto_naming(SButton::FArguments, OnHovered)
		.def_argument_auto_naming(SButton::FArguments, OnUnhovered)
		.def_argument_auto_naming(SButton::FArguments, ClickMethod)
		.def_argument_auto_naming(SButton::FArguments, TouchMethod)
		.def_argument_auto_naming(SButton::FArguments, PressMethod)
		.def_argument_auto_naming(SButton::FArguments, DesiredSizeScale)
		.def_argument_auto_naming(SButton::FArguments, ContentScale)
		.def_argument_auto_naming(SButton::FArguments, ButtonColorAndOpacity)
		.def_argument_auto_naming(SButton::FArguments, ForegroundColor)
		.def_argument_auto_naming(SButton::FArguments, IsFocusable)
		.def_argument_auto_naming(SButton::FArguments, PressedSoundOverride)
		.def_argument_auto_naming(SButton::FArguments, HoveredSoundOverride)
		.def_argument_auto_naming(SButton::FArguments, TextShapingMethod)
		.def_argument_auto_naming(SButton::FArguments, TextFlowDirection)
		.def_auto_naming(SButton, GetBorder)
		.def_auto_naming(SButton, GetForegroundColor)
		.def_auto_naming(SButton, GetDisabledForegroundColor)
		.def_auto_naming(SButton, IsPressed)
		.def_auto_naming(SButton, SetContentPadding)
		.def_auto_naming(SButton, SetHoveredSound)
		.def_auto_naming(SButton, SetPressedSound)
		.def_auto_naming(SButton, SetOnClicked)
		.def_auto_naming(SButton, SetOnHovered)
		.def_auto_naming(SButton, SetOnUnhovered)
		.def_auto_naming(SButton, SetButtonStyle)
		.def_auto_naming(SButton, SetClickMethod)
		.def_auto_naming(SButton, SetTouchMethod)
		.def_auto_naming(SButton, SetPressMethod)
#if !UE_BUILD_SHIPPING
		.def_auto_naming(SButton, SimulateClick)
#endif // !UE_BUILD_SHIPPING
		;
	#pragma endregion

	#pragma region SHorizontalBox
	auto InsertWidget = [](SHorizontalBox& Self, const py::args& Args, const py::kwargs& Kwargs) -> void
	{
		int Index = INDEX_NONE;
		TSharedPtr<SWidget> Widget;
		pybind11::detail::make_caster<int> IndexCaster;
		pybind11::detail::make_caster<SWidget> WidgetCaster;
		do
		{
			int ArgumentIndex = 0;
			if (ArgumentIndex < Args.size() && IndexCaster.load(Args[ArgumentIndex], true))
			{
				Index = IndexCaster;
				ArgumentIndex++;
			}
			if (ArgumentIndex < Args.size() && WidgetCaster.load(Args[ArgumentIndex], false))
			{
				Widget = static_cast<SWidget&>(WidgetCaster).AsShared();
				ArgumentIndex++;
			}
		} while (false);
		auto SlotArguments = Self.InsertSlot(Index);
#pragma push_macro("cast")
#undef cast
		auto PythonSlotArguments = pybind11::detail::make_caster<decltype(SlotArguments)>::cast(std::addressof(SlotArguments), pybind11::return_value_policy::reference, pybind11::handle());
#pragma pop_macro("cast")
		pybind11::arguments_migrator::migrate(PythonSlotArguments, Kwargs);
		if (Widget)
		{
			SlotArguments[Widget.ToSharedRef()];
		}
	};
	py::unreal_slate_widget_class<SHorizontalBox>(Module, "SHorizontalBox")
		.def("add_widget", InsertWidget, py::return_value_policy::reference)
		.def("insert_widget", InsertWidget, py::return_value_policy::reference)
		.def_auto_naming(SHorizontalBox, AddSlot, py::return_value_policy::reference)
		.def_auto_naming(SHorizontalBox, InsertSlot, py::return_value_policy::reference)
		.def_auto_naming(SHorizontalBox, RemoveSlot)
		.def_overloaded_auto_naming(SHorizontalBox, GetSlot, SHorizontalBox::FSlot&(SHorizontalBox::*)(int32), py::return_value_policy::reference)
		.def_slot_content()
		.def_slot_argument_auto_naming(SHorizontalBox::FScopedWidgetSlotArguments, AutoWidth)
		.def_slot_argument_auto_naming(SHorizontalBox::FScopedWidgetSlotArguments, FillWidth)
		.def_slot_argument_auto_naming(SHorizontalBox::FScopedWidgetSlotArguments, MaxWidth)
		;
	#pragma endregion

	#pragma region STableRow
	py::unreal_slate_widget_class<SPythonTableRow, SBorder>(Module, "STableRow")
		.def_content();
	#pragma endregion

	#pragma region SListView
	py::unreal_class<STableViewBase, SCompoundWidget, TSharedPtr<STableViewBase>>(Module, "STableViewBase");
	using namespace UE::Python::Internal;
	py::unreal_slate_widget_class<SPythonListView, STableViewBase>(Module, "SListView")
		.def_argument<py::function>("on_generate_row", [Module](SPythonListView::FArguments& Self, py::function Function)
		{
			Self.OnGenerateRow_Lambda(FOnGenerateRowLambda(Module.attr("STableRow"), Function));
		})
		.def_argument_auto_naming(SPythonListView::FArguments, Orientation)
		.def_auto_naming(SPythonListView, SetItemsSource)
		.def_auto_naming(SPythonListView, RequestListRefresh)
		;
	#pragma endregion
}

PRAGMA_ENABLE_DEPRECATION_WARNINGS