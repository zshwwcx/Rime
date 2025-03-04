#pragma once

#include "pybind11/unreal.h"
#include "KGPyTypeNameDefinitions.h"

namespace KGPyUnreal
{
    void Initialize();

	void Initialize_BindingTest(py::module_& Module);
	void Initialize_Slate(py::module_& Module);
	void Initialize_KGCore(py::module_& Module);
}