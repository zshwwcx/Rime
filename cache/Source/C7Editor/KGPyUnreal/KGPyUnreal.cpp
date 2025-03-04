#include "KGPyUnreal.h"
#include "KGPythonScriptSubModuleHelper.h"

PRAGMA_DISABLE_DEPRECATION_WARNINGS
PYBIND11_MODULE(kg, Module)
{
	Module.doc() = "unreal python module exported with pybind11";

	py::unreal_enum<EWindowType>(Module, "WindowType")
		.value_auto_naming(EWindowType, Normal)
		.value_auto_naming(EWindowType, Menu)
		.value_auto_naming(EWindowType, ToolTip)
		.value_auto_naming(EWindowType, Notification)
		.value_auto_naming(EWindowType, CursorDecorator)
		.value_auto_naming(EWindowType, GameWindow)
		.export_values();

	KGPyUnreal::Initialize_BindingTest(Module);
	KGPyUnreal::Initialize_Slate(Module);
	KGPyUnreal::Initialize_KGCore(Module);
}
PRAGMA_ENABLE_DEPRECATION_WARNINGS

void KGPyUnreal::Initialize()
{
	FKGPythonScriptSubModuleHelper::FPyScopedGIL GIL;
	PyObject* SysModules = PyImport_GetModuleDict();
	PyDict_SetItemString(SysModules, "kg", PyInit_kg());
}