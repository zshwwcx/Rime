#include "KGPyUnreal.h"

#include "Components/Widget.h"

namespace UE::Python::Internal
{
	struct Test
	{
	public:
		DECLARE_DELEGATE_RetVal_OneParam(int, FDelegate, int);
		DECLARE_MULTICAST_DELEGATE_OneParam(FMulticastDelegate, int);

	public:
		Test() { }

		TSharedPtr<Test> get_shared_ptr() const { return shared_ptr; }
		TSharedPtr<Test> set_shared_ptr(TSharedPtr<Test> in_shared_ptr) { return shared_ptr = in_shared_ptr; }
		TArray<TSharedPtr<Test>> set_shared_ptr_array(const TArray<TSharedPtr<Test>>& in_array) { return in_array; }

		TSharedRef<Test> get_or_create_shared_ref() const { return shared_ptr == nullptr ? MakeShared<Test>() : shared_ptr.ToSharedRef(); }
		TSharedRef<Test> set_shared_ref(TSharedRef<Test> in_shared_ref) { return (shared_ptr = in_shared_ref).ToSharedRef(); }
		TArray<TSharedRef<Test>> set_shared_ref_array(const TArray<TSharedRef<Test>>& in_array) { return in_array; }

		TWeakPtr<Test> get_weak_ptr() const { return shared_ptr.ToWeakPtr();; }
		TWeakPtr<Test> set_weak_ptr(TWeakPtr<Test> in_weak_ptr) { return shared_ptr = in_weak_ptr.Pin(); }
		TArray<TWeakPtr<Test>> set_weak_ptr_array(const TArray<TWeakPtr<Test>>& in_array) { return in_array; }

		int get_integer() const { return integer; }
		int set_integer(int in_integer) { return integer = in_integer; }
		TArray<int> set_integer_array(const TArray<int>& in_array) { return in_array; }
		TSet<int> set_integer_set(const TSet<int>& in_set) { return in_set; }
		TMap<int, int> set_integer_to_integer_map(const TMap<int, int>& in_map) { return in_map; }

		FSlateBrush get_brush() const { return brush; }
		FSlateBrush& set_brush(const FSlateBrush& in_brush) { return brush = in_brush; }
		FSlateBrush& get_brush_ref() { return brush; }
		TArray<FSlateBrush> set_brush_array(const TArray<FSlateBrush>& in_array) { return in_array; }

		UWidget* get_widget() const { return widget.Get(); }
		UWidget* set_widget(UWidget* in_widget) { return (widget = TWeakObjectPtr<UWidget>(in_widget)).Get(); }
		TArray<UWidget*> set_widget_array(const TArray<UWidget*>& in_array) { return in_array; }

		TObjectPtr<UWidget> get_widget_object_ptr() const { return widget.Get(); }
		TObjectPtr<UWidget> set_widget_object_ptr(TObjectPtr<UWidget> in_widget) { return (widget = TWeakObjectPtr<UWidget>(in_widget)).Get(); }

		TWeakObjectPtr<UWidget> get_widget_weak_object_ptr() const { return widget.Get(); }
		TWeakObjectPtr<UWidget> set_widget_weak_object_ptr(TWeakObjectPtr<UWidget> in_widget) { return (widget = TWeakObjectPtr<UWidget>(in_widget)).Get(); }

		void set_delegate(const FDelegate& in_delegate) { delegate = in_delegate; }
		int execute_delegate(int in_integer) const
		{
			if (delegate.IsBound())
			{
				return delegate.Execute(in_integer);
			}
			return 0;
		}

		FMulticastDelegate& get_multicast_delegate_ref() { return multicast_delegate; }
		void broadcast_multicast_delegate(int in_integer) const
		{
			multicast_delegate.Broadcast(in_integer);
		}

		TArray<FString> set_string_array(const TArray<FString>& in_string_array) { return in_string_array; }
		FString set_string(const FString& in_string) { return in_string; }
		TArray<FText> set_text_array(const TArray<FText>& in_text_array) { return in_text_array; }
		FText set_text(const FText& in_text) { return in_text; }

	private:
		TSharedPtr<Test> shared_ptr;
		int integer;
		FSlateBrush brush;
		TWeakObjectPtr<UWidget> widget = nullptr;
		FDelegate delegate;
		FMulticastDelegate multicast_delegate;
	};
}

PYBIND11_UNREAL_REGISTER_TYPE_NAME(UE::Python::Internal::Test)

void KGPyUnreal::Initialize_BindingTest(py::module_& Module)
{
	Module.doc() = "test python module exported with pybind11";

	using Test = UE::Python::Internal::Test;

	auto Test_ = py::unreal_class<Test, TSharedPtr<Test>>(Module, "Test")
		.def(py::init())
		.def("get_shared_ptr", &Test::get_shared_ptr)
		.def("set_shared_ptr", &Test::set_shared_ptr)
		.def("set_shared_ptr_array", &Test::set_shared_ptr_array)
		.def("get_or_create_shared_ref", &Test::get_or_create_shared_ref)
		.def("set_shared_ref", &Test::set_shared_ref)
		.def("set_shared_ref_array", &Test::set_shared_ref_array)
		.def("get_weak_ptr", &Test::get_weak_ptr)
		.def("set_weak_ptr", &Test::set_weak_ptr)
		.def("set_weak_ptr_array", &Test::set_weak_ptr_array)
		.def("get_integer", &Test::get_integer)
		.def("set_integer", &Test::set_integer)
		.def("set_integer_array", &Test::set_integer_array)
		.def("set_integer_set", &Test::set_integer_set)
		.def("set_integer_to_integer_map", &Test::set_integer_to_integer_map)
		.def("get_brush", &Test::get_brush)
		.def("set_brush", &Test::set_brush)
		.def("get_brush_ref", &Test::get_brush_ref, py::return_value_policy::reference)
		.def("set_brush_array", &Test::set_brush_array)
		.def("get_widget", &Test::get_widget)
		.def("set_widget", &Test::set_widget)
		.def("set_widget_array", &Test::set_widget_array)
		.def("get_widget_object_ptr", &Test::get_widget_object_ptr)
		.def("set_widget_object_ptr", &Test::set_widget_object_ptr)
		.def("get_widget_weak_object_ptr", &Test::get_widget_weak_object_ptr)
		.def("set_widget_weak_object_ptr", &Test::set_widget_weak_object_ptr)
		.def("set_delegate", &Test::set_delegate)
		.def("execute_delegate", &Test::execute_delegate)
		.def("get_multicast_delegate_ref", &Test::get_multicast_delegate_ref, py::return_value_policy::reference)
		.def("broadcast_multicast_delegate", &Test::broadcast_multicast_delegate)
		.def("set_string_array", &Test::set_string_array)
		.def("set_string", &Test::set_string)
		.def("set_text_array", &Test::set_text_array)
		.def("set_text", &Test::set_text)
		;
	py::unreal_delegate<Test::FDelegate>(Test_, "Delegate");
	py::unreal_multicast_delegate<Test::FMulticastDelegate>(Test_, "MulticastDelegate");
}